extends GutTest

const GEN1_ROM_SIZE: int = RomRegistry.SIZES[RomRegistry.GEN1]

## The Generation 1 offset tables cannot be checked for correctness without a
## cartridge; that is what [method Gen1Importer.verify_layout] does at import
## time, and `tools/checks/gen1_tables.gd` sweeps the decoded result. What can be
## checked here is that the tables are complete and internally consistent, and
## that the addressing arithmetic around them is right.

## Every key both profiles have to carry, since a missing one is a crash at
## import rather than a refusal.
const REQUIRED_KEYS: Array[String] = [
	"species_names", "base_stats", "mew_base_stats", "pic_mew_bank", "dex_order",
	"dex_entries", "dex_entries_bank", "moves", "move_names", "type_names",
	"type_names_bank", "type_effects", "item_names", "item_prices", "tmhm_moves",
	"mon_palettes", "super_palettes", "trainer_names", "evos_moves", "evos_moves_bank",
	"cries",
]


func test_every_gen1_game_has_a_layout() -> void:
	for id: StringName in RomRegistry.ids_of_generation(RomRegistry.GEN1):
		assert_true(Gen1Layout.is_characterised(id), "%s has no layout" % id)


func test_a_gen2_game_has_none() -> void:
	assert_true(Gen1Layout.for_id(RomRegistry.CRYSTAL).is_empty())
	assert_true(Gen1Layout.for_id(&"emerald").is_empty())


func test_red_and_blue_share_one_table() -> void:
	# The two are one source built twice and every table this layout names is at
	# the same offset in both; only bank $1D's map scripts move.
	assert_eq(Gen1Layout.for_id(RomRegistry.RED), Gen1Layout.for_id(RomRegistry.BLUE))


func test_every_layout_is_complete_and_inside_the_cartridge() -> void:
	for id: StringName in RomRegistry.ids_of_generation(RomRegistry.GEN1):
		var layout: Dictionary = Gen1Layout.for_id(id)
		for key: String in REQUIRED_KEYS:
			assert_true(layout.has(key), "%s has no %s" % [id, key])
		for key: String in layout:
			assert_between(int(layout[key]), 0, GEN1_ROM_SIZE - 1, "%s.%s" % [id, key])


func test_every_table_ends_inside_the_cartridge() -> void:
	for id: StringName in RomRegistry.ids_of_generation(RomRegistry.GEN1):
		var layout: Dictionary = Gen1Layout.for_id(id)
		assert_lt(
			Gen1Layout.species_name_offset(layout, Gen1Layout.INDEX_COUNT)
				+ Gen1Layout.NAME_LENGTH,
			GEN1_ROM_SIZE, "%s species names" % id
		)
		assert_lt(
			Gen1Layout.move_offset(layout, Gen1Layout.MOVE_COUNT) + Gen1Layout.MOVE_DATA_SIZE,
			GEN1_ROM_SIZE, "%s moves" % id
		)
		assert_lt(
			Gen1Layout.item_price_offset(layout, Gen1Layout.ITEM_COUNT)
				+ Gen1Layout.ITEM_PRICE_SIZE,
			GEN1_ROM_SIZE, "%s item prices" % id
		)


func test_base_stats_rows_are_one_record_apart() -> void:
	var layout: Dictionary = Gen1Layout.for_id(RomRegistry.RED)
	assert_eq(
		Gen1Layout.base_stats_offset(layout, 2) - Gen1Layout.base_stats_offset(layout, 1),
		Gen1Layout.BASE_STATS_SIZE
	)


func test_red_keeps_mew_out_of_the_table_and_yellow_does_not() -> void:
	var red: Dictionary = Gen1Layout.for_id(RomRegistry.RED)
	var yellow: Dictionary = Gen1Layout.for_id(RomRegistry.YELLOW)
	assert_eq(Gen1Layout.base_stats_offset(red, Gen1Layout.SPECIES_COUNT),
		int(red["mew_base_stats"]), "Red sends Mew to its own row")
	assert_eq(
		Gen1Layout.base_stats_offset(yellow, Gen1Layout.SPECIES_COUNT),
		int(yellow["base_stats"]) + (Gen1Layout.SPECIES_COUNT - 1) * Gen1Layout.BASE_STATS_SIZE,
		"Yellow keeps Mew in the table"
	)


func test_the_pic_bank_follows_the_index_thresholds() -> void:
	var red: Dictionary = Gen1Layout.for_id(RomRegistry.RED)
	assert_eq(Gen1Layout.pic_bank(red, 0x01), 0x09)
	assert_eq(Gen1Layout.pic_bank(red, 0x1E), 0x09)
	assert_eq(Gen1Layout.pic_bank(red, 0x1F), 0x0A)
	assert_eq(Gen1Layout.pic_bank(red, 0x4A), 0x0B)
	assert_eq(Gen1Layout.pic_bank(red, 0x74), 0x0C)
	assert_eq(Gen1Layout.pic_bank(red, 0x99), 0x0D)
	assert_eq(Gen1Layout.pic_bank(red, Gen1Layout.PIC_INDEX_FOSSIL_KABUTOPS), 0x0B)


func test_only_red_and_blue_send_mew_to_bank_one() -> void:
	assert_eq(
		Gen1Layout.pic_bank(Gen1Layout.for_id(RomRegistry.RED), Gen1Layout.PIC_INDEX_MEW), 0x01
	)
	assert_eq(
		Gen1Layout.pic_bank(Gen1Layout.for_id(RomRegistry.YELLOW), Gen1Layout.PIC_INDEX_MEW),
		0x09, "Yellow put Mew's pic back in the run"
	)


func test_the_unused_type_run_is_excluded_and_the_special_run_is_not() -> void:
	assert_true(Gen1Layout.is_real_type(0x08))
	assert_false(Gen1Layout.is_real_type(0x09))
	assert_false(Gen1Layout.is_real_type(0x13))
	assert_true(Gen1Layout.is_real_type(0x14))
	assert_false(Gen1Layout.is_special_type(0x08), "the physical run ends at GHOST")
	assert_true(Gen1Layout.is_special_type(0x14), "FIRE opens the special run")


func test_every_evolution_method_has_a_record_size() -> void:
	for method: int in [
		Gen1Layout.EVOLVE_LEVEL, Gen1Layout.EVOLVE_ITEM, Gen1Layout.EVOLVE_TRADE
	]:
		assert_true(Gen1Layout.EVOLVE_SIZES.has(method), "method %d has no size" % method)
	# The item row is the only four-byte one; a decoder with the size wrong stays
	# in step everywhere else and comes out of that row reading rubbish.
	assert_eq(int(Gen1Layout.EVOLVE_SIZES[Gen1Layout.EVOLVE_ITEM]), 4)


func test_the_base_stats_record_holds_every_member_it_names() -> void:
	var members: Array[int] = [
		Gen1Layout.BASE_DEX_NO, Gen1Layout.BASE_HP, Gen1Layout.BASE_ATTACK,
		Gen1Layout.BASE_DEFENSE, Gen1Layout.BASE_SPEED, Gen1Layout.BASE_SPECIAL,
		Gen1Layout.BASE_TYPE_1, Gen1Layout.BASE_TYPE_2, Gen1Layout.BASE_CATCH_RATE,
		Gen1Layout.BASE_EXP, Gen1Layout.BASE_PIC_SIZE, Gen1Layout.BASE_FRONT_PIC,
		Gen1Layout.BASE_BACK_PIC, Gen1Layout.BASE_MOVES, Gen1Layout.BASE_GROWTH_RATE,
	]
	for member: int in members:
		assert_between(member, 0, Gen1Layout.BASE_STATS_SIZE - 1, "member %d" % member)
	assert_eq(
		Gen1Layout.BASE_TMHM + Gen1Layout.BASE_TMHM_BYTES, Gen1Layout.BASE_STATS_SIZE - 1,
		"the TM/HM bits end one padding byte short of the record"
	)


func test_a_pointer_row_resolves_through_its_own_bank() -> void:
	var data: PackedByteArray = PackedByteArray()
	data.resize(GEN1_ROM_SIZE)
	var layout: Dictionary = {"type_names": 0x100, "type_names_bank": 0x09}
	# Row 1 points at $7DAE in bank 9.
	data[0x102] = 0xAE
	data[0x103] = 0x7D
	var rom: RomFile = RomFile.from_bytes(data, RomRegistry.RED)
	assert_eq(Gen1Layout.pointer_target(rom, layout, "type_names", 1), 0x09 * 0x4000 + 0x3DAE)
