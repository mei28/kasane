#!/bin/bash
# Copies an unsigned Kasane.app, such as the one Nix builds, and signs the copy and the kasaned
# inside it as dev.mei.kasane, so one Input Monitoring grant covers both and survives rebuilds.
# The copy's Info.plist records where it came from as KasaneSource.
#   scripts/sign-app.sh <identity> <unsigned Kasane.app> <destination>
set -euo pipefail

usage="usage: sign-app.sh <identity> <unsigned Kasane.app> <destination>"
identity="${1:?$usage}"
source_app="$(realpath "${2:?$usage}")"
destination="${3:?$usage}"

if [[ -e $destination ]]; then
  echo "error: $destination already exists" >&2
  exit 1
fi
# The copy in the Nix store is read-only and dated 1970. cp -R makes a writable copy dated now.
cp -R "$source_app" "$destination"
chmod -R u+w "$destination"
# Before signing, so the signature covers it. install-app.sh compares it to skip an unchanged app.
/usr/libexec/PlistBuddy -c "Add :KasaneSource string $source_app" "$destination/Contents/Info.plist"

codesign --force --sign "$identity" --identifier dev.mei.kasane "$destination/Contents/MacOS/kasaned"
codesign --force --sign "$identity" --identifier dev.mei.kasane "$destination"
codesign --verify --strict "$destination"
