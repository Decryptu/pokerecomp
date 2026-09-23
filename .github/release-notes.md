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

- PP UP works on all six games. Pick the move from the pack and its PP goes up by a fifth, up to three times. Saves imported from a cartridge keep the PP Ups they had, and exported ones carry them back.
- Status animations in battle: the sleep, confusion and love animations on every turn a Pokemon is asleep, confused or in love, and the poison, burn, Leech Seed, Nightmare and Curse animations with their damage.
- Gold, Silver and Crystal print "X is in love with Y!" every turn an infatuated Pokemon tries to move.
- Red, Blue and Yellow show both parties' Poke Ball rows when a battle starts. On all six games, a trainer's row comes back, with the fainted one crossed out, before their next Pokemon comes out.
- Mods can rewrite any wild table while the game runs: grass, surf, fishing, Headbutt, Rock Smash, swarms, the Bug-Catching Contest and roamers. A switch in a mod's settings can put its changes in or take them back without a restart. A Pokemon added by another mod can be met in the wild.

## Fixed

- A nicknamed Pokemon is called by its nickname in battle. The HUD, "Go! X!", the EXP line, level-ups and move learning all showed the species name.
- The status lines on Gold, Silver and Crystal read as on the cartridge: "X's fully paralyzed!", "X's paralyzed! Maybe it can't attack!", "X's badly poisoned!", "X is hurt by poison!", "X's hurt by its burn!" and "X's infatuation kept it from attacking!".
- Learning a new move in battle asks the question once, with no extra line in front. Red, Blue and Yellow asked it twice. Forgetting a move says "1, 2 and... Poof!" again.
- Red, Blue and Yellow say "New POKéDEX data will be added for X!" after a catch.
- A Pokedex entry on Gold, Silver or Crystal no longer shows the description of a Pokemon you have only seen.
- The trainer card on Gold, Silver and Crystal shows ¥ before your money.
- The stats page on Red, Blue and Yellow shows a dash for each empty move slot.
- On Red, Blue and Yellow, a Pokemon fainting from poison in the field is announced before the screen flashes.
- A mod's grass table with fewer slots than the game rolls is refused, instead of turning up no Pokemon at all on those slots.

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
