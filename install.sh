#!/bin/bash

# Nashville96 XFCE Configuration Installer
# Portability: Works for any user on Arch-based systems

set -e

echo "--------------------------------------------------"
echo " Nashville96 XFCE configuration restore "
echo "--------------------------------------------------"

NEW_USER=$(whoami)
PLACEHOLDER="@USERNAME@"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# 1. Check for Package Manager and Install Dependencies
echo "[1/10] Checking for missing dependencies..."

# List of official packages
PKGS="xfce4 xfce4-goodies xfce4-whiskermenu-plugin pavucontrol zsh git noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-dejavu ttf-liberation ttf-freefont pipewire pipewire-alsa pipewire-pulse wireplumber kitty fastfetch"
# List of AUR packages
AUR_PKGS="ttf-bigblue-terminal"

# Function to check and install packages
install_packages() {
    if command -v pacman &> /dev/null; then
        echo "Updating system and installing base packages..."
        sudo pacman -Syu --needed --noconfirm $PKGS
    else
        echo "Pacman not found. Please ensure dependencies are installed manually."
    fi
}

install_aur_packages() {
    local helper=""
    if command -v yay &> /dev/null; then helper="yay";
    elif command -v paru &> /dev/null; then helper="paru";
    fi

    if [ -z "$helper" ]; then
        echo "No AUR helper found. Would you like to install 'yay'? (y/n)"
        read -r install_yay
        if [[ "$install_yay" =~ ^[Yy]$ ]]; then
            echo "Bootstrapping 'yay'..."
            sudo pacman -S --needed --noconfirm base-devel git
            git clone https://aur.archlinux.org/yay.git /tmp/yay
            (cd /tmp/yay && makepkg -si --noconfirm)
            rm -rf /tmp/yay
            helper="yay"
        else
            echo "Skipping AUR packages."
            return
        fi
    fi

    echo "Installing AUR packages using $helper..."
    $helper -S --needed --noconfirm $AUR_PKGS
}

install_packages
install_aur_packages

# 2. Create directories
echo "[2/10] Preparing directory structure..."
mkdir -p ~/.config/xfce4/xfconf/xfce-perchannel-xml/
mkdir -p ~/.config/xfce4/panel/
mkdir -p ~/.config/fastfetch/
mkdir -p ~/.config/kitty/
mkdir -p ~/.themes/
mkdir -p ~/.local/share/icons/
mkdir -p ~/.local/share/fonts/
mkdir -p ~/Pictures/Wallpapers/
mkdir -p ~/.config/autostart/

# 3. Deploy configuration assets
echo "[3/10] Deploying configuration assets..."
cp -v "$SCRIPT_DIR"/xfconf/*.xml ~/.config/xfce4/xfconf/xfce-perchannel-xml/
cp -rv "$SCRIPT_DIR"/panel/* ~/.config/xfce4/panel/
cp -v "$SCRIPT_DIR"/fastfetch/config.jsonc ~/.config/fastfetch/
[ -f "$SCRIPT_DIR"/kitty/kitty.conf ] && cp -v "$SCRIPT_DIR"/kitty/kitty.conf ~/.config/kitty/
cp -rv "$SCRIPT_DIR"/themes/* ~/.themes/
cp -rv "$SCRIPT_DIR"/icons/* ~/.local/share/icons/
cp -rv "$SCRIPT_DIR"/fonts/* ~/.local/share/fonts/
cp -v "$SCRIPT_DIR"/wallpapers/* ~/Pictures/Wallpapers/

# 4. Sanitize Username in XMLs
echo "[4/10] Localizing configuration for user '$NEW_USER'..."
find ~/.config/xfce4/xfconf/xfce-perchannel-xml/ -type f -name "*.xml" -exec sed -i "s/$PLACEHOLDER/$NEW_USER/g" {} +

# 5. Configure Fontconfig for Thai
echo "[5/10] Setting up Thai font preferences (Sarabun)..."
mkdir -p ~/.config/fontconfig
cat > ~/.config/fontconfig/fonts.conf <<FOF
<?xml version="1.1"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <alias>
    <family>serif</family>
    <prefer><family>Sarabun</family></prefer>
  </alias>
  <alias>
    <family>sans-serif</family>
    <prefer><family>Sarabun</family></prefer>
  </alias>
  <alias>
    <family>monospace</family>
    <prefer><family>Sarabun</family></prefer>
  </alias>
  <match target="pattern">
    <test name="lang" compare="contains">
      <string>th</string>
    </test>
    <edit name="family" mode="prepend" binding="strong">
      <string>Sarabun</string>
    </edit>
  </match>
</fontconfig>
FOF

# 6. Apply System Shell and Wallpaper
echo "[6/10] Applying shell and wallpaper settings..."
if [ "$SHELL" != "$(which zsh)" ]; then
    echo "Changing default shell to Zsh... (Authentication required)"
    sudo chsh -s "$(which zsh)" "$NEW_USER"
fi

# Apply current wallpaper
DEFAULT_WALLPAPER="/home/$NEW_USER/Pictures/Wallpapers/90278.jpg"
for prop in $(xfconf-query -c xfce4-desktop -l | grep last-image); do
    xfconf-query -c xfce4-desktop -p "$prop" -s "$DEFAULT_WALLPAPER"
done

# 7. Apply Themes (GTK, Icons, XFWM4)
echo "[7/10] Applying system themes..."
xfconf-query -c xsettings -p /Net/ThemeName -s "custom"
xfconf-query -c xsettings -p /Net/IconThemeName -s "SE98"
xfconf-query -c xfwm4 -p /general/theme -s "custom_WM"

# Set Kitty as preferred terminal
if command -v xfce4-mime-helper &> /dev/null; then
    echo "Setting Kitty as preferred terminal..."
    xfce4-mime-helper --apply TerminalEmulator kitty
fi

# Detect and Apply Terminal Font (for xfce4-terminal)
CURRENT_FONT="BigBlueTerm437 Nerd Font Mono 12"
echo "Applying terminal font: $CURRENT_FONT"
xfconf-query -c xfce4-terminal -p /font-name -n -t string -s "$CURRENT_FONT"
xfconf-query -c xfce4-terminal -p /font-use-system -n -t bool -s false

# 8. Zsh Configuration
echo "[8/10] Deploying Zsh configuration..."
cp -v "$SCRIPT_DIR"/zsh/.zshrc ~/.zshrc
cp -v "$SCRIPT_DIR"/zsh/.p10k.zsh ~/.p10k.zsh

# 9. Apply settings
echo "[9/10] Reloading configuration services..."
pkill xfconfd || true
fc-cache -fv
(xfce4-panel --restart &>/dev/null &)

# 10. Finalizing
echo "[10/10] Done!"
echo "--------------------------------------------------"
echo " Installation complete! "
echo "--------------------------------------------------"
