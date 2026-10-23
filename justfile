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
