class_name Gen2Layout
extends RefCounted

## Where the data lives inside each supported cartridge. Offsets are absolute
## positions in the 2 MiB dump rather than bank:address pairs, so a decoder never
## thinks about banking; Gold and Silver share the bank map and Crystal is its own
## table. Every offset was located in the cartridges themselves, by searching for
## independently known bytes, then cross-checked against pret for structure. A
## table is a claim about a specific dump, so an uncharacterised ROM is refused
## rather than guessed at, and a comment here records how an offset was FOUND:
## that is evidence rather than restatement, so tighten it and never delete it.

const SPECIES_COUNT: int = 251
## `GetMonFramesPointer`'s `cp JOHTO_POKEMON`: the frame data below this species
## is in `KantoFrames`' bank and from it in `JohtoFrames`'.
const JOHTO_SPECIES: int = 152
const NAME_LENGTH: int = 10
const BASE_STATS_SIZE: int = 32
const PIC_POINTER_SIZE: int = 3

## Map records are fixed-size entries in a 26-group table. Map dimensions are
## measured in 4x4-tile blocks, while event coordinates are measured in the
## resulting 2x2-cell walk grid.
const MAP_GROUP_COUNT: int = 26
const MAP_GROUP_POINTER_SIZE: int = 2
const MAP_RECORD_SIZE: int = 9
const MAP_ATTRIBUTES_SIZE: int = 12
const MAP_CONNECTION_RECORD_SIZE: int = 12
const MAP_CONNECTION_FLAG_EAST: int = 1
const MAP_CONNECTION_FLAG_WEST: int = 2
const MAP_CONNECTION_FLAG_SOUTH: int = 4
const MAP_CONNECTION_FLAG_NORTH: int = 8
const MAP_BLOCK_TILE_WIDTH: int = 4
const MAP_BLOCK_CELL_WIDTH: int = 2
const MAP_MAX_BLOCKS: int = 128
const MAP_MAX_WIDTH_BLOCKS: int = 40
const MAP_MAX_HEIGHT_BLOCKS: int = 54
const MAP_EVENT_HEADER_SIZE: int = 2
const MAP_WARP_EVENT_SIZE: int = 5
const MAP_COORD_EVENT_SIZE: int = 8
const MAP_BG_EVENT_SIZE: int = 5
const MAP_OBJECT_EVENT_SIZE: int = 13
const MAP_SCENE_SCRIPT_SIZE: int = 4
const MAP_CALLBACK_SIZE: int = 3
const MAP_MAX_SCENE_SCRIPTS: int = 32
const MAP_MAX_CALLBACKS: int = 16

## Normal and swarm wild encounter records are fixed-size tables keyed by map
## group and number. Grass carries three time-of-day rates and seven slots per
## time; water carries one rate and three slots. Fishing and roaming use their
## own source tables below.
const WILD_GRASS_RECORD_SIZE: int = 47
const WILD_WATER_RECORD_SIZE: int = 9
const WILD_GRASS_SLOT_COUNT: int = 7
const WILD_WATER_SLOT_COUNT: int = 3
const WILD_TIME_COUNT: int = 3
const WILD_TABLE_END: int = 0xFF
const WILD_GRASS_PROBABILITIES: Array[int] = [30, 60, 80, 90, 95, 99, 100]
const WILD_WATER_PROBABILITIES: Array[int] = [60, 90, 100]

## Fishing groups contain a chance byte and three CPU pointers. Each pointed
## rod table is a threshold/species/level stream whose final threshold is $FF.
## A species byte of zero means that the level byte indexes TimeFishGroups
## instead.
const FISH_GROUP_COUNT: int = 13
const FISH_GROUP_RECORD_SIZE: int = 7
const FISH_ROD_COUNT: int = 3
const FISH_TABLE_END: int = 0xFF
const FISH_TIME_GROUP_COUNT: int = 22
const FISH_TIME_GROUP_SIZE: int = 4
const FISH_MAX_ENTRIES: int = 8

## RoamMaps stores a start map, a count, that many target map pairs and a zero
## terminator. The complete table has sixteen source rows in all supported
## profiles.
const ROAM_MAP_COUNT: int = 16
const ROAM_TABLE_END: int = 0xFF

## TreeMonMaps and RockMonMaps are `(group, number, set)` triples ending in $FF.
## TreeMons is a pointer table into the same bank; each set is one or two
## `db %, species, level` tables, each ending in $FF. Sizes are never assumed:
## TreeMonSet_Rock ships a common table and no rare one, and pokegold's shared
## None/Unused/City set is five rows where every other set is six.
const TREEMON_MAP_RECORD_SIZE: int = 3
const TREEMON_TABLE_END: int = 0xFF
const TREEMON_MAX_ROWS: int = 16
const ASLEEP_TREEMON_TABLE_END: int = 0xFF
const ASLEEP_TREEMON_MAX_ROWS: int = 16

## The cartridge compares an 8-bit random value directly with these encoded
## percentage thresholds when it varies a surfing encounter's level. The
## values are the source's integer `$FF / 100 * percent` expressions.
const WILD_SURF_LEVEL_THRESHOLDS: Array[int] = [89, 165, 216, 242]

## Two blocks of 96 tiles: `LoadTilesetGFX` copies the first to vTiles2 in VRAM
## bank 0 and the second to vTiles5 in bank 1 at the same tile numbers, and a
## metatile byte with bit 7 set names the second. So the span is 224: block 0 at
## 0..95, `_LoadFontsExtra1`'s 32 font tiles at 96..127, block 1 at 128..223, and
## the strip carries all 224 with the font gap blank. Eight tilesets compress one
## block only and no block of theirs names the second, so the import blanks it;
## tables are shorter under 128 blocks and unused entries may hold $FF, which is
## why a tile past the span resolves to 0.
const TILESET_RECORD_SIZE: int = 15
const TILESET_TILE_COUNT: int = 224
const TILESET_BLOCK_TILES: int = 96
const TILESET_BLOCK_STRIDE: int = 128
const TILESET_META_BYTES_PER_BLOCK: int = 16
const TILESET_COLLISION_BYTES_PER_BLOCK: int = 4

## Overworld object graphics are six-byte records: CPU address, byte length,
## ROM bank, sprite type and default palette. The graphics are uncompressed
## 2bpp tiles. Palette records are four 15-bit colours, grouped by time of day
## and then by the eight overworld palette kinds.
const OVERWORLD_SPRITE_RECORD_SIZE: int = 6
const OVERWORLD_SPRITE_PALETTE_GROUP_COUNT: int = 32
const OVERWORLD_SPRITE_PALETTE_GROUP_BYTES: int = 8
const OVERWORLD_SPRITE_PALETTE_BYTES: int = OVERWORLD_SPRITE_PALETTE_GROUP_COUNT * OVERWORLD_SPRITE_PALETTE_GROUP_BYTES
const OVERWORLD_SPRITE_TYPES: Array = [1, 2, 3]
const OVERWORLD_SPRITE_PALETTE_COUNT: int = 8
## data/sprites/emotes.asm's `emote` macro: CPU address, byte length, ROM bank,
## and the VRAM address the sheet is loaded to. Twelve entries, in
## constants/script_constants.asm's EMOTE_* order, and the last four are the
## engine's own overlays rather than showemote arguments: a jump shadow, the
## fishing rod, Strength's boulder dust and the tall-grass rustle.
const EMOTE_RECORD_SIZE: int = 6
const EMOTE_COUNT: int = 12
## The `vTiles0 tile n` an emote record's last field holds. A sprite tile counts
## from here, so the tile number is the distance in tiles from it.
const VTILES0: int = 0x8000
const EMOTE_NAMES: Array[String] = [
	"shock", "question", "happy", "sad", "heart", "bolt", "sleep", "fish",
	"shadow", "rod", "boulder_dust", "grass_rustle",
]

## IconPointers has one null entry followed by the 38 reusable overworld icon
## shapes in constants/icon_constants.asm. The null entry is not graphic data:
## `NullIcon` and `PoliwagIcon` are the same address, which is what makes the
## table NUM_ICONS + 1 entries long and its first two entries equal.
const MON_ICON_COUNT: int = 38
const MON_ICON_TILES: int = 8
const MON_ICON_BYTES: int = MON_ICON_TILES * PokeTiles.TILE_BYTES
const ICON_POINTER_COUNT: int = MON_ICON_COUNT + 1
const ICON_POINTER_SIZE: int = 2

## `constants/icon_constants.asm`'s `ICON_EGG`, which `ReadMonMenuIcon` answers
## for species EGG rather than reading `MonMenuIcons`. It is the one icon no
## species row names.
const ICON_EGG: int = 28

## `HeldItemIcons` is `gfx/stats/mail.2bpp` and `gfx/stats/item.2bpp`, the two
## tiles `GetIconGFX` loads behind every icon's eight. `ItemIsMail` is
## [method Gen2HeldItem.is_mail], and `.SpawnItemIcon` is what picks between
## the two: `SPRITE_ANIM_FRAMESET_PARTY_MON_WITH_MAIL` for a held mail and
## `..._WITH_ITEM` for anything else.
const HELD_ITEM_ICON_TILES: int = 2
const HELD_ITEM_ICON_MAIL: int = 0
const HELD_ITEM_ICON_ITEM: int = 1

## `InitPartyMenuOBPals` copies two of the eight palettes at `PartyMenuOBPals`
## into wOBPals1. Every party icon's OAM set is PAL_OW_RED, so the first is the
## one an icon wears; the second is the run's only different row.
const PARTY_MENU_OB_PALETTE_COUNT: int = 2
const PARTY_MENU_OB_PALETTE_BYTES: int = 8

## Global overworld service tables. The source keeps these apart from map data:
## marts are an index table of item lists, phone contacts are fixed records,
## and audio is two far-pointer tables into the banked audio programs.
const MART_COUNT: int = 34
const MART_POINTER_SIZE: int = 2
const MART_RECORD_MAX_ITEMS: int = 16
const MART_TERMINATOR: int = 0xFF
## `NUM_FRUIT_TREES` (`constants/script_constants.asm`). `FruitTreeItems` is one
## item byte per tree, indexed by the `fruittree` command's operand less one, and
## both pins ship the same thirty rows.
const FRUIT_TREE_COUNT: int = 30
## The seven apricorn items, ascending, and where their run starts in the table.
## Rows 17 to 23 are `FRUITTREE_ROUTE_37_1` through `FRUITTREE_ROUTE_42_3`, and
## no other row bears one; both pins agree. Used to identify the table by
## content, since it has no header and no terminator.
const FRUIT_TREE_APRICORNS: Array[int] = [0x55, 0x59, 0x5C, 0x5D, 0x61, 0x63, 0x65]
const FRUIT_TREE_FIRST_APRICORN: int = 16

## `SpawnPoints` (`data/maps/spawn_points.asm`): `db group, number, x, y` per
## `SPAWN_*` constant, then one row of `$FF` bytes. `NUM_SPAWNS` is 28 and both
## pins ship the same rows, coordinates included; only the map numbers move,
## since a group's numbering shifts with the maps pokegold does not have.
const SPAWN_RECORD_SIZE: int = 4
const SPAWN_COUNT: int = 28
const SPAWN_TERMINATOR: int = 0xFF

## The spawn coordinates, in table order, which is what identifies the table:
## every entry's x and y at a stride of four is a run no other bytes in a dump
## match. `SPAWN_HOME` is the bedroom, `SPAWN_DEBUG` the Viridian Pokecenter,
## then Kanto and then Johto.
const SPAWN_COORDINATES: Array[int] = [
	3, 3, 5, 3,
	5, 6, 23, 26, 13, 26, 19, 22, 11, 2, 9, 6, 5, 6, 9, 30, 29, 10, 19, 28, 11, 12, 9, 6,
	13, 6, 29, 4, 31, 26, 11, 74, 15, 10, 23, 44, 15, 28, 13, 22, 23, 28, 15, 14,
	21, 29, 21, 30, 23, 20, 6, 2,
]

## `SPAWN_*` indexes worth naming. `SPAWN_HOME` is where a new game's respawn
## point starts and `SPAWN_INDIGO` is the one `FlyMap` tests before it will draw
## Kanto at all.
const SPAWN_HOME: int = 0
const SPAWN_INDIGO: int = 13

## `Flypoints` (`data/maps/flypoints.asm`): `db landmark, spawn` per `FLY_*`
## constant, then `-1`. The twelve Johto rows come first and `KANTO_FLYPOINT` is
## where Kanto starts, which is the whole of how `FlyMap` picks the region's
## range. The spawn column is identical between the pins; the landmark column is
## not, since Gold and Silver ship one landmark fewer.
const FLYPOINT_RECORD_SIZE: int = 2
const FLYPOINT_COUNT: int = 24
const FLYPOINT_TERMINATOR: int = 0xFF
const KANTO_FLYPOINT: int = 12
const FLYPOINT_SPAWNS: Array[int] = [
	14, 15, 16, 18, 20, 22, 21, 19, 23, 24, 25, 26,
	2, 3, 4, 5, 7, 6, 8, 10, 9, 11, 12, 13,
]
const PHONE_CONTACT_COUNT: int = 38
const PHONE_CONTACT_SIZE: int = 12
const SPECIAL_PHONE_CALL_COUNT: int = 8
const SPECIAL_PHONE_CALL_SIZE: int = 6
const PHONE_NON_TRAINER_NAME_POINTER_SIZE: int = 2
const AUDIO_POINTER_SIZE: int = 3
## Audio channel programs share subroutines within their bank, so one cached
## record keeps the complete 16 KiB bank window rather than truncating a valid
## jump target at the next top-level pointer.
const AUDIO_MAX_RECORD_BYTES: int = 0x4000
const AUDIO_WAVE_SAMPLE_COUNT: int = 10
const AUDIO_WAVE_SAMPLE_BYTES: int = 16
const AUDIO_DRUMKIT_COUNT: int = 6
const AUDIO_DRUMKIT_SAMPLE_COUNT: int = 13
const AUDIO_DRUMKIT_BYTES: int = 0x174
## `NUM_CRIES`, which is 68 rather than 67: constants/cry_constants.asm runs
## CRY_NIDORAN_M through CRY_DONPHAN inclusive. The pointer table's own last
## entry is CRY_DONPHAN and the next three bytes are already the SFX table, so a
## count of 67 dropped exactly one cry, the one species 232 asks for.
const AUDIO_CRY_COUNT: int = 68

## `PokemonCries` (data/pokemon/cries.asm): `mon_cry index, pitch, length` per
## species, six bytes a row. 255 rows, not 251: the table pads to `$ff` with four
## silent CRY_NIDORAN_M rows the way the pic tables pad.
## The table is what makes a cry per species rather than per stream: Ivysaur and
## Venusaur both play CRY_BULBASAUR and differ only in these two words.
const MON_CRY_COUNT: int = 255
const MON_CRY_ROW_SIZE: int = 6

## Rows pinned by value rather than by shape, since 255 six-byte rows of the
## right shape sit in more than one place. Species number to
## `[index, pitch, length]`, read off `data/pokemon/cries.asm`.
const MON_CRY_PINS: Dictionary = {
	1: [15, 128, 129],
	2: [15, 32, 256],
	3: [15, 0, 320],
	251: [55, 330, 273],
	252: [0, 0, 0],
}

## The overworld palette file contains 42 four-colour groups: morning, day,
## night and dark outdoor groups, the indoor group, and the two animated water
## groups. Palette maps use two nibbles per tile and reserve sixteen bytes for
## the font tiles between VRAM banks.
const WORLD_PALETTE_GROUP_COUNT: int = 42
const WORLD_PALETTE_GROUP_BYTES: int = 8
const WORLD_PALETTE_BYTES: int = WORLD_PALETTE_GROUP_COUNT * WORLD_PALETTE_GROUP_BYTES
const WORLD_PALETTE_MAP_BYTES: int = 0x70

## `LoadSpecialMapPalette` (engine/tilesets/tileset_palettes.asm): six Crystal
## tilesets whose eight palettes are fixed, and its carry skips `LoadMapPals`'
## environment and time-of-day selection whole. Appended to the palette groups.
const SPECIAL_PALETTE_BASE: int = WORLD_PALETTE_GROUP_COUNT
const SPECIAL_PALETTE_TILESETS: Array[int] = [0x15, 0x16, 0x1D, 0x05, 0x1B, 0x0D]
## `.ice_path`'s `cp INDOOR`: the Hall of Fame shares the tileset and is handed back.
const SPECIAL_PALETTE_ICE_PATH: int = 0x1D
const SPECIAL_PALETTE_MANSION: int = 0x0D
const PAL_BG_WATER: int = 3
const PAL_BG_YELLOW: int = 4
const PAL_BG_ROOF: int = 6
const SPECIAL_PALETTE_ENVIRONMENT_INDOOR: int = 3

## `LoadMapGroupRoof` and `RoofPals`. A map group names one of five nine-tile
## roof runs, copied over `vTiles2 tile $0a` on every map load, and `_LoadMapPals`
## replaces colours 1 and 2 of `PAL_BG_ROOF` with that group's own pair on a TOWN
## or ROUTE map. `MapGroupRoofs` is NUM_MAP_GROUPS + 1 bytes and `RoofPals` is
## two colours for morn/day and two for nite per group.
const MAP_GROUP_ROOF_COUNT: int = 27
const ROOF_COUNT: int = 5
const ROOF_TILES: int = 9
const ROOF_TILE_BYTES: int = ROOF_TILES * 16
const ROOF_VRAM_TILE: int = 0x0A
const WORLD_ANIMATION_BANK: int = 0x3F
const WORLD_ANIMATION_COMMAND_BYTES: int = 4
const WORLD_ANIMATION_MAX_COMMANDS: int = 64

const MOVE_COUNT: int = 251
const MOVE_DATA_SIZE: int = 7

## Item numbers run from 1 to 255. The last several entries are the unused
## "TERU-SAMA" slots the cartridges ship with; they are decoded rather than
## trimmed, so an item number always indexes the table directly.
const ITEM_COUNT: int = 255
const ITEM_ATTRIBUTE_SIZE: int = 7
const ITEM_ATTRIBUTE_PARAM: int = 3
const ITEM_ATTRIBUTE_PERMISSIONS: int = 4
const ITEM_ATTRIBUTE_POCKET: int = 5
const ITEM_ATTRIBUTE_HELP: int = 6
## The item attribute table calls this field a pocket, but its value is the
## cartridge's item type: ITEM=1, KEY_ITEM=2, BALL=3, TM_HM=4.
const ITEM_POCKET_BALL: int = 3
const ITEMMENU_NOUSE: int = 0
const ITEMMENU_CURRENT: int = 4
const ITEMMENU_PARTY: int = 5
const ITEMMENU_CLOSE: int = 6
## Both permission bits read inverted: a set bit is what the item cannot do.
const ITEM_ATTRIBUTE_CANT_SELECT: int = 1 << 6
const ITEM_ATTRIBUTE_CANT_TOSS: int = 1 << 7
const TRADE_RECORD_SIZE: int = 32
const TRADE_NAME_LENGTH: int = 11
const TRADE_GENDER_EITHER: int = 0
const TRADE_GENDER_MALE: int = 1
const TRADE_GENDER_FEMALE: int = 2
## Crystal's fourth set, the one `DoNPCTrade` tests for CAUGHT_BY_GIRL. Gold and
## Silver ship three sets, so no row of theirs reaches it.
const TRADE_DIALOGSET_GIRL: int = 3

## `TradeTexts`, transcribed: `TRADE_DIALOG_*` rows by `TRADE_DIALOGSET_*`
## columns, each cell naming a stub. Crystal's NEWBIE column shares variant 2
## until the trade has happened and then takes two texts Gold and Silver lack.
const TRADE_TEXTS: Array[String] = [
	"intro_1", "intro_2", "intro_2", "intro_3",
	"cancel_1", "cancel_2", "cancel_2", "cancel_3",
	"wrong_1", "wrong_2", "wrong_2", "wrong_3",
	"complete_1", "complete_2", "complete_4", "complete_3",
	"after_1", "after_2", "after_4", "after_3",
]
const TRADE_TEXTS_GOLD_SILVER: Array[String] = [
	"intro_1", "intro_2", "intro_3",
	"cancel_1", "cancel_2", "cancel_3",
	"wrong_1", "wrong_2", "wrong_3",
	"complete_1", "complete_2", "complete_3",
	"after_1", "after_2", "after_3",
]
## The two cells in their own run, because only Crystal ships them.
const TRADE_NEWBIE_TEXTS: Array[String] = ["complete_4", "after_4"]
## The stubs' own order in the file, variant-major where `TradeTexts` is
## dialog-major, which is the order a run of stubs is read at.
const TRADE_TEXT_ORDER: Array[String] = [
	"intro_1", "cancel_1", "wrong_1", "complete_1", "after_1",
	"intro_2", "cancel_2", "wrong_2", "complete_2", "after_2",
	"intro_3", "cancel_3", "wrong_3", "complete_3", "after_3",
]


static func trade_text_name(crystal: bool, dialog: int, dialog_set: int) -> String:
	var table: Array[String] = TRADE_TEXTS if crystal else TRADE_TEXTS_GOLD_SILVER
	var sets: int = 4 if crystal else 3
	var cell: int = dialog * sets + clampi(dialog_set, 0, sets - 1)
	return "" if cell < 0 or cell >= table.size() else table[cell]

## Type numbers are sparse: $00-$09 are the physical types, $14-$1B the special
## ones, and the run between is padding that still has a name entry. Reading all
## 28 keeps the table indexable by type number.
const TYPE_COUNT: int = 28
const TYPE_POINTER_SIZE: int = 2

## The type numbers themselves. Only the ones something here names are listed:
## the rest are reached by number, since a move's type byte is already one.
## $06 sits between ROCK and BUG and is the unused BIRD slot, which is why the
## physical types are not a contiguous run of nine.
const TYPE_NORMAL: int = 0x00
const TYPE_FIGHTING: int = 0x01
const TYPE_FLYING: int = 0x02
const TYPE_POISON: int = 0x03
const TYPE_GROUND: int = 0x04
const TYPE_ROCK: int = 0x05
## The unused physical type between Rock and Bug, and the run of ten between
## Steel and Fire that holds only `CURSE_TYPE`. No move and no species carries
## either, and both exist here because Hidden Power's type has to step over them
## (`constants/type_constants.asm`, `engine/battle/hidden_power.asm`).
const TYPE_BIRD: int = 0x06
const TYPE_UNUSED_START: int = 0x0A
const TYPE_UNUSED_END: int = 0x14
const TYPE_BUG: int = 0x07
const TYPE_GHOST: int = 0x08
const TYPE_STEEL: int = 0x09
const TYPE_FIRE: int = 0x14
const TYPE_WATER: int = 0x15
const TYPE_GRASS: int = 0x16
const TYPE_ELECTRIC: int = 0x17
const TYPE_PSYCHIC: int = 0x18
const TYPE_ICE: int = 0x19
const TYPE_DRAGON: int = 0x1A
const TYPE_DARK: int = 0x1B

## The longest move and item name in these games is twelve characters. This is
## the runaway guard for a terminator walk, not a field width.
const MAX_NAME_LENGTH: int = 16

## The type matchup chart: attacker, defender, multiplier, exceptions only, so a
## pair not in the table is [constant MATCHUP_EFFECTIVE] and the whole of
## Generation 2 fits in 332 bytes. Multipliers are in tenths as the cartridge
## stores them, applied by multiplying then dividing, because the games truncate
## after each of a defender's two types.
const MATCHUP_ENTRY_SIZE: int = 3
const MATCHUP_ATTACKER: int = 0
const MATCHUP_DEFENDER: int = 1
const MATCHUP_MULTIPLIER: int = 2

const MATCHUP_NO_EFFECT: int = 0
const MATCHUP_NOT_VERY_EFFECTIVE: int = 5
const MATCHUP_EFFECTIVE: int = 10
const MATCHUP_SUPER_EFFECTIVE: int = 20

## Every multiplier the table actually contains. [constant MATCHUP_EFFECTIVE] is
## not among them: a neutral matchup is an absent row, so a byte of 10 here would
## mean the walk has left the table.
const MATCHUP_MULTIPLIERS: Array = [
	MATCHUP_NO_EFFECT, MATCHUP_NOT_VERY_EFFECTIVE, MATCHUP_SUPER_EFFECTIVE,
]

## The table ends twice. $FE ends it for a defender under Foresight, and $FF ends
## it for everything else, so the rows between the two are exactly the matchups
## Foresight cancels: Normal and Fighting against a Ghost. Reading the rows as
## "true unless Foresight" rather than "extra under Foresight" is the way round
## the cartridge means them, and the flag in the cache is named for it.
const MATCHUP_END_FORESIGHT: int = 0xFE
const MATCHUP_END: int = 0xFF

## What the walk has to find. All three games carry the same chart, so unlike the
## trainer class count these are constants rather than layout entries.
const MATCHUP_COUNT: int = 108
const FORESIGHT_MATCHUP_COUNT: int = 2

## Runaway guard for the walk, well past the real end of the table.
const MAX_MATCHUPS: int = 256

## A type number the chart can name. The physical types run $00-$09 and the
## special ones $14-$1B; everything between is padding that a move may carry but
## that no matchup mentions.
const PHYSICAL_TYPES_END: int = 0x09
const SPECIAL_TYPES_START: int = 0x14

## One Pokedex entry (data/pokemon/dex_entries.asm): a terminated category, then
## height and weight as little-endian words, then two terminated pages. The page
## break is the terminator itself, `MACRO page` being `db "@", \#`, so an entry
## ends after the second run rather than the first. Height is decimal digits of
## feet and inches (204 is 2'04") and weight tenths of a pound, both stored raw
## and formatted at draw time.
const DEX_ENTRY_PAGES: int = 2
const DEX_ENTRY_MEASUREMENT_BYTES: int = 2
## Runaway guard for a page walk, well past the longest entry in any of the
## three dumps (the longest measured is under 200 bytes).
const DEX_ENTRY_MAX_PAGE_LENGTH: int = 256
## The category is at most twelve characters, the same guard the move and item
## name walks use.
const DEX_ENTRY_MAX_CATEGORY_LENGTH: int = MAX_NAME_LENGTH

## Pointers are two bytes and bank-local, and the bank is chosen by species
## rather than stored: GetDexEntryPointer (engine/pokedex/pokedex_2.asm) rotates
## `species - 1` twice and masks to NUM_DEX_ENTRY_BANKS bits, which is `(species
## - 1) >> 6`. The four sections are species 1-64, 65-128, 129-192 and 193-251.
const DEX_ENTRY_POINTER_SIZE: int = 2
const DEX_ENTRY_BANK_SPECIES: int = 64
const DEX_ENTRY_BANK_COUNT: int = 4

## The three orderings Pokedex_OrderMonsByMode builds, as constants/ram_constants.asm
## numbers them. UNOWN is the fourth mode and is not one of these: it lists Unown
## forms rather than species, from its own table.
const DEXMODE_NEW: int = 0
const DEXMODE_OLD: int = 1
const DEXMODE_ABC: int = 2
const DEXMODE_UNOWN: int = 3

## Evolutions and level-up moves are one table, not two. A species' entry lists
## its evolutions, then a zero byte, then its level-up moves as level and move
## pairs, then another zero byte. One pointer answers both questions, which is
## why the two are decoded in the same pass rather than as separate tables.
## The pointers are two bytes rather than three: the entries sit in the pointer
## table's own bank, so there is no bank number to store.
const EVOS_ATTACKS_POINTER_SIZE: int = 2
const EVOS_ATTACKS_END: int = 0

## EggMovePointers is one little-endian pointer per species. Like the evolution
## table, each pointer names a list in the table's own bank. Unlike a level-up
## list, an egg-move list carries move numbers alone and ends at $FF; an empty
## list is therefore one $FF byte.
const EGG_MOVE_POINTER_SIZE: int = 2
const EGG_MOVE_END: int = 0xFF

## How a species evolves. The byte after the method is a level for
## [constant EVOLVE_LEVEL] and [constant EVOLVE_STAT], an item for
## [constant EVOLVE_ITEM], a held item for [constant EVOLVE_TRADE] ($FF for
## none), and a time of day for [constant EVOLVE_HAPPINESS].
const EVOLVE_LEVEL: int = 1
const EVOLVE_ITEM: int = 2
const EVOLVE_TRADE: int = 3
const EVOLVE_HAPPINESS: int = 4
## The one method that takes a second parameter, and the one only Tyrogue uses:
## a level, and then which way Attack and Defense have to compare.
const EVOLVE_STAT: int = 5

## Every method the table can name, which is what makes an evolution entry
## checkable: the byte that opens one is either a method or the terminator.
const EVOLVE_METHODS: Array = [
	EVOLVE_LEVEL, EVOLVE_ITEM, EVOLVE_TRADE, EVOLVE_HAPPINESS, EVOLVE_STAT,
]

## What [constant EVOLVE_HAPPINESS] asks about besides the happiness itself.
## Golbat evolves at any time, Eevee into Espeon by day and Umbreon by night.
const TRIGGER_ANYTIME: int = 1
const TRIGGER_MORNDAY: int = 2
const TRIGGER_NITE: int = 3

## Which way Attack and Defense have to compare for [constant EVOLVE_STAT].
const ATTACK_OVER_DEFENSE: int = 1
const ATTACK_UNDER_DEFENSE: int = 2
const ATTACK_EQUALS_DEFENSE: int = 3

## The highest level these games count to, and so the highest a level-up move or
## a level evolution can name.
const MAX_LEVEL: int = 100

## Runaway guards for the two walks. Five evolutions is the most any species has
## and fourteen level-up moves is the most, so both are well clear.
const MAX_EVOLUTIONS: int = 8
const MAX_LEVEL_UP_MOVES: int = 32

## Every evolution in the table, counted. All three games agree, as they do about
## the type matchup chart, so this is a constant rather than a layout entry.
const EVOLUTION_COUNT: int = 122

## Muk, whose level-up moves are not in ascending order. The cartridges ship it
## that way in all three games and pret's own listing carries a comment saying so.
## Named rather than worked around, because the order is load bearing: filling a
## fresh Pokemon stops at the first entry above its level, so a Muk below 45 never
## reaches the three moves after the level 45 one. Checking the order everywhere
## else is worth the exception, since scrambled levels are what a wrong offset
## produces.
const UNSORTED_LEARNSET_SPECIES: int = 89

## Unown's entry in the main pic table is a deliberate $FF placeholder: its 26
## letter forms live in a table of their own.
const UNOWN_SPECIES: int = 201
const UNOWN_FORMS: int = 26

## `UnownWords`: a pointer per form and then the words themselves in the same
## order, so the table's first entry is where the run behind it starts. The table
## has one entry more than there are forms because its zeroth is an unused
## duplicate of A's, and `PrintUnownWord` indexes it by form number. A word is not
## text: `unownword` stores each letter as `FIRST_UNOWN_CHAR + the letter's rank`,
## the tile number of the font `Pokedex_LoadUnownFont` builds, terminated with
## $FF, so it decodes with the alphabet alone and never through [Gen2Text].
const UNOWN_WORD_ENTRIES: int = UNOWN_FORMS + 1
const UNOWN_WORD_POINTER_SIZE: int = 2
const FIRST_UNOWN_CHAR: int = 0x40
const UNOWN_WORD_TERMINATOR: int = 0xFF
## Well past REASSURE, the longest at eight.
const UNOWN_WORD_MAX_LENGTH: int = 16

## `UnownWalls`: the four words the Ruins of Alph chamber walls spell, in
## `UNOWNWORDS_*` order, ending at $FF. Crystal only, since Gold and Silver's
## chambers carry the puzzle sign where Crystal carries the pattern. A letter is
## stored under the `unown` charmap: `$10 * (i / 8) + 2 * i` over the alphabet and
## a dash, which is the top-left tile of that letter's 2x2 block in a
## sixteen-tile-wide font, so the codes run 0-14, 32-46, 64-78 and 96-100, always
## even, and nothing else decodes.
const UNOWN_WALL_COUNT: int = 4
const UNOWN_WALL_MAX_LENGTH: int = 12
const UNOWN_WALL_TERMINATOR: int = 0xFF
## "ABCDEFGHIJKLMNOPQRSTUVWXYZ-", the charmap's own `PRINTABLE_UNOWN`.
const UNOWN_WALL_ALPHABET: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ-"
const UNOWN_WALL_BLOCK: int = 0x20
const UNOWN_WALL_ROW_LETTERS: int = 8
## The `UNOWNWORDS_*` argument `setval` puts in `wScriptVar` before the special.
## Only the first is named: it is the one the Kabuto chamber's two wall patterns
## ask for, and the check reads the word behind it rather than storing any.
const UNOWNWORDS_ESCAPE: int = 0

## The font is indexed by character code, not by position in a sheet: its first
## tile is code $80 ("A") and its last is $FF ("9"). That is not a coincidence of
## ordering, it is how the hardware prints at all. The font is loaded so that a
## character byte is already the tile number to draw, so the alphabet's runs in
## [Gen2Text] and the tiles here are the same run seen twice.
const FONT_TILES: int = 128
const FONT_FIRST_CODE: int = 0x80

## The alphabets and the digits: A-Z, a-z, 0-9. Every one of these has a glyph
## in every supported cartridge, and they are the runs [Gen2Text] builds
## arithmetically rather than listing.
const FONT_INK_RUNS: Array = [[0x80, 0x99], [0xA0, 0xB9], [0xF6, 0xFF]]
## "0"'s own character code, which the digits run up from.
const FONT_DIGIT_ZERO_CODE: int = 0xF6

## Codes with no character in [Gen2Text], whose tiles are blank. They sit between
## the runs above, which is what makes the pair a layout check: an offset out by
## one tile drags a blank onto "z" and a glyph onto a code that has none. Crystal
## draws an arrow at $EB where Gold and Silver leave a hole, so only the runs all
## three agree on are checked.
const FONT_BLANK_RUNS: Array = [[0xBA, 0xBF], [0xC6, 0xCF], [0xD7, 0xDE]]

## `FontExtra`, the 2bpp sheet `_LoadFontsExtra1` parks under the main font.
## Thirty-two tiles stored, of which it copies `FontExtra + 3 tiles` to
## `vTiles2 tile '<BOLD_D>'` for 22, so a tile is addressed by its code minus $60
## and the run that reaches the screen is $63 to $78. That run carries the
## ellipsis, the two quotes, the middle dot and `<COLON>`, which is every
## character [Gen2Text] decodes below the main font's $80 and the reason a text
## saying an ellipsis drew nothing without it. Codes $60 to $62 are overwritten
## elsewhere and are stored but never drawn from here.
const FONT_EXTRA_TILES: int = 32
const FONT_EXTRA_FIRST_CODE: int = 0x60
const FONT_EXTRA_LOADED_FIRST: int = 0x63
const FONT_EXTRA_LOADED_LAST: int = 0x78

## Text box borders: eight frames of six tiles, in the order ┌ ─ ┐ │ └ ┘, loaded
## at code $79 where [Gen2Text]'s box-drawing codes start, so a box is drawn by
## printing characters like anything else.
const FRAME_COUNT: int = 8
const FRAME_TILES: int = 6
const FRAME_FIRST_CODE: int = 0x79
## Positions within a frame.
const FRAME_TOP_LEFT: int = 0
const FRAME_HORIZONTAL: int = 1
const FRAME_TOP_RIGHT: int = 2
const FRAME_VERTICAL: int = 3
const FRAME_BOTTOM_LEFT: int = 4
const FRAME_BOTTOM_RIGHT: int = 5

## `MapEntryFrameGFX`, the fourteen tiles `LoadMapNameSignGFX` requests into
## `vTiles2 tile MAP_NAME_SIGN_START`. `PlaceMapNameFrame` addresses them by
## offset from that base, so the strip is stored in the cartridge's own order.
const MAP_ENTRY_SIGN_TILES: int = 14

## The battle HUD's own graphics, which sit in the same section as the font and
## the text box borders and are the rest of what a battle screen draws.
## [code]battle_font[/code] is 2bpp and carries "HP:", the HP bar's nine fill
## levels and the screen's odds and ends. The two HUD borders are 1bpp, the boxes
## a name and level sit in. The exp bar is 2bpp, seven fills and two ends.
const BATTLE_FONT_TILES: int = 32
## `_LoadFontsBattleExtra`'s `ld hl, vTiles2 tile $60`. Its twenty-five tiles
## cover $60 to $78, so a code in that run addresses this strip rather than the
## main font while loaded, which [constant Gen2Text.FONT_BATTLE_EXTRA] names.
const BATTLE_FONT_FIRST_CODE: int = 0x60
const ENEMY_HUD_TILES: int = 4
const PLAYER_HUD_TILES: int = 6
const EXP_BAR_TILES: int = 9

## `LoadBallIconGFX`'s own `.gfx`, four sprite tiles at `vTiles0 tile $31`:
## a live Pokemon, a statused one, a fainted one and an empty party slot, which
## `StageBallTilesData` picks between with `$31` to `$34`.
const BALL_ICON_TILES: int = 4
const BALL_ICON_FIRST_TILE: int = 0x31
## `BattleTransitionTiles`, the two `DoBattleTransition` fills the screen with,
## and the two four-colour palettes it draws them and the whole map in.
const BATTLE_TRANSITION_TILES: int = 2
## `MinimizePic`, the single tile `CopyMinimizePic` drops into an otherwise blank
## box: the dot a minimized Pokemon is drawn as for as long as it stays in.
const MINIMIZE_TILES: int = 1
## Its eight rows, lit pixels set, transcribed off `gfx/battle/minimize.png`: a
## solid diamond in colour 3 and nothing else. One tile has no neighbour to slide
## against, so its own shape is the whole of what pins the address.
const MINIMIZE_PIC_ROWS: Array[int] = [0x00, 0x00, 0x18, 0x3C, 0x7E, 0x3C, 0x24, 0x00]
const TRANSITION_PALETTE_NAMES: Array[String] = ["day", "dark"]
const TRANSITION_PALETTE_COLORS: int = 4
## `GetTrainerBackpic`: the player's own 6x6 picture, the one standing on the
## field before a Pokemon is sent out. Three of them, and the order here is the
## order [constant PLAYER_BACKPICS] names.
const PLAYER_BACKPIC_TILES: int = 6
const PLAYER_BACKPICS: Array[String] = ["chris", "kris", "dude"]
## The two palettes those three are drawn in: the Dude wears the player's own.
const PLAYER_PALETTE_NAMES: Array[String] = ["chris", "kris"]

## `StatsScreenPageTilesGFX`, the seventeen tiles `LoadStatsScreenPageTilesGFX`
## puts at `vTiles2 tile $31`: the vertical divider, the page indicator squares,
## the exp bar's two end caps and `'⁂'`, which `constants/charmap.asm` names as
## this sheet's tile 14. The stats screen and the move screen are the two that
## load it.
const STATS_TILES: int = 17
const STATS_FIRST_TILE: int = 0x31
## `PrintPartyMonPage1` and `StatsScreen_PlaceShinyIcon` both draw `'⁂'`,
## which is this sheet's tile 14.
const STATS_SHINY_TILE: int = 14

## The trainer card's graphics (engine/menus/trainer_card.asm). `CardStatusGFX`
## is six tiles but `_Option`'s page 1 asks for 86, running on into `LeaderGFX`,
## so page 1's strip is those 86 from the card_status offset; pages 2 and 3 load
## 86 from the leaders offset, which overlaps it, and both are imported because
## that is what each page draws. The pic is 5x7, stored column-major on Crystal
## and row-major on Gold and Silver, so the importer reorders Crystal's.
const CARD_STATUS_TILES: int = 86
const CARD_LEADER_TILES: int = 86
const CARD_BADGE_TILES: int = 44
const CARD_RIGHT_CORNER_TILES: int = 1
const CARD_FRAME_TILES: int = 6
const CARD_PIC_COLUMNS: int = 5
const CARD_PIC_ROWS: int = 7
const CARD_PIC_TILES: int = CARD_PIC_COLUMNS * CARD_PIC_ROWS

## The Pokedex's graphics (engine/pokedex/pokedex.asm): `PokedexLZ`'s 58 tiles to
## `vTiles2 tile $31` and `PokedexSlowpokeLZ`'s 55 to `vTiles0` straight after.
## Neither is what an unseen species is drawn as; that is `question_mark` below.
## The first two were located by compressing the pinned PNGs with pret's
## `lzcompress` flags, each hitting once per dump in the source's own order. The
## question mark's PNG matched nothing, so it was found by shape: exactly one LZ
## run per dump decompresses to 49 tiles. `Footprints` is 1bpp and uncompressed,
## eight top halves then their bottoms, hence [constant FOOTPRINT_HALF_STRIDE].
const POKEDEX_TILES: int = 58
const POKEDEX_SLOWPOKE_TILES: int = 55
## `LoadQuestionMarkPic`, whose `ld c, 7 * 7` is what the copy out of `sScratch`
## sends to the pic slot. Column major, the way every pic is stored.
const POKEDEX_QUESTION_MARK_TILES: int = 49
const POKEDEX_QUESTION_MARK_COLUMNS: int = 7
## `Pokedex_GetAndPlaceFootprint` asks for two 1bpp tiles at a time, twice.
const FOOTPRINT_TILES: int = 4
const FOOTPRINT_HALF_TILES: int = 2
## The gap the source calls "each bottom half is 8 tiles off": eight species of
## two tiles sit between a footprint's halves.
const FOOTPRINT_HALF_STRIDE: int = 8 * FOOTPRINT_HALF_TILES
const FOOTPRINT_SPECIES: int = 251
## The stored image is 16x64 tiles, which is 256 species of four and not 251:
## the last eight species' bottom halves are only addressable because the run
## carries the whole grid. All 1,024 tiles are imported for that reason.
const FOOTPRINT_SLOTS: int = 256

## `UnownFont`, the alphabet `Pokedex_LoadUnownFont` inverts into the dex sheet's
## own `$40` onwards. The file is 27 tiles and `Request2bpp` sends
## `NUM_UNOWN + 1`, which is the same 27; the `39 tiles` the copy before it asks
## for runs past the sheet into whatever follows and is never drawn. Located by
## matching the assembled `gfx/font/unown_font.png`, which hits once per dump.
const UNOWN_FONT_TILES: int = 27
## `FIRST_UNOWN_CHAR`, where the letters land.
const UNOWN_FONT_FIRST_TILE: int = 0x40

## `ItemDescriptions` and `MoveDescriptions`, the two lines a pack row prints
## into its own text box (`PrintItemDescription`, `PrintMoveDescription`). Both
## are `table_width 2` pointer tables in the bank their texts sit in, so an entry
## is read as an in-bank address rather than as a far pointer.
const DESCRIPTION_MAX_BYTES: int = 80
const MOVE_DESCRIPTION_COUNT: int = 251

## The pack screen's graphics (engine/items/pack.asm). `PackMenuGFX` is 80 tiles
## and `Pack_InitGFX` copies `$60 tiles`, so the sixteen landing on `vTiles2 tile
## $50` are `PackGFX`'s own first sixteen; `DrawPackGFX` puts the pocket's
## fifteen there before the screen is shown and no tilemap names the sixteenth.
## That overrun is what says the two runs are adjacent, and they are in every
## dump. `PackFGFX` is Crystal's alone, Gold and Silver having no player gender
## and no `DrawKrisPackGFX`. All four are uncompressed and each matches the
## assembled `gfx/pack` PNGs once per dump.
const PACK_MENU_TILES: int = 80
const PACK_POCKET_TILES: int = 15
const PACK_POCKETS: int = 4
const PACK_TILES: int = PACK_POCKET_TILES * PACK_POCKETS
## `PlacePackGFX`'s own `ld a, $50`, which is where a pocket's picture is placed
## and so what a pack tile number is offset by.
const PACK_FIRST_TILE: int = 0x50
## `PackGFXPointers`' order, as the pocket each of the four pictures belongs to:
## the sheet is stored key items, items, TM/HM, balls.
const PACK_POCKET_PICTURES: Array[int] = [1, 3, 0, 2]
## `DrawPocketName`'s 5x12 tilemap, four 5x3 pieces in `*_POCKET` order.
const PACK_NAME_COLUMNS: int = 5
const PACK_NAME_ROWS: int = 3
const PACK_NAME_CELLS: int = PACK_NAME_COLUMNS * PACK_NAME_ROWS * PACK_POCKETS
## `.ChrisPackPals` and `.KrisPackPals`, which `gfx/pack/pack.pal` and
## `pack_f.pal` define six palettes each of. `_CGB_PackPals` copies eight and its
## own comment asks why; the attrmap it then fills names only 0 to 5, so the two
## past the file are read and never drawn.
const PACK_PALETTES: int = 6
const PACK_PALETTE_COLORS: int = 4

## `BillsPC_InitGFX`'s two runs and `BillsPCOrangePalette`. `PCSelectLZ` is the
## selection cursor's own eight sprite tiles and `PCMailGFX` the four the mail
## and item markers are drawn from, stored immediately after it in every dump.
## Crystal compresses the first with `--literal-only` and Gold and Silver do
## not, so its run is 131 bytes there and 29 here; the decompressed sheet is
## what the importer checks, not the run's length.
const PC_SELECT_TILES: int = 8
const PC_MAIL_TILES: int = 4
## `gfx/pc/orange.pal`, which `_CGB_BillsPC` loads over the mon-pic palette
## while the cursor stands on a row holding no Pokémon.
const PC_PALETTE_COLORS: int = 4

## `DrawIntroPlayerPic`'s uncompressed 7x7 picture. Crystal stores Chris and
## Kris column-major; Gold and Silver use CAL's normal trainer picture instead.
const INTRO_PLAYER_PIC_COLUMNS: int = 7
const INTRO_PLAYER_PIC_ROWS: int = 7
const INTRO_PLAYER_PIC_TILES: int = INTRO_PLAYER_PIC_COLUMNS * INTRO_PLAYER_PIC_ROWS

## `InitGender`'s own background: one 2bpp tile of a single colour index, and the
## four-colour palette it is read through. `InitGenderScreen` ByteFills the whole
## tilemap with tile $00, which is where `LoadGenderScreenLightBlueTile` puts it,
## so the index in that tile is the field the box and menu are drawn over.
const GENDER_SCREEN_TILES: int = 1
const GENDER_SCREEN_PALETTE_COLORS: int = 4
## The index every pixel of the tile carries, which is `.Palette`'s second
## colour, RGB 09,30,31.
const GENDER_SCREEN_FILL_INDEX: int = 1

## `Copyright` (engine/menus/intro_menu.asm): 29 or 30 tiles requested into
## `vTiles2 tile $60`, and `CopyrightString` placed at (2,7). The string is
## `data/copyright.asm`, three `next`-separated rows of nothing but those tile
## codes, so the screen is the strip plus the code run and needs no font.
const COPYRIGHT_FIRST_CODE: int = 0x60
const COPYRIGHT_AT: Vector2i = Vector2i(2, 7)
## `PREDEFPAL_GAMEFREAK_LOGO_BG` (gfx/sgb/predef.pal), which `_CGB_GamefreakLogo`
## loads before `SplashScreen` draws the copyright. Its first colour is black and
## its last white, so the screen is white on black rather than the other way
## round.
const COPYRIGHT_PALETTE_COLORS: int = 4
## `PlaceString` stops at "@", and the rows are separated by `next`.
const COPYRIGHT_STRING_TERMINATOR: int = 0x50
const COPYRIGHT_STRING_NEXT: int = 0x4E
## Long enough for either pin's three rows; a run that reaches it has not found
## its terminator and is not the string.
const COPYRIGHT_STRING_MAX: int = 64
const COPYRIGHT_STRING_ROWS: int = 3

## `GameFreakLogoGFX` (engine/movie/splash.asm), which is two `INCBIN`s back to
## back rather than one run: `gamefreak_presents.1bpp` and then
## `gamefreak_logo.1bpp`. `Get1bpp` loads all 28 at once, but the halves are
## addressed apart. The BG strings index the first thirteen plus the logo's own
## first tile, which is blank and is the space in "GAME FREAK"; Gold's logo
## sprite draws the fifteen.
const PRESENTS_WORD_TILES: int = 13
const PRESENTS_LOGO_TILES: int = 15
const PRESENTS_GFX_TILES: int = PRESENTS_WORD_TILES + PRESENTS_LOGO_TILES
## The six tiles of "PRESENTS", which sit a row below "GAME FREAK" and so carry
## no ink in their top two rows.
const PRESENTS_SECOND_WORD_FIRST: int = 7
const PRESENTS_SECOND_WORD_TILES: int = 6
const PRESENTS_SECOND_WORD_CLEAR_ROWS: int = 2

## `GameFreakLogoStarsGFX`: `logo_star.2bpp` then `logo_sparkle.2bpp`, Gold and
## Silver only. Crystal spends the same beat on a Ditto instead.
const PRESENTS_STAR_TILES: int = 2
const PRESENTS_SPARKLE_TILES: int = 3
const PRESENTS_STARS_TILES: int = PRESENTS_STAR_TILES + PRESENTS_SPARKLE_TILES

## `GameFreakDittoGFX`, one LZ run `GameFreakPresentsInit` splits over `vTiles0`
## and `vTiles1` as 128 tiles each. The OAM sets index the result with a stride
## of $10, so it is one 16x16 sheet.
const PRESENTS_DITTO_COLUMNS: int = 16
const PRESENTS_DITTO_TILES: int = PRESENTS_DITTO_COLUMNS * PRESENTS_DITTO_COLUMNS
## `gfx/splash/ditto.pal`, which `_CGB_GamefreakLogo` loads into both object
## palettes. Colour 0 is white and so transparent on a sprite; colour 2 is the
## pink the fade below moves.
const PRESENTS_DITTO_PALETTE_COLORS: int = 4
const PRESENTS_DITTO_FADE_COLOR: int = 2
## `GameFreakDittoPaletteFade` (`gfx/splash/ditto_fade.pal`), one colour per step
## of `GameFreakLogo_Transform`. Crystal only.
const PRESENTS_DITTO_FADE_COLORS: int = 16

## `PREDEFPAL_GAMEFREAK_LOGO_OB`, the object palette Gold and Silver draw the
## star, the logo and the sparkles through. It sits eight bytes in front of
## `PREDEFPAL_GAMEFREAK_LOGO_BG`, which is the copyright screen's own palette.
const PRESENTS_OBJECT_PALETTE_COLORS: int = 4

## The title screen (`_TitleScreen` on Crystal, `TitleScreen` on Gold and Silver,
## `engine/movie/title.asm`): two screens sharing a phase, Crystal decompressing
## three graphics with sixteen palettes of its own and Gold and Silver two halves
## of a logo over one `$FF`-terminated tilemap with a bird behind a raw trail.
## Every offset was located the way the splash's were, and each hits once.
const TITLE_SUICUNE_TILES: int = 256
## `--trim-end 4`: `DrawTitleGraphic` places 7 rows of 20 from `vTiles1`, and the
## four tiles past them are whitespace the build drops.
const TITLE_LOGO_TILES: int = 156
## `--interleave`, so the sheet is a column of 8x16 objects rather than rows:
## `InitializeBackground` walks five columns of six sprites, stepping the tile
## number by two each time.
const TITLE_CRYSTAL_TILES: int = 60
const TITLE_CRYSTAL_SPRITE_COLUMNS: int = 5
const TITLE_CRYSTAL_SPRITE_ROWS: int = 6
## `TitleScreenPalettes` (`gfx/title/title.pal`), copied whole into both buffers.
const TITLE_PALETTES: int = 16
const TITLE_PALETTE_COLORS: int = 4

## Gold and Silver's own halves. `TitleScreenGFX1` is `--trim-whitespace`, which
## takes the bottom of the logo from 120 tiles to 112.
const TITLE_LOGO_BOTTOM_TILES: int = 112
const TITLE_LOGO_TOP_TILES: int = 60
## `TitleScreenTilemap`, read a byte at a time until `-1`. Long enough for either
## pin's run; one that reaches this has not found its terminator.
const TITLE_TILEMAP_TERMINATOR: int = 0xFF
const TITLE_TILEMAP_MAX: int = 1024
## `debgcoord 0, 0`: the run is written straight into the BG map rather than into
## the tilemap a screen is drawn from, so a row is `TILEMAP_WIDTH` and not
## `SCREEN_WIDTH`. The twelve bytes past column 19 are off the right of the
## screen and are blanks.
const TITLE_TILEMAP_COLUMNS: int = 32
const TITLE_TILEMAP_VISIBLE_COLUMNS: int = 20
## `TitleScreenGFX3` is four drawn tiles on both profiles, but `TitleScreen`
## copies eight whatever it is: Gold ships four blank tiles behind its trail and
## Silver's four come off the head of the compressed Lugia, loaded into VRAM and
## never shown. The source says so at the `FarCopyBytes`.
const TITLE_TRAIL_DRAWN_TILES: int = 4
const TITLE_TRAIL_COPIED_TILES: int = 8

## `GSTitleBGPals` and `GSTitleOBPals`, contiguous in `engine/gfx/color.asm`.
const TITLE_BG_PALETTES: int = 5
const TITLE_OB_PALETTES: int = 2

## `engine/menus/start_menu.asm`'s `.PokedexDesc` through `.QuitDesc`, one
## contiguous run of `PlaceString` strings in the order they are defined, which
## is not the order `.Items` lists them in. MENU ACCOUNT is what draws one.
const MENU_DESCRIPTION_COUNT: int = 9
## Long enough for the longest ("Trainer's key device"); a run that reaches it
## has not found its terminator and is not the table.
const MENU_DESCRIPTION_MAX: int = 64
## The order the strings are laid out in, as the start menu's own item kinds.
## `quit` is the Bug Catching Contest's, which stands where `save` does while
## one runs ([constant Gen2WorldStartMenu.ITEM_QUIT]).
const MENU_DESCRIPTION_ORDER: Array[StringName] = [
	&"pokedex", &"pokemon", &"pack", &"pokegear", &"player", &"save", &"option",
	&"exit", &"quit",
]

## `data/text/common_2.asm`'s pack texts, each a `text_far` target the way the
## intro texts are: `UseItem`'s two refusals and `TossMenu`'s three.
const PACK_TEXT_MAX_BYTES: int = 256

## `gfx/font/bg_text.pal`, PAL_BG_TEXT. Stored whole rather than as a pair: a
## palette fade over a text box passes through its two middle colours even
## though a 1bpp glyph never draws them.
const TEXT_BG_PALETTE_COLORS: int = 4

## `ShrinkFrame`'s `ld c, 7 * 7`: both shrink pictures are the same 7x7 box the
## trainer and player pics fill, and `PlaceGraphic` lays them down each column.
const SHRINK_PIC_COLUMNS: int = 7
const SHRINK_PIC_ROWS: int = 7
const SHRINK_PIC_TILES: int = SHRINK_PIC_COLUMNS * SHRINK_PIC_ROWS
## The two sheet names the cache holds them under.
const SHRINK_PIC_NAMES: Array[String] = ["shrink_1", "shrink_2"]

## `_CGB_TrainerCard`'s eight background palettes, as the trainer classes it
## reads them from, in its own call order. Slot 0 is the player's own class,
## which is why the cache carries a class the trainer tables otherwise skip;
## slot 1 is Falkner's, which the source's own comment marks as Kris's card
## palette and which Clair borrows further down.
const CARD_PALETTE_CLASSES: Array[int] = [0, 1, 3, 2, 4, 7, 6, 5]

## `PREDEFPAL_CGB_BADGE` (gfx/sgb/predef.pal), the object palette every badge
## sprite is drawn with. Four colours rather than a pair, since a predef palette
## is stored whole.
const CARD_BADGE_PALETTE_COLORS: int = 4

## The region map (`_TownMap` and `PokegearMap`, engine/pokegear/pokegear.asm).
## `Pokegear_LoadGFX` builds one VRAM window for both screens: `TownMapGFX` at
## `vTiles2`, `PokegearGFX` at `vTiles2 tile $30` and `PokegearSpritesGFX` at
## `vTiles0`, which is where the cursor's tiles come from. All three are LZ runs.
const TOWN_MAP_TILES: int = 48
const TOWN_MAP_FIRST_TILE: int = 0x00
const POKEGEAR_TILES: int = 46
const POKEGEAR_FIRST_TILE: int = 0x30
const POKEGEAR_SPRITE_TILES: int = 9
## `FastShipGFX`, uncompressed and copied over the player icon's own tiles when
## the player is on the S.S. Aqua, so it is the same four-frame walk read from
## eight tiles rather than twenty-four.
const FAST_SHIP_TILES: int = 8

## `JohtoMap` and `KantoMap` (gfx/pokegear/johto.bin, kanto.bin): one tile number
## per cell of the whole screen, then `-1`. `FillTownMap` writes them from (0,0),
## so a region map covers the screen before any frame is drawn over it.
const TOWN_MAP_REGION_CELLS: int = 360
const TOWN_MAP_REGION_TERMINATOR: int = 0xFF
const TOWN_MAP_REGION_BYTES: int = TOWN_MAP_REGION_CELLS + 1

## `PokedexNestIconGFX`, the blinking marker `Pokedex_GetArea` puts on every
## landmark a species is found at. One uncompressed tile sitting directly behind
## `KantoMap`, so the region map locates it rather than a fourth offset.
const DEX_NEST_ICON_TILES: int = 1

## `FlyMapLabelBorderGFX`, the six 1bpp tiles `_FlyMap` loads over `PokegearGFX`
## at `vTiles2 tile $30`: the bubble's four corners, its up/down arrow and one
## spare. Uncompressed and directly behind `PokedexNestIconGFX`, so the region
## map locates it too.
const FLY_MAP_LABEL_TILES: int = 6
const FLY_MAP_LABEL_FIRST_TILE: int = POKEGEAR_FIRST_TILE

## `RadioTilemapRLE`, `PhoneTilemapRLE` and `ClockTilemapRLE`: the other three
## Pokegear cards, one contiguous run in that order directly behind
## `PokegearSpritesGFX`, byte identical on all three cartridges.
## `Pokegear_LoadTilemapRLE` reads the *tile* first and its run length second,
## the opposite way round from the comment above it, and writes from (0,0) until
## `-1`. Each card is twelve rows; `Textbox` draws the four below them.
const POKEGEAR_CARD_ORDER: Array[String] = ["radio", "phone", "clock"]
const POKEGEAR_CARD_COLUMNS: int = 20
const POKEGEAR_CARD_ROWS: int = 12
const POKEGEAR_CARD_CELLS: int = POKEGEAR_CARD_ROWS * POKEGEAR_CARD_COLUMNS
const POKEGEAR_CARD_TERMINATOR: int = 0xFF
## The whole run, which is what bounds the walk over the three.
const POKEGEAR_CARD_TILEMAP_BYTES: int = 305

## `_GearEllipseText` and the four texts behind it, adjacent in
## `data/text/common_3.asm` and decoded in that order from the one offset: the
## two the phone card places while a call is being made or refused, then the
## question it opens with, the clock card's line, and the DELETE row's question.
const POKEGEAR_TEXT_NAMES: Array[String] = [
	"ellipse", "out_of_service", "ask_who", "press_button", "ask_delete",
]
const POKEGEAR_TEXT_MAX_BYTES: int = 64

## `PhoneClickText` and `PhoneEllipseText`, the two lines `HangUp` prints. Both
## are short; the window only has to hold each one whole.
const PHONE_CALL_TEXT_MAX_BYTES: int = 32

## `TownMapPals`: a palette per tile id, condensed to nybbles, least significant
## first. It covers $00 to $5f; $60 and above take palette 0.
const TOWN_MAP_PALETTE_MAP_BYTES: int = 48
const TOWN_MAP_PALETTE_MAP_LIMIT: int = 0x60
## `MalePokegearPals`/`FemalePokegearPals` (`PokegearPals` on Gold and Silver),
## which are gfx/pokegear/pokegear.pal: border, earth, mountain, city, point of
## interest and mountain point of interest. Only the city palette differs between
## the two Crystal copies.
const TOWN_MAP_PALETTES: int = 6
const TOWN_MAP_PALETTE_COLORS: int = 4
## Every one of the six opens on the same off-white, which is what identifies the
## run: RGB 28,31,20.
const TOWN_MAP_PALETTE_FIRST_COLOR: int = 0x53FC

## The credits (`engine/movie/credits.asm`).
## `CreditsScript`'s commands, `const_def -1, -1`: the byte a command is not is a
## `CreditsStringsPointers` index.
const CREDITS_END: int = 0xFF
const CREDITS_WAIT: int = 0xFE
const CREDITS_SCENE: int = 0xFD
const CREDITS_CLEAR: int = 0xFC
const CREDITS_MUSIC: int = 0xFB
const CREDITS_WAIT2: int = 0xFA
const CREDITS_THEEND: int = 0xF9
## The commands that take one operand; the rest are one byte.
const CREDITS_OPERAND_COMMANDS: Array[int] = [
	CREDITS_WAIT, CREDITS_WAIT2, CREDITS_SCENE,
]

## `CreditsBorderGFX`, then the four `Credits*GFX` mon sheets, uncompressed and
## contiguous in that order, and `CreditsScript` directly behind them. So one
## pinned offset locates all six and the run's own length pins the script.
const CREDITS_BORDER_TILES: int = 9
## `Credits_LoadBorderGFX.Frames` steps in 16-tile blocks, which is the 4x4 cell
## the banner is five copies of.
const CREDITS_MON_FRAME_TILES: int = 16
const CREDITS_SCENES: int = 4
const CREDITS_SCENE_FRAMES: int = 4
## `TheEndGFX` (gfx/misc.asm), eight tiles across and two down.
const CREDITS_THE_END_TILES: int = 16
const CREDITS_THE_END_COLUMNS: int = 8

## `Credits`' own VRAM window: the current mon frame's sixteen tiles at
## `vTiles2`, the border at tile $20, "The End" at $40 and `CopyrightGFX` at $60,
## which is where `LoadFontsBattleExtra` would put its strip. Letters are $80 and
## up and are untouched.
const CREDITS_BORDER_FIRST_CODE: int = 0x20
const CREDITS_THE_END_FIRST_CODE: int = 0x40

## `CreditsPalettes` (gfx/credits/credits.pal). Crystal copies 24 bytes per
## scene, which is BG palettes 0, 1 and 2; Gold and Silver copy 8 twice, so
## palettes 0 and 1 are the same four colours.
const CREDITS_PALETTE_COLORS: int = 4
## Every scene's first palette closes on RGB 07,07,07 in all three dumps, which
## is what identifies the run.
const CREDITS_PALETTE_LAST_COLOR: int = 0x1CE7

## Long enough for either script and either longest string; one that reaches
## these has not terminated.
const CREDITS_SCRIPT_MAX_BYTES: int = 1024
const CREDITS_STRING_MAX_BYTES: int = 64

## The intro movie (`CrystalIntro`, engine/movie/intro.asm).
## Every graphic, tilemap, attrmap and palette the movie draws is one contiguous
## section behind the code, in the INCBIN order below, and each entry starts on a
## sixteen-byte boundary from the first. So one pinned offset walks all
## thirty-five: decompress an entry, round its length up to
## [constant INTRO_ENTRY_ALIGN], and that is where the next one starts.
const INTRO_ENTRY_ALIGN: int = 16
## `IntroScene28`'s own count, which the movie ends on.
const INTRO_SCENES: int = 28
## The tilemaps and attrmaps are whole 32x32 BG maps, not screens.
const INTRO_MAP_COLUMNS: int = 32
const INTRO_MAP_ROWS: int = 32
const INTRO_MAP_BYTES: int = INTRO_MAP_COLUMNS * INTRO_MAP_ROWS
## Every `ld bc, 16 palettes` the movie copies into `wBGPals1`/`wBGPals2`.
const INTRO_PALETTES: int = 16
const INTRO_PALETTE_COLORS: int = 4
## `Intro_Scene24_ApplyPaletteFade.FadePals` (gfx/intro/fade.pal): eight
## palettes, one of which is copied over all eight BG palettes at a time.
const INTRO_FADE_PALETTES: int = 8
## `Intro_Scene20_AppearUnown`'s `.pal1` and `.pal2`, one palette each and
## contiguous, so the first pins the second.
const INTRO_UNOWN_PALETTES: int = 2
## The section's entries, as (cache name, kind, tiles). `map` is a 32x32 BG map,
## `attr` its attribute plane, `pal` a raw [constant INTRO_PALETTES] run and
## `raw` uncompressed tiles; everything else is an LZ tile strip of that many
## tiles. The order is `engine/movie/intro.asm`'s own INCBIN order and is what
## the walk depends on.
const INTRO_SECTION: Array[Array] = [
	["suicune_run", "lz", 192],
	["pichu_wooper", "lz", 128],
	["background", "lz", 128],
	["background_map", "map", 0],
	["background_attr", "attr", 0],
	["background_palette", "pal", 0],
	["unowns", "lz", 128],
	["pulse", "lz", 16],
	["unown_a_map", "map", 0],
	["unown_a_attr", "attr", 0],
	["unown_hi_map", "map", 0],
	["unown_hi_attr", "attr", 0],
	["unowns_map", "map", 0],
	["unowns_attr", "attr", 0],
	["unowns_palette", "pal", 0],
	["crystal_unowns", "lz", 32],
	["crystal_unowns_map", "map", 0],
	["crystal_unowns_attr", "attr", 0],
	["crystal_unowns_palette", "pal", 0],
	["suicune_close", "lz", 256],
	["suicune_close_map", "map", 0],
	["suicune_close_attr", "attr", 0],
	["suicune_close_palette", "pal", 0],
	["suicune_jump", "lz", 128],
	["suicune_back", "lz", 128],
	["suicune_jump_map", "map", 0],
	["suicune_jump_attr", "attr", 0],
	["suicune_back_map", "map", 0],
	["suicune_back_attr", "attr", 0],
	["suicune_palette", "pal", 0],
	["unown_back", "lz", 48],
	["grass_1", "raw", 4],
	["grass_2", "raw", 4],
	["grass_3", "raw", 4],
	["grass_4", "raw", 1],
]
## `Intro_RustleGrass` swaps four tiles at `vTiles2 tile $09` between three of
## the grass strips; `IntroScene15` and `IntroScene19` load the fourth as a
## single sprite tile.
const INTRO_GRASS_FIRST_TILE: int = 0x09
## The blank the two Suicune scenes park in the sprite tile the dict points at.
const INTRO_GRASS_BLANK: String = "grass_4"

## `GoldSilverIntro` (pokegold/engine/movie/intro.asm), where Crystal runs
## `CrystalIntro`: seventeen scenes over water, grass and fire rather than
## twenty-eight over Unown and Suicune. Its art section is Crystal's shape,
## contiguous and [constant INTRO_ENTRY_ALIGN]-aligned, so one pinned address
## walks all eleven. The names are pret's, which is also the INCBIN order the
## walk depends on: `1` goes to `vTiles2`, `2` to `vTiles0`, `fire2` to `vTiles1`.
const GS_INTRO_SCENES: int = 17
const GS_INTRO_SECTION: Array[Array] = [
	["water1", "lz", 128],
	["water_tilemap", "raw_bytes", 512],
	["water_meta", "raw_bytes", 272],
	["water2", "lz", 128],
	["grass1", "lz", 48],
	["grass_tilemap", "raw_bytes", 256],
	["grass_meta", "raw_bytes", 112],
	["grass2", "lz", 144],
	["fire1", "lz", 128],
	["fire2", "lz", 80],
	["fire3", "lz", 100],
]
## `Intro_DrawBackground` reads a 16-wide map of 2x2 metatiles through
## `Intro_Draw2x2Tiles`, which looks each byte up in the `.bin` four bytes at a
## time. `TILEMAP_WIDTH` is 32 (constants/hardware.inc), so a full draw is
## sixteen metatiles across and sixteen down, filling the whole BG map rather
## than the twenty visible columns.
const GS_INTRO_META_COLUMNS: int = 16
const GS_INTRO_META_BYTES: int = 4
## `ld de, Intro_WaterTilemap + 15 tiles`: the water scene starts fifteen
## metatile rows down its own map and scrolls up towards the surface, while the
## grass scene starts at its map's first row.
const GS_INTRO_WATER_FIRST_ROW: int = 15

## `Intro_LoadMagikarpPalettes`' inline `.MagikarpBGPal` and `.MagikarpOBPal`,
## and `_CGB_GSIntro.ShellderLaprasScene`'s `gfx/intro/shellder_lapras_bg.pal`
## and `_ob.pal`. Each pair is contiguous, so one pinned address per pair walks
## both; the object run is two palettes and every other one is a single palette.
const GS_INTRO_MAGIKARP_PALETTES: int = 2
const GS_INTRO_SHELLDER_LAPRAS_PALETTES: int = 3

## `PREDEFPAL_BLACKOUT`, which is what `_CGB_BattleGrayscale` fills every
## background and object palette with. Despite the name it is not black: $7FFF,
## $1CE7, $0C62, $0000, the grayscale ramp the whole battle is drawn in until
## `GetSGBLayout SCGB_BATTLE_COLORS` runs after `BattleIntroSlidingPics`.
## Below it, `_CGB_MoveList`'s own background palette, and `_UnownPuzzle`'s art as
## (cache name, kind, tiles) in the routine's own INCBIN order, which is what the
## walk depends on. `tile_borders` is pinned separately because thirty-four bytes
## of code sit inside that data.
const UNOWN_PUZZLE_SECTION: Array[Array] = [
	["cursor", "raw", 4],
	["start_cancel", "lz", 19],
	["hooh", "lz", 36],
	["aerodactyl", "lz", 36],
	["kabuto", "lz", 36],
	["omanyte", "lz", 36],
]
## `LoadUnownPuzzlePiecesGFX.LZPointers` in `UNOWNPUZZLE_*` order, which is what
## the map's own `setval` in front of the special names. `maskbits
## NUM_UNOWN_PUZZLES` is what bounds it, so the operand is taken modulo four.
const UNOWN_PUZZLE_PICTURES: Array[String] = [
	"kabuto", "omanyte", "aerodactyl", "hooh",
]
## A puzzle picture's side in tiles before `ConvertLoadedPuzzlePieces` doubles it.
const UNOWN_PUZZLE_PICTURE_TILES: int = 6
## `PuzzlePieceBorderData.TileBordersGFX`, the eight tiles
## `UnownPuzzle_AddPuzzlePieceBorders` ORs onto every piece's outer eight.
const UNOWN_PUZZLE_BORDER_TILES: int = 8
## `PREDEFPAL_UNOWN_PUZZLE`, which `_CGB_UnownPuzzle` writes to all four
## background palettes and to object palette 0.
const PREDEFPAL_UNOWN_PUZZLE: int = 0x4C


## `PlaceDiplomaOnScreen`'s art (`engine/events/diploma.asm`): `DiplomaGFX` is
## one LZ strip and the two tilemaps behind it are whole screens of tile
## numbers, uncompressed and laid out in the file's own order. Identical on all
## three cartridges. `MysteryGiftItems` and `MysteryGiftDecos`, which are the
## same length and sit next to each other in both pins: thirty-seven rows each,
## and an index past either end is `MysteryGiftFallbackItem`.
const MYSTERY_GIFT_TABLE_ROWS: int = 37
## `LoadMysteryGiftBackgroundGFX`'s `ld bc, wBGMapBufferEnd - wBGMapBuffer`: 120
## 1bpp bytes, which `FarCopyBytesDouble` turns into fifteen tiles whose second
## plane is then filled with $ff. Gold and Silver only.
const MYSTERY_GIFT_BACKGROUND_BYTES: int = 0x78
## `LoadMysteryGiftGFX2`'s own `ld bc, 14 tiles`. Gold and Silver only.
const MYSTERY_GIFT_GFX2_TILES: int = 14
## The four colours of a `.pal` include, which is what `_CGB_MysteryGift` copies
## straight into `wBGPals1`.
const MYSTERY_GIFT_PALETTE_COLORS: int = 4

const DIPLOMA_TILES: int = 112
const DIPLOMA_TILEMAP_BYTES: int = 360


## `LinkCommsBorderGFX`, the trade screen's own border, and the tilemaps behind
## it. The two cartridges draw the same screen out of very different amounts of
## data: Gold and Silver load nine tiles and let `PlaceTradeScreenTextbox` draw
## two ordinary boxes, while Crystal loads seventy and lays a whole screen down
## from `MobileTradeBorderTilemap` with the two cable rows over its top and
## bottom. `_LinkTextbox`'s eight corner and edge tiles are `$30` to `$37` of
## Crystal's block, which is what is copied to `$76` when only the box is wanted.
const LINK_BORDER_TILES_CRYSTAL: int = 70
const LINK_BORDER_TILES_GOLD_SILVER: int = 9
## `_LinkTextbox`'s `$30`, the first of the eight tiles it draws a box from.
const LINK_TEXTBOX_FIRST_TILE: int = 0x30
const LINK_TEXTBOX_TILES: int = 8
## `MobileTradeBorderTilemap` is a whole screen; the two cable strips are two
## rows each.
const LINK_TRADE_TILEMAP_BYTES: int = 360
const LINK_TRADE_CABLE_ROWS_BYTES: int = 40

## `PalPacket_Diploma`'s first entry, and the only one the page is drawn in:
## `_CGB_Unused0D` is SCGB_DIPLOMA's own layout and its `WipeAttrmap` puts every
## cell on palette 0.
const PREDEFPAL_DIPLOMA: int = 0x1B

## The `lb bc` each `TradeAnim_CopyBoxFromDEtoHL` is given.
const TRADE_ANIM_GAME_BOY_SIZE: Vector2i = Vector2i(6, 8)
const TRADE_ANIM_LINK_CABLE_SIZE: Vector2i = Vector2i(12, 3)
const TRADE_ANIM_GAME_BOY_CELLS: int = 48
const TRADE_ANIM_LINK_CABLE_CELLS: int = 36

## `TradeAnimation`'s art (engine/movie/trade_animation.asm): nine INCBINs end to
## end with no alignment, so one pinned address walks the lot, each entry's own
## length being where the next begins. `game_boy_cable` is `game_boy.2bpp` and
## `link_cable.2bpp` concatenated by the Makefile. `cable` is two tiles and not
## the four `LoadTradeBallAndCableGFX` asks for: that request runs on into
## `bubble`, and nothing draws what it took, the bulge naming only tile one.
const TRADE_ANIM_SECTION: Array[Array] = [
	["game_boy_tilemap", "map", TRADE_ANIM_GAME_BOY_CELLS],
	["link_cable_tilemap", "map", TRADE_ANIM_LINK_CABLE_CELLS],
	["arrow_right", "raw", 1],
	["arrow_left", "raw", 1],
	["cable", "raw", 2],
	["bubble", "raw", 4],
	["game_boy_cable", "lz", 49],
	["ball", "raw", 6],
	["poof", "raw", 12],
]
## `ld de, vTiles2 tile $31`, and what the run decompresses to.
const TRADE_ANIM_SHEET_FIRST_TILE: int = 0x31
const TRADE_ANIM_SHEET_TILES: int = 49
## Character codes whose font tile the layout overwrites with an arrow sheet.
const TRADE_ANIM_RIGHT_ARROW_CODE: int = 0xED
const TRADE_ANIM_LEFT_ARROW_CODE: int = 0xEE
## `PalPacket_TradeTube`'s first entry, and object palette 7 as well.
const PREDEFPAL_TRADE_TUBE: int = 0x1C

## `PrinterStatusStringPointers`' eight strings in table order, by the status
## each names. `null` is the empty string a status of zero prints, which is what
## `PlacePrinterStatusString` returns early on rather than drawing.
const PRINTER_STATUS_STRINGS: Array[String] = [
	"null", "checking_link", "transmitting", "printing",
	"error_1", "error_2", "error_3", "error_4",
]

## `_UnownPrinter`'s two `Request1bpp` glyphs, which the menu prints as `♂` and
## `♀`: a bold A for PRINT and a bold B for CANCEL.
const UNOWN_PRINTER_GLYPH_TILES: int = 2

## `MagnetTrainBGTiles`, a 2x18 strip `DrawMagnetTrain.FillAlt` repeats across
## the BG map, and `MagnetTrainTilemap`, the 20x4 train over it. Both name tiles
## of `TILESET_TRAIN_STATION`, which is in VRAM at every call site.
const MAGNET_TRAIN_BG_COLUMNS: int = 2
const MAGNET_TRAIN_BG_ROWS: int = 18
const MAGNET_TRAIN_BG_BYTES: int = MAGNET_TRAIN_BG_COLUMNS * MAGNET_TRAIN_BG_ROWS
const MAGNET_TRAIN_FG_COLUMNS: int = 20
const MAGNET_TRAIN_FG_ROWS: int = 4
const MAGNET_TRAIN_FG_BYTES: int = MAGNET_TRAIN_FG_COLUMNS * MAGNET_TRAIN_FG_ROWS
## `hlbgcoord 0, 6`.
const MAGNET_TRAIN_FG_ROW: int = 6


## `_SlotMachine`'s own data run (engine/games/slot_machine.asm), as
## (cache name, kind, size). `strip` is a raw byte run of that many bytes and
## `lz` a compressed one of that many tiles. `Reel1Tilemap` pins the lot: the
## three reel strips, `SlotsTilemap` and the three LZ runs are laid out in that
## order with nothing between them, so every entry landing on its own size is
## what says the address is right.
const SLOTS_SECTION: Array[Array] = [
	["reels", "strip", 3 * SLOTS_REEL_STRIP],
	["tilemap", "strip", SLOTS_TILEMAP_BYTES],
	["slots_1", "lz", 37],
	["slots_2", "lz", 64],
	["slots_3", "lz", 64],
]
## `REEL_SIZE` is fifteen, and each strip carries its first three symbols again
## behind them so a three-symbol window never has to wrap.
const SLOTS_REEL_SIZE: int = 15
const SLOTS_REEL_STRIP: int = SLOTS_REEL_SIZE + 3
## `SlotsTilemap` covers the top twelve rows; the six below it are the text box.
const SLOTS_TILEMAP_ROWS: int = 12
const SLOTS_TILEMAP_COLUMNS: int = 20
const SLOTS_TILEMAP_BYTES: int = SLOTS_TILEMAP_ROWS * SLOTS_TILEMAP_COLUMNS
## `SlotMachinePals` (gfx/slots/slots.pal), the sixteen `_CGB_SlotMachine`
## copies straight into `wBGPals1`: eight background palettes and the eight
## object ones behind them.
const SLOTS_PALETTES: int = 16
## `Slots_AskBet`, `Slots_AskPlayAgain` and `Slots_PayoutText`, each a run of
## `text_far` stubs laid out together at the end of its own routine. Byte
## identical on all three cartridges.
const SLOTS_BET_TEXT_ORDER: Array[String] = [
	"bet_how_many", "start", "not_enough_coins",
]
const SLOTS_PLAY_AGAIN_TEXT_ORDER: Array[String] = ["ran_out_of_coins", "play_again"]
const SLOTS_RESULT_TEXT_ORDER: Array[String] = ["lined_up", "darn"]
## Which pin each name is walked from, the way `DAY_CARE_TEXT_RUNS` does it.
const SLOTS_TEXT_RUNS: Array = [
	["slots_bet_text", SLOTS_BET_TEXT_ORDER],
	["slots_play_again_text", SLOTS_PLAY_AGAIN_TEXT_ORDER],
	["slots_result_text", SLOTS_RESULT_TEXT_ORDER],
]


## `_CardFlip`'s own art run (engine/games/card_flip.asm), as (cache name, kind,
## tiles). The order is the routine's own INCBIN order and the walk is what pins
## it: `.palettes` sits nine palettes in front of `CardFlipLZ03` and
## `CardFlipTilemap` behind `CardFlipLZ02`, so five entries landing on their own
## sizes puts the walk on the tilemap's independently found address. `off` and
## `on` are the two light bulbs `_CardFlip` copies over the font's own gender
## signs, which is why `CARD_FLIP_LIGHT_OFF_TILE` is a character code.
const CARD_FLIP_SECTION: Array[Array] = [
	["card_flip_3", "lz", 7],
	["card_flip_off", "raw", 1],
	["card_flip_on", "raw", 1],
	["card_flip_1", "lz", 62],
	["card_flip_2", "lz", 52],
]
## `CardFlipTilemap`, which `CardFlip_InitTilemap` places at `hlcoord 9, 0` as
## `lb bc, 12, 11`: twelve rows of eleven columns.
const CARD_FLIP_TILEMAP_ROWS: int = 12
const CARD_FLIP_TILEMAP_COLUMNS: int = 11
const CARD_FLIP_TILEMAP_AT_COLUMN: int = 9
const CARD_FLIP_TILEMAP_BYTES: int = CARD_FLIP_TILEMAP_ROWS * CARD_FLIP_TILEMAP_COLUMNS
## `gfx/card_flip/card_flip.pal`, the nine `CardFlip_InitAttrPals` copies into
## `wBGPals1`. Only the first five are ever selected by an attrmap cell; the
## three duplicates and the red one behind them are copied all the same.
const CARD_FLIP_PALETTES: int = 9
## `CARDFLIP_LIGHT_OFF` and `CARDFLIP_LIGHT_ON`, which are the character codes
## for "\u2642" and "\u2640": `_CardFlip` copies its two bulbs over those two
## glyphs, so a lamp is a font cell and not one of the sheets.
const CARD_FLIP_LIGHT_OFF_TILE: int = 0xEF
const CARD_FLIP_LIGHT_ON_TILE: int = 0xF5
## `_CardFlipPlayWithThreeCoinsText` and the seven behind it, one contiguous run
## in `data/text/common_3.asm`. The stubs inside the routine are scattered, so
## the run itself is what is pinned and walked.
const CARD_FLIP_TEXT_ORDER: Array[String] = [
	"play_with_three_coins", "not_enough_coins", "choose_a_card", "place_your_bet",
	"play_again", "shuffled", "yeah", "darn",
]


const PREDEFPAL_GOLDENROD: int = 0x10
const PREDEFPAL_BLACKOUT: int = 0x1A
const PREDEF_PALETTE_COLORS: int = 4
const PREDEF_PALETTE_SIZE: int = PREDEF_PALETTE_COLORS * PokePalette.COLOR_BYTES


## The offset of one `PredefPals` entry, or -1 for a layout with no pin.
static func predef_palette_offset(layout: Dictionary, index: int) -> int:
	var base: int = int(layout.get("predef_pals", -1))
	return -1 if base < 0 else base + index * PREDEF_PALETTE_SIZE


## `PredefPals` (gfx/sgb/predef.pal), eight bytes an entry. The three the movie
## reads are contiguous, so the run's own base is what locates them, and that
## base is already pinned: `game_freak_presents.object_palette` is
## `PREDEFPAL_GAMEFREAK_LOGO_OB`, index 77 of this table, which is what
## `verify_gs_intro` checks the base against for nothing.
const GS_INTRO_PREDEF_SIZE: int = INTRO_PALETTE_COLORS * PokePalette.COLOR_BYTES
const GS_INTRO_PREDEF: Dictionary = {
	"jigglypuff_pikachu_bg": 56,
	"jigglypuff_pikachu_ob": 57,
	"starters_transition": 58,
	# `PalPacket_Pack + 1` is PACK, ROUTES, ROUTES, ROUTES, and `WipeAttrmap`
	# leaves every tile on palette 0, so PACK is the only one the screen shows.
	"pack": 60,
}
const GS_INTRO_PREDEF_GAMEFREAK_LOGO_OB: int = 77

## `OakRatings` (data/events/pokedex_ratings.asm): nineteen `rating` rows of a
## caught-count threshold, an sfx word and a text pointer, which `FindOakRating`
## walks until the count fits. The five texts around it are located from the
## table rather than pinned again: `engine/events/prof_oaks_pc.asm` lays the
## stubs out as `OakPCText1`, `2` and `3` in front of `OakRating01` and
## `OakPCText4` behind `OakRating19`, each a `text_far` and a `text_end`.
const OAK_RATING_COUNT: int = 19
const OAK_RATING_SIZE: int = 5
const OAK_TEXT_STUB_SIZE: int = 5
## Their order in the run, as offsets in stubs from `OakRating01`.
const OAK_TEXT_STUBS: Dictionary = {
	"ask": -3, "level": -2, "counts": -1, "closed": OAK_RATING_COUNT,
}
## The caught count `FindOakRating`'s last row answers, which is every species.
const OAK_RATING_LAST_THRESHOLD: int = 255
## Long enough for the longest rating; one that reaches it has not terminated.
const OAK_TEXT_MAX_BYTES: int = 256

## `PokemonCenterPC.Jumptable`'s five strings, one contiguous `@`-terminated run
## in the source's own row order, and the six `text_far` stubs the routine's
## own texts sit behind, which follow it at a fixed distance on all three
## cartridges.
const POKECENTER_PC_ROWS: Array[String] = [
	"players_pc", "bills_pc", "oaks_pc", "hall_of_fame", "turn_off",
]
## `PlayersPCMenuData.PlayersPCMenuPointers`' own seven. The run below is the
## order the *strings* are laid down in, which is not the jumptable's:
## `.TurnOff` sits before `.LogOff` while `PLAYERSPCITEM_LOG_OFF` is 5 and
## `PLAYERSPCITEM_TURN_OFF` is 6. `.WhichPC` names the jumptable, so a list entry
## is read through `POKECENTER_PC_PLAYERS_ORDER`.
const POKECENTER_PC_PLAYERS_AT: int = 0x168
const POKECENTER_PC_PLAYERS_ROWS: Array[String] = [
	"withdraw_item", "deposit_item", "toss_item", "mail_box", "decoration",
	"turn_off", "log_off",
]
const POKECENTER_PC_PLAYERS_ORDER: Array[String] = [
	"withdraw_item", "deposit_item", "toss_item", "mail_box", "decoration",
	"log_off", "turn_off",
]
const POKECENTER_PC_ROW_MAX_BYTES: int = 24
## `.WhichPC`: each list is a count, that many row indices and a `-1`. Both
## tables follow their own string run, so the walk that reads the strings is
## what finds them.
const POKECENTER_PC_LISTS: int = 3
const POKECENTER_PC_PLAYERS_LISTS: int = 2
const POKECENTER_PC_LIST_END: int = 0xFF
## Every `text_far` stub the two routines print through, as its own distance
## from the row run. The six the top menu uses are one consecutive block; the
## item PC's eight are scattered through `pokecenter_pc.asm` between the
## submenus that own them, so each is pinned rather than strided.
const POKECENTER_PC_TEXT_AT: Dictionary = {
	"ask_what_do": 0x1D2,
	"how_many_withdraw": 0x256,
	"withdrew": 0x25B,
	"no_room_withdraw": 0x260,
	"no_items": 0x2CD,
	"how_many_deposit": 0x374,
	"deposited": 0x379,
	"no_room_deposit": 0x37E,
	"turn_on": 0x42D,
	"whose": 0x432,
	"bills_pc": 0x437,
	"players_pc": 0x43C,
	"oaks_pc": 0x441,
	"closed": 0x446,
}

## `DecorationAttributes`: one six-byte row per decoration, indexed by the
## `DECO_*` constant itself, so row 0 is the CANCEL entry and each category's
## own id is its PUT IT AWAY row. `DecorationNames` follows the table at
## `DECORATION_NAMES_AT` on all three cartridges; the attribute table is byte
## identical between the two pins and the name run is not, since Gold and Silver
## spell the third console "NINTENDO64".
const DECORATION_COUNT: int = 53
const DECORATION_ATTRIBUTE_SIZE: int = 6
const DECORATION_NAMES_AT: int = 0x13E
const DECORATION_NAME_COUNT: int = 26
## `engine/events/mom_phone.asm`'s own block, pinned at `Mom_GetScriptPointer`'s
## two inline scripts: four `writetext`s and an `end` each, thirteen bytes apart,
## with `MomItems_1` `MOM_ITEMS_AT` behind them and `MomItems_2` five rows past
## that. One address finds all four, and the deltas are the same on all three
## cartridges because the whole block is byte identical bar the item ids.
const MOM_DOLL_SCRIPT_AT: int = 0x0D
const MOM_ITEMS_AT: int = 0x39
const MOM_ITEM_SIZE: int = 8
## `MomItems_1` is what she picks from at random once the balance lands exactly
## on a `MOM_MONEY` boundary; `MomItems_2` is the ladder she walks in order.
const MOM_ITEMS_1_COUNT: int = 5
const MOM_ITEMS_2_COUNT: int = 10
## `constants/misc_constants.asm`' `MOM_MONEY`, the step the trigger balance
## climbs by.
const MOM_MONEY: int = 2300


## `DecorationIDs`, the `DECOFLAG_*` order `GetDecorationID` indexes: forty-five
## decoration ids and the `-1` that ends the run. It is not the id order, because
## the dolls come in front of the big dolls here and behind them there, so it is
## a table rather than a rule. Its own address is pinned per cartridge, since the
## name run in front of it is a different length on Gold and Silver.
const DECORATION_ID_COUNT: int = 45
## `list_start TEXTBOX_INNERW - 1`: seventeen characters and the terminator.
const DECORATION_NAME_MAX_BYTES: int = 18

## Every `text_far` stub `engine/items/mart.asm` prints through, as its distance
## from `MartHowManyText`. `GetMartDialogGroup.MartTextFunctionPointers` is what
## groups them: the rooftop sale reads the standard group, the bargain shop asks
## no quantity, and every other group's sold-out slot is `BuyMenuLoop` rather
## than a text. The deltas are the same on all three cartridges, which ship the
## whole routine byte identical.
const MART_TEXT_AT: Dictionary = {
	"how_many": 0x000,
	"final_price": 0x005,
	"bitter_intro": 0x03C,
	"bitter_how_many": 0x041,
	"bitter_final_price": 0x046,
	"bitter_thanks": 0x04B,
	"bitter_pack_full": 0x050,
	"bitter_no_money": 0x055,
	"bitter_come_again": 0x05A,
	"bargain_intro": 0x05F,
	"bargain_final_price": 0x064,
	"bargain_thanks": 0x069,
	"bargain_pack_full": 0x06E,
	"bargain_sold_out": 0x073,
	"bargain_no_money": 0x078,
	"bargain_come_again": 0x07D,
	"pharmacy_intro": 0x082,
	"pharmacy_how_many": 0x087,
	"pharmacy_final_price": 0x08C,
	"pharmacy_thanks": 0x091,
	"pharmacy_pack_full": 0x096,
	"pharmacy_no_money": 0x09B,
	"pharmacy_come_again": 0x0A0,
	## `SellMenu`'s own four, which sit between the shop groups above and
	## `MartWelcomeText`: `UnusedDummyString`'s six bytes are the gap between
	## `sell_price` and `welcome`.
	"sell_how_many": 0x165,
	"sell_price": 0x16A,
	"welcome": 0x175,
	"thanks": 0x192,
	"no_money": 0x197,
	"pack_full": 0x19C,
	"cant_buy": 0x1A1,
	"come_again": 0x1A6,
	"ask_more": 0x1AB,
	"bought": 0x1B0,
}

## A `text_far` stub is `TX_FAR`, a two-byte address, a bank byte and a
## `text_end`, so a run of them declared together is walked at this stride. The
## two runs below are each one contiguous block, which is what makes one pinned
## address per dump enough for either.
const TEXT_FAR_STUB_BYTES: int = 5

## `engine/events/name_rater.asm`'s ten stubs, in the file's own order, which is
## `_NameRater` reaching them with `.egg` ahead of `.samename`. Byte identical on
## all three cartridges.
const NAME_RATER_TEXT_ORDER: Array[String] = [
	"hello", "which_mon", "better_name", "what_name", "finished",
	"come_again", "perfect_name", "egg", "same_name", "named",
]

## The `text_far` stub runs the routines behind `tools/checks/specials.gd`'s
## deferred list print, by run name, then the layout key and the stub names in
## the file's own order. One table rather than one accessor per routine: a
## routine that gets built adds a row here and needs no importer of its own.
## A run whose layout offset is zero is not on the cartridge. `poke_seer`,
## `seer_advice` and `buena_prize` are Crystal's alone, and Gold and Silver's
## `SpecialsPointers` is short enough that no script of theirs can reach one.
const SPECIAL_TEXT_RUNS: Dictionary = {
	## `engine/events/magikarp.asm`. Two runs of one: the Guru's measuring box
	## sits inside `CheckMagikarpLength` and the record sign's at the file's end.
	"magikarp": [
		["magikarp_measure_text", ["measure"]],
		["magikarp_record_text", ["record"]],
	],
	## `CheckForLuckyNumberWinners`' two, which differ only in where the match
	## was found.
	"lucky_number": [["lucky_number_text", ["match_party", "match_pc"]]],
	## `Elevator_AskWhichFloor`'s one. Not a `special` at all: the elevator is a
	## script command, and the run is here because this table is where a routine
	## reaches its own `text_far` stubs.
	"elevator": [["elevator_text", ["which_floor"]]],
	## `engine/events/print_photo.asm`'s five, in `PhotoStudio`'s own file order.
	"photo_studio": [["photo_studio_text", [
		"which_mon", "hold_still", "presto", "no_photo", "egg",
	]]],
	## `engine/events/mom.asm`'s sixteen, from `MomLeavingText1` to
	## `MomJustDoWhatYouCanText`. `DSTChecks`' own six sit above them in the file
	## and are a separate concern: the clock question is already asked by the
	## two DST specials.
	"bank_of_mom": [["mom_text", [
		"leaving_1", "leaving_2", "leaving_3", "is_this_about_your_money",
		"what_do_you_want_to_do", "store_money", "take_money", "save_money",
		"havent_saved_that_much", "not_enough_room_in_wallet",
		"insufficient_funds_in_wallet", "not_enough_room_in_bank",
		"start_saving_money", "stored_money", "taken_money", "just_do_what_you_can",
	]]],
	## `engine/events/poke_seer.asm`. The stubs are laid out in the file's order
	## rather than `SeerTexts`', which is why `no_location` and `do_nothing` sit
	## the other way round from the table that indexes them.
	"poke_seer": [
		["poke_seer_text", [
			"see_all", "cant_tell_a_thing", "name_location", "time_level",
			"trade", "no_location", "egg", "do_nothing",
		]],
		["seer_advice_text", [
			"more_care", "more_confident", "much_strength", "mighty", "impressed",
		]],
	],
	## `engine/events/battle_tower/rules.asm`'s eight, which are three runs
	## because `BattleTower_PleaseReturnWhenReady`'s own three instructions sit
	## between the first two and `_CheckForBattleTowerRules` between the second
	## and the third. The last run is the mobile challenge's two rules ahead of
	## the local one's four, which is the file's order rather than either
	## routine's table.
	"battle_tower": [
		["battle_tower_excuse_text", ["excuse_me"]],
		["battle_tower_ready_text", ["return_when_ready"]],
		["battle_tower_rule_text", [
			"need_at_least_three", "egg_does_not_qualify",
			"only_three_may_be_entered", "must_all_be_different_kinds",
			"must_not_hold_the_same_items", "you_cant_take_an_egg",
		]],
	],
	## The trade screen's own three, which is every box `LinkTrade` prints that
	## is not an inline `db` string. Three runs of one rather than one of three:
	## `.String_Stats_Trade`'s sixteen bytes sit between the first two stubs and
	## the third is in `LinkTrade` itself, a page further down the file.
	"link": [
		["link_cant_battle_text", ["cant_battle"]],
		["link_abnormal_mon_text", ["abnormal_mon"]],
		["link_ask_trade_text", ["ask_trade"]],
	],
	## `TradeAnimation`'s boxes. Five runs because the stubs live inside the four
	## routines that print them, in the file's order rather than the script's.
	## `_MonNameSentToText` is left out: it is a `text_start` with nothing in it,
	## so it imports as an empty string a decode failure cannot be told from.
	"trade": [
		["trade_sent_text", ["was_sent"]],
		["trade_farewell_text", ["bids_farewell", "name_bids_farewell"]],
		["trade_take_care_text", ["take_good_care"]],
		["trade_sends_text", ["for_your_mon_sends", "ot_sends"]],
		["trade_will_trade_text", ["will_trade", "for_your_mon_will_trade"]],
	],
	## `DoMysteryGift`'s eight, one contiguous run behind
	## `.String_PressAToLink_BToCancel`. Every box the routine can end on is
	## here: the two refusals in front of the gift, the two daily limits, the
	## two the exchange itself fails with, and the two the gift arrives in.
	"mystery_gift": [["mystery_gift_text", [
		"canceled", "comm_error", "retrieve", "friend_not_ready",
		"five_a_day", "one_a_day", "sent", "sent_home",
	]]],
	## `BuenaPrize`'s six, in its own file order.
	"buena_prize": [["buena_prize_text", [
		"ask_which_prize", "is_that_right", "here_you_go", "not_enough_points",
		"no_room", "come_again",
	]]],
	## `NPCTrade`'s own words, which no `special` reaches: `Script_trade` is a
	## `farcall` to it and every line a trader says is inside. Two runs because
	## `TradedForText`'s `text_asm` sits between the pair and the fifteen.
	"npc_trade": [
		["npc_trade_cable_text", ["cable", "traded_for"]],
		["npc_trade_text", TRADE_TEXT_ORDER],
	],
	"npc_trade_newbie": [["npc_trade_newbie_text", TRADE_NEWBIE_TEXTS]],
}

## `engine/events/move_deleter.asm`'s eight, in the file's own order rather than
## the routine's: `MoveDeletion` lays them out between `.onlyonemove` and
## `.DeleteMove`. Byte identical on all three cartridges as well.
const MOVE_DELETER_TEXT_ORDER: Array[String] = [
	"knows_one", "ask_delete", "forgot", "egg", "come_again", "which_move",
	"intro", "which_mon",
]

## The Day-Care's four stub runs. `PrintDayCareText.TextTable` is a pointer
## table, but its twenty stubs are laid out in the file's own order behind it, so
## one pin walks them the way the two runs above are walked; the order below is
## that file order and not the table's. `.NotYetText` sits alone inside
## `DayCareManOutside` and needs a pin of its own. All four runs are byte
## identical on all three cartridges.
const DAY_CARE_TEXT_ORDER: Array[String] = [
	"man_intro", "man_intro_egg", "lady_intro", "lady_intro_egg", "which_one",
	"only_one_mon", "cant_accept_egg", "remove_mail", "last_healthy_mon",
	"ill_raise", "come_back_later", "are_we_geniuses", "has_grown",
	"perfect_heres_your_mon", "got_back", "back_already", "have_no_room",
	"not_enough_money", "oh_fine_then", "come_again",
]
## `DayCareManOutside`'s own five, after `.AskGiveEgg`.
const DAY_CARE_EGG_TEXT_ORDER: Array[String] = [
	"found_an_egg", "received_egg", "take_good_care", "ill_keep_it",
	"no_room_for_egg",
]
## `engine/pokemon/breeding.asm`'s two, the lady's ahead of the man's.
const DAY_CARE_LEFT_WITH_TEXT_ORDER: Array[String] = ["left_with_lady", "left_with_man"]
## `DayCareMonCompatibilityText`'s five, in the order the routine tests them.
const DAY_CARE_COMPATIBILITY_TEXT_ORDER: Array[String] = [
	"brimming_with_energy", "no_interest", "appears_to_care", "friendly",
	"shows_interest",
]
## `NICKNAMED_MON_STRUCT_LENGTH`: a whole Pokemon as a ROM table stores one,
## the 48-byte party-mon struct with its nickname behind it.
## [method Gen2SramAdapter.read_nicknamed_mon] is what reads a row of either
## table that uses it.
const NICKNAMED_MON_BYTES: int = 48 + 11

## `data/events/odd_eggs.asm`, Crystal's alone: `OddEggProbabilities`' fourteen
## cumulative words followed by `OddEggs`' fourteen nicknamed-mon rows. The two
## are one run, so one address reaches both.
const ODD_EGG_COUNT: int = 14
const ODD_EGG_PROBABILITY_BYTES: int = 2
const ODD_EGG_MONS_OFFSET: int = ODD_EGG_COUNT * ODD_EGG_PROBABILITY_BYTES
## `.Odd`, the name `_GiveOddEgg` copies into `wTempOddEggNickname` and then
## hands `AddMobileMonToParty` as the OT. The nickname is the row's own, which
## every row spells EGG.
const ODD_EGG_OT_NAME: String = "ODD"
## Every row's own `dname`, and the level and hatch counter all fourteen share.
const ODD_EGG_NICKNAME: String = "EGG"
const ODD_EGG_LEVEL: int = 5
## `odd_egg_prob`'s last cumulative word: the macro asserts the percentages sum
## to 100, and 100 * $ffff / 100 is $ffff.
const ODD_EGG_PROBABILITY_TOTAL: int = 0xFFFF

## Which pin each name is walked from, and at what index into it.
const DAY_CARE_TEXT_RUNS: Array = [
	["day_care_text", DAY_CARE_TEXT_ORDER],
	["day_care_not_yet_text", ["not_yet"]],
	["day_care_egg_text", DAY_CARE_EGG_TEXT_ORDER],
	["day_care_left_with_text", DAY_CARE_LEFT_WITH_TEXT_ORDER],
	["day_care_compatibility_text", DAY_CARE_COMPATIBILITY_TEXT_ORDER],
]

## `Landmarks` (data/maps/landmarks.asm): `db x + 8, y + 16` then a name pointer,
## so the stored bytes are already shadow-OAM coordinates and the raw x,y are
## screen pixels. Gold and Silver ship no `BATTLE TOWER`, so every landmark from
## it onward is one lower; see [Gen2WorldRadio]'s own constants.
const LANDMARK_RECORD_SIZE: int = 4
const LANDMARK_COUNT: int = 96
const LANDMARK_COUNT_GOLD_SILVER: int = 95
const LANDMARK_OAM_X: int = 8
const LANDMARK_OAM_Y: int = 16
## `GetLandmarkName` copies exactly this many bytes whatever the name's length.
const LANDMARK_NAME_BYTES: int = 18

## The battle animation data layer: the per-move scripts and the four tables the
## objects they spawn are built from. All five are stored as contiguous regions
## rather than entry by entry, each a pointer table followed by the bank-local
## data it points at, so a cached address resolves by subtraction.
## `BattleAnimations` is indexed by move number, so entry 0 is `BattleAnim_Dummy`
## and 1 `BattleAnim_Pound`; entries past [constant MOVE_COUNT] are the four the
## table pads to $100 with and the non-move animations `wFXAnimID`'s high byte
## reaches.
const BATTLE_ANIM_SCRIPT_COUNT: int = 278
const BATTLE_ANIM_OBJECT_COUNT: int = 188
const BATTLE_ANIM_OBJECT_SIZE: int = 6
const BATTLE_ANIM_FRAMESET_COUNT: int = 185
const BATTLE_ANIM_OAM_SET_COUNT: int = 216
const BATTLE_ANIM_OAM_SET_SIZE: int = 4
## `dbsprite`: y, x, tile, attributes.
const BATTLE_ANIM_OAM_SPRITE_SIZE: int = 4
## `AnimObjGFX` is `const_def 1`, so index 0 is a slot no `anim_*gfx` names and
## the table is one longer than [code]NUM_BATTLE_ANIM_GFX[/code].
const BATTLE_ANIM_GFX_COUNT: int = 42
const BATTLE_ANIM_GFX_SIZE: int = 4
## `AnimObjGFX`'s last two rows are `anim_obj_gfx 1, NULL`:
## `BATTLE_ANIM_GFX_PLAYERHEAD` and `..._ENEMYFEET` are written into
## `wBattleAnimTileDict` by `BattleAnimCmd_BattlerGFX_1Row`/`_2Row` off the
## battler's own pic, and are named by no `anim_*gfx` command, so neither row
## has a sheet to decode.
const BATTLE_ANIM_GFX_FIRST_SHEET: int = 1
const BATTLE_ANIM_GFX_LAST_SHEET: int = 39

## `BattleAnimSineWave`, the 32-word table `BattleAnim_Sine` and `..._Cosine`
## multiply an amplitude by (engine/battle_anims/functions.asm). It sits in the
## same bank as the four tables above, immediately before `BattleAnimFrameData`.
const BATTLE_ANIM_SINE_SAMPLES: int = 32
const BATTLE_ANIM_SINE_BYTES: int = BATTLE_ANIM_SINE_SAMPLES * 2

## What that table holds, pinned the way [constant BAR_PALETTES] pins the bars'
## colours: the values are the check for the offset. It is `sine_table 32`, which
## rgbasm evaluates at assembly time, and entry 16 is why it is imported rather
## than re-derived: sin(pi/2) is 1.0, which lands on $0100 and not the $00FF an
## eight-bit derivation produces. The same 64 bytes are in all three dumps.
const BATTLE_ANIM_SINE_WAVE: Array[int] = [
	0x00, 0x00, 0x19, 0x00, 0x32, 0x00, 0x4A, 0x00, 0x62, 0x00, 0x79, 0x00, 0x8E, 0x00, 0xA2, 0x00,
	0xB5, 0x00, 0xC6, 0x00, 0xD5, 0x00, 0xE2, 0x00, 0xED, 0x00, 0xF5, 0x00, 0xFB, 0x00, 0xFF, 0x00,
	0x00, 0x01, 0xFF, 0x00, 0xFB, 0x00, 0xF5, 0x00, 0xED, 0x00, 0xE2, 0x00, 0xD5, 0x00, 0xC6, 0x00,
	0xB5, 0x00, 0xA2, 0x00, 0x8E, 0x00, 0x79, 0x00, 0x62, 0x00, 0x4A, 0x00, 0x32, 0x00, 0x19, 0x00,
]

## The eight `PAL_BATTLE_OB_*` object palettes an animation object's palette byte
## indexes, and which of them the cartridge stores.
## Only six are stored. `_CGB_BattleScreenLayout` (engine/gfx/cgb_layouts.asm)
## copies `BattleObjectPals` into `wOBPals1` from slot 2 on, four colours each,
## and fills slots 0 and 1 from the two battlers' own two-colour palettes through
## `LoadPalette_White_Col1_Col2_Black`, so `PAL_BATTLE_OB_ENEMY` and
## `PAL_BATTLE_OB_PLAYER` are whoever is on the field rather than table rows.
const BATTLE_OBJECT_PALETTE_COUNT: int = 8
const BATTLE_OBJECT_PALETTE_FIRST_STORED: int = 2
const BATTLE_OBJECT_PALETTES_STORED: int = 6
const BATTLE_OBJECT_PALETTE_COLORS: int = 4

## The names the cache keys them by, in the cartridge's own order from
## `PAL_BATTLE_OB_GRAY` on (constants/battle_anim_constants.asm).
const BATTLE_OBJECT_PALETTE_NAMES: Array = [
	"gray", "yellow", "red", "green", "blue", "brown",
]

## What those palettes hold, the way [constant BAR_PALETTES] pins the bars':
## content known independently of the offset, so the values are the check.
## `gfx/battle_anims/battle_anims.pal`, as packed 15-bit colours.
const BATTLE_OBJECT_PALETTES: Array = [
	[0x7FFF, 0x6739, 0x35AD, 0x0000],
	[0x7FFF, 0x1FFF, 0x061F, 0x0000],
	[0x7FFF, 0x627F, 0x195E, 0x0000],
	[0x7FFF, 0x072C, 0x01C5, 0x0000],
	[0x7FFF, 0x7D88, 0x7C81, 0x0000],
	[0x7FFF, 0x1E58, 0x0DF4, 0x0000],
]

## The four palettes a battle draws its bars with: the HP bar in green, yellow
## or red depending on how much is left, and the exp bar in blue. They are two
## colours each like a species' palette, white and black being implied, and they
## sit immediately before the species palettes in every game.
## The names are the cache's keys, and the order is the cartridge's.
const BAR_PALETTE_NAMES: Array = ["hp_green", "hp_yellow", "hp_red", "exp"]

## What those palettes hold. This is content whose value is known independently,
## like the first species name, so the check for the offset is the values
## themselves: every bar shares a light colour and differs in the dark one.
const BAR_PALETTES: Array = [
	[0x3F5E, 0x02E0], [0x3F5E, 0x02BF], [0x3F5E, 0x001F], [0x3F5E, 0x7E24],
]

## `StatsScreenPagePals` (gfx/stats/pages.pal) and `StatsScreenPals`
## (gfx/stats/stats.pal), one contiguous run: three whole four-colour palettes
## the stats screen's three page indicators wear, then the three single colours
## `LoadStatsScreenPals` writes over colour 0 of `wBGPals1` palettes 0 and 2, so
## the open page tints the whole lower screen and the exp bar's trough.
## The two labels are read as one record because the second follows the first
## with nothing between it, which is what locates both from one pin.
const STATS_PAGE_PALETTES: int = 3
const STATS_PAGE_PALETTE_COLORS: int = 4
const STATS_PAGE_TINTS_OFFSET: int = (
	STATS_PAGE_PALETTES * STATS_PAGE_PALETTE_COLORS * PokePalette.COLOR_BYTES
)

## What that run holds, the way [constant BAR_PALETTES] pins the bars': pink,
## green and blue, identical in all three dumps.
const STATS_SCREEN_PAGE_PALETTES: Array = [
	[0x7FFF, 0x7E7F, 0x7DFF, 0x0000],
	[0x7FFF, 0x3BF5, 0x03F1, 0x0000],
	[0x7FFF, 0x7FF1, 0x7FF1, 0x0000],
]
const STATS_SCREEN_PAGE_TINTS: Array = [0x7E7F, 0x3BF5, 0x7FF1]


## The offset of one `StatsScreenPagePals` entry, or -1 for a layout with no pin.
static func stats_page_palette_offset(layout: Dictionary, index: int) -> int:
	var base: int = int(layout.get("stats_screen_palettes", -1))
	return -1 if base < 0 else base \
		+ index * STATS_PAGE_PALETTE_COLORS * PokePalette.COLOR_BYTES


## The offset of one `StatsScreenPals` colour, or -1 for a layout with no pin.
static func stats_page_tint_offset(layout: Dictionary, index: int) -> int:
	var base: int = int(layout.get("stats_screen_palettes", -1))
	return -1 if base < 0 else base + STATS_PAGE_TINTS_OFFSET \
		+ index * PokePalette.COLOR_BYTES


## An HP bar is green down to half and yellow down to a fifth, measured in lit
## pixels rather than in hit points: what colours the bar is what is drawn.
const HP_GREEN_PIXELS: int = 24
const HP_YELLOW_PIXELS: int = 10

## The HP bar's fill levels within [constant BATTLE_FONT_TILES], and the exp
## bar's within its own strip. Each step lights one more column, which is two
## more pixels than the step before, and that progression is what proves the
## offset: nothing else in the section counts up like this.
const HP_BAR_FIRST_TILE: int = 2
const HP_BAR_LEVELS: int = 9
const EXP_BAR_LEVELS: int = 7
const BAR_STEP_PIXELS: int = 2

## Trainer classes are numbered from 1; class 0 is the player, who has a palette
## in the table but no pic in it. Crystal added one class to the sixty-six Gold
## and Silver have, so the count lives in the layout rather than here.
## Every trainer pic is this square, unlike a Pokémon's front pic.
const TRAINER_PIC_TILES: int = 7

## A second table indexed like the class names, pics and palettes, one pointer
## per class, holding the individual trainers. "LEADER" is the class name every
## gym leader shares; FALKNER is stored inside class 1's party entry beside the
## Pokémon he brings, so a class's identity always means reading two tables.
## Two-byte pointers in the pointer table's own bank, like [member evos_attacks]:
## the entries share that bank, so there is no bank number to store.
const TRAINER_PARTY_POINTER_SIZE: int = 2

## What a trainer's Pokémon carries, in the type byte between its name and its
## first Pokémon. The low bit says whether it holds an item, the high bit
## whether it knows chosen moves rather than whatever its level teaches it.
const TRAINER_MON_NORMAL: int = 0
const TRAINER_MON_MOVES: int = 1
const TRAINER_MON_ITEM: int = 2
const TRAINER_MON_ITEM_MOVES: int = 3
const TRAINER_MON_TYPES: Array = [
	TRAINER_MON_NORMAL, TRAINER_MON_MOVES, TRAINER_MON_ITEM, TRAINER_MON_ITEM_MOVES,
]

## How many move slots a stored-moves Pokémon carries in the table, whatever a
## zero slot in it means: nothing, the way [Gen2BattleMon] treats one.
const TRAINER_MON_MOVE_COUNT: int = 4

## One trainer's Pokémon list ends here; so does a class's whole party group, but
## the two terminators are not read the same way. A Pokémon's own end is read
## for real; a group's is only reached by the *next* class's pointer, because
## nothing marks a group's end from inside it. See [constant EMPTY_TRAINER_CLASS].
const TRAINER_PARTY_END: int = 0xFF

## What a trainer can carry. Six is the real maximum in all three games, not a
## rule this layout invents.
const MAX_TRAINER_PARTY_SIZE: int = 6

## Runaway guard for a single class's trainers, well past the real maximum of 31
## (the wandering trainer classes: YOUNGSTER, LASS and the like carry the most).
const MAX_TRAINERS_PER_CLASS: int = 64

## The trainer *attributes* table: a third table indexed the same way as the
## class names, pics, palettes and parties, one fixed-stride entry per class
## rather than a pointer, and it is where a class's own AI behaviour lives.
## Seven bytes: two item numbers this class may use, a base money reward, then
## two words of bit flags. Confirmed against `TrainerClassAttributes` entry by
## entry: Falkner opens with his listed bytes, class 5 (Pryce) is the first to
## differ with a Hyper Potion, and one class carries an AI move weight word of
## zero ([constant NO_AI]), which the check must allow rather than reject.
const TRAINER_ATTRIBUTES_SIZE: int = 7
const ATTR_ITEM1: int = 0
const ATTR_ITEM2: int = 1
const ATTR_BASE_REWARD: int = 2
const ATTR_AI_MOVE_WEIGHTS: int = 3
const ATTR_AI_ITEM_SWITCH: int = 5

## Which of a move's scoring routines run, as a bitfield: [constant AI_BASIC]
## always runs when any bit is set, and the rest layer their own nudges on top
## of it. A class can carry none of them ([constant NO_AI]), which is not a
## decoding failure: Twins are really that undiscerning on the cartridge.
const AI_BASIC: int = 1 << 0
const AI_SETUP: int = 1 << 1
const AI_TYPES: int = 1 << 2
const AI_OFFENSIVE: int = 1 << 3
const AI_SMART: int = 1 << 4
const AI_OPPORTUNIST: int = 1 << 5
const AI_AGGRESSIVE: int = 1 << 6
const AI_CAUTIOUS: int = 1 << 7
const AI_STATUS: int = 1 << 8
const AI_RISKY: int = 1 << 9
const NO_AI: int = 0

## Every bit [constant ATTR_AI_MOVE_WEIGHTS] can legally carry. A wrong offset
## reading this word as something else has roughly a 1.5% chance of landing
## inside this mask by accident, and has to do it 66 or 67 times running.
const AI_MOVE_WEIGHTS_MASK: int = AI_BASIC | AI_SETUP | AI_TYPES | AI_OFFENSIVE \
	| AI_SMART | AI_OPPORTUNIST | AI_AGGRESSIVE | AI_CAUTIOUS | AI_STATUS | AI_RISKY

## How a class uses its held items and when it switches out. Bit 3 is skipped
## in the cartridge's own numbering (`const_skip` in pret's source), which is
## why the flags jump from [constant SWITCH_SOMETIMES] to [constant ALWAYS_USE].
const SWITCH_OFTEN: int = 1 << 0
const SWITCH_RARELY: int = 1 << 1
const SWITCH_SOMETIMES: int = 1 << 2
const ALWAYS_USE: int = 1 << 4
const UNKNOWN_USE: int = 1 << 5
const CONTEXT_USE: int = 1 << 6

## Every bit [constant ATTR_AI_ITEM_SWITCH] can legally carry, bit 3 excluded.
const AI_ITEM_SWITCH_MASK: int = SWITCH_OFTEN | SWITCH_RARELY | SWITCH_SOMETIMES \
	| ALWAYS_USE | UNKNOWN_USE | CONTEXT_USE

## The trainer *DVs* table: a fifth trainer table, indexed the same way as the
## attributes table, one fixed two-byte entry per class rather than a pointer.
## Two nibbles a byte, attack and defense in the first, speed and special in the
## second: exactly the shape [method Gen2Stats.pack_dvs] packs into, so a class's
## two raw bytes read big-endian are a [Gen2BattleMon] DV word unchanged.
## Confirmed against `TrainerClassDVs` entry by entry in all three games, with
## Falkner opening the table and the closing class (66 in Gold and Silver, 67 in
## Crystal, which alone carries MYSTICALMAN) carrying its own.
const TRAINER_DVS_SIZE: int = 2

## The one trainer class with no party: Professor Elm's class, whose name and pic
## exist but who is never sent into battle. Its source label is followed
## immediately by the next class's, so its pointer equals that one, and the
## honest reading is zero trainers rather than a copy. Confirmed against pret's
## party data (`PokemonProfGroup` has no entries before `WillGroup`), same class
## number in every game.
const EMPTY_TRAINER_CLASS: int = 10

## Back pics are always this square. Front pics vary and carry their own size in
## the base stats.
const BACKPIC_TILES: int = 6
## The battle screen's frontpic window, and so the atlas cell size.
const FRONTPIC_MAX_TILES: int = 7

## `EGG` is a party species rather than a Pokemon: `PokemonPicPointers` and
## `PokemonPalettes` both carry an entry for it past the 251, and nothing else
## in either table does.
const EGG_SPECIES: int = 0xFD
## `gfx/pokemon/egg/front.animated.2bpp`, five tiles square like the smallest
## front pics.
const EGG_PIC_TILES: int = 5

## Byte positions within a 32-byte base stats entry.
const STAT_HP: int = 1
const STAT_ATTACK: int = 2
const STAT_DEFENSE: int = 3
const STAT_SPEED: int = 4
const STAT_SP_ATTACK: int = 5
const STAT_SP_DEFENSE: int = 6
const OFFSET_TYPE1: int = 7
const OFFSET_TYPE2: int = 8
const OFFSET_CATCH_RATE: int = 9
const OFFSET_BASE_EXP: int = 10
const OFFSET_ITEM1: int = 11
const OFFSET_ITEM2: int = 12
const OFFSET_GENDER_RATIO: int = 13
const OFFSET_HATCH_CYCLES: int = 15
## Packed nibbles: width in the low half, height in the high half, in tiles.
const OFFSET_PIC_SIZE: int = 17
const OFFSET_GROWTH_RATE: int = 22
## Packed nibbles, one egg group per half.
const OFFSET_EGG_GROUPS: int = 23
const OFFSET_TMHM: int = 24
## Eight bytes of learnable flags, one bit per TM/HM/tutor number, indexed by the
## entry's own zero-based place in TMHMMoves. Sixty-four bits for sixty numbers,
## so the top four are always clear.
const TMHM_BYTES: int = 8

## data/moves/tmhm_moves.asm's TMHMMoves: fifty TMs, then seven HMs, then
## Crystal's three move tutors, then a zero terminator. Indexed by TMNUM, which
## is one-based, so entry n-1 is TM/HM number n. The first fifty-seven bytes are
## identical between the pins; only Crystal's tutor rows follow.
const TMHM_TM_COUNT: int = 50
const TMHM_HM_COUNT: int = 7
## data/events/happiness_changes.asm's HappinessChanges, one row per HAPPINESS_*
## constant and three signed bytes a row: the change below 100, the change below
## 200 and the change above it. `ChangeHappiness` takes its argument one-based,
## so row n-1 is HAPPINESS_n. Crystal ends on HAPPINESS_GAINLEVELATHOME, which
## pokegold does not ship; the eighteen rows before it are byte identical.
const HAPPINESS_CHANGE_WIDTH: int = 3
const HAPPINESS_CHANGE_COUNT_GOLD_SILVER: int = 18
const HAPPINESS_CHANGE_COUNT: int = 19
## `TeachTMHM`'s own `ld c, HAPPINESS_LEARNMOVE`, one-based the way the source
## passes it. The only row anything here asks for: every other `ChangeHappiness`
## caller is a routine this project does not run.
const HAPPINESS_LEARNMOVE: int = 5
## data/text/name_input_chars.asm's four keyboards, one contiguous block in
## source order with every row 17 bytes wide. The block is byte identical in all
## three dumps, so only its offset is profile split.
const NAME_INPUT_ROW_BYTES: int = 17
## Rows per table, in block order: NameInputLower, BoxNameInputLower,
## NameInputUpper, BoxNameInputUpper. A name keyboard is 5 rows and a box
## keyboard 6, which is the whole of NamingScreen_IsTargetBox's `ld b, $5` /
## `ld b, $6` split.
const NAME_INPUT_TABLE_ROWS: Array[int] = [5, 6, 5, 6]
const NAME_INPUT_BLOCK_BYTES: int = 374
## NamingScreen_GetLastCharacter reads the keyboard by cursor column, and the
## cursor steps two tiles at a time, so a column is every second byte of a row.
const NAME_INPUT_COLUMNS: int = 9
const NAME_INPUT_COLUMN_STRIDE: int = 2
## The letter each keyboard's first row opens with, which is what pins the block.
const NAME_INPUT_LOWER_A: int = 0xA0
const NAME_INPUT_UPPER_A: int = 0x80
## The last row of every table: the case switch, DEL and END, encoded.
const NAME_INPUT_COMMAND_LOWER: Array[int] = [
	0x94, 0x8F, 0x8F, 0x84, 0x91, 0x7F, 0x7F, 0x83, 0x84,
	0x8B, 0x7F, 0x7F, 0x7F, 0x84, 0x8D, 0x83, 0x7F,
]
const NAME_INPUT_COMMAND_UPPER: Array[int] = [
	0xAB, 0xAE, 0xB6, 0xA4, 0xB1, 0x7F, 0x7F, 0x83, 0x84,
	0x8B, 0x7F, 0x7F, 0x7F, 0x84, 0x8D, 0x83, 0x7F,
]

## data/text/mail_input_chars.asm's two keyboards, stored the same way and
## behind their own pin: `_ComposeMailMessage`'s code sits between them and the
## four above, so the block is not walked from `name_input_chars`. A mail row is
## 19 bytes rather than 17 and every table is 6 rows, `.PlaceMailCharset`'s own
## `ld b, 6` over `ld c, SCREEN_WIDTH - 1`.
const MAIL_INPUT_ROW_BYTES: int = 19
const MAIL_INPUT_TABLE_ROWS: int = 6
const MAIL_INPUT_TABLES: int = 2
## `ComposeMail_AnimateCursor.LetterEntries` has ten entries and steps $10, so a
## mail column is every second byte the way a name column is.
const MAIL_INPUT_COLUMNS: int = 10
## The first row of each keyboard, which is what pins the block: "A B C ..." and
## "a b c ...", encoded.
const MAIL_INPUT_UPPER_A: int = 0x80
const MAIL_INPUT_LOWER_A: int = 0xA0
## The command row of each mail keyboard, which is what the other end of the
## block is pinned on. Table 0 is uppercase and its switch says "lower".
const MAIL_INPUT_COMMAND_UPPER: Array[int] = [
	0xAB, 0xAE, 0xB6, 0xA4, 0xB1, 0x7F, 0x7F, 0x83, 0x84, 0x8B,
	0x7F, 0x7F, 0x7F, 0x84, 0x8D, 0x83, 0x7F, 0x7F, 0x7F,
]
const MAIL_INPUT_COMMAND_LOWER: Array[int] = [
	0x94, 0x8F, 0x8F, 0x84, 0x91, 0x7F, 0x7F, 0x83, 0x84, 0x8B,
	0x7F, 0x7F, 0x7F, 0x84, 0x8D, 0x83, 0x7F, 0x7F, 0x7F,
]

## constants/item_data_constants.asm's mail block. `MAIL_STRUCT_LENGTH` is $2f:
## two lines, the `<NEXT>` between them, the author, a nationality word, the
## author's ID, the species and the mail type.
const MAIL_LINE_LENGTH: int = 0x10
const MAIL_MSG_LENGTH: int = 2 * MAIL_LINE_LENGTH
const MAILBOX_CAPACITY: int = 10
const MAIL_STRUCT_LENGTH: int = 0x2F
## `PLAYER_NAME_LENGTH`, the field's own width. Both writers copy
## `NAME_LENGTH - 1` bytes into it, so the two bytes of `Nationality` behind it
## carry the tail of the name and no nationality; see [Gen2SaveMail].
const MAIL_AUTHOR_FIELD: int = 8
const MAIL_AUTHOR_LENGTH: int = 10

## `MailItems`, ten numbers and the -1 behind them.
const MAIL_ITEM_COUNT: int = 10
const MAIL_ITEM_END: int = 0xFF
## `MailGFXPointers` order, which is also `LoadMailPalettes.MailPals`': the
## *MAIL_INDEX constants at the head of engine/pokemon/mail_2.asm.
const MAIL_PALETTE_COUNT: int = 10
const MAIL_PALETTE_COLOURS: int = 4
## `gfx/mail.asm`, one uncompressed 1bpp run the load routines index by byte.
const MAIL_GFX_BYTES: int = 1360
const MAIL_GFX_TILES: int = MAIL_GFX_BYTES / TILE_BYTES_1BPP
## `_ComposeMailMessage.MailIcon`, the eight tiles the screen spawns as a party
## icon over the entry.
const MAIL_ICON_TILES: int = 8

## constants/battle_tower_constants.asm. A challenge is seven trainers deep and
## three Pokemon wide, and both tables the cartridge samples from are 21 rows of
## a level group. `BATTLETOWER_NUM_UNIQUE_TRAINERS` is 70, and only Crystal 1.1
## can reach past the first 21: `LoadOpponentTrainerAndPokemon`'s Crystal 1.0
## branch masks with `BATTLETOWER_NUM_UNIQUE_MON` instead.
const BATTLETOWER_PARTY_LENGTH: int = 3
const BATTLETOWER_STREAK_LENGTH: int = 7
const BATTLETOWER_NUM_UNIQUE_MON: int = 21
const BATTLETOWER_NUM_UNIQUE_TRAINERS: int = 70
const BATTLETOWER_LEVEL_GROUPS: int = 10
## `bt_trainer` is `dname` plus the class byte, so a row is `NAME_LENGTH - 1`
## characters and one more.
const BATTLETOWER_TRAINER_NAME_BYTES: int = 10
const BATTLETOWER_TRAINER_ROW_BYTES: int = BATTLETOWER_TRAINER_NAME_BYTES + 1
## `NICKNAMED_MON_STRUCT_LENGTH`, the party-mon struct with its nickname behind
## it, which is exactly what `LoadRandomBattleTowerMon` copies per slot.
const BATTLETOWER_MON_BYTES: int = NICKNAMED_MON_BYTES
## `BattleTowerText`'s two arrays. A male class draws from 25 texts and a female
## from 15, and each trainer owns a greeting, a loss line and a win line, laid
## out in the file in that order per trainer. One pin walks all 120 stubs.
const BATTLETOWER_MALE_TEXTS: int = 25
const BATTLETOWER_FEMALE_TEXTS: int = 15
const BATTLETOWER_TEXT_KINDS: Array[String] = ["greeting", "loss", "win"]
## `Strings_L10ToL100`: ten level rows and CANCEL, each eight bytes with two
## terminators. `Strings_Ll0ToL40` is the same run's first four rows plus its own
## CANCEL, so the short menu is a slice rather than a second pin.
const BATTLETOWER_LEVEL_ROW_BYTES: int = 8
const BATTLETOWER_LEVEL_ROWS: int = BATTLETOWER_LEVEL_GROUPS + 1
## `MenuData_ChallengeExplanationCancel`: the flags byte, the row count and three
## terminated strings.
const BATTLETOWER_CHALLENGE_MENU_ROWS: int = 3
## The four boxes `_BattleTowerRoomMenu` prints, which are plain texts in the
## mobile bank rather than `text_far` stubs.
const BATTLETOWER_MENU_TEXT_ORDER: Array[String] = [
	"what_level", "party_mon_tops_this_level", "uber_restriction", "cancel_challenge",
]

## constants/item_constants.asm. TM01 is $bf and HM01 $f3, but the run is not
## contiguous: ITEM_C3 and ITEM_DC are dummy items inside it, which is why
## GetTMHMNumber skips them rather than subtracting.
const ITEM_TM01: int = 0xBF
const ITEM_HM01: int = 0xF3
## The largest number a cartridge item can carry. Every `cp` the source makes on
## an item is a byte comparison, which is why routines like GetTMHMNumber need no
## upper bound there and do need one here: a number past this is mod-defined
## content (see [constant Gen2ContentOverlay.FIRST_MOD_NUMBER]), not an item the
## cartridge has a row for.
const ITEM_BYTE_MAX: int = 0xFF
const ITEM_DUMMY_TM04_05: int = 0xC3
const ITEM_DUMMY_TM28_29: int = 0xDC


## engine/items/items.asm's GetTMHMNumber: the one-based TM/HM number an item id
## carries, or 0 when [param item] is not one. The two dummy items in the range
## have no number of their own and answer 0 as well.
static func tmhm_number_for_item(item: int, count: int) -> int:
	if item < ITEM_TM01 or item == ITEM_DUMMY_TM04_05 or item == ITEM_DUMMY_TM28_29:
		return 0
	var value: int = item
	if value >= ITEM_DUMMY_TM04_05:
		if value >= ITEM_DUMMY_TM28_29:
			value -= 1
		value -= 1
	var number: int = value - ITEM_TM01 + 1
	return number if number >= 1 and number <= count else 0


## GetNumberedTMHM, the inverse: the item id a one-based TM/HM number carries.
static func item_for_tmhm_number(number: int, count: int) -> int:
	if number < 1 or number > count:
		return 0
	var value: int = number
	if value >= ITEM_DUMMY_TM04_05 - (ITEM_TM01 - 1):
		if value >= ITEM_DUMMY_TM28_29 - (ITEM_TM01 - 1) - 1:
			value += 1
		value += 1
	return value + ITEM_TM01 - 1

## Byte positions within a 7-byte move entry.
## The animation is the move's own number, which is what makes the table
## self-checking in the same way the base stats are.
const MOVE_ANIMATION: int = 0
const MOVE_EFFECT: int = 1
const MOVE_POWER: int = 2
const MOVE_TYPE: int = 3
const MOVE_ACCURACY: int = 4
const MOVE_PP: int = 5
const MOVE_EFFECT_CHANCE: int = 6

## Gold and Silver share the world and battle layout, while a few variable-size
## data sections move because their content differs.
const GOLD_SILVER: Dictionary = {
	"species_names": 0x1B0B74,
	"base_stats": 0x51B0B,
	"pic_pointers": 0x48000,
	"unown_pic_pointers": 0x7C000,
	# `PredefPals`, which `CopyPalettes` expands a `sgb_pal_set` byte through.
	# See [constant PREDEFPAL_BLACKOUT] for the one entry the battle reads.
	"predef_pals": 0xA265,
	# pokegold has no `pic_animation.asm`, no `anim.asm`, no bitmasks and no
	# frames: both of its send-outs reach `PlayStereoCry` directly, which is
	# Crystal's own `.cry_no_anim` branch. See [constant CRYSTAL].
	"pic_anim": {},
	"palettes": 0xAD3D,
	"move_names": 0x1B1574,
	"item_names": 0x1B0000,
	# `ItemDescriptions` and `MoveDescriptions`, each a table of in-bank
	# pointers its own texts follow. Located by encoding the pinned first entry
	# of each (`MasterBallDesc`, `PoundDescription`), which hits once per dump,
	# and taking the pointer to it in the same bank; every one of the 255 and 251
	# entries then terminates within [constant DESCRIPTION_MAX_BYTES].
	"item_descriptions": 0x1B8000,
	"move_descriptions": 0x1B4000,
	"item_attributes": 0x68A0,
	"item_status_actions": 0xF0C7,
	"item_healing_hp": 0xF405,
	"world_trades": 0xFCC24,
	"world_trade_count": 6,
	"move_data": 0x41AFE,
	"tmhm_moves": 0x11A66,
	"tmhm_move_count": 57,
	# `HappinessChanges`, located by its own fifty-four signed bytes, which hit
	# once per dump. Nothing near it is a table with the same shape.
	"happiness_changes": 0x7300,
	"happiness_change_count": HAPPINESS_CHANGE_COUNT_GOLD_SILVER,
	"name_input_chars": 0x120B4,
	"string_buffer_pointers": 0x24000,
	## `data/text/common_2.asm`'s intro texts, each at its own `text_far` target.
	## Nested the way the trainer card is, so the -1 for what Gold and Silver do
	## not ship stays out of the flat offset checks. `_OakText3` is a bare
	## `text_promptbutton` and carries no words, so it has no offset here.
	# `engine/menus/start_menu.asm`'s description run and the `data/text/common_2.asm`
	# boxes the pack and the field items say, encoded from the source and matched.
	# Each hits once per dump except the two refusals and the bike's two name lines,
	# copied elsewhere too; these are the copy beside the toss texts.
	"menu_text": {
		"descriptions": 0x12B15,
		"oak_no_time": 0x1945B2,
		"no_mon": 0x1945DB,
		"toss_ask": 0x194569,
		"toss_ask_quantity": 0x19457F,
		"toss_threw": 0x19459C,
		"escape_rope": 0x1940AE,  # The six a field item says, in the same file and located the same way.
		"itemfinder_nearby": 0x19443B,
		"itemfinder_nope": 0x19446D,
		"sacred_ash": 0x194529,
		"squirtbottle": 0x1944FF,
		"cant_get_off_bike": 0x19435E,
		"got_on_bike": 0x194376,
		"got_off_bike": 0x19438B,
		# `_CoinCaseCountText` ends with `done` rather than `text_end` here, so
		# `DoTextUntilTerminator` indexes `TextCommands` with $57 and runs off
		# the table: the arbitrary code execution pokegold's own comment names.
		# There is no text to be faithful to, so it is not imported.
		"coin_case": -1,
		# `_BlueCardBalanceText` is Crystal's alone: Buena and her Blue Card are
		# not in these two, so the item, the effect entry and the text are absent.
		"blue_card": -1,
		"sent_trophy_home": 0x19862A,
	},
	"intro_text": {
		"oak_1": 0x195624,
		"oak_2": 0x195693,
		"oak_4": 0x1956D3,
		"oak_5": 0x19573F,
		"oak_6": 0x1957B7,
		"oak_7": 0x1957DD,
		## `engine/menus/init_gender.asm` is Crystal only, and so is its text.
		"gender": -1,
	},
	"evos_attacks": 0x427BD,
	# `EggMovePointers` followed through its 251 same-bank pointers. The lists
	# contain 478 move ids across 106 nonempty species in both Gold and Silver.
	"egg_move_pointers": 0x239FE,
	"egg_move_count": 478,
	"egg_move_species_count": 106,
	"type_names": 0x509AE,
	"type_matchups": 0x34D01,
	"font": 0xF82F2,
	"frames": 0xF88F2,
	"bar_palettes": 0xAD2D,
	"stats_screen_palettes": 0x94D3,
	"battle_font": 0xF86F2,
	# `FontsExtra_SolidBlackAndUpArrowGFX`' second tile, which is 1bpp here and
	# a 2bpp sheet of its own on Crystal. Both are unique in their dump.
	"up_arrow": {"offset": 0xF9306, "bits": 1},
	# No `MapEntryFrameGFX` and no `InitMapNameSign` on these two: the map name
	# sign is Crystal's own screen.
	"map_entry_sign": -1,
	"enemy_hud": 0xF8BB2,
	"player_hud": 0xF8BD2,
	"exp_bar": 0xF8C02,
	# `LoadBallIconGFX`'s four ball icons and `BattleTransitionTiles`' two, both
	# uncompressed 2bpp runs read straight off the address.
	"ball_icons": 0x2C1A4,
	# `MinimizePic`, one uncompressed 2bpp tile; its sixteen bytes occur once in
	# each of the three dumps.
	"minimize_pic": 0xCC6C8,
	# `BattleTransitionTiles` and the two palettes `LoadPokeBallGraphics` floods
	# every background tile with, the second of which is the darkness palset's.
	"battle_transition": {
		"tiles": 0x8C5B3, "palette": 0x8C960, "dark_palette": 0x8C968,
	},
	# `GetTrainerBackpic`'s pics, LZ at the address rather than behind a
	# pointer. Gold and Silver have one player character, so there is no Kris.
	"player_backpic": {"chris": 0x3F9CB, "kris": -1, "dude": 0x3FB5B},
	# `EggPic`, LZ at the address the way the back pics are: Gold and Silver's
	# `PokemonPicPointers` stops at NUM_POKEMON and `_GetFrontpic` reaches the
	# egg through its own `cp EGG / ld hl, EggPic` instead. The picture is not
	# Crystal's and carries no animation frames. Located by decompressing at
	# every offset and keeping the run that reproduces pokegold's own
	# `gfx/pokemon/egg/egg.png`; the hit is unique and the same in both dumps.
	"egg_pic": 0x53A83,
	# Trainer card. Located by converting the pinned gfx/trainer_card PNGs and
	# matching the bytes in the cartridge; the run is contiguous and
	# self-consistent, status running straight into the two leader copies and
	# then the two badge copies. Nested, the way wild_encounters is, so the -1
	# for what a profile does not ship stays out of the flat offset checks.
	"trainer_card": {
		# Gold and Silver ship no Kris pic and no right corner, and store the
		# card pic row-major rather than in columns.
		"pic_male": 0x2547F,
		"pic_female": -1,
		"pic_columns": false,
		"frame": 0x256AF,
		"status": 0x2570F,
		"leaders": 0x2576F,
		"badges": 0x2622F,
		"right_corner": -1,
		"badge_palette": 0xA385,
	},
	# The region map. `johto`, `kanto`, `palette_map` and `palette` were matched
	# from the assembled gfx/pokegear files, the graphics by decompressing at every
	# offset and keeping the run reproducing the PNG, and the landmark table by its
	# x,y pairs at a stride of four, which nothing else matches. Every hit is
	# unique per dump. `cards` is the three card tilemaps as one run and
	# `card_texts` the run of five opening on `_GearEllipseText`. Nested like
	# trainer_card, so Gold and Silver's absent female palette stays out of the
	# flat offset checks.
	"town_map": {
		"gfx": 0xF8C92,
		"pokegear_gfx": 0x1C0E43,
		"sprites": 0x9149C,
		"cards": 0x914CC,
		"card_texts": 0x198066,
		"fast_ship": 0x90C7C,
		"johto": 0x91F52,
		"kanto": 0x920BB,
		"palette_map": 0x91EAC,
		"palette": 0xBB6E,
		"palette_female": -1,  # `PokegearPals` is one run: no Kris, so no second city palette.
		"landmarks": 0x92382,
		"landmark_count": LANDMARK_COUNT_GOLD_SILVER,
	},
	# `OakRatings`, located by its own nineteen ascending thresholds at a stride
	# of five, which hit once per dump. Everything else Prof Oak's PC says is
	# reached through the table's own text pointers.
	"oak_ratings": 0x2685B,
	# `PokemonCenterPC`'s own strings. The five row names are one run, and the
	# routine's six `text_far` stubs sit `POKECENTER_PC_TEXT_AT` past its start;
	# both were located by matching the row run's own bytes, which are unique in
	# a dump.
	"pokecenter_pc": 0x158D1,
	# `DecorationAttributes`, located by assembling the whole 53-row table from
	# the source's own constants and matching it, which hits once per dump.
	# `DecorationNames` is `DECORATION_NAMES_AT` behind it.
	"decorations": 0x26C2B,
	# `DecorationIDs`, located by matching all forty-six ids and the terminator,
	# which hits once per dump.
	"decoration_ids": 0x270FE,
	# `Mom_GetScriptPointer.ItemScript`, located by its own five command bytes
	# with `MomItems_1` at the pinned distance behind it, which hits once per dump.
	"mom_phone": 0xFCE98,
	# `UnownWords`, located by encoding the twenty-six words in the Unown font's
	# own codes and matching the whole run, which hits once per dump; the table
	# is the fifty-four bytes in front of it.
	"unown_words": 0xFBB64,
	# `UnownWalls` is Crystal's alone: the chamber wall patterns these four words
	# belong to are Crystal bg events, where pokegold's cells carry the puzzle
	# sign, and neither `DisplayUnownWords` nor the words are in the dump.
	"unown_walls": -1,
	## `OddEggs` and its probabilities are Crystal's alone: Gold and Silver have
	## no `GiveOddEgg` special and no Day-Care Man who offers one.
	"odd_eggs": -1,
	## Gold and Silver have no Battle Tower map, routine or table at all.
	"battle_tower": {},
	# The credits. `gfx` was located by converting the pinned gfx/credits PNGs
	# and matching the bytes: the border and the four mon sheets are one
	# contiguous run in `credits.asm`'s own INCBIN order and `CreditsScript`
	# follows it, so the run's length pins the script and the script's own
	# terminator pins `CreditsStringsPointers`. `palettes` is
	# gfx/credits/credits.pal assembled and matched, and `the_end` the same for
	# gfx/credits/theend.png. Each hits once per dump. Nested the way
	# trainer_card is.
	"credits": {
		"palettes": 0x86C1C,
		"gfx": 0x86CA6,
		"the_end": 0xCBCBD,
		"script": 0x87A36,
		"strings": 0x87B65,
		"strings_bank": 0x70,  # `PlaceFarString`, so the strings are not in the table's own bank.
		# NUM_CREDITS_STRINGS, STAFF and COPYRIGHT
		# (constants/credits_constants.asm). All three are checked against the
		# script and the copyright screen rather than trusted.
		"string_count": 76,
		"staff": 51,
		"copyright": 71,
		# `GetCreditsPalette.UpdatePals` copies eight bytes twice into the same
		# two slots, so a scene is one palette rather than Crystal's three.
		"scene_palettes": 1,
		# `Credits_LoadBorderGFX.Frames`, as 16-tile blocks into the mon run.
		# The first three scenes ship three frames each and repeat the first.
		"frames": [0, 1, 0, 2, 3, 4, 3, 5, 6, 7, 6, 8, 9, 10, 11, 12],
	},
	# The copyright screen (`Copyright`, engine/menus/intro_menu.asm). The
	# graphic was located by encoding the pinned gfx/splash/copyright.png as
	# 2bpp and matching it, which hits once per dump; the string by assembling
	# data/copyright.asm's own code run, which hits twice because that file is
	# INCLUDEd for the credits as well, and the lower address is bank 1's, the
	# one `Copyright` reads. Nested the way trainer_card is.
	"copyright": {"gfx": 0xE4000, "tiles": 30, "string": 0x6513, "palette": 0xA4D5},
	# `GameFreakPresents`. `GameFreakLogoGFX` and `GameFreakLogoStarsGFX` were
	# located by encoding the four pinned gfx/splash PNGs as cartridge tiles and
	# matching them; each hits once per dump and the four runs are contiguous in
	# the order splash.asm INCBINs them. `object_palette` is
	# PREDEFPAL_GAMEFREAK_LOGO_OB, the entry in front of the copyright screen's
	# own. Nested the way trainer_card is, so Crystal's Ditto staying -1 here
	# stays out of the flat offset checks.
	"game_freak_presents": {
		"gfx": 0xE4B81,
		"stars": 0xE4C61,
		"ditto": -1,
		"ditto_palette": -1,
		"ditto_fade": -1,
		"object_palette": 0xA4CD,
	},
	# `TitleScreen`. Gold's numbers; Silver's three differences are patched in
	# `for_id`. `GSTitleOBPals` also appears in Crystal, which keeps the unused
	# Gold and Silver title screen's copy at a different address; that is a
	# leftover rather than a second candidate for this one. Nested the way
	# trainer_card is, so Crystal's -1s stay out of the flat offset checks.
	"title": {
		"logo_bottom": 0x98000,
		"logo_top": 0x98476,
		"tilemap": 0x98616,
		"trail": 0xE41E0,
		"trail_tiles": 8,
		"bird": 0xE4260,
		"bird_tiles": 88,
		"bg_palette": 0xBB36,
		"ob_palette": 0xBB5E,
		"suicune": -1,
		"logo": -1,
		"crystal": -1,
		"palettes": -1,
	},
	"intro_movie": {"section": -1, "fade": -1, "unown_pals": -1},  # `CrystalIntro` is Crystal's; Gold and Silver run `GoldSilverIntro` below.
	# `_UnownPuzzle`'s art, the same two pins as Crystal's at Gold and Silver's
	# own addresses. Both cartridges carry it at the same offsets.
	"unown_puzzle": {"tile_borders": 0xE1F30, "section": 0xE1FD2},
	# `DiplomaGFX` and the two tilemaps behind it, at Gold and Silver's own
	# address; located the way Crystal's is.
	"diploma": 0xE0105,
	# `LinkCommsBorderGFX`, which is nine tiles here and carries no tilemap:
	# `PlaceTradeScreenTextbox` draws the trade screen's two boxes with
	# `LinkTextboxAtHL` instead. The same address on Gold and on Silver.
	"link_border": 0x29D5B,
	"link_trade_tilemaps": -1,
	# `TradeGameBoyTilemap`, which `TRADE_ANIM_SECTION` walks the run from.
	# rgblink's own address out of a build byte identical to this dump, and the
	# same on Gold and on Silver.
	"trade_anim": 0x29713,
	# `InitMysteryGiftLayout` at Gold and Silver's own addresses, which is three
	# art runs rather than Crystal's one: thirty-two tiles of `MysteryGiftGFX`,
	# `MysteryGiftBackgroundGFX`'s 1bpp question mark and border doubled into
	# fifteen, and `MysteryGiftGFX2`'s fourteen. The single palette is
	# `_CGB_MysteryGift`'s own, against Crystal's two.
	"mystery_gift": {
		"gfx": 0xFD0C9, "tiles": 0x20,
		"background": 0x17079, "gfx2": 0x170F1,
		"prompt": 0x29F01, "palette": 0x9AAA, "palettes": 1,
		"items": 0x2C530, "decos": 0x2C555,
	},
	# The ride's two tilemaps, at the same addresses on Gold and on Silver.
	"magnet_train": {"bg": 0x8D00C, "fg": 0x8D124},
	# `UnownDexATile` behind `UnownDexVacantString`, and `GBPrinterStrings`
	# behind `PrinterStatusStringPointers`' first entry.
	"unown_printer_glyphs": 0x16FCC,
	"printer_strings": 0x1C00C5,
	# `_SlotMachine`'s run at Gold and Silver's own addresses, which are the same
	# on both. The bet text sits at the end of bank $65 and the four behind it at
	# the top of $66, which a byte walk crosses without noticing.
	"slots": {"section": 0x9387C, "palettes": 0xBBBE},
	"slots_bet_text": 0x93630,
	"slots_play_again_text": 0x93683,
	"slots_result_text": 0x93730,
	"card_flip": {"section": 0xE14E8, "palettes": 0xE14A0},  # `_CardFlip`'s run at Gold and Silver's own addresses, the same on both.
	"card_flip_text": 0x198313,
	# `GoldSilverIntro`'s art section. `Intro_WaterGFX1` is the only pinned
	# address in it: the section is contiguous and sixteen-byte aligned, so the
	# walk in `GS_INTRO_SECTION` reaches the other ten, and all eleven reproduce
	# pret's own build byte for byte. `magikarp_palettes` and
	# `shellder_lapras_palettes` are INCLUDEd inside the code rather than in that
	# section; each is a unique byte run whose object half sits directly behind
	# it. `predef_pals` is `PredefPals` itself, checked against the
	# `game_freak_presents.object_palette` this layout already pins.
	"gs_intro": {
		"section": 0xE54E8,
		"magikarp_palettes": 0x9126,
		"shellder_lapras_palettes": 0x96E1,
		"predef_pals": 0xA265,
	},
	"intro_player": {"pic_male": -1, "pic_female": -1},
	"gender_screen": {"tile": -1, "palette": -1},
	# `ShrinkPlayer`'s two intermediate pictures. Located from the routine's own
	# `ld hl` / `ld b` operand pairs, which is the only place either address
	# appears: the compressed bytes cannot be searched for the way a PNG can.
	"shrink_pics": {"first": 0xFB5BE, "second": 0xFB64E},
	## pokegold ships no `gfx/font/bg_text.pal`; its text boxes are coloured by
	## the SGB/CGB layout that drew the screen, not by a palette of their own.
	## Nested the way trainer_card is, so the -1 stays out of the flat offset
	## checks.
	"text_bg_palette": {"offset": -1},
	# Pokedex. Located by encoding Bulbasaur's known category and published
	# height and weight ("SEED", 204, 150) and matching the bytes, then finding
	# the only 251-pointer run whose four 64-species groups each ascend and
	# restart. Both order tables were located by encoding the pinned
	# data/pokemon/dex_order_*.asm species lists whole. Nested for the same
	# reason trainer_card is.
	"pokedex": {
		"entry_pointers": 0x44360,
		"entry_banks": [0x68, 0x69, 0x6A, 0x6B],  # BANK("Pokedex Entries 001-064") through 193-251.
		"order_alpha": 0x40C65,
		"order_new": 0x40D60,
		# The screen's own graphics; see POKEDEX_TILES for how these were
		# located. All five are byte identical across the three dumps, so only
		# the addresses differ.
		"gfx": 0x41511,
		"slowpoke": 0x416B3,
		"question_mark": 0x1C0C40,
		"footprints": 0xF930E,
		"interface_palette": 0xA34D,
		"unown_font": 0xFB30E,
		"question_mark_palette": 0x9559,
		"cursor_palette": 0x9551,
	},
	# The pack screen. `menu_gfx` and `pocket_names` were located by assembling
	# the pinned `gfx/pack` files and matching the bytes, and `palettes` by
	# encoding `pack.pal`; each hits once per dump. `PackGFX` is not pinned
	# separately because it follows the menu sheet immediately, which is what
	# `Pack_InitGFX`'s sixteen-tile overrun relies on. `female_gfx` is -1 here:
	# these cartridges have no Kris.
	"pack": {
		"menu_gfx": 0x10F31,
		"female_gfx": -1,
		"pocket_names": 0x10DFC,
		"palettes": 0x996F,
		"female_palettes": -1,
	},
	# Bill's PC. `mail_gfx` was located by assembling `gfx/pc/pc_mail.png`,
	# `select_gfx` by decompressing backwards from it until the run reproduced
	# `gfx/pc/pc.png` and ended where the mail sheet begins, and
	# `orange_palette` by encoding `gfx/pc/orange.pal`. Each hits once per dump.
	"pc": {
		"select_gfx": 0xE3BF8,
		"mail_gfx": 0xE3C18,
		"orange_palette": 0x95CD,
	},
	# Mail. `items` is `MailItems`' own eleven bytes, `input_chars` the two
	# `MailEntry_*` keyboards assembled whole, `gfx` the 1,360 bytes
	# `gfx/mail.asm` INCBINs in one run, `palettes` `gfx/mail/mail.pal` encoded
	# and `icon` `gfx/naming_screen/mail.2bpp`. Each hits once per dump.
	"mail": {
		"items": 0xBBAF7,
		"input_chars": 0x125B6,
		"gfx": 0xBB59D,
		"palettes": 0x92C1,
		"icon": 0x122C1,
	},
	# Battle animations. `BattleAnimations` was located by matching
	# `BattleAnim_Pound` whole (d1 01 e0 01 31 d0 08 88 38 00 06 d0 01 88 38 00
	# 10 ff), then the run of 278 in-bank pointers whose second entry is its
	# address; the other four came from the assembled data/battle_anims files.
	# Each hit is unique except `sine`, whose 64 bytes appear four or five times
	# per dump: it was located from `calc_sine_wave`'s own `ld hl` operand, and
	# only that hit lies in the bank. Nested like trainer_card.
	"battle_anims": {
		"scripts": 0xC900A,
		"objects": 0xCCAA5,
		"sine": 0xCE6C4,
		"framesets": 0xCE7A3,
		"oam_sets": 0xCEDF3,
		"object_gfx": 0xCFC3B,
	},
	# BattleObjectPals (engine/gfx/color.asm). Located by matching the pinned
	# gfx/battle_anims/battle_anims.pal whole; the hit is unique, and the
	# identically sized unused table beside it does not match.
	"battle_object_palettes": 0x9C09,
	"trainer_pic_pointers": 0x80000,
	"trainer_palettes": 0xB53D,
	"trainer_class_names": 0x1B0955,
	"trainer_classes": 66,
	"trainer_last_class": "ROCKET",
	"trainer_parties": 0x3993E,
	"trainer_party_total": 495,
	"trainer_party_last_trainer": "GRUNT",
	"trainer_attributes": 0x39562,
	"trainer_dvs": 0x27283,
	"trainer_dvs_last": 0x7EA8, # GRUNTF, class 66, "ROCKET" in-game: atk 7, def 14, spd 10, spc 8.
	"map_group_pointers": 0x940ED,
	"map_group_counts": [14, 7, 82, 9, 10, 8, 17, 7, 6, 17, 22, 13, 6, 8, 12, 8, 13, 14, 4, 4, 26, 9, 13, 13, 15, 11],
	"tilesets": 0x156BE,
	## Each tileset's `*Meta` run, whose length is only the distance to the next
	## label: `TilesetForest` is 40 blocks on both cartridges, not 64.
	"tileset_block_counts": [128, 128, 128, 128, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 40],
	"tileset_palette_bank": 0x02,
	"world_palette_offset": 0xB75E,
	## `LoadMapPals` here has no `LoadSpecialMapPalette` in front of it.
	"special_map_palettes": [],
	"mansion_palette_yellow": -1,
	"roof_palettes": 0xB9AE,
	"map_group_roofs": 0x1C021,
	"roof_tiles": 0x1C03C,
	"overworld_sprites": 0x147DE,
	"overworld_sprite_count": 95,
	"overworld_sprite_palettes": 0xB8AE,
	"overworld_icons": 0x8EABE,
	## `HeldItemIcons`, in front of `MonMenuIcons` in the same bank but behind
	## `GetIconGFX`'s own code, so the icons' offset does not pin it.
	"held_item_icons": 0x8E8DB,
	"party_menu_ob_palettes": 0xBAC6,
	"emotes": 0x143C1,
	## The three sheets engine/events/field_moves.asm loads by name.
	## CutGrassGFX follows CutTreeGFX, so one wrong offset shows on both.
	"headbutt_tree_gfx": 0x8CB0B,
	"cut_tree_gfx": 0x8CC04,
	"cut_grass_gfx": 0x8CC44,
	## `HealMachineAnim.HealMachineGFX` and the palette `.LoadPalettes` copies
	## into wOBPals2's PAL_OW_TREE slot. Neither has a table either: both are
	## located by their own bytes, which occur once per dump.
	"heal_machine_gfx": 0x127D5,
	"heal_machine_palette": 0x12828,
	## `LoadFishingGFX`'s sheet, and no Kris here to pick a second one.
	"chris_fish_gfx": 0x50580,
	"kris_fish_gfx": -1,
	"mart_table": 0x162FE,
	"default_mart": 0x16469,
	"bargain_mart": 0x15EDA,
	"mart_text": 0x16063,
	## The Day-Care's four stub runs, each located by the text its first stub
	## points at rather than by a symbol: `PrintDayCareText.TextTable`'s twenty
	## behind `_DayCareManIntroText`, `.NotYetText` alone, `DayCareManOutside`'s
	## five and `engine/pokemon/breeding.asm`'s two plus five.
	"day_care_text": 0x16B28,
	"day_care_not_yet_text": 0x16B9A,
	"day_care_egg_text": 0x16BE9,
	"day_care_left_with_text": 0x177E6,
	"day_care_compatibility_text": 0x17820,
	## `NameRaterHelloText`, bank $3e:$7919 in both dumps.
	"name_rater_text": 0xFB919,
	## `MoveDeletion.MoveKnowsOneText`, bank $0b:$43dc in both dumps.
	"move_deleter_text": 0x2C3DC,
	## The deferred-routine stub runs, located the same way. Zero is a run the
	## cartridge does not ship: the Poke Seer, Buena and her prize counter are
	## Crystal's alone, and no Gold or Silver script reaches their specials.
	## Gold and Silver's own, and only the one row they ship a routine for.
	"special_text_ram": {
		"magikarp_record_holder": 0xDD35,
		## `wBufferTrademonNickname`, which `_LinkAskTradeForText` names with a
		## `text_ram` whose address is in the text data itself.
		"trademon_nickname": 0xCEEF,
		## `TradeAnimation`'s four `text_ram` buffers: who sent each Pokemon and
		## what species it is.
		"player_trademon_species_name": 0xC5D1,
		"player_trademon_sender_name": 0xC5E7,
		"ot_trademon_species_name": 0xC602,
		"ot_trademon_sender_name": 0xC618,
		## The two names `_MysteryGiftSentText` and `_MysteryGiftSentHomeText`
		## spell: the partner who sent the gift and the player it came home to.
		## Gold and Silver's Mystery Gift block sits a page below Crystal's, the
		## way their link block does.
		"mystery_gift_partner_name": 0xC803,
		"mystery_gift_player_name": 0xC853,
		## `wMonOrItemNameBuffer`, which `StringBufferPointers` has no index for.
		"mon_or_item_name": 0xCF48,
	},
	## Gold and Silver's own WRAM address for the same byte; their link block sits
	## a page lower than Crystal's.
	"other_player_link_mode": 0xCE51,
	## The same three stubs at Gold and Silver's own addresses, the same on both.
	"link_cant_battle_text": 0x289A8,
	"link_abnormal_mon_text": 0x289BD,
	"link_ask_trade_text": 0x28D51,
	## `TradeAnimation`'s five stub blocks, in the file's order and the same on
	## Gold and on Silver.
	"trade_sent_text": 0x2958B,
	"trade_farewell_text": 0x295AB,
	"trade_take_care_text": 0x295D3,
	"trade_sends_text": 0x295F3,
	"trade_will_trade_text": 0x29618,
	"mystery_gift_text": 0x29F31,
	"magikarp_measure_text": 0xFBCAD,
	"magikarp_record_text": 0xFBDEC,
	"lucky_number_text": 0xC7BA3,
	"elevator_text": 0x138CF,
	"photo_studio_text": 0x17034,
	"mom_text": 0x168A8,
	"poke_seer_text": 0,
	"seer_advice_text": 0,
	"buena_prize_text": 0,
	## `NPCTrade`'s stubs, located from `_NPCTradeCableText`'s own far pointer,
	## which hits once per dump. Three dialog sets here against Crystal's four.
	"npc_trade_cable_text": 0xFCD20,
	"npc_trade_text": 0xFCD3C,
	"npc_trade_newbie_text": 0,
	## The Battle Tower's three stub runs, which Gold and Silver ship no routine
	## to reach; see the `battle_tower` block in the Crystal layout.
	"battle_tower_excuse_text": 0,
	"battle_tower_ready_text": 0,
	"battle_tower_rule_text": 0,
	"fruit_trees": 0x44091,
	## `SpawnPoints` and `Flypoints`, each located by the byte column that is the
	## same on all three dumps: the spawn coordinates at a stride of four, and
	## the flypoints' spawn column at a stride of two ahead of its `-1`. Both hit
	## once per dump.
	"spawn_points": 0x15319,
	"flypoints": 0x91BCC,
	"rooftop_mart_count": 0,
	"rooftop_mart_1": 0,
	"rooftop_mart_2": 0,
	"phone_contacts": 0x9043A,
	"phone_non_trainer_names": 0x903CD,
	"phone_non_trainer_names_bank": 0x24,
	"phone_non_trainer_name_count": 5,
	"special_phone_calls": 0x905F6,
	"phone_out_of_area_bank": 0x24,
	"phone_out_of_area_address": 0x4626,
	# `_PhoneClickText` and the `_PhoneEllipseText` behind it, the two lines
	# `HangUp` prints. Matched on "Click!" itself, which hits once per dump.
	"phone_call_texts": 0x1980FC,
	"phone_just_talk_bank": 0x24,
	"phone_just_talk_address": 0x462F,
	"phone_condition_outside": 0x4190,  # SpecialCallOnlyWhenOutside and SpecialCallWhereverYouAre in engine/phone/phone.asm.
	"phone_condition_anywhere": 0x419F,
	"music_pointers": 0xE906E,
	"music_count": 93,
	"music_first_bank": 0x3A,
	"music_first_address": 0x5185,
	"sfx_pointers": 0xE925E,
	"sfx_count": 188,
	"sfx_first_bank": 0x3C,
	"sfx_first_address": 0x4B3F,
	"cry_pointers": 0xE9192,
	"cry_first_bank": 0x3C,
	"cry_first_address": 0x743D,
	"mon_cries": 0xF2747,
	"wave_samples": 0xE8DB2,
	"wave_samples_bank": 0x3A,
	"wave_samples_address": 0x4DB2,
	"drumkits": 0xE8E52,
	"drumkits_bank": 0x3A,
	"drumkits_address": 0x4E52,
	"world_animation_done": 0x42A2,
	"world_animation_functions": {
		0x42A2: "done", 0x42A5: "wait", 0x42A6: "timer_8", 0x42B0: "scroll_horizontal",
		0x4311: "scroll_vertical", 0x432E: "water", 0x4388: "flower",
		0x43E7: "lava_1", 0x4406: "lava_2", 0x4460: "tower",
		0x448E: "timer", 0x4493: "whirlpool", 0x44B1: "write_buffer",
		0x44BD: "read_buffer", 0x44F2: "water_palette", 0x452D: "cave_palette",
	},
	"world_animation_assets": {
		"water": {"offset": 0xFC348, "bytes": 64},
		"flower": {"offset": 0xFC3A7, "bytes": 64},
		"lava": {"offset": 0xFC420, "bytes": 64},
		"tower": {"offset": 0xFC57D, "bytes": 800},
		"whirlpool": {"offset": 0xFC8AD, "bytes": 256},
	},
	"wild_encounters": {
		"grass_johto": 0x2AB35,
		"water_johto": 0x2B669,
		"grass_kanto": 0x2B7C0,
		"water_kanto": 0x2BD43,
		"grass_johto_count": 61,
		"water_johto_count": 38,
		"grass_kanto_count": 30,
		"water_kanto_count": 24,
		"swarm_grass": 0x2BE1C,
		"swarm_grass_count": 4,
		"swarm_water": 0x2BED9,
		"swarm_water_count": 1,
		"fish_groups": 0x929F7,
		"fish_group_count": 13,
		"roam_maps": 0x2A95B,
		"roam_map_count": 16,
		"roaming": [
			{"species": 0xF3, "level": 40, "map_group": 2, "map_number": 5},
			{"species": 0xF4, "level": 40, "map_group": 10, "map_number": 4},
			{"species": 0xF5, "level": 40, "map_group": 1, "map_number": 12},
		],
		"tree_maps": 0xBA3E6,
		"tree_map_count": 34,
		"rock_maps": 0xBA44D,
		"rock_map_count": 4,
		"treemon_sets": 0xBA470,
		"treemon_set_count": 6,
		"asleep_treemons": {},
		# data/wild/bug_contest_mons.asm's ContestMons and
		# data/events/bug_contest_winners.asm's BugContestantPointers, both
		# located by their own bytes, which are unique in every dump: the
		# eleven `%, species, min, max` rows and the pointer entry pokegold and
		# pokecrystal both repeat for BUG_CONTEST_PLAYER.
		"bug_contest_mons": 0x97BB8,
		"bug_contest_mon_count": 11,
		"bug_contestants": 0x13B3F,
		"bug_contestant_count": 10,
	},
	# Gold and Silver patch three bank numbers and pass the rest through. The
	# stored value is what the linker assigned before three pic sections were
	# moved; see FixPicBank in pokegold.
	"pic_bank_add": 0,
	"pic_bank_patch": {0x13: 0x1F, 0x14: 0x20, 0x1F: 0x2E},
}

const CRYSTAL: Dictionary = {
	"species_names": 0x53384,
	"base_stats": 0x51424,
	"pic_pointers": 0x120000,
	"unown_pic_pointers": 0x124000,
	"predef_pals": 0x9DF6,  # The same table; Crystal has no Gold and Silver intro to pin it under.
	# `AnimateFrontpic`'s five tables, Crystal's alone: pokegold ships no
	# `pic_animation.asm`, no bitmasks and no frames, and both of its send-outs
	# reach `PlayStereoCry` directly. Every address here is rgblink's own, from a
	# `pokecrystal11.gbc` byte identical to the dump. A script pointer and a
	# bitmask pointer are read in the table's own bank; a frames pointer is read in
	# the bank its *data* lives in, `KantoFrames` below
	# [constant JOHTO_SPECIES] and `JohtoFrames` from it.
	"pic_anim": {
		"scripts": 0xD0695,
		"idle_scripts": 0xD16A3,
		"bitmask_pointers": 0xD24EF,
		"frame_pointers": 0xD4000,
		"script_bank": 0x34,
		"bitmask_bank": 0x34,
		"frame_pointer_bank": 0x35,
		"kanto_frame_bank": 0x35,
		"johto_frame_bank": 0x36,
		"unown_scripts": 0xD2229,
		"unown_idle_scripts": 0xD23D1,
		"unown_bitmask_pointers": 0xD3AD3,
		"unown_frame_pointers": 0xD99A9,
		"unown_frame_bank": 0x36,
	},
	"palettes": 0xA8CE,
	"move_names": 0x1C9F29,
	"item_names": 0x1C8000,
	"item_descriptions": 0x1C8987,  # The two description tables; see the Gold and Silver block above.
	"move_descriptions": 0x2CB52,
	"item_attributes": 0x67C1,
	"item_status_actions": 0xF071,
	"item_healing_hp": 0xF3AF,
	"world_trades": 0xFCE58,
	"world_trade_count": 7,
	"move_data": 0x41AFB,
	"tmhm_moves": 0x1167A,
	"tmhm_move_count": 60,
	# See the Gold and Silver block above; the first eighteen rows are byte
	# identical and Crystal adds HAPPINESS_GAINLEVELATHOME after them.
	"happiness_changes": 0x7221,
	"happiness_change_count": HAPPINESS_CHANGE_COUNT,
	"name_input_chars": 0x11CE7,
	"string_buffer_pointers": 0x24000,
	## See the Gold and Silver block above. Crystal moves `_OakText6` and
	## `_OakText7` out of the run the other four sit in, so the six are located
	## one by one rather than walked.
	# See the Gold and Silver block above for how these were located.
	"menu_text": {
		"descriptions": 0x1274E,
		"oak_no_time": 0x1C0BEE,
		"no_mon": 0x1C0C17,
		"toss_ask": 0x1C0BA5,
		"toss_ask_quantity": 0x1C0BBB,
		"toss_threw": 0x1C0BD8,
		"escape_rope": 0x1C06ED,
		"itemfinder_nearby": 0x1C0A77,
		"itemfinder_nope": 0x1C0AA9,
		"sacred_ash": 0x1C0B65,
		"squirtbottle": 0x1C0B3B,
		"cant_get_off_bike": 0x1C099A,
		"got_on_bike": 0x1C09B2,
		"got_off_bike": 0x1C09C7,
		"coin_case": 0x1C5C7B,
		"blue_card": 0x1C5C5E,
		"sent_trophy_home": 0x1C5D03,
	},
	"intro_text": {
		"oak_1": 0x1C1D35,
		"oak_2": 0x1C1DA4,
		"oak_4": 0x1C1DE5,
		"oak_5": 0x1C1E51,
		"oak_6": 0x1C4000,
		"oak_7": 0x1C4026,
		"gender": 0x1C0CA3,
	},
	"evos_attacks": 0x425B1,
	# Crystal's own `EggMovePointers`; its revised breeding data contains 480
	# move ids across 105 nonempty species.
	"egg_move_pointers": 0x23B11,
	"egg_move_count": 480,
	"egg_move_species_count": 105,
	"type_names": 0x5097B,
	"type_matchups": 0x34BB1,
	"font": 0xF8200,
	"frames": 0xF8800,
	"bar_palettes": 0xA8BE,
	"stats_screen_palettes": 0x8F52,
	"battle_font": 0xF8600,
	"up_arrow": {"offset": 0xF9424, "bits": 2},  # `FontsExtra2_UpArrowGFX`, its own 2bpp tile here.
	# `MapEntryFrameGFX`, the map name sign's own fourteen tiles. It is the entry
	# before `FontsExtra2_UpArrowGFX` in `gfx/font.asm` and ends exactly where
	# that one starts, which is what checks the address. Gold and Silver ship
	# neither the sheet nor `InitMapNameSign`, and say so with a -1.
	"map_entry_sign": 0xF9344,
	"enemy_hud": 0xF8AC0,
	"player_hud": 0xF8AE0,
	"exp_bar": 0xF8B10,
	"ball_icons": 0x2C172,  # See the Gold and Silver block above.
	"minimize_pic": 0xCC725,
	"battle_transition": {
		"tiles": 0x8C2F4, "palette": 0x8C6A1, "dark_palette": 0x8C6A9,
	},
	"player_backpic": {"chris": 0x2BA1A, "kris": 0x88ED6, "dude": 0x2BBAA},
	# Crystal's `PokemonPicPointers` carries an EGG entry and `_GetFrontpic`
	# reads the egg through it like any other pic, so there is no address to pin.
	"egg_pic": -1,
	# Trainer card; see the Gold and Silver block above for how these were
	# located. Crystal splits the card pic in two by gender and stores both
	# column-major, and adds the one-tile right corner Gold and Silver lack.
	"trainer_card": {
		"pic_male": 0x88365,
		"pic_female": 0x88595,
		"pic_columns": true,
		"frame": 0x887C5,
		"status": 0x25523,
		"leaders": 0x25583,
		"badges": 0x26043,
		"right_corner": 0x265C3,
		"badge_palette": 0x9F16,
	},
	# The region map; see the Gold and Silver block above for how these were
	# located. Every asset is byte identical across the three dumps, so only the
	# addresses differ. Crystal adds Kris's own city palette and the ninety-sixth
	# landmark, `BATTLE TOWER`.
	"town_map": {
		"gfx": 0xF8BA0,
		"pokegear_gfx": 0x1DE2E4,
		"sprites": 0x914DD,
		"cards": 0x9150D,
		"card_texts": 0x1C5824,
		"fast_ship": 0x90CB2,
		"johto": 0x91FFF,
		"kanto": 0x92168,
		"palette_map": 0x91F4B,
		"palette": 0xB729,
		"palette_female": 0xB759,
		"landmarks": 0x1CA8C3,
		"landmark_count": LANDMARK_COUNT,
	},
	# Every row from here to `mom_phone` is the Gold and Silver block above with a
	# moved address; `mom_phone`'s two scripts also move their `end` opcode.
	"oak_ratings": 0x2667F,
	"pokecenter_pc": 0x155FA,
	"decorations": 0x26A4F,
	"decoration_ids": 0x26F2B,
	"mom_phone": 0xFD0FD,
	# See the Gold and Silver block above; the words are byte identical and only
	# their address moves.
	"unown_words": 0xFBA5A,
	# `UnownWalls`, located by encoding all four words in the `unown` charmap and
	# matching the run, which hits once. `MenuHeaders_UnownWalls` follows it.
	"unown_walls": 0x8AEBC,
	# See the Gold and Silver block above for how these were located. Crystal's
	# strings sit in the pointer table's own bank, since it prints them with
	# `PlaceString` rather than `PlaceFarString`, and each of its four scenes is
	# three palettes rather than one.
	"credits": {
		"palettes": 0x109B6A,
		"gfx": 0x109C24,
		"the_end": 0xCBD2E,
		"script": 0x10ACB4,
		"strings": 0x10AE13,
		"strings_bank": 0x42,
		"string_count": 103,
		"staff": 72,
		"copyright": 98,
		"scene_palettes": 3,
		"frames": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
	},
	"copyright": {"gfx": 0xE4000, "tiles": 29, "string": 0x63FD, "palette": 0xA066},  # See the Gold and Silver block above for how this was located.
	# See the Gold and Silver block above for how these were located. Crystal
	# ships no star or sparkle: its beat is the Ditto, whose compressed run
	# cannot be searched for as bytes and was instead found by decompressing at
	# every offset in the dump and keeping the one that produced the pinned
	# gfx/splash/ditto.png exactly. Both of its palettes are unique eight- and
	# thirty-two-byte runs, and `ditto_fade` sits directly in front of the
	# graphic, which is where splash.asm puts it.
	"game_freak_presents": {
		"gfx": 0xE47CC,
		"stars": -1,
		"ditto": 0x109407,
		"ditto_palette": 0x9521,
		"ditto_fade": 0xE47AC,
		"object_palette": 0xA05E,
	},
	# `_TitleScreen`. A different screen from Gold and Silver's, so the two
	# halves of this entry have nothing in common but the key: the three LZ runs
	# and the sixteen palettes sit contiguous in `engine/movie/title.asm`'s own
	# INCBIN order, ending on the palettes.
	"title": {
		"suicune": 0x10EF46,
		"logo": 0x10F326,
		"crystal": 0x10FCEE,
		"palettes": 0x10FEDE,
		"logo_bottom": -1,
		"logo_top": -1,
		"tilemap": -1,
		"trail": -1,
		"trail_tiles": 0,
		"bird": -1,
		"bird_tiles": 0,
		"bg_palette": -1,
		"ob_palette": -1,
	},
	# `CrystalIntro`'s art section. `IntroSuicuneRunGFX` is the only pinned
	# address: the section is contiguous and sixteen-byte aligned, so the walk in
	# `INTRO_SECTION` reaches the other thirty-four. Found by decompressing at
	# every offset in the dump and keeping the one that produced the pinned
	# gfx/intro/suicune_run.png exactly. `fade` and `unown_pals` are INCLUDEd
	# inside the code rather than in that section; both are unique byte runs, and
	# `unown_1.pal` pins `unown_2.pal` directly behind it.
	"intro_movie": {"section": 0xE555D, "fade": 0xE519C, "unown_pals": 0xE538D},
	# `_UnownPuzzle`'s art. `PuzzlePieceBorderData.TileBordersGFX` and
	# `UnownPuzzleCursorGFX` are the two pinned addresses; the walk in
	# `UNOWN_PUZZLE_SECTION` reaches the five behind the cursor.
	"unown_puzzle": {"tile_borders": 0xE1723, "section": 0xE17C5},
	# `DiplomaGFX`, which `PlaceDiplomaOnScreen` decompresses and whose two
	# `SCREEN_AREA` tilemaps are laid out behind it with nothing between them.
	# Located off `.GameFreak`, the last of `PrintDiplomaPage2`'s own two
	# strings: `db "GAME FREAK@"` is eleven bytes and the INCBIN follows it.
	"diploma": 0x1DD805,
	# `LinkCommsBorderGFX` and, sixty-eight bytes of code behind it,
	# `MobileTradeBorderTilemap` with the two cable strips after it. Located off the
	# border tiles themselves, a byte-exact match for `gfx/trade/border_tiles.png`;
	# the tilemaps are pinned separately because three routines sit between them.
	# Below, `InitMysteryGiftLayout`'s own `ld bc, $43 tiles`, uncompressed and
	# straight into vTiles2, so the pin is a bounds check rather than a
	# decompression. Located off `.String_PressAToLink_BToCancel`, the only plain
	# text in the routine.
	"mystery_gift": {
		"gfx": 0x105258, "tiles": 0x43,
		"background": -1, "gfx2": -1,
		"prompt": 0x1049CD, "palette": 0x95E0, "palettes": 2,
		"items": 0x2C725, "decos": 0x2C74A,
	},
	"link_border": 0x16CFC1,
	"link_trade_tilemaps": 0x16D465,
	"trade_anim": 0x298C7,
	# The ride's two tilemaps, byte identical on all three cartridges.
	"magnet_train": {"bg": 0x8CD82, "fg": 0x8CEFF},
	# `UnownDexATile`, the two 1bpp tiles `_UnownPrinter` requests into the
	# menu's own A and B glyphs, seven bytes behind `UnownDexVacantString`.
	"unown_printer_glyphs": 0x16D9C,
	# `GBPrinterStrings`, which is `GBPrinterString_Null`'s own `"@"` with the
	# other seven terminated strings behind it in table order.
	"printer_strings": 0x1DC275,
	# `_SlotMachine`'s data run and the sixteen palettes `_CGB_SlotMachine`
	# copies. `section` is `Reel1Tilemap`, which walks the whole run; the three
	# text pins are the stub blocks at the end of `Slots_AskBet`,
	# `Slots_AskPlayAgain` and `Slots_PayoutText`. All five are rgblink's own
	# addresses out of a build byte identical to this dump.
	"slots": {"section": 0x93327, "palettes": 0xB7A9},
	"slots_bet_text": 0x930C7,
	"slots_play_again_text": 0x9311A,
	"slots_result_text": 0x931DB,
	# `_CardFlip`'s art run and the nine palettes `CardFlip_InitAttrPals` copies.
	# `palettes` is `.palettes`, which `CARD_FLIP_SECTION` walks the whole run
	# from; `card_flip_text` is `_CardFlipPlayWithThreeCoinsText`, the first of
	# eight texts laid out together in `data/text/common_3.asm`.
	"card_flip": {"section": 0xE0CDB, "palettes": 0xE0C93},
	"card_flip_text": 0x1C5793,
	# Crystal ships no `GoldSilverIntro`. Nested the way trainer_card is, so the
	# -1s stay out of the flat offset checks.
	"gs_intro": {
		"section": -1,
		"magikarp_palettes": -1,
		"shellder_lapras_palettes": -1,
		"predef_pals": -1,
	},
	# `engine/gfx/player_gfx.asm`: ChrisPic and KrisPic. Located by converting
	# the pinned 56x56 PNGs with rgbgfx --columns and matching the full runs.
	"intro_player": {"pic_male": 0x888A9, "pic_female": 0x88BB9},
	# `engine/menus/init_gender.asm`: LoadGenderScreenPal's inline `.Palette`
	# (gfx/new_game/gender_screen.pal) and LoadGenderScreenLightBlueTile's
	# `.LightBlueTile`. The palette's eight bytes are unique in the dump; the
	# tile, sixteen bytes of one repeated index, is not, so it is taken from the
	# `ld de` operand thirteen bytes past the palette. Crystal only.
	"gender_screen": {"tile": 0x48E71, "palette": 0x48E5C},
	"shrink_pics": {"first": 0x4D249, "second": 0x4D2D9},  # See the Gold and Silver block above for how these were located.
	# `gfx/font/bg_text.pal`, BG palette 7. Located from `LoadOW_BGPal7`'s own
	# `ld hl` operand, whose `ld de` is wBGPals1 + PAL_BG_TEXT; the eight bytes
	# are unique in the dump as well.
	"text_bg_palette": {"offset": 0x49418},
	# Pokedex; see the Gold and Silver block above for how these were located.
	# Both order tables sit at the same offsets in all three dumps; the entries
	# and their banks do not, and Gold and Silver do not even share description
	# text with each other, so every profile is read from its own cartridge.
	"pokedex": {
		"entry_pointers": 0x44378,
		"entry_banks": [0x60, 0x6E, 0x73, 0x74],
		"order_alpha": 0x40C65,
		"order_new": 0x40D60,
		# Crystal stores the two small palettes the other way round, which is
		# why each is pinned rather than walked from its neighbour.
		# `interface_palette` is PREDEFPAL_POKEDEX, pinned as its own offset the
		# way `trainer_card.badge_palette` pins PREDEFPAL_CGB_BADGE.
		"gfx": 0x4150E,
		"slowpoke": 0x416B0,
		"question_mark": 0x1DE0E1,
		"footprints": 0xF9434,
		"interface_palette": 0x9EDE,
		"unown_font": 0x1DC000,
		"question_mark_palette": 0x8FBA,
		"cursor_palette": 0x8FC2,
	},
	# The pack screen; see the Gold and Silver block above for how these were
	# located. Crystal is the profile that has both packs: `.KrisPackPals`
	# follows `.ChrisPackPals` in the same routine, which is the contiguity
	# `verify_pack` checks, while `PackFGFX` sits in a bank of its own.
	"pack": {
		"menu_gfx": 0x10B16,
		"female_gfx": 0x48E9B,
		"pocket_names": 0x109E1,
		"palettes": 0x9439,
		"female_palettes": 0x9469,
	},
	# Bill's PC; see the Gold and Silver block above for how these were located.
	# Crystal's cursor sheet is `--literal-only`, so its run is the longer one.
	"pc": {
		"select_gfx": 0xE3419,
		"mail_gfx": 0xE349D,
		"orange_palette": 0x9036,
	},
	# Mail; see the Gold and Silver block above for how these were located.
	"mail": {
		"items": 0xB9E80,
		"input_chars": 0x121DD,
		"gfx": 0xB9926,
		"palettes": 0x8D05,
		"icon": 0x11EF4,
	},
	# The Battle Tower, which Gold and Silver have no map, routine or table for.
	# `trainers` is `BattleTowerTrainers`' 70 rows, `mons` the ten level groups of
	# 21 nicknamed party-mon structs, `class_genders` and `class_sprites` the two
	# per-class tables, `trainer_text` the 120 `text_far` stubs, `level_strings`
	# `Strings_L10ToL100` and `challenge_menu`
	# `MenuData_ChallengeExplanationCancel`. Each hits once.
	# `BattleTowerTrainerData` is deliberately absent: its 36 bytes per trainer are
	# the mobile greeting's word pairs and nothing on a local challenge reads them.
	"battle_tower": {
		"trainers": 0x1F814E,
		"mons": 0x1F8450,
		"class_genders": 0x11F2F0,
		"class_sprites": 0x170B90,
		"trainer_text": 0x11F42E,
		"level_strings": 0x119D0C,
		"challenge_menu": 0x17D297,
		"text": {
			"what_level": 0x11ABA5,
			"party_mon_tops_this_level": 0x11AAF0,
			"uber_restriction": 0x11AB0F,
			"cancel_challenge": 0x11AB4A,
		},
	},
	# Battle animations; see the Gold and Silver block above for how these were
	# located. All five tables sit in the same two banks in every dump and only
	# the addresses within them move.
	"battle_anims": {
		"scripts": 0xC906F,
		"objects": 0xCCB56,
		"sine": 0xCE77F,
		"framesets": 0xCE85E,
		"oam_sets": 0xCEEAE,
		"object_gfx": 0xCFCF6,
	},
	"battle_object_palettes": 0x979C,
	"trainer_pic_pointers": 0x128000,
	"trainer_palettes": 0xB0CE,
	"trainer_class_names": 0x2C1EF,
	"trainer_classes": 67,
	"trainer_last_class": "MYSTICALMAN",
	"trainer_parties": 0x39999,
	"trainer_party_total": 541,
	"trainer_party_last_trainer": "EUSINE",
	"trainer_attributes": 0x3959C,
	"trainer_dvs": 0x270D6,
	"trainer_dvs_last": 0x9888, # MYSTICALMAN, class 67: atk 9, def 8, spd 8, spc 8.
	"map_group_pointers": 0x94000,
	"map_group_counts": [14, 7, 91, 9, 10, 8, 17, 7, 6, 17, 24, 13, 6, 8, 12, 8, 13, 14, 4, 6, 26, 16, 13, 13, 15, 11],
	"tilesets": 0x4D596,
	## See GOLD_SILVER: `TilesetForest`, here number 31, is the short one.
	"tileset_block_counts": [128, 128, 128, 128, 128, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 40, 64, 64, 64, 64, 64],
	"tileset_palette_bank": 0x13,
	"world_palette_offset": 0xB319,
	## In SPECIAL_PALETTE_TILESETS order. `MansionPalette1` is nine palettes: its
	## seventh goes over PAL_BG_WATER and its ninth over PAL_BG_ROOF.
	"special_map_palettes": [0x49501, 0x49550, 0x4959F, 0x495EE, 0x4963D, 0x4967D],
	"mansion_palette_yellow": 0x496FE,
	"roof_palettes": 0xB569,
	"map_group_roofs": 0x1C021,
	"roof_tiles": 0x1C03C,
	"overworld_sprites": 0x14736,
	## NUM_OVERWORLD_SPRITES (constants/sprite_constants.asm), which is the last
	## constant's own value: SPRITE_STANDING_YOUNGSTER is $66. Crystal's four rows
	## past pokegold's SPRITE_SILVER_TROPHY are Kris, Kris on a bike, Kurt
	## outside, the three beasts and the standing youngster. Reading 99 stopped at
	## SPRITE_SUICUNE and left thirteen map objects with no sprite, which is also
	## no collision: see Gen2WorldAPI.object_at().
	"overworld_sprite_count": 102,
	"overworld_sprite_palettes": 0xB469,
	"overworld_icons": 0x8EC0D,
	"held_item_icons": 0x8E9F7,
	"party_menu_ob_palettes": 0xB681,
	"emotes": 0x1444D,
	"headbutt_tree_gfx": 0x8C893,
	"cut_tree_gfx": 0x8C98C,
	"cut_grass_gfx": 0x8C9CC,
	"heal_machine_gfx": 0x123FC,
	"heal_machine_palette": 0x12451,
	## `LoadFishingGFX` picks between the two on `PLAYERGENDER_FEMALE_F`.
	"chris_fish_gfx": 0xB84F2,
	"kris_fish_gfx": 0xB8582,
	"mart_table": 0x160A9,
	"default_mart": 0x16214,
	"bargain_mart": 0x15C51,
	"mart_text": 0x15E0E,
	## The Day-Care's four stub runs; see the Gold and Silver block for how each
	## is located.
	"day_care_text": 0x168D2,
	"day_care_not_yet_text": 0x16944,
	"day_care_egg_text": 0x16993,
	"day_care_left_with_text": 0x17462,
	"day_care_compatibility_text": 0x1749C,
	## `NameRaterHelloText`, bank $3e:$780f.
	"name_rater_text": 0xFB80F,
	## `MoveDeletion.MoveKnowsOneText`, bank $0b:$45d1.
	"move_deleter_text": 0x2C5D1,
	## The deferred-routine stub runs `SPECIAL_TEXT_RUNS` names, each located by
	## encoding its first box and following the `text_far` that points at it.
	## The WRAM addresses the runs above name with `text_ram`, beyond the string
	## buffers `string_buffer_pointers` already carries. Crystal's Poke Seer has
	## five of its own; the record holder's name is on all three.
	"special_text_ram": {
		"magikarp_record_holder": 0xDFEA,
		"seer_nickname": 0xD003,
		"seer_caught_location": 0xD00E,
		"seer_time_of_day": 0xD01F,
		"seer_ot": 0xD02A,
		"seer_caught_level": 0xD036,
		"trademon_nickname": 0xD004,
		"player_trademon_species_name": 0xC6D1,
		"player_trademon_sender_name": 0xC6E7,
		"ot_trademon_species_name": 0xC703,
		"ot_trademon_sender_name": 0xC719,
		"mystery_gift_partner_name": 0xC903,
		"mystery_gift_player_name": 0xC953,
		"mon_or_item_name": 0xD050,
	},
	## `wOtherPlayerLinkMode`, the byte all three receptionist scripts `readmem`
	## after `CheckLinkTimeout_Receptionist`. Located off those three `readmem`s
	## themselves, which are the only three in either corpus that name it.
	"other_player_link_mode": 0xCF51,
	"link_cant_battle_text": 0x28AAF,
	"link_abnormal_mon_text": 0x28AC4,
	"link_ask_trade_text": 0x28EB8,
	"trade_sent_text": 0x29732,
	"trade_farewell_text": 0x29752,
	"trade_take_care_text": 0x2977A,
	"trade_sends_text": 0x2979A,
	"trade_will_trade_text": 0x297BF,
	"mystery_gift_text": 0x1049FD,
	"magikarp_measure_text": 0xFBBA9,
	"magikarp_record_text": 0xFBCE8,
	"lucky_number_text": 0x4D9C9,
	"elevator_text": 0x1350D,
	"photo_studio_text": 0x16E04,
	"mom_text": 0x16649,
	"poke_seer_text": 0x4F28C,
	"seer_advice_text": 0x4F2E8,
	"buena_prize_text": 0x8B072,
	"npc_trade_cable_text": 0xFCF7B,
	"npc_trade_text": 0xFCF97,
	"npc_trade_newbie_text": 0xFCFE2,
	"odd_eggs": 0x1FB552,
	## `engine/events/battle_tower/rules.asm`'s three stub runs; Crystal only.
	"battle_tower_excuse_text": 0x8B22C,
	"battle_tower_ready_text": 0x8B238,
	"battle_tower_rule_text": 0x8B23D,
	"fruit_trees": 0x44097,
	"spawn_points": 0x152AB,
	"flypoints": 0x91C5E,
	"rooftop_mart_count": 2,
	"rooftop_mart_1": 0x15AEE,
	"rooftop_mart_2": 0x15AFF,
	"phone_contacts": 0x9045F,
	"phone_non_trainer_names": 0x903D6,
	"phone_non_trainer_names_bank": 0x24,
	"phone_non_trainer_name_count": 6,
	"special_phone_calls": 0x90627,
	"phone_out_of_area_bank": 0x24,
	"phone_out_of_area_address": 0x4657,
	"phone_call_texts": 0x1C5580,
	"phone_just_talk_bank": 0x24,
	"phone_just_talk_address": 0x4660,
	"phone_condition_outside": 0x4188,  # Crystal's relocated special-call condition routines.
	"phone_condition_anywhere": 0x4197,
	"music_pointers": 0xE906E,
	"music_count": 103,
	"music_first_bank": 0x3A,
	"music_first_address": 0x51A3,
	"sfx_pointers": 0xE927C,
	"sfx_count": 207,
	"sfx_first_bank": 0x3C,
	"sfx_first_address": 0x4B3F,
	"cry_pointers": 0xE91B0,
	"cry_first_bank": 0x3C,
	"cry_first_address": 0x747D,
	"mon_cries": 0xF2787,
	"wave_samples": 0xE8DB2,
	"wave_samples_bank": 0x3A,
	"wave_samples_address": 0x4DB2,
	"drumkits": 0xE8E52,
	"drumkits_bank": 0x3A,
	"drumkits_address": 0x4E52,
	"world_animation_done": 0x42FB,
	"world_animation_functions": {
		0x42FB: "done", 0x42FE: "wait", 0x42FF: "timer_8", 0x4309: "scroll_horizontal",
		0x436A: "scroll_vertical", 0x4387: "fountain", 0x4402: "water",
		0x445C: "forest_left", 0x44C4: "forest_right", 0x44F2: "forest_left_2",
		0x451C: "forest_right_2", 0x456D: "flower", 0x45CC: "lava_1",
		0x45EB: "lava_2", 0x4645: "tower", 0x4673: "timer", 0x4678: "whirlpool",
		0x4696: "write_buffer", 0x46A2: "read_buffer", 0x46D7: "water_palette",
		0x471E: "cave_palette",
	},
	"world_animation_assets": {
		"water": {"offset": 0xFC41C, "bytes": 64},
		"flower": {"offset": 0xFC58C, "bytes": 64},
		"fountain": {"offset": 0xFC3B2, "bytes": 80},
		"forest": {"offset": 0xFC484, "bytes": 64},
		"lava": {"offset": 0xFC605, "bytes": 64},
		"tower": {"offset": 0xFC778, "bytes": 800},
		"whirlpool": {"offset": 0xFCAA8, "bytes": 256},
	},
	"wild_encounters": {
		"grass_johto": 0x2A5E9,
		"water_johto": 0x2B11D,
		"grass_kanto": 0x2B274,
		"water_kanto": 0x2B7F7,
		"grass_johto_count": 61,
		"water_johto_count": 38,
		"grass_kanto_count": 30,
		"water_kanto_count": 24,
		"swarm_grass": 0x2B8D0,
		"swarm_grass_count": 2,
		"swarm_water": -1,
		"swarm_water_count": 0,
		"fish_groups": 0x92488,
		"fish_group_count": 13,
		"roam_maps": 0x2A40F,
		"roam_map_count": 16,
		"roaming": [
			{"species": 0xF3, "level": 40, "map_group": 2, "map_number": 5},
			{"species": 0xF4, "level": 40, "map_group": 10, "map_number": 4},
		],
		"tree_maps": 0xB825E,
		"tree_map_count": 34,
		"rock_maps": 0xB82C5,
		"rock_map_count": 4,
		"treemon_sets": 0xB82E8,
		"treemon_set_count": 9,
		# CheckSleepingTreeMon and data/wild/treemons_asleep.asm are Crystal
		# only; pokegold ships neither. File order is Nite, Day, Morn.
		"asleep_treemons": {"nite": 0x3EB5D, "day": 0x3EB69, "morn": 0x3EB6F},
		"bug_contest_mons": 0x97D87,  # See the Gold and Silver block above for how these two were located.
		"bug_contest_mon_count": 11,
		"bug_contestants": 0x13783,
		"bug_contestant_count": 10,
	},
	# Crystal's equivalent table is a contiguous $48-$5F, so the whole remap
	# collapses to a constant: PICS_FIX in pokecrystal.
	"pic_bank_add": 0x36,
	"pic_bank_patch": {},
}


## The layout for a game id, or an empty Dictionary if it is not characterised.
static func for_id(id: StringName) -> Dictionary:
	match id:
		RomRegistry.GOLD:
			return GOLD_SILVER
		RomRegistry.SILVER:
			var silver: Dictionary = GOLD_SILVER.duplicate(true)
			# Silver's copy of the icon bank sits twenty-six bytes lower than
			# Gold's, so both offsets into it move together.
			silver["overworld_icons"] = 0x8EAA4
			silver["held_item_icons"] = 0x8E8C1
			silver["item_attributes"] = 0x6866
			silver["item_status_actions"] = 0xF0C5
			silver["item_healing_hp"] = 0xF403
			silver["happiness_changes"] = 0x72C6
			# `CopyrightString` sits in bank 1 on both, sixty bytes apart.
			var copyright: Dictionary = (silver["copyright"] as Dictionary).duplicate()
			copyright["string"] = 0x64D9
			silver["copyright"] = copyright
			# The splash graphics sit in the same bank on both, 440 bytes apart.
			var presents: Dictionary = (
				silver["game_freak_presents"] as Dictionary
			).duplicate()
			presents["gfx"] = 0xE49C9
			presents["stars"] = 0xE4AA9
			silver["game_freak_presents"] = presents
			# `GoldSilverIntro`'s art sits in the same bank on both, the same 440
			# bytes apart as the splash graphics. Every other address the movie
			# reads is identical on the two cartridges, and so is the art itself.
			var gs_intro: Dictionary = (silver["gs_intro"] as Dictionary).duplicate()
			gs_intro["section"] = 0xE5330
			silver["gs_intro"] = gs_intro
			# Silver's logo bottom sits at Gold's address and its top 34 bytes
			# later. Its trail is four tiles rather than eight, which is why the
			# Lugia behind it starts 64 bytes earlier: `TitleScreen` copies 8
			# tiles either way, so Silver's last four are the head of the
			# compressed Lugia, loaded into VRAM and never drawn.
			var title: Dictionary = (silver["title"] as Dictionary).duplicate()
			title["logo_top"] = 0x98498
			title["tilemap"] = 0x9862A
			title["trail_tiles"] = 4
			title["bird"] = 0xE4220
			title["bird_tiles"] = 128
			silver["title"] = title
			return silver
		RomRegistry.CRYSTAL:
			return CRYSTAL
	return {}


static func is_characterised(id: StringName) -> bool:
	return not for_id(id).is_empty()


## Translates the bank number stored in a pic pointer into the bank the data is
## really in.
## The tables were written before the pic sections were shuffled between banks
## and nobody rebuilt them, so the game repairs each pointer as it loads it.
## Reproducing that is not optional: the stored numbers are simply wrong.
static func fix_pic_bank(layout: Dictionary, stored: int) -> int:
	var patch: Dictionary = layout["pic_bank_patch"]
	if patch.has(stored):
		return patch[stored]
	return stored + int(layout["pic_bank_add"])


## `LoadNamingScreenGFX`'s four sheets, which sit either side of the keyboard
## block in `engine/menus/naming_screen.asm`'s own order: the border and the
## cursor before it, then End, MiddleLine and UnderLine after. Nothing else is
## between them, so each is located from the block rather than pinned again.
## The whole 446-byte run is byte identical in all three dumps.
const NAMING_BORDER_TILES: int = 1
const NAMING_CURSOR_TILES: int = 2
const NAMING_MARKER_TILES: int = 1
const TILE_BYTES_2BPP: int = 16
const TILE_BYTES_1BPP: int = 8


## `PackGFX`, which the source stores immediately after `PackMenuGFX` and never
## points at except through `PackGFXPointers`' own offsets into it.
static func pack_gfx_offset(layout: Dictionary) -> int:
	return int((layout["pack"] as Dictionary)["menu_gfx"]) \
		+ PACK_MENU_TILES * TILE_BYTES_2BPP


static func naming_border_offset(layout: Dictionary) -> int:
	return int(layout["name_input_chars"]) \
		- (NAMING_BORDER_TILES + NAMING_CURSOR_TILES) * TILE_BYTES_2BPP


static func naming_cursor_offset(layout: Dictionary) -> int:
	return naming_border_offset(layout) + NAMING_BORDER_TILES * TILE_BYTES_2BPP


## `NamingScreenGFX_End` sits first after the block and is unreferenced in both
## pins, so the two markers the screen does draw are one and two tiles past it.
static func naming_middle_line_offset(layout: Dictionary) -> int:
	return int(layout["name_input_chars"]) + NAME_INPUT_BLOCK_BYTES + TILE_BYTES_1BPP


static func naming_under_line_offset(layout: Dictionary) -> int:
	return naming_middle_line_offset(layout) + TILE_BYTES_1BPP


## Where [param table] of NAME_INPUT_TABLE_ROWS starts, counted from the block
## in source order, since the four keyboards are stored back to back with no
## header between them.
static func name_input_table_offset(layout: Dictionary, table: int) -> int:
	var at: int = int(layout["name_input_chars"])
	for before: int in table:
		at += NAME_INPUT_TABLE_ROWS[before] * NAME_INPUT_ROW_BYTES
	return at


## Where [param table] of the two mail keyboards starts. The pair is stored back
## to back the way the four name keyboards are, and every mail table is the same
## six rows.
static func mail_input_table_offset(layout: Dictionary, table: int) -> int:
	return int((layout["mail"] as Dictionary)["input_chars"]) \
		+ table * MAIL_INPUT_TABLE_ROWS * MAIL_INPUT_ROW_BYTES


## The Battle Tower's own block, empty on a cartridge that has no tower.
static func battle_tower(layout: Dictionary) -> Dictionary:
	return layout.get("battle_tower", {}) as Dictionary


static func has_battle_tower(layout: Dictionary) -> bool:
	return not battle_tower(layout).is_empty()


## `BattleTowerMons` row [param index] of level group [param group], which is
## `AddNTimes` twice: once over a whole group and once over the row.
static func battle_tower_mon_offset(layout: Dictionary, group: int, index: int) -> int:
	return int(battle_tower(layout)["mons"]) \
		+ (group * BATTLETOWER_NUM_UNIQUE_MON + index) * BATTLETOWER_MON_BYTES


## One of the 120 `text_far` stubs, addressed the way `BattleTowerText` reaches
## it: the male array first, then the female one, and within a trainer the
## greeting, the loss line and the win line.
static func battle_tower_text_offset(layout: Dictionary, female: bool, trainer: int, kind: int) -> int:
	var base: int = int(battle_tower(layout)["trainer_text"])
	var row: int = (BATTLETOWER_MALE_TEXTS if female else 0) + trainer
	return base + (row * BATTLETOWER_TEXT_KINDS.size() + kind) * TEXT_FAR_STUB_BYTES


## `data/text_buffers.asm`'s StringBufferPointers, in `text_buffer` argument
## order: wStringBuffer3, 4, 5, then 2, 1, then the two battle nicknames. The
## table is what turns a `TX_RAM` address back into a buffer this project fills,
## and the addresses are WRAM, so they differ between Gold/Silver and Crystal.
const STRING_BUFFER_POINTER_COUNT: int = 7
const STRING_BUFFER_POINTER_SIZE: int = 2

## `STRING_BUFFER_LENGTH` (`constants/script_constants.asm`). The five general
## buffers are one contiguous run, which is what [method RomImporter.verify_layout]
## checks the table against.
const STRING_BUFFER_LENGTH: int = 19

## Indices into the table, from the comment on `TextCommand_STRINGBUFFER`
## (`home/text.asm:902`). Only the five general buffers are ordered by stride;
## the two nicknames live elsewhere in WRAM.
const STRING_BUFFER_3: int = 0
const STRING_BUFFER_4: int = 1
const STRING_BUFFER_5: int = 2
const STRING_BUFFER_2: int = 3
const STRING_BUFFER_1: int = 4


static func string_buffer_pointer_offset(layout: Dictionary, index: int) -> int:
	return int(layout["string_buffer_pointers"]) + index * STRING_BUFFER_POINTER_SIZE


static func species_name_offset(layout: Dictionary, species: int) -> int:
	return int(layout["species_names"]) + (species - 1) * NAME_LENGTH


static func base_stats_offset(layout: Dictionary, species: int) -> int:
	return int(layout["base_stats"]) + (species - 1) * BASE_STATS_SIZE


static func dex_entry_pointer_offset(layout: Dictionary, species: int) -> int:
	var pokedex: Dictionary = layout["pokedex"]
	return int(pokedex["entry_pointers"]) + (species - 1) * DEX_ENTRY_POINTER_SIZE


## The bank a species' Pokedex entry lives in, by
## `GetDexEntryPointer`'s `(species - 1) >> 6`.
static func dex_entry_bank(layout: Dictionary, species: int) -> int:
	var pokedex: Dictionary = layout["pokedex"]
	var banks: Array = pokedex["entry_banks"]
	return int(banks[(species - 1) / DEX_ENTRY_BANK_SPECIES])


## Where a species' Pokedex entry starts in the dump, given the bank-local
## [param address] read from the table.
static func dex_entry_offset(layout: Dictionary, species: int, address: int) -> int:
	return RomFile.linear(dex_entry_bank(layout, species), address)


## The palette table carries a leading entry before Bulbasaur, so unlike every
## other table here it is indexed by species number directly.
static func palette_offset(layout: Dictionary, species: int) -> int:
	return int(layout["palettes"]) + species * PokePalette.ENTRY_BYTES


## Pointers come in pairs, front then back.
## `AnimateFrontpic`'s tables, or empty for a game that has no pic animation at
## all. Only Crystal does; see the `pic_anim` block in [constant CRYSTAL].
static func pic_anim(layout: Dictionary) -> Dictionary:
	var value: Variant = layout.get("pic_anim", {})
	return value if value is Dictionary else {}


## `PokeAnim_CopyBitmaskToBuffer.GetSize`: how many bytes one bitmask is, for a
## pic [param height] tiles tall. `.Sizes: db 4, 5, 7`, indexed by `height - 5`.
static func pic_anim_bitmask_bytes(height: int) -> int:
	match height:
		5:
			return 4
		6:
			return 5
		7:
			return 7
	return 0


## `.GetTilemap`: an animation frame names a tile in the pic's own `w * h` run,
## and `PokeAnim_PlaceGraphic` fills a 7x7 box. A tile inside the pic is
## remapped through `poke_anim_box`, which is `PadFrontpic`'s own alignment
## again, and one past it takes the box's own 49 tiles as its offset.
static func pic_anim_box_tile(tile: int, height: int) -> int:
	if height >= FRONTPIC_MAX_TILES or height <= 0:
		return tile
	var square: int = height * height
	if tile >= square:
		return tile + FRONTPIC_MAX_TILES * FRONTPIC_MAX_TILES - square
	# `poke_anim_box`'s row is the pic's column and its column the pic's row,
	# which is `PlaceGraphic`'s column-major box read the other way up.
	@warning_ignore("integer_division")
	var column: int = tile / height
	var row: int = tile % height
	return (column + 1) * FRONTPIC_MAX_TILES + row + FRONTPIC_MAX_TILES - height


static func pic_pointer_offset(layout: Dictionary, species: int, back: bool) -> int:
	var pair: int = (species - 1) * 2 + (1 if back else 0)
	return int(layout["pic_pointers"]) + pair * PIC_POINTER_SIZE


static func unown_pic_pointer_offset(layout: Dictionary, form: int, back: bool) -> int:
	var pair: int = form * 2 + (1 if back else 0)
	return int(layout["unown_pic_pointers"]) + pair * PIC_POINTER_SIZE


## One of the four bar palettes, by its position in [constant BAR_PALETTE_NAMES].
static func bar_palette_offset(layout: Dictionary, index: int) -> int:
	return int(layout["bar_palettes"]) + index * PokePalette.PAIR_BYTES


static func trainer_class_count(layout: Dictionary) -> int:
	return int(layout["trainer_classes"])


static func map_group_count(layout: Dictionary, group: int) -> int:
	var counts: Array = layout.get("map_group_counts", [])
	if group < 1 or group > counts.size():
		return 0
	return int(counts[group - 1])


static func map_count(layout: Dictionary) -> int:
	var out: int = 0
	for count: int in layout.get("map_group_counts", []):
		out += count
	return out


static func map_group_pointer_offset(layout: Dictionary, group: int) -> int:
	return int(layout["map_group_pointers"]) + (group - 1) * MAP_GROUP_POINTER_SIZE


static func map_record_offset(layout: Dictionary, group_pointer: int, number: int) -> int:
	return RomFile.linear(bank_of(int(layout["map_group_pointers"])), group_pointer) \
		+ (number - 1) * MAP_RECORD_SIZE


static func tileset_count(layout: Dictionary) -> int:
	return (layout.get("tileset_block_counts", []) as Array).size()


static func tileset_offset(layout: Dictionary, number: int) -> int:
	return int(layout["tilesets"]) + number * TILESET_RECORD_SIZE


static func tileset_block_count(layout: Dictionary, number: int) -> int:
	var counts: Array = layout.get("tileset_block_counts", [])
	if number < 0 or number >= counts.size():
		return 0
	return int(counts[number])


static func overworld_sprite_offset(layout: Dictionary, number: int) -> int:
	return int(layout["overworld_sprites"]) + (number - 1) * OVERWORLD_SPRITE_RECORD_SIZE


static func overworld_sprite_count(layout: Dictionary) -> int:
	return int(layout.get("overworld_sprite_count", 0))


static func emote_offset(layout: Dictionary, index: int) -> int:
	return int(layout.get("emotes", -1)) + index * EMOTE_RECORD_SIZE


static func overworld_icon_offset(layout: Dictionary, number: int) -> int:
	return int(layout.get("overworld_icons", -1)) \
		+ (number - 1) * MON_ICON_BYTES


## `IconPointers`, which `engine/gfx/mon_icons.asm` INCLUDEs immediately in front
## of `gfx/icons.asm`, so the icons' own offset pins it.
static func icon_pointers_offset(layout: Dictionary) -> int:
	return int(layout.get("overworld_icons", -1)) - ICON_POINTER_COUNT * ICON_POINTER_SIZE


## `MonMenuIcons`, one icon number per species, INCLUDEd in front of
## `IconPointers` by the same file and pinned by the same offset.
static func mon_menu_icons_offset(layout: Dictionary) -> int:
	return icon_pointers_offset(layout) - SPECIES_COUNT


## Trainer pics have no back half and no size of their own, so unlike the
## Pokémon table this one is a flat run of three-byte pointers, indexed from the
## first class rather than from the player.
static func trainer_pic_pointer_offset(layout: Dictionary, trainer_class: int) -> int:
	return int(layout["trainer_pic_pointers"]) + (trainer_class - 1) * PIC_POINTER_SIZE


## The palette table opens with the player, who is a trainer class with no pic,
## so it is indexed by class number where the pic table is indexed by class
## number minus one. The two are one entry out of step on purpose.
static func trainer_palette_offset(layout: Dictionary, trainer_class: int) -> int:
	return int(layout["trainer_palettes"]) + trainer_class * PokePalette.PAIR_BYTES


## Where a trainer class's own pointer sits in the trainer party table. The
## pointer itself still has to be resolved through [method bank_of] on this
## offset and [method RomFile.linear], the same as [method evos_attacks_pointer_offset].
static func trainer_party_pointer_offset(layout: Dictionary, trainer_class: int) -> int:
	return int(layout["trainer_parties"]) + (trainer_class - 1) * TRAINER_PARTY_POINTER_SIZE


## A trainer class's own entry in the attributes table, indexed the same way as
## [method trainer_pic_pointer_offset] and [method trainer_party_pointer_offset]:
## from the first class rather than from the player.
static func trainer_attributes_offset(layout: Dictionary, trainer_class: int) -> int:
	return int(layout["trainer_attributes"]) + (trainer_class - 1) * TRAINER_ATTRIBUTES_SIZE


## A trainer class's own entry in the DVs table, indexed the same way as
## [method trainer_attributes_offset].
static func trainer_dvs_offset(layout: Dictionary, trainer_class: int) -> int:
	return int(layout["trainer_dvs"]) + (trainer_class - 1) * TRAINER_DVS_SIZE


## How many bytes one Pokémon occupies in a trainer's party, past its level and
## species: nothing for [constant TRAINER_MON_NORMAL], an item, four moves, or
## both, depending on the type byte its trainer opens with.
static func trainer_mon_extra_size(mon_type: int) -> int:
	var size: int = 0
	if mon_type == TRAINER_MON_ITEM or mon_type == TRAINER_MON_ITEM_MOVES:
		size += 1
	if mon_type == TRAINER_MON_MOVES or mon_type == TRAINER_MON_ITEM_MOVES:
		size += TRAINER_MON_MOVE_COUNT
	return size


static func move_data_offset(layout: Dictionary, move: int) -> int:
	return int(layout["move_data"]) + (move - 1) * MOVE_DATA_SIZE


## One species' entry in the combined evolution and level-up move table. The
## pointer is two bytes and the entry it names is in the pointer table's own
## bank, so [method bank_of] on the table itself resolves it.
static func evos_attacks_pointer_offset(layout: Dictionary, species: int) -> int:
	return int(layout["evos_attacks"]) + (species - 1) * EVOS_ATTACKS_POINTER_SIZE


## One species' pointer in EggMovePointers. The address has no bank byte; the
## table's bank is the list's bank too.
static func egg_move_pointer_offset(layout: Dictionary, species: int) -> int:
	return int(layout["egg_move_pointers"]) + (species - 1) * EGG_MOVE_POINTER_SIZE


## How many bytes one evolution entry occupies. [constant EVOLVE_STAT] carries a
## second parameter and so is a byte longer than the rest.
## The cartridge never needs this: it skips the evolutions by reading bytes until
## it meets the terminator, which works because no byte inside an entry is ever
## zero. Something that decodes them rather than skipping them does need it.
static func evolution_size(method: int) -> int:
	return 4 if method == EVOLVE_STAT else 3


## Type names are reached through a pointer table rather than stored inline,
## because every unused type number points at the same "NORMAL" string. The
## pointers are two bytes, not three: the strings sit in the table's own bank.
static func type_name_pointer_offset(layout: Dictionary, type_number: int) -> int:
	return int(layout["type_names"]) + type_number * TYPE_POINTER_SIZE


## Whether a byte is a type number the matchup chart could be talking about.
## The type numbers are sparse, and the run between the two groups is padding
## that a move's type byte may legitimately hold but that no matchup names. A
## walk that has left the table lands in that gap almost immediately, which is
## most of what makes this a check worth having.
static func is_matchup_type(value: int) -> bool:
	if value <= PHYSICAL_TYPES_END:
		return true
	return value >= SPECIAL_TYPES_START and value < TYPE_COUNT


## Where `OakRatings` row [param index] starts.
static func oak_rating_offset(layout: Dictionary, index: int) -> int:
	return int(layout.get("oak_ratings", -1)) + index * OAK_RATING_SIZE


## The dump offset one of `prof_oaks_pc.asm`'s five text stubs sits at, counted
## in stubs from `OakRating01`, whose address the table's first row carries.
static func oak_text_stub_offset(rom: RomFile, layout: Dictionary, name: String) -> int:
	var table: int = int(layout.get("oak_ratings", -1))
	if not rom.in_bounds(table, OAK_RATING_SIZE) or not OAK_TEXT_STUBS.has(name):
		return -1
	var first: int = rom.u16le(table + 3) + int(OAK_TEXT_STUBS[name]) * OAK_TEXT_STUB_SIZE
	return RomFile.linear(bank_of(table), first)


## Where the word for Unown form [param form] starts, form 1 being A.
## The pointer is bank-local, so the table's own bank is the whole address.
static func unown_word_offset(rom: RomFile, layout: Dictionary, form: int) -> int:
	var table: int = int(layout.get("unown_words", -1))
	if form < 0 or form >= UNOWN_WORD_ENTRIES:
		return -1
	if not rom.in_bounds(table, UNOWN_WORD_ENTRIES * UNOWN_WORD_POINTER_SIZE):
		return -1
	var pointer: int = rom.u16le(table + form * UNOWN_WORD_POINTER_SIZE)
	return RomFile.linear(bank_of(table), pointer)


## The letter [param code] spells under the `unown` charmap, or an empty string
## when it is not a code that charmap can produce.
static func unown_wall_letter(code: int) -> String:
	if code < 0 or code % 2 != 0:
		return ""
	@warning_ignore("integer_division")
	var block: int = code / UNOWN_WALL_BLOCK
	@warning_ignore("integer_division")
	var within: int = (code % UNOWN_WALL_BLOCK) / 2
	if within >= UNOWN_WALL_ROW_LETTERS:
		return ""
	var index: int = block * UNOWN_WALL_ROW_LETTERS + within
	if index >= UNOWN_WALL_ALPHABET.length():
		return ""
	return UNOWN_WALL_ALPHABET[index]


## Where the `text_far` stub [param name] names sits.
static func pokecenter_pc_text_offset(layout: Dictionary, name: String) -> int:
	var at: int = int(layout.get("pokecenter_pc", -1))
	if at < 0 or not POKECENTER_PC_TEXT_AT.has(name):
		return -1
	return at + int(POKECENTER_PC_TEXT_AT[name])


## Where the move deleter's `text_far` stub [param name] names sits.
static func move_deleter_text_offset(layout: Dictionary, name: String) -> int:
	var at: int = int(layout.get("move_deleter_text", -1))
	var index: int = MOVE_DELETER_TEXT_ORDER.find(name)
	if at < 0 or index < 0:
		return -1
	return at + index * TEXT_FAR_STUB_BYTES


## Where the `text_far` stub [param name] names sits inside the run [param run]
## of `SPECIAL_TEXT_RUNS`, or -1 when the cartridge does not ship that run.
static func special_text_offset(layout: Dictionary, run: String, name: String) -> int:
	for entry: Array in SPECIAL_TEXT_RUNS.get(run, []) as Array:
		var index: int = (entry[1] as Array).find(name)
		if index < 0:
			continue
		var at: int = int(layout.get(String(entry[0]), 0))
		return -1 if at <= 0 else at + index * TEXT_FAR_STUB_BYTES
	return -1


## Every stub name in [param run], in the order the runs list them.
static func special_text_names(run: String) -> Array[String]:
	var out: Array[String] = []
	for entry: Array in SPECIAL_TEXT_RUNS.get(run, []) as Array:
		for name: Variant in entry[1] as Array:
			out.append(String(name))
	return out


## Whether the cartridge [param layout] describes ships [param run] at all.
static func has_special_text_run(layout: Dictionary, run: String) -> bool:
	for entry: Array in SPECIAL_TEXT_RUNS.get(run, []) as Array:
		if int(layout.get(String(entry[0]), 0)) <= 0:
			return false
	return not (SPECIAL_TEXT_RUNS.get(run, []) as Array).is_empty()


## Where the Name Rater's `text_far` stub [param name] names sits.
static func name_rater_text_offset(layout: Dictionary, name: String) -> int:
	var at: int = int(layout.get("name_rater_text", -1))
	var index: int = NAME_RATER_TEXT_ORDER.find(name)
	if at < 0 or index < 0:
		return -1
	return at + index * TEXT_FAR_STUB_BYTES


## Where the Day-Care's `text_far` stub [param name] names sits, whichever of
## its four runs holds it.
static func day_care_text_offset(layout: Dictionary, name: String) -> int:
	for run: Array in DAY_CARE_TEXT_RUNS:
		var index: int = (run[1] as Array).find(name)
		if index < 0:
			continue
		var at: int = int(layout.get(run[0], -1))
		return -1 if at < 0 else at + index * TEXT_FAR_STUB_BYTES
	return -1


## Where the slot machine's `text_far` stub [param name] names sits, whichever
## of its three runs holds it.
static func slots_text_offset(layout: Dictionary, name: String) -> int:
	for run: Array in SLOTS_TEXT_RUNS:
		var index: int = (run[1] as Array).find(name)
		if index < 0:
			continue
		var at: int = int(layout.get(run[0], -1))
		return -1 if at < 0 else at + index * TEXT_FAR_STUB_BYTES
	return -1


## Every name the three runs above carry, in their own order.
static func slots_text_names() -> Array[String]:
	var out: Array[String] = []
	for run: Array in SLOTS_TEXT_RUNS:
		out.append_array(run[1] as Array[String])
	return out


## Where the mart's `text_far` stub [param name] names sits.
static func mart_text_offset(layout: Dictionary, name: String) -> int:
	var at: int = int(layout.get("mart_text", -1))
	if at < 0 or not MART_TEXT_AT.has(name):
		return -1
	return at + int(MART_TEXT_AT[name])


## `Credits_LoadBorderGFX.Frames`, as 16-tile block indices into the mon run.
static func credits_frames(layout: Dictionary) -> Array:
	var stored: Variant = (layout.get("credits", {}) as Dictionary).get("frames", [])
	return stored if stored is Array else []


## How many tiles the four mon sheets occupy together, which is what the highest
## block `.Frames` names says. Zero for a cartridge with no credits.
static func credits_mon_tiles(layout: Dictionary) -> int:
	var frames: Array = credits_frames(layout)
	if frames.is_empty():
		return 0
	var highest: int = 0
	for block: Variant in frames:
		highest = maxi(highest, int(block))
	return (highest + 1) * CREDITS_MON_FRAME_TILES


## Where `CreditsPichuGFX` and its three neighbours start: directly behind
## `CreditsBorderGFX`, which is the one offset pinned. -1 without a credits entry.
static func credits_mon_gfx_offset(layout: Dictionary) -> int:
	var at: int = int((layout.get("credits", {}) as Dictionary).get("gfx", -1))
	return at + CREDITS_BORDER_TILES * PokeTiles.TILE_BYTES if at >= 0 else -1


## The dump offset `CreditsStringsPointers` entry [param index] names. Its bank
## is the strings' own rather than the table's, since Gold and Silver reach them
## with `PlaceFarString`.
static func credits_string_offset(rom: RomFile, layout: Dictionary, index: int) -> int:
	var entry: Dictionary = layout.get("credits", {})
	var table: int = int(entry.get("strings", -1))
	if table < 0 or index < 0 or index >= int(entry.get("string_count", 0)):
		return -1
	var at: int = table + index * 2
	if not rom.in_bounds(at, 2):
		return -1
	return RomFile.linear(int(entry.get("strings_bank", 0)), rom.u16le(at))


## `PokedexNestIconGFX`, which `INCBIN`s directly behind `kanto.bin` in the same
## bank; -1 for a cartridge with no region map.
static func dex_nest_icon_offset(layout: Dictionary) -> int:
	var kanto: int = int((layout.get("town_map", {}) as Dictionary).get("kanto", -1))
	return kanto + TOWN_MAP_REGION_BYTES if kanto >= 0 else -1


## `FlyMapLabelBorderGFX`, one 2bpp tile behind the nest icon; -1 for a cartridge
## with no region map.
static func fly_map_label_offset(layout: Dictionary) -> int:
	var nest: int = dex_nest_icon_offset(layout)
	return nest + DEX_NEST_ICON_TILES * PokeTiles.TILE_BYTES if nest >= 0 else -1


static func landmark_count(layout: Dictionary) -> int:
	return int((layout.get("town_map", {}) as Dictionary).get("landmark_count", 0))


## Where landmark [param index]'s four-byte record starts.
static func landmark_offset(layout: Dictionary, index: int) -> int:
	var entry: Dictionary = layout.get("town_map", {})
	return int(entry.get("landmarks", -1)) + index * LANDMARK_RECORD_SIZE


## The dump offset landmark [param index]'s name pointer addresses. The pointer
## is two bytes, so the string is in the table's own bank.
static func landmark_name_offset(rom: RomFile, layout: Dictionary, index: int) -> int:
	var record: int = landmark_offset(layout, index)
	if not rom.in_bounds(record, LANDMARK_RECORD_SIZE):
		return -1
	return RomFile.linear(bank_of(record), rom.u16le(record + 2))


static func font_offset(layout: Dictionary) -> int:
	return int(layout["font"])


## `FontExtra` is the entry immediately before `Font` in `gfx/font.asm` on all
## three dumps, so the pinned font offset walks it too and it needs no address
## of its own. Its own content is what checks that (`verify_layout`).
static func font_extra_offset(layout: Dictionary) -> int:
	return font_offset(layout) - FONT_EXTRA_TILES * PokeTiles.TILE_BYTES


## `StatsScreenPageTilesGFX` is the entry immediately before
## `EnemyHPBarBorderGFX` in `gfx/font.asm` on all three dumps, so the pinned
## enemy HUD offset walks back to it and it needs no address of its own. Its own
## content is what checks that (`verify_layout`).
static func stats_tiles_offset(layout: Dictionary) -> int:
	return int(layout["enemy_hud"]) - STATS_TILES * PokeTiles.TILE_BYTES


## Frames are stored back to back in selection order, six tiles of 1bpp each.
static func frame_offset(layout: Dictionary, frame: int) -> int:
	return int(layout["frames"]) + frame * FRAME_TILES * PokeTiles.TILE_1BPP_BYTES


## The bank a dump offset falls in, for resolving a pointer that carries an
## address but no bank number of its own.
static func bank_of(offset: int) -> int:
	@warning_ignore("integer_division")
	return offset / RomFile.BANK_SIZE
