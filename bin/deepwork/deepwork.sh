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
DND_ENABLED=false

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

  [[ "$DND_ENABLED" == true && -x "$DND_OFF" ]] && "$DND_OFF"
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
    s="${s##*( )}"
    s="${s%%*( )}"
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
  if [[ ! -x "$MPV" || ! -f "$1" ]]; then
    return
  fi
  mpv --loop=inf --no-video "$1" >/dev/null 2>&1 &
  SOUND_PID=$!
}

# ===== ZSH TIMER =====
zsh_timer() {
  local minutes="$1"
  local label="$2"
  local total_seconds=$((minutes*60))

  for ((i=total_seconds; i>0; i--)); do
    printf "\r%s | time remaining %02d:%02d " "$label" $((i/60)) $((i%60))
    sleep 1
  done
  echo ""  # newline after timer
}

# ===== TIMER WITH POST-TIMER INTERACTIVITY =====
run_timer() {
  local minutes="$1"
  local label="$2"
  local use_zsh="${3:-false}"

  if [[ "$use_zsh" == true ]]; then
    zsh_timer "$minutes" "$label"
  elif [[ -n "$ARTTIME" ]]; then
    $ARTTIME --nolearn -a butterfly -t "$label" -g "${minutes}m"
    stty sane
  else
    echo "[i] Timer for $minutes minutes: $label"
    sleep $((minutes*60))
  fi

  # Two blank lines for spacing
  echo ""
  echo ""

  # Post-timer prompt
  while true; do
    read "?ENTER = continue | e = extend +5 | q = quit > " choice
    echo ""
    echo ""
    case "$choice" in
      q) exit 0 ;;
      e)
        minutes=$((minutes+5))
        run_timer "$minutes" "$label" "$use_zsh"
        ;;
      *) break ;;
    esac
  done
}

# ===== POMODORO =====
run_pomodoro() {
  local total_minutes="$1"
  local work="$2"
  local short_break="$3"
  local long_break="$4"
  local rounds="$5"

  local elapsed=0
  local cycle=1

  while (( elapsed < total_minutes )); do
    # Work period
    local remaining=$(( total_minutes - elapsed ))
    local work_time=$(( work <= remaining ? work : remaining ))
    [[ work_time -le 0 ]] && break
    run_timer "$work_time" "Focus ($cycle)" true
    elapsed=$(( elapsed + work_time ))

    # Break
    remaining=$(( total_minutes - elapsed ))
    [[ remaining -le 0 ]] && break
    if (( cycle % rounds == 0 )); then
      local break_time=$(( long_break <= remaining ? long_break : remaining ))
      run_timer "$break_time" "Long Break ($cycle/$rounds)" true
      elapsed=$(( elapsed + break_time ))
    else
      local break_time=$(( short_break <= remaining ? short_break : remaining ))
      run_timer "$break_time" "Short Break ($cycle/$rounds)" true
      elapsed=$(( elapsed + break_time ))
    fi

    cycle=$((cycle+1))
  done

  # Extra focus if leftover
  local leftover=$(( total_minutes - elapsed ))
  if (( leftover > 0 )); then
    run_timer "$leftover" "Extra Focus" true
  fi
}

# ===== USER PROMPTS =====
read "hours?How long (hours, e.g. 1.5): "
read "music?Play soundtrack? (y/n): "
[[ "$music" == "y" ]] && read "music_file?Path to custom mp3 file: "
read "sites?Websites to block (comma-separated): "
read "pomodoro?Enable Pomodoro? (y/n): "

# ===== COUNTDOWN =====
echo ""
echo "Press any key to cancel..."
for i in {10..1}; do
  echo -n "$i... "
  read -t 1 -k 1 && exit 0
done
echo "\n"

# ===== BLOCK WEBSITES =====
[[ -n "$sites" ]] && block_websites "$sites"

# ===== ENABLE DND (only once) =====
if [[ "$DND_ENABLED" == false && -x "$DND_ON" ]]; then
    "$DND_ON"
    echo "[✓] DND enabled"
    DND_ENABLED=true
elif [[ "$DND_ENABLED" == false ]]; then
    echo "[!] DND enable script missing or not executable"
fi

# ===== PLAY MUSIC =====
[[ "$music" == "y" ]] && play_music "$music_file"

total_minutes=$(awk "BEGIN {print int($hours*60)}")

# ===== RUN POMODORO OR DEEPWORK =====
if [[ "$pomodoro" == "y" ]]; then
  default_work=25
  default_short_break=5
  default_long_break=15
  default_rounds=4

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
  # Use ArtTime if installed, else fallback to Zsh timer
  if [[ -n "$ARTTIME" ]]; then
    run_timer "$total_minutes" "Deep Work" false
  else
    run_timer "$total_minutes" "Deep Work" true
  fi
fi
