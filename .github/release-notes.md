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

- Yellow's Surfing Pikachu minigame runs whole at Pikachu's Beach: the waves, the jumps, the radness score, the high score and the printer's high score page, measured against the cartridge frame by frame.
- Yellow's printer pages: the diploma, the Pokemon portrait and the surfing high score, each drawn as the cartridge draws them.
- Bill's Pokemon list, the Indigo Plateau statues, the beach house and the Fan Club chairman's printer all run their scripts; no Generation 1 script arm is left unknown.
- A shiny is drawn shiny on Red, Blue and Yellow, with Gold, Silver or Crystal's colours when one of those is imported, and the shine plays on the send-out (`api_version` 34).
- Mods reach Red, Blue and Yellow: hidden items, a row on a party member's menu, whether Yellow's Pikachu is out, and `generation()` to tell the cartridges apart (`api_version` 34 and 35).
- Exp. All. The EXP.ALL in the bag halves the block, pays the Pokemon that fought, then pays the whole party the way the cartridge does, and the "with EXP.ALL," line prints.
- An HM in the bag can be a field-move source on Red, Blue and Yellow, behind Kanto's badges, for a mod that allows it.
- A mod's PC row opens Bill's own PC on Red, Blue and Yellow.

## Changed

- The cache format is 144. Import your cartridges again.
- A Repel renewal mod is handed the cartridge's own Repel table instead of carrying item numbers (`api_version` 35).

## Fixed

- A Generation 1 hidden item's flag was read as an event flag; it is an engine flag.
- Some Generation 1 script rows were never matched because the cache stored their numbers as floats.
- `tools/preview_pics.gd --shiny` drew Red's shinies the same as their normals.

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
