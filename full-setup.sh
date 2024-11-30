#!/bin/bash

# Exit on errors
set -e

# Variables
KIOSK_USER="kiosk"
KIOSK_PASSWORD="kiosk123"  # Replace with a secure password
KIOSK_URL="https://inline-panel.vercel.app"  # Replace with your kiosk website URL

echo "==============================="
echo "Starting full kiosk setup..."
echo "==============================="

# 1. Update the system
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# 2. Install required packages
echo "Installing necessary packages..."
sudo apt install -y \
    xorg \
    xfce4 \
    xfce4-terminal \
    lightdm \
    wget \
    onboard \
    pulseaudio \
    network-manager \
    xserver-xorg-input-all \
    xserver-xorg-video-all \
    policykit-1 \
    x11-xserver-utils \
    xdg-utils \
    unclutter

# 3. Install Google Chrome
if ! command -v google-chrome &>/dev/null; then
    echo "Google Chrome not found. Downloading and installing..."
    wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    sudo apt install -y ./google-chrome-stable_current_amd64.deb
    rm google-chrome-stable_current_amd64.deb
else
    echo "Google Chrome is already installed."
fi

# 4. Create the kiosk user
if id "$KIOSK_USER" &>/dev/null; then
    echo "User '$KIOSK_USER' already exists. Skipping creation."
else
    echo "Adding user '$KIOSK_USER'..."
    sudo adduser --disabled-password --gecos "" $KIOSK_USER
    echo "$KIOSK_USER:$KIOSK_PASSWORD" | sudo chpasswd
    echo "User '$KIOSK_USER' created with password: $KIOSK_PASSWORD"
fi

# 5. Add the kiosk user to necessary groups
echo "Adding '$KIOSK_USER' to required groups..."
sudo usermod -aG sudo,video,audio,netdev $KIOSK_USER

# 6. Restrict sudo permissions for the kiosk user
echo "Restricting sudo permissions for '$KIOSK_USER'..."
sudo bash -c "echo '$KIOSK_USER ALL=(ALL) NOPASSWD: /usr/bin/startx' >> /etc/sudoers.d/$KIOSK_USER"

# 7. Configure auto-login for the kiosk user
echo "Configuring auto-login for '$KIOSK_USER'..."
sudo bash -c "cat > /etc/lightdm/lightdm.conf.d/50-kiosk.conf" <<EOF
[SeatDefaults]
autologin-user=$KIOSK_USER
autologin-session=xfce
EOF

# 8. Set up kiosk session for the user
echo "Setting up kiosk environment for '$KIOSK_USER'..."
sudo -u $KIOSK_USER mkdir -p /home/$KIOSK_USER/.config
sudo -u $KIOSK_USER bash -c "cat > /home/$KIOSK_USER/.xinitrc" <<EOF
#!/bin/bash
xset s off  # Disable screensaver
xset -dpms  # Disable power management
xset s noblank  # Prevent screen blanking
unclutter &  # Hide mouse cursor when idle
onboard &  # Launch virtual keyboard
google-chrome --noerrdialogs --disable-infobars --kiosk $KIOSK_URL &  # Launch Chrome in kiosk mode
EOF
sudo chmod +x /home/$KIOSK_USER/.xinitrc

# 9. Configure screen settings to prevent blanking
echo "Disabling screen blanking and power-saving features for '$KIOSK_USER'..."
sudo -u $KIOSK_USER bash -c "cat > /home/$KIOSK_USER/.xprofile" <<EOF
xset s off
xset -dpms
xset s noblank
EOF

# 10. Set up a systemd service for kiosk mode
echo "Creating systemd service to launch kiosk mode automatically..."
sudo bash -c "cat > /etc/systemd/system/kiosk.service" <<EOF
[Unit]
Description=Kiosk Mode
After=graphical.target

[Service]
User=$KIOSK_USER
Environment=DISPLAY=:0
ExecStart=/usr/bin/startx
Restart=always

[Install]
WantedBy=graphical.target
EOF

sudo systemctl enable kiosk.service

# 11. Configure Xorg to prevent screen blanking at a system level
echo "Configuring Xorg settings to prevent blanking and disable input switching..."
sudo mkdir -p /etc/X11/xorg.conf.d/
sudo bash -c "cat > /etc/X11/xorg.conf.d/10-kiosk.conf" <<EOF
Section "ServerFlags"
    Option "BlankTime" "0"
    Option "StandbyTime" "0"
    Option "SuspendTime" "0"
    Option "OffTime" "0"
    Option "DontVTSwitch" "True"
    Option "DontZap" "True"
EndSection
EOF

# 12. Final cleanup and reboot
echo "==============================="
echo "Kiosk setup is complete!"
echo "Rebooting the system to apply changes..."
echo "==============================="
sudo reboot
