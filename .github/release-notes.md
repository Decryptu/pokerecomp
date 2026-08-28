<!-- The top section is rewritten for each release; everything below it is the
standing text and only takes {VERSION}. One line per paragraph, per bullet and
per table row: GitHub reflows a release body to the reader's window, and a line
break put in by hand only makes it ragged. -->

## New in this release

**Three ways to play, and the game keeps the rules for you.** Starting a new game now asks whether it is a Vanilla, Hard or Nuzlocke run. Nothing to install and nothing to remember to do yourself. The mode belongs to that save and cannot be changed later, because a challenge you can switch off after a death is not a challenge. Every save you already have is a Vanilla run and is untouched by this.

**Hard** makes every trainer in the game a real fight. Each one scores its moves with all ten of the game's own decision layers instead of the handful its class was given, switches out readily, and brings a party 15% higher in level with perfect stats and full training. The teams are still the ones the cartridge wrote: this raises them by one rule each rather than rewriting eight hundred of them.

**Nuzlocke** plays itself by the rules, so you do not have to:

- **One catch per area.** The first wild Pokemon you meet on a route, in a cave or in a town is the only one you may throw a ball at there, and it is spent whether you catch it, beat it or run from it. The ball menu tells you which area it was. The area is the met location a Pokemon's own summary shows, so a whole cave is one encounter rather than one per floor. Roamers and the Bug Catching Contest belong to no area and spend nothing.
- **A faint is death.** A Pokemon that faints is gone for good on the way out of the battle, and it is written to disk the moment it happens: quitting and reopening the save cannot bring it back.
- **Every Pokemon is nicknamed.** The question is skipped and the keyboard opens, for a catch, a gift and a hatched egg alike.
- **Losing your last Pokemon ends the run.** Nothing is healed, no money is halved, and the save goes back to the shelf marked over, listing what it met and what it lost. It cannot be continued.

**The battery indicator is real.** The cell in the top corner of the launcher was drawn full whatever your machine was doing. It now reads the machine on every platform that will answer: Windows, macOS, Linux, Android and iOS. It turns green while you are charging and amber when you are nearly out, and a machine that reports no charge at all, a desktop or a Switch, shows nothing rather than a full cell that is not true.

**For mod authors**, a run's progress read off a save now uses that save's own cartridge, so a Gold or Silver slot no longer reports the wrong badges, and a mod needs no cartridge cache of its own to ask.

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
