<!-- Rewrite from the exact `## Added` heading for each release. The text below
the release changes is standing guidance with a {VERSION} placeholder. -->

## Added

- Mods get API 48. A mod can change how often Raikou, Entei and Suicune appear on the route they are roaming, read the roaming slots, and make a Pokémon roam in an empty slot, such as Suicune in Crystal. It can also read whether the beasts have left the Burned Tower, whether Crystal's Suicune battle at Tin Tower happened, and which species are caught.

## Fixed

- Repel keeps away the wild Pokémon a mod shows on the map, as it does with random encounters. On Red, Blue and Yellow, Repel now also wears off while such a mod is on.
- TMs and HMs in a shop show the move's description. They showed "?".
- The PC's item list describes the item under the cursor.
- Fly and Dig take the user off the screen on the first turn, and it comes back when the move lands, misses or is interrupted. Every two-turn move now plays its first-turn animation.
- When a Pokémon forgets a move for a TM or HM, the TM party menu stays behind the text, and CANCEL and the last Pokémon's HP bar no longer show through the text box.
- The move lists for forgetting a move and for PP Up or Ether use the same boxes as the cartridge, in the bag and in battle.
- Raikou and Entei only start roaming after the Burned Tower, and the Pokédex no longer shows where they are before that. Saves where they got loose early are fixed when loaded.

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
