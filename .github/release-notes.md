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

## Fixed

- Mods installed before 0.1.27 read as not installed and could not be downloaded again, because the download was refused by the copy already on disk. The row now says "Installed, not loaded", offers to replace or remove it, and the update button on the mods page reinstalls every one of them in a single press.
- A mod built for an older contract now says which build it wants and that downloading it again is the fix, instead of naming both version numbers and leaving it there.

## Changed

- A Generation 1 hit shakes the screen or blinks the picture it landed on, a Pokemon grows out of its ball when it is sent out, and a thrown ball has its throw, its poof and its rocking. The status animations point at the rows the cartridge uses, and the animations that hide, move or squeeze a picture now move it on screen rather than only recording that they did. None of this is reachable from Play yet: Red, Blue and Yellow are still import and inspection only.

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
