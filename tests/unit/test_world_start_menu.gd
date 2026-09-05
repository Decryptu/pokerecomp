extends GutTest

const Fixture := preload("res://tests/integration/world_trainer_fixture.gd")

## engine/menus/start_menu.asm's StartMenu.SetUpMenuItems gating, reproduced
## as data: Pokedex behind wStatusFlags/STATUSFLAGS_POKEDEX_F, Pokemon behind
## a non-zero party count, Pokegear behind wPokegearFlags/POKEGEAR_OBTAINED_F,
## everything else always present.


func _kinds(menu: Gen2WorldStartMenu) -> Array:
	var out: Array = []
	for entry: Dictionary in menu.items():
		out.append(entry.get("kind"))
	return out


func test_default_list_omits_pokedex_pokemon_and_pokegear() -> void:
	var menu: Gen2WorldStartMenu = Gen2WorldStartMenu.build(0, false, false)
	assert_eq(_kinds(menu), [
		Gen2WorldStartMenu.ITEM_PACK, Gen2WorldStartMenu.ITEM_PLAYER,
		Gen2WorldStartMenu.ITEM_SAVE, Gen2WorldStartMenu.ITEM_OPTION,
		Gen2WorldStartMenu.ITEM_EXIT, Gen2WorldStartMenu.ITEM_LAUNCHER,
	])


## `SetUpMenuItems` reads `STATUSFLAGS2_BUG_CONTEST_TIMER_F` twice: PACK is
## dropped and the SAVE slot holds QUIT instead.
func test_a_running_contest_drops_pack_and_puts_quit_where_save_was() -> void:
	var menu: Gen2WorldStartMenu = Gen2WorldStartMenu.build(
		1, true, true, 0, "GOLD", false, true
	)
	var kinds: Array = _kinds(menu)
	assert_false(kinds.has(Gen2WorldStartMenu.ITEM_PACK), "only park balls throw")
	assert_false(kinds.has(Gen2WorldStartMenu.ITEM_SAVE))
	assert_eq(
		kinds.find(Gen2WorldStartMenu.ITEM_QUIT),
		kinds.find(Gen2WorldStartMenu.ITEM_PLAYER) + 1,
		"`.write` fills the one slot SAVE would have"
	)
	for entry: Dictionary in menu.items():
		if entry.get("kind") == Gen2WorldStartMenu.ITEM_QUIT:
			assert_eq(String(entry.get("label", "")), "QUIT")


func test_pokemon_appears_only_with_a_non_empty_party() -> void:
	var empty: Gen2WorldStartMenu = Gen2WorldStartMenu.build(0, false, false)
	assert_false(_kinds(empty).has(Gen2WorldStartMenu.ITEM_POKEMON))
	var with_party: Gen2WorldStartMenu = Gen2WorldStartMenu.build(1, false, false)
	assert_true(_kinds(with_party).has(Gen2WorldStartMenu.ITEM_POKEMON))


func test_pokegear_appears_only_with_the_source_engine_flag() -> void:
	var without: Gen2WorldStartMenu = Gen2WorldStartMenu.build(0, false, false)
	assert_false(_kinds(without).has(Gen2WorldStartMenu.ITEM_POKEGEAR))
	var with_flag: Gen2WorldStartMenu = Gen2WorldStartMenu.build(0, false, true)
	assert_true(_kinds(with_flag).has(Gen2WorldStartMenu.ITEM_POKEGEAR))


func test_pokedex_appears_only_with_the_source_engine_flag() -> void:
	var without: Gen2WorldStartMenu = Gen2WorldStartMenu.build(0, false, false)
	assert_false(_kinds(without).has(Gen2WorldStartMenu.ITEM_POKEDEX))
	var with_flag: Gen2WorldStartMenu = Gen2WorldStartMenu.build(0, true, false)
	assert_true(_kinds(with_flag).has(Gen2WorldStartMenu.ITEM_POKEDEX))
	for entry: Dictionary in with_flag.items():
		if entry.get("kind") == Gen2WorldStartMenu.ITEM_POKEDEX:
			assert_true(entry.get("available"))


func test_full_list_matches_the_source_item_order_when_every_gate_is_open() -> void:
	var menu: Gen2WorldStartMenu = Gen2WorldStartMenu.build(1, true, true)
	assert_eq(_kinds(menu), [
		Gen2WorldStartMenu.ITEM_POKEDEX, Gen2WorldStartMenu.ITEM_POKEMON,
		Gen2WorldStartMenu.ITEM_PACK, Gen2WorldStartMenu.ITEM_POKEGEAR,
		Gen2WorldStartMenu.ITEM_PLAYER, Gen2WorldStartMenu.ITEM_SAVE,
		Gen2WorldStartMenu.ITEM_OPTION, Gen2WorldStartMenu.ITEM_EXIT,
		Gen2WorldStartMenu.ITEM_LAUNCHER,
	])


func test_every_entry_the_gates_admit_is_available() -> void:
	var menu: Gen2WorldStartMenu = Gen2WorldStartMenu.build(1, true, true)
	var available_by_kind: Dictionary = {}
	for entry: Dictionary in menu.items():
		available_by_kind[entry.get("kind")] = entry.get("available")
	assert_true(available_by_kind[Gen2WorldStartMenu.ITEM_PACK])
	assert_true(available_by_kind[Gen2WorldStartMenu.ITEM_POKEMON])
	assert_true(available_by_kind[Gen2WorldStartMenu.ITEM_POKEGEAR])
	assert_true(available_by_kind[Gen2WorldStartMenu.ITEM_SAVE])
	assert_true(available_by_kind[Gen2WorldStartMenu.ITEM_EXIT])
	assert_true(available_by_kind[Gen2WorldStartMenu.ITEM_OPTION])
	assert_true(available_by_kind[Gen2WorldStartMenu.ITEM_PLAYER])
	assert_true(available_by_kind[Gen2WorldStartMenu.ITEM_POKEDEX])


## The way back out of the cartridge, which the console rather than the game
## owned. It is behind the contest gate PACK is: a contest is a timed errand and
## the cartridge's own QUIT is what leaves one.
func test_home_is_last_and_leaves_with_the_pack_during_a_contest() -> void:
	var menu: Gen2WorldStartMenu = Gen2WorldStartMenu.build(1, true, true)
	assert_eq(_kinds(menu).back(), Gen2WorldStartMenu.ITEM_LAUNCHER)
	var contest: Gen2WorldStartMenu = Gen2WorldStartMenu.build(
		1, true, true, 0, "", false, true
	)
	assert_false(_kinds(contest).has(Gen2WorldStartMenu.ITEM_LAUNCHER))
	assert_false(_kinds(contest).has(Gen2WorldStartMenu.ITEM_PACK))


func test_quit_never_appears_because_this_project_has_no_bug_contest() -> void:
	var menu: Gen2WorldStartMenu = Gen2WorldStartMenu.build(1, true, true)
	assert_false(_kinds(menu).has(&"quit"))


## STATICMENU_WRAP is on the source .MenuData flags, so the cursor wraps at
## both ends instead of stopping.
func test_cursor_wraps_at_both_ends() -> void:
	var menu: Gen2WorldStartMenu = Gen2WorldStartMenu.build(0, false, false)
	assert_eq(menu.size(), 6)
	assert_true(menu.move(-1))
	assert_eq(menu.cursor, 5)
	assert_true(menu.move(1))
	assert_eq(menu.cursor, 0)


## wBattleMenuCursorPosition survives a reopen; rebuilding with the previous
## cursor should keep the same selection rather than resetting to the top.
func test_cursor_persists_across_a_rebuild_and_clamps_to_a_shrunk_list() -> void:
	var menu: Gen2WorldStartMenu = Gen2WorldStartMenu.build(1, false, true)
	menu.move(2)
	var reopened: Gen2WorldStartMenu = Gen2WorldStartMenu.build(1, false, true, menu.cursor)
	assert_eq(reopened.cursor, menu.cursor)

	var shrunk: Gen2WorldStartMenu = Gen2WorldStartMenu.build(0, false, false, menu.cursor)
	assert_lt(shrunk.cursor, shrunk.size())


## `.MenuDesc`'s own strings come out of the cache, so a menu built by hand has
## none: an entry with no imported line answers empty rather than one this
## project wrote.
func test_a_menu_built_without_a_cache_has_no_descriptions() -> void:
	var menu := Gen2WorldStartMenu.build(1, true, true)
	for entry: Dictionary in menu.items():
		assert_eq(menu.description(StringName(entry["kind"])), "")
	assert_eq(menu.selected_description(), "")


func test_moving_an_empty_menu_does_nothing() -> void:
	var menu := Gen2WorldStartMenu.new()
	assert_false(menu.move(1))
	assert_eq(menu.selected_item(), {})
	assert_eq(menu.selected_kind(), &"")
	assert_false(menu.selected_available())


func test_from_world_reads_party_count_and_engine_flags_off_the_live_world() -> void:
	var data: GameData = Fixture.build()
	var world: Gen2WorldAPI = Gen2WorldAPI.open(
		data, Fixture.MAP_GROUP, Fixture.MAP_NUMBER, Vector2i(7, 6)
	)
	var empty_menu: Gen2WorldStartMenu = Gen2WorldStartMenu.from_world(world)
	assert_false(_kinds(empty_menu).has(Gen2WorldStartMenu.ITEM_POKEMON))
	assert_false(_kinds(empty_menu).has(Gen2WorldStartMenu.ITEM_POKEGEAR))

	world.set_party_summary(1, false)
	world.state.set_engine_flag(Gen2WorldStartMenu.ENGINE_POKEGEAR)
	var populated_menu: Gen2WorldStartMenu = Gen2WorldStartMenu.from_world(world)
	assert_true(_kinds(populated_menu).has(Gen2WorldStartMenu.ITEM_POKEMON))
	assert_true(_kinds(populated_menu).has(Gen2WorldStartMenu.ITEM_POKEGEAR))

	assert_eq(_kinds(Gen2WorldStartMenu.from_world(null)), _kinds(Gen2WorldStartMenu.build(0, false, false)))
	RomCache.clear(Fixture.directory())


## The registry seam: a mod entry is spliced in ahead of EXIT, which stays last of
## the source's own because it is what closes the menu, and no source entry
## moves. Only HOME, which the cartridge has no row for, is below it.
func test_a_registered_entry_lands_before_exit() -> void:
	Gen2ModHost.reset()
	var called: Array = []
	assert_true(bool(Gen2ModHost.instance().register_menu_entry(
		Gen2ModHost.MENU_START, &"atlas",
		{"label": "Atlas", "handler": func() -> void: called.append(true)}
	).get("ok", false)))
	var menu: Gen2WorldStartMenu = Gen2WorldStartMenu.build(0, false, false)
	assert_eq(_kinds(menu), [
		Gen2WorldStartMenu.ITEM_PACK, Gen2WorldStartMenu.ITEM_PLAYER,
		Gen2WorldStartMenu.ITEM_SAVE, Gen2WorldStartMenu.ITEM_OPTION,
		&"atlas", Gen2WorldStartMenu.ITEM_EXIT,
		Gen2WorldStartMenu.ITEM_LAUNCHER,
	])
	var entry: Dictionary = menu.items()[4]
	assert_eq(String(entry.get("label", "")), "Atlas")
	assert_true(bool(entry.get("available", false)))
	(entry["handler"] as Callable).call()
	assert_eq(called.size(), 1)
	Gen2ModHost.reset()


## An entry with no handler still appears, marked unavailable.
func test_a_registered_entry_without_a_handler_is_unavailable() -> void:
	Gen2ModHost.reset()
	Gen2ModHost.instance().register_menu_entry(
		Gen2ModHost.MENU_START, &"atlas", {"label": "Atlas"}
	)
	var menu: Gen2WorldStartMenu = Gen2WorldStartMenu.build(0, false, false)
	assert_false(bool(menu.items()[4].get("available", false)))
	Gen2ModHost.reset()


## The entry also carries the host's own VIEW row, so a mod that registered a
## renderer and no setting still has to be reachable: without this, a player on
## a shipped build could only change the view from the launcher.
func test_mods_appears_for_a_registered_view_with_no_setting() -> void:
	Gen2ModHost.reset()
	var script := GDScript.new()
	script.source_code = """extends Node2D
func set_world(_world, _animation = null) -> void:
	pass
func set_time_of_day(_time_of_day: int) -> void:
	pass
func refresh() -> void:
	pass
func refresh_animation() -> void:
	pass
"""
	script.reload()
	assert_true(bool(
		Gen2ModHost.instance().register_world_renderer(&"voxel", script).get("ok", false)
	))

	var menu: Gen2WorldStartMenu = Gen2WorldStartMenu.build(0, false, false)

	assert_true(_kinds(menu).has(Gen2WorldStartMenu.ITEM_MODS))
	Gen2ModHost.reset()


## MODS is not the cartridge's, so it appears only when there is something in it
## to change, and it sits ahead of both the registered entries and EXIT.
func test_mods_appears_only_for_a_mod_that_registered_a_setting() -> void:
	Gen2ModHost.reset()
	var without: Gen2WorldStartMenu = Gen2WorldStartMenu.build(0, false, false)
	assert_false(_kinds(without).has(Gen2WorldStartMenu.ITEM_MODS))

	assert_true(bool(Gen2ModHost.instance().register_option(&"voxel", {
		"key": "draw_distance", "label": "DISTANCE", "values": [8, 16],
	}).get("ok", false)))
	Gen2ModHost.instance().register_menu_entry(
		Gen2ModHost.MENU_START, &"atlas", {"label": "Atlas"}
	)
	var menu: Gen2WorldStartMenu = Gen2WorldStartMenu.build(0, false, false)
	assert_eq(_kinds(menu), [
		Gen2WorldStartMenu.ITEM_PACK, Gen2WorldStartMenu.ITEM_PLAYER,
		Gen2WorldStartMenu.ITEM_SAVE, Gen2WorldStartMenu.ITEM_OPTION,
		Gen2WorldStartMenu.ITEM_MODS, &"atlas", Gen2WorldStartMenu.ITEM_EXIT,
		Gen2WorldStartMenu.ITEM_LAUNCHER,
	])
	assert_true(bool(menu.items()[4].get("available", false)))
	Gen2ModHost.reset()


## `.PokedexString` and its siblings, which are what the box over the map
## prints, and the name `PlaceString` reads for `<PLAYER>`.
func test_the_labels_are_the_source_strings_with_the_player_name_filled_in() -> void:
	var menu: Gen2WorldStartMenu = Gen2WorldStartMenu.build(1, true, true, 0, "GOLD")
	var labels: Array = []
	for entry: Variant in menu.items():
		labels.append(String((entry as Dictionary).get("label", "")))
	assert_eq(labels, [
		"#DEX", "#MON", "PACK", "<POKE>GEAR", "GOLD", "SAVE", "OPTION", "EXIT",
		"HOME",
	])
	## A world with no save selected has no name to read.
	assert_eq(String(Gen2WorldStartMenu.build(0, false, false).items()[1]["label"]), "PLAYER")


## `AutomaticGetMenuBottomCoord` grows the box downward by two rows an entry and
## its own border, so `.MenuHeader`'s bottom coordinate is never read;
## `.ContestMenuHeader` is the same box two rows down.
func test_the_box_grows_downward_by_two_rows_an_entry() -> void:
	var five: Gen2MenuBox = Gen2StartMenuPage.list_box(5)
	assert_eq(five.border_position(), Vector2i(10, 0))
	assert_eq(five.border_size(), Vector2i(10, 12))
	assert_eq(Gen2StartMenuPage.list_box(8).border_size(), Vector2i(10, 18))
	assert_eq(Gen2StartMenuPage.list_box(5, true).border_position(), Vector2i(10, 2))


## Eight rows reach the last row of the screen exactly, which is what a fully
## unlocked save already has, so a `MENU_START` entry a mod registers has to be
## scrolled to rather than drawn at row 18. The box stops at the screen.
func test_the_box_stops_at_the_screen_however_many_rows_the_list_has() -> void:
	assert_eq(Gen2StartMenuPage.visible_rows(), 8)
	assert_eq(Gen2StartMenuPage.visible_rows(true), 7)
	assert_eq(Gen2StartMenuPage.list_box(12).border_size(), Vector2i(10, 18))
	assert_eq(Gen2StartMenuPage.list_box(12).bottom, Gen2StartMenuPage.ROWS - 1)
	assert_eq(Gen2StartMenuPage.list_box(12, true).bottom, Gen2StartMenuPage.ROWS - 1)


func _save_state(pokedex: bool, cursor: int) -> Dictionary:
	return {
		"player_name": "GOLD", "badges": 3, "pokedex": pokedex, "caught": 42,
		"hours": 12, "minutes": 7,
		"lines": Gen2StartMenuScreen.SAVE_ASK_LINES, "line": 0, "cursor": cursor,
	}


func _opaque(image: Image, tile: Vector2i) -> bool:
	return image.get_pixel(
		tile.x * Gen2Font.TILE + 4, tile.y * Gen2Font.TILE + 4
	).a > 0.0


## `SaveMenu` draws `DisplaySaveInfoOnSave`'s box in the right-hand sixteen
## columns, `SpeechTextbox` at the foot and `PlaceYesNoBox`'s own on the left,
## and nothing else: the map is still showing everywhere between them.
func test_the_save_screen_draws_three_boxes_over_the_map() -> void:
	Fixture.build()
	var page: Gen2StartMenuPage = Gen2StartMenuPage.from_data(
		GameData.open_directory(Fixture.directory())
	)
	var asked: Image = page.render_save(_save_state(true, 0))
	assert_true(_opaque(asked, Vector2i(4, 0)), "the info box's own corner")
	assert_true(_opaque(asked, Vector2i(19, 9)), "and its far one")
	assert_true(_opaque(asked, Vector2i(0, 12)), "the speech box")
	assert_true(_opaque(asked, Vector2i(0, 7)), "the yes/no box")
	assert_true(_opaque(asked, Vector2i(5, 11)), "and its far corner")
	assert_false(_opaque(asked, Vector2i(3, 0)), "the map left of the info box")
	assert_false(_opaque(asked, Vector2i(0, 6)), "the map above the yes/no box")
	assert_false(_opaque(asked, Vector2i(19, 11)), "the map between the boxes")

	## `SavingDontTurnOffThePower` prints with no question behind it, so the
	## yes/no box is not up at all.
	var saving: Image = page.render_save(_save_state(true, -1))
	assert_false(_opaque(saving, Vector2i(0, 7)))
	RomCache.clear(Fixture.directory())


## `.MenuData_NoDex` blanks the third row's label and
## `Continue_DisplayPokedexNumCaught` returns before its own `PrintNum`, so a
## player without the Pokedex is shown neither the word nor the count.
func test_the_dex_row_is_blank_without_the_pokedex_flag() -> void:
	Fixture.build()
	var page: Gen2StartMenuPage = Gen2StartMenuPage.from_data(
		GameData.open_directory(Fixture.directory())
	)
	var without: Image = page.render_save(_save_state(false, 0))
	var with_dex: Image = page.render_save(_save_state(true, 0))
	assert_ne(without.get_data(), with_dex.get_data())
	## An interior tile the box never writes, which is what a blank row reads as.
	var blank: Color = without.get_pixel(6 * Gen2Font.TILE, 3 * Gen2Font.TILE)
	var row: int = Gen2StartMenuPage.SAVE_DEX_AT.y
	for column: int in range(5, Gen2StartMenuPage.SAVE_INFO_RIGHT):
		assert_true(
			_tile_is(without, Vector2i(column, row), blank),
			"column %d of the dex row is blank" % column
		)
	assert_false(_tile_is(with_dex, Vector2i(5, row), blank), "#DEX is printed")
	RomCache.clear(Fixture.directory())


func _tile_is(image: Image, tile: Vector2i, color: Color) -> bool:
	for y: int in Gen2Font.TILE:
		for x: int in Gen2Font.TILE:
			if image.get_pixel(tile.x * Gen2Font.TILE + x, tile.y * Gen2Font.TILE + y) != color:
				return false
	return true


## MOVES is not the cartridge's either: it appears only where a registered
## field-move source has something the party cannot already reach, and it sits
## ahead of MODS and of the entries mods registered themselves.
func test_moves_appears_only_when_a_field_move_source_has_something_to_offer() -> void:
	Gen2ModHost.reset()
	var without: Gen2WorldStartMenu = Gen2WorldStartMenu.build(0, false, false)
	assert_false(_kinds(without).has(Gen2WorldStartMenu.ITEM_FIELD_MOVES))

	Gen2ModHost.instance().register_menu_entry(
		Gen2ModHost.MENU_START, &"atlas", {"label": "Atlas"}
	)
	var menu: Gen2WorldStartMenu = Gen2WorldStartMenu.build(0, false, false, 0, "", true)
	assert_eq(_kinds(menu), [
		Gen2WorldStartMenu.ITEM_PACK, Gen2WorldStartMenu.ITEM_PLAYER,
		Gen2WorldStartMenu.ITEM_SAVE, Gen2WorldStartMenu.ITEM_OPTION,
		Gen2WorldStartMenu.ITEM_FIELD_MOVES, &"atlas", Gen2WorldStartMenu.ITEM_EXIT,
		Gen2WorldStartMenu.ITEM_LAUNCHER,
	])
	assert_true(bool(menu.items()[4].get("available", false)))
	Gen2ModHost.reset()


## A registered row can hide itself, and the host's own gate runs after the
## mod's: a PC row is absent before the first Pokemon rather than refused.
func test_a_registered_entry_can_be_absent_rather_than_refused() -> void:
	Gen2ModHost.reset()
	assert_true(bool(Gen2ModHost.instance().register_menu_entry(
		Gen2ModHost.MENU_START, &"pc", {
			"label": "PC", "action": Gen2ModHost.START_ACTION_OPEN_BILLS_PC,
		}
	).get("ok", false)))
	assert_false(_kinds(Gen2WorldStartMenu.build(0, false, false)).has(&"pc"))
	assert_true(_kinds(Gen2WorldStartMenu.build(1, false, false)).has(&"pc"))
	Gen2ModHost.reset()


## `DrawStartMenu`'s own list: no Pokegear, no contest, POKéMON drawn whatever
## `wPartyCount` says, and only `EVENT_GOT_POKEDEX` gating anything.
func test_the_generation_1_list_is_draw_start_menus_own() -> void:
	var menu: Gen2WorldStartMenu = Gen2WorldStartMenu.build(
		0, false, true, 0, "", false, false, RomRegistry.GEN1
	)
	assert_eq(_kinds(menu), [
		Gen2WorldStartMenu.ITEM_POKEMON, Gen2WorldStartMenu.ITEM_PACK,
		Gen2WorldStartMenu.ITEM_PLAYER, Gen2WorldStartMenu.ITEM_SAVE,
		Gen2WorldStartMenu.ITEM_OPTION, Gen2WorldStartMenu.ITEM_EXIT,
		Gen2WorldStartMenu.ITEM_LAUNCHER,
	])
	var with_dex: Gen2WorldStartMenu = Gen2WorldStartMenu.build(
		0, true, false, 0, "", false, false, RomRegistry.GEN1
	)
	assert_eq(_kinds(with_dex)[0], Gen2WorldStartMenu.ITEM_POKEDEX)
	## The labels are the literal characters `db "POKéDEX@"` holds, not the `#`
	## and `<POKE>` markers Generation 2's charmap draws them with.
	assert_eq(String((with_dex.items()[0] as Dictionary)["label"]), "POKéDEX")
	assert_eq(String((with_dex.items()[2] as Dictionary)["label"]), "ITEM")
