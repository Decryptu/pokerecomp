class_name Gen1Layout
extends RefCounted

## Where the data lives inside each Generation 1 cartridge, the counterpart of
## [Gen2Layout]. Offsets are absolute positions in the 1 MiB dump, so a decoder
## never thinks about banking. Red and Blue share every table here: the 668
## symbols that move between them are all bank $1D's map scripts.
## Every offset was read off pret's own build of the pinned sources, which
## reproduces each dump byte for byte (`roms.sha1` holds the three SHA-1s
## [RomRegistry] does). A table is still a claim about a specific dump, so an
## uncharacterised ROM is refused rather than guessed at.

## `NUM_POKEMON` and `NUM_POKEMON_INDEXES`: 151 dex entries over 190 cartridge
## slots, most of the difference being MISSINGNO. `MonsterNames`,
## `PokedexEntryPointers`, `EvosMovesPointerTable` and `CryData` are indexed by
## the slot; `BaseStats` and `MonsterPalettes` by dex number.
const SPECIES_COUNT: int = 151
const INDEX_COUNT: int = 190
const NAME_LENGTH: int = 10

## `BASE_DATA_SIZE` and the `BASE_*` members of `pokemon_data_constants.asm`.
const BASE_STATS_SIZE: int = 28
const BASE_DEX_NO: int = 0
const BASE_HP: int = 1
const BASE_ATTACK: int = 2
const BASE_DEFENSE: int = 3
const BASE_SPEED: int = 4
## One stat for both halves of the split Generation 2 introduced.
const BASE_SPECIAL: int = 5
const BASE_TYPE_1: int = 6
const BASE_TYPE_2: int = 7
const BASE_CATCH_RATE: int = 8
const BASE_EXP: int = 9
## One byte, width in the high nybble and height in the low one, in tiles.
const BASE_PIC_SIZE: int = 10
const BASE_FRONT_PIC: int = 11
const BASE_BACK_PIC: int = 13
const BASE_MOVES: int = 15
const BASE_MOVE_COUNT: int = 4
const BASE_GROWTH_RATE: int = 19
const BASE_TMHM: int = 20
const BASE_TMHM_BYTES: int = 7

## `NUM_ATTACKS` and the `move` macro's six bytes.
const MOVE_COUNT: int = 165
const MOVE_DATA_SIZE: int = 6
const MOVE_ANIMATION: int = 0
const MOVE_EFFECT: int = 1
const MOVE_POWER: int = 2
const MOVE_TYPE: int = 3
const MOVE_ACCURACY: int = 4
const MOVE_PP: int = 5

## `NUM_TYPES`. $09 to $13 are a hole `TypeNames` fills with NORMAL and nothing
## uses, kept out of the cache by [method is_real_type]. The physical run is $00
## to $08 and the special run starts at $14, deciding Attack or Special.
const TYPE_COUNT: int = 27
const TYPE_UNUSED_FIRST: int = 0x09
const TYPE_UNUSED_LAST: int = 0x13
const TYPE_SPECIAL_FIRST: int = 0x14

## `TypeEffects`: attacker, defender, multiplier, ending in $FF. The multiplier
## is in tenths, the same encoding Generation 2 kept, so the cached chart needs
## no conversion between the two.
const TYPE_EFFECT_SIZE: int = 3
const TYPE_EFFECT_END: int = 0xFF
const TYPE_EFFECT_NEUTRAL: int = 10

## `NUM_ITEMS`, and the three packed-decimal bytes of `bcd3`.
const ITEM_COUNT: int = 83
const ITEM_PRICE_SIZE: int = 3

## `NUM_TMS` and `NUM_HMS`: `TechnicalMachines` is one move number per row and
## the HMs follow the TMs. As items they sit above the named ones, `HM01` at $C4.
const TM_COUNT: int = 50
const HM_COUNT: int = 5
const HM_FIRST_ITEM: int = 0xC4
const TM_FIRST_ITEM: int = HM_FIRST_ITEM + HM_COUNT
## `GetMachineName` spells the name rather than reading one, and
## `GetMachinePrice` takes a nybble of `TechnicalMachinePrices` and multiplies by
## a thousand. `ret c` above it leaves an HM priceless.
const MACHINE_PRICE_UNIT: int = 1000

## A `PokedexEntry`: category, feet, inches, weight in tenths of a pound, then
## `text_far`'s $17 with a `dab` pointer to the description.
const DEX_TEXT_FAR: int = 0x17
const DEX_CATEGORY_MAX: int = 16

## Every near-pointer table in these cartridges is two bytes a row.
const POINTER_SIZE: int = 2

## `MonsterPalettes` names an SGB palette a row, `SuperPalettes` holds the four
## colours of each, and a DMG reads neither and shows four greys.
const SUPER_PALETTE_COLORS: int = 4
const SUPER_PALETTE_BYTES: int = SUPER_PALETTE_COLORS * PokePalette.COLOR_BYTES
## `NUM_SGB_PALS`: Yellow put Pikachu's Beach's three behind `PAL_GAMEFREAK` and
## recoloured every row above them.
const SUPER_PALETTE_COUNT_RED_BLUE: int = 37
const SUPER_PALETTE_COUNT_YELLOW: int = 40
const PAL_ROUTE: int = 0x00
const PAL_PALLET: int = 0x01
const PAL_GRAYMON: int = 0x19
const PAL_CAVE: int = 0x23
## The three rows `GetHealthBarColor` picks between, under the names
## [method GameData.bar_palette] takes them by. Generation 1 has no exp bar.
const HP_BAR_PALETTES: Dictionary = {
	"hp_green": 0x1F, "hp_yellow": 0x20, "hp_red": 0x21,
}

## `GBPalNormal`'s `rOBP0`, %11010000: an object's colours 1, 2 and 3 take
## shades 0, 1 and 3, so a sprite never shows the palette's third colour.
const OBJECT_SHADES: Array[int] = [0, 0, 1, 3]

## Evolutions by method until a zero byte, then (level, move) pairs until
## another; `EVOLVE_ITEM` is the only four-byte row.
const EVOLVE_LEVEL: int = 1
const EVOLVE_ITEM: int = 2
const EVOLVE_TRADE: int = 3
const EVOLVE_SIZES: Dictionary = {
	EVOLVE_LEVEL: 3,
	EVOLVE_ITEM: 4,
	EVOLVE_TRADE: 3,
}

## `CryData`: base cry, pitch and length.
const CRY_SIZE: int = 3

## `UncompressMonSprite`'s if-chain, as the first internal index of each bank:
## `TANGELA + 1`, `MOLTRES + 1`, `BEEDRILL + 2`, `STARMIE + 1`. The Kabutops
## fossil stands outside the run everywhere; Mew does too in Red and Blue, where
## it sits in bank 1 beside its own `BaseStats` row.
const PIC_BANK_THRESHOLDS: Array[int] = [0x1F, 0x4A, 0x74, 0x99]
const PIC_BANKS: Array[int] = [0x09, 0x0A, 0x0B, 0x0C, 0x0D]
const PIC_INDEX_MEW: int = 0x15
const PIC_INDEX_FOSSIL_KABUTOPS: int = 0xB6
const PIC_BANK_FOSSIL_KABUTOPS: int = 0x0B

## `FontGraphics` and `TextBoxGraphics`, which `LoadFontTilePatterns` and
## `LoadTextBoxTilePatterns` copy to `vFont` and `vChars2 tile $60`. Both are
## indexed by character code: a byte is already the tile that draws it. The text
## box's six border tiles at $79 are inside the second, where Generation 2 keeps
## a table of eight frames of its own.
const FONT_TILES: int = 128
const FONT_FIRST_CODE: int = 0x80
const FONT_EXTRA_TILES: int = 32
const FONT_EXTRA_FIRST_CODE: int = 0x60

## `MoveEffectPointerTable` in Crystal's own numbering, indexed by the effect
## byte a move row carries. `SpecialDamageEffect` and `PoisonEffect` each stand
## for several of Crystal's effects and split by move, which is the pair below.
const MOVE_EFFECTS: Array[int] = [
	0, 1, 2, 3, 4, 5, 6, 7, 8, 9, # $00 to $09, which Crystal kept in order
	10, 11, 12, 13, 15, 16, # the six UP1s, Crystal's SP_DEF_UP splitting them
	34, 17, # PAY_DAY, SWIFT
	18, 19, 20, 21, 23, 24, # the six DOWN1s
	30, 25, 26, 27, 28, 29, 29, 31, # CONVERSION to FLINCH_SIDE_EFFECT1
	1, 2, 4, 5, 6, 31, # the same six statuses again, always rather than on a roll
	38, 39, 40, 41, 42, 155, 44, 45, 46, 47, 48, 49, # OHKO to CONFUSION
	50, 51, 52, 53, 55, 56, # the six UP2s
	32, 57, # HEAL, TRANSFORM
	58, 59, 60, 61, 63, 64, # the six DOWN2s
	35, 65, 66, 67, # LIGHT_SCREEN, REFLECT, POISON, PARALYZE
	68, 69, 70, 71, # the four drops that ride on a hit
	0, 0, 0, 0, # $48 to $4B, which `const_skip` leaves without a pointer
	76, 77, 0, # CONFUSION_SIDE, TWINEEDLE, $4E
	79, 80, 81, 82, 83, 84, 85, 86, # SUBSTITUTE to DISABLE
]

## Those two entries split, `ChargeEffect`'s own `cp DIG`, and the two damage
## constants that come with the first: `SONICBOOM_DAMAGE` and
## `DRAGON_RAGE_DAMAGE` sit in the routine here and in the power column there.
const MOVE_EFFECT_BY_MOVE: Dictionary = {
	49: 41, 69: 87, 82: 41, 91: 155, 92: 33, 101: 87, 149: 88,
}
const MOVE_POWER_BY_MOVE: Dictionary = {49: 20, 82: 40}


static func move_effect(number: int, effect: int) -> int:
	if MOVE_EFFECT_BY_MOVE.has(number):
		return int(MOVE_EFFECT_BY_MOVE[number])
	return MOVE_EFFECTS[effect] if effect >= 0 and effect < MOVE_EFFECTS.size() else 0


static func move_power(number: int, power: int) -> int:
	return int(MOVE_POWER_BY_MOVE.get(number, power))


## What a battle loads over the middle of that box: `HpBarAndStatusGraphics` at
## $62 as 2bpp, `BattleHudTiles1` at $6d and `BattleHudTiles2` with
## `BattleHudTiles3` contiguous behind it at $73, both doubled from 1bpp.
const BATTLE_FONT_TILES: int = 30
const BATTLE_FONT_FIRST_CODE: int = 0x62
const BATTLE_HUD_1_TILES: int = 3
const BATTLE_HUD_1_FIRST_CODE: int = 0x6D
const BATTLE_HUD_2_TILES: int = 6
const BATTLE_HUD_2_FIRST_CODE: int = 0x73

## The battle animation layer, all of it in bank $1E: `AttackAnimationPointers`,
## `SubanimationPointers`, `FrameBlockPointers` and `FrameBlockBaseCoords` with
## their data interleaved between them, so the cache holds one region and every
## table resolves inside it.
const ANIM_COUNT_RED_BLUE: int = 203
## Yellow drops `ZigZagScreenAnim`, the one entry past `NUM_ATTACK_ANIMS`.
const ANIM_COUNT_YELLOW: int = 202
const SUBANIM_COUNT: int = 86
const FRAME_BLOCK_COUNT: int = 122
const BASE_COORD_COUNT: int = 177
const BASE_COORD_SIZE: int = 2
const SUBANIM_ROW_SIZE: int = 3
const FRAME_BLOCK_SPRITE_SIZE: int = 4
const SPECIAL_EFFECT_ROW_SIZE: int = 3

## One `battle_anim` row. A byte at or above `FIRST_SE_ID` names a special
## effect and takes a sound after it; anything below is a subanimation's tileset
## in the top two bits and its frame delay in the low six, then a sound and a
## subanimation id.
const ANIM_FIRST_SE_ID: int = 0xC0
const ANIM_END: int = 0xFF
## `NO_MOVE - 1`, the sound byte that plays nothing.
const ANIM_NO_SOUND: int = 0xFF
const ANIM_DELAY_MASK: int = 0x3F
const ANIM_TILESET_SHIFT: int = 6
const ANIM_SE_SIZE: int = 2
const ANIM_SUBANIM_SIZE: int = 3

## One `subanim` header: the count in the low five bits, the type in the top
## three.
const SUBANIM_COUNT_MASK: int = 0x1F
const SUBANIM_TYPE_SHIFT: int = 5
const SUBANIMTYPE_NORMAL: int = 0
const SUBANIMTYPE_HVFLIP: int = 1
const SUBANIMTYPE_HFLIP: int = 2
const SUBANIMTYPE_COORDFLIP: int = 3
const SUBANIMTYPE_REVERSE: int = 4
const SUBANIMTYPE_ENEMY: int = 5
const SUBANIMTYPE_COUNT: int = 6

## `FRAMEBLOCKMODE_*`. 02 keeps the sprites and skips the delay, 03 keeps them
## and takes it, 04 keeps them and does not advance the write position.
const FRAMEBLOCKMODE_COUNT: int = 5
const FRAMEBLOCKMODE_KEEP_NO_DELAY: int = 2
const FRAMEBLOCKMODE_KEEP: int = 3
const FRAMEBLOCKMODE_HOLD: int = 4

## What `DrawFrameBlock` flips a coordinate about, and the offset
## `SUBANIMTYPE_HFLIP` translates down by.
const ANIM_FLIP_Y: int = 136
const ANIM_FLIP_X: int = 168
const ANIM_HFLIP_DROP: int = 40

## `FallingObjects_DeltaXs` is nine bytes and `FallingObjects_UpdateMovementByte`
## only wraps a movement byte that reaches nine, so the two objects
## `FallingObjects_InitialMovementData` starts at nine walk off the end and read
## the routine's own machine code as their drift. The byte is masked to seven
## bits, so 128 is as far as one can reach; the two dumps disagree past the ninth
## and both are cached.
const FALLING_DELTA_BYTES: int = 128
const FALLING_DELTA_TABLE: int = 9

## `MoveAnimationTilesPointers`: three `anim_tileset` rows of a tile count, a
## bank-local pointer and a padding byte. Tileset 2 is tileset 0 cut short.
const ANIM_TILESET_COUNT: int = 3
const ANIM_TILESET_ROW_SIZE: int = 4
const ANIM_TILESET_TILES: int = 0
const ANIM_TILESET_POINTER: int = 1

## The bank every table above lives in, and `vSprites tile $31`, which
## `DrawFrameBlock` adds to a frame block's tile so the id is an index into the
## loaded tileset.
const ANIM_BANK: int = 0x1E
const ANIM_BASE_TILE: int = 0x31

## `SetAnimationPalette` on the Super Game Boy: `rOBP0` while a subanimation
## draws is `wAnimPalette`, $F0, and `rOBP1` is $6C throughout.
const ANIM_OBP0: int = 0xF0
const ANIM_OBP1: int = 0x6C
## The DMG palette bit of an OAM attribute byte, where Generation 2 keeps a
## three-bit Game Boy Color palette.
const ANIM_OAM_OBP1: int = 0x10

## `constants/move_constants.asm`: moves do double duty as animation ids, and
## these are the rows past `NUM_ATTACKS` that no move number names.
const ANIM_ID_SHOWPIC: int = 0xA6
const ANIM_ID_ENEMY_HUD_SHAKE: int = 0xA9
const ANIM_ID_TOSS: int = 0xC1
const ANIM_ID_SHAKE: int = 0xC2
const ANIM_ID_POOF: int = 0xC3
const ANIM_ID_BLOCKBALL: int = 0xC4
const ANIM_ID_GREATTOSS: int = 0xC5
const ANIM_ID_ULTRATOSS: int = 0xC6
const ANIM_ID_SHAKE_SCREEN: int = 0xC7
const ANIM_ID_HIDEPIC: int = 0xC8

## `ItemUsePtrTable`'s five `ItemUseBall` rows, which `TossBallAnimation` also
## picks a throw off.
const ITEM_MASTER_BALL: int = 0x01
const ITEM_ULTRA_BALL: int = 0x02
const ITEM_GREAT_BALL: int = 0x03
const ITEM_POKE_BALL: int = 0x04
const ITEM_SAFARI_BALL: int = 0x08

## `ItemUseBall`'s three per-ball numbers: the ceiling Rand1 is rerolled above,
## `BallFactor` and `BallFactor2`. SAFARI_BALL takes the fall-through below.
const BALL_ROLL: Dictionary = {
	ITEM_POKE_BALL: [255, 12, 255],
	ITEM_GREAT_BALL: [200, 8, 200],
	ITEM_ULTRA_BALL: [150, 12, 150],
}
const BALL_ROLL_OTHER: Array[int] = [150, 12, 150]

## `.checkForAilments` takes the first off Rand1 and `.addAilmentValue` adds the
## second to the shakes, each [any other status, frozen or asleep].
const BALL_STATUS_SUBTRACT: Array[int] = [12, 25]
const BALL_STATUS_ADD: Array[int] = [5, 10]

## `.setAnimData`'s ladder over Z: under ten the ball misses, and each threshold
## passed is one more rock.
const BALL_SHAKE_THRESHOLDS: Array[int] = [10, 30, 70]

## What pins the two sheets: the edge under both panels is two solid rows in
## the middle of six blank ones, and the empty bar is a rule top and bottom.
const HUD_BOTTOM_CODE: int = 0x76
const HUD_BOTTOM_ROWS: Array[int] = [0, 0, 0, 0xFF, 0xFF, 0, 0, 0]
const HP_BAR_EMPTY_CODE: int = 0x63
const HP_BAR_EMPTY_ROWS: Array[int] = [0, 0, 0xFF, 0, 0, 0xFF, 0, 0]

## What checks the two offsets: every code [Gen1Text] draws has ink, the hole
## between "'v" and "'" has none, the space is the text box's only blank tile,
## and the border's column is eight rows of one pattern.
const FONT_INK_RUNS: Array = [[0x80, 0xBF], [0xE0, 0xFF]]
const FONT_BLANK_RUNS: Array = [[0xC0, 0xDF]]
const SPACE_CODE: int = 0x7F
## `TextBoxBorder` prints `┌─┐│└┘`, the six codes `charmap.asm` puts at $79.
## Generation 2 spells them the same way in a table of eight frames.
const FRAME_FIRST_CODE: int = 0x79
const FRAME_LAST_CODE: int = 0x7E
const FRAME_VERTICAL_CODE: int = FRAME_FIRST_CODE + Gen2Layout.FRAME_VERTICAL
const FRAME_VERTICAL_ROW: int = 0b00101000

## `PokeCenterFlashingMonitorAndHealBall`: the monitor and one ball.
## `AnimateHealingMachine` copies three tiles where the sheet is two, so the
## third is `PokeCenterOAMData` read as pixels at $7e, which nothing draws.
const HEAL_MACHINE_VTILE: int = 0x7C
const HEAL_MACHINE_BYTES: Array[int] = [
	0x00, 0x00, 0x00, 0x00, 0x7E, 0x00, 0x7E, 0x00,
	0x7E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x0C, 0x0C, 0x12, 0x1E,
	0x21, 0x3F, 0x33, 0x2D, 0x1E, 0x12, 0x0C, 0x0C,
]

## `ShockEmote`, at the $F8 `EmotionBubblesOAMBlock` names. It is the one
## `EmotionBubbles` row with a caller: `CheckFightingMapTrainers`.
const SHOCK_EMOTE_VTILE: int = 0xF8
const SHOCK_EMOTE_BYTES: Array[int] = [
	0x1F, 0x00, 0x3F, 0x1F, 0x7F, 0x20, 0xFF, 0x41,
	0xFF, 0x41, 0xFF, 0x41, 0xFF, 0x41, 0xFF, 0x41,
	0xF8, 0x00, 0xFC, 0xF8, 0xFE, 0x04, 0xFF, 0x82,
	0xFF, 0x82, 0xFF, 0x82, 0xFF, 0x82, 0xFF, 0x82,
	0xFF, 0x40, 0xFF, 0x41, 0xFF, 0x41, 0x7F, 0x20,
	0x3F, 0x1F, 0x1F, 0x00, 0x01, 0x00, 0x01, 0x00,
	0xFF, 0x02, 0xFF, 0x82, 0xFF, 0x82, 0xFE, 0x04,
	0xFC, 0xF8, 0xF8, 0xC0, 0xC0, 0x80, 0x80, 0x00,
]

## `PokeCenterOAMData`'s seven rows as the cartridge stores them: y, x, tile and
## whether the attribute byte flips it. Yellow sets a Game Boy Color palette in
## that byte too, so only bit 5 is read.
const HEAL_MACHINE_OAM_SIZE: int = 4
const HEAL_MACHINE_OAM: Array = [
	[0x24, 0x34, 0x7C, false],
	[0x2B, 0x30, 0x7D, false], [0x2B, 0x38, 0x7D, true],
	[0x30, 0x30, 0x7D, false], [0x30, 0x38, 0x7D, true],
	[0x35, 0x30, 0x7D, false], [0x35, 0x38, 0x7D, true],
]
const HEAL_MACHINE_OAM_XFLIP: int = 0x20

## `rOBP1` as `AnimateHealingMachine` writes it, and the same byte once
## `FlashSprite8Times` has xored $28 into it: two shades swap places where
## Crystal rotates all four.
const HEAL_MACHINE_SHADES: Array = [[0, 0, 2, 3], [0, 2, 0, 3]]

## `TX_SCRIPT_*`: a text pointer standing at one of these opens a facility
## rather than a box, `DisplayTextID` dispatching before it prints.
const TEXT_SCRIPT_IDS: Dictionary = {
	0xF5: "vending machine", 0xF6: "cable club receptionist", 0xF7: "prize vendor",
	0xF9: "Pokemon Center PC", 0xFC: "the player's PC", 0xFD: "Bill's PC",
	0xFE: "mart", 0xFF: "Pokemon Center nurse",
}
const TEXT_SCRIPT_MART: int = 0xFE
const TEXT_SCRIPT_POKECENTER_NURSE: int = 0xFF
const TEXT_SCRIPT_CABLE_CLUB: int = 0xF6
const TEXT_SCRIPT_VENDING_MACHINE: int = 0xF5
const TEXT_SCRIPT_PRIZE_VENDOR: int = 0xF7

## `IsItemInBag COIN_CASE`, which `CeladonPrizeMenu` opens on.
const ITEM_COIN_CASE: int = 0x45

## `CeladonPrizeMenu`'s two stub runs, which are not one: the unreferenced
## `HereYouGoText` between them moves on Yellow.
const PRIZE_TEXT_AT: Dictionary = {
	"require_coin_case": 0x00, "exchange": 0x06, "which_prize": 0x0B,
}
const PRIZE_TEXT_2_AT: Dictionary = {
	"so_you_want": 0x00, "need_more_coins": 0x05, "bag_full": 0x0B,
	"oh_fine_then": 0x11,
}

## `PrizeDifferentMenuPtrs`: three `(entries, cost)` pairs, each list three long
## and `@` terminated, a cost being a `bcd2`. `.putMonName`'s own `cp 2` is what
## makes the third menu TMs and the two in front of it Pokemon.
const PRIZE_MENUS: int = 3
const PRIZE_ROWS: int = 3
const PRIZE_TM_MENU: int = 2
const PRIZE_COST_SIZE: int = 2
const PRIZE_POINTER_PAIR: int = 4
## `PrizeMonLevelDictionary`, the two Pokemon menus' six rows.
const PRIZE_MON_LEVELS: int = 6
const PRIZE_MON_LEVEL_SIZE: int = 2

## `engine/events/vending_machine.asm` from `VendingMachineText1`: the greeting,
## the two strings the box draws, `VendingPrices` and the four stubs behind them,
## at the same deltas on all three cartridges.
const VENDING_TEXT_AT: Dictionary = {
	"greeting": 0x00, "no_money": 0x3A, "here_you_go": 0x3F,
	"bag_full": 0x44, "not_thirsty": 0x49,
}
const VENDING_DRINKS_AT: int = 0x05
const VENDING_DRINKS_LENGTH: int = 0x25
const VENDING_CANCEL: String = "CANCEL"
const VENDING_PRICES_AT: int = 0x67
const VENDING_ROWS: int = 3
## `vend_item`: one item byte and a `bcd3` price.
const VENDING_ROW_SIZE: int = 4

## `CableClubNPC`'s stubs by the delta from the first. Only the three a port
## with no cable reaches are named; the rest want a link partner.
const CABLE_CLUB_TEXT_AT: Dictionary = {
	"area_reserved": 0x00, "welcome": 0x05, "making_preparations": 0x1F,
}

## `ld c, 60 / call DelayFrames` before the preparations line, and
## `wLinkTimeoutCounter`, one frame a pass of `.establishConnectionLoop`.
const CABLE_CLUB_PREPARING_FRAMES: int = 60
const CABLE_CLUB_TIMEOUT_FRAMES: int = 90

## `script_mart` writes its inventory into the text pointer itself: the $FE,
## a count, that many item ids, and a $FF nothing reads. `LoadItemList` copies
## the run into `wItemList`, which is 16 bytes, so a longer count is a bad read.
const MART_COUNT_AT: int = 1
const MART_ITEMS_AT: int = 2
const MART_MAX_ITEMS: int = 14

## A `text_far` stub is `TX_FAR`, a two-byte address, a bank byte and a
## `text_end`; a `text_pause` in front of one adds a byte, which is what makes
## the second run below irregular. Each run is contiguous with the same deltas on
## all three cartridges, so one pinned address apiece is enough.
const TEXT_FAR_STUB_BYTES: int = 5

## `engine/events/pokemart.asm`'s eleven stubs in file order, under the slot
## names [Gen2WorldServiceScreen] gives a shop's boxes. The greeting is not among
## them: `DisplayPokemartDialogue` prints it from home, so it is pinned alone.
const MART_TEXT_AT: Dictionary = {
	"buy_intro": 0x00, "final_price": 0x05, "thanks": 0x0A, "no_money": 0x0F,
	"pack_full": 0x14, "sell_intro": 0x19, "sell_price": 0x1E,
	"bag_empty": 0x23, "cant_buy": 0x28, "come_again": 0x2D, "ask_more": 0x32,
}

## `engine/events/pokecenter.asm`'s five, `shall_we_heal` and `farewell` each
## carrying a `text_pause` ahead of the stub.
const POKECENTER_TEXT_AT: Dictionary = {
	"welcome": 0x00, "shall_we_heal": 0x05, "need_your_pokemon": 0x0B,
	"fighting_fit": 0x10, "farewell": 0x15,
}

## `MapHeaderPointers` is flat: one `dw` a map id, with `MapHeaderBanks` beside
## it. `SwitchToMapRomBank` selects that bank once, which is what puts a map's
## blocks, objects, text and script in the bank its header sits in.
const MAP_COUNT_RED_BLUE: int = 248
const MAP_COUNT_YELLOW: int = 249

## `map_header`: tileset, height, width, the blocks, text and script pointers,
## then the connection byte; `end_map_header` puts the object pointer behind
## whatever connection records were emitted.
const MAP_HEADER_SIZE: int = 10
const MAP_CONNECTION_RECORD_SIZE: int = 11
const MAP_OBJECT_POINTER_SIZE: int = 2
const MAP_CONNECTION_FLAG_EAST: int = 1
const MAP_CONNECTION_FLAG_WEST: int = 2
const MAP_CONNECTION_FLAG_SOUTH: int = 4
const MAP_CONNECTION_FLAG_NORTH: int = 8

## `map_constants.asm`'s largest map.
const MAP_MAX_WIDTH_BLOCKS: int = 50
const MAP_MAX_HEIGHT_BLOCKS: int = 72

## The 22 ids `map_header_pointers.asm` marks UNUSED, the same 22 in all three.
## Their `dw` repeats a real header while their bank byte is a $01, $11 or $1D
## placeholder naming a different one, so the pair decodes to noise.
const UNUSED_MAPS: Array[int] = [
	0x0B, 0x69, 0x6A, 0x6B, 0x6D, 0x6E, 0x6F, 0x70, 0x72, 0x73, 0x74, 0x75,
	0xCC, 0xCD, 0xCE, 0xE7, 0xED, 0xEE, 0xF1, 0xF2, 0xF3, 0xF4,
]

## `MapSongBanks`: the map's music id and the bank that music lives in.
const MAP_SONG_SIZE: int = 2

## `<Map>_Object`: a border block, a counted list each of warps, signs and
## objects, then one `warp_to` a warp that names only WRAM.
const WARP_EVENT_SIZE: int = 4
const SIGN_EVENT_SIZE: int = 3
const OBJECT_EVENT_SIZE: int = 6
const WARP_TO_SIZE: int = 4
## `object_event` writes coordinates four higher, as Generation 2 does.
const OBJECT_COORD_BIAS: int = 4
## `TRAINER | text` and `ITEM | text`, each carrying extra bytes behind the row;
## `LoadMapHeader`'s `.loadSpriteLoop` masks the byte with $3F for the text id.
const OBJECT_TRAINER_FLAG: int = 0x40
const OBJECT_ITEM_FLAG: int = 0x80
const OBJECT_TEXT_MASK: int = 0x3F
const OBJECT_TRAINER_BYTES: int = 2
const OBJECT_ITEM_BYTES: int = 1
## `object_event`'s two movement bytes as one shared template. Byte 1 is WALK or
## STAY; byte 2 is a fixed direction, the axis a random walk keeps to, or
## `BOULDER_MOVEMENT_BYTE_2`. A STAY sprite still turns, because `TryWalking`
## writes the facing before `CanWalkOntoTile` refuses its step.
const OBJECT_MOVEMENT_STAY: int = 0xFF
const OBJECT_STANDING_MOVEMENTS: Dictionary = {
	0x10: Gen2WorldObject.MOVEMENT_STRENGTH_BOULDER,
	0xD0: Gen2WorldObject.MOVEMENT_FIXED_DOWN,
	0xD1: Gen2WorldObject.MOVEMENT_FIXED_UP,
	0xD2: Gen2WorldObject.MOVEMENT_FIXED_LEFT,
	0xD3: Gen2WorldObject.MOVEMENT_FIXED_RIGHT,
}
const OBJECT_WALKING_MOVEMENTS: Dictionary = {
	0x01: Gen2WorldObject.MOVEMENT_WALK_UP_DOWN,
	0x02: Gen2WorldObject.MOVEMENT_WALK_LEFT_RIGHT,
}
## `CanWalkOntoTile`'s two displacement counters, $8 apiece at map load and the
## whole of a wanderer's band. Down and right are never refused, up stops at 0,
## and the vertical test also stands in front of a sideways step, so an object
## that walked five cells up can only keep going up.
const OBJECT_WALK_ORIGIN: int = 8
const OBJECT_WALK_FLOOR: int = 5
## `InitBattleEnemyParameters`' `cp OPP_ID_OFFSET`: the extra byte is this plus
## a trainer class, or below it a species, and the next its number or level.
const OPPONENT_ID_OFFSET: int = 200
## `trainer`'s twelve bytes, which a `text_asm` row's `ld hl` names: the bit
## `TrainerFlagAction` counts off the address behind it, the range
## `CheckSpriteCanSeePlayer` compares in pixels, then three texts and a spare.
const TRAINER_HEADER_SIZE: int = 12
const TRAINER_HEADER_AT: Dictionary = {
	"flag_bit": 0, "range": 1, "flag_address": 2,
	"before": 4, "after": 6, "end": 8,
}
const TRAINER_HEADER_END: int = 0xFF
const TRAINER_RANGE_SHIFT: int = 4
## `TX_ASM`, and the opcodes a row behind it is read with. Any opcode not here
## ends the path [method Gen1WorldImporter.decode_script] is walking.
const TEXT_ASM: int = 0x08
const SCRIPT_LD_HL: int = 0x21
const SCRIPT_LD_BC: int = 0x01
const SCRIPT_LD_B: int = 0x06
const SCRIPT_LD_A: int = 0x3E
const SCRIPT_LD_A_MEM: int = 0xFA
const SCRIPT_LD_MEM_A: int = 0xEA
const SCRIPT_LDH_MEM_A: int = 0xE0
const SCRIPT_AND_A: int = 0xA7
const SCRIPT_PREFIX: int = 0xCB
const SCRIPT_JR: int = 0x18
const SCRIPT_JP: int = 0xC3
const SCRIPT_RET: int = 0xC9
const SCRIPT_CALL: int = 0xCD
const SCRIPT_HRAM_BASE: int = 0xFF00
## Each key is a conditional `jr` or `jp`, the value whether it is taken when
## the tested bit was set; the carry rows read the flag a routine answers in.
const SCRIPT_BRANCHES: Dictionary = {0x20: true, 0xC2: true, 0x28: false, 0xCA: false}
const SCRIPT_CARRY_BRANCHES: Dictionary = {0x38: true, 0xDA: true, 0x30: false, 0xD2: false}
const SCRIPT_CALLS: Array[String] = [
	"print_text", "text_script_end", "disable_waiting", "yes_no_choice",
	"give_item", "is_item_in_bag", "bankswitch", "play_cry", "wait_for_sound",
]
const SCRIPT_SHORT_SIZE: int = 2
const SCRIPT_LONG_SIZE: int = 3
## The `CB` prefix's three rows, the low three bits naming the operand.
const SCRIPT_BIT_BASE: int = 0x40
const SCRIPT_RES_BASE: int = 0x80
const SCRIPT_SET_BASE: int = 0xC0
const SCRIPT_OPERAND_A: int = 7
const SCRIPT_OPERAND_HL: int = 6
## `flag_array NUM_EVENTS`: 2,560 events on all three cartridges.
const EVENT_FLAG_BYTES: int = 320
## `BAG_ITEM_CAPACITY`: one list of slots, not four pockets.
const BAG_ITEM_CAPACITY: int = 20
## `MAX_WARP_EVENTS`, `MAX_BG_EVENTS` and `MAX_OBJECT_EVENTS`.
const MAX_WARP_EVENTS: int = 32
const MAX_SIGN_EVENTS: int = 16
const MAX_OBJECT_EVENTS: int = 16
## `warp_event`'s indoor exit: `wLastMap`, the outdoor map the player came from.
const WARP_TO_LAST_MAP: int = 0xFF
## `ExtraWarpCheck`'s four named maps, which take the warp-carpet test their own
## tileset would not give them, and the two the routine answers by hand:
## SS Anne 3F asks for the map edge instead, and the Bow has one carpet tile.
const WARP_CARPET_MAPS: Array[int] = [0x52, 0xC7, 0xC8, 0xCA]
const MAP_SS_ANNE_3F: int = 0x61
const MAP_SS_ANNE_BOW: int = 0x63
const SS_ANNE_BOW_WARP_TILE: int = 0x15

## The map ids `SetPal_Overworld` splits on; only the link rooms are Yellow's.
const NUM_CITY_MAPS: int = 0x0B
const FIRST_INDOOR_MAP: int = 0x25
const CERULEAN_CAVE_2F: int = 0xE2
const CERULEAN_CAVE_1F: int = 0xE4
const TRADE_CENTER: int = 0xEF
const COLOSSEUM: int = 0xF0
const LORELEIS_ROOM: int = 0xF5
const BRUNOS_ROOM: int = 0xF6

## `GetBattleTransitionID_IsDungeonMap`: `DungeonMaps1`'s four ids and
## `DungeonMaps2`'s four inclusive ranges. The file's own comment lists the
## dungeons the pair misses, Victory Road 2F and Diglett's Cave among them.
const DUNGEON_MAPS: Array[int] = [0x33, 0x52, 0xC0, 0xE8]
const DUNGEON_MAP_RANGES: Array = [
	[0x3B, 0x3D], [0x5F, 0x76], [0x8D, 0x97], [0xCF, 0xE4],
]

## The `tileset` macro: the bank holding both graphics and blocks, the three
## pointers, three counter tiles, the grass tile and the animation kind, with
## $FF for "none" in all four tile columns.
const TILESET_RECORD_SIZE: int = 12
const TILESET_COUNT_RED_BLUE: int = 24
const TILESET_COUNT_YELLOW: int = 25
const TILESET_COUNTER_TILES: int = 3
const TILESET_NO_TILE: int = 0xFF
## `MAP_TILESET_SIZE`: `LoadTilesetTilePatternData` copies this many tiles to
## `vTileset` whatever the tileset holds, so a short one's tail is whatever
## follows it in the bank.
const TILESET_TILE_COUNT: int = 96
const TILESET_BLOCK_TILES: int = MAP_BLOCK_TILE_WIDTH * MAP_BLOCK_TILE_WIDTH

## Blocks per tileset, in table order. Nothing in the cartridge records it:
## `<Tileset>_Block` is an INCBIN whose length only the assembler knew. Read off
## the pinned checkouts' `.bst` files, and bracketed at import by the blocks the
## maps use and by where the next tileset's graphics start.
const TILESET_BLOCKS_RED_BLUE: Array[int] = [
	128, 19, 37, 128, 19, 116, 37, 116, 35, 128, 128, 17,
	128, 62, 23, 110, 58, 128, 79, 72, 58, 36, 128, 73,
]
## Yellow gave the Mart and Pokemon Center three more and added the Beach House.
const TILESET_BLOCKS_YELLOW: Array[int] = [
	128, 19, 40, 128, 19, 116, 40, 116, 35, 128, 128, 17,
	128, 62, 23, 110, 58, 128, 79, 72, 58, 36, 128, 73, 20,
]

## `WaterTilesets`, a $FF-terminated list, and the tile
## `IsNextTileShoreOrWater` calls water on one of them.
const TILESET_LIST_END: int = 0xFF
const WATER_TILE: int = 0x14

## The two tilesets `SetPal_Overworld` tests before the map id, the two
## `CheckIfInOutsideMap` calls a town or a route, and the two beside them that
## `ExtraWarpCheck` reads a carpet on.
const TILESET_CEMETERY: int = 15
const TILESET_CAVERN: int = 17
const TILESET_OVERWORLD: int = 0
const TILESET_PLATEAU: int = 23
const TILESET_FOREST: int = 3
const TILESET_SHIP: int = 13
const TILESET_SHIP_PORT: int = 14

## `WildDataPointers`, one `dw` a map id and $FFFF behind the last. A block is
## its rate byte alone when the rate is zero and `WILDDATA_LENGTH` otherwise,
## ten (level, species) pairs behind it; grass first, water in the same shape.
const WILD_SLOT_COUNT: int = 10
const WILD_DATA_LENGTH: int = 1 + WILD_SLOT_COUNT * 2
const WILD_POINTERS_END: int = 0xFFFF

## `WildMonEncounterSlotChances`, as the cumulative byte each slot wins on; its
## second column is the slot doubled, and the ten sum to 256.
const WILD_CHANCE_SIZE: int = 2
const WILD_SLOT_CHANCES: Array[int] = [50, 101, 140, 165, 190, 215, 228, 241, 252, 255]

## `GoodRodMons`. The Old Rod has no table: `ItemUseOldRod` carries its one pair
## as `lb bc, 5, MAGIKARP`, and neither rod reads the map.
const GOOD_ROD_SLOTS: Array = [[10, 0x9D], [10, 0x47]]

## `SuperRodData`, a map id and a pointer to `count` (level, species) rows that
## `ReadSuperRodData` picks between by rejecting a two-bit roll. Yellow's
## `SuperRodFishingSlots` is one row a map, four (species, level) pairs picked by
## a byte threshold. Both end on $FF where a map id would be.
const SUPER_ROD_ROW_SIZE: int = 3
const SUPER_ROD_ROW_SIZE_YELLOW: int = 9
const SUPER_ROD_SLOTS_YELLOW: int = 4
const SUPER_ROD_THRESHOLDS_YELLOW: Array[int] = [0x65, 0xB1, 0xE4, 0xFF]
const SUPER_ROD_MAX_SLOTS: int = 4
const ROD_LIST_END: int = 0xFF

## A walk cell's collision tile is the bottom-left of its 2x2 quarter of the
## block, the corner Generation 2 also picks. `_GetTileAndCoordsInFrontOfPlayer`
## reads (8, 11), (8, 7), (6, 9) and (10, 9) and the player's cell starts at
## screen (8, 8); reading them as top-left leaves 53 of Red's 226 maps with no
## cell a player can stand on, the Pokemon Centers among them.
const MAP_BLOCK_TILE_WIDTH: int = 4
const MAP_BLOCK_CELL_WIDTH: int = 2

## `SpriteSheetPointerTable`: a CPU address, the bytes of one half and the bank,
## with a picture id one past the row. `LoadMapSpriteTilePatterns` reads a row
## below `FIRST_STILL_SPRITE` twice, the second time $C0 further on, which is the
## `$80` the walking rows of `SpriteFacingAndAnimationTable` add.
const SPRITE_RECORD_SIZE: int = 4
const SPRITE_COUNT_RED_BLUE: int = 72
const SPRITE_COUNT_YELLOW: int = 82
const SPRITE_STILL_FIRST_RED_BLUE: int = 0x3D
const SPRITE_STILL_FIRST_YELLOW: int = 0x47
const SPRITE_WALKING_TILES: int = 12
const SPRITE_STILL_TILES: int = 4

## `NUM_TRAINERS`, the trainer classes rather than the individual trainers.
const TRAINER_CLASS_COUNT: int = 47

## `TrainerPicAndMoneyPointers`: a near pointer and the class's base reward
## money as three packed-decimal bytes. Every trainer picture is in the one bank
## the layout records, and `ChiefPic` and `ScientistPic` are the same address.
const TRAINER_PIC_SIZE: int = 5
## `ReadTrainerParty`'s `cp $ff`: a party opening on this stores a level in
## front of every species instead of one for the whole team.
const TRAINER_PARTY_LEVELS: int = 0xFF

## Sides in tiles: `_LoadTrainerPic`'s `ld a, $77`, the widest front pic, and
## every back pic, which `ScaleSpriteByTwo` doubles before a battle draws it.
const TRAINER_PIC_TILES: int = 7
const FRONTPIC_MAX_TILES: int = 7
const BACKPIC_TILES: int = 4

## `GetTrainerBackpic`'s counterpart, in the `player_back` atlas's slot order:
## the player, and the old man who borrows the screen for the catching tutorial.
const PLAYER_BACKPICS: Array[String] = ["player", "old_man"]

const RED_BLUE: Dictionary = {
	"species_names": 0x1C21E,
	"base_stats": 0x383DE,
	## Mew's row and its pic bank stand outside Red and Blue's tables. Yellow
	## put both back in the run, where these are zero.
	"mew_base_stats": 0x0425B,
	"pic_mew_bank": 0x01,
	"dex_order": 0x41024,
	"dex_entries": 0x4047E,
	"dex_entries_bank": 0x10,
	"moves": 0x38000,
	"move_names": 0xB0000,
	"type_names": 0x27DAE,
	"type_names_bank": 0x09,
	"type_effects": 0x3E474,
	"item_names": 0x0472B,
	"item_prices": 0x04608,
	"tm_prices": 0x7BFA7,
	"tmhm_moves": 0x13773,
	"mon_palettes": 0x725C8,
	"super_palettes": 0x72660,
	"trainer_names": 0x399FF,
	"evos_moves": 0x3B05C,
	"evos_moves_bank": 0x0E,
	"cries": 0x39446,
	"trainer_pics": 0x39914,
	"trainer_pics_bank": 0x13,
	## `TrainerDataPointers` and the `TrainerAI` that bounds the last class.
	"trainer_parties": 0x39D3B,
	"trainer_parties_end": 0x3A52E,
	## What a trainer header is read through, and what one of its texts may be.
	"talk_to_trainer": 0x31CC,
	"print_text": 0x3C49,
	"event_flags": 0xD747,
	## The rest of what `decode_script` reads; a row calling anything else is not.
	"text_script_end": 0x24D7,
	"yes_no_choice": 0x35EC,
	"disable_waiting": 0x30B6,
	"play_cry": 0x13D0,
	"wait_for_sound": 0x3748,
	"give_item": 0x3E2E,
	"is_item_in_bag": 0x3493,
	"bankswitch": 0x35D6,
	"remove_item": 0x7F37,
	"remove_item_bank": 0x05,
	"do_not_wait": 0xCC3C,
	"current_menu_item": 0xCC26,
	"item_to_remove": 0xFFDB,
	## `DisplayPokemartDialogue`'s own greeting and the head of the two facility
	## text runs [constant MART_TEXT_AT] and its neighbour walk. Every offset
	## here is `pokered.sym`'s, which builds both dumps.
	"mart_greeting": 0x02A55,
	"mart_text": 0x06E0C,
	"pokecenter_text": 0x0705D,
	"cable_club_text": 0x072B3,
	"vending_text": 0x74F99,
	"prize_text": 0x5277E,
	"prize_text_2": 0x52960,
	"prize_menus": 0x52843,
	"prize_mon_levels": 0x5298A,
	"font": 0x11A80,
	"text_box": 0x12288,
	"battle_font": 0x11EA0,
	"battle_hud_1": 0x12080,
	"battle_hud_2": 0x12098,
	"pic_player_back": 0x33E0A,
	"pic_old_man_back": 0x33E9A,
	"map_headers": 0x001AE,
	"map_header_banks": 0x0C23D,
	"map_songs": 0x0C04D,
	"tilesets": 0x0C7BE,
	"water_tilesets": 0x0E8E0,
	"overworld_sprites": 0x17B27,
	"heal_machine_gfx": 0x704B7,
	"shock_emote_gfx": 0x17CBD,
	"wild_data": 0x0CEEB,
	"wild_chances": 0x13918,
	"good_rod": 0x0E27F,
	"super_rod": 0x0E919,
	## `data/battle_anims`, every one of them in bank $1E and reached from
	## `AttackAnimationPointers`.
	"attack_anims": 0x7A07D,
	"subanims": 0x7A76D,
	"frame_blocks": 0x7AF74,
	"base_coords": 0x7BC85,
	"special_effects": 0x790DA,
	"anim_tilesets": 0x781F2,
	"falling_deltas": 0x79D0D,
	## `_IsTilePassable` and the lists it walks share a bank, and the pointer in
	## a tileset row names no bank of its own. Red and Blue keep both in home.
	"tileset_collision_bank": 0x00,
}

const YELLOW: Dictionary = {
	"species_names": 0xE8000,
	"base_stats": 0x383DE,
	"mew_base_stats": 0,
	"pic_mew_bank": 0,
	"dex_order": 0x410B1,
	"dex_entries": 0x4050B,
	"dex_entries_bank": 0x10,
	"moves": 0x38000,
	"move_names": 0xBC000,
	"type_names": 0x27D63,
	"type_names_bank": 0x09,
	"type_effects": 0x3E5FA,
	"item_names": 0x045B7,
	"item_prices": 0x04494,
	"tm_prices": 0xF65F5,
	"tmhm_moves": 0x1232D,
	"mon_palettes": 0x72921,
	"super_palettes": 0x729B9,
	"trainer_names": 0x3997E,
	"evos_moves": 0x3B1E5,
	"evos_moves_bank": 0x0E,
	"cries": 0x39462,
	"trainer_pics": 0x39893,
	"trainer_pics_bank": 0x13,
	"trainer_parties": 0x39DD1,
	"trainer_parties_end": 0x3A5B2,
	"talk_to_trainer": 0x3168,
	"print_text": 0x3C36,
	"event_flags": 0xD746,
	"text_script_end": 0x23D2,
	"yes_no_choice": 0x35EF,
	"disable_waiting": 0x2FDE,
	"play_cry": 0x118B,
	"wait_for_sound": 0x373E,
	"give_item": 0x3E3F,
	"is_item_in_bag": 0x3422,
	"bankswitch": 0x3E84,
	"remove_item": 0x7DBB,
	"remove_item_bank": 0x05,
	"do_not_wait": 0xCC3C,
	"current_menu_item": 0xCC26,
	"item_to_remove": 0xFFDB,
	"mart_greeting": 0x02938,
	"mart_text": 0x06B91,
	"pokecenter_text": 0x06ED0,
	"cable_club_text": 0x07188,
	"vending_text": 0x747DE,
	"prize_text": 0x526DF,
	"prize_text_2": 0x528C0,
	"prize_menus": 0x527AE,
	"prize_mon_levels": 0x528EA,
	"font": 0x10600,
	"text_box": 0x10E18,
	"battle_font": 0x10A20,
	"battle_hud_1": 0x10C00,
	"battle_hud_2": 0x10C18,
	## Yellow moved both back pics out of "Pics 4" and into their own bank.
	"pic_player_back": 0xF43B1,
	"pic_old_man_back": 0xF4441,
	"map_headers": 0xFC1F2,
	"map_header_banks": 0xFC3E4,
	"map_songs": 0xFC000,
	"tilesets": 0x0C558,
	"water_tilesets": 0x0E834,
	"overworld_sprites": 0x142A9,
	"heal_machine_gfx": 0x7050B,
	"shock_emote_gfx": 0x411E5,
	"wild_data": 0x0CB95,
	"wild_chances": 0x138E2,
	"good_rod": 0x0E12C,
	## Yellow's is a flat slot table rather than an index into groups.
	"super_rod": 0xF5EDA,
	"attack_anims": 0x7A22A,
	"subanims": 0x7A915,
	"frame_blocks": 0x7B11C,
	"base_coords": 0x7BE2D,
	"special_effects": 0x79145,
	"anim_tilesets": 0x7822B,
	"falling_deltas": 0x79E96,
	"tileset_collision_bank": 0x01,
}


## Bank $1D holds the 668 symbols that move between Red and Blue: everything in
## it sits one byte later on Blue.
const BLUE_ONLY: Dictionary = {
	"vending_text": 0x74F9A,
}

static var _blue: Dictionary = RED_BLUE.merged(BLUE_ONLY, true)


static func for_id(id: StringName) -> Dictionary:
	match id:
		RomRegistry.RED:
			return RED_BLUE
		RomRegistry.BLUE:
			return _blue
		RomRegistry.YELLOW:
			return YELLOW
	return {}


static func is_characterised(id: StringName) -> bool:
	return not for_id(id).is_empty()


## A type number the cartridge really uses.
static func is_real_type(type: int) -> bool:
	return type < TYPE_UNUSED_FIRST or type > TYPE_UNUSED_LAST


## Whether a move of this type takes Special rather than Attack: Generation 1
## splits on the type, which is what `SPECIAL EQU const_value` marks.
static func is_special_type(type: int) -> bool:
	return type >= TYPE_SPECIAL_FIRST


## Takes an internal index from 1 to [constant INDEX_COUNT].
static func species_name_offset(layout: Dictionary, index: int) -> int:
	return int(layout["species_names"]) + (index - 1) * NAME_LENGTH


## `GetMonHeader`: the row is the dex number less one, with Mew's own exception.
static func base_stats_offset(layout: Dictionary, dex: int) -> int:
	var mew: int = int(layout["mew_base_stats"])
	if dex == SPECIES_COUNT and mew != 0:
		return mew
	return int(layout["base_stats"]) + (dex - 1) * BASE_STATS_SIZE


static func move_offset(layout: Dictionary, move: int) -> int:
	return int(layout["moves"]) + (move - 1) * MOVE_DATA_SIZE


## `PokedexOrder` inverted: dex number to internal index, row 0 unused so a dex
## number indexes it directly.
static func index_of_dex(rom: RomFile, layout: Dictionary) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(Gen1Layout.SPECIES_COUNT + 1)
	var order: int = int(layout["dex_order"])
	for index: int in range(1, Gen1Layout.INDEX_COUNT + 1):
		var dex: int = rom.u8(order + index - 1)
		if dex >= 1 and dex <= Gen1Layout.SPECIES_COUNT:
			out[dex] = index
	return out


## `PokedexOrder` read forwards: the dex number an internal index carries, or
## zero for a slot no species claims.
static func dex_of_index(rom: RomFile, layout: Dictionary, index: int) -> int:
	if index < 1 or index > Gen1Layout.INDEX_COUNT:
		return 0
	return rom.u8(int(layout["dex_order"]) + index - 1)


## A `dw` or a `dab` inside a banked cartridge: below $4000 is home, whatever
## bank is switched in, so a pointer that carries no bank of its own is resolved
## against the one it was read from only above that line.
static func banked(bank: int, address: int) -> int:
	return RomFile.linear(0 if address < RomFile.BANK_SIZE else bank, address)


## One facility box's `text_far` stub: the run's own pinned head plus the slot's
## delta. [param slots] is [constant MART_TEXT_AT] or its neighbour.
## Answers -1 for a slot the table does not name.
static func facility_text_offset(
	layout: Dictionary, run: String, slots: Dictionary, name: String
) -> int:
	var at: int = int(layout.get(run, 0))
	if at <= 0 or not slots.has(name):
		return -1
	return at + int(slots[name])


static func item_price_offset(layout: Dictionary, item: int) -> int:
	return int(layout["item_prices"]) + (item - 1) * ITEM_PRICE_SIZE


static func cry_offset(layout: Dictionary, index: int) -> int:
	return int(layout["cries"]) + (index - 1) * CRY_SIZE


## The pic behind one row of `TrainerPicAndMoneyPointers`.
static func trainer_pic_offset(rom: RomFile, layout: Dictionary, trainer_class: int) -> int:
	var row: int = int(layout["trainer_pics"]) + (trainer_class - 1) * TRAINER_PIC_SIZE
	return RomFile.linear(int(layout["trainer_pics_bank"]), rom.u16le(row))


## The tile one character code draws from: `FontGraphics` is 1bpp from $80,
## `TextBoxGraphics` 2bpp from $60.
static func font_glyph_offset(layout: Dictionary, code: int) -> int:
	return int(layout["font"]) + (code - FONT_FIRST_CODE) * PokeTiles.TILE_1BPP_BYTES


static func text_box_glyph_offset(layout: Dictionary, code: int) -> int:
	return int(layout["text_box"]) + (code - FONT_EXTRA_FIRST_CODE) * PokeTiles.TILE_BYTES


## `NUM_POKEMON + 1` rows in dex order with MISSINGNO's first, so the dex number
## is the row.
static func mon_palette_offset(layout: Dictionary, dex: int) -> int:
	return int(layout["mon_palettes"]) + dex


static func super_palette_offset(layout: Dictionary, palette: int) -> int:
	return int(layout["super_palettes"]) + palette * SUPER_PALETTE_BYTES


## `SetPal_Overworld`: the `SuperPalettes` row a map's four colours come from.
## The two tilesets answer before the map id is read at all. A city's row is its
## map id plus one and every route shares [constant PAL_ROUTE]; an indoor map no
## branch names takes `wLastMap`'s, which is [param last_map].
static func overworld_palette(
	id: StringName, map_id: int, tileset: int, last_map: int = -1
) -> int:
	if tileset == TILESET_CEMETERY:
		return PAL_GRAYMON
	if tileset == TILESET_CAVERN:
		return PAL_CAVE
	if map_id < FIRST_INDOOR_MAP:
		return _town_palette(map_id)
	if map_id >= CERULEAN_CAVE_2F and map_id <= CERULEAN_CAVE_1F:
		return PAL_CAVE
	if map_id == BRUNOS_ROOM:
		return PAL_CAVE
	if map_id == LORELEIS_ROOM:
		return PAL_PALLET
	if id == RomRegistry.YELLOW and (map_id == TRADE_CENTER or map_id == COLOSSEUM):
		return PAL_GRAYMON
	return _town_palette(last_map)


## `.townOrRoute` and the `inc a` behind it: every id past the last city answers
## [constant PAL_ROUTE], the routine's own `ld a, PAL_ROUTE - 1`.
static func _town_palette(map_id: int) -> int:
	return map_id + 1 if map_id >= 0 and map_id < NUM_CITY_MAPS else PAL_ROUTE


## Resolves one row of a near-pointer table whose bank the layout records.
static func pointer_target(rom: RomFile, layout: Dictionary, key: String, row: int) -> int:
	var table: int = int(layout[key])
	var bank: int = int(layout["%s_bank" % key])
	return RomFile.linear(bank, rom.u16le(table + row * POINTER_SIZE))


## `UncompressMonSprite`'s bank for an internal index, so a pic pointer read out
## of `BaseStats` can be turned into an offset.
static func pic_bank(layout: Dictionary, index: int) -> int:
	var mew: int = int(layout["pic_mew_bank"])
	if index == PIC_INDEX_MEW and mew != 0:
		return mew
	if index == PIC_INDEX_FOSSIL_KABUTOPS:
		return PIC_BANK_FOSSIL_KABUTOPS
	for step: int in PIC_BANK_THRESHOLDS.size():
		if index < PIC_BANK_THRESHOLDS[step]:
			return PIC_BANKS[step]
	return PIC_BANKS[PIC_BANKS.size() - 1]


## How many map ids the flat table holds. Yellow added the Summer Beach House
## behind Agatha's room.
static func map_count(id: StringName) -> int:
	return MAP_COUNT_YELLOW if id == RomRegistry.YELLOW else MAP_COUNT_RED_BLUE


## `CheckIfInOutsideMap`: which maps write `wLastMap` on the way out of them.
static func is_outside_tileset(tileset: int) -> bool:
	return tileset == TILESET_OVERWORLD or tileset == TILESET_PLATEAU


## `BIT_DUNGEON_BATTLE_TRANSITION`, which picks the stripes over the circles.
static func is_dungeon_map(map_id: int) -> bool:
	if DUNGEON_MAPS.has(map_id):
		return true
	for range_pair: Array in DUNGEON_MAP_RANGES:
		if map_id >= int(range_pair[0]) and map_id <= int(range_pair[1]):
			return true
	return false


## `ExtraWarpCheck`: whether a warp the player is not standing on the tile of
## asks for a carpet in front of them rather than for the edge of the map.
static func warp_wants_carpet(map_id: int, tileset: int) -> bool:
	if map_id == MAP_SS_ANNE_3F:
		return false
	if WARP_CARPET_MAPS.has(map_id):
		return true
	return tileset in [TILESET_OVERWORLD, TILESET_SHIP, TILESET_SHIP_PORT, TILESET_PLATEAU]


static func tileset_count(id: StringName) -> int:
	return TILESET_COUNT_YELLOW if id == RomRegistry.YELLOW else TILESET_COUNT_RED_BLUE


## How many `AttackAnimationPointers` rows the cartridge holds.
static func anim_count(id: StringName) -> int:
	return ANIM_COUNT_YELLOW if id == RomRegistry.YELLOW else ANIM_COUNT_RED_BLUE


## `NUM_SPRITES`. Yellow added ten walking sprites in front of the still ones.
static func sprite_count(id: StringName) -> int:
	return SPRITE_COUNT_YELLOW if id == RomRegistry.YELLOW else SPRITE_COUNT_RED_BLUE


static func super_palette_count(id: StringName) -> int:
	return SUPER_PALETTE_COUNT_YELLOW if id == RomRegistry.YELLOW \
		else SUPER_PALETTE_COUNT_RED_BLUE


## `FIRST_STILL_SPRITE`, the picture id from which a sheet is four tiles.
static func first_still_sprite(id: StringName) -> int:
	return SPRITE_STILL_FIRST_YELLOW if id == RomRegistry.YELLOW \
		else SPRITE_STILL_FIRST_RED_BLUE


static func sprite_offset(layout: Dictionary, number: int) -> int:
	return int(layout["overworld_sprites"]) + (number - 1) * SPRITE_RECORD_SIZE


## Blocks per tileset, in `Tilesets` order.
static func tileset_blocks(id: StringName) -> Array[int]:
	return TILESET_BLOCKS_YELLOW if id == RomRegistry.YELLOW else TILESET_BLOCKS_RED_BLUE


## Whether a map id decodes to a header at all: see [constant UNUSED_MAPS].
static func is_real_map(map_id: int) -> bool:
	return not UNUSED_MAPS.has(map_id)


## Where one map's header sits, through `MapHeaderBanks` and `MapHeaderPointers`
## together. Everything the header points at is in the same bank.
static func map_header_offset(rom: RomFile, layout: Dictionary, map_id: int) -> int:
	return RomFile.linear(
		map_bank(rom, layout, map_id),
		rom.u16le(int(layout["map_headers"]) + map_id * POINTER_SIZE)
	)


static func map_bank(rom: RomFile, layout: Dictionary, map_id: int) -> int:
	return rom.u8(int(layout["map_header_banks"]) + map_id)


static func tileset_offset(layout: Dictionary, number: int) -> int:
	return int(layout["tilesets"]) + number * TILESET_RECORD_SIZE


static func map_song_offset(layout: Dictionary, map_id: int) -> int:
	return int(layout["map_songs"]) + map_id * MAP_SONG_SIZE


## An unlisted byte 2 leaves the direction to `Random`, standing or walking.
static func object_movement(byte_1: int, byte_2: int) -> int:
	if byte_1 == OBJECT_MOVEMENT_STAY:
		return OBJECT_STANDING_MOVEMENTS.get(
			byte_2, Gen2WorldObject.MOVEMENT_SPINRANDOM_SLOW
		)
	return OBJECT_WALKING_MOVEMENTS.get(byte_2, Gen2WorldObject.MOVEMENT_WANDER)


## Whether the Super Rod is read as Yellow's flat slot table.
static func flat_super_rod(id: StringName) -> bool:
	return id == RomRegistry.YELLOW


## Which of a block's sixteen tiles decides one walk cell.
static func cell_tile_index(cell_x: int, cell_y: int) -> int:
	return (cell_y * MAP_BLOCK_CELL_WIDTH + 1) * MAP_BLOCK_TILE_WIDTH \
		+ cell_x * MAP_BLOCK_CELL_WIDTH


## `TryDoWildEncounter` reads `hlcoord 9, 9` where everything else reads
## `hlcoord 8, 9`: the bottom right tile of the quarter block the player stands
## in rather than its bottom left, which is why a left shore rolls on grass.
static func cell_encounter_tile_index(cell_x: int, cell_y: int) -> int:
	return cell_tile_index(cell_x, cell_y) + 1
