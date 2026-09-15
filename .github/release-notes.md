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

- The Cable Club on Red, Blue and Yellow links two saves of the same cartridge. The receptionist saves the game, the menu offers the Trade Center and the Colosseum, and either room loads with your friend on the far stool: the other occupied save slot of that game.
- The Trade Center trades: both parties side by side, STATS on either Pokemon, the trade movie, an evolution on arrival for the species that evolve by trade, and CANCEL back to the room.
- The Colosseum fights the other save's party as a link battle: the versus box with the Poke Ball rows, RUN as a forfeit, the verdict, and a healed party back in the room.
- Yellow's COLOSSEUM2 offers the PIKA, PETIT and POKE CUP with each cup's level, count and evolution rules, and the cups' own sleep cap.
- A Pokemon evolves after a fight, by stone or by Rare Candy, on the cartridge's evolution screen with its flicker and cries; cancelling with B works.
- An in-game trade plays its movie on all three cartridges, with Yellow's own palette timing.
- The S.S. Anne sails out of Vermilion under its smoke, a pushed boulder raises its dust, and the spinner tiles spin the player.
- SAVE reads RESET while linked, and the bag is refused in a link room.

## Changed

- The cache format is 140. Import your cartridges again.

## Fixed

- Every secondary move effect on Red, Blue and Yellow (a paralysis, a burn, a flinch, a stat drop) had never triggered. They now roll at the cartridge's own odds.
- Attack animations on Red, Blue and Yellow read garbage after a fresh import.
- Running from a link battle on Gold, Silver and Crystal is a forfeit and counts as a loss; a link or Battle Tower fight awards no experience.
- A YES/NO question over a multi-page text opened its menu on the first page.
- On Crystal, a Pokemon that evolves after a link trade showed no evolution screen, and STATS on the link screen did nothing.
- A six-tile-wide picture drawn flipped lost a column on the evolution and stats screens.

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
