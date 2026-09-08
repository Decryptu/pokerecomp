class_name Gen2OakSpeech
extends RefCounted

## `engine/menus/intro_menu.asm`'s OakSpeech as beats: pic-then-text pairs with
## one branch, `NamePlayer`. Timing, palettes and the cry are the screen's.

## What a beat shows above its text.
enum Pic {
	OAK,
	## `PrepMonFrontpic`, zeroed DVs, on [method intro_species].
	MON,
	PLAYER,
	RIVAL,
}

## How a beat's picture arrives, between `GetSGBLayout` and the `PrintText`.
enum Enter {
	## The beat keeps the picture the one before it drew.
	NONE,
	FRONTPIC,
	## `Intro_WipeInFrontpic`, which the species beat uses instead.
	WIPE,
	MOVE_LEFT,
	FADE_IN_WHITE,
}

const NAME_NONE: String = ""
const NAME_PLAYER: String = "player"
const NAME_RIVAL: String = "rival"

## `constants/trainer_constants.asm`. Gold and Silver ship no ChrisPic, so CAL.
const POKEMON_PROF: int = 0x0A
const CAL: int = 0x0C
const GEN1_PROF_OAK: int = 0x1A
const GEN1_RIVAL1: int = 0x19
## `OakSpeech` is `ld a, MARILL` in pokegold and `ld a, WOOPER` in pokecrystal.
const MARILL: int = 183
const WOOPER: int = 194

## `constants/music_constants.asm`: MUSIC_ROUTE_30.
const MUSIC_ROUTE_30: int = 0x2B

## `ShrinkPlayer`: SFX_ESCAPE_ROPE, then `ld a, 32` into wMusicFade on MUSIC_NONE.
const SHRINK_SFX: int = 0x10
const SHRINK_FADE_FRAMES: int = 32
## Its five `DelayFrames`: the two pictures, the box clear, the sprite, the hold.
const SHRINK_WAITS: Array[int] = [8, 8, 8, 3, 50]
## `hlcoord 6, 5`, below `ShrinkFrame`'s (6,4), so `ClearBox` leaves its top row.
const SHRINK_CLEAR_AT: Vector2i = Vector2i(6, 5)
## `Intro_PlacePlayerSprite`'s four `dbsprite` are one 16x16 icon at y `9 * 8 +
## 4`, x `9 * 8`; hardware OAM counts from (-8, -16).
const SHRINK_SPRITE_AT: Vector2i = Vector2i(64, 60)

const GEN1_SHRINK_WAITS: Array[int] = [4, 4, 20, 50]
const GEN1_SHRINK_FADE_FRAMES: int = 10
const GEN1_SHRINK_SLOTS: Array[int] = [1, 2]

## `home/string.asm`'s InitName substitutes these for a blank entry.
const DEFAULT_MALE: String = "CHRIS"
const DEFAULT_FEMALE: String = "KRIS"


## `DrawIntroPlayerPic` and `HOF_LoadTrainerFrontpic` load the same picture:
## ChrisPic or KrisPic on Crystal, and CAL's own trainer pic on Gold and Silver,
## which ship neither. One seam, so the intro and the Hall of Fame cannot drift.
static func player_cell(data: GameData, female: bool) -> Dictionary:
	if data == null:
		return {}
	if not Gen2WorldState.is_crystal_profile(data):
		return trainer_cell(data, CAL)
	var sheet: String = "intro_player_female" if female else "intro_player_male"
	var strip: PackedByteArray = data.tile_indices(sheet)
	var tile: int = Gen2Font.TILE
	var tiles: int = Gen2Layout.INTRO_PLAYER_PIC_TILES
	if strip.size() < tiles * tile * tile:
		return {}
	var width: int = Gen2Layout.INTRO_PLAYER_PIC_COLUMNS * tile
	var indices := PackedByteArray()
	indices.resize(width * Gen2Layout.INTRO_PLAYER_PIC_ROWS * tile)
	var strip_width: int = tiles * tile
	for row: int in Gen2Layout.INTRO_PLAYER_PIC_ROWS:
		for column: int in Gen2Layout.INTRO_PLAYER_PIC_COLUMNS:
			var source_tile: int = row * Gen2Layout.INTRO_PLAYER_PIC_COLUMNS + column
			for y: int in tile:
				for x: int in tile:
					indices[(row * tile + y) * width + column * tile + x] = \
						strip[y * strip_width + source_tile * tile + x]
	return {"indices": indices, "width": width, "height": width}


## `SCGB_PLAYER_OR_MON_FRONTPIC_PALS` with `wCurPartySpecies` zero.
static func player_palette(data: GameData, female: bool) -> PackedColorArray:
	if data == null:
		return PackedColorArray()
	if not Gen2WorldState.is_crystal_profile(data):
		return data.trainer_palette(CAL)
	return data.card_palette(1 if female else 0)


static func trainer_cell(data: GameData, trainer_class: int) -> Dictionary:
	var pic: Dictionary = data.trainer_pic(trainer_class) if data != null else {}
	if pic.is_empty():
		return {}
	return Gen2PicImage.atlas_cell(
		data.atlas_indices(pic["atlas"]), data.atlas(pic["atlas"]), pic
	)


const GEN2_ORDER: Array = [
	[Pic.OAK, "oak_1", Enter.FRONTPIC, true, NAME_NONE],
	[Pic.MON, "oak_2", Enter.WIPE, false, NAME_NONE],
	[Pic.MON, "oak_4", Enter.NONE, true, NAME_NONE],
	[Pic.OAK, "oak_5", Enter.FRONTPIC, true, NAME_NONE],
	[Pic.PLAYER, "oak_6", Enter.FRONTPIC, false, NAME_PLAYER],
	[Pic.PLAYER, "oak_7", Enter.NONE, false, NAME_NONE],
]

const GEN1_ORDER: Array = [
	[Pic.OAK, "oak_speech_1", Enter.FRONTPIC, true, NAME_NONE],
	[Pic.MON, "oak_speech_2", Enter.MOVE_LEFT, true, NAME_NONE],
	[Pic.PLAYER, "introduce_player", Enter.MOVE_LEFT, false, NAME_PLAYER],
	[Pic.PLAYER, "your_name_is", Enter.NONE, true, NAME_NONE],
	[Pic.RIVAL, "introduce_rival", Enter.FRONTPIC, false, NAME_RIVAL],
	[Pic.RIVAL, "his_name_is", Enter.NONE, true, NAME_NONE],
	[Pic.PLAYER, "oak_speech_3", Enter.FADE_IN_WHITE, false, NAME_NONE],
]

## Source order, each `{ pic, text, key, enter, clears_after }`. `_OakText2` and
## `_OakText4` are two `PrintText` calls over one pic and so two beats, while
## `_OakText3` is a bare promptbutton and is none. `clears_after` is the
## `RotateThreePalettesRight` and `ClearTilemap` behind the text.
static func beats(data: GameData) -> Array:
	if data == null:
		return []
	var order: Array = GEN1_ORDER if is_gen1(data) else GEN2_ORDER
	var out: Array = []
	for row: Array in order:
		var key: String = String(row[1])
		var text: String = data.intro_text(key)
		if text == "":
			return []
		out.append({
			"pic": int(row[0]),
			"text": text,
			"key": key,
			"enter": int(row[2]),
			"clears_after": bool(row[3]),
			"name": String(row[4]),
		})
	return out


static func is_gen1(data: GameData) -> bool:
	return data != null and data.generation == RomRegistry.GEN1


## `InitName`, which makes the naming screen's END reachable with nothing typed.
static func resolve_name(entered: String, gender: int) -> String:
	if entered.strip_edges() != "":
		return entered
	return DEFAULT_FEMALE if gender == Gen2SaveData.GENDER_FEMALE else DEFAULT_MALE


static func with_names(text: String, player_name: String, rival_name: String) -> String:
	return Gen2TextStream.fill_names(text, {"player": player_name, "rival": rival_name})


static func intro_species(data: GameData) -> int:
	if is_gen1(data):
		return Gen1Layout.INTRO_SPECIES_YELLOW if data.id == RomRegistry.YELLOW \
			else Gen1Layout.INTRO_SPECIES_KANTO
	return WOOPER if Gen2WorldState.is_crystal_profile(data) else MARILL


## Which cry the species beat plays. `OakSpeechText2`'s own
## `sound_cry_nidorina` does not match the picture beside it, which is the
## source's own recorded bug and is kept.
static func intro_cry(data: GameData) -> int:
	if is_gen1(data) and data.id != RomRegistry.YELLOW:
		return Gen1Layout.INTRO_CRY_KANTO
	return intro_species(data)
