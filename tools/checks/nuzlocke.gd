extends RefCounted

var _r: RefCounted = null

## The Nuzlocke's area rule: every map a wild can be met on has a landmark of
## its own, and a landmark shared by several maps is ONE area, which is what
## makes a multi-floor cave one encounter rather than one per floor. Generation 1
## gives every map a `LoadTownMapEntry` row instead, and what is swept here is
## the fold [method GameData.area_landmark] puts over them.

## Per game: maps carrying a wild table, and the distinct areas behind them,
## which is how many encounters a Nuzlocke of that cartridge gets.
const EXPECTED_CENSUS: Dictionary = {
	&"red": [57, 36],
	&"blue": [57, 36],
	&"yellow": [57, 36],
	&"gold": [114, 79],
	&"silver": [114, 79],
	&"crystal": [114, 79],
}

const METHODS: Array[StringName] = [&"grass", &"surf"]


func run(r: RefCounted) -> void:
	_r = r
	for generation: int in [RomRegistry.GEN1, RomRegistry.GEN2]:
		_r.each_game_of(generation, func() -> void:
			_verify_every_encounter_map_has_an_area()
			_verify_an_area_draws_what_its_maps_draw()
		)


func _verify_every_encounter_map_has_an_area() -> void:
	var maps: int = 0
	var areas: Dictionary = {}
	var shared: Dictionary = {}
	for map: Gen2WorldMap in _r.data.world_maps():
		if not _has_wild_table(map):
			continue
		maps += 1
		var area: int = _area_of(map)
		if not _r.check(
			area != Gen2WorldRadio.LANDMARK_SPECIAL or _gen1(),
			"map %d/%d can roll a wild and borrows its landmark." % [map.group, map.number],
		):
			continue
		if not _r.check(
			not _r.data.landmark_name(area).is_empty(),
			"map %d/%d names landmark %d, which the cache cannot spell." % [
				map.group, map.number, area,
			],
		):
			continue
		areas[area] = true
		shared[area] = int(shared.get(area, 0)) + 1

	var biggest: int = 0
	for landmark: int in shared:
		biggest = maxi(biggest, int(shared[landmark]))
	_r.note("%d maps with a wild table over %d areas, the largest %d maps." % [
		maps, areas.size(), biggest,
	])
	## A landmark covering more than one map is what makes a multi-floor dungeon
	## one encounter; without it the census would be two identical numbers.
	_r.check(biggest > 1, "no landmark covers more than one map; the rule is per map.")
	var found: Array = [maps, areas.size()]
	var expected: Array = EXPECTED_CENSUS[_r.game_id]
	_r.check(
		found == expected,
		"census is %s, not the pinned %s." % [str(found), str(expected)]
	)


## Folding a map onto its area must change nothing drawn: the two agree on the
## town map's cell and its name, or the region map moved.
func _verify_an_area_draws_what_its_maps_draw() -> void:
	if not _gen1():
		return
	var folded: int = 0
	for map: int in _r.data.landmark_count():
		var area: int = _r.data.area_landmark(map)
		if area == map:
			continue
		folded += 1
		if not _r.check(
			_r.data.landmark_name(area) == _r.data.landmark_name(map)
			and _r.data.landmark(area).get("packed", -1) == _r.data.landmark(map).get("packed", -2),
			"map %d folds onto area %d and the two draw different entries." % [map, area]
		):
			return
	_r.note("%d of %d map ids fold onto an area of their own." % [
		folded, _r.data.landmark_count()
	])


func _gen1() -> bool:
	return _r.data != null and _r.data.generation == RomRegistry.GEN1


## The area one map belongs to: `wCurLandmark`, or its shared town map entry.
func _area_of(map: Gen2WorldMap) -> int:
	return _r.data.map_landmark(map)


## Whether a wild can be met on this map at all. Grass and water are the two
## tables keyed by map; a rod, a tree and a rock all stand on a map with one.
func _has_wild_table(map: Gen2WorldMap) -> bool:
	for method: StringName in METHODS:
		if not _r.data.world_encounter(method, map.group, map.number).is_empty():
			return true
	return false
