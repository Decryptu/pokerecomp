class_name Gen2BattleColors
extends RefCounted

## The colours a battle is drawn in on either generation, off the view, for
## any renderer: a palette per square and sprite on the Color hardware, and on
## a Super Game Boy `BlkPacket_Battle`'s blocks over `SetPal_Battle`'s four.

const TILE: int = PokeTiles.TILE_WIDTH

## `%11100100`, the DMG palette byte that maps every colour to itself.
const PALETTE_IDENTITY: int = 0xE4

## OAM attribute bits, as [Gen2BattleAnimObject] writes them.
const OAM_YFLIP: int = 1 << 6
const OAM_XFLIP: int = 1 << 5
const OAM_PALETTE: int = 0x07

## `BlkPacket_Battle`'s five blocks name one of four Super Game Boy palettes for
## every cell of a Generation 1 battle and `SetPal_Battle` fills them: 0 and 1
## are `PAL_GREENBAR` plus each side's HP bar colour, 2 and 3 are
## `DeterminePaletteID`'s. Block 1 gives rows 12 to 17 palette 2 and everything
## outside them palette 0.
const GEN1_PAL_PLAYER_BAR: int = 0
const GEN1_PAL_ENEMY_BAR: int = 1
const GEN1_PAL_PLAYER_MON: int = 2
const GEN1_PAL_ENEMY_MON: int = 3

var _data: GameData = null
var _view: Dictionary = {}
var _gen1_blocks: PackedByteArray = PackedByteArray()


func _init(data: GameData) -> void:
	_data = data


func set_view(view: Dictionary) -> void:
	_view = view


func gen1() -> bool:
	return _data != null and _data.generation == RomRegistry.GEN1


## A side's square: the species' palette through the background map, a
## trainer's or the back pic's own on the Color hardware, and on a Super Game
## Boy the mon's whoever stands there, since `SetPal_Battle` reads a species.
func pic_palette(back: bool) -> PackedColorArray:
	var gray: PackedColorArray = grayscale()
	if not gray.is_empty():
		return gray
	var slot: int = Gen2BattleAnimBackground.PAL_BG_PLAYER if back \
		else Gen2BattleAnimBackground.PAL_BG_ENEMY
	## `MarowakAnim`'s `rOBP1` over the enemy's square alone.
	var dmg: int = int(_view.get("enemy_pic_dmg", -1)) if not back else -1
	if dmg < 0:
		dmg = _palette_map("bg_palette_maps", slot)
	if not gen1():
		var trainer: int = int(_view.get("enemy_trainer_pic", 0))
		if not back and trainer > 0:
			return remapped(_data.trainer_palette(trainer), dmg)
		var backpic: String = String(_view.get("player_backpic", ""))
		if back and not backpic.is_empty():
			return remapped(_data.player_palette(
				String(_view.get("player_backpic_palette", "chris"))
			), dmg)
	return remapped(_species_palette(back), dmg)


## What the panels are drawn in: ink on the Color hardware, and on a Super Game
## Boy block 3's palette, whose colour 0 and 3 every row shares.
func panel_palette() -> PackedColorArray:
	if gen1():
		return gen1_screen_palette(GEN1_PAL_PLAYER_BAR)
	return PokePalette.pic_palette(PackedColorArray([Color.WHITE, Color.BLACK]))


func hp_palette(hp: int, max_hp: int) -> PackedColorArray:
	var black: PackedColorArray = grayscale()
	if not black.is_empty():
		return black
	var lit: int = Gen2BattleHud.bar_pixels(
		hp, max_hp, Gen2BattleHud.HP_BAR_TILES * Gen2BattleHud.TILE
	)
	return _data.bar_palette(GameData.hp_bar_palette_name(lit))


## One of `SetPal_Battle`'s four; every `SuperPalettes` row shares colours 0
## and 3, so a 1bpp surface reads the same out of whichever block covers it.
func gen1_screen_palette(slot: int) -> PackedColorArray:
	var black: PackedColorArray = grayscale()
	if not black.is_empty():
		return black
	var player: bool = slot == GEN1_PAL_PLAYER_BAR or slot == GEN1_PAL_PLAYER_MON
	var base: PackedColorArray = _species_palette(player) \
		if slot == GEN1_PAL_PLAYER_MON or slot == GEN1_PAL_ENEMY_MON else hp_palette(
			int(_view.get("player_hp" if player else "enemy_hp", 0)),
			int(_view.get("player_max_hp" if player else "enemy_max_hp", 0))
		)
	# `rBGP` is one byte for the whole screen where the Color hardware has a map
	# per palette, so every block takes slot 0's. It is what
	# `SetAnimationBGPalette` and `AnimationFlashScreen` darken the screen with.
	return remapped(base, _palette_map("bg_palette_maps", 0))


## One OAM tile as the hardware colours it where it lands, flips applied.
func object_image(
	pixels: PackedByteArray, attributes: int, left: int, top: int
) -> Image:
	var gray: PackedColorArray = grayscale()
	var lookup: Image
	if not gray.is_empty():
		lookup = Gen2PicImage.from_indices(pixels, TILE, TILE, gray, true)
	elif gen1():
		lookup = _gen1_object_image(pixels, attributes, left, top)
	else:
		lookup = Gen2PicImage.from_indices(pixels, TILE, TILE, remapped(
			object_palette(attributes & OAM_PALETTE),
			_palette_map("ob_palette_maps", attributes & OAM_PALETTE)
		), true)
	if (attributes & OAM_XFLIP) != 0:
		lookup.flip_x()
	if (attributes & OAM_YFLIP) != 0:
		lookup.flip_y()
	return lookup


## `_CGB_BattleGrayscale`'s palette up to `GetSGBLayout SCGB_BATTLE_COLORS`, and
## `SET_PAL_BATTLE_BLACK` behind a lost Generation 1 fight; empty otherwise.
func grayscale() -> PackedColorArray:
	if _data == null:
		return PackedColorArray()
	if bool(_view.get("gen1_black", false)):
		return _data.world_palette(Gen1Layout.PAL_BLACK)
	if not bool(_view.get("grayscale", false)):
		return PackedColorArray()
	return _data.battle_grayscale_palette()


func _species_palette(back: bool) -> PackedColorArray:
	return _data.palette(
		int(_view.get("player_species" if back else "enemy_species", 0)),
		bool(_view.get("player_shiny" if back else "enemy_shiny", false))
	)


## `CopyPals`: colour `index` is colour `(byte >> index * 2) & 3` of the
## pristine palette, so a remap never compounds.
static func remapped(palette: PackedColorArray, dmg: int) -> PackedColorArray:
	if palette.size() < PokePalette.COLORS_PER_PIC or dmg == PALETTE_IDENTITY:
		return palette
	var out := PackedColorArray()
	for index: int in PokePalette.COLORS_PER_PIC:
		out.append(palette[(dmg >> (index * 2)) & 3])
	return out


func _palette_map(key: String, slot: int) -> int:
	var maps: Variant = _view.get(key, null)
	if not maps is PackedByteArray or slot < 0 or slot >= (maps as PackedByteArray).size():
		return PALETTE_IDENTITY
	return int((maps as PackedByteArray)[slot])


## One of the eight object palettes, with both battlers' own pairs in it.
func object_palette(slot: int) -> PackedColorArray:
	return _data.battle_object_palette(
		slot,
		_battler_pair(int(_view.get("enemy_species", 0))),
		_battler_pair(int(_view.get("player_species", 0)))
	)


func _battler_pair(species: int) -> Array:
	var entry: Dictionary = _data.species(species)
	if entry.is_empty():
		return []
	var stored: Variant = (entry.get("palette", {}) as Dictionary).get("normal", [])
	return stored if stored is Array else []


func _gen1_object_image(
	pixels: PackedByteArray, attributes: int, left: int, top: int
) -> Image:
	var obp0: int = int(_view.get("anim_obp0", Gen1Layout.ANIM_OBP0))
	var out: Image = Image.create_empty(TILE, TILE, false, Image.FORMAT_RGBA8)
	var palettes: Dictionary = {}
	for row: int in TILE:
		var y: int = top + (TILE - 1 - row if attributes & OAM_YFLIP else row)
		for column: int in TILE:
			var index: int = pixels[row * TILE + column]
			if index == 0:
				continue
			var x: int = left + (TILE - 1 - column if attributes & OAM_XFLIP else column)
			var cell: int = _gen1_cell(x, y)
			if not palettes.has(cell):
				palettes[cell] = gen1_object_palette(attributes, x, y, obp0)
			out.set_pixel(column, row, (palettes[cell] as PackedColorArray)[index])
	return out


## The OAM byte's slot and `rOBP1` behind `OAM_HIGH_PALS` on the Color
## hardware; the `BlkPacket_Battle` block the cell sits in and `OAM_PAL1` on a
## Super Game Boy.
func gen1_object_palette(attributes: int, x: int, y: int, obp0: int) -> PackedColorArray:
	var cgb: bool = Gen1Layout.on_cgb(_data.id)
	var slot: int = attributes & Gen1Lcd.PALETTE_SLOT_MASK if cgb else _gen1_block(x, y)
	var high: int = Gen1Lcd.OAM_HIGH_PALS if cgb else Gen1Lcd.OAM_PAL1
	var dmg: int = Gen1Layout.ANIM_OBP1 if (attributes & high) != 0 else obp0
	return remapped(gen1_screen_palette(slot), dmg)


func _gen1_block(x: int, y: int) -> int:
	if _gen1_blocks.is_empty():
		_gen1_blocks = Gen1OpeningPage.attribute_map(
			(_data.opening().get("blocks", {}) as Dictionary).get("battle", [])
		)
	var cell: int = _gen1_cell(x, y)
	return _gen1_blocks[cell] if cell >= 0 and cell < _gen1_blocks.size() else 0


static func _gen1_cell(x: int, y: int) -> int:
	if x < 0 or x >= Gen2Screen.WIDTH or y < 0 or y >= Gen2Screen.HEIGHT:
		return -1
	@warning_ignore("integer_division")
	return (y / TILE) * Gen1OpeningPage.CELLS_ACROSS + x / TILE
