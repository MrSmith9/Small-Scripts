#!/bin/bash
sleep 1
clear
echo "############################################################################"
echo "#                            Nginx Installer                               #"
echo "#               by Nico L and Kyle Smith (mrsmith9)                        #"
echo "#                   https://github.com/ipexadev/scripts                    #"
echo "#                          Last Update: 27.06.2022                         #"
echo "############################################################################"
sleep 3
clear 
echo "############################################################################"
echo "#                            Checking for Root                             #"
echo "############################################################################"
if (( $EUID != 0 )); then
echo "############################################################################"
echo "#                            Please run as root                            #"
echo "############################################################################"
    exit
fi
sleep 1
clear
echo "############################################################################"
echo "#                             Checked for Root                             #"
echo "############################################################################"
sleep 2
clear
echo "############################################################################"
echo "#                          Installing Nginx                                #"
echo "############################################################################"
sleep 2
echo "############################################################################"
echo "#                      Server Update (apt update -y)                       #"
echo "############################################################################"
apt update -y
wait -n
echo "############################################################################"
echo "#                      Server Upgrade (apt upgrade -y)                     #"
echo "############################################################################"
apt upgrade -y
wait -n 
echo "############################################################################"
echo "#                 Nginx Installation (apt install nginx -y)                #"
echo "############################################################################"
apt install nginx -y
wait -n 
echo "############################################################################"
echo "#                Enabling Nginx (systemctl enable nginx)                   #"
echo "############################################################################"
systemctl enable nginx
echo "############################################################################"
echo "#            Checking Nginx Stauts (systemctl status nginx)                #"
echo "############################################################################"
systemctl status nginx
wait -n
echo "############################################################################"
echo "#                         Installed Nginx                                  #"
echo "############################################################################"

echo "############################################################################"
# Configure UFW firewall to allow SSH and Nginx
echo "#                       Configuring UFW firewall                           #"
if ! command -v ufw >/dev/null 2>&1; then
    echo "Installing ufw..."
    apt install -y ufw
fi
echo "Allowing OpenSSH to prevent lockout"
ufw allow OpenSSH
echo "Allowing Nginx HTTP/HTTPS"
ufw allow 'Nginx Full' || (ufw allow 80 && ufw allow 443)
echo "Enabling ufw (non-interactive)"
ufw --force enable
echo "###########################################################################"
echo "#                    Thank you for use this script                        #"
echo "###########################################################################"