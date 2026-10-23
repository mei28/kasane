# kasane

kasane blocks a MacBook's built-in keyboard while an external keyboard sits on top of it, and
releases the block whenever the external keyboard might not be usable.

Status: the core logic is tested, and the daemon works when run by hand as root with
`just run`. Installation as a LaunchDaemon is not set up yet.

## How it works

A root LaunchDaemon, `kasaned`, seizes the built-in keyboard's HID device with
`kIOHIDOptionsTypeSeizeDevice`. While the device is seized, its input reaches neither the OS nor
any other process. When the daemon exits, even by crashing, the kernel ends the seizure.

kasaned keeps the block on only while all of these hold:

- at least one keyboard other than the built-in one is connected
- the screen is unlocked and the user is on the console
- the system is awake

When any of them stops holding, kasaned releases the built-in keyboard and stays off until the
next ON trigger. Pressing the Touch ID button locks the screen, so the block can be released
without touching a key.

Any keyboard that is not built in counts, including devices that only look like one, such as a
YubiKey. With nothing else connected, ON would leave no keyboard that can type; locking the screen
with the Touch ID button or closing the lid still turns it OFF.

ON and OFF triggers (a double tap, or holding keys together) are set in a JSON file. At least one
OFF trigger must be on the external keyboard, and the built-in keyboard takes no hold triggers,
because the external keyboard's weight could hold a key down. The example config toggles with a
double tap of fn on the built-in keyboard. The Caps Lock LED on the built-in keyboard shows
the state; the setup assumes Caps Lock is remapped to Control.

Developed on macOS 26 on an Apple silicon MacBook.

## Usage

```sh
just test                        # run the KasaneCore tests
just run examples/config.json    # run kasaned as root against a config
```

## Documentation

- [docs/design.md](docs/design.md): design notes and hardware check results (Japanese)
- [spike/](spike/): throwaway scripts used for the hardware checks
