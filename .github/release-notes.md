<!-- Rewrite from the exact `## Added` heading for each release. The text below
the release changes is standing guidance with a {VERSION} placeholder. -->

## Added

- Mods get API 47. Every map has its name from the disassembly, such as `GOLDENROD_DEPT_STORE_2F`, and a mod can find a map by that name on any cartridge. Gold and Silver number some maps differently from Crystal, so a map named by group and number could land on the wrong one.

## Fixed

- Turning on the spot in tall grass can start a wild battle in Gold, Silver and Crystal, as it does on the cartridge.
- Characters who hop or get pushed back in a cutscene keep facing the same way: Elm's surprised jumps, the rival shoving you out of Elm's lab, Clair in the Dragon's Den and the Rattata on Route 30.
- Pokémon standing on the map, like Kurt's Slowpoke, no longer turn to face you when you talk to them.
- Objects that slide in a cutscene, like the legendary beasts in the Burned Tower, no longer play their walking animation.
- After loading a save, the first phone call waits the full 20 minutes again.
- Time spent in menus and battles now counts toward the next phone call.
- No phone call comes in during the Bug-Catching Contest.
- Incoming callers are picked with the cartridge's odds.

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
