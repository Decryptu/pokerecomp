<!-- The top section is rewritten for each release; everything below it is the
standing text and only takes {VERSION}. One line per paragraph, per bullet and
per table row: GitHub reflows a release body to the reader's window, and a line
break put in by hand only makes it ragged.

It is a changelog, not an essay. `## Added`, `## Changed`, `## Added

- Every in-game trade is a conversation. The trader's offer and its yes/no, the party list, the refusal for a cancel and the one for the wrong Pokemon, the cable line, the thanks and the fanfare, with the map's music back behind the last box. All seven swapped in silence before.
- A trade happens once. Each of the seven has its own flag, and the trader asks after the Pokemon it took when you talk to it again.
- The stats screen animates the Pokemon and plays its cry. On Crystal a fainted, frozen or sleeping one is silent there; on Gold and Silver it sounds whatever its status.
- "You can't get off here!" on Routes 16 and 17. The Bicycle's other two lines now come out of the cartridge with your own name in them, and it says the same thing used from SELECT as from the pack.
- The Bug Catching Contest plays its own music.
- Fly, Teleport and loading a save scatter Raikou and Entei across Johto.
- The party menu answers ABLE or NOT ABLE beside each Pokemon while you are teaching a TM or HM or holding an evolution stone, and its gender while the Day-Care or a trader is asking, in the column the HP bar sits in the rest of the time.

## Fixed

- Raikou and Entei moved on every map load. They move when you cross a map connection, walk through a door, fall through a floor or ride the magnet train.
- Which map a roaming Pokemon refuses to move onto, and whether a scatter may leave one where it stood. Both rules were the wrong way round.
- The Radio Tower's five floors kept whatever was playing outside them, and Mahogany Mart played the Suicune battle theme.
- Mounting the bike or starting to surf replayed the map's own track, and the right piece only turned up on the next map.
- The Pokemon a trade gives you took the slot the one you gave up left. It arrives last in the party.
- A traded Pokemon carried no gift landmark and the wrong gender.
- The stats screen and an evolution drew the Pokemon unmirrored and centred. It is mirrored and stands against the far column, and an Unown draws the letter its DVs pick.
- A Pokemon at level 100 had its level drawn a cell too wide, over the HP bar, in the party menu, the battle screen, the stats page, Bill's PC and the Hall of Fame.
- A caller telling you about a rare Pokemon on their route always read the morning table.
- Dig, an Escape Rope and Teleport printed their line over the map they arrived on rather than the one they left.
- Strength's cry and its second line were missing when it was used from the party menu.
- Strength, Flash and Teleport's return each cost a button press the cartridge does not ask for.
- The item PC refused to take a key item.

`api_version` stays 29 and nothing on the boundary moved.

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
