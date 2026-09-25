<!-- Rewrite from the exact `## Added` heading for each release. The text below
the release changes is standing guidance with a {VERSION} placeholder. -->

## Added

- Mods get API 45: `drawn_tile_at()` gives the tile the overworld background shows at any map tile, with the S.S. Anne scene's scrolling band in map terms and a revision number for rebuilding, the battle's map context carries cut trees and other changed blocks, and two new screenshot hooks start the S.S. Anne departure and the poison flash.
- Your Pokemon now shrinks back into its ball when you switch it out, in all six games.

## Changed

- Gold, Silver and Crystal now read every battle message from your cartridge, so the wording and line breaks match the original. Import your cartridges again after updating.
- "X used MOVE!", "Go! X!", "X, come back!" and the other lines the game shows without an arrow no longer wait for a button press.
- Switching out says "that's enough!", "OK!" or "good!" depending on how much damage your Pokemon did, as in the original games.
- The pauses around Protect, Roar, Thunder Wave, Beat Up, Baton Pass, switching and fainting now match the original timing.

## Fixed

- A trainer switching Pokemon in the middle of a turn no longer asks whether you want to switch too.
- Baton Pass and Roar no longer print "come back!" and "Go!" lines the originals never showed.
- Pursuit now hits after your "come back!" line.
- Ancientpower shows one message for each stat that rose, and Dream Eater says the dream was eaten.
- A Pokemon with no usable moves says so before using Struggle.
- In Red, Blue and Yellow, a Pokemon caught in Wrap can be switched out, Thrash says "thrashing about!" on later turns, and Roar against a trainer says the target is unaffected.

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
- **iOS**: the `.ipa` is deliberately **unsigned**. Install it with [AltStore](https://altstore.io) or [SideStore](https://sidestore.io), which sign it on your own machine with your own Apple ID. A free Apple ID works; apps signed that way need re-signing every 7 days. Add pokerecomp's source once, in **Sources** > **+**, and every later release shows up as an update: `https://raw.githubusercontent.com/Decryptu/pokerecomp/main/.github/altstore/source.json`
- **Switch**: extract the zip at the root of your microSD, so the file lands at `switch/pokerecomp.nro`, and launch **pokerecomp** from the homebrew menu. It needs a console that already runs homebrew; nothing here installs one.

## Updating

The launcher's about page tells you when a newer release exists. It does not install it: download the new file and replace the old one. **Your saves are kept separately and survive it**, on every platform.
