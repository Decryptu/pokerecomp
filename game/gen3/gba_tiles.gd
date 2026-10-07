class_name GbaTiles
extends RefCounted

const TILE_BYTES: int = 32
const TILE_SIDE: int = 8

## 4bpp tiles and their pixels both run row-major, low nibble first.
static func decode(data: PackedByteArray, columns: int, rows: int, offset: int = 0) -> PackedByteArray:
	if columns <= 0 or rows <= 0 or offset < 0 \
		or offset + columns * rows * TILE_BYTES > data.size():
		return PackedByteArray()
	var width: int = columns * TILE_SIDE
	var out := PackedByteArray()
	out.resize(width * rows * TILE_SIDE)
	for tile_y: int in rows:
		for tile_x: int in columns:
			var tile: int = offset + (tile_y * columns + tile_x) * TILE_BYTES
			for y: int in TILE_SIDE:
				for pair: int in (TILE_SIDE >> 1):
					var byte: int = data[tile + y * 4 + pair]
					var to: int = (tile_y * TILE_SIDE + y) * width + tile_x * TILE_SIDE + pair * 2
					out[to] = byte & 15
					out[to + 1] = byte >> 4
	return out
