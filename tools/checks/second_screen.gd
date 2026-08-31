extends RefCounted

var _r: RefCounted = null

## Verifies the lower display against freshly imported real caches on all three
## cartridges. Three things only a real cache can say: that every tab the START
## menu's gate opens has a page this cache can draw; that every tab's icon is in
## the sheet it names at the pixels it names, rather than one colour cut from the
## wrong place; and that Kris's pack and card picture are taken where Crystal ships
## them and fall back to Chris's where pokegold does not. The gate itself is
## asserted in tests/unit/test_second_screen.gd, which needs no cartridge.

## Every state the three gates can be in, as `[party, pokedex, pokegear]`. All
## eight, because a run reaches most of them: the Pokegear arrives before the dex
## on the cartridge's own path and after it on a walk that skips Elm's errand.
const GATES: Array[Array] = [
	[0, false, false], [0, true, false], [0, false, true], [0, true, true],
	[1, false, false], [1, true, false], [1, false, true], [1, true, true],
]

## Cyndaquil, which every cartridge here ships and which has a menu icon, so the
## #MON tab has something to draw whatever the profile.
const LEAD_SPECIES: int = 155

## An icon cut from the wrong pixels is usually one flat colour, so this is what
## says a crop landed on a picture rather than on a sheet's blank margin.
const MINIMUM_COLORS: int = 2


func run(r: RefCounted) -> void:
	_r = r
	for game_id: StringName in _r.GAME_IDS:
		var data: GameData = GameData.open(game_id)
		if data == null:
			_r.fail("%s cache is unavailable. Import roms/%s.gbc first." % [game_id, game_id])
			continue
		_verify_pages(game_id, data)
		_verify_icons(game_id, data, false)
		_verify_icons(game_id, data, true)
		_verify_gender_sheets(game_id, data)


## Every tab any gate can open has the page renderer that tab is built from.
##
## A tab whose page refuses would be a row on the panel that opens a black
## rectangle, which is worse than the tab not being there.
func _verify_pages(game_id: StringName, data: GameData) -> void:
	var offered: Dictionary = {}
	for gate: Array in GATES:
		var tabs: Gen2SecondScreenTabs = Gen2SecondScreenTabs.build(
			int(gate[0]), bool(gate[1]), bool(gate[2]), "CHRIS"
		)
		for entry: Dictionary in tabs.items():
			offered[StringName(entry["kind"])] = true
	_r.check(
		offered.size() == Gen2SecondScreenTabs.VIEWABLE.size(),
		"%s: the eight gates between them offer every tab (%d of %d)" % [
			game_id, offered.size(), Gen2SecondScreenTabs.VIEWABLE.size()
		]
	)
	for kind: StringName in offered:
		_r.check(_page_ready(data, kind), "%s: the %s page is drawable" % [game_id, kind])


## What each tab's page is built from, asked the same question
## [method Gen2SecondScreen._build_page] asks it.
func _page_ready(data: GameData, kind: StringName) -> bool:
	match kind:
		Gen2WorldStartMenu.ITEM_POKEDEX:
			var dex: Gen2PokedexPage = Gen2PokedexPage.from_data(data)
			return dex != null and dex.ready()
		Gen2WorldStartMenu.ITEM_POKEMON:
			return Gen2PartyMenuPage.from_data(data) != null
		Gen2WorldStartMenu.ITEM_PACK:
			var pack: Gen2PackPage = Gen2PackPage.from_data(data)
			return pack != null and pack.ready()
		Gen2WorldStartMenu.ITEM_POKEGEAR:
			## Both cards the tab can show come off the same page, and the MAP
			## card also needs the region map itself.
			var gear: Gen2TownMapPage = Gen2TownMapPage.from_data(data)
			return gear != null and gear.ready() and gear.cards_ready() \
				and data.landmark_count() > 0
		Gen2WorldStartMenu.ITEM_PLAYER:
			var card: Gen2TrainerCardPage = Gen2TrainerCardPage.from_data(
				data, false, Gen2WorldState.is_crystal_profile(data)
			)
			return card != null and card.ready()
	return false


func _verify_icons(game_id: StringName, data: GameData, female: bool) -> void:
	var who: String = "Kris" if female else "Chris"
	for kind: StringName in Gen2SecondScreenTabs.VIEWABLE:
		var icon: Image = Gen2SecondScreenTabs.icon(data, kind, LEAD_SPECIES, female)
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
	## Kris's own sheets ship with Crystal alone. pokegold has no female player
	## at all, so the fallback to Chris's is unreachable in a game and is the
	## honest answer for a tool that asks anyway.
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
