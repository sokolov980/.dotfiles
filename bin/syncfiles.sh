#!/bin/bash
# syncfiles — Simple dotfile and config sync tool for macOS
# Uses rsync over SSH to securely sync local configuration files between devices.

set -euo pipefail
IFS=$'\n\t'

# Config Loading (Optional ~/.syncfiles.conf)
# ---------------------------------------------------------------------------

CONFIG_FILE="$HOME/.syncfiles.conf"

load_config() {
  if [ -f "$CONFIG_FILE" ]; then
    echo "Loading config from $CONFIG_FILE"
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
  fi
}

load_config

# ---------------------------------------------------------------------------
# Default Settings (Overridden if config file sets these variables)
# ---------------------------------------------------------------------------

REMOTE_HOST="${REMOTE_HOST:-macbook.local}"
REMOTE_USER="${REMOTE_USER:-$USER}"
REMOTE_PATH="${REMOTE_PATH:-/Users/$REMOTE_USER/dotfiles-sync}"
LOCAL_PATH="${LOCAL_PATH:-$HOME/.dotfiles}"

LOCAL_DIR="$LOCAL_PATH"
REMOTE_DIR="$REMOTE_PATH"

LOG_FILE="$HOME/.dotfiles_sync.log"

# ---------------------------------------------------------------------------
# Logging Utility
# ---------------------------------------------------------------------------

log() {
  local message="$1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" | tee -a "$LOG_FILE"
}

# ---------------------------------------------------------------------------
# Environment Validation
# ---------------------------------------------------------------------------

check_ssh() {
  echo "Testing SSH connection to $REMOTE_HOST..."
  if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$REMOTE_USER@$REMOTE_HOST" true 2>/dev/null; then
    echo "Error: Cannot connect to $REMOTE_HOST via SSH"
    exit 1
  fi
}

ensure_dirs() {
  echo "Checking sync directories..."

  if [ ! -d "$LOCAL_DIR" ]; then
    echo "Local directory missing, creating $LOCAL_DIR"
    mkdir -p "$LOCAL_DIR"
  fi

  ssh "$REMOTE_USER@$REMOTE_HOST" "mkdir -p '$REMOTE_DIR'"
}

# ---------------------------------------------------------------------------
# Rsync Flags
# ---------------------------------------------------------------------------

RSYNC_BASE="-avh --progress --exclude=.git/ --exclude=node_modules/ --exclude=.DS_Store"
RSYNC_FLAGS="$RSYNC_BASE"
RSYNC_FLAGS_DELETE="$RSYNC_BASE --delete"

# ---------------------------------------------------------------------------
# Confirmation Prompt
# ---------------------------------------------------------------------------

confirm() {
  local prompt="$1"
  read -rp "$prompt [y/N]: " ans
  if [[ "$ans" != "y" && "$ans" != "Y" ]]; then
    echo "Aborted."
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Sync Operations
# ---------------------------------------------------------------------------

push_dotfiles() {
  echo "Pushing dotfiles to $REMOTE_HOST..."
  rsync $RSYNC_FLAGS_DELETE \
    "$LOCAL_DIR/" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/"
  echo "Dotfiles pushed successfully."
}

pull_dotfiles() {
  echo "Pulling dotfiles from $REMOTE_HOST..."
  rsync $RSYNC_FLAGS_DELETE \
    "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/" "$LOCAL_DIR/"
  echo "Dotfiles pulled successfully."
}

preview_changes() {
  echo "Previewing changes..."
  rsync -avhn --delete \
    --exclude=".git/" \
    --exclude="node_modules/" \
    --exclude=".DS_Store" \
    "$LOCAL_DIR/" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/"
}

diff_changes() {
  echo "Listing changed files (dry run)..."
  rsync -avhn --delete \
    --exclude=".git/" \
    --exclude="node_modules/" \
    --exclude=".DS_Store" \
    "$LOCAL_DIR/" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/" \
    | sed '1,3d'
}

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

show_usage() {
  echo "Usage: $0 [push|pull|preview|diff|help]"
  echo "  push     - Upload local dotfiles to remote"
  echo "  pull     - Download dotfiles from remote"
  echo "  preview  - Show rsync preview including deletions"
  echo "  diff     - Clean diff of changed files"
  echo "  help     - Show this help message"
}

# ---------------------------------------------------------------------------
# Command Handler
# ---------------------------------------------------------------------------

if [ "$#" -eq 0 ]; then
  show_usage
  exit 1
fi

command="$1"

check_ssh
ensure_dirs

case "$command" in
  push)
    confirm "This will overwrite remote files with local copies. Continue?"
    log "Pushing dotfiles to remote..."
    push_dotfiles
    log "Push complete."
    ;;
  pull)
    confirm "This will overwrite local files with remote copies. Continue?"
    log "Pulling dotfiles from remote..."
    pull_dotfiles
    log "Pull complete."
    ;;
  preview)
    preview_changes
    ;;
  diff)
    diff_changes
    ;;
  help|*)
    show_usage
    ;;
esac
