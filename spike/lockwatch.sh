#!/bin/bash
# Log once per second whether IORegistry's IOConsoleUsers marks the console session as locked.
# A root daemon can read this without a GUI session, unlike com.apple.screenIsLocked.
#   ./lockwatch.sh 60    then lock the screen for ~10 s and unlock
set -euo pipefail
end=$((SECONDS + ${1:-60}))
while ((SECONDS < end)); do
  users=$(ioreg -n Root -d1 -a)
  locked=$(plutil -extract IOConsoleUsers.0.CGSSessionScreenIsLocked raw -o - - <<<"$users" 2>/dev/null || echo absent)
  console=$(plutil -extract IOConsoleUsers.0.kCGSSessionOnConsoleKey raw -o - - <<<"$users")
  echo "$(date +%T) locked=$locked onConsole=$console"
  sleep 1
done
