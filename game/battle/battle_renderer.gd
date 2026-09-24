class_name Gen2BattleRenderer
extends Control

## Draws the battle field: pics, status panels, HP and exp bars and whatever an
## animation puts over them. [method set_battle_data] once, then
## [method set_view] per display change. The pics go through `wTilemap`, which
## is what an animation edits; every background layer is one plane, so the
## per-scanline scroll applies to all of them and to none of the objects.

const TILE: int = Gen2Font.TILE

## Where each picture sits and which tile ids are its own: see
## [Gen2BattleScreenMap], which the screen builds the map with.
const COLUMNS: int = Gen2BattleScreenMap.COLUMNS
const ROWS: int = Gen2BattleScreenMap.ROWS

## The background map is 256 pixels each way against the screen's 160 by 144, so
## a scroll wraps and blank is what comes in.
const MAP_WIDTH: int = 256
const MAP_HEIGHT: int = 256

const PALETTE_IDENTITY: int = Gen2BattleColors.PALETTE_IDENTITY
const OAM_YFLIP: int = Gen2BattleColors.OAM_YFLIP
const OAM_XFLIP: int = Gen2BattleColors.OAM_XFLIP
const OAM_PALETTE: int = Gen2BattleColors.OAM_PALETTE

## The white the hardware fills the battle background with; Generation 1 fills it
## with `SuperPalettes`' own, from [method Gen2BattleColors.gen1_screen_palette].
const BACKGROUND: Color = Color.WHITE

const GEN1_PAL_PLAYER_BAR: int = Gen2BattleColors.GEN1_PAL_PLAYER_BAR
const GEN1_PAL_ENEMY_BAR: int = Gen2BattleColors.GEN1_PAL_ENEMY_BAR
const GEN1_PAL_PLAYER_MON: int = Gen2BattleColors.GEN1_PAL_PLAYER_MON
const GEN1_PAL_ENEMY_MON: int = Gen2BattleColors.GEN1_PAL_ENEMY_MON

var _data: GameData = null
var _hud: Gen2BattleHud = null
var _view: Dictionary = {}
var _colors: Gen2BattleColors = null

var _enemy_pic: TextureRect = null
var _player_pic: TextureRect = null
var _panels: TextureRect = null
var _enemy_bar: TextureRect = null
var _player_bar: TextureRect = null
var _exp_bar: TextureRect = null
## `BattleStart_TrainerHuds`' party balls, which are OAM rather than background
## and so take no scroll.
var _hud_balls: TextureRect = null
var _sprites: TextureRect = null

## `SPRITE_MONSTER`, whose strip `GetSubstitutePic` and `AnimationSubstitute`
## build the doll from: $4C in both Generation 2 pins, $05 in pokered.
const SUBSTITUTE_SPRITE: int = 0x4C
const GEN1_SUBSTITUTE_SPRITE: int = 0x05

## The doll's top-left tile by generation and side, a box index being
## `column * side + row`: `GetSubstitutePic`'s `sScratch + (2 * 7 + 5) tiles` and
## `(2 * 6 + 4)`, `AnimationSubstitute`'s `PIC_HEIGHT * 2 + 4` and `* 3 + 4`. The
## enemy takes the sprite's down-facing frame and the player the up-facing one.
const SUBSTITUTE_AT: Dictionary = {
	RomRegistry.GEN2: {false: Vector2i(2, 5), true: Vector2i(2, 4)},
	RomRegistry.GEN1: {false: Vector2i(2, 4), true: Vector2i(3, 4)},
}
const SUBSTITUTE_FIRST_TILE: Dictionary = {false: 0, true: 4}

## The dot's tile: `GetMinimizePic`'s `(3 * 7 + 5)` and `(3 * 6 + 4)`, and
## `AnimationMinimizeMon`'s `PIC_WIDTH * 3 + 4` on either side.
const MINIMIZE_AT: Dictionary = {
	RomRegistry.GEN2: {false: Vector2i(3, 5), true: Vector2i(3, 4)},
	RomRegistry.GEN1: {false: Vector2i(3, 4), true: Vector2i(3, 4)},
}

## The view keys [method square_pixels] reads, in [method square_key]'s order.
const SQUARE_KEYS: Dictionary = {
	false: [
		"enemy_species", "enemy_substitute", "enemy_unown_form", "enemy_trainer_pic",
		"enemy_minimized", "enemy_special_pic",
	],
	true: [
		"player_species", "player_substitute", "player_unown_form", "player_backpic",
		"player_minimized",
	],
}

## One 56x56 and one 48x48 index buffer, the two pics padded out to their own
## boxes, rebuilt only when the picture drawn changes.
var _enemy_pixels: PackedByteArray = PackedByteArray()
var _player_pixels: PackedByteArray = PackedByteArray()
var _enemy_pixels_key: Array = []
var _player_pixels_key: Array = []

## Everything a pic layer is built out of. A draining bar moves the panels while
## the map, the species, the palette and the scroll all stand still, so the same
## two pictures were being rebuilt into a screen-sized buffer and a fresh
## texture on every frame of it. The layer is kept until one of its own inputs
## changes.
var _enemy_pic_key: Array = []
var _player_pic_key: Array = []
## The same for the four layers above them, by name.
var _layer_keys: Dictionary = {}


## Whether [param id] has to be rebuilt, recording [param key] as what it will
## then be holding.
func _layer_changed(id: StringName, key: Array) -> bool:
	if _layer_keys.get(id, null) == key:
		return false
	_layer_keys[id] = key
	return true


## The per-scanline offsets every background layer is scrolled by, which belong
## to each of them as much as their own contents do.
func _raster_key() -> Array:
	return [
		PackedInt32Array(_view.get("raster_scy", [])),
		PackedInt32Array(_view.get("raster_scx", [])),
	]


## Reads what it draws with out of the cache and builds its layers. Answers
## false if the cache is missing something the HUD needs, mirroring
## [method Gen2BattleHud.from_data].
func set_battle_data(data: GameData) -> bool:
	_data = data
	_colors = Gen2BattleColors.new(data)
	_hud = Gen2BattleHud.from_data(data)
	if _hud == null:
		return false

	## Palette 0's colour 0, the same white in all three bar rows.
	var field: Color = BACKGROUND
	if data.generation == RomRegistry.GEN1:
		field = data.bar_palette(GameData.HP_BAR_PALETTE_NAMES[0])[0]
	add_child(Gen2Screen.Field.create(field))

	_enemy_pic = _new_layer()
	_player_pic = _new_layer()
	_panels = _new_layer()
	_enemy_bar = _new_layer()
	_player_bar = _new_layer()
	_exp_bar = _new_layer()
	_hud_balls = _new_layer()
	_sprites = _new_layer()
	return true


## The display values a battle screen has settled on right now. Plain values,
## not the battle engine: what is drawn deliberately lags what has resolved,
## since a turn resolves at once and is then shown an event at a time.
func set_view(view: Dictionary) -> void:
	_view = view
	_colors.set_view(view)
	refresh()


func refresh() -> void:
	if _hud == null:
		return

	_draw_pics()
	_draw_panels()
	_draw_sprites()


## Both pics, each read out of the tilemap so an animation that blanked, shifted
## or resized one is what shows.
func _draw_pics() -> void:
	var map: PackedByteArray = _bg_map()
	_ensure_pixels()
	var raster: Array = _raster_key()
	var gray: PackedColorArray = _colors.grayscale()
	# A packed array is passed by reference, so a key holding the screen's own
	# map is a key that changes with it: every animation that edits nothing but
	# the tilemap, which is most of them, would compare equal to what is on
	# screen and never be redrawn.
	var map_key: PackedByteArray = map.duplicate()

	var enemy: int = int(_view.get("enemy_species", 0))
	var enemy_palette: PackedColorArray = _colors.pic_palette(false)
	var vbank1: PackedByteArray = _vbank1()
	var enemy_key: Array = [
		map_key, enemy, _enemy_pixels_key, enemy_palette, raster, vbank1.duplicate(), gray,
	]
	if enemy_key != _enemy_pic_key:
		_enemy_pic_key = enemy_key
		_show_layer(
			_enemy_pic,
			_pic_layer(
				map, Gen2BattleScreenMap.ENEMY_BASE_TILE,
				Gen2BattleScreenMap.ENEMY_SIDE, _enemy_pixels, vbank1, true
			),
			enemy_palette
		)
	var player: int = int(_view.get("player_species", 0))
	var player_palette: PackedColorArray = _colors.pic_palette(true)
	var player_key: Array = [
		map_key, player, _player_pixels_key, player_palette, raster,
		vbank1.duplicate(), gray,
	]
	if player_key != _player_pic_key:
		_player_pic_key = player_key
		_show_layer(
			_player_pic,
			_pic_layer(
				map, Gen2BattleScreenMap.PLAYER_BASE_TILE,
				Gen2BattleScreenMap.player_box_side(_data.generation),
				_player_pixels, vbank1
			),
			player_palette
		)


func _gen1() -> bool:
	return _colors != null and _colors.gen1()


## `wAttrmap` bit 3 over the screen, which is the VRAM bank each cell's tile
## number is read from. Only `PokeAnim_SetVBank1` ever sets it here, so it is
## empty unless the enemy's picture is being animated.
func _vbank1() -> PackedByteArray:
	var supplied: Variant = _view.get("bg_vbank1", null)
	if supplied is PackedByteArray \
			and (supplied as PackedByteArray).size() == COLUMNS * ROWS:
		return supplied
	return PackedByteArray()


## The tilemap the animation edits, or the plain one both pics sit in when the
## view carries none.
func _bg_map() -> PackedByteArray:
	var supplied: Variant = _view.get("bg_map", null)
	if supplied is PackedByteArray \
			and (supplied as PackedByteArray).size() == COLUMNS * ROWS:
		return supplied
	return Gen2BattleScreenMap.seeded()


## One index buffer of every cell of [param map] inside this pic's own run,
## `base + column * side + row` as `PlaceGraphic` walks. [param vbank1] is
## `wAttrmap` bit 3 and [param animated] whether this layer owns bank 1, which
## holds the enemy's picture and `AnimateFrontpic`'s frames from the same tile.
func _pic_layer(
	map: PackedByteArray, base: int, side: int, pixels: PackedByteArray,
	vbank1: PackedByteArray = PackedByteArray(), animated: bool = false
) -> PackedByteArray:
	var out: PackedByteArray = _new_buffer()
	var strip: int = pic_stride(pixels, side)
	if strip <= 0:
		return out
	@warning_ignore("integer_division")
	var banked: int = (strip / TILE) * side
	var square: int = side * side
	var banks: bool = vbank1.size() == map.size()
	for row: int in ROWS:
		for column: int in COLUMNS:
			var at: int = row * COLUMNS + column
			var bank1: bool = banks and vbank1[at] != 0
			var tile: int = int(map[at]) - base
			if not claims_tile(tile, bank1, animated, square, banked):
				continue
			@warning_ignore("integer_division")
			var source_x: int = (tile / side) * TILE
			var source_y: int = (tile % side) * TILE
			for line: int in TILE:
				var from: int = (source_y + line) * strip + source_x
				var to: int = (row * TILE + line) * Gen2Screen.WIDTH + column * TILE
				for x: int in TILE:
					out[to + x] = pixels[from + x]
	return out


## Whether the layer whose first tile is [param tile]'s own base draws this
## cell. Split out because it is the whole of `PokeAnim_SetVBank1`'s rule and
## getting it wrong is invisible until two pictures share a tile number: bank 1
## belongs to the animated layer alone and reaches its frames, [param banked],
## while bank 0 gives every layer its own [param square] and nothing behind it.
static func claims_tile(
	tile: int, bank1: bool, animated: bool, square: int, banked: int
) -> bool:
	if bank1 and not animated:
		return false
	return tile >= 0 and tile < (banked if bank1 else square)


## Both pics padded to their boxes, so a tile id indexes a fixed grid.
func _ensure_pixels() -> void:
	var enemy_key: Array = square_key(_view, false)
	if enemy_key != _enemy_pixels_key:
		_enemy_pixels = square_pixels(_data, _view, false, true)
		_enemy_pixels_key = enemy_key
	var player_key: Array = square_key(_view, true)
	if player_key != _player_pixels_key:
		_player_pixels = square_pixels(_data, _view, true)
		_player_pixels_key = player_key


## What [method square_pixels] answers from: it changes only when this does.
static func square_key(view: Dictionary, player_side: bool) -> Array:
	var out: Array = []
	for key: String in SQUARE_KEYS[player_side]:
		out.append(view.get(key))
	return out


## What stands on one side's square, as an index buffer of its box: the GHOST or
## a fossil, a link opponent, a trainer or the back pic, the doll, the dot, then
## the species or its Unown letter. [param frames] appends `GetAnimatedFrontpic`'s
## frames past the enemy's box, which [method pic_stride] then measures.
static func square_pixels(
	data: GameData, view: Dictionary, player_side: bool, frames: bool = false
) -> PackedByteArray:
	if player_side:
		var backpic: String = String(view.get("player_backpic", ""))
		if not backpic.is_empty():
			return back_pixels(data, data.player_backpic(backpic))
		var marked: PackedByteArray = _marked_square(data, view, true)
		if not marked.is_empty():
			return marked
		return back_pixels(data, battler_pic(
			data, int(view.get("player_species", 0)), int(view.get("player_unown_form", 0)), true
		))
	var side: int = Gen2BattleScreenMap.ENEMY_SIDE
	var special: String = String(view.get("enemy_special_pic", ""))
	var trainer: int = int(view.get("enemy_trainer_pic", 0))
	if not special.is_empty():
		return padded_pic(data, data.gen1_special_pic(special), side, true)
	if trainer == Gen2BattleScreen.LINK_OPPONENT_PIC:
		return padded_pic(data, data.player_frontpic(), side)
	if trainer > 0:
		return padded_pic(data, data.trainer_pic(trainer), side)
	var dot: PackedByteArray = _marked_square(data, view, false)
	if not dot.is_empty():
		return dot
	var species: int = int(view.get("enemy_species", 0))
	var form: int = int(view.get("enemy_unown_form", 0))
	return padded_pic(
		data, battler_pic(data, species, form, false), side, true,
		data.species_pic_animation(species, form) if frames else {}
	)


## `GetBattleMonBackpic`'s order: a doll stands in front of the dot.
static func _marked_square(
	data: GameData, view: Dictionary, player_side: bool
) -> PackedByteArray:
	var prefix: String = "player_" if player_side else "enemy_"
	if bool(view.get(prefix + "substitute", false)):
		return substitute_pixels(
			data.overworld_sprite_indices(substitute_sprite(data.generation)), player_side,
			data.generation
		)
	if bool(view.get(prefix + "minimized", false)):
		return minimize_pixels(data.tile_indices("minimize"), player_side, data.generation)
	return PackedByteArray()


## The back pic in its own box, which Generation 1 doubles on the way in.
static func back_pixels(data: GameData, pic: Dictionary) -> PackedByteArray:
	var side: int = Gen2BattleScreenMap.player_box_side(data.generation)
	if data.generation == RomRegistry.GEN1:
		return doubled_pic(data, pic, side)
	return padded_pic(data, pic, side)


## `ScaleSpriteByTwo`: a 32x32 back pic drawn 56x56. It walks 28 of the 32 rows
## and takes four pixels from the last column rather than eight, so the last
## four of each are dropped and what is left is drawn twice each way.
static func doubled_pic(data: GameData, pic: Dictionary, side: int) -> PackedByteArray:
	var box: int = side * TILE
	var out: PackedByteArray = PackedByteArray()
	out.resize(box * box)
	if pic.is_empty():
		return out
	var atlas_name: String = String(pic.get("atlas", ""))
	var cell: Dictionary = Gen2PicImage.atlas_cell(
		data.atlas_indices(atlas_name), data.atlas(atlas_name), pic
	)
	if cell.is_empty():
		return out

	var indices: PackedByteArray = cell["indices"]
	var stride: int = int(cell["width"])
	@warning_ignore("integer_division")
	var half: int = box / 2
	var rows: int = mini(half, int(cell["height"]))
	var columns: int = mini(half, stride)
	for y: int in rows:
		for x: int in columns:
			var value: int = indices[y * stride + x]
			for down: int in 2:
				var to: int = (y * 2 + down) * box + x * 2
				out[to] = value
				out[to + 1] = value
	return out


## `_GetFrontpic`'s own branch: Unown is drawn out of `UnownPicPointers` by
## letter, and everything else out of the species table. The atlas is indexed
## from zero and a letter counts from one, which is the subtraction here.
static func battler_pic(data: GameData, species: int, unown_form: int, back: bool) -> Dictionary:
	if species == Gen2Layout.UNOWN_SPECIES and unown_form > 0:
		return data.unown_pic(unown_form - 1, back)
	return data.species_pic(species, back)


## One square's side in tiles, which is 7 but for Generation 2's player.
static func square_side(generation: int, player_side: bool) -> int:
	return Gen2BattleScreenMap.player_box_side(generation) if player_side \
		else Gen2BattleScreenMap.ENEMY_SIDE


## `GetMinimizePic` and `AnimationMinimizeMon`: a blank box with the one
## "minimize" tile copied into it. Static like [method substitute_pixels].
static func minimize_pixels(
	tile: PackedByteArray, player_side: bool, generation: int = RomRegistry.GEN2
) -> PackedByteArray:
	var box: int = square_side(generation, player_side) * TILE
	var out: PackedByteArray = PackedByteArray()
	out.resize(box * box)
	if tile.size() < TILE * TILE:
		return out

	var at: Vector2i = MINIMIZE_AT[generation][player_side]
	for row: int in TILE:
		var to: int = (at.y * TILE + row) * box + at.x * TILE
		for column: int in TILE:
			out[to + column] = tile[row * TILE + column]
	return out


static func substitute_sprite(generation: int) -> int:
	return GEN1_SUBSTITUTE_SPRITE if generation == RomRegistry.GEN1 else SUBSTITUTE_SPRITE


## `GetSubstitutePic`: a blank box with four tiles of [param strip], the monster
## overworld sprite, copied into it. The doll wears whichever battler palette its
## box sits in, since nothing writes one for it. Static because it takes no
## screen: a check sweeping every cache builds it the way the renderer does.
static func substitute_pixels(
	strip: PackedByteArray, player_side: bool, generation: int = RomRegistry.GEN2
) -> PackedByteArray:
	var box: int = square_side(generation, player_side) * TILE
	var out: PackedByteArray = PackedByteArray()
	out.resize(box * box)

	var first: int = int(SUBSTITUTE_FIRST_TILE[player_side])
	# The strip is one tile row high, so its length is its width in pixels.
	@warning_ignore("integer_division")
	var width: int = strip.size() / TILE
	if width < (first + 4) * TILE:
		return out

	var at: Vector2i = SUBSTITUTE_AT[generation][player_side]
	for tile: int in 4:
		var left: int = (at.x + (tile & 1)) * TILE
		var top: int = (at.y + (tile >> 1)) * TILE
		var from_x: int = (first + tile) * TILE
		for row: int in TILE:
			var from: int = row * width + from_x
			var to: int = (top + row) * box + left
			for column: int in TILE:
				out[to + column] = strip[from + column]
	return out


## The row stride of a buffer [method padded_pic] produced. The box is square
## and `AnimateFrontpic`'s frames sit behind it in the same rows, so a pic that
## carries them is wider than its own box and every row of it is that wide.
## Zero when the buffer is not one, which is a caller with nothing to draw.
static func pic_stride(pixels: PackedByteArray, side: int) -> int:
	var box: int = side * TILE
	if box <= 0 or pixels.size() < box * box:
		return 0
	@warning_ignore("integer_division")
	var strip: int = pixels.size() / box
	return strip


## [param front] is whether `PadFrontpic` runs: a back pic and a trainer's are
## not padded. [param animation] is the `front_anim` cell `GetAnimatedEnemyFrontpic`
## loads `7 * 7 tiles` past the picture, [param mirrored] `wBoxAlignment`.
static func padded_pic(
	data: GameData, pic: Dictionary, side: int, front: bool = false,
	animation: Dictionary = {}, mirrored: bool = false
) -> PackedByteArray:
	var box: int = side * TILE
	var extra: int = _animation_columns(animation, side) * TILE
	var out: PackedByteArray = PackedByteArray()
	out.resize(box * (box + extra))
	if pic.is_empty():
		return out

	var atlas_name: String = String(pic.get("atlas", ""))
	var cell: Dictionary = Gen2PicImage.atlas_cell(
		data.atlas_indices(atlas_name), data.atlas(atlas_name), pic
	)
	if cell.is_empty():
		return out

	var indices: PackedByteArray = cell["indices"]
	var width: int = mini(int(cell["width"]), box)
	var height: int = mini(int(cell["height"]), box)
	var stride: int = int(cell["width"])
	## `PadFrontpic` does not centre a pic smaller than the 7x7 block: it lays one
	## blank tile column in front of it and blank tiles above each column, so the
	## pic is bottom-aligned one column in. The tile numbers `PlaceGraphic` writes
	## count over the padded block, so a pic left at the corner here is drawn a
	## column left and a row or two high of where the cartridge draws it.
	var pad_x: int = 0
	var pad_y: int = 0
	if front:
		@warning_ignore("integer_division")
		pad_x = Gen2PicImage.frontpic_pad_columns(
			width / TILE, false, data.generation
		) * TILE
		@warning_ignore("integer_division")
		pad_y = Gen2PicImage.frontpic_pad_rows(height / TILE) * TILE
	var strip: int = box + extra
	for y: int in mini(height, box - pad_y):
		for x: int in mini(width, box - pad_x):
			out[(y + pad_y) * strip + x + pad_x] = indices[y * stride + x]
	if extra > 0:
		_append_animation(data, animation, out, strip, side)
	return Gen2PicImage.tile_flipped_indices(out, strip) if mirrored else out


## How many tile columns of `side` an animation's own `w * h` tiles need. Zero
## when the cartridge has no animation for this pic, which is every pic on Gold
## and Silver and every trainer and back pic on Crystal.
static func _animation_columns(animation: Dictionary, side: int) -> int:
	if animation.is_empty() or side <= 0:
		return 0
	@warning_ignore("integer_division")
	var tiles: int = (int(animation.get("width", 0)) / TILE) \
		* (int(animation.get("height", 0)) / TILE)
	return ceili(float(tiles) / float(side))


## The animation's tiles laid into the strip past the box, in the run's own
## order: tile `side * side + i` is at column `side + i / side`, row `i % side`.
static func _append_animation(
	data: GameData, animation: Dictionary, out: PackedByteArray, strip: int, side: int
) -> void:
	var atlas: String = String(animation.get("atlas", ""))
	var cell: Dictionary = Gen2PicImage.atlas_cell(
		data.atlas_indices(atlas), data.atlas(atlas), animation
	)
	if cell.is_empty():
		return
	var indices: PackedByteArray = cell["indices"]
	var source_stride: int = int(cell["width"])
	@warning_ignore("integer_division")
	var rows: int = int(cell["height"]) / TILE
	@warning_ignore("integer_division")
	var count: int = (source_stride / TILE) * rows
	for index: int in count:
		# The atlas cell holds the tiles column major, the way every pic is
		# stored, and the strip wants them in the run's own order.
		@warning_ignore("integer_division")
		var source_x: int = (index / rows) * TILE
		var source_y: int = (index % rows) * TILE
		@warning_ignore("integer_division")
		var target_x: int = (side + index / side) * TILE
		var target_y: int = (index % side) * TILE
		for line: int in TILE:
			var from: int = (source_y + line) * source_stride + source_x
			var to: int = (target_y + line) * strip + target_x
			if from + TILE > indices.size() or to + TILE > out.size():
				continue
			for x: int in TILE:
				out[to + x] = indices[from + x]


## The panels, then each bar over them in its own colour: one buffer per
## palette. `BattleAnimClearHud` takes one side off for a move animation and
## `BattleAnimRestoreHuds` puts it back.
func _draw_panels() -> void:
	var raster: Array = _raster_key()
	var enemy_hp: int = int(_view.get("enemy_hp", 0))
	var enemy_max_hp: int = int(_view.get("enemy_max_hp", 0))
	var player_hp: int = int(_view.get("player_hp", 0))
	var player_max_hp: int = int(_view.get("player_max_hp", 0))
	var exp_pixels: int = int(_view.get("exp_pixels", 0))
	var enemy_hud: bool = bool(_view.get("enemy_hud_visible", true))
	var player_hud: bool = bool(_view.get("player_hud_visible", true))

	if _layer_changed(&"panels", Gen2BattleHud.panels_key(_view) + raster):
		var panels: PackedByteArray = _new_buffer()
		_hud.draw_panels(panels, Gen2Screen.WIDTH, _view)
		## Blocks 3 and 2 name palettes 0 and 1 for the two panels; both are
		## 1bpp, so one layer serves.
		_show_layer(_panels, panels, _colors.panel_palette())

	var gray: PackedColorArray = _colors.grayscale()
	if _layer_changed(&"enemy_bar", [enemy_hp, enemy_max_hp, enemy_hud, raster, gray]):
		var enemy: PackedByteArray = _new_buffer()
		if enemy_hud:
			_hud.draw_hp_bar(
				enemy, Gen2Screen.WIDTH, Gen2BattleHud.ENEMY_BAR, enemy_hp, enemy_max_hp
			)
		_show_layer(_enemy_bar, enemy, _colors.hp_palette(enemy_hp, enemy_max_hp))

	if _layer_changed(&"player_bar", [player_hp, player_max_hp, player_hud, raster, gray]):
		var player: PackedByteArray = _new_buffer()
		if player_hud:
			_hud.draw_hp_bar(
				player, Gen2Screen.WIDTH, Gen2BattleHud.PLAYER_BAR, player_hp, player_max_hp
			)
		_show_layer(_player_bar, player, _colors.hp_palette(player_hp, player_max_hp))

	if _layer_changed(&"exp_bar", [exp_pixels, player_hud, raster]):
		var gained: PackedByteArray = _new_buffer()
		# Generation 1's panel has no exp bar: the row under the HP numbers is
		# the border's own edge and nothing else.
		if player_hud and not _hud.gen1:
			_hud.draw_exp_bar(gained, Gen2Screen.WIDTH, exp_pixels)
		_show_layer(_exp_bar, gained, _data.bar_palette(GameData.EXP_BAR_PALETTE))

	_draw_hud_balls()


## `LoadTrainerHudOAM`: objects on `PAL_BATTLE_OB_YELLOW`, taking no scroll.
func _draw_hud_balls() -> void:
	var balls: Array = _view.get("trainer_hud_balls", []) as Array
	if balls.is_empty():
		_hud_balls.texture = null
		_layer_keys.erase(&"hud_balls")
		return
	if not _layer_changed(&"hud_balls", [balls]):
		return
	var sheet_name: String = "battle_balls" if _hud.gen1 else "ball_icons"
	var sheet: PackedByteArray = _data.tile_indices(sheet_name)
	var width: int = int(_data.tile_sheet(sheet_name).get("width", sheet.size() / TILE))
	var buffer: PackedByteArray = _new_buffer()
	for entry: Variant in balls:
		if not entry is Dictionary or width <= 0:
			continue
		var ball: Dictionary = entry as Dictionary
		var tile: int = int(ball.get("tile", 0))
		var left: int = int(ball.get("x", 0))
		var top: int = int(ball.get("y", 0))
		for row: int in TILE:
			if top + row < 0 or top + row >= Gen2Screen.HEIGHT:
				continue
			var from: int = row * width + tile * TILE
			var to: int = (top + row) * Gen2Screen.WIDTH + left
			for column: int in TILE:
				var x: int = left + column
				if x < 0 or x >= Gen2Screen.WIDTH or from + column >= sheet.size():
					continue
				buffer[to + column] = sheet[from + column]
	# Not through `_show_image`: an object is not part of the background plane
	# and does not take the scroll the background layers do.
	var image: Image = Gen2PicImage.from_indices(
		buffer, Gen2Screen.WIDTH, Gen2Screen.HEIGHT,
		_colors.object_palette(Gen2BattleAnimBackground.PAL_OB_YELLOW), true
	)
	Gen2PicImage.show(_hud_balls, image)
	_hud_balls.size = image.get_size()
	_hud_balls.position = Vector2.ZERO


## `wShadowOAM` as the animation left it: up to forty sprites, each eight by
## eight, in the order they were written, so a later one draws over an earlier.
## Objects are not part of the background plane and take no scroll. Index 0 is
## transparent, which is what OAM's own colour 0 is.
func _draw_sprites() -> void:
	var sprites: Array = _view.get("anim_sprites", [])
	# `BattleIntroSlidingPics` walks the player's own eighteen, which are OAM
	# like any other and go through the same blit.
	var intro: Array = _view.get("intro_sprites", [])
	if sprites.is_empty() and intro.is_empty():
		_sprites.texture = null
		return

	var image: Image = Image.create_empty(
		Gen2Screen.WIDTH, Gen2Screen.HEIGHT, false, Image.FORMAT_RGBA8
	)
	for entry: Variant in sprites:
		if entry is Dictionary:
			_blit_sprite(image, entry as Dictionary)
	for entry: Variant in intro:
		if entry is Dictionary:
			_blit_sprite(image, entry as Dictionary, true)
	Gen2PicImage.show(_sprites, image)
	_sprites.size = image.get_size()
	_sprites.position = Vector2.ZERO


## One OAM entry, y and x the hardware's (sixteen and eight subtracted).
## [param backpic] names the player's back pic as the sheet: `CopyBackpic`
## puts it in `vTiles0` and `.LoadTrainerBackpicAsOAM` addresses it there.
func _blit_sprite(into: Image, sprite: Dictionary, backpic: bool = false) -> void:
	var index: int = int(sprite.get("tile", 0))
	var pixels: PackedByteArray = _battler_tile(
		Gen2BattleScreenMap.PLAYER_BASE_TILE + index
	) if backpic else _sprite_tile(index)
	if pixels.is_empty():
		return
	var attributes: int = int(sprite.get("attributes", 0))
	var left: int = int(sprite.get("x", 0)) - 8
	var top: int = int(sprite.get("y", 0)) - 16
	var lookup: Image = _colors.object_image(pixels, attributes, left, top)

	var clip: Rect2i = Rect2i(0, 0, TILE, TILE)
	if left < 0:
		clip.position.x = -left
		clip.size.x += left
		left = 0
	if top < 0:
		clip.position.y = -top
		clip.size.y += top
		top = 0
	clip.size.x = mini(clip.size.x, Gen2Screen.WIDTH - left)
	clip.size.y = mini(clip.size.y, Gen2Screen.HEIGHT - top)
	if clip.size.x <= 0 or clip.size.y <= 0:
		return
	into.blend_rect(lookup, clip, Vector2i(left, top))


## One animation tile out of the window [method Gen2BattleAnimPlayer.tiles]
## describes, counted from `BATTLEANIM_BASE_TILE`: an imported sheet's, or one
## of the two pictures `anim_battlergfx_1row` and `..._2row` put there.
func _sprite_tile(tile: int) -> PackedByteArray:
	var window: Array = _view.get("anim_tiles", [])
	var at: int = tile - Gen2BattleAnimObject.BASE_TILE
	if at < 0 or at >= window.size() or not window[at] is Dictionary:
		return PackedByteArray()
	var entry: Dictionary = window[at]
	if entry.has("battler_tile"):
		return _battler_tile(int(entry["battler_tile"]))
	var strip: PackedByteArray = _data.battle_anim_gfx_indices(int(entry["gfx"]))
	var index: int = int(entry["tile"])
	var width: int = strip.size() / TILE if strip.size() > 0 else 0
	if width <= 0 or (index + 1) * TILE > width:
		return PackedByteArray()

	var out: PackedByteArray = PackedByteArray()
	out.resize(TILE * TILE)
	for row: int in TILE:
		var from: int = row * width + index * TILE
		for column: int in TILE:
			out[row * TILE + column] = strip[from + column]
	return out


## One tile of `vTiles2`, out of the same padded boxes the tilemap is drawn
## from, so a battler moved as objects is the picture that was on the field.
func _battler_tile(vram: int) -> PackedByteArray:
	var enemy: bool = vram < Gen2BattleScreenMap.PLAYER_BASE_TILE
	var side: int = Gen2BattleScreenMap.ENEMY_SIDE if enemy \
		else Gen2BattleScreenMap.player_box_side(_data.generation)
	var base: int = Gen2BattleScreenMap.ENEMY_BASE_TILE if enemy \
		else Gen2BattleScreenMap.PLAYER_BASE_TILE
	return pic_tile(_enemy_pixels if enemy else _player_pixels, side, vram - base)


## One tile of a buffer [method padded_pic] produced, numbered `column * side +
## row` the way `PlaceGraphic` numbers a picture's own box. Static because the
## same read is what `tools/checks/pokepic.gd` sweeps a corpus with: it is the
## one place a battler moved as objects and the same battler drawn as tilemap
## can disagree.
static func pic_tile(pixels: PackedByteArray, side: int, index: int) -> PackedByteArray:
	var strip: int = pic_stride(pixels, side)
	if index < 0 or index >= side * side or strip <= 0:
		return PackedByteArray()

	@warning_ignore("integer_division")
	var left: int = (index / side) * TILE
	var top: int = (index % side) * TILE
	var out: PackedByteArray = PackedByteArray()
	out.resize(TILE * TILE)
	for row: int in TILE:
		var from: int = (top + row) * strip + left
		for column: int in TILE:
			out[row * TILE + column] = pixels[from + column]
	return out


func _new_layer() -> TextureRect:
	var out := TextureRect.new()
	# Nearest, or the integer-scaled viewport is undone on the last hop.
	out.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(out)
	return out


func _new_buffer() -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(Gen2Screen.WIDTH * Gen2Screen.HEIGHT)
	return out


## Every layer above the pics is drawn with index 0 transparent: a panel is a
## shape on the background, not a rectangle over it.
func _show_layer(
	into: TextureRect, indices: PackedByteArray, palette: PackedColorArray
) -> void:
	_show_image(into, Gen2PicImage.from_indices(
		indices, Gen2Screen.WIDTH, Gen2Screen.HEIGHT, palette, true
	))


## One background layer, scrolled by whatever the view is asking for. An empty
## or absent offset list is a background sitting still, which is every frame
## outside the intro and outside an animation that opened a scanline window.
func _show_image(into: TextureRect, image: Image) -> void:
	var rows: PackedInt32Array = PackedInt32Array(_view.get("raster_scy", []))
	if not rows.is_empty():
		image = PokeRaster.scroll_rows(image, rows, MAP_HEIGHT)
	var offsets: PackedInt32Array = PackedInt32Array(_view.get("raster_scx", []))
	if not offsets.is_empty():
		image = PokeRaster.scroll(image, offsets, MAP_WIDTH)
	Gen2PicImage.show(into, image)
	into.size = image.get_size()
	into.position = Vector2.ZERO
