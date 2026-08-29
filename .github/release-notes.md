<!-- The top section is rewritten for each release; everything below it is the
standing text and only takes {VERSION}. One line per paragraph, per bullet and
per table row: GitHub reflows a release body to the reader's window, and a line
break put in by hand only makes it ragged. -->

## New in this release

Three things reported since the last release, and the rest of what landed with them.

**A held direction lets go when you do.** This is the big one. Holding a direction latched it: the menu carried on scrolling after you let go of the key, and if you closed the menu your character walked off in that direction with no way to stop them. The direction you had held could not be pressed again either, so the game became unplayable until you restarted it. It affected the keyboard, every controller and the launcher as well as the game, and it is fixed at the cause: a repeat is now sent to the screen that needs it instead of being recorded as a button that is still down.

**Starting a new game asks its questions properly again.** Oak asks you to set the clock, and the two confirmations had lost the thing they were confirming: the game said "What?" and then "Whoa!" over an empty screen and waited for a YES or a NO. They now read the way the cartridge reads them, "What? / DAY 10 o'clock?" and "Whoa! 0 min.?", so you can see what you are agreeing to.

**A controller can get through the launcher.** Nothing was highlighted on Settings, About or any other page long enough to scroll, and holding a direction threw the page around instead of moving between things. The highlight now lands on a real control, walks the whole page, and reaches the row of buttons along the bottom from anywhere. Holding a direction on a page of text scrolls it a tenth of a screen at a time rather than a whole page. The save editor moved two rows for every press and now moves one.

**The catching tutorial is played, not skipped.** The Dude in Cherrygrove used to hand you the line about a caught Pokemon and nothing else. He now fights the battle, works the pack and throws the ball himself, at the pace a real cartridge does it.

**A file can be picked without a mouse.** The system file browser needs a pointer, which a Switch and most handhelds do not have, so importing a cartridge meant leaving the dump at the root of the SD card. There is a browser built into the launcher now: one button per row, a d-pad walks it, and nothing on it has to be typed. Exporting a save also suggests a filename, which is the whole name where there is no keyboard.

**The mods list fits a phone.** On a narrow window each row's switch, bin and arrow get their own line, so "Hidden ..." is "Hidden Stats" and four cards fit where five were crammed.

**A button held when the app goes to the background is let go.** Take a call or switch apps mid-step on a phone and that button stayed down as far as the on-screen controller was concerned, so it never worked again until you restarted.

**CHANGE BOX in the PC works.** It was drawing a single broken row instead of the fourteen boxes. The mailbox and the box list are also drawn where the cartridge draws them, spacing and frame included.

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
