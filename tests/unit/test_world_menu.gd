extends GutTest


func test_vertical_menu_uses_the_source_default_and_wrap_flag() -> void:
	var menu: Gen2WorldMenu = Gen2WorldMenu.from_input({
		"menu_kind": &"vertical",
		"header": {"data_flags": 1 << 5, "default": 2},
		"options": ["A", "B", "C"],
	})
	assert_eq(menu.selected_index(), 1)
	assert_true(menu.move(Vector2i.DOWN))
	assert_eq(menu.selected_index(), 2)
	assert_true(menu.move(Vector2i.DOWN))
	assert_eq(menu.selected_index(), 0)
	assert_true(menu.move(Vector2i.UP))
	assert_eq(menu.selected_index(), 2)


func test_vertical_menu_stops_at_the_ends_without_source_wrap() -> void:
	var menu: Gen2WorldMenu = Gen2WorldMenu.from_input({
		"menu_kind": &"vertical", "header": {"default": 1},
		"options": ["A", "B"],
	})
	assert_false(menu.move(Vector2i.UP))
	assert_eq(menu.selected_index(), 0)
	assert_true(menu.move(Vector2i.DOWN))
	assert_false(menu.move(Vector2i.DOWN))
	assert_eq(menu.selected_index(), 1)


func test_two_dimensional_menu_moves_by_rows_and_columns() -> void:
	var menu: Gen2WorldMenu = Gen2WorldMenu.from_input({
		"menu_kind": &"2d",
		"header": {"data_flags": 1 << 5, "rows": 2, "columns": 2, "default": 1},
		"options": ["A", "B", "C", "D"],
	})
	assert_eq(menu.row(), 0)
	assert_eq(menu.column(), 0)
	assert_true(menu.move(Vector2i.RIGHT))
	assert_eq(menu.selected_index(), 1)
	assert_true(menu.move(Vector2i.DOWN))
	assert_eq(menu.selected_index(), 3)
	assert_true(menu.move(Vector2i.RIGHT))
	assert_eq(menu.selected_index(), 2)
	assert_true(menu.move(Vector2i.UP))
	assert_eq(menu.selected_index(), 0)


func test_two_dimensional_menu_does_not_select_a_missing_cell() -> void:
	var menu: Gen2WorldMenu = Gen2WorldMenu.from_input({
		"menu_kind": &"2d",
		"header": {"rows": 2, "columns": 2, "default": 1},
		"options": ["A", "B", "C"],
	})
	assert_true(menu.move(Vector2i.DOWN))
	assert_eq(menu.selected_index(), 2)
	assert_false(menu.move(Vector2i.RIGHT))
	assert_eq(menu.selected_index(), 2)


## `LoadMenuHeader`'s own `menu_coords`, carried through the importer's
## top/left/bottom/right and into the box a scripted `verticalmenu` draws.
func test_vertical_menu_carries_its_own_menu_coords() -> void:
	var menu: Gen2WorldMenu = Gen2WorldMenu.from_input({
		"menu_kind": &"vertical",
		"header": {"data_flags": 1 << 7, "left": 1, "top": 1, "right": 13, "bottom": 10},
		"options": ["A", "B"],
	})
	var box: Gen2MenuBox = menu.box()
	assert_eq(box.left, 1)
	assert_eq(box.top, 1)
	assert_eq(box.right, 13)
	assert_eq(box.bottom, 10)
	assert_eq(box.flags, 1 << 7)


## `Place2DMenuItemStrings`' column count and spacing carry into the box so a
## `2d` menu's items land where the grid puts them, not one under another.
func test_two_dimensional_menu_carries_columns_and_spacing_into_its_box() -> void:
	var menu: Gen2WorldMenu = Gen2WorldMenu.from_input({
		"menu_kind": &"2d",
		"header": {"rows": 2, "columns": 3, "spacing": 5, "default": 1},
		"options": ["A", "B", "C", "D", "E", "F"],
	})
	var box: Gen2MenuBox = menu.box()
	assert_eq(box.columns, 3)
	assert_eq(box.column_spacing, 5)


## `Script_yesorno` loads no menu header, so a `choice` arrives with none. The
## fallback is `YesNoMenuHeader`'s whole record and not just its coordinates:
## without STATICMENU_CURSOR nothing draws the arrow, so the box offered two
## answers with no mark on the one A would take.
func test_a_headerless_choice_wears_the_yes_no_menu_header() -> void:
	var menu: Gen2WorldMenu = Gen2WorldMenu.from_input({
		"type": &"choice", "command": &"yesorno", "choices": [&"yes", &"no"],
	})
	assert_eq(menu.options, ["YES", "NO"], "the strings are MenuData's own")
	assert_true(
		menu.box().has_flag(Gen2MenuBox.STATICMENU_CURSOR), "and the cursor is drawn"
	)
	assert_true(menu.box().has_flag(Gen2MenuBox.STATICMENU_NO_TOP_SPACING))
	assert_eq(menu.selected_index(), 0, "`db 1` is YES")
	assert_eq(menu.box().border_position(), Vector2i(14, 7), "_YesNoBox's own box")


## A header that names its flags still wins, zero included.
func test_a_loaded_header_keeps_its_own_flags() -> void:
	var menu: Gen2WorldMenu = Gen2WorldMenu.from_input({
		"menu_kind": &"vertical", "header": {"data_flags": 0, "default": 1},
		"options": ["A", "B"],
	})
	assert_eq(menu.flags, 0)
	assert_false(menu.box().has_flag(Gen2MenuBox.STATICMENU_CURSOR))


## `BattleTowerRoomMenu_UpdatePickLevelMenu`'s `.d_up` increments the room index
## and `.d_down` decrements it, so UP walks L:10 towards CANCEL: the opposite of
## every other menu here. Both wrap, and neither branch reads the flags byte.
func test_the_room_menu_runs_the_other_way_and_wraps_without_the_flag() -> void:
	var menu: Gen2WorldMenu = Gen2WorldMenu.from_input({
		"menu_kind": &"room", "header": {"data_flags": 0, "default": 1},
		"options": [" L:10 ", " L:20 ", " L:30 ", " L:40 ", "CANCEL"],
	})
	assert_eq(menu.selected_index(), 0)
	assert_true(menu.move(Vector2i.UP))
	assert_eq(menu.selected_value(), " L:20 ", "UP is `.d_up`'s inc")
	assert_true(menu.move(Vector2i.DOWN))
	assert_true(menu.move(Vector2i.DOWN))
	assert_eq(menu.selected_value(), "CANCEL", "and `.d_down` restarts at the last")
	assert_true(menu.move(Vector2i.UP))
	assert_eq(menu.selected_value(), " L:10 ", "past the last, `.d_up` restarts at 1")


## `MenuHeader_119cf7` carries `db 0`: no cursor, and the two arrows instead.
func test_the_room_menu_box_wears_the_arrows_rather_than_a_cursor() -> void:
	var box: Gen2MenuBox = Gen2WorldMenu.from_input({
		"menu_kind": &"room", "header": {
			"data_flags": 0, "default": 1,
			"left": 12, "top": 7, "right": 19, "bottom": 11,
		},
		"options": ["CANCEL"],
	}).box()
	assert_true(box.pick_arrows)
	assert_false(box.has_flag(Gen2MenuBox.STATICMENU_CURSOR))
	assert_eq(
		box.item_position(0), Vector2i(13, 9),
		"`hlcoord 13, 9`, which is the box's own text start with top spacing"
	)


## `YesNoMenuHeader` has no STATICMENU_WRAP and no left/right: UP is YES and
## DOWN is NO, and neither end wraps.
func test_a_yes_no_moves_by_up_and_down_and_wraps_neither_way() -> void:
	var menu: Gen2WorldMenu = Gen2WorldMenu.yes_no()
	assert_eq(menu.cursor, 0)
	assert_false(menu.press_yes_no(PokeButton.UP))
	assert_false(menu.press_yes_no(PokeButton.LEFT))
	assert_false(menu.press_yes_no(PokeButton.RIGHT))
	assert_eq(menu.cursor, 0)
	assert_true(menu.press_yes_no(PokeButton.DOWN))
	assert_false(menu.press_yes_no(PokeButton.DOWN))
	assert_eq(menu.cursor, 1)
	assert_false(menu.holding(), "moving answers nothing")


## B is `YesNoBox`'s carry wherever the cursor stands, and A takes the row.
func test_b_answers_no_from_either_row_and_a_takes_the_cursor() -> void:
	var refused: Gen2WorldMenu = Gen2WorldMenu.yes_no()
	assert_true(refused.press_yes_no(PokeButton.B))
	assert_false(refused.answered_yes())
	var accepted: Gen2WorldMenu = Gen2WorldMenu.yes_no()
	assert_true(accepted.press_yes_no(PokeButton.A))
	assert_true(accepted.answered_yes())
	var declined: Gen2WorldMenu = Gen2WorldMenu.yes_no()
	declined.press_yes_no(PokeButton.DOWN)
	declined.press_yes_no(PokeButton.A)
	assert_false(declined.answered_yes())


## `InterpretTwoOptionMenu`'s `ld c, $f / call DelayFrames` reads no joypad, and
## the answer is heard on its last frame and on no other.
func test_the_answer_is_held_fifteen_frames_and_reads_nothing_meanwhile() -> void:
	var menu: Gen2WorldMenu = Gen2WorldMenu.yes_no()
	assert_false(menu.advance_hold(), "nothing is held before an answer")
	menu.press_yes_no(PokeButton.A)
	assert_true(menu.holding())
	for frame: int in Gen2WorldMenu.ANSWER_HOLD_FRAMES - 1:
		assert_false(menu.press_yes_no(PokeButton.DOWN), "frame %d" % frame)
		assert_false(menu.press_yes_no(PokeButton.B), "frame %d" % frame)
		assert_false(menu.advance_hold(), "frame %d" % frame)
	assert_eq(menu.cursor, 0)
	assert_true(menu.answered_yes(), "the B pressed during the hold was dropped")
	assert_true(menu.advance_hold())
	assert_false(menu.holding())
	assert_false(menu.advance_hold())
