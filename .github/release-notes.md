<!-- Rewrite from the first release heading, `## Added`, `## Changed` or `## Fixed`, for each release. The text below
the release changes is standing guidance with a {VERSION} placeholder. -->

## Added

- Mods: API 58 lets a custom NPC speak. A `text` request shows the game's own text box, pages on each press, and tells the NPC when the box has closed, so a scene can chain dialogue, a catch demonstration and a gift.
- Mods: API 58 lets a custom NPC walk. A `step` request moves it one cell at normal NPC speed with the walking animation. Walls, water, map objects, the player and other solid NPCs block it, and the NPC is told where it ended up.

## Fixed

- The Dude's catching demonstration on Route 29 no longer sends out your first Pokémon. The Dude stays on screen and throws the ball himself, as on the cartridge. The same goes for a mod's catch demonstration.

## Updating this release

- Cartridge cache format is still 160. Coming from 0.1.67 or earlier, import each cartridge file again when the launcher requests it. **Saved games are kept separately and remain intact.**
- Mod API version is now 58. Existing supported mods remain compatible.

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
