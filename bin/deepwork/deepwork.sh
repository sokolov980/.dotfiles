#!/usr/bin/env bash

set -uo pipefail

# ===== CONFIG =====

DND_ON_SCRIPT="$HOME/.deepwork/enable_dnd.sh"
DND_OFF_SCRIPT="$HOME/.deepwork/disable_dnd.sh"
ARTTIME="$(command -v arttime || true)"
HOSTS_BACKUP="/etc/hosts.backup.deepwork"

ASCII_ART='
 ____                        _
|  _ \  ___  ___ ___  _ __ | |_ ___ _ __ ___
| | | |/ _ \/ __/ _ \| `_ \| __/ _ \ `_ ` _ \
| |_| |  __/ (_| (_) | | | | ||  __/ | | | | |
|____/ \___|\___\___/|_| |_|\__\___|_| |_| |_|
'

# ===== STATE =====

HOSTS_MODIFIED=false
SOUND_PID=""

# ===== CLEANUP =====

cleanup() {
  echo -e "\n\n[✓] Unlocking..."

  if [[ "$HOSTS_MODIFIED" == true && -f "$HOSTS_BACKUP" ]]; then
    sudo mv "$HOSTS_BACKUP" /etc/hosts
    echo "[✓] Websites unblocked"
  fi

  [[ -x "$DND_OFF_SCRIPT" ]] && "$DND_OFF_SCRIPT"

  [[ -n "$SOUND_PID" ]] && kill "$SOUND_PID" 2>/dev/null || true

  echo "[✓] Deep work session complete."
}

trap cleanup EXIT INT TERM

# ===== FUNCTIONS =====

block_websites() {
  local raw_sites="$1"

  echo "[+] Blocking websites..."

  [[ ! -f "$HOSTS_BACKUP" ]] && sudo cp /etc/hosts "$HOSTS_BACKUP"

  echo "# Blocked by deepwork" | sudo tee -a /etc/hosts >/dev/null

  IFS=',' read -ra ADDR <<<"$raw_sites"
  for site in "${ADDR[@]}"; do
    domain="$(echo "$site" | sed -E 's~(https?://)?([^/]+).*~\2~' | tr -d '[:space:]')"
    [[ -n "$domain" ]] && echo "127.0.0.1 $domain" | sudo tee -a /etc/hosts >/dev/null
  done

  HOSTS_MODIFIED=true
}

# ===== PROMPTS =====

read -rp "How long (hours, e.g. 1.5): " hours
read -rp "Websites to block (comma-separated): " sites

# ===== START SESSION =====

echo
echo "$ASCII_ART"
echo "Deep work starting soon…"
echo "Press any key in the next 10 seconds to cancel."

if read -t 10 -n 1; then
  echo "Cancelled."
  exit 1
fi

# ----- SAFETY CHECK -----

if [[ -z "$ARTTIME" ]]; then
  echo "[!] arttime is not installed or not in PATH."
  exit 1
fi

# ----- APPLY BLOCKS -----

[[ -n "$sites" ]] && block_websites "$sites"
[[ -x "$DND_ON_SCRIPT" ]] && "$DND_ON_SCRIPT"

# ----- LAUNCH ARTTIME -----

total_minutes="$(awk "BEGIN {print int($hours * 60)}")"

echo
echo "[✓] Focus locked — launching arttime"
echo "[✓] Close arttime to unlock"

# Prevent Ctrl+C from skipping cleanup
trap '' INT
arttime "${total_minutes}m"

# cleanup runs automatically on exit
