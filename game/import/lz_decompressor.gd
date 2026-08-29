class_name Gen2Lz
extends RefCounted

## The LZ variant Generation 1 and 2 use for every compressed graphic. A stream is
## a run of commands terminated by $FF, each packing a 3-bit opcode and a length;
## opcode 7 escapes to a long form so one command can span 1024 bytes. The seven
## are literal, iterate, alternate, zero, and the three back-references repeat,
## flipped and reversed. A back-reference offset is a one-byte distance back (high
## bit set) or a two-byte absolute position (high bit clear), and sources may
## overlap the bytes being written, so the copy is byte-at-a-time. The
## bit-reversing opcode exists because a mirrored 2bpp sprite half is those bytes.

enum Op {
	LITERAL,
	ITERATE,
	ALTERNATE,
	ZERO,
	REPEAT,
	FLIPPED,
	REVERSED,
	LONG,
}

const TERMINATOR: int = 0xFF
const MAX_SHORT_LENGTH: int = 32
const LONG_OFFSET_MASK: int = 0x80

## No Gen 2 graphic decompresses to anything near this. It only bounds the
## damage when a bad offset points at data that happens to decode forever.
const MAX_OUTPUT: int = 0x4000

## Set when the last decompression ran off the end of the data, hit an
## impossible back-reference, or overran [constant MAX_OUTPUT].
var failed: bool = false

## Bytes of compressed input the last successful decompression consumed,
## including the terminator.
var consumed: int = 0

static var _reversed_bits: PackedByteArray = PackedByteArray()


## Decompresses the stream starting at [param offset]. Returns the decompressed
## bytes, or an empty array on failure; check [member failed] to tell that
## apart from a legitimately empty stream.
func decompress(data: PackedByteArray, offset: int) -> PackedByteArray:
	failed = false
	consumed = 0

	var out: PackedByteArray = PackedByteArray()
	var pos: int = offset
	var size: int = data.size()

	while true:
		if pos < 0 or pos >= size:
			return _fail()

		var command: int = data[pos]
		pos += 1
		if command == TERMINATOR:
			consumed = pos - offset
			return out

		var op: int = command >> 5
		var length: int = (command & 0x1F) + 1
		if op == Op.LONG:
			if pos >= size:
				return _fail()
			op = (command >> 2) & 0x07
			length = (((command & 0x03) << 8) | data[pos]) + 1
			pos += 1

		var step: Dictionary = _back_reference(data, out, pos, op, length) \
			if op >= Op.REPEAT else _inline_bytes(data, pos, op, length)
		if step.is_empty():
			return _fail()
		out.append_array(step["bytes"])
		pos = int(step["pos"])

		if out.size() > MAX_OUTPUT:
			return _fail()

	return out


## Literal, iterate, alternate and zero. Empty for a stream that ends inside one.
func _inline_bytes(data: PackedByteArray, pos: int, op: int, length: int) -> Dictionary:
	var size: int = data.size()
	var bytes: PackedByteArray = PackedByteArray()
	match op:
		Op.LITERAL:
			if pos + length > size:
				return {}
			return {"pos": pos + length, "bytes": data.slice(pos, pos + length)}
		Op.ITERATE:
			if pos >= size:
				return {}
			for _i: int in length:
				bytes.append(data[pos])
			return {"pos": pos + 1, "bytes": bytes}
		Op.ALTERNATE:
			if pos + 2 > size:
				return {}
			for i: int in length:
				bytes.append(data[pos + 1] if i & 1 else data[pos])
			return {"pos": pos + 2, "bytes": bytes}
		Op.ZERO:
			bytes.resize(length)
			return {"pos": pos, "bytes": bytes}
	return {}


## Repeat, flipped and reversed. Empty when the stream or the source runs out.
func _back_reference(
	data: PackedByteArray, out: PackedByteArray, pos: int, op: int, length: int
) -> Dictionary:
	var size: int = data.size()
	if pos >= size:
		return {}
	var source: int = 0
	var high: int = data[pos]
	pos += 1
	if high & LONG_OFFSET_MASK:
		source = out.size() - (high & 0x7F) - 1
	else:
		if pos >= size:
			return {}
		source = (high << 8) | data[pos]
		pos += 1
	if source < 0 or source >= out.size():
		return {}
	var table: PackedByteArray = _bit_reversal_table()
	var bytes: PackedByteArray = PackedByteArray()
	for i: int in length:
		var from: int = source - i if op == Op.REVERSED else source + i
		if from < 0 or from >= out.size() + bytes.size():
			return {}
		var value: int = out[from] if from < out.size() else bytes[from - out.size()]
		bytes.append(table[value] if op == Op.FLIPPED else value)
	return {"pos": pos, "bytes": bytes}


## Convenience for callers that only care whether it worked.
static func unpack(data: PackedByteArray, offset: int) -> PackedByteArray:
	return Gen2Lz.new().decompress(data, offset)


func _fail() -> PackedByteArray:
	failed = true
	consumed = 0
	return PackedByteArray()


static func _bit_reversal_table() -> PackedByteArray:
	if not _reversed_bits.is_empty():
		return _reversed_bits

	var table: PackedByteArray = PackedByteArray()
	table.resize(256)
	for value: int in 256:
		var flipped: int = 0
		for bit: int in 8:
			if value & (1 << bit):
				flipped |= 1 << (7 - bit)
		table[value] = flipped
	_reversed_bits = table
	return _reversed_bits
