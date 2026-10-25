signing_identity := "kasane code signing"
nix_result := ".build/nix-kasane"
app := ".build/Kasane.app"
installed := "/Applications/Kasane.app"
# Present while nix-darwin's kasane module (services.kasane.enable) is on.
managed_plist := "/run/current-system/Library/LaunchDaemons/dev.mei.kasaned.plist"

default:
    @just --list

# Build every target
build:
    swift build

# Run the KasaneCore tests
test:
    swift test

# Run the Nix tests
test-nix:
    nix flake check

# Compare the strings Nix compiles with what Xcode's xcstringstool makes from the same catalog
check-strings:
    #!/usr/bin/env bash
    set -euo pipefail
    nix build --out-link .build/ja-strings .#ja-strings
    rm -rf .build/xcstrings
    xcrun xcstringstool compile bundle/Localizable.xcstrings --output-directory .build/xcstrings
    made="$(cd .build/xcstrings && find . -type f)"
    if [[ $made != ./ja.lproj/Localizable.strings ]]; then
        echo "error: xcstringstool made more than ja.lproj/Localizable.strings:" >&2
        echo "$made" >&2
        exit 1
    fi
    plutil -lint .build/xcstrings/ja.lproj/Localizable.strings .build/ja-strings
    # plutil sorts the keys, so only the content is compared.
    diff <(plutil -convert xml1 -o - .build/xcstrings/ja.lproj/Localizable.strings) <(plutil -convert xml1 -o - .build/ja-strings)

# Create the self-signed identity the app is signed with (once per Mac)
signing-identity:
    scripts/create-signing-identity.sh "{{signing_identity}}"

# Build Kasane.app with kasaned inside using Nix, and sign a copy. Both are signed as dev.mei.kasane, so one Input Monitoring grant covers both.
app:
    nix build --out-link {{nix_result}} .
    rm -rf {{app}}
    scripts/sign-app.sh "{{signing_identity}}" {{nix_result}}/Applications/Kasane.app {{app}}

# Redraw bundle/AppIcon.icns from scripts/app-icon.swift
icon:
    rm -rf .build/AppIcon.iconset
    swift scripts/app-icon.swift .build/AppIcon.iconset
    iconutil --convert icns --output bundle/AppIcon.icns .build/AppIcon.iconset

# Install Kasane.app built from this checkout over the one nix-darwin installed, and restart kasaned. The next darwin-rebuild switch puts the dotfiles' version back.
install:
    if ! test -e {{managed_plist}}; then echo "error: turn on services.kasane in nix-darwin and switch first" >&2; exit 1; fi
    nix build --out-link {{nix_result}} .
    sudo scripts/install-app.sh "{{signing_identity}}" "$(realpath {{nix_result}})/Applications/Kasane.app" "$(id -un)"

# Quit Kasane and remove it after services.kasane is turned off in nix-darwin, which removes kasaned (the config in /Library/Application Support/Kasane stays)
uninstall:
    if test -e {{managed_plist}}; then echo "error: turn off services.kasane in nix-darwin and switch first" >&2; exit 1; fi
    if pgrep -x Kasane >/dev/null; then pkill -x Kasane; fi
    sudo rm -rf {{installed}}

# Follow kasaned's log
logs:
    tail -f /var/log/kasaned.log
