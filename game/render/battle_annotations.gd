class_name Gen2BattleAnnotations
extends RefCounted

## What a registered battle-information provider draws on the hardware
## interface, validated once and drawn once.
##
## The grid is the cartridge's own screen in tiles, so a placement is said in the
## same coordinates `hlcoord` is and lands in the same cells whichever renderer
## is underneath: the annotations are interface, and the interface is 20x18
## whether the battle behind it is the built-in arena or a native-layer view.
##
## A mod supplies a string or a tile and nothing else. Where a cell may be drawn,
## what a tile's bytes mean, which provider owns a cell and when the layer is
## hidden are all the host's.

const TILE: int = Gen2Font.TILE
const COLUMNS: int = Gen2Screen.WIDTH / TILE
const ROWS: int = Gen2Screen.HEIGHT / TILE

## The two tile shapes a placement may carry, told apart by length rather than
## by a second key: eight bytes is 1bpp, one byte a row with bit 7 leftmost, the
## way the cartridge stores a font glyph; sixty-four is one palette index a
## pixel, the way [Gen2PicImage] reads a buffer.
const BYTES_1BPP: int = 8
const PIXELS_INDEXED: int = TILE * TILE

## What a set bit of a 1bpp tile is drawn in, which is what the font's own glyphs
## are decoded to, so a symbol a mod supplies is the same ink as the text beside
## it. It is also the highest index the hardware's four-colour palette has, which
## is what an indexed tile is checked against.
const INK_INDEX: int = Gen2Tiles.INK
const MAX_INDEX: int = Gen2Tiles.INK

## The interface's own font. A provider writes strings and the host writes them
## the way every other box does.
const FONT: StringName = Gen2Text.FONT_MAIN

var font: Gen2Font = null


static func from_data(data: GameData) -> Gen2BattleAnnotations:
	var glyphs: Gen2Font = Gen2Font.from_data(data)
	if glyphs == null:
		return null
	var out := Gen2BattleAnnotations.new()
	out.font = glyphs
	return out


## [param placement] as the host will keep it, or `{}` when it cannot be drawn.
##
## Refused rather than clipped: a symbol half off the screen, or a stage summary
## running through the border, is worse than one the player never sees, and a
## provider that is told nothing about the refusal would keep sending it.
static func validate(placement: Dictionary) -> Dictionary:
	var at_value: Variant = placement.get("at", null)
	if at_value is not Vector2i:
		return {}
	var at: Vector2i = at_value
	if at.x < 0 or at.y < 0 or at.x >= COLUMNS or at.y >= ROWS:
		return {}
	if placement.has("tile"):
		var tile: PackedByteArray = _tile_bytes(placement["tile"])
		if tile.is_empty():
			return {}
		return {"at": at, "tile": tile}
	var text: String = String(placement.get("text", ""))
	if text.is_empty():
		return {}
	var codes: PackedByteArray = Gen2Font.fit(text, COLUMNS - at.x, FONT)
	if codes.is_empty():
		return {}
	return {"at": at, "text": text, "width": codes.size()}


## Which cells [param placement] occupies, for the ownership check. A validated
## text placement carries its own tile count, so the width is measured once.
static func cells(placement: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var at: Vector2i = placement.get("at", Vector2i.ZERO)
	for column: int in maxi(int(placement.get("width", 1)), 1):
		out.append(at + Vector2i(column, 0))
	return out


## Draws [param placements] into [param indices], a buffer [param width] pixels
## across. Already validated, so nothing here can land outside the screen.
func draw(placements: Array, indices: PackedByteArray, width: int) -> void:
	if font == null:
		return
	for placement: Dictionary in placements:
		var at: Vector2i = placement.get("at", Vector2i.ZERO)
		if placement.has("tile"):
			_draw_tile(placement["tile"], indices, width, at)
			continue
		font.draw_text(
			String(placement.get("text", "")), indices, width,
			at.x * TILE, at.y * TILE, FONT, COLUMNS - at.x
		)


func _draw_tile(tile: PackedByteArray, indices: PackedByteArray, width: int, at: Vector2i) -> void:
	var one_bit: bool = tile.size() == BYTES_1BPP
	for row: int in TILE:
		var start: int = (at.y * TILE + row) * width + at.x * TILE
		if start < 0 or start + TILE > indices.size():
			continue
		for column: int in TILE:
			var value: int = (
				INK_INDEX if (tile[row] & (0x80 >> column)) != 0 else 0
			) if one_bit else tile[row * TILE + column]
			indices[start + column] = value


## The bytes of a tile a mod supplied, or an empty array when it is neither
## shape. An [Array] is accepted beside a [PackedByteArray] because a tile
## written out as a literal in a mod's source is one.
static func _tile_bytes(value: Variant) -> PackedByteArray:
	var out := PackedByteArray()
	if value is PackedByteArray:
		out = value
	elif value is Array:
		for entry: Variant in value as Array:
			if entry is not int and entry is not float:
				return PackedByteArray()
			var number: int = int(entry)
			if number < 0 or number > 0xFF:
				return PackedByteArray()
			out.append(number)
	else:
		return PackedByteArray()
	if out.size() == BYTES_1BPP:
		return out
	if out.size() != PIXELS_INDEXED:
		return PackedByteArray()
	for index: int in out:
		if index > MAX_INDEX:
			return PackedByteArray()
	return out
