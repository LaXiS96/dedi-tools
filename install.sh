#!/bin/bash
PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAyTUJfAeSIe3vPrpMZDIF7KDYGVdEbVYHEXTtAH1Tfwl2w0R6vuyvG3upW5qSbrBgcp1g+N/WWjE0nlenlaoiDdAWVUb74NKTmiff/pgzshzcINv81bVshYZsNHvp6zms0uzxktnLjndzgP7mr0fVFKAiEBVV8UFVolo8skJW8d2GMRU06GFO+RePqaS3kt/y1LXTcZb56mt3vl8R5jvxDAGccB8gOakFSkVuY15PheHES5tzqOTLsznpFQjJBu08yyvdbFR6v4BA0OZY5QAOutt0H654QW521UrItjJ9OeSSTj/s4t0D55eMF5JAkHPi0gDqImD2zJ5y9KFdQlnfBQ== dedi.laxis.it"

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root!" 1>&2
  exit 1
fi

apt-get update
AVAILABLE_KERNELS="$(apt-cache search linux-generic-lts | awk '{print $1}' | sed -e 's/^linux-generic-lts-//' -e '/-/d' | tr '\n' ' ' | sed 's/[ ]*$//')"
CHOSEN_KERNEL=""
echo
while [ "x$CHOSEN_KERNEL" = "x" ]; do
  echo -n -e "\e[1F\e[2KUbuntu LTS Kernel stack (available: $AVAILABLE_KERNELS): "; read CHOSEN_KERNEL
done
apt-get -y install linux-generic-lts-$CHOSEN_KERNEL

rm /etc/localtime; ln -s /usr/share/zoneinfo/CET /etc/localtime
locale-gen en_US.UTF-8; update-locale LANG=en_US.UTF-8

