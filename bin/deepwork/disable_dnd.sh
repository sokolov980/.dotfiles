#!/usr/bin/env zsh
# Disable macOS Do Not Disturb

# Set DND to false
defaults -currentHost write ~/Library/Preferences/ByHost/com.apple.notificationcenterui doNotDisturb -boolean false

# Clear any DND timestamp
defaults -currentHost delete ~/Library/Preferences/ByHost/com.apple.notificationcenterui doNotDisturbDate 2>/dev/null

# Restart NotificationCenter to apply changes
killall NotificationCenter 2>/dev/null
