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

- Battle animation sounds play on the side of the field the move came from. All 1,016 of them were centred; with stereo on they now pan 443 left and 573 right on your turn and the mirror on the enemy's.
- GROWL and ROAR played the plain cry instead of the pitched one their animation asks for.
- Six Crystal tilesets drew with the wrong colours: POKECOM_CENTER, BATTLE_TOWER_INSIDE, ICE_PATH, HOUSE, RADIO_TOWER and MANSION each carry eight fixed palettes and were taking the indoor or cave row. The Ice Path's floor was cave green.
- Fishing drew you standing, holding a rod tile from the wrong sheet. The lower half of the sprite is the cartridge's own fishing pose, Kris's on Crystal.
- The Pokedex page a new catch opens closed on B before its second page was ever shown, walked to other species on up and down, and stood on a PAGE/AREA/CRY/PRNT row the cartridge blanks.
- Cut and Fly leaves ran a frame out of step. A cut leaf opened on your own corner rather than four pixels out, a Fly leaf was drawn on the frame it was made and deleted a frame early, and the arrival drew one extra frame with the icon centred.
- The entrance shine, both exp bar sounds, the hit sound and four menu beeps skipped the check that stops a sound cutting itself off.

## Changed

- The cache format is 102. Re-import your cartridges once after updating: the six Crystal palette sets and the two fishing sheets are new imports.

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
