extends GutTest

## The byte boundary of Red, Blue and Yellow saves. Offsets here are spelled from
## `ram/sram.asm`, `ram/wram.asm` and `engine/menus/save.asm` rather than read out
## of the adapter, and `tools/checks/gen1_sram.gd` runs the same boundary against
## saves the real cartridges wrote.

const Fixture := preload("res://tests/unit/battle_fixture.gd")

const PARTY_AT: int = 0x2F2C
const MAIN_AT: int = 0x25A3
const SAVE_END: int = 0x3523
const BOX_BANK_2: int = 0x4000
const BOX_SIZE: int = 0x462
const HALL_AT: int = 0x0598

var _directory: String = ""


func before_each() -> void:
	_directory = RomCache.directory_for(&"gen1sramtest", "0123456789abcdef")


func after_each() -> void:
	RomCache.clear(_directory)


func _data() -> GameData:
	Fixture.build(_directory, "red", RomRegistry.GEN1)
	var rows: Array = RomCache.read_json(RomCache.species_path(_directory))
	for pair: Array in [
		[Fixture.PIKACHU, 0x54], [Fixture.CHARMANDER, 0xB0],
		[Fixture.BULBASAUR, 0x99], [Fixture.GEODUDE, 0xA9],
	]:
		rows[int(pair[0]) - 1]["index"] = pair[1]
	RomCache.write_json(RomCache.species_path(_directory), rows)
	var blocks: Array = []
	blocks.resize(16)
	blocks.fill(0)
	var cells: Array = []
	cells.resize(64)
	cells.fill(0)
	RomCache.write_json(RomCache.world_maps_path(_directory), [{
		"group": 0, "number": 38, "tileset": 0, "width_blocks": 4, "height_blocks": 4,
		"blocks": blocks, "collision": cells, "collision_width": 8, "collision_height": 8,
	}])
	var data: GameData = GameData.open_directory(_directory)
	data.sha1 = RomRegistry.sha1_for(&"red")
	return data


func _mon(data: GameData, species: int, level: int, nickname: String) -> Gen2SaveMon:
	var mon: Gen2SaveMon = Gen2SaveBattleAdapter.from_battle_mon(Gen2BattleMon.create(
		data, species, level, [Fixture.TACKLE, Fixture.THUNDERBOLT], 0xA5C3, {"hp": 300, "special": 4000}
	))
	mon.nickname = nickname
	mon.original_trainer = "RED"
	mon.ot_id = 0x1234
	mon.catch_rate = 190
	mon.happiness = 0
	mon.pokerus = 0
	mon.caught_time = 0
	mon.caught_gender = 0
	mon.caught_level = 0
	mon.caught_location = 0
	mon.item = 0
	mon.stats["sp_defense"] = mon.stats["sp_attack"]
	mon.pp_ups = [1, 0, 0, 0]
	mon.pp = [mon.max_pp(data, 0), 10, 0, 0]
	return mon


## A box row keeps no stats; `CalcMonStats` runs when it comes out.
func _boxed(data: GameData, species: int, level: int, nickname: String) -> Gen2SaveMon:
	var mon: Gen2SaveMon = _mon(data, species, level, nickname)
	mon.stats = {}
	return mon


func _save(data: GameData) -> Gen2SaveData:
	var save := Gen2SaveData.new()
	save.game_id = data.id
	save.rom_sha1 = data.sha1
	save.slot = 0
	save.player_name = "RED"
	save.player_id = 0xBEEF
	save.game_time = PokeGameTime.create(12, 34, 56, 7)
	save.party = [_mon(data, Fixture.PIKACHU, 25, "SPARKY"), _mon(data, Fixture.CHARMANDER, 18, "BLAZE")]
	save.current_box = 2
	(save.boxes[0] as Gen2SaveBox).put(_boxed(data, Fixture.GEODUDE, 12, "ROCKY"))
	(save.boxes[2] as Gen2SaveBox).put(_boxed(data, Fixture.BULBASAUR, 9, "BULBY"))
	(save.boxes[11] as Gen2SaveBox).put(_boxed(data, Fixture.PIKACHU, 30, "ZAP"))
	save.hall_of_fame = [
		{"win_count": 2, "mons": [{"species": Fixture.PIKACHU, "ot_id": 0, "dvs": 0, "level": 40, "nickname": "SPARKY"}]},
		{"win_count": 1, "mons": [
			{"species": Fixture.CHARMANDER, "ot_id": 0, "dvs": 0, "level": 36, "nickname": "BLAZE"},
			{"species": Fixture.PIKACHU, "ot_id": 0, "dvs": 0, "level": 35, "nickname": "ZAP"},
		]},
	]
	save.world = Gen2WorldSnapshot.new()
	save.world.map_id = Vector2i(0, 38)
	save.world.player_cell = Vector2i(3, 2)
	save.world.rival_name = "BLUE"
	save.world.gen1_last_blackout_map = 2
	save.world.world_state = Gen2WorldState.from_dict({
		"items": {20: 5, 4: 10}, "pc_items": {20: 1}, "money": {0: 4321}, "coins": 77,
		"event_flags": {37: true, 100: true, 2559: true},
		"engine_flags": {
			Gen2WorldState.gen1_badge_flag(0): true, Gen2WorldState.gen1_badge_flag(2): true,
			Gen1Layout.engine_flag_base("town_visited") + 3: true,
			Gen2WorldState.ENGINE_ALWAYS_ON_BIKE: true,
		},
		"seen_species": {Fixture.PIKACHU: true, Fixture.CHARMANDER: true},
		"caught_species": {Fixture.PIKACHU: true},
		"toggled_objects": {5: true, 17: true}, "gen1_map_scripts": {1: 3, 40: 2},
		"gen1_starters": {"player": 0xB0, "rival": 0xB1}, "starter_species": Fixture.CHARMANDER,
		"safari_balls": 20, "safari_steps": 400, "card_key_door": [12, 10],
		"gen1_bytes": {"first_lock_trash_can": 7, "lucky_slot_index": 3}, "npc_trades": {0: true, 9: true},
	})
	return save


## A cartridge with no save in it: zeroes, and the one byte the checksum makes of them.
func _blank() -> PackedByteArray:
	var raw := PackedByteArray()
	raw.resize(0x8000)
	raw[SAVE_END] = 0xFF
	return raw


func _exported(data: GameData, save: Gen2SaveData, base: PackedByteArray = PackedByteArray()) -> PackedByteArray:
	var out: Dictionary = Gen2SramAdapter.export_bytes(save, base if not base.is_empty() else _blank(), data)
	assert_true(out["ok"], out["message"])
	return out["raw"]


func _sum(raw: PackedByteArray, from: int, to: int) -> int:
	var total: int = 0
	for at: int in range(from, to):
		total = (total + raw[at]) & 0xFF
	return (~total) & 0xFF


func test_an_exported_save_is_laid_out_the_way_the_cartridge_reads_it() -> void:
	var data: GameData = _data()
	var raw: PackedByteArray = _exported(data, _save(data))
	assert_eq(raw.slice(0x2598, 0x259C), PackedByteArray([0x91, 0x84, 0x83, 0x50]), "sPlayerName: RED@")
	assert_eq(raw.slice(PARTY_AT, PARTY_AT + 4), PackedByteArray([2, 0x54, 0xB0, 0xFF]), "wPartyCount and wPartySpecies")
	assert_eq(raw.slice(MAIN_AT + 0x50, MAIN_AT + 0x53), PackedByteArray([0x00, 0x43, 0x21]), "wPlayerMoney is BCD")
	assert_eq(raw[MAIN_AT + 0x5F], 0b101, "wObtainedBadges")
	assert_eq(raw[MAIN_AT + 0x67], 38, "wCurMap")
	assert_eq(raw[MAIN_AT + 0x6A], 2, "wYCoord")
	assert_eq(raw[MAIN_AT + 0x6B], 3, "wXCoord")
	## `wOverworldMap` + (block row + 1) * (width + 6) + block column + 1, which is
	## what the bedroom measures on the cartridge: 0xC6E8 + 2 * 10 + 1 + 1.
	assert_eq(raw.slice(MAIN_AT + 0x68, MAIN_AT + 0x6A), PackedByteArray([0xFE, 0xC6]), "wCurrentTileBlockMapViewPointer")
	assert_eq(raw[MAIN_AT + 0x6C], 0, "wYBlockCoord is y & 1")
	assert_eq(raw[MAIN_AT + 0x6D], 1, "wXBlockCoord is x & 1")
	assert_eq(raw[MAIN_AT + 0x450 + (100 >> 3)] >> (100 & 7) & 1, 1, "event 100 is bit 4 of byte 12")
	assert_eq(raw[MAIN_AT + 0x2A9], 2 | 0x80, "wCurrentBoxNum has the changed-boxes bit once another box holds a Pokemon")
	assert_eq(raw[MAIN_AT + 0x2AB], 2, "wNumHoFTeams")
	assert_eq(raw[HALL_AT], 0xB0, "the oldest Hall of Fame team is stored first")
	assert_eq(raw[BOX_BANK_2 + 0], 1, "box 1 is in bank 2's first row")
	assert_eq(raw[0x6000 + 5 * BOX_SIZE], 1, "box 12 is in bank 3's last row")
	assert_eq(raw[SAVE_END], _sum(raw, 0x2598, SAVE_END), "the main checksum is the complemented byte sum")
	assert_eq(raw[BOX_BANK_2 + 6 * BOX_SIZE], _sum(raw, BOX_BANK_2, BOX_BANK_2 + 6 * BOX_SIZE), "the bank's box checksum")
	assert_eq(raw[BOX_BANK_2 + 6 * BOX_SIZE + 3], _sum(raw, BOX_BANK_2 + 2 * BOX_SIZE, BOX_BANK_2 + 3 * BOX_SIZE), "box 3's own checksum")


func test_an_exported_save_imports_to_what_was_exported() -> void:
	var data: GameData = _data()
	var save: Gen2SaveData = _save(data)
	var raw: PackedByteArray = _exported(data, save)
	var imported: Dictionary = Gen2SramAdapter.import_bytes(data.id, data.sha1, 0, raw, data)
	assert_true(imported["ok"], imported["message"])
	var back: Gen2SaveData = imported["save"]
	for slot: int in save.party.size():
		assert_eq(back.party[slot].to_dict(), save.party[slot].to_dict(), "party %d" % slot)
	for box: int in Gen2SaveData.BOX_COUNT:
		assert_eq(back.boxes[box].to_dict(), save.boxes[box].to_dict(), "box %d" % box)
	assert_eq(back.world.world_state.to_dict()["engine_flags"], save.world.world_state.to_dict()["engine_flags"].merged({Gen2WorldState.ENGINE_HALL_OF_FAME: true}))
	assert_eq(back.world.world_state.items(), save.world.world_state.items(), "the bag keeps its order")
	assert_eq(back.world.map_id, save.world.map_id)
	assert_eq(back.world.player_cell, save.world.player_cell)
	assert_eq(back.hall_of_fame, save.hall_of_fame)
	assert_eq(back.game_time.to_dict(), save.game_time.to_dict())
	assert_eq(back.current_box, 2)
	assert_eq(Gen2SramAdapter.export_bytes(back, raw, data)["raw"], raw, "an import exports back to the same bytes")


func test_a_cartridge_that_never_changed_boxes_holds_only_its_current_one() -> void:
	var data: GameData = _data()
	var save: Gen2SaveData = _save(data)
	save.boxes[0] = Gen2SaveBox.new()
	save.boxes[11] = Gen2SaveBox.new()
	var raw: PackedByteArray = _exported(data, save)
	assert_eq(raw[MAIN_AT + 0x2A9], 2, "nothing is in another box, so the flag stays clear")
	raw[BOX_BANK_2] = 7
	raw[BOX_BANK_2 + 1] = 0x01
	var imported: Dictionary = Gen2SramAdapter.import_bytes(data.id, data.sha1, 0, raw, data)
	assert_true(imported["ok"], "uninitialised box rows are never read: %s" % imported["message"])
	assert_eq((imported["save"] as Gen2SaveData).boxes[0].occupied_count(), 0)


func _corrupt(image: PackedByteArray, reason: String) -> void:
	match reason:
		"failed its checksum":
			image[MAIN_AT + 1] ^= 1
		"no Pokedex entry":
			image[PARTY_AT + 1] = 0x01
			image[PARTY_AT + 8] = 0x01
		"two stacks":
			image[MAIN_AT + 0x29] = image[MAIN_AT + 0x27]
		"not packed decimal":
			image[MAIN_AT + 0x51] = 0xA0
		"no end marker":
			image[PARTY_AT + 3] = 0x54
		"wWalkBikeSurfState":
			image[MAIN_AT + 0x409] = 9


func test_a_cartridge_save_the_port_cannot_carry_is_refused_with_its_reason() -> void:
	var data: GameData = _data()
	var raw: PackedByteArray = _exported(data, _save(data))
	for reason: String in [
		"failed its checksum", "no Pokedex entry", "two stacks", "not packed decimal",
		"no end marker", "wWalkBikeSurfState",
	]:
		var image: PackedByteArray = raw.duplicate()
		_corrupt(image, reason)
		if reason != "failed its checksum":
			image[SAVE_END] = _sum(image, 0x2598, SAVE_END)
		var result: Dictionary = Gen2SramAdapter.import_bytes(data.id, data.sha1, 0, image, data)
		assert_false(result["ok"], reason)
		assert_string_contains(String(result["message"]), reason)
	assert_false(Gen2SramAdapter.import_bytes(data.id, "0123456789abcdef", 0, raw, data)["ok"], "another revision")
	assert_false(Gen2SramAdapter.import_bytes(data.id, data.sha1, 0, raw.slice(0, 0x7000), data)["ok"], "a short file")


func test_a_port_save_the_cartridge_has_no_byte_for_is_not_exported() -> void:
	var data: GameData = _data()
	var save: Gen2SaveData = _save(data)
	var base: PackedByteArray = _exported(data, save)
	for edit: String in ["engine flag", "event flag", "script byte", "Pokedex entry", "species"]:
		var broken: Gen2SaveData = Gen2SaveData.from_dict(save.to_dict())
		var state: Dictionary = broken.world.world_state.to_dict()
		match edit:
			"engine flag":
				state["engine_flags"][99] = true
			"event flag":
				state["event_flags"][2560] = true
			"script byte":
				state["gen1_bytes"]["something_else"] = 1
			"Pokedex entry":
				state["caught_species"][152] = true
		broken.world.world_state = Gen2WorldState.from_dict(state)
		if edit == "species":
			broken.party[0].species = Fixture.MAGCARGO
		var result: Dictionary = Gen2SramAdapter.export_bytes(broken, base, data)
		assert_false(result["ok"], "%s has no place in the file" % edit)
		assert_string_contains(String(result["message"]), "cartridge index" if edit == "species" else edit)
	var home: Gen2SaveData = Gen2SaveData.from_dict(save.to_dict())
	home.boxes[12] = Gen2SaveBox.new()
	(home.boxes[12] as Gen2SaveBox).put(_boxed(data, Fixture.PIKACHU, 5, "TWELVE"))
	assert_false(Gen2SramAdapter.export_bytes(home, base, data)["ok"], "the cartridge has twelve boxes")
	assert_false(Gen2SramAdapter.export_bytes(save, PackedByteArray(), data)["ok"], "there is no image to patch")


## `wCompletedInGameTradeFlags`, `wGameProgressFlags` and the rest sit at the same
## offsets in all three games, which is what lets one table serve them, and every
## address `Gen1Layout` reads out of a ROM names the same byte as the adapter's.
func test_the_adapter_offsets_are_the_addresses_the_importer_read() -> void:
	var main_start: Dictionary = {RomRegistry.RED: 0xD2F7, RomRegistry.BLUE: 0xD2F7, RomRegistry.YELLOW: 0xD2F6}
	var offsets: Dictionary = {
		"event_flags": Gen1SramWorld.EVENT_FLAGS_AT, "map_scripts": Gen1SramWorld.MAP_SCRIPTS_AT,
		"obtained_badges": Gen1SramWorld.BADGES_AT, "first_lock_trash_can": Gen1SramWorld.LOCKS_AT,
		"fossil_item": Gen1SramWorld.FOSSIL_AT, "player_starter": Gen1SramWorld.PLAYER_STARTER_AT,
		"safari_steps": Gen1SramWorld.SAFARI_STEPS_AT, "status_flags_6": Gen1SramWorld.STATUS_FLAGS_6_AT,
		"toggleable_list": Gen1SramWorld.TOGGLES_AT + 0x28,
	}
	for run: String in Gen1SramWorld.FLAG_RUNS:
		offsets[run] = Gen1SramWorld.FLAG_RUNS[run]
	for id: StringName in RomRegistry.ids_of_generation(RomRegistry.GEN1):
		var layout: Dictionary = Gen1Layout.for_id(id)
		for key: String in offsets:
			if layout.has(key):
				assert_eq(
					int(layout[key]) - int(main_start[id]) + Gen1SramWorld.MAIN_AT, int(offsets[key]),
					"%s %s" % [id, key]
				)
