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

    # Save the habit to the habits file
    echo "$HABIT_NAME|$DESCRIPTION" >> "$HABITS_FILE"
    echo "'$HABIT_NAME' added successfully to your habit tracker."
}
