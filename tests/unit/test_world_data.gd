extends GutTest

## The cache-facing world records are deliberately node-free, so their geometry
## and collision conventions can be checked without opening a scene or a ROM.


func test_map_uses_row_major_blocks_and_collision_cells() -> void:
	var map := Gen2WorldMap.from_cache({
		"group": 2,
		"number": 3,
		"width_blocks": 2,
		"height_blocks": 1,
		"blocks": [4, 5],
		"collision_width": 4,
		"collision_height": 2,
		"collision": [10, 11, 12, 13, 14, 15, 16, 17],
	})

	assert_eq(map.block_at(0, 0), 4)
	assert_eq(map.block_at(1, 0), 5)
	assert_eq(map.block_at(2, 0), 0)
	assert_eq(map.collision_at(0, 0), 10)
	assert_eq(map.collision_at(3, 1), 17)
	assert_eq(map.collision_at(4, 0), -1)


func test_map_reads_directional_connections_and_signed_offsets() -> void:
	var map := Gen2WorldMap.from_cache({
		"group": 1,
		"number": 1,
		"width_blocks": 4,
		"height_blocks": 3,
		"connection_flags": Gen2Layout.MAP_CONNECTION_FLAG_NORTH,
		"connections": [{
			"direction": "north", "map_group": 2, "map_number": 4,
			"length": 5, "target_width_blocks": 8,
			"x_offset": -10, "y_offset": 11,
		}],
	})

	assert_eq(map.connection_flags, Gen2Layout.MAP_CONNECTION_FLAG_NORTH)
	assert_eq(map.connections.size(), 1)
	assert_eq(map.connections[0]["direction"], "north")
	assert_eq(map.connections[0]["map_group"], 2)
	assert_eq(map.connections[0]["x_offset"], -10)
	assert_eq(map.connections[0]["y_offset"], 11)


func test_tileset_expands_four_by_four_tiles_and_two_by_two_collision() -> void:
	var meta: Array = []
	for value: int in 32:
		meta.append(value)
	var collision: Array = [0, 0, 0, 0, 20, 21, 22, 23]
	var tileset := Gen2WorldTileset.from_cache({
		"number": 7,
		"block_count": 2,
		"meta": meta,
		"collision": collision,
	})

	assert_eq(tileset.tile_index(0, 0), 0)
	assert_eq(tileset.tile_index(1, 15), 31)
	assert_eq(tileset.collision_index(0, 0, 0), -1)
	assert_eq(tileset.collision_index(1, 0, 0), 20)
	assert_eq(tileset.collision_index(1, 1, 1), 23)


func test_tileset_palette_map_reads_low_nibble_first() -> void:
	var tileset := Gen2WorldTileset.from_cache({
		"number": 2,
		"block_count": 1,
		"tile_count": 6,
		"palette_map": [0x21, 0x43, 0x65],
	})

	assert_eq(tileset.palette_index(0), 1)
	assert_eq(tileset.palette_index(1), 2)
	assert_eq(tileset.palette_index(2), 3)
	assert_eq(tileset.palette_index(3), 4)
	assert_eq(tileset.palette_index(4), 5)
	assert_eq(tileset.palette_index(5), 6)


func test_a_block_names_the_second_graphics_block_and_a_placeholder_names_nothing() -> void:
	var meta: Array = []
	meta.resize(16)
	meta.fill(0)
	meta[0] = 211
	meta[1] = 0xFF
	var tileset := Gen2WorldTileset.from_cache({
		"number": 7,
		"block_count": 1,
		"meta": meta,
	})

	assert_eq(tileset.tile_count, Gen2Layout.TILESET_TILE_COUNT)
	assert_eq(tileset.tile_index(0, 0), 211)
	assert_eq(tileset.tile_index(0, 1), 0)


func test_a_second_block_palette_nibble_drops_the_vram_bank_bit() -> void:
	var palette_map: Array = []
	palette_map.resize(Gen2Layout.WORLD_PALETTE_MAP_BYTES)
	palette_map.fill(0)
	palette_map[64] = 0x0B
	palette_map[111] = 0xC0
	var tileset := Gen2WorldTileset.from_cache({
		"number": 2,
		"block_count": 1,
		"palette_map": palette_map,
	})

	assert_eq(tileset.palette_index(128), 3)
	assert_eq(tileset.palette_index(223), 4)
