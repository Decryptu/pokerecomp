extends GutTest

## Protect GBA pointer bounds, three header formats and repeated encounter sets.
## GB world tests cannot catch padding, rod slices or internal Hoenn species IDs.
const LAYOUT: Dictionary = {"map_groups": 0, "map_group_sizes": [2],
	"wild_headers": 0x400, "wild_header_count": 2, "species_to_national": 0x800}


func _dump() -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(4096)
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
	return bytes


func test_headers_decode_their_own_flags_and_signed_connections() -> void:
	for id: StringName in [RomRegistry.RUBY, RomRegistry.FIRERED, RomRegistry.EMERALD]:
		var world: Dictionary = Gen3World.read(RomFile.from_bytes(_dump(), id), LAYOUT)
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
