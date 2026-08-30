<!-- The top section is rewritten for each release; everything below it is the
standing text and only takes {VERSION}. One line per paragraph, per bullet and
per table row: GitHub reflows a release body to the reader's window, and a line
break put in by hand only makes it ragged. -->

## New in this release

One reported bug that closed fifteen more with it, the last movie the cartridge had left, and a reset that works wherever you press it.

**The PC's lists answer the arrows again.** Withdrawing and depositing would not move past the first Pokemon in the list, at a Pokemon Center and from the start menu alike. A focus ring meant for the launcher was going up over the box screen and eating every direction press. Reading the whole machine against the disassembly afterwards paid for a good deal more: the cursor returns to the top row after a transfer, the Pokemon cries when it is stored, taken out or released, a full box or a full party says so under the menu you asked from instead of throwing you back to the list, every refusal makes the sound it should, a finished MOVE PKMN W/O MAIL stays on the list you moved into, the stats page you open from a box walks that box, the box picker opens on BOX 1, PROF.OAK'S PC asks before it rates your Pokedex and says goodbye afterwards, and the machine plays its boot, choose and shutdown sounds. The selection ring on Crystal was five pixels out and left a loose line floating above the row below it; it closes now.

**The trade animation plays.** The tube, the ball, the cable and your Pokemon riding through it, one command a frame the way the cartridge spends them, behind both a link trade and an in-game one. Checked frame by frame against a real cartridge: 361 of 361 sprite states on Crystal and 405 of 405 on Gold and Silver, in order.

**A + B + START + SELECT resets from anywhere.** The console's own chord was wired to the overworld alone, so pressing it in a battle, in a menu, on the title screen or in the launcher did nothing at all. Every screen answers it now, and the overworld still asks first where there is room for the question. Your save page counts how many resets a slot has spent.

**SMOOTH SCROLL is smooth in more places.** A follower, a visible wild Pokemon and a jump down a ledge all move on the same fraction of a step the player does, rather than in eight jumps. A follower taking a ledge arcs over it instead of walking through it.

**A cartridge bay says which kind of empty it is.** A cache written by an older build looked exactly like a cartridge you had never imported. The shelf now tells the two apart, says so in a line under the bay, and puts the one button that fixes it in front of the file picker.

**For mod authors**, `api_version` is 28. A mod can switch trainer sightings off the way it can switch wild encounters off, without touching a flag. An actor can name the two cells it runs between, and the drawn row carries the height that comes with it, so a 3D view has the arc to work with.

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
