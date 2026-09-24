extends GutTest

## Generation 1's PC (`ActivatePC`, `BillsPC_`, `PlayerPC`) through the world
## screen and the service host. The fixture is Generation 2's cache read as
## Red and Blue, which is how the start-menu tests reach the same machine.

const Fixture := preload("res://tests/integration/world_trainer_fixture.gd")

const STACK: int = 7
const POTION: int = 0x14
const NICKNAMES: Array[String] = ["ALPHA", "BRAVO", "CHARLIE"]

## `text_ram` slots stand in for `wStringBuffer` and `wNameBuffer`, which is all
## the fill reads; the words are short stand-ins.
const SPECIAL_TEXT: Dictionary = {
	"pc": {"accessed_someones": "Accessed SOMEONE's\nPC."},
	"bills_pc": {"what": "What?"},
	"bills_pc_2": {
		"once_released": "Once released,\n<RAM_CF4B> is\ngone forever. OK?",
		"mon_was_released": "<RAM_CD6D> was\nreleased.",
	},
	"toss": {
		"ok_to_toss": "Is it OK to toss\n<RAM_CF4B>?",
		"threw_away": "Threw away\n<RAM_CF4B>.",
	},
}

var _data: GameData = null
var _world_screen: Gen2WorldScreen = null


func before_each() -> void:
	Gen2ModHost.reset()
	_data = Fixture.build()
	var items: Array = RomCache.read_json(RomCache.items_path(Fixture.directory()))
	for raw: Dictionary in items:
		match int(raw.get("number", 0)):
			STACK:
				raw["name"] = "ITEM7"
			POTION:
				raw["name"] = "POTION"
	RomCache.write_json(RomCache.items_path(Fixture.directory()), items)
	var manifest: Dictionary = RomCache.read_manifest(Fixture.directory())
	var special: Dictionary = manifest.get("special_text", {})
	special.merge(SPECIAL_TEXT, true)
	manifest["special_text"] = special
	RomCache.write_json(RomCache.manifest_path(Fixture.directory()), manifest)
	_data = GameData.open_directory(Fixture.directory())
	_data.generation = RomRegistry.GEN1


func after_each() -> void:
	if is_instance_valid(_world_screen):
		_world_screen.free()
		_world_screen = null
	RomCache.clear(Fixture.directory())
	Gen2ModHost.reset()


## `ActivatePC`'s top menu over the map, with three mons in the current box and
## two stacks in the PC.
func _open_machine() -> Gen2WorldServiceScreen:
	var packed: PackedScene = load("res://game/world/world_screen.tscn")
	_world_screen = packed.instantiate() as Gen2WorldScreen
	_world_screen.map_group = Fixture.MAP_GROUP
	_world_screen.map_number = Fixture.MAP_NUMBER
	_world_screen.start_cell = Vector2i(7, 6)
	var state := Gen2WorldState.new({}, {}, {}, {0: 500})
	var world := Gen2WorldAPI.open(
		_data, Fixture.MAP_GROUP, Fixture.MAP_NUMBER, Vector2i(7, 6), state
	)
	var save := Gen2SaveStore.create_development_save(_data, 0)
	save.world = world.snapshot()
	save.party.resize(1)
	for slot: int in NICKNAMES.size():
		var mon: Gen2SaveMon = Gen2SaveMon.from_dict(save.party[0].to_dict())
		mon.nickname = NICKNAMES[slot]
		save.boxes[0].slots[slot] = mon
	_world_screen.set_data(_data)
	_world_screen.set_save(save)
	add_child(_world_screen)
	await get_tree().process_frame
	_world_screen._world.state.apply_changes({}, {}, {"pc_items": {STACK: 5, POTION: 3}})
	_world_screen._open_service_overlay(&"pc")
	var host: Gen2WorldServiceScreen = _world_screen._service_host
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC)
	return host


## A top-menu row and the one box `ActivatePC` prints behind it.
func _take_top_row(host: Gen2WorldServiceScreen, row: int) -> void:
	for _step: int in row:
		host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_TEXT)
	host.handle_button(PokeButton.A)


## A row of `BillsPCMenu` onto its mon list, and the list walked to [param row].
func _open_mon_list(host: Gen2WorldServiceScreen, menu_row: int, row: int) -> void:
	_take_top_row(host, Gen2WorldPC.GEN1_PC_BILLS)
	for _step: int in menu_row:
		host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_MON_LIST)
	for _step: int in row:
		host.handle_button(PokeButton.DOWN)


func _box_names(host: Gen2WorldServiceScreen) -> Array:
	var out: Array = []
	for entry: Dictionary in Gen2WorldPC.gen1_box_entries(host._save, 0):
		out.append((entry["mon"] as Gen2SaveMon).nickname)
	return out


## `BillsPC_`'s `BillsPCMenu`: the accessed box, then the menu on its first row,
## and B off it is `ExitBillsPC` back to `ActivatePC`'s own menu.
func test_bills_pc_lands_on_its_own_menu() -> void:
	var host: Gen2WorldServiceScreen = await _open_machine()
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_TEXT)
	assert_eq(host._summary, "Accessed SOMEONE's\nPC.")
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_BOXES)
	assert_eq(host._pc_rows, Gen2WorldPC.gen1_bills_pc_menu())
	assert_eq(host._cursor, 0)
	host.handle_button(PokeButton.B)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC)


## `BillsPCRelease`: `OnceReleasedText` names the mon under the cursor, its two
## pages are pressed through, and YES releases that one and no other.
func test_release_asks_about_and_releases_the_chosen_mon() -> void:
	var host: Gen2WorldServiceScreen = await _open_machine()
	_open_mon_list(host, Gen2WorldPC.GEN1_BILLS_PC_RELEASE, 1)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_ASK)
	assert_eq(host._summary, "Once released,\nBRAVO is")
	host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	assert_eq(host._summary, "gone forever. OK?")
	assert_eq(host._cursor, 0, "the page's DOWN moved nothing")
	host.handle_button(PokeButton.A)
	assert_eq(_box_names(host), NICKNAMES, "the answer is held first")
	for _frame: int in Gen2WorldMenu.ANSWER_HOLD_FRAMES:
		host.advance_frame()
	assert_eq(_box_names(host), ["ALPHA", "CHARLIE"])
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_TEXT)
	assert_eq(host._summary, "BRAVO was\nreleased.")


## NO, and B which is NO's own answer: the list comes back on the row it left
## with every mon still in it.
func test_refusing_the_release_reopens_the_list_on_the_same_row() -> void:
	var host: Gen2WorldServiceScreen = await _open_machine()
	_open_mon_list(host, Gen2WorldPC.GEN1_BILLS_PC_RELEASE, 2)
	for refusal: Array in [[PokeButton.DOWN, PokeButton.A], [PokeButton.B]]:
		host.handle_button(PokeButton.A)
		host.handle_button(PokeButton.A)
		assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_ASK)
		for button: int in refusal:
			host.handle_button(button)
		for _frame: int in Gen2WorldMenu.ANSWER_HOLD_FRAMES:
			host.advance_frame()
		assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_MON_LIST)
		assert_eq(host._cursor, 2)
		assert_eq(_box_names(host), NICKNAMES)


## `BillsPCWithdraw`'s `DisplayDepositWithdrawMenu` acts on the mon chosen on
## the list, not on the submenu's own row.
func test_withdraw_takes_the_chosen_mon_out() -> void:
	var host: Gen2WorldServiceScreen = await _open_machine()
	_open_mon_list(host, Gen2WorldPC.GEN1_BILLS_PC_WITHDRAW, 2)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_MON_ACTION)
	host.handle_button(PokeButton.A)
	assert_eq(_box_names(host), ["ALPHA", "BRAVO"])
	assert_eq(host._save.party.size(), 2)
	assert_eq((host._save.party[1] as Gen2SaveMon).nickname, "CHARLIE")


## `PlayerPCToss`: `DisplayChooseQuantityMenu`, then `TossItem_`'s
## `IsItOKToTossItemText` naming the chosen stack, and YES tosses from it.
func test_toss_asks_about_and_tosses_the_chosen_stack() -> void:
	var host: Gen2WorldServiceScreen = await _open_machine()
	_take_top_row(host, Gen2WorldPC.GEN1_PC_PLAYERS)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_ITEMS)
	for _step: int in Gen2WorldPC.GEN1_PLAYERS_PC_TOSS:
		host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_ITEM_LIST)
	host.handle_button(PokeButton.DOWN)
	assert_eq(int(host._pc_entries[host._cursor]["item"]), POTION)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_ITEM_QUANTITY)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_ASK)
	assert_eq(host._summary, "Is it OK to toss\nPOTION?")
	host.handle_button(PokeButton.A)
	for _frame: int in Gen2WorldMenu.ANSWER_HOLD_FRAMES:
		host.advance_frame()
	var state: Gen2WorldState = _world_screen._world.state
	assert_eq(state.pc_item_quantity(POTION), 2)
	assert_eq(state.pc_item_quantity(STACK), 5)
	assert_eq(host._summary, "Threw away\nPOTION.")


## `PlayerPCToss`'s `jp .loop` keeps `wCurrentMenuItem`: a dial backed out of
## comes back on the row it left, and the menu's own cursor is untouched.
func test_the_toss_list_keeps_its_row_across_the_dial() -> void:
	var host: Gen2WorldServiceScreen = await _open_machine()
	_take_top_row(host, Gen2WorldPC.GEN1_PC_PLAYERS)
	for _step: int in Gen2WorldPC.GEN1_PLAYERS_PC_TOSS:
		host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	host.handle_button(PokeButton.DOWN)
	assert_eq(host._cursor, 1)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_ITEM_QUANTITY)
	host.handle_button(PokeButton.B)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_ITEM_LIST)
	assert_eq(host._cursor, 1)
	host.handle_button(PokeButton.B)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_ITEMS)
	assert_eq(host._cursor, Gen2WorldPC.GEN1_PLAYERS_PC_TOSS, "the menu row it was opened from")
