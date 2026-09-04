class_name Gen2MailPage
extends RefCounted

## `ReadAnyMail` and the ten `Load*MailGFX` routines behind it on the hardware
## tile grid. Each mail type builds its own VRAM window out of one flat 1bpp run
## and then writes a tilemap over it, so the page is two transcribed programs per
## type rather than a picture, which is what makes ten near-identical routines
## readable and lets `tools/checks/mail.gd` sweep every one. The 1bpp run has one
## ink level and the three `LoadMailGFX_Color*` write it into plane 0, plane 1 or
## both, which is why one sheet draws in three shades. PORTRAITMAIL's pic is in
## the buffer rather than a layer, since `PlaceGraphic` writes it into the tilemap.

const TILE: int = Gen2Font.TILE
const COLUMNS: int = 20
const ROWS: int = 18

## `ClearTilemap`'s own fill, which every cell the routine does not write keeps.
const BLANK_TILE: int = Gen2Text.SPACE
## `ld hl, vTiles2 tile $31`, where every routine starts loading, and the second
## destination four of them switch to.
const FIRST_TILE: int = 0x31
const SECOND_TILE: int = 0x3D

## `MailGFXPointers` order, which `MailGFX_PlaceMessage` and `LoadMailPalettes`
## both index: the *MAIL_INDEX constants at the head of `mail_2.asm`.
const FLOWER: int = 0
const SURF: int = 1
const LITEBLUE: int = 2
const PORTRAIT: int = 3
const LOVELY: int = 4
const EON: int = 5
const MORPH: int = 6
const BLUESKY: int = 7
const MUSIC: int = 8
const MIRAGE: int = 9

## The item number each index is reached by, which is `MailGFXPointers`' own
## first column and `MailItems`' order.
const ITEM_NUMBERS: Array[int] = [158, 181, 182, 183, 184, 185, 186, 187, 188, 189]

## Byte offsets into the `gfx/mail.asm` run, one per INCBIN label. The run is
## uncompressed and contiguous, so a label is an offset and a `+ n * TILE_1BPP_
## SIZE` in the source is `+ n * 8` here.
const G_MORPH_DIVIDER: int = 0
const G_GRASS: int = 8
const G_SMALL_POKEBALL: int = 16
const G_MORPH_BORDER: int = 24
const G_SMALL_NOTE: int = 32
const G_WAVE: int = 40
const G_PORTRAIT_UNDERLINE: int = 56
const G_LOVELY_UNDERLINE: int = 64
const G_SMALL_HEART: int = 72
const G_SMALL_SHAPES: int = 80
const G_EON_BORDER_1: int = 88
const G_EON_BORDER_2: int = 104
const G_NATU: int = 112
const G_DRATINI: int = 160
const G_POLIWAG: int = 208
const G_LAPRAS: int = 256
const G_EEVEE: int = 304
const G_DITTO: int = 352
const G_MEW: int = 400
const G_DRAGONITE_SENTRET: int = 544
const G_LARGE_POKEBALL: int = 728
const G_ODDISH: int = 760
const G_LARGE_SHAPES: int = 792
const G_LARGE_HEART: int = 824
const G_MORPH_CORNER: int = 856
const G_LARGE_CIRCLE: int = 888
const G_FLOWER: int = 920
const G_LARGE_NOTE: int = 984
const G_CLOUD: int = 1008
const G_SURF_BORDER: int = 1056
const G_FLOWER_BORDER: int = 1120
const G_LITEBLUE_BORDER: int = 1184
const G_MUSIC_BORDER: int = 1248
const G_LOVELY_BORDER: int = 1280
const G_PORTRAIT_BORDER: int = 1320

## A `gfx` op whose source is -1 continues where the last one stopped, which is
## `de` never being reloaded between two `LoadMailGFX_Color*` calls.
const CONTINUE: int = -1

## Per type, the routine's own loads. `["at", tile]` is `ld hl, vTiles2 tile n`,
## `["gfx", source, bytes, colour]` one `LoadMailGFX_Color*` and
## `["fill", bytes, index]` a `ByteFill` or `MailGFX_GenerateMonochromeTiles
## Color2`, both of which write a constant rather than a picture.
const LOADS: Array = [
	[  # FLOWER_MAIL
		["at", FIRST_TILE],
		["gfx", G_FLOWER_BORDER, 64, 1],
		["gfx", G_ODDISH, 32, 3],
		["gfx", G_FLOWER_BORDER + 48, 8, 2],
		["gfx", G_FLOWER, 32, 1],
		["gfx", CONTINUE, 32, 2],
	],
	[  # SURF_MAIL
		["at", FIRST_TILE],
		["gfx", G_SURF_BORDER, 64, 2],
		["gfx", G_LAPRAS, 48, 3],
		["gfx", G_WAVE, 8, 2],
		["gfx", G_SMALL_SHAPES, 16, 2],
		["gfx", CONTINUE, 16, 1],
		["gfx", G_LARGE_SHAPES, 64, 1],
		["gfx", CONTINUE, 64, 2],
	],
	[  # LITEBLUEMAIL
		["at", FIRST_TILE],
		["gfx", G_LITEBLUE_BORDER, 64, 2],
		["gfx", G_DRATINI, 48, 3],
		["gfx", G_PORTRAIT_UNDERLINE, 8, 2],
		["gfx", G_SMALL_SHAPES, 16, 2],
		["gfx", CONTINUE, 16, 1],
		["gfx", G_LARGE_SHAPES, 64, 1],
		["gfx", CONTINUE, 64, 2],
	],
	[  # PORTRAITMAIL
		["at", FIRST_TILE],
		["gfx", G_PORTRAIT_BORDER, 40, 2],
		["gfx", G_PORTRAIT_UNDERLINE, 8, 2],
		["at", SECOND_TILE],
		["gfx", G_LARGE_POKEBALL, 32, 1],
		["gfx", G_SMALL_POKEBALL, 8, 2],
	],
	[  # LOVELY_MAIL
		["at", FIRST_TILE],
		["gfx", G_LOVELY_BORDER, 40, 2],
		["gfx", G_POLIWAG, 48, 3],
		["gfx", G_LOVELY_UNDERLINE, 8, 2],
		["gfx", G_LARGE_HEART, 32, 2],
		["gfx", G_SMALL_HEART, 8, 1],
	],
	[  # EON_MAIL
		["at", FIRST_TILE],
		["gfx", G_EON_BORDER_1, 8, 2],
		["gfx", G_EON_BORDER_2, 8, 1],
		["gfx", G_EON_BORDER_2, 8, 1],
		["gfx", G_EON_BORDER_1, 8, 2],
		["gfx", G_SURF_BORDER + 48, 8, 2],
		["gfx", G_EEVEE, 48, 3],
		["at", SECOND_TILE],
		["gfx", G_LARGE_CIRCLE, 32, 1],
		["gfx", G_EON_BORDER_2, 8, 2],
	],
	[  # MORPH_MAIL
		["at", FIRST_TILE],
		["fill", 40, 2],
		["gfx", G_MORPH_CORNER + 24, 8, 2],
		["gfx", G_MORPH_CORNER, 8, 2],
		["gfx", G_MORPH_BORDER, 8, 2],
		["gfx", G_EON_BORDER_1, 8, 1],
		["gfx", G_MORPH_DIVIDER, 8, 2],
		["gfx", G_DITTO, 48, 3],
	],
	[  # BLUESKY_MAIL
		["at", FIRST_TILE],
		["gfx", G_EON_BORDER_1, 8, 2],
		["fill", 8, 3],
		["gfx", G_GRASS, 8, 3],
		["gfx", G_DRAGONITE_SENTRET, 184, 3],
		["gfx", G_CLOUD, 48, 1],
		["gfx", G_FLOWER_BORDER + 48, 8, 1],
		["gfx", G_CLOUD, 8, 1],
		["gfx", G_CLOUD + 16, 16, 1],
		["gfx", G_CLOUD + 40, 8, 1],
	],
	[  # MUSIC_MAIL
		["at", FIRST_TILE],
		["gfx", G_MUSIC_BORDER, 32, 2],
		["gfx", G_MORPH_BORDER, 16, 2],
		["gfx", G_NATU, 48, 3],
		["fill", 8, 0],
		["gfx", G_LARGE_NOTE, 24, 1],
		["gfx", G_SMALL_NOTE, 8, 1],
	],
	[  # MIRAGE_MAIL
		["at", FIRST_TILE],
		["fill", 40, 2],
		["gfx", G_GRASS, 8, 2],
		["gfx", G_MEW, 144, 2],
		["gfx", G_LITEBLUE_BORDER + 8, 8, 1],
		["gfx", G_LITEBLUE_BORDER + 48, 8, 1],
	],
]

## `LovelyEonMail_PlaceIcons`, which four routines share.
const ICON_PLACES: Array = [
	["g2", 2, 2, 0x3D], ["g2", 16, 2, 0x3D], ["g2", 9, 4, 0x3D],
	["g2", 2, 11, 0x3D], ["g2", 6, 12, 0x3D], ["g2", 12, 11, 0x3D],
	["put", 5, 4, 0x41], ["put", 6, 2, 0x41], ["put", 12, 4, 0x41],
	["put", 14, 2, 0x41], ["put", 3, 13, 0x41], ["put", 9, 11, 0x41],
	["put", 16, 12, 0x41],
]

## `DrawMailBorder` and `DrawMailBorder2`, the two frames the routines share.
## Each is the same eight writes with different corners: the first gives every
## corner its own tile, the second reuses $31 for all four.
const BORDER: Array = [
	["put", 0, 0, 0x31], ["row", 1, 0, 0x32, 18], ["put", 19, 0, 0x33],
	["col", 0, 1, 0x34, 16], ["put", 0, 17, 0x36], ["row", 1, 17, 0x37, 18],
	["col", 19, 1, 0x35, 16], ["put", 19, 17, 0x38],
]
const BORDER2: Array = [
	["put", 0, 0, 0x31], ["row", 1, 0, 0x32, 18], ["put", 19, 0, 0x31],
	["col", 0, 1, 0x33, 16], ["put", 0, 17, 0x31], ["row", 1, 17, 0x34, 18],
	["col", 19, 1, 0x35, 16], ["put", 19, 17, 0x31],
]

## Per type, the routine's own tilemap writes. `row`/`col` are
## `Mail_DrawRowLoop` and `Mail_DrawLeftRightBorder`, `altrow`/`altcol` are
## `Mail_PlaceAlternatingRow`/`Column` and take the number of pairs the source
## counts (`ld b, 18 / 2`), `seq` is `Mail_Place6TileRow`, `g2` and `g3` are the
## two `Mail_Draw*Graphic` blocks, and `pic` is `PrepMonFrontpic`.
const PLACES: Array = [
	[  # FLOWER_MAIL
		["border"], ["row", 2, 15, 0x3D, 16],
		["g2", 16, 13, 0x39], ["g2", 2, 13, 0x39],
		["g2", 2, 2, 0x3E], ["g2", 5, 3, 0x3E], ["g2", 10, 2, 0x3E],
		["g2", 16, 3, 0x3E], ["g2", 5, 11, 0x3E], ["g2", 16, 10, 0x3E],
		["g2", 3, 4, 0x42], ["g2", 12, 3, 0x42], ["g2", 14, 2, 0x42],
		["g2", 2, 10, 0x42], ["g2", 14, 11, 0x42],
	],
	[  # SURF_MAIL
		["border"], ["row", 2, 15, 0x3F, 16], ["g3", 15, 14, 0x39],
		["g2", 2, 2, 0x44], ["g2", 15, 11, 0x44],
		["g2", 3, 12, 0x4C], ["g2", 15, 2, 0x4C], ["g2", 6, 3, 0x50],
		["put", 13, 2, 0x40], ["put", 6, 14, 0x40],
		["put", 4, 5, 0x41], ["put", 17, 5, 0x41], ["put", 13, 12, 0x41],
		["put", 9, 2, 0x42], ["put", 14, 5, 0x42], ["put", 3, 10, 0x42],
		["put", 6, 11, 0x43],
	],
	# LITEBLUEMAIL: `FinishLoadingSurfLiteBlueMailGFX` is one routine, so the
	# two types differ in their sheets and in nothing they draw.
	[
		["border"], ["row", 2, 15, 0x3F, 16], ["g3", 15, 14, 0x39],
		["g2", 2, 2, 0x44], ["g2", 15, 11, 0x44],
		["g2", 3, 12, 0x4C], ["g2", 15, 2, 0x4C], ["g2", 6, 3, 0x50],
		["put", 13, 2, 0x40], ["put", 6, 14, 0x40],
		["put", 4, 5, 0x41], ["put", 17, 5, 0x41], ["put", 13, 12, 0x41],
		["put", 9, 2, 0x42], ["put", 14, 5, 0x42], ["put", 3, 10, 0x42],
		["put", 6, 11, 0x43],
	],
	[  # PORTRAITMAIL
		["border2"], ["row", 8, 15, 0x36, 10], ["icons"], ["pic", 1, 10],
	],
	[  # LOVELY_MAIL
		["border2"], ["row", 2, 15, 0x3C, 16], ["g3", 15, 14, 0x36], ["icons"],
	],
	[  # EON_MAIL
		["altrow", 0, 0, 0x31, 9], ["altrow", 1, 17, 0x31, 9],
		["altcol", 0, 1, 0x33, 8], ["altcol", 19, 0, 0x33, 8],
		["row", 2, 15, 0x35, 16], ["g3", 15, 14, 0x36], ["icons"],
	],
	[  # MORPH_MAIL
		["border2"],
		["g2", 1, 1, 0x31], ["g2", 17, 15, 0x31],
		["put", 1, 3, 0x31], ["put", 3, 1, 0x31],
		["put", 16, 16, 0x31], ["put", 18, 14, 0x31],
		["put", 1, 4, 0x36], ["put", 2, 3, 0x36],
		["put", 3, 2, 0x36], ["put", 4, 1, 0x36],
		["put", 15, 16, 0x37], ["put", 16, 15, 0x37],
		["put", 17, 14, 0x37], ["put", 18, 13, 0x37],
		["row", 2, 15, 0x38, 14],
		["row", 2, 11, 0x39, 16], ["row", 2, 5, 0x39, 16],
		["row", 6, 1, 0x3A, 13], ["row", 1, 16, 0x3A, 13],
		["g3", 3, 13, 0x3B],
	],
	[  # BLUESKY_MAIL
		["row", 0, 0, 0x31, 20], ["col", 0, 1, 0x31, 16], ["col", 19, 1, 0x31, 16],
		["row", 0, 17, 0x32, 20], ["row", 0, 16, 0x33, 20],
		# Three `Mail_Place6TileRow`s in a row without reloading `a`, so each
		# starts where the last stopped: $34, then $3a, then $40.
		["seq", 2, 2, 0x34, 6], ["seq", 3, 3, 0x3A, 6], ["seq", 4, 4, 0x40, 6],
		["put", 9, 4, BLANK_TILE],  # `dec hl / ld [hl], $7f`: the last tile of the third row is blanked.
		["g2", 15, 14, 0x45],
		["put", 15, 16, 0x49], ["put", 16, 16, 0x4A],
		["g3", 12, 1, 0x4B], ["g3", 15, 4, 0x4B],
		["row", 2, 11, 0x51, 16], ["g2", 10, 3, 0x52],
	],
	[  # MUSIC_MAIL
		["altrow", 0, 0, 0x31, 9], ["altrow", 1, 17, 0x31, 9],
		["altcol", 0, 1, 0x33, 8], ["altcol", 19, 0, 0x33, 8],
		["altrow", 2, 15, 0x35, 7], ["g3", 15, 14, 0x37], ["icons"],
	],
	[  # MIRAGE_MAIL
		["border2"], ["row", 1, 16, 0x36, 18], ["g3", 15, 14, 0x37],
		["put", 15, 16, 0x38], ["put", 16, 16, 0x39],
		["altrow", 1, 1, 0x3F, 9],
		["altcol", 0, 2, 0x41, 7], ["altcol", 19, 2, 0x43, 7],
		["put", 0, 1, 0x45], ["put", 19, 1, 0x46],
		["put", 0, 16, 0x47], ["put", 19, 16, 0x48],
		["row", 2, 5, 0x49, 16], ["row", 2, 11, 0x4A, 16],
	],
]

## `MailGFX_PlaceMessage`'s `hlcoord 2, 7` for the message and its three author
## columns, which are the type's own: PORTRAITMAIL prints at 8, MORPH_MAIL at 6
## and everything else at 5.
const MESSAGE_AT: Vector2i = Vector2i(2, 7)
const AUTHOR_ROW: int = 14
const AUTHOR_COLUMN: int = 5
const AUTHOR_COLUMN_PORTRAIT: int = 8
const AUTHOR_COLUMN_MORPH: int = 6

## `PrepMonFrontpic`'s `hlcoord 1, 10` and its seven-tile cell. `wBoxAlignment`
## is 1 there, so the picture is mirrored and `PlaceGraphic.right` lays its
## columns from the other side; the two compose into a plain horizontal flip
## (see [method Gen2PicImage.x_flipped_indices]).
const PIC_AT: Vector2i = Vector2i(1, 10)
const PIC_TILES: int = 7

var font: Gen2Font = null

## PORTRAITMAIL alone needs the cache at draw time, for the picture the routine
## puts under its frame.
var _data: GameData = null

## The `gfx/mail.asm` run as one index strip, `Gen2Layout.MAIL_GFX_TILES` wide.
var _strip: PackedByteArray = PackedByteArray()
## The VRAM window the last [method draw] built, tile number to 64 indices,
## and the tilemap it wrote over it. Both are kept so `tools/checks/mail.gd` can
## ask what a type loaded and what it placed without re-running the program.
var _vram: Dictionary = {}
var _map: PackedInt32Array = PackedInt32Array()
var _cursor_tile: int = FIRST_TILE
var _cursor_row: int = 0
var _source: int = 0


static func from_data(data: GameData) -> Gen2MailPage:
	var glyphs: Gen2Font = Gen2Font.from_data(data)
	if glyphs == null or data == null:
		return null
	var out := Gen2MailPage.new()
	out.font = glyphs
	out._data = data
	out._strip = data.tile_indices("mail_gfx")
	return out


func ready() -> bool:
	return font != null \
		and _strip.size() == Gen2Layout.MAIL_GFX_TILES * TILE * TILE


## Which `MailGFXPointers` row [param item] reaches. The source walks the table
## and falls through to the first entry when nothing matches; every item that
## reaches this screen is in the table, so the fallback is the same answer
## without reproducing the out-of-range palette index the walk leaves behind.
static func index_for_item(item: int) -> int:
	var found: int = ITEM_NUMBERS.find(item)
	return found if found >= 0 else FLOWER


## Whether this type draws a Pokemon into the page, which is PORTRAITMAIL alone.
static func has_pic(index: int) -> bool:
	return index == PORTRAIT


## The whole 160x144 page as palette indices, for [param mail] as it stands.
func draw(mail: Gen2SaveMail) -> PackedByteArray:
	var index: int = index_for_item(mail.item if mail != null else 0)
	_build_vram(index)

	var map: PackedInt32Array = PackedInt32Array()
	map.resize(COLUMNS * ROWS)
	map.fill(BLANK_TILE)
	_place(map, PLACES[index])
	_message(map, mail, index)
	_map = map
	var indices: PackedByteArray = _compose(map)
	if has_pic(index):
		_blend_pic(indices, mail)
	return indices


## The tile numbers the last [method draw] loaded, in order.
func loaded_tiles() -> Array:
	var out: Array = _vram.keys()
	out.sort()
	return out


## The distinct tile numbers the last [method draw] placed on the tilemap.
func placed_tiles() -> Array:
	var seen: Dictionary = {}
	for tile: int in _map:
		seen[tile] = true
	var out: Array = seen.keys()
	out.sort()
	return out


## One cell of the last [method draw]'s tilemap, for a check reading back what
## the message and the author printed.
func map_tile(at: Vector2i) -> int:
	if at.x < 0 or at.x >= COLUMNS or at.y < 0 or at.y >= ROWS:
		return -1
	return _map[at.y * COLUMNS + at.x]


## `MailGFXPointers`' own walk, so a host knows which
## `LoadMailPalettes.MailPals` row to draw the page with.
static func palette_index(mail: Gen2SaveMail) -> int:
	return index_for_item(mail.item if mail != null else 0)


## `MailGFX_PlaceMessage`: the buffer through one `PlaceString` at
## `hlcoord 2, 7`, whose `<NEXT>` drops two rows, then the author on row 14.
func _message(map: PackedInt32Array, mail: Gen2SaveMail, index: int) -> void:
	if mail == null:
		return
	var at: Vector2i = MESSAGE_AT
	var column: int = 0
	for code: int in mail.message:
		if code == Gen2Text.TERMINATOR:
			break
		if code == Gen2SaveMail.LINE_BREAK:
			at.y += 2
			column = 0
			continue
		_put(map, Vector2i(at.x + column, at.y), code)
		column += 1
	if mail.author.is_empty():
		return
	var author_x: int = AUTHOR_COLUMN
	if index == PORTRAIT:
		author_x = AUTHOR_COLUMN_PORTRAIT
	elif index == MORPH:
		author_x = AUTHOR_COLUMN_MORPH
	var codes: PackedByteArray = Gen2Text.encode(mail.author)
	for offset: int in codes.size():
		_put(map, Vector2i(author_x + offset, AUTHOR_ROW), codes[offset])


## One type's `LoadMailGFX_Color*` run into a fresh VRAM window.
func _build_vram(index: int) -> void:
	_vram = {}
	_cursor_tile = FIRST_TILE
	_cursor_row = 0
	_source = 0
	for raw_op: Variant in LOADS[index]:
		var op: Array = raw_op
		match String(op[0]):
			"at":
				_cursor_tile = int(op[1])
				_cursor_row = 0
			"gfx":
				if int(op[1]) != CONTINUE:
					_source = int(op[1])
				for _row: int in int(op[2]):
					_write_row(_source_row(_source), int(op[3]))
					_source += 1
			"fill":
				for _row: int in int(op[1]):
					_write_row(PackedByteArray(), int(op[2]), true)


## One 1bpp byte out of the run, as the eight pixels it lights. The strip is
## already decoded, so a lit pixel is [constant PokeTiles.INK] and the row is
## read off it rather than out of the byte.
func _source_row(byte_offset: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(TILE)
	@warning_ignore("integer_division")
	var tile: int = byte_offset / TILE
	var row: int = byte_offset % TILE
	var width: int = Gen2Layout.MAIL_GFX_TILES * TILE
	if tile < 0 or tile >= Gen2Layout.MAIL_GFX_TILES:
		return out
	for column: int in TILE:
		out[column] = _strip[row * width + tile * TILE + column]
	return out


## One row of the write cursor's tile, advancing it and stepping to the next
## tile every eight rows. [param constant_fill] writes [param colour] over the
## whole row, which is what a `ByteFill` and the monochrome generator do.
func _write_row(source: PackedByteArray, colour: int, constant_fill: bool = false) -> void:
	if not _vram.has(_cursor_tile):
		var blank := PackedByteArray()
		blank.resize(TILE * TILE)
		_vram[_cursor_tile] = blank
	var cell: PackedByteArray = _vram[_cursor_tile]
	for column: int in TILE:
		if constant_fill:
			cell[_cursor_row * TILE + column] = colour
		elif column < source.size() and source[column] == PokeTiles.INK:
			cell[_cursor_row * TILE + column] = colour
	_vram[_cursor_tile] = cell
	_cursor_row += 1
	if _cursor_row >= TILE:
		_cursor_row = 0
		_cursor_tile += 1


func _place(map: PackedInt32Array, program: Array) -> void:
	for raw_op: Variant in program:
		var op: Array = raw_op
		match String(op[0]):
			"border":
				_place(map, BORDER)
			"border2":
				_place(map, BORDER2)
			"icons":
				_place(map, ICON_PLACES)
			"put":
				_put(map, Vector2i(int(op[1]), int(op[2])), int(op[3]))
			"row":
				for step: int in int(op[4]):
					_put(map, Vector2i(int(op[1]) + step, int(op[2])), int(op[3]))
			"col":
				for step: int in int(op[4]):
					_put(map, Vector2i(int(op[1]), int(op[2]) + step), int(op[3]))
			"seq":
				for step: int in int(op[4]):
					_put(map, Vector2i(int(op[1]) + step, int(op[2])), int(op[3]) + step)
			"altrow":
				_alternating(map, op, true)
			"altcol":
				_alternating(map, op, false)
			"g2":
				_block(map, op, 2)
			"g3":
				_block(map, op, 3)
			"pic":
				## `PrepMonFrontpic` writes tiles the page has no picture for:
				## the pic is its host's own layer over [method pic_position].
				pass


## `Mail_PlaceAlternatingRow` and `..._Column`: `b` pairs of the tile and the
## one after it, then one more of the tile itself, so a run is `2 * b + 1` long.
func _alternating(map: PackedInt32Array, op: Array, horizontal: bool) -> void:
	var at := Vector2i(int(op[1]), int(op[2]))
	var tile: int = int(op[3])
	var step := Vector2i(1, 0) if horizontal else Vector2i(0, 1)
	for pair: int in int(op[4]):
		_put(map, at, tile)
		_put(map, at + step, tile + 1)
		at += step * 2
	_put(map, at, tile)


## `Mail_Draw2x2Graphic` and `Mail_Draw3x2Graphic`, both of which lay their
## tiles left to right and then top to bottom from the tile they are given.
func _block(map: PackedInt32Array, op: Array, width: int) -> void:
	var at := Vector2i(int(op[1]), int(op[2]))
	var tile: int = int(op[3])
	for row: int in 2:
		for column: int in width:
			_put(map, at + Vector2i(column, row), tile)
			tile += 1


## `_PrepMonFrontpic` into the page's own indices: the picture is mirrored, and
## a pic smaller than the seven-tile cell is padded the way
## `LoadOrientedFrontpic` pads one, from the right rather than the left because
## the alignment is set. Its own palette is not: `LoadMailPalettes` has already
## loaded the mail's, so the Pokemon is drawn in the mail's four colours.
func _blend_pic(indices: PackedByteArray, mail: Gen2SaveMail) -> void:
	if _data == null or mail == null:
		return
	var pic: Dictionary = _data.species_pic(mail.species)
	if pic.is_empty():
		return
	var cell: Dictionary = Gen2PicImage.atlas_cell(
		_data.atlas_indices(pic["atlas"]), _data.atlas(pic["atlas"]), pic
	)
	if cell.is_empty():
		return
	var width: int = int(cell["width"])
	var height: int = int(cell["height"])
	var pixels: PackedByteArray = Gen2PicImage.x_flipped_indices(cell["indices"], width)
	@warning_ignore("integer_division")
	var pad: int = Gen2PicImage.frontpic_pad_columns(width / TILE, true)
	var origin := Vector2i(
		(PIC_AT.x + pad) * TILE, PIC_AT.y * TILE + PIC_TILES * TILE - height
	)
	var page_width: int = COLUMNS * TILE
	for y: int in height:
		for x: int in width:
			var to_x: int = origin.x + x
			var to_y: int = origin.y + y
			if to_x < 0 or to_x >= page_width or to_y < 0 or to_y >= ROWS * TILE:
				continue
			indices[to_y * page_width + to_x] = pixels[y * width + x]


func _put(map: PackedInt32Array, at: Vector2i, tile: int) -> void:
	if at.x < 0 or at.x >= COLUMNS or at.y < 0 or at.y >= ROWS:
		return
	map[at.y * COLUMNS + at.x] = tile


## Resolves every tile number to pixels: the window this type just built, and
## the font for everything the message and the author printed.
func _compose(map: PackedInt32Array) -> PackedByteArray:
	var width: int = COLUMNS * TILE
	var indices := PackedByteArray()
	indices.resize(width * ROWS * TILE)
	if font == null:
		return indices
	for row: int in ROWS:
		for column: int in COLUMNS:
			var tile: int = map[row * COLUMNS + column]
			if _vram.has(tile):
				var cell: PackedByteArray = _vram[tile]
				for y: int in TILE:
					for x: int in TILE:
						indices[(row * TILE + y) * width + column * TILE + x] = cell[y * TILE + x]
			else:
				font.draw_code(tile, indices, width, column * TILE, row * TILE)
	return indices
