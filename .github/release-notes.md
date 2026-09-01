<!-- The top section is rewritten for each release; everything below it is the
standing text and only takes {VERSION}. One line per paragraph, per bullet and
per table row: GitHub reflows a release body to the reader's window, and a line
break put in by hand only makes it ragged.

It is a changelog, not an essay. `## Added`, `## Changed`, `## Fixed`, one
bullet per change, and no opening sentence summarising the release: a reader
scanning for their own bug does not want a paragraph about the shape of the
work. No `**Bold label.**` in front of a bullet, no contrast frame on every
line ("X rather than Y", "not X, Y"), and no em-dash. `CLAUDE.md`'s "Writing"
section is the whole rule; a reader called an earlier body AI-written and was
right. Rewrite from the line that is exactly `## Added`: an edit that searches
for the first one in the file lands inside this note and takes its closing
marker with it, which is how 0.1.17 published an empty body. -->

## Added

- The magnet train is a ride again. Both stations run the whole cutscene: 375 frames, 192 of the map's 256 pixels of scrolling, and your own overworld sprite drawn through the train window on 230 of them.
- Fly has its animation on both ends of the flight. The party member's menu icon carries you off the map with a widening swing, a leaf crosses every eight frames, and the arrival descends onto the row you left.
- The Berserk Gene works. Its holder spends it at the top of the turn for two Attack stages and a confusion whose length the cartridge never writes, so it runs on whatever count the last Pokemon left behind.
- The three trainer AI files are read against the source and swept over all three cartridges: 10,656 scorings and 3,548 HP bars, covering the four layers that roll no dice.

## Fixed

- A nightmare survived every cure. Waking up, HEAL BELL, a status item from the bag and a held berry all left it standing, and it kept taking a quarter of the Pokemon's health each turn until it switched out.
- SKETCH and MIMIC replaced the first slot holding the move where the cartridge replaces the last, which a Smeargle carrying four SKETCHes reaches. SKETCH also worked on a transformed target, and a transformed user kept what it sketched.
- ATTRACT, MIMIC, TRANSFORM and every stat drop reached a target part way through FLY or DIG.
- An enemy trainer lowering one of your stats now misses about a quarter of the time. LOCK-ON and the accuracy-dropping hits are exempt.
- ATTRACT read the Pokemon standing on the field, so a TRANSFORM changed which gender it saw. It reads what each side came into the battle as.
- BEAT UP read a bench member's health where it wanted its slot number, and Pokerus spread on a threshold one off.
- Objects standing on a side-wall tile refused every step or allowed every step, because the cartridge indexes its direction table with the wall mask. Seven map objects across the two cartridges stand on such a cell.
- A wild battle against a species the Pokedex already holds was missing the ball tile in the enemy's HUD, and the Celebi shrine ran three frames short.
- MYSTERYBERRY did nothing from the pack. It restores five PP, which is the only PP item that does.
- A REPEL used while one is still running is refused and kept rather than restarting the counter, and an ANTIDOTE on a party member poisoned to zero is refused the way the cartridge refuses it.
- The battle transition read a fainted lead's level and, for the opponent, whatever the previous battle ended on. Both are the bytes the cartridge really compares.
- `delcmdqueue` took a handle where the cartridge takes a type byte and answered the wrong way round, and the command queue is four fixed slots again rather than an unbounded list.
- An elevator whose current floor is on no row stalled the script instead of taking the cartridge's own refusal.
- The slot machine had its seven bias and its unbiased reel swapped, turning 23.4 percent of unbiased seven line-ups into a guaranteed 300 coins. Card flip's table was lit under the reveal.
- The Game Corner opened with an empty purse, and its refusal box closed on the frame it opened. Both games ask for coins and the Coin Case first now, coins first.
- A map header palette of 5, 6 or 7 was drawn as a cave.
- Every wild MAGIKARP kept the first size it rolled. Two of the eight maps that can produce one skip the length floor, which is the cartridge comparing feet against millimetres.
- HP bars divide the way the hardware divides, one byte at a time, so a bar at 300 of 401 is 36 pixels rather than 35. The draining number matches the pixel it is drawn beside.
- A move that was used but never announced was still remembered as your last move.
- SOUND in the options did nothing until the next launch. It follows the setting live and restarts the piece on a change.
- The Seer's reading, the Photo Studio's boxes and the Guru's measurement were dropped on the way back from the party list, and a cancelled list said nothing where the cartridge prints a line.
- PRESENT on a target already at full health said nothing with the battle scene on, and a forgotten move plays its sound.
- Badge boosts were paid in Battle Tower and link battles, where the cartridge pays none of either half.
- The item PC's quantity dial wraps: one step down from one is the whole stack.
- The trainer name comparison behind CheckOwnMon reads five letters, not the whole name.

## Changed

- The cache format is 100. Re-import your cartridges once after updating; the magnet train's background and tilemap are new imports.

`api_version` stays 29.

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
