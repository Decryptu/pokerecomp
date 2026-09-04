class_name Gen1SpriteCodec
extends RefCounted

## `UncompressSpriteData`, Generation 1's sprite format, which is not the
## [Gen2Lz] every other graphic in either generation uses. A stream opens on the
## picture's size in tiles and a bit naming which buffer takes the first chunk,
## then two run-length coded chunks of 2-bit groups with `wSpriteUnpackMode`
## between them. A chunk is written down each tile column four times over,
## filling bit pairs 7-6, then 5-4, 3-2 and 1-0, so four passes touch every
## output byte; the two finished chunks are the picture's two bit planes.

## `SPRITEBUFFERSIZE` is 7 by 7 tiles.
const MAX_TILES: int = 7
const PASSES: int = 4
## Mode 1 delta-decodes the first chunk and exclusive-ors it into the second;
## mode 2 delta-decodes both first.
const MODE_DELTA: int = 0
const MODE_XOR: int = 1
const MODE_DELTA_XOR: int = 2
## `LengthEncodingOffsetList` has sixteen rows.
const MAX_RUN_BITS: int = 16

## `DecodeNybble0Table` and `DecodeNybble1Table`, flattened so the nybble being
## decoded is the row. Which table is the last decoded nybble's bit 0, or its
## bit 3 when the picture is being mirrored.
const FROM_0: Array[int] = [0x0, 0x1, 0x3, 0x2, 0x7, 0x6, 0x4, 0x5,
	0xF, 0xE, 0xC, 0xD, 0x8, 0x9, 0xB, 0xA]
const FROM_1: Array[int] = [0xF, 0xE, 0xC, 0xD, 0x8, 0x9, 0xB, 0xA,
	0x0, 0x1, 0x3, 0x2, 0x7, 0x6, 0x4, 0x5]
const FLIPPED_FROM_0: Array[int] = [0x0, 0x8, 0xC, 0x4, 0xE, 0x6, 0x2, 0xA,
	0xF, 0x7, 0x3, 0xB, 0x1, 0x9, 0xD, 0x5]
const FLIPPED_FROM_1: Array[int] = [0xF, 0x7, 0x3, 0xB, 0x1, 0x9, 0xD, 0x5,
	0x0, 0x8, 0xC, 0x4, 0xE, 0x6, 0x2, 0xA]
## `NybbleReverseTable`.
const REVERSED: Array[int] = [0x0, 0x8, 0x4, 0xC, 0x2, 0xA, 0x6, 0xE,
	0x1, 0x9, 0x5, 0xD, 0x3, 0xB, 0x7, 0xF]

## Set by a run off the end of the cartridge, or a size no buffer can hold.
var failed: bool = false
## The last picture's size in tiles, from the first byte of its own stream.
var columns: int = 0
var rows: int = 0
var consumed: int = 0

var _data: PackedByteArray = PackedByteArray()
var _pos: int = 0
var _bit: int = 0


## Decompresses the pic at [param offset] into the column-major 2bpp tiles
## [method PokeTiles.decode_pic] takes, or nothing at all on failure.
## [param flipped] is `wSpriteFlipped`, which mirrors the pixels inside each
## tile column and leaves the columns for `CopyUncompressedPicToHL` to reverse.
func decompress(data: PackedByteArray, offset: int, flipped: bool = false) -> PackedByteArray:
	failed = false
	columns = 0
	rows = 0
	consumed = 0
	_data = data
	_pos = offset
	_bit = 0

	var size: int = _read_byte()
	columns = size >> 4
	rows = size & 0x0F
	if failed or columns < 1 or rows < 1 or columns > MAX_TILES or rows > MAX_TILES:
		failed = true
		return PackedByteArray()

	var second_first: bool = _read_bit() == 1
	var planes: Array[PackedByteArray] = [_new_plane(), _new_plane()]
	var first: int = 1 if second_first else 0
	_read_chunk(planes[first])
	var mode: int = _read_mode()
	_read_chunk(planes[1 - first])
	consumed = _pos - offset + (1 if _bit > 0 else 0)
	if failed:
		return PackedByteArray()

	_unpack(planes, first, mode, flipped)
	return _merge(planes, flipped)


func _new_plane() -> PackedByteArray:
	var plane: PackedByteArray = PackedByteArray()
	plane.resize(columns * rows * PokeTiles.TILE_1BPP_BYTES)
	return plane


func _read_byte() -> int:
	if _pos < 0 or _pos >= _data.size():
		failed = true
		return 0
	var value: int = _data[_pos]
	_pos += 1
	return value


func _read_bit() -> int:
	if _pos < 0 or _pos >= _data.size():
		failed = true
		return 0
	var value: int = (_data[_pos] >> (7 - _bit)) & 1
	_bit += 1
	if _bit == 8:
		_bit = 0
		_pos += 1
	return value


## One bit for mode 0, two for the others.
func _read_mode() -> int:
	if _read_bit() == 0:
		return MODE_DELTA
	return MODE_XOR + _read_bit()


## The cartridge stops the moment the last pair is placed, which is how a run
## of zeros longer than the picture ends the chunk.
func _read_chunk(plane: PackedByteArray) -> void:
	var stride: int = rows * PokeTiles.TILE_1BPP_BYTES
	var pairs: PackedByteArray = _read_pairs(columns * stride * PASSES)
	var at: int = 0
	for column: int in columns:
		for pass_number: int in PASSES:
			var shift: int = (PASSES - 1 - pass_number) * 2
			var base: int = column * stride
			for row: int in stride:
				plane[base + row] |= pairs[at] << shift
				at += 1


func _read_pairs(total: int) -> PackedByteArray:
	var pairs: PackedByteArray = PackedByteArray()
	pairs.resize(total)
	var at: int = 0
	var zeros: bool = _read_bit() == 0
	while at < total and not failed:
		if zeros:
			at = mini(total, at + _read_run_length())
			zeros = false
			continue
		var value: int = _read_bit() << 1
		value |= _read_bit()
		if value == 0:
			zeros = true
			continue
		pairs[at] = value
		at += 1
	return pairs


## How many zero pairs follow: leading ones count the number's bits, and
## `LengthEncodingOffsetList` adds `2^bits - 1` so each length has one encoding.
func _read_run_length() -> int:
	var bits: int = 1
	while _read_bit() == 1:
		bits += 1
		if bits > MAX_RUN_BITS:
			failed = true
			return 0
	var value: int = 0
	for _step: int in bits:
		value = (value << 1) | _read_bit()
	return value + (1 << bits) - 1


func _unpack(planes: Array[PackedByteArray], first: int, mode: int, flipped: bool) -> void:
	if mode == MODE_DELTA:
		_delta(planes[0], flipped)
		_delta(planes[1], flipped)
		return
	# A chunk that is not delta-decoded carries a mirrored picture's bits in
	# cartridge order, so `XorSpriteChunks` reverses its nybbles first.
	if mode == MODE_DELTA_XOR:
		_delta(planes[1 - first], false)
	_delta(planes[first], flipped)
	if flipped:
		_reverse_nybbles(planes[1 - first])
	_xor_into(planes[1 - first], planes[first])


## `SpriteDifferentialDecode`: a set bit toggles the running pixel value and a
## clear one keeps it, along each pixel row, restarting at every row.
func _delta(plane: PackedByteArray, flipped: bool) -> void:
	var stride: int = rows * PokeTiles.TILE_1BPP_BYTES
	var from_0: Array[int] = FLIPPED_FROM_0 if flipped else FROM_0
	var from_1: Array[int] = FLIPPED_FROM_1 if flipped else FROM_1
	var carry: int = 8 if flipped else 1
	for row: int in stride:
		var last: int = 0
		for column: int in columns:
			var at: int = column * stride + row
			var byte: int = plane[at]
			var high: int = (from_1 if (last & carry) != 0 else from_0)[byte >> 4]
			var low: int = (from_1 if (high & carry) != 0 else from_0)[byte & 0x0F]
			plane[at] = (high << 4) | low
			last = low


static func _reverse_nybbles(plane: PackedByteArray) -> void:
	for at: int in plane.size():
		var byte: int = plane[at]
		plane[at] = (REVERSED[byte >> 4] << 4) | REVERSED[byte & 0x0F]


static func _xor_into(plane: PackedByteArray, source: PackedByteArray) -> void:
	for at: int in plane.size():
		plane[at] ^= source[at]


## `InterlaceMergeSpriteBuffers`: buffer 1 is the low bit plane and buffer 2 the
## high one. A mirrored picture ends on the nybble swap that turns each already
## reversed pair into a reversed byte.
func _merge(planes: Array[PackedByteArray], flipped: bool) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(columns * rows * PokeTiles.TILE_BYTES)
	for at: int in planes[0].size():
		var low: int = planes[0][at]
		var high: int = planes[1][at]
		if flipped:
			low = ((low & 0x0F) << 4) | (low >> 4)
			high = ((high & 0x0F) << 4) | (high >> 4)
		out[at * 2] = low
		out[at * 2 + 1] = high
	return out
