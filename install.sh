#!/bin/bash

# Petty-Xfce4 Installer
# Works for any user on Arch-based systems

set -e

# colors
declare -g RED="" GREEN="" BLUE="" YELLOW="" BOLD="" RESET=""
if [[ -t 1 ]]; then
    RED=$'\e[1;31m' GREEN=$'\e[1;32m' YELLOW=$'\e[1;33m' BLUE=$'\e[1;34m' BOLD=$'\e[1m' RESET=$'\e[0m'
fi

# log
declare -i SUCCESS_COUNT=0
declare -i WARN_COUNT=0
declare -i ERROR_COUNT=0

log() {
    local level="$1" msg="$2" color=""
    case "$level" in 
        INFO) color="$BLUE" ;; 
        SUCCESS) color="$GREEN"; SUCCESS_COUNT+=1 ;; 
        WARN) color="$YELLOW"; WARN_COUNT+=1 ;; 
        ERROR) color="$RED"; ERROR_COUNT+=1 ;; 
        RUN) color="$BOLD" ;; 
    esac
    printf "%s[%s]%s %s\n" "${color}" "${level}" "${RESET}" "${msg}"
}

# env
NEW_USER=$(whoami)
PLACEHOLDER="@USERNAME@"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# sync from github
if [ -d "$SCRIPT_DIR/.git" ]; then
    log INFO "Checking for updates from GitHub..."
    if ! git -C "$SCRIPT_DIR" diff-index --quiet HEAD --; then
        log WARN "Local changes detected, stashing..."
        git -C "$SCRIPT_DIR" stash
        STASHED=true
    fi
    if git -C "$SCRIPT_DIR" pull; then
        log SUCCESS "Project updated from GitHub."
    else
        log WARN "Failed to pull from GitHub. Continuing with local files."
    fi
    [ "$STASHED" = true ] && git -C "$SCRIPT_DIR" stash pop
fi

clear
echo -e "${BLUE}================================================================${RESET}"
echo -e "${BOLD}       PETTY-XFCE4 CONFIGURATION ORCHESTRATOR       ${RESET}"
echo -e "${BLUE}================================================================${RESET}"
log INFO "Initializing deployment for user: ${NEW_USER}"

# deps
log INFO "Checking dependencies..."
PKGS="xfce4 xfce4-goodies xfce4-whiskermenu-plugin pavucontrol zsh git noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-dejavu ttf-liberation ttf-freefont pipewire pipewire-alsa pipewire-pulse wireplumber kitty fastfetch vulkan-icd-loader lib32-vulkan-icd-loader linux-headers ananicy-cpp viewnior mpv yt-dlp bluez bluez-utils blueman networkmanager network-manager-applet tlp xfce4-power-manager neovim xfce4-volumed-pulse ufw"
AUR_PKGS="ttf-bigblue-terminal cachyos-ananicy-rules"

install_packages() {
    log INFO "Synchronizing package databases..."
    sudo pacman -Sy
    
    log RUN "Installing base packages (this may take a while)..."
    # Split into logical groups for better error tracking
    local CORE_PKGS="xfce4 xfce4-goodies xfce4-whiskermenu-plugin pavucontrol zsh git"
    local FONT_PKGS="noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-dejavu ttf-liberation ttf-freefont"
    local AUDIO_PKGS="pipewire pipewire-alsa pipewire-pulse wireplumber xfce4-volumed-pulse"
    local UTIL_PKGS="kitty fastfetch viewnior mpv yt-dlp neovim"
    local NET_BT_PKGS="bluez bluez-utils blueman networkmanager network-manager-applet"
    local VOL_PKGS="gvfs gvfs-mtp gvfs-afc udisks2 ntfs-3g dosfstools exfatprogs libmtp"
    local OPT_PKGS="vulkan-icd-loader lib32-vulkan-icd-loader linux-headers ananicy-cpp tlp xfce4-power-manager ufw"

    for group in "$CORE_PKGS" "$FONT_PKGS" "$AUDIO_PKGS" "$UTIL_PKGS" "$NET_BT_PKGS" "$VOL_PKGS" "$OPT_PKGS"; do
        if sudo pacman -S --needed --noconfirm $group; then
            log SUCCESS "Installed package group: $(echo $group | cut -d' ' -f1-2)..."
        else
            log WARN "Some packages in group failed to install."
        fi
    done
}

install_aur_packages() {
    local helper=""
    if command -v yay &> /dev/null; then helper="yay"; elif command -v paru &> /dev/null; then helper="paru"; fi

    if [ -z "$helper" ]; then
        log WARN "No AUR helper found."
        echo -n "Install 'yay'? (y/n): "
        read -r install_yay
        if [[ "$install_yay" =~ ^[Yy]$ ]]; then
            log RUN "Bootstrapping 'yay'..."
            sudo pacman -S --needed --noconfirm base-devel git
            git clone https://aur.archlinux.org/yay.git /tmp/yay
            (cd /tmp/yay && makepkg -si --noconfirm)
            rm -rf /tmp/yay
            helper="yay"
        else
            log INFO "Skipping AUR packages."
            return
        fi
    fi
    log RUN "Installing AUR packages..."
    if $helper -S --needed --noconfirm $AUR_PKGS; then
        log SUCCESS "AUR packages installed."
    else
        log WARN "AUR package installation failed."
    fi
}

install_packages
install_aur_packages

# services
log RUN "Enabling services..."
for service in ananicy-cpp bluetooth NetworkManager tlp ufw; do
    if systemctl list-unit-files | grep -q "^${service}.service"; then
        if sudo systemctl enable --now "$service"; then
            log SUCCESS "Service ${service} enabled and started."
        else
            log WARN "Failed to enable service ${service}."
        fi
    else
        log WARN "Service ${service} not found. Package might not be installed."
    fi
done

# firewall
if command -v ufw &> /dev/null; then
    log INFO "Configuring UFW firewall..."
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    sudo ufw --force enable
    log SUCCESS "UFW firewall configured and enabled."
fi

# power & input
log INFO "Configuring power & input..."
xfconf-query -c pointers -p /$(xfconf-query -c pointers -l | grep -i touchpad | head -n 1)/TapToClick -n -t bool -s true || log WARN "Touchpad not found."

# dirs
log INFO "Preparing directories..."
mkdir -p ~/.config/xfce4/xfconf/xfce-perchannel-xml/ ~/.config/xfce4/panel/ ~/.config/fastfetch/ ~/.config/kitty/ ~/.themes/ ~/.local/share/icons/ ~/.local/share/fonts/ ~/Pictures/Wallpapers/ ~/.config/autostart/

# assets
log INFO "Deploying assets..."
cp -v "$SCRIPT_DIR"/xfconf/*.xml ~/.config/xfce4/xfconf/xfce-perchannel-xml/
cp -rv "$SCRIPT_DIR"/panel/* ~/.config/xfce4/panel/
cp -v "$SCRIPT_DIR"/fastfetch/config.jsonc ~/.config/fastfetch/
[ -f "$SCRIPT_DIR"/kitty/kitty.conf ] && cp -v "$SCRIPT_DIR"/kitty/kitty.conf ~/.config/kitty/
mkdir -p ~/.config/nvim
cp -rv "$SCRIPT_DIR"/nvim/* ~/.config/nvim/
cp -rv "$SCRIPT_DIR"/themes/* ~/.themes/
cp -rv "$SCRIPT_DIR"/icons/* ~/.local/share/icons/
cp -rv "$SCRIPT_DIR"/fonts/* ~/.local/share/fonts/
cp -v "$SCRIPT_DIR"/wallpapers/* ~/Pictures/Wallpapers/
[ -d "$SCRIPT_DIR"/autostart ] && cp -rv "$SCRIPT_DIR"/autostart/* ~/.config/autostart/
log SUCCESS "Assets deployed to home directory."

# optimization
log INFO "Applying system optimizations..."
if [ -d "$SCRIPT_DIR"/etc/sysctl.d ]; then
    sudo cp -v "$SCRIPT_DIR"/etc/sysctl.d/*.conf /etc/sysctl.d/ && log SUCCESS "Kernel parameters (sysctl) deployed."
fi

if [ -f "$SCRIPT_DIR"/etc/udev/rules.d/60-ioschedulers.rules ]; then
    sudo cp -v "$SCRIPT_DIR"/etc/udev/rules.d/60-ioschedulers.rules /etc/udev/rules.d/ && log SUCCESS "I/O Scheduler rules deployed."
fi

if [ -f "$SCRIPT_DIR"/etc/tmpfiles.d/cpu-performance.conf ]; then
    sudo cp -v "$SCRIPT_DIR"/etc/tmpfiles.d/cpu-performance.conf /etc/tmpfiles.d/ && log SUCCESS "CPU performance profiles deployed."
fi

# gpu
if lspci | grep -qi "NVIDIA"; then
    log SUCCESS "NVIDIA GPU detected."
    if [ -f "$SCRIPT_DIR"/etc/systemd/system/nvidia-persistence.service ]; then
        sudo cp -v "$SCRIPT_DIR"/etc/systemd/system/nvidia-persistence.service /etc/systemd/system/
        sudo systemctl enable --now nvidia-persistence.service && log SUCCESS "NVIDIA persistence mode enabled."
    fi
fi

log RUN "Triggering system changes..."
sudo sysctl --system > /dev/null
sudo udevadm control --reload-rules && sudo udevadm trigger
log SUCCESS "System optimizations and hardware triggers live."

# localization
log RUN "Localizing for $NEW_USER..."
find ~/.config/xfce4/xfconf/xfce-perchannel-xml/ -type f -name "*.xml" -exec sed -i "s/$PLACEHOLDER/$NEW_USER/g" {} +
log SUCCESS "Configuration files localized for $NEW_USER."

# fonts
log INFO "Font config..."
mkdir -p ~/.config/fontconfig
cat > ~/.config/fontconfig/fonts.conf <<FOF
<?xml version="1.1"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <alias><family>serif</family><prefer><family>Sarabun</family></prefer></alias>
  <alias><family>sans-serif</family><prefer><family>Sarabun</family></prefer></alias>
  <alias><family>monospace</family><prefer><family>BigBlueTerm437 Nerd Font Mono</family><family>Sarabun</family></prefer></alias>
  <match target="pattern"><test name="lang" compare="contains"><string>th</string></test><edit name="family" mode="prepend" binding="strong"><string>Sarabun</string></edit></match>
</fontconfig>
FOF

# settings
log RUN "Applying settings..."
[ "$SHELL" != "$(which zsh)" ] && sudo chsh -s "$(which zsh)" "$NEW_USER"

DEFAULT_WALLPAPER="/home/$NEW_USER/Pictures/Wallpapers/90278.jpg"
for prop in $(xfconf-query -c xfce4-desktop -l | grep last-image); do
    xfconf-query -c xfce4-desktop -p "$prop" -s "$DEFAULT_WALLPAPER"
done

xfconf-query -c xsettings -p /Net/ThemeName -s "custom"
xfconf-query -c xsettings -p /Net/IconThemeName -s "SE98"
xfconf-query -c xfwm4 -p /general/theme -s "custom_WM"

# Set default terminal
xfconf-query -c xfce4-mime-helper -p /TerminalEmulator -n -t string -s "kitty" || log WARN "Failed to set default terminal."

# terminal
log INFO "Terminal config..."
mkdir -p ~/.config/kitty
cat > ~/.config/kitty/kitty.conf <<KCF
font_family      BigBlueTerm437 Nerd Font Mono
font_size        12.0
background_opacity 0.9
KCF

# mimes
log INFO "Mime defaults..."
xdg-mime default nvim.desktop text/plain
xdg-mime default viewnior.desktop image/jpeg image/png image/gif image/bmp image/webp
xdg-mime default mpv.desktop video/mp4 video/x-matroska video/x-flv video/webm video/quicktime audio/mpeg audio/x-wav audio/ogg

# terminal font
CURRENT_FONT="BigBlueTerm437 Nerd Font Mono 12"
xfconf-query -c xfce4-terminal -p /font-name -n -t string -s "$CURRENT_FONT"
xfconf-query -c xfce4-terminal -p /font-use-system -n -t bool -s false

# shell
log INFO "Shell config..."
cp -v "$SCRIPT_DIR"/zsh/.zshrc ~/.zshrc
cp -v "$SCRIPT_DIR"/zsh/.p10k.zsh ~/.p10k.zsh

# reload
log RUN "Reloading..."
pkill xfconfd || true
fc-cache -fv
(xfce4-panel --restart &>/dev/null &)

# summary
echo -e "\n${BLUE}================================================================${RESET}"
echo -e "${BOLD}                     ORCHESTRATION SUMMARY                      ${RESET}"
echo -e "${BLUE}================================================================${RESET}"
[ $SUCCESS_COUNT -gt 0 ] && echo -e "${GREEN}  SUCCESSES: $SUCCESS_COUNT${RESET}"
[ $WARN_COUNT -gt 0 ] && echo -e "${YELLOW}  WARNINGS:  $WARN_COUNT${RESET}"
[ $ERROR_COUNT -gt 0 ] && echo -e "${RED}  ERRORS:    $ERROR_COUNT${RESET}"
echo -e "${BLUE}================================================================${RESET}"

if [ $ERROR_COUNT -eq 0 ]; then
    echo -e "${GREEN}${BOLD}FINISHED SUCCESSFULLY!${RESET}"
else
    echo -e "${YELLOW}${BOLD}FINISHED WITH $ERROR_COUNT ERRORS.${RESET}"
fi

