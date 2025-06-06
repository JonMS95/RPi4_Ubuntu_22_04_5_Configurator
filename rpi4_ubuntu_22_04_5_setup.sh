#!/bin/bash

# Variables
USER_NAME=""

# If the script was run with sudo, use $SUDO_USER. Otherwise, use the current user's name
if [ -n "$SUDO_USER" ]; then
    USER_NAME=$SUDO_USER
else
    USER_NAME=$USER
fi

HOME_DIR="/home/$USER_NAME"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

# 1) Add user to sudoers group and prevent it from being prompted for its password
sudo usermod -aG sudo $USER_NAME
sudo cp $SCRIPT_DIR/custom_sudoers_file /etc/sudoers.d/custom_sudoers
sudo chmod 440 /etc/sudoers.d/custom_sudoers

# 2) Update & install packages
sudo apt update
sudo apt upgrade -y
sudo apt install -y ssh avahi-daemon x11vnc lightdm xfce4 xfce4-goodies xfce4-power-manager xfce4-screensaver tmux git vim net-tools

# Enable and start ssh & avahi services
sudo systemctl enable ssh
sudo systemctl start ssh
sudo systemctl enable avahi-daemon
sudo systemctl start avahi-daemon

# 3) Setup x11vnc password and service
sudo mkdir -p $HOME_DIR/.vnc
sudo chown -R "$USER_NAME:$USER_NAME" "$HOME_DIR/.vnc"

if [ ! -f "$HOME_DIR/.vnc/passwd" ]; then
  echo "Please enter VNC password for user $USER_NAME:"
  sudo -u "$USER_NAME" x11vnc -storepasswd "$HOME_DIR/.vnc/passwd"
fi

sudo chmod 600 "$HOME_DIR/.vnc/passwd"

# Create systemd service for x11vnc
sudo sed "s/TEMPLATE_USER/$USER_NAME/g" x11vnc.service.template > x11vnc.service.$USER_NAME
sudo mv $SCRIPT_DIR/x11vnc.service.$USER_NAME /etc/systemd/system/x11vnc.service

sudo systemctl daemon-reload
sudo systemctl enable x11vnc.service
sudo systemctl start x11vnc.service

# 4) Configure LightDM for autologin
sudo mkdir -p /etc/lightdm/lightdm.conf.d
sudo sed "s/TEMPLATE_USER/$USER_NAME/g" 50-autologin.conf.template > 50-autologin.conf.$USER_NAME
sudo mv $SCRIPT_DIR/50-autologin.conf.$USER_NAME /etc/lightdm/lightdm.conf.d/50-autologin.conf

# 5) Configure XFCE to disable auto screen lock but allow manual lock
sudo -u $USER_NAME xfconf-query -c xfce4-session -p /general/LockCommand --create -t string -s "xfce4-screensaver-command -l"
sudo -u $USER_NAME xfconf-query -c xfce4-session -p /general/LockOnSuspend --create -t bool -s false
sudo -u $USER_NAME xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/lock-screen-suspend-hibernate --create -t bool -s false
sudo -u $USER_NAME xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/lock-screen-sleep --create -t bool -s false
sudo -u $USER_NAME xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/blank-on-ac --create -t int -s 0
sudo -u $USER_NAME xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/dpms-enabled --create -t bool -s false

# 6) Add xfce4-screensaver start to user's ~/.xsessionrc
sudo echo "xfce4-screensaver &" >> $HOME_DIR/.xsessionrc
sudo chown $USER_NAME:$USER_NAME $HOME_DIR/.xsessionrc

# 7) Copy your provided .tmux.conf and ensure TPM installed
if [ -f "$SCRIPT_DIR/.tmux.conf" ]; then
  sudo cp "$SCRIPT_DIR/.tmux.conf" $HOME_DIR/.tmux.conf
  sudo chown $USER_NAME:$USER_NAME $HOME_DIR/.tmux.conf
  echo ".tmux.conf copied from script directory"
else
  echo "Warning: .tmux.conf file not found in script directory. Skipping."
fi

if [ ! -d "$HOME_DIR/.tmux/plugins/tpm" ]; then
  sudo su - $USER_NAME -c "git clone https://github.com/tmux-plugins/tpm $HOME_DIR/.tmux/plugins/tpm"
fi

# 8) Overwrite .bashrc with your provided file
if [ -f "$SCRIPT_DIR/.bashrc" ]; then
  sudo cp "$SCRIPT_DIR/.bashrc" $HOME_DIR/.bashrc
  sudo chown $USER_NAME:$USER_NAME $HOME_DIR/.bashrc
  echo ".bashrc copied from script directory"
else
  echo "Warning: .bashrc file not found in script directory. Skipping."
fi

echo "Setup complete! Please reboot to apply all changes."
