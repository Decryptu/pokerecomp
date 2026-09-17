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

- Red, Blue and Yellow's OPTION menu is the cartridge's own: three sections on Red and Blue, and Yellow's one page with SOUND over MONO and the three EARPHONE settings, which now reach the sound driver, and PRINT.
- SAVE on Red, Blue and Yellow asks the cartridge's question over the START menu, saves before "Now saving..." (Yellow's "Saving..."), and closes the menu either way, as the cartridge does.
- Yellow is coloured as a Game Boy Color colours it: every species, bar, town map and map palette comes out of the table the hardware reads, and the intro and battle sprites carry their own palette bits.
- Yellow's Pikachu has its voice: the 42 clips play from the title, the emotion table, scripts, battles, the Hall of Fame, the status screen, Bill's PC, the day care and a poison faint.
- Every script sound on Red, Blue and Yellow plays, and the rival's theme and the Champion's room music start where the cartridge starts them.
- A mod's stats page turns on Red, Blue and Yellow, after the moves page, with A (`api_version` 33).
- A mod asked about a mart is told the map and, on Red, Blue and Yellow, the counter it was opened at (`api_version` 32).

## Changed

- The cache format is 142. Import your cartridges again.

## Fixed

- "#DEX" drew "?DEX" on a Generation 1 font, on the save box and everywhere else the source writes `#`.
- Yellow's SOUND option had never reached the sound driver.
- A catalogued shop behind another clerk's script was filed under that clerk's entry point: Goldenrod Dept Store 2F's second counter.

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
