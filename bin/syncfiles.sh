#!/bin/bash
# syncfiles — Advanced dotfile and config sync tool for macOS/Linux/Windows (WSL)

set -euo pipefail
IFS=$'\n\t'

# Load optional config from ~/.syncfiles.conf
CONFIG_FILE="$HOME/.syncfiles.conf"
if [ -f "$CONFIG_FILE" ]; then
  echo "Loading config from $CONFIG_FILE"
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

# Default settings (can be overridden in config)
REMOTE_HOST="${REMOTE_HOST:-macbook.local}"
REMOTE_USER="${REMOTE_USER:-$USER}"
REMOTE_PATH="${REMOTE_PATH:-/Users/$REMOTE_USER/dotfiles-sync}"
LOCAL_PATH="${LOCAL_PATH:-$HOME/.dotfiles}"

LOCAL_DIR="$LOCAL_PATH"
REMOTE_DIR="$REMOTE_PATH"
LOG_FILE="$HOME/.dotfiles_sync.log"

# Optional exclude patterns from ~/.syncfiles_exclude
EXCLUDE_FILE="$HOME/.syncfiles_exclude"
EXCLUDES=""
if [ -f "$EXCLUDE_FILE" ]; then
  while IFS= read -r line; do
    EXCLUDES="$EXCLUDES --exclude=$line"
  done < "$EXCLUDE_FILE"
fi

# Logging functions with levels
log() {
  local level="$1"
  local message="$2"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp][$level] $message" | tee -a "$LOG_FILE"
}
info() { log "INFO" "$1"; }
warn() { log "WARN" "$1"; }
error() { log "ERROR" "$1"; }

# Ensure SSH keys exist and connection works
check_ssh() {
  if [ ! -f "$HOME/.ssh/id_rsa" ] && [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    error "No SSH keys found. Generate one with ssh-keygen."
    exit 1
  fi

  info "Testing SSH connection to $REMOTE_HOST..."
  if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$REMOTE_USER@$REMOTE_HOST" true 2>/dev/null; then
    error "Cannot connect to $REMOTE_HOST via SSH. Ensure host is reachable and key is added."
    exit 1
  fi
}

# Ensure local and remote directories exist
ensure_dirs() {
  info "Checking sync directories..."
  [ ! -d "$LOCAL_DIR" ] && mkdir -p "$LOCAL_DIR"
  ssh "$REMOTE_USER@$REMOTE_HOST" "mkdir -p '$REMOTE_DIR'"
}

# Base rsync flags
RSYNC_BASE="-avh --progress --exclude=.git/ --exclude=node_modules/ --exclude=.DS_Store $EXCLUDES"
RSYNC_FLAGS="$RSYNC_BASE"
RSYNC_FLAGS_DELETE="$RSYNC_BASE --delete"

# Prompt for confirmation
confirm() {
  local prompt="$1"
  read -rp "$prompt [y/N]: " ans
  [[ "$ans" != "y" && "$ans" != "Y" ]] && { echo "Aborted."; exit 1; }
}

# Backup local files before push/pull/sync
backup_local() {
  local backup_dir="$LOCAL_DIR-backup-$(date '+%Y%m%d%H%M%S')"
  info "Backing up local files to $backup_dir"
  mkdir -p "$backup_dir"
  rsync -a --exclude=".git/" "$LOCAL_DIR/" "$backup_dir/"
}

# Push local dotfiles to remote
push_dotfiles() {
  info "Pushing dotfiles to $REMOTE_HOST..."
  rsync $RSYNC_FLAGS_DELETE "$LOCAL_DIR/" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/"
  info "Dotfiles pushed successfully."
}

# Pull remote dotfiles to local
pull_dotfiles() {
  info "Pulling dotfiles from $REMOTE_HOST..."
  rsync $RSYNC_FLAGS_DELETE "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/" "$LOCAL_DIR/"
  info "Dotfiles pulled successfully."
}

# Bidirectional sync with backups for conflicts
sync_dotfiles() {
  info "Synchronizing local and remote dotfiles (bidirectional with backups)..."
  backup_local
  rsync -avh --update --backup --suffix='.conflict' $RSYNC_FLAGS "$LOCAL_DIR/" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/"
  rsync -avh --update --backup --suffix='.conflict' $RSYNC_FLAGS "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/" "$LOCAL_DIR/"
  info "Sync complete."
}

# Preview changes without applying
preview_changes() {
  info "Previewing changes (dry run)..."
  rsync -avhn --delete $RSYNC_FLAGS "$LOCAL_DIR/" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/"
}

# Show clean diff of changes
diff_changes() {
  info "Listing changed files (dry run)..."
  rsync -avhn --delete $RSYNC_FLAGS "$LOCAL_DIR/" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/" | sed '1,3d'
}

# Usage instructions
show_usage() {
  echo "Usage: $0 [push|pull|sync|preview|diff|help]"
  echo "  push     - Upload local dotfiles to remote"
  echo "  pull     - Download dotfiles from remote"
  echo "  sync     - Merge changes with conflict backups"
  echo "  preview  - Show rsync preview including deletions"
  echo "  diff     - Clean diff of changed files"
  echo "  help     - Show this help message"
}

# Command handling
[ "$#" -eq 0 ] && { show_usage; exit 1; }
command="$1"

check_ssh
ensure_dirs

case "$command" in
  push)
    confirm "This will overwrite remote files with local copies. Continue?"
    push_dotfiles
    ;;
  pull)
    confirm "This will overwrite local files with remote copies. Continue?"
    pull_dotfiles
    ;;
  sync)
    confirm "This will merge changes and create backups for conflicts. Continue?"
    sync_dotfiles
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
