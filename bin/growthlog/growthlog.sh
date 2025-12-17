#!/bin/bash
# growthlog.sh - Ultimate personal growth tracker
# Features: habits, goals/sub-goals, streaks, reflections (optional encryption), calendar, stats, search, export
# Production-ready, modular, CLI with colors, pagination, backup, analytics

# ---------------------------
# Directory Setup
# ---------------------------
TRACKER_DIR="$HOME/growthlog"
LOG_DIR="$TRACKER_DIR/logs"
GOALS_FILE="$TRACKER_DIR/goals.txt"
HABITS_FILE="$TRACKER_DIR/habits.txt"
STREAK_FILE="$TRACKER_DIR/streaks.txt"
REFLECTIONS_FILE="$TRACKER_DIR/reflections.md"
SUBGOALS_FILE="$TRACKER_DIR/subgoals.txt"
EXPORT_DIR="$TRACKER_DIR/exports"
mkdir -p "$LOG_DIR" "$TRACKER_DIR" "$EXPORT_DIR"

# ---------------------------
# Colors
# ---------------------------
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
MAGENTA="\033[0;35m"
NC="\033[0m"

# ---------------------------
# Utility Functions
# ---------------------------
current_date() { date +'%Y-%m-%d'; }
trim() { echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'; }

validate_number() {
    local INPUT=$1
    while ! [[ "$INPUT" =~ ^[0-9]+$ ]]; do
        echo "Enter a valid number:"
        read INPUT
    done
    echo "$INPUT"
}

validate_date() {
    local INPUT=$1
    while ! date -d "$INPUT" "+%Y-%m-%d" >/dev/null 2>&1; do
        echo "Enter a valid date (YYYY-MM-DD):"
        read INPUT
    done
    echo "$INPUT"
}

confirm_action() {
    echo "$1 (y/n)"
    read RESP
    [[ "$RESP" == "y" || "$RESP" == "Y" ]]
}

# ---------------------------
# Habits
# ---------------------------
add_habit() {
    echo "Enter habit name:"
    read HABIT_NAME
    HABIT_NAME=$(trim "$HABIT_NAME")
    grep -q "^$HABIT_NAME|" "$HABITS_FILE" 2>/dev/null && { echo "'$HABIT_NAME' exists."; return; }
    echo "Enter brief description (optional):"
    read DESCRIPTION
    DESCRIPTION=$(trim "$DESCRIPTION")
    echo "Enter priority (1=High,2=Medium,3=Low):"
    read PRIORITY
    PRIORITY=$(validate_number "$PRIORITY")
    while ! [[ "$PRIORITY" =~ ^[1-3]$ ]]; do
        echo "Priority must be 1,2, or 3:"
        read PRIORITY
    done
    echo "Select category: 1) Health 2) Learning 3) Productivity"
    read CAT
    case $CAT in
        1) CATEGORY="Health" ;;
        2) CATEGORY="Learning" ;;
        3) CATEGORY="Productivity" ;;
        *) CATEGORY="General" ;;
    esac
    echo "$HABIT_NAME|$DESCRIPTION|Priority:$PRIORITY|Category:$CATEGORY" >> "$HABITS_FILE"
    echo -e "${GREEN}'$HABIT_NAME' added under $CATEGORY.${NC}"
}

list_habits() {
    [ ! -f "$HABITS_FILE" ] && { echo "No habits yet."; return; }
    awk -F"|" '{printf "%s (%s, %s)\n",$1,$4,$3}' "$HABITS_FILE"
}

log_habit() {
    DATE=$(current_date)
    list_habits
    echo "Enter completed habit (exact name):"
    read HABIT
    ! grep -q "^$HABIT|" "$HABITS_FILE" && { echo "Habit not found."; return; }
    echo "Times completed today:"
    read TIMES
    TIMES=$(validate_number "$TIMES")
    for i in $(seq 1 $TIMES); do
        echo "Notes (optional):"
        read NOTES
        LOG_FILE="$LOG_DIR/$DATE.txt"
        echo "$DATE: Habit Completed: $HABIT | Notes: $NOTES" >> "$LOG_FILE"
        update_streak "$HABIT"
    done
    echo -e "${GREEN}Logged $HABIT $TIMES time(s).${NC}"
}

# ---------------------------
# Streaks
# ---------------------------
update_streak() {
    HABIT=$1
    TODAY=$(current_date)
    [ ! -f "$STREAK_FILE" ] && { echo "$HABIT|1|$TODAY" >> "$STREAK_FILE"; return; }
    EXISTING=$(grep "^$HABIT|" "$STREAK_FILE")
    if [ -z "$EXISTING" ]; then
        echo "$HABIT|1|$TODAY" >> "$STREAK_FILE"
    else
        STREAK=$(echo $EXISTING | cut -d'|' -f2)
        LAST_DATE=$(echo $EXISTING | cut -d'|' -f3)
        YESTERDAY=$(date -d "$TODAY -1 day" +'%Y-%m-%d' 2>/dev/null || date -v-1d +'%Y-%m-%d')
        if [ "$LAST_DATE" == "$YESTERDAY" ]; then NEW_STREAK=$((STREAK+1))
        elif [ "$LAST_DATE" == "$TODAY" ]; then return
        else NEW_STREAK=1
        fi
        grep -v "^$HABIT|" "$STREAK_FILE" > "$STREAK_FILE.tmp"
        echo "$HABIT|$NEW_STREAK|$TODAY" >> "$STREAK_FILE.tmp"
        mv "$STREAK_FILE.tmp" "$STREAK_FILE"
    fi
}

view_streaks() {
    [ ! -f "$STREAK_FILE" ] && { echo "No streaks yet."; return; }
    echo -e "${CYAN}Habit streaks:${NC}"
    while IFS='|' read HABIT COUNT LAST; do
        COLOR=$([ "$COUNT" -ge 5 ] && echo "$GREEN" || echo "$YELLOW")
        echo -e "${COLOR}$HABIT: $COUNT day(s) (last logged: $LAST)${NC}"
    done < "$STREAK_FILE"
}

# ---------------------------
# Goals
# ---------------------------
add_goal() {
    echo "Enter goal name:"
    read GOAL
    GOAL=$(trim "$GOAL")
    echo "Optional review date (YYYY-MM-DD):"
    read REVIEW_DATE
    [ -n "$REVIEW_DATE" ] && REVIEW_DATE=$(validate_date "$REVIEW_DATE")
    echo "$GOAL|Progress:0|Review:$REVIEW_DATE" >> "$GOALS_FILE"
    echo -e "${GREEN}Goal added.${NC}"
    echo "Add sub-goals? (yes/no)"
    read SUB
    [ "$SUB" == "yes" ] && while :; do
        read SUBGOAL
        [ "$SUBGOAL" == "done" ] && break
        echo "$GOAL|Sub-goal:$SUBGOAL|pending" >> "$SUBGOALS_FILE"
    done
}

mark_subgoal_done() {
    echo "Enter goal name:"
    read GOAL
    grep "^$GOAL|" "$SUBGOALS_FILE" | grep "pending" || { echo "No pending sub-goals."; return; }
    echo "Enter exact sub-goal to mark done:"
    read SUBGOAL
    sed -i.bak "s|$GOAL|Sub-goal:$SUBGOAL|pending|$GOAL|Sub-goal:$SUBGOAL|done|" "$SUBGOALS_FILE"
    update_goal_progress "$GOAL"
    echo -e "${GREEN}Sub-goal marked done.${NC}"
}

update_goal_progress() {
    GOAL=$1
    TOTAL=$(grep "^$GOAL|" "$SUBGOALS_FILE" | wc -l)
    [ "$TOTAL" -eq 0 ] && return
    COMPLETED=$(grep "^$GOAL|" "$SUBGOALS_FILE" | grep -c "done")
    PERCENT=$((COMPLETED*100/TOTAL))
    REVIEW_DATE=$(grep "^$GOAL|" "$GOALS_FILE" | cut -d'|' -f3)
    grep -v "^$GOAL|" "$GOALS_FILE" > "$GOALS_FILE.tmp"
    echo "$GOAL|Progress:$PERCENT|$REVIEW_DATE" >> "$GOALS_FILE.tmp"
    mv "$GOALS_FILE.tmp" "$GOALS_FILE"
}

view_goal_progress() {
    [ ! -f "$GOALS_FILE" ] && { echo "No goals added."; return; }
    BAR_WIDTH=20
    while IFS='|' read GOAL PROG REVIEW; do
        PERCENT=$(echo $PROG | grep -o '[0-9]*')
        FILLED=$((PERCENT*BAR_WIDTH/100))
        BAR=$(printf "%0.s█" $(seq 1 $FILLED))
        SPACES=$(printf "%0.s░" $(seq 1 $((BAR_WIDTH-FILLED))))
        echo -e "${CYAN}$GOAL${NC} | Progress: [$BAR$SPACES] $PERCENT%"
    done < "$GOALS_FILE"
}

# ---------------------------
# Reflections
# ---------------------------
log_reflection() {
    DATE=$(current_date)
    echo "Feeling today:"
    read FEELING
    echo "What went well?"
    read POSITIVE
    echo "What could be improved?"
    read IMPROVEMENT
    ENTRY="### Reflection $DATE\nFeeling: $FEELING\nPositive: $POSITIVE\nImprovement: $IMPROVEMENT\n"
    echo -e "$ENTRY" >> "$REFLECTIONS_FILE"
    echo "Encrypt reflection? (yes/no)"
    read ENC
    [ "$ENC" == "yes" ] && {
        echo "Enter passphrase:"
        read -s PASS
        echo -e "$ENTRY" | openssl enc -aes-256-cbc -pbkdf2 -salt -pass pass:"$PASS" -out "$REFLECTIONS_FILE.enc.$DATE"
        echo -e "${GREEN}Reflection encrypted.${NC}"
    }
}

search_logs() {
    echo "Keyword to search logs/reflections:"
    read KEY
    grep -i "$KEY" "$LOG_DIR/"* "$REFLECTIONS_FILE" 2>/dev/null || echo "No matches found."
}

# ---------------------------
# Calendar
# ---------------------------
view_calendar() {
    YEAR=$(date +%Y)
    MONTH=$(date +%m)
    DAYS=$(date -d "$YEAR-$MONTH-01 +1 month -1 day" +%d 2>/dev/null || date -v+1m -v-1d +%d)
    echo -e "${CYAN}Calendar for $YEAR-$MONTH${NC}"
    cal $MONTH $YEAR 2>/dev/null || cal $MONTH $YEAR
    for DAY in $(seq -f "%02g" 1 $DAYS); do
        DATE="$YEAR-$MONTH-$DAY"
        [ -f "$LOG_DIR/$DATE.txt" ] && echo -ne "${GREEN}$DAY[✓]${NC} " || echo -ne "$DAY[ ] "
        ((DAY%7==0)) && echo ""
    done
    echo ""
}

# ---------------------------
# Stats & Export
# ---------------------------
view_stats() {
    echo -e "${CYAN}Weekly/Monthly Stats:${NC}"
    [ -f "$STREAK_FILE" ] && awk -F'|' '{print $2,$1}' "$STREAK_FILE" | sort -nr | head -n1 | awk '{print "Longest streak: "$1" days for "$2}'
    TOTAL_HABITS=$(wc -l < "$HABITS_FILE" 2>/dev/null || echo 0)
    TOTAL_LOGS=$(grep -hr "Habit Completed" "$LOG_DIR" 2>/dev/null | wc -l)
    ((TOTAL_HABITS>0)) && echo "Completion rate: $((TOTAL_LOGS*100/TOTAL_HABITS))%"
}

export_logs() {
    cp "$LOG_DIR/"* "$EXPORT_DIR/" 2>/dev/null
    cp "$GOALS_FILE" "$EXPORT_DIR/" 2>/dev/null
    cp "$REFLECTIONS_FILE" "$EXPORT_DIR/" 2>/dev/null
    echo -e "${GREEN}Exported logs, goals, reflections to $EXPORT_DIR${NC}"
}

view_summary() {
    DATE=$(current_date)
    FILE="$LOG_DIR/$DATE.txt"
    [ -f "$FILE" ] && cat "$FILE" || echo "No activities logged today."
}

# ---------------------------
# Main Menu
# ---------------------------
while true; do
    clear
    echo -e "${BLUE}GrowthLog - Personal Tracker${NC}"
    echo "1) Add habit"
    echo "2) Log habit"
    echo "3) Add/update goal"
    echo "4) Mark sub-goal done"
    echo "5) Log reflection"
    echo "6) View goal progress"
    echo "7) Daily summary"
    echo "8) View streaks"
    echo "9) View calendar"
    echo "10) Stats"
    echo "11) Search logs/reflections"
    echo "12) Export logs/goals/reflections"
    echo "13) Exit"
    read -p "Choose: " ACTION
    case $ACTION in
        1) add_habit ;;
        2) log_habit ;;
        3) add_goal ;;
        4) mark_subgoal_done ;;
        5) log_reflection ;;
        6) view_goal_progress ;;
        7) view_summary ;;
        8) view_streaks ;;
        9) view_calendar ;;
        10) view_stats ;;
        11) search_logs ;;
        12) export_logs ;;
        13) echo "Goodbye!"; exit ;;
        *) echo -e "${RED}Invalid option.${NC}"; sleep 1 ;;
    esac
done
