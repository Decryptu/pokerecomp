<!-- The top section is rewritten for each release; everything below it is the
standing text and only takes {VERSION}. One line per paragraph, per bullet and
per table row: GitHub reflows a release body to the reader's window, and a line
break put in by hand only makes it ragged.

It is a changelog, not an essay. `## Added`, `## Changed`, `## Fixed`, one
bullet per change, and no opening sentence summarising the release: a reader
scanning for their own bug does not want a paragraph about the shape of the
work. No `**Bold label.**` in front of a bullet, no contrast frame on every
line ("X rather than Y", "not X, Y"), and no em-dash. Vary the sentence length:
a body of uniform 15 to 25 word sentences reads as machine-written, and one
here was called that and deserved it. Rewrite from the line that is exactly
`## Added`: an edit that searches for the first one in the file lands inside
this note and takes its closing marker with it, which is how 0.1.17 published
an empty body. -->

## Added

- Red, Blue and Yellow open the way the cartridges do: the copyright screen, GAME FREAK presents, the Gengar and Nidorino movie or Yellow's Pikachu intro, and the title screen with its Pokemon rolling past. Against a real cartridge over 3000 frames the LCD registers match on every frame and the sprites on all but one on Red and Blue; Yellow's surf scene tears its own sprites for 23 frames and this port draws them whole.
- The Game Corner's slot machines play. A machine is faced from the side with a COIN CASE and a coin, asks, takes a bet of one to three, and its wheels stop on whole symbols with the cartridge's own odds: the flags roll once a bet, wheel 3 rolls on past a match they forbid, a 300 win halves them, and the payout counts a coin at a time with the music held. The lucky machine is the one the map rolled on entry.
- The three out-of-order machines say so, and a machine faced from below, without a COIN CASE or with an empty one answers the way it does on the cartridge.
- Pewter Museum's two fossils, Route 15's binoculars and Yellow's Fan Club pictures pop their picture up in a box over the map.
- The Viridian School blackboard and the link cable help in Celadon open their menus: a heading prints its own text and the menu comes back until QUIT or B.
- The Celadon Mansion game designer's diploma draws once the Pokedex is complete, with the player's sprite behind it on Red and Blue and Yellow's own border.

## Changed

- The cache format is 137. Import your cartridges again.
- The title screen's Pokemon are this port's roll; on a cartridge they come off its timer.

## Fixed

- A script that rolled once and stored the result rolled twice, which is what picked the lucky slot machine.
- Yellow's Route 15 binoculars said nothing.
- A Generation 1 sound cut short by a screenshot tool went on playing.

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
