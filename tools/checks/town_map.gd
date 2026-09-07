extends RefCounted

var _r: RefCounted = null

## Verifies the region map against freshly imported real caches, on all three
## cartridges, and the Pokegear's other three cards with it, since they are the same
## VRAM window, palettes and page. Expected values come from the pinned sources'
## landmarks, the two region `.bin`s, the palette map and `_TownMap`. The
## real-cartridge counterpart to tests/unit/test_town_map.gd. What only a real cache
## can say is that the 96 landmarks and the two 360-cell maps decoded, that the
## Gold/Silver split is exactly the one `BATTLE TOWER` causes, and that `FindNest`
## keeps each region's own wild tables over all 251 species.


## The one landmark Gold and Silver do not ship, and the two either side of it in
## Crystal's table.
const BATTLE_TOWER: int = 29
const LIGHTHOUSE_NAME: String = "LIGHTHOUSE"
const BATTLE_TOWER_NAME: String = "BATTLE TOWER"
const ROUTE_40_NAME: String = "ROUTE 40"

## Landmarks whose names carry the `<BSP>` the region map breaks a line on, and
## one that does not, so both branches are covered on a real name.
const BROKEN_NAME: int = 1
const UNBROKEN_NAME: int = 2

## An icon is 16 pixels drawn around the landmark's own point, so a point within
## eight pixels of an edge hangs off it. Only `SPECIAL`, which is at (-8,-16) and
## is drawn by nothing, does.
const ICON_ORIGIN: int = Gen2TownMapScreen.ICON_ORIGIN
const LANDMARK_SPECIAL: int = 0

## One cell of each card tilemap that no other card has in that place: the clock
## card's own name-box corner, the phone card's frame, and the radio dial's scale
## row (gfx/pokegear/clock.tilemap.rle and its two neighbours).
const CARD_PINS: Array[Array] = [
	["clock", Vector2i(12, 0), 0x30],
	["clock", Vector2i(19, 2), 0x33],
	["phone", Vector2i(0, 2), 0x06],
	["radio", Vector2i(9, 2), 0x3B],
]

## `_PokegearAskWhoCallText` and `_PokegearPressButtonText`, whose `line` is the
## newline a decoded text carries.
const CARD_TEXTS: Dictionary = {
	"ask_who": "Whom do you want\nto call?",
	"press_button": "Press any button\nto exit.",
	"ellipse": "……",
	"out_of_service": "You're out of the\nservice area.",
}

## `wShadowOAMEnd - wShadowOAM` in sprites, which is what `.nestloop` would run
## past if a species were found at more landmarks than the hardware has objects.
const SHADOW_OAM_SPRITES: int = 40


## `LoadTownMapEntry` end to end: the external table's own first row, the first
## indoor map, the last one Silph Co.'s group covers, and Cerulean Cave, whose
## packed pair `DisplayWildLocations` refuses a nest icon by.
const GEN1_PALLET_TOWN: int = 0
const GEN1_LANDMARK_PINS: Array[Array] = [
	[0x00, "PALLET TOWN", 0xB2], [0x25, "PALLET TOWN", 0xB2],
	[0xEB, "SILPH CO.", 0x5A], [0xE4, "CERULEAN CAVE", 0x19],
]
## The places `TownMapOrder`'s 47 rows stand on: MT_MOON_1F and ROUTE_4 share
## Mt. Moon's own entry, which is why the walk shows one fewer.
const GEN1_ORDER_PLACES: int = 47
## `FindWildLocationsOfMon` on the two ends: PIKACHU stands in the Viridian
## Forest and the Power Plant, and in no wild table at all on Yellow, which hands
## one over instead; MEW is nowhere on any of the three.
const GEN1_NEST_PINS: Dictionary = {
	&"red": [[25, 2], [151, 0]],
	&"blue": [[25, 2], [151, 0]],
	&"yellow": [[25, 0], [151, 0]],
}


func run(r: RefCounted) -> void:
	_r = r
	for game_id: StringName in _r.GAME_IDS:
		var _data: GameData = GameData.open(game_id)
		if _data == null:
			_r.fail("%s cache is unavailable. Import roms/%s.gbc first." % [game_id, game_id])
			continue
		var crystal: bool = Gen2WorldState.is_crystal_profile(_data)
		_verify_landmarks(game_id, _data, crystal)
		_verify_regions(game_id, _data)
		_verify_palettes(game_id, _data, crystal)
		_verify_cursor_walk(game_id, _data, crystal)
		_verify_page(game_id, _data, crystal)
		_verify_nests(game_id, _data, crystal)
		_verify_flypoints(game_id, _data)
		_verify_cards(game_id, _data)
	_r.each_game_of(RomRegistry.GEN1, _one_gen1_game)


## `LoadTownMap` and the three screens over it, on Red, Blue and Yellow. What
## only a real cache can say is that `CompressedMap`'s runs fill the screen out
## of the sixteen tiles it has, that `LoadTownMapEntry` resolves every map id
## either table names, and that `FindWildLocationsOfMon` finds the species the
## cartridge's own wild tables hold.
func _one_gen1_game() -> void:
	_gen1_region()
	_gen1_landmarks()
	_gen1_cursor_walk()
	_gen1_fly_walk()
	_gen1_nests()
	_gen1_screens()


func _gen1_region() -> void:
	var cells: PackedByteArray = _r.data.town_map_region(
		Gen2TownMap.region_name(Gen2TownMap.REGION_KANTO)
	)
	if not _r.check(
		cells.size() == Gen1Layout.WORLD_MAP_CELLS,
		"the region map decoded to %d cells." % cells.size()
	):
		return
	var outside: int = 0
	for cell: int in cells:
		if cell < Gen1Layout.WORLD_MAP_FIRST_CODE 			or cell >= Gen1Layout.WORLD_MAP_FIRST_CODE + Gen1Layout.WORLD_MAP_TILES:
			outside += 1
	_r.check(outside == 0, "%d cells name a tile the sheet has not." % outside)
	_r.check(
		_r.data.town_map_palette(0).size() == PokePalette.COLORS_PER_PIC,
		"PAL_TOWNMAP decoded to %d colours." % _r.data.town_map_palette(0).size()
	)


## Every map id `LoadTownMapEntry` answers for, and the four rows pinned by hand:
## the external table's first, the internal walk's own first row above
## `FIRST_INDOOR_MAP`, the deepest indoor map, and Cerulean Cave, whose packed
## coordinates are what `DisplayWildLocations` refuses an icon by.
func _gen1_landmarks() -> void:
	var count: int = Gen1Layout.map_count(_r.data.id)
	_r.check(
		_r.data.landmark_count() == count,
		"%d landmark rows for %d maps." % [_r.data.landmark_count(), count]
	)
	var offscreen: int = 0
	var unnamed: int = 0
	for map: int in count:
		var entry: Dictionary = _r.data.landmark(map)
		if _r.data.landmark_name(map).is_empty():
			unnamed += 1
		var at := Vector2i(int(entry.get("x", -1)), int(entry.get("y", -1)))
		if at.x < 0 or at.y < 0 or at.x >= Gen2Screen.WIDTH or at.y >= Gen2Screen.HEIGHT:
			offscreen += 1
	_r.check(unnamed == 0, "%d map ids resolved to no name." % unnamed)
	_r.check(offscreen == 0, "%d landmark points fall off the screen." % offscreen)
	for pin: Array in GEN1_LANDMARK_PINS:
		var entry: Dictionary = _r.data.landmark(int(pin[0]))
		var name: String = _r.data.landmark_name(int(pin[0]))
		_r.check(
			name == String(pin[1]) and int(entry.get("packed", -1)) == int(pin[2]),
			"map %d is %s at $%02x." % [int(pin[0]), name, int(entry.get("packed", -1))]
		)


## `.pressedUp` and `.pressedDown` over `TownMapOrder`: 47 presses come back to
## the row the walk started on, and every row names a map the cache has.
func _gen1_cursor_walk() -> void:
	var order: PackedInt32Array = _r.data.town_map_order()
	if not _r.check(
		order.size() == Gen1Layout.TOWN_MAP_ORDER_COUNT,
		"TownMapOrder decoded to %d rows." % order.size()
	):
		return
	var missing: int = 0
	for map: int in order:
		if _r.data.world_map(0, map) == null:
			missing += 1
	_r.check(missing == 0, "%d order rows name a map the cache has not." % missing)
	var walk: Gen2TownMap = Gen2TownMap.create_gen1(GEN1_PALLET_TOWN, order)
	_r.check(
		walk.cursor == GEN1_PALLET_TOWN and not walk.row_cleared,
		"the map opened on %d rather than wCurMap." % walk.cursor
	)
	var seen: Dictionary = {}
	for _press: int in order.size():
		walk.press(PokeButton.UP)
		seen[walk.cursor] = true
	_r.check(
		walk.row_index == 0 and walk.cursor == order[0],
		"%d presses ended on row %d." % [order.size(), walk.row_index]
	)
	_r.check(
		seen.size() == GEN1_ORDER_PLACES,
		"the walk showed %d places of %d." % [seen.size(), GEN1_ORDER_PLACES]
	)
	walk.press(PokeButton.DOWN)
	_r.check(
		walk.row_index == order.size() - 1,
		"one DOWN press from the first row landed on %d." % walk.row_index
	)


## `BuildFlyLocationsList` and the walk over it: with Pallet Town alone visited
## every press stays there, and with all eleven the walk is a ring.
func _gen1_fly_walk() -> void:
	var lone := PackedInt32Array()
	var every := PackedInt32Array()
	for town: int in Gen1Layout.NUM_CITY_MAPS:
		lone.append(town if town == 0 else Gen1Layout.TOWN_MAP_NOT_VISITED)
		every.append(town)
	var alone: Gen2TownMap = Gen2TownMap.fly_gen1(GEN1_PALLET_TOWN, lone)
	alone.press(PokeButton.UP)
	_r.check(alone.cursor == 0, "an unvisited walk reached map %d." % alone.cursor)
	alone.press(PokeButton.DOWN)
	_r.check(alone.cursor == 0, "an unvisited walk fell to map %d." % alone.cursor)
	var full: Gen2TownMap = Gen2TownMap.fly_gen1(GEN1_PALLET_TOWN, every)
	var seen: Dictionary = {}
	for _press: int in Gen1Layout.NUM_CITY_MAPS:
		full.press(PokeButton.UP)
		seen[full.cursor] = true
	_r.check(
		seen.size() == Gen1Layout.NUM_CITY_MAPS and full.cursor == 0,
		"the fly walk showed %d towns and ended on %d." % [seen.size(), full.cursor]
	)
	var landings: int = 0
	for map: int in Gen1Layout.map_count(_r.data.id):
		var landing: Dictionary = _r.data.gen1_fly_warp(map)
		if landing.is_empty():
			continue
		landings += 1
		var record: Gen2WorldMap = _r.data.world_map(0, map)
		_r.check(
			record != null and int(landing["x"]) < record.collision_width
				and int(landing["y"]) < record.collision_height,
			"map %d lands a flight at %s." % [map, landing]
		)
	_r.check(
		landings == Gen1Layout.FLY_WARP_COUNT,
		"FlyWarpDataPtr decoded to %d rows." % landings
	)


## `FindWildLocationsOfMon` over all 151 species: every map it names holds the
## species in its own grass or water table, and no map is named twice.
func _gen1_nests() -> void:
	var wrong: int = 0
	var total: int = 0
	for species: int in range(1, Gen1Layout.SPECIES_COUNT + 1):
		var nests: Array = Gen2WorldEncounter.gen1_nests(_r.data, species)
		total += nests.size()
		var seen: Dictionary = {}
		for map: int in nests:
			if seen.has(map) or not _gen1_map_holds(map, species):
				wrong += 1
			seen[map] = true
	_r.check(wrong == 0, "%d nests name a map with no such wild slot." % wrong)
	_r.note("gen1 nests %s: %d over 151 species" % [_r.game_id, total])
	for pin: Array in GEN1_NEST_PINS[_r.game_id] as Array:
		var found: int = Gen2WorldEncounter.gen1_nests(_r.data, int(pin[0])).size()
		_r.check(found == int(pin[1]), "species %d has %d nests." % [int(pin[0]), found])


func _gen1_map_holds(map: int, species: int) -> bool:
	for method: StringName in [Gen2WorldEncounter.METHOD_GRASS, &"water"]:
		for slot: Variant in _r.data.world_encounter(method, 0, map).get("slots", []) as Array:
			if slot is Dictionary and int((slot as Dictionary).get("species", 0)) == species:
				return true
	return false


## The three screens drawn: `DisplayTownMap` on the map the player stands on,
## `LoadTownMap_Nest` for a species with no wild table, which is the AREA UNKNOWN
## box, and `LoadTownMap_Fly`. The blink is what the cursor answers to.
func _gen1_screens() -> void:
	var host := Gen2TownMapScreen.new()
	if not _r.check(host.open(_r.data, GEN1_PALLET_TOWN), "the map would not open."):
		host.free()
		return
	var shown: int = host.render().get_used_rect().size.y
	for _frame: int in Gen1Layout.TOWN_MAP_BLINK_FRAMES:
		host.advance_frame()
	_r.check(
		host.shadow_oam() == Gen2TownMapScreen.OAM_CLEARED,
		"the cursor was still up after %d frames." % Gen1Layout.TOWN_MAP_BLINK_FRAMES
	)
	_r.check(shown > 0, "the map drew an empty screen.")
	_r.check(
		host.open_gen1_dex_area(_r.data, Gen1Layout.SPECIES_COUNT, [], GEN1_PALLET_TOWN)
			and host.nest_count() == 0,
		"MEW's AREA screen drew a nest."
	)
	var towns := PackedInt32Array()
	for town: int in Gen1Layout.NUM_CITY_MAPS:
		towns.append(town)
	_r.check(host.open_gen1_fly(_r.data, GEN1_PALLET_TOWN, towns), "the fly map would not open.")
	host.handle_button(PokeButton.A)
	_r.check(host.chosen_spawn() == 0, "A on the fly map chose %d." % host.chosen_spawn())
	host.free()


## `Flypoints` and `SpawnPoints` against the cache they were imported beside: every
## flypoint names a landmark the region map draws and a spawn the table holds, and
## every spawn names a map this cartridge ships. The landmark column is the
## profile-split half, so this is where it is swept: Gold and Silver ship one
## landmark fewer, and a Crystal number read on either lands on the wrong city.
## Below, `_FlyMap`'s own walk on a real cache: with every flypoint visited, one
## press per row reaches each of the region's twelve and comes back to where it
## started.
func _verify_fly_walk(game_id: StringName, _data: GameData) -> void:
	var crystal: bool = Gen2WorldState.is_crystal_profile(_data)
	var visited: Array[int] = []
	for index: int in _data.flypoint_count():
		visited.append(index)
	for in_kanto: bool in [false, true]:
		var map: Gen2TownMap = Gen2TownMap.fly(
			Gen2TownMap.JOHTO_LANDMARK, in_kanto, visited, crystal
		)
		var opened: int = map.cursor
		var seen: Dictionary = {}
		for _press: int in Gen2Layout.KANTO_FLYPOINT:
			seen[map.cursor] = true
			var landmark: int = int(_data.flypoint(map.cursor).get("landmark", -1))
			var point: Dictionary = _data.landmark(landmark)
			_r.check(
				not point.is_empty(),
				"%s: flypoint %d names landmark %d, which the map cannot draw." % [
					game_id, map.cursor, landmark,
				]
			)
			map.press(PokeButton.UP)
		_r.check(
			seen.size() == Gen2Layout.KANTO_FLYPOINT,
			"%s: the %s fly walk reached %d flypoints, not %d." % [
				game_id, "Kanto" if in_kanto else "Johto", seen.size(),
				Gen2Layout.KANTO_FLYPOINT,
			]
		)
		_r.check(
			map.cursor == opened,
			"%s: the %s fly walk did not wrap back to where it opened." % [
				game_id, "Kanto" if in_kanto else "Johto",
			]
		)


func _verify_flypoints(game_id: StringName, _data: GameData) -> void:
	if not _r.check(
		_data.flypoint_count() == Gen2Layout.FLYPOINT_COUNT,
		"%s: %d flypoints, not %d." % [
			game_id, _data.flypoint_count(), Gen2Layout.FLYPOINT_COUNT,
		]
	):
		return
	if not _r.check(
		_data.spawn_point_count() == Gen2Layout.SPAWN_COUNT,
		"%s: %d spawn points, not %d." % [
			game_id, _data.spawn_point_count(), Gen2Layout.SPAWN_COUNT,
		]
	):
		return

	var seen: Dictionary = {}
	for index: int in _data.flypoint_count():
		var row: Dictionary = _data.flypoint(index)
		var landmark: int = int(row["landmark"])
		var spawn: int = int(row["spawn"])
		_r.check(
			landmark > 0 and landmark < _data.landmark_count(),
			"%s: flypoint %d names landmark %d, which this cartridge does not ship." % [
				game_id, index, landmark,
			]
		)
		_r.check(
			not seen.has(landmark),
			"%s: flypoint %d repeats landmark %d." % [game_id, index, landmark]
		)
		seen[landmark] = true
		var point: Dictionary = _data.spawn_point(spawn)
		_r.check(
			not point.is_empty() and _data.world_map(
				int(point["map_group"]), int(point["map_number"])
			) != null,
			"%s: flypoint %d lands on spawn %d, which names no map." % [
				game_id, index, spawn,
			]
		)
		# Johto first, Kanto behind it: `FlyMap` picks a region's cursor range
		# off that split alone.
		_r.check(
			(landmark < Gen2WorldRadio.kanto_landmark(Gen2WorldState.is_crystal_profile(_data)))
				== (index < Gen2Layout.KANTO_FLYPOINT),
			"%s: flypoint %d is on the wrong side of the region split." % [game_id, index]
		)
	for index: int in _data.spawn_point_count():
		var point: Dictionary = _data.spawn_point(index)
		_r.check(
			_data.world_map(int(point["map_group"]), int(point["map_number"])) != null,
			"%s: spawn %d names map %d.%d, which this cartridge does not ship." % [
				game_id, index, int(point["map_group"]), int(point["map_number"]),
			]
		)
	_verify_fly_walk(game_id, _data)
	print("%s: %d flypoints over %d spawn points, %d of them Johto." % [
		game_id, _data.flypoint_count(), _data.spawn_point_count(), Gen2Layout.KANTO_FLYPOINT,
	])


func _verify_landmarks(game_id: StringName, _data: GameData, crystal: bool) -> void:
	var wanted: int = Gen2Layout.LANDMARK_COUNT if crystal \
		else Gen2Layout.LANDMARK_COUNT_GOLD_SILVER
	if not _r.check(
		_data.landmark_count() == wanted,
		"%s: %d landmarks, expected %d." % [game_id, _data.landmark_count(), wanted]
	):
		return
	_r.check(
		_data.landmark_name(LANDMARK_SPECIAL) == "SPECIAL",
		"%s: landmark 0 is %s, not SPECIAL." % [game_id, _data.landmark_name(LANDMARK_SPECIAL)]
	)
	# The whole profile split, as one row: Crystal inserts BATTLE TOWER after the
	# Lighthouse and everything past it is one higher.
	_r.check(
		_data.landmark_name(BATTLE_TOWER - 1) == LIGHTHOUSE_NAME,
		"%s: landmark %d is %s, not %s." % [
			game_id, BATTLE_TOWER - 1, _data.landmark_name(BATTLE_TOWER - 1), LIGHTHOUSE_NAME,
		]
	)
	var after: String = BATTLE_TOWER_NAME if crystal else ROUTE_40_NAME
	_r.check(
		_data.landmark_name(BATTLE_TOWER) == after,
		"%s: landmark %d is %s, not %s." % [
			game_id, BATTLE_TOWER, _data.landmark_name(BATTLE_TOWER), after,
		]
	)
	_r.check(
		_data.landmark_name(_data.landmark_count() - 1) == "FAST SHIP",
		"%s: the last landmark is %s, not FAST SHIP." % [
			game_id, _data.landmark_name(_data.landmark_count() - 1),
		]
	)
	_r.check(
		_breaks(_data, BROKEN_NAME),
		"%s: landmark %d carries no line break." % [game_id, BROKEN_NAME]
	)
	_r.check(
		not _breaks(_data, UNBROKEN_NAME),
		"%s: landmark %d carries a line break it should not." % [game_id, UNBROKEN_NAME]
	)
	for index: int in range(1, _data.landmark_count()):
		var entry: Dictionary = _data.landmark(index)
		var x: int = int(entry.get("x", -1))
		var y: int = int(entry.get("y", -1))
		if not _r.check(
			x >= ICON_ORIGIN and x + ICON_ORIGIN <= Gen2Screen.WIDTH \
				and y >= ICON_ORIGIN and y + ICON_ORIGIN <= Gen2Screen.HEIGHT,
			"%s: landmark %d (%s) is at (%d,%d); its icon hangs off the screen." % [
				game_id, index, _data.landmark_name(index), x, y,
			]
		):
			return


## Whether a landmark's name carries the `<BSP>` the region map breaks on.
func _breaks(_data: GameData, landmark: int) -> bool:
	var codes: PackedByteArray = _data.landmark(landmark).get("codes", PackedByteArray())
	return Gen2TownMapPage.NAME_BREAK_CODES[0] in codes


func _verify_regions(game_id: StringName, _data: GameData) -> void:
	for region: String in ["johto", "kanto"]:
		var cells: PackedByteArray = _data.town_map_region(region)
		if not _r.check(
			cells.size() == Gen2Layout.TOWN_MAP_REGION_CELLS,
			"%s: the %s map is %d cells, expected %d." % [
				game_id, region, cells.size(), Gen2Layout.TOWN_MAP_REGION_CELLS,
			]
		):
			continue
		for cell: int in cells:
			if not _r.check(
				cell < Gen2Layout.TOWN_MAP_TILES,
				"%s: the %s map names tile $%02X, past TownMapGFX." % [game_id, region, cell]
			):
				break


func _verify_palettes(game_id: StringName, _data: GameData, crystal: bool) -> void:
	for slot: int in Gen2Layout.TOWN_MAP_PALETTES:
		var colors: PackedColorArray = _data.town_map_palette(slot)
		if not _r.check(
			colors.size() == Gen2Layout.TOWN_MAP_PALETTE_COLORS,
			"%s: region palette %d has %d colours." % [game_id, slot, colors.size()]
		):
			continue
		_r.check(
			colors[0] == PokePalette.from_packed(Gen2Layout.TOWN_MAP_PALETTE_FIRST_COLOR),
			"%s: region palette %d does not open on the shared off-white." % [game_id, slot]
		)
	# `TownMapPals`' table stops at $60; the font above it takes palette 0.
	_r.check(
		_data.town_map_palette_of(Gen2Layout.TOWN_MAP_PALETTE_MAP_LIMIT) == 0,
		"%s: a tile past the palette map is not on palette 0." % game_id
	)
	# `FemalePokegearPals` differs from the male run in its city palette alone,
	# and only Crystal ships one.
	var male: PackedColorArray = _data.town_map_palette(Gen2TownMapPage.CITY_PALETTE)
	var female: PackedColorArray = _data.town_map_palette(Gen2TownMapPage.CITY_PALETTE, true)
	_r.check(
		(male != female) == crystal,
		"%s: the female city palette %s the male one." % [
			game_id, "matches" if male == female else "differs from",
		]
	)


## `.pressed_up` and `.pressed_down` walk the whole window and wrap at both ends,
## so a full lap visits every landmark in it exactly once and comes home.
func _verify_cursor_walk(game_id: StringName, _data: GameData, crystal: bool) -> void:
	for opened: bool in [false, true]:
		for landmark: int in [Gen2TownMap.JOHTO_LANDMARK, Gen2WorldRadio.kanto_landmark(crystal)]:
			var map := Gen2TownMap.create(landmark, crystal, opened)
			map.cursor = map.first_landmark()
			var seen: Dictionary = {}
			var length: int = map.last_landmark() - map.first_landmark() + 1
			for _step: int in length:
				seen[map.cursor] = true
				map.press(PokeButton.UP)
			_r.check(
				seen.size() == length and map.cursor == map.first_landmark(),
				"%s: the %d..%d window walks %d landmarks and lands on %d." % [
					game_id, map.first_landmark(), map.last_landmark(), seen.size(), map.cursor,
				]
			)
			map.press(PokeButton.DOWN)
			_r.check(
				map.cursor == map.last_landmark(),
				"%s: DOWN from %d reached %d, not %d." % [
					game_id, map.first_landmark(), map.cursor, map.last_landmark(),
				]
			)
	# Kanto opens on the Victory Road window until the Hall of Fame is set.
	var kanto: int = Gen2WorldRadio.kanto_landmark(crystal)
	var sealed := Gen2TownMap.create(kanto, crystal, false)
	var shift: int = 0 if crystal else 1
	_r.check(
		sealed.first_landmark() == Gen2TownMap.LANDMARK_VICTORY_ROAD - shift,
		"%s: the sealed Kanto window opens at %d." % [game_id, sealed.first_landmark()]
	)
	_r.check(
		Gen2TownMap.create(kanto, crystal, true).first_landmark() == kanto,
		"%s: the Hall of Fame does not open the whole Kanto window." % game_id
	)


## The page against the real art: every tile a region map or a frame names has to
## resolve out of the two sheets, and both screens have to compose.
func _verify_page(game_id: StringName, _data: GameData, crystal: bool) -> void:
	var page: Gen2TownMapPage = Gen2TownMapPage.from_data(_data)
	if not _r.check(page != null and page.ready(), "%s: the region map art is missing." % game_id):
		return
	# The two objects the screen draws come off strips of their own.
	for sheet: Array in [
		["pokegear_sprites", Gen2Layout.POKEGEAR_SPRITE_TILES],
		["fast_ship", Gen2Layout.FAST_SHIP_TILES],
		["fly_map_label", Gen2Layout.FLY_MAP_LABEL_TILES],
	]:
		_r.check(
			_data.tile_indices(String(sheet[0])).size()
				== int(sheet[1]) * PokeTiles.TILE_PIXELS,
			"%s: the %s strip is not %d tiles." % [game_id, sheet[0], int(sheet[1])]
		)
	for screen: StringName in [
		Gen2TownMap.SCREEN_TOWN_MAP, Gen2TownMap.SCREEN_POKEGEAR_CARD,
		Gen2TownMap.SCREEN_DEX_AREA, Gen2TownMap.SCREEN_FLY,
	]:
		for region: String in ["johto", "kanto"]:
			var landmark: int = BROKEN_NAME if region == "johto" \
				else Gen2WorldRadio.kanto_landmark(crystal)
			var map: PackedInt32Array = page.tilemap(
				_data.town_map_region(region),
				_data.landmark(landmark).get("codes", PackedByteArray()),
				screen,
				[&"map", &"phone", &"radio"] as Array,
			)
			var image: Image = page.image(_data, map, false, screen)
			_r.check(
				image.get_width() == Gen2Screen.WIDTH \
					and image.get_height() == Gen2Screen.HEIGHT,
				"%s: the %s %s screen did not compose." % [game_id, region, screen]
			)
			if screen == Gen2TownMap.SCREEN_FLY:
				_verify_fly_bubble(game_id, region, map)


## `TownMapBubble`'s own cells, transcribed here rather than read off the page:
## the four corners of the label border, the arrow at the right of its middle row
## and `Where?` in the top left.
const FLY_BUBBLE_CELLS: Array[Array] = [
	[Vector2i(1, 0), 0x30], [Vector2i(18, 0), 0x31],
	[Vector2i(1, 2), 0x32], [Vector2i(18, 2), 0x33],
	[Vector2i(18, 1), 0x34],
]
const FLY_BUBBLE_WHERE_AT: Vector2i = Vector2i(2, 0)


func _verify_fly_bubble(game_id: StringName, region: String, map: PackedInt32Array) -> void:
	for cell: Array in FLY_BUBBLE_CELLS:
		var at: Vector2i = cell[0]
		var tile: int = map[at.y * Gen2TownMapPage.COLUMNS + at.x]
		_r.check(
			tile == int(cell[1]),
			"%s: the %s fly bubble has $%02X at (%d,%d), wanted $%02X." % [
				game_id, region, tile, at.x, at.y, int(cell[1]),
			]
		)
	var where: PackedByteArray = Gen2Text.encode("Where?")
	for index: int in where.size():
		var at: Vector2i = FLY_BUBBLE_WHERE_AT + Vector2i(index, 0)
		_r.check(
			map[at.y * Gen2TownMapPage.COLUMNS + at.x] == where[index],
			"%s: the %s fly bubble does not say Where? at (%d,%d)." % [
				game_id, region, at.x, at.y,
			]
		)


## `FindNest` over the whole species range, which is the only sweep that can say
## the merged encounter tables kept their regions: a Johto walk that reached a
## Kanto row would put a nest on the wrong map.
func _verify_nests(game_id: StringName, _data: GameData, crystal: bool) -> void:
	_r.check(
		_data.tile_indices("dex_nest_icon").size()
			== Gen2Layout.DEX_NEST_ICON_TILES * PokeTiles.TILE_PIXELS,
		"%s: the dex nest icon is not one tile." % game_id
	)
	var kanto_first: int = Gen2WorldRadio.kanto_landmark(crystal)
	var roaming: Array = _data.world_roaming_mons()
	var deepest: int = 0
	for species: int in range(1, Gen2Layout.SPECIES_COUNT + 1):
		for region: int in Gen2TownMap.REGION_NAMES.size():
			var list: Array = Gen2WorldEncounter.nests(
				_data, species, Gen2TownMap.region_name(region), roaming
			)
			deepest = maxi(deepest, list.size())
			var seen: Dictionary = {}
			for landmark: int in list:
				var in_kanto: bool = landmark >= kanto_first
				if not _r.check(
					landmark != LANDMARK_SPECIAL and in_kanto == (region == Gen2TownMap.REGION_KANTO)
						and not seen.has(landmark),
					"%s: species %d's %s nests name landmark %d." % [
						game_id, species, Gen2TownMap.region_name(region), landmark,
					]
				):
					return
				seen[landmark] = true
	# `.nestloop` writes straight into shadow OAM with no bound of its own, so a
	# species over forty landmarks would run past it. None comes close.
	_r.check(
		deepest <= SHADOW_OAM_SPRITES,
		"%s: a species nests at %d landmarks, past shadow OAM's %d." % [
			game_id, deepest, SHADOW_OAM_SPRITES,
		]
	)
	# `.RoamMon1` and `.RoamMon2` put a roamer on whatever map it is standing on,
	# and only in Johto. There is no `.RoamMon3`, so Gold and Silver's Suicune
	# has no nest at all.
	for index: int in roaming.size():
		var mon: Dictionary = roaming[index]
		var species: int = int(mon["species"])
		var map: Gen2WorldMap = _data.world_map(int(mon["map_group"]), int(mon["map_number"]))
		var wanted: Array = [] if index >= Gen2WorldEncounter.ROAM_NEST_MONS \
			else [map.location]
		_r.check(
			Gen2WorldEncounter.nests(_data, species, "johto", roaming) == wanted,
			"%s: roamer %d (species %d) does not nest on %s." % [
				game_id, index, species, str(wanted),
			]
		)
		_r.check(
			Gen2WorldEncounter.nests(_data, species, "kanto", roaming).is_empty(),
			"%s: roamer %d (species %d) nests in Kanto." % [game_id, index, species]
		)


## The clock, phone and radio cards on a real cache: each RLE tilemap decoded to
## a whole screen out of the two sheets, both Pokegear texts as the source's own
## words, and the page drawing all three. The tilemaps and the texts are byte
## identical on the three cartridges, so the pins below are the same everywhere.
func _verify_cards(game_id: StringName, _data: GameData) -> void:
	var page: Gen2TownMapPage = Gen2TownMapPage.from_data(_data)
	if not _r.check(
		page != null and page.cards_ready(),
		"%s: the cache holds no Pokegear card tilemaps." % game_id
	):
		return
	for card: String in Gen2Layout.POKEGEAR_CARD_ORDER:
		var cells: PackedByteArray = _data.pokegear_card(StringName(card))
		if not _r.check(
			cells.size() == Gen2Layout.POKEGEAR_CARD_CELLS,
			"%s: the %s card is %d cells, wanted %d." % [
				game_id, card, cells.size(), Gen2Layout.POKEGEAR_CARD_CELLS,
			]
		):
			continue
		for cell: int in cells:
			if not _r.check(
				cell < Gen2Layout.POKEGEAR_FIRST_TILE + Gen2Layout.POKEGEAR_TILES
					or cell == Gen2TownMapPage.BLANK_TILE,
				"%s: the %s card names tile $%02X, past its sheets." % [game_id, card, cell]
			):
				break
	for pin: Array in CARD_PINS:
		var cells: PackedByteArray = _data.pokegear_card(StringName(pin[0]))
		var at: Vector2i = pin[1]
		var cell: int = int(cells[at.y * Gen2TownMapPage.COLUMNS + at.x])
		_r.check(
			cell == int(pin[2]),
			"%s: the %s card has $%02X at (%d,%d), wanted $%02X." % [
				game_id, pin[0], cell, at.x, at.y, int(pin[2]),
			]
		)
	for name: String in CARD_TEXTS:
		_r.check(
			_data.pokegear_text(name) == String(CARD_TEXTS[name]),
			"%s: Pokegear text %s reads \"%s\"." % [
				game_id, name, _data.pokegear_text(name).replace("\n", "|"),
			]
		)
	## `PrintHoursMins` and `_GearTodayText` on the card the cartridge draws
	## them on, read back off the tile map the page built.
	var map: PackedInt32Array = page.clock_tilemap([&"map"], 3, 13, 5, "")
	_r.check(
		_card_text(map, Gen2TownMapPage.CLOCK_TIME_AT, 8) == " 1:05 PM",
		"%s: the clock card reads \"%s\"." % [
			game_id, _card_text(map, Gen2TownMapPage.CLOCK_TIME_AT, 8),
		]
	)
	print("%s: 3 Pokegear cards of %d cells, %d texts." % [
		game_id, Gen2Layout.POKEGEAR_CARD_CELLS, CARD_TEXTS.size(),
	])


func _card_text(map: PackedInt32Array, at: Vector2i, length: int) -> String:
	var out: String = ""
	for column: int in length:
		out += Gen2Text.character(map[at.y * Gen2TownMapPage.COLUMNS + at.x + column])
	return out
