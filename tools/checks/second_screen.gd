extends RefCounted

var _r: RefCounted = null

## Verifies the lower display against freshly imported real caches on all six
## cartridges. Three things only a real cache can say: that every tab the START
## menu's gate opens has a page this cache can draw; that every icon is in the
## sheet it names at the pixels it names rather than one colour cut from the
## wrong place; and that Kris's pack and card picture are taken where Crystal
## ships them. The gate itself is asserted in tests/unit/test_second_screen.gd.

## Every state the three gates can be in, as `[party, pokedex, pokegear]`. All
## eight: a run reaches most of them, in either order.
const GATES: Array[Array] = [
	[0, false, false], [0, true, false], [0, false, true], [0, true, true],
	[1, false, false], [1, true, false], [1, false, true], [1, true, true],
]

## Cyndaquil and Bulbasaur, which are the lead a check of each generation asks
## for: both ship a menu icon, so the #MON tab has something to draw.
const LEAD_SPECIES: int = 155
const GEN1_LEAD_SPECIES: int = 1

## Crystal's Pokegear carries the map; Generation 1 has no Pokegear.
const GEN1_ABSENT: Array[StringName] = [Gen2WorldStartMenu.ITEM_POKEGEAR]
const GEN2_ABSENT: Array[StringName] = [Gen2WorldStartMenu.ITEM_TOWN_MAP]
## Generation 1's ITEM row has no picture to cut, so its label is drawn.
const GEN1_UNPICTURED: Array[StringName] = [Gen2WorldStartMenu.ITEM_PACK]

## An icon cut from the wrong pixels is usually one flat colour.
const MINIMUM_COLORS: int = 2


func run(r: RefCounted) -> void:
	_r = r
	for generation: int in [RomRegistry.GEN1, RomRegistry.GEN2]:
		_r.each_game_of(generation, func() -> void:
			_verify_pages(_r.game_id, _r.data)
			_verify_icons(_r.game_id, _r.data, false)
			if _r.data.generation == RomRegistry.GEN2:
				_verify_icons(_r.game_id, _r.data, true)
				_verify_gender_sheets(_r.game_id, _r.data)
		)


## Every tab any gate can open has the renderer it is built from.
func _verify_pages(game_id: StringName, data: GameData) -> void:
	var offered: Dictionary = {}
	for gate: Array in GATES:
		var tabs: Gen2SecondScreenTabs = Gen2SecondScreenTabs.build(
			int(gate[0]), bool(gate[1]), bool(gate[2]), "CHRIS", data.generation, true
		)
		for entry: Dictionary in tabs.items():
			offered[StringName(entry["kind"])] = true
	var absent: Array[StringName] = _absent(data)
	_r.check(
		offered.size() == Gen2SecondScreenTabs.VIEWABLE.size() - absent.size(),
		"%s: the eight gates between them offer every tab (%d of %d)" % [
			game_id, offered.size(),
			Gen2SecondScreenTabs.VIEWABLE.size() - absent.size()
		]
	)
	for kind: StringName in absent:
		_r.check(not offered.has(kind), "%s: no gate offers %s" % [game_id, kind])
	for kind: StringName in offered:
		_r.check(_page_ready(data, kind), "%s: the %s page is drawable" % [game_id, kind])


## The tabs this generation has no row for at all.
func _absent(data: GameData) -> Array[StringName]:
	return GEN1_ABSENT if data.generation == RomRegistry.GEN1 else GEN2_ABSENT


## What each tab's page is built from, asked the same question
## [method Gen2SecondScreen._build_page] asks it.
func _page_ready(data: GameData, kind: StringName) -> bool:
	var gen1: bool = data.generation == RomRegistry.GEN1
	match kind:
		Gen2WorldStartMenu.ITEM_POKEDEX:
			var dex: Gen2PokedexPage = Gen2PokedexPage.from_data(data)
			return dex != null and dex.ready()
		Gen2WorldStartMenu.ITEM_POKEMON:
			return Gen2PartyMenuPage.from_data(data) != null
		Gen2WorldStartMenu.ITEM_PACK:
			## Generation 1 has no `PackGFX`: `StartMenu_Item` is the same framed
			## list the shop is drawn in.
			if gen1:
				return Gen2MartPage.from_data(data) != null
			var pack: Gen2PackPage = Gen2PackPage.from_data(data)
			return pack != null and pack.ready()
		Gen2WorldStartMenu.ITEM_TOWN_MAP:
			var region: Gen2TownMapPage = Gen2TownMapPage.from_data(data)
			return region != null and region.ready() and data.landmark_count() > 0
		Gen2WorldStartMenu.ITEM_POKEGEAR:
			## Both cards the tab can show come off the same page, and the MAP
			## card also needs the region map itself.
			var gear: Gen2TownMapPage = Gen2TownMapPage.from_data(data)
			return gear != null and gear.ready() and gear.cards_ready() \
				and data.landmark_count() > 0
		Gen2WorldStartMenu.ITEM_PLAYER:
			var card: Gen2TrainerCardPage = Gen2TrainerCardPage.from_data(
				data, false, not gen1 and Gen2WorldState.is_crystal_profile(data)
			)
			return card != null and card.ready()
	return false


func _verify_icons(game_id: StringName, data: GameData, female: bool) -> void:
	var who: String = "Kris" if female else "Chris"
	var gen1: bool = data.generation == RomRegistry.GEN1
	var lead: int = GEN1_LEAD_SPECIES if gen1 else LEAD_SPECIES
	for kind: StringName in Gen2SecondScreenTabs.VIEWABLE:
		if _absent(data).has(kind):
			continue
		var icon: Image = Gen2SecondScreenTabs.icon(data, kind, lead, female)
		if gen1 and GEN1_UNPICTURED.has(kind):
			_r.check(icon == null, "%s: the %s tab draws its label" % [game_id, kind])
			continue
		if not _r.check(icon != null, "%s: the %s icon is cut (%s)" % [game_id, kind, who]):
			continue
		var colors: int = _colors(icon)
		_r.check(
			colors >= MINIMUM_COLORS,
			"%s: the %s icon is a picture rather than one flat colour (%s, %d)" % [
				game_id, kind, who, colors
			]
		)
		_r.check(
			icon.get_height() <= Gen2SecondScreenTabs.ICON_MAX,
			"%s: the %s icon fits the tab row (%s, %d high)" % [
				game_id, kind, who, icon.get_height()
			]
		)


## An egg has no species and still has an icon, which is the one #MON tab a
## player can reach with nothing else in the party.
func _verify_gender_sheets(game_id: StringName, data: GameData) -> void:
	_r.check(
		Gen2SecondScreenTabs.icon(data, Gen2WorldStartMenu.ITEM_POKEMON, 0, false, true) != null,
		"%s: a party led by an egg has a #MON icon" % game_id
	)
	## Kris's own sheets ship with Crystal alone, so the fallback to Chris's is
	## unreachable in a game and is the honest answer for a tool that asks.
	var crystal: bool = Gen2WorldState.is_crystal_profile(data)
	for sheet: String in ["pack_pockets_female", "card_pic_female"]:
		_r.check(
			data.tile_indices(sheet).is_empty() != crystal,
			"%s: %s is shipped only by Crystal" % [game_id, sheet]
		)
	for kind: StringName in [
		Gen2WorldStartMenu.ITEM_PACK, Gen2WorldStartMenu.ITEM_PLAYER,
	]:
		_r.check(
			Gen2SecondScreenTabs.icon(data, kind, 0, true) != null,
			"%s: the %s icon is drawn without Kris's own sheet" % [game_id, kind]
		)


func _colors(image: Image) -> int:
	var seen: Dictionary = {}
	for y: int in image.get_height():
		for x: int in image.get_width():
			seen[image.get_pixel(x, y)] = true
	return seen.size()
