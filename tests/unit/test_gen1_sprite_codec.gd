extends GutTest

## `UncompressSpriteData` on streams built here, so the shape of the format is
## pinned without a cartridge. Every real picture is checked against pret's own
## PNGs by `tools/checks/gen1_pics.gd`.

## One tile square, which is one 8-byte plane and 32 bit pairs a chunk.
const ONE_TILE: int = 0x11
const PAIRS: int = 32
## Four passes of the pair 01 fill a byte with $55, and the differential decode
## turns that into $66.
const LITERAL_ONES: int = 0x66
const LITERAL_TWOS: int = 0xAA


## Writes a bit stream the way the cartridge reads one: most significant bit of
## each byte first.
class Bits extends RefCounted:
	var bytes: PackedByteArray = PackedByteArray()
	var _bit: int = 0

	func byte(value: int) -> void:
		put(value, 8)

	func put(value: int, count: int) -> void:
		for step: int in count:
			var one: int = (value >> (count - 1 - step)) & 1
			if _bit == 0:
				bytes.append(0)
			bytes[bytes.size() - 1] |= one << (7 - _bit)
			_bit = (_bit + 1) % 8

	## A chunk of literal pairs, none of them zero.
	func literals(values: Array[int]) -> void:
		put(1, 1)
		for value: int in values:
			put(value, 2)

	## A chunk that opens on a run of [param count] zero pairs, which is as many
	## as the picture needs.
	func zeros(count: int) -> void:
		put(0, 1)
		var width: int = 1
		while count > (1 << (width + 1)) - 2:
			width += 1
		# `width - 1` ones, then the zero that ends the count, then the number.
		put(((1 << (width - 1)) - 1) << 1, width)
		put(count - (1 << width) + 1, width)


func _repeat(value: int, count: int) -> Array[int]:
	var out: Array[int] = []
	for _step: int in count:
		out.append(value)
	return out


func _cycle(count: int) -> Array[int]:
	var out: Array[int] = []
	for step: int in count:
		out.append(1 + step % 3)
	return out


## A whole one-tile stream: the size byte, the buffer bit, both chunks and the
## unpack mode between them.
func _one_tile(second_first: bool, mode: int, a: Array[int], b: Array[int]) -> PackedByteArray:
	var bits := Bits.new()
	bits.byte(ONE_TILE)
	bits.put(1 if second_first else 0, 1)
	bits.literals(a)
	if mode == Gen1SpriteCodec.MODE_DELTA:
		bits.put(0, 1)
	else:
		bits.put(mode + 1, 2)
	bits.literals(b)
	return bits.bytes


func test_the_first_byte_is_the_picture_size() -> void:
	var bits := Bits.new()
	bits.byte(0x53)
	bits.put(0, 1)
	bits.zeros(5 * 3 * 8 * 4)
	bits.put(0, 1)
	bits.zeros(5 * 3 * 8 * 4)
	var codec := Gen1SpriteCodec.new()
	var out: PackedByteArray = codec.decompress(bits.bytes, 0)
	assert_false(codec.failed, "a whole stream decodes")
	assert_eq(codec.columns, 5, "the high nybble is the width in tiles")
	assert_eq(codec.rows, 3, "the low nybble is the height in tiles")
	assert_eq(out.size(), 5 * 3 * PokeTiles.TILE_BYTES, "one 2bpp tile per tile")


func test_a_run_of_zeros_fills_the_picture() -> void:
	var bits := Bits.new()
	bits.byte(ONE_TILE)
	bits.put(0, 1)
	bits.zeros(PAIRS)
	bits.put(0, 1)
	bits.zeros(PAIRS)
	var codec := Gen1SpriteCodec.new()
	var out: PackedByteArray = codec.decompress(bits.bytes, 0)
	assert_false(codec.failed, "a run of zeros is a picture")
	assert_eq(out.count(0), PokeTiles.TILE_BYTES, "every byte is blank")


func test_literal_pairs_are_differentially_decoded() -> void:
	var codec := Gen1SpriteCodec.new()
	var out: PackedByteArray = codec.decompress(
		_one_tile(false, Gen1SpriteCodec.MODE_DELTA, _repeat(1, PAIRS), _repeat(1, PAIRS)), 0
	)
	assert_false(codec.failed, "both chunks decode")
	assert_eq(out.count(LITERAL_ONES), PokeTiles.TILE_BYTES, "both planes carry $66")


func test_mode_one_exclusive_ors_the_first_chunk_into_the_second() -> void:
	var codec := Gen1SpriteCodec.new()
	var out: PackedByteArray = codec.decompress(
		_one_tile(false, Gen1SpriteCodec.MODE_XOR, _repeat(1, PAIRS), _repeat(2, PAIRS)), 0
	)
	assert_false(codec.failed, "mode 1 decodes")
	assert_eq(out[0], LITERAL_ONES, "the low plane is the delta-decoded chunk")
	assert_eq(out[1], LITERAL_TWOS ^ LITERAL_ONES, "the high plane is the other one, xored")


func test_the_buffer_bit_swaps_which_plane_the_first_chunk_lands_in() -> void:
	var codec := Gen1SpriteCodec.new()
	var out: PackedByteArray = codec.decompress(
		_one_tile(true, Gen1SpriteCodec.MODE_XOR, _repeat(1, PAIRS), _repeat(2, PAIRS)), 0
	)
	assert_false(codec.failed, "the second buffer decodes")
	assert_eq(out[0], LITERAL_TWOS ^ LITERAL_ONES, "the xored chunk is the low plane now")
	assert_eq(out[1], LITERAL_ONES, "and the delta-decoded one is the high plane")


func test_a_flipped_picture_mirrors_the_pixels_inside_each_tile_column() -> void:
	var stream: PackedByteArray = _one_tile(
		false, Gen1SpriteCodec.MODE_DELTA, _cycle(PAIRS), _cycle(PAIRS)
	)
	var codec := Gen1SpriteCodec.new()
	var plain: PackedByteArray = PokeTiles.decode_pic(codec.decompress(stream, 0), 1, 1)
	var mirrored: PackedByteArray = PokeTiles.decode_pic(codec.decompress(stream, 0, true), 1, 1)
	assert_false(codec.failed, "a mirrored picture decodes")
	var wanted: PackedByteArray = PackedByteArray()
	for row: int in PokeTiles.TILE_HEIGHT:
		for column: int in PokeTiles.TILE_WIDTH:
			wanted.append(plain[row * PokeTiles.TILE_WIDTH + 7 - column])
	assert_eq(mirrored, wanted, "every row is reversed")


func test_consumed_counts_the_bytes_the_stream_used() -> void:
	var stream: PackedByteArray = _one_tile(
		false, Gen1SpriteCodec.MODE_DELTA, _repeat(1, PAIRS), _repeat(1, PAIRS)
	)
	var codec := Gen1SpriteCodec.new()
	codec.decompress(stream, 0)
	assert_eq(codec.consumed, stream.size(), "the whole stream was read")


func test_a_stream_outside_the_cartridge_fails() -> void:
	var codec := Gen1SpriteCodec.new()
	var stream: PackedByteArray = _one_tile(
		false, Gen1SpriteCodec.MODE_DELTA, _repeat(1, PAIRS), _repeat(1, PAIRS)
	)
	assert_eq(codec.decompress(stream, -1).size(), 0, "a negative offset decodes nothing")
	assert_true(codec.failed, "and says so")
	assert_eq(codec.decompress(stream, stream.size()).size(), 0, "so does one past the end")
	assert_true(codec.failed, "and says so")
	assert_eq(codec.decompress(stream.slice(0, 4), 0).size(), 0, "a truncated stream fails")
	assert_true(codec.failed, "and says so")


func test_a_size_no_sprite_buffer_can_hold_fails() -> void:
	var codec := Gen1SpriteCodec.new()
	var bits := Bits.new()
	bits.byte(0x88)
	bits.put(0, 1)
	bits.zeros(PAIRS)
	assert_eq(codec.decompress(bits.bytes, 0).size(), 0, "an 8x8 picture is refused")
	assert_true(codec.failed, "and says so")
	bits = Bits.new()
	bits.byte(0x00)
	assert_eq(codec.decompress(bits.bytes, 0).size(), 0, "and so is an empty one")
	assert_true(codec.failed, "and says so")
