# Save data

Project saves are separate from cartridge-derived `GameData` and the scene-free
battle engine. Slots live in Godot's `user://`, never in the repository.

## Canonical project model

Save format version 6 stores:

- game ID and ROM SHA-1, preventing use with another cache;
- player name, party order and each Pokémon's species, held item, level,
  experience, current HP, status, DVs, five Gen II stat-experience values,
  moves and PP;
- fourteen PC boxes with twenty ordered slots each. Boxed Pokémon use the same
  persistent model as party Pokémon. Gifts and catches fill the party first,
  then go to the front of the box and move the rest back, as `SendMonIntoBox`
  does; an egg never reaches a box;
- an optional validated world snapshot: map ID, player cell, facing, movement
  mode, event flags, map scenes, inventory quantities, money, coins, phone
  contacts, seen species, repel steps, swarm state, roaming positions, source
  engine flags, the script memory bytes `readmem`/`loadmem` address, the
  day/hour/minute clock with `wCurDay`'s own day count, the host second that
  clock was written at and the daylight-saving flag. The stamp makes the clock real-time across sessions: a
  world opens at the saved time plus the seconds that have passed since, because
  the cartridge's RTC keeps running while the machine is off
  (`Gen2WorldClock.catch_up`);
- imported-save and party-transaction identity fields: OT ID, nickname, OT,
  happiness, Pokerus and caught data, and a Generation 1 member's
  `MON_CATCH_RATE` byte, which the Time Capsule reads as a held item;
- the trainer card's own fields: `player_id`, the player's `gender` and the play
  timer;
- a per-slot, per-mod JSON namespace, and the `run` block naming what produced
  the state: the world's seed, the mods that were loaded when it was last
  written, and the registered mod settings the run is played with
  (`run_options`), so a slot cannot silently change draw distance when it is
  reopened, and the gameplay rules it is played under (`run_rules`: which of the
  cartridge's own bugs are reproduced, and which challenge the run was created
  under). A Nuzlocke run also carries a `nuzlocke` block: the areas that have
  given up their one encounter, what it has lost for good, and whether it is
  over. A slot whose run has ended is never opened again;
- `is_egg` for received eggs. An egg keeps its party slot and is skipped when
  the battle party is built, the way the cartridge refuses it as a combatant
  rather than removing it. Its `happiness` byte is its hatch counter, written by
  `GiveEgg` and drained by `DoEggStep`: one cycle off every egg in the party
  every 256 steps, and the first to reach zero hatches where it stands.

Derived battle stats are recalculated on load. Volatile state is never saved:
stages, confusion, recharge, Disable, Encore, trapping, Fly, Dig, Rollout,
rampage, weather and screens. A held item is not volatile, so a berry eaten in a
battle is gone from the party afterwards.

Slots live under `user://save_slots` per game revision, created on demand up to
`Gen2SaveStore.MAX_SLOTS`. A slot number is its file name. Each save carries a
`label`, the player's name for the slot, so an exported file names itself; an
empty label falls back to the player name.

| Field | Source |
|---|---|
| `player_id` | `wPlayerID`, rolled once when a game starts, read from SRAM on import and written back on export. `GetTreeScore` reads it: half of a headbutt tree's encounter tier comes from the trainer ID |
| `gender` | Crystal's `wPlayerGender`. Always male on Gold and Silver, which ship neither the byte nor Kris |
| `current_box` | `wCurBox`, written by CHANGE BOX's SWITCH and read by both of BILL'S PC's lists |
| `box_names` | `sBoxNames`, written by its NAME row. An empty name means `SetDefaultBoxNames`' own "BOX1" spelling rather than a stored string |
| `hall_of_fame` | `sHallOfFame`, the thirty induction records newest first |
| `save_file_exists` | `wSaveFileExists`: false from New Game until the first in-game save, which therefore asks no overwrite question; true for older and imported slots |

Generation 2 SRAM box placement is outside this model; Generation 1's boxes are
mapped (see "Generation 1 cartridge SRAM").

Older project saves migrate in memory one version step at a time up to 6, and
the next successful save writes 6. Migration invents nothing: a missing world
snapshot stays missing, and no trainer ID is rolled, since that would change an
existing save's headbutt encounters. Fields added inside version 6 default
rather than versioning, and a slot written before the run block adopts the
installation's rules once, on first activation.

## Player flow

The launcher selects an imported cache and opens `game/save/save_screen.tscn`.
It lists the slots that exist as `READY` or `INCOMPATIBLE`, offers a new one at
the lowest free number, and rejects failed `.sav` imports before calling
`Gen2SaveStore.save`, so partial data cannot replace a slot. A game with no
saves lists none and has nothing selected.

New games accept up to ten encoded characters and start with an empty party.
When the source home map exists they start at map group 24, map 7, cell 3,3 with
3000 money, from Crystal's `SPAWN_HOME` and `START_MONEY`. The imported Elm's Lab
scripts offer Chikorita, Cyndaquil or Totodile at level 5 holding Berry; the
party host creates the first save Pokemon only after the player confirms.

After battle messages finish, `Gen2SaveBattleAdapter` writes player name,
Pokémon identity, held item, happiness, Pokerus, caught data, nickname, OT, HP,
status, experience, DVs, stat experience, moves and PP. Volatile state is
discarded. Party rows the battle never held, eggs and a Pokémon caught during
the fight, keep their slots.

Overworld writeback is transactional. Battles, gifts, healing, item use and PC
transfers validate and update the live run after their result messages. Ordinary
gameplay leaves the last explicit save intact, including its Pokédex flags;
quitting without SAVE discards those changes. Nuzlocke transactions persist
immediately so deaths and claimed encounters survive reopening. A loss validates
and reconstructs the source save party before returning blackout recovery. Continue
enters the overworld only with a validated snapshot. The start menu's SAVE writes
map, player, items, currency, events, source engine flags and schedule state
through `Gen2SaveStore`, with item and currency references checked against the
selected cache. Daily engine flags reset when the day count moves, however many
days that is; story flags such as Hall of Fame persist. The file keeps every
map in insertion order, which is the order of the bag's pockets and the phone
list. `Gen2WorldAPI.open_snapshot()` restores a
saved position without clamping it.

`box_screen.tscn`, opened from the party screen or from the Players House PC as
an embedded overworld overlay, presents one numbered box at a time with twenty
fixed slots and a party selection column. Depositing uses the current box's first
free slot, withdrawal requires party capacity, and both go through
`Gen2SaveStorage` to validate a candidate save before the shared
runtime object changes. The last party member cannot be boxed.

MOVE PKMN W/O MAIL is the same screen in `Gen2BoxScreen.MODE_MOVE`, where left
and right load the party or any box and a chosen Pokemon is inserted at a second
cursor. Closing the overlay resumes the paused source script, which is where a
changed decoration reloads the room. Embedded gameplay transfers stay in memory
until SAVE, except in Nuzlocke. Standalone storage editing writes the slot.

Party-owned overworld transactions modify a candidate `Gen2SaveData` and the
live world snapshot first. Gifts, eggs, NPC trades, source `HealParty` recovery,
item effects and catches commit only after validation and optional persistence,
and a failed write restores live world state. A full party routes a valid
addition to the front of the current box; with the party and that box full the
transaction refuses before consuming an item or ball, leaving save and world
state unchanged.

## Slot durability

A slot is two files. `Gen2SaveStore.save()` writes `slot_N.json` complete, then
copies it to `slot_N.json.bak`, following the cartridge's primary-then-backup
order in `_SaveGameData`. Each file begins with a header line carrying a 16-bit
additive checksum over its JSON payload, the algorithm `Checksum` uses in
`engine/menus/save.asm`, so a truncated or altered copy is refused rather than
loaded. Neither write depends on rename atomicity, which Godot does not provide
on Windows.

A load takes the primary and falls back to the backup on any failure: a missing
file, a bad header or checksum, invalid JSON, a failed migration or a validator
rejection. When both fail, the primary's message is reported. A slot counts as
occupied while either copy exists, so a lost primary cannot present itself as an
empty slot that a new game would overwrite. Unlike `TryLoadSaveFile`, a load
never repairs the weak copy, because drawing the slot menu loads every slot;
the next save rewrites both. Slots written before the header existed load
unchecked, which is also how an exported file with no header is accepted.

Export copies a slot file verbatim, header included. Import reads one back,
refuses a save recorded against another cartridge, and lands it in the lowest
free slot with that number written into the copy.

## Original Generation 2 shape

The model follows stable Crystal source fields. `box_struct` contains species,
item, four moves, OT ID, three-byte experience, five stat-experience words, DVs,
PP, happiness, Pokerus, caught data and level. `party_struct` adds status,
current/max HP and five derived stats.

Mail is on the record rather than in a slot of its own: `Gen2SaveMon.mail` is
`sPartyMail`'s entry for that member and `Gen2SaveData.mailbox` is `sMailboxes`
behind `sMailboxCount`. Both default rather than versioning, so a slot written
before mail existed reads as a party holding none and an empty mailbox.

`SECTION "SRAM Battle Tower"` rides in the world snapshot rather than the save
proper, which is where the cartridge keeps it too, since a challenge can be saved
and left between battles. `Gen2WorldState.battle_tower()` carries the state, the
streak of trainers already met, the chosen room, the save-file flags and the
prize drawn for the run. It also holds `sGSBallFlag`, which sits in the same bank
and which only a mod's `request_gs_ball()` writes. Gold/Silver's optional GS Ball
quest and the originally received starter are stored in world state.

Original Generation 2 SRAM also contains player, map, checksum, PC box, Hall of
Fame and Crystal-specific regions. The Generation 2 adapter imports only party
data; the world snapshot is a separate runtime shape and does not claim to
reproduce unsupported SRAM bytes.

## Cartridge SRAM boundary

For Gold, Silver and Crystal, `Gen2SramAdapter` accepts a raw `PackedByteArray`,
supported ROM identity and complete 32 KiB SRAM image, with trailing emulator RTC
data allowed. Import
selects the primary copy, then backup, and rejects both if their 99/127 markers
or checksums fail. Gold/Silver use split backup regions; Crystal uses contiguous
ranges. A valid backup repairs the primary before patching, and both copies are
rewritten with little-endian 16-bit checksums.

It maps player name and six-party fields: species, item, moves, OT ID,
experience, stat experience, DVs, PP, happiness, Pokerus, caught data, level,
status, current HP, nickname and OT. Derived stats are rebuilt from the selected
`GameData`; other bytes remain untouched. Export requires an existing valid SRAM
image and invents no map or event state. It refuses a save carrying mod content:
every species, item and move on the hardware is one byte and
`Gen2ContentOverlay.FIRST_MOD_NUMBER` sits past that, so truncating one would
write a different Pokemon into a real cartridge. Crystal's player gender rides in
`sCrystalData`, outside both save copies; only bit 0 is written.

| Profile | Primary data | Checksum | Party | Backup |
|---|---|---|---|---|
| Gold/Silver | `0x2009..0x2D68` | `0x2D69` | `0x288A` | `0x0C6B`, `0x10E8`, `0x15C7`, `0x3D96`, `0x7E39` |
| Crystal | `0x2009..0x2B82` | `0x2D0D` | `0x2865` | `0x1209..0x1D82`, checksum `0x1F0D` |

## Generation 1 cartridge SRAM

`Gen2SramAdapter` hands Red, Blue and Yellow to `Gen1SramAdapter`, which carries
the whole game rather than the party alone: the port models the Generation 1
trainer, so a field the file cannot hold or the model cannot represent is
refused rather than dropped. The three games place every section identically
(`ram/sram.asm`), and `wMainData` differs only in the Pikachu fields Yellow keeps
in padding.

| Section | File offset |
|---|---|
| `sGameData`: name, main data, sprite data, party, current box | `0x2598..0x3522`, checksum `0x3523` |
| Party, `sCurBoxData` | `0x2F2C`, `0x30C0` |
| `sBox1`..`sBox6`, `sBox7`..`sBox12`, each `0x462` bytes, then a sum over all six and one each | `0x4000`, `0x6000` |
| `sHallOfFame`, fifty teams of six `0x10`-byte records | `0x0598` |

A file is valid when `CalcCheckSum` over `sGameData` matches `sMainDataCheckSum`;
there is no second copy. The sums over the box banks are written on export and
never read, as on the cartridge. Until the first CHANGE BOX the box banks hold
uninitialised bytes, so `BIT_HAS_CHANGED_BOXES` of `wCurrentBoxNum` decides
whether anything but the current box is read.

Import carries:

| Cartridge | Model |
|---|---|
| `sPlayerName`, `wPlayerID`, `wPlayTime*` | name, `player_id`, `game_time` |
| `wPartyMons`, `sCurBoxData` and the twelve box rows, `wDayCareMon` | `party`, `boxes` (the current box is `sCurBoxData`; its own row is stale), `current_box`, the Day-Care slot. A Pokemon keeps species, level, experience, HP, status, DVs, stat experience, moves, PP and PP Ups, OT ID and name, nickname and catch rate byte |
| `wBagItems`, `wBoxItems`, money, coins | bag and item PC stacks in order, `money`, `coins` |
| `wPokedexOwned`, `wPokedexSeen` | caught and seen species |
| `wObtainedBadges`, `wBeatGymFlags`, `wStatusFlags1`, `wStatusFlags4`, `wElite4Flags`, hidden item and coin flags, `wTownVisitedFlag`, Pikachu map script flags | the engine flags `Gen1Layout.ENGINE_FLAG_BYTES` numbers, the badge flags and the always-on-bike bit |
| `wEventFlags`, `wCompletedInGameTradeFlags`, `wToggleableObjectFlags`, `wGameProgressFlags` | event flags, finished trades, the objects a `ShowObject` or `HideObject` has moved, map script states |
| `wCurMap`, `wYCoord`, `wXCoord`, `wLastMap`, `wLastBlackoutMap`, `wMapPalOffset`, `wWalkBikeSurfState` | the world snapshot's map, cell, last maps, palette offset and movement mode |
| `wRivalName`, `wRivalStarter`, `wPlayerStarter`, `wFossilItem` and `wFossilMon`, `wNumSafariBalls` and `wSafariSteps`, `wCardKeyDoorY` and `X`, the Vermilion trash can bytes | the same values on the snapshot and its state |
| `wNumHoFTeams`, `sHallOfFame` | `hall_of_fame` and the Hall of Fame engine flag |
| Yellow's `wPikachuHappiness`, `wPikachuMood`, `wPikachuEmotionModifier`, two state bits and `wPikachuSpawnState`, `wSurfingMinigameHiScore` | the Pikachu record and the minigame score |

What it does not carry, and why:

- `wOptions`: the options are installation-wide, and the file's byte is left as it
  is on export.
- The facing: `SpecialEnterMap` resets the player sprite, so every Continue stands
  the player facing down.
- Status flags the cartridge clears or the port derives (`wStatusFlags2`, `3`, `5`,
  `7`, the rest of `6`), `wMovementFlags`, the map header copied into
  `wMainData`, `wWarpedFromWhichWarp`, the sprite buffers, the sprite data and
  `sTileAnimations`. Export leaves every one of these bytes as it found them.
- A Hall of Fame record's OT ID and DVs, which `HoFRecordMonInfo` never stored.
- The 152nd Pokedex bit, and a Pokemon caught but not seen, which the model reads
  as seen.

Import refuses a file whose checksum fails, a Pokemon, Day-Care slot or Hall of
Fame member whose species has no Pokedex entry, a bag or PC with an item in two
stacks (the model keeps one stack per item) or a stack of zero or over 99, money
or coins that are not packed decimal, a list with no end marker, a current box
past the twelfth, a map the cache does not hold, and anything
`Gen2SaveValidator` rejects.

Export patches an existing valid image, because OPTION, the Hall of Fame teams
the model dropped and the unmapped flag bytes cannot be invented. Bytes the
model decodes to the same value are not rewritten, so an untouched import exports
byte for byte. A party, box or Hall of Fame that changed is rewritten whole. A
moved player gets `wCurMap`, the cell, the block coordinates and
`wCurrentTileBlockMapViewPointer`, which is `wOverworldMap` + (block row + 1) *
(width in blocks + 6) + block column + 1, as measured in Red's bedroom. The
first occupied box other than the current one sets `BIT_HAS_CHANGED_BOXES` and
writes all twelve rows the way `EmptyAllSRAMBoxes` and `CopyBoxToOrFromSRAM`
would, with their sums. Export refuses mod content, an engine flag, event flag
(past 2559), trade, map script byte, toggleable object or script byte with no
byte in the file, a Pokedex entry past 151, more than twenty bag stacks or fifty
PC ones, a stack over 99, a Pokemon in a thirteenth box, a species with no
cartridge index, and more than fifty Hall of Fame teams.

The save screen's `Import .sav` calls the import; nothing in the player flow calls
the export yet.

Verification: `tests/unit/test_gen1_sram.gd` holds the layout, the round trip and
the refusals on a synthetic cache. `tools/checks/gen1_sram.gd` runs the same
boundary on saves the real cartridges wrote under PyBoy, through a local script
named by `GEN1_SAV_ORACLE`, and has the game load an edited export.

Implementation and synthetic fixtures:

- `game/save/sram_adapter.gd`, `tests/unit/test_save.gd`
- `game/save/gen1_sram_adapter.gd`, `gen1_sram_world.gd`, `gen1_sram_mons.gd`,
  `gen1_sram_context.gd`, `tests/unit/test_gen1_sram.gd`

Layout references: [Red/Blue SRAM layout](https://raw.githubusercontent.com/pret/pokered/master/ram/sram.asm), [Red/Blue save routines](https://raw.githubusercontent.com/pret/pokered/master/engine/menus/save.asm), [Gold/Silver SRAM layout](https://raw.githubusercontent.com/pret/pokegold/master/ram/sram.asm), [Gold/Silver save routines](https://raw.githubusercontent.com/pret/pokegold/master/engine/menus/save.asm), [Crystal SRAM layout](https://raw.githubusercontent.com/pret/pokecrystal/master/ram/sram.asm), [Crystal save routines](https://raw.githubusercontent.com/pret/pokecrystal/master/engine/menus/save.asm), [Crystal Pokémon constants](https://raw.githubusercontent.com/pret/pokecrystal/master/constants/pokemon_data_constants.asm), [Crystal bank map](https://github.com/pret/pokecrystal/blob/master/layout.link), [Crystal RAM macros](https://github.com/pret/pokecrystal/blob/master/macros/ram.asm).
