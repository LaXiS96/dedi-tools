#!/bin/bash
PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAukJrHxfSXSy1RgYWoS2tB2A/wR6VrQi6Q1AiXIXk4LbYqTvl5r7obIaYpKjimXWuwfY5WNsTPpEUn6jdxSnyOm5US6FBsfFfoTmFSswucgJ/JJSBabQK6xXLHgo5ov41Mp5BfG3BdqbqK4d6IRx8Dsp0gnU9Rg5oaVM/vCJFdg4PPXhjEoQOjJhj40tZkPBLO72A3Siw3mOoDUh1FNvz2YgDNI/i6lTSHDuRlrb0Ye0pl4avF72YUoHecfVYc/Opkc3SS/6Zau8tdPyIRJuJ50tEl+8nOmrv0IQgFyV5BWv7OXNiWdbq+4WfgspVRgNbvWuXng+KSJX3l5iTPFkNZw== ServDiscount"
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

mkdir /storage
echo -e "\nUUID=1d7b8ae6-f2bc-4491-a523-8d062c53c115 /storage        ext4    defaults        0       2" >> /etc/fstab
mount /storage

#echo; echo -n "Do you want to setup LXC for root-unprivileged containers? [Y/n] "; YESNO=""; $READ YESNO
#case $YESNO in ""|[Yy]) YESNO="y";; esac
#if [ "$YESNO" = "y" ]; then
  apt-get -y install lxc
  echo "Configuring LXC..."
  usermod --add-subuids 100000-165535 root
  usermod --add-subgids 100000-165535 root
  echo "lxc.id_map = u 0 100000 65536" >> /etc/lxc/default.conf
  echo "lxc.id_map = g 0 100000 65536" >> /etc/lxc/default.conf
  echo "lxc.start.auto = 1" >> /etc/lxc/default.conf
  echo "lxc.start.delay = 5" >> /etc/lxc/default.conf
  echo "lxc.mount.entry = /storage/lxc/share share none bind,create=dir 0 0" >> /etc/lxc/default.conf
  mkdir -p -m 0777 /storage/lxc/share
  
  mv /etc/default/lxc-net /etc/default/lxc-net.bk
  echo -e "USE_LXC_BRIDGE=\"false\"" > /etc/default/lxc-net

  echo -ne "\nauto lxcbr0\niface lxcbr0 inet static\n\tbridge_ports none\n\tbridge_fd 0\n\tbridge_maxwait 0\n\tbridge_stop on\n" >> /etc/network/interfaces
  echo -ne "\thwaddress de:ad:ed:ff:ff:01\n\taddress 10.0.1.254\n\tnetmask 255.255.255.0\n" >> /etc/network/interfaces
  
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
#fi

#echo; echo -n "Do you want to setup libvirt for KVM? [Y/n] "; YESNO=""; $READ YESNO
#case $YESNO in ""|[Yy]) YESNO="y";; esac
#if [ "$YESNO" = "y" ]; then
  apt-get -y install qemu-kvm libvirt-bin virtinst
  mkdir -p /storage/kvm/{pools/main,isos}
  virsh pool-define-as main dir --target /storage/kvm/pools/main
  virsh pool-autostart main && virsh pool-start main
  
  cat > /etc/libvirt/qemu/networks/kvmbr0.xml << EOT
<network>
  <name>kvmbr0</name>
  <forward mode="bridge"/>
  <bridge name="kvmbr0"/>
</network>
EOT
  virsh net-define /etc/libvirt/qemu/networks/kvmbr0.xml
  virsh net-autostart kvmbr0
  
  echo -ne "\nauto kvmbr0\niface kvmbr0 inet static\n\tbridge_ports none\n\tbridge_fd 0\n\tbridge_maxwait 0\n\tbridge_stop on\n" >> /etc/network/interfaces
  echo -ne "\thwaddress de:ad:ed:ff:ff:02\n\taddress 10.0.2.254\n\tnetmask 255.255.255.0\n" >> /etc/network/interfaces
  
  echo "-- libvirt for KVM is configured."
#fi

#echo; echo -n "Setup iptables and edit rules? [Y/n] "; YESNO=""; $READ YESNO
#case $YESNO in ""|[Yy]) YESNO="y";; esac
#if [ "$YESNO" = "y" ]; then
  sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
  cat > /etc/iptables.rules << EOT
*filter
-P INPUT ACCEPT
-P FORWARD ACCEPT
-P OUTPUT ACCEPT

-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A INPUT --destination 255.255.255.255 -j DROP

-A INPUT -m state --state NEW -p icmp --icmp-type echo-request -j ACCEPT
-A INPUT -m state --state NEW -p tcp --dport 22 -j ACCEPT

-A INPUT -j LOG --log-prefix "[iptables] " --log-level warning
-P INPUT DROP
COMMIT
*nat
-A POSTROUTING --source 10.0.1.0/24 ! --destination 10.0.1.0/24 -j MASQUERADE
-A POSTROUTING --source 10.0.2.0/24 ! --destination 10.0.2.0/24 -j MASQUERADE
COMMIT
EOT
  nano /etc/iptables.rules
  echo -n "Please add \"up iptables-restore < /etc/iptables.rules\" to your main interface [press any key] "; $READ
  nano /etc/network/interfaces
  echo "-- iptables is configured."
#fi

echo; echo "Script done. Please reboot the machine."
