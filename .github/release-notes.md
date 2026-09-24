<!-- Rewrite from the exact `## Added` heading for each release. The text below
the release changes is standing guidance with a {VERSION} placeholder. -->

## Added

- Gold, Silver and Crystal open the full pack screen for SELL at the mart, DEPOSIT ITEM at the PC and PACK in battle, with its pockets, the sell dial, the money box and the USE/QUIT menu.
- The PC item list has CANCEL, a quantity dial and a toss question.
- The battle party list opens SWITCH, STATS and CANCEL, and STATS shows the stats screen in battle.
- Mods get API 43: one call draws a battle square and both status panels, one list holds everything the overworld draws, and the playthrough check can run with mods at their default settings.

## Changed

- Every YES/NO box works the same way: the answer stays on screen a moment before it is used, the cursor stops at the ends, and B means NO. A question longer than one box is read page by page before the choice appears.
- The pack reopens on the last pocket and row you used.
- A mod's item shuffle is refused when it hides a story item behind the gate it opens, such as OAK'S PARCEL or the SQUIRTBOTTLE.

## Fixed

- FLY takes you to the town you pick with A, and the TOWN MAP closes on A in Red, Blue and Yellow.
- A trainer's Pokemon comes out of its ball before it moves and cries. "sent out" and other long lines scroll up instead of starting a new box.
- The Team Rocket Hideout grunts walk up to you at the security cameras, and Lance leaves the Electrode room without walking through walls.
- A wild battle where both Pokemon faint, or where you say NO to "Use next" and run, no longer brings the party list back forever.
- The first Pokemon that can fight leads the battle; a fainted lead is no longer sent out.
- The Day-Care egg can be collected, and Mom starts saving money.
- Warps work on dark maps in Red, Blue and Yellow, such as Rock Tunnel without FLASH.
- Oak's aides give their item and say how many Pokemon they asked for and how many you have.
- The PC in Red, Blue and Yellow acts on the entry you picked, and BILL's PC opens on its own menu.
- The Goldenrod Pokemon Center in Crystal no longer gives the GS BALL, and the Battle Tower desk no longer reports a deleted record.
- Medicine in battle fills the HP bar and says what it did.
- B advances text, START closes the menu, GIVE and TAKE go back to the party list, Repel says it was used, and the radio plays its station.
- Nicknames, eggs, gender and status show correctly in the party, PC, trade and naming screens.
- Red, Blue and Yellow draw a Pokemon that used Minimize and the Substitute doll, and a Pokemon comes back on screen after Quick Attack, Low Kick, Submission and Counter.
- The Day-Care egg and the move tutor's refusal play the right sound.
- A mod's gift egg stays an egg, and a mod that changes the wild tables shows its new Pokemon on the map straight away.

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
