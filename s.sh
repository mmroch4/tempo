#!/bin/bash

# Exit on errors
set -e

# Variables
USER_NAME=$(whoami)
KIOSK_URL="http://inline-panel.vercel.app"  # Replace with your kiosk website URL

echo "==========================="
echo "Starting kiosk setup..."
echo "==========================="

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
    google-chrome-stable \
    onboard \
    pulseaudio \
    network-manager \
    xserver-xorg-input-all \
    xserver-xorg-video-all \
    policykit-1 \
    x11-xserver-utils \
    xdg-utils \
    wget

# 3. Install Google Chrome (if not available in the package list)
if ! command -v google-chrome &>/dev/null; then
    echo "Google Chrome not found. Downloading and installing..."
    wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    sudo apt install -y ./google-chrome-stable_current_amd64.deb
    rm google-chrome-stable_current_amd64.deb
fi

# 4. Configure LightDM
echo "Configuring LightDM for auto-login..."
sudo bash -c "cat > /etc/lightdm/lightdm.conf.d/50-kiosk.conf" <<EOF
[SeatDefaults]
autologin-user=$USER_NAME
autologin-session=xfce
EOF

# 5. Configure Kiosk Session
echo "Setting up kiosk session..."

# Create .xinitrc file to define the session behavior
cat > ~/.xinitrc <<EOF
#!/bin/bash
xset s off  # Disable screensaver
xset -dpms  # Disable power management
xset s noblank  # Prevent screen blanking
pulseaudio --start  # Start audio service
onboard &  # Launch virtual keyboard
google-chrome --noerrdialogs --disable-infobars --kiosk $KIOSK_URL &  # Launch Chrome in kiosk mode
EOF
chmod +x ~/.xinitrc

# Create .xprofile to handle screen settings
cat > ~/.xprofile <<EOF
xset s off
xset -dpms
xset s noblank
EOF

# 6. Set Up a Systemd Service for Kiosk
echo "Creating systemd service for kiosk..."
sudo bash -c "cat > /etc/systemd/system/kiosk.service" <<EOF
[Unit]
Description=Kiosk Mode
After=graphical.target

[Service]
User=$USER_NAME
Environment=DISPLAY=:0
ExecStart=/usr/bin/startx
Restart=always

[Install]
WantedBy=graphical.target
EOF

# Enable the kiosk service
sudo systemctl enable kiosk.service

# 7. Prevent Screen Lock and Power Saving
echo "Configuring screen settings to prevent blanking..."
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

# 8. Install Additional Tools for Kiosk Mode
echo "Installing optional tools for better experience..."
sudo apt install -y unclutter  # Hides mouse cursor
unclutter &  # Start unclutter

# 9. Clean up and finish
echo "Kiosk setup is complete! Rebooting the system..."
sudo reboot
