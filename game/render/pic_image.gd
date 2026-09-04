class_name Gen2PicImage
extends RefCounted

## Colour indices plus a palette to an [Image]. The cache stores what the
## cartridge stores, two bits per pixel and no colour, so the palette is chosen
## here at draw time and a shiny sprite costs one [PackedColorArray] rather than
## a second copy of the pixels.
##
## Built as one buffer for [method Image.create_from_data]: per-pixel
## [method Image.set_pixel] on a 56x56 sprite is 3136 binding calls for a table
## lookup, and a battle can want several sprites a frame. Node-free, so headless.

const CHANNELS: int = 4
## Every fourth pixel each way is what [method field_color] counts: two samples
## per 8x8 tile on each axis.
const FIELD_STRIDE: int = 4
const TRANSPARENT := Color(0.0, 0.0, 0.0, 0.0)
## A sprite never draws its first colour.
const TRANSPARENT_INDEX: int = 0
## The alpha byte a picture the hardware could have drawn carries everywhere.
const OPAQUE: int = 255

## `PadFrontpic`'s box: every front pic is placed as 7x7 tiles whatever its own
## size is.
const FRONTPIC_TILES: int = 7


## An image [param width] x [param height] from a row-major index buffer.
## [param transparent_background] makes index 0 transparent: the hardware has no
## alpha and draws it white, which is right for a battle sprite in its window and
## wrong for one over anything else.
static func from_indices(
	indices: PackedByteArray,
	width: int,
	height: int,
	palette: PackedColorArray,
	transparent_background: bool = false
) -> Image:
	if width <= 0 or height <= 0 or indices.size() < width * height:
		return Image.create_empty(maxi(width, 1), maxi(height, 1), false, Image.FORMAT_RGBA8)

	return canvas_image(
		canvas_from_indices(indices, width, height, palette, transparent_background),
		width, height
	)


## The same before the conversion, for a page that goes on to blit over it.
static func canvas_from_indices(
	indices: PackedByteArray,
	width: int,
	height: int,
	palette: PackedColorArray,
	transparent_background: bool = false
) -> PackedInt32Array:
	var words := PackedInt32Array()
	if width <= 0 or height <= 0 or indices.size() < width * height:
		words.resize(maxi(width, 1) * maxi(height, 1))
		return words
	var table: PackedInt32Array = lookup(palette, transparent_background)
	words.resize(width * height)
	for i: int in width * height:
		words[i] = table[indices[i]]
	return words


## An image from a row-major index buffer plus `wAttrmap`: one palette index per
## tile, so a screen the hardware draws in several palettes is one buffer here
## too rather than a layer per colour. [param slots] is [param columns] wide and
## row-major, and a slot naming no palette falls back on the first.
##
## `FillBoxCGB` and `ByteFill` over an attrmap `WipeAttrmap` cleared are what
## every `_CGB_*` layout writes, so a caller's own `attributes()` is that list of
## boxes flattened once.
static func from_attributes(
	indices: PackedByteArray,
	width: int,
	height: int,
	slots: PackedInt32Array,
	columns: int,
	palettes: Array
) -> Image:
	if palettes.is_empty():
		return Image.create_empty(maxi(width, 1), maxi(height, 1), false, Image.FORMAT_RGBA8)
	if width <= 0 or height <= 0 or indices.size() < width * height:
		return Image.create_empty(maxi(width, 1), maxi(height, 1), false, Image.FORMAT_RGBA8)

	return canvas_image(
		canvas_from_attributes(indices, width, height, slots, columns, palettes),
		width, height
	)


## The same before the conversion, for a page that goes on to blit over it.
static func canvas_from_attributes(
	indices: PackedByteArray,
	width: int,
	height: int,
	slots: PackedInt32Array,
	columns: int,
	palettes: Array
) -> PackedInt32Array:
	var words := PackedInt32Array()
	if palettes.is_empty() or width <= 0 or height <= 0 \
		or indices.size() < width * height:
		words.resize(maxi(width, 1) * maxi(height, 1))
		return words

	var lookups: Array[PackedInt32Array] = []
	for palette: Variant in palettes:
		lookups.append(lookup(palette as PackedColorArray, false))

	var tile: int = Gen2Font.TILE
	words.resize(width * height)
	for y: int in height:
		@warning_ignore("integer_division")
		var row: int = (y / tile) * columns
		var line: int = y * width
		for x: int in width:
			@warning_ignore("integer_division")
			var slot: int = row + x / tile
			var table: PackedInt32Array = lookups[
				clampi(slots[slot] if slot < slots.size() else 0, 0, lookups.size() - 1)
			]
			words[line + x] = table[indices[line + x]]
	return words


## An attrmap from a list of `FillBoxCGB` boxes, each (x, y, width, height,
## palette) over the zeroes `WipeAttrmap` leaves.
static func attribute_boxes(
	boxes: Array, columns: int, rows: int
) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(columns * rows)
	for box: Variant in boxes:
		var cells: Array = box as Array
		for row: int in int(cells[3]):
			for column: int in int(cells[2]):
				var x: int = int(cells[0]) + column
				var y: int = int(cells[1]) + row
				if x >= 0 and x < columns and y >= 0 and y < rows:
					out[y * columns + x] = int(cells[4])
	return out


## One cell out of a pic atlas, cropped to the pic's real size.
## [param pic] is [method GameData.species_pic]'s answer: which atlas, which slot
## and how much of the cell is filled. A cell is the size of the largest pic of
## its kind, so a 5x5 sprite carries blank tiles it must not be positioned by.
static func from_atlas(
	indices: PackedByteArray,
	atlas: Dictionary,
	pic: Dictionary,
	palette: PackedColorArray,
	transparent_background: bool = false
) -> Image:
	var cell: Dictionary = atlas_cell(indices, atlas, pic)
	if cell.is_empty():
		return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	return from_indices(
		cell["indices"], int(cell["width"]), int(cell["height"]),
		palette, transparent_background
	)


## The same cell before a palette is chosen: { indices, width, height }, or empty
## for a slot the atlas does not hold. Split out so a palette fade over a
## frontpic swaps colours rather than cropping the atlas again.
##
## A [param pic] carrying its own [code]indices[/code] is a mod's picture and has
## no cell to crop: the atlases hold exactly the cartridge's slots. Answering it
## here is what lets every screen draw one without knowing which it has.
static func atlas_cell(
	indices: PackedByteArray, atlas: Dictionary, pic: Dictionary
) -> Dictionary:
	if pic.has("indices"):
		var supplied: Variant = pic["indices"]
		var pic_width: int = int(pic.get("width", 0))
		var pic_height: int = int(pic.get("height", 0))
		if not supplied is PackedByteArray or pic_width <= 0 or pic_height <= 0 \
			or (supplied as PackedByteArray).size() < pic_width * pic_height:
			return {}
		return {"indices": supplied, "width": pic_width, "height": pic_height}

	var cell: int = int(atlas.get("cell", 0))
	var columns: int = int(atlas.get("columns", 0))
	var atlas_width: int = int(atlas.get("width", 0))
	var slot: int = int(pic.get("slot", -1))
	if cell <= 0 or columns <= 0 or atlas_width <= 0 or slot < 0:
		return {}

	var width: int = mini(int(pic.get("width", cell)), cell)
	var height: int = mini(int(pic.get("height", cell)), cell)
	if width <= 0 or height <= 0:
		return {}

	var left: int = (slot % columns) * cell
	var top: int = (slot / columns) * cell
	var cropped: PackedByteArray = PackedByteArray()
	cropped.resize(width * height)

	for y: int in height:
		var from: int = (top + y) * atlas_width + left
		if from + width > indices.size():
			break
		for x: int in width:
			cropped[y * width + x] = indices[from + x]

	return {"indices": cropped, "width": width, "height": height}


## One packed RGBA8 word per colour index, so a blit is an array copy rather
## than a [Color] conversion. Little-endian, which is the order
## [method PackedInt32Array.to_byte_array] writes and `FORMAT_RGBA8` reads.
##
## Public because every per-tile blit in the project shares it: a page that
## builds a [Color] per pixel pays a binding call and an allocation for a table
## lookup, which is what [method blit_tile] exists to stop.
static func lookup(
	palette: PackedColorArray, transparent_background: bool = false
) -> PackedInt32Array:
	var out := PackedInt32Array()
	var count: int = maxi(palette.size(), PokePalette.COLORS_PER_PIC)
	out.resize(count)

	for i: int in count:
		var color: Color = palette[i] if i < palette.size() else Color.MAGENTA
		# The palette's own alpha, so a translucent colour needs no second
		# flag. Every cartridge palette is opaque, PokePalette.decode_color
		# building an opaque Color.
		var alpha: int = 0 if transparent_background and i == 0 \
			else int(clampf(color.a, 0.0, 1.0) * 255.0)
		## Truncated, not rounded: `Image.set_pixel` casts and a five-bit
		## colour's own reference expansion floors, so a colour comes out the
		## same byte whichever path drew it. Rounding put every caller of this
		## table one unit off the rest of the game on nine of the 32 levels.
		out[i] = int(clampf(color.r, 0.0, 1.0) * 255.0) \
			| (int(clampf(color.g, 0.0, 1.0) * 255.0) << 8) \
			| (int(clampf(color.b, 0.0, 1.0) * 255.0) << 16) \
			| (alpha << 24)

	return out


## What `wBoxAlignment` produces, a plain horizontal mirror. The flag is read
## twice and only both halves make sense of it: `LoadOrientedFrontpic`'s `.x_flip`
## bit-reverses every byte as it loads, mirroring each tile's pixels, and
## `PlaceGraphic`'s `.right` then walks the tile columns with `dec hl`. Reversing
## the columns alone scrambles the sprite. The two compose exactly into
## [method Image.flip_x]. `PrepMonFrontpic` sets the flag itself, so Oak's
## speech, the mail, the stats screen and an evolution all draw mirrored.
static func x_flipped(image: Image) -> Image:
	if image == null:
		return image
	var out: Image = image.duplicate()
	out.flip_x()
	return out


## `PadFrontpic` (engine/gfx/load_pics.asm) fills the 7x7 block a front pic is
## placed in, and does not centre a smaller pic: it lays one blank tile column
## before it and blank rows above it, so the pic is bottom-aligned one column in.
## This is that left pad, in tiles, for a [param width]-tile-wide pic.
##
## [param mirrored] is `wBoxAlignment`, which `LoadOrientedFrontpic` reads:
## reversing the columns leaves the trailing blank on the left instead, which for
## a 5x5 is one column further in than a 6x6.
static func frontpic_pad_columns(width: int, mirrored: bool = false) -> int:
	if width >= FRONTPIC_TILES or width <= 0:
		return 0
	return FRONTPIC_TILES - 1 - width if mirrored else 1


## The same pad above the pic, in tiles. `PadFrontpic` writes its blank tiles in
## front of each column, so a shorter pic is bottom-aligned in the box whichever
## way `wBoxAlignment` runs its columns.
static func frontpic_pad_rows(height: int) -> int:
	if height >= FRONTPIC_TILES or height <= 0:
		return 0
	return FRONTPIC_TILES - height


## Where the seven-tile cell leaves a front pic, in pixels: bottom-aligned, one
## blank column in, and on the other side of the cell when the picture is
## mirrored. [param size] is the pic's own pixel size.
static func frontpic_origin(size: Vector2i, mirrored: bool = false) -> Vector2i:
	@warning_ignore("integer_division")
	var columns: int = size.x / PokeTiles.TILE_WIDTH
	@warning_ignore("integer_division")
	var rows: int = size.y / PokeTiles.TILE_WIDTH
	return Vector2i(
		frontpic_pad_columns(columns, mirrored), frontpic_pad_rows(rows)
	) * PokeTiles.TILE_WIDTH


## The 7x7 box a [Gen2PicAnimation] leaves, read out of the strip
## [method Gen2BattleRenderer.padded_pic] produced: a box cell is
## `column * side + row` and its value is a tile number down the strip's own
## columns, which is `PokeAnim_PlaceGraphic`'s own numbering.
static func animation_box_indices(
	box: PackedByteArray, pixels: PackedByteArray, side: int
) -> PackedByteArray:
	var span: int = side * PokeTiles.TILE_WIDTH
	var out := PackedByteArray()
	if box.size() != side * side or pixels.is_empty() or side <= 0:
		return out
	out.resize(span * span)
	@warning_ignore("integer_division")
	var strip: int = pixels.size() / span
	for column: int in side:
		for row: int in side:
			var tile: int = int(box[column * side + row])
			@warning_ignore("integer_division")
			var source_x: int = (tile / side) * PokeTiles.TILE_WIDTH
			var source_y: int = (tile % side) * PokeTiles.TILE_WIDTH
			if source_x + PokeTiles.TILE_WIDTH > strip:
				continue
			for line: int in PokeTiles.TILE_WIDTH:
				var from: int = (source_y + line) * strip + source_x
				var to: int = (row * PokeTiles.TILE_WIDTH + line) * span \
					+ column * PokeTiles.TILE_WIDTH
				for x: int in PokeTiles.TILE_WIDTH:
					out[to + x] = pixels[from + x]
	return out


## `LoadOrientedFrontpic`'s `.x_flip` on its own: every tile's pixels reversed
## where its column is not. That is what a strip an animation indexes by tile
## number needs, because `PokeAnim_PlaceGraphic` runs the columns back itself.
static func tile_flipped_indices(indices: PackedByteArray, width: int) -> PackedByteArray:
	if width <= 0:
		return indices
	var out := PackedByteArray()
	out.resize(indices.size())
	@warning_ignore("integer_division")
	var height: int = indices.size() / width
	@warning_ignore("integer_division")
	var tiles: int = width / PokeTiles.TILE_WIDTH
	for y: int in height:
		var row: int = y * width
		for tile: int in tiles:
			var left: int = tile * PokeTiles.TILE_WIDTH
			for x: int in PokeTiles.TILE_WIDTH:
				out[row + left + x] = indices[row + left + PokeTiles.TILE_WIDTH - 1 - x]
	return out


## The same mirror on an index buffer, for a caller that will recolour it.
static func x_flipped_indices(indices: PackedByteArray, width: int) -> PackedByteArray:
	if width <= 0:
		return indices
	var out := PackedByteArray()
	out.resize(indices.size())
	@warning_ignore("integer_division")
	var height: int = indices.size() / width
	for y: int in height:
		var row: int = y * width
		for x: int in width:
			out[row + x] = indices[row + width - 1 - x]
	return out


## The palette as the eight-bit colours a blit actually writes.
##
## For a caller comparing a rendered pixel against a palette: a 15-bit colour is
## kept as a float and read back through an eight-bit image, so the comparison
## belongs where the picture is and the conversion has to be the drawing's own.
static func quantized(
	palette: PackedColorArray, transparent_background: bool = false
) -> PackedColorArray:
	var table: PackedInt32Array = lookup(palette, transparent_background)
	var out := PackedColorArray()
	for index: int in palette.size():
		var word: int = table[index]
		out.append(Color8(
			word & 0xFF, (word >> 8) & 0xFF, (word >> 16) & 0xFF, (word >> 24) & 0xFF
		))
	return out


## A blank canvas [param width] x [param height], one packed RGBA8 word per
## pixel. Every word is zero, which is transparent black.
##
## A word rather than four bytes because the inner loop of every page in the
## project is one store per pixel either way, and four of them cost four bounds
## checks; the conversion to bytes at the end is one memcpy.
static func canvas(width: int, height: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(maxi(width, 0) * maxi(height, 0))
	return out


## The [Image] a canvas has become. Paired with [method canvas] so a page builds
## its screen in one buffer and pays one conversion.
static func canvas_image(pixels: PackedInt32Array, width: int, height: int) -> Image:
	if width <= 0 or height <= 0 or pixels.size() < width * height:
		return Image.create_empty(maxi(width, 1), maxi(height, 1), false, Image.FORMAT_RGBA8)
	return Image.create_from_data(
		width, height, false, Image.FORMAT_RGBA8, pixels.to_byte_array()
	)


## One 8x8 tile of [param strip] into a [method canvas] buffer. [param strip] is
## a horizontal run of [param strip_tiles] tiles, one byte of colour index per
## pixel, which is the shape every sheet in the cache is stored in.
## [param skip_index] is the colour the blit leaves standing, -1 for none: an
## object palette never draws index 0 and a background tile draws all four.
## Clipped rather than refused, so a caller places a sprite partly off screen the
## way OAM does.
static func blit_tile(
	pixels: PackedInt32Array,
	width: int,
	height: int,
	strip: PackedByteArray,
	strip_tiles: int,
	tile: int,
	at_x: int,
	at_y: int,
	table: PackedInt32Array,
	flip_x: bool = false,
	flip_y: bool = false,
	skip_index: int = -1,
) -> void:
	if strip_tiles <= 0 or tile < 0 or tile >= strip_tiles or table.is_empty():
		return
	var stride: int = strip_tiles * PokeTiles.TILE_WIDTH
	var left: int = tile * PokeTiles.TILE_WIDTH
	var colors: int = table.size()
	for row: int in PokeTiles.TILE_HEIGHT:
		var y: int = at_y + row
		if y < 0 or y >= height:
			continue
		var from: int = (
			(PokeTiles.TILE_HEIGHT - 1 - row) if flip_y else row
		) * stride + left
		if from < 0 or from + PokeTiles.TILE_WIDTH > strip.size():
			continue
		var to_row: int = y * width
		for column: int in PokeTiles.TILE_WIDTH:
			var x: int = at_x + column
			if x < 0 or x >= width:
				continue
			var index: int = strip[
				from + ((PokeTiles.TILE_WIDTH - 1 - column) if flip_x else column)
			]
			if index == skip_index:
				continue
			pixels[to_row + x] = table[mini(index, colors - 1)]


## Puts [param image] on [param target].
##
## The one way a screen in this project hands a redrawn picture to the node that
## shows it, so the reuse below happens everywhere rather than at whichever
## screen was measured.
static func show(target: TextureRect, image: Image) -> void:
	if target == null:
		return
	target.texture = refreshed_texture(target.texture as ImageTexture, image)
	Gen2Screen.note_picture(target, image)


## What a picture is mostly made of, which is the colour a screen carries out past
## the hardware rectangle it was laid out in. The picture's own field rather than
## its border, since a cartridge screen puts a box frame along its edge often
## enough that the edge says black where the screen reads white. Sampled on a
## stride, because tile art is flat in blocks of eight. A picture with any
## transparency has no field at all: the hardware has no alpha, so one that is not
## opaque is a layer over another screen, and answering for the screen underneath
## is what painted a black band over the map.
static func field_color(image: Image, stride: int = FIELD_STRIDE) -> Color:
	if image == null or image.is_empty() or image.get_format() != Image.FORMAT_RGBA8:
		return TRANSPARENT
	var width: int = image.get_width()
	var height: int = image.get_height()
	var step: int = maxi(stride, 1)
	# The bytes rather than `get_pixel`: one binding call per sample is what a
	# screen redrawn every frame cannot afford, and this runs on every one.
	var data: PackedByteArray = image.get_data()
	var counts: Dictionary = {}
	var best: int = -1
	var seen: int = 0
	var y: int = 0
	while y < height:
		var row: int = y * width * CHANNELS
		var x: int = 0
		while x < width:
			var at: int = row + x * CHANNELS
			if data[at + 3] < OPAQUE:
				return TRANSPARENT
			var key: int = (
				data[at] << 24 | data[at + 1] << 16 | data[at + 2] << 8 | data[at + 3]
			)
			var count: int = int(counts.get(key, 0)) + 1
			counts[key] = count
			if count > seen:
				seen = count
				best = key
			x += step
		y += step
	if best < 0:
		return TRANSPARENT
	return Color.hex(best)


## The texture [param texture] becomes once it holds [param image]. A screen
## redrawn every frame used to answer `ImageTexture.create_from_image` each time,
## which allocates a texture and frees the last one on every frame it draws;
## `update` writes into the one already on the GPU. The size and format have to
## match for that, so a first frame and a resize still create. Not headless: the
## dummy driver hands `ImageTexture.get_image` back the picture the texture was
## created with rather than the one it was last updated with.
static func refreshed_texture(texture: ImageTexture, image: Image) -> ImageTexture:
	if image == null:
		return texture
	if texture == null or _drawing_nothing \
		or Vector2i(texture.get_size()) != image.get_size() \
		or texture.get_format() != image.get_format():
		return ImageTexture.create_from_image(image)
	texture.update(image)
	return texture


static var _drawing_nothing: bool = DisplayServer.get_name() == "headless"
