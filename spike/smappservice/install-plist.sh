#!/bin/bash
# Registers the spike daemon with a plain LaunchDaemon plist (no SMAppService). Run with sudo.
set -euo pipefail
label=dev.mei.kasaned.spike
plist=/Library/LaunchDaemons/$label.plist
cat >"$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key><string>$label</string>
	<key>Program</key><string>/Applications/KasaneSpike.app/Contents/MacOS/kasanedspike</string>
	<key>MachServices</key><dict><key>dev.mei.kasane.spike.daemon</key><true/></dict>
	<key>RunAtLoad</key><true/>
	<key>StandardErrorPath</key><string>/var/log/kasane-spike.log</string>
</dict>
</plist>
PLIST
chown root:wheel "$plist"
chmod 644 "$plist"
launchctl bootstrap system "$plist"
echo "loaded $label"
