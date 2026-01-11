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

HOSTS_MODIFIED=false
SOUND_PID=""

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

echo
echo "$ASCII_ART"
echo "Deep work starting soon…"
echo "Press any key in the next 10 seconds to cancel."

if read -t 10 -n 1; then
  echo "Cancelled."
  exit 1
fi

if [[ -z "$ARTTIME" ]]; then
  echo "[!] arttime is not installed or not in PATH."
  exit 1
fi

[[ -n "$sites" ]] && block_websites "$sites"
[[ -x "$DND_ON_SCRIPT" ]] && "$DND_ON_SCRIPT"

# ===== TIMER FORMATTING =====

# Get integer hours
hours_int=${hours%.*}

# Calculate the remaining minutes (rounded)
minutes=$(awk "BEGIN { printf(\"%.0f\", ($hours - $hours_int) * 60) }")

# If user input was fractional and hours_int is zero, handle properly
if [[ "$hours_int" -eq 0 ]]; then
  time_arg="${minutes}m"
else
  time_arg="${hours_int}h${minutes}m"
fi

echo
echo "[✓] Focus locked — launching arttime with goal: $time_arg"
echo "[!] _Close_ arttime or let the timer finish to unlock"

# Prevent Ctrl+C from skipping cleanup
trap '' INT

# Start arttime with delta time goal
# `-g` flag can be used for non-interactive goal if supported 
# Else, goal will be read interactively inside arttime
# Use `--nolearn` to skip first-time help screens
"$ARTTIME" --nolearn -g "$time_arg"
