#!/usr/bin/env zsh
# Disable Do Not Disturb
defaults -currentHost write ~/Library/Preferences/ByHost/com.apple.notificationcenterui doNotDisturb -boolean false
defaults -currentHost write ~/Library/Preferences/ByHost/com.apple.notificationcenterui doNotDisturbDate -date "$(date)"
killall NotificationCenter
echo "[✓] DND disabled"
