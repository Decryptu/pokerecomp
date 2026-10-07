extends GutTest

## Protect padded party variants, internal species mapping and retained IVs.
## A stride/flag refactor can swap moves and items; older tests use GB parties.
const LAYOUT: Dictionary = {
	"trainers": 0, "trainer_count": 5, "trainer_class_names": 0x200,
	"trainer_class_count": 1, "trainer_pic_count": 1, "trainer_money": 0x300,
	"trainer_pics": 0x320, "trainer_palettes": 0x360, "trainer_coords": 0x380,
	"species_to_national": 0x800, "item_count": 349,
}


func _dump() -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(4096)
	bytes[0x200] = 0xBB
	bytes[0x201] = 0xFF
	bytes[0x300] = 0xFF
	bytes[0x301] = 7
	bytes.encode_u32(0x360, 0x08000390)
	bytes[0x390] = 0x10
	bytes[0x391] = 32
	bytes.encode_u16(0x800 + 276 * 2, 252)
	for flags: int in 4:
		var at: int = (flags + 1) * 40
		bytes[at] = flags
		bytes[at + 2] = 0x85
		bytes[at + 4] = 0xBB
		bytes[at + 5] = 0xFF
		bytes.encode_u16(at + 16, 13)
		bytes[at + 24] = 1
		bytes.encode_u32(at + 28, 0x80000007)
		bytes[at + 32] = 2
		bytes.encode_u32(at + 36, 0x08000400 + flags * 64)
		for slot: int in 2:
			var mon: int = 0x400 + flags * 64 + slot * (8 if flags in [0, 2] else 16)
			bytes.encode_u16(mon, 255 if slot == 1 else 0)
			bytes[mon + 2] = 20 if slot == 1 else 10
			bytes.encode_u16(mon + 4, 277)
			if flags in [2, 3]:
				bytes.encode_u16(mon + 6, 200)
			if flags in [1, 3]:
				var moves: int = mon + (8 if flags == 3 else 6)
				bytes.encode_u16(moves, 33)
				bytes.encode_u16(moves + 2, 98)
	return bytes


func test_all_four_party_formats_keep_both_members() -> void:
	var rows: Array = Gen3Trainers.read(RomFile.from_bytes(_dump()), LAYOUT)
	assert_eq(rows.size(), 4)
	for flags: int in 4:
		var party: Array = rows[flags]["party"]
		assert_eq(party.size(), 2)
		assert_eq(party[0]["species"], 252)
		assert_eq(party[1]["level"], 20)
		assert_eq(party[1]["iv"], 255)
		assert_eq(party[0]["item"], 200 if flags in [2, 3] else 0)
		assert_eq(party[1]["moves"], [33, 98, 0, 0] if flags in [1, 3] else [])


func test_invalid_parties_return_no_partial_trainers() -> void:
	var changes: Array = [
		[40, 4, 1], [72, 0, 1], [72, 7, 1], [76, 0, 4],
		[76, 0x09000000, 4], [76, 0x08000401, 4], [76, 0x08000FFC, 4],
		[0x400, 256, 2], [0x402, 101, 1], [0x404, 252, 2],
		[0x446, 355, 2], [0x486, 349, 2],
	]
	for change: Array in changes:
		var bytes: PackedByteArray = _dump()
		match int(change[2]):
			1: bytes[int(change[0])] = int(change[1])
			2: bytes.encode_u16(int(change[0]), int(change[1]))
			4: bytes.encode_u32(int(change[0]), int(change[1]))
		assert_true(Gen3Trainers.read(RomFile.from_bytes(bytes), LAYOUT).is_empty(), str(change))


func test_cache_api_keeps_individual_identity_and_integer_party_fields() -> void:
	var data := GameData.new()
	data.generation = RomRegistry.GEN3
	data._atlases = {"trainers": {"cell": 64, "decoded": 1}}
	data._trainers = JSON.parse_string(JSON.stringify(Gen3Trainers.read(RomFile.from_bytes(_dump()), LAYOUT)))
	assert_eq(data.trainer_count(), 4)
	assert_true(data.trainer(0).is_empty())
	assert_true(data.trainer(5).is_empty())
	assert_eq(data.trainer_party_count(1), 1)
	assert_eq(data.trainer_party_count(0), 0)
	assert_true(data.trainer_party(1, 1).is_empty())
	var entry: Dictionary = data.trainer_party(4)
	assert_eq(entry["type"], 3)
	assert_eq(entry["party"][1]["iv"], 255)
	assert_eq(entry["party"][0]["moves"], [33, 98, 0, 0])
	assert_eq(entry["items"], [13, 0, 0, 0])
	assert_eq(entry["ai_flags"], 0x80000007)
	assert_typeof(entry["palette"][0], TYPE_INT)
	assert_typeof(entry["pic_coordinates"]["size"], TYPE_INT)
	assert_true(entry["female"])
	assert_eq(entry["encounter_music"], 5)
	assert_eq(data.trainer_pic(4)["slot"], 0)
	assert_eq(data.trainer_palette(4).size(), 16)
	assert_eq(data.trainer_attributes(4)["base_money"], 7)
	entry["party"][0]["iv"] = 99
	assert_eq(data.trainer_party(4)["party"][0]["iv"], 0)
