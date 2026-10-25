#!/bin/bash
# Signs a Nix-built Kasane.app as <user>, puts it root-owned at /Applications/Kasane.app, and
# restarts kasaned and the menu bar app. nix-darwin runs it on every activation, so it leaves an
# installed app alone while it came from the same store path.
#   install-app.sh <identity> <Kasane.app in /nix/store> <user>   (as root)
set -euo pipefail
# The tools here are macOS's: nix-darwin's activation puts GNU coreutils first. Exported, so the
# commands run through sudo find them too.
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

usage="usage: install-app.sh <identity> <Kasane.app in /nix/store> <user>"
identity="${1:?$usage}"
source_app="${2:?$usage}"
user="${3:?$usage}"
scripts="$(cd "$(dirname "$0")" && pwd)"
installed=/Applications/Kasane.app
label=dev.mei.kasaned

if [[ $(id -u) -ne 0 ]]; then
  echo "error: install-app.sh must run as root" >&2
  exit 1
fi
if [[ $source_app != /nix/store/* ]]; then
  echo "error: $source_app is not in /nix/store" >&2
  exit 1
fi

# grep reads all of plutil's output: with -q, plutil could die of SIGPIPE and fail the pipeline.
if [[ -e $installed ]] \
  && plutil -p "$installed/Contents/Info.plist" | grep -F "\"KasaneSource\" => \"$source_app\"" >/dev/null; then
  echo "kasane: $installed is up to date"
  exit 0
fi

# Signing needs the user's login keychain, so it runs as the user in the user's session.
uid="$(id -u "$user")"
as_user() { launchctl asuser "$uid" sudo --user="$user" --set-home -- "$@"; }
staging="$(as_user mktemp -d)"
trap 'rm -rf "$staging"' EXIT
as_user "$scripts/sign-app.sh" "$identity" "$source_app" "$staging/Kasane.app"

# Nothing installed has changed up to here, so a failed signature leaves kasane running as it was.
echo "kasane: installing $source_app"
was_running=false
if pgrep -x Kasane >/dev/null; then
  was_running=true
  pkill -x Kasane
fi
rm -rf "$installed"
ditto "$staging/Kasane.app" "$installed"
chown -R root:wheel "$installed"
# On a first install kasaned is not loaded yet; nix-darwin loads it after this script.
if launchctl print "system/$label" >/dev/null 2>&1; then
  launchctl kickstart -k "system/$label"
fi
if $was_running; then
  as_user open "$installed"
fi
