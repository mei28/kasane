default:
    @just --list

# Build every target
build:
    swift build

# Run the KasaneCore tests
test:
    swift test
