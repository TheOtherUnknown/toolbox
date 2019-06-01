#!/bin/bash
# Provision Debian 9 servers (sort of anyway)
# MUST RUN AS ROOT

if [[ $EUID > 0 ]]; then
  echo 'This script must be run as root!'
  exit 1
fi
echo 'This script does not set the FQDN! If it is not correct, please stop the script and correct it NOW.'
sleep 5
# Don't prompt during install, use debconf
export DEBIAN_FRONTEND="noninteractive"
debconf-set-selections <<< "krb5-config krb5-config/default_realm string AD.CSG.IUS.EDU"
debconf-set-selections <<< "krb5-config krb5-config/kerberos_servers string ad.csg.ius.edu"
# Add backports repo
echo 'deb http://deb.debian.org/debian stretch-backports main' > /etc/apt/sources.list.d/stretch-backports.list
apt-get update -qq
apt-get install adcli realmd krb5-user samba-common-bin samba-libs samba-dsdb-modules sssd sssd-tools libnss-sss libpam-sss unattended-upgrades -y
apt-get -t stretch-backports install ansible -y
# Automatic updates
cat << EOF > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF
cat << EOF >> /etc/apt/apt.conf.d/50unattended-upgrades
Unattended-Upgrade::Origins-Pattern {
        "a=*-security";
};
Unattended-Upgrade::Automatic-Reboot "false";
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
if [ -x "$(command -v nmcli)" ]; then
  nmcli connection modify 'Wired connection 1' ipv4.dns "192.168.1.140,192.168.1.139,1.1.1.1" 
  nmcli connection modify 'Wired connection 1' ipv4.dns-search 'csg.ius.edu'
  systemctl restart NetworkManager
else
  echo 'Unable to configure DNS servers with nmcli, assuming current DNS servers are correct'
  sleep 5
fi
# Configure sudo for AD
echo '%CSG\\server\ admins ALL=(ALL:ALL) ALL' >> /etc/sudoers # Allows members of the server admins group to sudo on servers
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
echo -n 'Join the domain now? [Y/n]: '
read adstart
adstart=${adstart:-y}
if [ "$adstart" = "y" ] || [ "$adstart" = "Y" ] ; then
  systemctl restart smbd sssd realmd
  systemctl enable smbd sssd realmd
  export DEBIAN_FRONTEND="dialog"
  echo -n 'Enter the username for an AD user with permissions to join the domain: '
  read adadmin
  kinit $adadmin
  realm discover -v AD.CSG.IUS.EDU
  realm join AD.CSG.IUS.EDU -U $adadmin -v
  net ads join -k
  pam-auth-update
fi
