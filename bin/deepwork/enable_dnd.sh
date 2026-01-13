#!/usr/bin/env zsh
# Enable DND using ⌃⌥⌘ D

osascript <<EOF
tell application "System Events"
    keystroke "d" using {control down, option down, command down}
end tell
EOF
