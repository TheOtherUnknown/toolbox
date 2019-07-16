#!/bin/bash
set -eu # One fails, it all fails
vzdump --all --mode snapshot --dumpdir /mnt # Mount backup beforehand
apt update
apt upgrade -y
pve5to6
systemctl stop pve-ha-lrm
echo "Stopped LRM on this machine. Press a key once the LRM has been stopped on all machines in the cluster."
read -n 1 -s # Stage 2
systemctl stop pve-ha-crm
echo "deb http://download.proxmox.com/debian/corosync-3/ stretch main" > /etc/apt/sources.list.d/corosync3.list
apt update
apt dist-upgrade --download-only -y
apt dist-upgrade
echo "Corosync is up to date. Press a key once all other machines in the cluster are up to date as well."
read -n 1 -s # Stage 3
systemctl start pve-ha-lrm
systemctl start pve-ha-crm
rm /etc/apt/sources.list.d/corosync3.list
sed -i 's/stretch/buster/g' /etc/apt/sources.list
for file in /etc/apt/sources.list.d/*; do sed -i 's/stretch/buster/g' $file; done
apt update
apt dist-upgrade -y
echo "Update complete. Scheduling restart..."
pvecm status
shutdown -r 5min
