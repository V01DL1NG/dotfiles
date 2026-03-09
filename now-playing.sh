#!/usr/bin/env bash

# Try Spotify via AppleScript first
if osascript -e 'application "Spotify" is running' 2>/dev/null | grep -q true; then
  result=$(osascript -e 'tell application "Spotify" to if player state is playing then artist of current track & " - " & name of current track' 2>/dev/null)
  if [ -n "$result" ]; then
    echo "$result" | cut -c1-50
    exit 0
  fi
fi

# Try SoundCloud in Edge (search all tabs)
if osascript -e 'application "Microsoft Edge" is running' 2>/dev/null | grep -q true; then
  result=$(osascript \
    -e 'tell application "Microsoft Edge"' \
    -e '  repeat with w in windows' \
    -e '    repeat with t in tabs of w' \
    -e '      set tabTitle to title of t' \
    -e '      if tabTitle contains "SoundCloud" then' \
    -e '        set AppleScript'"'"'s text item delimiters to " | "' \
    -e '        return item 1 of (text items of tabTitle)' \
    -e '      end if' \
    -e '    end repeat' \
    -e '  end repeat' \
    -e 'end tell' 2>/dev/null)
  if [ -n "$result" ]; then
    echo "$result" | cut -c1-50
    exit 0
  fi
fi

# Fall back to nowplaying-cli (Apple Music, etc.)
result=$(nowplaying-cli get title 2>/dev/null)
if [ -n "$result" ] && [ "$result" != "null" ]; then
  echo "$result" | cut -c1-50
fi
