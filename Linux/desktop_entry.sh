#! /bin/bash

VM_NAME=$(sudo virsh list --all --name | grep -i "win")
DIR="$(dirname $(realpath $0))"
TARGET="$HOME/.local/share/applications/looking-glass-${VM_NAME}.desktop"
ICON_TARGET="$HOME/.local/share/icons/looking-glass-${VM_NAME}.svg"
LAUNCHER_TARGET="$HOME/.local/bin/looking-glass-${VM_NAME}.sh"

if [[ -f "$TARGET" ]]; then
    read -p "File '$TARGET' already exists. Overwrite? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        exit 1
    fi
fi

mkdir -p "$(dirname "$TARGET")"
mkdir -p "$(dirname "$LAUNCHER_TARGET")"
mkdir -p "$(dirname "$ICON_TARGET")"
cp -f "$DIR/logo.svg" "$ICON_TARGET"
cp -f "$DIR/launch_vm.sh" "$LAUNCHER_TARGET"
# rsvg-convert -w 48 -h 48 "$ICON" -o "$ICON_TARGET.xmp"
# chmod 777 "$ICON_TARGET.xmp"

# black magic with rev: https://unix.stackexchange.com/a/617832
echo "
[Desktop Entry]
Name=Windows 11 (Looking Glass)
Comment=Launch Windows 11 VM with Looking Glass
Exec=$LAUNCHER_TARGET
Icon=$(realpath $ICON_TARGET |rev| cut -d"." -f2- |rev)
Terminal=false
Type=Application
Categories=System;Emulator;
StartupNotify=true
StartupWMClass=looking-glass-client
" | tee $TARGET > /dev/null 2>&1

chmod +x "$TARGET"
chmod +x "$LAUNCHER_TARGET"

# Passwordless sudo configuration for virsh (optional)
echo "To allow passwordless VM start/shutdown, run:"
echo "sudo EDITOR=vim visudo"
echo "Then add the line:"
echo "$USERNAME ALL=(root) NOPASSWD: /usr/bin/virsh"

echo "Setup complete! You can now launch Windows 11 via your application menu."

