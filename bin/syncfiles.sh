#!/bin/bash
# syncfiles — Cross-platform dotfile sync tool with multi-remote, versioned backups, hooks, selective sync, and verbose mode

set -euo pipefail
IFS=$'\n\t'

BIN_DIR="$HOME/bin"
SCRIPT_NAME="syncfiles"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

if ! command -v $SCRIPT_NAME >/dev/null 2>&1; then
  mkdir -p "$BIN_DIR"
  [ ! -f "$BIN_DIR/$SCRIPT_NAME" ] && ln -s "$SCRIPT_PATH" "$BIN_DIR/$SCRIPT_NAME"
  if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo "Note: $BIN_DIR not in PATH. Add 'export PATH=\"\$HOME/bin:\$PATH\"' to shell config."
  fi
fi

OS_TYPE="$(uname -s)"
IS_WSL=false
IS_WINDOWS=false
case "$OS_TYPE" in
  Linux) grep -qi microsoft /proc/version 2>/dev/null && IS_WSL=true ;;
  Darwin) ;;
  MINGW*|MSYS*|CYGWIN*) IS_WINDOWS=true ;;
esac

to_unix_path() {
  local path="$1"
  if [ "$IS_WINDOWS" = true ] || [ "$IS_WSL" = true ]; then
    path="$(echo "$path" | sed -E 's|([A-Za-z]):|/\L\1|')"
    path="${path//\\//}"
  fi
  echo "$path"
}

CONFIG_FILE="$(to_unix_path "$HOME")/.syncfiles.conf"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

REMOTE_HOSTS=(${REMOTE_HOSTS:-"macbook.local"})
REMOTE_USER="${REMOTE_USER:-$USER}"
REMOTE_PATH="$(to_unix_path "${REMOTE_PATH:-$HOME/dotfiles-sync}")"
LOCAL_PATH="$(to_unix_path "${LOCAL_PATH:-$HOME/.dotfiles}")"
LOG_DIR="$(to_unix_path "$HOME/.dotfiles_sync_logs")"
mkdir -p "$LOG_DIR"

LOCAL_DIR="$LOCAL_PATH"
REMOTE_DIR="$REMOTE_PATH"

EXCLUDE_FILE="$(to_unix_path "$HOME/.syncfiles_exclude")"
EXCLUDES=""
[ -f "$EXCLUDE_FILE" ] && while IFS= read -r line; do EXCLUDES="$EXCLUDES --exclude=$line"; done < "$EXCLUDE_FILE"
INCLUDE_FILE="$(to_unix_path "$HOME/.syncfiles_include")"
INCLUDES=""
[ -f "$INCLUDE_FILE" ] && while IFS= read -r line; do INCLUDES="$INCLUDES $line"; done < "$INCLUDE_FILE"

VERBOSE=false
if [[ "${SYNCFILES_VERBOSE:-false}" == "true" ]] || [[ "${1:-}" == "-v" ]]; then
  VERBOSE=true
  log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
  log "Verbose mode enabled."
else
  log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/syncfiles.log"; }
fi

pre_hook() { [ -n "${PRE_SYNC_HOOK:-}" ] && eval "$PRE_SYNC_HOOK"; }
post_hook() { [ -n "${POST_SYNC_HOOK:-}" ] && eval "$POST_SYNC_HOOK"; }

check_ssh() {
  [ ! -f "$HOME/.ssh/id_rsa" ] && [ ! -f "$HOME/.ssh/id_ed25519" ] && { echo "No SSH keys found."; exit 1; }
  for host in "${REMOTE_HOSTS[@]}"; do
    log "Testing SSH to $host..."
    ssh -o BatchMode=yes -o ConnectTimeout=5 "$REMOTE_USER@$host" true 2>/dev/null || { echo "Cannot connect to $host"; exit 1; }
  done
}

ensure_dirs() {
  [ ! -d "$LOCAL_DIR" ] && mkdir -p "$LOCAL_DIR"
  for host in "${REMOTE_HOSTS[@]}"; do
    ssh "$REMOTE_USER@$host" "mkdir -p '$REMOTE_DIR'"
  done
}

RSYNC_BASE="-azh --partial --inplace --info=progress2 --exclude=.git/ --exclude=node_modules/ --exclude=.DS_Store $EXCLUDES"
RSYNC_FLAGS="$RSYNC_BASE"
RSYNC_FLAGS_DELETE="$RSYNC_BASE --delete"
RSYNC_SSH_OPTS="-e 'ssh -C -o ControlMaster=auto -o ControlPersist=10m'"
[ "$VERBOSE" = true ] && RSYNC_FLAGS="$RSYNC_FLAGS -vv" && RSYNC_FLAGS_DELETE="$RSYNC_FLAGS_DELETE -vv"

confirm() { read -rp "$1 [y/N]: " ans; [[ "$ans" != "y" && "$ans" != "Y" ]] && { echo "Aborted."; exit 1; }; }

backup_local() {
  timestamp="$(date '+%Y%m%d%H%M%S')"
  backup_dir="$LOCAL_DIR-backup-$timestamp"
  log "Backing up local files to $backup_dir"
  mkdir -p "$backup_dir"
  rsync -a --exclude=".git/" "$LOCAL_DIR/" "$backup_dir/"
  [ "${ENCRYPT_BACKUP:-false}" == "true" ] && tar czf - "$backup_dir" | gpg -c -o "$backup_dir.tar.gz.gpg" && rm -rf "$backup_dir"
}

push_dotfiles() { pre_hook; for host in "${REMOTE_HOSTS[@]}"; do log "Pushing to $host"; rsync $RSYNC_FLAGS_DELETE $RSYNC_SSH_OPTS "$LOCAL_DIR/" "$REMOTE_USER@$host:$REMOTE_DIR/"; done; post_hook; log "Push complete."; }
pull_dotfiles() { pre_hook; for host in "${REMOTE_HOSTS[@]}"; do log "Pulling from $host"; rsync $RSYNC_FLAGS_DELETE $RSYNC_SSH_OPTS "$REMOTE_USER@$host:$REMOTE_DIR/" "$LOCAL_DIR/"; done; post_hook; log "Pull complete."; }
sync_dotfiles() { pre_hook; backup_local; for host in "${REMOTE_HOSTS[@]}"; do rsync -avh --update --backup --suffix='.conflict' $RSYNC_FLAGS $RSYNC_SSH_OPTS "$LOCAL_DIR/" "$REMOTE_USER@$host:$REMOTE_DIR/"; rsync -avh --update --backup --suffix='.conflict' $RSYNC_FLAGS $RSYNC_SSH_OPTS "$REMOTE_USER@$host:$REMOTE_DIR/" "$LOCAL_DIR/"; done; post_hook; log "Sync complete."; }
preview_changes() { for host in "${REMOTE_HOSTS[@]}"; do rsync -avhn --delete $RSYNC_FLAGS $RSYNC_SSH_OPTS "$LOCAL_DIR/" "$REMOTE_USER@$host:$REMOTE_DIR/"; done; }
diff_changes() { for host in "${REMOTE_HOSTS[@]}"; do rsync -avhn --delete $RSYNC_FLAGS $RSYNC_SSH_OPTS "$LOCAL_DIR/" "$REMOTE_USER@$host:$REMOTE_DIR/" | sed '1,3d'; done; }

show_usage() {
  echo "Usage: syncfiles [push|pull|sync|preview|diff|help] [-v]"
  echo "Ensure the script is in your PATH or symlinked via ~/bin."
  echo "Add 'export PATH=\"\$HOME/bin:\$PATH\"' to shell config if needed."
}

[ "$#" -eq 0 ] && { show_usage; exit 1; }
command="$1"
[ "$command" == "-v" ] && command="$2"

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
