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

- Using a Potion, a status cure, a Revive or a Rare Candy from the party menu on Red, Blue and Yellow prints the cartridge's own line in the speech box, fills the bar under the Potion sound first, and a Rare Candy shows the level-up stat box. Vitamins, PP restores and refusals print over the list as it stands.
- A gift Pokemon, a caught Pokemon sent to the box and a move learned over a full set say their Red, Blue and Yellow lines: "Got EEVEE!", the nickname question, "sent to BILL's PC" once Bill has been met, "There's no room" when neither has any, and the Move Deleter's own wording with its swap sound.
- A Repel wearing off says so, on every cartridge. Before this, the count ran out in silence unless a mod renewed it.
- A status move that lands on nothing says what its own routine says: "It didn't affect", "already asleep", "already paralyzed", "already poisoned", "already confused", "evaded the attack" or "But it failed!". Every one of them had said "attack missed" or nothing.

## Changed

- Trainer Pokemon on Red, Blue and Yellow carry the cartridge's DVs (`$9888`) rather than perfect ones, so a trainer's Pokemon has the HP and stats the cartridge gives it.
- Gaining several levels in one fight on Red, Blue and Yellow jumps straight to the final level, says "grew to level N" once and offers only that level's moves, which is what the cartridge does.
- Withdrawing a Pokemon from the PC on Gold, Silver and Crystal restores its HP and clears its status, and depositing one restores its PP.
- The imported cache is format 149 and is rebuilt on first launch.

## Fixed

- Thunder Wave, Sing, Stun Spore, Glare and Leech Seed land behind a Substitute on Red, Blue and Yellow, as they do on the cartridge; Glare paralyses a Ghost-type there too.
- A trainer's Thunder Wave, Sleep Powder or Toxic on Red, Blue and Yellow no longer fails a quarter of the time. That roll is Gold, Silver and Crystal's.
- Rest on Red, Blue and Yellow no longer resets a bad poisoning's counter, so a Pokemon that was badly poisoned and rested is hurt the way the cartridge hurts it when poisoned again.
- Seafoam Islands' strong current runs on Red, Blue and Yellow; its B3F script never ran on a frame with no boulder pushed, and the puzzle could not be finished.
- Pushing a boulder on Red, Blue and Yellow checks the tile two cells ahead, as the cartridge does; the port had checked the boulder's own tile and let a push through where the cartridge refuses one.
- Yellow's Underground Path trade evolves the MACHOKE into MACHAMP, and a link trade records both the species that arrived and what it became.
- Walking out of a door or a warp on Red, Blue and Yellow no longer spends three quiet steps: only a fight arms the wild cooldown, and a step onto a map through a warp counts neither for poison nor for an encounter, on any cartridge.
- The Pokemon Center on Red, Blue and Yellow asks "Shall we heal your POKéMON?" on the first visit only, then greets you with the yes/no box.
- A vending machine on Red, Blue and Yellow checks for ¥200 whatever the drink costs and a purchase that would go below zero leaves ¥0, both as the cartridge does.
- Yellow's VAPOREON learns HAZE at level 42 and never MIST, as on the cartridge.
- The last poisoned party member fainting on the overworld on Red, Blue and Yellow is silent, as on the cartridge.
- The cartridge's battle level-up box on Red, Blue and Yellow shows SPECIAL, where the port had shown SPCL.ATK and SPCL.DEF.

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
