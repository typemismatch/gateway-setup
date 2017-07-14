#!/bin/bash

#Create a log file in same directory to store output of the script
timestamp=$(date +%s)
exec > >(tee -ia ubuntu-gateway-install-log-$timestamp.log)
exec 2> >(tee -ia ubuntu-gateway-install-log-$timestamp.log >&2)

#To change color to yellow for info text
Y='\033[1;33m'
NC='\033[0m'

#Get the board details
ATOM_PLATFORM="DE3815TYKH"
CORE_PLATFORM="NUC5i7RYB"
GATEWAY_DIR="gateway-setup"
CUR_DIR="${PWD##*/}"
platform=$(cat /sys/devices/virtual/dmi/id/board_name)

install_node() {
    echo -e "${Y}Install Node..${NC}\n"
    curl -sL https://deb.nodesource.com/setup_4.x | sudo -E bash -
    apt-get install -y nodejs
}

install_and_setup_node-red() {
    echo -e "${Y}Install Node-Red and it's UPM Grove kit npm packages...${NC}\n"
    npm install -g node-red
    npm install -g node-red-contrib-upm

    echo -e "${Y}Create & add Node-Red user to dialout group for ttyACM0 access${NC}\n"
    useradd node-red -G dialout
    mkdir -p /home/node-red/.node-red
    chown -R node-red:node-red /home/node-red

    echo -e "${Y}Setup imraa & Node-Red services and default flows...${NC}\n"
    cp conf_files/node-red/node-red-experience.timer /lib/systemd/system/node-red-experience.timer
    cp conf_files/node-red/node-red-experience.service /lib/systemd/system/node-red-experience.service
    cp conf_files/mraa-imraa.service /lib/systemd/system/mraa-imraa.service
    cp utils/dfu-util /usr/bin/

    #run daemon-reload for this to take effect
    systemctl daemon-reload

    #Enable node-red timer which will start the service after a short time on boot
    systemctl enable node-red-experience.timer
}

install_mraa_upm_plugins() {
    echo -e "${Y}Install MRAA, UPM and its dependencies..${NC}\n"
    add-apt-repository -y ppa:mraa/mraa
    apt-get update
    apt-get install -y libmraa1 libmraa-dev mraa-tools mraa-imraa python-mraa \
        python3-mraa libupm-dev python-upm python3-upm upm-examples

    echo -e "${Y}Install MRAA and UPM plugins for java script...${NC}\n"
    #Install MRAA & UPM plugins for java script
    npm install -g mraa
    npm install -g jsupm_grove
    npm install -g jsupm_i2clcd
    npm install -g jsupm_servo
}

echo -e "${Y}********** Start of Script ***********${NC}\n"

if [[ $EUID -ne 0 ]]; then
    echo -e "${Y}This script must be run as root${NC}\n"
    exit 1
fi

if [ "$CUR_DIR" != "$GATEWAY_DIR" ]; then
    echo -e "${Y}ERROR!! Check your current working directory!${NC}\n"
    echo -e "${Y}Download your installation script and configuration files from github and then execute this script with following commands:${NC}"
    echo -e "${Y}git clone https://github.com/SSG-DRD-IOT/gateway-setup.git${NC}"
    echo -e "${Y}cd gateway-setup${NC}"
    echo -e "${Y}./ubuntu-corei7-gateway-setup.sh${NC}\n"
    exit 1
fi

echo -e "${Y}Install package dependencies...${NC}\n"
apt-get install -y software-properties-common build-essential libssl-dev libkrb5-dev checkinstall
apt-get install -y avahi-daemon avahi-autoipd avahi-utils libavahi-compat-libdnssd-dev
apt-get install -y libtool automake
apt-get install -y openssh-client openssh-server

echo -e "${Y}Modify the sshd_config file for ssh access to root user, it is disabled by default and restrart sshd...${NC}\n"
sed -ie 's/prohibit-password/yes/g' /etc/ssh/sshd_config
systemctl restart sshd

#Install Node
install_node

#Install Node-Red
install_and_setup_node-red

#Install MRAA UPM and plugins for JS
install_mraa_upm_plugins

echo -e "${Y}Export node path(NODE_PATH) by adding it to bashrc file...${NC}\n"
echo 'export NODE_PATH=/usr/lib/node_modules/' >> ~/.bashrc
#This won't work since it will source it in sub-shell. Need to source the bash file after the
#script exits
source ~/.bashrc

#Install PIP
apt-get install python-pip -y

#Install AWS CLI
pip install --upgrade awscli

#Install NANO
apt-get install nano -y

#Set some of permissions
chmod a+x /home/aws/gateway-setup/agent/lib-systemd-system/setup.sh
chmod a+x /home/aws/gateway-setup/wifi_setup.sh

#Install the FIRMATA to the Arduino
# This doesn't work during the install and must be done manually.
#imraa -af

#Add the cli to bash
echo 'export PATH=~/.local/bin:$PATH' >> ~/.bash_profile
echo 'export PATH=~/.local/bin:$PATH' >> /home/aws/.bash_profile

echo -e "\n${Y}********** End of Script ***********${NC}\n"
echo -e "${Y}********** Rebooting after installation **********${NC}\n"
sleep 3
reboot
