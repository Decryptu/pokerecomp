<!-- Rewrite from the first release heading, `## Added`, `## Changed` or `## Fixed`, for each release. The text below
the release changes is standing guidance with a {VERSION} placeholder. -->

## Added

- Mods: API 56 adds catch demonstrations. A custom NPC can ask for the game's own catching tutorial on any species and level: the Dude's fight in Gold, Silver and Crystal, the old man's in Red, Blue and Yellow. It always catches and keeps nothing. The NPC is told when it ends, and battle requests now report back the same way gifts do.

## Fixed

- Incoming phone calls ring with their sound and show the caller box at the top of the screen, with the phone icon and the caller's name. The box stays up for the whole call, and every call ends with the hang-up clicks before the text closes.
- BUENA's DISC JOCKEY line sits under her name in the Pokégear phone list instead of running off the screen.
- Dark caves are dark when you walk in. Dark Cave and other unlit caves used to stay lit until the game was reloaded inside them.
- Every menu box is as tall as its rows. The bedroom PC's TURN OFF row was hidden under the text box, and the decoration menus filled the screen.
- The decoration and mailbox screens stack over the PC menu the way the cartridge draws them. The decoration menu reopens on the category you left, and B goes back to the top menu.
- Scrolling lists print their last column in full: SURF PIKACHU DOLL, 12-letter apricorns and 10-letter mail authors are no longer cut.
- Buena's prize counter shows its Points box and the cost column, plays the purchase sound and reopens on the row you left. Four password rows named the wrong items.
- Kurt in Gold and Silver takes one apricorn from a list with no quantity dial.
- Quantity dials repeat a held direction. Refusals over the party list print in the full text box, so their second line is no longer off the screen.

## Updating this release

- Cartridge cache format is now 160. Import each cartridge file again when the launcher requests it. **Saved games are kept separately and remain intact.**
- Mod API version is now 56. Existing supported mods remain compatible; mods using catch demonstrations require this version.

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
