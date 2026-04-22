#!/bin/bash

# Nashville96 XFCE Configuration Updater
# This script fetches the latest changes from GitHub and re-applies the configuration.

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo "--------------------------------------------------"
echo " Nashville96 XFCE configuration update "
echo "--------------------------------------------------"

# 1. Pull latest changes from Git
if [ -d "$SCRIPT_DIR/.git" ]; then
    echo "[1/4] Fetching latest changes from GitHub..."
    
    # Check for uncommitted changes
    if ! git -C "$SCRIPT_DIR" diff-index --quiet HEAD --; then
        echo "Warning: You have uncommitted changes in $SCRIPT_DIR."
        echo "Stashing changes before pulling..."
        git -C "$SCRIPT_DIR" stash
        STASHED=true
    fi
    
    git -C "$SCRIPT_DIR" pull
    
    if [ "$STASHED" = true ]; then
        echo "Re-applying stashed changes..."
        git -C "$SCRIPT_DIR" stash pop || echo "Conflict detected while popping stash. Please resolve manually."
    fi
else
    echo "[1/4] Not a git repository. Skipping fetch."
fi

# 2. Re-apply configuration assets
echo "[2/4] Re-applying configuration assets..."

NEW_USER=$(whoami)
PLACEHOLDER="@USERNAME@"

# Ensure directories exist
mkdir -p ~/.config/xfce4/xfconf/xfce-perchannel-xml/
mkdir -p ~/.config/xfce4/panel/
mkdir -p ~/.config/fastfetch/
mkdir -p ~/.config/kitty/
mkdir -p ~/.themes/
mkdir -p ~/.local/share/icons/
mkdir -p ~/.local/share/fonts/
mkdir -p ~/Pictures/Wallpapers/

# Sync files (excluding keyboard shortcuts to preserve user customizations)
for file in "$SCRIPT_DIR"/xfconf/*.xml; do
    filename=$(basename "$file")
    if [ "$filename" != "xfce4-keyboard-shortcuts.xml" ]; then
        cp -v "$file" ~/.config/xfce4/xfconf/xfce-perchannel-xml/
    else
        echo "Skipping $filename to preserve your custom shortcut keys."
    fi
done
cp -rv "$SCRIPT_DIR"/panel/* ~/.config/xfce4/panel/
cp -v "$SCRIPT_DIR"/fastfetch/config.jsonc ~/.config/fastfetch/
[ -f "$SCRIPT_DIR"/kitty/kitty.conf ] && cp -v "$SCRIPT_DIR"/kitty/kitty.conf ~/.config/kitty/
cp -rv "$SCRIPT_DIR"/themes/* ~/.themes/
cp -rv "$SCRIPT_DIR"/icons/* ~/.local/share/icons/
cp -rv "$SCRIPT_DIR"/fonts/* ~/.local/share/fonts/
cp -v "$SCRIPT_DIR"/wallpapers/* ~/Pictures/Wallpapers/

# Localize configuration for the current user
echo "Localizing configuration for user '$NEW_USER'..."
find ~/.config/xfce4/xfconf/xfce-perchannel-xml/ -type f -name "*.xml" -exec sed -i "s/$PLACEHOLDER/$NEW_USER/g" {} +

# Re-apply Zsh configuration
cp -v "$SCRIPT_DIR"/zsh/.zshrc ~/.zshrc
cp -v "$SCRIPT_DIR"/zsh/.p10k.zsh ~/.p10k.zsh

# 3. Ensure theme settings are applied
echo "[3/4] Ensuring themes are applied..."
xfconf-query -c xsettings -p /Net/ThemeName -s "custom" || true
xfconf-query -c xsettings -p /Net/IconThemeName -s "SE98" || true
xfconf-query -c xfwm4 -p /general/theme -s "custom_WM" || true

# 4. Reload services
echo "[4/4] Reloading configuration services..."
pkill xfconfd || true
fc-cache -fv
(xfce4-panel --restart &>/dev/null &)

echo "--------------------------------------------------"
echo " Update successful! "
echo "--------------------------------------------------"
