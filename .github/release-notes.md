<!-- The top section is rewritten for each release; everything below it is
     the standing text and only takes {VERSION}. -->

## New in this release

This one is for mod authors. Nothing in the game itself changed, and mods
written for an older release keep working.

- **A mod can see a Pokemon being caught.** The battle publishes the catch on
  its own `Gotcha!` line, with the species, the ball, where it was caught and
  where it went.
- **A mod can add a line to a battle.** One line, in the battle's own box, with
  the game's own pacing. A line that would not fit is refused rather than cut
  off, and the launcher says which mod asked for it.
- **Two mods that raise the shiny odds now stack.** Each one's extra rolls are
  added together instead of the larger one winning.

The mod contract is `api_version` 20. The first mod built on it is a Catch
Combo: catch the same species over and over and the odds of a shiny climb, the
way they do in the Let's Go games.

**This release ships no game data.** pokerecomp is not an emulator: it rebuilds
everything from a Game Boy Color cartridge you dump yourself, and verifies the
file before using it. Bring your own Crystal, Gold or Silver ROM.

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

- **Windows** may show a blue "Windows protected your PC" box, because the build
  is not signed by a paid certificate. Click **More info**, then **Run anyway**.
- **macOS**: the app is ad-hoc signed and not notarized, so double-clicking it
  is refused. **Right-click the app, choose Open, then Open again.** Only the
  first launch needs this.
- **Linux**: `chmod +x pokerecomp-{VERSION}-linux-x86_64` and run it.
- **Android**: your phone will ask you to allow installing from this source.
- **iOS**: the `.ipa` is deliberately **unsigned**. Install it with
  [AltStore](https://altstore.io) or [SideStore](https://sidestore.io), which
  sign it on your own machine with your own Apple ID. A free Apple ID works;
  apps signed that way need re-signing every 7 days.
- **Switch**: extract the zip at the root of your microSD, so the file lands at
  `switch/pokerecomp.nro`, and launch **pokerecomp** from the homebrew menu. It
  needs a console that already runs homebrew; nothing here installs one.

## Updating

The launcher's about page tells you when a newer release exists. It does not
install it: download the new file and replace the old one. **Your saves are kept
separately and survive it**, on every platform.
