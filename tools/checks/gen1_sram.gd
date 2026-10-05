extends RefCounted

## Reads saves the real Red, Blue and Yellow wrote and exports one they load.
## `GEN1_SAV_ORACLE` is the command of a local PyBoy script that saves a WRAM
## scenario through the game's own START menu and reports the saved bytes; unset,
## the topic notes it and passes. Nothing it writes is kept.

const ORACLE: String = "GEN1_SAV_ORACLE"
const MONEY_AFTER: int = 654321
const COINS_AFTER: int = 111
const EDITED_CELL: Vector2i = Vector2i(2, 2)
const EDITED_BOX: int = 5
const FLAG_RUNS: Array[String] = [
	"status_flags_4", "obtained_hidden_items", "obtained_hidden_coins", "town_visited",
	"status_flags_1", "elite_4_flags", "beat_gym_flags", "pikachu_map_script_flags",
]

var _r: RefCounted = null
var _expected: Dictionary = {}
var _snapshot: Gen2WorldSnapshot = null


func run(r: RefCounted) -> void:
	_r = r
	_r.each_game_of(RomRegistry.GEN1, _one)


func _one() -> void:
	if OS.get_environment(ORACLE).is_empty():
		_r.note("%s is unset: cartridge-made saves skipped" % ORACLE)
		return
	var sav: String = OS.get_temp_dir().path_join("gen1_sram_%s.sav" % _r.game_id)
	var made: String = OS.get_temp_dir().path_join("gen1_sram_%s.json" % _r.game_id)
	if not _oracle([String(_r.game_id), sav, made]):
		return
	_expected = JSON.parse_string(FileAccess.get_file_as_string(made))
	var raw: PackedByteArray = FileAccess.get_file_as_bytes(sav)
	var imported: Dictionary = Gen2SramAdapter.import_bytes(_r.game_id, _r.data.sha1, 0, raw, _r.data)
	if _r.check(imported["ok"], "the cartridge save is refused: %s" % imported["message"]):
		var save: Gen2SaveData = imported["save"]
		_snapshot = save.world
		_trainer(save)
		_party(save)
		_boxes(save)
		_world(save)
		_hall(save)
		_opens(save)
		_screen(save)
		_round_trip(save, raw)
		_edited(save, raw, sav)
		_r.note("%d bytes imported, exported byte for byte, and an edited export loaded by the game" % raw.size())
	for path: String in [sav, made]:
		DirAccess.remove_absolute(path)


func _oracle(args: Array) -> bool:
	var line: String = "%s '%s' 2>&1" % [OS.get_environment(ORACLE), "' '".join(PackedStringArray(args))]
	var output: Array = []
	var code: int = OS.execute("/bin/sh", ["-c", line], output, true)
	return _r.check(code == 0, "the PyBoy oracle failed (%d): %s" % [code, output])


func _trainer(save: Gen2SaveData) -> void:
	_r.check(save.player_name == _expected["player_name"], "player name is %s" % save.player_name)
	_r.check(save.player_id == int(_expected["player_id"]), "player ID is %d" % save.player_id)
	_r.check(save.world.rival_name == _expected["rival_name"], "rival is %s" % save.world.rival_name)
	var time: Array = _expected["play_time"]
	_r.check(
		[save.game_time.hours, save.game_time.capped, save.game_time.minutes, save.game_time.seconds, save.game_time.frames]
		== [int(time[0]), int(time[1]) != 0, int(time[2]), int(time[3]), int(time[4])],
		"play time is %s" % save.game_time.to_dict()
	)


func _party(save: Gen2SaveData) -> void:
	var rows: Array = _expected["party"]
	if not _r.check(save.party.size() == rows.size(), "party holds %d" % save.party.size()):
		return
	for slot: int in rows.size():
		var mon: Gen2SaveMon = save.party[slot]
		_mon(mon, rows[slot], "party %d" % slot)
		_r.check(int(mon.stats.get("hp", 0)) == int(rows[slot]["max_hp"]), "party %d max HP is %s" % [slot, mon.stats])


func _mon(mon: Gen2SaveMon, row: Dictionary, label: String) -> void:
	var exp_keys: Array = ["hp", "attack", "defense", "speed", "special"]
	var stat_exp: Array = []
	for key: String in exp_keys:
		stat_exp.append(int(mon.stat_exp[key]))
	var got: Dictionary = {
		"species": mon.species, "level": mon.level, "dvs": mon.dvs, "exp": mon.exp,
		"moves": mon.moves, "pp": mon.pp, "pp_ups": mon.pp_ups, "status": mon.status, "hp": mon.hp,
		"catch_rate": mon.catch_rate, "ot_id": mon.ot_id, "ot": mon.original_trainer,
		"nickname": mon.nickname, "stat_exp": stat_exp,
	}
	for key: String in got:
		_r.check(_same(got[key], row[key]), "%s %s is %s, not %s" % [label, key, got[key], row[key]])


static func _difference(a: Variant, b: Variant, path: String = "") -> String:
	if a is Dictionary and b is Dictionary:
		for key: Variant in (a as Dictionary).keys() + (b as Dictionary).keys():
			if not (a as Dictionary).has(key) or not (b as Dictionary).has(key):
				return "%s/%s" % [path, key]
			var inner: String = _difference(a[key], b[key], "%s/%s" % [path, key])
			if not inner.is_empty():
				return inner
		return ""
	if a is Array and b is Array:
		if (a as Array).size() != (b as Array).size():
			return "%s has %d and %d" % [path, (a as Array).size(), (b as Array).size()]
		for index: int in (a as Array).size():
			var inner: String = _difference(a[index], b[index], "%s[%d]" % [path, index])
			if not inner.is_empty():
				return inner
		return ""
	var same: bool = (a is float or a is int) and (b is float or b is int) and float(a) == float(b)
	return "" if same or (typeof(a) == typeof(b) and a == b) else "%s: %s, not %s" % [path, a, b]


static func _same(a: Variant, b: Variant) -> bool:
	if a is Array and b is Array:
		if (a as Array).size() != (b as Array).size():
			return false
		for index: int in (a as Array).size():
			if not _same((a as Array)[index], (b as Array)[index]):
				return false
		return true
	if a is Dictionary and b is Dictionary:
		for key: Variant in a as Dictionary:
			if not (b as Dictionary).has(key) or not _same(a[key], b[key]):
				return false
		return (a as Dictionary).size() == (b as Dictionary).size()
	if a is String or b is String:
		return String(a) == String(b)
	return int(a) == int(b)


func _boxes(save: Gen2SaveData) -> void:
	var current: int = int(_expected["current_box"])
	_r.check(save.current_box == current, "current box is %d" % save.current_box)
	for index: int in save.boxes.size():
		var rows: Array = []
		if index == current:
			rows = _expected["current_box_mons"]
		elif (_expected["boxes"] as Dictionary).has(str(index)):
			rows = _expected["boxes"][str(index)]
		var box: Gen2SaveBox = save.boxes[index]
		if not _r.check(box.occupied_count() == rows.size(), "box %d holds %d" % [index, box.occupied_count()]):
			continue
		for slot: int in rows.size():
			_mon(box.slots[slot], rows[slot], "box %d slot %d" % [index, slot])


func _world(save: Gen2SaveData) -> void:
	var world: Gen2WorldSnapshot = save.world
	var state: Gen2WorldState = world.world_state
	var cell: Array = _expected["cell"]
	_r.check(world.map_id == Vector2i(0, int(_expected["map"])), "map is %s" % world.map_id)
	_r.check(world.gen1_last_blackout_map == int(_expected["last_blackout"]), "blackout map")
	_r.check(world.player_cell == Vector2i(int(cell[0]), int(cell[1])), "cell is %s" % world.player_cell)
	_stacks(state.items(), _expected["bag"], "bag")
	_stacks(state.pc_items(), _expected["pc"], "item PC")
	_r.check(state.money() == int(_expected["money"]), "money is %d" % state.money())
	_r.check(state.coins() == int(_expected["coins"]), "coins are %d" % state.coins())
	for bit: int in 8:
		_r.check(
			state.is_engine_flag_active(Gen2WorldState.gen1_badge_flag(bit)) == ((int(_expected["badges"]) >> bit) & 1 == 1),
			"badge %d" % bit
		)
	_bits(_expected["event_bytes"], state.is_event_flag_active, "event flag")
	_bits(_expected["trade_bytes"], state.npc_trade_done, "in-game trade")
	_species(state.caught_species(), _expected["owned"], "owned")
	_species(state.seen_species(), _expected["seen"], "seen")
	_toggles(state)
	_progress(state)
	_runs(state)
	_r.check(state.day_care_has_mon(0), "the Day-Care holds nobody")
	_mon(state.day_care_mon(0), _expected["day_care"], "day care")


func _stacks(items: Dictionary, rows: Array, label: String) -> void:
	var got: Array = []
	for item: Variant in items:
		got.append([int(item), int(items[item])])
	_r.check(_same(got, rows), "%s is %s, not %s" % [label, got, rows])


func _species(got: Dictionary, rows: Array, label: String) -> void:
	var numbers: Array = []
	for dex: Variant in got:
		numbers.append(int(dex))
	numbers.sort()
	_r.check(_same(numbers, rows), "%s Pokedex is %s, not %s" % [label, numbers, rows])


func _toggles(state: Gen2WorldState) -> void:
	var bytes: Array = _expected["toggle_bytes"]
	for index: int in 256:
		var hidden: bool = (int(bytes[index >> 3]) >> (index & 7)) & 1 == 1
		_r.check(
			state.is_object_toggled(index) == (hidden == _r.data.gen1_toggle_on(index)),
			"toggleable object %d" % index
		)


func _bits(bytes: Array, test: Callable, label: String) -> void:
	for index: int in bytes.size() * 8:
		_r.check(
			test.call(index) == ((int(bytes[index >> 3]) >> (index & 7)) & 1 == 1),
			"%s %d" % [label, index]
		)


func _progress(state: Gen2WorldState) -> void:
	var scripts: Array = _expected["script_bytes"]
	for offset: int in scripts.size():
		_r.check(state.gen1_map_script(offset) == int(scripts[offset]), "map script byte %d" % offset)
	var starters: Array = _expected["starters"]
	_r.check(state.gen1_starter("player") == int(starters[0]), "player starter")
	_r.check(state.gen1_starter("rival") == int(starters[1]), "rival starter")
	var safari: Array = _expected["safari"]
	_r.check(
		[state.safari_balls(), state.safari_steps()] == [int(safari[0]), (int(safari[1][0]) << 8) | int(safari[1][1])],
		"Safari Zone"
	)
	var door: Array = _expected["card_key"]
	_r.check(state.card_key_door() == Vector2i(int(door[0]), int(door[1])), "card key door")
	var locks: Array = _expected["locks"]
	_r.check(state.gen1_byte("first_lock_trash_can") == int(locks[0]), "first lock")
	_r.check(state.gen1_byte("second_lock_trash_can") == int(locks[1]), "second lock")
	var fossil: Dictionary = {}
	for index: int in 2:
		if int(_expected["fossil"][index]) != 0:
			fossil[["item", "mon"][index]] = int(_expected["fossil"][index])
	_r.check(_snapshot.gen1_fossil == fossil, "fossil is %s" % _snapshot.gen1_fossil)
	if _r.game_id == RomRegistry.YELLOW:
		_yellow(state)


func _yellow(state: Gen2WorldState) -> void:
	var locks: Array = _expected["locks"]
	_r.check(state.gen1_byte("second_lock_trash_can_alt") == int(locks[2]), "alt lock")
	var score: Array = _expected["surf_score"]
	_r.check(
		[state.gen1_byte("surf_hi_score_low"), state.gen1_byte("surf_hi_score_high")] == [int(score[0]), int(score[1])],
		"Surfing minigame score"
	)
	var pikachu: Dictionary = _snapshot.gen1_pikachu
	var row: Array = _expected["pikachu"]
	_r.check(
		[int(pikachu["happiness"]), int(pikachu["mood"]), int(pikachu["emotion_modifier"]), int(pikachu["flags"]), int(pikachu["spawn_state"])]
		== [int(row[0]), int(row[1]), int(row[2]), int(row[3]) & 0x0A, int(row[4])],
		"Pikachu is %s, the game saved %s" % [pikachu, row]
	)


func _runs(state: Gen2WorldState) -> void:
	var runs: Dictionary = _expected["flag_runs"]
	for flag_run: String in FLAG_RUNS:
		if not runs.has(flag_run):
			continue
		var base: int = Gen1Layout.engine_flag_base(flag_run)
		_bits(runs[flag_run], func(index: int) -> bool: return state.is_engine_flag_active(base + index), flag_run)


func _hall(save: Gen2SaveData) -> void:
	var teams: Array = _expected["hall"]
	if not _r.check(save.hall_of_fame.size() == teams.size(), "%d Hall of Fame teams" % save.hall_of_fame.size()):
		return
	for index: int in teams.size():
		var record: Dictionary = save.hall_of_fame[index]
		_r.check(int(record["win_count"]) == teams.size() - index, "team %d count" % index)
		var mons: Array = []
		for mon: Dictionary in record["mons"]:
			mons.append({"species": mon["species"], "level": mon["level"], "nickname": mon["nickname"]})
		_r.check(_same(mons, teams[index]), "Hall of Fame team %d is %s" % [index, mons])


## On a copy: opening a world writes the map's music into the state it is handed.
func _opens(save: Gen2SaveData) -> void:
	var world: Gen2WorldAPI = Gen2WorldAPI.open_snapshot(
		_r.data, Gen2SaveData.from_dict(save.to_dict()).world, null
	)
	if not _r.check(world != null, "the imported position does not open"):
		return
	_r.check(world.map_id() == Vector2i(0, int(_expected["map"])), "opened on %s" % world.map_id())
	_r.check(world.player_cell == save.world.player_cell, "opened at %s" % world.player_cell)
	_r.check(world.rival_name == _expected["rival_name"], "the world's rival is %s" % world.rival_name)
	_r.check(Gen2SaveBattleAdapter.to_battle_party(_r.data, save) != null, "the party does not become a battle party")


## The real screen, a second of its frames spent.
func _screen(save: Gen2SaveData) -> void:
	var screen: Gen2WorldScreen = (load("res://game/world/world_screen.tscn") as PackedScene).instantiate()
	screen.set_data(_r.data)
	screen.set_save(Gen2SaveData.from_dict(save.to_dict()))
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.set_process(false)
	if _r.check(screen._world != null, "the world screen did not open the import"):
		screen.advance_frames(60)
		_r.check(screen._world.map_id() == Vector2i(0, int(_expected["map"])), "the screen stands on %s" % screen._world.map_id())
		_r.check(screen._world.player_cell == save.world.player_cell, "the screen stands at %s" % screen._world.player_cell)
		_r.check(screen._world.state.is_engine_flag_active(Gen2WorldState.gen1_badge_flag(0)), "the screen has lost the Boulder Badge")
	_r.close_screen(screen)


func _round_trip(save: Gen2SaveData, raw: PackedByteArray) -> void:
	var stored: Gen2SaveData = Gen2SaveData.from_dict(JSON.parse_string(JSON.stringify(save.to_dict())))
	_r.check(Gen2SaveValidator.validate(stored, _r.data)["ok"], "the slot file does not validate")
	var lost: String = _difference(save.to_dict(), stored.to_dict())
	_r.check(lost.is_empty(), "the slot file loses %s" % lost)
	var out: Dictionary = Gen2SramAdapter.export_bytes(save, raw, _r.data)
	if _r.check(out["ok"], "export refused: %s" % out["message"]):
		_r.check(out["raw"] == raw, "an untouched import exports different bytes")


## Edits the port's own state, exports it, and has the cartridge load the result.
func _edited(save: Gen2SaveData, raw: PackedByteArray, sav: String) -> void:
	var edited: Gen2SaveData = Gen2SaveData.from_dict(save.to_dict())
	var state: Dictionary = edited.world.world_state.to_dict()
	state["money"] = {0: MONEY_AFTER}
	state["coins"] = COINS_AFTER
	state["engine_flags"][Gen2WorldState.gen1_badge_flag(7)] = true
	state["items"][0x28] = 7
	state["event_flags"].erase(37)
	state["event_flags"][100] = true
	edited.world.world_state = Gen2WorldState.from_dict(state)
	edited.world.player_cell = EDITED_CELL
	edited.world.rival_name = "BLUE"
	edited.party.pop_back()
	var boxed: Gen2SaveMon = Gen2SaveMon.from_dict(edited.party[0].to_dict())
	boxed.nickname = "NEWBOX"
	boxed.stats = {}
	edited.current_box = EDITED_BOX
	edited.boxes[EDITED_BOX] = Gen2SaveBox.new()
	edited.boxes[EDITED_BOX].put(boxed)
	var out: Dictionary = Gen2SramAdapter.export_bytes(edited, raw, _r.data)
	if not _r.check(out["ok"], "edited export refused: %s" % out["message"]):
		return
	var back: Dictionary = Gen2SramAdapter.import_bytes(_r.game_id, _r.data.sha1, 0, out["raw"], _r.data)
	if _r.check(back["ok"], "edited export is not importable: %s" % back["message"]):
		var difference: String = _difference(edited.to_dict(), (back["save"] as Gen2SaveData).to_dict())
		_r.check(difference.is_empty(), "the edit did not survive an import: %s" % difference)
	var handle: FileAccess = FileAccess.open(sav, FileAccess.WRITE)
	handle.store_buffer(out["raw"])
	handle.close()
	var loaded: String = OS.get_temp_dir().path_join("gen1_sram_%s_loaded.json" % _r.game_id)
	if _oracle(["verify", String(_r.game_id), sav, loaded]):
		_cartridge_view(JSON.parse_string(FileAccess.get_file_as_string(loaded)), edited)
	DirAccess.remove_absolute(loaded)


func _cartridge_view(game: Dictionary, edited: Gen2SaveData) -> void:
	_r.check([int(game["map"]), int(game["x"]), int(game["y"])] == [int(_expected["map"]), EDITED_CELL.x, EDITED_CELL.y], "the game stands at %s" % game)
	var species: Array = []
	for mon: Gen2SaveMon in edited.party:
		species.append(_r.data.species(mon.species)["index"])
	_r.check(_same(game["party"], species), "the game's party is %s" % [game["party"]])
	_r.check(_same(game["money"], [0x65, 0x43, 0x21]), "the game's money is %s" % [game["money"]])
	_r.check(_same(game["coins"], [0x01, 0x11]), "the game's coins are %s" % [game["coins"]])
	_r.check(int(game["badges"]) == (int(_expected["badges"]) | 0x80), "the game's badges are %d" % int(game["badges"]))
	_r.check(int(game["box"]) == (EDITED_BOX | 0x80) and int(game["box_count"]) == 1, "the game's box is %s" % [game["box"]])
	_r.check(int(game["bag"][0]) == (_expected["bag"] as Array).size() + 1, "the game's bag count is %d" % int(game["bag"][0]))
	var events: Array = game["events"]
	_r.check((int(events[100 >> 3]) >> (100 & 7)) & 1 == 1 and (int(events[37 >> 3]) >> (37 & 7)) & 1 == 0, "the game's event flags")
