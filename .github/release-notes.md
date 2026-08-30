<!-- The top section is rewritten for each release; everything below it is the
standing text and only takes {VERSION}. One line per paragraph, per bullet and
per table row: GitHub reflows a release body to the reader's window, and a line
break put in by hand only makes it ragged. -->

## New in this release

One reported bug, one thing the mods page was missing, and two ways to make the game your own.

**Your own Pokemon no longer has a duplicate beside it.** A battle slides your trainer picture off its square before your first Pokemon is sent out, and pressing A through "Wild LEDYBA appeared!" ran the battle on in the middle of that slide: the new picture was put back and the rest of the slide walked it two columns left, leaving a strip of it at the edge of the screen for the rest of the fight. That is where the doubled sprite came from, and why it was a different width every time. Nothing in the game reads a button during a slide any more, which is what the cartridge does.

**Update all.** The mods page had one button for checking your sources for updates. It is now that button until something is out of date, and a download button after, saying how many. One press downloads and installs every update in turn.

**Put your own art on a cartridge.** The three dots above the shelf now take a picture of your own for the cartridge you are looking at, and give the shipped one back whenever you want it. Any PNG, WebP or JPEG; it is scaled to fit the cartridge whatever shape it is, and kept beside your saves, so an update never asks for it again.

**For mod authors**, `api_version` is 26, and both new seams are for quality-of-life mods. A mod can turn B into running shoes: on foot, a step taken while B is held goes at bike speed, your follower keeps up, and a recorded run replays at the same speed. And a mod can scale experience, from a half to five times, applied at the one place every award passes through, so the participant split, the Exp. Share, level ups, move offers and evolutions all follow from it. Stat experience is left exactly as the cartridge pays it.

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
