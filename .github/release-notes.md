<!-- Rewrite from the first release heading, `## Added`, `## Changed` or `## Fixed`, for each release. The text below
the release changes is standing guidance with a {VERSION} placeholder. -->

## Fixed

- Trainers who spot you or whom you talk to play their encounter music, in all six games.
- The Dragon Shrine elder walks away after the quiz; he used to slide. Other cutscenes where one character turns while another walks, such as the rival in Azalea Town and Lance in the Rocket base, are fixed too.
- Whirlpool keeps the whirlpool on screen until its sound has played, and you can't move until then.
- Flash plays its sound under its message and fades to white before the cave lights up.
- Rock Smash from the party menu shakes the screen and breaks the rock before any wild Pokémon appears.
- A rock smashed into a wild battle stays gone after the battle, until you leave the map.
- A Pokémon keeps the stats it had until something recalculates them: level-up, a Rare Candy, vitamins, evolution, the PC, the Day-Care, hatching or a trade.
- The PC box list closes gaps: a withdrawal or release moves the rest up, and a deposit goes to the end.
- Hatching an egg matches the cartridge: the wobble, the cracks and shell pieces, the cry in Gold and Silver, and the map music coming back after.
- Link trades reset the traded Pokémon's happiness to 70, and a traded egg no longer registers its species in the Pokédex.
- Time Capsule trades refuse held-item evolutions and convert the partner's items and happiness the way Gold, Silver and Crystal do.
- A benched Pokémon that forgets the move your active Pokémon has disabled frees it. A copied Mimic move is listed as MIMIC when you forget a move.
- Mart, PC, pack, save and Hall of Fame messages print letter by letter at your text speed, with the page clear and scroll, and holding A or B speeds them up.
- Bill's PC messages wait as long as on the cartridge, the Day-Care names your Pokémon, and CHANGE BOX shows the current box and a CANCEL row.
- A new game's first save no longer asks about overwriting a file.
- The Day-Care Man in Gold and Silver explains eggs on your first visit.

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
