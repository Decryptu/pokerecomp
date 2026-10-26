# Saves

Project slots live under `user://save_slots`, keyed by game revision. They are
separate from disposable cartridge caches. Export/import project slots through
the save screen; imported files must match the selected ROM identity.

## Persistence

Ordinary gameplay updates the live run; SAVE persists it. Closing without saving
loses later changes. Nuzlocke deaths and claimed encounters persist immediately.
Party/storage transactions validate a candidate before committing; failed writes
restore live state. A full party routes catches/gifts to the current box; if both
are full the transaction refuses without consuming the item or ball.

Slots store persistent Pokémon, storage, world progress, clock, run rules and
per-mod state. Derived battle stats are rebuilt; volatile battle state is omitted.
The clock catches up across sessions. Older formats migrate in memory and write
the current format on the next save; missing historical data is not invented.

Each slot has primary JSON and `.bak` files with an additive-checksum header.
Writes update primary then backup; loads try primary then backup and do not
repair either while listing slots. Either file reserves the slot number. Legacy
headerless files remain readable. Export copies the file, header included.

The authoritative model, versions and validation live in
[save_data.gd](../game/save/save_data.gd),
[save_mon.gd](../game/save/save_mon.gd) and
[save_store.gd](../game/save/save_store.gd).

## Cartridge `.sav` compatibility

| Cartridge | Import/export scope |
|---|---|
| Red, Blue, Yellow | Player, party, twelve boxes, Day-Care, bag/PC items, currency, Pokédex, map/position, supported flags and progress, Hall of Fame; Yellow's Pikachu/minigame fields |
| Gold, Silver, Crystal | Player and party only; no world or PC-box transfer |

The save screen's Export .sav patches a chosen valid SRAM image into a new file:
supported fields change, other bytes stay, and no whole save is built from
project state. Mod-only species/items/moves are refused, never truncated to
cartridge bytes. Keep the original image if you write over it.

Generation 2 accepts 32 KiB plus optional trailing emulator RTC data, validates
markers/checksums and selects primary then backup. Export repairs and updates
both save copies. Crystal gender is outside those copies; only bit 0 changes.

Generation 1 has one main-data checksum and no backup. Before the first CHANGE
BOX, only the current box is initialized; the import honors that flag. Continue
faces down, matching the cartridge. Installation options, transient buffers and
fields the cartridge clears on entry are preserved in the base SRAM, not mapped
into project state.

Imports refuse invalid checksums, malformed/unterminated lists, unsupported
records and values the project cannot represent. Generation 1 duplicate item
stacks cannot be represented by the one-stack-per-item model. Export also refuses
unsupported world state instead of silently dropping it. The returned refusal
names the unsupported field.

For exact layouts, mapped fields and refusal rules, use
[sram_adapter.gd](../game/save/sram_adapter.gd),
[gen1_sram_adapter.gd](../game/save/gen1_sram_adapter.gd) and their adjacent
`sram_*` helpers. Original layouts are in the pinned sources' `ram/sram.asm`;
see [reference setup](REFERENCES.md).
