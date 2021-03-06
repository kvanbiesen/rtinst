#!/bin/bash

######################################################################
#
#  Copyright (c) 2015 arakasi72 (https://github.com/arakasi72)
#
#  --> Licensed under the MIT license: http://www.opensource.org/licenses/mit-license.php
#
######################################################################
#Script Console Colors
black=$(tput setaf 0); red=$(tput setaf 1); green=$(tput setaf 2); yellow=$(tput setaf 3);
blue=$(tput setaf 4); magenta=$(tput setaf 5); cyan=$(tput setaf 6); white=$(tput setaf 7);
on_red=$(tput setab 1); on_green=$(tput setab 2); on_yellow=$(tput setab 3); on_blue=$(tput setab 4);
on_magenta=$(tput setab 5); on_cyan=$(tput setab 6); on_white=$(tput setab 7); bold=$(tput bold);
dim=$(tput dim); underline=$(tput smul); reset_underline=$(tput rmul); standout=$(tput smso);
reset_standout=$(tput rmso); normal=$(tput sgr0); alert=${white}${on_red}; title=${standout};

PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/bin:/sbin

rtorrentrel='0.9.6'
libtorrentrel='0.13.6'
rtorrentloc='http://rtorrent.net/downloads/rtorrent-'$rtorrentrel'.tar.gz'
libtorrentloc='http://rtorrent.net/downloads/libtorrent-'$libtorrentrel'.tar.gz'
xmlrpcloc='https://svn.code.sf.net/p/xmlrpc-c/code/stable'

blob=master
rtdir=https://raw.githubusercontent.com/kvanbiesen/rtinst/$blob/scripts

if [ $(dpkg-query -W -f='${Status}' lsb-release 2>/dev/null | grep -c "ok installed") -gt 0 ]; then
  fullrel=$(lsb_release -sd)
  osname=$(lsb_release -si)
  relno=$(lsb_release -sr | cut -d. -f1)
else
  fullrel=$(cat /etc/issue.net)
  osname=$(cat /etc/issue.net | cut -d' ' -f1)
  relno=$(cat /etc/issue.net | tr -d -c 0-9. | cut -d. -f1)
fi

if [ "$relno" = "16" ]; then
  phpver=php7.0
  phploc=/etc/php/7.0
else
  phpver=php5
  phploc=/etc/php5
fi

serverip=$(ip route get 8.8.8.8 | awk 'NR==1 {print $NF}')
webpass=''
cronline1="@reboot sleep 10; /usr/local/bin/rtcheck irssi rtorrent"
cronline2="*/10 * * * * /usr/local/bin/rtcheck irssi rtorrent"
dlflag=1
portdefault=1
logfile="/dev/null"
gotip=0
install_rt=0
sshport=''
rudevflag=1
passfile='/etc/nginx/.htpasswd'
package_list="openssl sudo nano autoconf build-essential ca-certificates comerr-dev curl cfv dtach htop irssi libcloog-ppl-dev libcppunit-dev libcurl3 libncurses5-dev libterm-readline-gnu-perl libsigc++-2.0-dev libperl-dev libtool libxml2-dev ncurses-base ncurses-term ntp patch pkg-config $phpver-fpm $phpver $phpver-cli $phpver-dev $phpver-curl $phpver-geoip $phpver-mcrypt $phpver-xmlrpc python-scgi screen subversion texinfo unzip zlib1g-dev libcurl4-openssl-dev mediainfo python-software-properties software-properties-common aptitude $phpver-json nginx-full apache2-utils git libarchive-zip-perl libnet-ssleay-perl libhtml-parser-perl libxml-libxml-perl libjson-perl libjson-xs-perl libxml-libxslt-perl libjson-rpc-perl libarchive-zip-perl"
Install_list=""


function _askquota() {
  echo -ne "${bold}${yellow}Do you wish to use user quotas?${normal} (Default: ${green}${bold}Y${normal}) "; read input
    case $input in
      [yY] | [yY][Ee][Ss] | "" ) quota="yes";echo "${bold}Quotas will be installed${normal}" ;;
      [nN] | [nN][Oo] ) quota="no";echo "${cyan}Quotas will not be installed${normal}" ;;
    *) quota="yes";echo "${bold}Quotas will be installed${normal}" ;;
    esac
}

# primary partition question
function _askpartition() {
  if [[ $quota == yes ]]; then
  echo
  echo "##################################################################################"
  echo "#${bold} By default the script will initiate a build using ${green}/${normal} ${bold}as the${normal}"
  echo "#${bold} primary partition for mounting quotas.${normal}"
  echo "#"
  echo "#${bold} Some providers, such as OVH and SYS force ${green}/home${normal} ${bold}as the primary mount ${normal}"
  echo "#${bold} on their server setups. So if you have an OVH or SYS server and have not"
  echo "#${bold} modified your partitions, it is safe to choose option ${yellow}2)${normal} ${bold}below.${normal}"
  echo "#"
  echo "#${bold} If you are not sure:${normal}"
  echo "#${bold} I have listed out your current partitions below. Your mountpoint will be"
  echo "#${bold} listed as ${green}/home${normal} ${bold}or ${green}/${normal}${bold}. ${normal}"
  echo "#"
  echo "#${bold} Typically, the partition with the most space assigned is your default.${normal}"
  echo "##################################################################################"
  echo
  lsblk
  echo
  echo -e "${bold}${yellow}1)${normal} / - ${green}root mount${normal}"
  echo -e "${bold}${yellow}2)${normal} /home - ${green}home mount${normal}"
  echo -ne "${bold}${yellow}What is your mount point for user quotas?${normal} (Default ${green}1${normal}): "; read version
  case $version in
    1 | "") primaryroot=root  ;;
    2) primaryroot=home  ;;
    *) primaryroot=root ;;
  esac
  echo "Using ${green}$primaryroot mount${normal} for quotas"
  echo
fi
}

# enable quota for disks
function _qmount() {
  # Setup mount points for Quotas
  if [[ $quota == yes ]]; then
    if [[ $DISTRO == Ubuntu ]]; then
      if [[ ${primaryroot} == "root" ]]; then
        sed -i 's/errors=remount-ro/usrjquota=aquota.user,jqfmt=vfsv1,errors=remount-ro/g' /etc/fstab
        apt-get install -y linux-image-extra-virtual quota >>"${OUTTO}" 2>&1
        mount -o remount / || mount -o remount /home >>"${OUTTO}" 2>&1
        quotacheck -auMF vfsv1 >>"${OUTTO}" 2>&1
        quotaon -uv / >>"${OUTTO}" 2>&1
        service quota start >>"${OUTTO}" 2>&1
      else
        sed -i 's/errors=remount-ro/usrjquota=aquota.user,jqfmt=vfsv1,errors=remount-ro/g' /etc/fstab
        apt-get install -y linux-image-extra-virtual quota >>"${OUTTO}" 2>&1
        mount -o remount /home >>"${OUTTO}" 2>&1
        quotacheck -auMF vfsv1 >>"${OUTTO}" 2>&1
        quotaon -uv /home >>"${OUTTO}" 2>&1
        service quota start >>"${OUTTO}" 2>&1
      fi
    elif [[ $DISTRO == Debian ]]; then
      if [[ ${primaryroot} == "root" ]]; then
        sed -i 's/errors=remount-ro/usrjquota=aquota.user,jqfmt=vfsv1,errors=remount-ro/g' /etc/fstab
        apt-get install -y quota >>"${OUTTO}" 2>&1
        mount -o remount / || mount -o remount /home >>"${OUTTO}" 2>&1
        quotacheck -auMF vfsv1 >>"${OUTTO}" 2>&1
        quotaon -uv / >>"${OUTTO}" 2>&1
        service quota start >>"${OUTTO}" 2>&1
      else
        sed -i 's/errors=remount-ro/usrjquota=aquota.user,jqfmt=vfsv1,errors=remount-ro/g' /etc/fstab
        apt-get install -y quota >>"${OUTTO}" 2>&1
        mount -o remount /home >>"${OUTTO}" 2>&1
        quotacheck -auMF vfsv1 >>"${OUTTO}" 2>&1
        quotaon -uv /home >>"${OUTTO}" 2>&1
        service quota start >>"${OUTTO}" 2>&1
      fi
    fi
	touch /install/.quota.lock
	
  fi
}

#exit on error function
error_exit() {
echo "Error: $1"
echo "This is most likely a network error, if your network is working, then it is likely a temporary issue with the relevant file server"
echo "Run 'bash rtinst.sh -l' for detailed output to rtinst.log"
echo "Once issue is resolved the script can be run again to complete installation"
if ! [ -z "$sshport" ]; then
  echo "SSH Port was set before script was stopped to $sshport"
  echo "make sure you can login before closing this session"
fi
exit 1
}

#function to generate random password
genpasswd() {
local genln=$1
[ -z "$genln" ] && genln=8
tr -dc A-Za-z0-9 < /dev/urandom | head -c ${genln} | xargs
}

#function to set a user input password
set_pass() {
exec 3>&1 >/dev/tty
local LOCALPASS=''
local exitvalue=0
echo "Enter a password (6+ chars)"
echo "or leave blank to generate a random one"

while [ -z $LOCALPASS ]
do
  echo "Please enter the new password:"
  read -s password1

#check that password is valid
  if [ -z $password1 ]; then
    echo "Random password generated, will be provided to user at end of script"
    exitvalue=1
    LOCALPASS=$(genpasswd) && break
  elif [ ${#password1} -lt 6 ]; then
    echo "password needs to be at least 6 chars long" && continue
  else
    echo "Enter the new password again:"
    read -s password2

# Check both passwords match
    if [ $password1 != $password2 ]; then
      echo "Passwords do not match"
    else
      LOCALPASS=$password1
    fi
  fi
done

exec >&3-
echo $LOCALPASS
return $exitvalue
}

#function to determine random number between 2 numbers
random()
{
    local min=$1
    local max=$2
    local RAND=`od -t uI -N 4 /dev/urandom | awk '{print $2}'`
    RAND=$((RAND%((($max-$min)+1))+$min))
    echo $RAND
}

# function to ask user for y/n response
ask_user(){
while true
  do
    read answer
    case $answer in [Yy]* ) return 0 ;;
                    [Nn]* ) return 1 ;;
                        * ) echo "Enter y or n";;
    esac
  done
}

enter_ip() {
echo "enter your server's name or IP address"
echo "e.g. example.com or 213.0.113.113"
read serverip
echo "Your Server IP/Name is $serverip"
echo -n "Is this correct y/n? "
ask_user
}

# determine system
if ([ "$osname" = "Ubuntu" ] && [ $relno -ge 12 ]) || ([ "$osname" = "Debian" ] && [ $relno -ge 7 ])  || ([ "$osname" = "Raspbian" ] && [ $relno -ge 7 ]); then
  echo $fullrel
else
 echo $fullrel
 echo "Only Ubuntu release 12 and later, and Debian and Raspbian release 7 and later, are supported"
 echo "Your system does not appear to be supported"
 exit
fi

# get options
while getopts ":dlt" optname
  do
    case $optname in
      "d" ) dlflag=0 ;;
      "l" ) logfile="$HOME/rtinst.log" ;;
      "t" ) portdefault=0 ;;
        * ) echo "incorrect option, only -d, and -l allowed" && exit 1 ;;
    esac
  done

shift $(( $OPTIND - 1 ))

# Check if there is more than 0 argument
if [ $# -gt 0 ]; then
  echo "No arguments allowed $1 is not a valid argument"
  exit 1
fi

#pop quota question
#_askquota
#_askpartition
#_qmount

# check IP Address
case $serverip in
    127* ) gotip=1 ;;
  local* ) gotip=1 ;;
      "" ) gotip=1 ;;
esac

if [ $gotip = 1 ]; then
  echo "Unable to determine your IP address"
  gotip=enter_ip
else
  echo "Your Server IP/Name is $serverip"
  echo -n "Is this correct y/n? "
  gotip=ask_user
fi

until $gotip
    do
      gotip=enter_ip
    done

echo "Your server's IP/Name is set to $serverip"

#check rtorrent installation
if which rtorrent; then
  echo "It appears that rtorrent has been installed."
  echo -n "Do you wish to skip rtorrent compilation? "
  if ask_user; then
    install_rt=1
    echo "rtorrent installation will be skipped."
  else
    skip_rt=0
    echo "rtorrent will be re-installed"
  fi
fi

# set and prepare user
if test "$SUDO_USER" = "root" || { test -z "$SUDO_USER" &&  test "$LOGNAME" = "root"; }; then
  echo "Enter the name of the user to install to"
  echo "This will be your primary user"
  echo "It can be an existing user or a new user"
  echo

  confirm_name=1
  while [ $confirm_name = 1 ]
    do
      read -p "Enter user name: " answer
      addname=$answer
      echo -n "Confirm that user name is $answer y/n? "
      if ask_user; then
        confirm_name=0
      fi
    done

  user=$addname

  if id -u $user >/dev/null 2>&1; then
    echo "$user already exists"
  else
    adduser --gecos "" $user
  fi

elif ! [ -z "$SUDO_USER" ]; then
  user=$SUDO_USER
else
  echo "Script must be run using sudo or root"
  exit 1
fi

home=$(eval echo "~$user")

#set password for rutorrent
echo "Set Password for RuTorrent web client"
webpass=$(set_pass)
PASSFLAG=$?
#Interaction ended message
echo
echo "No more user input required, you can complete unattended"
echo "It will take approx 10 minutes for the script to complete"
echo

#update amd upgrade system
if [ "$fullrel" = "Ubuntu 12.04.5 LTS" ]; then
  wget --no-check-certificate https://help.ubuntu.com/12.04/sample/sources.list >> $logfile 2>&1 || error_exit "Unable to download sources file from https://help.ubuntu.com/12.04/sample/sources.list"
  cp /etc/apt/sources.list /etc/apt/sources.list.bak
  mv sources.list /etc/apt/sources.list
fi

echo "Updating package lists" | tee $logfile
apt-get update 2>&1 >>$logfile | tee -a $logfile
if ! [ $? = 0 ]; then
  error_exit "Problem updating packages."
fi

echo "Upgrading packages" | tee -a $logfile
export DEBIAN_FRONTEND=noninteractive
apt-get -y upgrade  2>&1 >>$logfile | tee -a $logfile
if ! [ $? = 0 ]; then
  error_exit "Problem upgrading packages."
fi

apt-get clean && apt-get autoclean >> $logfile 2>&1

#install the packsges needed
echo "Installing required packages" | tee -a $logfile
for package_name in $package_list
  do
    if apt-cache show $package_name >/dev/null 2>&1 ; then
      if [ $(dpkg-query -W -f='${Status}' $package_name 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        install_list="$install_list $package_name"
      fi
    else
      echo $package_name" not found, skipping"
    fi
  done

test -z "$install_list" || apt-get -y install $install_list  2>&1 >>$logfile | tee -a $logfile

#install unrar package
if [ $osname = "Debian" ]; then
  cd $home
  if [ "$(uname -m)" = "x86_64" ]; then
    curl -s http://www.rarlab.com/rar/rarlinux-x64-5.3.0.tar.gz | tar xz
  elif [ "$(uname -m)" = "x86_32" ]; then
    curl -s http://www.rarlab.com/rar/rarlinux-5.3.0.tar.gz | tar xz
  fi
  cp $home/rar/rar /bin/rar
  cp $home/rar/unrar /bin/unrar
  rm -r $home/rar
elif [ $osname = "Ubuntu" ]; then
  apt-get -y install unrar  >> $logfile 2>&1
fi

#install ffmpeg
if ! [ $osname = "Raspbian" ] && [ $(dpkg-query -W -f='${Status}' "ffmpeg" 2>/dev/null | grep -c "ok installed") = 0 ]; then
  echo "Installing ffmpeg"
  if [ $relno = 14 ]; then
    apt-add-repository -y ppa:mc3man/trusty-media >> $logfile 2>&1 || error_exit "Problem adding to repository from - https://launchpad.net/~mc3man/+archive/ubuntu/ppa"
    apt-get update >> $logfile 2>&1 || error_exit "problem updating package lists"
    apt-get -y install ffmpeg >> $logfile 2>&1
  elif [ $relno = 8 ]; then
    grep "deb http://www.deb-multimedia.org jessie main" /etc/apt/sources.list >> /dev/null || echo "deb http://www.deb-multimedia.org jessie main" >> /etc/apt/sources.list
    apt-get update >> $logfile 2>&1 || error_exit "problem updating package lists"
    apt-get -y --force-yes install deb-multimedia-keyring >> $logfile 2>&1
    apt-get -y --force-yes install ffmpeg >> $logfile 2>&1
  else
    apt-get -y install ffmpeg >> $logfile 2>&1
  fi
fi

echo "Completed installation of required packages        "

#add user to sudo group if not already
if groups $user | grep -q -E ' sudo(\s|$)'; then
  echo "$user already has sudo privileges"
else
  adduser $user sudo
fi

# download rt scripts and config files
echo "Fetching rtinst scripts" | tee -a $logfile
cd $home

rm -f rtgetscripts
wget -q --no-check-certificate $rtdir/rtgetscripts
bash rtgetscripts

#raise file limits
sed -i '/hard nofile/ d' /etc/security/limits.conf
sed -i '/soft nofile/ d' /etc/security/limits.conf
sed -i '$ i\* hard nofile 32768\n* soft nofile 16384' /etc/security/limits.conf

# secure ssh
echo "Configuring SSH" | tee -a $logfile

portline=$(grep 'Port ' /etc/ssh/sshd_config)

if [ "$portdefault" = "0" ]; then
  sshport=22
  sed -i "/^Port/ c\Port $sshport" /etc/ssh/sshd_config
elif [ "$portline" = "Port 22" ] && [ "$portdefault" = "1" ]; then
  sshport=$(random 21000 29000)
  sed -i "s/Port 22/Port $sshport/g" /etc/ssh/sshd_config
fi

sed -i "s/X11Forwarding yes/X11Forwarding no/g" /etc/ssh/sshd_config
sed -i '/^PermitRootLogin/ c\PermitRootLogin no' /etc/ssh/sshd_config

usedns=$(grep UseDNS /etc/ssh/sshd_config)
if [ -z "$usedns" ]; then
  echo "UseDNS no" >> /etc/ssh/sshd_config
else
 sed -i "s/$usedns/UseDNS no/g" /etc/ssh/sshd_config
fi

if [ -z "$(grep sshuser /etc/group)" ]; then
groupadd sshuser
fi

allowlist=$(grep AllowUsers /etc/ssh/sshd_config)
if ! [ -z "$allowlist" ]; then
  for ssh_user in $allowlist
    do
      if   [ ! "$ssh_user" = "AllowUsers" ] && [ "$(groups $ssh_user 2> /dev/null | grep -E ' sudo(\s|$)')" = "" ]; then
        adduser $ssh_user sshuser
      fi
    done
  sed -i "/$allowlist/ d" /etc/ssh/sshd_config
fi
grep "AllowGroups sudo sshuser" /etc/ssh/sshd_config > /dev/null || echo "AllowGroups sudo sshuser" >> /etc/ssh/sshd_config

service ssh restart 1>> $logfile
sshport=$(grep 'Port ' /etc/ssh/sshd_config | sed 's/[^0-9]*//g')
echo "SSH port set to $sshport"

# install ftp

ftpport=$(random 41005 48995)

if [ $(dpkg-query -W -f='${Status}' "vsftpd" 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
  echo "Installing Pure-Ftpd" | tee -a $logfile
    apt-get -y install pure-ftpd >> $logfile 2>&1
fi
#//pure-pw mkdb
#//ln -s /etc/pure-ftpd/pureftpd.passwd /etc/pureftpd.passwd
#//ln -s /etc/pure-ftpd/pureftpd.pdb /etc/pureftpd.pdb
#//ln -s /etc/pure-ftpd/conf/PureDB /etc/pure-ftpd/auth/PureDB

echo "$ftpport" > /etc/pure-ftpd/conf/Bind 
echo 'yes' > /etc/pure-ftpd/conf/ChrootEveryone
echo 'no' > /etc/pure-ftpd/conf/DisplayDotFiles
echo 'yes' > /etc/pure-ftpd/conf/ProhibitDotFilesWrite
echo 'yes' > /etc/pure-ftpd/conf/ProhibitDotFilesRead
echo '2' > /etc/pure-ftpd/conf/TLS
echo '5' > /etc/pure-ftpd/conf/MaxClientsPerIP
echo 'yes' > /etc/pure-ftpd/conf/Daemonize
echo 'no' > /etc/pure-ftpd/conf/VerboseLog
echo 'yes' > /etc/pure-ftpd/conf/NoChmod
echo 'no' > /etc/pure-ftpd/conf/AnonymousOnly
echo 'yes' > /etc/pure-ftpd/conf/NoAnonymous
echo 'no' > /etc/pure-ftpd/conf/PAMAuthentication
echo 'yes' > /etc/pure-ftpd/conf/UnixAuthentication
echo 'yes' > /etc/pure-ftpd/conf/DontResolve
echo '15' > /etc/pure-ftpd/conf/MaxIdleTime
echo '2000 8' > /etc/pure-ftpd/conf/LimitRecursion
echo 'yes' > /etc/pure-ftpd/conf/AntiWarez
echo 'no' > /etc/pure-ftpd/conf/AnonymousCanCreateDirs
echo 'yes' > /etc/pure-ftpd/conf/AllowUserFXP
echo 'no' > /etc/pure-ftpd/conf/AllowAnonymousFXP
echo 'no' > /etc/pure-ftpd/conf/AutoRename
echo 'yes' > /etc/pure-ftpd/conf/AnonymousCantUpload
echo 'yes' > /etc/pure-ftpd/conf/NoChmod
echo 'yes' > /etc/pure-ftpd/conf/CustomerProof


mkdir -p /etc/ssl/private/
openssl req -x509 -nodes -days 3650 -subj /CN=$serverip -newkey rsa:2048 -keyout /etc/ssl/private/pure-ftpd.pem -out /etc/ssl/private/pure-ftpd.pem >> $logfile 2>&1
chmod 600 /etc/ssl/private/pure-ftpd.pem

service pure-ftpd restart 1>> $logfile

ftpport=$(cat '/etc/pure-ftpd/conf/Bind')
echo "FTP port set to $ftpport"

# install rtorrent
if [ $install_rt = 0 ]; then
  cd $home
  mkdir -p source
  cd source
  echo "Downloading rtorrent source files" | tee -a $logfile

  svn co $xmlrpcloc xmlrpc  >> $logfile 2>&1 || error_exit "Unable to download xmlrpc source files from https://svn.code.sf.net/p/xmlrpc-c/code/stable"
  curl -# $libtorrentloc | tar xz  >> $logfile 2>&1 || error_exit "Unable to download libtorrent source files from http://libtorrent.rakshasa.no/downloads"
  curl -# $rtorrentloc | tar xz  >> $logfile 2>&1 || error_exit "Unable to download rtorrent source files from http://libtorrent.rakshasa.no/downloads"

  cd xmlrpc
  echo "Installing xmlrpc" | tee -a $logfile
  ./configure --prefix=/usr --enable-libxml2-backend --disable-libwww-client --disable-wininet-client --disable-abyss-server --disable-cgi-server >> $logfile 2>&1
  make >> $logfile 2>&1
  make install >> $logfile 2>&1

  cd ../libtorrent-$libtorrentrel
  echo "Installing libtorrent" | tee -a $logfile
  ./autogen.sh >> $logfile 2>&1
  if [ $osname = "Raspbian" ]; then
    ./configure --prefix=/usr --disable-instrumentation >> $logfile 2>&1
  else
    ./configure --prefix=/usr >> $logfile 2>&1
  fi
  make -j2 >> $logfile 2>&1
  make install >> $logfile 2>&1

  cd ../rtorrent-$rtorrentrel
  echo "Installing rtorrent" | tee -a $logfile
  ./autogen.sh >> $logfile 2>&1
  ./configure --prefix=/usr --with-xmlrpc-c >> $logfile 2>&1
  make -j2 >> $logfile 2>&1
  make install >> $logfile 2>&1
  ldconfig >> $logfile 2>&1
else
 echo "skiping rtorrent installation" | tee -a $logfile
fi

echo "Configuring rtorrent" | tee -a $logfile
cd $home

mkdir -p rtorrent/.session
mkdir -p rtorrent/downloads
mkdir -p rtorrent/watch


rtgetscripts $home/.rtorrent.rc
sed -i "s|<user home>|${home}|g" $home/.rtorrent.rc
sed -i "s/<user name>/$user/g" $home/.rtorrent.rc

# install rutorrent


mkdir -p /var/www
cd /var/www

if [ -d "/var/www/rutorrent" ]; then
  rm -r /var/www/rutorrent
fi

# if [ $rudevflag = 1 ]; then
#   echo "Installing Rutorrent (stable)" | tee -a $logfile
#   wget --no-check-certificate https://bintray.com/artifact/download/novik65/generic/rutorrent-3.6.tar.gz >> $logfile 2>&1 || error_exit "Unable to download rutorrent files from https://bintray.com/artifact/download/novik65/generic/rutorrent-3.6.tar.gz"
#   wget --no-check-certificate https://bintray.com/artifact/download/novik65/generic/plugins-3.6.tar.gz >> $logfile 2>&1 || error_exit "Unable to download rutorrent plugin files from https://bintray.com/artifact/download/novik65/generic/plugins-3.6.tar.gz"
#   tar -xzf rutorrent-3.6.tar.gz
#   tar -xzf plugins-3.6.tar.gz
#   rm rutorrent-3.6.tar.gz
#   rm plugins-3.6.tar.gz
#   rm -r rutorrent/plugins
#   mv plugins rutorrent
# else
#   echo "Installing Rutorrent (development)" | tee -a $logfile
#   git clone https://github.com/Novik/ruTorrent.git
#   mv ruTorrent rutorrent
# fi

echo "Installing Rutorrent" | tee -a $logfile
git clone https://github.com/Novik/ruTorrent.git rutorrent >> $logfile 2>&1

echo "Configuring Rutorrent" | tee -a $logfile
rm rutorrent/conf/config.php
rtgetscripts /var/www/rutorrent/conf/config.php ru.config
mkdir -p /var/www/rutorrent/conf/users/$user/plugins

#cd /var/www/rutorrent/plugins
#rm -r diskspace/
#git clone https://github.com/kvanbiesen/rtplugins.git
#if [[ $quota == yes ]]; then
#    if [[ ${primaryroot} == "root" ]]; then
#		rm -r diskspaceh/
#	else
#		rm -r diskspace/
#	fi
#fi


echo "<?php" > /var/www/rutorrent/conf/users/$user/config.php
echo >> /var/www/rutorrent/conf/users/$user/config.php
echo "\$homeDirectory = \"$home\";" >> /var/www/rutorrent/conf/users/$user/config.php
echo "\$topDirectory = \"$home\";" >> /var/www/rutorrent/conf/users/$user/config.php
echo "\$scgi_port = 5000;" >> /var/www/rutorrent/conf/users/$user/config.php
echo "\$XMLRPCMountPoint = \"/RPC2\";" >> /var/www/rutorrent/conf/users/$user/config.php
echo >> /var/www/rutorrent/conf/users/$user/config.php
echo "?>" >> /var/www/rutorrent/conf/users/$user/config.php

rtgetscripts /var/www/rutorrent/conf/plugins.ini ru.ini
if [ $osname = "Raspbian" ]; then
  sed -i '/\[screenshots\]/,+1d' /var/www/rutorrent/conf/plugins.ini
  sed -i '/\[unpack\]/,+1d' /var/www/rutorrent/conf/plugins.ini
  echo '[screenshots]' >> /var/www/rutorrent/conf/plugins.ini
  echo 'enabled = no' >> /var/www/rutorrent/conf/plugins.ini
  echo '[unpack]' >> /var/www/rutorrent/conf/plugins.ini
  echo 'enabled = no' >> /var/www/rutorrent/conf/plugins.ini
fi

# install nginx
cd $home

if [ -f "/etc/apache2/ports.conf" ]; then
  echo "Detected apache2. Changing apache2 port to 81 in /etc/apache2/ports.conf" | tee -a $logfile
  sed -i "s/Listen 80/Listen 81/g" /etc/apache2/ports.conf
  service apache2 stop >> $logfile 2>&1
fi

echo "Installing nginx" | tee -a $logfile
#webpass=$(genpasswd)
htpasswd -c -b $passfile $user $webpass >> $logfile 2>&1
chown www-data:www-data $passfile
chmod 640 $passfile

openssl req -x509 -nodes -days 3650 -subj /CN=$serverip -newkey rsa:2048 -keyout /etc/ssl/ruweb.key -out /etc/ssl/ruweb.crt >> $logfile 2>&1

sed -i "s/user www-data;/user www-data www-data;/g" /etc/nginx/nginx.conf
sed -i "s/worker_processes 4;/worker_processes 1;/g" /etc/nginx/nginx.conf
sed -i "s/pid \/run\/nginx\.pid;/pid \/var\/run\/nginx\.pid;/g" /etc/nginx/nginx.conf
sed -i "s/# server_tokens off;/server_tokens off;/g" /etc/nginx/nginx.conf
sed -i "s/access_log \/var\/log\/nginx\/access\.log;/access_log off;/g" /etc/nginx/nginx.conf
sed -i "s/error\.log;/error\.log crit;/g" /etc/nginx/nginx.conf
grep client_max_body_size /etc/nginx/nginx.conf > /dev/null 2>&1 || sed -i "/server_tokens off;/ a\        client_max_body_size 40m;\n" /etc/nginx/nginx.conf
sed -i "/upload_max_filesize/ c\upload_max_filesize = 40M" $phploc/fpm/php.ini
sed -i '/^;\?listen.owner/ c\listen.owner = www-data' $phploc/fpm/pool.d/www.conf
sed -i '/^;\?listen.group/ c\listen.group = www-data' $phploc/fpm/pool.d/www.conf
sed -i '/^;\?listen.mode/ c\listen.mode = 0660' $phploc/fpm/pool.d/www.conf

if [ -d "/usr/share/nginx/www" ]; then
  cp /usr/share/nginx/www/* /var/www
elif [ -d "/usr/share/nginx/html" ]; then
  cp /usr/share/nginx/html/* /var/www
fi

mv /etc/nginx/sites-available/default /etc/nginx/sites-available/default.old

rtgetscripts /etc/nginx/sites-available/default nginxsite
rtgetscripts /etc/nginx/sites-available/dload-loc nginxsitedl

echo "location ~ \.php$ {" > /etc/nginx/conf.d/php
echo "          fastcgi_split_path_info ^(.+\.php)(/.+)$;" >> /etc/nginx/conf.d/php
if [ $relno = 12 ]; then
  echo "          fastcgi_pass 127.0.0.1:9000;" >> /etc/nginx/conf.d/php
elif [ $relno = 16 ]; then
  echo "          fastcgi_pass unix:/var/run/php/php7.0-fpm.sock;" >> /etc/nginx/conf.d/php
else
  echo "          fastcgi_pass unix:/var/run/php5-fpm.sock;" >> /etc/nginx/conf.d/php
fi
echo "          fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;" >> /etc/nginx/conf.d/php
echo "          fastcgi_index index.php;" >> /etc/nginx/conf.d/php
echo "          include fastcgi_params;" >> /etc/nginx/conf.d/php
echo "}" >> /etc/nginx/conf.d/php

echo "location ~* \.(jpg|jpeg|gif|css|png|js|woff|ttf|svg|eot)$ {" > /etc/nginx/conf.d/cache
echo "        expires 30d;" >> /etc/nginx/conf.d/cache
echo "}" >> /etc/nginx/conf.d/cache

sed -i "s/<Server IP>/$serverip/g" /etc/nginx/sites-available/default

service nginx restart && service $phpver-fpm restart

if [ $dlflag = 0 ]; then
  rtdload enable
fi

# install autodl-irssi
echo "Installing autodl-irssi" | tee -a $logfile
adlport=$(random 36001 36100)
adlpass=$(genpasswd $(random 12 16))

mkdir -p $home/.irssi/scripts/autorun
cd $home/.irssi/scripts
curl -sL http://git.io/vlcND | grep -Po '(?<="browser_download_url": ")(.*-v[\d.]+.zip)' | xargs wget --quiet -O autodl-irssi.zip
unzip -o autodl-irssi.zip >> $logfile 2>&1
rm autodl-irssi.zip
cp autodl-irssi.pl autorun/
mkdir -p $home/.autodl
touch $home/.autodl/autodl.cfg && touch $home/.autodl/autodl2.cfg

cd /var/www/rutorrent/plugins
git clone https://github.com/autodl-community/autodl-rutorrent.git autodl-irssi >> $logfile 2>&1 || error_exit "Unable to download autodl plugin files from https://github.com/autodl-community/autodl-irssi"

mkdir /var/www/rutorrent/conf/users/$user/plugins/autodl-irssi

touch /var/www/rutorrent/conf/users/$user/plugins/autodl-irssi/conf.php

echo "<?php" > /var/www/rutorrent/conf/users/$user/plugins/autodl-irssi/conf.php
echo >> /var/www/rutorrent/conf/users/$user/plugins/autodl-irssi/conf.php
echo "\$autodlPort = $adlport;" >> /var/www/rutorrent/conf/users/$user/plugins/autodl-irssi/conf.php
echo "\$autodlPassword = \"$adlpass\";" >> /var/www/rutorrent/conf/users/$user/plugins/autodl-irssi/conf.php
echo >> /var/www/rutorrent/conf/users/$user/plugins/autodl-irssi/conf.php
echo "?>" >> /var/www/rutorrent/conf/users/$user/plugins/autodl-irssi/conf.php

rtgetscripts /var/www/rutorrent/plugins/diskspace/action.php diskspace.action.php

cd $home/.autodl
echo "[options]" > autodl2.cfg
echo "gui-server-port = $adlport" >> autodl2.cfg
echo "gui-server-password = $adlpass" >> autodl2.cfg

# set permissions
echo "Setting permissions, Starting services" | tee -a $logfile
chown -R www-data:www-data /var/www
chmod -R 755 /var/www/rutorrent
chown -R $user:$user $home

cd $home

if [ -z "$(grep "ALL ALL = NOPASSWD: /usr/local/bin/rtsetpass" /etc/sudoers)" ]; then
  echo "ALL ALL = NOPASSWD: /usr/local/bin/rtsetpass" | (EDITOR="tee -a" visudo)  > /dev/null 2>&1
fi

#add quota support to all users
echo "www-data ALL=(root) NOPASSWD: /usr/sbin/repquota" | tee -a /etc/sudoers > /dev/null

su $user -c '/usr/local/bin/rt restart'
su $user -c '/usr/local/bin/rt -i restart'

if [ -z "$(crontab -u $user -l | grep "$cronline1")" ]; then
    (crontab -u $user -l; echo "$cronline1" ) | crontab -u $user - >> $logfile 2>&1
fi

if [ -z  "$(crontab -u $user -l | grep "\*/10 \* \* \* \* /usr/local/bin/rtcheck irssi rtorrent")" ]; then
    (crontab -u $user -l; echo "$cronline2" ) | crontab -u $user - >> $logfile 2>&1
fi

echo
echo "crontab entries made. rtorrent and irssi will start on boot for $user"
echo
echo "ftp client should be set to explicit ftp over tls using port $ftpport" | tee $home/rtinst.info
echo
if [ $dlflag = 0 ]; then
  find $home -type d -print0 | xargs -0 chmod 755
fi
echo "If enabled, access https downloads at https://$serverip/download/$user" | tee -a $home/rtinst.info
echo
echo "rutorrent can be accessed at https://$serverip/rutorrent" | tee -a $home/rtinst.info

if [ $PASSFLAG = 1 ]; then
  echo "rutorrent password set to $webpass" | tee -a $home/rtinst.info
else
  echo "rutorrent password as set by user" | tee -a $home/rtinst.info
fi

echo "to change rutorrent password enter: rtpass" | tee -a $home/rtinst.info
echo
echo "IMPORTANT: SSH Port set to $sshport - Ensure you can login before closing this session"
echo "ssh port changed to $sshport" | tee -a $home/rtinst.info > /dev/null
echo
echo "The above information is stored in rtinst.info in your home directory."
echo "To see contents enter: cat $home/rtinst.info"
echo
echo "To install webmin enter: sudo rtwebmin"
echo
echo "PLEASE REBOOT YOUR SYSTEM ONCE YOU HAVE NOTED THE ABOVE INFORMATION"
rm $home/sources
chown $user rtinst.info
