extends RefCounted

## Verifies the backup warp against freshly imported real caches on all three
## cartridges: `wBackupWarpNumber`, `wBackupMapGroup` and `wBackupMapNumber`,
## which `SavePlayerData` copies into `sCurMapData` and which two unrelated
## routines both read.
##
## Expected values come from the pinned pokecrystal and pokegold sources:
## home/map.asm's `CopyWarpData` and `GetWarpDestCoords`, home/region.asm's
## `IsInJohto`, engine/overworld/landmarks.asm's `RegionCheck`,
## engine/overworld/scripting.asm's `Script_warpmod`, ram/wram.asm and
## engine/menus/save.asm.
##
## The finding the topic carries: a `warp_event` whose destination is -1 names
## no warp and no map of its own, and this port read the placeholder beside it,
## so the stairs out of every Pokemon Center's second floor led nowhere. The
## same three bytes are the landmark a `LANDMARK_SPECIAL` map borrows, so the
## radio, the battle track, the town map and the dex area screen all answered
## with Johto's defaults up there whatever region the player was in.
##
##   Godot --headless --path . -s res://tools/validate.gd -- backup_warp

## The six `warp_event`s in either corpus whose destination is -1, as
## [group, number, warp index]. Crystal and Gold and Silver disagree only on the
## Goldenrod dept store elevator's map number, which [constant ELEVATOR_CRYSTAL]
## and [constant ELEVATOR_GOLD_SILVER] name.
const ELEVATOR_CRYSTAL: Array = [[11, 17, 1], [11, 17, 2]]
const ELEVATOR_GOLD_SILVER: Array = [[11, 18, 1], [11, 18, 2]]
const SHARED_BACKUP_WARPS: Array = [
	[15, 3, 1],  # FAST_SHIP_1F's cabin
	[20, 1, 1],  # POKECENTER_2F's stairs
	[21, 11, 1], [21, 11, 2],  # the Celadon dept store elevator
]

## POKECENTER_2F, the one `LANDMARK_SPECIAL` map that is not a cable club room.
const POKECENTER_2F_GROUP: int = 20
const POKECENTER_2F: int = 1
const POKECENTER_2F_STAIRS: Vector2i = Vector2i(0, 7)

## Cherrygrove City's Pokemon Center, its stairs cell and the landmark the map
## carries. Warp 3 there is the one that leads up, on all three cartridges.
const CENTER_GROUP: int = 2
const CENTER_MAP: int = 3
const CENTER_STAIRS: Vector2i = Vector2i(0, 7)
const CENTER_STAIRS_WARP: int = 3

## The two dept store elevators, whose `elevator` script command reads the same
## three bytes through `.FindCurrentFloor` and writes them through
## `Elevator_GoToFloor`. Crystal's Goldenrod car is map 11/17 and Gold and
## Silver's 11/18; the Celadon one is 21/11 on all three.
const CELADON_ELEVATOR: Array = [21, 11]
const GOLDENROD_ELEVATOR_CRYSTAL: Array = [11, 17]
const GOLDENROD_ELEVATOR_GOLD_SILVER: Array = [11, 18]

## Vermilion City's, whose landmark is Kanto's: the region a
## `LANDMARK_SPECIAL` map answers with is the backup's and not a constant.
const KANTO_CENTER_GROUP: int = 17
const KANTO_CENTER_MAP: int = 10
const KANTO_CENTER_STAIRS: Vector2i = Vector2i(0, 7)


func run(r: RefCounted) -> void:
	for game_id: StringName in [&"crystal", &"gold", &"silver"]:
		var data: GameData = GameData.open(game_id)
		if data == null:
			r.fail("%s cache is unavailable. Import roms/%s.gbc first." % [game_id, game_id])
			continue
		_verify_corpus(r, game_id, data)
		_verify_walk(r, game_id, data, CENTER_GROUP, CENTER_MAP, CENTER_STAIRS)
		_verify_walk(
			r, game_id, data, KANTO_CENTER_GROUP, KANTO_CENTER_MAP, KANTO_CENTER_STAIRS
		)
		_verify_save_round_trip(r, game_id, data)
		_verify_elevators(r, game_id, data)


## Which warp events carry the destination, whole corpus. The pair of counts is
## what says a seventh cannot appear without a reading of it.
func _verify_corpus(r: RefCounted, game_id: StringName, data: GameData) -> void:
	var expected: Dictionary = {}
	var elevator: Array = ELEVATOR_CRYSTAL if game_id == &"crystal" else ELEVATOR_GOLD_SILVER
	for row: Array in SHARED_BACKUP_WARPS + elevator:
		expected["%d:%d:%d" % [row[0], row[1], row[2]]] = true
	var found: Dictionary = {}
	for map: Gen2WorldMap in data.world_maps():
		var warps: Array = map.events.get("warps", [])
		for index: int in warps.size():
			if int((warps[index] as Dictionary).get("destination", 0)) \
					== Gen2WorldAPI.BACKUP_WARP_DESTINATION:
				found["%d:%d:%d" % [map.group, map.number, index + 1]] = true
	r.check(
		found.size() == expected.size(),
		"%s: %d warp events name the backup warp, not %d." % [
			game_id, found.size(), expected.size(),
		]
	)
	for key: String in expected:
		r.check(found.has(key), "%s: warp %s does not name the backup warp." % [game_id, key])


## The reported shape, end to end on the real maps: up the stairs of a Pokemon
## Center, and back down into the same one. `GetWarpDestCoords`'s `.backup` is
## what records the way back, and the landmark the floor borrows is the same
## map's.
func _verify_walk(
	r: RefCounted, game_id: StringName, data: GameData,
	group: int, number: int, stairs: Vector2i,
) -> void:
	var world: Gen2WorldAPI = Gen2WorldAPI.open(
		data, group, number, stairs, Gen2WorldState.new()
	)
	if not r.check(world != null, "%s: map %d/%d is missing." % [game_id, group, number]):
		return
	var ground: int = world.landmark()
	var up: Dictionary = world.try_warp(stairs)
	if not r.check(
		bool(up.get("ok", false)) and world.map_id() == Vector2i(POKECENTER_2F_GROUP, POKECENTER_2F),
		"%s: the stairs of %d/%d do not reach POKECENTER_2F (%s)." % [
			game_id, group, number, up.get("reason", &"no_result"),
		]
	):
		return
	r.check(
		world.backup_warp == {
			"warp": CENTER_STAIRS_WARP, "map_group": group, "map_number": number,
		},
		"%s: arriving on POKECENTER_2F from %d/%d recorded %s." % [
			game_id, group, number, world.backup_warp,
		]
	)
	r.check(
		world.landmark() == Gen2WorldRadio.LANDMARK_SPECIAL,
		"%s: POKECENTER_2F's own landmark is %d, not LANDMARK_SPECIAL." % [
			game_id, world.landmark(),
		]
	)
	r.check(
		world.landmark_backup() == ground,
		"%s: POKECENTER_2F borrows landmark %d, not %d/%d's %d." % [
			game_id, world.landmark_backup(), group, number, ground,
		]
	)
	var crystal: bool = Gen2WorldState.is_crystal_profile(data)
	r.check(
		Gen2WorldRadio.is_kanto_landmark(world.landmark_backup(), crystal) \
			== Gen2WorldRadio.is_kanto_landmark(ground, crystal),
		"%s: POKECENTER_2F over %d/%d answers the wrong region." % [game_id, group, number]
	)
	var down: Dictionary = world.try_warp(POKECENTER_2F_STAIRS)
	r.check(
		bool(down.get("ok", false)) and world.map_id() == Vector2i(group, number),
		"%s: the stairs off POKECENTER_2F reach %s, not %d/%d (%s)." % [
			game_id, world.map_id(), group, number, down.get("reason", &"no_result"),
		]
	)


## The three bytes sit in `wCurMapData`, which `SavePlayerData` copies into
## `sCurMapData`, so a player who saves upstairs comes back down the way they
## went up. A snapshot written before the field existed carries none, which is
## a game that has walked through no such warp.
func _verify_save_round_trip(r: RefCounted, game_id: StringName, data: GameData) -> void:
	var world: Gen2WorldAPI = Gen2WorldAPI.open(
		data, CENTER_GROUP, CENTER_MAP, CENTER_STAIRS, Gen2WorldState.new()
	)
	if world == null or not bool(world.try_warp(CENTER_STAIRS).get("ok", false)):
		r.fail("%s: the walk up the stairs failed before the save." % game_id)
		return
	var reopened: Gen2WorldSnapshot = Gen2WorldSnapshot.from_dict(world.snapshot().to_dict())
	var restored: Gen2WorldAPI = Gen2WorldAPI.open_snapshot(data, reopened)
	if not r.check(restored != null, "%s: the saved snapshot does not reopen." % game_id):
		return
	r.check(
		restored.backup_warp == world.backup_warp,
		"%s: a save reopens with backup warp %s, not %s." % [
			game_id, restored.backup_warp, world.backup_warp,
		]
	)
	r.check(
		bool(restored.try_warp(POKECENTER_2F_STAIRS).get("ok", false)) \
			and restored.map_id() == Vector2i(CENTER_GROUP, CENTER_MAP),
		"%s: a save written on POKECENTER_2F cannot walk back down." % game_id
	)
	var older: Dictionary = world.snapshot().to_dict()
	older.erase("backup_warp")
	var legacy: Gen2WorldSnapshot = Gen2WorldSnapshot.from_dict(older)
	r.check(
		legacy != null and legacy.backup_warp.is_empty(),
		"%s: a snapshot written before the field reads a backup warp it never had." % game_id
	)


## Every `elevator` command in the corpus, its floor list decoded and its rows
## checked against the maps they name. `.FindCurrentFloor` matches the backup
## warp's map, so the list is only usable if every row names a real map, and
## `Elevator_GoToFloor` copies the row's last three bytes over the backup warp,
## so every row's warp has to exist on the map it names.
func _verify_elevators(r: RefCounted, game_id: StringName, data: GameData) -> void:
	var crystal: bool = game_id == &"crystal"
	var expected: Array = [
		CELADON_ELEVATOR,
		GOLDENROD_ELEVATOR_CRYSTAL if crystal else GOLDENROD_ELEVATOR_GOLD_SILVER,
	]
	var found: int = 0
	for pair: Array in expected:
		var map: Gen2WorldMap = data.world_map(pair[0], pair[1])
		if not r.check(map != null, "%s: elevator map %s is missing." % [game_id, pair]):
			continue
		var bank: int = int(map.events.get("bank", 0))
		for row: Dictionary in _elevator_commands(data, map, crystal):
			found += 1
			var decoded: Dictionary = Gen2WorldScript.decode_elevator_floors(
				data.world_script_at(bank, int(row["address"]))
			)
			if not r.check(
				bool(decoded.get("ok", false)),
				"%s: %s's floor list did not decode (%s)." % [
					game_id, pair, decoded.get("reason", &"unknown"),
				]
			):
				continue
			for entry: Dictionary in decoded["floors"]:
				var floor_map: Gen2WorldMap = data.world_map(
					int(entry["map_group"]), int(entry["map_number"])
				)
				if not r.check(
					floor_map != null,
					"%s: %s names map %d/%d, which is not in the cache." % [
						game_id, pair, int(entry["map_group"]), int(entry["map_number"]),
					]
				):
					continue
				r.check(
					int(entry["warp"]) >= 1 \
						and int(entry["warp"]) <= (floor_map.events.get("warps", []) as Array).size(),
					"%s: %s names warp %d on map %d/%d, which has %d." % [
						game_id, pair, int(entry["warp"]),
						int(entry["map_group"]), int(entry["map_number"]),
						(floor_map.events.get("warps", []) as Array).size(),
					]
				)
			## The car's own door is a -1 warp, so riding to a floor and walking
			## out has to land on that floor's own warp.
			_verify_ride(r, game_id, data, pair, decoded["floors"])
	r.check(
		found == expected.size(),
		"%s: %d elevator commands were reached, not %d." % [game_id, found, expected.size()]
	)


## `Elevator_GoToFloor` then the -1 warp: choosing a floor writes the backup warp
## and the door spends it, on every floor the list names.
func _verify_ride(
	r: RefCounted, game_id: StringName, data: GameData, pair: Array, floors: Array
) -> void:
	for entry: Dictionary in floors:
		var world: Gen2WorldAPI = Gen2WorldAPI.open(
			data, pair[0], pair[1], Vector2i(1, 3), Gen2WorldState.new()
		)
		if world == null:
			r.fail("%s: elevator map %s does not open." % [game_id, pair])
			return
		world.backup_warp = {
			"warp": int(entry["warp"]),
			"map_group": int(entry["map_group"]),
			"map_number": int(entry["map_number"]),
		}
		var out: Dictionary = world.try_warp(Vector2i(1, 3))
		r.check(
			bool(out.get("ok", false)) \
				and world.map_id() == Vector2i(int(entry["map_group"]), int(entry["map_number"])),
			"%s: %s riding to floor %d reaches %s, not %d/%d (%s)." % [
				game_id, pair, int(entry["floor"]), world.map_id(),
				int(entry["map_group"]), int(entry["map_number"]),
				out.get("reason", &"no_result"),
			]
		)


## Every `elevator` command the map's own event scripts reach, as
## `{address}` rows.
func _elevator_commands(data: GameData, map: Gen2WorldMap, crystal: bool) -> Array:
	var out: Array = []
	var bank: int = int(map.events.get("bank", 0))
	for raw: Variant in (map.events.get("bg_events", []) as Array) \
			+ (map.events.get("objects", []) as Array):
		var bytes: PackedByteArray = data.world_script(
			bank, int((raw as Dictionary).get("script", 0))
		)
		var at: int = 0
		while at < bytes.size():
			var command: Dictionary = Gen2WorldScript.command_at(bytes, at, crystal)
			if not bool(command.get("ok", false)):
				break
			if Gen2WorldScript.command_name(int(command["opcode"]), crystal) == &"elevator":
				out.append({"address": int(command.get("address", 0))})
			at += int(command["width"])
			if Gen2WorldScript.is_terminal(int(command["opcode"]), crystal):
				break
	return out
