#!/bin/bash

# Nashville96 Updater
# Pulls latest changes and re-applies config

set -e
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo "--- Nashville96 Update ---"

# 1. pull
if [ -d "$SCRIPT_DIR/.git" ]; then
    echo "[1/4] Fetching..."
    if ! git -C "$SCRIPT_DIR" diff-index --quiet HEAD --; then
        echo "Stashing local changes..."
        git -C "$SCRIPT_DIR" stash
        STASHED=true
    fi
    git -C "$SCRIPT_DIR" pull
    [ "$STASHED" = true ] && git -C "$SCRIPT_DIR" stash pop
else
    echo "[1/4] Not a git repo, skipping fetch."
fi

# 2. sync
echo "[2/4] Syncing assets..."
NEW_USER=$(whoami)
PLACEHOLDER="@USERNAME@"

mkdir -p ~/.config/xfce4/xfconf/xfce-perchannel-xml/ ~/.config/xfce4/panel/ ~/.config/fastfetch/ ~/.config/kitty/ ~/.themes/ ~/.local/share/icons/ ~/.local/share/fonts/ ~/Pictures/Wallpapers/

for file in "$SCRIPT_DIR"/xfconf/*.xml; do
    [ "$(basename "$file")" != "xfce4-keyboard-shortcuts.xml" ] && cp -v "$file" ~/.config/xfce4/xfconf/xfce-perchannel-xml/
done

cp -rv "$SCRIPT_DIR"/panel/* ~/.config/xfce4/panel/
cp -v "$SCRIPT_DIR"/fastfetch/config.jsonc ~/.config/fastfetch/
[ -f "$SCRIPT_DIR"/kitty/kitty.conf ] && cp -v "$SCRIPT_DIR"/kitty/kitty.conf ~/.config/kitty/
mkdir -p ~/.config/nvim
cp -rv "$SCRIPT_DIR"/nvim/* ~/.config/nvim/
cp -rv "$SCRIPT_DIR"/themes/* ~/.themes/
cp -rv "$SCRIPT_DIR"/icons/* ~/.local/share/icons/
cp -rv "$SCRIPT_DIR"/fonts/* ~/.local/share/fonts/
cp -v "$SCRIPT_DIR"/wallpapers/* ~/Pictures/Wallpapers/

# localise
echo "Localizing for $NEW_USER..."
find ~/.config/xfce4/xfconf/xfce-perchannel-xml/ -type f -name "*.xml" -exec sed -i "s/$PLACEHOLDER/$NEW_USER/g" {} +

# shell
cp -v "$SCRIPT_DIR"/zsh/.zshrc ~/.zshrc
cp -v "$SCRIPT_DIR"/zsh/.p10k.zsh ~/.p10k.zsh

# 3. themes
echo "[3/4] Theme settings..."
xfconf-query -c xsettings -p /Net/ThemeName -s "custom" || true
xfconf-query -c xsettings -p /Net/IconThemeName -s "SE98" || true
xfconf-query -c xfwm4 -p /general/theme -s "custom_WM" || true

# 4. reload
echo "[4/4] Reloading..."
pkill xfconfd || true
fc-cache -fv
(xfce4-panel --restart &>/dev/null &)

echo "--- Update Success ---"
