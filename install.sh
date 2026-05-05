#!/bin/bash

# ==============================================================================
# PETTY-XFCE4 CONFIGURATION ORCHESTRATOR
# ==============================================================================
# Portability: Works for any user on Arch-based systems
# Style Inspired by: dusklinux/dusky ORCHESTRA

set -e

# 1. Colors
declare -g RED="" GREEN="" BLUE="" YELLOW="" BOLD="" RESET=""

if [[ -t 1 ]]; then
    RED=$'\e[1;31m'
    GREEN=$'\e[1;32m'
    YELLOW=$'\e[1;33m'
    BLUE=$'\e[1;34m'
    BOLD=$'\e[1m'
    RESET=$'\e[0m'
fi

# 2. Logging Function
log() {
    local level="$1"
    local msg="$2"
    local color=""

    case "$level" in
        INFO)    color="$BLUE" ;;
        SUCCESS) color="$GREEN" ;;
        WARN)    color="$YELLOW" ;;
        ERROR)   color="$RED" ;;
        RUN)     color="$BOLD" ;;
    esac

    printf "%s[%s]%s %s\n" "${color}" "${level}" "${RESET}" "${msg}"
}

# 3. Environment Setup
NEW_USER=$(whoami)
PLACEHOLDER="@USERNAME@"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

clear
echo -e "${BLUE}================================================================${RESET}"
echo -e "${BOLD}       PETTY-XFCE4 CONFIGURATION ORCHESTRATOR       ${RESET}"
echo -e "${BLUE}================================================================${RESET}"
log INFO "Initializing deployment for user: ${NEW_USER}"

# 4. Dependency Management
log INFO "Checking for missing dependencies..."

# List of official packages
PKGS="xfce4 xfce4-goodies xfce4-whiskermenu-plugin pavucontrol zsh git noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-dejavu ttf-liberation ttf-freefont pipewire pipewire-alsa pipewire-pulse wireplumber kitty fastfetch vulkan-icd-loader lib32-vulkan-icd-loader linux-headers ananicy-cpp viewnior mpv yt-dlp"
# List of AUR packages
AUR_PKGS="ttf-bigblue-terminal cachyos-ananicy-rules"

install_packages() {
    if command -v pacman &> /dev/null; then
        log RUN "Updating system and installing base packages..."
        sudo pacman -Syu --needed --noconfirm $PKGS
    else
        log ERROR "Pacman not found. Please ensure dependencies are installed manually."
        exit 1
    fi
}

install_aur_packages() {
    local helper=""
    if command -v yay &> /dev/null; then helper="yay";
    elif command -v paru &> /dev/null; then helper="paru";
    fi

    if [ -z "$helper" ]; then
        log WARN "No AUR helper found."
        echo -n "Would you like to install 'yay'? (y/n): "
        read -r install_yay
        if [[ "$install_yay" =~ ^[Yy]$ ]]; then
            log RUN "Bootstrapping 'yay'..."
            sudo pacman -S --needed --noconfirm base-devel git
            git clone https://aur.archlinux.org/yay.git /tmp/yay
            (cd /tmp/yay && makepkg -si --noconfirm)
            rm -rf /tmp/yay
            helper="yay"
        else
            log WARN "Skipping AUR packages."
            return
        fi
    fi

    log RUN "Installing AUR packages using $helper..."
    $helper -S --needed --noconfirm $AUR_PKGS
}

install_packages
install_aur_packages

log SUCCESS "Dependencies synchronized."

# 5. Enabling Services
log RUN "Enabling Ananicy-cpp..."
sudo systemctl enable --now ananicy-cpp

# 6. Directory Structure
log INFO "Preparing directory structure..."
mkdir -p ~/.config/xfce4/xfconf/xfce-perchannel-xml/
mkdir -p ~/.config/xfce4/panel/
mkdir -p ~/.config/fastfetch/
mkdir -p ~/.config/kitty/
mkdir -p ~/.themes/
mkdir -p ~/.local/share/icons/
mkdir -p ~/.local/share/fonts/
mkdir -p ~/Pictures/Wallpapers/
mkdir -p ~/.config/autostart/

# 7. Asset Deployment
log INFO "Deploying configuration assets..."
cp -v "$SCRIPT_DIR"/xfconf/*.xml ~/.config/xfce4/xfconf/xfce-perchannel-xml/
cp -rv "$SCRIPT_DIR"/panel/* ~/.config/xfce4/panel/
cp -v "$SCRIPT_DIR"/fastfetch/config.jsonc ~/.config/fastfetch/
[ -f "$SCRIPT_DIR"/kitty/kitty.conf ] && cp -v "$SCRIPT_DIR"/kitty/kitty.conf ~/.config/kitty/
cp -rv "$SCRIPT_DIR"/themes/* ~/.themes/
cp -rv "$SCRIPT_DIR"/icons/* ~/.local/share/icons/
cp -rv "$SCRIPT_DIR"/fonts/* ~/.local/share/fonts/
cp -v "$SCRIPT_DIR"/wallpapers/* ~/Pictures/Wallpapers/
[ -d "$SCRIPT_DIR"/autostart ] && cp -rv "$SCRIPT_DIR"/autostart/* ~/.config/autostart/

# Deploy System-level Optimizations (I/O, Network & GPU)
echo "Deploying system optimizations..."
[ -d "$SCRIPT_DIR"/etc/sysctl.d ] && sudo cp -v "$SCRIPT_DIR"/etc/sysctl.d/*.conf /etc/sysctl.d/
[ -f "$SCRIPT_DIR"/etc/udev/rules.d/60-ioschedulers.rules ] && sudo cp -v "$SCRIPT_DIR"/etc/udev/rules.d/60-ioschedulers.rules /etc/udev/rules.d/

# CPU Performance Optimization (Performance Governor & EPP)
log RUN "Optimizing CPU for high-performance gaming..."
[ -f "$SCRIPT_DIR"/etc/tmpfiles.d/cpu-performance.conf ] && sudo cp -v "$SCRIPT_DIR"/etc/tmpfiles.d/cpu-performance.conf /etc/tmpfiles.d/

# Smart GPU Detection for Performance Fixes
if lspci | grep -qi "NVIDIA"; then
    log SUCCESS "NVIDIA GPU detected. Applying specialized fixes..."
    if [ -f "$SCRIPT_DIR"/etc/systemd/system/nvidia-persistence.service ]; then
        sudo cp -v "$SCRIPT_DIR"/etc/systemd/system/nvidia-persistence.service /etc/systemd/system/
        sudo systemctl enable nvidia-persistence.service
    fi
    [ -d "$SCRIPT_DIR"/autostart ] && cp -rv "$SCRIPT_DIR"/autostart/* ~/.config/autostart/
else
    log INFO "Non-NVIDIA GPU detected. Skipping NVIDIA-specific tweaks."
fi

sudo sysctl --system
sudo udevadm control --reload-rules && sudo udevadm trigger

# 8. Localization & Personalization
log RUN "Localizing configuration for user '$NEW_USER'..."
find ~/.config/xfce4/xfconf/xfce-perchannel-xml/ -type f -name "*.xml" -exec sed -i "s/$PLACEHOLDER/$NEW_USER/g" {} +

log INFO "Setting up font preferences (BigBlue + Sarabun)..."
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
    <prefer>
      <family>BigBlueTerm437 Nerd Font Mono</family>
      <family>Sarabun</family>
    </prefer>
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

log RUN "Applying shell and wallpaper settings..."
if [ "$SHELL" != "$(which zsh)" ]; then
    log INFO "Changing default shell to Zsh... (Authentication required)"
    sudo chsh -s "$(which zsh)" "$NEW_USER"
fi

DEFAULT_WALLPAPER="/home/$NEW_USER/Pictures/Wallpapers/90278.jpg"
for prop in $(xfconf-query -c xfce4-desktop -l | grep last-image); do
    xfconf-query -c xfce4-desktop -p "$prop" -s "$DEFAULT_WALLPAPER"
done

log RUN "Applying system themes..."
xfconf-query -c xsettings -p /Net/ThemeName -s "custom"
xfconf-query -c xsettings -p /Net/IconThemeName -s "SE98"
xfconf-query -c xfwm4 -p /general/theme -s "custom_WM"

if command -v xfce4-mime-helper &> /dev/null; then
    log INFO "Setting Kitty as preferred terminal..."
    xfce4-mime-helper --apply TerminalEmulator kitty
fi

# Configure Kitty terminal font
log INFO "Configuring Kitty terminal font..."
mkdir -p ~/.config/kitty
cat > ~/.config/kitty/kitty.conf <<KCF
font_family      BigBlueTerm437 Nerd Font Mono
font_size        12.0
background_opacity 0.9
KCF

log INFO "Setting Viewnior and MPV as default multimedia viewers..."
xdg-mime default viewnior.desktop image/jpeg image/png image/gif image/bmp image/webp
xdg-mime default mpv.desktop video/mp4 video/x-matroska video/x-flv video/webm video/quicktime audio/mpeg audio/x-wav audio/ogg

CURRENT_FONT="BigBlueTerm437 Nerd Font Mono 12"
log INFO "Applying terminal font: $CURRENT_FONT"
xfconf-query -c xfce4-terminal -p /font-name -n -t string -s "$CURRENT_FONT"
xfconf-query -c xfce4-terminal -p /font-use-system -n -t bool -s false

# 9. Shell Configuration
log INFO "Deploying Zsh configuration..."
cp -v "$SCRIPT_DIR"/zsh/.zshrc ~/.zshrc
cp -v "$SCRIPT_DIR"/zsh/.p10k.zsh ~/.p10k.zsh

# 10. Finalizing
log RUN "Reloading configuration services..."
pkill xfconfd || true
fc-cache -fv
(xfce4-panel --restart &>/dev/null &)

echo -e "\n${GREEN}================================================================${RESET}"
log SUCCESS "Installation complete!"
echo -e "${BOLD}Enjoy your Nashville96 XFCE environment!${RESET}"
echo -e "${GREEN}================================================================${RESET}\n"
