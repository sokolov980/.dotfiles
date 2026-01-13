#!/usr/bin/env zsh
# Enable macOS Do Not Disturb

# Set DND to true
defaults -currentHost write ~/Library/Preferences/ByHost/com.apple.notificationcenterui doNotDisturb -boolean true

# Optionally set a future timestamp (disable auto-off)
defaults -currentHost write ~/Library/Preferences/ByHost/com.apple.notificationcenterui doNotDisturbDate -date "$(date +%s)"

# Restart NotificationCenter to apply changes
killall NotificationCenter 2>/dev/null
