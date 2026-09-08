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

- Red, Blue and Yellow play their own music, sound effects and cries. `audio/engine_1.asm` is a second driver beside Crystal's, and a map plays its piece out of whichever ROM bank the cartridge names for it. All 151 cries are in.
- A Generation 1 new game runs from Oak's speech to the bedroom. Six intro palettes, the pic that walks across the window, both keyboards for your name and your rival's, and the save that puts you in Red's house at (3, 6) with 3000 in the wallet and a POTION in the PC.
- The Safari Zone runs whole. The gate takes the fee, hands over 30 balls, counts your 500 steps and ends the game with the PA wherever you are standing. Bait and the rock move the catch rate and the flee roll, and Yellow's discount for a thin wallet works.
- Celadon Mart's, Silph Co.'s and Rocket Hideout's elevators ride and shake, and the door you walked in through goes back where it belongs when you leave.
- The NAME RATER renames a Pokemon, on his own ten-letter keyboard with the party icon drawn over it.
- The Poke Flute plays inside a battle. It stays quiet while the low health alarm owns the channels it would take.

## Changed

- Generation 1 map scripts run their own bodies. 186 state bodies over 98 tables decode on Red and Blue, 127 of them whole, against 118 and 65 last release.
- The menus a text row draws for itself are open. Among them the Cinnabar lab handing back what your fossil revives into, the Cerulean badge house's list, Oak's aides, the Pokedex rating and the healing machine sounding once per ball.
- Every `text_asm` row on Red and Blue decodes now, 317 of them, and none is left with an arm the walker could not read.
- Blue's layout is built from Red's and the bytes it shifts, so a correction to one reaches the other.
- Red, Blue and Yellow are still import and inspection only. Play turns them away.
- The cache format is 126. Import your Generation 1 cartridge again: a cache written before this one carries no audio and no map music bank.

## Fixed

- Every scripted warp landed on the row in front of the one it named. `wDestinationWarpID` counts from zero.
- Importing Yellow raised an error partway and left one map's state machine half built.
- Six of the Safari gate's text rows were never read, because the table they sat in could only grow once.
- Route 11 Gate 2F's aide said nothing at all.
- Generation 1's Pokemon Center nurse never recorded the town to wake up in, two stores having matched the same byte.

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
