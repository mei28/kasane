signing_identity := "kasane code signing"

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

# Follow kasaned's log
logs:
    tail -f /var/log/kasaned.log
