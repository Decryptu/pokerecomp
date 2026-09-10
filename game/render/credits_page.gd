class_name Gen2CreditsPage
extends RefCounted

## The credits screen, on the tile grid the hardware uses. [Gen2Credits] owns the
## BG map and the attribute map; this resolves a tile number to pixels and
## colours it through `CreditsPalettes`. The VRAM window is the banner's 4x4 mon
## cell at $00, `CreditsBorderGFX` at $20, `TheEndGFX` at $40, `CopyrightGFX` at
## $60 and the font from $80. `Credits_LYOverride` scrolls the two border bands
## alone, two pixels a cycle.

const TILE: int = Gen2Font.TILE
const COLUMNS: int = Gen2Credits.COLUMNS
const ROWS: int = Gen2Credits.ROWS
const WIDTH: int = COLUMNS * TILE

const BLANK_TILE: int = Gen2Credits.BLANK_TILE
## The banner cell is addressed by `Credits_LoadBorderGFX.Frames`' block rather
## than by tile number, so these sixteen are resolved against the block the frame
## is drawing and not against a strip position.
const BANNER_TILES: int = Gen2Layout.CREDITS_MON_FRAME_TILES

var font: Gen2Font = null
## The VRAM window, as one indices strip per tile number.
var _tiles: Dictionary = {}
## Generation 1 loads its copyright and `TheEndGfx` at the same $60 in turn,
## so its sheets are kept by name and the frame says which is loaded.
var _gen1: bool = false
var _gen1_sheets: Dictionary = {}
var _gen1_colors: PackedColorArray = PackedColorArray()
## `CreditsMonsGFX` whole, which a block indexes into.
var _mons: PackedByteArray = PackedByteArray()
var _mons_width: int = 0


## Null on a cache with no credits graphics, which is the caller's cue not to
## open the screen.
static func from_data(data: GameData) -> Gen2CreditsPage:
	var glyphs: Gen2Font = Gen2Font.from_data(data)
	if glyphs == null or data == null:
		return null
	var out := Gen2CreditsPage.new()
	out.font = glyphs
	if data.generation == RomRegistry.GEN1:
		out._gen1 = true
		for name: String in [Gen1Credits.SHEET_COPYRIGHT, Gen1Credits.SHEET_THE_END]:
			out._gen1_sheets[name] = _cells(data, name)
		## The player's `SET_PAL_POKEMON_WHOLE_SCREEN`, species 0, is PAL_MEWMON.
		out._gen1_colors = data.world_palette(Gen1Layout.PAL_MEWMON)
		return out
	out._load_sheet(data, "credits_border", Gen2Layout.CREDITS_BORDER_FIRST_CODE)
	out._load_sheet(data, "credits_the_end", Gen2Layout.CREDITS_THE_END_FIRST_CODE)
	out._load_sheet(data, "copyright", Gen2Layout.COPYRIGHT_FIRST_CODE)
	out._mons = data.tile_indices("credits_mons")
	out._mons_width = out._mons.size() / TILE if out._mons.size() > 0 else 0
	return out


func ready() -> bool:
	if _gen1:
		return font != null and _gen1_colors.size() >= Gen2Layout.CREDITS_PALETTE_COLORS \
			and not (_gen1_sheets.get(Gen1Credits.SHEET_THE_END, []) as Array).is_empty()
	return font != null and _mons_width > 0 \
		and _tiles.has(Gen2Layout.CREDITS_BORDER_FIRST_CODE) \
		and _tiles.has(Gen2Layout.CREDITS_THE_END_FIRST_CODE)


## The whole 160x144 screen. [param state] is [method Gen2Credits.frame_state].
func image(data: GameData, state: Dictionary) -> Image:
	if _gen1:
		return _image_gen1(data, state)
	var map: PackedInt32Array = state.get("map", PackedInt32Array())
	var slots: PackedInt32Array = state.get("attributes", PackedInt32Array())
	var indices: PackedByteArray = compose(map, int(state.get("block", -1)))
	var out: PackedInt32Array = Gen2PicImage.canvas(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
	if map.size() < COLUMNS * ROWS or slots.size() < COLUMNS * ROWS:
		return Gen2PicImage.canvas_image(out, Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
	var scene: int = int(state.get("scene", 0))
	var tables: Array[PackedInt32Array] = []
	for slot: int in [
		Gen2Credits.PALETTE_BANNER, Gen2Credits.PALETTE_BORDER, Gen2Credits.PALETTE_TEXT,
	]:
		var colors: PackedColorArray = palette(data, scene, slot)
		tables.append(
			PackedInt32Array() if colors.is_empty() else Gen2PicImage.lookup(colors)
		)
	var scroll: int = int(state.get("scroll", 0))
	var scrolled: Array = state.get("scroll_rows", [])
	for row: int in ROWS:
		var shift: int = scroll if row in scrolled else 0
		for column: int in COLUMNS:
			var table: PackedInt32Array = tables[
				clampi(slots[row * COLUMNS + column], 0, tables.size() - 1)
			]
			if table.is_empty():
				continue
			for y: int in TILE:
				var at_y: int = row * TILE + y
				var line: int = at_y * WIDTH
				for x: int in TILE:
					var at_x: int = column * TILE + x
					out[line + at_x] = table[indices[line + (at_x + shift) % WIDTH]]
	return Gen2PicImage.canvas_image(out, Gen2Screen.WIDTH, Gen2Screen.HEIGHT)


## `GetCreditsPalette`, whose Gold and Silver branch copies one four-colour
## palette into both of the slots it uses and then blacks out the border and text
## slot's last colour, which is the one the font's ink lands on.
func palette(data: GameData, scene: int, slot: int) -> PackedColorArray:
	var colors: PackedColorArray = data.credits_palette(scene, slot)
	if colors.size() < Gen2Layout.CREDITS_PALETTE_COLORS:
		return colors
	if slot == Gen2Credits.PALETTE_BORDER and not Gen2WorldState.is_crystal_profile(data):
		colors[Gen2Layout.CREDITS_PALETTE_COLORS - 1] = Color.BLACK
	return colors


## Resolves every tile number to pixels: the banner cell out of the mon run, the
## other three graphics out of the VRAM window, everything else out of the font.
func compose(map: PackedInt32Array, block: int) -> PackedByteArray:
	var indices := PackedByteArray()
	indices.resize(WIDTH * ROWS * TILE)
	if map.size() < COLUMNS * ROWS:
		return indices
	for row: int in ROWS:
		for column: int in COLUMNS:
			var tile: int = map[row * COLUMNS + column]
			var at := Vector2i(column * TILE, row * TILE)
			if tile < BANNER_TILES:
				_blit_banner(indices, block, tile, at)
			elif _tiles.has(tile):
				_blit(indices, _tiles[tile], at)
			elif tile != BLANK_TILE:
				font.draw_code(tile, indices, WIDTH, at.x, at.y, Gen2Text.FONT_MAIN)
	return indices


## `wCreditsBlankFrame2bpp` is sixteen tiles of solid colour 2, which is the
## background the four border mons are drawn on, so a cleared banner is that
## colour rather than blank.
func _blit_banner(
	indices: PackedByteArray, block: int, tile: int, at: Vector2i
) -> void:
	if block < 0:
		_fill(indices, at, Gen2Credits.BLANK_FRAME_INDEX)
		return
	var slot: int = block * BANNER_TILES + tile
	if (slot + 1) * TILE > _mons_width:
		return
	for y: int in TILE:
		for x: int in TILE:
			indices[(at.y + y) * WIDTH + at.x + x] = _mons[y * _mons_width + slot * TILE + x]


func _load_sheet(data: GameData, name: String, first_tile: int) -> void:
	var cells: Array = _cells(data, name)
	for tile: int in cells.size():
		_tiles[first_tile + tile] = cells[tile]


func _blit(indices: PackedByteArray, cell: PackedByteArray, at: Vector2i) -> void:
	for y: int in TILE:
		for x: int in TILE:
			indices[(at.y + y) * WIDTH + at.x + x] = cell[y * TILE + x]


func _fill(indices: PackedByteArray, at: Vector2i, index: int) -> void:
	for y: int in TILE:
		for x: int in TILE:
			indices[(at.y + y) * WIDTH + at.x + x] = index


## The tilemap through `rBGP`, the middle rows scrolled by the slide with the
## next mon riding in from BG column 20.
func _image_gen1(data: GameData, state: Dictionary) -> Image:
	var out: PackedInt32Array = Gen2PicImage.canvas(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
	var map: PackedInt32Array = state.get("map", PackedInt32Array())
	if map.size() < COLUMNS * ROWS:
		return Gen2PicImage.canvas_image(out, Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
	var indices: PackedByteArray = compose_gen1(map, StringName(state.get("sheet", &"")))
	var mon: Dictionary = _gen1_mon_cell(data, int(state.get("mon", 0)))
	var scroll: int = int(state.get("scroll", 0))
	var table: PackedInt32Array = Gen2PicImage.lookup(
		Gen2WorldPalette.fade_palette(_gen1_colors, int(state.get("bgp", 0)))
	)
	for y: int in Gen2Screen.HEIGHT:
		@warning_ignore("integer_division")
		var row: int = y / TILE
		var middle: bool = row >= Gen1Credits.MIDDLE_FIRST_ROW \
			and row < Gen1Credits.BAND_BOTTOM_ROW
		var line: int = y * WIDTH
		for x: int in WIDTH:
			var source: int = x + scroll if middle else x
			var index: int = 0
			if source < WIDTH:
				index = indices[line + source]
			elif not mon.is_empty():
				index = _gen1_mon_index(mon, source - Gen1Credits.MON_SOURCE_X, y)
			out[line + x] = table[index]
	return Gen2PicImage.canvas_image(out, Gen2Screen.WIDTH, Gen2Screen.HEIGHT)


## $7e solid, the loaded sheet as it is, and the font through
## `ShiftFontColorIndex`, which zeroes the low plane so ink is colour 2.
func compose_gen1(map: PackedInt32Array, sheet: StringName) -> PackedByteArray:
	var indices := PackedByteArray()
	indices.resize(WIDTH * ROWS * TILE)
	var cells: Array = _gen1_sheets.get(sheet, [])
	for row: int in ROWS:
		for column: int in COLUMNS:
			var tile: int = map[row * COLUMNS + column]
			var at := Vector2i(column * TILE, row * TILE)
			if tile == Gen1Credits.BLACK_TILE:
				_fill(indices, at, PokeTiles.INK)
			elif tile >= Gen1Layout.CREDITS_TILES_FIRST_CODE \
				and tile - Gen1Layout.CREDITS_TILES_FIRST_CODE < cells.size():
				_blit(indices, cells[tile - Gen1Layout.CREDITS_TILES_FIRST_CODE], at)
			elif tile != BLANK_TILE:
				font.draw_code(tile, indices, WIDTH, at.x, at.y, Gen2Text.FONT_MAIN)
				_shift_ink(indices, at)
	return indices


func _shift_ink(indices: PackedByteArray, at: Vector2i) -> void:
	for y: int in TILE:
		for x: int in TILE:
			var slot: int = (at.y + y) * WIDTH + at.x + x
			indices[slot] = indices[slot] & 2


## `LoadFrontSpriteByMonIndex` at `hlcoord 8, 6`, bottom-centred in its box.
func _gen1_mon_cell(data: GameData, species: int) -> Dictionary:
	if species <= 0 or data == null:
		return {}
	var pic: Dictionary = data.species_pic(species)
	if pic.is_empty():
		return {}
	var cell: Dictionary = Gen2PicImage.atlas_cell(
		data.atlas_indices(pic["atlas"]), data.atlas(pic["atlas"]), pic
	)
	if cell.is_empty():
		return {}
	var box: int = Gen2PicImage.FRONTPIC_TILES * TILE
	cell["left"] = Gen2PicImage.frontpic_pad_columns(
		int(cell["width"]) / TILE, false, RomRegistry.GEN1
	) * TILE
	cell["top"] = Gen1Credits.MON_ROW * TILE + box - int(cell["height"])
	cell["bottom"] = Gen1Credits.MON_ROW * TILE + box
	return cell


func _gen1_mon_index(mon: Dictionary, x: int, y: int) -> int:
	var px: int = x - int(mon["left"])
	var py: int = y - int(mon["top"])
	if px < 0 or py < 0 or px >= int(mon["width"]) or y >= int(mon["bottom"]):
		return 0
	return (mon["indices"] as PackedByteArray)[py * int(mon["width"]) + px]


static func _cells(data: GameData, name: String) -> Array:
	var indices: PackedByteArray = data.tile_indices(name)
	var out: Array = []
	if indices.is_empty():
		return out
	var width: int = indices.size() / TILE
	@warning_ignore("integer_division")
	for tile: int in width / TILE:
		var cell := PackedByteArray()
		cell.resize(TILE * TILE)
		for y: int in TILE:
			for x: int in TILE:
				cell[y * TILE + x] = indices[y * width + tile * TILE + x]
		out.append(cell)
	return out
