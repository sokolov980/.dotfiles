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
| | |/ _ \/ __/ _ \| `_ \| __/ _ \ `_ ` _ \
| |_| |  __/ (_| (_) | | | ||  __/ | | | | |
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

  if [[ -x "$DND_OFF" ]]; then
    "$DND_OFF"
  else
    echo "[!] DND disable script missing, skipping"
  fi

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
    s="${s##*( )}"   # trim leading spaces
    s="${s%%*( )}"   # trim trailing spaces
    d=$(echo "$s" | sed -E 's~(https?://)?([^/]+).*~\2~')
    echo "127.0.0.1 $d" | sudo tee -a /etc/hosts >/dev/null
    echo "::1 $d" | sudo tee -a /etc/hosts >/dev/null
  done

  sudo dscacheutil -flushcache
  sudo killall -HUP mDNSResponder 2>/dev/null || true
  HOSTS_MODIFIED=true
}

play_music() {
  if [[ ! -x "$MPV" ]]; then
    echo "[!] mpv not found. Skipping music playback."
    return
  fi
  if [[ ! -f "$1" ]]; then
    echo "[!] Music file '$1' not found. Skipping music playback."
    return
  fi

  mpv --loop=inf --no-video "$1" >/dev/null 2>&1 &
  SOUND_PID=$!
}

# ===== TIMER WITH POST-TIMER INTERACTIVITY =====
run_timer() {
  local minutes="$1"
  local label="$2"

  if [[ -n "$ARTTIME" ]]; then
    # ArtTime runs timer, blocking until finished
    $ARTTIME --nolearn -a butterfly -t "$label" -g "${minutes}m"
  else
    # fallback sleep for testing
    echo "[i] Timer for $minutes minutes: $label (arttime not installed)"
    sleep "$((minutes*60))"
  fi

  # Post-timer prompt
  while true; do
    read "?ENTER = continue | e = extend +5 | q = quit > " choice
    case "$choice" in
      q)
        echo "Ending deep work session early."
        exit 0
        ;;
      e)
        minutes=$((minutes + 5))
        echo "Extending by 5 minutes..."
        if [[ -n "$ARTTIME" ]]; then
          $ARTTIME --nolearn -a butterfly -t "$label" -g "${minutes}m"
        else
          echo "[i] Extended timer for $minutes minutes: $label"
          sleep "$((minutes*60))"
        fi
        ;;
      *)
        break
        ;;
    esac
  done
}

# ===== POMODORO RUNNER (Auto-adjust rounds) =====
run_pomodoro() {
  local total_minutes="$1"
  local work="$2"
  local break_time="$3"

  local round_time=$((work + break_time))
  local rounds=$((total_minutes / round_time))
  local remainder=$((total_minutes % round_time))

  if (( rounds == 0 )); then
    echo "[!] Session too short for Pomodoro with given work/break settings."
    run_timer "$total_minutes" "focus"
    return
  fi

  echo "[i] Running $rounds Pomodoro rounds with $work/$break_time min work/break."

  for ((round=1; round<=rounds; round++)); do
    echo ""
    echo "Starting Pomodoro round $round of $rounds"
    run_timer "$work" "focus ($round/$rounds)"

    if (( round < rounds )); then
      echo ""
      echo "Break time"
      run_timer "$break_time" "break ($round/$rounds)"
    fi
  done

  # leftover minutes
  if (( remainder > 0 )); then
    echo ""
    echo "Extra focus time to complete session: $remainder minutes"
    run_timer "$remainder" "focus (extra)"
  fi
}

# ===== PROMPTS =====
read "hours?How long (hours, e.g. 1.5): "
read "music?Play soundtrack? (y/n): "
[[ "$music" == "y" ]] && read "music_file?Path to custom mp3 file: "
read "sites?Websites to block (comma-separated): "
read "pomodoro?Enable Pomodoro? (y/n): "

if [[ "$pomodoro" == "y" ]]; then
  read "work?Work minutes (e.g., 25): "
  read "break?Break minutes (e.g., 5): "
fi

# ===== COUNTDOWN =====
echo ""
echo "press any key to cancel..."

for i in {10..1}; do
  echo -n "$i... "
  read -t 1 -k 1 && exit 0
done
echo ""

# ===== START SESSION =====
[[ -n "$sites" ]] && block_websites "$sites"

if [[ -x "$DND_ON" ]]; then
  "$DND_ON"
else
  echo "[!] DND enable script missing, skipping"
fi

[[ "$music" == "y" ]] && play_music "$music_file"

total_minutes=$(awk "BEGIN {print int($hours*60)}")

if [[ "$pomodoro" == "y" ]]; then
  run_pomodoro "$total_minutes" "$work" "$break"
else
  run_timer "$total_minutes" "deep work"
fi
