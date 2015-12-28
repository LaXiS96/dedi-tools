#!/bin/bash
PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAyTUJfAeSIe3vPrpMZDIF7KDYGVdEbVYHEXTtAH1Tfwl2w0R6vuyvG3upW5qSbrBgcp1g+N/WWjE0nlenlaoiDdAWVUb74NKTmiff/pgzshzcINv81bVshYZsNHvp6zms0uzxktnLjndzgP7mr0fVFKAiEBVV8UFVolo8skJW8d2GMRU06GFO+RePqaS3kt/y1LXTcZb56mt3vl8R5jvxDAGccB8gOakFSkVuY15PheHES5tzqOTLsznpFQjJBu08yyvdbFR6v4BA0OZY5QAOutt0H654QW521UrItjJ9OeSSTj/s4t0D55eMF5JAkHPi0gDqImD2zJ5y9KFdQlnfBQ== dedi.laxis.it"
READ="read -e"

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root!" 1>&2
  exit 1
fi

echo "REMARK: Reply to questions by pressing Enter to use the default [UPPERCASE] option."

echo -n "Skip apt-get update? [y/N] "; YESNO=""; $READ YESNO
case $YESNO in ""|[Nn]) apt-get update;; esac

echo -n "Skip apt-get upgrade? [y/N] "; YESNO=""; $READ YESNO
case $YESNO in ""|[Nn]) apt-get upgrade;; esac

echo; echo "Available LTS kernel stacks:"
AVAILABLE_STACKS="$(apt-cache search linux-generic-lts | awk '{print $1}' | sed -e 's/^linux-generic-lts-//' -e '/-/d' | tr '\n' ' ' | sed 's/[ ]*$//')"
AVAILABLE_STACKS=($AVAILABLE_STACKS)
for STACK in ${AVAILABLE_STACKS[@]}; do
  STACK_VERSION="$(apt-cache show linux-generic-lts-$STACK | grep "Version: " | awk '{print $2}' | tr '\n' ' ' | sed 's/[ ]*$//')"
  echo -e "$STACK\t$STACK_VERSION"
done
echo -n "Which stack do you want to install? [stack/N] "; INPUT=""; $READ INPUT
case $INPUT in ""|[Nn]) echo "Skipping kernel upgrade...";; *) apt-get -y install linux-generic-lts-$INPUT;; esac

echo; echo "Setting up locale and timezone..."
rm /etc/localtime; ln -s /usr/share/zoneinfo/CET /etc/localtime
locale-gen en_US.UTF-8; update-locale LANG=en_US.UTF-8

echo -n "Edit /etc/hostname? [Y/n] "; YESNO=""; $READ YESNO
case $YESNO in ""|[Yy]) nano /etc/hostname;; esac

echo -n "Edit /etc/hosts? [Y/n] "; YESNO=""; $READ YESNO
case $YESNO in ""|[Yy]) nano /etc/hosts;; esac

echo -n "Setup static IPv6? [Y/n] "; YESNO=""; $READ YESNO
case $YESNO in ""|[Yy]) YESNO="y";; esac
if [ "$YESNO" = "y" ]; then
  echo -n "Main interface (e.g. eth0, em1): "; IFACE=""; $READ IFACE
  OUT="\niface $IFACE inet6 static\n"
  echo -n "IPv6 address (no /prefix, short form allowed): "; ADDR=""; $READ ADDR
  OUT="$OUT\taddress $ADDR\n"
  echo -n "Network prefix (only numbers): "; PREFIX=""; $READ PREFIX
  OUT="$OUT\tnetmask $PREFIX\n"
  echo -n "Gateway (no /prefix, short form allowed): "; GATEWAY=""; $READ GATEWAY
  OUT="$OUT\tup ip -6 route add $GATEWAY dev $IFACE\n"
  OUT="$OUT\tup ip -6 route add default via $GATEWAY dev $IFACE\n"
  cat /etc/network/interfaces > /etc/network/interfaces.bk
  cat /etc/network/interfaces > /etc/network/interfaces.tmp
  echo -n -e "$OUT" >> /etc/network/interfaces.tmp
  echo; echo "A backup of your current /etc/network/interfaces was saved as /etc/network/interfaces.bk"
  echo -n "Please check /etc/network/interfaces and edit to your liking [press any key] "; $READ
  nano /etc/network/interfaces.tmp
  echo -n "Should I apply your changes (they are currently in /etc/network/interfaces.tmp)? [Y/n] "; YESNO=""; $READ YESNO
  case $YESNO in ""|[Yy]) rm -f /etc/network/interfaces; mv /etc/network/interfaces.tmp /etc/network/interfaces;; esac
else
  echo -n "Edit /etc/network/interfaces? [Y/n] "; YESNO=""; $READ YESNO
  case $YESNO in ""|[Yy]) nano /etc/network/interfaces;; esac
fi

echo; echo "Adding key \"$(echo "$PUBLIC_KEY" | cut -d" " -f3-)\" to root's authorized_keys..."
if [ ! -f "/root/.ssh/authorized_keys" ]; then
  mkdir -p /root/.ssh
  echo -n "" >/root/.ssh/authorized_keys
fi
echo "$PUBLIC_KEY" >> /root/.ssh/authorized_keys

echo -n "Edit /etc/ssh/sshd_config? [Y/n] "; YESNO=""; $READ YESNO
case $YESNO in ""|[Yy]) nano /etc/ssh/sshd_config;; esac

echo; echo -n "Do you want to setup LXC for root-unprivileged containers? [Y/n] "; YESNO=""; $READ YESNO
case $YESNO in ""|[Yy]) YESNO="y";; esac
if [ "$YESNO" = "y" ]; then
  apt-get -y install lxc
  echo "Setting LXC defaults..."
  usermod --add-subuids 100000-165535 root
  usermod --add-subgids 100000-165535 root
  echo "lxc.id_map = u 0 100000 65536" >> /etc/lxc/default.conf
  echo "lxc.id_map = g 0 100000 65536" >> /etc/lxc/default.conf
  echo "lxc.start.auto = 1" >> /etc/lxc/default.conf
  echo "lxc.start.delay = 5" >> /etc/lxc/default.conf
  echo "lxc.mount.entry = /storage/lxc/share share none bind,create=dir 0 0" >> /etc/lxc/default.conf
  mkdir -p -m 0777 /storage/lxc/share
  
  mkdir -p /storage/lxc/lib
  chmod 0711 /storage/lxc/lib
  rmdir /var/lib/lxc &&
  ln -s /storage/lxc/lib /var/lib/lxc
  
  #echo -n "Alternative path for /var/lib/lxc [path/N]: "; INPUT=""; $READ INPUT
  #case $INPUT in
  #  ""|[Nn])
  #    echo "Using default /var/lib/lxc for container storage..."
  #    chmod 0711 /var/lib/lxc
  #    ;;
  #  *)
  #    if [ -d "$INPUT" ]; then
  #      echo "Directory $INPUT exists..."
  #    else
  #      echo "Directory $INPUT does not exist. Creating it..."
  #      mkdir -p "$INPUT"
  #    fi
  #    chmod 0711 "$INPUT"
  #    rmdir /var/lib/lxc &&
  #    ln -s "$INPUT" /var/lib/lxc &&
  #    echo "/var/lib/lxc was symlinked to $INPUT..."
  #    ;;
  #esac
  
  apt-get -y install git
  git clone https://github.com/LaXiS96/virt-tools.git /root/virt-tools
  #chmod +x /root/lxc-tools/*.sh
  
  echo "-- LXC is configured."
fi

echo; echo -n "Do you want to setup libvirt for KVM? [Y/n] "; YESNO=""; $READ YESNO
case $YESNO in ""|[Yy]) YESNO="y";; esac
if [ "$YESNO" = "y" ]; then
  apt-get -y install qemu-kvm libvirt-bin virtinst
  mkdir -p /storage/kvm/{pools/main,isos}
  virsh net-autostart default && virsh net-start default
  virsh pool-define-as main dir --target /storage/kvm/pools/main
  virsh pool-autostart main && virsh pool-start main
  
  echo "-- libvirt for KVM is configured."
fi

echo; echo -n "Setup iptables and edit rules? [Y/n] "; YESNO=""; $READ YESNO
case $YESNO in ""|[Yy]) YESNO="y";; esac
if [ "$YESNO" = "y" ]; then
  cat > /etc/iptables.sh << EOT
#!/bin/bash
sleep 10
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

iptables -I INPUT 1 -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -I INPUT 2 --destination 10.155.7.255 -j DROP
iptables -I INPUT 3 --destination 255.255.255.255 -j DROP

iptables -I INPUT 4 -m state --state NEW -p icmp --icmp-type echo-request -j ACCEPT
iptables -I INPUT 5 -m state --state NEW -p tcp --dport 22 -j ACCEPT

iptables -I INPUT 6 -m state --state NEW --source 10.0.3.5 -j ACCEPT

iptables -A INPUT -j LOG --log-prefix "[iptables] " --log-level warning
iptables -P INPUT DROP

iptables -I FORWARD 2 -m state --state NEW --destination 192.168.122.0/24 -j ACCEPT

iptables -t nat -A PREROUTING -p udp --dport 1194 -j DNAT --to-destination 10.0.3.5:1194
EOT
  nano /etc/iptables.sh
  echo -n "Please add \"up bash /etc/iptables.sh\" to your main interface [press any key] "; $READ
  nano /etc/network/interfaces
  echo "-- iptables is configured."
fi

echo; echo "Script done. Please reboot the machine."
