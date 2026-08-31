extends RefCounted

var _r: RefCounted = null

## `NPCTrade` (`engine/events/npc_trade.asm`) against freshly imported real
## caches, over every row of `NPCTrades` and every cell of `TradeTexts` rather
## than one sampled trader. A cell that resolves to the wrong variant still
## prints a sensible English box, and an unfilled `text_ram` marker is only
## visible in the finished string, so neither is something a screen test sees.
## Expected values are transcribed from the pins, not read back from the cache.

## Crystal's seven rows and Gold and Silver's six, as (dialog set, wanted,
## offered, nickname, item, OT id, OT name, gender). Crystal's first row asks for
## ABRA where Gold and Silver ask for DROWZEE, and their fourth and fifth rows
## are different trades rather than the same one renumbered.
const EXPECTED_TRADES: Dictionary = {
	&"crystal": [
		[0, 63, 66, "MUSCLE", 0xAE, 37460, "MIKE", 0],
		[0, 69, 95, "ROCKY", 0x53, 48926, "KYLE", 0],
		[1, 98, 100, "VOLTY", 0x4E, 29189, "TIM", 0],
		[3, 148, 85, "DORIS", 0x6A, 283, "EMY", 2],
		[2, 93, 178, "PAUL", 0x96, 15616, "CHRIS", 0],
		[3, 113, 142, "AEROY", 0xAE, 26491, "KIM", 0],
		[0, 51, 82, "MAGGIE", 0x8F, 50082, "FOREST", 0],
	],
	&"gold": [
		[0, 96, 66, "MUSCLE", 0xAE, 37460, "MIKE", 0],
		[0, 69, 95, "ROCKY", 0x53, 48926, "KYLE", 0],
		[1, 98, 100, "VOLTY", 0x4E, 29189, "TIM", 0],
		[2, 148, 112, "DON", 0x53, 283, "EMY", 2],
		[1, 44, 78, "RUNNY", 0x4F, 15616, "CHRIS", 0],
		[2, 113, 142, "AEROY", 0xAE, 26491, "KIM", 0],
	],
}

## The five `TRADE_DIALOG_*` rows, in the table's own order.
const DIALOGS: Array[String] = ["intro", "cancel", "wrong", "complete", "after"]

## One line out of each variant, far enough in to tell it from its neighbours.
## `after_4` and `complete_4` are Crystal's alone.
const EXPECTED_LINES: Dictionary = {
	"intro_1": "I collect", "intro_2": "looking", "intro_3": "cute",
	"cancel_1": "Aww", "cancel_2": "disappointing", "cancel_3": "darn",
	"wrong_1": "letdown", "wrong_2": "too bad", "wrong_3": "Please trade",
	"complete_1": "Yay!", "complete_2": "Great!", "complete_3": "Wow!",
	"complete_4": "Uh? What happened?",
	"after_1": "how", "after_2": "doing great", "after_3": "How is that",
	"after_4": "Trading is so odd",
}

## `GetTradeMonNames`' tail. Only EMY's row asks for a gender in either pin.
const GENDER_SYMBOLS: Dictionary = {
	RomLayout.TRADE_GENDER_MALE: "♂", RomLayout.TRADE_GENDER_FEMALE: "♀",
}


func run(r: RefCounted) -> void:
	_r = r
	_r.each_game(_verify_game)


func _verify_game() -> void:
	var expected: Array = EXPECTED_TRADES.get(
		_r.game_id if _r.crystal else &"gold", []
	)
	if not _r.check(
		_r.data.world_trade_count() == expected.size(),
		"%d trade rows, not %d" % [_r.data.world_trade_count(), expected.size()]
	):
		return
	for index: int in expected.size():
		_verify_row(index, expected[index] as Array)
	_verify_boxes()
	_r.note("%d trade rows and %d dialog cells verified." % [
		expected.size(), DIALOGS.size() * (4 if _r.crystal else 3),
	])


## One `NPCTrades` row, every field of it. The DVs are checked as a word because
## the two nibbles of each byte are a stat apiece and a swapped pair reads as a
## plausible Pokemon.
func _verify_row(index: int, expected: Array) -> void:
	var row: Dictionary = _r.data.world_trade(index)
	for field: Array in [
		["dialog", expected[0]], ["requested_species", expected[1]],
		["offered_species", expected[2]], ["nickname", expected[3]],
		["item", expected[4]], ["ot_id", expected[5]], ["ot_name", expected[6]],
		["gender", expected[7]],
	]:
		_r.check(
			row.get(field[0], null) == field[1],
			"trade %d's %s is %s, not %s" % [
				index, field[0], row.get(field[0], "<missing>"), field[1],
			]
		)
	_r.check(
		int(row.get("dvs", 0)) > 0 and int(row.get("dvs", 0)) <= 0xFFFF,
		"trade %d's DV word is %d" % [index, int(row.get("dvs", 0))]
	)


## Every cell of `TradeTexts`, resolved the way the script command resolves it:
## through a runner whose `GetTradeMonNames` buffers are already filled, so an
## unfilled `text_ram` marker is a failure rather than a `<RAM_D073>` on screen.
func _verify_boxes() -> void:
	var runner := Gen2WorldScriptRunner.new()
	runner.data = _r.data
	runner.player_name = "GOLD"
	var sets: int = 4 if _r.crystal else 3
	for index: int in _r.data.world_trade_count():
		var record: Dictionary = _r.data.world_trade(index)
		runner.call(&"_set_trade_names", record)
		for dialog: int in DIALOGS.size():
			_verify_cell(runner, index, dialog, int(record.get("dialog", 0)), sets)
		_verify_names(runner, index, record)
	for name: String in ["cable", "traded_for"]:
		_r.check(
			not String(runner.call(&"_special_box", "npc_trade", name)).is_empty(),
			"the %s box did not resolve" % name
		)


func _verify_cell(
	runner: Gen2WorldScriptRunner, index: int, dialog: int, dialog_set: int, sets: int
) -> void:
	if not _r.check(
		dialog_set >= 0 and dialog_set < sets,
		"trade %d names dialog set %d of %d" % [index, dialog_set, sets]
	):
		return
	var name: String = RomLayout.trade_text_name(_r.crystal, dialog, dialog_set)
	var box: String = String(runner.call(&"_trade_dialog_text", {
		"dialog": dialog_set,
	}, dialog))
	_r.check(
		box.contains(String(EXPECTED_LINES.get(name, "?"))),
		"trade %d's %s box is \"%s\", which is not %s" % [
			index, DIALOGS[dialog], box, name,
		]
	)
	_r.check(
		not box.contains(Gen2TextStream.RAM_MARKER) and not box.contains("<PLAYER"),
		"trade %d's %s box left a marker unfilled: \"%s\"" % [
			index, DIALOGS[dialog], box,
		]
	)


## `wStringBuffer1` carries the wanted species with the row's gender symbol
## written over its terminator, and `wStringBuffer2` the offered one. The intro
## box names both, so it is where a swapped pair shows.
func _verify_names(
	runner: Gen2WorldScriptRunner, index: int, record: Dictionary
) -> void:
	var wanted: String = String(
		_r.data.species(int(record["requested_species"])).get("name", "")
	) + String(GENDER_SYMBOLS.get(int(record.get("gender", 0)), ""))
	var offered: String = String(
		_r.data.species(int(record["offered_species"])).get("name", "")
	)
	var intro: String = String(runner.call(&"_trade_dialog_text", record, 0))
	for name: String in [wanted, offered]:
		_r.check(
			intro.contains(name),
			"trade %d's intro box does not name %s: \"%s\"" % [index, name, intro]
		)
