extends RefCounted

var _r: RefCounted = null

## Verifies mail against freshly imported real caches, in all three games.
##
## Expected values come from the pinned pokecrystal and pokegold sources:
## data/items/mail_items.asm's MailItems, data/text/mail_input_chars.asm's two
## keyboards, gfx/mail/mail.pal, and the ten Load*MailGFX routines in
## engine/pokemon/mail_2.asm.
##
## The pins here are counted off the asm rather than read from
## [Gen2MailPage]'s own tables, so a mistranscribed byte count or tile number is
## a failure instead of an agreement: LOADED_RANGES is what each routine's
## `ld c, n * TILE_1BPP_SIZE` calls add up to, and every tile a routine places
## has to fall inside its own range.
##
##   Godot --headless --path . -s res://tools/validate.gd -- mail

## `MailItems`, which is also [constant Gen2HeldItem.MAIL_ITEMS]' pin.
const EXPECTED_ITEMS: Array[int] = [158, 181, 182, 183, 184, 185, 186, 187, 188, 189]

## The two mail keyboards' symbol rows by cursor column, which is the part of
## the block a plausible neighbouring run of text would not reproduce.
## Uppercase row 4 is PK MN PO KE é ♂ ♀ ¥ … ×; lowercase row 2 ends . - / and
## row 4 opens on the two quotation marks.
const EXPECTED_SYMBOL_ROWS: Array = [
	# MailEntry_Uppercase row 2: U to Z, a blank, then , ? !
	[0, 2, [0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x7F, 0xF4, 0xE6, 0xE7]],
	# row 4: PK MN PO KE é ♂ ♀ ¥ … ×
	[0, 4, [0xE1, 0xE2, 0x70, 0x71, 0xEA, 0xEF, 0xF5, 0xF0, 0x75, 0xF1]],
	# MailEntry_Lowercase row 2: u to z, a blank, then . - /
	[1, 2, [0xB4, 0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0x7F, 0xE8, 0xE3, 0xF3]],
	# row 4: the two quotation marks, [ ] ' : ; and three blanks
	[1, 4, [0x72, 0x73, 0x9E, 0x9F, 0xE0, 0x9C, 0x9D, 0x7F, 0x7F, 0x7F]],
]

## `gfx/mail/mail.pal`'s first colour per row, encoded, and the black every row
## ends on.
const EXPECTED_PALETTE_FIRST: Array[int] = [
	0x2FF4, 0x7E8F, 0x7E38, 0x473F, 0x7F53, 0x727F, 0x5E33, 0x7F47, 0x57F5, 0x7F47,
]

## Per mail type, the VRAM runs its routine fills, counted off its own
## `LoadMailGFX_Color*` byte counts: eight bytes is one tile, and a routine that
## reloads `hl` opens a second run. `[first, last]` inclusive.
const LOADED_RANGES: Array = [
	[[0x31, 0x45]],              # FLOWER_MAIL: 8 + 4 + 1 + 4 + 4 tiles
	[[0x31, 0x53]],              # SURF_MAIL: 8 + 6 + 1 + 2 + 2 + 8 + 8
	[[0x31, 0x53]],              # LITEBLUEMAIL: the same tail, its own head
	[[0x31, 0x36], [0x3D, 0x41]],# PORTRAITMAIL: 5 + 1, then 4 + 1 at $3d
	[[0x31, 0x41]],              # LOVELY_MAIL: 5 + 6 + 1 + 4 + 1
	[[0x31, 0x3B], [0x3D, 0x41]],# EON_MAIL: 5 + 6, then 4 + 1 at $3d
	[[0x31, 0x40]],              # MORPH_MAIL: 5 generated + 5 + 6
	[[0x31, 0x55]],              # BLUESKY_MAIL: 1 + 1 + 1 + 23 + 6 + 1 + 1 + 2 + 1
	[[0x31, 0x41]],              # MUSIC_MAIL: 4 + 2 + 6 + 1 + 3 + 1
	[[0x31, 0x4A]],              # MIRAGE_MAIL: 5 generated + 1 + 18 + 1 + 1
]

## A message that fills the first line exactly, so the page has to put the break
## in the right place for the second line to start where it should. No "PK" or
## "MN" in it: `Gen2Text.encode` folds either into one code, and a sixteen-letter
## line that encodes to fifteen bytes would not reach the break at all.
const SAMPLE_LINE_1: String = "AAAABBBBCCCCDDDD"
const SAMPLE_LINE_2: String = "QRSTUV"
const SAMPLE_AUTHOR: String = "GOLD"

var _blocks: Dictionary = {}
var _palettes: Dictionary = {}
var _items: Dictionary = {}


func run(r: RefCounted) -> void:
	_r = r
	_r.each_game(func() -> void:
		_verify_items()
		_verify_keyboards()
		_verify_palettes()
		_verify_pages()
	)
	_verify_identical()


## `MailItems` against the number list `ItemIsMail`'s only caller here reads.
func _verify_items() -> void:
	var items: Array = _r.data.mail_items()
	if not _r.check(
		items.size() == EXPECTED_ITEMS.size(),
		"MailItems has %d entries, not the pinned %d." % [items.size(), EXPECTED_ITEMS.size()]
	):
		return
	for index: int in items.size():
		_r.check(
			int(items[index]) == EXPECTED_ITEMS[index],
			"MailItems entry %d is %d, not %d." % [index, int(items[index]), EXPECTED_ITEMS[index]]
		)
		_r.check(
			Gen2HeldItem.is_mail(int(items[index])),
			"item %d is in MailItems and Gen2HeldItem.is_mail refuses it." % int(items[index])
		)
	_r.check(
		not Gen2HeldItem.is_mail(0),
		"Gen2HeldItem.is_mail answers yes for no item at all."
	)
	_items[_r.game_id] = items.duplicate()


## The two keyboards' shape, letters, symbol rows and command rows.
func _verify_keyboards() -> void:
	var flat: Array = []
	for table: int in RomLayout.MAIL_INPUT_TABLES:
		var rows: Array = _r.data.name_input_chars(
			Gen2NamingScreen.Keyboard.MAIL_UPPER + table
		)
		if not _r.check(
			rows.size() == RomLayout.MAIL_INPUT_TABLE_ROWS,
			"mail table %d has %d rows, not %d." % [
				table, rows.size(), RomLayout.MAIL_INPUT_TABLE_ROWS,
			]
		):
			continue
		for row: Array in rows:
			_r.check(
				row.size() == RomLayout.MAIL_INPUT_ROW_BYTES,
				"mail table %d has a %d-byte row, not %d." % [
					table, row.size(), RomLayout.MAIL_INPUT_ROW_BYTES,
				]
			)
			flat.append_array(row)
		# Rows 0 and 1 spell the first twenty letters ten at a time.
		var first: int = RomLayout.MAIL_INPUT_UPPER_A if table == 0 \
			else RomLayout.MAIL_INPUT_LOWER_A
		for row: int in 2:
			for column: int in RomLayout.MAIL_INPUT_COLUMNS:
				var expected: int = first + row * RomLayout.MAIL_INPUT_COLUMNS + column
				var stored: int = _cell(rows, row, column)
				_r.check(
					stored == expected,
					"mail table %d cell (%d,%d) is $%02X, not $%02X." % [
						table, row, column, stored, expected,
					]
				)
		var command: Array[int] = RomLayout.MAIL_INPUT_COMMAND_UPPER if table == 0 \
			else RomLayout.MAIL_INPUT_COMMAND_LOWER
		_r.check(
			Array(rows[RomLayout.MAIL_INPUT_TABLE_ROWS - 1]) == Array(command),
			"mail table %d has no command row." % table
		)
	for entry: Array in EXPECTED_SYMBOL_ROWS:
		var rows: Array = _r.data.name_input_chars(
			Gen2NamingScreen.Keyboard.MAIL_UPPER + int(entry[0])
		)
		if rows.size() != RomLayout.MAIL_INPUT_TABLE_ROWS:
			continue
		var codes: Array = entry[2]
		for column: int in codes.size():
			var stored: int = _cell(rows, int(entry[1]), column)
			_r.check(
				stored == int(codes[column]),
				"mail table %d cell (%d,%d) is $%02X, not $%02X." % [
					int(entry[0]), int(entry[1]), column, stored, int(codes[column]),
				]
			)
	_r.check(
		_r.data.name_input_chars(Gen2NamingScreen.Keyboard.size()).is_empty(),
		"a seventh keyboard was read out of a six-table block."
	)
	_blocks[_r.game_id] = flat


func _cell(rows: Array, row: int, column: int) -> int:
	var codes: Array = rows[row]
	var at: int = column * RomLayout.NAME_INPUT_COLUMN_STRIDE
	return int(codes[at]) if at < codes.size() else -1


## `LoadMailPalettes.MailPals`: four colours a row, the first pinned and the
## last black.
func _verify_palettes() -> void:
	var stored: Array = []
	for index: int in RomLayout.MAIL_PALETTE_COUNT:
		var colours: PackedColorArray = _r.data.mail_palette(index)
		if not _r.check(
			colours.size() == RomLayout.MAIL_PALETTE_COLOURS,
			"mail palette %d has %d colours, not %d." % [
				index, colours.size(), RomLayout.MAIL_PALETTE_COLOURS,
			]
		):
			continue
		var expected: Color = Gen2Palette.from_packed(EXPECTED_PALETTE_FIRST[index])
		_r.check(
			colours[0].is_equal_approx(expected),
			"mail palette %d opens on %s, not %s." % [index, colours[0], expected]
		)
		_r.check(
			colours[RomLayout.MAIL_PALETTE_COLOURS - 1].is_equal_approx(Color.BLACK),
			"mail palette %d does not end in black." % index
		)
		for colour: Color in colours:
			stored.append(colour)
	_palettes[_r.game_id] = stored


## Every type's page: the run its routine loads, that nothing is placed outside
## it, and that the message and the author land where `MailGFX_PlaceMessage`
## puts them.
func _verify_pages() -> void:
	var page: Gen2MailPage = Gen2MailPage.from_data(_r.data)
	if not _r.check(page != null and page.ready(), "the mail graphics sheet is missing."):
		return
	for index: int in EXPECTED_ITEMS.size():
		var mail: Gen2SaveMail = _sample(EXPECTED_ITEMS[index])
		var pixels: PackedByteArray = page.draw(mail)
		_r.check(
			pixels.size() == Gen2Screen.WIDTH * Gen2Screen.HEIGHT,
			"mail %d drew %d pixels, not a whole screen." % [index, pixels.size()]
		)
		_r.check(
			Gen2MailPage.index_for_item(EXPECTED_ITEMS[index]) == index,
			"item %d does not reach mail type %d." % [EXPECTED_ITEMS[index], index]
		)

		var wanted: Array = []
		for span: Variant in LOADED_RANGES[index]:
			for tile: int in range(int((span as Array)[0]), int((span as Array)[1]) + 1):
				wanted.append(tile)
		_r.check(
			page.loaded_tiles() == wanted,
			"mail %d loaded %s, not the pinned run %s." % [
				index, _span(page.loaded_tiles()), _span(wanted),
			]
		)
		for tile: int in page.placed_tiles():
			# Only the mail window is the routine's; below it and from the blank
			# up is the font, which the message and the author print through.
			if tile < Gen2MailPage.FIRST_TILE or tile >= Gen2Text.SPACE:
				continue
			_r.check(
				wanted.has(tile),
				"mail %d places tile $%02X, which its routine never loads." % [index, tile]
			)

		var at: Vector2i = Gen2MailPage.MESSAGE_AT
		_r.check(
			page.map_tile(at) == Gen2Text.encode(SAMPLE_LINE_1)[0],
			"mail %d does not print the message at %s." % [index, at]
		)
		## `<NEXT>` drops two rows at the string's own starting column, so the
		## second line opens under the first rather than beside it.
		_r.check(
			page.map_tile(at + Vector2i(0, 2)) == Gen2Text.encode(SAMPLE_LINE_2)[0],
			"mail %d does not break its message onto row %d." % [index, at.y + 2]
		)
		var author_x: int = Gen2MailPage.AUTHOR_COLUMN
		if index == Gen2MailPage.PORTRAIT:
			author_x = Gen2MailPage.AUTHOR_COLUMN_PORTRAIT
		elif index == Gen2MailPage.MORPH:
			author_x = Gen2MailPage.AUTHOR_COLUMN_MORPH
		_r.check(
			page.map_tile(Vector2i(author_x, Gen2MailPage.AUTHOR_ROW))
				== Gen2Text.encode(SAMPLE_AUTHOR)[0],
			"mail %d does not print its author at column %d." % [index, author_x]
		)
	_r.note("ten mail types drawn, %d tiles of graphics." % RomLayout.MAIL_GFX_TILES)


## One composed message on both lines, which is what `_ComposeMailMessage`
## leaves behind once the entry has filled the first.
func _sample(item: int) -> Gen2SaveMail:
	var entry: PackedByteArray = Gen2SaveMail.blank_message()
	var first: PackedByteArray = Gen2Text.encode(SAMPLE_LINE_1)
	for index: int in first.size():
		entry[index] = first[index]
	var second: PackedByteArray = Gen2Text.encode(SAMPLE_LINE_2)
	for index: int in second.size():
		entry[Gen2SaveMail.LINE_LENGTH + 1 + index] = second[index]
	return Gen2SaveMail.compose(entry, SAMPLE_AUTHOR, 0x1234, 1, item)


## Every cartridge ships the same tables and the same palettes; only the offsets
## move, so a disagreement is a wrong pin rather than a cartridge difference.
func _verify_identical() -> void:
	for table: Dictionary in [_blocks, _palettes, _items]:
		var ids: Array = table.keys()
		for index: int in range(1, ids.size()):
			_r.check(
				table[ids[index]] == table[ids[0]],
				"%s and %s disagree about the mail tables." % [ids[0], ids[index]]
			)


func _span(tiles: Array) -> String:
	if tiles.is_empty():
		return "nothing"
	return "$%02X..$%02X (%d)" % [int(tiles[0]), int(tiles[-1]), tiles.size()]
