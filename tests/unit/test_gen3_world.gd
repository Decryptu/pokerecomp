extends GutTest

## Protect GBA bounds, header/event formats, script dispatch and encounter variants.
## GB world tests miss packed unions, padding, rod slices and Hoenn species IDs.
const LAYOUT: Dictionary = {"map_groups": 0, "map_group_sizes": [2], "item_count": 10,
	"wild_headers": 0x400, "wild_header_count": 2, "species_to_national": 0x800,
	"standard_scripts": 0xC00, "standard_script_count": 1,
	"berries": 0x820, "movement_types": 0xF80, "movement_type_count": 2,
	"trainer_battle_scripts": [0xD01, 0xD01, 0xD01, 0xD01, 0xD01]}


func _dump(id: StringName = RomRegistry.EMERALD) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(4096)
	bytes.encode_u32(0xC00, 0x08000D01)
	bytes[0xD01] = 2
	for berry: int in 43:
		bytes[0x820 + berry * 28 + 20] = 3
		bytes[0x820 + berry * 28 + 10] = 3
		bytes[0x820 + berry * 28 + 11] = 2
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
	var surfable: Array = [0x6F] if id in [RomRegistry.RUBY, RomRegistry.SAPPHIRE, RomRegistry.EMERALD] else []
	data._world_scripts = {"movement_types": movement, "surfable_behaviors": surfable}
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


const GEN3_TABLES = preload("res://tools/checks/gen3_tables.gd")


## ARM-handler traces protect destination reservation, slow-walk cadence,
## midpoint jumps, locked/contextual facings, persistent flags and emote requests.
## Substituting a generic tween or Hoenn action ids on FRLG changes this stream.
func test_held_movement_frames_match_each_cartridge_engine() -> void:
	var digests: Dictionary = {
		RomRegistry.RUBY: "a16c8b027612ee10665e8b1317ab99787e469c35",
		RomRegistry.SAPPHIRE: "a16c8b027612ee10665e8b1317ab99787e469c35",
		RomRegistry.FIRERED: "7f85d125b31f24b43046a3fda4bce3d9b769c8e1",
		RomRegistry.LEAFGREEN: "7f85d125b31f24b43046a3fda4bce3d9b769c8e1",
		RomRegistry.EMERALD: "917933e32eb5ac1a0c7d22ad3bf4c8dbf6c14c58",
	}
	for id: StringName in digests:
		assert_eq(_held_movement_trace(id).sha1_text(), digests[id], str(id))


func _held_movement_trace(id: StringName) -> String:
	var objects: Gen3ObjectEvents = _field_objects(id)
	var lines := PackedStringArray()
	for action: int in 256:
		for locked: int in 2:
			var object := Gen3ObjectEvents.ObjectEvent.new()
			object.active = true
			object.local_id = 0
			object.map_number = 0
			object.map_group = 0
			object.current = Vector2i(12, 12)
			object.previous = Vector2i(11, 12)
			object.pixel_position = object.current * 16
			object.facing = 4
			object.movement_direction = 4
			object.facing_locked = locked != 0
			object.frozen = true
			objects.objects[0] = object
			if not GEN3_TABLES.arm_traced(objects, action) or objects.set_held_movement(object, action):
				continue
			for frame: int in range(1, 41):
				var effects: Array = objects.step_movements().filter(GEN3_TABLES.arm_traced_effect)
				var effect: Array = [-1, 0, 0, 0] if effects.is_empty() else [effects[0]["effect_id"],
					effects[0]["local_id"], effects[0]["map_number"], effects[0]["map_group"]]
				var pixels: Vector2i = object.pixel_position - Vector2i(192, 192)
				lines.append(",".join([action, locked, frame, object.current.x, object.current.y,
					object.previous.x, object.previous.y, pixels.x, pixels.y, object.jump_y,
					object.facing, object.movement_direction, object.previous_movement_direction,
					int(object.facing_locked), int(object.held_movement_finished),
					int(object.invisible), int(object.disable_jump_landing_effect), int(object.fixed_priority)] + effect))
	return "\n".join(lines) + "\n"


## The collision host must reserve both endpoints until arrival and release
## only the departure cell then. No importer or stationary collision check
## exercises occupancy while a held action is progressing or awaiting clearing.
func test_held_movement_occupancy_ground_reads_and_explicit_clearing() -> void:
	var objects: Gen3ObjectEvents = _field_objects(RomRegistry.EMERALD)
	var avatar: Gen3PlayerAvatar = Gen3PlayerAvatar.open(objects, Vector2i(12, 12), 4, 0)
	var player: Gen3ObjectEvents.ObjectEvent = avatar.object()
	var grid: Gen3MapGrid = objects.camera.grid
	grid.set_metatile_entry(12, 12, 0x3001)
	grid.set_metatile_entry(13, 12, 0x4002)
	player.frozen = true
	assert_eq(Gen3ObjectEvents.held_movement_status(player), 16)
	assert_false(objects.set_held_movement(player, 0x0B))
	assert_false(player.frozen)
	assert_true(objects.set_held_movement(player, 0))
	assert_eq(objects.step_movements(), [{"kind": "spawn", "object_id": 0},
		{"kind": "begin_step", "object_id": 0}])
	assert_eq(player.current, Vector2i(13, 12))
	assert_eq(player.previous, Vector2i(12, 12))
	assert_eq(player.pixel_position, Vector2i(193, 192))
	assert_eq([player.current_behavior, player.previous_behavior, player.current_elevation], [2, 1, 4])
	var probe := Gen3ObjectEvents.ObjectEvent.new()
	assert_eq(objects.collision_at(probe, 12, 12, 4), Gen3ObjectEvents.Collision.OBJECT_EVENT)
	assert_eq(objects.collision_at(probe, 13, 12, 4), Gen3ObjectEvents.Collision.OBJECT_EVENT)
	assert_eq(Gen3ObjectEvents.clear_held_movement_if_finished(player), 0)
	for frame: int in 14:
		assert_eq(objects.step_movements(), [])
	assert_eq(objects.step_movements(), [{"kind": "finish_step", "object_id": 0}])
	assert_eq(player.previous, player.current)
	assert_eq(player.pixel_position, Vector2i(208, 192))
	assert_eq([player.current_behavior, player.previous_behavior], [2, 2])
	assert_eq(objects.collision_at(probe, 12, 12, 4), Gen3ObjectEvents.Collision.NONE)
	assert_eq(Gen3ObjectEvents.held_movement_status(player), 1)
	assert_true(objects.set_held_movement(player, 0))
	assert_eq(Gen3ObjectEvents.clear_held_movement_if_finished(player), 1)
	assert_eq(Gen3ObjectEvents.clear_held_movement_if_finished(player), 16)
	assert_true(objects.set_held_movement(player, 0xFE))
	assert_false(player.held_movement_active)


## ARM tasks and held dispatchers pin frame order, blocked/finished holds,
## facing locks and FRLG freezing. Swapping task/sprite order or clearing every
## finished hold erases cartridge differences no stationary probe exercises.
func test_avatar_movement_tasks_match_each_cartridge_engine() -> void:
	var digests: Dictionary = {
		RomRegistry.RUBY: "dcda455344be4fb5d7dff51eea65c3b67d356500",
		RomRegistry.SAPPHIRE: "dcda455344be4fb5d7dff51eea65c3b67d356500",
		RomRegistry.FIRERED: "f881d6493b11d6169671ed20ab47926d3eb5dc59",
		RomRegistry.LEAFGREEN: "f881d6493b11d6169671ed20ab47926d3eb5dc59",
		RomRegistry.EMERALD: "c9405ecfd60809f43167cc01942dfb66361a8727",
	}
	for id: StringName in digests:
		var trace: String = _avatar_task_trace(id)
		assert_eq(trace.sha1_text(), digests[id], str(id))


func _avatar_task_trace(id: StringName) -> String:
	var lines := PackedStringArray()
	for kind: int in 2:
		for direction: int in range(1, 5):
			for hold_state: int in 4:
				for locked: int in 2:
					var avatar: Gen3PlayerAvatar = _task_avatar(id, kind, direction, hold_state, locked)
					lines.append(_task_frame(avatar, [kind, direction, hold_state, locked, 0]))
					for frame: int in range(1, 41):
						var held: Gen3ObjectEvents.ObjectEvent = avatar.object() if kind == 1 else avatar.objects.objects[1]
						if frame == 4 and hold_state > 0 and (held.single_movement_active
								or held.movement_action == (0x19 if avatar._frlg else 0x11)):
							Gen3ObjectEvents.clear_held_movement(held)
							held.single_movement_active = false
						avatar.step_movement_tasks()
						avatar.objects.step_movements()
						lines.append(_task_frame(avatar, [kind, direction, hold_state, locked, frame]))
	return "\n".join(lines) + "\n"


func _task_avatar(id: StringName, kind: int, direction: int, hold_state: int, locked: int) -> Gen3PlayerAvatar:
	var objects: Gen3ObjectEvents = _field_objects(id)
	var avatar: Gen3PlayerAvatar = Gen3PlayerAvatar.open(objects, Vector2i(12, 12), 4, 1)
	avatar.flags = 0xE8 if kind == 1 else 0x21
	avatar.object().facing_locked = locked != 0
	avatar.object().frozen = true
	if kind == 1:
		avatar.object().graphics_id = avatar.graphics_for(Gen3PlayerAvatar.State.SURFING)
		avatar.object().current_elevation = 1
	for slot: int in range(1, 3):
		var object := Gen3ObjectEvents.ObjectEvent.new()
		object.active = true
		object.local_id = slot
		object.map_group = 0
		object.map_number = 0
		object.graphics_id = 97
		if slot == 1 and not avatar._frlg:
			object.graphics_id = 87
		object.current = Vector2i(12, 12) + Gen3FieldCamera.DIRECTIONS[direction] if slot == 1 else Vector2i(20, 20)
		object.previous = object.current
		object.pixel_position = object.current * 16
		object.facing = 4
		object.movement_direction = 4
		object.frozen = slot == 1 and kind == 0
		objects.objects[slot] = object
	if kind == 1:
		objects.objects[1].current_elevation = 1
	var held: Gen3ObjectEvents.ObjectEvent = avatar.object() if kind == 1 else objects.objects[1]
	if hold_state in [1, 2]:
		objects.set_held_movement(held, 0x19 if avatar._frlg else 0x11)
		held.held_movement_finished = hold_state == 2
	elif hold_state == 3:
		held.single_movement_active = true
	if kind == 1 and hold_state == 1:
		objects.set_held_movement(objects.objects[2], 0x1C if avatar._frlg else 0x14)
	objects.events.flag_set(Gen3EventData.STRENGTH_FLAG[id])
	avatar.begin_collision_movement(direction)
	return avatar


func _task_frame(avatar: Gen3PlayerAvatar, prefix: Array) -> String:
	var values: Array = prefix + [avatar.flags, int(avatar.prevent_step), int(avatar.controls_locked)]
	var origins: Array[Vector2i] = [Vector2i(12, 12),
		Vector2i(12, 12) + Gen3FieldCamera.DIRECTIONS[int(prefix[1])], Vector2i(20, 20)]
	for slot: int in 3:
		var object: Gen3ObjectEvents.ObjectEvent = avatar.objects.objects[slot]
		var pixels: Vector2i = object.pixel_position - origins[slot] * 16
		values.append_array([object.current.x, object.current.y, object.previous.x, object.previous.y,
			pixels.x, pixels.y, object.jump_y, object.facing, object.movement_direction,
			object.previous_movement_direction, int(object.facing_locked), Gen3ObjectEvents.held_movement_status(object),
			object.movement_action, object.graphics_id, int(object.frozen)])
	return ",".join(values)


## A push lands before its task unlocks input. Using the object's byte-sized
## trainer type or removing without a hide flag loses a Seafoam floor's state;
## stationary avatar probes never run the landing or respawn objects.
func test_strength_landing_hides_boulder_reveals_floor_and_releases_occupancy() -> void:
	for id: StringName in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN]:
		var avatar: Gen3PlayerAvatar = _boulder_avatar(id, 0x3C66)
		var objects: Gen3ObjectEvents = avatar.objects
		var boulder: Gen3ObjectEvents.ObjectEvent = objects.objects[1]
		objects.events.flag_set(0x125)
		assert_eq(boulder.trainer_type, 0x25)
		assert_eq(avatar.begin_collision_movement(4)["collision"], Gen3PlayerAvatar.Collision.PUSHED_BOULDER)
		assert_true(avatar.controls_locked)
		assert_eq(avatar.begin_collision_movement(4)["collision"], Gen3PlayerAvatar.Collision.IMPASSABLE)
		var effects: Array = []
		for frame: int in 33:
			effects.append_array(avatar.step_movement_tasks())
			objects.step_movements()
			if frame == 0:
				assert_eq(boulder.current, Vector2i(14, 12))
				assert_eq(boulder.previous, Vector2i(13, 12))
				assert_eq(objects.collision_at(avatar.object(), 13, 12, 4), Gen3ObjectEvents.Collision.OBJECT_EVENT)
		assert_false(avatar.prevent_step)
		assert_false(avatar.controls_locked)
		assert_false(boulder.active)
		assert_eq(avatar.object().current, Vector2i(12, 12))
		assert_true(objects.events.flag_get(0x25))
		assert_false(objects.events.flag_get(0x125))
		assert_true(effects.has({"kind": "sound", "name": "fall"}))
		objects.spawn_in_view()
		assert_eq(objects.at_position(Vector2i(13, 12)), -1)
		assert_eq(objects.collision_at(avatar.object(), 13, 12, 4), Gen3ObjectEvents.Collision.NONE)


## Switch dispatch ignores the normal coordinate-event variable/elevation
## gates and preserves duplicate rows, including null scripts. Filtering as a
## player step drops a boulder's scripts; no bytecode test pushes.
func test_strength_switch_dispatch_preserves_all_matching_coordinate_rows() -> void:
	for id: StringName in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN, RomRegistry.EMERALD]:
		var avatar: Gen3PlayerAvatar = _boulder_avatar(id, 0x3020)
		var coords: Array = [
			{"x": 7, "y": 5, "elevation": 15, "variable": 0x4000, "value": 99, "script_offset": 0xD00},
			{"x": 8, "y": 5, "elevation": 0, "variable": 0, "value": 0, "script_offset": 0xD20},
			{"x": 7, "y": 5, "elevation": 0, "variable": 0, "value": 0, "script_offset": 0},
		]
		avatar.objects.camera.data._world_headers["0:0"]["events"]["coords"] = coords
		assert_eq(avatar.begin_collision_movement(4)["collision"], Gen3PlayerAvatar.Collision.PUSHED_BOULDER)
		var scripts: Array = []
		for frame: int in 33:
			for effect: Dictionary in avatar.step_movement_tasks():
				if effect["kind"] == "script":
					scripts.append(int(effect["offset"]))
			avatar.objects.step_movements()
		assert_eq(scripts, [] if id == RomRegistry.EMERALD else [0xD00, 0])
		assert_false(avatar.controls_locked)
		assert_true(avatar.objects.objects[1].active)


func _boulder_avatar(id: StringName, entry: int) -> Gen3PlayerAvatar:
	var objects: Gen3ObjectEvents = _field_objects(id)
	objects.camera.header = {"layout_id": 1}
	var avatar: Gen3PlayerAvatar = Gen3PlayerAvatar.open(objects, Vector2i(12, 12), 4, 0)
	var template: Dictionary = Gen3ObjectEvents.EMPTY_TEMPLATE.duplicate()
	template.merge({"local_id": 1, "graphics_id": 97 if avatar._frlg else 87,
		"x": 6, "y": 5, "elevation": 3, "trainer_type": 0x125, "flag": 0x25}, true)
	objects.camera.data._world_headers["0:0"]["events"]["objects"] = [template]
	objects.load_templates()
	objects.spawn_in_view()
	objects.camera.grid.set_metatile_entry(14, 12, entry)
	objects.events.flag_set(Gen3EventData.STRENGTH_FLAG[id])
	return avatar


## A ledge is a two-cell held jump, while another held action remains owned by
## its caller. Replacing it or clearing a finished hold here changes scripted
## motion; only the input model consumes ledge collision requests.
func test_ledge_collision_starts_two_cell_jump_without_stealing_a_hold() -> void:
	var objects: Gen3ObjectEvents = _field_objects(RomRegistry.EMERALD)
	var avatar: Gen3PlayerAvatar = Gen3PlayerAvatar.open(objects, Vector2i(12, 12), 4, 0)
	objects.camera.grid.set_metatile_entry(13, 12, 0x3C38)
	assert_eq(avatar.begin_collision_movement(4)["requests"],
		[{"kind": "jumped_ledge"}, {"kind": "sound", "name": "ledge"}])
	assert_eq(avatar.object().player_copyable_movement, 8)
	for frame: int in 32:
		objects.step_movements()
	assert_eq(avatar.object().current, Vector2i(14, 12))
	assert_eq(avatar.object().pixel_position, Vector2i(224, 192))
	objects.camera.grid.set_metatile_entry(15, 12, 0x3C38)
	avatar.begin_collision_movement(4)
	assert_true(avatar.object().held_movement_finished)
	assert_eq(avatar.object().movement_action, 0x0F)


## The ARM lookup uses active local IDs, not the player bit or map identity;
## nearest-axis facing and unconditional coordinate shifts both corrupt it.
## Isolated action traces have no player and cannot detect these substitutions.
func test_contextual_facing_matches_cartridge_lookup_and_axis_priority() -> void:
	for id: StringName in [RomRegistry.RUBY, RomRegistry.SAPPHIRE, RomRegistry.FIRERED,
			RomRegistry.LEAFGREEN, RomRegistry.EMERALD]:
		assert_eq(_context_facing_trace(id).sha1_text(), "42f8b1b53021ea18a3e0f8d3c5869651ddf336f3", str(id))


func _context_facing_trace(id: StringName) -> String:
	var field: Gen3ObjectEvents = _field_objects(id)
	for entry: Vector2i in [Vector2i(7, 2), Vector2i(9, 3), Vector2i(10, 4)]:
		field.camera.data._world_scripts["movement_types"][entry.x]["facing"] = entry.y
	var objects := Gen3ObjectEvents.new(field.camera, field.events)
	var actions: Array = [0x4A, 0x4B, 0x5A] if objects._frlg else [0x3E, 0x3F, 0x4E]
	var lines := PackedStringArray()
	for mode: int in 3:
		for locked: int in 2:
			for presence: int in 4:
				for type: int in [0, 7, 8, 9, 10]:
					for dx: int in range(-2, 3):
						for dy: int in range(-2, 3):
							lines.append_array(_context_frames(objects, int(actions[mode]),
								[mode, locked, presence, type, dx, dy]))
	return "\n".join(lines) + "\n"


func _context_frames(objects: Gen3ObjectEvents, action: int, setup: Array) -> PackedStringArray:
	var object := Gen3ObjectEvents.ObjectEvent.new()
	object.active = true
	object.local_id = 42
	object.map_number = 7
	object.map_group = 9
	object.movement_type = int(setup[3])
	object.current = Vector2i(12, 12)
	object.previous = Vector2i(11, 12)
	object.pixel_position = object.current * 16
	object.facing = 4
	object.movement_direction = 4
	object.facing_locked = int(setup[1]) != 0
	objects.objects[0] = object
	var player := Gen3ObjectEvents.ObjectEvent.new()
	player.active = int(setup[2]) in [1, 3]
	player.is_player = int(setup[2]) == 3
	player.local_id = 42 if player.is_player else Gen3ObjectEvents.LOCALID_PLAYER
	player.map_number = 33
	player.map_group = 44
	player.current = object.current + Vector2i(int(setup[4]), int(setup[5]))
	objects.objects[1] = player
	objects.set_held_movement(object, action)
	var lines := PackedStringArray()
	for frame: int in range(1, 3):
		objects.step_movements()
		lines.append(",".join(setup + [frame, object.current.x, object.current.y,
			object.previous.x, object.previous.y, 0, 0, 0, object.facing, object.movement_direction,
			object.previous_movement_direction, int(object.facing_locked), int(object.held_movement_finished),
			0, 0, 0, -1, 0, 0, 0]))
	return lines


## `InitJumpRegular` starts FLDEFF_SHADOW once per jump for the drawing host and
## clears `hasShadow` on landing; `InitJumpSpecial` starts none. The ARM-pinned
## movement streams leave the shadow out, so only this asserts it.
func test_regular_jumps_start_one_shadow_and_clear_it_on_landing() -> void:
	for id: StringName in [RomRegistry.RUBY, RomRegistry.FIRERED]:
		var objects: Gen3ObjectEvents = _field_objects(id)
		var object := Gen3ObjectEvents.ObjectEvent.new()
		object.active = true
		object.local_id = 3
		object.current = Vector2i(12, 12)
		object.facing = Gen3ObjectEvents.Direction.EAST
		objects.objects[0] = object
		var frlg: bool = id == RomRegistry.FIRERED
		for action: int in [0x0F + 8 * int(frlg), 0x46 + 12 * int(frlg), 0x3D + 12 * int(frlg)]:
			Gen3ObjectEvents.clear_held_movement(object)
			objects.set_held_movement(object, action)
			var shadows: Array = []
			var shadowed: bool = false
			while not object.held_movement_finished:
				shadows.append_array(objects.step_movements().filter(func(request: Dictionary) -> bool:
					return request["kind"] == "field_effect" and request.get("effect_id", -1) == Gen3ObjectEvents.FLDEFF_SHADOW))
				shadowed = shadowed or object.has_shadow
			var special: bool = action == 0x3D + 12 * int(frlg)
			assert_eq(shadows.size(), 0 if special else 1, "%s %02X" % [id, action])
			assert_eq(shadowed, not special)
			assert_false(object.has_shadow)
		assert_eq(objects.step_movements().size(), 0)


## Follow the real jump input through the effect list: the request-only path never tracked or stopped a shadow.
func test_jump_shadow_lifetime_follows_identity_and_terrain() -> void:
	for id: StringName in [RomRegistry.RUBY, RomRegistry.SAPPHIRE, RomRegistry.FIRERED,
			RomRegistry.LEAFGREEN, RomRegistry.EMERALD]:
		var objects: Gen3ObjectEvents = _field_objects(id)
		var object := Gen3ObjectEvents.ObjectEvent.new()
		object.active = true
		object.local_id = 3
		object.current = Vector2i(12, 12)
		object.previous = object.current
		objects.objects[0] = object
		objects.set_held_movement(object, 0x17 if id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN] else 0x0F)
		objects.step_movements()
		assert_true(objects.field_effect_active(Gen3ObjectEvents.FLDEFF_SHADOW), str(id))
		while not object.held_movement_finished:
			objects.step_movements()
		assert_false(objects.field_effect_active(Gen3ObjectEvents.FLDEFF_SHADOW), str(id))
		for probe: Array in [[2, 0, false], [0, 2, true], [0, 0x16, false], [0x17, 0, true],
				[0xD1, 0, id in [RomRegistry.RUBY, RomRegistry.SAPPHIRE, RomRegistry.EMERALD]],
				[0x6F, 0, id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN]]]:
			object.has_shadow = true
			object.current_behavior = int(probe[0])
			object.previous_behavior = int(probe[1])
			var requests: Array = []
			objects.start_effect_sprite(object, 0, Gen3ObjectEvents.FLDEFF_SHADOW, -1, true, requests)
			objects.step_movements()
			assert_eq(objects.field_effect_active(Gen3ObjectEvents.FLDEFF_SHADOW), probe[2], "%s %s" % [id, probe])
			object.active = false
			objects.step_movements()
			assert_false(objects.field_effect_active(Gen3ObjectEvents.FLDEFF_SHADOW))
			object.active = true


## The shadow follows ground position without x2/y2 or visibility, keeps its spawn size, and sorts with objects.
## Existing movement tests see requests only; the BG compositor test supplies OAM rather than building it.
func test_shadow_oam_tracks_ground_and_keeps_spawn_geometry() -> void:
	var objects: Gen3ObjectEvents = _field_objects(RomRegistry.EMERALD)
	var data: GameData = objects.camera.data
	data._sections["gba_graphics"] = true
	var tiles := PackedByteArray()
	tiles.resize(32)
	tiles.fill(0x11)
	data._world_tilesets = {"sprite_images": {"1": {"bytes": tiles}}}
	data._world_scripts["sprite_images"] = {"5": [[1, 32]]}
	data._world_scripts["shadow_templates"] = [{"width": 8, "height": 8, "images": 5}]
	data._world_scripts["object_graphics"] = [{"width": 16, "height": 32, "shadow_size": 0,
		"anims": 0, "oam": {"shape": 2, "size": 2}, "subsprite_tables": 0}]
	data._world_scripts["sprite_anims"] = {}
	var tall: Dictionary = data._world_scripts["object_graphics"][0].duplicate(true)
	tall["height"] = 64
	tall["shadow_size"] = 3
	data._world_scripts["object_graphics"].append(tall)
	var object := Gen3ObjectEvents.ObjectEvent.new()
	object.active = true
	object.local_id = 3
	object.pixel_position = Vector2i(80, 80)
	object.current = Vector2i(6, 5)
	object.priority = 2
	object.subpriority = 149
	object.fixed_priority = true
	object.has_shadow = true
	object.ground_on_spawn = false
	object.frozen = true
	object.anim.tiles = [1, 32]
	object.jump_y = -12
	object.x2 = 7
	objects.objects[0] = object
	var requests: Array = []
	objects.start_effect_sprite(object, 0, Gen3ObjectEvents.FLDEFF_SHADOW, -1, true, requests)
	objects.step_movements()
	var entries: Array = objects.sprites.oam(objects, Vector2i.ZERO)
	assert_eq(entries.size(), 2)
	assert_eq([entries[0]["x"], entries[0]["y"], entries[0]["size"], entries[0]["palette"], entries[0]["tiles"]],
		[84, 88, Vector2i(8, 8), 0, tiles])
	object.invisible = true
	object.pixel_position += Vector2i(16, 8)
	objects.step_movements()
	entries = objects.sprites.oam(objects, Vector2i.ZERO)
	assert_eq(entries.size(), 1)
	assert_eq([entries[0]["x"], entries[0]["y"]], [100, 96])
	objects.set_graphics_id(object, 1)
	entries = objects.sprites.oam(objects, Vector2i.ZERO)
	assert_eq([entries[0]["y"], entries[0]["size"]], [72, Vector2i(8, 8)])
	objects.remove(object.local_id, object.map_number, object.map_group)
	objects.step_movements()
	assert_true(objects.sprites.oam(objects, Vector2i.ZERO).is_empty())


## `UpdateObjectEventElevationAndPriority` returns before `ObjectEventUpdateElevation` under a
## fixed priority, so a fixed object keeps its elevation and OAM priority across a step onto
## another level while a free one takes the cell's.
func test_fixed_priority_skips_the_ground_elevation_and_priority_update() -> void:
	for id: StringName in [RomRegistry.RUBY, RomRegistry.FIRERED, RomRegistry.EMERALD]:
		for fixed: bool in [false, true]:
			var objects: Gen3ObjectEvents = _field_objects(id)
			objects.camera.grid.blocks[12 * 32 + 13] = 0x4000
			var object := Gen3ObjectEvents.ObjectEvent.new()
			object.active = true
			object.current = Vector2i(12, 12)
			object.previous = object.current
			object.current_elevation = 3
			object.previous_elevation = 3
			object.fixed_priority = fixed
			objects.objects[0] = object
			var walk: int = 0x10 if id == RomRegistry.FIRERED else 0x08
			objects.set_held_movement(object, Gen3ObjectEvents.direction_action(walk, Gen3ObjectEvents.Direction.EAST))
			while not object.held_movement_finished:
				objects.step_movements()
			assert_eq([object.current, object.current_elevation, object.previous_elevation, object.priority],
				[Vector2i(13, 12), 3 if fixed else 4, 3 if fixed else 4, 2 if fixed else 1], "%s %s" % [id, fixed])


## The OBJ layer takes each pixel from the first OAM entry with one there and only then
## weighs that entry's priority against the BG, so a later entry with the better priority
## stays behind it. Composing the layer by priority would draw the later one in front.
func test_first_oam_entry_owns_a_pixel_whatever_the_priorities() -> void:
	var grid: Gen3MapGrid = _field_objects(RomRegistry.EMERALD).camera.grid
	grid._layer_types.resize(1024)
	grid._layer_types.fill(Gen3FieldVram.LAYER_TYPES)
	var vram := Gen3FieldVram.new()
	vram.palettes.resize(512)
	var palettes := PackedByteArray()
	palettes.resize(512)
	palettes.encode_u16(2, 0x001F)
	palettes.encode_u16(4, 0x7C00)
	var oam: Array = []
	for entry: Array in [[0, 3, 0x11], [4, 0, 0x22]]:
		var tiles := PackedByteArray()
		tiles.resize(GbaTiles.TILE_BYTES)
		tiles.fill(entry[2])
		oam.append({"x": entry[0], "y": entry[0], "size": Vector2i(8, 8), "flip": Vector2i.ZERO,
			"priority": entry[1], "palette": 0, "tiles": tiles})
	var image: Image = vram.draw_screen(grid, Vector2i.ZERO, Vector2i(16, 16), oam, palettes)
	assert_eq([image.get_pixel(5, 5), image.get_pixel(10, 10), image.get_pixel(14, 2)],
		[PokePalette.from_packed(0x001F), PokePalette.from_packed(0x7C00), PokePalette.from_packed(0)])


## State actions must survive hold clearing without freeing an invisible NPC's
## collision cells; emotes identify it once rather than repeating on each frame.
## Isolated frame traces reset state before every action and use identity zero.
func test_instant_actions_persist_without_changing_occupancy_or_repeating_emotes() -> void:
	for id: StringName in [RomRegistry.RUBY, RomRegistry.SAPPHIRE, RomRegistry.FIRERED,
			RomRegistry.LEAFGREEN, RomRegistry.EMERALD]:
		var objects: Gen3ObjectEvents = _field_objects(id)
		var template: Dictionary = Gen3ObjectEvents.EMPTY_TEMPLATE.duplicate()
		template.merge({"local_id": 42, "x": 5, "y": 5}, true)
		var object: Gen3ObjectEvents.ObjectEvent = objects.objects[objects.spawn(template, 7, 9)]
		var offset: int = 12 if objects._frlg else 0
		for action: int in [0x54 + offset, 0x51 + offset, 0x5C + (14 if objects._frlg else 0)]:
			assert_false(objects.set_held_movement(object, action))
			objects.step_movements()
			assert_eq(Gen3ObjectEvents.clear_held_movement_if_finished(object), 1)
		assert_true(object.invisible)
		assert_true(object.disable_jump_landing_effect)
		assert_true(object.fixed_priority)
		var probe := Gen3ObjectEvents.ObjectEvent.new()
		assert_eq(objects.collision_at(probe, 12, 12, 4), Gen3ObjectEvents.Collision.OBJECT_EVENT)
		assert_false(objects.set_held_movement(object, 0x56 + offset))
		assert_eq(objects.step_movements(), [{"kind": "field_effect", "effect_id": 0,
			"object_id": 0, "local_id": 42, "map_number": 7, "map_group": 9}])
		assert_eq(objects.step_movements(), [])
		assert_true(object.held_movement_active)
		Gen3ObjectEvents.clear_held_movement_if_finished(object)
		for action: int in [0x55 + offset, 0x50 + offset, 0x5D + (14 if objects._frlg else 0)]:
			assert_false(objects.set_held_movement(object, action))
			objects.step_movements()
			Gen3ObjectEvents.clear_held_movement_if_finished(object)
		assert_false(object.invisible)
		assert_false(object.disable_jump_landing_effect)
		assert_false(object.fixed_priority)
		assert_eq(object.current, Vector2i(12, 12))
		assert_eq(object.previous, Vector2i(12, 12))


## Gate turns share temp-var bytes, static probes never turn, and only collision
## 1 blocks the arm. Stationary non-puzzle avatar probes miss all three seams.
func test_rotating_gate_collision_turns_shared_vars_once_and_preserves_static_queries() -> void:
	var objects: Gen3ObjectEvents = _field_objects(RomRegistry.EMERALD)
	objects.camera.group = 12
	objects.camera.number = 1
	var avatar: Gen3PlayerAvatar = Gen3PlayerAvatar.open(objects, Vector2i(12, 12), 4, 0)
	objects.events.var_set(0x4003, 0xA5A5)
	objects.events.var_set(0x4004, 0xBEEF)
	avatar.load_rotating_gates(true)
	assert_eq(objects.events.var_get(0x4000), 0x0201)
	assert_eq(objects.events.var_get(0x4003), 0x0200)
	assert_eq(objects.events.var_get(0x4004), 0xBEEF)
	# Gate 0, rotated east: push its south arm by walking west.
	var at := Vector2i(12, 14)
	assert_eq(avatar.collision_at(avatar.object(), at, 3, true), {"collision": 0, "requests": []})
	assert_eq(avatar.gate_orientation(0), 1)
	var result: Dictionary = avatar.collision_at(avatar.object(), at, 3)
	assert_eq(result, {"collision": 0, "requests": [{"kind": "rotate_gate", "gate": 0,
		"orientation": 1, "rotation": 2}]})
	assert_eq(objects.events.var_get(0x4000), 0x0202)
	avatar.load_rotating_gates()
	assert_eq(avatar.gate_orientation(0), 2)
	avatar.load_rotating_gates(true)
	objects.camera.grid.blocks[13 + 32 * 14] = 0x3400
	assert_eq(avatar.collision_at(avatar.object(), at, 3, true)["collision"], 8)
	assert_eq(avatar.collision_at(avatar.object(), at, 3)["collision"], 8)
	assert_eq(avatar.gate_orientation(0), 1)
	for collision: int in [2, 3]:
		objects.camera.grid.blocks[13 + 32 * 14] = 0x3000 | (collision << 10)
		avatar.load_rotating_gates(true)
		avatar.object().current = at + Vector2i(1, 0)
		assert_eq(avatar.begin_collision_movement(3)["requests"], [{"kind": "rotate_gate", "gate": 0,
			"orientation": 1, "rotation": 2}])
		assert_eq(avatar.gate_orientation(0), 2)
	objects.camera.group = 0
	assert_eq(avatar.rotating_gate_collision(3, at), {"collision": 0, "requests": []})
	assert_eq(avatar.gate_orientation(0), 2)


## ARM callback traces protect every patrol's return axis, range turns,
## blocked in-place steps, fixed facing and each pace through freeze/hold gates.
## Existing held-action tests never dispatch an autonomous movement type.
func test_autonomous_patrol_frames_match_each_cartridge_engine() -> void:
	var digests: Dictionary = {
		RomRegistry.RUBY: "0d8353eb92e0df59191440a52c955957adae918f",
		RomRegistry.SAPPHIRE: "0d8353eb92e0df59191440a52c955957adae918f",
		RomRegistry.FIRERED: "0c0a12d599b9292d1760b8c39bdedd3bbb03a230",
		RomRegistry.LEAFGREEN: "0c0a12d599b9292d1760b8c39bdedd3bbb03a230",
		RomRegistry.EMERALD: "adb004e3736ee73894a1658beb8215a51cb45cd2",
	}
	for id: StringName in digests:
		var objects: Gen3ObjectEvents = _movement_objects(id)
		var lines := PackedStringArray()
		var types: Array = range(7, 11) + range(0x19, 0x35) + range(0x40, 0x4D)
		if id == RomRegistry.EMERALD:
			types += range(0x4D, 0x51)
		for type: int in types:
			for scenario: int in 7:
				lines.append_array(_patrol_trace(objects, type, scenario))
		var output: String = "\n".join(lines) + "\n"
		assert_eq(output.sha1_text(), digests[id], str(id))


func _movement_objects(id: StringName) -> Gen3ObjectEvents:
	var field: Gen3ObjectEvents = _field_objects(id)
	var types: Array = []
	for type: int in 81:
		types.append({"ranged": false, "facing": [2, 1, 3, 4][type - 0x19] if type >= 0x19 and type <= 0x1C else 4})
	field.camera.data._world_scripts["movement_types"] = types
	return Gen3ObjectEvents.new(field.camera, field.events)


func _patrol_trace(objects: Gen3ObjectEvents, type: int, scenario: int) -> PackedStringArray:
	var object := Gen3ObjectEvents.ObjectEvent.new()
	object.active = true
	object.movement_type = type
	object.initial = Vector2i(12, 12)
	object.current = object.initial
	object.previous = Vector2i(11, 12)
	object.pixel_position = object.current * 16
	object.facing = 4
	object.movement_direction = 4
	object.current_elevation = 3
	object.previous_elevation = 3
	object.movement_range = Vector2i(2, 3)
	object.facing_locked = scenario == 2
	objects.objects[0] = object
	objects.camera.grid.set_metatile_entry(13, 12, 0x3400 if scenario == 1 else (0x1000 if scenario == 6 else 0x3000))
	var other := Gen3ObjectEvents.ObjectEvent.new()
	other.active = scenario == 5
	other.current = Vector2i(13, 12)
	other.previous = Vector2i(12, 13)
	other.current_elevation = 3
	objects.objects[1] = other
	var lines := PackedStringArray()
	for frame: int in range(1, 193):
		if scenario == 3 and frame in [9, 13]:
			object.frozen = frame == 9
		if scenario == 4:
			if frame == 85:
				objects.set_held_movement(object, 2)
			if frame == 100:
				Gen3ObjectEvents.clear_held_movement_if_finished(object)
		objects.step_movements()
		var pixels: Vector2i = object.pixel_position - Vector2i(192, 192)
		lines.append(",".join([type, scenario, frame, object.current.x, object.current.y,
			object.previous.x, object.previous.y, pixels.x, pixels.y, object.facing,
			object.movement_direction, object.previous_movement_direction, object.direction_sequence_index,
			object.movement_state, object.movement_action, int(object.single_movement_active),
			int(object.held_movement_active), int(object.held_movement_finished), int(object.frozen), int(object.invisible)]))
	return lines


## Original ARM callbacks protect random draw order, waits, weighted facings,
## trainer running reactions and freeze/hold resumption, absent from patrols.
func test_random_movement_frames_match_each_cartridge_engine() -> void:
	var digests: Dictionary = {
		RomRegistry.RUBY: "245271b5078f4456c2f52553262e3996241f6c2b",
		RomRegistry.SAPPHIRE: "245271b5078f4456c2f52553262e3996241f6c2b",
		RomRegistry.FIRERED: "f2e2f783da403b37d47183b08f0c6935d8a8e6b1",
		RomRegistry.LEAFGREEN: "f2e2f783da403b37d47183b08f0c6935d8a8e6b1",
		RomRegistry.EMERALD: "245271b5078f4456c2f52553262e3996241f6c2b",
	}
	for id: StringName in digests:
		var objects: Gen3ObjectEvents = _movement_objects(id)
		var lines := PackedStringArray()
		for type: int in range(1, 7) + range(0xD, 0x19):
			for scenario: int in 9:
				lines.append_array(_random_trace(objects, type, scenario))
		var output: String = "\n".join(lines) + "\n"
		assert_eq(output.sha1_text(), digests[id], str(id))


func _random_trace(objects: Gen3ObjectEvents, type: int, scenario: int) -> PackedStringArray:
	var object := Gen3ObjectEvents.ObjectEvent.new()
	object.active = true
	object.local_id = 1
	object.movement_type = type
	object.initial = Vector2i(12, 12)
	object.current = object.initial
	object.previous = Vector2i(11, 12)
	object.pixel_position = object.current * 16
	object.facing = 4
	object.movement_direction = 4
	object.current_elevation = 3
	object.previous_elevation = 3
	object.movement_range = Vector2i(2, 3)
	object.facing_locked = scenario == 2
	object.trainer_type = 1 if scenario == 5 else 3 if scenario == 6 else 2 if scenario == 7 else 0
	object.trainer_range = 4
	objects.objects[0] = object
	objects.random_seed = 0x1234 + scenario
	objects.camera.grid.set_metatile_entry(13, 12, 0x3400 if scenario == 1 else 0x3000)
	var player := Gen3ObjectEvents.ObjectEvent.new()
	player.active = true
	player.local_id = Gen3ObjectEvents.LOCALID_PLAYER
	player.current_elevation = 15
	player.previous_elevation = 15
	player.current = Vector2i(25, 25)
	player.previous = player.current
	objects.objects[1] = player
	var lines := PackedStringArray()
	for frame: int in range(1, 1537 if scenario >= 5 else 513):
		if scenario == 3 and frame in [9, 25]:
			object.frozen = frame == 9
		if scenario == 4:
			if frame == 85:
				objects.set_held_movement(object, 2)
			if frame == 100:
				Gen3ObjectEvents.clear_held_movement_if_finished(object)
		if scenario >= 5:
			player.current = Vector2i(12 + ((frame / 16) % 9) - 4, 12 + ((frame / 144) % 9) - 4)
			player.previous = player.current
		objects.step_movements(scenario >= 5 and frame % 13 != 0)
		var pixels: Vector2i = object.pixel_position - Vector2i(192, 192)
		var waiting: bool = object.movement_state == (2 if type >= 0x17 else 3)
		lines.append(",".join([type, scenario, frame, object.current.x, object.current.y,
			object.previous.x, object.previous.y, pixels.x, pixels.y, object.facing,
			object.movement_direction, object.previous_movement_direction, object.movement_state,
			object.movement_action, int(object.single_movement_active), int(object.held_movement_active),
			int(object.held_movement_finished), int(object.frozen), object.movement_delay if waiting else 0,
			objects.random_seed]))
	return lines


## Copy callbacks must latch entry facing, gate tile centers and check landing
## cells before grass-limited movement. Held-action and random traces miss this.
func test_copy_player_frames_match_each_cartridge_engine() -> void:
	var digests: Dictionary = {
		RomRegistry.RUBY: "8df6e03ba616d1b74a732e16cd7155476d314ad4", RomRegistry.SAPPHIRE: "8df6e03ba616d1b74a732e16cd7155476d314ad4",
		RomRegistry.FIRERED: "fb9e2094d414d336ff9c23bf254c9faf60dfb513", RomRegistry.LEAFGREEN: "fb9e2094d414d336ff9c23bf254c9faf60dfb513", RomRegistry.EMERALD: "8df6e03ba616d1b74a732e16cd7155476d314ad4",
	}
	for id: StringName in digests:
		var objects: Gen3ObjectEvents = _copy_objects(id)
		var lines := PackedStringArray()
		for type: int in range(0x35, 0x39) + range(0x3B, 0x3F):
			for initial: int in range(1, 5):
				for direction: int in range(1, 5):
					if initial != 2 or direction != 4:
						lines.append_array(_copy_trace(objects, type, initial, direction, 1, 0))
			for copy: int in 11:
				for scenario: int in 9:
					lines.append_array(_copy_trace(objects, type, 2, 4, copy, scenario))
		var output: String = "\n".join(lines) + "\n"
		assert_eq(output.sha1_text(), digests[id], str(id))


func _copy_objects(id: StringName) -> Gen3ObjectEvents:
	var field: Gen3ObjectEvents = _movement_objects(id)
	for type: int in range(0x35, 0x39) + range(0x3B, 0x3F):
		field.camera.data._world_scripts["movement_types"][type]["facing"] = [2, 1, 3, 4][(type - 0x35 if type < 0x3B else type - 0x3B)]
	return Gen3ObjectEvents.new(field.camera, field.events)


func _copy_trace(objects: Gen3ObjectEvents, type: int, initial: int, direction: int, copy: int, scenario: int) -> PackedStringArray:
	var object := Gen3ObjectEvents.ObjectEvent.new()
	object.active = true
	object.local_id = 1
	object.movement_type = type
	object.initial = Vector2i(12, 12)
	object.current = object.initial
	object.previous = Vector2i(11, 12)
	object.pixel_position = object.current * 16
	object.facing = 4
	object.movement_direction = 4
	object.current_elevation = 3
	object.previous_elevation = 3
	object.movement_range = Vector2i(2, 3)
	object.facing_locked = scenario == 5
	object.current_behavior = [2, 2, 3, 0xD1, 0, 2, 2, 2, 2][scenario]
	objects.objects[0] = object
	objects.camera.grid.blocks.fill(0x3000 | object.current_behavior)
	objects.camera.grid.set_metatile_entry(13, 12, (0x3400 if scenario == 1 else 0x3000) | object.current_behavior)
	var player := Gen3ObjectEvents.ObjectEvent.new()
	player.active = true
	player.local_id = Gen3ObjectEvents.LOCALID_PLAYER
	player.current_elevation = 15
	player.previous_elevation = 15
	player.facing = initial
	player.movement_direction = direction
	player.player_copyable_movement = copy
	player.movement_action = -1 if scenario == 6 else 0
	player.current = Vector2i(25, 25)
	player.previous = player.current
	objects.objects[1] = player
	var lines := PackedStringArray()
	for frame: int in range(1, 35):
		if scenario == 8:
			if frame == 2:
				player.facing = initial % 4 + 1
			if frame in [9, 13]:
				object.frozen = frame == 9
			if frame == 17:
				objects.set_held_movement(object, 2)
			if frame == 22:
				Gen3ObjectEvents.clear_held_movement_if_finished(object)
		objects.step_movements(false, scenario == 7)
		var pixels: Vector2i = object.pixel_position - Vector2i(192, 192)
		lines.append(",".join([type, initial, direction, copy, scenario, frame, object.current.x, object.current.y,
			object.previous.x, object.previous.y, pixels.x, pixels.y, object.jump_y, object.facing,
			object.movement_direction, object.previous_movement_direction, object.direction_sequence_index,
			object.movement_state, object.movement_action, int(object.single_movement_active),
			int(object.held_movement_active), int(object.held_movement_finished), int(object.frozen), int(object.invisible)]))
	return lines


## Mew's rock avoidance and step-counter choices cannot be inferred from the
## normal direction-copy traces, which never enter Faraway Island.
func test_mew_copy_callback_matches_original_escape_decisions() -> void:
	var objects: Gen3ObjectEvents = _copy_objects(RomRegistry.EMERALD)
	objects.camera.group = 26
	objects.camera.number = 57
	objects.camera.grid._flags = {1: true, 2: true, 3: true, 4: true}
	var lines := PackedStringArray()
	for at: Vector2i in [Vector2i(20, 15), Vector2i(22, 17), Vector2i(24, 15), Vector2i(26, 17),
			Vector2i(15, 16), Vector2i(17, 18), Vector2i(19, 19), Vector2i(21, 21)]:
		for dx: int in range(-2, 3):
			for dy: int in range(-2, 3):
				for direction: int in 5:
					for mask: int in 16:
						for steps: int in [0, 1, 8, 9, 65535]:
							lines.append(_mew_trace(objects, at, Vector2i(dx, dy), direction, mask, steps))
	var output: String = "\n".join(lines) + "\n"
	assert_eq(output.sha1_text(), "0139e3695fc37632d1b5fdfef77423fc2f3c99a0")


func _mew_trace(objects: Gen3ObjectEvents, at: Vector2i, delta: Vector2i, direction: int, mask: int, steps: int) -> String:
	var mew := Gen3ObjectEvents.ObjectEvent.new()
	mew.active = true
	mew.local_id = 1
	mew.map_number = 57
	mew.map_group = 26
	mew.graphics_id = 229
	mew.movement_type = 0x3C
	mew.current = at
	mew.previous = at
	mew.pixel_position = at * 16
	mew.facing = 4
	mew.movement_direction = 4
	mew.current_elevation = 3
	mew.previous_elevation = 3
	mew.invisible = true
	objects.objects[0] = mew
	objects.camera.grid.blocks.fill(0x3000)
	for side: int in range(1, 5):
		var cell: Vector2i = at + Gen3FieldCamera.DIRECTIONS[side]
		objects.camera.grid.set_metatile_entry(cell.x, cell.y, 0x3002 if mask & (1 << (side - 1)) else 0x3000)
	var player := Gen3ObjectEvents.ObjectEvent.new()
	player.active = true
	player.local_id = Gen3ObjectEvents.LOCALID_PLAYER
	player.facing = 2
	player.movement_direction = maxi(direction, 1)
	player.player_copyable_movement = 2
	player.movement_action = 0
	player.current_elevation = 15
	player.previous_elevation = 15
	player.previous = at + delta
	player.current = player.previous + Gen3FieldCamera.DIRECTIONS[direction]
	objects.objects[1] = player
	objects.events.var_set(0x403A, steps)
	objects.step_movements()
	var pixels: Vector2i = mew.pixel_position - at * 16
	return ",".join([at.x, at.y, delta.x, delta.y, direction, mask, steps, mew.current.x, mew.current.y,
		mew.previous.x, mew.previous.y, pixels.x, pixels.y, mew.jump_y, mew.facing,
		mew.movement_direction, mew.previous_movement_direction, mew.direction_sequence_index,
		mew.movement_state, mew.movement_action, int(mew.single_movement_active),
		int(mew.held_movement_active), int(mew.held_movement_finished), int(mew.frozen), int(mew.invisible)])


## A missing entry facing yields DIR_NONE; native collision reads outside its
## callback table. Rejecting it centrally keeps copy actions on the same tile.
func test_copy_player_without_entry_direction_refuses_translation() -> void:
	var objects: Gen3ObjectEvents = _copy_objects(RomRegistry.EMERALD)
	_copy_trace(objects, 0x35, 0, 4, 2, 0)
	assert_eq(objects.objects[0].current, Vector2i(12, 12))
	assert_eq(objects.objects[0].previous, Vector2i(12, 12))


## An action already selected finishes without reading the player again.
## Returning early on a missing player stalls it; the frame sweeps retain one.
func test_copy_player_selected_action_finishes_after_player_removal() -> void:
	var objects: Gen3ObjectEvents = _copy_objects(RomRegistry.EMERALD)
	_copy_trace(objects, 0x35, 2, 1, 2, 0)
	objects.objects[1].active = false
	for frame: int in 14:
		objects.step_movements()
	assert_eq(objects.objects[0].previous, objects.objects[0].current)
	assert_eq(objects.objects[0].movement_state, 1)
	assert_false(objects.objects[0].single_movement_active)


## Disguise callbacks spawn before the freeze/hold gate, once per object.
## Moving initialization into autonomous dispatch hides frozen and scripted
## trainers; existing patrol traces never use either disguise movement type.
func test_disguises_spawn_once_even_when_frozen_or_held() -> void:
	for id: StringName in [RomRegistry.RUBY, RomRegistry.SAPPHIRE, RomRegistry.FIRERED,
			RomRegistry.LEAFGREEN, RomRegistry.EMERALD]:
		for type: int in [0x39, 0x3A]:
			for held: bool in [false, true]:
				var objects: Gen3ObjectEvents = _movement_objects(id)
				var template: Dictionary = Gen3ObjectEvents.EMPTY_TEMPLATE.duplicate()
				template.merge({"local_id": 42, "movement_type": type, "x": 5, "y": 5}, true)
				var object: Gen3ObjectEvents.ObjectEvent = objects.objects[objects.spawn(template, 7, 9)]
				object.frozen = true
				if held:
					assert_false(objects.set_held_movement(object, 0))
				var effects: Array = objects.step_movements().filter(
					func(request: Dictionary) -> bool: return request["kind"] == "field_effect")
				assert_eq(effects, [{"kind": "field_effect", "effect_id": type - 0x1D,
					"object_id": 0, "local_id": 42, "map_number": 7, "map_group": 9}])
				assert_eq(object.direction_sequence_index, 1)
				assert_eq(objects.step_movements(), [])
				assert_eq(object.current, Vector2i(12, 12))


## Original ARM reveal/effect/animation callbacks across forty frames catch
## early completion, reordered END handling and effects frozen by held actions.
func test_disguise_reveal_frames_match_each_cartridge_engine() -> void:
	for id: StringName in [RomRegistry.RUBY, RomRegistry.SAPPHIRE, RomRegistry.FIRERED,
			RomRegistry.LEAFGREEN, RomRegistry.EMERALD]:
		var lines := PackedStringArray()
		for type: int in [0x39, 0x3A]:
			var objects: Gen3ObjectEvents = _movement_objects(id)
			var object := Gen3ObjectEvents.ObjectEvent.new()
			object.active = true
			object.movement_type = type
			objects.objects[0] = object
			objects.step_movements()
			assert_false(objects.set_held_movement(object, 0x67 if objects._frlg else 0x59))
			for frame: int in range(1, 41):
				objects.step_movements()
				lines.append(",".join([type, frame, object.direction_sequence_index,
					object.disguise_state, int(object.disguise_ready),
					int(object.held_movement_finished), int(object.disguise_spawned)]))
			Gen3ObjectEvents.clear_held_movement_if_finished(object)
			assert_eq(objects.step_movements(), [])
			assert_false(objects.set_held_movement(object, 0x67 if objects._frlg else 0x59))
			assert_eq(objects.step_movements(), [])
			assert_true(object.held_movement_finished)
		assert_eq(("\n".join(lines) + "\n").sha1_text(), "848252bdb8c21ea508b4818c45b2def911583d3e", str(id))


## A removed trainer's pool slot can be reused before the next sprite callback.
## Dropping effects with the slot leaks the old disguise; frame-only traces
## never remove or replace the linked object.
func test_removed_disguise_stops_before_reused_slot_spawns_its_effect() -> void:
	for outside: bool in [false, true]:
		var objects: Gen3ObjectEvents = _movement_objects(RomRegistry.EMERALD)
		var template: Dictionary = Gen3ObjectEvents.EMPTY_TEMPLATE.duplicate()
		template.merge({"local_id": 42, "movement_type": 0x39}, true)
		objects.spawn(template, 7, 9)
		objects.step_movements()
		if outside:
			objects.camera.pos = Vector2i(100, 100)
			objects.remove_outside_view()
		else:
			objects.remove(42, 7, 9)
		template["local_id"] = 43
		template["movement_type"] = 0x3A
		assert_eq(objects.spawn(template, 7, 9), 0)
		var effects: Array = objects.step_movements().filter(
			func(request: Dictionary) -> bool: return request.has("effect_id"))
		assert_eq(effects, [
			{"kind": "stop_field_effect", "effect_id": 28, "object_id": 0, "local_id": 42, "map_number": 7, "map_group": 9},
			{"kind": "field_effect", "effect_id": 29, "object_id": 0, "local_id": 43, "map_number": 7, "map_group": 9},
		])
		assert_eq(objects.step_movements(), [])


## Reveal is an immediate no-op for ordinary trainers regardless of patrol state.
func test_reveal_dispatch_does_not_read_patrol_state_as_disguise_state() -> void:
	for id: StringName in [RomRegistry.RUBY, RomRegistry.FIRERED, RomRegistry.EMERALD]:
		var objects: Gen3ObjectEvents = _movement_objects(id)
		var object := Gen3ObjectEvents.ObjectEvent.new()
		object.active = true
		object.direction_sequence_index = 35
		objects.objects[0] = object
		assert_false(objects.set_held_movement(object, 0x67 if objects._frlg else 0x59))
		objects.step_movements()
		assert_true(object.held_movement_finished)


## A buried trainer's reveal hands off to `trainer_see.c`'s task: the task's
## first run on the next frame, the puff's animCmdIndex 2 on its 13th pass, the
## callback stop after END, and the facing type written to the saved template.
## The task clears the finished flag every frame, so a jump that reran past its
## sixteen frames would index outside the jump table.
func test_buried_trainer_reveal_follows_the_trainer_see_task_clock() -> void:
	for id: StringName in [RomRegistry.RUBY, RomRegistry.FIRERED, RomRegistry.EMERALD]:
		var objects: Gen3ObjectEvents = _movement_objects(id)
		var template: Dictionary = Gen3ObjectEvents.EMPTY_TEMPLATE.duplicate()
		template.merge({"local_id": 42, "movement_type": 0x3F, "x": 5, "y": 5}, true)
		objects.templates = [template.duplicate()]
		var object: Gen3ObjectEvents.ObjectEvent = objects.objects[objects.spawn(template, objects.camera.number, objects.camera.group)]
		var player := Gen3ObjectEvents.ObjectEvent.new()
		player.active = true
		player.current = object.current + Vector2i(-3, 1)
		objects.objects[1] = player
		var see := Gen3TrainerSee.new(objects, null)
		objects.step_movements()
		assert_true(object.fixed_priority, str(id))
		assert_false(object.held_movement_active)
		assert_false(objects.set_held_movement(object, 0x67 if objects._frlg else 0x59))
		var puffs: Array = []
		for frame: int in range(1, 36):
			for request: Dictionary in see.run_tasks() + objects.step_movements():
				if request.get("effect_id", -1) == Gen3ObjectEvents.ASH_PUFF:
					puffs.append([frame, request["kind"], request.get("at", object.current)])
			if frame == 1:
				assert_false(object.held_movement_finished, str(id))
			if frame == 2:
				assert_eq(object.facing, Gen3ObjectEvents.Direction.WEST)
			if frame in [15, 16]:
				assert_eq(object.fixed_priority, frame == 15, "%s frame %d" % [id, frame])
				assert_eq(object.jump_y, 0 if frame == 15 else -4)
			if frame == 31:
				assert_true(object.held_movement_finished)
				assert_eq(object.jump_y, 0)
			if frame == 34:
				assert_eq(object.movement_type, 0x3F)
		assert_eq(puffs, [[3, "field_effect", object.current], [34, "stop_field_effect", object.current]], str(id))
		assert_eq(object.movement_type, 9, str(id))
		assert_eq(int(objects.templates[0]["movement_type"]), 9)
		assert_true(object.held_movement_finished)
		assert_eq(object.current, object.previous)


## A seen trainer's approach follows `trainer_see.c`'s task clock: the icon's
## 60 frames and the callback pass after its END, one normal-pace walk per
## cell short of the player, then the saved template keeps the trainer's new
## facing and cell. Hoenn turns the player to the trainer; FRLG's turn is
## commented out. Script waits and battle setup never see these frames.
func test_trainer_approach_follows_the_trainer_see_task_clock() -> void:
	for id: StringName in [RomRegistry.RUBY, RomRegistry.FIRERED, RomRegistry.EMERALD]:
		var see: Gen3TrainerSee = _trainer_see(id, [[1, 5, 0, 1]])
		var trainer: Gen3ObjectEvents.ObjectEvent = see.objects.objects[1]
		assert_true(see.check_trainers(), str(id))
		assert_eq(see.approaching[0]["radius"], 4)
		var marks: Array = _approach_marks(see, 120)
		assert_eq(marks, [[1, "field_effect", 0], [62, "stop_field_effect", 0], [114, "script_enable", -1]], str(id))
		assert_eq(trainer.current, Vector2i(11, 12))
		assert_eq(trainer.movement_type, 10)
		assert_eq([see.objects.templates[0]["x"], see.objects.templates[0]["y"],
			see.objects.templates[0]["movement_type"]], [4, 5, 10])
		assert_eq(see.avatar.object().facing, 4 if id == RomRegistry.FIRERED else 3, str(id))


## Path checks differ by engine: Emerald starts past the trainer and ignores
## only its out-of-range bit, FRLG also tests the trainer's own cell, and
## Ruby's mask (pret's BUGFIX_TRAINERAPPROACH off) blocks on that bit alone.
## A beaten trainer's flag comes from its `trainerbattle` id.
func test_trainer_sight_keeps_each_engines_path_check() -> void:
	var cases: Dictionary = {"wall": [false, false, true], "own cell": [true, false, true],
		"out of range": [true, true, false], "beaten": [false, false, false]}
	var ids: Array = [RomRegistry.EMERALD, RomRegistry.FIRERED, RomRegistry.RUBY]
	for case: String in cases:
		for index: int in ids.size():
			var see: Gen3TrainerSee = _trainer_see(ids[index], [[1, 5, 0, 1]])
			match case:
				"wall":
					see.objects.camera.grid.set_impassable(10, 12, true)
				"own cell":
					see.objects.camera.grid.set_impassable(8, 12, true)
				"out of range":
					see.objects.objects[1].movement_range = Vector2i(1, 0)
				"beaten":
					see.objects.events.flag_set(Gen3TrainerSee.TRAINER_FLAGS_START + 5)
			assert_eq(see.check_trainers(), cases[case][index], "%s %s" % [case, ids[index]])


## Emerald pairs two seeing trainers only while two Pokémon can battle, and
## its double-battle modes need them; FRLG refuses only TRAINER_BATTLE_DOUBLE
## and takes the first trainer. The second Emerald trainer moves alone.
func test_trainer_check_pairs_emerald_trainers_and_gates_double_battles() -> void:
	var cases: Array = [
		[RomRegistry.EMERALD, 0, true, [1, 2]], [RomRegistry.EMERALD, 0, false, [1]],
		[RomRegistry.EMERALD, 7, false, [2]], [RomRegistry.EMERALD, 7, true, [1]],
		[RomRegistry.FIRERED, 4, false, [2]], [RomRegistry.FIRERED, 7, false, [1]],
		[RomRegistry.RUBY, 4, false, [1]],
	]
	for row: Array in cases:
		var see: Gen3TrainerSee = _trainer_see(row[0], [[1, 5, row[1], 1], [5, 1, 0, 3]])
		assert_true(see.check_trainers(row[2]), str(row))
		assert_eq(see.approaching.map(func(trainer: Dictionary) -> int: return trainer["slot"]), row[3], str(row))
	var pair: Gen3TrainerSee = _trainer_see(RomRegistry.EMERALD, [[1, 5, 0, 1], [5, 1, 0, 3]])
	pair.check_trainers()
	assert_true(pair.prepare_second_trainer())
	assert_eq(pair.approaching_id, 1)
	assert_true(pair.objects.objects[1].frozen)
	assert_false(pair.objects.objects[2].frozen)
	assert_false(pair.prepare_second_trainer())
	assert_eq(pair.approaching_id, 0)


## FRLG scrolls the camera to a trainer more than three cells above: an
## invisible object walks up the remaining cells at fast pace, the icon plays
## there, it walks back and is removed, then the trainer walks without the
## turn the other path gives it. A full object pool hides such a trainer.
func test_firered_trainer_above_the_view_scrolls_the_camera_object() -> void:
	var see: Gen3TrainerSee = _trainer_see(RomRegistry.FIRERED, [[5, 0, 0, 1]])
	see.objects.camera.pos = Vector2i(5, 5)
	var trainer: Gen3ObjectEvents.ObjectEvent = see.objects.objects[1]
	trainer.facing = Gen3ObjectEvents.Direction.SOUTH
	for slot: int in range(2, Gen3ObjectEvents.COUNT):
		see.objects.objects[slot].active = true
	assert_false(see.check_trainers())
	for slot: int in range(2, Gen3ObjectEvents.COUNT):
		see.objects.objects[slot].active = false
	assert_true(see.check_trainers())
	var marks: Array = _approach_marks(see, 185)
	assert_eq(marks, [[1, "camera_follow", 2], [25, "field_effect", 0], [86, "stop_field_effect", 0],
		[111, "camera_follow", 0], [179, "script_enable", -1]])
	assert_null(see.objects.by_identity(Gen3TrainerSee.LOCALID_CAMERA, 0, 0))
	assert_eq(trainer.current, Vector2i(12, 11))
	assert_eq(see.avatar.object().facing, 4)


## A stationary type re-faces from `dirn_to_anim`, which maps a diagonal to
## its south action; offsetting by the facing walked Emerald NPCs west after a
## scripted diagonal step. Corpus traces never reach a diagonal facing here.
func test_stationary_type_after_a_diagonal_walk_faces_south() -> void:
	var objects: Gen3ObjectEvents = _movement_objects(RomRegistry.EMERALD)
	var template: Dictionary = Gen3ObjectEvents.EMPTY_TEMPLATE.duplicate()
	template.merge({"local_id": 3, "movement_type": 8, "x": 5, "y": 5}, true)
	var object: Gen3ObjectEvents.ObjectEvent = objects.objects[objects.spawn(template, 0, 0)]
	objects.step_movements()
	assert_false(objects.set_held_movement(object, 0x8C))
	for frame: int in 20:
		objects.step_movements()
	assert_eq(object.facing, 7)
	var landed: Vector2i = object.current
	Gen3ObjectEvents.clear_held_movement_if_finished(object)
	for frame: int in 40:
		objects.step_movements()
	assert_eq(object.facing, Gen3ObjectEvents.Direction.SOUTH)
	assert_eq(object.current, landed)


## Emerald's `sAnim_GoSouth` cells are images 3, 0, 4, 0. Graphics 0's anims are in
## `sStepAnimTables`, so each step leads with the other foot and a face seeks the
## standing cell; graphics 1's are not, so a step resumes the running cell. A slow
## in-place walk adds a delay frame on odd counts and ends one cell on, not three.
func test_walk_step_anims_alternate_feet_only_on_listed_tables() -> void:
	var objects: Gen3ObjectEvents = _movement_objects(RomRegistry.EMERALD)
	_standard_anims(objects.camera.data)
	var movers: Array[Gen3ObjectEvents.ObjectEvent] = []
	for graphics: int in 2:
		var template: Dictionary = Gen3ObjectEvents.EMPTY_TEMPLATE.duplicate()
		template.merge({"local_id": graphics + 1, "graphics_id": graphics, "x": 5 + graphics * 4, "y": 5}, true)
		movers.append(objects.objects[objects.spawn(template, 0, 0)])
	var images: Array = [[], []]
	for step: int in 3:
		_hold_until_finished(objects, movers, 0x08, images)
	assert_eq(images, [[3, 4, 3], [3, 0, 4]])
	_hold_until_finished(objects, movers, 0x02, [[], []])
	assert_eq([movers[0].anim.anim_num, movers[0].anim.image, movers[1].anim.anim_num], [6, 2, 6])
	_hold_until_finished(objects, movers, 0x19, [[], []])
	assert_eq(movers[0].anim.cmd_index, 3)


func _hold_until_finished(objects: Gen3ObjectEvents, movers: Array[Gen3ObjectEvents.ObjectEvent],
		action: int, first_images: Array) -> void:
	for mover: Gen3ObjectEvents.ObjectEvent in movers:
		Gen3ObjectEvents.clear_held_movement(mover)
		objects.set_held_movement(mover, action)
	objects.step_movements()
	for index: int in movers.size():
		first_images[index].append(movers[index].anim.image)
	while not movers.all(func(mover: Gen3ObjectEvents.ObjectEvent) -> bool: return mover.held_movement_finished):
		objects.step_movements()


## pret's `sAnimTable_Standard` face and go rows; only the first table is listed.
static func _standard_anims(data: GameData) -> void:
	var anims: Array = []
	for cells: Array in [[0], [1], [2], [2 | 1 << 6], [3, 0, 4, 0], [5, 1, 6, 1], [7, 2, 8, 2],
			[7 | 1 << 6, 2 | 1 << 6, 8 | 1 << 6, 2 | 1 << 6]]:
		var duration: int = 16 if cells.size() == 1 else 8
		anims.append(cells.map(func(cell: int) -> int:
			return (cell & 0x3F) | duration << 16 | (cell >> 6) << 22) + [Gen3SpriteAnim.JUMP])
	data._world_scripts["object_graphics"] = [{"inanimate": false, "anims": 0}, {"inanimate": false, "anims": 1}]
	data._world_scripts["sprite_anims"] = {"0": anims, "1": anims}
	data._world_scripts["step_anims"] = {"0": [1, 3, 0, 2]}


## Trainers by [layout x, layout y, trainerbattle mode, trainer type]; the
## player stands at backup (12, 12) facing east and each trainer faces east.
func _trainer_see(id: StringName, trainers: Array) -> Gen3TrainerSee:
	var objects: Gen3ObjectEvents = _movement_objects(id)
	var avatar: Gen3PlayerAvatar = Gen3PlayerAvatar.open(objects, Vector2i(12, 12), 4, 0)
	var instructions: Dictionary = {}
	objects.camera.data._world_scripts["instructions"] = instructions
	for index: int in trainers.size():
		var row: Array = trainers[index]
		var script: int = 0x1000 + index * 8
		instructions[str(script)] = {"bytes": [0x5C, row[2], 5 + index, 0], "next_offset": script + 4}
		var template: Dictionary = Gen3ObjectEvents.EMPTY_TEMPLATE.duplicate()
		template.merge({"local_id": index + 1, "x": row[0], "y": row[1], "trainer_type": row[3],
			"trainer_sight_or_berry_tree_id": 5, "script_offset": script}, true)
		objects.templates.append(template)
		objects.spawn(template, 0, 0)
	return Gen3TrainerSee.new(objects, avatar)


## `[frame, kind, object or effect id]` for each camera, icon and script request.
func _approach_marks(see: Gen3TrainerSee, frames: int) -> Array:
	var marks: Array = []
	var requests: Array = see.start_approach()
	for frame: int in range(1, frames):
		requests.append_array(see.run_tasks())
		requests.append_array(see.objects.step_movements())
		for request: Dictionary in requests:
			if request["kind"] in ["camera_follow", "field_effect", "stop_field_effect", "script_enable"]:
				marks.append([frame, request["kind"], request.get("effect_id", request.get("object_id", -1))])
		requests.clear()
	return marks


## ARM movement and sprite clocks pin stage polling, both sparkle halves,
## natural withering versus picking, and initialization before a freeze gate.
func test_berry_field_frames_match_the_original_callbacks() -> void:
	for id: StringName in [RomRegistry.RUBY, RomRegistry.SAPPHIRE, RomRegistry.EMERALD]:
		var lines := PackedStringArray()
		for stage: int in 6:
			for scenario: int in 6:
				lines.append_array(_berry_field_trace(id, stage, scenario))
		assert_eq(("\n".join(lines) + "\n").sha1_text(), "fcf2d33034088159c3ae0321528d786399d0aa7b", str(id))


func _berry_field_trace(id: StringName, stage: int, scenario: int) -> PackedStringArray:
	var objects: Gen3ObjectEvents = _movement_objects(id)
	objects.camera.data._world_scripts["berries"] = [{"stage_minutes": 180, "min_yield": 2,
		"max_yield": 3, "berry_graphics": [61, 61, 62, 62, 62], "berry_palettes": [3, 4, 4, 4, 4]}]
	_berry_tree_anims(objects.camera.data)
	objects.events.berries.plant(0, 1, stage)
	var object := Gen3ObjectEvents.ObjectEvent.new()
	object.active = true
	object.graphics_id = 61
	object.movement_type = 12
	object.current = Vector2i(12, 12)
	object.previous = object.current
	objects.objects[0] = object
	var lines := PackedStringArray()
	for frame: int in range(1, 401):
		if frame == 81:
			if scenario in [0, 3]:
				objects.events.berries.plant(0, 1, stage % 5 + 1)
			elif scenario in [1, 2]:
				objects.events.berries.remove(0)
				if scenario == 2:
					objects.mark_berry_tree_picked(object.local_id, object.map_number, object.map_group)
		if scenario == 3 and frame in [41, 91]:
			if frame == 41:
				objects.freeze_except_player()
			else:
				objects.unfreeze_all()
		if scenario == 4 and frame == 41:
			objects.set_held_movement(object, 0x14)
		if scenario == 4 and frame == 61:
			Gen3ObjectEvents.clear_held_movement_if_finished(object)
		var effects: Array = objects.step_movements().filter(
			func(request: Dictionary) -> bool: return request["kind"] == "field_effect")
		lines.append(",".join([stage, scenario, frame, object.graphics_id, int(object.invisible),
			int(object.single_movement_active), object.movement_action & 255, object.movement_state,
			1 + int(object.berry_sparkling) * 2 + int(object.berry_just_picked) * 4,
			object.anim.anim_num, object.palette_num, -1 if effects.is_empty() else int(effects[-1]["effect_id"])]))
	return lines


## pret's `sAnimTable_BerryTree` behind both tree graphics: one 32-frame cell, two
## 32s, two 48s, four 32s and four 48s, each closed by `ANIMCMD_END`.
static func _berry_tree_anims(data: GameData) -> void:
	var stages: Array = []
	for cells: Array in [[[0, 32]], [[1, 32], [2, 32]], [[3, 48], [4, 48]],
			[[5, 32], [5, 32], [6, 32], [6, 32]], [[7, 48], [7, 48], [8, 48], [8, 48]]]:
		stages.append(cells.map(func(cell: Array) -> int: return cell[0] | cell[1] << 16) + [Gen3SpriteAnim.END])
	var rows: Array = []
	for index: int in 63:
		rows.append({"inanimate": false, "anims": 0 if index >= 61 else 1})
	data._world_scripts["object_graphics"] = rows
	data._world_scripts["sprite_anims"] = {"0": stages, "1": []}


## Original ARM saves and RNG state cover every watering mask, the tenth
## regrowth, batched expiry and unseen trees; the field trace never ticks time.
func test_berry_growth_records_match_the_original_engine() -> void:
	var objects: Gen3ObjectEvents = _movement_objects(RomRegistry.EMERALD)
	var rows: Array = []
	for berry: int in 43:
		rows.append({"stage_minutes": 180, "min_yield": 2, "max_yield": 3})
	rows[20] = {"stage_minutes": 180, "min_yield": 2, "max_yield": 6}
	rows[30] = {"stage_minutes": 1080, "min_yield": 1, "max_yield": 2}
	objects.camera.data._world_scripts["berries"] = rows
	var lines := PackedStringArray()
	for berry: int in [1, 21, 31]:
		lines.append_array(_berry_growth_trace(objects.camera.data, berry))
	assert_eq(("\n".join(lines) + "\n").sha1_text(), "6ccde374b62b2c6caf374d3000063a256fe1c8f2")


func _berry_growth_trace(data: GameData, berry: int) -> PackedStringArray:
	var lines := PackedStringArray()
	for scenario: int in 18:
		var trees := Gen3BerryTrees.new(data)
		trees.plant(0, berry, 5 if scenario == 16 else 1, scenario != 17)
		trees.random_seed = 0x12345678
		var duration: int = int(trees.record(0)["minutes"]) / (4 if scenario == 16 else 1)
		for turn: int in 101:
			var stage: int = int(trees.record(0)["stage"])
			if scenario < 16 and stage >= 1 and stage <= 4 and scenario & (1 << (stage - 1)):
				trees.water(0)
			var minutes: int = duration if scenario < 16 else int([0, 1, duration - 1, duration,
				duration + 1, duration * 4, duration * 70, duration * 71, -1][turn % 9])
			trees.advance_minutes(minutes)
			var values: Array = [berry, scenario, turn]
			values.append_array(Array(trees._records.slice(0, 6)))
			values.append(trees.random_seed)
			lines.append(",".join(values))
	return lines


## Byte stage tables need no word alignment. The world must refuse a bad
## table before caching it; existing graphics cases cover metatiles instead.
func test_berry_tables_keep_byte_aligned_rows_and_refuse_bad_spans() -> void:
	var bytes: PackedByteArray = _dump()
	bytes.resize(0x1400)
	var layout: Dictionary = LAYOUT.duplicate()
	layout.merge({"berry_graphics": 0x1000, "berry_palettes": 0x1100})
	for berry: int in 44:
		bytes.encode_u32(0x1000 + berry * 4, 0x08001201)
		bytes.encode_u32(0x1100 + berry * 4, 0x08001206)
	for value: int in 10:
		bytes[0x1201 + value] = value
	var world: Dictionary = Gen3World.read(RomFile.from_bytes(bytes, RomRegistry.EMERALD), layout)
	assert_false(world.is_empty())
	var data := GameData.new()
	data.generation = RomRegistry.GEN3
	data._sections = {"scripts": true}
	data._world_scripts = world["scripts"]
	var row: Dictionary = data.world_berry(43)
	assert_eq(row, {"stage_minutes": 180, "min_yield": 2, "max_yield": 3,
		"berry_graphics": [0, 1, 2, 3, 4], "berry_palettes": [5, 6, 7, 8, 9]})
	row["berry_graphics"][0] = 99
	assert_eq(data.world_berry(43)["berry_graphics"][0], 0)
	assert_eq(data.world_berry(0), {})
	assert_eq(data.world_berry(44), {"berry_graphics": [0, 1, 2, 3, 4], "berry_palettes": [5, 6, 7, 8, 9]})
	assert_eq(data.world_berry(45), {})
	bytes.encode_u32(0x1100 + 42 * 4, 0x080013FC)
	assert_eq(Gen3World.read(RomFile.from_bytes(bytes, RomRegistry.EMERALD), layout), {})


func test_only_seen_berry_trees_resume_their_saved_growth() -> void:
	var objects: Gen3ObjectEvents = _movement_objects(RomRegistry.EMERALD)
	objects.camera.data._world_scripts["berries"] = [{"stage_minutes": 180, "min_yield": 2, "max_yield": 3}]
	objects.camera.pos = Vector2i(10, 10)
	var positions: Array[Vector2i] = [Vector2i(10, 13), Vector2i(24, 21), Vector2i(9, 13),
		Vector2i(25, 21), Vector2i(10, 12), Vector2i(24, 22), Vector2i(10, 13)]
	for index: int in positions.size():
		var object: Gen3ObjectEvents.ObjectEvent = objects.objects[index]
		object.active = true
		object.movement_type = 12 if index < 6 else 7
		object.current = positions[index]
		object.trainer_range = index
		objects.events.berries.plant(index, 1, 1, false)
	objects.allow_seen_berry_growth()
	objects.events.berries.advance_minutes(180)
	for index: int in positions.size():
		assert_eq(objects.events.berries.record(index)["stage"], 2 if index < 2 else 1)
	objects.events.clear_temp()
	var next_map := Gen3ObjectEvents.new(objects.camera, objects.events)
	assert_same(next_map.events.berries, objects.events.berries)
	assert_eq(next_map.events.berries.record(0)["stage"], 2)


## The original ARM lookup admits ID 44, but larger IDs and zero use CHERI.
## Clamping to the growth-table count changes the reserved row's palette.
func test_berry_graphics_keep_the_cartridge_overread_boundary() -> void:
	for id: StringName in [RomRegistry.RUBY, RomRegistry.SAPPHIRE, RomRegistry.EMERALD]:
		var objects: Gen3ObjectEvents = _movement_objects(id)
		var row: Dictionary = {"stage_minutes": 180, "min_yield": 2, "max_yield": 3,
			"berry_graphics": [61, 61, 62, 62, 62], "berry_palettes": [3, 4, 4, 4, 4]}
		var rows: Array = []
		for berry: int in 43:
			rows.append(row)
		rows.append({"berry_graphics": [61, 61, 62, 62, 62], "berry_palettes": [61, 61, 62, 62, 62]})
		objects.camera.data._world_scripts["berries"] = rows
		for berry: int in [0, 43, 44, 45, 255]:
			for stage: int in range(1, 6):
				objects.events.berries.plant(0, berry, stage)
				var object := Gen3ObjectEvents.ObjectEvent.new()
				object.active = true
				object.movement_type = 12
				objects.objects[0] = object
				objects.step_movements()
				assert_eq(object.graphics_id, 61 if stage < 3 else 62)
				assert_eq(object.palette_num, int(([13, 13, 14, 14, 14] if berry == 44 else [3, 4, 4, 4, 4])[stage - 1]))
