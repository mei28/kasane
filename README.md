# kasane

kasane blocks a MacBook's built-in keyboard while an external keyboard sits on top of it, and
releases the block whenever the external keyboard might not be usable.

Status: the core logic and the daemon are written, and the core logic is tested. The daemon has
not yet been run as root with an external keyboard, and installation is not set up.

## How it works

A root LaunchDaemon, `kasaned`, seizes the built-in keyboard's HID device with
`kIOHIDOptionsTypeSeizeDevice`. While the device is seized, its input reaches neither the OS nor
any other process. When the daemon exits, even by crashing, the kernel ends the seizure.

kasaned keeps the block on only while all of these hold:

- at least one external keyboard from the vendor/product ID allowlist is connected
- the screen is unlocked and the user is on the console
- the system is awake

When any of them stops holding, kasaned releases the built-in keyboard and stays off until the
next ON trigger. Pressing the Touch ID button locks the screen, so the block can be released
without touching a key.

ON and OFF triggers (a double tap, or holding keys together) are set in a JSON file. OFF triggers
can only be placed on the external keyboard. The Caps Lock LED on the built-in keyboard shows
the state; the setup assumes Caps Lock is remapped to Control.

Developed on macOS 26 on an Apple silicon MacBook.

## Usage

```sh
just test                        # run the KasaneCore tests
just run examples/config.json    # run kasaned as root against a config
```

Find an external keyboard's vendor and product IDs in kasaned's log: it prints every keyboard it
sees, including the ones it ignores.

## Documentation

- [docs/design.md](docs/design.md): design notes and hardware check results (Japanese)
- [spike/](spike/): throwaway scripts used for the hardware checks
