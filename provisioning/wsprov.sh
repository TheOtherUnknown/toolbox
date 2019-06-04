#!/bin/bash
# Provision Ubuntu workstations (sort of anyway)
# MUST RUN AS ROOT

if [ $EUID -gt 0 ]; then
  echo 'This script must be run as root!'
  exit 1
fi
echo 'Enter a hostname for this machine: '
read hostn
sed -i "s/$(hostnamectl --static)/$hostn.csg.ius.edu/" /etc/hosts # Correct the FQDN in /etc/hosts 
hostnamectl set-hostname $hostn.csg.ius.edu
# Don't prompt during install, use debconf
export DEBIAN_FRONTEND="noninteractive"
debconf-set-selections <<< "krb5-config krb5-config/default_realm string AD.CSG.IUS.EDU"
debconf-set-selections <<< "krb5-config krb5-config/kerberos_servers string ad.csg.ius.edu"
add-apt-repository universe
apt-get update -qq
apt-get install ufw adcli realmd krb5-user samba-common-bin samba-libs samba-dsdb-modules sssd sssd-tools libnss-sss libpam-sss unattended-upgrades ansible -y
# Automatic updates
cat << EOF > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF
cat << EOF >> /etc/apt/apt.conf.d/50unattended-upgrades
Unattended-Upgrade::Origins-Pattern {
        "o=${distro_id}*";
        "a=*-security";
};
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-WithUsers "true";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
EOF
# AD config
smbc='
   # Start CSG config
   workgroup = CSG
   client signing = yes
   client use spnego = yes
   kerberos method = secrets and keytab
   realm = AD.CSG.IUS.EDU
   security = ads
   # End CSG config
'
sed -i '/workgroup/d' /etc/samba/smb.conf # Remove default workgroup line
gawk -i inplace -v x="$smbc" '{print} /\[global\]/{print x}'  /etc/samba/smb.conf # https://stackoverflow.com/questions/47582028
cat << EOF > /etc/sssd/sssd.conf
# Config file for SSSD to allow for auth via AD
[nss]
filter_groups = root
filter_users = root
reconnection_retries = 3
[pam]
reconnection_retries = 3
[sssd]
domains = ad.csg.ius.edu
config_file_version = 2
services = nss, pam
default_domain_suffix = AD.CSG.IUS.EDU
full_name_format = %1$s
[domain/ad.csg.ius.edu]
ad_domain = ad.csg.ius.edu
krb5_realm = AD.CSG.IUS.EDU
realmd_tags = manages-system joined-with-samba
cache_credentials = True
id_provider = ad
krb5_store_password_if_offline = True
default_shell = /bin/bash
ldap_id_mapping = True
use_fully_qualified_names = True
fallback_homedir = /home/%d/%u
access_provider = ad
auth_provider = ad
chpass_provider = ad
access_provider = ad
ldap_schema = ad
dyndns_update = true
dyndns_refresh_interval = 43200
dyndns_update_ptr = true
dyndns_ttl = 3600
EOF
chmod 700 /etc/sssd/sssd.conf
ufw enable # Turn on the firewall
nmcli connection modify 'Wired connection 1' ipv4.dns-search 'csg.ius.edu'
systemctl restart NetworkManager
# Configure sudo for AD
echo '%CSG\\ws\ admins ALL=(ALL:ALL) ALL' >> /etc/sudoers # Allows members of the ws admins group to sudo on workstations
echo 'Defaults insults' >> /etc/sudoers # :D
echo 'Defaults lecture_file = /etc/sudoers.lecture' >> /etc/sudoers
cat << EOF > /etc/sudoers.lecture
Well, this is it. The last line of defense against malicious activity. 
As a superuser, please remember the following:
1). Respect the privacy of others. (Would you like it if we went through your home directory?)
2). Passwords NEVER go in cleartext. (Don't try to change the password of a domain user using passwd either.)
3). Use common sense. (Trust, but verify.)
4). Don't just copy-paste. (rm -rf /)
If you have any further questions, contact whoever gave you superuser rights. 
EOF
# Restart stuff
systemctl restart smbd sssd realmd
systemctl enable smbd sssd realmd
# Hide users on login screen
mkdir -p /etc/lightdm/lightdm.conf.d
cat << EOF > /etc/lightdm/lightdm.conf.d/50-hide-users.conf
[Seat:*]
greeter-hide-users=true
greeter-show-manual-login=true
EOF
export DEBIAN_FRONTEND="dialog"
echo 'Enter the username for an AD user with permissions to join the domain:'
read adadmin
kinit "$adadmin"
realm discover -v AD.CSG.IUS.EDU
realm join AD.CSG.IUS.EDU -U "$adadmin" -v
net ads join -k
pam-auth-update
