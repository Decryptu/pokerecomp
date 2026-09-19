<!-- The top section is rewritten for each release; everything below it is the
standing text and only takes {VERSION}. One line per paragraph, per bullet and
per table row: GitHub reflows a release body to the reader's window, and a line
break put in by hand only makes it ragged.

It is a changelog, not an essay. `## Added`, `## Changed`, `## Fixed`, one
bullet per change, and no opening sentence summarising the release: a reader
scanning for their own bug does not want a paragraph about the shape of the
work. No `**Bold label.**` in front of a bullet, no contrast frame on every
line ("X rather than Y", "not X, Y"), and no em-dash. Vary the sentence length:
a body of uniform 15 to 25 word sentences reads as machine-written, and one
here was called that and deserved it. Rewrite from the line that is exactly
`## Added`: an edit that searches for the first one in the file lands inside
this note and takes its closing marker with it, which is how 0.1.17 published
an empty body. -->

## Added

- Battles on Red, Blue and Yellow run on the cartridge's own turn rules: stored stats with the badge boosts and status penalties compounding the way they do there, poison and Leech Seed at a sixteenth, sleep for 1 to 7 turns with the waking turn lost, Rest, Disable, Thrash, Counter, Rage, Bide, Substitute, Mimic, Fissure, Swift, Metronome, Struggle and the multi-hit moves each doing what the cartridge does.
- MIMIC puts the opponent's move list up and you pick the copy, as the cartridge does; the enemy rolls.
- Mods reach the gameplay catalog on Red, Blue and Yellow: starters, gifts, statics, trades, prizes, items, badges and shops can be listed and patched (`api_version` 37), a mod can validate its placement against Kanto's map graph, and the Old and Good Rod are fishing groups like any other.
- A Kanto badge notice icon draws from the trainer card's own sheet on Red, Blue and Yellow (`api_version` 36).

## Changed

- The cache format is 146. Import your cartridges again.
- Bide prints nothing while it stores on Red, Blue and Yellow, adds and doubles the way the cartridge's byte arithmetic does, and a hit on a Substitute counts toward it.
- Rage builds once per hit of a multi-hit move, on a missed Explosion and on Disable, and never on a stat move, a status move or Transform, as `HandleBuildingRage` sits on the cartridge.
- Transform on Red, Blue and Yellow copies a Pokemon in the air, underground or already transformed, keeps a Disable running over the new moves, and a Substitute in front of the target does not stop it.
- A confused Pokemon hitting itself, or crashing after a missed Jump Kick, behind its own Substitute spends the opponent's Substitute instead, and a Jump Kick crash costs one point, which is what the cartridge does.
- "It hurt itself in its confusion!" and "kept going and crashed!" print before the health bar moves.

## Fixed

- Transform gave an empty move slot five PP on every cartridge; it gives none.
- Full paralysis landed 64 times in 256; the cartridge's check is 63.
- A mod that registered by generation at boot kept those registrations after Play selected a cartridge of another generation.

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
