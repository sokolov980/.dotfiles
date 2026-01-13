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
    [[ -z "$s" ]] && continue
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
    $ARTTIME --nolearn -a butterfly -t "$label" -g "${minutes}m"
  else
    echo "[i] Timer for $minutes minutes: $label (arttime not installed)"
    sleep "$((minutes*60))"
  fi

  # Post-timer prompt for extend or quit
  while true; do
    read "?ENTER = continue | e = extend +5 | q = quit > " choice
    case "$choice" in
      q)
        echo "Ending session early."
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

# ===== POMODORO CYCLE =====
run_pomodoro() {
  local total_minutes="$1"
  local work="$2"
  local short_break="$3"
  local long_break="$4"
  local rounds="$5"

  local elapsed=0
  local round_num=1

  while (( elapsed < total_minutes )); do
    # Work period
    local remaining=$(( total_minutes - elapsed ))
    local work_time=$(( work <= remaining ? work : remaining ))
    echo ""
    echo "Focus ($round_num/$rounds)"
    run_timer "$work_time" "focus ($round_num/$rounds)"
    elapsed=$(( elapsed + work_time ))

    # Determine break
    (( elapsed >= total_minutes )) && break
    if (( round_num % rounds == 0 )); then
      # Long break
      local break_time=$(( long_break <= (total_minutes - elapsed) ? long_break : (total_minutes - elapsed) ))
      echo ""
      echo "Long break"
      run_timer "$break_time" "long break"
      elapsed=$(( elapsed + break_time ))
    else
      # Short break
      local break_time=$(( short_break <= (total_minutes - elapsed) ? short_break : (total_minutes - elapsed) ))
      echo ""
      echo "Short break"
      run_timer "$break_time" "short break"
      elapsed=$(( elapsed + break_time ))
    fi

    round_num=$((round_num + 1))
  done

  # Extra focus if any leftover minutes
  local leftover=$(( total_minutes - elapsed ))
  if (( leftover > 0 )); then
    echo ""
    echo "Extra focus to complete session: $leftover minutes"
    run_timer "$leftover" "focus (extra)"
  fi
}

# ===== PROMPTS =====
read "hours?How long (hours, e.g. 1.5): "
read "music?Play soundtrack? (y/n): "
[[ "$music" == "y" ]] && read "music_file?Path to custom mp3 file: "
read "sites?Websites to block (comma-separated): "
read "pomodoro?Enable Pomodoro? (y/n): "

# ===== COUNTDOWN =====
echo ""
echo "press any key to cancel..."
for i in {10..1}; do
  echo -n "$i... "
  read -t 1 -k 1 && exit 0
done
echo ""

[[ -n "$sites" ]] && block_websites "$sites"

if [[ -x "$DND_ON" ]]; then
  "$DND_ON"
else
  echo "[!] DND enable script missing, skipping"
fi

[[ "$music" == "y" ]] && play_music "$music_file"

total_minutes=$(awk "BEGIN {print int($hours*60)}")

if [[ "$pomodoro" == "y" ]]; then
  # Pomodoro defaults
  default_work=25
  default_short_break=5
  default_long_break=15
  default_rounds=4

  echo ""
  read "custom?Use default Pomodoro settings? (y/n): "
  if [[ "$custom" == "n" ]]; then
    read "work?Work minutes (default $default_work): "
    read "short_break?Short break minutes (default $default_short_break): "
    read "long_break?Long break minutes (default $default_long_break): "
    read "rounds?Rounds before long break (default $default_rounds): "
  else
    work=$default_work
    short_break=$default_short_break
    long_break=$default_long_break
    rounds=$default_rounds
  fi

  run_pomodoro "$total_minutes" "$work" "$short_break" "$long_break" "$rounds"
else
  run_timer "$total_minutes" "deep work"
fi
