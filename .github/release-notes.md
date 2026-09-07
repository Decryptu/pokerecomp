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

- The launcher opens on the cartridge you last played. Anyone whose game is Crystal was turning the carousel four steps at every launch. A shelf that has never been played from still opens on Red.
- A mod can rewrite what a text box says. Every named box reads through one seam now, which is what a translation needs: the menus, the marts, the name rater, the move deleter, the Day-Care, the intro and the special scripts. Issue #575 asked for a French Crystal and had nothing to aim at.

## Changed

- Generation 1's overworld is walked, fought and talked to. A map opens and a step meets a wild Pokemon. A sign or an NPC opens a box, a trainer sees you across a room and walks up, and the fight behind it runs to a faint with its own wipe, animations and ball throws.
- Every counter on Red, Blue and Yellow is open: the mart, the Pokemon Center nurse, the cable club receptionist, the vending machines, the Game Corner prize counter with its four coin clerks, the Day-Care, and all three PCs.
- The START menu, the bag, the party list, the Pokedex, the trainer card and the region map each draw in Generation 1's own layout.
- Field moves run. Cut, Surf, Strength, Fly, Dig, Teleport and Softboiled, the three fishing rods, the bicycle down Cycling Road, the Poke Flute in front of a Snorlax, and Flash lighting Rock Tunnel.
- Hidden objects, in-game trades, gifts, items on the ground, Silph Co.'s card key doors, the dungeon holes and the Escape Rope all answer.
- A Generation 1 map runs its own per-frame script, so a state machine walks an NPC across a room or the player up a corridor and holds its line until that walk has been drawn.
- None of this is reachable from Play. Red, Blue and Yellow are still import and inspection only.

## Fixed

- A mod archive refused for its contract now names the manifest it found. One built by another project's generator carries `manifest.json` with an `api` field, and this installer reported "no mod.json" over a file it had already read, then refused the mod for declaring the 0 it had defaulted to.

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
