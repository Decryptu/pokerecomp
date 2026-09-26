<!-- Rewrite from the first release heading, `## Added`, `## Changed` or `## Fixed`, for each release. The text below
the release changes is standing guidance with a {VERSION} placeholder. -->

## Fixed

- An X item still works at +6: it is used up, costs the turn and says the stat won't rise. X items now say which stat went up and make your Pokémon a little happier.
- Ethers and Elixers can be used on a fainted Pokémon, and restore a transformed Pokémon's own moves. In battle their move list takes only up and down, and B goes back to the party list.
- Bitter Berry no longer asks which Pokémon to use it on.
- A Full Heal or Full Restore on a confused Pokémon with no status says it came to its senses.
- Heal Powder, Energypowder, Energy Root and Revival Herb say "It looks bitter…", and lower happiness in battle too.
- Using the Poké Doll in a trainer battle gets Professor Oak's warning.
- A Revive used on a Pokémon that never fought the current opponent no longer gives it a share of the experience.
- Choosing an Egg for an item says it can't be used on an Egg.
- A registered item that can't be used gets Professor Oak's warning.
- A Ditto that used Transform is caught as a Ditto.
- A Pokémon caught into your party keeps the PP it used in battle.
- "Gotcha!" plays the caught jingle and the capture music, and the new Pokédex entry plays its sound.
- A Pokémon caught in the Bug-Catching Contest is added to the Pokédex straight away.
- A Rare Candy used where the Pokémon was caught raises happiness more, in Crystal.
- A move learned from a Rare Candy, an evolution stone or an evolution after a battle shows "learned" and offers to forget a move when all four slots are full.
- The party menu reopens on the Pokémon you last picked.
- Softboiled and Milk Drink animate both HP bars and say how much HP was recovered.
- Refused field moves, TAKE, mail and Softboiled messages appear over the party menu, which then comes back on the same Pokémon.
- Backing out of GIVE, TAKE or the mail menu returns to the party list.
- Giving an item that can't be held goes back to the bag. Mail is written after the Pokémon takes it.
- The MOVE screen no longer wraps from the last move to the first.
- In Gold and Silver, the MOVE screen says ATTK and the mail menu opens further left.
- In a Cable Club room, the START menu hides PACK and SAVE, and the party menu hides field moves and ITEM.
- The music is quieter while a stats screen or a Pokédex entry is open.

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
