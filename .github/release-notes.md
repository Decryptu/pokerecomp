<!-- The top section is rewritten for each release; everything below it is the
standing text and only takes {VERSION}. One line per paragraph, per bullet and
per table row: GitHub reflows a release body to the reader's window, and a line
break put in by hand only makes it ragged. -->

## New in this release

Mostly about how walking looks and feels, plus three screens the port had left plain.

**The map scrolls smoothly.** The camera used to move a whole Game Boy pixel at a time, sixty times a second, which on a modern panel is twelve screen pixels a jump and reads as a row of stills rather than motion. With SMOOTH SCROLL on, the picture now sits on a screen pixel instead: over 900 frames of walking through New Bark Town on a 120 Hz display, 457 of them used to move nothing at all, and now 15 do. The picture itself is unchanged, pixel for pixel; only where it sits between two of them is new.

**Walking no longer stutters at every cell.** A held direction dropped one drawn frame and doubled the next, once per step, at every frame rate. That is gone: 240 frames of the same walk now run 151 frames in a row of steady motion and stop only at the map edge. A frame the system swallows also costs the frame it swallowed and nothing else, where before one dropped frame a second was enough to unsettle the pacing for the next twelve.

**The shop opens on the map.** The cartridge prints the clerk's welcome and opens BUY/SELL/QUIT over it with the town still behind both, and the port drew the buy list under all of it and spent a button press on the welcome. The press is gone and the counter looks right.

**Saving says what it is doing, everywhere.** CHANGE BOX used to switch boxes silently, MOVE PKMN W/O MAIL opened its listing with nothing in front of it, and the cable club and Battle Tower wrote their saves with a blank screen. All three now ask first and show the save, as the START menu already did. The Hall of Fame draws SAVING RECORD before an induction.

**Waterfalls, whirlpools and the Ruins of Alph.** A waterfall climb is paced one cell at a time with the climber spinning up it, and a fall drawn to the top row of the map no longer refuses. A whirlpool spits the player back out instead of holding them. Flash in the Aerodactyl Chamber and an Escape Rope in the Kabuto Chamber each open their wall, which neither did before.

**On a phone or handheld, the on-screen controller stays put.** Android reports its own Back button, navigation bar and volume rocker as key events, and one of them read as a keyboard being picked up: the controller vanished mid-game and the map grew into the space. Only a controller you actually plug in takes over now.

**For mod authors**, `api_version` is 25. A world actor can ask whether the party is physically with the player, so a follower puts itself away at a healing machine, the Day Care counter and a trade. A visible wild encounter can walk from cell to cell instead of teleporting. And a step in flight says which two cells it runs between, for a renderer whose world is not a flat grid.

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
