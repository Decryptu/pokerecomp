<!-- Rewrite from the first release heading, `## Added`, `## Changed` or `## Fixed`, for each release. The text below
the release changes is standing guidance with a {VERSION} placeholder. -->

## Added

- For mods, one set of calls answers whether a cell is land, water or wall, whether it is a doorway, and which ways a ledge drops, on all six cartridges. Mod API 49.

## Changed

- Talking to someone or reading a sign plays the click the games make.
- On Gold, Silver and Crystal, the phone list keeps the order you registered numbers in, and the random caller is picked from that order.
- A Pokémon given to you while your party is full goes to the front of the box and keeps the nickname you chose. The message names the species.

## Fixed

- On Gold, Silver and Crystal, incoming phone calls only rang while you stood on a door, stairs or a cave entrance. They now ring anywhere but those tiles.
- Items rearranged in the bag with SELECT went back to item order after loading a save.
- Walking through a door, onto a scripted spot or into a trainer's view no longer counts as a step for Repel, poison, eggs, friendship or the Day-Care. Crossing onto the next route now counts.
- A hatching egg, poison damage or a Repel running out ends that step, so no wild Pokémon appears behind it.
- Daily events, Pokérus and the lucky number count every day that passes, including a week away and days with the game closed.
- The Bug-Catching Contest lasts its full 20 minutes and ends even if you stand still.
- The Lucky Number Show at the Radio Tower opens again after you win a prize, and the radio announces the same number.
- Swarms on Gold and Silver end with the day.
- The Battle Tower hands over its reward, and only says the pack is full when the item pocket is.
- An Unown sent to the PC because your party is full now enters the Unown dex.
- Pokémon given by other trainers carry their original owner's ID, so they gain traded experience.
- Mystery Gift's daily limit lifts once a day has passed.
- Gold and Silver no longer show a trainer gender mark on a Pokémon's summary, which only Crystal has.

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
