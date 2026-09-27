<!-- Rewrite from the first release heading, `## Added`, `## Changed` or `## Fixed`, for each release. The text below
the release changes is standing guidance with a {VERSION} placeholder. -->

## Changed

- Indoors, the filled screen draws only the room you are in. The other cabins on the S.S. Aqua and the S.S. Anne, and cave or tower areas you can only reach from another floor, stay hidden along with the people in them.
- Mods: API 52 adds `camera_reaches()`, which says whether a block of an indoor map belongs to the room the player is in.

## Fixed

- A trainer fight no longer freezes at its start until you leave the app and come back. A sound that never finished held it; every wait on a sound now gives up after about 20 seconds. The card flip game, the slots and the Unown puzzle waited the same way.
- Vermilion City's Snorlax and the Snorlax, Lapras and Onix dolls in your bedroom are drawn correctly instead of as scrambled tiles.
- On Red, Blue and Yellow, the POKé FLUTE in battle plays its tune after you press past its first box, and "All sleeping POKéMON woke up." appears when the tune ends.
- On Red, Blue and Yellow, a wait on a sound effect ignores the wave channel, as on the cartridge.

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
