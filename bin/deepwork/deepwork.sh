#!/usr/bin/env bash
set -uo pipefail

# ===== CONFIG =====
DND_ON_SCRIPT="$HOME/.deepwork/enable_dnd.sh"
DND_OFF_SCRIPT="$HOME/.deepwork/disable_dnd.sh"
ARTTIME="$(command -v arttime || true)"
MPV="$(command -v mpv || true)"
HOSTS_BACKUP="/etc/hosts.backup.deepwork"

HOSTS_MODIFIED=false
SOUND_PID=""
POMODORO_MODE=false

# ===== CLEANUP =====
cleanup() {
  echo
  echo "[✓] Unlocking..."

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

  sudo cp /etc/hosts "$HOSTS_BACKUP"

  echo "# Blocked by deepwork" | sudo tee -a /etc/hosts >/dev/null

  IFS=',' read -ra ADDR <<<"$raw_sites"
  for site in "${ADDR[@]}"; do
    domain="$(echo "$site" | sed -E 's~(https?://)?([^/]+).*~\2~' | tr -d '[:space:]')"
    [[ -n "$domain" ]] && echo "127.0.0.1 $domain" | sudo tee -a /etc/hosts >/dev/null
  done

  HOSTS_MODIFIED=true
}

play_soundtrack() {
  local file="$1"
  [[ -x "$MPV" && -f "$file" ]] || return
  mpv --loop=inf --no-video "$file" >/dev/null 2>&1 &
  SOUND_PID=$!
}

start_arttime_hours() {
  local hours="$1"
  local h=${hours%.*}
  local m=$(awk "BEGIN { printf(\"%.0f\", ($hours - $h) * 60) }")
  [[ "$h" -eq 0 ]] && time_arg="${m}m" || time_arg="${h}h${m}m"
  "$ARTTIME" --nolearn -a butterfly -t "deep work time – blocking distractions" -g "$time_arg"
}

run_pomodoro() {
  local work="$1" break="$2" rounds="$3"

  for ((i=1; i<=rounds; i++)); do
    "$ARTTIME" --nolearn -a butterfly -t "deep work – focus ($i/$rounds)" -g "${work}m"
    [[ "$i" -lt "$rounds" ]] && \
      "$ARTTIME" --nolearn -a butterfly -t "deep work – break" -g "${break}m"
  done
}

# ===== PROMPTS =====
read -rp "How long (hours, e.g. 1.5): " hours
read -rp "Play soundtrack? (y/n): " play_music
[[ "$play_music" =~ ^[Yy]$ ]] && read -rp "Path to custom mp3 file: " music_file
read -rp "Websites to block (comma-separated): " sites
read -rp "Enable Pomodoro? (y/n): " pomodoro

if [[ "$pomodoro" =~ ^[Yy]$ ]]; then
  POMODORO_MODE=true
  read -rp "Work minutes (e.g., 25): " work_minutes
  read -rp "Break minutes (e.g., 5): " break_minutes
  read -rp "Number of Pomodoro rounds: " rounds
fi

# ===== COUNTDOWN =====
echo
echo "Deep work starting soon…"
echo "Press any key in the next 10 seconds to cancel."

for i in {10..1}; do
  echo -n "$i... "
  read -t 1 -n 1 && { echo "Cancelled."; exit 1; }
done
echo

# ===== SESSION START =====
[[ -n "$sites" ]] && block_websites "$sites"
[[ -x "$DND_ON_SCRIPT" ]] && "$DND_ON_SCRIPT"
[[ "$play_music" =~ ^[Yy]$ ]] && play_soundtrack "$music_file"

if [[ "$POMODORO_MODE" == true ]]; then
  run_pomodoro "$work_minutes" "$break_minutes" "$rounds"
else
  start_arttime_hours "$hours"
fi
