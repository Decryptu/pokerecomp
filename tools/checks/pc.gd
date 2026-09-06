extends RefCounted

var _r: RefCounted = null

## Verifies Bill's PC's graphics and its screen against freshly imported real
## caches over every species, and Generation 1's three machines beside them. Expected values come from
## `engine/pokemon/bills_pc.asm`: `BillsPC_InitGFX`'s two runs, `_CGB_BillsPC`'s
## palettes, `BillsPC_UpdateSelectionCursor`'s ring and `PCMonInfo`'s left column.
## The sweep is over species because that column is the one thing whose width is
## not fixed: a pic wider than its seven-tile cell, or a name wider than the two
## boxes `ClearBox` leaves for it, would overrun the listing.

## `BillsPCOrangePalette`, `gfx/pc/orange.pal`, which is the same four colours in
## all three dumps.
const ORANGE: Array[int] = [0x01FF, 0x0197, 0x00EF, 0x0000]
const SPECIES_COUNT: int = 251
## What `PCMonInfo` clears for the pic, the name and the level: eight columns
## (`hlcoord 0, 0 / lb bc, 15, 8`) plus the three past them on the name's own row
## (`hlcoord 8, 14 / lb bc, 1, 3`), which the ten-tile species names need.
const INFO_COLUMNS: int = 8
const NAME_OVERHANG: Vector2i = Vector2i(8, 14)
const NAME_OVERHANG_COLUMNS: int = 3

## `BillsPC_UpdateSelectionCursor`'s `.OAM`, transcribed from the two
## disassemblies rather than read back out of the page: repeated `dbsprite` rows
## folded into `[first x tile, count, y tile, x pixel, y pixel, tile, x, y flip]`.
## The macro lays down `y tile * 8 + y pixel` and `x tile * 8 + x pixel`.
const CRYSTAL_OAM: Array = [
	[10, 9, 4, 0, 6, 0, false, false], [18, 1, 4, 7, 6, 0, false, false],
	[10, 9, 7, 0, 1, 0, false, true], [18, 1, 7, 7, 1, 0, false, true],
	[9, 1, 5, 6, 6, 1, false, false], [9, 1, 6, 6, 1, 1, false, true],
	[19, 1, 5, 1, 6, 1, true, false], [19, 1, 6, 1, 1, 1, true, true],
]
const GOLD_OAM: Array = [
	[9, 1, 5, 7, 1, 0, false, false], [10, 8, 5, 7, 1, 1, false, false],
	[18, 1, 5, 7, 1, 2, false, false],
	[9, 1, 6, 7, 1, 3, false, false], [10, 8, 6, 7, 1, 4, false, false],
	[18, 1, 6, 7, 1, 5, false, false],
]
const OAM_X_BIAS: int = 8
const OAM_Y_BIAS: int = 16

## Every slot of the runs Generation 1's own machines print from.
const GEN1_TEXT_RUNS: Dictionary = {
	"pc": ["turned_on", "accessed_bills", "accessed_someones", "accessed_mine"],
	"players_pc": [
		"turned_on", "what_do_you_want", "what_to_deposit", "deposit_how_many",
		"item_was_stored", "nothing_to_deposit", "no_room_to_store",
		"what_to_withdraw", "withdraw_how_many", "withdrew_item", "nothing_stored",
		"cant_carry_more", "what_to_toss", "toss_how_many",
	],
	"bills_pc": [
		"switch_on", "what", "mon_was_stored", "cant_deposit_last", "box_full",
		"mon_is_taken_out", "no_mon", "cant_take_mon",
	],
	"bills_pc_2": ["once_released", "mon_was_released"],
	"oaks_pc": ["get_rated", "closed", "accessed"],
	"hof_pc": ["accessed"],
	"change_box": ["warning"],
	"choose_box": ["choose"],
}
## `DisplayPCMainMenu` before the Pokedex, after it, and once `wNumHoFTeams` is
## not zero.
const GEN1_TOP_MENU_ROWS: Array[int] = [3, 4, 5]
## A box with nothing in it refuses a withdrawal and a release and takes a
## deposit, the development save's party being six.
const GEN1_EMPTY_BOX_REFUSALS: Array[StringName] = [&"", &"no_mon", &"no_mon"]


func run(r: RefCounted) -> void:
	_r = r
	for game_id: StringName in _r.GAME_IDS:
		var data: GameData = GameData.open(game_id)
		if data == null:
			_r.fail("%s cache is unavailable. Import roms/%s.gbc first." % [game_id, game_id])
			continue
		_verify_graphics(game_id, data)
		_verify_cursor(game_id, Gen2PCBoxPage.from_data(data))
		_verify_info_column(game_id, data)
	r.each_game_of(RomRegistry.GEN1, _verify_gen1)


## Generation 1's three machines: every box `ActivatePC`, `PlayerPC`, `BillsPC_`,
## `OpenOaksPC` and `ChangeBox` print, `DexRatingsTable` whole, and the menus
## and refusals the three read.
func _verify_gen1() -> void:
	var data: GameData = _r.data
	for run_name: String in GEN1_TEXT_RUNS:
		for slot: String in GEN1_TEXT_RUNS[run_name] as Array:
			_r.check(not data.special_text(run_name, slot).is_empty(),
				"%s's %s box is empty." % [run_name, slot])
	_verify_gen1_ratings(data)
	_verify_gen1_menus(data)
	_r.check(Gen2StatsScreenPage.from_data(data) != null,
		"StatusScreen has no tile page.")


## `DexRatingsTable`, and `DisplayDexRating`'s `cp b / jr c`: a row answers for
## the counts under its own threshold, so 9 owned takes the first row and 10
## takes the second.
func _verify_gen1_ratings(data: GameData) -> void:
	var rows: Array = data.oak_ratings()
	if not _r.check(rows.size() == Gen1Layout.DEX_RATING_ROWS,
		"%d rating rows." % rows.size()):
		return
	for index: int in rows.size():
		var row: Dictionary = rows[index]
		_r.check(not String(row.get("text", "")).is_empty(),
			"rating row %d has no text." % index)
	for caught: int in [0, 9, 10, 149, 151]:
		var wanted: int = 0
		for index: int in rows.size():
			if caught < int((rows[index] as Dictionary)["threshold"]):
				wanted = index
				break
		_r.check(
			Gen2ProfOaksPC.rating_for(data, caught) == rows[wanted],
			"%d owned did not land on row %d." % [caught, wanted]
		)
	_r.check(not data.oak_pc_text("counts").is_empty(),
		"DexCompletionText is empty.")


## `DisplayPCMainMenu`'s list, which grows with the Pokedex and again with
## `wNumHoFTeams`, and `BillsPCDeposit`, `BillsPCWithdraw` and `BillsPCRelease`'s
## own refusals.
func _verify_gen1_menus(data: GameData) -> void:
	var state := Gen2WorldState.new()
	var rows: Array[int] = []
	for open_dex: bool in [false, true]:
		state.set_engine_flag(Gen2WorldState.ENGINE_POKEDEX, open_dex)
		rows.append(Gen2WorldPC.gen1_top_menu(state, "RED").size())
	state.set_hall_of_fame(true)
	rows.append(Gen2WorldPC.gen1_top_menu(state, "RED").size())
	_r.check(rows == GEN1_TOP_MENU_ROWS,
		"the machine's menu reads %s." % [rows])
	var items: int = Gen2WorldPC.gen1_players_pc_menu().size()
	var boxes: int = Gen2WorldPC.gen1_bills_pc_menu().size()
	_r.check(
		items == Gen2WorldPC.GEN1_PLAYERS_PC_ROWS.size()
			and boxes == Gen2WorldPC.GEN1_BILLS_PC_ROWS.size(),
		"the item menu reads %d rows and the box menu %d." % [items, boxes]
	)
	_r.check(
		Gen2WorldPC.gen1_box_menu(null).size() == Gen1Layout.BOX_COUNT,
		"the box picker is not twelve rows."
	)
	var save: Gen2SaveData = Gen2SaveStore.create_development_save(data, 0)
	if not _r.check(save != null, "no development save."):
		return
	var refusals: Array[StringName] = []
	for row: int in [
		Gen2WorldPC.GEN1_BILLS_PC_DEPOSIT, Gen2WorldPC.GEN1_BILLS_PC_WITHDRAW,
		Gen2WorldPC.GEN1_BILLS_PC_RELEASE,
	]:
		refusals.append(Gen2WorldPC.gen1_bills_pc_refusal(save, row, 0))
	_r.check(refusals == GEN1_EMPTY_BOX_REFUSALS,
		"an empty box refused with %s." % [refusals])


## `BillsPC_InitGFX`'s two sheets and the palette `_CGB_BillsPC` loads over the
## pic box for a row with no Pokemon on it.
func _verify_graphics(game_id: StringName, data: GameData) -> void:
	for run_row: Array in [
		["pc_select", Gen2Layout.PC_SELECT_TILES], ["pc_mail", Gen2Layout.PC_MAIL_TILES],
	]:
		var strip: PackedByteArray = data.tile_indices(String(run_row[0]))
		var want: int = int(run_row[1]) * PokeTiles.TILE_WIDTH * PokeTiles.TILE_HEIGHT
		_r.check(
			strip.size() == want,
			"%s: %s is %d pixels, not the %d its %d tiles need." % [
				game_id, String(run_row[0]), strip.size(), want, int(run_row[1]),
			]
		)
	var palette: PackedColorArray = data.pc_palette()
	if not _r.check(
		palette.size() == Gen2Layout.PC_PALETTE_COLORS,
		"%s: the PC palette holds %d colours, not %d." % [
			game_id, palette.size(), Gen2Layout.PC_PALETTE_COLORS,
		]
	):
		return
	for index: int in ORANGE.size():
		_r.check(
			palette[index].is_equal_approx(PokePalette.from_packed(ORANGE[index])),
			"%s: PC colour %d is %s, not the pinned $%04X." % [
				game_id, index, palette[index], ORANGE[index],
			]
		)


## `.OAM` object by object against the disassembly's own operands, and the
## sixteen pixels a row it steps by, which says the shadow-OAM bias came off once
## rather than twice. A bottom bar that drifts off its own sides is what this
## pins: bounds alone still read it as an object inside the listing.
func _verify_cursor(game_id: StringName, page: Gen2PCBoxPage) -> void:
	if not _r.check(page != null, "%s: the PC page needs a font." % game_id):
		return
	var wanted: Array = _expected_oam(
		CRYSTAL_OAM if game_id == RomRegistry.CRYSTAL else GOLD_OAM
	)
	var drawn: Array = page.cursor_set()
	if not _r.check(
		drawn.size() == wanted.size(),
		"%s: the ring draws %d objects, not the %d `.OAM` lays down." % [
			game_id, drawn.size(), wanted.size(),
		]
	):
		return
	for index: int in wanted.size():
		_r.check(
			Array(drawn[index]) == Array(wanted[index]),
			"%s: ring object %d is %s, not `dbsprite`'s %s." % [
				game_id, index, drawn[index], wanted[index],
			]
		)
	var first: Array = page.cursor_sprites(0, 1)
	for cursor: int in Gen2PCBoxPage.LIST_HEIGHT:
		var sprites: Array = page.cursor_sprites(cursor, 1)
		for index: int in sprites.size():
			var step: int = Vector2i(sprites[index]["position"]).y \
				- Vector2i(first[index]["position"]).y
			_r.check(
				step == cursor * Gen2PCBoxPage.CURSOR_STEP,
				"%s: cursor %d object %d sits %d pixels down, not %d." % [
					game_id, cursor, index, step,
					cursor * Gen2PCBoxPage.CURSOR_STEP,
				]
			)
	_r.check(
		page.cursor_sprites(0, 0).is_empty(),
		"%s: a list with nothing in it still draws a cursor." % game_id
	)


## One run list as the page's own `[x, y, tile, flips]` rows.
func _expected_oam(runs: Array) -> Array:
	var out: Array = []
	for row: Array in runs:
		for step: int in int(row[1]):
			out.append([
				(int(row[0]) + step) * Gen2Font.TILE + int(row[3]) - OAM_X_BIAS,
				int(row[2]) * Gen2Font.TILE + int(row[4]) - OAM_Y_BIAS,
				int(row[5]), bool(row[6]), bool(row[7]),
			])
	return out


## `PCMonInfo`'s column over the whole species run: the pic fits the seven-tile
## cell and the name fits the eleven columns its two clears cover.
func _verify_info_column(game_id: StringName, data: GameData) -> void:
	var cell: int = Gen2PCBoxPage.pic_size()
	var widest: int = 0
	var widest_name: String = ""
	for species: int in range(1, SPECIES_COUNT + 1):
		var pic: Dictionary = data.species_pic(species)
		if not _r.check(not pic.is_empty(), "%s: species %d has no pic." % [game_id, species]):
			continue
		_r.check(
			int(pic.get("width", 0)) <= cell and int(pic.get("height", 0)) <= cell,
			"%s: species %d is %dx%d, past the %dx%d cell." % [
				game_id, species, int(pic["width"]), int(pic["height"]), cell, cell,
			]
		)
		var name: String = String(data.species(species).get("name", ""))
		var columns: int = Gen2Text.encoded_length(name, Gen2Text.FONT_BATTLE_EXTRA)
		if columns > widest:
			widest = columns
			widest_name = name
	_r.check(
		Gen2PCBoxPage.SPECIES_AT.x + widest <= INFO_COLUMNS + NAME_OVERHANG_COLUMNS,
		"%s: %s is %d columns and runs past the %d PCMonInfo clears." % [
			game_id, widest_name, widest, INFO_COLUMNS + NAME_OVERHANG_COLUMNS,
		]
	)
	_r.check(
		Gen2PCBoxPage.SPECIES_AT.y == NAME_OVERHANG.y \
			and Gen2PCBoxPage.SPECIES_AT.x + widest <= NAME_OVERHANG.x + NAME_OVERHANG_COLUMNS,
		"%s: the name row is not the one the second ClearBox covers." % game_id
	)
