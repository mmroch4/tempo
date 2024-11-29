#!/bin/bash

# Update package lists
sudo apt update

# Install required packages
sudo apt install -y xorg openbox chromium-browser matchbox-keyboard lightdm

# Create a new user for the kiosk
KIOSK_USER="kiosk"
sudo adduser --disabled-password --gecos "" $KIOSK_USER

# Set up autologin for the kiosk user
sudo mkdir -p /etc/lightdm/lightdm.conf.d
echo "[Seat:*]" | sudo tee /etc/lightdm/lightdm.conf.d/50-kiosk.conf
echo "autologin-user=$KIOSK_USER" | sudo tee -a /etc/lightdm/lightdm.conf.d/50-kiosk.conf
echo "autologin-user-timeout=0" | sudo tee -a /etc/lightdm/lightdm.conf.d/50-kiosk.conf

# Create a script to launch the kiosk environment
KIOSK_SCRIPT="/home/$KIOSK_USER/kiosk.sh"
echo "#!/bin/bash" | sudo tee $KIOSK_SCRIPT
echo "xset r rate 300 50" | sudo tee -a $KIOSK_SCRIPT
echo "matchbox-window-manager &" | sudo tee -a $KIOSK_SCRIPT
echo "chromium-browser --no-sandbox --kiosk --app=https://miguelrocha.dev" | sudo tee -a $KIOSK_SCRIPT
echo "matchbox-keyboard &" | sudo tee -a $KIOSK_SCRIPT

# Make the kiosk script executable
sudo chmod +x $KIOSK_SCRIPT
sudo chown $KIOSK_USER:$KIOSK_USER $KIOSK_SCRIPT

# Set the kiosk script to run on startup
echo "exec /home/$KIOSK_USER/kiosk.sh" | sudo tee -a /home/$KIOSK_USER/.xinitrc
sudo chown $KIOSK_USER:$KIOSK_USER /home/$KIOSK_USER/.xinitrc

# Enable the lightdm service to start on boot
sudo systemctl enable lightdm

# Reboot the system
echo "Kiosk setup complete. The system will reboot now."
sudo reboot