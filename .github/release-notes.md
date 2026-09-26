<!-- Rewrite from the first release heading, `## Added`, `## Changed` or `## Fixed`, for each release. The text below
the release changes is standing guidance with a {VERSION} placeholder. -->

## Changed

- Menus click when you press A or B, including every party list, the bag and the battle menus.
- Holding a direction keeps scrolling only in the menus that do so in the games.
- The bag list stops at its top and bottom.
- A scrolling list shows its down arrow only while CANCEL is off screen. The elevator, mailbox, Buena's prizes and long decoration lists end on CANCEL.
- On Gold, Silver and Crystal, SELECT reorders moves during a battle.
- The battle menu and move cursors return to the top when a new Pokémon is sent out, and the START menu cursor resets after a battle. The bag opens on its first pocket after a battle.
- A critical hit and the type matchup are separate messages, and a move that hits several times names the matchup once.
- Colosseum link battles on Gold, Silver and Crystal show the versus screen first, then the result and your link record.

## Fixed

- On Gold, Silver and Crystal, a trainer's switch or item use happens at its proper point in the turn, and Berserk Gene and flinching are handled before you choose a move.
- A move disabled or drained by Spite after you chose it fails with its own message and no longer turns into Struggle. An Encored move is used even while disabled.
- Poison, burn and other end-of-turn damage stop once the battle is decided, and experience is paid as each Pokémon faints.
- Toxic damage grows by the amount the games use, and Heal Bell no longer resets it.
- Wrap and similar moves no longer hurt a Pokémon behind a Substitute.
- A fainted Pokémon loses its status condition.
- Tri Attack causes a burn, freeze or paralysis only on its 20% chance.
- Gust and Twister double their damage only against Fly, Earthquake and Magnitude only against Dig, and Stomp only against Minimize.
- King's Rock can no longer make a missed move flinch. MiracleBerry cures confusion.
- Future Sight, one-hit KO moves against a higher level, Counter, Mirror Coat, Present, Bide, Mirror Move, Psych Up, Belly Drum and Swagger show the games' messages when they fail. A move that cannot affect the target's type says so even when it would have missed.
- Belly Drum at maximum Attack fails without costing HP. Swagger at maximum Attack misses and does not confuse.
- Out of Park Balls, a Bug-Catching Contest battle ends.
- Trainers' loss lines appear only in battles you are allowed to lose and at the Battle Tower.
- Wild victory music starts when the wild Pokémon faints.
- Opposing trainers choose their next Pokémon by type matchup, as the games do.
- Knocking out a switching Pokémon with Pursuit gives no experience.
- Baton Pass keeps Mean Look and Spider Web on the opponent. While trapped, choosing a Pokémon to switch to says so and keeps you on the party list.
- A transformed Pokémon gains experience and learns moves as its own species. Pokérus doubles stat experience.
- A Pokémon on the bench that gains several levels shows one message, and new moves come after all of them.
- The experience bar fills at the games' rate and is empty at level 100.
- Catching a Pokémon still pays Pay Day money and lets your Pokémon evolve.
- The Exp. Share message on Gold, Silver and Crystal no longer says EXP.ALL.
- The link record orders its trainers as the games do.
- On Gold and Silver, wild Hoothoot and Noctowl are asleep outside the night, and wild Pidgey and Spearow at night.
- The Dragon Shrine quiz ignores B.

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
