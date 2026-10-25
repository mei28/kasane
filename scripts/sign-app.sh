#!/bin/bash
# Signs Kasane.app and the kasaned inside it as dev.mei.kasane, so one Input Monitoring grant
# covers both and survives rebuilds.
#   scripts/sign-app.sh <identity> <Kasane.app>
set -euo pipefail

identity="${1:?usage: sign-app.sh <identity> <Kasane.app>}"
app="${2:?usage: sign-app.sh <identity> <Kasane.app>}"

codesign --force --sign "$identity" --identifier dev.mei.kasane "$app/Contents/MacOS/kasaned"
codesign --force --sign "$identity" --identifier dev.mei.kasane "$app"
codesign --verify --strict "$app"
