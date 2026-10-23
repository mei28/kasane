#!/bin/bash
# Builds KasaneSpike.app with the daemon inside, signed inside-out.
#   ./build.sh [identity]    default identity: "kasane code signing"; "-" signs ad hoc
# Then, as root:  ditto KasaneSpike.app /Applications/KasaneSpike.app; chown -R root:wheel it;
#                 ./install-plist.sh registers the daemon with a plain /Library/LaunchDaemons plist.
set -euo pipefail
cd "$(dirname "$0")"
identity="${1:-kasane code signing}"
out=build
app="$out/KasaneSpike.app"
# The daemon sits next to the app's executable and is signed with the app's identifier, so the
# Input Monitoring grant System Settings records for the app also covers the daemon.

rm -rf "$out"
mkdir -p "$app/Contents/MacOS"

# Both entry files have top-level code, so each must be compiled as a main.swift.
mkdir -p "$out/daemon" "$out/app"
cp Daemon.swift "$out/daemon/main.swift"
cp App.swift "$out/app/main.swift"
swiftc -swift-version 5 -O Shared.swift "$out/daemon/main.swift" -o "$app/Contents/MacOS/kasanedspike"
swiftc -swift-version 5 -O Shared.swift "$out/app/main.swift" -o "$app/Contents/MacOS/KasaneSpike"

plist() { # path identifier executable
  cat >"$1" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key><string>$2</string>
	<key>CFBundleExecutable</key><string>$3</string>
	<key>CFBundleName</key><string>$3</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>0.0.1</string>
	<key>LSUIElement</key><true/>
</dict>
</plist>
EOF
}
plist "$app/Contents/Info.plist" dev.mei.kasane.spike KasaneSpike


codesign --force --sign "$identity" --identifier dev.mei.kasane.spike "$app/Contents/MacOS/kasanedspike"
codesign --force --sign "$identity" --identifier dev.mei.kasane.spike "$app"
codesign --verify --strict --verbose=1 "$app"
codesign --display --requirements - "$app" 2>&1 | grep designated
codesign --display --requirements - "$app/Contents/MacOS/kasanedspike" 2>&1 | grep designated
