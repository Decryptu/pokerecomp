extends RefCounted

var _r: RefCounted = null

## Verifies the menu mon icons a party page draws, against freshly imported real
## caches: `MonMenuIcons`, `IconPointers`' art behind it, `HeldItemIcons` and
## `PartyMenuOBPals`. The whole corpus rather than a sample: every species on all
## three cartridges resolves to an icon whose eight tiles decode and carry ink. The
## table is a plain byte run, so a wrong offset lands on neighbouring data that
## still reads as numbers; what says it is the right run is that every entry is in
## range, that the first and last species are the shapes the source names, and that
## the three cartridges agree entry for entry.

## Generation 1's own run: `MonPartyData` holds a nybble per dex number and the
## cache stores it one higher, `ICON_MON` being zero. `MonPartySpritePointers`
## loads a trade bubble beside the party shapes and no dex number names it, so
## it is the one strip the table leaves out.
const GEN1_SPECIES: int = Gen1Layout.SPECIES_COUNT
const GEN1_TRADE_BUBBLE: int = 0x0E + 1
## `data/pokemon/menu_icons.asm`'s ends: Bulbasaur is `ICON_GRASS` and Mew
## `ICON_MON`. Pikachu is Yellow's own `ICON_PIKACHU`, the shape it added, where
## Red and Blue draw it as `ICON_FAIRY`.
const GEN1_BULBASAUR_ICON: int = 0x07 + 1
const GEN1_MEW_ICON: int = 0x00 + 1
const GEN1_PIKACHU: int = 25
const GEN1_PIKACHU_ICON: int = 0x0A + 1
const GEN1_FAIRY_ICON: int = 0x03 + 1
## `constants/icon_constants.asm`'s run from `ICON_MON` to `ICON_QUADRUPED`,
## every one of which a dex number names. Yellow's eleventh is Pikachu's own.
const GEN1_SHAPES: int = 10

## `constants/icon_constants.asm`, the entries the census names.
const ICON_BULBASAUR: int = 22
const ICON_HUMANSHAPE: int = 14
const ICON_UNOWN: int = 25

## `data/pokemon/menu_icons.asm`'s first and last rows, either side of the run.
const FIRST_SPECIES: int = 1
const LAST_SPECIES: int = 251
const UNOWN: int = 201

var _first_table: PackedByteArray = PackedByteArray()


func run(r: RefCounted) -> void:
	_r = r
	_first_table = PackedByteArray()
	_r.each_game(_check_game)
	_r.each_game_of(RomRegistry.GEN1, _check_gen1_game)


## The same sweep on Generation 1, whose icons come out of
## `MonPartySpritePointers` rather than one sheet.
func _check_gen1_game() -> void:
	var table: PackedByteArray = _r.data.mon_menu_icon_table()
	if not _r.check(
		table.size() == GEN1_SPECIES,
		"MonPartyData holds %d entries, not %d." % [table.size(), GEN1_SPECIES]
	):
		return
	_r.check(
		_r.data.mon_menu_icon(1) == GEN1_BULBASAUR_ICON,
		"BULBASAUR draws icon %d." % _r.data.mon_menu_icon(1)
	)
	_r.check(
		_r.data.mon_menu_icon(GEN1_SPECIES) == GEN1_MEW_ICON,
		"MEW draws icon %d." % _r.data.mon_menu_icon(GEN1_SPECIES)
	)
	var pikachu: int = GEN1_PIKACHU_ICON if _r.game_id == RomRegistry.YELLOW \
		else GEN1_FAIRY_ICON
	_r.check(
		_r.data.mon_menu_icon(GEN1_PIKACHU) == pikachu,
		"PIKACHU draws icon %d, not %d." % [
			_r.data.mon_menu_icon(GEN1_PIKACHU), pikachu,
		]
	)
	var used: Dictionary = {}
	for dex: int in range(1, GEN1_SPECIES + 1):
		used[_r.data.mon_menu_icon(dex)] = true
	var lit: int = 0
	for icon: int in used:
		lit += _gen1_icon_pixels(int(icon))
	## The trade bubble is loaded beside them and no party row names it, so it
	## is checked here rather than left as the one strip nothing reads.
	_gen1_icon_pixels(GEN1_TRADE_BUBBLE)
	var shapes: int = GEN1_SHAPES + (1 if _r.game_id == RomRegistry.YELLOW else 0)
	_r.check(
		used.size() == shapes,
		"%d of the %d shapes a party menu loads are used." % [used.size(), shapes]
	)
	_r.note("party icons: %d dex numbers over %d shapes, %d drawn pixels." % [
		GEN1_SPECIES, used.size(), lit,
	])


## One Generation 1 shape: eight tiles, both frames drawn, and the two of them
## different, which is what `AnimatePartyMon` swaps between.
func _gen1_icon_pixels(icon: int) -> int:
	var strip: PackedByteArray = _r.data.overworld_icon_indices(icon)
	var frame: int = Gen1Layout.MON_ICON_FRAME_TILES * PokeTiles.TILE_WIDTH
	if not _r.check(
		strip.size() == Gen1Layout.MON_ICON_FRAME_TILES * 2 * PokeTiles.TILE_PIXELS,
		"icon %d decoded %d pixels." % [icon, strip.size()]
	):
		return 0
	var drawn: int = 0
	var same: bool = true
	for row: int in PokeTiles.TILE_HEIGHT:
		for column: int in frame:
			var first: int = strip[row * frame * 2 + column]
			var second: int = strip[row * frame * 2 + frame + column]
			drawn += (1 if first != 0 else 0) + (1 if second != 0 else 0)
			same = same and first == second
	_r.check(drawn > 0, "icon %d is blank." % icon)
	## The ball and the helix share their two frames: `.editCoords` shakes them
	## a pixel down instead of loading a second one.
	if not Gen1Layout.MON_ICON_SHAKING.has(icon - 1):
		_r.check(not same, "icon %d draws the same picture twice." % icon)
	return drawn


func _check_game() -> void:
	var table: PackedByteArray = _r.data.mon_menu_icon_table()
	if not _r.check(
		table.size() == LAST_SPECIES,
		"MonMenuIcons holds %d entries, not %d." % [table.size(), LAST_SPECIES]
	):
		return
	_r.check(
		_r.data.mon_menu_icon(FIRST_SPECIES) == ICON_BULBASAUR,
		"BULBASAUR draws icon %d, not ICON_BULBASAUR." % _r.data.mon_menu_icon(FIRST_SPECIES)
	)
	_r.check(
		_r.data.mon_menu_icon(LAST_SPECIES) == ICON_HUMANSHAPE,
		"CELEBI draws icon %d, not ICON_HUMANSHAPE." % _r.data.mon_menu_icon(LAST_SPECIES)
	)
	_r.check(
		_r.data.mon_menu_icon(UNOWN) == ICON_UNOWN,
		"UNOWN draws icon %d, not ICON_UNOWN." % _r.data.mon_menu_icon(UNOWN)
	)
	# A species past the cartridge's own range is what a mod would number, and
	# it has no row rather than a wrong one.
	_r.check(
		_r.data.mon_menu_icon(LAST_SPECIES + 1) == 0,
		"a species past the table answers an icon anyway."
	)
	if _first_table.is_empty():
		_first_table = table
	else:
		_r.check(
			_first_table == table, "MonMenuIcons differs from the other cartridges."
		)

	var used: Dictionary = {}
	for species: int in range(FIRST_SPECIES, LAST_SPECIES + 1):
		used[_r.data.mon_menu_icon(species)] = true
	var lit: int = 0
	for icon: int in range(1, Gen2Layout.MON_ICON_COUNT + 1):
		var strip: PackedByteArray = _r.data.overworld_icon_indices(icon)
		if not _r.check(
			strip.size() == Gen2Layout.MON_ICON_TILES * PokeTiles.TILE_PIXELS,
			"icon %d decoded %d pixels." % [icon, strip.size()]
		):
			continue
		var drawn: int = 0
		for index: int in strip:
			if index != 0:
				drawn += 1
		_r.check(drawn > 0, "icon %d is blank." % icon)
		lit += drawn
	_r.check(
		used.size() == Gen2Layout.MON_ICON_COUNT - 1,
		"%d of the %d shapes are used; only ICON_EGG should be spare." % [
			used.size(), Gen2Layout.MON_ICON_COUNT,
		]
	)

	_check_held_item_icons()
	_check_palette()
	_r.note("party icons: %d species over %d shapes, %d drawn pixels." % [
		LAST_SPECIES, used.size(), lit,
	])


## `HeldItemIcons`, both tiles, though only the item one is ever drawn.
func _check_held_item_icons() -> void:
	var held: PackedByteArray = _r.data.held_item_icon_indices()
	_r.check(
		held.size() == Gen2Layout.HELD_ITEM_ICON_TILES * PokeTiles.TILE_PIXELS,
		"HeldItemIcons decoded %d pixels." % held.size()
	)


## `PartyMenuOBPals`' first palette, the one every icon's OAM set names. Colour
## 0 is the transparent index, so an icon drawn in a palette whose colour 0 is
## not the light one the source ships would lose its outline instead of its
## background.
func _check_palette() -> void:
	var colors: PackedColorArray = _r.data.party_menu_icon_palette()
	if not _r.check(
		colors.size() == PokePalette.COLORS_PER_PIC,
		"the icon palette holds %d colours." % colors.size()
	):
		return
	_r.check(colors[3] == Color.BLACK, "the icon palette does not end in black.")
	_r.check(
		colors[0].get_luminance() > colors[2].get_luminance(),
		"the icon palette's transparent colour is darker than its third."
	)
