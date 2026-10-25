signing_identity := "kasane code signing"
app := ".build/Kasane.app"
installed := "/Applications/Kasane.app"
daemon_label := "dev.mei.kasaned"
daemon_plist := "/Library/LaunchDaemons/dev.mei.kasaned.plist"

default:
    @just --list

# Build every target
build:
    swift build

# Run the KasaneCore tests
test:
    swift test

# Create the self-signed identity the app is signed with (once per Mac)
signing-identity:
    scripts/create-signing-identity.sh "{{signing_identity}}"

# Build Kasane.app with kasaned inside. Both are signed as dev.mei.kasane, so one Input Monitoring grant covers both.
app:
    swift build -c release --product Kasane
    swift build -c release --product kasaned
    rm -rf {{app}}
    mkdir -p {{app}}/Contents/MacOS {{app}}/Contents/Resources
    cp bundle/Info.plist {{app}}/Contents/
    cp .build/release/Kasane .build/release/kasaned {{app}}/Contents/MacOS/
    cp bundle/AppIcon.icns {{app}}/Contents/Resources/
    xcrun xcstringstool compile bundle/Localizable.xcstrings --output-directory {{app}}/Contents/Resources
    scripts/sign-app.sh "{{signing_identity}}" {{app}}

# Redraw bundle/AppIcon.icns from scripts/app-icon.swift
icon:
    rm -rf .build/AppIcon.iconset
    swift scripts/app-icon.swift .build/AppIcon.iconset
    iconutil --convert icns --output bundle/AppIcon.icns .build/AppIcon.iconset

# Install Kasane.app root-owned in /Applications, (re)start kasaned, and open the app
install: app
    scripts/install-app.sh {{app}}
    sudo install -o root -g wheel -m 644 bundle/{{daemon_label}}.plist {{daemon_plist}}
    if sudo launchctl print system/{{daemon_label}} >/dev/null 2>&1; then sudo launchctl kickstart -k system/{{daemon_label}}; else sudo launchctl bootstrap system {{daemon_plist}}; fi
    open {{installed}}

# Stop kasaned and remove Kasane.app and the LaunchDaemon (the config in /Library/Application Support/Kasane stays)
uninstall:
    if pgrep -x Kasane >/dev/null; then pkill -x Kasane; fi
    if sudo launchctl print system/{{daemon_label}} >/dev/null 2>&1; then sudo launchctl bootout system/{{daemon_label}}; fi
    sudo rm -f {{daemon_plist}}
    sudo rm -rf {{installed}}

# Follow kasaned's log
logs:
    tail -f /var/log/kasaned.log
