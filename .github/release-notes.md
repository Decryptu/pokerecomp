<!-- The top section is rewritten for each release; everything below it is the
standing text and only takes {VERSION}. One line per paragraph, per bullet and
per table row: GitHub reflows a release body to the reader's window, and a line
break put in by hand only makes it ragged. -->

## New in this release

Four reported bugs, every one of them in what the game shows you rather than in what it decides.

**Pokemon were nearly always female.** Gender is worked out by comparing a byte built from the Attack and Speed DVs against the species ratio, and this port had that comparison the wrong way round, so a Pokemon that should have been male read female. Everything that reads a gender was wrong with it: the save editor, the box, the stats page, the Hall of Fame, both Day-Care parents, the gender an egg hatches with, Attract, and the in-game trades that ask for a particular one. Nothing is stored, so no save needs fixing: a Pokemon you already have reads the right way round from now on.

**The policeman lets you name your rival.** He asked what the thief called himself and then answered SILVER for you. The naming screen opens now, and leaving it blank still gives SILVER, the way the cartridge does.

**People turn to look at you again.** Mom did not look up when she stopped you about the Pokegear, and the old man showing you around Cherrygrove faced you every way but the right one. The script command that turns you was doing nothing at all, everywhere it is used, so no scene had ever turned you since this port could run one. The old man also dragged you around facing wherever the walk was going to end rather than turning as he went.

**The "!" bubble appears over your own head.** Every surprise in the game puts one there and none of them drew it. So did `disappear PLAYER`, which is what takes you off screen in Lance's room while the reporter runs about looking for you.

**For mod authors**, `api_version` stays 29 and nothing on the boundary moved.

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
