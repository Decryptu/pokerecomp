<!-- The top section is rewritten for each release; everything below it is the
standing text and only takes {VERSION}. One line per paragraph, per bullet and
per table row: GitHub reflows a release body to the reader's window, and a line
break put in by hand only makes it ragged. -->

## New in this release

This one is all about catching. Every number a thrown ball uses was checked against a real cartridge, case by case, and a lot of them were wrong.

**The seven balls Kurt makes now work.** Take him apricorns, get a Level Ball or a Lure Ball or a Heavy Ball back, and the game refused to let you throw it. All seven do what they are supposed to do now, including the ones that famously do nothing: the Moon Ball never helped on a real cartridge either, and it does not here.

**A Pokemon you catch arrives the way you left it.** It used to turn up at full health with its status cured. Catch one at 3 HP while it is asleep and that is what joins your party, which is what the cartridge does and what makes weakening one worth doing.

**Every Pokemon you caught was being treated as a traded one.** They were given a random trainer ID instead of yours, so they collected the extra experience a traded Pokemon gets, for the rest of the game. They get your ID now.

**Catch rates match the cartridge exactly.** Health, sleep, freeze, every ball's multiplier and the odd corners of the arithmetic the original got wrong. A Pokemon with more than 341 maximum health really is easier to catch at full health than at half on a real cartridge, and it is here too.

**A caught Pokemon comes with full PP**, which it did not before.

**Catches go into the box you have open, at the top of it.** They were going to the first box with room anywhere in storage, and to the bottom. If the open box is full the throw is refused, the game says so, and you keep the ball.

**Throwing a ball costs your turn.** A ball that broke free used to be free: the wild Pokemon just stood there. It attacks now.

**A ball thrown at another trainer's Pokemon is thrown.** You see it knocked away, you get both lines about it, and you lose the ball, exactly as you should.

**The pack asks USE or QUIT.** Picking a ball used to ask you which ball a second time. It asks the question the cartridge asks instead.

**Catching a new species adds it to the POKEDEX in front of you.** The line about new data and the entry page behind it were both missing.

**A Pokemon on the end of a rod says it was hooked** when the fight starts, instead of saying it appeared. The game now knows a fishing battle from any other, which is also the one battle a Lure Ball helps in.

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
