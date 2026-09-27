<!-- Rewrite from the first release heading, `## Added`, `## Changed` or `## Fixed`, for each release. The text below
the release changes is standing guidance with a {VERSION} placeholder. -->

## Added

- The save editor edits Pokemon in the PC boxes. Tap one to change its species, level, gender, happiness, held item, moves and DVs, as for a party member.
- Mods can place a Pokemon on the map that blocks the way and starts a wild battle when you press A on it.
- Mods can swap their own Pokemon in for the wild you meet in grass or water, so a mod can have any number of roaming Pokemon on all six games.
- Mods can run a whole battle on their own screen, which a double battle mod needs. The game still pays the prize, saves, evolves and whites out as usual.
- Mods are told how every battle ended and which Pokemon was left standing.
- In Crystal, a mod can turn on the GS Ball event from the Virtual Console release. The Goldenrod Pokemon Center hands over the GS Ball, and Kurt and the Ilex Forest shrine follow.

## Changed

- The save editor picks items, species, moves and held items by name from a list you scroll with your finger.

## Fixed

- The save editor's item list scrolls on a phone, so every item can be added. It no longer lists the unused TERU-SAMA items, and its button says Add for a new item and Set for one already in the bag.
- Ho-Oh always holds a Sacred Ash and the Vermilion City Snorlax always holds Leftovers, as on the cartridge.
- Randomizer mods no longer put a key item on the Goldenrod GS Ball, which the game never gives without a mod.

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
