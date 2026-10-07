extends GutTest

## Synthetic BIOS streams protect flag order, overlapping references and bounds;
## the Game Boy decoder tests exercise a different compression format.
func test_flags_overlap_and_nonzero_offset() -> void:
	var stream := PackedByteArray([99, 0x10, 9, 0, 0, 0x30, 65, 66, 0x10, 1, 0, 0])
	assert_eq(GbaLz.decompress(stream, 1), PackedByteArray([65, 66, 65, 66, 65, 66, 66, 66, 66]))


func test_flag_group_rollover_and_partial_final_group() -> void:
	var stream := PackedByteArray([0x10, 9, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 0, 9])
	assert_eq(GbaLz.decompress(stream, 0), PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8, 9]))


func test_invalid_streams_return_no_partial_pixels() -> void:
	var streams: Array = [
		[0x11, 1, 0, 0, 0, 7],
		[0x10, 0, 0, 0],
		[0x10, 1, 0, 1],
		[0x10, 1, 0, 0],
		[0x10, 1, 0, 0, 0],
		[0x10, 3, 0, 0, 0x80, 0],
		[0x10, 3, 0, 0, 0x80, 0, 0],
		[0x10, 2, 0, 0, 0x40, 7, 0, 0],
	]
	for stream: Array in streams:
		assert_true(GbaLz.decompress(PackedByteArray(stream), 0).is_empty(), str(stream))
	assert_true(GbaLz.decompress(PackedByteArray([0x10, 1]), 0).is_empty())
	assert_true(GbaLz.decompress(PackedByteArray(), -1).is_empty())


## Asymmetric tile runs catch column-major placement and reversed nibbles;
## all existing tile tests cover only planar Game Boy data.
func test_4bpp_tile_and_pixel_order() -> void:
	var tiles := PackedByteArray()
	tiles.resize(4 * 32)
	for tile: int in 4:
		for byte: int in 32:
			tiles[tile * 32 + byte] = ((tile + 9) << 4) | (tile + 1)
	var pixels: PackedByteArray = GbaTiles.decode(tiles, 2, 2)
	assert_eq(pixels.size(), 256)
	assert_eq(pixels.slice(0, 10), PackedByteArray([1, 9, 1, 9, 1, 9, 1, 9, 2, 10]))
	assert_eq(pixels.slice(128, 138), PackedByteArray([3, 11, 3, 11, 3, 11, 3, 11, 4, 12]))
	assert_true(GbaTiles.decode(tiles, 3, 2).is_empty())
	assert_true(GbaTiles.decode(tiles, 2, 2, -1).is_empty())


func test_reference_distance_keeps_its_high_bits() -> void:
	var stream := PackedByteArray([0x10, 4, 1, 0])
	for block: int in 32:
		stream.append(0)
		for byte: int in 8:
			stream.append(block * 8 + byte)
	stream.append_array(PackedByteArray([0x40, 0xAB, 1, 0]))
	var decoded: PackedByteArray = GbaLz.decompress(stream, 0)
	assert_eq(decoded.size(), 260)
	assert_eq(decoded.slice(256), PackedByteArray([0xAB, 0, 1, 2]))
