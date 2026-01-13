#!/usr/bin/env zsh
set -uo pipefail

# ===== CONFIG =====
ARTTIME="$(command -v arttime || true)"
MPV="$(command -v mpv || true)"
DND_ON="$HOME/.deepwork/enable_dnd.sh"
DND_OFF="$HOME/.deepwork/disable_dnd.sh"
HOSTS_BACKUP="/etc/hosts.backup.deepwork"

HOSTS_MODIFIED=false
SOUND_PID=""

ASCII_DONE='
 ____                        _
|  _ \  ___  ___ ___  _ __ | |_ ___ _ __ ___
| | | |/ _ \/ __/ _ \| `_ \| __/ _ \ `_ ` _ \
| |_| |  __/ (_| (_) | | | | ||  __/ | | | | |
|____/ \___|\___\___/|_| |_|\__\___|_| |_| |_|
'

# ===== CLEANUP =====
cleanup() {
  echo ""

  if [[ "$HOSTS_MODIFIED" == true && -f "$HOSTS_BACKUP" ]]; then
    sudo cp "$HOSTS_BACKUP" /etc/hosts
    sudo chmod 644 /etc/hosts
    sudo chown root:wheel /etc/hosts
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder 2>/dev/null || true
    sudo rm -f "$HOSTS_BACKUP"
    echo "[✓] Websites unblocked"
  fi

  [[ -x "$DND_OFF" ]] && "$DND_OFF"
  [[ -n "$SOUND_PID" ]] && kill "$SOUND_PID" 2>/dev/null || true

  echo "$ASCII_DONE"
  echo "[✓] Deep work session complete."
}

trap cleanup EXIT INT TERM

# ===== FUNCTIONS =====
block_websites() {
  local raw="$1"
  echo "[+] Blocking websites..."

  sudo cp /etc/hosts "$HOSTS_BACKUP"
  echo "# Blocked by deepwork" | sudo tee -a /etc/hosts >/dev/null

  local sites=(${(s:,:)raw})
  for site in $sites; do
    domain=$(echo "$site" | sed -E 's~(https?://)?([^/]+).*~\2~' | tr -d '[:space:]')
    [[ -n "$domain" ]] || continue
    echo "127.0.0.1 $domain" | sudo tee -a /etc/hosts >/dev/null
    echo "::1 $domain" | sudo tee -a /etc/hosts >/dev/null
  done

  sudo dscacheutil -flushcache
  sudo killall -HUP mDNSResponder 2>/dev/null || true
  HOSTS_MODIFIED=true
}

play_music() {
  local file="$1"
  [[ -x "$MPV" && -f "$file" ]] || return
  mpv --loop=inf --no-video "$file" >/dev/null 2>&1 &
  SOUND_PID=$!
}

run_arttime_hours() {
  local h="$1"
  local whole=${h%.*}
  local mins=$(( (h - whole) * 60 ))
  local goal

  [[ "$whole" -gt 0 ]] && goal="${whole}h${mins}m" || goal="${mins}m"
  arttime --nolearn -a butterfly -t "deep work time" -g "$goal"
}

run_pomodoro() {
  local work="$1" break="$2" rounds="$3"

  for ((i=1; i<=rounds; i++)); do
    arttime --nolearn -a butterfly -t "focus ($i/$rounds)" -g "${work}m"

    if [[ "$i" -lt "$rounds" ]]; then
      echo ""
      echo "Pomodoro round $i complete."
      read "?Press ENTER to continue, or q to quit: " choice

      if [[ "$choice" == "q" ]]; then
        echo "Ending deep work session early."
        exit 0   # cleanup trap fires
      fi

      arttime --nolearn -a butterfly -t "break" -g "${break}m"
    fi
  done
}

# ===== PROMPTS =====
read "hours?Session duration (hours, e.g. 1.5): "
read "music?Play soundtrack? (y/n): "
[[ "$music" == "y" ]] && read "music_file?Path to mp3 file: "
read "sites?Websites to block (comma-separated): "
read "pomodoro?Enable Pomodoro? (y/n): "

if [[ "$pomodoro" == "y" ]]; then
  read "work?Work minutes (e.g., 25): "
  read "break?Break minutes (e.g., 5): "
  read "rounds?Number of Pomodoro rounds: "
fi

# ===== COUNTDOWN =====
echo ""
echo "Press any key to cancel..."

for i in {10..1}; do
  echo -n "$i... "
  read -t 1 -k 1 && { echo "cancelled."; exit 0; }
done
echo ""

# ===== START SESSION =====
[[ -n "$sites" ]] && block_websites "$sites"
[[ -x "$DND_ON" ]] && "$DND_ON"
[[ "$music" == "y" ]] && play_music "$music_file"

if [[ "$pomodoro" == "y" ]]; then
  run_pomodoro "$work" "$break" "$rounds"
else
  run_arttime_hours "$hours"
fi
