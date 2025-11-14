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

LOCAL_DIR="$LOCAL_PATH"
REMOTE_DIR="$REMOTE_PATH"

ensure_dirs() {
  echo "Checking sync directories..."

  if [ ! -d "$LOCAL_DIR" ]; then
    echo "Local directory missing, creating $LOCAL_DIR"
    mkdir -p "$LOCAL_DIR"
  fi

  ssh "$REMOTE_USER@$REMOTE_HOST" "mkdir -p '$REMOTE_DIR'"
}

check_ssh() {
  echo "Testing SSH connection to $REMOTE_HOST..."
  if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$REMOTE_USER@$REMOTE_HOST" true 2>/dev/null; then
    echo "Error: Cannot connect to $REMOTE_HOST via SSH"
    exit 1
  fi
}

RSYNC_FLAGS="-avh --progress --exclude=.git/ --exclude=node_modules/ --exclude=.DS_Store"
RSYNC_FLAGS_DELETE="$RSYNC_FLAGS --delete"
rsync $RSYNC_FLAGS_DELETE ...

diff_changes() {
  echo "→ Listing changed files (dry run)..."
  rsync -avhn --delete \
    --exclude=".git/" \
    --exclude="node_modules/" \
    --exclude=".DS_Store" \
    "$LOCAL_DIR/" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/" | sed '1,3d'
}

confirm() {
  local prompt="$1"
  read -rp "$prompt [y/N]: " ans
  if [[ "$ans" != "y" && "$ans" != "Y" ]]; then
    echo "Aborted."
    exit 1
  fi
}

confirm "This will overwrite remote files with local copies. Continue?"

