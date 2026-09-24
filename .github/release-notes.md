<!-- Rewrite from the exact `## Added` heading for each release. The text below
the release changes is standing guidance with a {VERSION} placeholder. -->

## Added

- Mods can put a PC row on the start menu that opens the whole Pokemon Center PC: BILL'S PC, your own PC, PROF.OAK'S PC and the Hall of Fame. On Gold, Silver and Crystal it needs a Pokemon in the party, like the real PC.
- The save editor shows each party Pokemon's gender and can switch it. It lists all 20 slots of a box and every item in the bag, picks items by name, and removes the selected item.

## Fixed

- When a trainer sends out the next Pokemon, the ball opens before the Pokemon appears, and its HP bar comes back after the cry. The Poke Ball row goes away as the line starts. The line names the trainer ("LEADER FALKNER sent out ...").
- A trainer turning to face you, or the second of two trainers facing each other, now notices you while you stand still. In Cianwood Gym the second Black Belt walks over after the first battle.
- The TM/HM pocket is always in number order.
- Mom and Elm answer the phone. Calling from the Pokegear stays on the phone screen, plays the dial tone twice, and hangs up on the card. Trainers who call you use their own lines.
- The hole in Burned Tower stays hidden until after the rival battle. Any map that changes its own tiles keeps them after a battle, including the Elite Four doors and the Radio Tower shutter.
- Falling through the hole in Burned Tower draws the basement correctly, and plays the fall and the landing shake. The Ruins of Alph chambers and the Magnet Train take their warps the same way.
- The save editor keeps the map and position you type in when you press Save.
- When a mod changes the wild tables, the wild Pokemon already walking on the map follow the new tables.

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
