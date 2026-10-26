<!-- Rewrite from the first release heading, `## Added`, `## Changed` or `## Fixed`, for each release. The text below
the release changes is standing guidance with a {VERSION} placeholder. -->

## Added

- Generation 3 field effects: puddle splashes, feet in flowing water, sand piles in deep sand, hot-spring water, seaweed bubbles, footprints and bike tire tracks, and the berry-tree growth sparkle.
- Generation 3 field moves: the field-move banner, Surf with its surf blob, Cut on trees and grass, Rock Smash, Strength (with Ruby and Sapphire's Desert Ruins braille door), Waterfall, Secret Power and Fly.
- Generation 3 player movement: walking, running, ice, currents, slides, secret base mats and FireRed and LeafGreen's spin tiles, plus the Mach Bike, the Acro Bike and FireRed and LeafGreen's bike.

## Changed

- Generation 3 cartridges remain experimental and unplayable while field integration continues.

## Updating this release

- Cartridges must be reimported for the updated cache format. Saves are preserved.

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
