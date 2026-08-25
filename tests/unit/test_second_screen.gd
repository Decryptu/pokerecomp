extends GutTest

## The lower display: which pages it offers, and where a touch lands.
##
## Its gate is the START menu's, so what is asserted here is that the two answer
## the same thing rather than that a second list was copied correctly.

const PLAYER: String = "CHRIS"


func _tabs(party: int, pokedex: bool, pokegear: bool) -> Gen2SecondScreenTabs:
	return Gen2SecondScreenTabs.build(party, pokedex, pokegear, PLAYER)


func _kinds(tabs: Gen2SecondScreenTabs) -> Array:
	var out: Array = []
	for entry: Dictionary in tabs.items():
		out.append(StringName(entry["kind"]))
	return out


## A player who has not been to Elm's lab has a pack and a trainer card, which is
## exactly what `SetUpMenuItems` leaves once its three gates all refuse.
func test_bedroom_offers_only_the_ungated_pages() -> void:
	assert_eq(
		_kinds(_tabs(0, false, false)),
		[Gen2WorldStartMenu.ITEM_PACK, Gen2WorldStartMenu.ITEM_PLAYER]
	)


func test_the_team_page_waits_for_the_starter() -> void:
	assert_false(
		_tabs(0, false, false).has_kind(Gen2WorldStartMenu.ITEM_POKEMON),
		"an empty party has no team page"
	)
	assert_true(
		_tabs(1, false, false).has_kind(Gen2WorldStartMenu.ITEM_POKEMON),
		"one Pokemon opens it"
	)


func test_the_dex_and_gear_pages_wait_for_their_engine_flags() -> void:
	assert_false(_tabs(1, false, false).has_kind(Gen2WorldStartMenu.ITEM_POKEDEX))
	assert_false(_tabs(1, false, false).has_kind(Gen2WorldStartMenu.ITEM_POKEGEAR))
	assert_true(_tabs(1, true, false).has_kind(Gen2WorldStartMenu.ITEM_POKEDEX))
	assert_true(_tabs(1, false, true).has_kind(Gen2WorldStartMenu.ITEM_POKEGEAR))


## The tabs are the START menu's own rows in the START menu's own order, less the
## ones that do something rather than show something.
func test_every_tab_is_a_start_menu_row_in_source_order() -> void:
	var menu: Gen2WorldStartMenu = Gen2WorldStartMenu.build(3, true, true, 0, PLAYER)
	var expected: Array = []
	for entry: Dictionary in menu.items():
		var kind: StringName = StringName(entry["kind"])
		if Gen2SecondScreenTabs.VIEWABLE.has(kind):
			expected.append(kind)
	assert_eq(_kinds(_tabs(3, true, true)), expected)


func test_save_option_and_exit_never_reach_a_tab() -> void:
	var kinds: Array = _kinds(_tabs(6, true, true))
	for kind: StringName in [
		Gen2WorldStartMenu.ITEM_SAVE, Gen2WorldStartMenu.ITEM_OPTION,
		Gen2WorldStartMenu.ITEM_EXIT,
	]:
		assert_false(kinds.has(kind), "%s is an action, not a page" % kind)


func test_selecting_a_missing_tab_is_refused() -> void:
	var tabs: Gen2SecondScreenTabs = _tabs(0, false, false)
	assert_false(tabs.select(Gen2WorldStartMenu.ITEM_POKEMON))
	assert_eq(tabs.selected_kind(), Gen2WorldStartMenu.ITEM_PACK)
	assert_true(tabs.select(Gen2WorldStartMenu.ITEM_PLAYER))
	assert_eq(tabs.selected_kind(), Gen2WorldStartMenu.ITEM_PLAYER)


## A gate opening mid-walk changes the signature, which is what makes a host
## redraw the row rather than leave a tab the player has just earned off it.
func test_the_signature_follows_the_tab_set_and_the_chosen_tab() -> void:
	var before: String = _tabs(0, false, false).signature()
	assert_ne(before, _tabs(1, false, false).signature(), "a starter adds a tab")
	var tabs: Gen2SecondScreenTabs = _tabs(1, false, false)
	var first: String = tabs.signature()
	tabs.select(Gen2WorldStartMenu.ITEM_PLAYER)
	assert_ne(first, tabs.signature(), "the chosen tab is in it")


## The canvas is the largest whole-scale rectangle that fills the panel, so a
## hardware pixel is a square block of panel pixels and the leftover is a bar
## rather than a resampled picture.
func test_the_canvas_fills_a_panel_at_a_whole_scale() -> void:
	## The AYN Thor's lower display. 1080 / 178 is 6, and 1240 / 6 is 206.
	assert_eq(
		Gen2SecondScreenHost.canvas_for(Vector2i(1240, 1080)), Vector2i(206, 180)
	)


func test_a_panel_smaller_than_the_page_gets_the_smallest_canvas() -> void:
	assert_eq(
		Gen2SecondScreenHost.canvas_for(Vector2i(128, 96)),
		Gen2SecondScreen.CANVAS_MIN
	)
	assert_eq(
		Gen2SecondScreenHost.canvas_for(Vector2i.ZERO), Gen2SecondScreen.CANVAS_MIN
	)


func test_the_canvas_never_loses_the_page_or_the_tab_row() -> void:
	for panel: Vector2i in [
		Vector2i(1240, 1080), Vector2i(1280, 720), Vector2i(960, 544),
		Vector2i(320, 240), Vector2i(1080, 1240),
	]:
		var canvas: Vector2i = Gen2SecondScreenHost.canvas_for(panel)
		assert_true(
			canvas.x >= Gen2SecondScreen.CANVAS_MIN.x
				and canvas.y >= Gen2SecondScreen.CANVAS_MIN.y,
			"%s left room for the page and the row" % panel
		)


const CANVAS := Vector2i(206, 180)


## A touch above the row is on the page, and a page takes nothing: that is the
## whole of what "read only" is enforced by.
func test_a_touch_on_the_page_lands_on_no_tab() -> void:
	assert_eq(Gen2SecondScreen.tab_index_at(Vector2(100.0, 0.0), CANVAS, 5), -1)
	assert_eq(Gen2SecondScreen.tab_index_at(Vector2(100.0, 143.0), CANVAS, 5), -1)
	assert_eq(Gen2SecondScreen.tab_index_at(Vector2(100.0, 70.0), CANVAS, 5), -1)


## Five tabs across 206 pixels: each cell is its own share, and the last one
## reaches the right edge rather than stopping a pixel short of it.
func test_the_row_is_split_into_one_cell_per_tab() -> void:
	var count: int = 5
	var covered: int = 0
	for index: int in count:
		var cell: Rect2i = Gen2SecondScreen.tab_cell(index, CANVAS, count)
		covered += cell.size.x
		assert_eq(
			Gen2SecondScreen.tab_index_at(
				Vector2(float(cell.position.x), 150.0), CANVAS, count
			),
			index, "the left edge of cell %d" % index
		)
		assert_eq(
			Gen2SecondScreen.tab_index_at(
				Vector2(float(cell.position.x + cell.size.x - 1), 150.0), CANVAS, count
			),
			index, "the right edge of cell %d" % index
		)
	assert_eq(covered, CANVAS.x, "the cells cover the row exactly")


func test_a_touch_off_the_canvas_lands_on_no_tab() -> void:
	for at: Vector2 in [
		Vector2(-1.0, 150.0), Vector2(206.0, 150.0), Vector2(100.0, 180.0),
		Vector2(100.0, -1.0),
	]:
		assert_eq(Gen2SecondScreen.tab_index_at(at, CANVAS, 5), -1, str(at))


func test_a_row_with_no_tabs_takes_no_touch() -> void:
	assert_eq(Gen2SecondScreen.tab_index_at(Vector2(100.0, 150.0), CANVAS, 0), -1)


## Every engine callback that could deliver a press to a page without the page
## being asked for it. A screen that declares none of these cannot act on input
## the second display never routes to it, whatever else it is doing.
const INPUT_CALLBACKS: Array[String] = [
	"_input", "_unhandled_input", "_unhandled_key_input", "_gui_input",
	"_shortcut_input",
]

## The pages the lower display hosts, as their own scripts.
const HOSTED: Array[String] = [
	"res://game/world/pokedex_screen.gd",
	"res://game/save/party_screen.gd",
	"res://game/world/town_map_screen.gd",
	"res://game/world/pokegear_screen.gd",
	"res://game/world/trainer_card_screen.gd",
]


## The read-only promise, asserted where it is actually kept: none of the pages
## the lower display shows reads input at all. Each is driven by its host calling
## `handle_button`, and the lower display calls nothing.
##
## This is the test that fails the day someone gives one of these screens an
## input callback of its own, which is the one change that would let a page on
## the panel act on a press meant for the game.
func test_no_hosted_page_reads_input() -> void:
	for path: String in HOSTED:
		var script: Script = load(path) as Script
		assert_not_null(script, path)
		if script == null:
			continue
		var declared: Array[String] = []
		for entry: Dictionary in script.get_script_method_list():
			declared.append(String(entry.get("name", "")))
		for callback: String in INPUT_CALLBACKS:
			assert_false(
				declared.has(callback),
				"%s declares %s" % [path.get_file(), callback]
			)


## The launcher's own page is drawn at the panel's resolution rather than in the
## hardware canvas, and how big it is drawn is a whole multiple of the launcher's
## units. A desktop window smaller than one unit's worth still gets one.
func test_the_launcher_page_scales_by_whole_units() -> void:
	assert_eq(Gen2SecondScreen.idle_scale(Vector2i(1240, 1080)), 2)
	assert_eq(Gen2SecondScreen.idle_scale(Vector2i(824, 720)), 1)
	assert_eq(Gen2SecondScreen.idle_scale(Vector2i(64, 64)), 1)
	assert_eq(Gen2SecondScreen.idle_scale(Vector2i(1920, 1620)), 3)
