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

- Red, Blue and Yellow are playable. The shelf offers Play on all three, and a game runs from the bedroom to the Hall of Fame: 360 steps and eight badges on Red and Blue, 361 on Yellow, through Brock, Mt. Moon, the Nugget Bridge, Bill, the S.S. Anne, the trash cans, Rock Tunnel, the Rocket Hideout, Pokemon Tower, the SNORLAX, the Safari Zone, Silph Co., Cinnabar, Viridian's gym, Victory Road, the Elite Four and the Champion.
- Oak's Lab runs whole, from the speech to the rival leaving with the Pokedex: the starter pick, the fight, the parcel and the hand-over. Yellow's lab hands over the Pikachu.
- The old man's catch tutorial on Red and Blue, and Prof. Oak's Pikachu battle on Yellow, with the cartridge's own ball, back pic and cursor timings.
- Generation 1's own Hall of Fame: the white frames, each member sliding in with its cry, the player's stats and the dex rating, then the credits with their bands, each `CreditsMons` silhouette crossing at 8 px a frame and THE END. 5254 frames on Red and Blue, 5248 on Yellow. `sHallOfFame` keeps 50 teams and the League PC walks them oldest first.
- Vermilion Gym's fifteen trash cans and the door they open, Cinnabar Gym's six quiz machines and the trainer a wrong answer walks up, the Champion's Room's eleven states, Pokemon Tower 7F's rocket walking off, and Pewter City's museum and gym guides.
- Every map-script body but the two link maps decodes on all three cartridges: Red and Blue read 183 state bodies of 373, Yellow 223 of 408, against 186 of 206 last release.
- The S.S. Anne leaves the dock, with its 1144 frames and the gangway taken off. The game designer's completed-dex diploma prints.
- The Hall of Fame music starts on the page that asks for it and fades on the page that ends it, on both generations.

## Changed

- The cache format is 133. Import your Generation 1 cartridge again.
- Blue's `TheEndGfx` sits one byte on from Red's, and `Gen1Layout` pins the credits tables for all three.
- A Generation 1 map's load-time work is its entry script walked under each `wCurrentMapScriptFlags` bit, and `EndTrainerBattle` puts the map's script back on row 2 the way the cartridge does.
- Cinnabar Gym's gate flags were compared against emulator block-write traces, all 128 masks per cartridge, and every trainer after wins, losses and re-entry.

## Fixed

- Every Generation 1 map connection landed at the source x, so Route 1 came out ten cells into Viridian's fenced corner.
- No TM or HM could be taught on Generation 1.
- A trainer paid a hundred times the prize, with Crystal's quarter split on top.
- Every Elite Four room's end-battle state printed its after-battle line for ever.
- Silph Co. 3F's card key door shut again on the way back from 11F, and the Mansion's four switches opened nothing.
- The tower's MAROWAK stood again after every won fight, and the Safari gate asked "Leaving early?" for ever.
- Lance's trigger asked for a wild Pokemon of species 0. The LIFT KEY never appeared and EVENT_BEAT_LANCE was never set, because three trainer texts are machine code.
- Yellow's Safari gate printed `<NUM_CD3D>` where Red spells ¥500, and `HiddenCoins`' two boxes printed `<NUM_FFA0>` on all three cartridges.
- Pewter City's two guides and Bill were placed four cells off.
- A Safari or tutorial battle sent the lead out and drew a player HUD.
- Lt. Surge's receipt did not name TM24 and the Silph rival did not name the player.
- The Viridian Mart clerk's two parcel rows were empty, and Mt. Moon's super nerd fought the last rocket met.
- A Generation 1 induction drew Crystal's panels and then stopped on "The credits are not in this cache".
- `_DexRatingText` wrapped and could not print, from a `<COLON>` encoded as seven unknowns.
- The story walk stopped on every ledge hop. All three Johto profiles walk to Red again.
- `GameData.palette` raised on a species record without a palette.
- README lines still said Play was refused on Generation 1.

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
