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

## Fixed

- Every question and every list a conversation opens stood over the wrong lines. A box carries the last thing said before the question, so Mom's day-of-the-week dial no longer sits over "#MON GEAR, or just #GEAR." and her phone question no longer sits over "Come home to adjust your clock". 116 of Crystal's 155 questions and 92 of Gold and Silver's 122 were showing text nobody had just read.
- Mom's day-of-the-week picker asked nothing and painted the room white. It asks "What day is it?" over the house, and the box under it reads " 6:00 AM DST, is that OK?" on a twelve-hour clock.
- Six script commands were read at the wrong width or not read at all, so a conversation that reached one stopped where it stood. Twelve fewer Crystal scripts and four fewer on Gold and Silver now stop on a byte no command owns.
- Eleven more commands were decoded and then refused, among them the two the phone scripts name 119 times.
- An earthquake shook for half as long as the cartridge shakes it and froze nobody while it ran, and Rock Smash's own shake had no strength at all.
- The shop list carried seventeen sites the cartridge does not ship, each selling two Potions, Whirl Island B1F among them.
- The POKéGEAR clock and the Daylight Saving box read the time through two different routines. Both are `PrintHoursMins` now.

`api_version` stays 29 and nothing on the boundary moved.

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
