<!-- The top section is rewritten for each release; everything below it is the
standing text and only takes {VERSION}. One line per paragraph, per bullet and
per table row: GitHub reflows a release body to the reader's window, and a line
break put in by hand only makes it ragged. -->

## New in this release

**Controllers work in menus again.** A stick or a d-pad used to fly down a list: one push moved the cursor half a dozen rows, so picking an item or a move was guesswork. A held direction now moves one row, waits a quarter of a second, then repeats at the speed the Game Boy repeated at. Holding the d-pad to run down a long box list works too, which it never did before.

**Battles ran at double speed.** Every fight started from the overworld was spending each frame twice. Health bars drained twice as fast, move animations played twice as fast, and the little arrow that tells you a text box is waiting flickered instead of blinking. Fights now run at the speed the cartridge ran them at.

**A fainting Pokemon waited for its own health bar.** The sprite used to start sinking off the screen while the bar beside it was still emptying. The bar empties first, then the picture goes, in that order.

**The ball stays on screen when you catch something.** After the wobbles it used to vanish the instant the animation ended, so "Gotcha!" was printed over an empty field. The ball now sits closed on the ground until you press past that message, which is what the cartridge does.

**What a thrown ball says is what the game says.** "The ball shook!" was never in either cartridge. A throw now says the item was used, the ball rocks, and then one line: either "Gotcha!" or one of the four real messages for a break-out, chosen by how many times it rocked.

**Five lists a battle asks with are real menus now.** The pack, the balls you can throw, the move an Ether goes on, and the forget offer and its yes/no used to be a line of key names in the text box. Each is a drawn list you move a cursor through, with up and down as well as left and right.

**HOME leaves the game.** A new row under EXIT in the START menu hands the cartridge back to the launcher. It asks first, because nothing is saved on the way out.

**A + B + START + SELECT resets, like it did on the console.** It works on the map and inside a fight, and puts you back at the save screen. Shiny hunters know why. The first time you ever press it the game asks whether you meant to, so a handful of buttons pressed by accident cannot cost you a walk; answer once and it never asks again.

**A press during a trainer's approach no longer breaks the fight.** Holding A while a trainer walked up to you killed the script behind the battle. The fight still happened, but everything after it did not: a gym leader's badge, the flag behind it and its text all went missing.

**The lines a badge, a TM and a found item print stay up long enough to read.** They were being replaced a frame after they appeared on any machine drawing faster than the sound was being mixed.

**The save editor fits a phone.** It was drawn at desktop size on a phone screen, which made it unreadable and unusable. It is now drawn at the size everything else in the launcher is, and it stands clear of the notch and the home bar.

**For mod authors**, `tools/record_clip.gd` can aim a recording at what is on screen rather than at a frame number, which is what a clip that has to fight, open the pack or throw a ball needs.

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
- **iOS**: the `.ipa` is deliberately **unsigned**. Install it with [AltStore](https://altstore.io) or [SideStore](https://sidestore.io), which sign it on your own machine with your own Apple ID. A free Apple ID works; apps signed that way need re-signing every 7 days.
- **Switch**: extract the zip at the root of your microSD, so the file lands at `switch/pokerecomp.nro`, and launch **pokerecomp** from the homebrew menu. It needs a console that already runs homebrew; nothing here installs one.

## Updating

The launcher's about page tells you when a newer release exists. It does not install it: download the new file and replace the old one. **Your saves are kept separately and survive it**, on every platform.
