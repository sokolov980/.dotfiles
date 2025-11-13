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

# Sync Logic

# Function: push local dotfiles to remote
push_dotfiles() {
  echo "→ Pushing dotfiles to $REMOTE_HOST..."
  rsync -avh --progress \
    --exclude=".git/" \
    --exclude="node_modules/" \
    --exclude=".DS_Store" \
    "$LOCAL_DIR/" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/"
  echo "Dotfiles pushed successfully."
}

# Function: pull dotfiles from remote
pull_dotfiles() {
  echo "→ Pulling dotfiles from $REMOTE_HOST..."
  rsync -avh --progress \
    --exclude=".git/" \
    --exclude="node_modules/" \
    --exclude=".DS_Store" \
    "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/" "$LOCAL_DIR/"
  echo "Dotfiles pulled successfully."
}

# Function: check for changes before syncing
preview_changes() {
  echo "→ Previewing changes between local and remote..."
  rsync -avhn --delete \
    --exclude=".git/" \
    --exclude="node_modules/" \
    --exclude=".DS_Store" \
    "$LOCAL_DIR/" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/"
}

# Command Handling & Logging

LOG_FILE="$HOME/.dotfiles_sync.log"

log() {
  local message="$1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" | tee -a "$LOG_FILE"
}

show_usage() {
  echo "Usage: $0 [push|pull|preview|help]"
  echo "  push     - Upload local dotfiles to remote"
  echo "  pull     - Download dotfiles from remote"
  echo "  preview  - Show what will change before syncing"
  echo "  help     - Show this help message"
}

case "$1" in
  push)
    log "Pushing dotfiles to remote..."
    push_dotfiles
    log "Push complete."
    ;;
  pull)
    log "Pulling dotfiles from remote..."
    pull_dotfiles
    log "Pull complete."
    ;;
  preview)
    preview_changes
    ;;
  help|*)
    show_usage
    ;;
esac
