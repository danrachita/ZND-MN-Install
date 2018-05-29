#!/bin/bash
clear

# Check if we are root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root." 1>&2
   exit 1
fi

# Check if we have enough memory
if [[ `free -m | awk '/^Mem:/{print $2}'` -lt 900 ]]; then
  echo "This installation requires at least 1GB of RAM.";
  exit 1
fi

# Check if we have enough disk space
if [[ `df -k --output=avail / | tail -n1` -lt 10485760 ]]; then
  echo "This installation requires at least 10GB of free disk space.";
  exit 1
fi

# Install tools for dig and systemctl
echo "Preparing installation..."
apt-get install git dnsutils systemd -y > /dev/null 2>&1

# Check for systemd
#systemctl --version >/dev/null 2>&1 || { echo "systemd is required. Are you using Ubuntu 16.04?"  >&2; exit 1; }

# CHARS is used for the loading animation further down.
CHARS="/-\|"
EXTERNALIP=`dig +short myip.opendns.com @resolver1.opendns.com`

clear


echo "
 |   +------- MASTERNODE INSTALLER v1.1 -------+  |
 |   ZND Installer by Kurbz                       |
 |   for Ununtu 16.04 only                        |
 +------------------------------------------------+
"

sleep 2

USER=root

USERHOME=`eval echo "~$USER"`

read -e -p "Server IP Address: " -i $EXTERNALIP -e IP
read -e -p "Masternode Private Key: " KEY


clear

# Generate random passwords
RPCUSER=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
RPCPASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

# update packages and upgrade Ubuntu
echo "Installing dependencies..."
apt-get -qq update
apt-get -qq upgrade
apt-get -qq autoremove
apt-get -qq install wget htop unzip
apt-get install systemd -y
apt-get update 
apt-get -y install libdb++-dev 
apt-get -y install libboost-all-dev 
apt-get -y install libcrypto++-dev 
apt-get -y install libqrencode-dev 
apt-get -y install libminiupnpc-dev 
apt-get -y install libgmp-dev 
apt-get -y install libgmp3-dev 
apt-get -y install autoconf 
apt-get -y install autogen 
apt-get -y install automake 
apt-get -y install bsdmainutils 
apt-get -y install libzmq3-dev 
apt-get -y install libminiupnpc-dev 
apt-get -y install libevent-dev
add-apt-repository -y ppa:bitcoin/bitcoin
apt-get update
apt-get install -y libdb4.8-dev libdb4.8++-dev
apt-get -qq install aptitude
apt-get update


aptitude -y -q install fail2ban
service fail2ban restart
apt-get -qq install ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 15198/tcp
yes | ufw enable


echo "
**********Installing deamon***********
"
sleep 2
wget  https://github.com/ktjbrowne/ZND-MN-Install/raw/master/zenad-cli
wget https://github.com/ktjbrowne/ZND-MN-Install/raw/master/zenadd
cp ./zenad-cli /usr/local/bin/zenad-cli
cp ./zenadd /usr/local/bin/zenadd
#cp ./krtd-Linux64 krtd
#cp ./krt-cli-Linux64 krtcli

chmod +x /usr/local/bin/zenadd
chmod +x ./zenadd
chmod +x /usr/local/bin/zenad-cli
chmod +x ./zenad-cli
echo "
*********Configuring confs***********
"
sleep 2
mkdir $USERHOME/.zenad

# Create hightemperature.conf
touch $USERHOME/.zenad/zenad.conf
cat > $USERHOME/.zenad/zenad.conf << EOL
rpcuser=${RPCUSER}
rpcpassword=${RPCPASSWORD}
rpcallowip=127.0.0.1
rpcport=15199
port=15198
listen=1
server=1
daemon=1
listenonion=0
logtimestamps=1
maxconnections=256
externalip=${IP}
bind=${IP}:15198
masternodeaddr=${IP}
masternodeprivkey=${KEY}
masternode=1
addnode=104.238.171.122:15198
addnode=162.251.109.12:15198
addnode=104.238.191.193:15198
addnode=77.220.215.101:15198


EOL
chmod 0600 $USERHOME/.zenad/zenad.conf
chown -R $USER:$USER $USERHOME/.zenad

sleep 1

cat > /etc/systemd/system/zenad.service << EOL
[Unit]
Description=zenad
After=network.target
[Service]
Type=forking
User=${USER}
WorkingDirectory=${USERHOME}
ExecStart=/usr/local/bin/zenadd -conf=${USERHOME}/.zenad/zenad.conf -datadir=${USERHOME}/.zenad
ExecStop=/usr/local/bin/zenad-cli -conf=${USERHOME}/.zenad/zenad.conf -datadir=${USERHOME}/.zenad stop
Restart=on-abort
[Install]
WantedBy=multi-user.target
EOL

chmod +x /usr/local/bin/zenadd 
chmod +x /usr/local/bin/zenad-cli
sudo ln -s /usr/lib/x86_64-linux-gnu/libboost_system.so.1.58.0 /usr/lib/x86_64-linux-gnu/libboost_program_options.so.1.54.0
#start service
echo "
********Starting Service*************
"
sleep 3
sudo systemctl enable zenad
sudo systemctl start zenad
sudo systemctl start zenad.service

#clear

echo "Service Started... Press any key to continue. "

#clear

echo "Your masternode is syncing. Please wait for this process to finish. "

until su -c "zenad-cli startmasternode local false 2>/dev/null | grep 'successfully started' > /dev/null" $USER; do
  for (( i=0; i<${#CHARS}; i++ )); do
    sleep 5
    #echo -en "${CHARS:$i:1}" "\r"
    clear
    echo "Service Started. Your masternode is syncing. 
    When Current = Synced then select your MN in the local wallet and start it."
    echo "Current Block: "
    su -c "curl http://chain.zenad.group/api/getblockcount" $USER
    echo "
    Synced Blocks: "
    su -c "zenad-cli getblockcount" $USER
  done
done

su -c "/usr/local/bin/zenad-cli startmasternode local false" $USER

sleep 1
su -c "/usr/local/bin/zenad-cli masternode status" $USER
sleep 1
#clear
#su -c "/usr/local/bin/krtd masternode status" $USER
#sleep 5

echo "" && echo "Masternode setup completed." && echo ""
