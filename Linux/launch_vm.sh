#!/bin/bash

VM_NAME=$(sudo virsh list --all --name | grep -i "win")

# Logging setup
LOG_DIR="$HOME/.local/share/looking-glass-logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_FILE="$LOG_DIR/${VM_NAME}_lg.log"

echo "Launching $VM_NAME at $(date) " | tee -a "$LOG_FILE"

# Start VM if not running
echo "Starting VM $VM_NAME..." | tee -a "$LOG_FILE"
sudo virsh start "$VM_NAME" >/dev/null 2>&1 || echo "VM may already be running" | tee -a "$LOG_FILE"

# Wait until VM is running
until sudo virsh domstate "$VM_NAME" | grep -q running; do
    echo "Waiting for VM to run..." #| tee -a "$LOG_FILE"
    sleep 1
done
echo "VM $VM_NAME is running." | tee -a "$LOG_FILE"

# Launch Looking Glass
echo "Launching Looking Glass..." | tee -a "$LOG_FILE"
looking-glass-client \
    -m KEY_RIGHTCTRL \
    -n \
    wayland:fractionScale=yes \
    opengl:vsync=no \
    opengl:preventBuffer=yes \
    spice:showCursorDot=yes \
    input:autoCapture=yes \
    input:captureOnly=yes \
	spice:clipboard \
    2>&1 | tee -a "$LOG_FILE"

echo "Session over" | tee -a "$LOG_FILE"

