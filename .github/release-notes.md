<!-- Rewrite from the first release heading, `## Added

- Red, Blue and Yellow cartridge saves can be imported with Import .sav. Party, boxes, bag, item PC, money, coins, badges, Pokédex, event flags, position, Hall of Fame and Yellow's Pikachu data are carried over.
- Bug-Catching Contest judging announces third, second and first place with the cartridge's texts, placing jingles and scores.
- Mods: `menu_path` in `mod.json` puts a mod's settings under named categories in the start menu's MODS entry, for example Community Mods, then SIRsparky Mods, then Wild Encounters. Mods that name the same path share one submenu.
- Yellow: the Pokédex has the PRNT row and Bill's PC has PRINT BOX, both answering with the printer error.

## Changed

- Full-screen menus fade to white and back when opening and closing, with each cartridge's measured timings.
- Holding a direction in a long list scrolls at the cartridge's pace: every 9 frames on Gold, Silver and Crystal, and after a 30-frame delay on Red, Blue and Yellow.
- Yellow's Pokémon Center nurse walks a following Pikachu to the counter and hides it during the heal. Red and Blue's nurse turns and bows.
- Gold and Silver open the pack's item menus on the left side of the screen.
- Text pauses, frame waits and fades inside Generation 1 scripts now take the time they take on the cartridge.

## Fixed

- The level-up, learned-move, item pickup, hidden item and key item jingles were silent. They play when the text reaches them, and the text waits for them.
- Pokédex entries play the Pokémon's cry when opened and when stepping between entries.
- Red, Blue and Yellow: accuracy and evasion stages used Gold and Silver's table, so Sand-Attack, Smokescreen, Flash, Double Team and Minimize had the wrong effect.
- Red, Blue and Yellow: Struggle ignored type matchups and could hit Ghost-types. Mist no longer blocks the stat drop from Psychic, Bubblebeam or Aurora Beam. Acid lowers Defense a third of the time instead of about one in nine.
- Red, Blue and Yellow: the "super effective" and "not very effective" messages follow the cartridge on dual-type targets.
- Red, Blue and Yellow: Pay Day money is collected when a wild Pokémon flees, and not on a catch or a run.
- Gold and Silver: four trainer AI move rules, the switch AI, the Lucky Number Show's box range and Silver's default rival name (GOLD) follow those cartridges.
- Crystal: CHANGE BOX saved the box you were leaving.
- The slot machine's win box printed a placeholder where the payout amount belongs.
- Link trades show a traded Pokémon's evolution. Gold and Silver use their own trade screen layout.
- The Pokégear clock updates while the CLOCK card is open, and the Pokédex Show radio program reads the entry's category.
- Yellow: the surfing minigame's game over text was drawn mostly off screen.
- `beat_red` stayed false in older saves after Red was beaten. Loading the save now repairs it ([#847](https://github.com/Decryptu/pokerecomp/issues/847)).

## Updating this release

- Cartridge cache format is now 163. Import each cartridge file again when the launcher requests it. **Saved games are kept separately and remain intact.**
- Mod API version is still 59. Existing supported mods remain compatible.

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
