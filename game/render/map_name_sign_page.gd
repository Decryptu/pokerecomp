class_name Gen2MapNameSignPage
extends RefCounted

## `PlaceMapNameFrame` and `PlaceMapNameCenterAlign`: the sign a map entry raises,
## drawn out of `MapEntryFrameGFX`'s own fourteen tiles with the landmark's name
## centred on its lower interior row. Four rows of the window, which the hardware
## can only run to the bottom of the screen from, so `rWY` $70 is what puts the
## sign at the bottom. Crystal's own screen: Gold and Silver ship neither routine
## nor sheet. [method render_notice] is the same four rows carrying a mod's two
## lines and an icon, so a notice is vanilla by construction; a cache with no
## sheet falls back to the ordinary text-box frame.

const TILE: int = Gen2Font.TILE
const COLUMNS: int = 20
const ROWS: int = 4

## `PlaceMapNameSign`'s `ld a, $70 / ldh [rWY]`, in pixels down the screen.
const TOP: int = 0x70

## Offsets from `MAP_NAME_SIGN_START`, which is where `LoadMapNameSignGFX`
## requests the sheet: the strip is stored in the cartridge's order, so each is
## its index in it. Tile 0 is named by nothing.
const TILE_TOP_LEFT: int = 1
const TILE_TOP: int = 2
const TILE_TOP_RIGHT: int = 4
const TILE_LEFT_UPPER: int = 5
const TILE_LEFT_LOWER: int = 6
const TILE_BOTTOM_LEFT: int = 7
const TILE_BOTTOM: int = 8
const TILE_BOTTOM_RIGHT: int = 10
const TILE_RIGHT_UPPER: int = 11
const TILE_RIGHT_LOWER: int = 12
const TILE_INTERIOR: int = 13

## `PlaceMapNameCenterAlign`'s `hlcoord 0, 2`: the name sits on the second
## interior row, not the first.
const NAME_ROW: int = 2

## A notice's own interior: the icon is a 2x2 square in the first two columns
## inside the frame, and both lines start clear of it. The two interior rows are
## rows 1 and 2, the same pair the sign uses.
const NOTICE_ICON_TILES: int = 2
const NOTICE_ICON_AT: Vector2i = Vector2i(1, 1)
const NOTICE_TEXT_COLUMN: int = 4
const NOTICE_TITLE_ROW: int = 1
const NOTICE_LINE_ROW: int = 2
## What one line of a notice may be, which is what is left of the twenty columns
## once the frame and the icon have taken theirs. A line past this is refused
## rather than clipped, the way a battle message is.
const NOTICE_COLUMNS: int = COLUMNS - NOTICE_TEXT_COLUMN - 1


## `PAL_BG_TEXT`, the slot `InitMapSignAttrmap` writes over every tile of the
## sign. On a map that is the map's OWN palette 7, which `LoadMapPalettes` fills
## out of `bg_tiles.pal`'s per-environment, per-time-of-day "text" row: cream,
## cream, brown, black, which is what makes the sign read as wood. The blue
## `Palette_TextBG7` this used to draw with is `LoadOW_BGPal7`'s, and nothing in
## `MapSetupScript_Connection` or `RefreshMapSprites` runs that before the sign
## is placed.
const PAL_BG_TEXT: int = 7


## The sign holding [param name], or null when the cache carries no sheet, no
## font or no palette, which is every Gold and Silver cache.
##
## [param environment] and [param time_of_day] are the map's, since the slot the
## sign is drawn through is one of the eight the map loaded.
static func render(
	data: GameData,
	name: String,
	environment: int = Gen2WorldAPI.ENVIRONMENT_TOWN,
	time_of_day: int = Gen2WorldPalette.TIME_MORNING,
) -> Image:
	if data == null:
		return null
	var sheet: PackedByteArray = data.tile_indices("map_entry_sign")
	if sheet.size() < RomLayout.MAP_ENTRY_SIGN_TILES * TILE * TILE:
		return null
	var font: Gen2Font = Gen2Font.from_data(data)
	if font == null:
		return null
	var slots: Array = Gen2WorldPalette.palette_slots(environment, time_of_day)
	var palette: PackedColorArray = data.world_palette(int(slots[PAL_BG_TEXT]))
	if palette.size() < 4:
		palette = Gen2Palette.pic_palette(PackedColorArray([Color.WHITE, Color.BLACK]))
	var width: int = COLUMNS * TILE
	var indices := PackedByteArray()
	indices.resize(width * ROWS * TILE)
	var strip_width: int = RomLayout.MAP_ENTRY_SIGN_TILES * TILE
	for row: int in ROWS:
		var tiles: Array[int] = _row_tiles(row)
		for column: int in COLUMNS:
			Gen2Font.blit_slot(
				sheet, strip_width, tiles[column], indices, width,
				column * TILE, row * TILE
			)
	font.draw_text(name, indices, width, name_column(name) * TILE, NAME_ROW * TILE)
	return Gen2PicImage.from_indices(indices, width, ROWS * TILE, palette)


## The same four rows carrying [param title] over [param line], with the first
## two interior columns left clear for the icon the caller draws over them.
##
## [param frame_style] is the player's chosen text-box border, used only where
## the cache carries no `MapEntryFrameGFX`: that is every Gold and Silver cache,
## and a notice has to reach those players too. Null only when there is no font,
## which is a cache with no cartridge behind it at all.
static func render_notice(
	data: GameData,
	title: String,
	line: String,
	environment: int = Gen2WorldAPI.ENVIRONMENT_TOWN,
	time_of_day: int = Gen2WorldPalette.TIME_MORNING,
	frame_style: int = 0,
) -> Image:
	if data == null:
		return null
	var font: Gen2Font = Gen2Font.from_data(data)
	if font == null:
		return null
	var slots: Array = Gen2WorldPalette.palette_slots(environment, time_of_day)
	var palette: PackedColorArray = data.world_palette(int(slots[PAL_BG_TEXT]))
	if palette.size() < 4:
		palette = Gen2Palette.pic_palette(PackedColorArray([Color.WHITE, Color.BLACK]))
	var width: int = COLUMNS * TILE
	var indices := PackedByteArray()
	indices.resize(width * ROWS * TILE)
	var sheet: PackedByteArray = data.tile_indices("map_entry_sign")
	if sheet.size() >= RomLayout.MAP_ENTRY_SIGN_TILES * TILE * TILE:
		var strip_width: int = RomLayout.MAP_ENTRY_SIGN_TILES * TILE
		for row: int in ROWS:
			var tiles: Array[int] = _row_tiles(row)
			for column: int in COLUMNS:
				Gen2Font.blit_slot(
					sheet, strip_width, tiles[column], indices, width,
					column * TILE, row * TILE
				)
	else:
		_draw_text_frame(font, frame_style, indices, width)
	font.draw_text(
		title, indices, width, NOTICE_TEXT_COLUMN * TILE, NOTICE_TITLE_ROW * TILE,
		Gen2Text.FONT_MAIN, NOTICE_COLUMNS
	)
	font.draw_text(
		line, indices, width, NOTICE_TEXT_COLUMN * TILE, NOTICE_LINE_ROW * TILE,
		Gen2Text.FONT_MAIN, NOTICE_COLUMNS
	)
	return Gen2PicImage.from_indices(indices, width, ROWS * TILE, palette)


## The 16x16 a notice wears, out of the vocabulary an actor and a battle
## annotation already share. Null where the cache carries no art for what was
## asked, which draws a notice with no icon rather than a placeholder. `badge` is
## `TrainerCard_JohtoBadgesOAM`'s four tiles, 0 to 7, the Kanto eight having no
## art on the cartridge; `species` is [method GameData.species_icon_indices];
## `sprite` is an `OverworldSprites` row facing down; and `tile` is raw indices in
## [Gen2BattleAnnotations]' own shape, drawn in the frame's palette.
static func render_notice_icon(
	data: GameData, icon: Dictionary, time_of_day: int = Gen2WorldPalette.TIME_MORNING
) -> Image:
	if data == null or icon.is_empty():
		return null
	var side: int = NOTICE_ICON_TILES * TILE
	if icon.has("badge"):
		var badge: int = int(icon["badge"])
		if badge < 0 or badge >= BADGE_ART_ROWS:
			return null
		var tiles: PackedByteArray = data.tile_indices("card_badges")
		if tiles.is_empty():
			return null
		@warning_ignore("integer_division")
		var strip: int = tiles.size() / Gen2Tiles.TILE_PIXELS
		var table: PackedInt32Array = Gen2PicImage.lookup(data.card_badge_palette())
		var pixels: PackedInt32Array = Gen2PicImage.canvas(side, side)
		for quadrant: int in 4:
			Gen2PicImage.blit_tile(
				pixels, side, side, tiles, strip, badge * 4 + quadrant,
				(quadrant % 2) * TILE, (quadrant >> 1) * TILE, table, false, false, 0
			)
		return Gen2PicImage.canvas_image(pixels, side, side)
	if icon.has("species"):
		var species: int = int(icon["species"])
		var indices: PackedByteArray = data.species_icon_indices(species)
		var sprite: Gen2WorldSprite = data.overworld_icon(data.mon_menu_icon(species))
		if indices.is_empty() or sprite == null:
			return null
		return Gen2WorldSprite.image_for(
			sprite, indices,
			data.overworld_sprite_palette(sprite.default_palette, time_of_day)
		)
	if icon.has("sprite"):
		var row: Gen2WorldSprite = data.overworld_sprite(int(icon["sprite"]))
		if row == null:
			return null
		return Gen2WorldSprite.image_for(
			row, data.overworld_sprite_indices(row.number),
			data.overworld_sprite_palette(row.default_palette, time_of_day)
		)
	if icon.has("tile"):
		var raw: PackedByteArray = _notice_tile_indices(icon["tile"])
		if raw.is_empty():
			return null
		var slots: Array = Gen2WorldPalette.palette_slots(
			Gen2WorldAPI.ENVIRONMENT_TOWN, time_of_day
		)
		var colors: PackedColorArray = data.world_palette(int(slots[PAL_BG_TEXT]))
		if colors.size() < 4:
			return null
		var table: PackedInt32Array = Gen2PicImage.lookup(colors)
		var pixels: PackedInt32Array = Gen2PicImage.canvas(side, side)
		for pixel: int in raw.size():
			@warning_ignore("integer_division")
			pixels[pixel] = table[mini(raw[pixel], colors.size() - 1)]
		return Gen2PicImage.canvas_image(pixels, side, side)
	return null


## A raw 16x16 of palette indices, which is the one shape a mod may draw itself.
## An [Array] is accepted beside a [PackedByteArray] for the reason
## [method Gen2BattleAnnotations._tile_bytes] accepts one: a square written out
## as a literal in a mod's source is an Array.
static func _notice_tile_indices(value: Variant) -> PackedByteArray:
	var side: int = NOTICE_ICON_TILES * TILE
	var out := PackedByteArray()
	if value is PackedByteArray:
		out = value
	elif value is Array:
		for entry: Variant in value as Array:
			if entry is not int and entry is not float:
				return PackedByteArray()
			out.append(clampi(int(entry), 0, Gen2Tiles.INK))
	else:
		return PackedByteArray()
	if out.size() != side * side:
		return PackedByteArray()
	for index: int in out:
		if index > Gen2Tiles.INK:
			return PackedByteArray()
	return out


## `TrainerCard_JohtoBadgesOAM`'s own length. `TrainerCard_KantoBadgesOAM` reuses
## the same eight pictures, so a Kanto badge has no art of its own to ask for.
const BADGE_ART_ROWS: int = 8


## `Textbox`'s own border, for a cache with no `MapEntryFrameGFX`: the same four
## rows, drawn with the six frame tiles every screen in the game already uses.
static func _draw_text_frame(
	font: Gen2Font, frame_style: int, indices: PackedByteArray, width: int
) -> void:
	var first: int = RomLayout.FRAME_FIRST_CODE
	for column: int in COLUMNS:
		var top: int = first + RomLayout.FRAME_HORIZONTAL
		var bottom: int = top
		if column == 0:
			top = first + RomLayout.FRAME_TOP_LEFT
			bottom = first + RomLayout.FRAME_BOTTOM_LEFT
		elif column == COLUMNS - 1:
			top = first + RomLayout.FRAME_TOP_RIGHT
			bottom = first + RomLayout.FRAME_BOTTOM_RIGHT
		font.draw_frame_code(frame_style, top, indices, width, column * TILE, 0)
		font.draw_frame_code(
			frame_style, bottom, indices, width, column * TILE, (ROWS - 1) * TILE
		)
	for row: int in range(1, ROWS - 1):
		for column: int in [0, COLUMNS - 1]:
			font.draw_frame_code(
				frame_style, first + RomLayout.FRAME_VERTICAL,
				indices, width, column * TILE, row * TILE
			)


## `PlaceMapNameCenterAlign`: `(SCREEN_WIDTH - length) >> 1`, where the length is
## `.GetNameLength`'s, one per character placed.
static func name_column(name: String) -> int:
	return maxi(0, (COLUMNS - Gen2Text.encoded_length(name)) >> 1)


## One row of the frame. The top and bottom rows are `.FillTopBottom`, whose loop
## writes its first pair from the incremented tile and every pair after that in
## twos: two of `tile + 1`, then four repeats of `tile, tile, tile + 1,
## tile + 1`.
static func _row_tiles(row: int) -> Array[int]:
	match row:
		0:
			return _edge_row(TILE_TOP_LEFT, TILE_TOP, TILE_TOP_RIGHT)
		ROWS - 1:
			return _edge_row(TILE_BOTTOM_LEFT, TILE_BOTTOM, TILE_BOTTOM_RIGHT)
		1:
			return _interior_row(TILE_LEFT_UPPER, TILE_RIGHT_UPPER)
	return _interior_row(TILE_LEFT_LOWER, TILE_RIGHT_LOWER)


static func _edge_row(left: int, fill: int, right: int) -> Array[int]:
	var out: Array[int] = [left, fill + 1, fill + 1]
	while out.size() < COLUMNS - 1:
		out.append_array([fill, fill, fill + 1, fill + 1])
	out.append(right)
	return out


static func _interior_row(left: int, right: int) -> Array[int]:
	var out: Array[int] = [left]
	for _column: int in COLUMNS - 2:
		out.append(TILE_INTERIOR)
	out.append(right)
	return out
