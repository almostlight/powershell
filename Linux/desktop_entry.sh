#! /bin/bash

VM_NAME=$(sudo virsh list --all --name | grep -i "win")
DIR="$(dirname $(realpath $0))"
ICON_PATH="$DIR/logo.svg"
TARGET="$HOME/.local/share/applications/looking-glass-$VM_NAME.desktop"
LAUNCHER_SCRIPT="$HOME/.local/bin/launch_${VM_NAME}_lg.sh"

if [[ -f "$TARGET" ]]; then
    read -p "File '$TARGET' already exists. Overwrite? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        exit 1
    fi
fi

mkdir -p "$(dirname "$TARGET")"
mkdir -p "$(dirname "$LAUNCHER_SCRIPT")"

echo "
[Desktop Entry]
Name=Windows 11 (Looking Glass)
Comment=Launch Windows 11 VM with Looking Glass (auto-shutdown)
Icon=$ICON_PATH
Terminal=false
Type=Application
Categories=System;Emulator;
StartupNotify=true
Exec=$LAUNCHER_SCRIPT
" | tee $TARGET > /dev/null 2>&1

cp "$DIR/launch_vm.sh" $LAUNCHER_SCRIPT

sudo chmod +x "$TARGET"
chmod +x "$LAUNCHER_SCRIPT"

# Passwordless sudo configuration for virsh (optional)
echo "To allow passwordless VM start/shutdown, run:"
echo "sudo EDITOR=vim visudo"
echo "Then add the line:"
echo "$USERNAME ALL=(root) NOPASSWD: /usr/bin/virsh"

echo "Setup complete! You can now launch Windows 11 via your application menu."

