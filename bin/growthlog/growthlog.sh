#!/bin/bash

# growthlog.sh - A holistic personal growth tracker. Logs habits, goals, reflections, and more.
# Designed to help track your progress, mindset, and daily insights.

TRACKER_DIR="$HOME/growthlog"
LOG_DIR="$TRACKER_DIR/logs"
GOALS_FILE="$TRACKER_DIR/goals.txt"
HABITS_FILE="$TRACKER_DIR/habits.txt"
REFLECTIONS_FILE="$TRACKER_DIR/reflections.md"

# Create directories if they don't exist
mkdir -p "$LOG_DIR"
mkdir -p "$TRACKER_DIR"

# Function to add a new habit to track
add_habit() {
    echo "Enter the habit you want to track (e.g., Exercise, Meditation):"
    read HABIT_NAME
    echo "Enter a brief description (optional):"
    read DESCRIPTION

# Function to log a completed habit for today
log_habit() {
    DATE=$(date +'%Y-%m-%d')
    echo "Which habit did you complete today?"
    cat "$HABITS_FILE" | while IFS="|" read NAME DESC; do
        echo "- $NAME"
    done
    echo "Enter the habit you completed today (exact match):"
    read COMPLETED_HABIT
    echo "Any notes for today? (Optional)"
    read NOTES

    LOG_FILE="$LOG_DIR/$DATE.txt"

    # Log the habit for today
    echo "$DATE: Habit Completed: $COMPLETED_HABIT | Notes: $NOTES" >> "$LOG_FILE"
    echo "Habit logged for $DATE."
}

# Function to add or update a goal
add_goal() {
    echo "Enter your long-term goal (e.g., Learn a new language, Run a marathon):"
    read GOAL
    echo "Optional: When do you want to review this goal? (YYYY-MM-DD, leave blank for no review)"
    read REVIEW_DATE

    # Save the goal to the goals file
    echo "$GOAL | Review: $REVIEW_DATE" >> "$GOALS_FILE"
    echo "Goal added successfully."
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

    # Save the habit to the habits file
    echo "$HABIT_NAME|$DESCRIPTION" >> "$HABITS_FILE"
    echo "'$HABIT_NAME' added successfully to your habit tracker."
}


# Function to view progress on goals
view_goals() {
    echo "Your long-term goals:"
    if [ -f "$GOALS_FILE" ]; then
        cat "$GOALS_FILE"
    else
        echo "No goals added yet. Start tracking your long-term goals!"
    fi
}

# Function to see a summary of your growth logs for today
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

# Function to show an overview of your reflections
view_reflections() {
    echo "Your daily reflections:"
    if [ -f "$REFLECTIONS_FILE" ]; then
        cat "$REFLECTIONS_FILE"
    else
        echo "No reflections saved yet. Start reflecting on your day!"
    fi
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
echo "7) View past reflections"
echo "8) Exit"
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
        view_goals
        ;;
    6)
        view_summary
        ;;
    7)
        view_reflections
        ;;
    8)
        echo "Goodbye!"
        ;;
    *)
        echo "Invalid option. Please choose a valid action."
        ;;
esac
