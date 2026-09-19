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

- A lost fight on Red, Blue and Yellow blacks out: the party is healed, the money halved and the player wakes at the last Pokemon Center, as `HandleBlackOut` does. Before this a lost trainer fight left you standing beside the trainer with a fainted party.
- The battle says its own line on the way out: "is out of useable POKéMON! blacked out!" under the black palette, the rival's "Yeah! Am I great or what?" behind his picture, and no blackout at all after the starter fight in Oak's Lab. A poison faint prints the same line on the map, and Yellow ends the Safari game there.
- A wild Pokemon in Pokemon Tower without the SILPH SCOPE is a GHOST: your Pokemon is too scared to move, the ghost says "Get out...", a thrown ball is dodged and running always works. The restless soul with the scope is unveiled as MAROWAK over the cartridge's own 153-frame animation.
- A traded Pokemon on Red, Blue and Yellow disobeys the way it does there: the MARSH badge is the one at 70, a sleeping Pokemon gets no special line, and the random move it picks instead follows the cartridge's own off-by-one roll.

## Changed

- The cache format is 147. Import your cartridges again.
- Every battle line on Red, Blue and Yellow reads the cartridge's own wording with its own line breaks: "wants to fight!", "sent out", "Critical hit!", "Nothing happened!", "No effect!", "greatly rose!", "Come back!", "Hit the enemy 2 times!" and the rest.
- A trainer's defeat prints "was defeated!" on Gold, Silver and Crystal and "defeated" on Red, Blue and Yellow. The port's own "Player won!" and "The enemy won!" lines are gone.
- The rival is named by his own name in a battle on every cartridge.

## Fixed

- Crystal forgot the rival's name once the naming screen closed, so every later line about him read "???".
- A Red, Blue or Yellow trainer's name printed with a stray space before "wants to battle!".
- The GHOST and the two fossils were drawn from the corner of their box rather than padded like a front picture.

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
