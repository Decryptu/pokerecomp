class_name Gen2SecondScreenTabs
extends RefCounted

## Which pages a second display may show, and each one's icon. The gate is
## [Gen2WorldStartMenu]'s, filtered to entries that are a picture, so a tab
## appears on the frame its START menu row does. SAVE, OPTION, EXIT and a mod's
## own row do something rather than show something, so none reaches a tab.

## Those rows, in `SetUpMenuItems` order. The map is on no menu at all,
## `ItemUseTownMap` being a bag row, so [method build] places that one.
const VIEWABLE: Array[StringName] = [
	Gen2WorldStartMenu.ITEM_POKEDEX,
	Gen2WorldStartMenu.ITEM_POKEMON,
	Gen2WorldStartMenu.ITEM_PACK,
	Gen2WorldStartMenu.ITEM_POKEGEAR,
	Gen2WorldStartMenu.ITEM_TOWN_MAP,
	Gen2WorldStartMenu.ITEM_PLAYER,
]

## What the map tab is called, which is the bag's own name for `ItemUseTownMap`.
const TOWN_MAP_LABEL: String = "TOWN MAP"

## A species icon is two tiles by two, the size every 16x16 object the cartridge
## draws is. A crop out of a screen's own sheet is whatever that picture is, no
## rectangle of `PackGFX` under 32 by 20 reading as a bag, so [constant ICON_MAX]
## is the tallest of them and what the row has to hold above the underline.
const ICON_TILE: int = 8
const ICON_SIZE: int = ICON_TILE * 2
const ICON_MAX: int = 18

## Where each tab's icon is cut from: the sheet, the top-left pixel in its grid,
## the grid's width in tiles and the pixel scale. Every one is art the page it
## opens draws: `HUDBallIcons`' caught marker, the middle of `PackGFX`'s bag,
## `.PlacePokegearCardIcon`'s MAP icon, the head of `GetCardPic`'s picture. #MON
## is the party's lead, read live, so it has no entry here or in
## [constant GEN1_ICONS].
const ICONS: Dictionary = {
	Gen2WorldStartMenu.ITEM_POKEDEX: {
		"sheet": "ball_icons", "at": Vector2i(0, 0), "size": Vector2i(8, 8),
		"stride": 4, "scale": 2,
	},
	Gen2WorldStartMenu.ITEM_PACK: {
		"sheet": "pack", "at": Vector2i(4, 3), "size": Vector2i(32, 18), "stride": 5,
	},
	Gen2WorldStartMenu.ITEM_POKEGEAR: {
		"sheet": "pokegear", "at": Vector2i(0, 8), "stride": 16,
	},
	Gen2WorldStartMenu.ITEM_PLAYER: {
		"sheet": "card_pic", "at": Vector2i(12, 1), "size": Vector2i(24, 18), "stride": 5,
	},
}

## `Gen2PackPage.ATTRIBUTES`' last row, which is the palette `_CGB_PackPals`
## gives the five-by-three picture.
const PACK_PICTURE_PALETTE: int = 5

## The same on a Generation 1 cache, which shares no sheet: `.writeTile`'s ball,
## `TownMapCursor`'s four tiles and `RedPicFront`'s head. ITEM has no picture at
## all, `StartMenu_Item` being a text box, so the row's own label is drawn.
const GEN1_ICONS: Dictionary = {
	Gen2WorldStartMenu.ITEM_POKEDEX: {
		"sheet": "battle_balls", "at": Vector2i(0, 0), "size": Vector2i(8, 8),
		"stride": 4, "scale": 2,
	},
	Gen2WorldStartMenu.ITEM_TOWN_MAP: {
		"sheet": "town_map_cursor", "at": Vector2i(0, 0), "stride": 2,
	},
	Gen2WorldStartMenu.ITEM_PLAYER: {
		"player_pic": true, "at": Vector2i(14, 2), "size": Vector2i(24, 18),
	},
}

var cursor: int = 0
var _items: Array = []


## [param party_count], [param pokedex] and [param pokegear] are the three gates
## `SetUpMenuItems` reads, and are handed straight to the START menu so the two
## lists cannot drift. [param player_name] is the STATUS row's own label, and
## [param town_map] the map tab's: see [method town_map_owned].
static func build(
	party_count: int,
	pokedex: bool,
	pokegear: bool,
	player_name: String = "",
	generation: int = RomRegistry.GEN2,
	town_map: bool = false,
) -> Gen2SecondScreenTabs:
	var menu: Gen2WorldStartMenu = Gen2WorldStartMenu.build(
		party_count, pokedex, pokegear, 0, player_name, false, false, generation
	)
	var out := Gen2SecondScreenTabs.new()
	for entry: Dictionary in menu.items():
		var kind: StringName = StringName(entry.get("kind", &""))
		if not VIEWABLE.has(kind):
			continue
		out._items.append({"kind": kind, "label": String(entry.get("label", ""))})
		## Generation 1 alone, where Crystal's Pokegear row and its map stand.
		if kind == Gen2WorldStartMenu.ITEM_PACK and town_map \
			and generation == RomRegistry.GEN1:
			out._items.append({
				"kind": Gen2WorldStartMenu.ITEM_TOWN_MAP, "label": TOWN_MAP_LABEL,
			})
	return out


## The same list off the live world, the way [method Gen2WorldStartMenu.from_world]
## reads it. A world with no state has no page at all, which is what a screen
## opened before the overworld exists shows.
static func from_world(world: Gen2WorldAPI) -> Gen2SecondScreenTabs:
	if world == null or world.state == null:
		return Gen2SecondScreenTabs.new()
	return build(
		int(world.party_summary().get("count", 0)),
		world.state.is_engine_flag_active(Gen2WorldStartMenu.ENGINE_POKEDEX),
		world.state.is_engine_flag_active(Gen2WorldStartMenu.ENGINE_POKEGEAR),
		world.player_name(),
		world.data.generation if world.data != null else RomRegistry.GEN2,
		town_map_owned(world),
	)


## Whether Generation 1's map tab is earned, which is the TOWN MAP in the bag.
static func town_map_owned(world: Gen2WorldAPI) -> bool:
	if world == null or world.state == null or world.data == null:
		return false
	if world.data.generation != RomRegistry.GEN1:
		return false
	return world.state.item_quantity(Gen1Layout.ITEM_TOWN_MAP) > 0


func items() -> Array:
	return _items.duplicate(true)


func size() -> int:
	return _items.size()


func is_empty() -> bool:
	return _items.is_empty()


func selected_kind() -> StringName:
	if cursor < 0 or cursor >= _items.size():
		return &""
	return StringName(_items[cursor].get("kind", &""))


func has_kind(kind: StringName) -> bool:
	for entry: Dictionary in _items:
		if StringName(entry.get("kind", &"")) == kind:
			return true
	return false


## Puts the cursor on [param kind], answering whether that tab is there. The one
## way a tap changes the page, so a tab that has not been earned yet cannot be
## opened by asking for it.
func select(kind: StringName) -> bool:
	for index: int in _items.size():
		if StringName(_items[index].get("kind", &"")) == kind:
			cursor = index
			return true
	return false


## What is drawn right now, so a host redrawing on change knows when nothing
## has. The tab set and the chosen tab are both in it: a gate opening mid-walk
## adds a tab and moves nothing else.
func signature() -> String:
	var parts: Array[String] = []
	for entry: Dictionary in _items:
		parts.append(String(entry.get("kind", &"")))
	return "%s|%s" % [",".join(parts), selected_kind()]


## The 16x16 icon for [param kind], or null where the cache cannot supply it.
##
## [param species] is the party's lead, which is the #MON tab's own icon and the
## one that is not a fixed crop; [param female] picks Kris's pack and card
## picture on a cartridge that carries them.
static func icon(
	data: GameData, kind: StringName, species: int = 0, female: bool = false,
	egg: bool = false
) -> Image:
	if data == null:
		return null
	if kind == Gen2WorldStartMenu.ITEM_POKEMON:
		return _species_icon(data, species, egg)
	var gen1: bool = data.generation == RomRegistry.GEN1
	var spec: Variant = (GEN1_ICONS if gen1 else ICONS).get(kind, null)
	if not spec is Dictionary:
		return null
	var row: Dictionary = spec
	var colors: PackedColorArray = _palette(data, kind, female)
	if colors.size() < PokePalette.COLORS_PER_PIC:
		return null
	if row.has("player_pic"):
		return _player_crop(data, row["at"], row["size"], colors)
	var strip: PackedByteArray = _sheet(data, String(row["sheet"]), female)
	if strip.is_empty():
		return null
	return _crop(
		strip, int(row["stride"]), row.get("at", Vector2i.ZERO),
		row.get("size", Vector2i(ICON_SIZE, ICON_SIZE)),
		int(row.get("scale", 1)), colors, int(row.get("transparent", -1))
	)


## A rectangle of `RedPicFront`, which is what the card draws, rather than of a
## tile sheet: an atlas cell is already a plain raster.
static func _player_crop(
	data: GameData, at: Vector2i, extent: Vector2i, colors: PackedColorArray
) -> Image:
	var cell: Dictionary = Gen2PicImage.atlas_cell(
		data.atlas_indices("player_front"), data.atlas("player_front"),
		data.player_frontpic()
	)
	if cell.is_empty():
		return null
	var indices: PackedByteArray = cell["indices"]
	var width: int = int(cell["width"])
	var pixels: PackedInt32Array = Gen2PicImage.canvas(extent.x, extent.y)
	var lookup: PackedInt32Array = Gen2PicImage.lookup(colors)
	for y: int in extent.y:
		for x: int in extent.x:
			var offset: int = (at.y + y) * width + at.x + x
			if offset < 0 or offset >= indices.size():
				continue
			pixels[y * extent.x + x] = lookup[mini(indices[offset], lookup.size() - 1)]
	return Gen2PicImage.canvas_image(pixels, extent.x, extent.y)


## `ReadMonMenuIcon`'s first frame, which is what the party menu puts beside a
## nickname. Composed there because Generation 1 mirrors half of every frame.
static func _species_icon(data: GameData, species: int, egg: bool) -> Image:
	if species <= 0 and not egg:
		return null
	return Gen2PartyMenuPage.icon_image(data, species, egg)


## The [param extent] rectangle of a sheet at [param at], as one picture, drawn
## [param scale] whole pixels per source pixel. The cache stores every sheet as
## one row of tiles, so a rectangle crossing a tile boundary is assembled here:
## [param stride] is how many tiles wide the sheet was before it was flattened.
## [param skip] is the colour left standing, zero for an object and -1 for a
## background sheet.
static func _crop(
	strip: PackedByteArray, stride: int, at: Vector2i, extent: Vector2i, scale: int,
	colors: PackedColorArray, skip: int
) -> Image:
	var factor: int = maxi(scale, 1)
	var out := Vector2i(extent.x * factor, extent.y * factor)
	var pixels: PackedInt32Array = Gen2PicImage.canvas(out.x, out.y)
	var lookup: PackedInt32Array = Gen2PicImage.lookup(colors)
	if stride <= 0 or lookup.is_empty() or out.x <= 0 or out.y <= 0:
		return Gen2PicImage.canvas_image(pixels, maxi(out.x, 1), maxi(out.y, 1))
	@warning_ignore("integer_division")
	var width: int = strip.size() / PokeTiles.TILE_HEIGHT
	for y: int in out.y:
		@warning_ignore("integer_division")
		var source_y: int = at.y + y / factor
		@warning_ignore("integer_division")
		var row: int = source_y / PokeTiles.TILE_HEIGHT
		var line: int = source_y % PokeTiles.TILE_HEIGHT
		for x: int in out.x:
			@warning_ignore("integer_division")
			var source_x: int = at.x + x / factor
			@warning_ignore("integer_division")
			var tile: int = row * stride + source_x / PokeTiles.TILE_WIDTH
			var offset: int = line * width \
				+ tile * PokeTiles.TILE_WIDTH + source_x % PokeTiles.TILE_WIDTH
			if offset < 0 or offset >= strip.size():
				continue
			var index: int = strip[offset]
			if index == skip:
				continue
			pixels[y * out.x + x] = lookup[mini(index, lookup.size() - 1)]
	return Gen2PicImage.canvas_image(pixels, out.x, out.y)


## The cache's own name for a sheet, which differs from the tab's for the two
## that have a Kris counterpart.
static func _sheet(data: GameData, name: String, female: bool) -> PackedByteArray:
	match name:
		"pack":
			var pockets: String = "pack_pockets_female" if female else "pack_pockets"
			var strip: PackedByteArray = data.tile_indices(pockets)
			return strip if not strip.is_empty() else data.tile_indices("pack_pockets")
		"card_pic":
			var card: String = "card_pic_female" if female else "card_pic_male"
			var pic: PackedByteArray = data.tile_indices(card)
			return pic if not pic.is_empty() else data.tile_indices("card_pic_male")
	return data.tile_indices(name)


## The palette the page each icon was cut from draws it with, so a tab is the
## same colours as the screen it opens.
static func _palette(data: GameData, kind: StringName, female: bool) -> PackedColorArray:
	## `HUDBallIcons` and `.writeTile`'s ball are two colours through whatever
	## their screen's palette is, so the marker is black on white on either.
	if kind == Gen2WorldStartMenu.ITEM_POKEDEX:
		return PokePalette.pic_palette(PackedColorArray([Color.WHITE, Color.BLACK]))
	if data.generation == RomRegistry.GEN1:
		return _gen1_palette(data, kind)
	match kind:
		Gen2WorldStartMenu.ITEM_PACK:
			var pack: PackedColorArray = data.pack_palette(PACK_PICTURE_PALETTE, female)
			return pack if not pack.is_empty() else data.pack_palette(PACK_PICTURE_PALETTE)
		Gen2WorldStartMenu.ITEM_POKEGEAR:
			return data.town_map_palette(
				data.town_map_palette_of(Gen2Layout.POKEGEAR_FIRST_TILE + 0x10), female
			)
		Gen2WorldStartMenu.ITEM_PLAYER:
			return data.card_palette(1 if female else 0)
	return PackedColorArray()


## The cursor and the card picture wear the `SuperPalettes` rows their own
## `PalPacket` names.
static func _gen1_palette(data: GameData, kind: StringName) -> PackedColorArray:
	match kind:
		Gen2WorldStartMenu.ITEM_TOWN_MAP:
			return Gen2WorldPalette.gen1_object_colors(
				data.world_palette(Gen1Layout.PAL_TOWNMAP)
			)
		Gen2WorldStartMenu.ITEM_PLAYER:
			return data.world_palette(Gen1Layout.PAL_MEWMON)
	return PackedColorArray()
