#!/bin/bash
# Puts Kasane.app root-owned at /Applications/Kasane.app, quitting the running menu bar app first.
#   scripts/install-app.sh <Kasane.app>
set -euo pipefail

app="${1:?usage: install-app.sh <Kasane.app>}"
installed=/Applications/Kasane.app

if pgrep -x Kasane >/dev/null; then pkill -x Kasane; fi
sudo rm -rf "$installed"
sudo ditto "$app" "$installed"
sudo chown -R root:wheel "$installed"
