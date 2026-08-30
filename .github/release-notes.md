<!-- The top section is rewritten for each release; everything below it is the
standing text and only takes {VERSION}. One line per paragraph, per bullet and
per table row: GitHub reflows a release body to the reader's window, and a line
break put in by hand only makes it ragged. -->

## New in this release

A reported bug in the music, a launcher that says which button does what, and a bench share of an experience award for mods.

**Mom's music no longer plays under the town's.** Talking to Mom downstairs started the phone tutorial music while the town's lead kept playing, at a speed that did not match. A music start loads only the channels the new piece names, which is why the cartridge stops the piece in front of every one of them; this port did not. Every music request the game makes stops first now. A sound whose record a cache does not carry skips its script command instead of leaving it pending with nothing to advance it, which is one way a conversation could stick.

**The launcher says which button does what.** The four unlabelled discs are a named tab strip along the top, flanked by the shoulder badges that step it. Every screen prints the actions it offers along the bottom, wearing the control you are actually holding: the badge is read from your own bindings, so a rebind, a pad being plugged in or a hand leaving the keys each change what is drawn. Settings is five sections behind a rail instead of one long scroll, every option is drawn as the same row, and the cartridge options moved off a floating disc onto a plate that names the cartridge. Pad badges print the letters your pad prints; Auto reads the controller that is connected, and Nintendo and Xbox are the two manual answers under Appearance. The cartridge picture, the mods check, the Application settings and the update check are drawn with new glyphs, and a Close chip's words stay readable with the pointer on them.

**A mart refuses on the price before the stack.** An order that was both unaffordable and over the 99 stack said PACK FULL, where the cartridge says you have not got the money.

**For mod authors**, `api_version` is 29. `register_experience_bystanders` pays every living party member a fraction of the fighter's own award: 0.0 is the cartridge, 0.5 is Gen 6's Exp. Share, 1.0 is Gen 8's. A claimed share suppresses the cartridge halving, and a bystander is paid once and last.

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
