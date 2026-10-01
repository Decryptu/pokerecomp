<!-- Rewrite from the first release heading, `## Added`, `## Changed` or `## Fixed`, for each release. The text below
the release changes is standing guidance with a {VERSION} placeholder. -->

## Added

- Mods: API 55 adds Pokémon gift requests for custom NPCs and mods. Gifts use the normal party and current-box storage, and report whether delivery succeeds. Progress now exposes the originally received starter and retains completion of Red's credits.
- Mods can activate the GS Ball event in Gold and Silver through the same request used in Crystal. The optional chain runs through Goldenrod, Kurt's one-day examination and the Ilex Forest shrine's level-30 Celebi encounter. Its saved state prevents repeated grants; mods choose their own unlock requirements.

## Fixed

- Visible wild Pokémon stay within terrain reachable from the player, including after same-map warps and one-way crossings. Burned Tower's inaccessible outer floor no longer hosts them.
- Unown stays absent from visible encounters until a Ruins of Alph puzzle unlocks it.
- Battle weather, stat stages, types and identification annotations update with the displayed events. Rain Dance no longer reveals the weather before the move runs.
- AMNESIA and other ordinary letter pairs render correctly without becoming Pokémon symbols. Party, battle, PC and Pokédex labels keep their intended glyphs.
- Returning after Red's credits runs Mt. Silver's map callbacks and releases player input.
- Ordinary battles and world transactions preserve the last explicit save. Unsaved Pokédex flags, party changes, gifts, healing, items and PC transfers stay in the current run until SAVE. Nuzlocke changes remain durable.
- Oak's scripted escort updates the lab's map graphics immediately in Red, Blue and Yellow, and hides his Pallet Town object when the escort ends.
- Generation 1 overworld Pokémon icons render both halves correctly in both animation frames.

## Updating this release

- Cartridge cache format is now 159. Import each cartridge file again when the launcher requests it. **Saved games are kept separately and remain intact.**
- Mod API version is now 55. Existing supported mods remain compatible; mods using the new requests require this version.

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
