#!/bin/bash
# syncfiles — Simple dotfile and config sync tool for macOS
# Uses rsync over SSH to securely sync local configuration files between devices.
# Usage:
#   syncfiles push -> upload local files to remote machine
#   syncfiles pull -> download remote files to local machine

set -euo pipefail
IFS=$'\n\t'

REMOTE_HOST="macbook.local" # Replace with the other Mac’s hostname or IP
REMOTE_USER="$USER" # Same username on both Macs (adjust if needed)
REMOTE_PATH="/Users/$REMOTE_USER/dotfiles-sync" # Remote sync directory
LOCAL_PATH="$HOME/.dotfiles" # Local folder to sync from/to

