#!/bin/bash

# growthlog.sh - A comprehensive personal growth tracker
# Tracks habits, goals, reflections, streaks, calendar, stats, and encrypted reflections

TRACKER_DIR="$HOME/growthlog"
LOG_DIR="$TRACKER_DIR/logs"
GOALS_FILE="$TRACKER_DIR/goals.txt"
HABITS_FILE="$TRACKER_DIR/habits.txt"
STREAK_FILE="$TRACKER_DIR/streaks.txt"
REFLECTIONS_FILE="$TRACKER_DIR/reflections.md"
SUBGOALS_FILE="$TRACKER_DIR/subgoals.txt"

mkdir -p "$LOG_DIR"
mkdir -p "$TRACKER_DIR"

# ---------------------------
# Utility functions
# ---------------------------
validate_number() {
    local INPUT
    INPUT=$1
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
# Habits
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

    echo "Enter priority (1=High, 2=Medium, 3=Low):"
    PRIORITY=$(validate_number $(read PRIORITY; echo $PRIORITY))
    while ! [[ "$PRIORITY" =~ ^[1-3]$ ]]; do
        echo "Priority must be 1, 2, or 3:"
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
        echo "No habits to log. Add habits first."
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
    TIMES=$(validate_number $TIMES)

    for i in $(seq 1 $TIMES); do
        echo "Notes (optional):"
        read NOTES
        LOG_FILE="$LOG_DIR/$DATE.txt"
        echo "$DATE: Habit Completed: $COMPLETED_HABIT | Notes: $NOTES" >> "$LOG_FILE"
        update_streak "$COMPLETED_HABIT"
    done

    echo "Logged $COMPLETED_HABIT $TIMES time(s) for $DATE."
}

# Persistent streaks
update_streak() {
    HABIT=$1
    TODAY=$(current_date)
    if [ ! -f "$STREAK_FILE" ]; then
        echo "$HABIT|1|$TODAY" >> "$STREAK_FILE"
        return
    fi

    # Get existing streak and last log
    EXISTING=$(grep "^$HABIT|" "$STREAK_FILE")
    if [ -z "$EXISTING" ]; then
        echo "$HABIT|1|$TODAY" >> "$STREAK_FILE"
    else
        STREAK=$(echo $EXISTING | cut -d'|' -f2)
        LAST_DATE=$(echo $EXISTING | cut -d'|' -f3)
        # Check if yesterday was logged
        YESTERDAY=$(date -d "$TODAY -1 day" +'%Y-%m-%d' 2>/dev/null || date -v-1d +'%Y-%m-%d')
        if [ "$LAST_DATE" == "$YESTERDAY" ]; then
            NEW_STREAK=$((STREAK +1))
        elif [ "$LAST_DATE" == "$TODAY" ]; then
            return
        else
            NEW_STREAK=1
        fi
        # Update streak file
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
# Goals
# ---------------------------
add_goal() {
    echo "Enter goal name:"
    read GOAL
    echo "Progress percentage (0-100):"
    PROGRESS=$(validate_number $(read PROGRESS; echo $PROGRESS))
    while (( PROGRESS <0 || PROGRESS >100 )); do
        echo "Enter a number between 0-100:"
        read PROGRESS
    done
    echo "Optional review date (YYYY-MM-DD):"
    read REVIEW_DATE

    echo "$GOAL|Progress:$PROGRESS|Review:$REVIEW_DATE" >> "$GOALS_FILE"
    echo "Goal added."

    echo "Add sub-goals? (yes/no)"
    read SUB
    if [ "$SUB" == "yes" ]; then
        while :; do
            read SUBGOAL
            [ "$SUBGOAL" == "done" ] && break
            echo "$GOAL|Sub-goal:$SUBGOAL" >> "$SUBGOALS_FILE"
        done
    fi
}

view_goal_progress() {
    if [ ! -f "$GOALS_FILE" ]; then
        echo "No goals added."
        return
    fi

    BAR_WIDTH=20
    while IFS='|' read GOAL PROG REVIEW; do
        PERCENT=$(echo $PROG | grep -o '[0-9]*')
        FILLED=$(( PERCENT*BAR_WIDTH/100 ))
        BAR=$(printf "%0.s#" $(seq 1 $FILLED))
        SPACES=$(printf "%0.s-" $(seq 1 $((BAR_WIDTH-FILLED))))
        echo "$GOAL | Progress: [$BAR$SPACES] $PERCENT%"
    done < "$GOALS_FILE"
}

# ---------------------------
# Reflections (with optional encryption)
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

    echo "Do you want to encrypt this reflection? (yes/no)"
    read ENC
    if [ "$ENC" == "yes" ]; then
        echo "Enter a passphrase:"
        read -s PASS
        echo -e "$ENTRY" | openssl enc -aes-256-cbc -pbkdf2 -salt -pass pass:"$PASS" -out "$REFLECTIONS_FILE.enc.$DATE"
        echo "Reflection encrypted."
    fi
}

search_logs() {
    echo "Enter keyword to search in logs or reflections:"
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
# Weekly/Monthly stats
# ---------------------------
view_stats() {
    echo "Weekly/Monthly Stats:"
    # Longest streak
    if [ -f "$STREAK_FILE" ]; then
        LONGEST=$(awk -F'|' '{print $2,$1}' "$STREAK_FILE" | sort -nr | head -n1)
        echo "Longest streak: $LONGEST"
    fi
    # Completion rate (approx)
    TOTAL_HABITS=$(wc -l < "$HABITS_FILE" 2>/dev/null || echo 0)
    TOTAL_LOGS=$(grep -hr "Habit Completed" "$LOG_DIR" 2>/dev/null | wc -l)
    if ((TOTAL_HABITS>0)); then
        RATE=$((TOTAL_LOGS*100/TOTAL_HABITS))
        echo "Completion rate: $RATE%"
    fi
}

# ---------------------------
# Main Menu
# ---------------------------
while true; do
    clear
    echo "GrowthLog - Personal Tracker"
    echo "1) Add a new habit"
    echo "2) Log a habit for today"
    echo "3) Add or update a goal"
    echo "4) Log today's reflection"
    echo "5) View goal progress"
    echo "6) View daily summary"
    echo "7) View habit streaks"
    echo "8) View calendar"
    echo "9) View stats"
    echo "10) Search logs/reflections"
    echo "11) Exit"

    read ACTION
    case $ACTION in
        1) add_habit ;;
        2) log_habit ;;
        3) add_goal ;;
        4) log_reflection ;;
        5) view_goal_progress ;;
        6) view_summary ;;
        7) view_streaks ;;
        8) view_calendar ;;
        9) view_stats ;;
        10) search_logs ;;
        11) echo "Goodbye!"; exit ;;
        *) echo "Invalid option."; sleep 1 ;;
    esac
done
