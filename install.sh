#!/bin/bash
PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAyTUJfAeSIe3vPrpMZDIF7KDYGVdEbVYHEXTtAH1Tfwl2w0R6vuyvG3upW5qSbrBgcp1g+N/WWjE0nlenlaoiDdAWVUb74NKTmiff/pgzshzcINv81bVshYZsNHvp6zms0uzxktnLjndzgP7mr0fVFKAiEBVV8UFVolo8skJW8d2GMRU06GFO+RePqaS3kt/y1LXTcZb56mt3vl8R5jvxDAGccB8gOakFSkVuY15PheHES5tzqOTLsznpFQjJBu08yyvdbFR6v4BA0OZY5QAOutt0H654QW521UrItjJ9OeSSTj/s4t0D55eMF5JAkHPi0gDqImD2zJ5y9KFdQlnfBQ== dedi.laxis.it"
alias read="read -e"

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root!" 1>&2
  exit 1
fi

apt-get update
echo; echo "Available LTS kernel stacks:"
AVAILABLE_STACKS="$(apt-cache search linux-generic-lts | awk '{print $1}' | sed -e 's/^linux-generic-lts-//' -e '/-/d' | tr '\n' ' ' | sed 's/[ ]*$//')"
AVAILABLE_STACKS=($AVAILABLE_STACKS)
for STACK in ${AVAILABLE_STACKS[@]}; do
  STACK_VERSION="$(apt-cache show linux-generic-lts-$STACK | grep "Version: " | awk '{print $2}' | tr '\n' ' ' | sed 's/[ ]*$//')"
  echo -e "$STACK\t$STACK_VERSION"
done
echo -n "Which stack do you want to install? [stack/N] "; INPUT=""; read INPUT
case $INPUT in ""|[Nn]) echo "Skipping...";; *) apt-get -y install linux-generic-lts-$INPUT;; esac

echo "Setting up locale and timezone..."
rm /etc/localtime; ln -s /usr/share/zoneinfo/CET /etc/localtime
locale-gen en_US.UTF-8; update-locale LANG=en_US.UTF-8

echo -n "Edit /etc/hostname? [Y/n] "; YESNO=""; read YESNO
case $YESNO in ""|[Yy]) nano /etc/hostname;; esac

echo -n "Edit /etc/hosts? [Y/n] "; YESNO=""; read YESNO
case $YESNO in ""|[Yy]) nano /etc/hosts;; esac

echo -n "Setup static IPv6? [Y/n] "; YESNO=""; read YESNO
case $YESNO in ""|[Yy]) YESNO="y";; esac
if [ "$YESNO" = "y" ]; then
  echo -n "Main interface (e.g. eth0, em1): "; IFACE=""; read IFACE
  OUT="iface $IFACE inet6 static\n"
  echo -n "IPv6 address (no /prefix, short form allowed): "; ADDR=""; read ADDR
  OUT="$OUT\taddress $ADDR\n"
  echo -n "Network prefix (only numbers): "; PREFIX=""; read PREFIX
  OUT="$OUT\tnetmask $PREFIX\n"
  echo -n "Gateway (no /prefix, short form allowed): "; GATEWAY=""; read GATEWAY
  OUT="$OUT\tup ip -6 route add $GATEWAY dev $IFNAME\n"
  OUT="$OUT\tup ip -6 route add default via $GATEWAY dev $IFNAME\n"
  cat /etc/network/interfaces > /etc/network/interfaces.bk
  cat /etc/network/interfaces > /etc/network/interfaces.tmp
  echo "$OUT" >> /etc/network/interfaces.tmp
  echo "A backup of your current /etc/network/interfaces was saved as /etc/network/interfaces.bk"
  echo -n "Please check /etc/network/interfaces and edit to your liking [press any key] "; read
  nano /etc/network/interfaces.tmp
  echo -n "Should I apply your changes (they are currently in /etc/network/interfaces.tmp)? [Y/n] "; YESNO=""; read YESNO
  case $YESNO in ""|[Yy]) rm -f /etc/network/interfaces; mv /etc/network/interfaces.tmp /etc/network/interfaces;; esac
else
  echo -n "Edit /etc/network/interfaces? [Y/n] "; YESNO=""; read YESNO
  case $YESNO in ""|[Yy]) nano /etc/network/interfaces;; esac
fi

echo "Adding key \"$(echo "$PUBLIC_KEY" | cut -d" " -f3-)\" to root's authorized_keys..."
if [ ! -f "/root/.ssh/authorized_keys" ]; then
  mkdir -p /root/.ssh
  echo -n "" >/root/.ssh/authorized_keys
fi
echo "$PUBLIC_KEY" >> /root/.ssh/authorized_keys

echo -n "Edit /etc/ssh/sshd_config? [Y/n] "; YESNO=""; read YESNO
case $YESNO in ""|[Yy]) nano /etc/ssh/sshd_config;; esac

echo -n "Do you want to setup LXC for root-unprivileged containers? [Y/n] "; YESNO=""; read YESNO
case $YESNO in ""|[Yy]) YESNO="y";; esac
if [ "$YESNO" = "y" ]; then
  apt-get -y install lxc
  usermod --add-subuids 100000-165535 root
  usermod --add-subgids 100000-165535 root
  echo "lxc.id_map = u 0 100000 65536" >> /etc/lxc/default.conf
  echo "lxc.id_map = g 0 100000 65536" >> /etc/lxc/default.conf
  echo "lxc.start.auto = 1" >> /etc/lxc/default.conf
  echo "lxc.start.delay = 5" >> /etc/lxc/default.conf
  echo "lxc.mount.entry = /share share none bind,create=dir 0 0" >> /etc/lxc/default.conf
  chmod +x /var/lib/lxc
  mkdir -m 0777 /share
  echo "LXC was setup successfully."
fi

echo -n "Setup iptables and edit /etc/iptables.rules? [Y/n] "; YESNO=""; read YESNO
case $YESNO in ""|[Yy]) YESNO="y";; esac
if [ "$YESNO" = "y" ]; then
  cat > /etc/iptables.rules <<EOT
*filter
-P INPUT ACCEPT
-P OUTPUT ACCEPT
-P FORWARD ACCEPT
-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A INPUT -p tcp -m state --state NEW --dport 22 -j ACCEPT
-A INPUT -p icmp -m state --state NEW --icmp-type echo-request -j ACCEPT
-P INPUT DROP
COMMIT
EOT
  nano /etc/iptables.rules
  echo -n "Please add \"pre-up iptables-restore < /etc/iptables.rules\" to your main interface [press any key] "; read
  nano /etc/network/interfaces
  echo "Iptables is configured."
fi

echo; echo "Script done. Please reboot the machine."
