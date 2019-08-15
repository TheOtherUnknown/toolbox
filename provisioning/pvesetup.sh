#!/bin/bash
if [ $EUID -gt 0 ]; then
  echo 'This script must be run as root!'
  exit 1
fi
rm /etc/apt/sources.list.d/pve-enterprise.list
echo 'deb http://download.proxmox.com/debian/pve buster pve-no-subscription' >> /etc/apt/sources.list
apt update -qq
apt -y install freeipa-client sudo 
freeipa-client-install
lsblk
mkdir /media/vmstore0
echo -n 'Enter path of disk for vmstore0: '
read mpath
mount $mpath /media/vmstore0
echo "$mpath         /media/vmstore0       ext4          noatime          0      2" >> /etc/fstab
