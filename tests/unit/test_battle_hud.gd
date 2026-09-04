extends GutTest

## The battle screen's tile page and the arithmetic behind its bars.
##
## Builds its own cache, like `test_game_data.gd`: nothing here opens a
## cartridge, because the point of the drawing layer is that it works on
## indices and a palette and never sees one.

var _directory: String = ""


func before_each() -> void:
	_directory = RomCache.directory_for(&"battletest", "0123456789abcdef")
	RomCache.clear(_directory)
	RomCache.prepare(_directory)


func after_each() -> void:
	RomCache.clear(_directory)


## Four sheets, each filled with one index, so which sheet a tile came from can
## be read off the page.
func _write_cache(with_sheets: bool = true) -> void:
	var sheets: Dictionary = {}
	if with_sheets:
		var written: Dictionary = {
			"exp_bar": [Gen2Layout.EXP_BAR_TILES, 2],
			"battle_font": [Gen2Layout.BATTLE_FONT_TILES, 1],
			"enemy_hud": [Gen2Layout.ENEMY_HUD_TILES, 2],
			"player_hud": [Gen2Layout.PLAYER_HUD_TILES, 3],
			"font": [Gen2Layout.FONT_TILES, 3],
			"frames": [Gen2Layout.FRAME_COUNT * Gen2Layout.FRAME_TILES, 3],
		}
		for row_name: String in written:
			var tiles: int = written[row_name][0]
			var value: int = written[row_name][1]
			var indices: PackedByteArray = PackedByteArray()
			indices.resize(tiles * PokeTiles.TILE_WIDTH * PokeTiles.TILE_HEIGHT)
			indices.fill(value)
			RomCache.write_indices(RomCache.tile_path(_directory, row_name), indices)
			sheets[row_name] = {
				"width": tiles * PokeTiles.TILE_WIDTH,
				"height": PokeTiles.TILE_HEIGHT,
				"tiles": tiles,
				"first_code": Gen2Layout.FONT_FIRST_CODE if row_name == "font" else 0,
				"bits": 1,
			}

	RomCache.write_json(RomCache.manifest_path(_directory), {
		"format_version": RomCache.FORMAT_VERSION,
		"game_id": "battletest",
		"sha1": "0123456789abcdef",
		"tiles": sheets,
		"bar_palettes": {
			"hp_green": [0x02E0, 0x02E0],
			"hp_yellow": [0x02BF, 0x02BF],
			"hp_red": [0x001F, 0x001F],
			"exp": [0x7E24, 0x7E24],
		},
		"complete": true,
	})


func _data() -> GameData:
	return GameData.open_directory(_directory)


## The index one tile of the page draws, read back out of a buffer.
func _drawn(page: Gen2BattleTiles, tile: int) -> int:
	var into: PackedByteArray = PackedByteArray()
	into.resize(PokeTiles.TILE_WIDTH * PokeTiles.TILE_HEIGHT)
	page.draw(tile, into, PokeTiles.TILE_WIDTH, 0, 0)
	return into[0]


func test_the_page_needs_every_sheet_it_draws_from() -> void:
	_write_cache(false)
	assert_null(Gen2BattleTiles.from_data(_data()))
	assert_null(Gen2BattleHud.from_data(_data()))


func test_a_later_sheet_wins_the_tiles_it_lands_on() -> void:
	# The battle font is copied in first and the HUD borders over the middle of
	# it, exactly as they are in video memory, so thirteen of its tiles are never
	# seen. Getting this backwards draws a border where a bar should be.
	_write_cache()
	var page: Gen2BattleTiles = Gen2BattleTiles.from_data(_data())
	assert_not_null(page)
	assert_eq(_drawn(page, Gen2BattleTiles.EXP_BAR_AT), 2, "the exp bar keeps its own tiles")
	assert_eq(_drawn(page, Gen2BattleTiles.HP_BAR_EMPTY), 1, "the bar is the battle font's")
	assert_eq(_drawn(page, Gen2BattleTiles.ENEMY_HUD_AT), 2, "the enemy border overwrites")
	assert_eq(_drawn(page, Gen2BattleTiles.PLAYER_HUD_AT), 3, "so does the player's")


func test_a_tile_outside_the_page_draws_nothing() -> void:
	_write_cache()
	var page: Gen2BattleTiles = Gen2BattleTiles.from_data(_data())
	assert_eq(_drawn(page, Gen2BattleTiles.FIRST_TILE - 1), 0)
	assert_eq(_drawn(page, Gen2BattleTiles.LAST_TILE + 1), 0)


## `PrintLevel`: "3-digit numbers overwrite the :L", on a `cp 100` the source
## calls distinct from MAX_LEVEL. `PlacePartyMonLevel` carries the same test, and
## both reach here. The symbol is a battle-font tile and a digit a font tile, so
## the index a cell is drawn in says which of the two stands in it.
func test_a_three_digit_level_overwrites_the_level_symbol() -> void:
	_write_cache()
	var hud: Gen2BattleHud = Gen2BattleHud.from_data(_data())
	assert_not_null(hud)
	assert_eq(_level_cells(hud, 99), [2, 3, 3, 0] as Array[int])
	assert_eq(_level_cells(hud, 100), [3, 3, 3, 0] as Array[int])


## The first index of each of the four cells a level could reach, drawn into a
## buffer that wide so nothing else can put ink in them.
func _level_cells(hud: Gen2BattleHud, level: int) -> Array[int]:
	var width: int = 4 * PokeTiles.TILE_WIDTH
	var into: PackedByteArray = PackedByteArray()
	into.resize(width * PokeTiles.TILE_HEIGHT)
	hud.draw_level(into, width, Vector2i.ZERO, level)
	var out: Array[int] = []
	for column: int in 4:
		out.append(int(into[column * PokeTiles.TILE_WIDTH]))
	return out


func test_a_full_bar_is_full_and_an_empty_one_is_empty() -> void:
	assert_eq(Gen2BattleHud.bar_pixels(20, 20, 48), 48)
	assert_eq(Gen2BattleHud.bar_pixels(0, 20, 48), 0)


func test_a_pokemon_that_is_alive_never_shows_an_empty_bar() -> void:
	# The games round the bar down and then put a pixel back, so that an empty
	# bar means fainted and nothing else.
	assert_eq(Gen2BattleHud.bar_pixels(1, 999, 48), 1)


## `ComputeHPBarPixels`' divisor is one byte, so a maximum over 255 shifts both
## product and divisor right two bits, and both shifts truncate: 300 of 401 is
## 35 exactly and 36 the way the routine divides it.
func test_a_maximum_over_a_byte_is_divided_the_way_the_routine_divides_it() -> void:
	assert_eq(Gen2BattleHud.bar_pixels(300, 401, 48), 36)
	assert_eq(300 * 48 / 401, 35, "and not the exact fraction")
	assert_eq(Gen2BattleHud.bar_pixels(400, 401, 48), 48, "a nearly full bar still fills")
	assert_eq(Gen2BattleHud.bar_pixels(128, 256, 48), 24, "an exact half is unchanged")


func test_a_bar_is_as_full_as_the_fraction_behind_it() -> void:
	assert_eq(Gen2BattleHud.bar_pixels(10, 20, 48), 24)
	assert_eq(Gen2BattleHud.bar_pixels(5, 20, 48), 12)


func test_a_bar_with_no_maximum_does_not_divide_by_it() -> void:
	assert_eq(Gen2BattleHud.bar_pixels(5, 0, 48), 0)


func test_the_bar_colour_follows_what_is_drawn_not_the_hit_points() -> void:
	# Half a bar is still green, a fifth of it is yellow, and below that it is
	# red: the rule is about pixels, which is why a bar can turn red on a
	# Pokémon with hit points left.
	assert_eq(GameData.hp_bar_palette_name(48), "hp_green")
	assert_eq(GameData.hp_bar_palette_name(Gen2Layout.HP_GREEN_PIXELS), "hp_green")
	assert_eq(GameData.hp_bar_palette_name(Gen2Layout.HP_GREEN_PIXELS - 1), "hp_yellow")
	assert_eq(GameData.hp_bar_palette_name(Gen2Layout.HP_YELLOW_PIXELS), "hp_yellow")
	assert_eq(GameData.hp_bar_palette_name(Gen2Layout.HP_YELLOW_PIXELS - 1), "hp_red")


func test_a_bar_palette_comes_back_as_four_colours() -> void:
	_write_cache()
	var data: GameData = _data()
	var palette: PackedColorArray = data.bar_palette("hp_green")
	assert_eq(palette.size(), PokePalette.COLORS_PER_PIC)
	assert_eq(palette[0], Color.WHITE)
	assert_eq(palette[3], Color.BLACK)
	assert_ne(palette, data.bar_palette("hp_red"))


func test_an_unknown_bar_palette_is_legible_rather_than_missing() -> void:
	_write_cache()
	assert_eq(_data().bar_palette("nothing"), _data().bar_palette("also nothing"))


func test_the_hud_draws_its_panels_where_the_hardware_puts_them() -> void:
	# The panels sit above and below the pics and must not reach into either.
	_write_cache()
	var hud: Gen2BattleHud = Gen2BattleHud.from_data(_data())
	assert_not_null(hud)

	var screen: PackedByteArray = PackedByteArray()
	screen.resize(Gen2Screen.WIDTH * Gen2Screen.HEIGHT)
	hud.draw_enemy(screen, Gen2Screen.WIDTH, "PIDGEY", 5)
	hud.draw_player(screen, Gen2Screen.WIDTH, "CYNDAQUIL", 5, 18, 18)

	assert_ne(_ink_in_row(screen, Gen2BattleHud.ENEMY_NAME.y), 0, "the enemy's row_name row")
	assert_ne(_ink_in_row(screen, Gen2BattleHud.PLAYER_BAR.y), 0, "the player's bar row")
	assert_eq(_ink_in_row(screen, Gen2TextBox.STANDARD_TOP), 0, "nothing in the text box")
	assert_eq(_ink_in_row(screen, 5), 0, "nothing between the two panels")


## `DrawEnemyHUDBorder`'s tail: a wild battle whose species the Pokedex already
## holds carries `ExpBarGFX`' ninth tile under the enemy's name, and nothing else
## on the panel moves.
func test_a_caught_species_marks_the_enemy_panel_with_a_ball() -> void:
	_write_cache()
	var hud: Gen2BattleHud = Gen2BattleHud.from_data(_data())

	var plain: PackedByteArray = PackedByteArray()
	plain.resize(Gen2Screen.WIDTH * Gen2Screen.HEIGHT)
	hud.draw_enemy(plain, Gen2Screen.WIDTH, "PIDGEY", 5)

	var caught: PackedByteArray = PackedByteArray()
	caught.resize(Gen2Screen.WIDTH * Gen2Screen.HEIGHT)
	hud.draw_enemy(caught, Gen2Screen.WIDTH, "PIDGEY", 5, true)

	## Row 1 already carries the level, so the ball is the difference between
	## the two panels rather than everything drawn on the row.
	assert_eq(
		_ink_in_row(caught, Gen2BattleHud.ENEMY_CAUGHT.y)
			- _ink_in_row(plain, Gen2BattleHud.ENEMY_CAUGHT.y),
		Gen2Font.TILE * Gen2Font.TILE,
		"one tile of ball"
	)
	assert_eq(
		_ink_in_row(caught, Gen2BattleHud.ENEMY_NAME.y),
		_ink_in_row(plain, Gen2BattleHud.ENEMY_NAME.y),
		"the name row is untouched"
	)


func test_the_hp_bar_fill_is_drawn_apart_from_the_panel() -> void:
	# The fill is the only part of a panel that is not black on white, so it is
	# a layer of its own and the panel must not draw it.
	_write_cache()
	var hud: Gen2BattleHud = Gen2BattleHud.from_data(_data())

	var full: PackedByteArray = PackedByteArray()
	full.resize(Gen2Screen.WIDTH * Gen2Screen.HEIGHT)
	hud.draw_hp_bar(full, Gen2Screen.WIDTH, Gen2BattleHud.ENEMY_BAR, 20, 20)

	var empty: PackedByteArray = PackedByteArray()
	empty.resize(Gen2Screen.WIDTH * Gen2Screen.HEIGHT)
	hud.draw_hp_bar(empty, Gen2Screen.WIDTH, Gen2BattleHud.ENEMY_BAR, 0, 20)

	assert_ne(_ink_in_row(full, Gen2BattleHud.ENEMY_BAR.y), 0)
	assert_eq(_ink_in_row(empty, Gen2BattleHud.ENEMY_BAR.y), 0, "a fainted bar draws nothing")


## `PlaceExpBar` takes a pixel count in `b`, and it is never a ratio: `CalcExpBar`
## has already divided. It starts at `hlcoord 17, 11` and writes with `ld [hld], a`,
## so the full tiles land at the right-hand end and the run walks left, and unlike
## `DrawBattleHPBar` it lays no empty template first: every tile the fill did not
## reach is written $62 by `.loop2`. The fixture fills each sheet with one index, so
## a column says which sheet drew it, and a column of 0 is a hole.
func test_the_exp_bar_is_drawn_from_a_pixel_count() -> void:
	_write_cache()
	var hud: Gen2BattleHud = Gen2BattleHud.from_data(_data())
	var tile: int = Gen2BattleHud.TILE
	var length: int = Gen2BattleHud.EXP_BAR_TILES * tile

	for pixels: int in [0, 4, tile, tile + 4, length, length * 2]:
		var screen: PackedByteArray = _exp_row(hud, pixels)
		for column: int in Gen2BattleHud.EXP_BAR_TILES:
			assert_ne(
				_exp_column(screen, column), 0,
				"tile %d is drawn at %d pixels" % [column, pixels]
			)

	# Under one tile: only the rightmost column is a partial, and it is the
	# right-hand one because the run is written leftward from column 17.
	var part: PackedByteArray = _exp_row(hud, 4)
	assert_eq(_exp_column(part, Gen2BattleHud.EXP_BAR_TILES - 1), 2, "the lit end is the right")
	for column: int in Gen2BattleHud.EXP_BAR_TILES - 1:
		assert_eq(_exp_column(part, column), 1, "tile %d is still empty" % column)

	# One tile and a remainder: the rightmost is full and the partial has moved
	# one column left, which a bar filling the other way would invert.
	var more: PackedByteArray = _exp_row(hud, tile + 4)
	assert_eq(_exp_column(more, Gen2BattleHud.EXP_BAR_TILES - 1), 1, "a whole tile")
	assert_eq(_exp_column(more, Gen2BattleHud.EXP_BAR_TILES - 2), 2, "then the remainder")

	# Exactly full and past full draw the same eight whole tiles and no partial.
	for pixels: int in [length, length * 2]:
		var screen: PackedByteArray = _exp_row(hud, pixels)
		for column: int in Gen2BattleHud.EXP_BAR_TILES:
			assert_eq(_exp_column(screen, column), 1, "tile %d is whole" % column)


func _exp_row(hud: Gen2BattleHud, pixels: int) -> PackedByteArray:
	var screen: PackedByteArray = PackedByteArray()
	screen.resize(Gen2Screen.WIDTH * Gen2Screen.HEIGHT)
	hud.draw_exp_bar(screen, Gen2Screen.WIDTH, pixels)
	return screen


## The index one pixel inside tile [param column] of the exp bar's own row.
func _exp_column(screen: PackedByteArray, column: int) -> int:
	var x: int = (Gen2BattleHud.PLAYER_EXP.x + column) * Gen2Font.TILE
	var y: int = Gen2BattleHud.PLAYER_EXP.y * Gen2Font.TILE
	return screen[y * Gen2Screen.WIDTH + x]


## Lit pixels in one row of tiles.
func _ink_in_row(screen: PackedByteArray, row: int) -> int:
	var out: int = 0
	for y: int in range(row * Gen2Font.TILE, (row + 1) * Gen2Font.TILE):
		for x: int in Gen2Screen.WIDTH:
			if screen[y * Gen2Screen.WIDTH + x] != 0:
				out += 1
	return out
