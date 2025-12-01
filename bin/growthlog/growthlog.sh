#!/bin/bash

# growthlog.sh - A comprehensive personal growth tracker
# This script tracks habits, long-term goals, daily reflections, and more.
# It features streak tracking, progress summaries, goal completion reports, and calendar views.

TRACKER_DIR="$HOME/growthlog"
LOG_DIR="$TRACKER_DIR/logs"
GOALS_FILE="$TRACKER_DIR/goals.txt"
HABITS_FILE="$TRACKER_DIR/habits.txt"
STREAK_FILE="$TRACKER_DIR/streaks.txt"
REFLECTIONS_FILE="$TRACKER_DIR/reflections.md"
SUBGOALS_FILE="$TRACKER_DIR/subgoals.txt"

# Create directories if they don't exist
mkdir -p "$LOG_DIR"
mkdir -p "$TRACKER_DIR"

# Function to add a new habit to track
add_habit() {
    echo "Enter the habit you want to track (e.g., Exercise, Meditation):"
    read HABIT_NAME
    echo "Enter a brief description (optional):"
    read DESCRIPTION
    echo "Enter the priority for this habit (1 = High, 2 = Medium, 3 = Low):"
    read PRIORITY

    # Check if habit already exists to avoid duplicates
    if grep -q "$HABIT_NAME" "$HABITS_FILE"; then
        echo "'$HABIT_NAME' already exists. Use a different name or update the description."
        return
    fi

    # Save the habit to the habits file with priority
    echo "$HABIT_NAME|$DESCRIPTION|Priority: $PRIORITY" >> "$HABITS_FILE"
    echo "'$HABIT_NAME' added successfully."
}

# Function to log a completed habit for today (multiple completions allowed)
log_habit() {
    DATE=$(date +'%Y-%m-%d')
    echo "Which habit did you complete today?"
    cat "$HABITS_FILE" | while IFS="|" read NAME DESC PRIORITY; do
        echo "- $NAME (Priority: $PRIORITY)"
    done
    echo "Enter the habit you completed today (exact match):"
    read COMPLETED_HABIT

    # Check if the habit exists
    if ! grep -q "$COMPLETED_HABIT" "$HABITS_FILE"; then
        echo "Habit '$COMPLETED_HABIT' not found. Please add it first."
        return
    fi

    echo "How many times did you complete $COMPLETED_HABIT today?"
    read TIMES

    for i in $(seq 1 $TIMES); do
        echo "Any notes for this completion? (Optional)"
        read NOTES

        # Log the habit completion
        LOG_FILE="$LOG_DIR/$DATE.txt"
        echo "$DATE: Habit Completed: $COMPLETED_HABIT | Notes: $NOTES" >> "$LOG_FILE"
        echo "Habit logged for $DATE."

        # Update streaks
        update_streak "$COMPLETED_HABIT"
    done
}

# Function to update streaks for habits
update_streak() {
    HABIT=$1
    LAST_LOG_DATE=$(grep "$HABIT" "$LOG_DIR/"* | tail -n 1 | cut -d' ' -f1)
    if [ "$LAST_LOG_DATE" == "$(date +'%Y-%m-%d')" ]; then
        echo "No streaks updated, already logged today."
        return
    fi

    # Track streaks
    if [ -f "$STREAK_FILE" ]; then
        STREAK=$(grep "$HABIT" "$STREAK_FILE" | cut -d'|' -f2)
        if [ -z "$STREAK" ]; then
            STREAK=0
        fi
        NEW_STREAK=$((STREAK + 1))
        sed -i "/$HABIT/c\\$HABIT|$NEW_STREAK" "$STREAK_FILE"
    else
        echo "$HABIT|1" >> "$STREAK_FILE"
    fi

    echo "Streak for '$HABIT' updated."
}

# Function to add a long-term goal with sub-goals
add_goal() {
    echo "Enter your long-term goal (e.g., Learn a new language, Run a marathon):"
    read GOAL
    echo "Enter your goal's progress (e.g., 50%):"
    read PROGRESS
    echo "Optional: When do you want to review this goal? (YYYY-MM-DD, leave blank for no review)"
    read REVIEW_DATE

    # Save the goal to the goals file
    echo "$GOAL | Progress: $PROGRESS | Review: $REVIEW_DATE" >> "$GOALS_FILE"
    echo "Goal added successfully."

    # Add sub-goals if any
    echo "Do you want to add any sub-goals for this goal? (yes/no)"
    read ADD_SUBGOALS
    if [ "$ADD_SUBGOALS" == "yes" ]; then
        echo "Enter sub-goals for this goal (one per line). Type 'done' when finished:"
        while :; do
            read SUBGOAL
            if [ "$SUBGOAL" == "done" ]; then
                break
            fi
            echo "$GOAL | Sub-goal: $SUBGOAL" >> "$SUBGOALS_FILE"
        done
    fi
}

# Function to log daily reflections
log_reflection() {
    DATE=$(date +'%Y-%m-%d')
    echo "How did you feel today? (e.g., energized, stressed, focused)"
    read FEELING
    echo "What went well today?"
    read POSITIVE
    echo "What could you improve tomorrow?"
    read IMPROVEMENT

    echo "Reflection for $DATE:" > "$REFLECTIONS_FILE"
    echo "Feeling: $FEELING" >> "$REFLECTIONS_FILE"
    echo "Positive: $POSITIVE" >> "$REFLECTIONS_FILE"
    echo "Improvement: $IMPROVEMENT" >> "$REFLECTIONS_FILE"
    echo "Reflection saved."
}

# Function to view progress on goals with a simple progress bar
view_goal_progress() {
    echo "Viewing progress for your goals:"
    if [ -f "$GOALS_FILE" ]; then
        while IFS="|" read GOAL PROGRESS REVIEW_DATE; do
            # Extract the progress percentage
            PERCENTAGE=$(echo $PROGRESS | grep -o '[0-9]*')
            BAR=$(printf "%-${PERCENTAGE}s" "#" | sed 's/ /#/g')  # Bar representation
            SPACES=$(printf "%-$((100 - PERCENTAGE))s" " ")  # Spaces for the remaining part
            echo "$GOAL | Progress: [$BAR$SPACES] $PERCENTAGE%"
        done < "$GOALS_FILE"
    else
        echo "No goals added yet. Start tracking your long-term goals!"
    fi
}

# Function to show a quick summary of today's logs
view_summary() {
    DATE=$(date +'%Y-%m-%d')
    LOG_FILE="$LOG_DIR/$DATE.txt"
    
    if [ -f "$LOG_FILE" ]; then
        echo "Summary for $DATE:"
        cat "$LOG_FILE"
    else
        echo "No activities logged for today."
    fi
}

# Function to view habit streaks
view_streaks() {
    echo "Your habit streaks:"
    if [ -f "$STREAK_FILE" ]; then
        cat "$STREAK_FILE"
    else
        echo "No streaks recorded yet. Start tracking your habits to build streaks!"
    fi
}

# Function to view the calendar-like habit tracker for the current month
view_calendar() {
    echo "Displaying calendar for the current month:"
    cal | awk 'BEGIN {print "Sun Mon Tue Wed Thu Fri Sat"} {print $0}' # Prints the calendar

    CURRENT_MONTH=$(date +'%Y-%m')
    for DAY in $(seq -f "%02g" 1 31); do
        DATE="$CURRENT_MONTH-$DAY"
        LOG_FILE="$LOG_DIR/$DATE.txt"

        if [ -f "$LOG_FILE" ]; then
            echo -n "$DAY: [✓] "
        else
            echo -n "$DAY: [ ] "
        fi
        if [ $((DAY % 7)) -eq 0 ]; then
            echo ""  # New line for each week
        fi
    done
}

# Main Menu
clear
echo "Welcome to GrowthLog: Your personal growth tracker!"
echo "Choose an action:"
echo "1) Add a new habit"
echo "2) Log a habit for today"
echo "3) Add or update a long-term goal"
echo "4) Log today's reflection"
echo "5) View goal progress"
echo "6) View daily summary"
echo "7) View habit streaks"
echo "8) View calendar"
echo "9) Exit"
read ACTION

case $ACTION in
    1)
        add_habit
        ;;
    2)
        log_habit
        ;;
    3)
        add_goal
        ;;
    4)
        log_reflection
        ;;
    5)
        view_goal_progress
        ;;
    6)
        view_summary
        ;;
    7)
        view_streaks
        ;;
    8)
        view_calendar
        ;;
    9)
        echo "Goodbye!"
        ;;
    *)
        echo "Invalid option. Please choose a valid action."
        ;;
esac
