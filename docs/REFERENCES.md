# External source references

The pret disassemblies are the authoritative reference for original game
behaviour. Ports and other recompilations are secondary: read them for approach,
settle behaviour against pret. All are comparison sources, never project
content. Never copy a ROM, extracted cartridge data or a whole external checkout
into the project history.

## Pinned repositories

The exact revisions used by the local workflow are recorded in
[`references.lock`](../references.lock); its `sources` line lists which
checkouts the fetch and status scripts manage.

| Game | Repository | Pinned revision | Useful areas |
| --- | --- | --- | --- |
| Red and Blue | [pret/pokered](https://github.com/pret/pokered) | `a1a22aaf84d1675bcdbaeb194592379d586d838e` | Generation 1 data, maps, scripts, battle behavior |
| Yellow | [pret/pokeyellow](https://github.com/pret/pokeyellow) | `e89ead154b9968aa50eed9328ff2b38b6c194382` | The same for Yellow, which moved most tables and retuned every palette |
| Crystal | [pret/pokecrystal](https://github.com/pret/pokecrystal) | `8e8f7e20052a596371a77022f0392c285e51bbf1` | Maps, scripts, events, data, battle behavior |
| Gold and Silver | [pret/pokegold](https://github.com/pret/pokegold) | `a0dad0957ac8a9ffa67e950ee3ab6715a212ded5` | Maps, scripts, events, data, battle behavior |
| Crystal, C port | [DanZC/suiCune](https://github.com/DanZC/suiCune) | `201d70028249b3297c441be195489e579bbf231a` | Secondary reference only: a C99 rewrite of pokecrystal, useful for how a routine reads once the GameBoy hardware assumptions are removed. Behavior is settled against pret, never against this port. |

The lock file is the source of truth. The branch name recorded there is the
upstream branch the revision was pinned from, never a substitute for the hash.

Each of these builds a ROM that is byte for byte the retail cartridge: the
hashes in a checkout's `roms.sha1` are the ones [`RomRegistry`](../game/rom/rom_registry.gd)
matches a dump against. A `.sym` file from such a build is where every offset in
`Gen1Layout` and `Gen2Layout` comes from, which is stronger evidence than
searching a dump for known bytes. Building one needs `rgbds` and writes into the
checkout, so build a copy outside `.references/` and leave the checkout clean.

## Local checkout workflow

Run from the project root:

```sh
bash tools/fetch_reference_sources.sh
bash tools/reference_status.sh
bash tools/reference_status.sh --remote
```

The fetch script clones a missing repository, fetches the locked revision and
checks it out detached. An existing checkout must have the expected origin and no
local edits; the script refuses to replace local work or move to another
revision. The status script reports each checkout as missing, dirty, at the wrong
revision or ready. `--remote` also reports when the recorded upstream branch has
moved past the pin.

The default checkout root is `.references/`, ignored by the project and safe to
remove and recreate. Set `GEN2_REFERENCE_ROOT`, or pass a first argument to
either script, to use another directory:

```sh
GEN2_REFERENCE_ROOT=/path/to/reference-cache bash tools/fetch_reference_sources.sh
bash tools/reference_status.sh /path/to/reference-cache
```

Updating a pin is deliberate: inspect the changes, update `references.lock`, and
record why.

## Source lookup guide

The two repositories use closely related paths. Check the matching path in
`pokegold` when behavior differs between Gold and Silver and Crystal.

| Behavior | Primary source paths |
| --- | --- |
| Map scripts and scenes | `maps/*.asm`, `data/maps/scenes.asm` |
| Script command widths and dispatch | `macros/scripts/events.asm`, `engine/overworld/scripting.asm` |
| Special event handlers | `data/events/special_pointers.asm`, `engine/events/specials.asm` |
| Party health and recovery | `engine/pokemon/health.asm`, `engine/events/whiteout.asm` |
| Save behavior | `ram/sram.asm`, `engine/menus/save.asm` |
| Map connections and warps | `data/maps/attributes.asm`, the matching map files and overworld warp code |
| Wild encounters | `data/wild/*.asm`, `data/wild/fish.asm` |
| Trainer parties and data | `data/trainers/parties.asm`, the matching trainer data files |

When a source fact changes runtime behaviour, record the file and symbol next to
the implementation, plus the pinned commit if the fact is revision-specific.
Source-derived data stays out of tracked files unless it is a small, verified
runtime table or test fixture the project requires.
