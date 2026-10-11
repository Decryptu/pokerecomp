extends GutTest

## Protect GBA bounds, header/event formats, script dispatch and encounter variants.
## GB world tests miss packed unions, padding, rod slices and Hoenn species IDs.
const LAYOUT: Dictionary = {"map_groups": 0, "map_group_sizes": [2], "item_count": 10,
	"wild_headers": 0x400, "wild_header_count": 2, "species_to_national": 0x800,
	"standard_scripts": 0xC00, "standard_script_count": 1,
	"movement_types": 0xF80, "movement_type_count": 2,
	"trainer_battle_scripts": [0xD01, 0xD01, 0xD01, 0xD01, 0xD01]}


func _dump(id: StringName = RomRegistry.EMERALD) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(4096)
	bytes.encode_u32(0xC00, 0x08000D01)
	bytes[0xD01] = 2
	bytes.encode_u32(0, 0x08000020)
	for number: int in 2:
		bytes.encode_u32(0x20 + number * 4, 0x08000040 + number * 28)
		var at: int = 0x40 + number * 28
		for field: int in 3:
			bytes.encode_u32(at + field * 4, 0x08000100 + field * 0x40)
		bytes.encode_u32(at + 12, 0x08000200)
		bytes.encode_u16(at + 16, 123)
		bytes.encode_u16(at + 18, 7)
		bytes[at + 20] = 9
		bytes[at + 23] = 4
		bytes[at + 24] = 1
		bytes[at + 25] = 5
		bytes[at + 26] = 0xFE
	bytes.encode_u32(0x100, 3)
	bytes.encode_u32(0x104, 2)
	for field: int in 4:
		bytes.encode_u32(0x108 + field * 4, 0x08000300 + field * 32)
	bytes[0x118] = 3
	bytes[0x119] = 2
	bytes.encode_u32(0x200, 1)
	bytes.encode_u32(0x204, 0x08000220)
	bytes[0x220] = 3
	bytes.encode_u32(0x224, 0xFFFFFFCE)
	bytes[0x229] = 1
	for variant: int in 2:
		var at: int = 0x400 + variant * 20
		bytes.encode_u32(at + 4, 0x08000500 + variant * 16)
		bytes.encode_u32(at + 16, 0x08000540)
		bytes[0x500 + variant * 16] = 20 + variant
		bytes.encode_u32(0x504 + variant * 16, 0x08000600 + variant * 64)
		for slot: int in 12:
			var mon: int = 0x600 + variant * 64 + slot * 4
			bytes[mon] = 2
			bytes[mon + 1] = 5
			bytes.encode_u16(mon + 2, 277 + variant)
	bytes[0x428] = 0xFF
	bytes[0x429] = 0xFF
	bytes[0x540] = 30
	bytes.encode_u32(0x544, 0x08000700)
	for slot: int in 10:
		bytes[0x700 + slot * 4] = 5 + slot
		bytes[0x701 + slot * 4] = 10 + slot
		bytes.encode_u16(0x702 + slot * 4, 277)
	bytes.encode_u16(0x800 + 276 * 2, 252)
	bytes.encode_u16(0x800 + 277 * 2, 253)
	var frlg: bool = id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN]
	for secondary: int in 2:
		var at: int = 0x340 + secondary * 32
		bytes[at] = 1
		bytes[at + 1] = secondary
		bytes.encode_u32(at + 4, 0x08000E00)
		bytes.encode_u32(at + 8, 0x08000B00)
		bytes.encode_u32(at + 12, 0x08000E80 + secondary * 32)
		bytes.encode_u32(at + (20 if frlg else 16), 0x08000E90 + secondary * 32)
		bytes.encode_u16(0xE80 + secondary * 32, 0xFC00)
		if frlg:
			bytes.encode_u32(0xE90 + secondary * 32, 0xC7000123)
		else:
			bytes.encode_u16(0xE90 + secondary * 32, 0x2123)
	bytes.encode_u32(0xE00, 0x00002010)
	for tile_byte: int in 32:
		bytes[0xE05 + tile_byte + tile_byte / 8] = tile_byte
	return bytes


func test_headers_decode_their_own_flags_and_signed_connections() -> void:
	for id: StringName in [RomRegistry.RUBY, RomRegistry.FIRERED, RomRegistry.EMERALD]:
		var world: Dictionary = Gen3World.read(RomFile.from_bytes(_dump(id), id), LAYOUT)
		assert_false(world.is_empty(), str(id))
		var row: Dictionary = world["headers"]["0:0"]
		assert_eq(row["connections"], [{"direction": 3, "offset": -50, "group": 0, "number": 1}])
		assert_eq([row["width"], row["height"], row["music"], row["layout_id"]], [3, 2, 123, 7])
		if id == RomRegistry.RUBY:
			assert_eq(row["escape_rope"], 5)
			assert_eq(row["flags"], 254)
			assert_false(row.has("allow_running"))
		else:
			assert_true(row["allow_cycling"] if id == RomRegistry.FIRERED else row["allow_running"])
			assert_true(row["allow_escaping"])
			assert_false(row["allow_running"] if id == RomRegistry.FIRERED else row["allow_cycling"])
		if id == RomRegistry.FIRERED:
			assert_eq(row["floor_number"], -2)
			assert_eq(row["border_width"], 3)
		else:
			assert_eq(row["border_width"], 2)


func test_cache_api_keeps_variants_rod_slots_and_integer_fields() -> void:
	var bytes: PackedByteArray = _dump()
	bytes[0x600] = 5
	bytes[0x601] = 2
	var world: Dictionary = Gen3World.read(RomFile.from_bytes(bytes, RomRegistry.EMERALD), LAYOUT)
	var data := GameData.new()
	data.generation = RomRegistry.GEN3
	data._sections = {"headers": true, "encounters": true}
	data._world_headers = JSON.parse_string(JSON.stringify(world["headers"]))
	data._world_encounters = JSON.parse_string(JSON.stringify(world["encounters"]))
	assert_eq(data.map_count(), 2)
	assert_eq(data.world_map_headers().size(), 2)
	assert_typeof(data.world_map_header(0, 0)["width"], TYPE_INT)
	assert_null(data.world_map(0, 0))
	assert_true(data.world_map_header(0, 2).is_empty())
	assert_eq(data.world_encounter_variant_count(&"land", 0, 0), 2)
	assert_eq(data.world_encounter(&"land", 0, 0)["slots"][0]["species"], 252)
	assert_eq(data.world_encounter(&"land", 0, 0)["slots"][0]["min_level"], 5)
	assert_eq(data.world_encounter(&"land", 0, 0)["slots"][0]["max_level"], 2)
	assert_eq(data.world_encounter(&"land", 0, 0, 1)["slots"][0]["species"], 253)
	assert_true(data.world_encounter(&"land", 0, 0, -1).is_empty())
	assert_true(data.world_encounter(&"land", 0, 0, 2).is_empty())
	var rod: Dictionary = data.world_encounter(&"good_rod", 0, 0)
	assert_eq(rod["slots"].map(func(slot: Dictionary) -> int: return slot["slot"]), [2, 3, 4])
	assert_eq(rod["slots"].map(func(slot: Dictionary) -> int: return slot["chance"]), [60, 20, 20])
	assert_typeof(rod["slots"][0]["min_level"], TYPE_INT)
	rod["slots"][0]["species"] = 99
	assert_eq(data.world_encounter(&"good_rod", 0, 0)["slots"][0]["species"], 252)


func test_bad_pointers_records_and_terminator_refuse_the_entire_world() -> void:
	var changes: Array = [
		[0, 0, 4], [0, 0x08000FFC, 4], [0x20, 0x08000041, 4],
		[0x44, 0x07000140, 4], [0x100, 0xFFFFFFFF, 4], [0x10C, 0x08000FFC, 4],
		[0x229, 2, 1], [0x200, 0xFFFFFFFF, 4], [0x204, 0x08000FFC, 4],
		[0x428, 0, 1], [0x404, 0x08000501, 4], [0x504, 0x08000FFC, 4],
		[0x600, 0, 1], [0x600, 101, 1], [0x601, 0, 1], [0x601, 101, 1], [0x602, 252, 2],
	]
	for change: Array in changes:
		var bytes: PackedByteArray = _dump()
		match int(change[2]):
			1: bytes[int(change[0])] = int(change[1])
			2: bytes.encode_u16(int(change[0]), int(change[1]))
			4: bytes.encode_u32(int(change[0]), int(change[1]))
		assert_true(Gen3World.read(RomFile.from_bytes(bytes, RomRegistry.EMERALD), LAYOUT).is_empty(), str(change))


func test_missing_method_does_not_shift_a_later_set_into_the_default() -> void:
	var bytes: PackedByteArray = _dump()
	bytes.encode_u32(0x404, 0)
	var world: Dictionary = Gen3World.read(RomFile.from_bytes(bytes, RomRegistry.EMERALD), LAYOUT)
	assert_true(world["encounters"]["land"]["0:0"][0].is_empty())
	assert_eq(world["encounters"]["land"]["0:0"][1]["rate"], 21)


func _event_dump(id: StringName = RomRegistry.EMERALD) -> PackedByteArray:
	var bytes: PackedByteArray = _dump(id)
	for kind: int in 4:
		bytes[0x140 + kind] = 1
		bytes.encode_u32(0x144 + kind * 4, 0x08000900 + kind * 0x40)
	bytes[0x900] = 17
	bytes[0x901] = 200
	bytes.encode_u16(0x904, 0xFFFF)
	bytes.encode_u16(0x906, 10)
	bytes[0x908] = 3
	bytes[0x909] = 7
	bytes[0x90A] = 0xA2
	bytes.encode_u16(0x90C, 2)
	bytes.encode_u16(0x90E, 300)
	bytes.encode_u32(0x910, 0x08000D01)
	bytes.encode_u16(0x914, 1000)
	bytes.encode_u16(0x940, 5)
	bytes.encode_u16(0x942, 6)
	bytes[0x944] = 4
	bytes[0x945] = 0xFF
	bytes[0x946] = 0x7F
	bytes[0x947] = 0x7F
	bytes.encode_u16(0x980, 0xFFFF)
	bytes.encode_u16(0x986, 0x4001)
	bytes.encode_u16(0x988, 2)
	bytes[0x9C5] = 7
	bytes.encode_u16(0x9C8, 200)
	bytes.encode_u16(0x9CA, 0x8305)
	bytes[0x180] = 2
	bytes.encode_u32(0x181, 0x08000A01)
	bytes[0x185] = 3
	bytes.encode_u32(0x186, 0x08000D01)
	bytes.encode_u16(0xA01, 0x4001)
	bytes.encode_u16(0xA03, 0x4002)
	bytes.encode_u32(0xA05, 0x08000D01)
	return bytes


func _event_data(bytes: PackedByteArray, id: StringName) -> GameData:
	var world: Dictionary = Gen3World.read(RomFile.from_bytes(bytes, id), LAYOUT)
	var data := GameData.new()
	data.generation = RomRegistry.GEN3
	data._sections = {"headers": true}
	data._world_headers = JSON.parse_string(JSON.stringify(world.get("headers", {})))
	return data


func test_event_unions_and_script_entries_survive_the_cache_api() -> void:
	for id: StringName in [RomRegistry.RUBY, RomRegistry.EMERALD, RomRegistry.FIRERED]:
		var data: GameData = _event_data(_event_dump(id), id)
		var events: Dictionary = data.world_map_events(0, 0)
		assert_false(events.is_empty(), str(id))
		var object: Dictionary = events["objects"][0]
		assert_eq([object["local_id"], object["x"], object["movement_range_x"],
			object["movement_range_y"], object["trainer_sight_or_berry_tree_id"],
			object["script_offset"], object["flag"]], [17, -1, 2, 10, 300, 0xD01, 1000])
		assert_typeof(object["script_offset"], TYPE_INT)
		assert_eq(events["warps"][0]["group"], 0x7F)
		assert_eq(events["warps"][0]["warp_id"], 255)
		assert_eq(events["coords"][0]["script_offset"], 0)
		assert_eq(events["coords"][0]["x"], 65535 if id == RomRegistry.FIRERED else -1)
		var item: Dictionary = events["backgrounds"][0]
		assert_eq(item["hidden_item_id"], 5 if id == RomRegistry.FIRERED else 0x8305)
		if id == RomRegistry.FIRERED:
			assert_eq(item["quantity"], 3)
			assert_true(item["underfoot"])
		else:
			assert_false(item.has("quantity"))
		var scripts: Array = data.world_map_script_entries(0, 0)
		assert_eq(scripts, [{"type": 2, "table_offset": 0xA01,
			"conditions": [{"variable": 0x4001, "value": 0x4002, "script_offset": 0xD01}]},
			{"type": 3, "script_offset": 0xD01}])
		object["flag"] = 0
		scripts[0]["conditions"][0]["value"] = 0
		assert_eq(data.world_map_events(0, 0)["objects"][0]["flag"], 1000)
		assert_eq(data.world_map_script_entries(0, 0)[0]["conditions"][0]["value"], 0x4002)
		assert_true(data.world_map_events(0, 2).is_empty())
		assert_true(data.world_map_script_entries(0, 2).is_empty())


func test_clone_objects_secret_bases_and_null_map_scripts_keep_their_union() -> void:
	var bytes: PackedByteArray = _event_dump(RomRegistry.FIRERED)
	bytes[0x902] = 255
	bytes[0x908] = 42
	bytes.encode_u16(0x90C, 1)
	bytes.encode_u16(0x90E, 0)
	bytes.encode_u32(0x48, 0)
	var data: GameData = _event_data(bytes, RomRegistry.FIRERED)
	assert_eq(data.world_map_events(0, 0)["objects"][0], {"local_id": 17,
		"graphics_id": 200, "kind": 255, "x": -1, "y": 10,
		"target_local_id": 42, "target_group": 0, "target_number": 1})
	assert_true(data.world_map_script_entries(0, 0).is_empty())
	bytes = _event_dump()
	bytes[0x9C5] = 8
	bytes.encode_u32(0x9C8, 123)
	data = _event_data(bytes, RomRegistry.EMERALD)
	assert_eq(data.world_map_events(0, 0)["backgrounds"][0]["secret_base_id"], 123)


func test_event_and_dispatch_bounds_refuse_the_whole_world() -> void:
	var changes: Array = [[0x144, 0, 4], [0x148, 0x08000FFC, 4],
		[0x14C, 0x08000981, 4], [0x150, 0x08000FFC, 4], [0x902, 1, 1],
		[0x910, 0x09000000, 4], [0x947, 42, 1], [0x98C, 0x08001000, 4],
		[0x9C5, 0, 1], [0x180, 8, 1], [0x181, 0, 4],
		[0x181, 0x08000FFF, 4], [0xA05, 0, 4], [0x186, 0x08001000, 4]]
	for change: Array in changes:
		var bytes: PackedByteArray = _event_dump()
		if int(change[2]) == 1:
			bytes[int(change[0])] = int(change[1])
		else:
			bytes.encode_u32(int(change[0]), int(change[1]))
		assert_true(Gen3World.read(RomFile.from_bytes(bytes, RomRegistry.EMERALD), LAYOUT).is_empty(), str(change))


func test_dispatch_and_condition_terminators_fit_at_the_end_of_the_dump() -> void:
	var bytes: PackedByteArray = _event_dump()
	bytes.encode_u32(0x48, 0x08000FFF)
	assert_true(_event_data(bytes, RomRegistry.EMERALD).world_map_script_entries(0, 0).is_empty())
	bytes[0xFFF] = 3
	assert_true(Gen3World.read(RomFile.from_bytes(bytes, RomRegistry.EMERALD), LAYOUT).is_empty())
	bytes = _event_dump()
	bytes.encode_u32(0x181, 0x08000FFE)
	assert_eq(_event_data(bytes, RomRegistry.EMERALD).world_map_script_entries(0, 0)[0]["conditions"], [])
	bytes[0xFFE] = 1
	assert_true(Gen3World.read(RomFile.from_bytes(bytes, RomRegistry.EMERALD), LAYOUT).is_empty())


## Protect the independent Tileset formats and binary cache boundary. A shared
## GB decoder or a swapped FRLG pointer passes header/event-only checks.
func test_graphics_payloads_keep_bank_splits_attributes_and_detached_bytes() -> void:
	for id: StringName in [RomRegistry.RUBY, RomRegistry.FIRERED, RomRegistry.EMERALD]:
		var world: Dictionary = Gen3World.read(RomFile.from_bytes(_dump(id), id), LAYOUT)
		assert_false(world.is_empty(), str(id))
		var path: String = "user://test_gen3_graphics.json"
		assert_true(RomCache.write_section(path, RomCache.blob_path(path), world["graphics"]))
		var data := GameData.new()
		data.id = id
		data.generation = RomRegistry.GEN3
		data._sections = {"headers": true, "gba_graphics": true}
		data._world_headers = JSON.parse_string(JSON.stringify(world["headers"]))
		data._world_tilesets = RomCache.read_json(path)
		data._indices["blob/tilesets"] = RomCache.read_blob(RomCache.blob_path(path))
		var primary: Dictionary = data.world_map_tileset(0, 0)
		var secondary: Dictionary = data.world_map_tileset(0, 0, true)
		assert_typeof(primary["tiles"]["bytes"], TYPE_PACKED_BYTE_ARRAY)
		assert_eq(primary["tiles"]["bytes"].size(), 32)
		assert_eq(primary["tiles"]["bytes"][31], 31)
		assert_eq(secondary["tile_offset"], 640 if id == RomRegistry.FIRERED else 512)
		assert_eq(secondary["palette_offset"], 7 if id == RomRegistry.FIRERED else 6)
		assert_eq(secondary["palette_count"], 7 if id == RomRegistry.EMERALD else 6)
		var metatile: Dictionary = data.world_metatile(0, 0, int(secondary["metatile_offset"]))
		assert_eq(metatile["tiles"][0], {"tile": 0, "flip_x": true, "flip_y": true, "palette": 15})
		assert_eq(metatile["behavior"], 0x123 if id == RomRegistry.FIRERED else 0x23)
		assert_eq(metatile["layer_type"], 2)
		# One row past the array, DrawMetatileAt reads the attribute array as tiles.
		var past: Dictionary = data.world_metatile(0, 0, int(secondary["metatile_offset"]) + 1)
		assert_eq(past["tiles"][0]["tile"], 0x123)
		assert_eq(data.world_map_layout(0, 0)["blocks"]["bytes"].size(), 12)
		primary["tiles"]["bytes"][31] = 0
		assert_eq(data.world_map_tileset(0, 0)["tiles"]["bytes"][31], 31)
		assert_true(data.world_metatile(0, 0, 1024).is_empty())
		assert_true(data.world_map_layout(0, 9).is_empty())
		assert_true(data.world_map_tileset(0, 9).is_empty())
		assert_null(data.world_tileset(0))
		DirAccess.remove_absolute(path)
		DirAccess.remove_absolute(RomCache.blob_path(path))


func test_graphics_bounds_flags_and_lz_refuse_the_entire_world() -> void:
	var changes: Array = [[0x114, 0x08000340, 4], [0x340, 2, 1], [0x341, 2, 1], [0x344, 0, 4],
		[0x348, 0x08000FFC, 4], [0x34C, 0x08000E81, 4], [0x350, 0x08000E91, 4],
		[0x354, 0x08001001, 4], [0x354, 0x08000F01, 4], [0x350, 0x08000E80, 4], [0xE00, 0, 1]]
	for change: Array in changes:
		var bytes: PackedByteArray = _dump()
		if int(change[2]) == 1:
			bytes[int(change[0])] = int(change[1])
		else:
			bytes.encode_u32(int(change[0]), int(change[1]))
		assert_true(Gen3World.read(RomFile.from_bytes(bytes, RomRegistry.EMERALD), LAYOUT).is_empty(), str(change))


## Late opcodes and disabled handlers consume different bytes on each engine.
## The header checks cannot catch a command silently eating its successor.
func test_script_operand_widths_follow_handlers_instead_of_assembler_macros() -> void:
	var bytes := PackedByteArray([0xC7, 9, 2, 0x72, 2, 0x74, 1, 2, 3, 4, 2])
	var frlg: RomFile = RomFile.from_bytes(bytes, RomRegistry.FIRERED)
	var emerald: RomFile = RomFile.from_bytes(bytes, RomRegistry.EMERALD)
	assert_eq(Gen3Script.instruction(frlg, 0)["operands"], [9])
	assert_eq(Gen3Script.instruction(emerald, 0)["next_offset"], 1)
	assert_eq(Gen3Script.instruction(frlg, 3)["next_offset"], 4)
	assert_eq(Gen3Script.instruction(emerald, 3)["next_offset"], 4)
	assert_eq(Gen3Script.instruction(frlg, 5)["next_offset"], 6)
	assert_eq(Gen3Script.instruction(emerald, 5)["operands"], [1, 2, 3, 4])
	assert_true(Gen3Script.instruction(RomFile.from_bytes(bytes, RomRegistry.RUBY), 0).is_empty())
	bytes = PackedByteArray([0x79, 0x15, 1, 50, 200, 0, 0, 0, 0, 2, 0, 0, 0, 3, 1])
	var row: Dictionary = Gen3Script.instruction(RomFile.from_bytes(bytes, RomRegistry.EMERALD), 0)
	assert_eq(row["operands"], [277, 50, 200, 0x02000000, 0x03000000, 1])
	assert_eq(row["next_offset"], 15)


func test_script_graph_keeps_calls_cycles_dispatch_and_warp_boundaries_in_cache() -> void:
	var bytes: PackedByteArray = _event_dump()
	bytes[0xD01] = 4
	bytes.encode_u32(0xD02, 0x08000D31)
	bytes[0xD06] = 6
	bytes[0xD07] = 1
	bytes.encode_u32(0xD08, 0x08000D01)
	bytes[0xD0C] = 9
	bytes[0xD0D] = 0
	bytes[0xD0E] = 0x39
	bytes[0xD16] = 0xFF
	bytes[0xD31] = 3
	var world: Dictionary = Gen3World.read(RomFile.from_bytes(bytes, RomRegistry.EMERALD), LAYOUT)
	assert_false(world.is_empty())
	var path: String = "user://test_gen3_scripts.json"
	assert_true(RomCache.write_section(path, RomCache.blob_path(path), world["scripts"]))
	var data := GameData.new()
	data.generation = RomRegistry.GEN3
	data._sections = {"scripts": true}
	data._world_scripts = RomCache.read_json(path)
	data._indices["blob/scripts"] = RomCache.read_blob(RomCache.blob_path(path))
	assert_eq(data.world_script_offsets(), [0xD01, 0xD06, 0xD0C, 0xD0E, 0xD31])
	var call_row: Dictionary = data.world_script_instruction(0xD01)
	assert_eq(call_row["operands"], [0x08000D31])
	assert_typeof(call_row["operands"][0], TYPE_INT)
	assert_eq(call_row["script_offsets"], [0xD31])
	assert_eq(call_row["bytes"], PackedByteArray([4, 0x31, 0x0D, 0, 8]))
	assert_eq(data.world_script_instruction(0xD06)["script_offsets"], [0xD01])
	assert_eq(data.world_script_instruction(0xD0C)["script_offsets"], [0xD01])
	assert_false(data.world_script_instruction(0xD0E)["fallthrough"])
	assert_true(data.world_script_instruction(0xD16).is_empty())
	assert_true(data.world_script_instruction(-1).is_empty())
	assert_eq(data.world_standard_script_offset(0), 0xD01)
	assert_eq(data.world_standard_script_offset(1), -1)
	assert_eq(data.world_standard_script_offset(-1), -1)
	call_row["bytes"][0] = 0
	call_row["operands"][0] = 0
	assert_eq(data.world_script_instruction(0xD01)["bytes"][0], 4)
	assert_eq(data.world_script_instruction(0xD01)["operands"][0], 0x08000D31)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(RomCache.blob_path(path))


func test_trainer_script_formats_keep_continuations_and_frlg_rival_texts() -> void:
	for id: StringName in [RomRegistry.RUBY, RomRegistry.FIRERED, RomRegistry.EMERALD]:
		var modes: int = int({RomRegistry.EMERALD: 13, RomRegistry.FIRERED: 10, RomRegistry.RUBY: 9}[id])
		for mode: int in modes:
			var bytes: PackedByteArray = _dump(id)
			bytes[0xD01] = 0x5C
			bytes[0xD02] = mode
			bytes.encode_u16(0xD03, 42)
			bytes.encode_u16(0xD05, 5)
			bytes[0xD41] = 2
			bytes[0xD51] = 0xFF
			var size: int = 14
			if mode == 3:
				size = 10
			elif mode in [6, 8]:
				size = 22
			elif mode in [1, 2, 4, 7]:
				size = 18
			for pointer: int in range(0xD07, 0xD01 + size, 4):
				var continuation: bool = mode in [1, 2, 6, 8] and pointer + 4 == 0xD01 + size
				bytes.encode_u32(pointer, 0x08000D41 if continuation else 0x08000D51)
			bytes[0xD01 + size] = 2
			var scripts: Dictionary = Gen3Script.read(RomFile.from_bytes(bytes, id), LAYOUT, {})
			assert_false(scripts.is_empty(), "%s mode %d" % [id, mode])
			var row: Dictionary = scripts["instructions"][str(0xD01)]
			assert_eq(row["next_offset"], 0xD01 + size)
			assert_eq(scripts["texts"].keys(), [str(0xD51)])
			var targets: Array = row["script_offsets"]
			if id == RomRegistry.EMERALD and mode in [10, 11]:
				assert_true(targets.is_empty())
			else:
				assert_true(targets.has(0xD01 + size))
				assert_eq(targets.has(0xD41), mode in [1, 2, 6, 8])


func test_script_bounds_unknown_opcodes_and_targets_refuse_the_whole_world() -> void:
	var changes: Array = [[0xC00, 0, 4], [0xD01, 0xFF, 1],
		[0xD01, 5, 1], [0xD01, 0x5C, 1]]
	for change: Array in changes:
		var bytes: PackedByteArray = _dump()
		if int(change[2]) == 4:
			bytes.encode_u32(int(change[0]), int(change[1]))
		else:
			bytes[int(change[0])] = int(change[1])
		bytes[0xD02] = 255
		assert_true(Gen3World.read(RomFile.from_bytes(bytes, RomRegistry.EMERALD), LAYOUT).is_empty(), str(change))
	var overlapping: PackedByteArray = _dump()
	overlapping[0xD01] = 4
	overlapping.encode_u32(0xD02, 0x08000D03)
	overlapping[0xD06] = 2
	assert_true(Gen3World.read(RomFile.from_bytes(overlapping, RomRegistry.EMERALD), LAYOUT).is_empty())
	for bytes: PackedByteArray in [PackedByteArray([4, 0, 0, 8]), PackedByteArray([0x5C]),
		PackedByteArray([0x5C, 6, 1, 0, 0, 0]), PackedByteArray([0x79, 1, 0, 5])]:
		assert_true(Gen3Script.instruction(RomFile.from_bytes(bytes, RomRegistry.EMERALD), 0).is_empty())


## No cartridge text carries $FF inside a control code's arguments, and none of
## the refusals below occurs in a dump, so the real-cache sweeps cannot see them.
func test_text_span_reads_control_code_arguments_per_engine() -> void:
	var bgm := PackedByteArray([0xFC, 0x0B, 0xFF, 0x01, 0xBB, 0xFF])
	assert_eq(Gen3Text.span(RomRegistry.RUBY, bgm, 0, 16), 6)
	assert_eq(Gen3Text.decode_fixed(RomRegistry.RUBY, bgm, 0, 6), "<PLAY_BGM 511>A")
	var resume := PackedByteArray([0xFC, 0x18, 0xFF])
	assert_eq(Gen3Text.span(RomRegistry.EMERALD, resume, 0, 16), 3)
	assert_eq(Gen3Text.span(RomRegistry.RUBY, resume, 0, 16), -1)
	assert_eq(Gen3Text.span(RomRegistry.EMERALD, PackedByteArray([0xFC, 0x19, 0xFF]), 0, 16), -1)
	var symbol := PackedByteArray([0xF9, 0xFF, 0xFF])
	assert_eq(Gen3Text.span(RomRegistry.FIRERED, symbol, 0, 16), 3)
	assert_eq(Gen3Text.span(RomRegistry.SAPPHIRE, symbol, 0, 16), 2)
	assert_eq(Gen3Text.span(RomRegistry.EMERALD, bgm, 0, 3), -1)
	assert_eq(Gen3Text.decode_fixed(RomRegistry.SAPPHIRE, PackedByteArray([0xFD, 0x08]), 0, 2), "<AQUA>")
	assert_eq(Gen3Text.decode_fixed(RomRegistry.RUBY, PackedByteArray([0xFD, 0x08]), 0, 2), "<MAGMA>")


func _data_dump(script: PackedByteArray) -> PackedByteArray:
	var bytes: PackedByteArray = _dump()
	for index: int in script.size():
		bytes[0xD01 + index] = script[index]
	for index: int in 6:
		bytes[0xF00 + index] = [0xFC, 0x0B, 0xFF, 0x01, 0xBB, 0xFF][index]
	bytes[0xF20] = 0x10
	bytes[0xF21] = 0x11
	bytes[0xF22] = 0xFE
	bytes.encode_u16(0xF30, 5)
	bytes.encode_u16(0xF32, 3)
	return bytes


## Protect which operands are data and how far each run reaches: msgbox's
## `loadword 0` but no other slot, null and RAM texts, a movement label inside
## another list, and a mart's ITEM_NONE. A wrong role or length moves a digest
## only after a reimport, and the refusals never happen on a real dump.
func test_script_data_follows_handler_operands_through_the_cache() -> void:
	var script := PackedByteArray([0x0F, 0, 0, 0x0F, 0, 8, 0x0F, 1, 0xF0, 0x0F, 0, 0xFF,
		0x67, 0, 0, 0, 0, 0x67, 0xC4, 0x1F, 0x02, 0x02, 0x4F, 1, 0, 0x20, 0x0F, 0, 8,
		0x4F, 2, 0, 0x21, 0x0F, 0, 8, 0x86, 0x30, 0x0F, 0, 8, 2])
	var world: Dictionary = Gen3World.read(RomFile.from_bytes(_data_dump(script), RomRegistry.EMERALD), LAYOUT)
	assert_false(world.is_empty())
	var path: String = "user://test_gen3_script_data.json"
	assert_true(RomCache.write_section(path, RomCache.blob_path(path), world["scripts"]))
	var data := GameData.new()
	data.generation = RomRegistry.GEN3
	data._sections = {"scripts": true}
	data._world_scripts = RomCache.read_json(path)
	data._indices["blob/scripts"] = RomCache.read_blob(RomCache.blob_path(path))
	assert_eq(data.world_script_offsets("texts"), [0xF00])
	assert_eq(data.world_script_data("texts", 0xF00)["bytes"], PackedByteArray([0xFC, 0x0B, 0xFF, 0x01, 0xBB, 0xFF]))
	assert_eq(data.world_script_offsets("movements"), [0xF20, 0xF21])
	assert_eq(data.world_script_data("movements", 0xF21)["bytes"], PackedByteArray([0x11, 0xFE]))
	var mart: Dictionary = data.world_script_data("marts", 0xF30)
	assert_eq(mart["entries"], [5, 3])
	assert_typeof(mart["entries"][0], TYPE_INT)
	mart["entries"][0] = 0
	assert_eq(data.world_script_data("marts", 0xF30)["entries"][0], 5)
	assert_true(data.world_script_data("braille", 0xF00).is_empty())
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(RomCache.blob_path(path))
	var refusals: Array = [{0xF32: 10}, {0xF20: 0x9E}, {0xF04: 0xFC, 0xF05: 0x19, 0xF06: 0xFF},
		{0xD03: 0x0C, 0xD04: 0x0D}]
	for change: Dictionary in refusals:
		var bytes: PackedByteArray = _data_dump(script)
		for at: int in change:
			bytes[at] = change[at]
		assert_true(Gen3World.read(RomFile.from_bytes(bytes, RomRegistry.EMERALD), LAYOUT).is_empty(), str(change))


func test_out_of_range_standard_script_calls_keep_their_fallthrough() -> void:
	var bytes: PackedByteArray = _dump()
	bytes[0xD01] = 8
	bytes[0xD02] = 255
	bytes[0xD03] = 2
	var scripts: Dictionary = Gen3Script.read(RomFile.from_bytes(bytes, RomRegistry.EMERALD), LAYOUT, {})
	assert_true(scripts["instructions"][str(0xD01)]["fallthrough"])
	assert_eq(scripts["instructions"].size(), 2)


func _field_objects(id: StringName) -> Gen3ObjectEvents:
	var data := GameData.new()
	data.id = id
	data.generation = RomRegistry.GEN3
	data._sections = {"headers": true, "scripts": true}
	data._world_headers = {"0:0": {"events": {"objects": []}}}
	var movement: Array = []
	for type: int in 12:
		movement.append({"ranged": false, "facing": 1})
	data._world_scripts = {"movement_types": movement}
	var camera := Gen3FieldCamera.new()
	camera.data = data
	camera.group = 0
	camera.number = 0
	camera.grid = Gen3MapGrid.new()
	camera.grid.width = 32
	camera.grid.height = 32
	camera.grid.layout_width = 17
	camera.grid.layout_height = 18
	camera.grid.blocks.resize(32 * 32)
	camera.grid.blocks.fill(0x3000)
	camera.grid._behaviors.resize(1024)
	for behavior: int in 512:
		camera.grid._behaviors[behavior] = behavior
	return Gen3ObjectEvents.new(camera, Gen3EventData.new(id))


## Protect pool reservation, player persistence at map edges, locked turns and
## state-mask priority. Reusing an NPC spawn or replacing all flag bits breaks
## these; the importer and NPC corpus checks never create an avatar.
func test_player_avatar_reserves_a_slot_and_preserves_control_state() -> void:
	for id: StringName in [RomRegistry.RUBY, RomRegistry.SAPPHIRE, RomRegistry.FIRERED,
			RomRegistry.LEAFGREEN, RomRegistry.EMERALD]:
		var objects: Gen3ObjectEvents = _field_objects(id)
		var avatar: Gen3PlayerAvatar = Gen3PlayerAvatar.open(objects, Vector2i(12, 12), 4, 1)
		assert_eq(avatar.object_id, 0)
		assert_true(avatar.object().is_player)
		assert_eq(avatar.object().graphics_id, 7 if id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN] else 89)
		assert_eq(avatar.object().current, Vector2i(12, 12))
		assert_eq(avatar.object().previous_movement_direction, 1)
		assert_eq(avatar.object().current_elevation, 0)
		assert_eq(avatar.flags, 0x21)
		assert_null(Gen3PlayerAvatar.open(objects, Vector2i(12, 12), 1, 0))
		avatar.track_camera()
		assert_true(avatar.object().tracked_by_camera)
		objects.camera.pos = Vector2i(100, 100)
		objects.remove_outside_view()
		assert_true(avatar.object().active)
		avatar.object().facing_locked = true
		Gen3ObjectEvents.set_direction(avatar.object(), 2)
		assert_eq(avatar.object().facing, 4)
		assert_eq(avatar.object().previous_movement_direction, 4)
		assert_eq(avatar.object().movement_direction, 2)
		avatar.flags = 0xFF
		avatar.set_state_mask(8)
		assert_eq(avatar.flags, 0xE8)
		assert_eq(avatar.graphics_by_current_state(), 9 if id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN] else 92)
		avatar.set_state_mask(3)
		assert_eq(avatar.graphics_by_current_state(), avatar.graphics_for(0))
	var full_pool: Gen3ObjectEvents = _field_objects(RomRegistry.EMERALD)
	for object: Gen3ObjectEvents.ObjectEvent in full_pool.objects:
		object.active = true
	assert_null(Gen3PlayerAvatar.open(full_pool, Vector2i(12, 12), 1, 0))


## Protect precedence and current-vs-previous lookup: a blocked ledge is still
## jumped, surf dismount ignores a departing object, Strength does not. A flat
## passability test or reuse of the generic occupancy reader changes them.
func test_player_collision_precedence_and_effect_requests() -> void:
	var objects: Gen3ObjectEvents = _field_objects(RomRegistry.EMERALD)
	var avatar: Gen3PlayerAvatar = Gen3PlayerAvatar.open(objects, Vector2i(12, 12), 1, 0)
	var grid: Gen3MapGrid = objects.camera.grid
	grid.set_metatile_entry(12, 13, 0x3C3B)
	assert_eq(avatar.check_collision(1), {"collision": 6, "requests": [{"kind": "jumped_ledge"}]})
	assert_eq(avatar.collision_at(avatar.object(), Vector2i(12, 13), 1, true)["collision"], 2)
	assert_eq(avatar.check_collision(2)["collision"], 0)
	grid.set_metatile_entry(12, 13, 0x3000)
	avatar.object().current_elevation = 1
	avatar.flags = 8
	assert_eq(avatar.check_collision(1), {"collision": 5, "requests": [{"kind": "stop_surfing", "direction": 1}]})
	var other: Gen3ObjectEvents.ObjectEvent = objects.objects[1]
	other.active = true
	other.current = Vector2i(13, 13)
	other.previous = Vector2i(12, 13)
	other.current_elevation = 3
	assert_eq(avatar.check_collision(1)["collision"], 5)
	other.current = Vector2i(12, 13)
	assert_eq(avatar.check_collision(1)["collision"], 3)
	other.current_elevation = 0
	assert_eq(avatar.check_collision(1)["collision"], 3)
	avatar.object().current_elevation = 3
	other.graphics_id = 87
	objects.events.flag_set(0x829)
	other.previous = other.current
	assert_eq(avatar.check_collision(1)["collision"], 4)
	objects.events.flag_set(0x889)
	assert_eq(avatar.check_collision(1), {"collision": 7,
		"requests": [{"kind": "push_boulder", "object_id": 1, "direction": 1}]})
	grid.set_metatile_entry(12, 14, 0x3060)
	assert_eq(avatar.check_collision(1)["collision"], 4)
	other.current = Vector2i(13, 13)
	assert_eq(avatar.check_collision(1)["collision"], 4)
	other.active = false
	grid.set_metatile_entry(12, 13, 0x30D1)
	assert_eq(avatar.check_collision(1)["collision"], 9)


## FRLG's stairs read the source cell and its fall warp bypasses boulder
## blocking; ninth-bit behaviors narrow at u8 predicates. Hoenn checks and
## real maps without such high-bit attributes cannot catch these differences.
func test_frlg_stairs_fall_warps_and_behavior_narrowing() -> void:
	var objects: Gen3ObjectEvents = _field_objects(RomRegistry.FIRERED)
	var avatar: Gen3PlayerAvatar = Gen3PlayerAvatar.open(objects, Vector2i(12, 12), 4, 0)
	var grid: Gen3MapGrid = objects.camera.grid
	grid.set_metatile_entry(12, 12, 0x306C)
	assert_eq(avatar.check_collision(4)["collision"], 8)
	assert_eq(avatar.check_collision(3)["collision"], 0)
	grid.set_metatile_entry(12, 12, 0x3000)
	grid.set_metatile_entry(13, 12, 0x30D1)
	assert_eq(avatar.check_collision(4)["collision"], 0)
	var boulder: Gen3ObjectEvents.ObjectEvent = objects.objects[1]
	boulder.active = true
	boulder.current = Vector2i(13, 12)
	boulder.previous = boulder.current
	boulder.graphics_id = 97
	objects.events.flag_set(0x805)
	grid.set_metatile_entry(14, 12, 0x3C66)
	assert_eq(avatar.check_collision(4)["collision"], 7)
	grid.set_metatile_entry(14, 12, 0x3D66)
	assert_eq(avatar.check_collision(4)["collision"], 4)
	grid.set_metatile_entry(14, 12, 0x3C00)
	assert_eq(avatar.check_collision(4)["collision"], 4)
	boulder.active = false
	grid.set_metatile_entry(13, 12, 0x3131)
	assert_eq(avatar.check_collision(4)["collision"], 2)
	grid.set_metatile_entry(13, 12, 0x3138)
	assert_eq(avatar.check_collision(4)["collision"], 6)
	grid.set_metatile_entry(12, 12, 0x316C)
	assert_eq(avatar.check_collision(4)["collision"], 8)
	var probe := Gen3ObjectEvents.ObjectEvent.new()
	var collisions := PackedByteArray()
	for behavior: int in 512:
		grid.set_metatile_entry(13, 12, 0x3000 | behavior)
		for direction: int in range(1, 5):
			collisions.append(objects.collision_at(probe, 13, 12, direction))
	# GetCollisionAtCoords on the byte-matching FireRed ARM build, all nine-bit
	# behaviors and four directions; unrelated occupancy/bounds checks stubbed.
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA1)
	context.update(collisions)
	assert_eq(context.finish().hex_encode(), "52b7918b9a77eab781cb5694d5d6fd3fe3d8dc60")
	collisions.clear()
	grid.set_metatile_entry(13, 12, 0x3000)
	for behavior: int in 512:
		probe.current_behavior = behavior
		for direction: int in range(1, 5):
			collisions.append(objects.collision_at(probe, 13, 12, direction))
	context.start(HashingContext.HASH_SHA1)
	context.update(collisions)
	assert_eq(context.finish().hex_encode(), "a7a8366fd59a46b69c316cf1ba715119eb7e48b5")


## Surf prompts use the last nonzero elevation and, on FRLG, terrain rather
## than a water-looking behavior. Reusing the Hoenn predicate makes valid
## FRLG water fail and waterfalls pass; collision tests do not ask this query.
func test_player_water_query_reads_each_engines_source_of_water() -> void:
	for id: StringName in [RomRegistry.RUBY, RomRegistry.FIRERED, RomRegistry.EMERALD]:
		var objects: Gen3ObjectEvents = _field_objects(id)
		var avatar: Gen3PlayerAvatar = Gen3PlayerAvatar.open(objects, Vector2i(12, 12), 4, 0)
		avatar.object().current_elevation = 3
		avatar.object().previous_elevation = 3
		var grid: Gen3MapGrid = objects.camera.grid
		grid.set_metatile_entry(13, 12, 0x1010)
		if id == RomRegistry.FIRERED:
			var words := PackedByteArray()
			words.resize(256 * 4)
			words.encode_u32(0x10 * 4, 2 << 9)
			grid.primary = {"metatile_count": 256, "attribute_size": 4,
				"attributes": {"bytes": words}, "metatiles": {"bytes": PackedByteArray()}}
		assert_true(avatar.facing_fishable_water())
		avatar.object().previous_elevation = 1
		assert_false(avatar.facing_fishable_water())
		avatar.object().previous_elevation = 3
		grid.set_metatile_entry(13, 12, 0x1013)
		assert_false(avatar.facing_fishable_water())
