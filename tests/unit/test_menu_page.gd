extends GutTest

## The menu box drawn onto the tile grid, against a synthetic cache.
##
## The fixture fills each sheet with an index of its own, so a drawn pixel says
## which strip it came from and an untouched one reads 0. That is what lets the
## border, the options and the cursor be told apart without a real cartridge.

const Fixture := preload("res://tests/integration/world_trainer_fixture.gd")
const BattleFixture := preload("res://tests/unit/battle_fixture.gd")

const TILE: int = Gen2Font.TILE
const WIDTH: int = Gen2Screen.WIDTH
const HEIGHT: int = Gen2Screen.HEIGHT

## init_gender.asm's .MenuHeader, the first real menu this project draws.
const FLAGS: int = (
	Gen2MenuBox.STATICMENU_CURSOR | Gen2MenuBox.STATICMENU_WRAP
	| Gen2MenuBox.STATICMENU_DISABLE_B
)
const OPTIONS: Array = ["Boy", "Girl"]

var _page: Gen2MenuPage = null


func before_each() -> void:
	Fixture.build()
	_page = Gen2MenuPage.from_data(GameData.open_directory(Fixture.directory()))


func after_each() -> void:
	RomCache.clear(Fixture.directory())


func _box() -> Gen2MenuBox:
	return Gen2MenuBox.from_coords(6, 4, 12, 9, FLAGS)


func _blank() -> PackedByteArray:
	var indices := PackedByteArray()
	indices.resize(WIDTH * HEIGHT)
	return indices


func _draw(cursor: int, indices: PackedByteArray) -> void:
	_page.draw(_box(), OPTIONS, cursor, indices, WIDTH)


func _ink_in_tile(indices: PackedByteArray, tile: Vector2i) -> bool:
	for row: int in TILE:
		for column: int in TILE:
			var at: int = (tile.y * TILE + row) * WIDTH + tile.x * TILE + column
			if at < indices.size() and indices[at] != 0:
				return true
	return false


func test_the_border_is_drawn_on_the_boxs_own_corners() -> void:
	var indices: PackedByteArray = _blank()
	_draw(0, indices)
	for corner: Vector2i in [
		Vector2i(6, 4), Vector2i(12, 4), Vector2i(6, 9), Vector2i(12, 9),
	]:
		assert_true(_ink_in_tile(indices, corner), "corner %s" % corner)


## `MenuBox` reaches `Textbox` with the interior, so the frame is seven tiles by
## six and nothing is drawn outside it.
func test_nothing_is_drawn_outside_the_frame() -> void:
	var indices: PackedByteArray = _blank()
	_draw(0, indices)
	assert_false(_ink_in_tile(indices, Vector2i(5, 4)), "one column left of the box")
	assert_false(_ink_in_tile(indices, Vector2i(13, 4)), "one column right of the box")
	assert_false(_ink_in_tile(indices, Vector2i(6, 3)), "one row above the box")
	assert_false(_ink_in_tile(indices, Vector2i(6, 10)), "one row below the box")


func test_options_print_two_rows_apart_inside_the_border() -> void:
	var indices: PackedByteArray = _blank()
	_draw(0, indices)
	assert_true(_ink_in_tile(indices, Vector2i(8, 6)), "first option")
	assert_true(_ink_in_tile(indices, Vector2i(8, 8)), "second option")
	assert_false(_ink_in_tile(indices, Vector2i(8, 7)), "the row between them")


func test_the_cursor_follows_the_selection() -> void:
	var first: PackedByteArray = _blank()
	_draw(0, first)
	assert_true(_ink_in_tile(first, Vector2i(7, 6)), "arrow on the first option")
	assert_false(_ink_in_tile(first, Vector2i(7, 8)), "no arrow on the second")

	var second: PackedByteArray = _blank()
	_draw(1, second)
	assert_false(_ink_in_tile(second, Vector2i(7, 6)))
	assert_true(_ink_in_tile(second, Vector2i(7, 8)))


func test_a_negative_cursor_draws_no_arrow() -> void:
	var indices: PackedByteArray = _blank()
	_draw(-1, indices)
	assert_false(_ink_in_tile(indices, Vector2i(7, 6)))
	assert_true(_ink_in_tile(indices, Vector2i(8, 6)), "the options are still there")


## `Textbox` clears its own interior, so a menu opened over a filled page does
## not show that page through its options.
func test_the_interior_is_cleared_under_the_box() -> void:
	var indices: PackedByteArray = _blank()
	for at: int in indices.size():
		indices[at] = 3
	_draw(0, indices)
	# An interior tile that carries neither an option nor the cursor.
	assert_false(_ink_in_tile(indices, Vector2i(11, 7)), "interior cleared")
	# Outside the box the fill survives, since the menu draws only its own area.
	assert_true(_ink_in_tile(indices, Vector2i(2, 2)), "the page outside is untouched")


## The title prints on the border's own top row, overwriting it, so a title that
## fits inside the box cannot be told from the border it covers. A title long
## enough to run past the right-hand corner can: column 14 is outside a box that
## ends at 12, so ink there is the title and nothing else.
func test_a_title_prints_only_when_the_flag_is_set() -> void:
	var without: PackedByteArray = _blank()
	_page.draw(_box(), OPTIONS, 0, without, WIDTH, "LONGTITLEHERE", 2)
	assert_false(_ink_in_tile(without, Vector2i(14, 4)), "no title without the flag")

	var titled := Gen2MenuBox.from_coords(6, 4, 12, 9, FLAGS | Gen2MenuBox.STATICMENU_PLACE_TITLE)
	var with_title: PackedByteArray = _blank()
	_page.draw(titled, OPTIONS, 0, with_title, WIDTH, "LONGTITLEHERE", 2)
	assert_true(_ink_in_tile(with_title, Vector2i(14, 4)), "the title ran past the corner")


## `Pokepic`'s box is a `MenuBox` and a `PlaceGraphic`, so it is checked where
## the box it is made of is. `PokepicMenuHeader`'s `menu_coords 6, 4, 14, 13` is
## nine tiles by ten drawn, with a seven-wide interior the 7x7 pic fills and one
## interior row left under it.
func test_the_pokepic_box_is_the_headers_own_size() -> void:
	var box: Gen2MenuBox = Gen2PokepicPage.menu_box()
	assert_eq(box.border_position(), Vector2i(6, 4))
	assert_eq(box.border_size(), Vector2i(9, 10))
	assert_eq(box.interior(), Vector2i(7, 8))


## `PadFrontpic` bottom-aligns a smaller pic one column in rather than centring
## it, on top of `PlaceGraphic`'s own one-tile inset.
func test_a_pokepic_smaller_than_the_block_is_padded_not_centred() -> void:
	assert_eq(Gen2PokepicPage.pic_position(7, 7), Vector2i(TILE, TILE))
	assert_eq(Gen2PokepicPage.pic_position(6, 6), Vector2i(2 * TILE, 2 * TILE))
	assert_eq(Gen2PokepicPage.pic_position(5, 5), Vector2i(2 * TILE, 3 * TILE))


func test_the_pokepic_box_draws_the_pic_inside_its_frame() -> void:
	var data: GameData = GameData.open_directory(Fixture.directory())
	var image: Image = Gen2PokepicPage.render(data, BattleFixture.CHARMANDER, Gen2WorldMap.new())
	assert_not_null(image)
	assert_eq(image.get_size(), Vector2i(9, 10) * TILE)
	## The atlas is filled with index 1, so a pic pixel is the map's own second
	## background colour and the interior around it is the box's blank.
	## Through [method Gen2PicImage.from_indices] rather than off the palette, so
	## the comparison is against the same eight bits a channel the image holds.
	var pic: Color = Gen2PicImage.from_indices(
		PackedByteArray([1]), 1, 1,
		data.world_palette(int(Gen2WorldPalette.palette_slots(
			Gen2WorldMap.new().environment, Gen2WorldPalette.TIME_MORNING
		)[Gen2PokepicPage.PALETTE_GRAY]))
	).get_pixel(0, 0)
	assert_eq(image.get_pixelv(Gen2PokepicPage.pic_position(7, 7)), pic, "the pic's corner")
	## `lb bc, 7, 7` in an eight-row interior leaves the bottom row of it blank.
	assert_ne(image.get_pixel(TILE, 8 * TILE + 1), pic, "the row under the pic")


func test_the_pokepic_box_refuses_a_species_the_cache_does_not_hold() -> void:
	var data: GameData = GameData.open_directory(Fixture.directory())
	assert_null(Gen2PokepicPage.render(data, BattleFixture.MAX_SPECIES + 1, Gen2WorldMap.new()))
	assert_null(Gen2PokepicPage.render(data, BattleFixture.CHARMANDER, null))


## `PrintUnownStamp` restarts the map music when B cancels the printer send,
## then returns to the browser rather than closing it.
func test_cancelling_an_unown_print_restarts_the_map_music() -> void:
	var screen := Gen2UnownPrinterScreen.new()
	add_child_autofree(screen)
	screen._open = true
	screen.visible = true
	var tracks: Array[int] = []
	var restarts: Array[bool] = []
	screen.music_requested.connect(func(track: int) -> void: tracks.append(track))
	screen.map_music_requested.connect(func() -> void: restarts.append(true))

	screen.handle_button(PokeButton.A)
	assert_eq(tracks, [Gen2UnownPrinterScreen.MUSIC_PRINTER])
	assert_true(screen.printing())
	screen.handle_button(PokeButton.B)

	assert_eq(restarts.size(), 1)
	assert_false(screen.printing())
	assert_true(screen.visible, "the browser stays open after the send is cancelled")


## `PlaceVerticalMenuItems` has no bound and needs none: every cartridge label is
## written to fit the box it is placed in. A label a mod registers is not, and
## unbounded it was drawn straight through the right-hand border and over
## whatever the box sits on, which is what the in-game MODS row could do.
## The cut itself, and that it is marked, are [Gen2Font]'s and tested there. Here
## the row is only bounded: the ellipsis lands in the last interior column, which
## this cache has no tile for, so the column before it is the last glyph.
func test_a_row_too_wide_for_its_box_is_cut_at_the_border() -> void:
	var box: Gen2MenuBox = _box()
	var indices: PackedByteArray = _blank()
	_page.draw(box, ["A VERY LONG MOD NAME INDEED"], 0, indices, WIDTH)

	# The last interior column, one short of the right-hand border at box.right.
	var last: int = box.left + box.interior().x
	assert_true(
		_ink_in_tile(indices, Vector2i(last - 1, box.item_position(0).y)),
		"fills the row up to the cut"
	)
	for column: int in range(box.right + 1, Gen2Screen.WIDTH / TILE):
		assert_false(
			_ink_in_tile(indices, Vector2i(column, box.item_position(0).y)),
			"nothing past the border at column %d" % column
		)


## `ScrollingMenu_UpdateDisplay`'s two arrows, both written over the box's
## right-hand border: `▼` whenever `SCROLLINGMENU_DISPLAY_ARROWS` is set, and
## `▲` only past the first row. The frame is already drawn in both corners, so
## each is read as a corner that differs from the same box without arrows.
func _arrow_box(scroll: int) -> Gen2MenuBox:
	var box: Gen2MenuBox = _box()
	box.scrolling_arrows = true
	box.scroll = scroll
	return box


func _tile(indices: PackedByteArray, at: Vector2i) -> PackedByteArray:
	var out := PackedByteArray()
	for row: int in TILE:
		var start: int = (at.y * TILE + row) * WIDTH + at.x * TILE
		out.append_array(indices.slice(start, start + TILE))
	return out


## `[top-right, bottom-right]` for a box drawn with [param scroll], against the
## same box with no arrows at all.
func _arrow_corners(scroll: int) -> Array[bool]:
	var plain: PackedByteArray = _blank()
	_page.draw(_box(), OPTIONS, 0, plain, WIDTH)
	var drawn: PackedByteArray = _blank()
	var box: Gen2MenuBox = _arrow_box(scroll)
	_page.draw(box, OPTIONS, 0, drawn, WIDTH)
	return [
		_tile(drawn, Vector2i(box.right, box.top)) != _tile(plain, Vector2i(box.right, box.top)),
		_tile(drawn, Vector2i(box.right, box.bottom))
			!= _tile(plain, Vector2i(box.right, box.bottom)),
	]


func test_the_down_arrow_is_drawn_whatever_the_scroll_is() -> void:
	var corners: Array[bool] = _arrow_corners(0)
	assert_true(corners[1], "the down arrow does not wait for rows below the window")
	assert_false(corners[0], "wMenuScrollPosition is zero, so the up arrow waits")


func test_the_up_arrow_waits_for_the_window_to_leave_the_top() -> void:
	var corners: Array[bool] = _arrow_corners(1)
	assert_true(corners[0])
	assert_true(corners[1])


## `BattleTowerRoomMenu_UpdatePickLevelMenu` writes `String_119d07` at
## `hlcoord 13, 8` and `hlcoord 13, 10` and turns the upper tile over with the
## attrmap's own $40, so the two arrows are one glyph drawn twice.
func test_the_room_menus_upper_arrow_is_the_lower_one_turned_over() -> void:
	var box: Gen2MenuBox = Gen2MenuBox.from_coords(12, 7, 19, 11, 0)
	box.pick_arrows = true
	var indices: PackedByteArray = _blank()
	_page.draw(box, [" L:10 "], -1, indices, WIDTH)
	assert_true(_ink_in_tile(indices, Vector2i(16, 8)), "the flipped arrow")
	assert_true(_ink_in_tile(indices, Vector2i(16, 10)), "and `String_119d07`'s own")
	for row: int in TILE:
		for column: int in TILE:
			var top: int = (8 * TILE + row) * WIDTH + 16 * TILE + column
			var bottom: int = (10 * TILE + TILE - 1 - row) * WIDTH + 16 * TILE + column
			assert_eq(indices[top], indices[bottom], "row %d column %d" % [row, column])


## A box without the field draws neither, which is every other menu in the game.
func test_no_arrows_without_the_room_menus_own_field() -> void:
	var indices: PackedByteArray = _blank()
	_page.draw(Gen2MenuBox.from_coords(12, 7, 19, 11, 0), [" L:10 "], -1, indices, WIDTH)
	assert_false(_ink_in_tile(indices, Vector2i(16, 8)))
	assert_false(_ink_in_tile(indices, Vector2i(16, 10)))
