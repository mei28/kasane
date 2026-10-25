# kasane

kasane blocks a MacBook's built-in keyboard while an external keyboard sits on top of it. It
unblocks the built-in keyboard whenever the external one might not be usable, so one keyboard can
always type.

Status: in daily use on one MacBook. The core logic is tested; the daemon and the menu bar app
are checked on the hardware.

## Requirements

kasane needs a MacBook with macOS 15 or later and nix-darwin. It is developed on macOS 26 on an
Apple silicon MacBook. Development also uses [just](https://github.com/casey/just) and Xcode, whose
Swift runs the tests.

## Install

1. Create the code signing identity, once per Mac:
   `nix run github:mei28/kasane#signing-identity`. It puts a self-signed identity in the login
   keychain. The app and kasaned are both signed with it as `dev.mei.kasane`, so one Input
   Monitoring grant covers both and survives rebuilds.
2. Add kasane to the nix-darwin flake and turn it on:

   ```nix
   inputs.kasane.url = "github:mei28/kasane";

   # in the modules of nix-darwin.lib.darwinSystem
   kasane.darwinModules.default

   # in a nix-darwin module
   services.kasane.enable = true;
   ```

3. Run `sudo darwin-rebuild switch` from a terminal in your login session. The activation signs
   the Nix-built Kasane.app with the identity from step 1, installs it root-owned at
   `/Applications/Kasane.app`, and loads kasaned as a LaunchDaemon. If signing fails, the switch
   stops and leaves the installed app and kasaned as they were.
4. Open Kasane and turn it on under Input Monitoring in System Settings. The menu's "Open Input
   Monitoring Settings…" opens the pane.
5. Restart kasaned with `sudo launchctl kickstart -k system/dev.mei.kasaned`. A running kasaned
   does not pick up the grant.

A switch that changes kasane replaces the app and restarts kasaned, which unblocks the built-in
keyboard. A switch that leaves kasane unchanged does not touch it.

To uninstall, turn off `services.kasane` and switch, which removes kasaned, then run
`just uninstall` to remove the app. The config in `/Library/Application Support/Kasane` stays.

## Use

With the default config:

- Tap fn twice on the built-in keyboard to block it. Tap fn twice again to unblock it.
- Hold both Shift keys on the external keyboard for a second to unblock the built-in keyboard.

The menu bar icon shows an external keyboard over the built-in one. The built-in keyboard fades
while it is blocked, and the whole icon fades while kasane is paused. An exclamation mark appears
when kasaned is not running, Input Monitoring is not granted, no built-in keyboard is found, or
kasaned cannot use its config. kasaned also lights the Caps Lock LED on the built-in keyboard
while it blocks the keyboard. When Caps Lock is remapped to another key, as on the development
Mac, nothing else lights that LED.

The menu blocks and unblocks the built-in keyboard, and pauses kasane. While paused, kasaned
unblocks the keyboard and ignores every trigger. Quitting the menu bar app leaves kasaned running.

## Safety

kasaned keeps the built-in keyboard blocked only while all of these hold:

- at least one keyboard other than the built-in one is connected
- the screen is unlocked and the user is on the console
- the system is awake

When any of them stops holding, kasaned unblocks the built-in keyboard and leaves it unblocked
until the next trigger. Pressing the Touch ID button locks the screen and closing the lid sleeps
the system, so either one unblocks the keyboard without touching a key.

kasaned always starts unblocked. If kasaned exits, even by crashing, the kernel releases the
built-in keyboard. If its main thread stops for 2 seconds while blocking, kasaned exits on purpose.

Any keyboard that is not built in counts as external, including devices that only look like a
keyboard, such as a YubiKey. With only such a device connected, blocking leaves no keyboard that
can type. A trigger on the built-in keyboard, the Touch ID button, or the lid still unblocks it.

## Settings

The settings window lists the triggers for two actions:

- "Block and Unblock" blocks the built-in keyboard, or unblocks it while blocked. Its triggers
  can be on either keyboard.
- "Unblock from the External Keyboard" is the way back when those triggers are out of reach. Its
  triggers must be on the external keyboard, and its last trigger cannot be removed.

"Add…" records a trigger from the keys you press, and each row has a button that removes it.
Changes take effect at once. A trigger is one of three kinds:

| Kind | Keys | Example |
|---|---|---|
| Tap | fn or one modifier key, 2 to 5 times | fn twice |
| Hold | fn and modifier keys held together | both Shift keys for 1 second |
| Shortcut | modifier keys and one letter, digit, Space, Return, Tab, Escape, Delete, or arrow key | ⌃⌥⌘K |

kasaned refuses a config that breaks these rules, and the window shows why:

- The built-in keyboard takes no hold triggers, because the external keyboard's weight could hold
  a key down.
- A key on one keyboard takes tap triggers of one count only. With fn twice and fn three times,
  the shorter one would fire first.
- A shortcut needs ⌃ or ⌘. ⇧A and ⌥← come up in ordinary typing.
- Two triggers that differ only in timing are duplicates.

A shortcut fires when you let go of every key, and only if you held its last key for less than a
second. kasaned observes keys without taking them, so a shortcut also reaches the app in front.
Pick one that no app uses.

kasaned reads keys before macOS substitutes them, so it applies each keyboard's `UserKeyMapping`
itself. `hidutil` sets that property, and nix-darwin's `remapCapsLockToControl` sets it through
`hidutil`. With Caps Lock mapped to Control, the Caps Lock key counts as ⌃. kasaned rereads the
substitutions when a keyboard connects and every 5 seconds.

kasaned keeps the config in `/Library/Application Support/Kasane/config.json`.
[examples/config.json](examples/config.json) shows the default. When the file is from an older
version or damaged, kasaned runs without triggers and refuses to block, and the settings window
offers to restore the default config.

The General section turns on launch at login and picks the language: the system's, English, or
Japanese.

## Development

```sh
just test              # run the KasaneCore tests with Xcode's Swift
just test-nix          # run the Nix tests
just check-strings     # compare the strings Nix compiles with Xcode's xcstringstool output
just build             # debug build of every target
just app               # build Kasane.app with Nix and sign a copy at .build/Kasane.app
just install           # install a build of this checkout over the nix-darwin one
just logs              # follow kasaned's log in /var/log/kasaned.log
just uninstall         # remove Kasane.app after services.kasane is off
just icon              # redraw bundle/AppIcon.icns from scripts/app-icon.swift
just signing-identity  # create the code signing identity, like the flake app
```

`just install` needs the nix-darwin module, and the next switch puts back the version the
nix-darwin flake pins. To switch to a checkout instead, pass
`--override-input kasane git+file:///path/to/kasane` to `darwin-rebuild`. Nix builds only the files
git tracks, so `git add` new files first.

## How it works

kasaned runs as root from `/Applications/Kasane.app/Contents/MacOS/kasaned`. It blocks the
built-in keyboard by opening its HID device with `kIOHIDOptionsTypeSeizeDevice`. While the device
is seized, its input reaches neither the OS nor any other process, but kasaned still receives it,
so triggers on the built-in keyboard keep working.

The menu bar app, Kasane, talks to kasaned over XPC. Each side accepts the other only when it is
signed by the same certificate. kasaned checks every config and every block request itself, so
the app cannot turn off the safety rules.

Nix builds Kasane.app unsigned with nixpkgs' Swift, because Nix builds cannot reach the login
keychain. The activation signs a copy as the primary user and records the store path it came from
in its Info.plist, so a later switch leaves an app built from the same store path alone.
`bundle/Localizable.xcstrings` is compiled by `nix/strings.nix`, since Xcode's xcstringstool is
not available to Nix.

The `KasaneCore` target holds the config, trigger recognition, and the block state machine without
IOKit, and `just test` covers it. `kasaned` and `Kasane` are the IOKit and AppKit layers around
it.

## Documentation

- [docs/design.md](docs/design.md): design notes and hardware check results (Japanese)
- [spike/](spike/): throwaway scripts used for the hardware checks
