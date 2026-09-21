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

- The START menu, the PC, the Cable Club and the trainer card on Red, Blue and Yellow show the POKéDEX once Prof. Oak has handed it over. The row never appeared before, on any of the three, and a save that already has the Pokedex sees it on load.
- The low-health alarm sounds in a Red, Blue or Yellow battle when the bar turns red, and stops when it turns back.
- Cutting a tree or grass on Red, Blue and Yellow plays the cartridge's own cut: the block splits apart under the cut sound, or the leaves scatter, with the view redrawn on either side.
- Selecting an item with SELECT on Red, Blue and Yellow and pressing it on another swaps the two rows, in the bag and in the mart's sell list.
- Talking to someone on Red, Blue and Yellow turns them to face you, and someone who stands still turns back afterwards, as on the cartridge.

## Changed

- A Pokemon's HP bar on Red, Blue and Yellow turns yellow under 27 pixels, where Gold, Silver and Crystal's turns under 24.
- Someone more than half a screen away on Red, Blue and Yellow stands frozen, as on the cartridge, and a trainer there cannot see you.
- Pewter City's two guides walk you to the museum door or the gym sign from wherever they meet you, as the cartridge's tables say, and stand back where they were afterwards.
- The two Cinnabar Gym doors and every other block a script swaps in view on Red, Blue and Yellow hold the frames the cartridge's redraw spends.
- Pressing a direction on Red, Blue and Yellow is read on the overworld's own pass, behind the map's script, so a tap on the step onto Pallet Town's north path meets Prof. Oak rather than walking out onto Route 1.
- The imported cache is format 151 and is rebuilt on first launch.

## Fixed

- Prof. Oak's PIKACHU battle on Yellow no longer freezes on an empty text box before "Wild PIKACHU appeared!". A battle screen refresh had left the low-health alarm byte at a value Yellow's sound driver reads as "hold the first sound channel", so every cry hung and the text waiting behind it never came; on Android with sound on, no Yellow battle got past its first cry.
- The first cry of a session on Red, Blue and Yellow no longer waits about four seconds before its text: a fresh driver's wave channel counted 255 frames on a cry that never used it.
- A move used instead of the one you chose on Red, Blue and Yellow says "used instead," as the cartridge does.
- A Rare Candy and a level gained in battle on Red, Blue and Yellow play their sound and wait for a press before the stat box, and a TM a Pokemon cannot learn or already knows says so in the cartridge's words with its refusal sound and returns to the party list.
- The mart on Red, Blue and Yellow returns to BUY/SELL/QUIT after "not enough money", "bag full" and "can't sell that", and to the sell list after a sale, with no extra box.
- Pewter Gym's trainer by the door on Red, Blue and Yellow no longer spots you from a column he cannot see.
- A trainer's Pokemon in the swap list on Red, Blue and Yellow prints no ABLE/NOT ABLE beside every row where the cartridge prints none, and the swap arrow stands on the nickname's row.
- The play timer on Red, Blue and Yellow stops at 255 hours and keeps counting through the Hall of Fame.

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
