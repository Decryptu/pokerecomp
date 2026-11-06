extends GutTest


func test_signed_warp_records_resolve_explicit_coordinates_or_the_map_center() -> void:
	var data := GameData.new()
	data.generation = RomRegistry.GEN3
	data._sections["headers"] = true
	data._world_headers = {"0:1": {"width": 31, "height": 19, "events": {"warps": []}}}
	var warps := Gen3Warp.new()
	warps.destination = Gen3Warp.record(0, 1, 0xFF, 0x4005, 7)
	assert_eq(warps.position(data), Vector2i(5, 7))
	warps.commit()
	warps.destination = Gen3Warp.record(0, 1, 0xFF, 0x80, 7)
	assert_eq(warps.position(data), Vector2i(15, 9))
	warps.commit()
	assert_eq(warps.last["x"], 5)
	assert_eq(warps.location["x"], -128)


func test_a_dummy_fixed_hole_uses_the_last_map_but_a_fixed_map_keeps_the_fall_coordinates() -> void:
	var warps := Gen3Warp.new()
	warps.last = Gen3Warp.record(1, 2, 3, 4, 5)
	warps.hole = Gen3Warp.record(0xFF, 0xFF, 0xFF)
	assert_eq(warps.fall_destination(Vector2i(6, 7)), warps.last)
	warps.hole = Gen3Warp.record(2, 3, 4, 10, 11)
	assert_eq(warps.fall_destination(Vector2i(6, 7)), Gen3Warp.record(2, 3, -1, 6, 7))


func test_applying_a_warp_clears_the_fixed_dive_and_hole_warps() -> void:
	var warps := Gen3Warp.new()
	warps.dive = Gen3Warp.record(1, 2, 3)
	warps.hole = Gen3Warp.record(1, 2, 3)
	warps.destination = Gen3Warp.record(4, 5, 6)
	warps.commit()
	assert_true(warps.dive.is_empty())
	assert_true(warps.hole.is_empty())


func test_arrival_takes_the_destination_tile_and_map_over_the_stored_state() -> void:
	var events := Gen3EventData.new(RomRegistry.EMERALD)
	var input := Gen3FieldInput.new(events)
	var flag: Dictionary = Gen3PlayerAvatar.Flag
	var outdoors: Dictionary = {"map_type": 3, "allow_cycling": true}
	assert_eq(input.initial_flags(flag.MACH_BIKE, Vector2i(0, 1), outdoors, false), flag.MACH_BIKE)
	assert_eq(input.initial_flags(flag.MACH_BIKE, Vector2i(0, 1), {"map_type": 8}, false), flag.ON_FOOT)
	assert_eq(input.initial_flags(flag.ON_FOOT, Vector2i(0, 1), outdoors, true), flag.SURFING)
	assert_eq(input.initial_flags(flag.SURFING, Vector2i(0, 1), {"map_type": 5}, false), flag.UNDERWATER)
	var direction: Dictionary = Gen3ObjectEvents.Direction
	assert_eq(input.initial_direction(direction.WEST, flag.ON_FOOT, flag.ON_FOOT, 0x69, 8), direction.SOUTH)
	assert_eq(input.initial_direction(direction.WEST, flag.ON_FOOT, flag.ON_FOOT, 0x65, 8), direction.NORTH, "The mat inside a door.")
	assert_eq(input.initial_direction(direction.WEST, flag.ON_FOOT, flag.ON_FOOT, 0x61, 8), direction.WEST, "A ladder keeps it.")
	assert_eq(input.initial_direction(direction.WEST, flag.SURFING, flag.UNDERWATER, 0, 5), direction.WEST, "So does a dive.")
	assert_eq(input.initial_direction(direction.WEST, flag.ON_FOOT, flag.ON_FOOT, 0, 3), direction.SOUTH)
	assert_true(Gen3FieldInput.new(Gen3EventData.new(RomRegistry.RUBY)).biking_allowed(Vector2i(29, 11), {"map_type": 8}),
		"Ruby's cycling road gates are indoors.")
