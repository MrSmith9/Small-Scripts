#!/bin/bash
sleep 1
clear
echo "############################################################################"
echo "#                           Python Installer                               #"
echo "#                              by Nico L.                                  #"
echo "#                   https://github.com/ipexadev/scripts                    #"
echo "#                          Last Update: 20.07.2026                         #"
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
echo "#                         Installing Python                                #"
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
echo "#            Python Installation (deadsnakes PPA, selectable version)      #"
echo "############################################################################"
PYVER="${PYTHON_VERSION:-3.11}"
echo "Selected Python version: ${PYVER}"
if command -v python${PYVER} >/dev/null 2>&1; then
    echo "python${PYVER} is already installed — skipping installation."
else
    apt install -y software-properties-common apt-transport-https ca-certificates gnupg
    add-apt-repository ppa:deadsnakes/ppa -y
    apt update -y
    apt install -y python${PYVER} python${PYVER}-venv python${PYVER}-dev
fi
if python${PYVER} -m pip --version >/dev/null 2>&1; then
    echo "pip for python${PYVER} already available."
else
    apt install -y python3-pip
    python${PYVER} -m ensurepip --upgrade >/dev/null 2>&1 || true
    python${PYVER} -m pip install --upgrade pip >/dev/null 2>&1 || true
fi
echo "############################################################################"
echo "#                         Installed Python ${PYVER}                        #"
echo "############################################################################"

wait -n
echo "###########################################################################"
echo "#                    Thank you for use this script                        #"
echo "###########################################################################"