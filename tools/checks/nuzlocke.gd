extends RefCounted

var _r: RefCounted = null

## The Nuzlocke's area rule against freshly imported real caches, for all three
## cartridges.
##
## A Nuzlocke counts by AREA, and the area a catch belongs to is the landmark
## `SetCaughtData` writes: `Gen2WorldAPI.landmark_backup`, the same number the
## Pokemon's own met location carries. So the rule only works if every map a
## wild can be met on has a landmark of its own. A map that answered
## `LANDMARK_SPECIAL` would put its encounter on whatever the player last warped
## from, which is a different area on every visit.
##
## The census is the point, the way `wild_encounters.gd`'s is: it is what a
## Nuzlocke actually has to spend. A landmark shared by several maps is ONE
## area, which is what makes a multi-floor cave one encounter rather than one
## per floor, and the two counts differing is what proves that.
##
##   Godot --headless --path . -s res://tools/validate.gd -- nuzlocke

## Per game: maps carrying a wild table, and the distinct landmarks behind them,
## which is how many encounters a Nuzlocke of that cartridge gets.
const EXPECTED_CENSUS: Dictionary = {
	&"gold": [114, 79],
	&"silver": [114, 79],
	&"crystal": [114, 79],
}

## The methods a step, a surf, a rod, a headbutt or a smash resolves to. A map
## with a row in any of them can produce a wild the player meets.
const METHODS: Array[StringName] = [&"grass", &"surf"]


func run(r: RefCounted) -> void:
	_r = r
	_r.each_game(func() -> void:
		_verify_every_encounter_map_has_an_area()
	)


func _verify_every_encounter_map_has_an_area() -> void:
	var maps: int = 0
	var areas: Dictionary = {}
	var shared: Dictionary = {}
	for map: Gen2WorldMap in _r.data.world_maps():
		if not _has_wild_table(map):
			continue
		maps += 1
		if not _r.check(
			map.location != Gen2WorldRadio.LANDMARK_SPECIAL,
			"map %d/%d can roll a wild and borrows its landmark." % [map.group, map.number],
		):
			continue
		if not _r.check(
			not _r.data.landmark_name(map.location).is_empty(),
			"map %d/%d names landmark %d, which the cache cannot spell." % [
				map.group, map.number, map.location,
			],
		):
			continue
		areas[map.location] = true
		shared[map.location] = int(shared.get(map.location, 0)) + 1

	var biggest: int = 0
	for landmark: int in shared:
		biggest = maxi(biggest, int(shared[landmark]))
	_r.note("%d maps with a wild table over %d areas, the largest %d maps." % [
		maps, areas.size(), biggest,
	])
	## A landmark covering more than one map is what makes a multi-floor dungeon
	## one encounter. Without it the census would be two identical numbers and
	## the rule would be per map rather than per area.
	_r.check(biggest > 1, "no landmark covers more than one map; the rule is per map.")
	var found: Array = [maps, areas.size()]
	var expected: Array = EXPECTED_CENSUS[_r.game_id]
	_r.check(
		found == expected,
		"census is %s, not the pinned %s." % [str(found), str(expected)]
	)


## Whether a wild can be met on this map at all. Grass and water are the two
## tables keyed by map; a rod, a headbutt tree and a smashable rock all stand on
## a map that already has one of them.
func _has_wild_table(map: Gen2WorldMap) -> bool:
	for method: StringName in METHODS:
		if not _r.data.world_encounter(method, map.group, map.number).is_empty():
			return true
	return false
