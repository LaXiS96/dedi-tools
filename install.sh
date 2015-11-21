#!/bin/bash
PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAyTUJfAeSIe3vPrpMZDIF7KDYGVdEbVYHEXTtAH1Tfwl2w0R6vuyvG3upW5qSbrBgcp1g+N/WWjE0nlenlaoiDdAWVUb74NKTmiff/pgzshzcINv81bVshYZsNHvp6zms0uzxktnLjndzgP7mr0fVFKAiEBVV8UFVolo8skJW8d2GMRU06GFO+RePqaS3kt/y1LXTcZb56mt3vl8R5jvxDAGccB8gOakFSkVuY15PheHES5tzqOTLsznpFQjJBu08yyvdbFR6v4BA0OZY5QAOutt0H654QW521UrItjJ9OeSSTj/s4t0D55eMF5JAkHPi0gDqImD2zJ5y9KFdQlnfBQ== dedi.laxis.it"

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root!" 1>&2
  exit 1
fi

apt-get update
#AVAILABLE_KERNELS="$(apt-cache search linux-generic-lts | awk '{print $1}' | sed -e 's/^linux-generic-lts-//' -e '/-/d' | tr '\n' ' ' | sed 's/[ ]*$//')"
#CHOSEN_KERNEL=""
#echo
#while [ "x$CHOSEN_KERNEL" = "x" ]; do
#  echo -n -e "\e[1F\e[2KUbuntu LTS Kernel stack (available: $AVAILABLE_KERNELS): "; read CHOSEN_KERNEL
#done
#apt-get -y install linux-generic-lts-$CHOSEN_KERNEL
AVAILABLE_STACKS="$(apt-cache search linux-generic-lts | awk '{print $1}' | sed -e 's/^linux-generic-lts-//' -e '/-/d' | tr '\n' ' ' | sed 's/[ ]*$//')"
AVAILABLE_STACKS=($AVAILABLE_STACKS)
for STACK in ${AVAILABLE_STACKS[@]}; do
  STACK_VERSION="$(apt-cache show linux-generic-lts-$STACK | grep "Version: " | awk '{print $2}' | tr '\n' ' ' | sed 's/[ ]*$//')"
  echo -e "$STACK\t$STACK_VERSION"
done
echo -n "Which stack do you want to install? [stack/N] "; INPUT=""; read INPUT
case $INPUT in "") echo "Skipping...";; *) apt-get -y install linux-generic-lts-$INPUT;; esac

echo "Setting up locale and timezone..."
rm /etc/localtime; ln -s /usr/share/zoneinfo/CET /etc/localtime
locale-gen en_US.UTF-8; update-locale LANG=en_US.UTF-8

echo -n "Ready to edit /etc/hostname? [Y/n] "; YESNO=""; read YESNO
case $YESNO in ""|[Yy]) nano /etc/hostname;; esac

echo -n "Ready to edit /etc/network/interfaces? [Y/n] "; YESNO=""; read YESNO
case $YESNO in ""|[Yy]) nano /etc/network/interfaces;; esac

echo "Adding key \"$(echo "$PUBLIC_KEY" | cut -d" " -f3-)\" to root's authorized_keys..."
if [ ! -f "/root/.ssh/authorized_keys" ]; then
  mkdir -p /root/.ssh
  echo -n "" >/root/.ssh/authorized_keys
fi
echo "$PUBLIC_KEY" >> /root/.ssh/authorized_keys

echo -n "Ready to edit /etc/ssh/sshd_config? [Y/n] "; YESNO=""; read YESNO
case $YESNO in ""|[Yy]) nano /etc/ssh/sshd_config;; esac

echo; echo "Script done. Please reboot the machine."
