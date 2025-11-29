#!/bin/bash
# syncfiles — Cross-platform high-performance dotfile sync tool

set -euo pipefail
IFS=$'\n\t'

# Detect OS
OS_TYPE="$(uname -s)"
IS_WSL=false
IS_WINDOWS=false

case "$OS_TYPE" in
  Linux)
    if grep -qi microsoft /proc/version 2>/dev/null; then
      IS_WSL=true
    fi
    ;;
  Darwin)
    ;; # macOS
  MINGW*|MSYS*|CYGWIN*)
    IS_WINDOWS=true
    ;;
esac

# Convert Windows paths to Unix style for rsync
to_unix_path() {
  local path="$1"
  if [ "$IS_WINDOWS" = true ]; then
    path="$(echo "$path" | sed -E 's|([A-Za-z]):|/\L\1|')"
    path="${path//\\//}"
  fi
  echo "$path"
}

# Config
CONFIG_FILE="$(to_unix_path "$HOME")/.syncfiles.conf"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

REMOTE_HOST="${REMOTE_HOST:-macbook.local}"
REMOTE_USER="${REMOTE_USER:-$USER}"
REMOTE_PATH="$(to_unix_path "${REMOTE_PATH:-$HOME/dotfiles-sync}")"
LOCAL_PATH="$(to_unix_path "${LOCAL_PATH:-$HOME/.dotfiles}")"
LOG_FILE="$(to_unix_path "$HOME/.dotfiles_sync.log")"

LOCAL_DIR="$LOCAL_PATH"
REMOTE_DIR="$REMOTE_PATH"

EXCLUDE_FILE="$(to_unix_path "$HOME/.syncfiles_exclude")"
EXCLUDES=""
[ -f "$EXCLUDE_FILE" ] && while IFS= read -r line; do EXCLUDES="$EXCLUDES --exclude=$line"; done < "$EXCLUDE_FILE"

# Logging
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

# SSH check
check_ssh() {
  if [ ! -f "$HOME/.ssh/id_rsa" ] && [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    echo "No SSH keys found. Generate one with ssh-keygen."
    exit 1
  fi
  log "Testing SSH connection to $REMOTE_HOST..."
  ssh -o BatchMode=yes -o ConnectTimeout=5 "$REMOTE_USER@$REMOTE_HOST" true 2>/dev/null || { echo "Cannot connect to $REMOTE_HOST via SSH."; exit 1; }
}

# Ensure directories exist
ensure_dirs() {
  [ ! -d "$LOCAL_DIR" ] && mkdir -p "$LOCAL_DIR"
  ssh "$REMOTE_USER@$REMOTE_HOST" "mkdir -p '$REMOTE_DIR'"
}

# Rsync flags
RSYNC_BASE="-azh --partial --inplace --info=progress2 --exclude=.git/ --exclude=node_modules/ --exclude=.DS_Store $EXCLUDES"
RSYNC_FLAGS="$RSYNC_BASE"
RSYNC_FLAGS_DELETE="$RSYNC_BASE --delete"
RSYNC_SSH_OPTS="-e 'ssh -C -o ControlMaster=auto -o ControlPersist=10m'"

confirm() { read -rp "$1 [y/N]: " ans; [[ "$ans" != "y" && "$ans" != "Y" ]] && { echo "Aborted."; exit 1; }; }

# Backup local files
backup_local() {
  backup_dir="$LOCAL_DIR-backup-$(date '+%Y%m%d%H%M%S')"
  log "Backing up local files to $backup_dir"
  mkdir -p "$backup_dir"
  rsync -a --exclude=".git/" "$LOCAL_DIR/" "$backup_dir/"
}

# Operations
push_dotfiles() { log "Pushing dotfiles to $REMOTE_HOST..."; rsync $RSYNC_FLAGS_DELETE $RSYNC_SSH_OPTS "$LOCAL_DIR/" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/"; log "Push complete."; }
pull_dotfiles() { log "Pulling dotfiles from $REMOTE_HOST..."; rsync $RSYNC_FLAGS_DELETE $RSYNC_SSH_OPTS "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/" "$LOCAL_DIR/"; log "Pull complete."; }
sync_dotfiles() { log "Synchronizing local and remote dotfiles..."; backup_local; rsync -avh --update --backup --suffix='.conflict' $RSYNC_FLAGS $RSYNC_SSH_OPTS "$LOCAL_DIR/" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/"; rsync -avh --update --backup --suffix='.conflict' $RSYNC_FLAGS $RSYNC_SSH_OPTS "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/" "$LOCAL_DIR/"; log "Sync complete."; }
preview_changes() { log "Previewing changes (dry run)..."; rsync -avhn --delete $RSYNC_FLAGS $RSYNC_SSH_OPTS "$LOCAL_DIR/" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/"; }
diff_changes() { log "Listing changed files (dry run)..."; rsync -avhn --delete $RSYNC_FLAGS $RSYNC_SSH_OPTS "$LOCAL_DIR/" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/" | sed '1,3d'; }

# Usage
show_usage() {
  echo "Usage: $0 [push|pull|sync|preview|diff|help]"
  echo "  push     - Upload local dotfiles to remote"
  echo "  pull     - Download dotfiles from remote"
  echo "  sync     - Merge changes with conflict backups"
  echo "  preview  - Show rsync preview including deletions"
  echo "  diff     - Clean diff of changed files"
  echo "  help     - Show this help message"
}

[ "$#" -eq 0 ] && { show_usage; exit 1; }
command="$1"

check_ssh
ensure_dirs

case "$command" in
  push) confirm "Overwrite remote files with local copies? Continue?"; push_dotfiles ;;
  pull) confirm "Overwrite local files with remote copies? Continue?"; pull_dotfiles ;;
  sync) confirm "Merge changes and create backups for conflicts? Continue?"; sync_dotfiles ;;
  preview) preview_changes ;;
  diff) diff_changes ;;
  help|*) show_usage ;;
esac
