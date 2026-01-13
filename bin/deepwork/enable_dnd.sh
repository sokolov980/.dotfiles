#!/usr/bin/env zsh
# Enable Do Not Disturb
defaults -currentHost write ~/Library/Preferences/ByHost/com.apple.notificationcenterui doNotDisturb -boolean true
defaults -currentHost write ~/Library/Preferences/ByHost/com.apple.notificationcenterui doNotDisturbDate -date "$(date)"
killall NotificationCenter
echo "[✓] DND enabled"
