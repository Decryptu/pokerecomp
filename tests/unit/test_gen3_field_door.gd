extends GutTest


func _door(id: StringName, big: bool) -> Dictionary:
	var data := GameData.new()
	data.id = id
	data.generation = RomRegistry.GEN3
	data._sections = {"headers": true, "scripts": true}
	data._world_headers = {"0:0": {}}
	data._world_scripts = {"doors": [{"metatile": 7, "sound": 1, "big": big, "tiles": 5, "palettes": [1, 2, 3, 4, 5, 6, 7, 8]}]}
	data._sections["gba_graphics"] = true
	var bytes := PackedByteArray()
	bytes.resize(0x600)
	for at: int in bytes.size():
		bytes[at] = at / 0x100 + 1
	data._world_tilesets = {"doors": {"5": {"bytes": bytes}}}
	var camera := Gen3FieldCamera.new()
	camera.data = data
	camera.grid = Gen3MapGrid.new()
	camera.grid.width = 32
	camera.grid.height = 32
	camera.grid.blocks.resize(1024)
	camera.grid.blocks.fill(0)
	camera.grid.blocks[10 * 32 + 10] = 7
	camera.grid._behaviors.resize(1024)
	camera.grid._behaviors[7] = 0x69
	var vram := Gen3FieldVram.new()
	vram.palette = Gen3Palette.new()
	vram.tiles.resize(Gen3FieldVram.TILE_COUNT * GbaTiles.TILE_BYTES)
	var events := Gen3EventData.new(id)
	return {"door": Gen3FieldDoor.new(camera, vram, Gen3FieldInput.new(events), events), "vram": vram}


func _run(door: Gen3FieldDoor) -> int:
	var frames: int = 0
	while door.running:
		door.step()
		frames += 1
	return frames


func test_a_door_opens_over_the_two_cells_in_twenty_frames_then_closes_back_to_the_map() -> void:
	var fixture: Dictionary = _door(RomRegistry.EMERALD, false)
	var door: Gen3FieldDoor = fixture["door"]
	var vram: Gen3FieldVram = fixture["vram"]
	assert_true(door.open(Vector2i(10, 10)))
	assert_false(door.open(Vector2i(10, 10)), "One door animates at a time.")
	assert_eq(door.sound(Vector2i(10, 10)), "sliding_door")
	assert_eq(_run(door), 20)
	assert_eq(vram.door_cells[Vector2i(10, 9)], PackedInt32Array([0x13F8, 0x23F9, 0x33FA, 0x43FB]))
	assert_eq(vram.door_cells[Vector2i(10, 10)], PackedInt32Array([0x53FC, 0x63FD, 0x73FE, 0x83FF]))
	assert_eq(vram.tiles[1016 * GbaTiles.TILE_BYTES], 3, "The last frame is at 0x200.")
	assert_true(door.close(Vector2i(10, 10)))
	assert_eq(_run(door), 20)
	assert_true(vram.door_cells.is_empty())
	assert_false(door.open(Vector2i(11, 10)), "Off a door nothing starts, which the warp tasks read as finished.")


func test_each_engine_lays_a_door_out_its_own_way() -> void:
	var big: Dictionary = _door(RomRegistry.EMERALD, true)
	(big["door"] as Gen3FieldDoor).set_opened(Vector2i(10, 10))
	assert_eq(big["vram"].door_cells.size(), 4)
	assert_eq(big["vram"].door_cells[Vector2i(11, 10)][0] & 0x3FF, 1020)
	assert_eq(big["vram"].tiles[1008 * GbaTiles.TILE_BYTES], 5, "Big doors step 0x200.")
	big["door"].close(Vector2i(10, 10))
	big["door"].step()
	assert_eq(big["vram"].tiles[1008 * GbaTiles.TILE_BYTES], 3, "Emerald closes a big door with the small frames.")
	var small: Dictionary = _door(RomRegistry.FIRERED, false)
	(small["door"] as Gen3FieldDoor).set_opened(Vector2i(10, 10))
	assert_eq(small["vram"].door_cells.keys(), [Vector2i(10, 10)])
	assert_eq(small["vram"].tiles[1016 * GbaTiles.TILE_BYTES], 2, "FRLG's small frames are four tiles, so the last is at 0x100.")
