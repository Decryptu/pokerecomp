class_name Gen2SecondScreenTabs
extends RefCounted

## Which pages a second display may show, and the icon each is reached by.
##
## The gate is not this file's: it is [Gen2WorldStartMenu]'s, filtered to the
## entries that are a picture rather than an action. A tab therefore appears on
## exactly the frame its START menu row does, so the team page cannot be opened
## before Elm has handed over a starter and the Pokegear page cannot be opened
## before the phone call that gives one. SAVE, OPTION and EXIT do something
## rather than show something, and a mod's own row is a screen this cannot draw,
## so neither reaches a tab.
##
## Node-free: it answers a list and an icon image, and the view decides where to
## put them.

## The START menu rows that are a page. In `SetUpMenuItems` order, which is the
## order they are drawn in.
const VIEWABLE: Array[StringName] = [
	Gen2WorldStartMenu.ITEM_POKEDEX,
	Gen2WorldStartMenu.ITEM_POKEMON,
	Gen2WorldStartMenu.ITEM_PACK,
	Gen2WorldStartMenu.ITEM_POKEGEAR,
	Gen2WorldStartMenu.ITEM_PLAYER,
]

## A species icon is two tiles by two, the size every 16x16 object the cartridge
## draws is. A crop out of a screen's own sheet is whatever that picture is:
## `PackGFX`'s bag is 32 by 20 and no smaller rectangle of it reads as a bag.
## [constant ICON_MAX] is the tallest any of them is, which is what the tab row
## has to be able to hold.
const ICON_TILE: int = 8
const ICON_SIZE: int = ICON_TILE * 2
const ICON_MAX: int = 20

## Where each tab's icon is cut from: the cache's own sheet name, the top-left
## pixel in that sheet's own grid, how many tiles wide that grid is, and how many
## whole pixels one source pixel is drawn as. Every one is art the page it opens
## already draws:
##
## | Tab | Icon |
## |---|---|
## | #DEX | the caught marker on the dex listing, which is one tile and so is drawn at two |
## | PACK | the middle of `PackGFX`'s five-by-three bag |
## | GEAR | `.PlacePokegearCardIcon`'s MAP icon, tile $40 less [constant RomLayout.POKEGEAR_FIRST_TILE] |
## | player | the head of `GetCardPic`'s own player picture |
##
## #MON has no entry: its icon is the party's lead, read live.
const ICONS: Dictionary = {
	Gen2WorldStartMenu.ITEM_POKEDEX: {
		"sheet": "pokedex", "at": Vector2i(112, 8), "size": Vector2i(8, 8),
		"stride": 16, "scale": 2,
	},
	Gen2WorldStartMenu.ITEM_PACK: {
		"sheet": "pack", "at": Vector2i(4, 2), "size": Vector2i(32, 20), "stride": 5,
	},
	Gen2WorldStartMenu.ITEM_POKEGEAR: {
		"sheet": "pokegear", "at": Vector2i(0, 8), "stride": 16,
	},
	Gen2WorldStartMenu.ITEM_PLAYER: {
		"sheet": "card_pic", "at": Vector2i(12, 0), "size": Vector2i(24, 20), "stride": 5,
	},
}

## `Gen2PackPage.ATTRIBUTES`' last row, which is the palette `_CGB_PackPals`
## gives the five-by-three picture.
const PACK_PICTURE_PALETTE: int = 5

var cursor: int = 0
var _items: Array = []


## [param party_count], [param pokedex] and [param pokegear] are the three gates
## `SetUpMenuItems` reads, and are handed straight to the START menu so the two
## lists cannot drift. [param player_name] is the STATUS row's own label.
static func build(
	party_count: int,
	pokedex: bool,
	pokegear: bool,
	player_name: String = "",
) -> Gen2SecondScreenTabs:
	var menu: Gen2WorldStartMenu = Gen2WorldStartMenu.build(
		party_count, pokedex, pokegear, 0, player_name
	)
	var out := Gen2SecondScreenTabs.new()
	for entry: Dictionary in menu.items():
		var kind: StringName = StringName(entry.get("kind", &""))
		if not VIEWABLE.has(kind):
			continue
		out._items.append({"kind": kind, "label": String(entry.get("label", ""))})
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
	)


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
	var spec: Variant = ICONS.get(kind, null)
	if not spec is Dictionary:
		return null
	var row: Dictionary = spec
	var strip: PackedByteArray = _sheet(data, String(row["sheet"]), female)
	var colors: PackedColorArray = _palette(data, kind, female)
	if strip.is_empty() or colors.size() < Gen2Palette.COLORS_PER_PIC:
		return null
	return _crop(
		strip, int(row["stride"]), row.get("at", Vector2i.ZERO),
		row.get("size", Vector2i(ICON_SIZE, ICON_SIZE)),
		int(row.get("scale", 1)), colors, -1
	)


## `ReadMonMenuIcon`'s first frame, drawn with `InitPartyMenuOBPals`' own
## palette, which is what the party menu puts beside a nickname. The frame is its
## own two-tile-wide grid, so it is cut exactly like a sheet is.
static func _species_icon(data: GameData, species: int, egg: bool) -> Image:
	if species <= 0 and not egg:
		return null
	var strip: PackedByteArray = data.species_icon_indices(species, egg)
	var colors: PackedColorArray = data.party_menu_icon_palette()
	if strip.is_empty() or colors.size() < Gen2Palette.COLORS_PER_PIC:
		return null
	return _crop(
		strip, 2, Vector2i.ZERO, Vector2i(ICON_SIZE, ICON_SIZE), 1, colors, 0
	)


## The [param extent] rectangle of a sheet at [param at], as one picture, drawn
## [param scale] whole pixels per source pixel.
##
## The cache stores every sheet as a single row of tiles, so a rectangle that
## crosses a tile boundary is assembled here rather than blitted: [param stride]
## is how many tiles wide the sheet was before it was flattened, which is the
## only thing that says where its second row of tiles went.
##
## [param skip] is the colour left standing: zero for a species icon, which is an
## object and never draws its own index 0, and -1 for a background sheet, whose
## four colours are all drawn.
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
	var width: int = strip.size() / Gen2Tiles.TILE_HEIGHT
	for y: int in out.y:
		@warning_ignore("integer_division")
		var source_y: int = at.y + y / factor
		@warning_ignore("integer_division")
		var row: int = source_y / Gen2Tiles.TILE_HEIGHT
		var line: int = source_y % Gen2Tiles.TILE_HEIGHT
		for x: int in out.x:
			@warning_ignore("integer_division")
			var source_x: int = at.x + x / factor
			@warning_ignore("integer_division")
			var tile: int = row * stride + source_x / Gen2Tiles.TILE_WIDTH
			var offset: int = line * width \
				+ tile * Gen2Tiles.TILE_WIDTH + source_x % Gen2Tiles.TILE_WIDTH
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
	match kind:
		Gen2WorldStartMenu.ITEM_POKEDEX:
			return data.pokedex_palette("interface")
		Gen2WorldStartMenu.ITEM_PACK:
			var pack: PackedColorArray = data.pack_palette(PACK_PICTURE_PALETTE, female)
			return pack if not pack.is_empty() else data.pack_palette(PACK_PICTURE_PALETTE)
		Gen2WorldStartMenu.ITEM_POKEGEAR:
			return data.town_map_palette(
				data.town_map_palette_of(RomLayout.POKEGEAR_FIRST_TILE + 0x10), female
			)
		Gen2WorldStartMenu.ITEM_PLAYER:
			return data.card_palette(1 if female else 0)
	return PackedColorArray()
