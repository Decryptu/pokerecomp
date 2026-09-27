<!-- Rewrite from the first release heading, `## Added`, `## Changed` or `## Fixed`, for each release. The text below
the release changes is standing guidance with a {VERSION} placeholder. -->

## Fixed

- The HP bar now goes down for Curse, Sandstorm, Leech Seed, Nightmare, Wrap and the other trapping moves, Spikes, Substitute, Pain Split, Belly Drum and Destiny Bond, and goes up for Leftovers and Berries. It used to keep the old number, so a Pokemon hurt by Curse could faint from a full bar.
- A confused Pokemon that hurts itself shows "It hurt itself in its confusion!" first, then the hit, then the HP loss. Poison and burn damage are in the same order as the cartridge.
- Sandstorm plays its animation on each Pokemon it hits. Trapping moves, Destiny Bond, a Jump Kick crash and held items play the animations they were missing, and a Jump Kick crash in Red, Blue and Yellow shakes the screen.
- Trainers' items play their sound.
- After beating Lance, the Hall of Fame room is drawn in place of a white screen, and the game restarts once the credits end. Continue then starts you in New Bark Town. Beating Red takes you back to Mt. Silver.
- Scenes that fade to white and then move you, such as Ecruteak Gym, the Fast Ship and the National Park gates, fade the new place back in.
- The restarts the game does on its own, after the Hall of Fame and in the Battle Tower, no longer add to the Resets count on the save screen.
- The item PC, mailbox, CHANGE BOX, decorations, elevator, Buena's prizes and Kurt's apricorns draw their lists one column to the left with the item count on the row under its name. The item PC keeps its list on screen under its questions and returns to WITHDRAW ITEM.
- Mart menus no longer wrap, Gold and Silver draw BUY/SELL/QUIT at its full width, and Gold, Silver and Crystal keep the buy list's cursor after a purchase. The PC's and the marts' sounds finish before the next message, and Red, Blue and Yellow's PC and vending machines play theirs.

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
