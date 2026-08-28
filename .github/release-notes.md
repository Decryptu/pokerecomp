<!-- The top section is rewritten for each release; everything below it is the
standing text and only takes {VERSION}. One line per paragraph, per bullet and
per table row: GitHub reflows a release body to the reader's window, and a line
break put in by hand only makes it ragged. -->

## New in this release

**pokerecomp runs on a Nintendo Switch.** Upstream Godot has no Switch platform and the homebrew ports stopped at 4.1, so the engine was ported onto this project's own pin. Extract the zip at the root of a microSD and launch it from the homebrew menu. This is the first release to carry it, so tell us what breaks.

Getting it running found four things wrong on every platform, each fixed where it belonged rather than behind a platform check:

- A machine with no keyboard could move every focus ring in the launcher and choose nothing under it. A pad now answers accept and cancel everywhere.
- A device with both a touchscreen and a pad drew an on-screen controller nobody was using, on a phone with a controller paired as much as on a Switch.
- Sixteen refusals a session went into the log from a guard that named headless and mobile, and a console is neither.
- The launcher's display density asked whether it was on a phone. What it actually needed to know was whether the window is the whole screen.

**A Bug Catching Contest ends the way the cartridge ends it.** Four escapes and the start menu all reached the contest and none of them touched it. Fly, Dig, an Escape Rope and Teleport each left the timer running across the warp; the whole party competed instead of the lead alone; blacking out inside a contest halved your money; and the START menu offered PACK and SAVE where the cartridge offers neither, with no QUIT row and no status box. A second catch is now offered over the comparison page the cartridge draws, STOCK #MON above THIS #MON, so the question is answered by looking rather than by memory.

**SELECT moves an item inside its pocket**, in the pack and in the item PC. Mark a row, then place it. Both lists now keep items in the order you picked them up, which is what the cartridge does, instead of sorting them by an internal number.

**The save pages fit a phone.** On a screen held upright the save slot panel was pushed wider than the window, and everything past Import .sav, Delete included, was off the edge with no way to reach it. The party page and the save editor were rebuilt in the launcher's own appearance and both reflow to the window they are given.

**A and B can be arranged separately** on the on-screen controller. They were one cluster on a fixed diagonal; each now has its own place in each orientation, and a layout you already arranged is carried over.

**This release ships no game data.** pokerecomp is not an emulator: it rebuilds everything from a Game Boy Color cartridge you dump yourself, and verifies the file before using it. Bring your own Crystal, Gold or Silver ROM.

## Which file

| You have | Download |
|---|---|
| Windows, any PC from the last 15 years | `pokerecomp-{VERSION}-windows-x86_64.exe` |
| Windows on a Snapdragon or Surface Pro X | `pokerecomp-{VERSION}-windows-arm64.exe` |
| A Mac | `pokerecomp-{VERSION}-macos.zip` |
| Linux on a desktop or laptop | `pokerecomp-{VERSION}-linux-x86_64` |
| Linux on a Raspberry Pi, an SBC or an arm64 handheld | `pokerecomp-{VERSION}-linux-arm64` |
| Android, including handhelds like the Ayn Thor | `pokerecomp-{VERSION}-android.apk` |
| iPhone or iPad | `pokerecomp-{VERSION}-ios.ipa` |
| A Nintendo Switch running homebrew | `pokerecomp-{VERSION}-switch.zip` |

Every download is one file. `sha256sums.txt` covers all of them.

## First launch

- **Windows** may show a blue "Windows protected your PC" box, because the build is not signed by a paid certificate. Click **More info**, then **Run anyway**.
- **macOS**: the app is ad-hoc signed and not notarized, so double-clicking it is refused. **Right-click the app, choose Open, then Open again.** Only the first launch needs this.
- **Linux**: `chmod +x pokerecomp-{VERSION}-linux-x86_64` and run it.
- **Android**: your phone will ask you to allow installing from this source.
- **iOS**: the `.ipa` is deliberately **unsigned**. Install it with [AltStore](https://altstore.io) or [SideStore](https://sidestore.io), which sign it on your own machine with your own Apple ID. A free Apple ID works; apps signed that way need re-signing every 7 days.
- **Switch**: extract the zip at the root of your microSD, so the file lands at `switch/pokerecomp.nro`, and launch **pokerecomp** from the homebrew menu. It needs a console that already runs homebrew; nothing here installs one.

## Updating

The launcher's about page tells you when a newer release exists. It does not install it: download the new file and replace the old one. **Your saves are kept separately and survive it**, on every platform.
