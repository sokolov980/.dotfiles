#!/usr/bin/env bash

set -uo pipefail

# ===== CONFIG =====

DND_ON_SCRIPT="$HOME/.deepwork/enable_dnd.sh"
DND_OFF_SCRIPT="$HOME/.deepwork/disable_dnd.sh"
MPV="$(command -v mpv || true)"
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
  echo -e "\nCleaning up..."

  if [[ "$HOSTS_MODIFIED" == true && -f "$HOSTS_BACKUP" ]]; then
    sudo mv "$HOSTS_BACKUP" /etc/hosts
    echo "[✓] Hosts file restored"
  fi

  [[ -x "$DND_OFF_SCRIPT" ]] && "$DND_OFF_SCRIPT" || true

  if [[ -n "$SOUND_PID" ]]; then
    kill "$SOUND_PID" 2>/dev/null || true
  fi

  echo "Session ended."
}

trap cleanup EXIT INT TERM

# ===== FUNCTIONS =====

block_websites() {
  local raw_sites="$1"

  echo "[+] Blocking websites..."

  if [[ ! -f "$HOSTS_BACKUP" ]]; then
    sudo cp /etc/hosts "$HOSTS_BACKUP"
  fi

  echo "# Blocked by deepwork" | sudo tee -a /etc/hosts >/dev/null

  IFS=',' read -ra ADDR <<<"$raw_sites"
  for site in "${ADDR[@]}"; do
    domain="$(echo "$site" \
      | sed -E 's~(https?://)?([^/]+).*~\2~' \
      | tr -d '[:space:]')"

    [[ -n "$domain" ]] && echo "127.0.0.1 $domain" | sudo tee -a /etc/hosts >/dev/null
  done

  HOSTS_MODIFIED=true
}

start_dnd() {
  [[ -x "$DND_ON_SCRIPT" ]] && "$DND_ON_SCRIPT"
}

play_soundtrack() {
  local path="$1"

  if [[ -n "$MPV" && -f "$path" ]]; then
    "$MPV" --no-video --loop-file "$path" &
    SOUND_PID=$!
  else
    echo "[!] Soundtrack skipped (mpv or file missing)"
  fi
}

countdown_timer() {
  echo -n "Starting in: "
  for i in {10..1}; do
    echo -n "$i... "
    sleep 1
  done
  echo
}

show_ascii() {
  echo "$ASCII_ART"
  echo -e "\nDeep work session complete."
}

pomodoro_loop() {
  local work_min="$1"
  local break_min="$2"
  local rounds="$3"

  for ((i = 1; i <= rounds; i++)); do
    echo "Pomodoro $i — work ($work_min min)"
    sleep $((work_min * 60))

    echo "Break ($break_min min)"
    sleep $((break_min * 60))
  done
}

# ===== PROMPTS =====

read -rp "How long (hours, e.g. 1.5): " hours
read -rp "Play soundtrack? (y/n): " play_music

music_path=""
if [[ "$play_music" == "y" ]]; then
  read -rp "Path to custom mp3 file: " music_path
  [[ ! -f "$music_path" ]] && echo "[!] File not found, skipping music" && music_path=""
fi

read -rp "Websites to block (comma-separated): " sites
read -rp "Enable Pomodoro? (y/n): " enable_pomo

use_pomo=false
if [[ "$enable_pomo" == "y" ]]; then
  read -rp "Work minutes: " work_min
  read -rp "Break minutes: " break_min
  read -rp "Pomodoro rounds: " rounds
  use_pomo=true
fi

# ===== START SESSION =====

echo -e "\nBlocking for $hours hour(s)."
echo "Press any key in the next 10 seconds to cancel..."

if read -t 10 -n 1; then
  echo "Cancelled."
  exit 1
fi

[[ -n "$sites" ]] && block_websites "$sites"
start_dnd
[[ -n "$music_path" ]] && play_soundtrack "$music_path"

countdown_timer

if [[ "$use_pomo" == true ]]; then
  pomodoro_loop "$work_min" "$break_min" "$rounds"
else
  sleep_seconds="$(awk "BEGIN {print $hours * 3600}")"
  sleep "$sleep_seconds"
fi

show_ascii
