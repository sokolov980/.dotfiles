#!/usr/bin/env zsh
# Disable Do Not Disturb on macOS

defaults -currentHost write ~/Library/Preferences/ByHost/com.apple.notificationcenterui doNotDisturb -boolean false
defaults -currentHost write ~/Library/Preferences/ByHost/com.apple.notificationcenterui doNotDisturbDate -date "$(date)"
killall NotificationCenter 2>/dev/null || true

echo "[✓] DND disabled"
