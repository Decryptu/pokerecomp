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

## 151 dex entries over 190 cartridge slots. `MonsterNames`, `PokedexEntryPointers`,
## `EvosMovesPointerTable` and `CryData` are indexed by the slot; `BaseStats` and
## `MonsterPalettes` by dex number.
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
## `NUM_FLOORS`: a floor is an item id above the named run with its own name.
const FLOOR_COUNT: int = 14
const ITEM_NAME_COUNT: int = ITEM_COUNT + FLOOR_COUNT

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
## `PalPacket_PartyMenu`'s first row, which `BlkPacket_PartyMenu` gives the two
## columns the party menu's icons stand in and nothing else.
const PAL_MEWMON: int = 0x10
## `PalPacket_Pokedex`, which is what `BlkPacket_Pokedex` gives every cell of the
## dex outside the picture box.
const PAL_BROWNMON: int = 0x15
## `PalPacket_TrainerCard`'s four, in its own order.
const PAL_REDMON: int = 0x12
const PAL_YELLOWMON: int = 0x18
const PAL_BADGE: int = 0x22
const PAL_CAVE: int = 0x23
## The three rows `GetHealthBarColor` picks between, under the names
## [method GameData.bar_palette] takes them by. Generation 1 has no exp bar.
const HP_BAR_PALETTES: Dictionary = {
	"hp_green": 0x1F, "hp_yellow": 0x20, "hp_red": 0x21,
}

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

## `FontGraphics` and `TextBoxGraphics`, copied to `vFont` and `vChars2 tile $60`
## and indexed by character code. The box's six border tiles at $79 are inside
## the second.
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
## `PTile`, the bold P `StatusScreen2` copies to $72 for "PP".
const STATS_P_TILES: int = 1
const STATS_P_CODE: int = 0x72
const BATTLE_FONT_FIRST_CODE: int = 0x62
const BATTLE_HUD_1_TILES: int = 3
const BATTLE_HUD_1_FIRST_CODE: int = 0x6D
const BATTLE_HUD_2_TILES: int = 6
const BATTLE_HUD_2_FIRST_CODE: int = 0x73

## The battle animation layer, all of it in bank $1E with its data interleaved,
## so the cache holds one region.
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

## `FallingObjects_DeltaXs` is nine bytes and two objects start at nine, so they
## read the routine's own machine code as their drift, masked to seven bits; the
## two dumps disagree past the ninth and both are cached.
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
## picks a throw off; [constant BALL_ITEMS] gathers them in ball pocket order.
const ITEM_MASTER_BALL: int = 0x01
const ITEM_ULTRA_BALL: int = 0x02
const ITEM_GREAT_BALL: int = 0x03
const ITEM_POKE_BALL: int = 0x04
const ITEM_SAFARI_BALL: int = 0x08
const BALL_ITEMS: Array[int] = [
	ITEM_POKE_BALL, ITEM_GREAT_BALL, ITEM_ULTRA_BALL, ITEM_MASTER_BALL,
	ITEM_SAFARI_BALL,
]

## The other `ItemUsePtrTable` rows the pack reaches, by `item_constants.asm`'s
## own numbering, which is not Crystal's anywhere.
const ITEM_BICYCLE: int = 0x06
const ITEM_ESCAPE_ROPE: int = 0x1D
## `IsItemInBag COIN_CASE`, which `CeladonPrizeMenu` opens on.
const ITEM_COIN_CASE: int = 0x45
const ITEM_COIN: int = 0x3B
const ITEM_FRESH_WATER: int = 0x3C
const ITEM_SODA_POP: int = 0x3D
const ITEM_LEMONADE: int = 0x3E
const ITEM_CARD_KEY: int = 0x30
const ITEM_ITEMFINDER: int = 0x47
const ITEM_TOWN_MAP: int = 0x05
const ITEM_POKEDEX: int = 0x09
const ITEM_MOON_STONE: int = 0x0A
const ITEM_FULL_RESTORE: int = 0x10
const ITEM_REVIVE: int = 0x35
const ITEM_MAX_REVIVE: int = 0x36
const ITEM_RARE_CANDY: int = 0x28
## `ItemUseMedicine`'s `cp CALCIUM + 1`: the last item the follower is glad of.
const ITEM_CALCIUM: int = 0x27
const ITEM_OAKS_PARCEL: int = 0x46
const ITEM_PP_UP: int = 0x4F
const ITEM_OLD_ROD: int = 0x4C
const ITEM_GOOD_ROD: int = 0x4D
const ITEM_SUPER_ROD: int = 0x4E
const ITEM_POKE_DOLL: int = 0x33
const ITEM_POKE_FLUTE: int = 0x49

## `ItemUseXStat`'s `sub X_ATTACK - ATTACK_UP1_EFFECT`, in the move effects' own
## stat order, with `SPECIAL_STAGE_TWIN` carrying X SPECIAL's other half, and
## then the three that `set` a bit of `wPlayerBattleStatus2` instead.
const ITEM_X_STATS: Dictionary = {
	0x41: "attack", 0x42: "defense", 0x43: "speed", 0x44: "sp_attack",
}
const ITEM_X_SUBSTATUSES: Dictionary = {
	0x2E: Gen2Substatus.X_ACCURACY,
	0x37: Gen2Substatus.MIST,
	0x3A: Gen2Substatus.FOCUS_ENERGY,
}

## `ItemUseEvoStone`'s five rows of `ItemUsePtrTable`. Crystal numbers its own
## six differently, and [method Gen2Evolution.stone_items] is the one seam that
## tells the two apart.
const STONE_ITEMS: Array[int] = [ITEM_MOON_STONE, 0x20, 0x21, 0x22, 0x2F]

## `.addHealAmount`'s ladder; FULL_RESTORE and MAX_POTION heal past
## [constant Gen2Stats.MAX_STAT_VALUE], which is the maximum to the party host.
const ITEM_HEAL_AMOUNTS: Dictionary = {
	ITEM_FULL_RESTORE: 999, 0x11: 999, 0x12: 200, 0x13: 50, 0x14: 20,
	0x3C: 50, 0x3D: 60, 0x3E: 80,
}
## `.cureStatusAilment`'s own five and the `$ff` its fall-through carries, which
## FULL_HEAL takes and which `.doneHealingPartyHP` gives FULL_RESTORE too.
const ITEM_STATUS_MASKS: Dictionary = {
	0x0B: Gen2Status.POISON, 0x0C: Gen2Status.BURN, 0x0D: Gen2Status.FREEZE,
	0x0E: Gen2Status.SLEEP_MASK, 0x0F: Gen2Status.PARALYSIS,
	ITEM_FULL_RESTORE: Gen2Status.ANY, 0x34: Gen2Status.ANY,
}
## `.useVitamin`'s `sub HP_UP`, doubled onto `MON_HP_EXP`: the five stat
## experience words in the party struct's own order.
const ITEM_VITAMINS: Dictionary = {
	0x23: "hp", 0x24: "attack", 0x25: "defense", 0x26: "speed", 0x27: "special",
}
## The `ItemUsePtrTable` rows that answer `ItemUseNotTime` outside a battle; the
## four X stats are in `UsableItems_PartyMenu` and still never open it.
const ITEM_BATTLE_ONLY: Array[int] = [
	ITEM_MASTER_BALL, ITEM_ULTRA_BALL, ITEM_GREAT_BALL, ITEM_POKE_BALL,
	ITEM_SAFARI_BALL, 0x15, 0x16, 0x2E, 0x33, 0x37, 0x3A,
	0x41, 0x42, 0x43, 0x44,
]

## `ItemUseRepel`, `ItemUseSuperRepel` and `ItemUseMaxRepel`'s own `ld b`.
const ITEM_REPEL_STEPS: Dictionary = {0x1E: 100, 0x38: 200, 0x39: 250}
## `.restorePP`'s `add 10` and the `MAX_ETHER` that skips it, with `.useElixir`
## walking all four slots by decrementing the item twice. The value is whether
## the whole moveset is restored, which is what [Gen2WorldPartyHost] reads.
const ITEM_PP_RESTORE: Dictionary = {0x50: false, 0x51: false, 0x52: true, 0x53: true}
const ITEM_PP_RESTORE_MAX: Array[int] = [0x51, 0x53]
const ITEM_PP_RESTORE_STEPS: Dictionary = {0x50: 10, 0x52: 10}

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


## `ItemUsePtrTable`'s own answer inside a battle, as the nibble [Gen2WorldPack]
## branches on: `ItemUseMedicine` and `ItemUsePPRestore` open the party list, the
## balls, X items, Poke Doll and Poke Flute are spent on whoever is out, and
## every other row jumps to `ItemUseNotTime` there.
static func item_battle_menu(item: int) -> int:
	if item in BALL_ITEMS or ITEM_X_STATS.has(item) or ITEM_X_SUBSTATUSES.has(item) \
		or item == ITEM_POKE_DOLL or item == ITEM_POKE_FLUTE:
		return Gen2Layout.ITEMMENU_CLOSE
	if ITEM_HEAL_AMOUNTS.has(item) or ITEM_STATUS_MASKS.has(item) \
		or ITEM_PP_RESTORE.has(item) or item == ITEM_REVIVE or item == ITEM_MAX_REVIVE:
		return Gen2Layout.ITEMMENU_PARTY
	return Gen2Layout.ITEMMENU_NOUSE


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
const EMOTE_TILES: int = 4
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
const TEXT_SCRIPT_POKECENTER_PC: int = 0xF9
const TEXT_SCRIPT_PLAYERS_PC: int = 0xFC
const TEXT_SCRIPT_BILLS_PC: int = 0xFD


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
## `text_end`; a `text_pause` in front of one adds a byte.
const TEXT_FAR_STUB_BYTES: int = 5

const ELEVATOR_TEXT_AT: Dictionary = {"which_floor": 0x00}
const ELEVATOR_FLOOR_END: int = 0xFF
const ELEVATOR_WARP_SIZE: int = 2
const ELEVATOR_MAX_FLOORS: int = 16
const ELEVATOR_SHAKE_PASSES: int = 100
const ELEVATOR_SHAKE_STEP: int = 2
const ELEVATOR_SHAKE_FRAMES: int = ELEVATOR_SHAKE_PASSES * ELEVATOR_SHAKE_STEP

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

## `DaycareGentlemanText`'s fifteen stubs, at the same deltas on all three.
## `all_right_then` has no `text_end`, so `come_again` prints as part of it.
const DAY_CARE_TEXT_AT: Dictionary = {
	"intro": 0x00, "which_mon": 0x05, "will_look_after": 0x0A,
	"come_see_me": 0x0F, "has_grown": 0x14, "owe_money": 0x19,
	"got_mon_back": 0x1E, "needs_more_time": 0x23, "all_right_then": 0x28,
	"come_again": 0x2C, "no_room": 0x31, "only_one_mon": 0x36,
	"knows_hm_move": 0x3B, "heres_your_mon": 0x40, "not_enough_money": 0x45,
}

## `engine/items/item_effects.asm`'s two runs the pack prints from: the three
## refusals `ItemUseFailed` reaches and `TossItem_`'s own three.
const ITEM_USE_TEXT_AT: Dictionary = {
	"not_time": 0x00, "not_yours": 0x05, "no_effect": 0x0A, "no_cycling": 0x19,
	"no_surfing": 0x1E,
}
## `GotOnBicycleText` and `GotOffBicycleText`, pinned away from the run above
## because Yellow's `DontHavePokemonText` sits between them and it.
const BICYCLE_TEXT_AT: Dictionary = {"got_on": 0x00, "got_off": 0x0A}
## `ItemUsePokeFlute`'s own three, in file order.
const POKE_FLUTE_TEXT_AT: Dictionary = {
	"no_effect": 0x00, "woke_up": 0x05, "had_effect": 0x0A,
}
const SAFARI_BATTLE_TEXT_AT: Dictionary = {"eating": 0x00, "angry": 0x05}
## `AIBattleWithdrawText` and `AIBattleUseItemText`, $C3 apart on every cartridge.
const TRAINER_AI_TEXT_AT: Dictionary = {"withdraw": 0x00, "use_item": 0xC3}
const SAFARI_TEXT_AT: Dictionary = {"times_up": 0x00, "game_over": 0x05}
const SAFARI_ITEM_TEXT_AT: Dictionary = {"bait": 0x00, "rock": 0x05}
const SAFARI_LOW_COST_TEXT_AT: Dictionary = {"low_cost_1": 0x00, "low_cost_2": 0x05}
const SAFARI_NAG_TEXT_AT: Dictionary = {"one_ball": 0x00}

## `InitBattleVariables`' two comparisons and `PrintSafariZoneSteps`' own pair,
## which reaches the rest houses a fight is never the game's on.
const SAFARI_FIRST_MAP: int = 0xD9
const SAFARI_BATTLE_END_MAP: int = 0xDD
const SAFARI_WINDOW_END_MAP: int = 0xE2
const SAFARI_ZONE_GATE_MAP: int = 0x9C
const SAFARI_GAME_OVER_WARP: int = 3
const SAFARI_SCRIPT_LEAVING: int = 5
## Ahead of `const_next $550 - 1`, so all three cartridges number them alike.
const SAFARI_GAME_OVER_EVENT: int = 590
const IN_SAFARI_ZONE_EVENT: int = 591
## `.success`: 30 balls and 502 steps for ¥500.
const SAFARI_BALLS: int = 30
const SAFARI_STEPS: int = 502
## SAFARI_BALL, and the two badge numbers the bait and the rock overload.
const SAFARI_BALL_ITEM: int = 0x08
const SAFARI_BAIT_ITEM: int = 0x15
const SAFARI_ROCK_ITEM: int = 0x16
## `BaitRockCommon`'s `.randomLoop`, which grows a factor by 1 to 5.
const SAFARI_FACTOR_MASK: int = 7
const SAFARI_FACTOR_LIMIT: int = 5
const SAFARI_MENU_COLUMN: int = 12

## Yellow's admission for a purse that cannot pay: `ld a, 23` writes $17, which
## `DivideBCD` reads as seventeen, and `.load_balls` stops the quotient at 29.
const SAFARI_LOW_COST_DIVISOR: int = 17
const SAFARI_LOW_COST_DIGITS: int = 100
const SAFARI_LOW_COST_MAX_BALLS: int = 29
## An empty purse's visits are counted in `wSafariSteps`' high byte and paid on
## the fourth; `Pointers_f2100` has five rows for four counts.
const SAFARI_NAG_LINES: int = 5
const SAFARI_NAG_GIFT_VISIT: int = 3
const SAFARI_NAG_BALLS: int = 1

## `CannotGetOffHereText`, which `.useOrTossItem` prints in front of `UseItem`
## rather than through `ItemUseFailed`. `CannotUseItemsHereText` above it is the
## Colosseum's and no screen here reaches it.
const START_MENU_TEXT_AT: Dictionary = {"cannot_get_off": 0x00}
## `start_sub_menus.asm`'s own six in file order, and `field_move_messages.asm`'s
## four. Yellow keeps each run whole and moves the second away from the first.
const FIELD_MOVE_TEXT_AT: Dictionary = {
	"flash_lights_area": 0x00, "warp_to_last_center": 0x23,
	"cannot_teleport_now": 0x42, "cannot_fly_here": 0x5E,
	"not_healthy_enough": 0x72, "new_badge_required": 0x87,
}
const STRENGTH_TEXT_AT: Dictionary = {
	"used_strength": 0x00, "can_move_boulders": 0x15,
	"current_too_fast": 0x2D, "cycling_is_fun": 0x4C,
}
## `UsedCut`'s two, and `ItemUseSurfboard`'s two.
const CUT_TEXT_AT: Dictionary = {"nothing_to_cut": 0x00, "used_cut": 0x1D}
const SURF_TEXT_AT: Dictionary = {"got_on": 0x00, "no_place_to_get_off": 0x11}

## `CoinCaseNumCoinsText`, a run of one: `ItemUseCoinCase` is the only reader.
const COIN_CASE_TEXT_AT: Dictionary = {"coins": 0x00}
## `PartyMenuMessagePointers`' own five, in the order the table names them.
## The sixth row points at `PartyMenuItemUseText` again.
const PARTY_MENU_TEXT_AT: Dictionary = {
	"normal": 0x00, "item_use": 0x05, "battle": 0x0A, "use_tm": 0x0F, "swap": 0x14,
}
const TOSS_TEXT_AT: Dictionary = {
	"threw_away": 0x00, "ok_to_toss": 0x05, "too_important": 0x0A,
}

## `engine/menus/pc.asm`'s four, which `ActivatePC` prints around the machine's
## own top menu.
const PC_TEXT_AT: Dictionary = {
	"turned_on": 0x00, "accessed_bills": 0x05, "accessed_someones": 0x0A,
	"accessed_mine": 0x0F,
}

## `engine/menus/players_pc.asm`'s fourteen in file order: `PlayerPC` reached
## from a text script has no generic PC in front of it, so it prints its own
## boot line.
const PLAYERS_PC_TEXT_AT: Dictionary = {
	"turned_on": 0x00, "what_do_you_want": 0x05, "what_to_deposit": 0x0A,
	"deposit_how_many": 0x0F, "item_was_stored": 0x14, "nothing_to_deposit": 0x19,
	"no_room_to_store": 0x1E, "what_to_withdraw": 0x23, "withdraw_how_many": 0x28,
	"withdrew_item": 0x2D, "nothing_stored": 0x32, "cant_carry_more": 0x37,
	"what_to_toss": 0x3C, "toss_how_many": 0x41,
}

## `engine/pokemon/bills_pc.asm`'s stubs, in two runs: Yellow puts an extra one
## between `CantTakeMonText` and `ReleaseWhichMonText`.
const BILLS_PC_TEXT_AT: Dictionary = {
	"switch_on": 0x00, "what": 0x05, "mon_was_stored": 0x0F,
	"cant_deposit_last": 0x14, "box_full": 0x19, "mon_is_taken_out": 0x1E,
	"no_mon": 0x23, "cant_take_mon": 0x28,
}
const BILLS_PC_RELEASE_TEXT_AT: Dictionary = {
	"once_released": 0x00, "mon_was_released": 0x05,
}

## `engine/menus/oaks_pc.asm`'s three, the second spending a `text_waitbutton`.
const OAKS_PC_TEXT_AT: Dictionary = {
	"get_rated": 0x00, "closed": 0x05, "accessed": 0x0B,
}
## `engine/menus/league_pc.asm`'s one.
const HOF_PC_TEXT_AT: Dictionary = {"accessed": 0x00}
const HOF_DEX_TEXT_AT: Dictionary = {"seen_owned": 0x00, "rating": TEXT_FAR_STUB_BYTES}

## `ChangeBox`'s two, pinned apart because Yellow's own boxes move the second.
const CHANGE_BOX_TEXT_AT: Dictionary = {"warning": 0x00}
const CHOOSE_BOX_TEXT_AT: Dictionary = {"choose": 0x00}

const INTRO_TEXT_AT: Dictionary = {
	"oak_speech_1": 0x00, "oak_speech_2": 0x05, "introduce_player": 0x0F,
	"introduce_rival": 0x14, "oak_speech_3": 0x19,
}
const INTRO_NAME_TEXT_AT: Dictionary = {"your_name_is": 0x00, "his_name_is": 0x48}

## `special_warp_spec REDS_HOUSE_2F, 3, 6, REDS_HOUSE_2`: a map byte, a
## `fly_warp` and the destination's tileset. `fly_warp` writes `db y, x` for
## arguments given as x then y, so the cell `LoadSpecialWarpData` copies onto
## `wYCoord` is (6, 3) read the other way round.
const NEW_GAME_WARP_RECORD_AT: int = 1
const NEW_GAME_WARP_TILESET_AT: int = 7

const INTRO_NAME_ROWS: int = 4
const INTRO_NAME_MAX: int = 16

## `LowerCaseAlphabet` with `UpperCaseAlphabet` behind it: five rows of nine and
## the case-switch label. `<ED>` is the last cell of the last row, and its tile
## is `ED_Tile` rather than the font's own $F0.
const ALPHABET_ROWS: int = 5
const ALPHABET_COLUMNS: int = 9
const ALPHABET_LABEL_LENGTH: int = 11
const ALPHABET_STRIDE: int = ALPHABET_ROWS * ALPHABET_COLUMNS + ALPHABET_LABEL_LENGTH
const ALPHABET_UPPER: int = 0
const ALPHABET_LOWER: int = 1
const CHAR_ED: int = 0xF0

const MUSIC_ROUTES2: int = 239
const SFX_SHRINK: int = 156
const INTRO_SPECIES_KANTO: int = 33
const INTRO_CRY_KANTO: int = 30
const INTRO_SPECIES_YELLOW: int = 25

## `DexRatingsTable`: `dbw threshold, text`, the walk stopping at the first row
## the owned count is under, with `DexCompletionText`'s stub right behind it.
const DEX_RATING_ROWS: int = 16
const DEX_RATING_ROW_SIZE: int = 3
const DEX_RATING_STEP: int = 10

## `PokeballTileGraphics`' four; only the ball itself is drawn here.
const BALL_TILES: int = 4
const DEX_COMPLETION_TEXT_AT: int = -TEXT_FAR_STUB_BYTES

## `CreditsOrder`'s six commands; anything below is a `CreditsTextPointers`
## index, of which there are `NUM_CRED_STRINGS`.
const CREDITS_TEXT_FADE_MON: int = 0xFF
const CREDITS_TEXT_MON: int = 0xFE
const CREDITS_TEXT_FADE: int = 0xFD
const CREDITS_TEXT: int = 0xFC
const CREDITS_COPYRIGHT: int = 0xFB
const CREDITS_THE_END: int = 0xFA
const CREDITS_STRINGS_RED_BLUE: int = 64
const CREDITS_STRINGS_YELLOW: int = 86
const CREDITS_STRING_MAX: int = 32
const CREDITS_CENTRE_COLUMN: int = 9
## `TheEndGfx` and `LoadCopyrightTiles`' run both land at `vChars2 tile $60`;
## Yellow's run reaches `NineTile`, which its `CopyrightTextString` uses.
const CREDITS_THE_END_TILES: int = 10
const CREDITS_TILES_FIRST_CODE: int = 0x60
const COPYRIGHT_TILES_RED_BLUE: int = 28
const COPYRIGHT_TILES_YELLOW: int = 30
const COPYRIGHT_ROWS: int = 3

## `PlayIntro` and `DisplayTitleScreen`: `GameFreakIntro` is thirteen tiles,
## six and a blank; the Gengar 95 and a blank; the front mon three poses of 36.
const SPLASH_LOGO_TILES: int = 20
const SPLASH_STAR_TILES: int = 1
const INTRO_BACK_MON_TILES: int = 96
const INTRO_FRONT_MON_POSE_TILES: int = 36
const INTRO_FRONT_MON_POSES: int = 3
const INTRO_NIDORINO_ANIMS: int = 7
const INTRO_ANIMATION_END: int = 80
const INTRO_TILEMAP_FIRST: int = 3
const INTRO_TILEMAPS: int = 3
const TILE_ID_LIST_ROW_SIZE: int = 3
const SPLASH_LOGO_OAM_SPRITES: int = 16
const SPLASH_SHOOTING_STAR_SPRITES: int = 4
const SPLASH_SMALL_STAR_WAVES: int = 4
const SPLASH_SMALL_STAR_WAVE_SPRITES: int = 4
const TITLE_LOGO_TILES_RED_BLUE: int = 112
const TITLE_LOGO_TILES_YELLOW: int = 115
const TITLE_PLAYER_TILES: int = 35
const TITLE_MONS: int = 16
const TITLE_VERSION_TILES: Dictionary = {RomRegistry.RED: 10, RomRegistry.BLUE: 8}
const TITLE_VERSION_TEXT_MAX: int = 16
const TITLE_LOGO_CORNER_TILES: int = 3
const TITLE_PIKACHU_BG_TILES: int = 64
const TITLE_PIKACHU_OB_TILES: int = 12
const TITLE_EYES_SPRITES: int = 8
const TITLE_LOGO_TILEMAP: Vector2i = Vector2i(16, 7)
const TITLE_BUBBLE_TILEMAP: Vector2i = Vector2i(7, 4)
const TITLE_PIKACHU_TILEMAP: Vector2i = Vector2i(12, 9)
## `YellowIntroGraphics2` less the last tile `CopyVideoData` is told to leave.
const YELLOW_INTRO_GFX_1_TILES: int = 128
const YELLOW_INTRO_GFX_2_TILES: int = 255
const YELLOW_INTRO_CLOUD_TILES: int = 8
const YELLOW_INTRO_TILEMAPS: Array[Vector2i] = [Vector2i(20, 6), Vector2i(4, 3), Vector2i(2, 2)]
const YELLOW_INTRO_SPEED_BARS: int = 8
const YELLOW_INTRO_SPAWN_STATES: int = 11
const YELLOW_INTRO_FRAMESETS: int = 11
const YELLOW_INTRO_OAM_SETS: int = 20
const YELLOW_INTRO_SINE_BYTES: int = 32
const YELLOW_INTRO_SINE_WORDS: int = 32
const YELLOW_INTRO_PAL_END: int = 0xFF
const ANIM_FRAME_END: int = 0xFF
const ANIM_FRAME_RESTART: int = 0xFE
const ANIM_FRAME_DURATION_MASK: int = 0x3F
## `PAL_SET`'s and `ATTR_BLK`'s bytes.
const PAL_SET_COMMAND: int = 0x51
const PAL_SET_ROW: int = 1
const OAM_ROW_SIZE: int = 4
const PAL_SET_PALETTES: int = 4
const ATTR_BLK_COUNT_AT: int = 1
const ATTR_BLK_ROWS_AT: int = 2
const ATTR_BLK_ROW_SIZE: int = 6
const ATTR_BLK_MAX_ROWS: int = 3

## `LoadPokedexTilePatterns`: `PokedexTileGraphics` at `vChars2 tile $60`, over
## the text box sheet, with `PokeballTileGraphics`' first tile at $72 behind it.
const POKEDEX_TILES: int = 18
const POKEDEX_FIRST_CODE: int = 0x60
const POKEDEX_BALL_CODE: int = 0x72

## `LoadTownMap`: `WorldMapTileGraphics` at `vChars2 tile $60` over the text box
## sheet, and `CompressedMap`'s runs, each byte a tile nybble from that base and
## a count, filling the whole screen.
const WORLD_MAP_TILES: int = 16
const WORLD_MAP_FIRST_CODE: int = 0x60
const WORLD_MAP_CELLS: int = 360
## `TownMapCursor`, `MonNestIcon`, `TownMapUpArrow` and the `BirdSprite` frames
## `LoadTownMap_Fly` copies over the cursor, all at `vSprites tile $04`.
const TOWN_MAP_CURSOR_TILES: int = 4
const TOWN_MAP_NEST_TILES: int = 1
const TOWN_MAP_ARROW_TILES: int = 1
const TOWN_MAP_BIRD_TILES: int = 12
## `PalPacket_TownMap` under a `BlkPacket_WholeScreen`, so one row colours every
## cell of the screen.
const PAL_TOWNMAP: int = 0x0C
## `TownMapOrder`, the ids `DisplayTownMap`'s own cursor walks.
const TOWN_MAP_ORDER_COUNT: int = 47
## `LoadTownMapEntry`: a map under this indexes `ExternalMapEntries` by itself,
## and one above it takes the first `InternalMapEntries` row whose group byte is
## greater. Both rows pack y in the high nybble and x in the low one.
const EXTERNAL_MAP_ENTRY_SIZE: int = 3
const INTERNAL_MAP_ENTRY_SIZE: int = 4
## `MarkTownVisitedAndLoadToggleableObjects` sets a bit for any map under this,
## and `BuildFlyLocationsList` walks the [constant NUM_CITY_MAPS] under that.
const FIRST_ROUTE_MAP: int = 0x0C
## `TownMapCoordsToOAMCoords` gives (x * 8 + 24, y * 8 + 24) and
## `WriteTownMapSpriteOAM` takes 4 off x and, the borrow out of x costing one of
## the two, 3 off y. Stored is the 16x16 icon's own centre.
const TOWN_MAP_ICON_CENTRE: Vector2i = Vector2i(20, 13)
## `.nestloop` writes that pair with no adjustment, so its 8x8 icon hangs a
## pixel below the centre the borrow gave the bigger one.
const TOWN_MAP_NEST_ORIGIN: Vector2i = Vector2i(4, 5)
## `DisplayWildLocations`' `cp $19`: the packed coordinates Cerulean Cave's own
## entry carries, and the one place a nest icon is never drawn.
const TOWN_MAP_SKIP_COORDS: int = 0x19
## `TownMapSpriteBlinkingAnimation` counts to 25 and hides every object but the
## player's, then to 50 and shows them again.
const TOWN_MAP_BLINK_FRAMES: int = 25
## `FlyWarpDataPtr`: thirteen `db map, 0 / dw` rows, each pointing at a
## `fly_warp` whose third and fourth bytes are the tile the player lands on.
const FLY_WARP_COUNT: int = 13
const FLY_WARP_ROW_SIZE: int = 4
const FLY_WARP_RECORD_AT: int = 2
## `wBeatGymFlags`' own bit for the badge `.fly` asks for.
const THUNDERBADGE: int = 2

## `LoadSpecialWarpData`'s other pair. A `DungeonWarpList` row is a destination
## map and a hole index; `DungeonWarpData`'s row at the same place is a `fly_warp`.
const DUNGEON_WARP_ROW_SIZE: int = 2
const DUNGEON_WARP_DATA_SIZE: int = 6
## `ItemUseEscapeRope`'s one refusal by map, in front of `EscapeRopeTilesets`.
const AGATHAS_ROOM: int = 0xF7
## PALLET_TOWN, which is map 0 and so what a zeroed `wLastBlackoutMap` names.
const PALLET_TOWN: int = 0x00
## `PlayMapChangeSound`'s `cp $0b`, the OVERWORLD door tile it parts
## SFX_GO_INSIDE from SFX_GO_OUTSIDE by on every map.
const OVERWORLD_DOOR_TILE: int = 0x0B

## `IsBikeRidingAllowed`'s two maps by name, in front of `BikeRidingTilesets`.
const ROUTE_23: int = 0x22
const INDIGO_PLATEAU: int = 0x09
const BIKE_ALLOWED_MAPS: Array[int] = [ROUTE_23, INDIGO_PLATEAU]
## `BikeRidingTilesets`: OVERWORLD, FOREST, UNDERGROUND, SHIP_PORT and CAVERN.
const BIKE_RIDING_TILESET_COUNT: int = 5
## `ForcedBikeOrSurfMaps`, whose `force_bike_surf` macro writes `db map, y, x`
## for arguments given as map, x, y. Route 16's and Route 18's four rows force
## the bike; Seafoam Islands B3F's and B4F's force surfing instead.
const FORCED_BIKE_SURF_ROW_SIZE: int = 3
const FORCED_BIKE_SURF_ROWS: int = 8
const SEAFOAM_ISLANDS_B3F: int = 0xA1
const SEAFOAM_ISLANDS_B4F: int = 0xA2
## `res BIT_ALWAYS_ON_BIKE, [hl]`: bit 5 of `wStatusFlags6`, which only Route 16
## Gate 1F's and Route 18 Gate 1F's per-frame scripts open with.
const ALWAYS_ON_BIKE_BIT: int = 5

## `ItemUsePokeFlute`'s two maps and the events each branch reads. Yellow's third
## branch is Pikachu at PEWTER_POKECENTER, who does not follow the player here.
const ROUTE_12: int = 0x17
const ROUTE_16: int = 0x1B
const SNORLAX_FLUTE_ROW_SIZE: int = 2
const SNORLAX_FLUTES: Array[Dictionary] = [
	{"map": ROUTE_12, "fight": 1166, "beat": 1167, "count": 4},
	{"map": ROUTE_16, "fight": 1224, "beat": 1225, "count": 2},
]

## `.outOfBattleMovePointers`' own `bit` on `wObtainedBadges`. Dig, Teleport and
## Softboiled test none.
const BOULDERBADGE: int = 0
const CASCADEBADGE: int = 1
const RAINBOWBADGE: int = 3
const SOULBADGE: int = 4
const FIELD_MOVE_BADGES: Dictionary = {
	Gen2WorldFieldMove.MOVE_CUT: CASCADEBADGE,
	Gen2WorldFieldMove.MOVE_FLY: THUNDERBADGE,
	Gen2WorldFieldMove.MOVE_SURF: SOULBADGE,
	Gen2WorldFieldMove.MOVE_STRENGTH: RAINBOWBADGE,
	Gen2WorldFieldMove.MOVE_FLASH: BOULDERBADGE,
}

const TILESET_GYM: int = 7
const CUT_TREE_TILE: int = 0x3D
const CUT_GRASS_TILE: int = 0x52
const CUT_GYM_TREE_TILE: int = 0x50
## `CutTreeBlockSwaps`, byte identical in all three: the block holding the tree
## and the one that replaces it. `ReplaceTreeTileBlock` walks the whole list
## whatever the tileset, so a gym's own row sits beside the overworld's.
const CUT_BLOCK_SWAPS: Dictionary = {
	0x32: 0x6D, 0x33: 0x6C, 0x34: 0x6F, 0x35: 0x4C, 0x60: 0x6E,
	0x0B: 0x0A, 0x3C: 0x35, 0x3F: 0x35, 0x3D: 0x36,
}
const CUT_BLOCK_SWAP_SIZE: int = 2
const CUT_BLOCK_SWAP_END: int = 0xFF

## `IsNextTileShoreOrWater`'s two shore tiles, which its `cp SHIP_PORT` skips on
## the Vermilion dock alone.
const SHORE_TILES: Array[int] = [0x48, 0x32]

## `IsSurfingAllowed`'s Seafoam branch, which nothing reaches yet: only that
## map's own per-frame script sets either boulder event.
const SEAFOAM_B4F_STAIRS := Vector2i(7, 11)
const SEAFOAM_BOULDER_EVENTS: Array[int] = [2512, 2513]

## `CheckForCollisionWhenPushingBoulder`'s `cp $15`, which refuses a push whether
## or not the tileset calls that tile passable.
const BOULDER_STAIRS_TILE: int = 0x15

## `wMapPalOffset`, which `LoadGBPal` subtracts from `FadePal4` in bytes before
## writing rBGP, rOBP0 and rOBP1. Only the warp into ROCK_TUNNEL_1F writes it, so
## that floor and B1F are the whole of Generation 1's darkness.
const ROCK_TUNNEL_1F: int = 0x52
const MAP_PAL_OFFSET_DARK: int = 6
## `FadePal1` to `FadePal8` as the byte run `LoadGBPal` indexes: rBGP, rOBP0 and
## rOBP1 a row, `dc`-packed.
const FADE_PALS: Array[int] = [
	0xFF, 0xFF, 0xFF, 0xFE, 0xFE, 0xF8, 0xF9, 0xE4, 0xE4, 0xE4, 0xD0, 0xE0,
	0xE4, 0xD0, 0xE0, 0x90, 0x80, 0x90, 0x40, 0x40, 0x40, 0x00, 0x00, 0x00,
]
const FADE_PAL_BASE: int = 9
const FADE_PAL_BACKGROUND: int = 0
const FADE_PAL_OBJECT: int = 1

## `NOT_VISITED`, which `BuildFlyLocationsList` writes for a town the player has
## not been to, and `.townMapFlyLoop`'s own `ld c, 15` between two draws.
const TOWN_MAP_NOT_VISITED: int = 0xFE
const TOWN_MAP_FLY_DELAY: int = 15

## `DrawTrainerInfo`'s own four sheets and where each lands. `BlankLeaderNames`
## runs straight on into `CircleTile`, which is why its `$17` is one longer than
## the file: `$76` is the circle "●BADGES●" is written with, and the sixteen
## under it are the leader names the international ROMs erased.
const TRAINER_CARD_BOX_TILES: int = 9
const TRAINER_CARD_BOX_CODE: int = 0x77
## The ninth tile, which goes to `vChars1 tile $57` rather than beside the
## other eight, and is the card's background.
const TRAINER_CARD_FILL_CODE: int = 0xD7
const TRAINER_CARD_NAME_TILES: int = 23
const TRAINER_CARD_NAME_CODE: int = 0x60
const TRAINER_CARD_CIRCLE_CODE: int = 0x76
const BADGE_NUMBER_TILES: int = 8
const BADGE_NUMBER_CODE: int = 0xD8
## `GymLeaderFaceAndBadgeTileGraphics`: eight tiles a leader, the face first and
## its badge four on (`DrawBadges`' own `add 4`).
const BADGE_FACE_TILES: int = 64
const BADGE_FACE_CODE: int = 0x20
const BADGE_FACE_STRIDE: int = 8
const BADGE_FACE_BADGE_AT: int = 4
## `TextBoxGraphics` tile 13, which the card copies on its own to `vChars1 tile
## $56` for the play timer's colon.
const TRAINER_CARD_COLON_TILE: int = 13
const TRAINER_CARD_COLON_CODE: int = 0xD6

## `NUM_BOXES` and `MONS_PER_BOX`, which `BOX_NUM_MASK` bounds `wCurrentBoxNum`
## to.
const BOX_COUNT: int = 12
const BOX_CAPACITY: int = 20

## `EVENT_MET_BILL`, which puts BILL's PC on the machine's top menu where
## SOMEONE's PC otherwise stands. Yellow's unused `EVENT_54F` sits below it and
## its `const_next $550 - 1` re-anchors the run, so all three number it alike;
## `pc_met_bill` pins `DisplayPCMainMenu`'s own read of it.
const MET_BILL_EVENT: int = 1360
const OPCODE_LD_A_FAR: int = 0xFA
const OPCODE_CB_PREFIX: int = 0xCB
const OPCODE_BIT_A: int = 0x47

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
## `ToggleableObjectStates`: a map id, the object's 1-based id, and ON or OFF;
## a row's distance from the table is the index `HideObject` is given.
const TOGGLE_STATE_SIZE: int = 3
const TOGGLE_ON: int = 0x15
## `add_predef`'s `dba`, indexed by the id the `predef` macro leaves in a.
const PREDEF_SIZE: int = 3
## `PickUpItemText`'s two boxes, a `text_far` stub and a `sound_get_item_1` apart.
const PICK_UP_TEXT_AT: Dictionary = {"found": 0x00, "no_room": 0x06}

## `TradeMons`: `npctrade`'s give and get species, its `TRADE_DIALOGSET_*` and a
## nickname. `ConnectCableText` and `TradedForText` sit behind the last of
## `InGameTradeTextPointers`' three tables.
const TRADE_COUNT: int = 10
const TRADE_RECORD_SIZE: int = 14
const TRADE_NAME_LENGTH: int = 11
const NPC_TRADE_TEXT_AT: Dictionary = {"cable": 0x00, "traded_for": 0x05}
## `InGameTrade_GetMonName`'s two buffers, which every box of the run names by
## address: the species the row asks for and the one it offers.
const TRADE_GIVE_NAME: int = 0xCD13
const TRADE_RECEIVE_NAME: int = 0xCD1E

## `object_event`'s two movement bytes as one shared template. Byte 1 is WALK or
## STAY; byte 2 is a fixed direction, the axis a random walk keeps to, or
## `BOULDER_MOVEMENT_BYTE_2`. A STAY sprite still turns, because `TryWalking`
## writes the facing before `CanWalkOntoTile` refuses its step.
const OBJECT_MOVEMENT_STAY: int = 0xFF
const OBJECT_MOVEMENT_NONE: int = 0xFF
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
## `CanWalkOntoTile`'s two displacement counters, $8 apiece at map load: down
## and right are never refused, up stops at 0, and the vertical test also stands
## in front of a sideways step.
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
const SCRIPT_LD_DE: int = 0x11
const SCRIPT_LD_BC: int = 0x01
const SCRIPT_LD_B: int = 0x06
const SCRIPT_LD_A: int = 0x3E
const SCRIPT_LD_A_MEM: int = 0xFA
const SCRIPT_LD_MEM_A: int = 0xEA
const SCRIPT_LDH_MEM_A: int = 0xE0
const SCRIPT_AND_A: int = 0xA7
const SCRIPT_XOR_A: int = 0xAF
## `CheckEvent flag, 1`: one `rrca` per bit up to the one asked about, or `add a`
## alone for bit 7, which leaves the answer in carry rather than in Z.
const SCRIPT_RRCA: int = 0x0F
const SCRIPT_ADD_A: int = 0x87
const SCRIPT_HIGH_BIT: int = 7
const SCRIPT_AND_N: int = 0xE6
const SCRIPT_LD_C: int = 0x0E
const SCRIPT_LD_B_A: int = 0x47
const SCRIPT_LD_C_A: int = 0x4F
## `ld a, b`, which carries a facing chosen either side of a branch past it.
const SCRIPT_LD_A_B: int = 0x78
## `GuardDrinksList`, three drinks under a zero.
const GUARD_DRINK_MAX: int = 8
## `map_coord_movement`: `db y, x` and a pointer, under a $FF.
const ARROW_ROW_SIZE: int = 4
const ARROW_TILE_MAX: int = 64
const SCRIPT_LDH_A_MEM: int = 0xF0
const SCRIPT_DEC_A: int = 0x3D
const SCRIPT_INC_A: int = 0x3C
## `ld [hli], a`, which is how `AgathaScriptWalkIntoRoom` writes its six steps.
const SCRIPT_LD_HLI_A: int = 0x22
const SCRIPT_LD_A_HLI: int = 0x2A
const SCRIPT_LD_E: int = 0x1E
const SCRIPT_ADD_HL_DE: int = 0x19
const SCRIPT_LD_H_HL: int = 0x66
const SCRIPT_LD_L_A: int = 0x6F
const SCRIPT_INC_H: int = 0x24
const SCRIPT_INC_HL: int = 0x23
const SCRIPT_INC_DE: int = 0x13
const SCRIPT_DEC_B: int = 0x05
const SCRIPT_CP_B: int = 0xB8
const SCRIPT_CP_C: int = 0xB9
const SCRIPT_LD_A_HL: int = 0x7E
const SCRIPT_ADD_N: int = 0xC6
const SCRIPT_LD_H_D: int = 0x62
const SCRIPT_LD_L_E: int = 0x6B
const SCRIPT_LD_D_H: int = 0x54
const SCRIPT_LD_E_L: int = 0x5D
const SCRIPT_AND_B: int = 0xA0
const SCRIPT_OR_N: int = 0xF6
const SCRIPT_ITEM_QUANTITY_SOURCE: int = -100
const SCRIPT_SYMBOLIC_COORD_INDEX: String = "coord_index"
const SCRIPT_LD_HL_A: int = 0x77
const SCRIPT_LD_HL_N: int = 0x36
const SCRIPT_LD_A_C: int = 0x79
const SCRIPT_LD_A_L: int = 0x7D
const SCRIPT_LD_A_H: int = 0x7C
const SCRIPT_DEC_HL: int = 0x35
const SCRIPT_SWAP_A: int = 0x37
const SCRIPT_COORD_SOURCES: Array[String] = ["player_y", "player_x"]
## `PAD_DOWN` down to `PAD_RIGHT`, bits 7 to 4, as `Gen2WorldAPI`'s directions.
const PAD_DIRECTIONS: Dictionary = {0x80: 0, 0x40: 1, 0x20: 2, 0x10: 3}
const PAD_DOWN_MASK: int = 0x80
## `wSimulatedJoypadStatesEnd`'s buffer, one walking step an entry. The longest
## the corpus writes is `WalkToLance_RLEList`'s 37.
const SIMULATED_JOYPAD_MAX: int = 48
## `DecodeRLEList`'s pairs of a byte and a repeat count, under a $FF.
const RLE_PAIR_SIZE: int = 2
const RLE_END: int = 0xFF
## `NPC_MOVEMENT_DOWN` to `..._RIGHT`, $00 to $C0: the top two bits are already
## the order [constant PAD_DIRECTIONS] counts in, and a low bit set is
## `NPC_CHANGE_FACING`, whose facing is whatever `c` last held.
const NPC_MOVEMENT_SHIFT: int = 6
const NPC_MOVEMENT_LOW_BITS: int = 0x3F
const NPC_MOVEMENT_END: int = 0xFF
const NPC_MOVEMENT_MAX: int = 32
## Yellow's `Func_5288`: $04 to $07 are the four directions at a doubled step.
const NPC_RUN_FIRST: int = 0x04
const NPC_RUN_LAST: int = 0x07
## Below `wSpriteStateData1`: an address at or above it is WRAM, so a `de`
## naming one is `FindPathToPlayer`'s answer rather than a list in the bank.
const SCRIPT_WRAM_BASE: int = 0xC000
const SCRIPT_PREFIX: int = 0xCB
const SCRIPT_JR: int = 0x18
const SCRIPT_JR_NZ: int = 0x20
const SCRIPT_JP: int = 0xC3
const SCRIPT_RET: int = 0xC9
const SCRIPT_CALL: int = 0xCD
const SCRIPT_HRAM_BASE: int = 0xFF00
## `wGameProgressFlags`' own run of `w<Map>CurScript` bytes, 122 on all three
## cartridges, which `CallFunctionInTable` dispatches on.
const MAP_SCRIPT_BYTES: int = 0x7A
const MAP_SCRIPT_STATES: int = 32
## What a `<Map>_ScriptPointers` word has to be to be a pointer at all.
const SCRIPT_LOWEST: int = 0x0100
const SCRIPT_CEILING: int = 0x8000
## How deep a `call` to a routine the layout does not name may nest: the Fan
## Club's second state reaches `InitializePikachuTextID` three calls down.
const SCRIPT_CALL_DEPTH: int = 3
const SCRIPT_PUSH_AF: int = 0xF5
const SCRIPT_POP_AF: int = 0xF1
const SCRIPT_PUSH_HL: int = 0xE5
const SCRIPT_POP_HL: int = 0xE1
const SCRIPT_PUSH_BC: int = 0xC5
const SCRIPT_POP_BC: int = 0xC1
const SCRIPT_ADD_B: int = 0x80
const SCRIPT_LD_D_A: int = 0x57
const SCRIPT_LD_E_A: int = 0x5F
const SCRIPT_ADC_B: int = 0x88
const SCRIPT_SRL_A: int = 0x3F
## Bytes a script writes and the world keeps by name, `Random` or not.
const SCRIPT_STORED_BYTES: Array[String] = ["first_lock_trash_can", "lucky_slot_index"]
const SCRIPT_RANDOM_SOURCES: Array[String] = ["random_add", "random_sub"]
## BIT_CUR_MAP_LOADED_1 and BIT_CUR_MAP_LOADED_2, which `EnterMap` sets.
const MAP_LOADED_1_BIT: int = 5
const MAP_LOADED_2_BIT: int = 6
const MAP_LOAD_BOTH: int = (1 << MAP_LOADED_1_BIT) | (1 << MAP_LOADED_2_BIT)
## A `dbmapcoord` list: `db y, x` rows under a terminator.
const MAP_COORD_END: int = 0xFF
const MAP_COORD_SIZE: int = 2
## The keys a decoded node keeps its branches under, and the only arrays a
## walker may recurse into: `either`, `cells` and `moves` are values.
const SCRIPT_BRANCH_KEYS: Array[String] = [
	"then", "else", "yes", "no", "ok", "full", "done",
]
## Each key is a conditional `jr` or `jp`, the value whether it is taken when
## the tested bit was set; the carry rows read the flag a routine answers in.
const SCRIPT_BRANCHES: Dictionary = {0x20: true, 0xC2: true, 0x28: false, 0xCA: false}
const SCRIPT_CARRY_BRANCHES: Dictionary = {0x38: true, 0xDA: true, 0x30: false, 0xD2: false}
const SCRIPT_CALLS: Array[String] = [
	"print_text", "text_script_end", "disable_waiting", "yes_no_choice",
	"give_item", "is_item_in_bag", "bankswitch", "play_cry", "wait_for_sound",
	"predef", "display_pokedex", "give_pokemon", "wait_for_button", "load_item_list",
	"auto_textbox_on", "auto_textbox_off", "has_enough_money", "display_text_box",
	"has_enough_coins", "print_predef_text", "display_text_id", "count_set_bits",
	"start_simulating_joypad", "update_sprites", "play_sound", "play_sound_wait",
	"call_function_in_table", "execute_map_script", "load_gym_names",
	"text_box_border", "place_string", "handle_menu_input", "add_n_times",
	"remove_item_from_inventory", "display_list_menu", "copy_to_string_buffer",
	"delay_frame", "delay_frames", "delay_3", "play_default_music", "check_map_trainers",
	"player_coords_in_array", "start_trainer_battle", "end_trainer_battle", "force_bike_or_surf",
	"play_music", "stop_all_music", "random", "set_sprite_position_2", "set_sprite_image",
	"set_sprite_image_2", "enable_pikachu_drawing", "disable_pikachu_drawing",
	"check_pikachu_following", "disable_pikachu_following", "enable_pikachu_following",
	"apply_pikachu_movement",
	"set_sprite_facing", "set_sprite_facing_delay", "sprite_stay", "move_sprite",
	"decode_rle", "decode_arrow_movement", "update_gym_gates",
	"serial_connect", "fill_memory", "save_end_battle_text", "engage_map_trainer",
	"check_boulder_coords", "sprite_pointer_1", "sprite_pointer_2",
	"add_party_mon", "get_item_name", "get_mon_name", "get_sprite_position_2",
	"display_party_menu", "get_party_mon_name",
	"gb_pal_white_out_delay", "restore_screen_tiles", "load_gb_pal",
	"save_screen_1", "load_screen_1", "save_screen_2", "reload_map_data", "copy_data",
	"init_battle_enemy", "set_sprite_position", "get_sprite_position",
	"fade_out_white", "fade_in_white", "fade_out_black", "fade_in_black", "init",
]
## The flag bits a `set` or `res` spends nothing on: BIT_SPINNING is an
## animation this port does not draw, `wStatusFlags5`'s two are the queued
## walk's own state, and BIT_FORCED_WARP is `OverworldLoop`'s alone.
const SPINNING_BIT: int = 7
const FORCED_WARP_BIT: int = 2
## BIT_NO_MAP_MUSIC is a script's hold on the map's music, which no node here
## carries, and `wPikachuMapScriptFlags` the follower nothing here draws.
const NO_MAP_MUSIC_BIT: int = 1
const NO_TEXT_DELAY_BIT: int = 6
const SCRIPT_SCRATCH_BYTES: Array[String] = [
	"which_trade", "rival_starter_ball", "trainer_header_flag_bit", "opponent_after_wrong_answer",
	"saved_npc_movement_index",
]
## The scratch bytes a walk reads as a run-time value.
const SCRIPT_RUNTIME_SCRATCH: Array[String] = [
	"trainer_header_flag_bit", "opponent_after_wrong_answer", "sprite_index_wram",
	"saved_npc_movement_index",
]
## `PokemonTower7FNPCCoordMovementTable`: `map_coord_movement` rows, sixteen
## bytes a rocket, matched against the player's cell.
const OBJECT_COORD_ROWS: int = 4
const SCRIPT_FLAG_ACTION_SOURCE: int = -101
## The row a hand-drawn menu's cursor stands on, read as an item id.
const SCRIPT_MENU_ITEM_SOURCE: int = -102
## `wFossilItem`, read back into `hItemToRemoveID` on the way past the box.
const SCRIPT_FOSSIL_ITEM_SOURCE: int = -103
const SCRIPT_PAD_B_BIT: int = 1
## `AddNTimes` over `hl = 3`, `bc = 2` and `dec l`; the Bike Shop's `ld b, 4` agrees.
const SCRIPT_MENU_ROWS_PER_ENTRY: int = 2
const SCRIPT_MENU_SIZED_BY_COUNT: int = -1
## `ld d, 0`, `ld e, a`, `add hl, de`, `ld a, [hl]` behind `ld hl, wFilteredBagItems`.
const SCRIPT_FILTERED_INDEX: Array[int] = [0x16, 0x00, 0x5F, 0x19, 0x7E]
const SCRIPT_DEC_L: int = 0x2D
const SCRIPT_LD_B_L: int = 0x45
const SCRIPT_LD_D: int = 0x16
const SCRIPT_JR_CARRY: int = 0x38
const SCRIPT_SUB_N: int = 0xD6
const LIST_MENU_MAX: int = 16
const FILTERED_BAG_MAX: int = 4
const MENU_STRING_MAX: int = 24
const FILTER_PRINT_SCAN: int = 32
const BAG_SCAN_SIZE: int = 40
const MENU_ROW_BREAK: String = "<NEXT>"
const FLAG_ACTION_RESET: int = 0
const FLAG_ACTION_SET: int = 1
const FLAG_ACTION_TEST: int = 2
## `PewterPokecenterJigglypuffText`, whose song loop is one node behind its
## box; `wSprite03StateData1` is the singer. Yellow's `jigglypuff_tail` is the
## code past `PlayDefaultMusic`, in the routine's own bank.
const SCRIPT_FIRST_BOX_ROWS: Array[String] = ["jigglypuff_text"]
const JIGGLYPUFF_OBJECT: int = 2
const JIGGLYPUFF_HUSH_FRAMES: int = 32
const JIGGLYPUFF_SPIN_FRAMES: int = 24
const JIGGLYPUFF_AFTER_FRAMES: int = 48
const MUSIC_JIGGLYPUFF_SONG: Array[int] = [0x1F, 208]
const OAKS_AIDE_TEXT_AT: Dictionary = {
	"hi": 0x00, "uh_oh": 0x05, "come_back": 0x0A, "here_you_go": 0x0F,
	"got_item": 0x14, "no_room": 0x1A,
}
const OAKS_AIDE_GOT_ITEM: int = 1
const SCRIPT_SILENT_FLAGS: Dictionary = {
	"movement_flags": 1 << SPINNING_BIT,
	"status_flags_5": (1 << SCRIPTED_NPC_MOVEMENT_BIT) | (1 << SCRIPTED_MOVEMENT_STATE_BIT)
		| (1 << NO_TEXT_DELAY_BIT),
	"status_flags_7": (1 << FORCED_WARP_BIT) | (1 << NO_MAP_MUSIC_BIT),
	"status_flags_3": (1 << WARP_FROM_SCRIPT_BIT) | (1 << ON_DUNGEON_WARP_BIT)
		| (1 << TALKED_TO_TRAINER_BIT) | (1 << PRINT_END_BATTLE_TEXT_BIT),
	"status_flags_6": 1 << DUNGEON_WARP_BIT,
	"pikachu_map_script_flags": 0xFF & ~((1 << PIKACHU_MAP_PAUSE_IGT_BIT)
		| (1 << PIKACHU_MAP_SURF_SELECT_BIT)),
	## The champion fight turns battle animations on for itself; the sight walk
	## owns BIT_SEEN_BY_TRAINER and the renderer BIT_NO_SPRITE_UPDATES.
	"options": 1 << BATTLE_ANIMATION_BIT,
	"misc_flags": (1 << SEEN_BY_TRAINER_BIT) | (1 << NO_SPRITE_UPDATES_BIT),
}
const BATTLE_ANIMATION_BIT: int = 7
const SEEN_BY_TRAINER_BIT: int = 0
const NO_SPRITE_UPDATES_BIT: int = 4
const DUNGEON_WARP_BIT: int = 4
const WARP_FROM_SCRIPT_BIT: int = 3
const ON_DUNGEON_WARP_BIT: int = 4
const NO_NPC_FACE_PLAYER_BIT: int = 5
const TALKED_TO_TRAINER_BIT: int = 6
const PRINT_END_BATTLE_TEXT_BIT: int = 7
const PUSHED_BOULDER_BIT: int = 7
## Bits clear whenever a state body runs: the fall and the sight walk happen outside it.
const SCRIPT_ZERO_BITS: Dictionary = {
	"status_flags_3": (1 << ON_DUNGEON_WARP_BIT) | (1 << TALKED_TO_TRAINER_BIT),
}
const PIKACHU_SPAWN_SURFING_BIT: int = 6
const PIKACHU_SPAWN_STARTER_BIT: int = 7
const PIKACHU_MAP_PAUSE_IGT_BIT: int = 0
## `PikachuMovement_EnterCellSeparatorNotDown` is the longest, at eight bytes.
const PIKACHU_MOVEMENT_MAX: int = 32
## The follower's bank, `PikachuEmotionTable`'s 34 rows and
## `StarterPikachuEmotionsJumptable`'s commands with their argument widths.
const PIKACHU_BANK: int = 0x3F
const TEXT_PIKACHU_ANIM: int = 0xD4
const PIKACHU_EMOTIONS: int = 34
const PIKACHU_EMOTION_END: int = 0xFF
const PIKACHU_EMOTION_COMMANDS: Dictionary = {
	1: "text", 2: "pcm", 3: "emote", 4: "movement", 5: "pikapic", 6: "subcmd",
	7: "delay", 9: "turn_away",
}
const PIKACHU_EMOTION_SIZES: Dictionary = {1: 2, 2: 1, 3: 1, 4: 2, 5: 1, 6: 1, 7: 1}
const PIKACHU_HAPPINESS_ROW: int = 6
## `PikaPicAnimPointers`' 30 rows, `PikaPicAnimBGFramesPointers`' 36,
## `PikaPicTilemapPointers`' 43 and `PikaPicAnimGFXHeaders`' 63 of four bytes,
## a compressed one reserving `5 * 5` tiles. The setup commands and their
## argument widths are `RunPikaPicAnimSetupScript.Jumptable`'s.
const PIKAPIC_SCRIPTS: int = 30
const PIKAPIC_FRAMESETS: int = 36
const PIKAPIC_TILEMAPS: int = 43
const PIKAPIC_GFX: int = 63
const PIKAPIC_GFX_HEADER_SIZE: int = 4
const PIKAPIC_COMPRESSED: int = 0xFF
const PIKAPIC_PIC_TILES: int = 25
const PIKAPIC_FRAMESET_END: int = 0xE0
const PIKAPIC_COMMANDS: Dictionary = {
	0: "nop", 1: "delay", 2: "loadgfx", 3: "object", 4: "nop", 5: "nop", 6: "delete",
	7: "nop", 8: "nop", 9: "jump", 10: "duration", 11: "cry", 12: "thunderbolt",
	13: "run", 14: "ret",
}
const PIKAPIC_COMMAND_SIZES: Dictionary = {1: 1, 2: 1, 3: 5, 6: 1, 9: 2, 10: 2, 11: 1}
const PIKAPIC_JUMP: int = 9
const PIKAPIC_RET: int = 14
const PIKAPIC_TILE_KEEP: int = 0xFF
## `PikachuCriesPointerTable`'s 43 `dba` rows, each clip opening on its byte
## count; `PlayPikachuSoundClip`'s three `DelayFrame`s, and the eight one-bit
## samples a byte holds at the 394 samples a frame the cartridge was measured at.
const PIKACHU_CRIES: int = 43
const PIKACHU_CRY_ROW_SIZE: int = 3
const PIKACHU_CRY_LEAD_FRAMES: int = 3
const PIKACHU_CRY_SAMPLES_PER_FRAME: int = 394


## `PlayPikachuSoundClip`'s frames for a clip of [param clip_bytes].
static func pikachu_cry_frames(clip_bytes: int) -> int:
	return PIKACHU_CRY_LEAD_FRAMES \
		+ ceili(float(clip_bytes * 8) / float(PIKACHU_CRY_SAMPLES_PER_FRAME))
## `DisplayTextIDInit`'s `CopyScreenTileBufferToVRAM` and `LoadFontTilePatterns`,
## measured from the A press to `TalkToPikachu` on the cartridge.
const TEXT_INIT_FRAMES: int = 20
## `MapSpecificPikachuExpression`'s named rows of that table, its `.Emotions`
## list under `wPikachuEmotionModifier`, and the maps and script it reads.
const PIKACHU_EMOTION_FAN_CLUB_SEEL: int = 29
const PIKACHU_EMOTION_FAN_CLUB_LEFT: int = 30
const PIKACHU_EMOTION_PEWTER_ASLEEP: int = 26
const PIKACHU_EMOTION_BILL_HEALED: int = 27
const PIKACHU_EMOTION_BILL_ARRIVED: int = 23
const PIKACHU_EMOTION_BILL_UNMET: int = 32
const PIKACHU_EMOTION_BILL_MET: int = 31
const PIKACHU_EMOTION_ASLEEP: int = 11
const PIKACHU_EMOTION_AILING: int = 28
const PIKACHU_EMOTION_TOWER: int = 22
const PIKACHU_MODIFIER_EMOTIONS: Array[int] = [18, 21, 23, 24, 25]
const POKEMON_FAN_CLUB: int = 0x5A
const PEWTER_POKECENTER: int = 0x3A
const BILLS_HOUSE: int = 0x58
const POKEMON_TOWER_1F: int = 0x8E
const POKEMON_TOWER_7F: int = 0x94
const MET_BILL_2_EVENT: int = 1372
const BILLS_HOUSE_SCRIPT_ARRIVED: int = 0
const BILLS_HOUSE_SCRIPT_HEALED: int = 5
## `StarterPikachuEmotionCommand_subcmd`'s rows that do anything here.
const PIKACHU_SUBCMD_REDRAW: int = 2
const PIKACHU_SUBCMD_PEWTER: int = 4
const PIKACHU_SUBCMD_FAN_CLUB: int = 5
const PIKACHU_SUBCMD_BILLS: int = 6
const PIKACHU_REDRAW_FRAMES: int = 3
const PIKACHU_MAP_SURF_SELECT_BIT: int = 1
const PIKACHU_MAP_SCRIPT_ACTIVE_BIT: int = 7
## `IsStarterPikachuAliveInOurParty` compares `NAME_LENGTH_JP - 1` letters of
## the OT name against the player's.
const OT_MATCH_LENGTH: int = 5
## Bits that live for one map, held by name until the next map load.
const SCRIPT_VOLATILE_BITS: Dictionary = {
	"misc_flags": {PUSHED_BOULDER_BIT: "pushed_boulder"},
	"gym_quiz_flags": {7: "gym_quiz_answered"},
	"status_flags_3": {NO_NPC_FACE_PLAYER_BIT: "no_npc_face_player"},
	"pikachu_map_script_flags": {PIKACHU_MAP_SCRIPT_ACTIVE_BIT: "pikachu_script_active"},
}
const SCRIPT_TEMP_BYTES: Array[String] = ["object_to_hide", "object_to_show"]
## The sight walk owns engagement; dungeon warps are dispatched separately.
const SCRIPT_ZERO_SOURCES: Array[String] = [
	"trainer_header_flag_bit", "which_dungeon_warp",
]
## `wIsInBattle` is LOST_BATTLE when the player lost and `wBattleResult` 2 when
## the wild was caught or ran, which is all a post-battle state asks.
const BATTLE_OUTCOME_LOST: String = "lost"
const BATTLE_OUTCOME_ESCAPED: String = "escaped"
const BATTLE_OUTCOME_WON: String = "won"
const BATTLE_OUTCOME_SOURCES: Dictionary = {
	"is_in_battle": [0xFF, BATTLE_OUTCOME_LOST],
	"battle_result": [2, BATTLE_OUTCOME_ESCAPED],
}
## `wBattleType` read across onto Crystal's numbering. The old man and Yellow's
## Prof. Oak share `DisplayBattleMenu`'s branch, so both are the Dude's tutorial
## here; `tutor` names `LoadPlayerBackPic`'s pic and `.oldManName`'s row.
const BATTLE_TYPE_OLD_MAN: int = 1
const BATTLE_TYPE_SAFARI: int = 2
const BATTLE_TYPE_PIKACHU: int = 4
const BATTLE_TYPES: Dictionary = {
	BATTLE_TYPE_OLD_MAN: {"battle_type": Gen2Battle.BATTLETYPE_TUTORIAL, "tutor": "old_man"},
	BATTLE_TYPE_SAFARI: {"battle_type": Gen2Battle.BATTLETYPE_SAFARI},
	BATTLE_TYPE_PIKACHU: {"battle_type": Gen2Battle.BATTLETYPE_TUTORIAL, "tutor": "prof_oak"},
}
const TUTOR_NAMES: Dictionary = {"old_man": "OLD MAN", "prof_oak": "PROF.OAK"}
## `wCurOpponent` as each tutor's script writes it, by dex number.
const TUTOR_WILDS: Dictionary = {
	RomRegistry.RED: {BATTLE_TYPE_OLD_MAN: 13}, RomRegistry.BLUE: {BATTLE_TYPE_OLD_MAN: 13},
	RomRegistry.YELLOW: {BATTLE_TYPE_OLD_MAN: 19, BATTLE_TYPE_PIKACHU: 25},
}
const TUTOR_WILD_LEVEL: int = 5
## `OldManItemList` is fifty balls where Yellow's `SimulatedInputBattleItemList` is one.
const TUTOR_BALLS: Dictionary = {RomRegistry.RED: 50, RomRegistry.BLUE: 50, RomRegistry.YELLOW: 1}
## `DisplayBattleMenu`'s two `DelayFrames` and `DisplayListMenuIDLoop`'s one.
const TUTOR_FRAMES: Dictionary = {
	RomRegistry.RED: [80, 50, 80], RomRegistry.BLUE: [80, 50, 80],
	RomRegistry.YELLOW: [20, 20, 20],
}
## Yellow's `ItemUseBall` answers `$63` while EVENT_INITIAL_CATCH_TRAINING stands.
const INITIAL_CATCH_TRAINING_EVENT: Dictionary = {RomRegistry.YELLOW: 47}
## Routines named by a full ROM offset, the same address in another bank being another routine.
const SCRIPT_BANKED_CALLS: Array[String] = [
	"coin_box", "music_rival_start", "music_rival_tempo", "schedule_pikachu_spawn",
	"music_rival_start_tempo", "music_cities1_tempo", "is_starter_pikachu_alive",
	"check_pikachu_status", "play_pikachu_sound_clip", "celadon_granny_thresholds",
	"try_apply_pikachu_movement", "mt_moon_pikachu_movement", "cinnabar_pikachu_movement",
	"emotion_bubble", "find_path_to_player", "calc_player_relative",
	"hall_of_fame_pc", "is_player_on_dungeon_warp", "load_spinner_arrow_tiles",
	"pewter_guys", "convert_npc_directions", "heal_party", "save_game_data",
	"get_item_quantity", "flag_action", "route23_copy_badge_text", "oaks_aide",
	"starter_dex", "display_dex_rating",
	"safari_low_cost", "safari_nag", "name_rater_check_ot", "name_rater_screen",
]
## The four of those a `farcall` spends nothing on: no node carries a sound.
const SCRIPT_SILENT_BANKED_CALLS: Array[String] = [
	"music_rival_start", "music_rival_tempo", "music_rival_start_tempo",
	"music_cities1_tempo", "play_pikachu_sound_clip",
	"load_spinner_arrow_tiles", "convert_npc_directions", "pewter_guys",
]
## The routines that spend nothing here: no node carries a sound, a press
## already ends every box, and `wAutoTextBoxDrawingControl` has no counterpart.
const SCRIPT_SILENT_CALLS: Array[String] = [
	"play_cry", "wait_for_sound", "wait_for_button",
	"auto_textbox_on", "auto_textbox_off", "count_set_bits", "update_sprites",
	"play_sound", "play_sound_wait", "load_gym_names",
	"random",
	## `SetSpritePosition2` puts back what `GetSpritePosition2` saved on the same
	## visit, which the map's own table answers here; the image index is drawn.
	"set_sprite_position_2", "set_sprite_image", "set_sprite_image_2",
	## Red and Blue spell `StopAllMusic` as `PlaySound`; only Yellow has a routine.
	"play_music", "stop_all_music",
	## A wait is frames of nothing and the map music is nobody's here. The three
	## trainer rows every fighting map's own table opens with are the sight walk
	## `Gen2WorldAPI.dispatch_sight_events` runs behind this script.
	"delay_frame", "delay_frames", "delay_3", "play_default_music", "check_map_trainers",
	"start_trainer_battle", "end_trainer_battle",
	"force_bike_or_surf",
	"serial_connect", "fade_out_white", "fade_in_white", "fade_out_black",
	"fade_in_black", "get_sprite_position", "init_battle_enemy",
	"gb_pal_white_out_delay", "restore_screen_tiles", "load_gb_pal",
	"get_sprite_position_2", "save_screen_1", "load_screen_1", "save_screen_2",
	"reload_map_data", "copy_data",
]
const SCRIPT_CONDITIONAL_CALLS: Array[int] = [0xC4, 0xCC, 0xD4, 0xDC]
## The two of them the zero flag answers, `true` calling on a clear one.
const SCRIPT_ZERO_CALLS: Dictionary = {0xC4: true, 0xCC: false}
const SCRIPT_CARRY_CALLS: Array[int] = [0xD4, 0xDC]
const SCRIPT_CALLS_ON_SET: Array[int] = [0xC4, 0xDC]
const SPRITE_PIXEL_FIELDS: Array[int] = [1, 4, 6]
const SPRITE_MAP_Y_AT: int = 4
const SPRITE_MAP_X_AT: int = 5
const SPRITE_MAP_OFFSET: int = 4
const ROUTE23_SCAN: int = 0x30
const ROUTE23_OPCODE_SIZES: Dictionary = {
	0x21: 3, 0xFA: 3, 0x47: 1, 0x1E: 2, 0x0E: 2, 0x2A: 1, 0xFE: 2, 0xC8: 1, 0x1C: 1,
	0x0D: 1, 0xB8: 1, 0x20: 2, 0xD0: 1, 0x7B: 1, 0xE0: 2, 0x79: 1, 0xEA: 3, 0x06: 2,
	0x3E: 2, 0xCD: 3,
}
const EMOTE_FRAMES: int = 60
const RIVAL_CLASSES: Array[int] = [0x19, 0x2A, 0x2B]
const BADGE_COUNT: int = 8
const MOVE_DOWN: int = 0
const MOVE_UP: int = 1
const MOVE_LEFT: int = 2
const MOVE_RIGHT: int = 3
const MOVEMENT_SCRIPT_PALLET: int = 1
const MOVEMENT_SCRIPT_MUSEUM: int = 2
const MOVEMENT_SCRIPT_GYM: int = 3
const PALLET_PATH_LEFT_COLUMN: int = 0x0A
const PEWTER_CITY: int = 0x02
## Which map each table's two RLE lists stand on.
const MOVEMENT_SCRIPT_LISTS: Dictionary = {
	PALLET_TOWN: {MOVEMENT_SCRIPT_PALLET: ["rle_pallet_player", "rle_pallet_object"]},
	PEWTER_CITY: {
		MOVEMENT_SCRIPT_MUSEUM: ["rle_museum_player", "rle_museum_object"],
		MOVEMENT_SCRIPT_GYM: ["rle_gym_player", "rle_gym_object"],
	},
}
const NPC_CHANGE_FACING: int = 0xE0
const BADGE_NAME_MAX: int = 13
## `wSpriteStateData1`: sixteen slots of sixteen bytes, the player's own first
## and a map's objects behind it in their table order, facing at offset nine.
const SPRITE_SLOT_SIZE: int = 0x10
const SPRITE_FACING_AT: int = 9
const SPRITE_SLOTS: int = 16

## The stores a row is walked past: nothing here reads any of them.
const SCRIPT_SILENT_STORES: Array[String] = [
	"joy_held", "auto_text_box_control", "joy_ignore", "update_sprites_enabled",
	## A forced walk writes the pad bit over the player's own facing byte, and
	## the `walk` node behind it carries the direction anyway.
	"facing_direction",
	## `hJoyPressed` beside `hJoyHeld`, and the sound id no node here carries.
	"joy_pressed", "new_sound_id",
	## The captain's back rub swaps the audio bank around its jingle.
	"audio_rom_bank", "audio_saved_rom_bank",
	"npc_movement_bank", "list_scroll_offset", "dungeon_warp_destination",
	"which_dungeon_warp", "sprite_screen_y", "sprite_screen_x",
	"letter_printing_delay", "player_movement_byte_1", "override_joypad_mask",
	"mon_data_location", "joy_released",
	"trainer_header_flag_bit", "party_menu_type",
	## The menu registers, which the `menu` node behind them carries instead.
	"current_menu_item", "max_menu_item", "top_menu_item_y", "top_menu_item_x",
	"menu_watched_keys",
	"last_menu_item", "menu_item_to_swap", "print_item_prices", "list_menu_id",
	"filtered_bag_count", "walk_bike_surf_state_copy",
	## `AddPartyMon`'s catch-rate byte, read back by a Time Capsule alone.
	"party_mon_1_catch_rate",
]
## The same over two bytes; `LoadItemList` already left the list itself.
const SCRIPT_SILENT_WORDS: Array[String] = ["list_pointer"]
## `cp n` and the two conditional `ret`s behind it, whose value is the side
## taken when the comparison did not match.
const SCRIPT_CP_N: int = 0xFE
const SCRIPT_RET_BRANCHES: Dictionary = {0xC0: true, 0xC8: false}
## The same two on carry, which `ret nc` behind `ArePlayerCoordsInArray` is.
const SCRIPT_RET_CARRY_BRANCHES: Dictionary = {0xD8: true, 0xD0: false}
## `PrintPredefTextID`'s operand counts from 1. Yellow puts the Fan Club's two
## pictures at $0C and $0D, so every row past the fossils sits two higher there
## and an id read as Red's decodes, in the wrong bank, to something.
const TEXT_PREDEF_COUNT: int = 66
const TEXT_PREDEF_COUNT_YELLOW: int = 68
const TEXT_PREDEF_SIZE: int = 2
const TEXT_PREDEFS: Dictionary = {
	"card_key_success": 0x01, "card_key_fail": 0x02,
	"gym_statue": 0x0C, "gym_statue_badge": 0x0D, "found_hidden_item": 0x24,
	"hidden_item_bag_full": 0x25, "found_hidden_coins": 0x2B,
	"dropped_hidden_coins": 0x2C, "trash": 0x26, "first_lock": 0x3B, "second_lock": 0x3D,
	"reset": 0x3E,
}
const TEXT_PREDEFS_YELLOW: Dictionary = {
	"card_key_success": 0x01, "card_key_fail": 0x02,
	"gym_statue": 0x0E, "gym_statue_badge": 0x0F, "found_hidden_item": 0x26,
	"hidden_item_bag_full": 0x27, "found_hidden_coins": 0x2D,
	"dropped_hidden_coins": 0x2E, "trash": 0x28, "first_lock": 0x3D, "second_lock": 0x3F,
	"reset": 0x40,
}
## `PrintCardKeyText`: a Silph Co. door draws either of two tiles, the top
## floor's own a third, and the block that opens one is $0E under it and $03
## there. SILPH_CO_11F is the one floor the routine names by number.
const CARD_KEY_DOOR_TILES: Array[int] = [0x18, 0x24]
const CARD_KEY_TOP_FLOOR_TILE: int = 0x5E
const CARD_KEY_OPEN_BLOCK: int = 0x0E
const CARD_KEY_TOP_FLOOR_BLOCK: int = 0x03
const SILPH_CO_TOP_FLOOR: int = 0xEB
## `SilphCoMapList`, ten floors under a terminator.
## The two packed-decimal buffers a price is written into, most significant
## byte first. `wPriceTemp` stands at `wWhichTrade`'s own address.
const SCRIPT_BCD_BUFFERS: Array[String] = ["money_hram", "which_trade"]
const MONEY_BYTES: int = 3
## `hCoins` unions `hMoney`'s last two bytes and `hUnusedCoinsByte` its first, so one buffer
## holds both, and `AddBCD`'s `.fill` is what ceils a sum that carried out of the two.
const COIN_BYTES: int = 2
const COIN_BUFFER_AT: int = 1
const COIN_CEILING: int = 9999
const MONEY_BOX_ID: int = 0x13
const SCRIPT_SHORT_SIZE: int = 2
const SCRIPT_LONG_SIZE: int = 3
## Every conditional `jr` is below this and every conditional `jp` above it, so
## `jp nz` at $C2 is three bytes where [constant SCRIPT_JP] would call it two.
const SCRIPT_HOP_LIMIT: int = 0x40
## The `CB` prefix's three rows, the low three bits naming the operand.
const SCRIPT_BIT_BASE: int = 0x40
const SCRIPT_RES_BASE: int = 0x80
const SCRIPT_SET_BASE: int = 0xC0
const SCRIPT_PREFIX_BLOCK: int = 0x40
const SCRIPT_OPERAND_A: int = 7
const SCRIPT_OPERAND_HL: int = 6
## `flag_array NUM_EVENTS`: 2,560 events on all three cartridges.
const EVENT_FLAG_BYTES: int = 320
## Generation 1's own saved flag runs, which Crystal's engine flag table names
## none of, so they sit above every Crystal index. The value is the run's width
## in bytes and the order is what fixes where each one starts.
const ENGINE_FLAG_BYTES: Dictionary = {
	"status_flags_4": 1,
	"obtained_hidden_items": HIDDEN_ITEM_FLAG_BYTES,
	"obtained_hidden_coins": HIDDEN_COIN_FLAG_BYTES,
	"town_visited": TOWN_VISITED_FLAG_BYTES,
	## Appended, because a run's base is its position here and a saved index
	## may not move.
	"status_flags_1": 1,
	"elite_4_flags": 1,
	"beat_gym_flags": 1,
	"pikachu_map_script_flags": 1,
}
## `PrintStrengthText` sets bit 0 and `IsSurfingAllowed` bit 1. Generation 1 has
## no `ResetBikeFlags`, so bit 0 outlives the map it was set on.
const STRENGTH_ACTIVE_BIT: int = 0
const SURF_ALLOWED_BIT: int = 1
const ENGINE_FLAG_FIRST: int = 256
const ENGINE_FLAG_BITS: int = 8
## `flag_array NUM_CITY_MAPS`, rounded up to the two bytes the array occupies.
const TOWN_VISITED_FLAG_BYTES: int = 2

## `BAG_ITEM_CAPACITY`: one list of slots, not four pockets.
const BAG_ITEM_CAPACITY: int = 20
## The one type byte every Generation 1 item wears, so the shared pack draws the
## bag as the single `DisplayListMenuID` list `engine/menus/start_sub_menus.asm`
## opens.
const BAG_POCKET: int = Gen2Layout.ITEM_POCKET_ITEM

## `KeyItemFlags` (`data/items/key_items.asm`): `dbit` writes item `n + 1` into
## bit `n % 8` of byte `n / 8`, `(NUM_ITEMS + 7) / 8` bytes in all.
const KEY_ITEM_FLAG_BYTES: int = 11
## `UsableItems_PartyMenu` and `UsableItems_CloseMenu`, each a run of item
## numbers ending in `-1`. The guard is the whole item table: a longer run means
## the offset is wrong.
const USABLE_ITEMS_END: int = 0xFF
const USABLE_ITEMS_MAX: int = ITEM_COUNT
## `MAX_WARP_EVENTS`, `MAX_BG_EVENTS` and `MAX_OBJECT_EVENTS`.
const MAX_WARP_EVENTS: int = 32
const MAX_SIGN_EVENTS: int = 16
const MAX_OBJECT_EVENTS: int = 16

## `hidden_event`: y, x, the routine's own argument, then its bank and address.
## Red and Blue keep the map ids and the pointers in two tables; Yellow writes
## the pointer beside each id.
const HIDDEN_EVENT_SIZE: int = 6
const HIDDEN_EVENT_MAP_SIZE: int = 3
const HIDDEN_EVENT_END: int = 0xFF
## `HiddenItemCoords` and `HiddenCoinCoords`: map id, y, x, indexed by position.
const HIDDEN_COORD_SIZE: int = 3
## `flag_array MAX_HIDDEN_ITEMS` and `MAX_HIDDEN_COINS`, in bytes.
const HIDDEN_ITEM_FLAG_BYTES: int = 14
const HIDDEN_COIN_FLAG_BYTES: int = 2
## `AddBCD`'s own ceiling, which a coin case holding 9999 already stands at.
const HIDDEN_COIN_CEILING: int = 9999
## `HiddenCoins` writes a packed-decimal sum by hand off `argument - COIN`, and
## its own `.bcd40` is unreachable: a 40-coin row pays 20.
const HIDDEN_COIN_AMOUNTS: Dictionary = {10: 10, 20: 20, 40: 20}
const HIDDEN_COIN_DEFAULT: int = 100
## The hidden event routines that index a table of their own, read by hand.
const HIDDEN_TABLE_ROUTINES: Array[String] = [
	"hidden_items", "hidden_coins", "bench_guy_text", "gym_statues", "gym_trash",
]
## EVENT_2ND_LOCK_OPENED and EVENT_1ST_LOCK_OPENED. `GymTrashCans` is a mask and
## four cans a row, Yellow's a count and four pairs, and a draw reads past either.
const LOCK_2ND_EVENT: int = 352
const LOCK_1ST_EVENT: int = 353
const TRASH_CANS: int = 15
const TRASH_ROW_SIZE: int = 5
const TRASH_ROW_SIZE_YELLOW: int = 9
const TRASH_TABLE_TAIL: int = 256
const TRASH_TABLE_TAIL_YELLOW: int = 512
const TRASH_FIRST_MASK: int = 0x0E
const TRASH_CAN_MASK: int = 0x0F
const TRASH_THREE_THIRD: int = 0xFF / 3
const TRASH_TEXTS: Array[String] = ["trash", "first_lock", "second_lock", "reset"]
## `bookshelf_tile` is a tileset, a tile and a `tx_pre` id; `MapBadgeFlags` a
## map and its `wBeatGymFlags` mask; `BenchGuyTextPointers` a map, a facing and
## a `tx_pre` id.
const BOOKSHELF_ROW_SIZE: int = 3
const BADGE_ROW_SIZE: int = 2
## `GYM_CITY_LENGTH` and `NAME_LENGTH`, the two runs a gym's own map script
## hands `LoadGymLeaderAndCityName` and `_GymStatueText1` reads back out of RAM.
## The `ld hl`, `ld de` and `jp` are one shape the head of that script reaches.
const GYM_CITY_LENGTH: int = 17
const GYM_LEADER_LENGTH: int = 11
const GYM_NAME_SEARCH: int = 64
const GYM_NAME_TAILS: Array[int] = [SCRIPT_JP, SCRIPT_CALL]
const BENCH_GUY_ROW_SIZE: int = 3

## `wTileMap` is the 20x18 screen and `lda_coord 8, 9` the tile the player
## stands on: a walk cell's bottom left one, the cell being two tiles each way.
const SCREEN_WIDTH_TILES: int = 20
const SCREEN_HEIGHT_TILES: int = 18
const SCREEN_PLAYER_COLUMN: int = 8
const SCREEN_PLAYER_ROW: int = 9

## `wStatusFlags5`'s two scripted-movement bits: one stands while the walk a
## `MoveSprite` started is drawn, the other while the player spends
## `wSimulatedJoypadStatesIndex`, which a body may read instead.
const SCRIPTED_NPC_MOVEMENT_BIT: int = 0
const SCRIPTED_MOVEMENT_STATE_BIT: int = 7
const MOVEMENT_TEST_OBJECT: String = "object"
const MOVEMENT_TEST_PLAYER: String = "player"

## `SPRITE_FACING_*`, which `CheckIfCoordsInFrontOfPlayerMatch` steps by.
const FACING_DOWN: int = 0x00
const FACING_UP: int = 0x04
const FACING_LEFT: int = 0x08
const FACING_RIGHT: int = 0x0C
const FACING_STEPS: Dictionary = {
	FACING_DOWN: Vector2i(0, 1), FACING_UP: Vector2i(0, -1),
	FACING_LEFT: Vector2i(-1, 0), FACING_RIGHT: Vector2i(1, 0),
}
## `PLAYER_DIR_*` as `UpdatePlayerSprite` reads them, one `bit` per row in this
## order, so a byte with two set takes the first and zero reaches `.notMoving`,
## which leaves the facing byte alone.
const PLAYER_DIR_FACINGS: Array = [
	[0x04, FACING_DOWN], [0x08, FACING_UP], [0x02, FACING_LEFT], [0x01, FACING_RIGHT],
]

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

## Blocks per tileset, read off the pinned checkouts' `.bst` files: nothing in
## the cartridge records an INCBIN's length.
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

## `GoodRodMons`: level, the cartridge's internal index and the dex number the
## cache speaks. Neither this rod nor the Old Rod reads the map at all.
const GOOD_ROD_SLOTS: Array = [[10, 0x9D, 118], [10, 0x47, 60]]
## `old_rod` pins `lb bc, 5, MAGIKARP`, which rgbds writes as one `ld bc`.
const OLD_ROD_SLOT: Array = [5, 129]
const OPCODE_LD_BC: int = 0x01

## `SuperRodData`: a map id and `count` (level, species) rows. Yellow's is one
## row a map, four (species, level) pairs picked by a byte threshold.
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

## `SpriteSheetPointerTable`: a CPU address, the bytes of one half and the bank.
## A row below `FIRST_STILL_SPRITE` is read twice, the second time $C0 further on.
const SPRITE_RECORD_SIZE: int = 4
const SPRITE_COUNT_RED_BLUE: int = 72
const SPRITE_COUNT_YELLOW: int = 82
const SPRITE_STILL_FIRST_RED_BLUE: int = 0x3D
const SPRITE_STILL_FIRST_YELLOW: int = 0x47
const SPRITE_WALKING_TILES: int = 12
const SPRITE_STILL_TILES: int = 4
## `RedBikeSprite`, which `LoadBikePlayerSpriteGraphics` loads by address and no
## row names: the walking strip `INCBIN`'d in front of SPRITE_RED's, so its
## address is that row's less both halves.
const SPRITE_BIKE_BYTES: int = SPRITE_WALKING_TILES * 2 * PokeTiles.TILE_BYTES

## `MonPartySpritePointers`: a CPU address, the tiles to copy, the bank and the
## `vSprites` address. An icon's two frames are four tiles at `ICON << 2` and
## four more `ICONOFFSET` above them.
const MON_ICON_HEADER_SIZE: int = 6
const MON_ICON_HEADER_COUNT_RED_BLUE: int = 28
const MON_ICON_HEADER_COUNT_YELLOW: int = 30
const MON_ICON_FRAME_TILES: int = 4
const MON_ICON_FRAME_OFFSET: int = 0x40
## `vSprites`, which a header's destination is an address inside.
const MON_ICON_VRAM_AT: int = 0x8000
## `MonPartyData` holds one `ICON_*` nybble per dex number, the odd number in
## the high half. Zero is `ICON_MON`, so a cache row is the nybble plus one:
## [method GameData.mon_menu_icon] reads zero as no icon at all.
const MON_ICON_NYBBLES: int = 16
const MON_ICON_VRAM_TILES: int = MON_ICON_FRAME_OFFSET + MON_ICON_NYBBLES * MON_ICON_FRAME_TILES
## `AnimatePartyMon`'s `.editCoords` pair, which shake a pixel down where every
## other icon swaps frame, so the two carry the same picture twice.
const MON_ICON_BALL: int = 0x01
const MON_ICON_HELIX: int = 0x02
const MON_ICON_SHAKING: Array[int] = [MON_ICON_BALL, MON_ICON_HELIX]

## `NUM_TRAINERS`, the trainer classes rather than the individual trainers.
const TRAINER_CLASS_COUNT: int = 47

## `TrainerPicAndMoneyPointers`: a near pointer and the class's base reward
## money as three packed-decimal bytes. Every trainer picture is in the one bank
## the layout records, and `ChiefPic` and `ScientistPic` are the same address.
const TRAINER_PIC_SIZE: int = 5
## `ReadTrainerParty`'s `cp $ff`: a party opening on this stores a level in
## front of every species instead of one for the whole team.
const TRAINER_PARTY_LEVELS: int = 0xFF

## `AIMoveChoiceModificationFunctionPointers` names four layers.
const TRAINER_AI_LAYER_COUNT: int = 4
## `TrainerAIPointers`: a use count and a near pointer.
const TRAINER_AI_ROW_SIZE: int = 3
## Each cartridge's `TrainerAIPointers` targets by bank-local address; Yellow
## retuned Koga, Blaine and Sabrina.
const TRAINER_AI_ROUTINES: Dictionary = {
	RomRegistry.RED: {
		0x65E9: "juggler", 0x65EF: "blackbelt", 0x65F5: "giovanni",
		0x65FB: "cooltrainer_m", 0x6601: "cooltrainer_f", 0x6614: "brock",
		0x661C: "misty", 0x6622: "lt_surge", 0x6628: "erika", 0x6634: "koga",
		0x663A: "blaine", 0x6640: "sabrina", 0x664C: "rival2", 0x6658: "rival3",
		0x6664: "lorelei", 0x6670: "bruno", 0x6676: "agatha", 0x6687: "lance",
		0x6693: "generic",
	},
	RomRegistry.YELLOW: {
		0x667F: "juggler", 0x6685: "blackbelt", 0x668B: "giovanni",
		0x6691: "cooltrainer_m", 0x6697: "cooltrainer_f", 0x66AA: "brock",
		0x66B2: "misty", 0x66B8: "lt_surge", 0x66BE: "erika", 0x66CA: "koga_yellow",
		0x66D0: "blaine_yellow", 0x66DC: "sabrina_yellow", 0x66E2: "rival2",
		0x66EE: "rival3", 0x66FA: "lorelei", 0x6706: "bruno", 0x670C: "agatha",
		0x671D: "lance", 0x6729: "generic",
	},
}
## `LoneMoves`, `TeamMoves` and `.ChampionRival`, Red and Blue's own.
const LONE_MOVE_COUNT: int = 8
const LONE_MOVE_SIZE: int = 2
const TEAM_MOVE_END: int = 0xFF
## `wEnemyMon1Moves + 2`: every table move lands in the third slot.
const SPECIAL_MOVE_SLOT: int = 3
const TEAM_MOVE_MEMBER: int = 5
const CHAMPION_BIRD_MEMBER: int = 1
const CHAMPION_STARTER_MEMBER: int = 6
## `.ChampionRival`'s `cp STARTER3` and `cp STARTER1`, Squirtle's line the rest.
const CHAMPION_STARTER_MOVES: Array = [
	{"species": 0x99, "move": 0x48}, {"species": 0xB0, "move": 0x7E},
	{"species": 0, "move": 0x3B},
]
const CHAMPION_BIRD_MOVE: int = 0x8F
const RIVAL3_CLASS: int = 0x2B

## Sides in tiles: `_LoadTrainerPic`'s `ld a, $77`, the widest front pic, and
## every back pic, which `ScaleSpriteByTwo` doubles before a battle draws it.
const TRAINER_PIC_TILES: int = 7
const FRONTPIC_MAX_TILES: int = 7
const BACKPIC_TILES: int = 4

## `LoadPlayerBackPic`'s three in atlas slot order; Red and Blue have no Prof. Oak.
const PLAYER_BACKPICS: Array[String] = ["player", "old_man", "prof_oak"]

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
	"key_item_flags": 0x0E799,
	"usable_items_party": 0x13434,
	"usable_items_close": 0x13459,
	"item_use_text": 0x0E5C0,
	"coin_case_text": 0x0E247,
	"party_menu_text": 0x12E7F,
	"toss_text": 0x0E755,
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
	"trainer_move_choices": 0x3989B,
	"trainer_ai_pointers": 0x3A55C,
	"trainer_ai_text": 0x3A781,
	"lone_moves": 0x39D22,
	"team_moves": 0x39D32,
	## What a trainer header is read through, and what one of its texts may be.
	"talk_to_trainer": 0x31CC,
	"print_text": 0x3C49,
	"event_flags": 0xD747,
	"status_flags_4": 0xD72E,
	"status_flags_1": 0xD728,
	## The rest of what `decode_script` reads; a row calling anything else is not.
	"text_script_end": 0x24D7,
	"yes_no_choice": 0x35EC,
	"disable_waiting": 0x30B6,
	"play_cry": 0x13D0,
	"display_pokedex": 0x0349B,
	"give_pokemon": 0x03E48,
	"wait_for_sound": 0x3748,
	"random": 0x3E5C,
	"wait_for_button": 0x3865,
	"auto_textbox_on": 0x3C3C,
	"auto_textbox_off": 0x3C3F,
	"give_item": 0x3E2E,
	"is_item_in_bag": 0x3493,
	"bankswitch": 0x35D6,
	## `HasEnoughMoney` against `hMoney`, `SubBCDPredef` off `wPlayerMoney` and
	## the `MONEY_BOX` `DisplayTextBoxID` draws.
	"has_enough_money": 0x35A6,
	"display_text_box": 0x30E8,
	"text_box_id": 0xD125,
	"money_hram": 0xFF9F,
	"player_money": 0xD347,
	"sub_bcd": 0x0F836,
	"has_enough_coins": 0x35B1,
	"player_coins": 0xD5A4,
	"add_bcd": 0x0F81D,
	"coin_box": 0x48F1E,
	"remove_item": 0x7F37,
	"remove_item_bank": 0x05,
	"do_not_wait": 0xCC3C,
	"current_menu_item": 0xCC26,
	## The menu a script draws itself, over `GetQuantityOfItemInBag`'s own list.
	"text_box_border": 0x1922,
	"place_string": 0x1955,
	"handle_menu_input": 0x3ABE,
	"add_n_times": 0x3A87,
	"filtered_bag_items": 0xCC5B,
	"filtered_bag_count": 0xCD37,
	"name_buffer": 0xCD6D,
	"string_buffer": 0xCF4B,
	## `NameRatersHouseNameRaterText`'s four routines, `wBuffer` and `wNameBuffer`.
	"display_party_menu": 0x13FC,
	"get_party_mon_name": 0x15B4,
	"gb_pal_white_out_delay": 0x3DD4,
	"restore_screen_tiles": 0x3DBE,
	"load_gb_pal": 0x20BA,
	"name_rater_check_ot": 0x1DA20,
	"name_rater_screen": 0x655C,
	"party_menu_type": 0xD07D,
	"entry_buffer": 0xCEE9,
	"copy_to_string_buffer": 0x3826,
	"display_dex_rating": 0x44169,
	## `wFossilItem` and `wFossilMon`, written one visit and read the next.
	"fossil_item": 0xD70F,
	"fossil_mon": 0xD710,
	"max_menu_item": 0xCC28,
	"top_menu_item_y": 0xCC24,
	"top_menu_item_x": 0xCC25,
	"menu_watched_keys": 0xCC29,
	"last_menu_item": 0xCC2A,
	"menu_item_to_swap": 0xCC35,
	"display_list_menu": 0x2BE6,
	"list_menu_id": 0xCF94,
	"list_pointer": 0xCF8B,
	"item_list": 0xCF7B,
	"print_item_prices": 0xCF93,
	"cur_item": 0xCF91,
	"bag_items": 0xD31E,
	"remove_item_from_inventory": 0x2BBB,
	"item_to_remove": 0xFFDB,
	"toggleable_index": 0xCC4D,
	"toggleable_list": 0xD5CE,
	"cur_party_species": 0xCF91,
	"cur_map_script": 0xDA39,
	"map_scripts": 0xD5F0,
	## The per-frame half's own dispatch: `hl` is the table for one and `de` is
	## for the other, which takes the trainer header in `hl` instead.
	"call_function_in_table": 0x3D97,
	"execute_map_script": 0x3160,
	"delay_frames": 0x3739,
	"delay_3": 0x3DD7,
	"play_default_music": 0x2307,
	"check_map_trainers": 0x3219,
	"player_coords_in_array": 0x34BF,
	"start_trainer_battle": 0x324C,
	"end_trainer_battle": 0x3275,
	"joy_ignore": 0xCD6B,
	"update_sprites_enabled": 0xCFCB,
	"obtained_badges": 0xD356,
	"sprite_state_data": 0xC100,
	## `ReplaceTileBlock` writes `wNewTileBlockID` at the block `bc` names, and
	## `SilphCoMapList` is the ten floors `PrintCardKeyText` answers on.
	"map_script_flags": 0xD126,
	"options": 0xD355,
	"new_tile_block": 0xD09F,
	"replace_tile_block": 0x0EE9E,
	"card_key_door": 0xD73F,
	"unlocked_silph_doors": 0xFFE0,
	"first_lock_trash_can": 0xD743,
	"silph_map_list": 0x526E3,
	## `DaycareGentlemanText` and the head of its own stub run.
	"day_care_script": 0x56254,
	"day_care_text": 0x5640F,
	## `DoInGameTradeDialogue`, the trade table it indexes with `wWhichTrade`,
	## `InGameTradeTextPointers` and the pair of boxes the swap itself prints.
	"in_game_trade": 0x71AD9,
	"which_trade": 0xCD3D,
	"trade_mons": 0x71B7B,
	"trade_text_pointers": 0x71D64,
	"trade_ot_name": 0x71D59,
	"npc_trade_cable_text": 0x71D88,
	## `Predef` and the table it indexes, with the three rows read through it.
	"predef": 0x3E6D,
	"predef_pointers": 0x4FE79,
	"load_item_list": 0x02A5A,
	"elevator_floor_menu": 0x1C9C6,
	"poke_flute_ch5": 0x6322,
	"poke_flute_ch6": 0x6325,
	"poke_flute_ch7": 0x449B,
	"hide_object": 0x0F1D7,
	"show_object": 0x0F1C8,
	"pick_up_item": 0x04DE1,
	"found_item_text": 0x04E26,
	"toggleable_pointers": 0x0C8F5,
	"toggleable_states": 0x0CAEA,
	## `DisplayPokemartDialogue`'s own greeting and the head of the two facility
	## text runs [constant MART_TEXT_AT] and its neighbour walk. Every offset
	## here is `pokered.sym`'s, which builds both dumps.
	"mart_greeting": 0x02A55,
	"elevator_text": 0x89DAD,
	"mart_text": 0x06E0C,
	"pokecenter_text": 0x0705D,
	"cable_club_text": 0x072B3,
	"vending_text": 0x74F99,
	"pc_text": 0x17F23,
	"players_pc_text": 0x07B22,
	"bills_pc_text": 0x217E9,
	"bills_pc_release_text": 0x2181B,
	"oaks_pc_text": 0x1E93B,
	"hof_pc_text": 0x76683,
	## `DexSeenOwnedText`, then the credits' four tables and the copyright run.
	"hof_dex_text": 0x703FA,
	"credits_mons": 0x74131,
	"credits_order": 0x74243,
	"credits_text_pointers": 0x742C3,
	"credits_the_end": 0x7473E,
	"copyright_tiles": 0x120C8,
	"copyright_text": 0x04556,
	"splash_falling_star": 0x70190,
	"splash_logo_tiles": 0x41959,
	"splash_small_star_oam": 0x700EE,
	"splash_small_star_waves": 0x700F2,
	"splash_logo_oam": 0x70140,
	"splash_shooting_star_oam": 0x70180,
	"intro_back_mon": 0x41A99,
	"intro_front_mon": 0x42099,
	"intro_nidorino_anims": 0x41910,
	"tile_id_lists": 0x79AEA,
	"title_logo_tiles": 0x11380,
	"title_version_tiles": 0x6802F,
	"title_player_tiles": 0x126A8,
	"title_mons": 0x04588,
	"title_version_text": 0x045A1,
	"pal_packet_title": 0x72488,
	"pal_packet_intro": 0x724B8,
	"pal_packet_splash": 0x724C8,
	"pal_packet_generic": 0x724A8,
	"blk_packet_title": 0x7228E,
	"blk_packet_intro": 0x722C1,
	"blk_packet_splash": 0x723DD,
	"change_box_text": 0x73909,
	"choose_box_text": 0x739D4,
	"dex_ratings": 0x441D1,
	"prize_text": 0x5277E,
	"prize_text_2": 0x52960,
	"prize_menus": 0x52843,
	"prize_mon_levels": 0x5298A,
	"font": 0x11A80,
	"text_box": 0x12288,
	"pokedex_tiles": 0x12488,
	## The region map's own sheet, its run-length screen, the three object tiles
	## and the twelve `BirdSprite` frames the fly map draws instead of a cursor.
	"world_map_tiles": 0x125A8,
	"town_map_rle": 0x71100,
	"town_map_order": 0x70F11,
	"town_map_cursor": 0x70F40,
	"town_map_nest": 0x716BE,
	"town_map_arrow": 0x71093,
	"town_map_bird": 0x14D80,
	"external_map_entries": 0x71313,
	"internal_map_entries": 0x71382,
	"town_visited": 0xD70B,
	"display_town_map": 0x70E3E,
	"display_diploma": 0x566E2,
	"town_map_text": 0x0FC12,
	## `RemoveGuardDrink`, whose own `ld hl` names `GuardDrinksList`.
	"remove_guard_drink": 0x5A59F,
	## `DecodeArrowMovementRLE` and the byte `BIT_SPINNING` sits in.
	"decode_arrow_movement": 0x3442,
	"movement_flags": 0xD736,
	"status_flags_7": 0xD733,
	## The two bytes a state body reads that nothing here writes.
	"trainer_header_flag_bit": 0xCC55,
	"opponent_after_wrong_answer": 0xDA38,
	## The pair `OverworldLoop` starts a scripted wild battle off.
	"cur_opponent": 0xD059,
	"cur_enemy_level": 0xD127,
	"is_in_battle": 0xD057,
	"battle_result": 0xCF0B,
	## `wSavedCoordIndex`, whose HRAM twin is `item_to_remove`'s own byte.
	"saved_coord_index": 0xCF0D,
	"fly_warps": 0x06448,
	"new_game_warp": 0x06420,
	"intro_text": 0x06253,
	"intro_name_text": 0x0699F,
	"default_names_player": 0x06AA8,
	"default_names_rival": 0x06ABE,
	"intro_alphabet": 0x0679E,
	"intro_ed_tile": 0x06767,
	## `LoadSpecialWarpData` and `ItemUseEscapeRope`: the dungeon warp tables, the
	## tilesets a rope may be pulled on and the rest houses that record no map.
	"dungeon_warps": 0x063BF,
	"escape_rope_tilesets": 0x0DFFD,
	"rest_houses": 0x07092,
	"which_dungeon_warp": 0xD71E,
	"dungeon_warp_destination": 0xD71D,
	## `IsBikeRidingAllowed`'s tileset list, `CheckForceBikeOrSurf`'s coordinate
	## list and the byte the gate scripts clear a forced ride in.
	"bike_riding_tilesets": 0x009E2,
	"forced_bike_surf": 0x0C3E6,
	"status_flags_6": 0xD732,
	## `Route12SnorlaxFluteCoords` with `Route16SnorlaxFluteCoords` behind it,
	## and the three boxes `ItemUsePokeFlute` prints from behind both.
	"snorlax_flute_coords": 0x0E1FD,
	"poke_flute_text": 0x0E20B,
	"bicycle_text": 0x0E5F2,
	"start_menu_text": 0x1342F,
	"field_move_text": 0xA40A9,
	"strength_text": 0xA403C,
	"cut_text": 0xA82F8,
	"surf_text": 0xA685E,
	"cut_tree_blocks": 0x0F100,
	"pc_met_bill": 0x17EEC,
	"battle_font": 0x11EA0,
	"battle_hud_1": 0x12080,
	"battle_hud_2": 0x12098,
	"pic_player_back": 0x33E0A,
	"pic_old_man_back": 0x33E9A,
	"pic_player_front": 0x12EDE,
	"pic_shrink_1": 0x12FE8,
	"pic_shrink_2": 0x13042,
	"trainer_card_box": 0x2FB98,
	"trainer_card_names": 0x2FC28,
	"badge_numbers": 0x2FD98,
	"badge_faces": 0x0EA9E,
	"map_headers": 0x001AE,
	"map_header_banks": 0x0C23D,
	"map_songs": 0x0C04D,
	"tilesets": 0x0C7BE,
	"water_tilesets": 0x0E8E0,
	"overworld_sprites": 0x17B27,
	"mon_icons": 0x717C0,
	"mon_icon_species": 0x7190D,
	"heal_machine_gfx": 0x704B7,
	"ball_tiles": 0x3A97E,
	"stats_p": 0x12ADC,
	"shock_emote_gfx": 0x17CBD,
	"emote_sheets": 3,
	"wild_data": 0x0CEEB,
	"wild_chances": 0x13918,
	"good_rod": 0x0E27F,
	"old_rod": 0x0E252,
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
	## `CheckForHiddenEventOrBookshelfOrCardKeyDoor`: the hidden events per map,
	## the two coordinate lists, the bookshelf tiles and `TextPredefs`.
	"hidden_event_maps": 0x46A40,
	"hidden_event_pointers": 0x46A96,
	"hidden_item_coords": 0x766B8,
	"hidden_coin_coords": 0x76822,
	"bookshelf_tiles": 0x0FB8B,
	"text_predefs": 0x03F22,
	"map_badge_flags": 0x62442,
	"bench_guy_texts": 0x6247E,
	## The four table routines, by full ROM offset the way
	## [constant SCRIPT_BANKED_CALLS] names one.
	"hidden_items": 0x76688,
	"hidden_coins": 0x76799,
	"bench_guy_text": 0x6245D,
	"gym_statues": 0x62419,
	"gym_trash": 0x5DDFC,
	"gym_trash_cans": 0x5DE7D,
	"print_predef_text": 0x3EF5,
	"display_text_id": 0x2920,
	"count_set_bits": 0x2B7F,
	"load_gym_names": 0x317F,
	"text_id_hram": 0xFF8C,
	"facing_direction": 0xC109,
	"joy_held": 0xFFB4,
	"auto_text_box_control": 0xCF0C,
	"tile_map": 0xC3A0,
	"cur_map_tileset": 0xD367,
	"num_set_bits": 0xD11E,
	"player_y": 0xD361,
	"player_x": 0xD362,
	## `StartSimulatingJoypadStates` and its buffer: one entry per walking step.
	"update_sprites": 0x2429,
	"play_sound": 0x23B1,
	"play_sound_wait": 0x3740,
	"start_simulating_joypad": 0x3486,
	"simulated_joypad_index": 0xCD38,
	"simulated_joypad_end": 0xCCD3,
	## `hSpriteFacingDirection`, above `hSpriteIndex` at `hTextID`'s own byte.
	"sprite_facing_hram": 0xFF8D,
	"joy_pressed": 0xFFB3,
	"new_sound_id": 0xC0EE,
	"audio_rom_bank": 0xC0EF,
	"audio_saved_rom_bank": 0xC0F0,
	"status_flags_5": 0xD730,
	"last_map": 0xD365,
	"last_blackout_map": 0xD719,
	"serial_connect": 0x22FA,
	"check_boulder_coords": 0x34E4,
	"get_item_quantity": 0x0F8A5,
	"update_gym_gates": 0x3EAD,
	"update_gym_gates_far": 0x1EB0A,
	"gym_gate_coords": 0x1EB48,
	"sprite_pointer_1": 0x34FC,
	"sprite_pointer_2": 0x3500,
	"fill_memory": 0x36E0,
	"misc_flags": 0xCD60,
	"status_flags_3": 0xD72D,
	"elite_4_flags": 0xD734,
	"walk_bike_surf_state": 0xD700,
	"walk_bike_surf_state_copy": 0xD11A,
	"force_bike_or_surf": 0x12ED,
	"warp_destination_map": 0xFF8B,
	"destination_warp_id": 0xD42F,
	"emotion_bubble_sprite": 0xCD4F,
	"which_emotion_bubble": 0xCD50,
	"emotion_bubble": 0x17C47,
	"find_path_to_player": 0x0F8BA,
	"calc_player_relative": 0x0F929,
	"npc_relative_perspective": 0xFF9B,
	"npc_sprite_offset": 0xFF95,
	"npc_movement_directions": 0xCC5B,
	"npc_movement_directions_2": 0xCC97,
	"npc_num_scripted_steps": 0xCF0F,
	"saved_npc_movement_index": 0xD157,
	"delay_frame": 0x20AF,
	"npc_movement_table": 0xCC57,
	"npc_movement_function": 0xCF10,
	"npc_movement_bank": 0xCC58,
	"sprite_index_wram": 0xCF13,
	"trainer_no": 0xD05D,
	"save_end_battle_text": 0x3354,
	"engage_map_trainer": 0x336A,
	"init_battle_enemy": 0x32D7,
	"battle_type": 0xD05A,
	"list_scroll_offset": 0xCC36,
	"sprite_screen_y": 0xFFEB,
	"sprite_screen_x": 0xFFEC,
	"sprite_map_y": 0xFFED,
	"sprite_map_x": 0xFFEE,
	"set_sprite_position": 0x32F9,
	"set_sprite_position_2": 0x32FE,
	"set_sprite_image": 0x34B9,
	"get_sprite_position": 0x32EF,
	"cur_map_text_ptr": 0xD36C,
	"hall_of_fame_pc": 0x7405C,
	"is_player_on_dungeon_warp": 0x46981,
	"load_spinner_arrow_tiles": 0x44FD7,
	"pewter_guys": 0x37CA1,
	"convert_npc_directions": 0x0F9A0,
	"heal_party": 0x0F6A5,
	"save_game_data": 0x73848,
	"rival_starter": 0xD715,
	"player_starter": 0xD717,
	"object_to_hide": 0xD079,
	"object_to_show": 0xD07A,
	"route23_default_script": 0x51219,
	## `VermilionDockSSAnneLeavesScript`, a movie the walker is not asked to read.
	"ss_anne_leaves": 0x1DB9B,
	"route23_badge_texts": 0x51276,
	"fade_out_white": 0x20D8,
	"fade_in_white": 0x20F6,
	"fade_out_black": 0x20EF,
	"fade_in_black": 0x20D1,
	"init": 0x1F54,
	"letter_printing_delay": 0xD358,
	"player_movement_byte_1": 0xC206,
	"override_joypad_mask": 0xCD3B,
	"num_safari_balls": 0xDA47,
	"safari_game_over": 0xDA46,
	"safari_steps": 0xD70D,
	"safari_battle_text": 0x042A7,
	"safari_game_over_text": 0x1EA0D,
	"safari_item_text": 0x0DFA5,
	"safari_steps_labels": 0x0C579,
	"safari_battle_menu_text": 0x07468,
	"safari_out_of_balls_text": 0x89639,
	"rle_pallet_player": 0x1A4E9,
	"flag_action": 0x0F666,
	"route23_copy_badge_text": 0x5125D,
	"add_party_mon": 0x3927,
	"mon_data_location": 0xCC49,
	"party_mon_1_catch_rate": 0xD172,
	"beat_gym_flags": 0xD72A,
	"gym_leader_no": 0xD05C,
	"random_add": 0xFFD3,
	"random_sub": 0xFFD4,
	"lucky_slot_index": 0xCD05,
	"oaks_aide_reward": 0xFFDC,
	"get_item_name": 0x2FCF,
	"get_mon_name": 0x2F9E,
	"get_sprite_position_2": 0x32F4,
	"save_screen_1": 0x3719,
	"load_screen_1": 0x3725,
	"save_screen_2": 0x36F4,
	"reload_map_data": 0x3071,
	"copy_data": 0x00B5,
	"oaks_aide": 0x59035,
	"oaks_aide_text": 0x59091,
	"starter_dex": 0x5C0DC,
	"joy_released": 0xFFB2,
	"rival_starter_ball": 0xCD3E,
	"jigglypuff_text": 0x5C59B,
	"channel_sound_ids": 0xC026,
	"rle_pallet_object": 0x1A4DC,
	"rle_museum_player": 0x1A559,
	"rle_museum_object": 0x1A562,
	"rle_gym_player": 0x1A5CD,
	"rle_gym_object": 0x1A5DA,
	"player_moving_direction": 0xD528,
	"play_music": 0x23A1,
	## `Music_RivalAlternateStart` and the three beside it, in bank $02.
	"music_rival_start": 0x9B47,
	"music_rival_tempo": 0x9B65,
	"music_rival_start_tempo": 0x9B75,
	"music_cities1_tempo": 0x9B81,
	"set_sprite_facing": 0x34AE,
	"set_sprite_facing_delay": 0x34A6,
	"sprite_stay": 0x3541,
	"move_sprite": 0x363A,
	"decode_rle": 0x350C,
	"obtained_hidden_items": 0xD6F0,
	"obtained_hidden_coins": 0xD6FE,
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
	"key_item_flags": 0x0E6DD,
	"usable_items_party": 0x11FDE,
	"usable_items_close": 0x12003,
	"item_use_text": 0x0E4FF,
	"coin_case_text": 0x0E0F4,
	"party_menu_text": 0x11A38,
	"toss_text": 0x0E699,
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
	"trainer_move_choices": 0x3981E,
	"trainer_ai_pointers": 0x3A5F2,
	"trainer_ai_text": 0x3A817,
	"special_trainer_moves": 0x39C6B,
	"talk_to_trainer": 0x3168,
	"print_text": 0x3C36,
	"event_flags": 0xD746,
	"status_flags_4": 0xD72D,
	"status_flags_1": 0xD727,
	"text_script_end": 0x23D2,
	"yes_no_choice": 0x35EF,
	"disable_waiting": 0x2FDE,
	"play_cry": 0x118B,
	"display_pokedex": 0x0347D,
	"give_pokemon": 0x03E59,
	"wait_for_sound": 0x373E,
	"random": 0x3E6D,
	"wait_for_button": 0x3852,
	"auto_textbox_on": 0x3C29,
	"auto_textbox_off": 0x3C2C,
	"give_item": 0x3E3F,
	"is_item_in_bag": 0x3422,
	"bankswitch": 0x3E84,
	"has_enough_money": 0x35C3,
	"display_text_box": 0x3010,
	"text_box_id": 0xD124,
	"money_hram": 0xFF9F,
	"player_money": 0xD346,
	"sub_bcd": 0x0F6BC,
	"has_enough_coins": 0x35CE,
	"player_coins": 0xD5A3,
	"add_bcd": 0x0F6A3,
	"coin_box": 0x48F42,
	"remove_item": 0x7DBB,
	"remove_item_bank": 0x05,
	"do_not_wait": 0xCC3C,
	"current_menu_item": 0xCC26,
	"text_box_border": 0x16F0,
	"place_string": 0x1723,
	"handle_menu_input": 0x3AAB,
	"add_n_times": 0x3A74,
	"filtered_bag_items": 0xCC5B,
	"filtered_bag_count": 0xCD37,
	"name_buffer": 0xCD6D,
	"string_buffer": 0xCF4A,
	"display_party_menu": 0x11C8,
	"get_party_mon_name": 0x1394,
	"gb_pal_white_out_delay": 0x3DD8,
	"restore_screen_tiles": 0x3DC2,
	"load_gb_pal": 0x1E6F,
	"name_rater_check_ot": 0x1D328,
	"name_rater_screen": 0x62CD,
	"party_menu_type": 0xD07C,
	"entry_buffer": 0xCEE9,
	"copy_to_string_buffer": 0x3813,
	"display_dex_rating": 0x44169,
	"fossil_item": 0xD70E,
	"fossil_mon": 0xD70F,
	"max_menu_item": 0xCC28,
	"top_menu_item_y": 0xCC24,
	"top_menu_item_x": 0xCC25,
	"menu_watched_keys": 0xCC29,
	"last_menu_item": 0xCC2A,
	"menu_item_to_swap": 0xCC35,
	"display_list_menu": 0x2AE0,
	"list_menu_id": 0xCF93,
	"list_pointer": 0xCF8A,
	"item_list": 0xCF7A,
	"print_item_prices": 0xCF92,
	"cur_item": 0xCF90,
	"bag_items": 0xD31D,
	"remove_item_from_inventory": 0x2ABD,
	"item_to_remove": 0xFFDB,
	"toggleable_index": 0xCC4D,
	"toggleable_list": 0xD5CD,
	"cur_party_species": 0xCF90,
	"cur_map_script": 0xDA38,
	"map_scripts": 0xD5EF,
	"call_function_in_table": 0x3D93,
	"execute_map_script": 0x30FC,
	"delay_frames": 0x372F,
	"delay_3": 0x3DDB,
	"play_default_music": 0x216B,
	"check_map_trainers": 0x31B5,
	"player_coords_in_array": 0x34BC,
	"start_trainer_battle": 0x31E8,
	"end_trainer_battle": 0x3211,
	"joy_ignore": 0xCD6B,
	"update_sprites_enabled": 0xCFCA,
	"obtained_badges": 0xD355,
	"sprite_state_data": 0xC100,
	"map_script_flags": 0xD125,
	"options": 0xD354,
	"new_tile_block": 0xD09E,
	"replace_tile_block": 0x0ED1B,
	"card_key_door": 0xD73E,
	"unlocked_silph_doors": 0xFFE0,
	"first_lock_trash_can": 0xD742,
	"silph_map_list": 0x52645,
	"day_care_script": 0x56244,
	"day_care_text": 0x56441,
	"in_game_trade": 0x71B86,
	"which_trade": 0xCD3D,
	"trade_mons": 0x71C1D,
	"trade_text_pointers": 0x71E38,
	"trade_ot_name": 0x71E2D,
	"npc_trade_cable_text": 0x71E5C,
	"predef": 0x3EB4,
	"predef_pointers": 0xF681D,
	"load_item_list": 0x0293D,
	"elevator_floor_menu": 0x1C264,
	"poke_flute_ch5": 0x59EB,
	"poke_flute_ch6": 0x59EE,
	"poke_flute_ch7": 0x444B,
	"hide_object": 0x0F053,
	"show_object": 0x0F044,
	"pick_up_item": 0x04D55,
	"found_item_text": 0x04D9A,
	"toggleable_pointers": 0x0C69B,
	"toggleable_states": 0x0C892,
	"mart_greeting": 0x02938,
	"elevator_text": 0xA0100,
	"mart_text": 0x06B91,
	"pokecenter_text": 0x06ED0,
	"cable_club_text": 0x07188,
	"vending_text": 0x747DE,
	"pc_text": 0x17DA7,
	"players_pc_text": 0x079C9,
	"bills_pc_text": 0x21826,
	"bills_pc_release_text": 0x2185D,
	"oaks_pc_text": 0x1E2D4,
	"hof_pc_text": 0x75F02,
	"hof_dex_text": 0x70452,
	"credits_mons": 0xF1028,
	"credits_order": 0xF1171,
	"credits_text_pointers": 0xF11E3,
	"credits_the_end": 0xF181B,
	"copyright_tiles": 0x10C48,
	"copyright_text": 0x04355,
	"splash_falling_star": 0x701B6,
	"splash_logo_tiles": 0x41AA6,
	"splash_small_star_oam": 0x70101,
	"splash_small_star_waves": 0x70105,
	"splash_logo_oam": 0x70166,
	"splash_shooting_star_oam": 0x701A6,
	"tile_id_lists": 0x79C46,
	"title_logo_tiles": 0xF46FB,
	"title_logo_corner": 0xF4E2B,
	"title_pikachu_bg": 0xF4E5B,
	"title_pikachu_ob": 0xF525B,
	"title_nine_tile": 0x10E08,
	"title_logo_tilemap": 0xF45F9,
	"title_bubble_tilemap": 0xF4673,
	"title_pikachu_tilemap": 0xF468F,
	"title_eyes_oam": 0xF45C7,
	"yellow_intro_gfx_1": 0xFA35A,
	"yellow_intro_gfx_2": 0xFAB5A,
	"yellow_intro_clouds": 0xF9C2C,
	"yellow_intro_tilemap_1": 0xF9B6E,
	"yellow_intro_tilemap_2": 0xF9BE6,
	"yellow_intro_tilemap_3": 0xF9BF2,
	"yellow_intro_speed_bars": 0xF99F0,
	"yellow_intro_pal_flash": 0xF9DD6,
	"yellow_intro_pal_fade": 0xF9E0A,
	"yellow_intro_spawn_states": 0xF9FDA,
	"yellow_intro_frames": 0xFA0EA,
	"yellow_intro_oam": 0xFA13D,
	"yellow_intro_sine": 0xF9ED8,
	"yellow_intro_sine_words": 0xFA0AA,
	"pal_packet_title": 0x727C1,
	"pal_packet_intro": 0x727F1,
	"pal_packet_splash": 0x72801,
	"pal_packet_generic": 0x727E1,
	"pal_packet_beach": 0x72811,
	"blk_packet_title": 0x72681,
	"blk_packet_intro": 0x726A1,
	"blk_packet_splash": 0x72731,
	"change_box_text": 0x73C52,
	"choose_box_text": 0x73D10,
	"dex_ratings": 0x441D1,
	"prize_text": 0x526DF,
	"prize_text_2": 0x528C0,
	"prize_menus": 0x527AE,
	"prize_mon_levels": 0x528EA,
	"font": 0x10600,
	"text_box": 0x10E18,
	"pokedex_tiles": 0x11018,
	"world_map_tiles": 0x11138,
	"town_map_rle": 0x7118A,
	"town_map_order": 0x70F95,
	"town_map_cursor": 0x70FC4,
	"town_map_nest": 0x7174B,
	"town_map_arrow": 0x7111E,
	"town_map_bird": 0x15171,
	"external_map_entries": 0x7139C,
	"internal_map_entries": 0x7140B,
	"town_visited": 0xD70A,
	"display_town_map": 0x70EB4,
	"display_diploma": 0x56714,
	"town_map_text": 0x0FAA0,
	"remove_guard_drink": 0x5A53A,
	"decode_arrow_movement": 0x33D1,
	"movement_flags": 0xD735,
	"status_flags_7": 0xD732,
	"trainer_header_flag_bit": 0xCC55,
	"opponent_after_wrong_answer": 0xDA37,
	"cur_opponent": 0xD058,
	"cur_enemy_level": 0xD126,
	"is_in_battle": 0xD056,
	"battle_result": 0xCF0B,
	"saved_coord_index": 0xCF0D,
	"fly_warps": 0x061BC,
	"new_game_warp": 0x06194,
	"intro_text": 0x05FB9,
	"intro_name_text": 0x0671D,
	"default_names_player": 0x06827,
	"default_names_rival": 0x06840,
	"intro_alphabet": 0x0651C,
	"intro_ed_tile": 0x064E5,
	"dungeon_warps": 0x06133,
	"escape_rope_tilesets": 0x0DE28,
	"rest_houses": 0x06F0A,
	"which_dungeon_warp": 0xD71D,
	"dungeon_warp_destination": 0xD71C,
	"bike_riding_tilesets": 0x00822,
	"forced_bike_surf": 0x0C12F,
	"status_flags_6": 0xD731,
	"snorlax_flute_coords": 0x0E0AC,
	"poke_flute_text": 0x0E0BA,
	"bicycle_text": 0x0E536,
	"start_menu_text": 0x11FD9,
	"field_move_text": 0xB40A7,
	"strength_text": 0xB417E,
	"cut_text": 0xB7166,
	"surf_text": 0xB6B0E,
	"cut_tree_blocks": 0x0EF80,
	"pc_met_bill": 0x17D70,
	"battle_font": 0x10A20,
	"battle_hud_1": 0x10C00,
	"battle_hud_2": 0x10C18,
	## Yellow moved both back pics out of "Pics 4" and into their own bank.
	"pic_player_back": 0xF43B1,
	"pic_old_man_back": 0xF4441,
	"pic_prof_oak_back": 0xF44D2,
	"pic_player_front": 0x11A97,
	"pic_shrink_1": 0x11B96,
	"pic_shrink_2": 0x11BF0,
	"trainer_card_box": 0xF5C24,
	"trainer_card_names": 0xF5CB4,
	"badge_numbers": 0xF5E24,
	"badge_faces": 0x0E91B,
	"map_headers": 0xFC1F2,
	"map_header_banks": 0xFC3E4,
	"map_songs": 0xFC000,
	"tilesets": 0x0C558,
	"water_tilesets": 0x0E834,
	"overworld_sprites": 0x142A9,
	"mon_icons": 0x7184D,
	"mon_icon_species": 0x719BA,
	"heal_machine_gfx": 0x7050B,
	"ball_tiles": 0x3AA28,
	"stats_p": 0x11682,
	"shock_emote_gfx": 0x411E5,
	"emote_sheets": 8,
	"wild_data": 0x0CB95,
	"wild_chances": 0x138E2,
	"good_rod": 0x0E12C,
	"old_rod": 0x0E0FF,
	## Yellow's is a flat slot table rather than an index into groups.
	"super_rod": 0xF5EDA,
	"attack_anims": 0x7A22A,
	"subanims": 0x7A915,
	"frame_blocks": 0x7B11C,
	"base_coords": 0x7BE2D,
	"special_effects": 0x79145,
	"anim_tilesets": 0x7822B,
	"falling_deltas": 0x79E96,
	## Yellow writes each pointer beside its own map id and keeps no second table.
	"hidden_event_maps": 0xF268D,
	"hidden_event_pointers": 0,
	"hidden_item_coords": 0x75FAA,
	"hidden_coin_coords": 0x7611E,
	"bookshelf_tiles": 0x0FA19,
	"text_predefs": 0x03F67,
	"map_badge_flags": 0x62611,
	"bench_guy_texts": 0x6264D,
	"hidden_items": 0x75F74,
	"hidden_coins": 0x7608E,
	"bench_guy_text": 0x6262C,
	"gym_statues": 0x625E8,
	"gym_trash": 0x5DE60,
	"gym_trash_cans": 0xF2D31,
	"print_predef_text": 0x3F3A,
	"display_text_id": 0x2817,
	"count_set_bits": 0x2A81,
	"load_gym_names": 0x311B,
	"text_id_hram": 0xFF8C,
	"facing_direction": 0xC109,
	"joy_held": 0xFFB4,
	"auto_text_box_control": 0xCF0C,
	"tile_map": 0xC3A0,
	"cur_map_tileset": 0xD366,
	"num_set_bits": 0xD11D,
	"player_y": 0xD360,
	"player_x": 0xD361,
	"update_sprites": 0x231C,
	"play_sound": 0x2238,
	"play_sound_wait": 0x3736,
	"start_simulating_joypad": 0x3415,
	"simulated_joypad_index": 0xCD38,
	"simulated_joypad_end": 0xCCD3,
	"sprite_facing_hram": 0xFF8D,
	"joy_pressed": 0xFFB3,
	"new_sound_id": 0xC0EE,
	"audio_rom_bank": 0xC0EF,
	"audio_saved_rom_bank": 0xC0F0,
	"status_flags_5": 0xD72F,
	"last_map": 0xD364,
	"last_blackout_map": 0xD718,
	"serial_connect": 0x2156,
	"check_boulder_coords": 0x34E1,
	"get_item_quantity": 0x0F735,
	"update_gym_gates": 0x3EF0,
	"update_gym_gates_far": 0x1E4BF,
	"gym_gate_coords": 0x1E503,
	"gym_quiz_flags": 0xD474,
	"sprite_pointer_1": 0x34F9,
	"sprite_pointer_2": 0x34FD,
	"fill_memory": 0x166E,
	"misc_flags": 0xCD60,
	"status_flags_3": 0xD72C,
	"elite_4_flags": 0xD733,
	"walk_bike_surf_state": 0xD6FF,
	"walk_bike_surf_state_copy": 0xD119,
	"force_bike_or_surf": 0x0FD6,
	"warp_destination_map": 0xFF8B,
	"destination_warp_id": 0xD42E,
	"emotion_bubble_sprite": 0xCD4F,
	"which_emotion_bubble": 0xCD50,
	"emotion_bubble": 0x4116F,
	"find_path_to_player": 0x0F74A,
	"calc_player_relative": 0x0F7B9,
	"npc_relative_perspective": 0xFF9B,
	"npc_sprite_offset": 0xFF95,
	"npc_movement_directions": 0xCC5B,
	"npc_movement_directions_2": 0xCC97,
	"npc_num_scripted_steps": 0xCF0F,
	"saved_npc_movement_index": 0xD156,
	"delay_frame": 0x1E64,
	"npc_movement_table": 0xCC57,
	"npc_movement_function": 0xCF10,
	"npc_movement_bank": 0xCC58,
	"sprite_index_wram": 0xCF13,
	"trainer_no": 0xD05C,
	"save_end_battle_text": 0x32F0,
	"engage_map_trainer": 0x3306,
	"init_battle_enemy": 0x3273,
	"battle_type": 0xD059,
	"list_scroll_offset": 0xCC36,
	"sprite_screen_y": 0xFFEB,
	"sprite_screen_x": 0xFFEC,
	"sprite_map_y": 0xFFED,
	"sprite_map_x": 0xFFEE,
	"set_sprite_position": 0x3295,
	"set_sprite_position_2": 0x329A,
	"set_sprite_image": 0x349B,
	"set_sprite_image_2": 0x34A1,
	"get_sprite_position": 0x328B,
	"cur_map_text_ptr": 0xD36B,
	"hall_of_fame_pc": 0xF0F26,
	"is_player_on_dungeon_warp": 0x46BF3,
	"load_spinner_arrow_tiles": 0x45077,
	"pewter_guys": 0x1A6E5,
	"convert_npc_directions": 0x0F830,
	"heal_party": 0x0F52B,
	"save_game_data": 0x73B91,
	"rival_starter": 0xD714,
	"player_starter": 0xD716,
	"object_to_hide": 0xD078,
	"object_to_show": 0xD079,
	"route23_default_script": 0x511D2,
	"ss_anne_leaves": 0x1D4A3,
	"route23_badge_texts": 0x5122F,
	"fade_out_white": 0x1E96,
	"fade_in_white": 0x1EBD,
	"fade_out_black": 0x1EB6,
	"fade_in_black": 0x1E8F,
	"init": 0x1D10,
	"letter_printing_delay": 0xD357,
	"player_movement_byte_1": 0xC206,
	"override_joypad_mask": 0xCD3B,
	"num_safari_balls": 0xDA46,
	"safari_game_over": 0xDA45,
	"safari_steps": 0xD70C,
	"safari_battle_text": 0x04141,
	"safari_game_over_text": 0x1E3A5,
	"safari_item_text": 0x0DDC5,
	"safari_steps_labels": 0x0C2C4,
	"safari_battle_menu_text": 0x0733D,
	"safari_out_of_balls_text": 0x9F511,
	"safari_low_cost": 0xF2077,
	"safari_nag": 0xF20CE,
	"safari_low_cost_text": 0xF20C4,
	"safari_nag_text": 0xF20F6,
	"safari_nag_lines": 0xF2100,
	"rle_pallet_player": 0x1A5FB,
	"flag_action": 0x0F4EC,
	"route23_copy_badge_text": 0x51216,
	"add_party_mon": 0x391C,
	"mon_data_location": 0xCC49,
	"party_mon_1_catch_rate": 0xD171,
	"beat_gym_flags": 0xD729,
	"gym_leader_no": 0xD05B,
	"random_add": 0xFFD3,
	"random_sub": 0xFFD4,
	"lucky_slot_index": 0xCD05,
	"oaks_aide_reward": 0xFFDC,
	"get_item_name": 0x2EC4,
	"get_mon_name": 0x2E93,
	"get_sprite_position_2": 0x3290,
	"save_screen_1": 0x370F,
	"load_screen_1": 0x371B,
	"save_screen_2": 0x36EC,
	"reload_map_data": 0x2F66,
	"copy_data": 0x00B1,
	"oaks_aide": 0x58ECC,
	"oaks_aide_text": 0x58F28,
	"starter_dex": 0x5C0D4,
	"joy_released": 0xFFB2,
	"rival_starter_ball": 0xCD3E,
	"jigglypuff_text": 0x5C498,
	"channel_sound_ids": 0xC026,
	"rle_pallet_object": 0x1A5EE,
	"rle_museum_player": 0x1A661,
	"rle_museum_object": 0x1A66A,
	"rle_gym_player": 0x1A6CB,
	"rle_gym_object": 0x1A6D8,
	"pikachu_map_script_flags": 0xD492,
	"pikachu_spawn_state_flags": 0xD471,
	"pikachu_spawn_state": 0xD430,
	"pikachu_happiness": 0xD46F,
	"schedule_pikachu_spawn": 0xFC4FA,
	"enable_pikachu_drawing": 0x1525,
	"disable_pikachu_drawing": 0x152D,
	"disable_pikachu_following": 0x153A,
	"enable_pikachu_following": 0x1542,
	"check_pikachu_following": 0x154A,
	"is_starter_pikachu_alive": 0xFCDB8,
	"check_pikachu_status": 0xFCE73,
	"play_pikachu_sound_clip": 0xF0000,
	"celadon_granny_thresholds": 0xF1EA2,
	"jigglypuff_tail": 0x5E06,
	"apply_pikachu_movement": 0x159B,
	"try_apply_pikachu_movement": 0xF0A82,
	## `MtMoonB2FScript_ApplyPikachuMovementData` and `CinnabarGymScript_74fa3`,
	## the same gate without the refresh.
	"mt_moon_pikachu_movement": 0x4A325,
	"cinnabar_pikachu_movement": 0x74FA3,
	"pikachu_emotion_table": 0xFD019,
	"pikachu_mood_table": 0xFD99C,
	"pikachu_happiness_table": 0xFD9A6,
	"bills_house_script": 0xD660,
	"pikapic_scripts": 0xFDA5E,
	"pikapic_framesets": 0xFDBC9,
	"pikapic_tilemaps": 0xFDDB8,
	"pikapic_thunderbolt": 0xFE242,
	"pikapic_gfx_headers": 0xFE572,
	"pikachu_cries": 0xF008E,
	"player_moving_direction": 0xD527,
	"play_music": 0x2211,
	"stop_all_music": 0x2233,
	"music_rival_start": 0x99BD,
	"music_rival_tempo": 0x99DB,
	"music_rival_start_tempo": 0x99E7,
	"music_cities1_tempo": 0x99F4,
	"set_sprite_facing": 0x3490,
	"set_sprite_facing_delay": 0x3488,
	"sprite_stay": 0x353E,
	"move_sprite": 0x363D,
	"decode_rle": 0x3509,
	"obtained_hidden_items": 0xD6EF,
	"obtained_hidden_coins": 0xD6FD,
	"tileset_collision_bank": 0x01,
}


## What Blue moves, and by how many bytes. Bank $1D holds the 668 symbols that
## shift: everything in it sits one byte later. `DefaultNamesRival` moves two,
## because the player table in front of it spells BLUE, GARY and JOHN where Red
## spells RED, ASH and JACK.
const BLUE_SHIFT: Dictionary = {
	"default_names_rival": 2,
	"vending_text": 1,
	"hidden_items": 1,
	"hidden_coins": 1,
	"hidden_item_coords": 1,
	"hidden_coin_coords": 1,
	"hof_pc_text": 1,
	"credits_the_end": 1,
}

static var _blue: Dictionary = _shifted_for_blue()


static func _shifted_for_blue() -> Dictionary:
	var layout: Dictionary = RED_BLUE.duplicate()
	for key: String in BLUE_SHIFT:
		layout[key] = int(RED_BLUE[key]) + int(BLUE_SHIFT[key])
	return layout


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


static func trainer_ai_routine(id: StringName, address: int) -> String:
	var routines: Dictionary = TRAINER_AI_ROUTINES.get(
		RomRegistry.YELLOW if id == RomRegistry.YELLOW else RomRegistry.RED, {}
	)
	return String(routines.get(address, ""))


## `TrainerAI`'s `.done` guard on a locked opponent, Yellow's alone.
static func trainer_ai_respects_lock(id: StringName) -> bool:
	return id == RomRegistry.YELLOW


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


## `IsItemHM`, and the TM run that follows the five HMs in the item numbering.
static func is_hm_item(item: int) -> bool:
	return item >= HM_FIRST_ITEM and item < TM_FIRST_ITEM


static func is_tm_item(item: int) -> bool:
	return item >= TM_FIRST_ITEM and item < TM_FIRST_ITEM + TM_COUNT


## `TechnicalMachines`' own one-based row for [param item], or 0. The item
## numbering puts the HMs under the TMs and the table has them the other way up.
static func machine_number(item: int) -> int:
	if is_tm_item(item):
		return item - TM_FIRST_ITEM + 1
	return TM_COUNT + item - HM_FIRST_ITEM + 1 if is_hm_item(item) else 0


## The inverse: the item a one-based `TechnicalMachines` row is carried by.
static func machine_item(number: int) -> int:
	if number >= 1 and number <= TM_COUNT:
		return TM_FIRST_ITEM + number - 1
	if number > TM_COUNT and number <= TM_COUNT + HM_COUNT:
		return HM_FIRST_ITEM + number - TM_COUNT - 1
	return 0


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


## `.inBattle`'s `wWereAnyMonsAsleep`: Yellow's `ld c, a` counts the wild's own
## sleep, where Red and Blue clear it and print `PlayedFluteNoEffectText` anyway.
static func flute_counts_wild(id: StringName) -> bool:
	return id == RomRegistry.YELLOW


static func credits_string_count(id: StringName) -> int:
	return CREDITS_STRINGS_YELLOW if id == RomRegistry.YELLOW else CREDITS_STRINGS_RED_BLUE


static func copyright_tiles(id: StringName) -> int:
	return COPYRIGHT_TILES_YELLOW if id == RomRegistry.YELLOW else COPYRIGHT_TILES_RED_BLUE


static func player_backpics(layout: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for name: String in PLAYER_BACKPICS:
		if layout.has("pic_%s_back" % name):
			out.append(name)
	return out


static func battle_type_values(raw: int) -> Dictionary:
	var row: Dictionary = BATTLE_TYPES.get(raw, {})
	if row.is_empty():
		return {}
	var out: Dictionary = {"battle_type": int(row["battle_type"]), "gen1_battle_type": raw}
	if row.has("tutor"):
		out["tutorial"] = true
		out["can_lose"] = false
	return out


## `.oldManBattle`'s throw.
static func tutorial_ball_lands(id: StringName, raw: int, event_active: Callable) -> bool:
	if raw != BATTLE_TYPE_OLD_MAN or not INITIAL_CATCH_TRAINING_EVENT.has(id):
		return true
	return not bool(event_active.call(int(INITIAL_CATCH_TRAINING_EVENT[id])))


## `CheckIfInOutsideMap`: which maps write `wLastMap` on the way out of them.
static func is_outside_tileset(tileset: int) -> bool:
	return tileset == TILESET_OVERWORLD or tileset == TILESET_PLATEAU


## One of [constant TEXT_PREDEFS]' rows in this cartridge's own numbering.
static func text_predef(id: StringName, name: String) -> int:
	return int((TEXT_PREDEFS_YELLOW if id == RomRegistry.YELLOW else TEXT_PREDEFS)[name])


static func text_predef_count(id: StringName) -> int:
	return TEXT_PREDEF_COUNT_YELLOW if id == RomRegistry.YELLOW else TEXT_PREDEF_COUNT


## What one `HiddenCoins` row pays, off its own argument column.
static func hidden_coin_amount(argument: int) -> int:
	return int(HIDDEN_COIN_AMOUNTS.get(argument - ITEM_COIN, HIDDEN_COIN_DEFAULT))


## The two bytes a script reads that the shared engine flags already hold:
## `wObtainedBadges` and `BIT_ALWAYS_ON_BIKE`. -1 for any other byte or bit.
static func script_flag_alias(layout: Dictionary, address: int, bit: int) -> int:
	if address == int(layout.get("obtained_badges", -1)):
		return Gen2WorldState.gen1_badge_flag(bit)
	if address != int(layout.get("status_flags_6", -1)) or bit != ALWAYS_ON_BIKE_BIT:
		return -1
	return Gen2WorldState.ENGINE_ALWAYS_ON_BIKE


## Whether a test is asking about a walk still being drawn, and whose: a
## `jr nz` behind any of the three is the side that is still waiting.
static func script_battle_outcome(layout: Dictionary, address: int, value: int) -> String:
	for name: String in BATTLE_OUTCOME_SOURCES:
		var row: Array = BATTLE_OUTCOME_SOURCES[name]
		if address == int(layout.get(name, -1)) and value == int(row[0]):
			return String(row[1])
	return ""


static func script_zero_source(layout: Dictionary, address: int) -> bool:
	for name: String in SCRIPT_ZERO_SOURCES:
		if address == int(layout.get(name, -1)):
			return true
	return false


static func script_silent_flag(layout: Dictionary, address: int, bit: int) -> bool:
	for name: String in SCRIPT_SILENT_FLAGS:
		if address == int(layout.get(name, -1)):
			return (int(SCRIPT_SILENT_FLAGS[name]) & (1 << bit)) != 0
	return false


static func script_movement_test(layout: Dictionary, address: int, bit: int) -> String:
	if address == int(layout["simulated_joypad_index"]) and bit < 0:
		return MOVEMENT_TEST_PLAYER
	if address != int(layout.get("status_flags_5", -1)):
		return ""
	if bit == SCRIPTED_NPC_MOVEMENT_BIT:
		return MOVEMENT_TEST_OBJECT
	return MOVEMENT_TEST_PLAYER if bit == SCRIPTED_MOVEMENT_STATE_BIT else ""


## `wPlayerMovingDirection` as the facing it draws, or -1 for zero.
static func player_dir_facing(direction: int) -> int:
	for row: Array in PLAYER_DIR_FACINGS:
		if direction & int(row[0]) != 0:
			return int(row[1])
	return -1


## Which map object's facing byte [param address] is, or -1. Slot 0 is the
## player's, which is walked past instead.
static func sprite_facing_slot(layout: Dictionary, address: int) -> int:
	var base: int = int(layout["sprite_state_data"])
	var offset: int = address - base
	if offset < SPRITE_SLOT_SIZE or offset >= SPRITE_SLOTS * SPRITE_SLOT_SIZE \
		or offset % SPRITE_SLOT_SIZE != SPRITE_FACING_AT:
		return -1
	@warning_ignore("integer_division")
	return offset / SPRITE_SLOT_SIZE - 1


## Where one of [constant ENGINE_FLAG_BYTES]' runs starts, or -1.
static func engine_flag_base(name: String) -> int:
	var index: int = ENGINE_FLAG_FIRST
	for run: String in ENGINE_FLAG_BYTES:
		if run == name:
			return index
		index += int(ENGINE_FLAG_BYTES[run]) * ENGINE_FLAG_BITS
	return -1


## Which table routine stands at [param offset], or "" for machine code.
static func hidden_routine(layout: Dictionary, offset: int) -> String:
	for name: String in HIDDEN_TABLE_ROUTINES:
		if int(layout.get(name, -1)) == offset:
			return name
	return ""


static func is_safari_battle_map(map_id: int) -> bool:
	return map_id >= SAFARI_FIRST_MAP and map_id < SAFARI_BATTLE_END_MAP


static func is_safari_map(map_id: int) -> bool:
	return map_id >= SAFARI_FIRST_MAP and map_id < SAFARI_WINDOW_END_MAP


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


## Which of a frame's four tiles its OAM writer reads.
## `WriteSymmetricMonPartySpriteOAM` reads tiles 0 and 2 and draws each twice,
## X-flipping the second; the helix has no symmetry and reads all four.
static func mon_icon_tiles_read(icon: int) -> Array[int]:
	return [0, 1, 2, 3] if icon == MON_ICON_HELIX else [0, 2]


## Which tile of a frame one quadrant of the 2x2 draws, and whether X-flipped.
static func mon_icon_quadrant(icon: int, quadrant: int) -> Array:
	return [quadrant, false] if icon == MON_ICON_HELIX \
		else [quadrant & 2, quadrant % 2 == 1]


## How many `MonPartySpritePointers` rows `LoadMonPartySpriteGfx` copies.
## Yellow added Pikachu's own icon and its second frame.
static func mon_icon_header_count(id: StringName) -> int:
	return MON_ICON_HEADER_COUNT_YELLOW if id == RomRegistry.YELLOW \
		else MON_ICON_HEADER_COUNT_RED_BLUE


## `FIRST_STILL_SPRITE`, the picture id from which a sheet is four tiles.
static func first_still_sprite(id: StringName) -> int:
	return SPRITE_STILL_FIRST_YELLOW if id == RomRegistry.YELLOW \
		else SPRITE_STILL_FIRST_RED_BLUE


static func sprite_offset(layout: Dictionary, number: int) -> int:
	return int(layout["overworld_sprites"]) + (number - 1) * SPRITE_RECORD_SIZE


## The picture id [constant SPRITE_BIKE_BYTES]' strip is cached under.
static func bike_sprite(id: StringName) -> int:
	return sprite_count(id) + 1


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


## `UsedCut`'s gate, as the tile it writes to `wCutTile` or -1: OVERWORLD takes a
## cut tree or grass, GYM one tile of its own, every other tileset nothing.
static func cut_tile(tileset: int, tile: int) -> int:
	if tileset == TILESET_GYM:
		return tile if tile == CUT_GYM_TREE_TILE else -1
	if tileset != TILESET_OVERWORLD:
		return -1
	return tile if tile == CUT_TREE_TILE or tile == CUT_GRASS_TILE else -1


## `ReplaceTreeTileBlock`'s walk, or -1 for a block the list does not name.
static func cut_block_swap(block: int) -> int:
	return int(CUT_BLOCK_SWAPS.get(block, -1))


## `IsNextTileShoreOrWater`: a tileset off `WaterTilesets` answers no whatever is
## in front, and the dock's own $32 is a landing rather than more sea.
static func is_shore_or_water(tileset: int, water: bool, tile: int) -> bool:
	if not water:
		return false
	if tile == WATER_TILE:
		return true
	return tileset != TILESET_SHIP_PORT and SHORE_TILES.has(tile)


## Where `wStatusFlags1`'s two bits sit in the shared engine flag space.
static func status_flag_1(bit: int) -> int:
	return engine_flag_base("status_flags_1") + bit


## `LoadGBPal`, whose `sub b` counts bytes back from `FadePal4`. An offset past
## either end of the run answers the identity rather than reading nothing.
static func gb_palette(offset: int, register: int) -> int:
	var at: int = FADE_PAL_BASE - offset + register
	if at < 0 or at >= FADE_PALS.size():
		return FADE_PALS[FADE_PAL_BASE]
	return FADE_PALS[at]


## `ItemUseOldRod`'s one pair and `GoodRodMons`' two, as the `{level, species}`
## slots the shared fishing resolution takes.
static func rod_slots(rod: StringName) -> Array:
	if rod == Gen2WorldEncounter.METHOD_OLD_ROD:
		return [{"level": int(OLD_ROD_SLOT[0]), "species": int(OLD_ROD_SLOT[1])}]
	var out: Array = []
	for row: Array in GOOD_ROD_SLOTS:
		out.append({"level": int(row[0]), "species": int(row[2])})
	return out


## Whether the Super Rod is read as Yellow's flat slot table.
## `wRivalStarter` and `wPlayerStarter` hold one of these and nothing else, so
## `Route22GetRivalTrainerNoByStarterScript`'s unterminated table walk stops.
const SCRIPT_STARTERS: Dictionary = {
	RomRegistry.RED: {"rival": [0xB0, 0xB1, 0x99], "player": [0xB0, 0xB1, 0x99]},
	RomRegistry.BLUE: {"rival": [0xB0, 0xB1, 0x99], "player": [0xB0, 0xB1, 0x99]},
	RomRegistry.YELLOW: {"rival": [1, 2, 3], "player": [0x54]},
}


static func script_starters(id: StringName, who: String) -> Array:
	return (SCRIPT_STARTERS.get(id, {}) as Dictionary).get(who, [])


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


## The four copies of the sound driver, as the ROM banks they and their data live
## in. Yellow alone has a fourth; the other three are the same banks on all three
## cartridges, and so is every sound id.
const AUDIO_BANK_ROM: Array[int] = [0x02, 0x08, 0x1F, 0x20]
const AUDIO_BANK_COUNT_RED_BLUE: int = 3
const AUDIO_BANK_COUNT_YELLOW: int = 4
## `MAX_SFX_ID_1` to `_4`: an id above its bank's own is a piece of music, which
## is what makes `PlaySound` clear the four music channels first.
const AUDIO_MAX_SFX_ID: Array[int] = [185, 233, 194, 152]
## `Audio<N>_WavePointers`. Red and Blue keep one per bank at the same address;
## Yellow keeps a single table and every copy of the driver reads it.
const AUDIO_WAVE_POINTERS_RED_BLUE: int = 0x4361
const AUDIO_WAVE_POINTERS_YELLOW: int = 0x5A16
## Where a bank's header table starts, and how many ids the corpus walk finds in
## each: an entry names its own channel count, so the walk steps by it and stops
## where the first channel pointer begins.
const AUDIO_HEADER_TABLE: int = 0x4000
const AUDIO_HEADER_ENTRY_SIZE: int = 3
const AUDIO_RECORD_COUNT_RED_BLUE: Array[int] = [115, 126, 121]
const AUDIO_RECORD_COUNT_YELLOW: Array[int] = [115, 126, 121, 74]
## `CryData`'s first column counts cries rather than sound ids: the id is
## `CRY_SFX_START` plus three times the index, every cry header being three
## channels long.
const AUDIO_CRY_COUNT: int = 38
const AUDIO_CRY_FIRST_ID: int = 20

## `Audio1_HWChannelEnableMasks`, which Yellow alone reads through
## `Audio1_ApplyMonoStereo`: the mono row, then the three earphone rows the SOUND
## option picks between. `wOptions & SOUND_MASK` shifted right once is the offset.
const YELLOW_ENABLE_MASKS: Array[int] = [
	0x11, 0x22, 0x44, 0x88, 0x11, 0x22, 0x44, 0x88,
	0x01, 0x20, 0x44, 0x88, 0x11, 0x22, 0x44, 0x88,
	0x01, 0x20, 0x04, 0x80, 0x01, 0x20, 0x04, 0x80,
	0x01, 0x02, 0x40, 0x80, 0x01, 0x02, 0x40, 0x80,
]
const YELLOW_SOUND_OPTION_MASK: int = 0x30

## The effects a Generation 1 path names directly. `Music_PokeFluteInBattle`
## starts the first and overwrites its three channel pointers at once.
const SFX_CAUGHT_MON: int = 154
const SFX_GO_INSIDE: int = 173
## `AnimateHealingMachine`'s own two, one per ball and one behind the flashes.
const SFX_HEALING_MACHINE: int = 158
const MUSIC_PKMN_HEALED: int = 232
const SFX_GO_OUTSIDE: int = 181

## The one seam every Crystal-numbered effect request reaches: a role spelled as
## Crystal's own number, answered with the Generation 1 sound id that plays it.
## An unlisted number belongs to a screen no Generation 1 cartridge opens.
const SFX_ROLES: Dictionary = {
	0x01: 134, ## SFX_ITEM, which is SFX_Get_Item1_1
	0x02: 154, ## SFX_CAUGHT_MON, the battle bank's own
	0x08: 144, ## SFX_READ_TEXT_2 is SFX_PRESS_AB
	0x0B: 151, ## SFX_POISON is SFX_POISONED
	0x0D: 153, ## SFX_BOOT_PC is SFX_TURN_ON_PC
	0x0E: 154, ## SFX_SHUT_DOWN_PC is SFX_TURN_OFF_PC
	0x0F: 155, ## SFX_CHOOSE_PC_OPTION is SFX_ENTER_PC
	0x13: 173, ## SFX_WARP_TO is SFX_GO_INSIDE
	0x15: 144, ## SFX_CHANGE_DEX_MODE is SFX_PRESS_AB
	0x16: 162, ## SFX_JUMP_OVER_LEDGE is SFX_LEDGE
	0x18: 164, ## SFX_FLY
	0x19: 165, ## SFX_WRONG is SFX_DENIED
	0x1F: 173, ## SFX_ENTER_DOOR is SFX_GO_INSIDE
	0x20: 157, ## SFX_SWITCH_POKEMON is SFX_SWITCH
	0x22: 178, ## SFX_TRANSACTION is SFX_PURCHASE
	0x23: 181, ## SFX_EXIT_BUILDING is SFX_GO_OUTSIDE
	0x24: 180, ## SFX_BUMP is SFX_COLLISION
	0x25: 182, ## SFX_SAVE
	0x28: 145, ## SFX_THROW_BALL is SFX_BALL_TOSS
	0x29: 147, ## SFX_BALL_POOF
	0x2E: 165, ## the move tutor's own SFX_WRONG
	0x5E: 233, ## SFX_SHINE is SFX_TRAINER_APPEARED
	0x62: 157, ## SFX_SWITCH_POCKETS is SFX_SWITCH
	0x8C: 140, ## SFX_EXP_BAR is SFX_TINK
	0xA4: 137, ## SFX_EVOLVED is SFX_GET_ITEM_2
	0xAB: 167, ## SFX_NOT_VERY_EFFECTIVE
	0xAC: 166, ## SFX_DAMAGE
	0xAD: 176, ## SFX_SUPER_EFFECTIVE
	0xB6: 140, ## SFX_HIT_END_OF_EXP_BAR is SFX_TINK
}

## The other half of the seam: a Crystal track number answered with the bank and
## id that play the piece here. `MapSongBanks` carries both bytes itself, so only
## the pieces a screen names by constant are listed.
const MUSIC_ROLES: Dictionary = {
	0x01: [0x1F, 195], ## MUSIC_TITLE is Music_TitleScreen
	0x06: [0x08, 234], ## MUSIC_KANTO_GYM_LEADER_BATTLE
	0x07: [0x08, 237], ## MUSIC_KANTO_TRAINER_BATTLE
	0x08: [0x08, 240], ## MUSIC_KANTO_WILD_BATTLE
	0x0D: [0x02, 232], ## MUSIC_HEAL is Music_PkmnHealed
	0x12: [0x1F, 217], ## MUSIC_GAME_CORNER
	0x13: [0x1F, 210], ## MUSIC_BICYCLE is Music_BikeRiding
	0x14: [0x1F, 202], ## MUSIC_HALL_OF_FAME
	0x21: [0x1F, 214], ## MUSIC_SURF is Music_Surfing
	0x24: [0x1F, 199], ## MUSIC_CREDITS
	0x29: [0x08, 240], ## MUSIC_JOHTO_WILD_BATTLE
	0x2A: [0x08, 237], ## MUSIC_JOHTO_TRAINER_BATTLE
	0x2B: [0x1F, 205], ## MUSIC_ROUTE_30 is Music_OaksLab, the speech's own piece
	0x2E: [0x08, 234], ## MUSIC_JOHTO_GYM_LEADER_BATTLE
	0x2F: [0x08, 243], ## MUSIC_CHAMPION_BATTLE is Music_FinalBattle
	0x30: [0x08, 237], ## MUSIC_RIVAL_BATTLE
	0x31: [0x08, 237], ## MUSIC_ROCKET_BATTLE
	0x4A: [0x08, 240], ## MUSIC_JOHTO_WILD_BATTLE_NIGHT
}

## How many copies of the driver a cartridge ships.
static func audio_bank_count(id: StringName) -> int:
	return AUDIO_BANK_COUNT_YELLOW if id == RomRegistry.YELLOW \
		else AUDIO_BANK_COUNT_RED_BLUE


static func audio_record_counts(id: StringName) -> Array[int]:
	return AUDIO_RECORD_COUNT_YELLOW if id == RomRegistry.YELLOW \
		else AUDIO_RECORD_COUNT_RED_BLUE


## Where the copy of the driver in [param index] reads its wave instruments.
## Yellow's later copies read the first one's table, which is a bank away.
static func audio_wave_pointers(id: StringName, index: int) -> int:
	if id != RomRegistry.YELLOW:
		return AUDIO_WAVE_POINTERS_RED_BLUE
	return AUDIO_WAVE_POINTERS_YELLOW if index == 0 else 0


## The sound id a Crystal-numbered effect plays here, or -1 for a role no
## Generation 1 cartridge has.
static func sfx_role(crystal_number: int) -> int:
	return int(SFX_ROLES.get(crystal_number, -1))


## The bank and id a Crystal-numbered track plays here, or an empty array.
static func music_role(crystal_track: int) -> Array:
	return MUSIC_ROLES.get(crystal_track, [])
