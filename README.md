# kasane

kasane blocks a MacBook's built-in keyboard while an external keyboard sits on top of it, and
releases the block whenever the external keyboard might not be usable.

Status: in daily use on one MacBook. The core logic is tested; the daemon and the menu bar app
are checked on the hardware.

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

The settings window of the menu bar app, Kasane, lists the triggers for two actions. "Block and
Unblock" switches the built-in keyboard; by default it holds fn tapped twice on the built-in
keyboard. "Unblock from the External Keyboard" is the way back when those keys are out of reach;
by default it holds both Shift keys held for a second. "Add…" records a trigger and each row can
be removed. A trigger taps fn or a modifier 2 to 5 times, holds keys together, or is a shortcut
such as ⌃⌥⌘K. The unblock triggers must be on the external keyboard and at least one must stay,
the built-in keyboard takes no hold triggers because the external keyboard's weight could hold a
key down, and a shortcut needs ⌃ or ⌘. A shortcut also reaches the app in front, since kasaned
observes keys without taking them.

kasaned keeps the config in `/Library/Application Support/Kasane/config.json`, and
[examples/config.json](examples/config.json) shows the default. The Caps Lock LED on the built-in
keyboard shows the state; the setup assumes Caps Lock is remapped to Control.

Developed on macOS 26 on an Apple silicon MacBook.

## Usage

```sh
just test       # run the KasaneCore tests
just install    # build Kasane.app, install it to /Applications, and (re)start kasaned
just logs       # follow kasaned's log
just uninstall  # stop kasaned and remove Kasane.app and the LaunchDaemon
```

### First install

1. `just signing-identity` creates a self-signed code signing identity in the login keychain
   (once per Mac). kasaned is signed with the app's identifier, so one Input Monitoring grant
   covers both and survives rebuilds.
2. `just install` builds Kasane.app with kasaned inside, installs it root-owned to
   `/Applications`, and registers `bundle/dev.mei.kasaned.plist` as a LaunchDaemon.
3. Turn on Kasane under Input Monitoring in System Settings (the menu links to it), then restart
   kasaned with `sudo launchctl kickstart -k system/dev.mei.kasaned`.

## Documentation

- [docs/design.md](docs/design.md): design notes and hardware check results (Japanese)
- [spike/](spike/): throwaway scripts used for the hardware checks
