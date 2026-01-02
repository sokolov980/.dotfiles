#!/bin/bash
set -euo pipefail

# ===== CONFIG =====
DND_ON_SCRIPT="$HOME/.deepwork/enable_dnd.sh"
DND_OFF_SCRIPT="$HOME/.deepwork/disable_dnd.sh"
MPV="$(command -v mpv || true)"
ARTTIME="$HOME/.local/bin/arttime"

ASCII_ART='
 ____                        _                 
|  _ \  ___  ___ ___  _ __ | |_ ___ _ __ ___  
| | |/ _ \/ __/ _ \| `_ \| __/ _ \ `_ ` _ \ 
| |_| |  __/ (_| (_) | | | | ||  __/ | | | | |
|____/ \___|\___\___/|_| |_|\__\___|_| |_| |_|'

# ===== FUNCTIONS =====
cleanup() {
    echo -e "\nCleaning up..."
    [[ -f /etc/hosts.backup.deepwork ]] && sudo mv /etc/hosts.backup.deepwork /etc/hosts
    [[ -x "$DND_OFF_SCRIPT" ]] && "$DND_OFF_SCRIPT" || true
    [[ -n "${SOUND_PID:-}" ]] && kill "$SOUND_PID" 2>/dev/null || true
    echo "Session ended."
}

trap cleanup EXIT

start_dnd() {
    [[ -x "$DND_ON_SCRIPT" ]] && "$DND_ON_SCRIPT"
}

play_soundtrack() {
    local path=$1
    if [[ -n "$MPV" && -f "$path" ]]; then
        "$MPV" --no-video "$path" --loop-file &
        SOUND_PID=$!
    else
        echo "[!] Soundtrack file missing or mpv not installed."
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
    local work_min=$1
    local break_min=$2
    local rounds=$3
    for ((i=1; i<=rounds; i++)); do
        echo "Pomodoro $i: Work for $work_min minutes..."
        sleep "$((work_min * 60))"
        echo "Break for $break_min minutes..."
        sleep "$((break_min * 60))"
    done
}

block_websites() {
    local raw_sites=$1
    echo "[+] Blocking websites: $raw_sites"
    sudo cp /etc/hosts /etc/hosts.backup.deepwork
    echo "# Blocked by deepwork" | sudo tee -a /etc/hosts >/dev/null

    IFS=',' read -ra ADDR <<< "$raw_sites"
    for site in "${ADDR[@]}"; do
        domain=$(echo "$site" | sed -E 's~(https?://)?([^/]+).*~\2~' | tr -d '[:space:]')
        [[ -n "$domain" ]] && echo "127.0.0.1 $domain" | sudo tee -a /etc/hosts >/dev/null
    done
}

# ===== PROMPTS =====
read -rp "How long (hours, e.g., 1.5): " hours
read -rp "Play soundtrack? (y/n): " play_music

music_path=""
if [[ "$play_music" == "y" ]]; then
    read -rp "Path to custom mp3 file: " music_path
    [[ ! -f "$music_path" ]] && echo "[!] File not found. Skipping music." && music_path=""
fi

read -rp "Websites to block (comma-separated): " sites
read -rp "Enable Pomodoro? (y/n): " enable_pomo

use_pomo=false
if [[ "$enable_pomo" == "y" ]]; then
    read -rp "Work minutes: " work_min
    read -rp "Break minutes: " break_min
    read -rp "Number of rounds: " rounds
    use_pomo=true
fi

# ===== CANCEL WINDOW (FIXED) =====
echo -e "\nPress any key in the next 10 seconds to cancel..."
if read -r -t 10 -n 1; then
    echo "Cancelled."
    exit 0
fi

# ===== START SESSION =====
[[ -n "$sites" ]] && block_websites "$sites"
start_dnd
[[ -n "$music_path" ]] && play_soundtrack "$music_path"

countdown_timer

# ===== MAIN SESSION =====
if [[ "$use_pomo" == "true" ]]; then
    pomodoro_loop "$work_min" "$break_min" "$rounds"
else
    sleep_time=$(awk "BEGIN {print $hours * 3600}")
    sleep "$sleep_time"
fi

# ===== RUN ARTTIME =======
if [[ -x "$ARTTIME" ]]; then
    hours_int=$(awk "BEGIN {print int($hours)}")
    "$ARTTIME" --nolearn -a butterfly \
        -t "deep work time – blocking distractions" \
        -g "${hours_int}h"
else
    echo "[!] arttime not found at $ARTTIME"
fi

show_ascii
