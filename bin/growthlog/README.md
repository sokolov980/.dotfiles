# growthlog

A comprehensive personal growth tracker for the command line.  

> Tracks habits, goals, sub-goals, daily reflections, streaks, calendar, weekly/monthly stats, and allows reflections to be encrypted. 

---

## Usage

```bash
./growthlog.sh
```

Follow the interactive menu to choose actions.

---

## Menu Actions

- `Add habit` Add a new habit with category and priority

- `Log habit` Record a habit completion (supports multiple completions per day)

- `Add/update goal` Add a long-term goal with optional sub-goals

- `Mark sub-goal done` Mark a sub-goal as completed (updates progress automatically)

- `Log reflection` Record daily reflection with optional encryption

- `View goal progress` Show progress bars for all goals

- `Daily summary` Display today’s logged activities

- `View streaks` See habit streaks (color-coded)

- `View calenda`r Calendar view with habit completion markers

- `Stats` Weekly/monthly summary, longest streak, completion rates

- `Search logs/reflections` Keyword search across logs and reflections

- `Export logs/goals/reflections` Export tracked data for backup

---

## Features

- Habit tracking with categories (Health, Learning, Productivity)

- Persistent streak tracking

- Goals with automatic progress calculation based on sub-goals

- Daily reflections with optional encryption (OpenSSL AES-256)

- Calendar view with habit completion markers

- Weekly and monthly stats, including longest streak and completion rate

- Search/filter logs and reflections by keyword

- Export logs, goals, and reflections to a backup directory

- Color-coded CLI for improved readability

- Input validation for numbers, dates, and selections

- Multi-action interactive menu loop

---

## Examples

```bash
# Start the tracker
./growthlog.sh

# Add a new habit
# Follow prompts to enter name, description, priority, and category

# Log a habit completion
# Enter habit name, number of completions, and optional notes

# Add a goal with sub-goals
# Follow prompts to enter goal name, optional review date, and sub-goals

# Mark a sub-goal as completed
# Updates goal progress automatically

# Log daily reflection with encryption
# Enter feelings, positives, improvements; optionally encrypt with passphrase

# View goal progress with color-coded progress bars
./growthlog.sh -> choose "View goal progress"

# Search logs or reflections for keywords
./growthlog.sh -> choose "Search logs/reflections"

# Export all tracked data
./growthlog.sh -> choose "Export logs/goals/reflections"
```

---

## Notes

- Make the script executable: `chmod +x growthlog.sh`

- Run from any terminal in its directory

- Reflections can be optionally encrypted; store passphrases securely

- Export directory: `~/growthlog/exports` for backups

- Configuration files are not required; all data is stored under `~/growthlog`
  
---
