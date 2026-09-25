class_name Gen2WorldRenderer
extends Node2D

## Draws the visible map page in hardware pixels: the cartridge's 160x144, or a
## larger [member Gen2WorldAPI.view_pixels] with the connected maps on
## [Gen2WorldMapLayer] quads and the border block filling the rest.

const PLAYER_COLOR: Color = Color("#d34a5a")
const FALLBACK_BACKGROUND: Color = Color("#f5f1d8")

var _world: Gen2WorldAPI = null
var _animation: Gen2WorldAnimation = null
## Every sprite and background edit this view draws. See [Gen2WorldDrawList].
var _draw_list: Gen2WorldDrawList = null
var _anim_textures: Dictionary = {}
var _time_of_day: int = Gen2WorldPalette.TIME_MORNING
var _atlas: ImageTexture = null
## The coloured tile strips in use this frame, keyed by the pair that chooses
## their colours: see [method _atlas_for]. The current map's is [member _atlas].
var _atlases: Dictionary = {}
## The map quads, in draw order: the void fill, each connected map, then this
## map's own block buffer. Pooled rather than rebuilt, since the camera moves
## every frame and nothing about a quad but its position does.
var _map_layers: Array[Gen2WorldMapLayer] = []
var _block_textures: Dictionary = {}
var _tiles_textures: Dictionary = {}
## `wOverworldMapBlocks` itself: the map plus the three-block margin
## `ChangeMap` leaves, resolved through [method Gen2WorldAPI.drawn_block_at] so
## the connection strips in it are the cartridge's own.
var _buffer_texture: ImageTexture = null
var _buffer_revision: int = -1
var _background_color: Color = FALLBACK_BACKGROUND
var _actor_textures: Dictionary = {}
var _priority_atlas: ImageTexture = null
var _priority_indices: PackedByteArray = PackedByteArray()
var _effect_textures: Dictionary = {}
## The palette order the map fades are one step of, and `FillWhiteBGColor`
## beside it. The identity order is every other frame of the game.
var _fade_order: int = Gen2WorldPalette.FADE_IDENTITY
var _fade_white_fill: bool = false


func set_world(world: Gen2WorldAPI, animation: Gen2WorldAnimation = null) -> void:
	_world = world
	_animation = animation
	_actor_textures.clear()
	_effect_textures.clear()
	_block_textures.clear()
	_buffer_texture = null
	_buffer_revision = -1
	_rebuild_atlas()
	refresh()


## `DoBattleTransition`'s own screen: the cells it has written, the two tiles it
## draws them with and the palette it floods the map with, or an empty one when
## it floods nothing.
var _transition_cells: PackedByteArray = PackedByteArray()
## Which screen cell each cell draws its map tile from, for a squeeze that moves
## `wTileMap` rather than blacking it out.
var _transition_sources: PackedInt32Array = PackedInt32Array()
var _transition_tiles: PackedByteArray = PackedByteArray()
var _transition_palette: PackedColorArray = PackedColorArray()
## `StartTrainerBattle_Flash` writes `wBGP` and calls `DmgToCgbBGPals` alone, so
## the three flash passes are a background order and the sprites over them keep
## their own colours. The map fade is the other shape and goes through
## [method set_fade], which is both.
var _transition_order: int = Gen2BattleTransition.IDENTITY
var _poison_flash: bool = false
## The one patterned tile of the pair, cached rather than drawn pixel by pixel:
## the transition is redrawn once for the screen and again over the lower half of
## every sprite standing in grass.
var _transition_textures: Dictionary = {}


## Gen2ModHost.RENDERER_DRAW_LIST_METHOD. Without one the map is drawn bare.
func set_draw_list(draw_list: Gen2WorldDrawList) -> void:
	_draw_list = draw_list
	queue_redraw()


## Selects the palette rows this view draws with. The world owns the clock and
## object visibility; a renderer only reads them, so a second view of the same
## world cannot change what the first one sees.
func set_time_of_day(time_of_day: int) -> void:
	_time_of_day = clampi(time_of_day, 0, 3)
	_actor_textures.clear()
	_effect_textures.clear()
	_rebuild_atlas()
	queue_redraw()


## Gen2ModHost.RENDERER_FADE_METHOD: one step of `FadeOutToWhite` or
## `FadeInFromWhite`, a palette order over every palette and `FillWhiteBGColor`
## on the way out. The host spends the frames whether or not a view takes this.
func set_fade(order: int, white_fill: bool = false) -> void:
	if order == _fade_order and white_fill == _fade_white_fill:
		return
	_fade_order = order
	_fade_white_fill = white_fill
	_actor_textures.clear()
	_effect_textures.clear()
	_anim_textures.clear()
	_rebuild_atlas()
	queue_redraw()


## Repaints the tiles the last animation frame rewrote, one or two a frame; a
## palette command recolours every tile of its row and is still a repaint.
func refresh_animation() -> void:
	if _animation == null or _atlas == null:
		_rebuild_atlas()
		queue_redraw()
		return
	var recolour: bool = _animation.palette_changed()
	var changed: PackedInt32Array = _animation.changed_tiles()
	if not recolour and changed.is_empty():
		return
	var animated: PackedByteArray = _animation.current_indices()
	for entry: Dictionary in _atlases.values():
		_repaint_atlas(entry, animated, changed, recolour)
	# The priority strip is the map being walked on, not whichever cached strip
	# the loop ended on: a connected map in another group has its own roof.
	var current: Dictionary = _atlas_for(_world.current_map, _world.current_tileset)
	if recolour and not current.is_empty():
		var palettes: Array = current["palettes"]
		if not palettes.is_empty() and (palettes[0] as PackedColorArray).size() >= 1:
			_background_color = (palettes[0] as PackedColorArray)[0]
	_priority_indices = current["indices"] if not current.is_empty() else animated
	_priority_atlas = null
	queue_redraw()


## One cached strip through this frame's graphics and, when [param recolour], its
## own palette rows read again. Only the tiles whose colours or whose pixels
## actually moved are written.
func _repaint_atlas(
	entry: Dictionary, animated: PackedByteArray, changed: PackedInt32Array,
	recolour: bool
) -> void:
	var tiles: int = int(entry["tile_count"])
	var indices: PackedByteArray = entry["indices"]
	var repaint := PackedByteArray()
	repaint.resize(tiles)
	var any: bool = false
	if bool(entry["animated"]):
		# The roof stands over `vTiles2 tile $0a` for as long as the map is
		# loaded, so an animation pass rebuilds the strip under it rather than
		# replacing it.
		indices = _world.data.roofed_tile_indices(
			animated, int(entry["roof"]), tiles
		)
		entry["indices"] = indices
		for tile: int in changed:
			if tile >= 0 and tile < tiles:
				repaint[tile] = 1
				any = true
	if recolour:
		var palettes: Array = _tile_palettes_for(entry["map"], entry["tileset"])
		var tables: Array = _palette_tables(palettes)
		var was: Array = entry["tables"]
		entry["palettes"] = palettes
		entry["tables"] = tables
		for tile: int in tiles:
			if tile < was.size() and tables[tile] == was[tile]:
				continue
			repaint[tile] = 1
			any = true
	if not any:
		return
	var words: PackedInt32Array = entry["words"]
	var background: int = Gen2PicImage.lookup(
		PackedColorArray([_background_color])
	)[0]
	for tile: int in tiles:
		if repaint[tile] != 0:
			_paint_tile(words, tiles, indices, entry["tables"], background, tile)
	entry["words"] = words
	(entry["texture"] as ImageTexture).update(
		Gen2PicImage.canvas_image(words, tiles * PokeTiles.TILE_WIDTH, PokeTiles.TILE_HEIGHT)
	)


func _rebuild_atlas() -> void:
	_atlases.clear()
	_atlas = null
	_background_color = FALLBACK_BACKGROUND
	if _world == null or _world.data == null or _world.current_tileset == null:
		return
	var entry: Dictionary = _atlas_for(_world.current_map, _world.current_tileset)
	if entry.is_empty():
		return
	var palettes: Array = entry["palettes"]
	if not palettes.is_empty() and (palettes[0] as PackedColorArray).size() >= 1:
		_background_color = (palettes[0] as PackedColorArray)[0]
	_atlas = entry["texture"]
	# Built on demand: only an object standing in grass reads it.
	_priority_indices = entry["indices"]
	_priority_atlas = null
	# The quads hold the strip they were configured with, and this is a new one.
	_sync_map_layers()


## The coloured tile strip a map draws with, cached on its tileset and the
## environment `GetMapPalette` reads, so a connected map sharing both shares it.
func _atlas_for(map: Gen2WorldMap, tileset: Gen2WorldTileset) -> Dictionary:
	if map == null or tileset == null or _world == null or _world.data == null:
		return {}
	## Packed rather than formatted: `_sync_map_layers` asks for one of these per
	## connected map on every frame the camera moves.
	var key: int = tileset.number | (map.environment << 8) | (map.group << 16)
	if _atlases.has(key):
		return _atlases[key]
	var indices: PackedByteArray = _world.data.world_tileset_indices(tileset.number)
	var animated: bool = _animation != null and _world.current_tileset != null \
		and tileset.number == _world.current_tileset.number \
		and not _animation.current_indices().is_empty()
	if animated:
		indices = _animation.current_indices()
	if indices.size() < tileset.tile_count * PokeTiles.TILE_PIXELS:
		return {}
	var roof: int = _world.data.map_roof(map, tileset)
	indices = _world.data.roofed_tile_indices(indices, roof, tileset.tile_count)
	var palettes: Array = _tile_palettes_for(map, tileset)
	var tables: Array = _palette_tables(palettes)
	var background: int = Gen2PicImage.lookup(
		PackedColorArray([_background_color])
	)[0]
	var words: PackedInt32Array = Gen2PicImage.canvas(
		tileset.tile_count * PokeTiles.TILE_WIDTH, PokeTiles.TILE_HEIGHT
	)
	for tile: int in tileset.tile_count:
		_paint_tile(words, tileset.tile_count, indices, tables, background, tile)
	var entry: Dictionary = {
		"texture": ImageTexture.create_from_image(Gen2PicImage.canvas_image(
			words, tileset.tile_count * PokeTiles.TILE_WIDTH, PokeTiles.TILE_HEIGHT
		)),
		## The strip before its conversion, so an animation frame repaints the
		## one or two tiles it rewrote rather than recolouring the whole run.
		"words": words,
		"palettes": palettes,
		"tables": tables,
		## Kept so a palette step reads the rows this strip was coloured through
		## again rather than rebuilding the cache to find out.
		"map": map,
		"tileset": tileset,
		"indices": indices,
		"animated": animated,
		"roof": roof,
		"tile_count": tileset.tile_count,
	}
	_atlases[key] = entry
	return entry


## The one palette `.pal_loop` puts every background tile on, through whatever
## order the flash is on. Empty when the transition floods nothing, which is
## every wild battle: those wedges take the palette their own cell was drawn in.
func flood_palette() -> PackedColorArray:
	if _transition_palette.is_empty():
		return PackedColorArray()
	return Gen2WorldPalette.fade_palette(
		Gen2WorldPalette.fade_palette(_transition_palette, _fade_order), _transition_order
	)


## The palettes the current map's tile strip was coloured with, which
## [method _atlas_for] already resolved and kept.
func _current_palettes() -> Array:
	var entry: Dictionary = _atlas_for(_world.current_map, _world.current_tileset)
	return entry["palettes"] if not entry.is_empty() else []


## `LoadPoisonBGPals` writes `wBGPals2` alone, so the sprites keep their colours.
func set_poison_flash(on: bool) -> void:
	if on == _poison_flash:
		return
	_poison_flash = on
	_rebuild_atlas()
	queue_redraw()


func _tile_palettes_for(map: Gen2WorldMap, tileset: Gen2WorldTileset) -> Array:
	if _poison_flash:
		var flooded: Array = []
		var flash: PackedColorArray = Gen2WorldPalette.poison_flash_palette()
		for _tile: int in tileset.tile_count:
			flooded.append(flash)
		return flooded
	## `StartTrainerBattle_LoadPokeBallGraphics.pal_loop` puts every background
	## tile on `PAL_BG_TEXT` and fills that one palette, which is why a trainer
	## transition draws the whole map in four colours.
	if not _transition_palette.is_empty():
		var flooded: Array = []
		var flood: PackedColorArray = flood_palette()
		for _tile: int in tileset.tile_count:
			flooded.append(flood)
		return flooded
	var rows: Array = Gen2WorldPalette.tile_palettes(
		_world.data,
		map,
		tileset,
		_time_of_day,
		_animation.water_palette_color() if _animation != null else -1,
		_animation.cave_palette_color() if _animation != null else -1,
		_fade_order,
		_fade_white_fill,
		_world.gen1_last_map(),
		_world.gen1_map_pal_offset,
	)
	if _transition_order == Gen2BattleTransition.IDENTITY:
		return rows
	var faded: Array = []
	for row: PackedColorArray in rows:
		faded.append(Gen2WorldPalette.fade_palette(row, _transition_order))
	return faded


## One tile of the strip, coloured. Index 0 is a colour here rather than a hole:
## the atlas is the background layer, and the cartridge's transparent index
## belongs to sprites.
func _paint_tile(
	words: PackedInt32Array, tiles: int, indices: PackedByteArray, tables: Array,
	background: int, tile: int
) -> void:
	var width: int = tiles * PokeTiles.TILE_WIDTH
	var table: PackedInt32Array = tables[tile] if tile < tables.size() \
		else PackedInt32Array()
	var colors: int = table.size()
	var left: int = tile * PokeTiles.TILE_WIDTH
	for y: int in PokeTiles.TILE_HEIGHT:
		var row: int = y * width + left
		for x: int in PokeTiles.TILE_WIDTH:
			var color_index: int = indices[row + x]
			words[row + x] = table[color_index] if color_index < colors else background


## One [method Gen2PicImage.lookup] per palette row, built once for a repaint
## and trimmed to the row's length so a colour it lacks falls through.
func _palette_tables(palettes: Array) -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for entry: Variant in palettes:
		var palette: PackedColorArray = entry
		if seen.has(palette):
			out.append(seen[palette])
			continue
		var table: PackedInt32Array = Gen2PicImage.lookup(palette)
		table.resize(palette.size())
		seen[palette] = table
		out.append(table)
	return out


## `DoBattleTransition` over the map: [param tiles] are `LoadBattleTransitionGFX`'s
## two, [param palette] the trainer flood (empty on a wild, whose black is the
## cell's own colour 3) and [param order] the flash's `wBGP`. Which sprites it
## leaves is the draw list's.
func set_transition(
	cells: PackedByteArray, tiles: PackedByteArray, palette: PackedColorArray,
	_sprites: int = Gen2BattleTransition.SPRITES_ALL, _opponent: int = -1,
	order: int = Gen2BattleTransition.IDENTITY,
	sources: PackedInt32Array = PackedInt32Array()
) -> void:
	var was: PackedColorArray = _transition_palette
	var was_order: int = _transition_order
	_transition_sources = sources
	_transition_cells = cells
	_transition_tiles = tiles
	_transition_palette = palette
	_transition_order = order
	if palette != was or order != was_order:
		_transition_textures.clear()
		_actor_textures.clear()
		_effect_textures.clear()
		_anim_textures.clear()
		_rebuild_atlas()
	queue_redraw()


func clear_transition() -> void:
	if _transition_cells.is_empty() and _transition_palette.is_empty():
		return
	var was_flooding: bool = not _transition_palette.is_empty()
	_transition_cells = PackedByteArray()
	_transition_sources = PackedInt32Array()
	_transition_tiles = PackedByteArray()
	_transition_palette = PackedColorArray()
	_transition_textures.clear()
	if _transition_order != Gen2BattleTransition.IDENTITY:
		_transition_order = Gen2BattleTransition.IDENTITY
		was_flooding = true
	if was_flooding:
		_actor_textures.clear()
		_effect_textures.clear()
		_anim_textures.clear()
		_rebuild_atlas()
	queue_redraw()


## The transition's cells are `wTilemap`, under every sprite until
## `StartTrainerBattle_Finish`; [param priority] is the OAM_PRIO pass, where
## colour 0 is left transparent.
func _draw_transition(
	camera_pixels: Vector2, clip: Rect2 = Rect2(), priority: bool = false
) -> void:
	var black: int = Gen2BattleTransition.CELL_BLACK
	var flood: PackedColorArray = flood_palette()
	## The strip's own palettes, not a fresh resolve: this runs again over the
	## lower half of every sprite standing in grass, and building one palette
	## table per sprite was most of such a frame.
	var palettes: Array = [] if not flood.is_empty() else _current_palettes()
	## The screen's own top-left corner, which is the surface's until a view
	## larger than the hardware's puts the twenty by eighteen cells in the middle
	## of something wider.
	var origin: Vector2 = screen_offset()
	var screen_tile := Vector2i(
		floori((camera_pixels.x + origin.x) / float(PokeTiles.TILE_WIDTH)),
		floori((camera_pixels.y + origin.y) / float(PokeTiles.TILE_HEIGHT)),
	)
	## The whole screen, or the few cells a sprite's own lower half falls in.
	var first := Vector2i.ZERO
	var last := Vector2i(Gen2BattleTransition.COLUMNS - 1, Gen2BattleTransition.ROWS - 1)
	if priority:
		first = Vector2i(
			floori((clip.position.x - origin.x) / PokeTiles.TILE_WIDTH),
			floori((clip.position.y - origin.y) / PokeTiles.TILE_HEIGHT),
		)
		last = Vector2i(
			mini(ceili((clip.end.x - origin.x) / PokeTiles.TILE_WIDTH), last.x),
			mini(ceili((clip.end.y - origin.y) / PokeTiles.TILE_HEIGHT), last.y),
		)
	for y: int in range(maxi(first.y, 0), last.y + 1):
		for x: int in range(maxi(first.x, 0), last.x + 1):
			var index: int = y * Gen2BattleTransition.COLUMNS + x
			var cell: int = int(_transition_cells[index])
			## A cell the squeeze filled is black whatever it was drawing before.
			var source: int = -1 if cell == Gen2BattleTransition.CELL_BLACK \
				else _transition_source(index)
			if cell == Gen2BattleTransition.CELL_NONE and source < 0:
				continue
			var at := Rect2(
				origin + Vector2(x * PokeTiles.TILE_WIDTH, y * PokeTiles.TILE_HEIGHT),
				Vector2(PokeTiles.TILE_WIDTH, PokeTiles.TILE_HEIGHT)
			)
			var covered: Rect2 = at if not priority else at.intersection(clip)
			if covered.size.x <= 0.0 or covered.size.y <= 0.0:
				continue
			if source >= 0:
				_draw_moved_tile(screen_tile, source, at, covered)
				continue
			var palette: PackedColorArray = flood
			if palette.is_empty():
				var tile: int = _drawn_tile_at(screen_tile.x + x, screen_tile.y + y)
				palette = palettes[tile] if tile >= 0 and tile < palettes.size() \
					else PackedColorArray()
			if cell == black or _transition_tiles.is_empty():
				draw_rect(covered, palette[3] if palette.size() > 3 else Color.BLACK, true)
				continue
			var texture: Texture2D = _transition_texture(palette, priority)
			if texture == null:
				continue
			draw_texture_rect_region(
				texture, covered, Rect2(covered.position - at.position, covered.size)
			)


## `VermilionDock_SyncScrollWithLY`: lines $50 to $7F scroll by the drifts
## done, over the view's whole width, and [method Gen2WorldDrawList.drawn_tile_at]
## answers the columns brought in past the screen's twentieth.
func _draw_ss_anne_band(_background: Vector2) -> void:
	var scroll: Dictionary = _draw_list.band_scroll() if _draw_list != null else {}
	var found: Dictionary = _draw_list.band() if _draw_list != null else {}
	if _atlas == null or scroll.is_empty() or found.is_empty():
		return
	var offset: int = int(scroll["offset"])
	var screen: Vector2 = screen_offset()
	var first_x: int = int(found["first_column"])
	var first_y: int = (found["rows"] as Vector2i).x - int(scroll["top"]) / PokeTiles.TILE_HEIGHT
	var shift: int = posmod(offset, PokeTiles.TILE_WIDTH)
	var top: int = int(scroll["top"]) / PokeTiles.TILE_HEIGHT
	var bottom: int = int(scroll["bottom"]) / PokeTiles.TILE_HEIGHT
	var band := Rect2(
		Vector2(0, screen.y + int(scroll["top"])),
		Vector2(view_pixels().x, int(scroll["bottom"]) - int(scroll["top"]))
	)
	var size := Vector2(PokeTiles.TILE_WIDTH, PokeTiles.TILE_HEIGHT)
	var left: int = -int(screen.x) / PokeTiles.TILE_WIDTH
	var right: int = (view_pixels().x - int(screen.x)) / PokeTiles.TILE_WIDTH + 1
	for row: int in range(top, bottom):
		for column: int in range(left, right):
			var source: int = column + offset / PokeTiles.TILE_WIDTH
			var tile: int = _drawn_tile_at(first_x + source, first_y + row)
			if tile < 0:
				continue
			var at := Rect2(
				screen + Vector2(column * PokeTiles.TILE_WIDTH - shift, row * PokeTiles.TILE_HEIGHT),
				size
			)
			var covered: Rect2 = at.intersection(band)
			if covered.size.x <= 0.0:
				continue
			draw_texture_rect_region(_atlas, covered, Rect2(
				Vector2(tile * PokeTiles.TILE_WIDTH, 0) + (covered.position - at.position), covered.size
			))


## Where the cell at [param index] takes its map tile from, or -1 for its own.
func _transition_source(index: int) -> int:
	if index >= _transition_sources.size():
		return -1
	var source: int = int(_transition_sources[index])
	return -1 if source < 0 or source == index else source


## The map tile another screen cell was drawing, painted over this one.
func _draw_moved_tile(
	screen_tile: Vector2i, source: int, at: Rect2, covered: Rect2
) -> void:
	if _atlas == null:
		return
	@warning_ignore("integer_division")
	var tile: int = _drawn_tile_at(
		screen_tile.x + source % Gen2BattleTransition.COLUMNS,
		screen_tile.y + source / Gen2BattleTransition.COLUMNS,
	)
	if tile < 0:
		return
	draw_texture_rect_region(
		_atlas,
		covered,
		Rect2(
			Vector2(tile * PokeTiles.TILE_WIDTH, 0) + (covered.position - at.position),
			covered.size,
		),
	)


## `BATTLETRANSITION_SQUARE`, the one tile of the pair that has a pattern in it.
## [param transparent_zero] is the OAM_PRIO pass, where the tile's colour 0
## pixels lose to the sprite under them.
func _transition_texture(
	palette: PackedColorArray, transparent_zero: bool
) -> Texture2D:
	if _transition_tiles.size() < PokeTiles.TILE_PIXELS:
		return null
	var key: String = "%d:%d" % [hash(palette), int(transparent_zero)]
	var texture: Texture2D = _transition_textures.get(key, null)
	if texture != null:
		return texture
	var image := Image.create(
		PokeTiles.TILE_WIDTH, PokeTiles.TILE_HEIGHT, false, Image.FORMAT_RGBA8
	)
	for y: int in PokeTiles.TILE_HEIGHT:
		for x: int in PokeTiles.TILE_WIDTH:
			var index: int = int(_transition_tiles[y * PokeTiles.TILE_WIDTH + x])
			var color: Color = palette[index] if index < palette.size() else Color.BLACK
			if index == 0 and transparent_zero:
				color.a = 0.0
			image.set_pixel(x, y, color)
	texture = ImageTexture.create_from_image(image)
	_transition_textures[key] = texture
	return texture


func refresh() -> void:
	_sync_map_layers()
	queue_redraw()


## The scroll the map is drawn at. `StepFunction_ScreenShake` reaches hSCY and
## nothing else, so an earthquake moves the background under the sprites standing
## on it rather than moving the picture.
func _background_camera() -> Vector2:
	var camera: Vector2 = _camera_pixels()
	return camera if _draw_list == null else camera + _draw_list.background_offset()


## The camera, snapped to the finest step this surface can draw: at six screen
## pixels to a hardware one the map scrolls six times as often, and one snap
## shared by every quad and sprite is what stops them crawling against each
## other. At one step this is [method Gen2WorldAPI.view_origin_pixels] exactly.
func _camera_pixels() -> Vector2:
	var steps: float = float(_subpixel_steps())
	return (_world.view_origin_subpixel() * steps).round() / steps


func _subpixel_steps() -> int:
	var surface: Viewport = get_viewport()
	if surface == null:
		return 1
	return maxi(1, int(surface.canvas_transform.get_scale().x))


## The map quads under this frame's camera: the border block, each connected
## map furthest first, then `wOverworldMapBlocks`, whose three-block margin a
## whole neighbour map would overdraw past the strip's `length`.
func _sync_map_layers() -> void:
	if _world == null or _world.current_map == null or _world.current_tileset == null \
		or _atlas == null:
		_show_map_layers(0)
		return
	var map: Gen2WorldMap = _world.current_map
	var tileset: Gen2WorldTileset = _world.current_tileset
	var camera: Vector2 = _background_camera()
	var view := Vector2(view_pixels())
	var block_pixels: int = Gen2Layout.MAP_BLOCK_CELL_WIDTH * Gen2WorldAPI.CELL_PIXELS
	var used: int = 0
	var zero_is_border: bool = Gen2WorldAPI.drawn_block_of(_world.data, map, 0) != 0

	var fill: Gen2WorldMapLayer = _map_layer(used)
	used += 1
	fill.configure(
		_atlas, _one_block_texture(), _tiles_texture(tileset), Vector2i.ZERO,
		map.border_block, tileset.block_count, tileset.tile_count, true,
	)
	fill.place(Vector2.ZERO, view, camera)

	if view.x > Gen2WorldAPI.VIEW_PIXELS.x or view.y > Gen2WorldAPI.VIEW_PIXELS.y:
		var placements: Array = _world.map_placements().values()
		placements.reverse()
		for placement: Dictionary in placements:
			var near: Gen2WorldMap = placement["map"]
			var near_tileset: Gen2WorldTileset = _world.data.world_tileset(near.tileset)
			if near_tileset == null:
				continue
			var at: Vector2 = Vector2(placement["origin"] as Vector2i) * float(block_pixels) \
				- camera
			var size := Vector2(near.width_blocks, near.height_blocks) * float(block_pixels)
			if not Rect2(at, size).intersects(Rect2(Vector2.ZERO, view)):
				continue
			var blocks: ImageTexture = _blocks_texture(near)
			var strip: Dictionary = _atlas_for(near, near_tileset)
			if blocks == null or strip.is_empty():
				continue
			var layer: Gen2WorldMapLayer = _map_layer(used)
			used += 1
			layer.configure(
				strip["texture"], blocks, _tiles_texture(near_tileset),
				Vector2i(near.width_blocks, near.height_blocks), near.border_block,
				near_tileset.block_count, near_tileset.tile_count, false, zero_is_border,
			)
			layer.place(at, size)

	var buffer: ImageTexture = _map_buffer_texture()
	if buffer != null:
		var span := Vector2i(
			map.width_blocks + 2 * Gen2WorldAPI.BUFFER_BLOCKS,
			map.height_blocks + 2 * Gen2WorldAPI.BUFFER_BLOCKS,
		)
		var layer: Gen2WorldMapLayer = _map_layer(used)
		used += 1
		layer.configure(
			_atlas, buffer, _tiles_texture(tileset), span, map.border_block,
			tileset.block_count, tileset.tile_count, false, zero_is_border,
		)
		layer.place(
			Vector2.ONE * float(-Gen2WorldAPI.BUFFER_BLOCKS * block_pixels) - camera,
			Vector2(span) * float(block_pixels),
		)
	_show_map_layers(used)


func _map_layer(index: int) -> Gen2WorldMapLayer:
	while _map_layers.size() <= index:
		var layer := Gen2WorldMapLayer.new()
		_map_layers.append(layer)
		add_child(layer)
	return _map_layers[index]


func _show_map_layers(count: int) -> void:
	for index: int in _map_layers.size():
		_map_layers[index].visible = index < count


## `wOverworldMapBlocks`: the map's own blocks with the three-block margin
## around them, every byte through [method Gen2WorldAPI.drawn_block_at], so the
## connection strips and the border fill in it are the cartridge's own.
func _map_buffer_texture() -> ImageTexture:
	if _world == null or _world.current_map == null:
		return null
	if _buffer_texture != null and _buffer_revision == _world.block_revision:
		return _buffer_texture
	var map: Gen2WorldMap = _world.current_map
	var span := Vector2i(
		map.width_blocks + 2 * Gen2WorldAPI.BUFFER_BLOCKS,
		map.height_blocks + 2 * Gen2WorldAPI.BUFFER_BLOCKS,
	)
	if span.x <= 0 or span.y <= 0:
		return null
	var bytes := PackedByteArray()
	bytes.resize(span.x * span.y)
	for y: int in span.y:
		var row: int = y * span.x
		for x: int in span.x:
			bytes[row + x] = _world.drawn_block_at(
				x - Gen2WorldAPI.BUFFER_BLOCKS, y - Gen2WorldAPI.BUFFER_BLOCKS
			) & 0xFF
	_buffer_texture = Gen2WorldMapLayer.block_texture(bytes, span)
	_buffer_revision = _world.block_revision
	return _buffer_texture


## A connected map's own block list, which nothing a run does edits: only the
## loaded map takes `changeblock`.
func _blocks_texture(map: Gen2WorldMap) -> ImageTexture:
	var key: String = "%d:%d" % [map.group, map.number]
	if _block_textures.has(key):
		return _block_textures[key]
	var texture: ImageTexture = Gen2WorldMapLayer.block_texture(
		map.blocks, Vector2i(map.width_blocks, map.height_blocks)
	)
	_block_textures[key] = texture
	return texture


## The tileset's metatile table as sixteen bytes a block, with anything past the
## tile strip folded to zero the way [method Gen2WorldTileset.tile_index] does.
func _tiles_texture(tileset: Gen2WorldTileset) -> ImageTexture:
	if _tiles_textures.has(tileset.number):
		return _tiles_textures[tileset.number]
	var slots: int = Gen2Layout.MAP_BLOCK_TILE_WIDTH * Gen2Layout.MAP_BLOCK_TILE_WIDTH
	var bytes := PackedByteArray()
	bytes.resize(slots * maxi(tileset.block_count, 1))
	for at: int in bytes.size():
		var index: int = tileset.meta[at] if at < tileset.meta.size() else 0
		bytes[at] = index if index < tileset.tile_count else 0
	var texture: ImageTexture = Gen2WorldMapLayer.block_texture(
		bytes, Vector2i(slots, maxi(tileset.block_count, 1))
	)
	_tiles_textures[tileset.number] = texture
	return texture


## A one-block stand-in for the void fill's block sampler, which its own quad
## never reads: every pixel of that quad is outside the map it declares.
func _one_block_texture() -> ImageTexture:
	if not _block_textures.has("void"):
		_block_textures["void"] = Gen2WorldMapLayer.block_texture(
			PackedByteArray([0]), Vector2i.ONE
		)
	return _block_textures["void"]


## The drawn surface in hardware pixels, which is the cartridge's own until a
## screen asks the world for more.
func view_pixels() -> Vector2i:
	return _world.view_pixels if _world != null else Gen2WorldAPI.VIEW_PIXELS


## Where the cartridge's own 160x144 screen sits inside the drawn surface.
func screen_offset() -> Vector2:
	return Vector2(Gen2Screen.hardware_corner(view_pixels()))


func _draw() -> void:
	if _world == null or _atlas == null:
		draw_rect(Rect2(Vector2.ZERO, Vector2(view_pixels())), _background_color, true)
		return

	var camera_pixels: Vector2 = _camera_pixels()
	var background: Vector2 = _background_camera()
	if _draw_list == null:
		return
	_draw_hidden_trees(background, _draw_list.hidden_tree_cells())
	_draw_tile_overrides(background, _draw_list.tile_overrides())
	_draw_ss_anne_band(background)
	if not _transition_cells.is_empty():
		_draw_transition(background)
	for row: Dictionary in _draw_list.sprites():
		_draw_row(row, camera_pixels, background)


## [method Gen2WorldAPI.screen_tile_overrides]: a tile written straight into
## the background map, painted over the quad that still draws the block's own.
func _draw_tile_overrides(background: Vector2, overrides: Dictionary) -> void:
	for cell: Vector2i in overrides:
		_draw_atlas_tile(_drawn_tile_at(cell.x, cell.y), Vector2(cell * PokeTiles.TILE_WIDTH) - background)


## `HideHeadbuttTree`'s four tiles, painted over a map quad that knows nothing
## of them while the tree's own sprite anim plays.
func _draw_hidden_trees(background: Vector2, cells: Array) -> void:
	for cell: Vector2i in cells:
		var at: Vector2 = Vector2(cell * Gen2WorldAPI.CELL_PIXELS) - background
		for row: int in Gen2Layout.MAP_BLOCK_CELL_WIDTH:
			for column: int in Gen2Layout.MAP_BLOCK_CELL_WIDTH:
				_draw_atlas_tile(
					_drawn_tile_at(cell.x * 2 + column, cell.y * 2 + row),
					at + Vector2(column * PokeTiles.TILE_WIDTH, row * PokeTiles.TILE_HEIGHT)
				)


func _draw_atlas_tile(tile: int, at: Vector2) -> void:
	var size := Vector2(PokeTiles.TILE_WIDTH, PokeTiles.TILE_HEIGHT)
	draw_texture_rect_region(
		_atlas, Rect2(at, size), Rect2(Vector2(tile * PokeTiles.TILE_WIDTH, 0), size)
	)


## One row of [method Gen2WorldDrawList.sprites], at the surface pixel its
## anchor puts it on.
func _draw_row(row: Dictionary, camera_pixels: Vector2, background: Vector2) -> void:
	var origin: Vector2 = row["origin"]
	var at: Vector2 = origin + row["offset"]
	match StringName(row["anchor"]):
		Gen2WorldDrawList.ANCHOR_WORLD:
			at = origin - camera_pixels + row["offset"]
		Gen2WorldDrawList.ANCHOR_SCREEN:
			at = screen_offset() + origin + row["offset"]
	match StringName(row["kind"]):
		Gen2WorldDrawList.KIND_SPRITE:
			_draw_sprite_row(row, at)
		Gen2WorldDrawList.KIND_TILES:
			for tile: Dictionary in row["tiles"]:
				var texture: Texture2D = _tile_texture(row, tile)
				if texture != null:
					draw_texture(texture, at + Vector2(tile["offset"] as Vector2i))
		Gen2WorldDrawList.KIND_GRASS:
			_draw_grass_over(at, background)
		Gen2WorldDrawList.KIND_PULSE:
			var pulse: Texture2D = _pulse_texture(row)
			if pulse != null:
				draw_texture(pulse, at)


## A sprite row: the whole picture, a `region` of it, mirrored, or clipped to
## the 160x144 pane; the player with no picture is a crossed box.
func _draw_sprite_row(row: Dictionary, at: Vector2) -> void:
	var texture: Texture2D = _sprite_texture(row)
	if texture == null:
		if row["role"] == &"player":
			_draw_player_marker(at)
		return
	var region: Rect2 = row["region"]
	if region.has_area() and not bool(row["clip_to_screen"]):
		draw_texture_rect_region(texture, Rect2(at, region.size), region)
		return
	if not region.has_area():
		region = Rect2(Vector2.ZERO, texture.get_size())
	if bool(row["clip_to_screen"]):
		var shown: Rect2 = Rect2(at, region.size).intersection(
			Rect2(screen_offset(), Vector2(Gen2WorldAPI.VIEW_PIXELS))
		)
		if shown.size.x > 0.0 and shown.size.y > 0.0:
			draw_texture_rect_region(
				texture, shown, Rect2(region.position + shown.position - at, shown.size)
			)
		return
	if bool(row["flip_x"]):
		var size: Vector2 = texture.get_size()
		draw_texture_rect(texture, Rect2(at + Vector2(size.x, 0.0), Vector2(-size.x, size.y)), false)
		return
	draw_texture(texture, at)


func _draw_player_marker(at: Vector2) -> void:
	var marker := Rect2(at, Vector2(16, 16))
	draw_rect(marker, PLAYER_COLOR, false, 1.0)
	draw_line(marker.position, marker.end, PLAYER_COLOR, 1.0)
	draw_line(
		Vector2(marker.end.x, marker.position.y), Vector2(marker.position.x, marker.end.y),
		PLAYER_COLOR, 1.0
	)


## Redraws the map over the bottom half of a sprite drawn at [param pixel], with
## the transparent index left out, which is what OAM_PRIO amounts to here.
func _draw_grass_over(pixel: Vector2, background: Vector2) -> void:
	if _priority_atlas == null:
		_build_priority_atlas()
	if _priority_atlas == null:
		return
	var over := Rect2(
		pixel + Vector2(0, PokeTiles.TILE_HEIGHT),
		Vector2(Gen2WorldAPI.CELL_PIXELS, PokeTiles.TILE_HEIGHT),
	)
	## The tuft covers at most three tiles by two; walking the whole page once per
	## sprite in grass is more than a window-filling view can afford.
	var first := Vector2i(
		floori((over.position.x + background.x) / float(PokeTiles.TILE_WIDTH)),
		floori((over.position.y + background.y) / float(PokeTiles.TILE_HEIGHT)),
	)
	var last := Vector2i(
		ceili((over.end.x + background.x) / float(PokeTiles.TILE_WIDTH)),
		ceili((over.end.y + background.y) / float(PokeTiles.TILE_HEIGHT)),
	)
	for y: int in range(first.y, last.y + 1):
		for x: int in range(first.x, last.x + 1):
			var at := Rect2(
				Vector2(x * PokeTiles.TILE_WIDTH, y * PokeTiles.TILE_HEIGHT) - background,
				Vector2(PokeTiles.TILE_WIDTH, PokeTiles.TILE_HEIGHT),
			)
			var covered: Rect2 = at.intersection(over)
			if covered.size.x <= 0.0 or covered.size.y <= 0.0:
				continue
			var tile: int = _drawn_tile_at(x, y)
			if tile < 0 or tile >= _world.current_tileset.tile_count:
				continue
			for piece: Rect2 in _priority_pieces(covered):
				draw_texture_rect_region(
					_priority_atlas,
					piece,
					Rect2(
						Vector2(tile * PokeTiles.TILE_WIDTH, 0) + (piece.position - at.position),
						piece.size,
					),
				)
	## Where the transition wrote over the map, its own tile wins the priority
	## test rather than the grass, and the pieces above left those cells to it.
	if not _transition_cells.is_empty():
		_draw_transition(background, over, true)


## [method Gen2WorldDrawList.drawn_tile_at] with this frame's hidden trees over it.
func _drawn_tile_at(tile_x: int, tile_y: int) -> int:
	if _draw_list == null:
		return -1
	var tile := Vector2i(tile_x, tile_y)
	if _draw_list.hidden_tree_cells().has(Vector2i(floori(tile_x / 2.0), floori(tile_y / 2.0))) \
		and not _draw_list.tile_overrides().has(tile):
		return Gen2WorldEffects.HEADBUTT_TREE_HIDDEN_TILE
	return _draw_list.drawn_tile_at(tile)


## The parts of [param rect] the map still owns, split on the screen's own
## 8-pixel grid so a cell `DoBattleTransition` has written is left to it.
func _priority_pieces(rect: Rect2) -> Array[Rect2]:
	if _transition_cells.is_empty():
		return [rect] as Array[Rect2]
	var out: Array[Rect2] = []
	var top: float = rect.position.y
	while top < rect.end.y:
		var bottom: float = minf(floorf(top / PokeTiles.TILE_HEIGHT) * PokeTiles.TILE_HEIGHT \
			+ PokeTiles.TILE_HEIGHT, rect.end.y)
		var left: float = rect.position.x
		while left < rect.end.x:
			var right: float = minf(floorf(left / PokeTiles.TILE_WIDTH) * PokeTiles.TILE_WIDTH \
				+ PokeTiles.TILE_WIDTH, rect.end.x)
			if not _transition_wrote(Vector2(left, top)):
				out.append(Rect2(Vector2(left, top), Vector2(right - left, bottom - top)))
			left = right
		top = bottom
	return out


## Whether the transition has taken the screen cell [param at] falls in.
func _transition_wrote(at: Vector2) -> bool:
	var screen: Vector2 = at - screen_offset()
	var x: int = floori(screen.x / PokeTiles.TILE_WIDTH)
	var y: int = floori(screen.y / PokeTiles.TILE_HEIGHT)
	if x < 0 or x >= Gen2BattleTransition.COLUMNS \
		or y < 0 or y >= Gen2BattleTransition.ROWS:
		return false
	var index: int = y * Gen2BattleTransition.COLUMNS + x
	return index < _transition_cells.size() \
		and (int(_transition_cells[index]) != Gen2BattleTransition.CELL_NONE
			or _transition_source(index) >= 0)


## The same strip as the atlas with the cartridge's transparent index left out,
## for the tiles that are drawn over a sprite rather than under it.
func _build_priority_atlas() -> void:
	if _atlas == null:
		return
	var entry: Dictionary = _atlas_for(_world.current_map, _world.current_tileset)
	if entry.is_empty():
		return
	var width: int = int(entry["tile_count"]) * PokeTiles.TILE_WIDTH
	if _priority_indices.size() < width * PokeTiles.TILE_HEIGHT:
		return
	var words: PackedInt32Array = (entry["words"] as PackedInt32Array).duplicate()
	for y: int in PokeTiles.TILE_HEIGHT:
		var row: int = y * width
		for x: int in width:
			if int(_priority_indices[row + x]) == 0:
				words[row + x] = 0
	_priority_atlas = ImageTexture.create_from_image(
		Gen2PicImage.canvas_image(words, width, PokeTiles.TILE_HEIGHT)
	)


## A sprite row's picture. `DmgToCgbObjPals` takes the fade's own order too, and
## `FillWhiteBGColor` is background only, so a sprite flattens onto its colour 0.
## Keyed on the colours, since those are what the palette and the hour chose.
func _sprite_texture(row: Dictionary) -> Texture2D:
	var sprite: Gen2WorldSprite = row["sprite"]
	if sprite == null or _draw_list == null:
		return null
	var colors: PackedColorArray = row["colors"]
	var key: int = sprite.sprite_type | (sprite.number << 3) | (int(row["facing"]) << 19) \
		| (int(row["frame"]) << 22) | (int(row["big_shape"]) << 25) | (hash(colors) << 30)
	if _actor_textures.has(key):
		return _actor_textures[key]
	var image: Image = _draw_list.sprite_image(
		row, Gen2WorldPalette.fade_palette(colors, _fade_order)
	)
	var texture: Texture2D = ImageTexture.create_from_image(image) if image != null else null
	_actor_textures[key] = texture
	return texture


func _tile_texture(row: Dictionary, tile: Dictionary) -> Texture2D:
	var colors: PackedColorArray = row["colors"]
	var key: String = "%s:%d:%d:%d:%d" % [
		row["sheet"], int(tile["tile"]), int(tile["flip_x"]), int(tile["flip_y"]), hash(colors),
	]
	if _effect_textures.has(key):
		return _effect_textures[key]
	var image: Image = _draw_list.tile_image(
		row["sheet"], int(tile["tile"]), colors, bool(tile["flip_x"]), bool(tile["flip_y"])
	)
	var texture: Texture2D = ImageTexture.create_from_image(image) if image != null else null
	_effect_textures[key] = texture
	return texture


func _pulse_texture(row: Dictionary) -> Texture2D:
	var attributes: int = int(row["attributes"]) & (Gen2BattleAnimObject.OAM_SHARED_FLAGS
		| Gen2BattleAnimObject.OAM_PALETTE)
	var key: String = "%d:%d:%d:%s" % [
		int(row["gfx"]), int(row["tile"]), attributes, str(row["pair"]),
	]
	if _anim_textures.has(key):
		return _anim_textures[key]
	var image: Image = _draw_list.pulse_image(row)
	var texture: Texture2D = ImageTexture.create_from_image(image) if image != null else null
	_anim_textures[key] = texture
	return texture
