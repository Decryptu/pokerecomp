extends RefCounted

var _r: RefCounted = null

## Where a wild encounter can be rolled at all, against freshly imported real
## caches on all three cartridges, plus the roaming graph the three beasts walk.
## The shape comes from RandomEncounter, CanEncounterWildMon,
## CheckWildEncounterCooldown, CheckGrassCollision and CheckIceTile, and
## `visible_encounter_cells` has to name exactly the cells the step roll accepts.
## The census is the point: an encounter cell is a small minority of a map's
## walkable cells, and the defect this exists to catch was every land cell.

## Census of the real caches, pinned so a cache or a rule change is loud.
## Per game: encounter cells, maps holding one, and cells refused for ice.
const EXPECTED_CENSUS: Dictionary = {
	&"gold": [39058, 138, 775],
	&"silver": [39058, 138, 775],
	&"crystal": [40156, 146, 779],
}

## Route 29, the first grass a new game walks into, and the same map number in
## all three games (constants/map_constants.asm, group 24).
const ROUTE_29_GROUP: int = 24
const ROUTE_29_NUMBER: int = 3

## Union Cave 1F, whose whole floor rolls because its environment is CAVE.
## pokecrystal inserts eight Ruins of Alph rooms ahead of it in group 3.
const UNION_CAVE_GROUP: int = 3
const UNION_CAVE_NUMBER_CRYSTAL: int = 37
const UNION_CAVE_NUMBER_GOLD_SILVER: int = 29


func run(r: RefCounted) -> void:
	_r = r
	_r.each_game(func() -> void:
		_verify_route_29()
		_verify_union_cave()
		_verify_bug_contest()
		_verify_gate_errand()
		_census()
		_verify_wild_patch_indices()
		_verify_wild_held_items()
		_verify_rolled_dvs()
		_verify_magikarp_filter()
		_verify_roaming_walk()
	)


## `UpdateRoamMons` passes per starting map, enough to measure the graph.
const ROAM_WALK_UPDATES: int = 400


## `UpdateRoamMons` and `JumpRoamMon` over the whole of `RoamMaps` on each
## cartridge, from every row: every landing is a real map, a connection step is
## a connection and never `wRoamMons_Last*`, and a jump never lands on the
## player. The census is the point, since a roamer stuck on its first map breaks
## no rule.
func _verify_roaming_walk() -> void:
	var rows: Array = _r.data.world_roaming_maps()
	if not _r.check(rows.size() == RomLayout.ROAM_MAP_COUNT,
		"RoamMaps holds %d rows, not %d." % [rows.size(), RomLayout.ROAM_MAP_COUNT]):
		return
	var known: Dictionary = {}
	for row: Dictionary in rows:
		known[Vector2i(int(row["map_group"]), int(row["map_number"]))] = true
	var reached: Dictionary = {}
	var jumps: int = 0
	for start: Vector2i in known:
		var state := Gen2WorldState.from_dict({"roaming_mons": [{
			"species": 243, "level": 40,
			"map_group": start.x, "map_number": start.y,
		}]})
		var generator := RandomNumberGenerator.new()
		generator.seed = start.x * 256 + start.y
		var player: Vector2i = start
		for pass_index: int in ROAM_WALK_UPDATES:
			var last: Array = state.to_dict()["roam_last_map"]
			var before: Vector2i = _roamer_map(state)
			var moved: Array = state.advance_roaming(rows, generator, player)
			var now: Vector2i = _roamer_map(state)
			reached[now] = true
			if not _r.check(known.has(now), "a roamer walked to %s." % now):
				return
			if moved.is_empty():
				continue
			if bool(moved[0]["jumped"]):
				## `JumpRoamMon` refuses the player's map alone, so a jump may
				## land on `wRoamMons_Last` where a connection step may not.
				jumps += 1
				if not _r.check(now != player, "a jump landed on the player at %s." % now):
					return
			else:
				if not _r.check(_connects(rows, before, now),
					"a roamer stepped to %s, which %s does not connect to." % [now, before]):
					return
				if not _r.check(now != Vector2i(int(last[0]), int(last[1])),
					"a roamer walked onto wRoamMons_Last %s." % now):
					return
			## The player follows the roamer, so a jump always has one to refuse.
			player = now if now != player else before
	_r.check(
		reached.size() == known.size(),
		"a roamer reached %d of the %d roaming maps." % [reached.size(), known.size()]
	)
	_r.check(jumps > 0, "no pass of the sweep took `JumpRoamMon`.")
	_r.note("roaming: %d maps reached, %d jumps in %d passes" % [
		reached.size(), jumps, known.size() * ROAM_WALK_UPDATES,
	])


func _roamer_map(state: Gen2WorldState) -> Vector2i:
	var mon: Dictionary = state.roaming_mons()[0]
	return Vector2i(int(mon["map_group"]), int(mon["map_number"]))


## Whether [param to] is one of [param source]'s own connections.
func _connects(rows: Array, source: Vector2i, to: Vector2i) -> bool:
	for row: Dictionary in rows:
		if Vector2i(int(row["map_group"]), int(row["map_number"])) != source:
			continue
		for connection: Dictionary in row["connections"]:
			if Vector2i(
				int(connection["map_group"]), int(connection["map_number"])
			) == to:
				return true
	return false


## How many wilds the DV sweep builds per cartridge. Big enough for the shiny
## count to be a measurement rather than a coincidence: 1 in 8192 a wild, so a
## sweep this size finds one about half the time and the check below is on the
## spread rather than on a shiny turning up.
const DV_SWEEP_WILDS: int = 4096
## Species and level the sweep builds, chosen for being in all three caches and
## for not being UNOWN, whose letter gate is swept separately below.
const DV_SWEEP_SPECIES: int = 19
const DV_SWEEP_LEVEL: int = 5


## Every species' two base item slots through `LoadEnemyMon.WildItem`.
func _verify_wild_held_items() -> void:
	var generator := RandomNumberGenerator.new()
	generator.seed = 20260926
	var rolled: int = 0
	for species: int in range(1, RomLayout.SPECIES_COUNT + 1):
		var row: Dictionary = _r.data.species(species)
		var held: Array = row.get("held_items", []) as Array
		if not _r.check(held.size() == 2, "species %d has %d held-item slots." % [species, held.size()]):
			continue
		var allowed: Array[int] = [0, int(held[0]), int(held[1])]
		_r.check(
			Gen2WorldBattleAdapter._wild_held_item(
				row, Gen2Battle.BATTLETYPE_FORCEITEM, generator
			) == int(held[0]),
			"species %d did not force its first held item." % species
		)
		for _sample: int in 32:
			var item: int = Gen2WorldBattleAdapter._wild_held_item(
				row, Gen2Battle.BATTLETYPE_NORMAL, generator
			)
			_r.check(item in allowed, "species %d rolled item %d." % [species, item])
			rolled += 1
	_r.note("wild held items: %d species, %d ordinary rolls" % [
		RomLayout.SPECIES_COUNT, rolled,
	])


## `LoadEnemyMon`'s `.InitDVs` against the real caches, where before only a
## visible encounter carried DVs and the other eight sources entered at
## 15/15/15/15. Four claims in the source's order of precedence: a request
## carrying `dvs` keeps them; `BATTLETYPE_FORCESHINY` writes the shiny word, the
## red Gyarados; an ordinary wild spreads over the whole 16-bit word with every
## nibble reaching both ends; and a wild UNOWN takes only an unlocked letter.
func _verify_rolled_dvs() -> void:
	var party: Gen2Party = Gen2WorldBattleAdapter.fallback_party(_r.data)
	if not _r.check(party != null, "no party could be built for the DV sweep."):
		return
	var generator := RandomNumberGenerator.new()
	generator.seed = 20260825

	var carried: int = Gen2Stats.pack_dvs(2, 10, 10, 10)
	_r.check(
		_dv_word(party, generator, {"dvs": carried}) == carried,
		"a wild carrying its own DVs was rolled over."
	)
	_r.check(
		_dv_word(party, generator, {
			"battle_type": Gen2Battle.BATTLETYPE_FORCESHINY,
		}) == Gen2Stats.SHINY_DVS,
		"a forced-shiny wild did not get the shiny word."
	)

	var words: Dictionary = {}
	var lowest: Array[int] = [15, 15, 15, 15]
	var highest: Array[int] = [0, 0, 0, 0]
	var shinies: int = 0
	for _wild: int in DV_SWEEP_WILDS:
		var word: int = _dv_word(party, generator, {})
		words[word] = true
		if Gen2Stats.is_shiny(word):
			shinies += 1
		var nibbles: Array[int] = [
			Gen2Stats.attack_dv(word), Gen2Stats.defense_dv(word),
			Gen2Stats.speed_dv(word), Gen2Stats.special_dv(word),
		]
		for index: int in nibbles.size():
			lowest[index] = mini(lowest[index], nibbles[index])
			highest[index] = maxi(highest[index], nibbles[index])
	_r.check(
		words.size() > DV_SWEEP_WILDS / 2,
		"%d wilds drew only %d distinct DV words." % [DV_SWEEP_WILDS, words.size()]
	)
	_r.check(
		lowest == [0, 0, 0, 0] and highest == [15, 15, 15, 15],
		"a DV nibble never reached both ends: %s to %s." % [lowest, highest]
	)
	_r.note(
		"wild DVs: %d words over %d rolls, %d shiny" % [words.size(), DV_SWEEP_WILDS, shinies]
	)

	## `CheckUnownLetter`, one set at a time. A save with nothing solved meets no
	## wild UNOWN at all, so no mask of zero is swept here.
	for set_index: int in Gen2WorldState.UNOWN_LETTER_SETS.size():
		var allowed: Array = Gen2WorldState.UNOWN_LETTER_SETS[set_index]
		var seen: Dictionary = {}
		for _wild: int in 256:
			seen[Gen2Stats.unown_letter(Gen2WorldBattleAdapter.wild_dvs(
				{"unlocked_unowns": 1 << set_index}, Gen2Battle.BATTLETYPE_NORMAL,
				RomLayout.UNOWN_SPECIES, generator
			))] = true
		for letter: int in seen:
			_r.check(
				letter in allowed,
				"set %d let UNOWN letter %d through." % [set_index, letter]
			)
		_r.check(
			seen.size() == allowed.size(),
			"set %d reached %d of its %d letters." % [set_index, seen.size(), allowed.size()]
		)


## `LoadEnemyMon.CheckMagikarpArea` over every map that can produce a Magikarp:
## the request has to carry the map the filter reads, and the floor has to drop
## short Magikarp everywhere but the group and map number the two `cp`s name.
func _verify_magikarp_filter() -> void:
	var maps: Array = _magikarp_maps()
	if not _r.check(not maps.is_empty(), "no map holds a wild MAGIKARP."):
		return
	var skipped: Array = []
	var unstamped: int = 0
	for pair: Vector2i in maps:
		var world: Gen2WorldAPI = _r.open_world(pair.x, pair.y, Vector2i.ZERO)
		if world == null:
			continue
		world.set_player_id(0x1234)
		world.state.set_wild_encounter_cooldown(0)
		var request: Dictionary = world.encounter_request(
			RandomNumberGenerator.new(), true, Gen2WorldEncounter.METHOD_SURF
		)
		var values: Variant = request.get("values", null)
		if not values is Dictionary:
			continue
		var carried: Dictionary = values as Dictionary
		if int(carried.get("map_group", -1)) != pair.x \
			or int(carried.get("map_number", -1)) != pair.y \
			or int(carried.get("player_id", -1)) != 0x1234:
			unstamped += 1
			continue
		if _short_magikarp_share(carried) != _short_magikarp_share({}):
			skipped.append(pair)
	_r.check(unstamped == 0, "%d wild requests carried no map." % unstamped)
	for pair: Vector2i in skipped:
		_r.check(
			pair.x == Gen2WorldBattleAdapter.GROUP_LAKE_OF_RAGE \
				or pair.y == Gen2WorldBattleAdapter.MAP_LAKE_OF_RAGE,
			"map %d/%d skipped the Magikarp floor." % [pair.x, pair.y]
		)
	_r.check(
		_short_magikarp_share({"map_group": 5, "map_number": 3}) \
			< _short_magikarp_share({
				"map_group": Gen2WorldBattleAdapter.GROUP_LAKE_OF_RAGE, "map_number": 6,
			}),
		"the floor dropped no short Magikarp outside the lake."
	)
	_r.note("Magikarp floor: %d maps, %d of them skipping it." % [
		maps.size(), skipped.size(),
	])


func _magikarp_maps() -> Array:
	var out: Array = []
	for region: String in ["johto", "kanto"]:
		for row: Dictionary in _r.data.world_encounter_region_rows(&"surf", region):
			if not _holds_magikarp(row):
				continue
			var pair: PackedStringArray = String(row.get("map", "")).split(":")
			if pair.size() == 2:
				out.append(Vector2i(int(pair[0]), int(pair[1])))
	return out


static func _holds_magikarp(row: Dictionary) -> bool:
	for key: Variant in row:
		var slots: Variant = row[key]
		if not slots is Array:
			continue
		for slot: Variant in slots as Array:
			if slot is Dictionary \
				and int((slot as Dictionary).get("species", 0)) \
					== Gen2WorldPartyHost.SPECIES_MAGIKARP:
				return true
	return false


func _short_magikarp_share(values: Dictionary) -> int:
	var generator := RandomNumberGenerator.new()
	generator.seed = 20260912
	var request: Dictionary = values.duplicate()
	request["player_id"] = 0x1234
	var short: int = 0
	for _wild: int in 256:
		var word: int = Gen2WorldBattleAdapter.wild_dvs(
			request, Gen2Battle.BATTLETYPE_NORMAL,
			Gen2WorldPartyHost.SPECIES_MAGIKARP, generator
		)
		var length: Vector2i = Gen2WorldPartyHost.magikarp_length(
			PackedByteArray([(word >> 8) & 0xFF, word & 0xFF]), 0x1234
		)
		if length.x < Gen2WorldBattleAdapter.MAGIKARP_FLOOR_FEET:
			short += 1
	return short


## One wild built through the whole adapter, so the sweep measures the path a
## battle takes rather than the roll on its own.
func _dv_word(
	party: Gen2Party, generator: RandomNumberGenerator, extra: Dictionary
) -> int:
	var values: Dictionary = {
		"kind": &"wild", "pokemon": DV_SWEEP_SPECIES, "level": DV_SWEEP_LEVEL,
	}
	values.merge(extra, true)
	var prepared: Dictionary = Gen2WorldBattleAdapter.prepare(
		_r.data, {"values": values}, party, generator
	)
	if not bool(prepared.get("ok", false)):
		_r.fail("a wild could not be prepared: %s" % prepared.get("reason", ""))
		return -1
	return (prepared["battle"] as Gen2Battle).enemy.dvs


## The National Park gate, where a contest is entered. Same ids on both
## profiles: group 3 shifts only from Union Cave on, and group 10's gates sit
## ahead of Goldenrod's own inserts.
const GATE_GROUP: int = 10
const GATE_NUMBER: int = 15
const PARK_CONTEST_GROUP: int = 3
const PARK_CONTEST_NUMBER: int = 16
## `Route35OfficerScriptContest` refuses on Sunday, Monday, Wednesday and
## Friday, so the walk is done on a Tuesday.
const CONTEST_WEEKDAY: int = 2
## Route 36's gate, where `BugContestResultsWarpScript` warps to.
const RESULTS_GATE_GROUP: int = 10
const RESULTS_GATE_NUMBER: int = 17


## `Route35OfficerScriptContest` through to `GiveParkBalls`: the errand a player
## actually walks, on the real map with the real script, rather than the specials
## called by hand.
func _verify_gate_errand() -> void:
	var world: Gen2WorldAPI = _r.open_world(GATE_GROUP, GATE_NUMBER, Vector2i.ZERO)
	if world == null:
		return
	world.set_world_clock(CONTEST_WEEKDAY, 12, 0)
	_r.field_move_party(world)
	var talked: Array = _talk_to_officer(world)
	if not _r.check(not talked.is_empty(), "no object at the gate asks about the contest."):
		return

	## The officer's question, then its `yesorno`, then the balls.
	var answered: Array = _drain_to_choice(world, talked)
	if not _r.check(not answered.is_empty(), "the officer never asked a yes/no."):
		return
	world.choose_script_input(0)
	var _entered: Dictionary = _drain_script(world)
	_r.check(
		world.bug_contest_active(),
		"ENGINE_BUG_CONTEST_TIMER is not set after saying yes."
	)
	_r.check(
		world.state.park_balls() == Gen2WorldBugContest.BALLS,
		"the officer handed %d park balls." % world.state.park_balls()
	)
	_r.check(
		world.state.withdrawn_bug_contestants().size()
			== Gen2WorldBugContest.CONTESTANTS_WITHDRAWN,
		"%d contestants withdrew, not five." % world.state.withdrawn_bug_contestants().size()
	)
	_r.check(
		world.map_id() == Vector2i(PARK_CONTEST_GROUP, PARK_CONTEST_NUMBER),
		"the errand ended on map %s, not the contest park." % str(world.map_id())
	)
	_r.check(
		world.bug_contest_minutes_remaining() == Gen2WorldBugContest.MINUTES,
		"the timer opened on %d minutes." % world.bug_contest_minutes_remaining()
	)
	_r.note("gate errand: %d park balls, %d minutes, %d contestants withdrawn." % [
		world.state.park_balls(), world.bug_contest_minutes_remaining(),
		world.state.withdrawn_bug_contestants().size(),
	])

	## `CheckTimeEvents`: twenty minutes on, the contest is over and
	## `BugContestResultsWarpScript` takes the player to the results gate.
	world.set_world_clock(
		CONTEST_WEEKDAY, 12, Gen2WorldBugContest.MINUTES
	)
	## Something caught, so the judging has a score to rank.
	world.state.set_contest_mon({
		"species": 10, "level": 15, "max_hp": 40, "hp": 40, "attack": 20,
		"defense": 20, "speed": 25, "special_attack": 20, "special_defense": 20,
		"dvs": 0xFFFF, "item": 0,
	})
	var over: Array = world.check_bug_contest_timer()
	_r.check(not over.is_empty(), "the timer running out queued nothing.")
	var judged: Dictionary = _drain_script(world)
	_r.check(not judged.is_empty(), "the results script never asked for a judging.")
	if not judged.is_empty():
		_r.check(
			(judged["placings"] as Array).size() == 3,
			"the judging placed %d." % (judged["placings"] as Array).size()
		)
		_r.note("judging: score %d, placed %d, first is %s." % [
			int(judged["score"]), int(judged["player_place"]),
			str((judged["placings"] as Array)[0]),
		])
	_r.check(
		not world.bug_contest_active(),
		"BugContestResultsScript left the contest flag set."
	)
	## `BugContestResultsWarpScript`'s own `warp ROUTE_36_NATIONAL_PARK_GATE`,
	## which it falls into `BugContestResultsScript` past: the same script clears
	## the flag, judges and hands out the prize.
	_r.check(
		world.map_id() == Vector2i(RESULTS_GATE_GROUP, RESULTS_GATE_NUMBER),
		"the contest ended on map %s, not the results gate." % str(world.map_id())
	)
	_r.note("the contest ended on map %s." % str(world.map_id()))

	## The other way a contest ends: `farscall Script_AbortBugContest` and
	## `special WarpToSpawnPoint`, which Fly, Dig, an Escape Rope and Teleport
	## all share. Run against the same cache rather than a fixture, because the
	## flag indices split by profile.
	var crystal: bool = Gen2WorldState.is_crystal_profile(world.data)
	var timer: int = Gen2WorldState.engine_flag(
		Gen2WorldState.ENGINE_BUG_CONTEST_TIMER, crystal
	)
	var daily: int = Gen2WorldState.engine_flag(
		Gen2WorldState.ENGINE_DAILY_BUG_CONTEST, crystal
	)
	world.state.set_engine_flag(daily, false)
	world.state.set_engine_flag(timer)
	world.state.set_engine_flag(
		Gen2WorldState.engine_flag(Gen2WorldState.ENGINE_SAFARI_ZONE, crystal)
	)
	var escaped: Dictionary = world.warp_to_spawn(RomLayout.SPAWN_HOME)
	_r.check(
		bool(escaped.get("ok", false)),
		"an escape to SPAWN_HOME answered %s." % str(escaped.get("reason", ""))
	)
	_r.check(
		not world.state.is_engine_flag_active(timer),
		"WarpToSpawnPoint left the contest timer set."
	)
	_r.check(
		not world.state.is_engine_flag_active(
			Gen2WorldState.engine_flag(Gen2WorldState.ENGINE_SAFARI_ZONE, crystal)
		),
		"WarpToSpawnPoint left STATUSFLAGS2_SAFARI_GAME_F set."
	)
	_r.check(
		world.state.is_engine_flag_active(daily),
		"Script_AbortBugContest did not spend the day's contest."
	)
	_r.check(world.take_contest_abort(), "the masked party was not owed back.")


## The step each facing looks along, in FACING_* order.
const FACING_STEPS: Array[Vector2i] = [
	Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT,
]


## Every object on the map faced and talked to, answering with the first one
## whose script says anything. The officer's cell is not pinned: the two gates
## differ in nothing else, and a hand-named cell breaks on the other profile.
func _talk_to_officer(world: Gen2WorldAPI) -> Array:
	for index: int in world.objects.size():
		var object: Gen2WorldObject = world.objects[index]
		for facing: int in [
			Gen2WorldSprite.FACING_DOWN, Gen2WorldSprite.FACING_UP,
			Gen2WorldSprite.FACING_LEFT, Gen2WorldSprite.FACING_RIGHT,
		]:
			var direction: Vector2i = FACING_STEPS[facing]
			var stand: Vector2i = object.cell - direction
			if stand.x < 0 or stand.y < 0 \
				or stand.x >= world.current_map.collision_width \
				or stand.y >= world.current_map.collision_height:
				continue
			world.player_cell = stand
			world.player_facing = facing
			var results: Array = world.interact()
			if not results.is_empty():
				return results
	return []


## The script run to its end: every text acknowledged and every movement frame
## the applymovements ask for spent, which is what the world screen does a frame
## at a time.
func _drain_script(world: Gen2WorldAPI) -> Dictionary:
	var judged: Dictionary = {}
	var random := RandomNumberGenerator.new()
	random.seed = 13
	for _step: int in 4000:
		if not world.pending_script_wait().is_empty():
			world.advance_script_presentation_frame()
			continue
		if not world.script_busy():
			return judged
		## The one request this errand makes of its host: `BugContestJudging`
		## leaves the placing in wScriptVar, which the script branches on.
		var request: Dictionary = world.pending_runtime_request()
		if StringName(request.get("kind", &"")) == &"bug_contest_judging_requested":
			judged = world.judge_bug_contest(random)
			world.complete_runtime_request({
				"ok": true, "script_value": int(judged.get("player_place", 0)),
			})
			continue
		world.run_event_queue(true)
	return judged


## Runs the script on until it is waiting on a choice, which is the officer's
## own `yesorno`.
func _drain_to_choice(world: Gen2WorldAPI, results: Array) -> Array:
	var out: Array = results.duplicate()
	for _step: int in 40:
		for entry: Dictionary in out:
			var event: Dictionary = entry.get("event", {})
			if StringName(event.get("type", &"")) == &"choice":
				return out
		if not world.script_busy():
			return []
		out = world.run_event_queue(true)
	return []


## `ContestMons` and `BugContestantPointers` as imported, and the contest's own
## encounter over the whole table. All three cartridges ship both byte
## identical, which is why the expected values are not per game.
const CONTEST_SPECIES: Array[int] = [10, 13, 11, 14, 12, 15, 48, 46, 123, 127, 49]
const CONTEST_PERCENTS: Array[int] = [20, 20, 10, 10, 5, 5, 10, 10, 5, 5, 0xFF]
## `BugContestant_BugCatcherDon` and `BugContestant_SchoolboyKipp`, the first and
## last records, as `[class, trainer]`.
const CONTESTANT_EDGES: Array = [[36, 1], [23, 2]]


func _verify_bug_contest() -> void:
	var mons: Array = _r.data.bug_contest_mons()
	if not _r.check(
		mons.size() == Gen2WorldBugContest.NUM_CONTEST_MONS,
		"ContestMons has %d rows, not %d." % [
			mons.size(), Gen2WorldBugContest.NUM_CONTEST_MONS,
		]
	):
		return
	var total: int = 0
	for index: int in mons.size():
		var row: Dictionary = mons[index]
		_r.check(
			int(row["species"]) == CONTEST_SPECIES[index]
				and int(row["percent"]) == CONTEST_PERCENTS[index],
			"ContestMons row %d is %d at %d percent." % [
				index, int(row["species"]), int(row["percent"]),
			]
		)
		if int(row["percent"]) != 0xFF:
			total += int(row["percent"])
	_r.check(total == 100, "ContestMons' percentages add to %d, not 100." % total)

	var contestants: Array = _r.data.bug_contestants()
	if not _r.check(
		contestants.size() == Gen2WorldBugContest.NUM_CONTESTANTS,
		"BugContestantPointers has %d records, not %d." % [
			contestants.size(), Gen2WorldBugContest.NUM_CONTESTANTS,
		]
	):
		return
	for edge: int in CONTESTANT_EDGES.size():
		var entry: Dictionary = contestants[0 if edge == 0 else contestants.size() - 1]
		_r.check(
			int(entry["trainer_class"]) == int(CONTESTANT_EDGES[edge][0])
				and int(entry["trainer"]) == int(CONTESTANT_EDGES[edge][1]),
			"contestant edge %d is class %d trainer %d." % [
				edge, int(entry["trainer_class"]), int(entry["trainer"]),
			]
		)
		_r.check(
			(entry["placings"] as Array).size() == 3,
			"contestant edge %d has %d placings." % [edge, (entry["placings"] as Array).size()]
		)

	## Every draw the walk can produce, over the whole table: a row of it, at a
	## level between that row's own two, and never the `db -1` sentinel.
	var random := RandomNumberGenerator.new()
	random.seed = 7
	var drawn: Dictionary = {}
	for _draw: int in 2000:
		var result: Dictionary = Gen2WorldBugContest.resolve(mons, true, random, true)
		if not _r.check(not result.is_empty(), "a contest draw answered nothing."):
			return
		var species: int = int(result["pokemon"])
		drawn[species] = int(drawn.get(species, 0)) + 1
		for row: Dictionary in mons:
			if int(row["species"]) != species:
				continue
			_r.check(
				int(result["level"]) >= int(row["min_level"])
					and int(result["level"]) <= int(row["max_level"]),
				"a level %d %d is outside its row." % [int(result["level"]), species]
			)
			break
	_r.check(
		not drawn.has(CONTEST_SPECIES[CONTEST_SPECIES.size() - 1]),
		"the sentinel row was drawn."
	)
	_r.check(drawn.size() == mons.size() - 1, "only %d of the ten rows came up." % drawn.size())
	_r.note("bug contest: %d rows, %d contestants, %d species drawn in 2000." % [
		mons.size(), contestants.size(), drawn.size(),
	])


## An outdoor map: only the tiles CheckGrassCollision names roll, and the path
## between them does not.
func _verify_route_29() -> void:
	var world: Gen2WorldAPI = _r.open_world(
		ROUTE_29_GROUP, ROUTE_29_NUMBER, Vector2i.ZERO
	)
	if world == null:
		return
	world.state.set_wild_encounter_cooldown(0)
	var counts: Dictionary = _map_counts(world)
	_r.check(
		world.current_map.environment == Gen2WorldPhoneHost.ENVIRONMENT_ROUTE,
		"Route 29 is environment %d, not ROUTE." % world.current_map.environment
	)
	_r.check(
		int(counts["encounter"]) > 0,
		"Route 29 offers no encounter cell at all."
	)
	_r.check(
		int(counts["encounter"]) < int(counts["walkable"]),
		"Route 29 rolls on all %d of its walkable cells." % int(counts["walkable"])
	)
	_r.note("Route 29: %d encounter cells of %d walkable." % [
		int(counts["encounter"]), int(counts["walkable"]),
	])


## A CAVE map: every walkable cell rolls, which is the branch that skips
## CheckGrassCollision entirely.
func _verify_union_cave() -> void:
	var number: int = UNION_CAVE_NUMBER_CRYSTAL if _r.crystal \
		else UNION_CAVE_NUMBER_GOLD_SILVER
	var world: Gen2WorldAPI = _r.open_world(UNION_CAVE_GROUP, number, Vector2i.ZERO)
	if world == null:
		return
	world.state.set_wild_encounter_cooldown(0)
	if not _r.check(
		world.current_map.environment == Gen2WorldAPI.ENVIRONMENT_CAVE,
		"Union Cave 1F is environment %d, not CAVE." % world.current_map.environment
	):
		return
	var counts: Dictionary = _map_counts(world)
	_r.check(
		int(counts["encounter"]) == int(counts["walkable"]),
		"Union Cave 1F rolls on %d of its %d walkable cells." % [
			int(counts["encounter"]), int(counts["walkable"]),
		]
	)
	_r.note("Union Cave 1F: %d cells, all of them CAVE." % int(counts["encounter"]))


## Every map in the cache, so a rule change is one number rather than one map.
## Every index of the four wild sources beside the map tables is patchable and
## reads back through `GameData` on a real cache, so an off-by-one either way, or
## a source read from somewhere else, shows here and in no fixture.
func _verify_wild_patch_indices() -> void:
	var overlay := Gen2ContentOverlay.new()
	var data: GameData = GameData.open(_r.game_id)
	if data == null:
		return
	data.set_content_overlay(overlay)
	var host: Gen2ModHost = Gen2ModHost.instance()
	var sets: int = 0
	for index: int in data.treemon_set_count():
		if data.treemon_set(index).is_empty():
			continue
		sets += 1
		overlay.patch(Gen2ContentOverlay.KIND_TREEMON, &"check", index, {
			"common": [{"percent": 100, "species": index + 1, "level": 5}],
		})
		var patched: Dictionary = data.treemon_set(index)
		_r.check(
			int((patched["common"] as Array)[0]["species"]) == index + 1
				and (patched["rare"] as Array).size() == (data.treemon_set(index)["rare"] as Array).size(),
			"treemon set %d did not read its patch back." % index
		)
	var rows: int = 0
	for pair: Array in [
		[Gen2ContentOverlay.KIND_BUG_CONTEST, data.bug_contest_mons()],
		[Gen2ContentOverlay.KIND_ROAMING, data.world_roaming_mons()],
	]:
		for index: int in (pair[1] as Array).size():
			rows += 1
			overlay.patch(pair[0], &"check", index, {"species": index + 1})
	for index: int in data.world_fishing_time_groups().size():
		rows += 1
		overlay.patch(Gen2ContentOverlay.KIND_FISHING_TIME, &"check", index, {
			"night": {"species": index + 1, "level": 5},
		})
	for index: int in data.bug_contest_mons().size():
		_r.check(
			int(data.bug_contest_mons()[index]["species"]) == index + 1,
			"contest row %d did not read its patch back." % index
		)
	for index: int in data.world_roaming_mons().size():
		_r.check(
			int(data.world_roaming_mons()[index]["species"]) == index + 1,
			"roaming mon %d did not read its patch back." % index
		)
	for index: int in data.world_fishing_time_groups().size():
		_r.check(
			int(data.world_fishing_time_groups()[index]["night"]["species"]) == index + 1,
			"fishing time group %d did not read its patch back." % index
		)
	_r.note("wild patch indices: %d treemon sets and %d list rows read back." % [
		sets, rows,
	])
	## The shared overlay is untouched, since a check is not a mod.
	_r.check(host.content_overlay().is_empty(), "the check leaked into the shared overlay.")


func _census() -> void:
	var cells: int = 0
	var maps: Dictionary = {}
	var iced: int = 0
	for map: Gen2WorldMap in _r.data.world_maps():
		var tileset: Gen2WorldTileset = _r.data.world_tileset(map.tileset)
		if tileset == null:
			continue
		var world := Gen2WorldAPI.new(
			_r.data, map, tileset, Vector2i.ZERO, Gen2WorldState.new()
		)
		world.state.set_wild_encounter_cooldown(0)
		var counts: Dictionary = _map_counts(world)
		var visible: Dictionary = _visible_cells_match(world)
		if not bool(visible["ok"]):
			_r.check(false, "map %d/%d cell %s: %s." % [
				map.group, map.number, str(visible["cell"]), visible["reason"],
			])
			return
		cells += int(counts["encounter"])
		iced += int(counts["ice"])
		if int(counts["encounter"]) > 0:
			maps[map.group * 256 + map.number] = true
	var found: Array = [cells, maps.size(), iced]
	_r.note("encounter cells %d over %d maps, %d refused for ice." % [
		cells, maps.size(), iced,
	])
	var expected: Array = EXPECTED_CENSUS[_r.game_id]
	_r.check(
		found == expected,
		"census is %s, not the pinned %s." % [str(found), str(expected)]
	)


## What one map offers: walkable cells, cells CanEncounterWildMon accepts, and
## cells it would have accepted but for the ice test.
func _map_counts(world: Gen2WorldAPI) -> Dictionary:
	var walkable: int = 0
	var encounter: int = 0
	var ice: int = 0
	var map: Gen2WorldMap = world.current_map
	for y: int in map.collision_height:
		for x: int in map.collision_width:
			var cell := Vector2i(x, y)
			var permission: int = world.collision_permission_at(cell)
			if permission != Gen2WorldCollision.LAND_TILE \
				and permission != Gen2WorldCollision.WATER_TILE:
				continue
			walkable += 1
			world.player_cell = cell
			if world.can_encounter_wild_mon():
				encounter += 1
			elif Gen2WorldCollision.is_ice(world.collision_code_at(cell)):
				ice += 1
	return {"walkable": walkable, "encounter": encounter, "ice": ice}


## The sweep a visible-encounter provider is handed has to be exactly the set of
## cells the step roll accepts, cell for cell, or a mod stands a Pokemon where
## the cartridge would never have produced one. Answered per map and grouped by
## the method the terrain resolves to, so the two counts also have to add up.
func _visible_cells_match(world: Gen2WorldAPI) -> Dictionary:
	var sweep: Dictionary = world.visible_encounter_cells()
	var listed: Dictionary = {}
	for method: Variant in sweep:
		for cell: Vector2 in sweep[method] as PackedVector2Array:
			var at := Vector2i(cell)
			var permission: int = world.collision_permission_at(at)
			var wanted: StringName = Gen2WorldEncounter.METHOD_SURF \
				if permission == Gen2WorldCollision.WATER_TILE \
				else Gen2WorldEncounter.METHOD_GRASS
			if StringName(method) != wanted or listed.has(at):
				return {"ok": false, "cell": at, "reason": "wrong method or listed twice"}
			listed[at] = true
	var map: Gen2WorldMap = world.current_map
	for y: int in map.collision_height:
		for x: int in map.collision_width:
			var cell := Vector2i(x, y)
			world.player_cell = cell
			## The sweep's one narrowing on the roll: a cell nothing can stand
			## on. A cave's walls pass `CanEncounterWildMon`, since that branch
			## skips the grass test, and a Pokemon cannot be put in one.
			var permission: int = world.collision_permission_at(cell)
			var standable: bool = permission == Gen2WorldCollision.LAND_TILE \
				or permission == Gen2WorldCollision.WATER_TILE
			if (world.can_encounter_wild_mon() and standable) != listed.has(cell):
				return {"ok": false, "cell": cell, "reason": "the roll and the sweep disagree"}
	return {"ok": true, "cells": listed.size()}
