#!/usr/bin/env zsh
# Enable Do Not Disturb using assigned keyboard shortcut
osascript <<EOF
tell application "System Events"
    keystroke space using {command down, control down, option down}
end tell
EOF
