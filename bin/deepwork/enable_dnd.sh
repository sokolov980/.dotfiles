#!/usr/bin/env zsh
# Enable Do Not Disturb on macOS

# For macOS 12+ (Monterey / Ventura)
defaults -currentHost write ~/Library/Preferences/ByHost/com.apple.notificationcenterui doNotDisturb -boolean true
defaults -currentHost write ~/Library/Preferences/ByHost/com.apple.notificationcenterui doNotDisturbDate -date "$(date)"
killall NotificationCenter 2>/dev/null || true

echo "[✓] DND enabled"
