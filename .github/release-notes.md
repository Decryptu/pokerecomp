<!-- The "Fixed" section is rewritten for each release; everything below it is
     the standing text and only takes {VERSION}. -->

## Fixed in this release

- **The mobile dock now leaves room for the launcher.** Portrait buttons no
  longer expand to fill the row, and a phone held sideways stays on the compact
  layout instead of being mistaken for a desktop. Cartridge art gets the freed
  space on iOS and Android.
- **Mod downloads stay on the mod's information row.** The download icon no
  longer creates an otherwise empty second row in every card.

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

## Updating

The launcher's about page tells you when a newer release exists. It does not
install it: download the new file and replace the old one. **Your saves are kept
separately and survive it**, on every platform.
