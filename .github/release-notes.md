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

- Leaving and entering a map on Red, Blue and Yellow plays the cartridge's own animations: a warp pad lifts you off the floor and sets you down, a hole swallows the top half of your sprite and drops you onto the floor below, an Escape Rope, Dig or Teleport spins you in place and up, and Fly turns you into the bird that flaps off the screen and glides back in. The white fades, every teleport and fly sound, and the fifty-frame drop through a hole are frame for frame the cartridge's, measured on Red and Yellow.
- `Gen2WorldTileset.name`, the `TILESET_*` constant's name on every cartridge, and `GameData.world_tileset_named()`, so a mod keyed by tileset reads the same on Gold, whose numbering sits three lower than Crystal's past KANTO. `api_version` 40.
- `Gen2BattleColors`, the colours a battle is drawn in on either generation, for any renderer a mod registers; `Gen2WorldPalette.overworld_sprite_colors`, `Gen2WorldMap.is_outside()` and `Gen2WorldCollision.gen1_ledge_direction` beside it. `api_version` 39.
- Every slot a visible-encounter provider is handed carries `chance`, its weight in the roll, a shiny wild on Red, Blue and Yellow is announced with the shine sound, and Yellow's Pikachu is held in `occupied`. `api_version` 38.

## Changed

- The mod contract is `api_version` 40; both example mods declare it.

## Fixed

- A Red, Blue or Yellow map numbered a block 0 and it was drawn as the map's border: 118 blocks on Red, the east end of Oak's Lab in Pallet Town among them, stood as tall grass or trees.
- After a fly, an Escape Rope, Dig, Teleport or a fall through a hole on Red, Blue and Yellow the player faces down on landing, as `ResetPlayerSpriteData` leaves them; a fall had kept the facing you fell in with.
- A Red, Blue or Yellow battle drawn by a mod's renderer printed its text box in white and black.

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
