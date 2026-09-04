extends RefCounted

## Every picture [Gen1SpriteCodec] decodes and the two fixed sheets beside them,
## swept on Red, Blue and Yellow: 151 front pics, 151 back pics, 47 trainer
## classes, two battle back pics, `FontGraphics` and `TextBoxGraphics`. The
## digests come from a run in which all 906 species pics, all 141 trainer pics
## and all six back pics matched the PNGs under a pinned checkout's
## `gfx/pokemon` and `gfx/trainers` pixel for pixel, those being what the
## cartridge's own `.pic` files are built from. Re-earn them against those
## rather than by copying whatever this prints.

const SPECIES_COUNT: int = 151
const TRAINER_COUNT: int = 47
## The only three front sizes in the corpus.
const FRONT_SIDES: Array[int] = [5, 6, 7]
const BACK_SIDE: int = 4
const TRAINER_SIDE: int = 7

## SHA-1 of each atlas's own index buffer. Red and Blue share every picture,
## and Yellow redrew all 151 front pics and six trainer ones, Brock, Misty,
## Erika and the rival's three, but no back pic at all.
const DIGESTS: Dictionary = {
	&"red": {
		"front": "672ba02e2d98a787fb619e11e77fba45a379a47b",
		"back": "a8976278a8c8294f285a25a993a44f2f6012b127",
		"trainers": "1bdca25cb1bf6de93811f597481f0bda00079cf6",
		"player_back": "6c2830e479cf877b20bd10f6c94324bb5c3e425d",
	},
	&"blue": {
		"front": "672ba02e2d98a787fb619e11e77fba45a379a47b",
		"back": "a8976278a8c8294f285a25a993a44f2f6012b127",
		"trainers": "1bdca25cb1bf6de93811f597481f0bda00079cf6",
		"player_back": "6c2830e479cf877b20bd10f6c94324bb5c3e425d",
	},
	&"yellow": {
		"front": "d6e50eed9888dbe7787b1a1952403eab5bd133b6",
		"back": "a8976278a8c8294f285a25a993a44f2f6012b127",
		"trainers": "6b0fe80efffb9a8223a9646b1df42cfa592fd0f4",
		"player_back": "6c2830e479cf877b20bd10f6c94324bb5c3e425d",
	},
}

## `TrainerPicAndMoneyPointers`' money column, first row, last row and the two
## the cartridge caps: money received is this times the last enemy's level.
const PINNED_MONEY: Dictionary = {1: 1500, 26: 9900, 47: 9900}
const MIN_MONEY: int = 500
const MAX_MONEY: int = 9900

## `ChiefPic:` falls through to `ScientistPic`, so rows 27 and 28 are one picture.
const SHARED_PIC_ROWS: Array[int] = [27, 28]

## SHA-1 of each tile strip. All three cartridges hold the one font and the one
## text box; re-earn these against `gfx/font/font.png` and `font_extra.png`.
## SHA-1 of each tile strip. All three cartridges hold the same five; re-earn
## these against `gfx/font/font.png`, `font_extra.png`, `font_battle_extra.png`
## and `gfx/battle/battle_hud_*.png`.
const SHEET_DIGESTS: Dictionary = {
	"font": "8146fe98bbbd27f9d67509e3da62044b44785a3a",
	"font_extra": "ca0735bbbf8d2ce178a3f06a8d95ac6395dc8f7e",
	"battle_font": "91f966f8c57286416ccec63a798e299417fb16b3",
	"battle_hud_1": "f3c855d6f6f97f4994d4cd1967a2a205e8adac3d",
	"battle_hud_2": "cc45fdec1282f49f07f31d80d2919a7b40ae8fce",
}

## What the assembled page has to hold once the four sheets have overlapped:
## the empty bar, the panel edge, the level symbol and the two bar caps, by tile
## number and by whether any pixel of that tile is set.
const BATTLE_PAGE_TILES: Array[int] = [0x62, 0x63, 0x6B, 0x6C, 0x6D, 0x6E, 0x76, 0x78]

## `ScaleSpriteByTwo` walks 28 of a back pic's 32 rows and takes four pixels
## from the last column, so a battle never draws past this. Nine back pics are
## drawn past it and are cut on hardware: eight have a 29th row and Persian has
## a 29th column.
const BACK_PIC_KEPT: int = 28
const CROPPED_BACK_PICS: Array[int] = [20, 26, 40, 51, 53, 58, 77, 125, 137]

var _r: RefCounted = null


func run(r: RefCounted) -> void:
	_r = r
	r.each_game_of(RomRegistry.GEN1, _one_game)


func _one_game() -> void:
	_atlas("front", SPECIES_COUNT, FRONT_SIDES[FRONT_SIDES.size() - 1])
	_atlas("back", SPECIES_COUNT, BACK_SIDE)
	_atlas("trainers", TRAINER_COUNT, TRAINER_SIDE)
	_atlas("player_back", Gen1Layout.PLAYER_BACKPICS.size(), BACK_SIDE)
	_species_pics()
	_trainer_pics()
	_player_pics()
	_sheets()
	_battle_page()
	_digests()


## One atlas's metadata: the cell is the largest picture of its kind, and every
## slot decoded.
func _atlas(name: String, cells: int, side: int) -> void:
	var atlas: Dictionary = _r.data.atlas(name)
	if not _r.check(not atlas.is_empty(), "the cache carries no %s atlas." % name):
		return
	_r.check(
		int(atlas["cell"]) == side * PokeTiles.TILE_WIDTH,
		"the %s atlas has %d-pixel cells, wanted %d." % [
			name, int(atlas["cell"]), side * PokeTiles.TILE_WIDTH,
		]
	)
	_r.check(int(atlas["decoded"]) == cells, "the %s atlas decoded %d of %d cells." % [
		name, int(atlas["decoded"]), cells,
	])


## Every species, both pictures. A front pic is square, its ink fills its own
## box, and the rest of the 7x7 cell stays blank: a decoder that read the size
## nybbles the wrong way round draws inside the cell but outside the box.
func _species_pics() -> void:
	var sides: Dictionary = {}
	for dex: int in range(1, SPECIES_COUNT + 1):
		var pic: Dictionary = _r.data.species_pic(dex)
		var tiles: Array = (_r.data.species(dex))["front_tiles"]
		var side: int = int(tiles[0])
		sides[side] = int(sides.get(side, 0)) + 1
		_r.check(
			int(tiles[1]) == side and FRONT_SIDES.has(side),
			"species %d is %s tiles, which is no front pic size." % [dex, tiles]
		)
		_r.check(
			int(pic.get("width", 0)) == side * PokeTiles.TILE_WIDTH,
			"species %d's front cell is %d wide, wanted %d." % [
				dex, int(pic.get("width", 0)), side * PokeTiles.TILE_WIDTH,
			]
		)
		_inked("front", dex, pic)
		_blank_outside(dex, side)
		_inked("back", dex, _r.data.species_pic(dex, true))
	_r.note("gen1 pics %s front sizes, %d species" % [sides, SPECIES_COUNT])


func _trainer_pics() -> void:
	var shared: Array[PackedByteArray] = []
	for trainer_class: int in range(1, TRAINER_COUNT + 1):
		var entry: Dictionary = _r.data.trainer(trainer_class)
		var money: int = int(entry.get("base_money", 0))
		var pinned: int = int(PINNED_MONEY.get(trainer_class, 0))
		if pinned > 0:
			_r.check(money == pinned, "trainer class %d pays %d, pinned %d." % [
				trainer_class, money, pinned,
			])
		_r.check(money >= MIN_MONEY and money <= MAX_MONEY,
			"trainer class %d pays %d, outside the table's own range." % [trainer_class, money])
		var cell: Dictionary = _cell("trainers", trainer_class - 1)
		_r.check(_ink(cell), "trainer class %d draws a blank picture." % trainer_class)
		if SHARED_PIC_ROWS.has(trainer_class):
			shared.append(cell.get("indices", PackedByteArray()))
	_r.check(
		shared.size() == SHARED_PIC_ROWS.size() and shared[0] == shared[1],
		"the Chief and the Scientist are not the one picture ChiefPic falls into."
	)


func _player_pics() -> void:
	var drawn: Array[PackedByteArray] = []
	for slot: int in Gen1Layout.PLAYER_BACKPICS.size():
		var cell: Dictionary = _cell("player_back", slot)
		_r.check(_ink(cell), "the %s back pic is blank." % Gen1Layout.PLAYER_BACKPICS[slot])
		drawn.append(cell.get("indices", PackedByteArray()))
	_r.check(drawn[0] != drawn[1], "the player and the old man share a back pic.")


## The import's own font check seen from the cache side, and addressed the way
## the hardware addresses it: by character code.
func _sheets() -> void:
	var drawn: int = 0
	for inked: Array in Gen1Layout.FONT_INK_RUNS:
		for code: int in range(int(inked[0]), int(inked[1]) + 1):
			_r.check(_sheet_ink("font", code), "font code $%02X (%s) is blank." % [
				code, Gen1Text.character(code),
			])
			drawn += 1
	for hole: Array in Gen1Layout.FONT_BLANK_RUNS:
		for code: int in range(int(hole[0]), int(hole[1]) + 1):
			_r.check(not _sheet_ink("font", code), "font code $%02X draws." % code)

	var last: int = Gen1Layout.FONT_EXTRA_FIRST_CODE + Gen1Layout.FONT_EXTRA_TILES - 1
	for code: int in range(Gen1Layout.FONT_EXTRA_FIRST_CODE, last + 1):
		var wanted: bool = code != Gen1Layout.SPACE_CODE
		_r.check(_sheet_ink("font_extra", code) == wanted,
			"text box code $%02X %s." % [code, "is blank" if wanted else "draws"])
	_r.note("gen1 sheets %d font codes drawn, %d text box tiles" % [
		drawn, Gen1Layout.FONT_EXTRA_TILES,
	])


## The battle's own tile page, assembled the way a battle assembles it, and the
## crop `ScaleSpriteByTwo` puts every back pic through: the four rows and four
## columns it drops have to be blank on all 153 of them or a battle is drawing
## less than the cartridge does.
func _battle_page() -> void:
	var page: Gen2BattleTiles = Gen2BattleTiles.from_data(_r.data)
	if not _r.check(page != null, "the battle tile page does not assemble."):
		return
	var blank: PackedByteArray = PackedByteArray()
	blank.resize(PokeTiles.TILE_WIDTH * PokeTiles.TILE_HEIGHT)
	for tile: int in BATTLE_PAGE_TILES:
		var drawn: PackedByteArray = blank.duplicate()
		page.draw(tile, drawn, PokeTiles.TILE_WIDTH, 0, 0)
		_r.check(drawn != blank, "battle tile $%02X is blank." % tile)

	var cropped: Array[int] = []
	for slot: int in SPECIES_COUNT + Gen1Layout.PLAYER_BACKPICS.size():
		var name: String = "back" if slot < SPECIES_COUNT else "player_back"
		if _draws_outside_crop(name, slot if slot < SPECIES_COUNT else slot - SPECIES_COUNT):
			cropped.append(slot + 1)
	_r.check(cropped == CROPPED_BACK_PICS, "back pics cut by the scaler read %s" % str(cropped))
	_r.note("gen1 battle page %d tiles, %d back pics cut to %dx%d" % [
		BATTLE_PAGE_TILES.size(), cropped.size(), BACK_PIC_KEPT, BACK_PIC_KEPT,
	])


func _draws_outside_crop(name: String, slot: int) -> bool:
	var cell: Dictionary = _cell(name, slot)
	var width: int = int(cell.get("width", 0))
	var indices: PackedByteArray = cell.get("indices", PackedByteArray())
	for y: int in int(cell.get("height", 0)):
		for x: int in width:
			if x < BACK_PIC_KEPT and y < BACK_PIC_KEPT:
				continue
			if indices[y * width + x] != 0:
				return true
	return false


## Whether the tile one character code addresses has any pixel set.
func _sheet_ink(name: String, code: int) -> bool:
	var sheet: Dictionary = _r.data.tile_sheet(name)
	var indices: PackedByteArray = _r.data.tile_indices(name)
	var slot: int = code - int(sheet.get("first_code", 0))
	var width: int = int(sheet.get("width", 0))
	if slot < 0 or slot >= int(sheet.get("tiles", 0)) or width <= 0:
		return false
	for y: int in PokeTiles.TILE_HEIGHT:
		for x: int in PokeTiles.TILE_WIDTH:
			if indices[y * width + slot * PokeTiles.TILE_WIDTH + x] != 0:
				return true
	return false


func _inked(name: String, dex: int, pic: Dictionary) -> void:
	var cell: Dictionary = Gen2PicImage.atlas_cell(
		_r.data.atlas_indices(name), _r.data.atlas(name), pic
	)
	_r.check(_ink(cell), "species %d draws a blank %s pic." % [dex, name])


## The cell past the picture's own box, which nothing may draw in.
func _blank_outside(dex: int, side: int) -> void:
	var cell: Dictionary = _cell("front", dex - 1)
	var width: int = int(cell.get("width", 0))
	var indices: PackedByteArray = cell.get("indices", PackedByteArray())
	var edge: int = side * PokeTiles.TILE_WIDTH
	for y: int in int(cell.get("height", 0)):
		for x: int in width:
			if (x < edge and y < edge) or indices[y * width + x] == 0:
				continue
			_r.fail("species %d draws at %d,%d, outside its %d-tile box." % [dex, x, y, side])
			return


## A whole atlas cell, the picture and the blank around it.
func _cell(name: String, slot: int) -> Dictionary:
	return Gen2PicImage.atlas_cell(
		_r.data.atlas_indices(name), _r.data.atlas(name), {"slot": slot}
	)


static func _ink(cell: Dictionary) -> bool:
	var indices: Variant = cell.get("indices", null)
	if not indices is PackedByteArray:
		return false
	for index: int in indices as PackedByteArray:
		if index != 0:
			return true
	return false


static func _sha1(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA1)
	context.update(data)
	return context.finish().hex_encode()


func _digests() -> void:
	var pinned: Dictionary = DIGESTS.get(_r.game_id, {}) as Dictionary
	for name: String in ["front", "back", "trainers", "player_back"]:
		var digest: String = _sha1(_r.data.atlas_indices(name))
		var expected: String = String(pinned.get(name, ""))
		if expected.is_empty():
			_r.fail("no pinned digest for the %s atlas. It answered %s." % [name, digest])
			continue
		_r.check(digest == expected, "the %s atlas is %s, pinned %s." % [
			name, digest, expected,
		])
	for name: String in SHEET_DIGESTS:
		var digest: String = _sha1(_r.data.tile_indices(name))
		_r.check(digest == String(SHEET_DIGESTS[name]), "the %s sheet is %s, pinned %s." % [
			name, digest, SHEET_DIGESTS[name],
		])
