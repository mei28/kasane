signing_identity := "kasane code signing"
label := "dev.mei.kasaned"
installed := "/usr/local/bin/kasaned"

default:
    @just --list

# Build every target
build:
    swift build

# Run the KasaneCore tests
test:
    swift test

# Run kasaned as root against a config. Ctrl-C from the external keyboard stops it and releases the built-in one.
run config="examples/config.json":
    swift build
    sudo .build/debug/kasaned {{config}}

# Create the self-signed identity that install signs with (once per Mac)
signing-identity:
    scripts/create-signing-identity.sh "{{signing_identity}}"

# Build, sign, and install kasaned as root, then restart the LaunchDaemon if it is loaded
install:
    swift build -c release --product kasaned
    codesign --force --sign "{{signing_identity}}" --identifier {{label}} .build/release/kasaned
    sudo install -o root -g wheel -m 755 .build/release/kasaned {{installed}}
    if sudo launchctl print system/{{label}} >/dev/null 2>&1; then sudo launchctl kickstart -k system/{{label}}; fi

# Follow the LaunchDaemon's log
logs:
    tail -f /var/log/kasaned.log
