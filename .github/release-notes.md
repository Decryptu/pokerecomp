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

- Yellow's Pikachu walks behind the player: the follow buffer, the eight movement commands and their hop arcs, the tricks a hop earns, the spawn state every warp and connection leaves, and the happiness and mood bytes. A 2222-frame route from the bedroom over Route 1's ledge matches the cartridge frame for frame.
- Talking to the follower opens its face box, with `PikachuEmotionTable`'s bubbles, movements and faces timed from the A press. Its scenes run: the Fan Club's Seel, Bill's house, the Pewter center, Mt Moon, Cinnabar Gym, Oak's lab, Viridian City, Pokemon Tower 2F and the Game Corner.
- Pewter's Jigglypuff sings on all three cartridges, turning every 24 frames until the channels fall silent, and Yellow's follower falls asleep behind it.
- Happiness moves from all eleven of the cartridge's callers: walking, the PC deposit, items, a Rare Candy, a TM, a poison faint, a trade, the level-up, a faint, the X items and a gym leader's fight.
- Trainers on Red, Blue and Yellow fight with the cartridge's own head. The move roll is `SelectEnemyMove`'s, the three scoring layers are `AIEnemyTrainerChooseMoves`', and each class's routine spends its item or switches where its move would have been: Brock's Full Heal, Misty's X Defend, Erika's Super Potion, the Jugglers' switches, Agatha's, Lance's Hyper Potion, every one at the odds its `cp` leaves.
- Gym leaders and the Elite Four carry their signature moves: Brock's Onix knows BIDE, Misty's Starmie BUBBLEBEAM, Lorelei's Lapras BLIZZARD, the champion's Pidgeot SKY ATTACK and its starter the move its species names, and Yellow's own per-trainer rows.
- The trainer's own withdraw and item lines, `AIBattleWithdrawText` and `AIBattleUseItemText`, with the trainer named.

## Changed

- The cache format is 135. Import your cartridges again.
- Generation 1 steps take seventeen frames where the cartridge's do, a turn shows one pass, a ledge is found on one pass and hopped on the next, and a warp follows `GBFadeOutToBlack`'s timeline with the screen back at 39 frames indoors and 41 out.
- Every `EmotionBubbles` row of Red, Blue and Yellow is imported under Generation 2's names.

## Fixed

- An opponent's PP was spent on Generation 1, where the cartridge never spends it.
- Quick Attack went at ordinary speed and Counter did not go last on Generation 1.
- A gift Pokemon's OT id was not the player's.
- A held direction walked past Oak on the north path.
- Event flags 0 to 7 were lost across a map load on Generation 1.
- The first door out of a house did not open on a new game, `wLastMap` starting empty.
- Pewter's mart could not be opened by the replay tool on the three Generation 1 caches.

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
