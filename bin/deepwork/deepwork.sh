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

# ===== HELPERS =====
block_websites() {
  sudo cp /etc/hosts "$HOSTS_BACKUP"
  echo "# Blocked by deepwork" | sudo tee -a /etc/hosts >/dev/null

  local sites=(${(s:,:)1})
  for s in $sites; do
    d=$(echo "$s" | sed -E 's~(https?://)?([^/]+).*~\2~' | tr -d ' ')
    echo "127.0.0.1 $d" | sudo tee -a /etc/hosts >/dev/null
    echo "::1 $d" | sudo tee -a /etc/hosts >/dev/null
  done

  sudo dscacheutil -flushcache
  sudo killall -HUP mDNSResponder 2>/dev/null || true
  HOSTS_MODIFIED=true
}

play_music() {
  [[ -x "$MPV" && -f "$1" ]] || return
  mpv --loop=inf --no-video "$1" >/dev/null 2>&1 &
  SOUND_PID=$!
}

pause_prompt() {
  while true; do
    read "?ENTER=continue | p=pause | e=+5min | q=quit > " c
    case "$c" in
      q) exit 0 ;;
      p) echo "Paused. Press ENTER to resume."; read ;;
      e) echo "extend" ; return 1 ;;
      *) return 0 ;;
    esac
  done
}

run_timer() {
  local mins="$1" label="$2"
  while true; do
    arttime --nolearn -a butterfly -t "$label" -g "${mins}m"
    pause_prompt && break
    mins=$((mins + 5))
  done
}

run_pomodoro() {
  for ((i=1; i<=rounds; i++)); do
    run_timer "$work" "focus ($i/$rounds)"
    [[ "$i" -lt "$rounds" ]] && run_timer "$break" "break"
  done
}

# ===== PROMPTS (EXACT TEXT) =====
read "hours?How long (hours, e.g. 1.5): "
read "music?Play soundtrack? (y/n): "
[[ "$music" == "y" ]] && read "music_file?Path to custom mp3 file: "
read "sites?Websites to block (comma-separated): "
read "pomodoro?Enable Pomodoro? (y/n): "

if [[ "$pomodoro" == "y" ]]; then
  read "work?Work minutes (e.g., 25): "
  read "break?Break minutes (e.g., 5): "
  read "rounds?Number of Pomodoro rounds: "
fi

# ===== COUNTDOWN =====
echo ""
echo "press any key to cancel..."

for i in {10..1}; do
  echo -n "$i... "
  read -t 1 -k 1 && exit 0
done
echo ""

# ===== START =====
[[ -n "$sites" ]] && block_websites "$sites"
[[ -x "$DND_ON" ]] && "$DND_ON"
[[ "$music" == "y" ]] && play_music "$music_file"

if [[ "$pomodoro" == "y" ]]; then
  run_pomodoro
else
  mins=$((hours * 60))
  run_timer "$mins" "deep work"
fi
