#!/bin/bash

# growthlog.sh - Comprehensive personal growth tracker
# Features: habits, goals with sub-goals, reflections (optional encryption), streaks, calendar, stats, search, export

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
# Utility functions
# ---------------------------
validate_number() {
    local INPUT=$1
    while ! [[ "$INPUT" =~ ^[0-9]+$ ]]; do
        echo "Enter a valid number:"
        read INPUT
    done
    echo "$INPUT"
}

current_date() {
    date +'%Y-%m-%d'
}

# ---------------------------
# Habit Management
# ---------------------------
add_habit() {
    echo "Enter habit name:"
    read HABIT_NAME

    if grep -q "^$HABIT_NAME|" "$HABITS_FILE" 2>/dev/null; then
        echo "'$HABIT_NAME' already exists."
        return
    fi

    echo "Enter brief description (optional):"
    read DESCRIPTION

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
    echo "'$HABIT_NAME' added successfully under category $CATEGORY."
}

log_habit() {
    DATE=$(current_date)
    if [ ! -f "$HABITS_FILE" ]; then
        echo "No habits to log."
        return
    fi

    echo "Your habits:"
    awk -F"|" '{print "- " $1 " (" $4 ", " $3 ")"}' "$HABITS_FILE"

    echo "Enter the habit completed today (exact match):"
    read COMPLETED_HABIT

    if ! grep -q "^$COMPLETED_HABIT|" "$HABITS_FILE"; then
        echo "Habit not found."
        return
    fi

    echo "How many times did you complete $COMPLETED_HABIT today?"
    read TIMES
    TIMES=$(validate_number "$TIMES")

    for i in $(seq 1 $TIMES); do
        echo "Notes (optional):"
        read NOTES
        LOG_FILE="$LOG_DIR/$DATE.txt"
        echo "$DATE: Habit Completed: $COMPLETED_HABIT | Notes: $NOTES" >> "$LOG_FILE"
        update_streak "$COMPLETED_HABIT"
    done
    echo "Logged $COMPLETED_HABIT $TIMES time(s) for $DATE."
}

# ---------------------------
# Streak Management
# ---------------------------
update_streak() {
    HABIT=$1
    TODAY=$(current_date)
    if [ ! -f "$STREAK_FILE" ]; then
        echo "$HABIT|1|$TODAY" >> "$STREAK_FILE"
        return
    fi

    EXISTING=$(grep "^$HABIT|" "$STREAK_FILE")
    if [ -z "$EXISTING" ]; then
        echo "$HABIT|1|$TODAY" >> "$STREAK_FILE"
    else
        STREAK=$(echo $EXISTING | cut -d'|' -f2)
        LAST_DATE=$(echo $EXISTING | cut -d'|' -f3)
        YESTERDAY=$(date -d "$TODAY -1 day" +'%Y-%m-%d' 2>/dev/null || date -v-1d +'%Y-%m-%d')
        if [ "$LAST_DATE" == "$YESTERDAY" ]; then
            NEW_STREAK=$((STREAK+1))
        elif [ "$LAST_DATE" == "$TODAY" ]; then
            return
        else
            NEW_STREAK=1
        fi
        grep -v "^$HABIT|" "$STREAK_FILE" > "$STREAK_FILE.tmp"
        echo "$HABIT|$NEW_STREAK|$TODAY" >> "$STREAK_FILE.tmp"
        mv "$STREAK_FILE.tmp" "$STREAK_FILE"
    fi
}

view_streaks() {
    if [ ! -f "$STREAK_FILE" ]; then
        echo "No streaks yet."
        return
    fi
    echo "Habit streaks:"
    while IFS='|' read HABIT COUNT LAST; do
        echo "$HABIT: $COUNT day(s) (last logged: $LAST)"
    done < "$STREAK_FILE"
}

# ---------------------------
# Goal Management with Sub-goals
# ---------------------------
add_goal() {
    echo "Enter goal name:"
    read GOAL
    echo "Optional review date (YYYY-MM-DD):"
    read REVIEW_DATE

    echo "$GOAL|Progress:0|Review:$REVIEW_DATE" >> "$GOALS_FILE"
    echo "Goal added."

    echo "Add sub-goals? (yes/no)"
    read SUB
    if [ "$SUB" == "yes" ]; then
        while :; do
            read SUBGOAL
            [ "$SUBGOAL" == "done" ] && break
            echo "$GOAL|Sub-goal:$SUBGOAL|pending" >> "$SUBGOALS_FILE"
        done
    fi
}

mark_subgoal_done() {
    echo "Enter goal name:"
    read GOAL
    grep "^$GOAL|" "$SUBGOALS_FILE" | grep "pending" || { echo "No pending sub-goals."; return; }
    echo "Enter exact sub-goal name to mark done:"
    read SUBGOAL
    sed -i.bak "s|$GOAL|Sub-goal:$SUBGOAL|pending|$GOAL|Sub-goal:$SUBGOAL|done|" "$SUBGOALS_FILE"
    update_goal_progress "$GOAL"
    echo "Sub-goal marked done and progress updated."
}

update_goal_progress() {
    GOAL=$1
    TOTAL=$(grep "^$GOAL|" "$SUBGOALS_FILE" | wc -l)
    if ((TOTAL==0)); then return; fi
    COMPLETED=$(grep "^$GOAL|" "$SUBGOALS_FILE" | grep -c "done")
    PERCENT=$((COMPLETED*100/TOTAL))
    REVIEW_DATE=$(grep "^$GOAL|" "$GOALS_FILE" | cut -d'|' -f3)
    grep -v "^$GOAL|" "$GOALS_FILE" > "$GOALS_FILE.tmp"
    echo "$GOAL|Progress:$PERCENT|$REVIEW_DATE" >> "$GOALS_FILE.tmp"
    mv "$GOALS_FILE.tmp" "$GOALS_FILE"
}

view_goal_progress() {
    if [ ! -f "$GOALS_FILE" ]; then
        echo "No goals added."
        return
    fi
    BAR_WIDTH=20
    while IFS='|' read GOAL PROG REVIEW; do
        PERCENT=$(echo $PROG | grep -o '[0-9]*')
        FILLED=$((PERCENT*BAR_WIDTH/100))
        BAR=$(printf "%0.s#" $(seq 1 $FILLED))
        SPACES=$(printf "%0.s-" $(seq 1 $((BAR_WIDTH-FILLED))))
        echo "$GOAL | Progress: [$BAR$SPACES] $PERCENT%"
    done < "$GOALS_FILE"
}

# ---------------------------
# Reflections (Optional Encryption)
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
    if [ "$ENC" == "yes" ]; then
        echo "Enter passphrase:"
        read -s PASS
        echo -e "$ENTRY" | openssl enc -aes-256-cbc -pbkdf2 -salt -pass pass:"$PASS" -out "$REFLECTIONS_FILE.enc.$DATE"
        echo "Reflection encrypted."
    fi
}

search_logs() {
    echo "Enter keyword to search logs/reflections:"
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
    echo "Calendar for $YEAR-$MONTH"
    cal $MONTH $YEAR 2>/dev/null || cal $MONTH $YEAR
    for DAY in $(seq -f "%02g" 1 $DAYS); do
        DATE="$YEAR-$MONTH-$DAY"
        if [ -f "$LOG_DIR/$DATE.txt" ]; then
            echo -n "$DAY:[✓] "
        else
            echo -n "$DAY:[ ] "
        fi
        if ((DAY%7==0)); then echo ""; fi
    done
    echo ""
}

# ---------------------------
# Stats and Reports
# ---------------------------
view_stats() {
    echo "Weekly/Monthly Stats:"
    if [ -f "$STREAK_FILE" ]; then
        LONGEST=$(awk -F'|' '{print $2,$1}' "$STREAK_FILE" | sort -nr | head -n1)
        echo "Longest streak: $LONGEST"
    fi
    TOTAL_HABITS=$(wc -l < "$HABITS_FILE" 2>/dev/null || echo 0)
    TOTAL_LOGS=$(grep -hr "Habit Completed" "$LOG_DIR" 2>/dev/null | wc -l)
    if ((TOTAL_HABITS>0)); then
        RATE=$((TOTAL_LOGS*100/TOTAL_HABITS))
        echo "Completion rate: $RATE%"
    fi
}

# ---------------------------
# Export / Backup
# ---------------------------
export_logs() {
    cp "$LOG_DIR/"* "$EXPORT_DIR/"
    cp "$GOALS_FILE" "$EXPORT_DIR/"
    cp "$REFLECTIONS_FILE" "$EXPORT_DIR/"
    echo "Exported logs, goals, and reflections to $EXPORT_DIR"
}

# ---------------------------
# Main Menu Loop
# ---------------------------
while true; do
    clear
    echo "GrowthLog - Personal Tracker"
    echo "1) Add a new habit"
    echo "2) Log a habit for today"
    echo "3) Add or update a goal"
    echo "4) Mark sub-goal as done"
    echo "5) Log today's reflection"
    echo "6) View goal progress"
    echo "7) View daily summary"
    echo "8) View habit streaks"
    echo "9) View calendar"
    echo "10) View stats"
    echo "11) Search logs/reflections"
    echo "12) Export logs/goals/reflections"
    echo "13) Exit"

    read ACTION
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
        *) echo "Invalid option."; sleep 1 ;;
    esac
done
