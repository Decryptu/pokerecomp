extends RefCounted

## Every Generation 1 trainer, swept on Red, Blue and Yellow:
## `TrainerDataPointers`' parties, the `trainer` header each `TalkToTrainer` text
## row carries, and that routine walked on every object standing on one. The
## counts come from pret's `data/trainers/parties.asm` and `scripts/`.

## Parties and members of `TrainerDataPointers`.
const PARTY_CENSUS: Dictionary = {
	&"red": [391, 994], &"blue": [391, 994], &"yellow": [396, 990],
}
const DEEPEST_PARTY: int = 6
const CLASS_COUNT: int = 47

## `text_asm` rows, the ones reaching `TalkToTrainer`, and the objects naming
## one: a trainer class above `OPP_ID_OFFSET`, or a standing wild below it.
const HEADER_CENSUS: Dictionary = {
	&"red": {"text_asm": 626, "headers": 322, "trainers": 310, "wilds": 12},
	&"blue": {"text_asm": 626, "headers": 322, "trainers": 310, "wilds": 12},
	&"yellow": {"text_asm": 675, "headers": 317, "trainers": 305, "wilds": 12},
}

## `view_range << 4` is a pixel distance, so the stored range is a nibble.
const MAX_SIGHT_RANGE: int = 5

## Sight lines walked, cells engaging their own trainer, and cells behind one.
const SIGHT_CENSUS: Dictionary = {
	&"red": {"lines": 295, "cells": 880, "behind": 0},
	&"blue": {"lines": 295, "cells": 880, "behind": 0},
	&"yellow": {"lines": 291, "cells": 868, "behind": 0},
}

## `BattleTransitions`' four trainer rows and the frames each runs to black in.
const TRAINER_TRANSITIONS: Dictionary = {
	Gen2BattleTransition.GEN1_TRAINER_BIT: 163,
	Gen2BattleTransition.GEN1_TRAINER_BIT
		| Gen2BattleTransition.GEN1_STRONGER_BIT: 130,
	Gen2BattleTransition.GEN1_TRAINER_BIT
		| Gen2BattleTransition.GEN1_DUNGEON_BIT: 64,
	Gen2BattleTransition.GEN1_TRAINER_BIT | Gen2BattleTransition.GEN1_STRONGER_BIT
		| Gen2BattleTransition.GEN1_DUNGEON_BIT: 64,
}
const TRANSITION_FRAME_CAP: int = 400

## Route 3's first Youngster: `YoungsterData`'s opening party and the base
## `pic_money` pays a level of.
const FIGHT_CLASS: int = 1
const FIGHT_INDEX: int = 0
const FIGHT_PARTY: Array = [[11, 19], [11, 23]]
const FIGHT_BASE_MONEY: int = 1500
const FIGHT_LEAD: int = 1
const FIGHT_LEAD_LEVEL: int = 50
const FIGHT_SEED: int = 20260930
const FIGHT_TURN_CAP: int = 64

## Where the player stands to talk to an object, and which way that faces.
const APPROACHES: Array = [
	[Vector2i.DOWN, Gen2WorldSprite.FACING_UP],
	[Vector2i.UP, Gen2WorldSprite.FACING_DOWN],
	[Vector2i.RIGHT, Gen2WorldSprite.FACING_LEFT],
	[Vector2i.LEFT, Gen2WorldSprite.FACING_RIGHT],
]

var _r: RefCounted = null


func run(r: RefCounted) -> void:
	_r = r
	r.each_game_of(RomRegistry.GEN1, _one_game)


func _one_game() -> void:
	_the_party_table()
	_the_headers()
	_every_trainer_is_talked_to()
	_every_trainer_sees()
	_a_trainer_is_beaten()
	_the_trainer_transitions()


## `CheckFightingMapTrainers` walked from every cell of every trainer's own
## line: inside the range the shock bubble and the walk-up open, and one cell
## past it or one cell behind, nothing does. `CheckPlayerIsInFrontOfSprite`
## exempts the Power Plant, but every fake item there carries `view_range` 0,
## which `CheckSpriteCanSeePlayer` refuses at any distance, so `behind` is 0.
func _every_trainer_sees() -> void:
	var census: Dictionary = {"lines": 0, "cells": 0, "behind": 0}
	for map: Gen2WorldMap in _r.data.world_maps():
		var rows: Array = map.events["objects"]
		var world: Gen2WorldAPI = null
		for index: int in rows.size():
			if int((rows[index] as Dictionary).get("sight_range", 0)) < 1:
				continue
			if world == null:
				world = _r.open_world(0, map.number, Vector2i.ZERO)
			if world == null:
				return
			_one_sight_line(world, map, index, census)
	_r.check(census == SIGHT_CENSUS[_r.game_id], "the sight census reads %s." % str(census))
	_r.note("gen1 trainers %d sight lines over %d cells" % [
		int(census["lines"]), int(census["cells"]),
	])


func _one_sight_line(
	world: Gen2WorldAPI, map: Gen2WorldMap, index: int, census: Dictionary
) -> void:
	var object: Gen2WorldObject = world.objects[index]
	var step: Vector2i = Gen2WorldAPI.SIGHT_STEPS[object.facing]
	var where: String = "map %d object %d" % [map.number, index]
	census["lines"] += 1
	for distance: int in range(1, object.sight_range + 1):
		var engaged: int = _engaged_at(world, object.cell + step * distance)
		if not _r.check(engaged >= 0 and engaged <= index,
			"%s saw nobody %d cells ahead." % [where, distance]):
			continue
		if engaged < index:
			continue
		census["cells"] += 1
		var path: Array = world.trainer_approach_plan(index, step, distance).get("path", [])
		_r.check(path.size() == distance - 1 and (path.is_empty() or path[0] == step),
			"%s walked %s to reach the player %d cells away." % [where, str(path), distance])
	_r.check(_engaged_at(world, object.cell + step * (object.sight_range + 1)) != index,
		"%s saw past its own range of %d." % [where, object.sight_range])
	if _engaged_at(world, object.cell - step) == index:
		census["behind"] += 1


## `dispatch_sight_events` from one cell, answering which object engaged and
## spending `TalkToTrainer` behind it so the next cell starts on an idle world.
func _engaged_at(world: Gen2WorldAPI, cell: Vector2i) -> int:
	world.player_cell = cell
	var opened: Array = world.dispatch_sight_events()
	if opened.is_empty():
		return -1
	var request: Dictionary = (opened[0].get("event", {}) as Dictionary).get("request", {})
	world.complete_runtime_request({"ok": true})
	world.run_event_queue(true)
	world.complete_runtime_request({})
	_r.check(not world.script_busy(), "a sighting at %s held the world." % cell)
	_r.check(StringName(request.get("kind", &"")) == &"trainer_approach_requested",
		"a sighting at %s opened %s." % [cell, request.get("kind", &"nothing")])
	return int((request.get("values", {}) as Dictionary).get("object_index", -1))


## A party is never empty, never over six, and every member is a real species.
func _the_party_table() -> void:
	var parties: int = 0
	var members: int = 0
	_r.check(_r.data.trainer_count() == CLASS_COUNT,
		"the cache holds %d trainer classes." % _r.data.trainer_count())
	for number: int in range(1, _r.data.trainer_count() + 1):
		var name: String = _r.data.trainer_name(number)
		for index: int in _r.data.trainer_party_count(number):
			var party: Array = (_r.data.trainer_party(number, index) as Dictionary)["party"]
			parties += 1
			members += party.size()
			if not _r.check(not party.is_empty() and party.size() <= DEEPEST_PARTY,
				"%s %d brings %d Pokemon." % [name, index + 1, party.size()]):
				continue
			for mon: Dictionary in party:
				_r.check(int(mon["species"]) >= 1 and int(mon["species"]) <= Gen1Layout.SPECIES_COUNT,
					"%s %d brings species %d." % [name, index + 1, int(mon["species"])])
				_r.check(int(mon["level"]) >= 1 and int(mon["level"]) <= Gen2Layout.MAX_LEVEL,
					"%s %d brings a level %d." % [name, index + 1, int(mon["level"])])
	var pinned: Array = PARTY_CENSUS[_r.game_id]
	_r.check([parties, members] == pinned,
		"the party table reads %d parties and %d members, pinned %s." % [
			parties, members, str(pinned),
		])
	_r.note("gen1 trainers %d parties, %d members" % [parties, members])


## Every header the corpus carries, and the object each belongs to: three texts,
## a range inside its nibble, a flag above zero, and a party that is stored.
func _the_headers() -> void:
	var census: Dictionary = {"text_asm": 0, "headers": 0, "trainers": 0, "wilds": 0}
	for map: Gen2WorldMap in _r.data.world_maps():
		for row: Dictionary in map.texts:
			if int(row.get("command", 0)) == Gen1Layout.TEXT_ASM:
				census["text_asm"] += 1
			if row.has("trainer"):
				census["headers"] += 1
				_one_header(map, row["trainer"])
		for object: Dictionary in map.events["objects"] as Array:
			var header: Dictionary = _header_for(map, object)
			if header.is_empty():
				continue
			## `CheckForEngagingTrainers` walks one list, so both kinds carry the
			## type and the range; only the flag's place tells them apart.
			_r.check(int(object.get("object_type", 0)) == Gen2WorldObject.OBJECTTYPE_TRAINER
				and int(object.get("sight_range", -1)) == int(header["sight_range"]),
				"map %d's header row is object type %d seeing %d." % [
					map.number, int(object.get("object_type", 0)),
					int(object.get("sight_range", -1)),
				])
			if object.has("trainer_class"):
				census["trainers"] += 1
				_one_trainer_object(map, object)
			else:
				census["wilds"] += 1
				_r.check(int(object.get("event_flag", 0)) == int(header["event_flag"]),
					"map %d's standing wild wears flag %d." % [
						map.number, int(object.get("event_flag", 0)),
					])
	_r.check(census == HEADER_CENSUS[_r.game_id],
		"the header census reads %s." % str(census))
	_r.note("gen1 trainers %d headers on %d text_asm rows" % [
		int(census["headers"]), int(census["text_asm"]),
	])


func _one_header(map: Gen2WorldMap, header: Dictionary) -> void:
	_r.check(int(header["event_flag"]) > 0,
		"map %d has a header on flag %d." % [map.number, int(header["event_flag"])])
	_r.check(int(header["sight_range"]) <= MAX_SIGHT_RANGE,
		"map %d has a header seeing %d cells." % [map.number, int(header["sight_range"])])
	for name: String in ["before", "after", "end"]:
		_r.check(not String(header[name]).is_empty(),
			"map %d has a header with no %s text." % [map.number, name])


func _one_trainer_object(map: Gen2WorldMap, object: Dictionary) -> void:
	var trainer_class: int = int(object["trainer_class"])
	var number: int = int(object["trainer_number"])
	if not _r.check(trainer_class >= 1 and trainer_class <= CLASS_COUNT,
		"map %d has trainer class %d." % [map.number, trainer_class]):
		return
	_r.check(number >= 1 and number <= _r.data.trainer_party_count(trainer_class),
		"map %d wants %s %d of %d." % [
			map.number, _r.data.trainer_name(trainer_class), number,
			_r.data.trainer_party_count(trainer_class),
		])


func _header_for(map: Gen2WorldMap, object: Dictionary) -> Dictionary:
	var id: int = int(object.get("text", 0))
	if id < 1 or id > map.texts.size():
		return {}
	var row: Dictionary = map.texts[id - 1]
	return row["trainer"] if row.has("trainer") else {}


## `TalkToTrainer` on every object standing on a header: the before-battle line,
## the fight it names, and the after-battle line once its flag is on.
func _every_trainer_is_talked_to() -> void:
	var talked: int = 0
	var wilds: int = 0
	for map: Gen2WorldMap in _r.data.world_maps():
		var world: Gen2WorldAPI = null
		for object: Dictionary in map.events["objects"] as Array:
			var header: Dictionary = _header_for(map, object)
			if header.is_empty():
				continue
			if world == null:
				world = _r.open_world(0, map.number, Vector2i.ZERO)
				if world == null:
					return
			if not _talk_to(world, map, object, header):
				continue
			if object.has("trainer_class"):
				talked += 1
			else:
				wilds += 1
	var pinned: Dictionary = HEADER_CENSUS[_r.game_id]
	_r.check(talked == int(pinned["trainers"]) and wilds == int(pinned["wilds"]),
		"%d trainers and %d standing wilds answered." % [talked, wilds])


func _talk_to(
	world: Gen2WorldAPI, map: Gen2WorldMap, object: Dictionary, header: Dictionary
) -> bool:
	var opened: Array = _face(world, object)
	var where: String = "map %d text %d" % [map.number, int(object.get("text", 0))]
	if not _r.check(not opened.is_empty(), "%s said nothing." % where):
		return false
	if not _r.check(_event_text(opened) == String(header["before"]),
		"%s opened with %s." % [where, _event_text(opened)]):
		return false
	var request: Dictionary = _request_after(world)
	if not _r.check(_battle_matches(request, object), "%s asked for %s." % [where, str(request)]):
		return false
	world.complete_runtime_request({"outcome": Gen2WorldBattleAdapter.OUTCOME_WON})
	if not _r.check(not world.script_busy(), "%s held the world after its fight." % where):
		return false
	if not _r.check(world.event_flag_active(int(header["event_flag"])),
		"%s left flag %d clear." % [where, int(header["event_flag"])]):
		return false
	if not object.has("trainer_class"):
		return _r.check(_face(world, object).is_empty(), "%s is still on the map." % where)
	var again: Array = _face(world, object)
	var answered: bool = _r.check(_event_text(again) == String(header["after"]),
		"%s finished with %s." % [where, _event_text(again)])
	world.run_event_queue(true)
	return answered


## The first of the four cells around an object that opens a box. Nothing is
## walked, so a wall is as good as a path.
func _face(world: Gen2WorldAPI, object: Dictionary) -> Array:
	var cell := Vector2i(int(object["x"]), int(object["y"]))
	for approach: Array in APPROACHES:
		world.player_cell = cell + (approach[0] as Vector2i)
		world.player_facing = int(approach[1])
		var opened: Array = world.interact()
		if not opened.is_empty():
			return opened
	return []


## What the box is waiting on, once `AfterDisplayingTextID`'s press is spent.
func _request_after(world: Gen2WorldAPI) -> Dictionary:
	world.run_event_queue(true)
	return world.pending_runtime_request()


func _battle_matches(request: Dictionary, object: Dictionary) -> bool:
	if StringName(request.get("kind", &"")) != &"battle_requested":
		return false
	var values: Dictionary = request.get("values", {})
	if not object.has("trainer_class"):
		return StringName(values.get("kind", &"")) == &"wild" \
			and int(values.get("pokemon", 0)) == int(object.get("species", 0)) \
			and int(values.get("level", 0)) == int(object.get("level", 0))
	return StringName(values.get("kind", &"")) == &"trainer" \
		and int(values.get("trainer_group", 0)) == int(object["trainer_class"]) \
		and int(values.get("trainer_id", -1)) == int(object["trainer_number"]) - 1


## That fight run to its last faint: `ReadTrainerParty` brings the stored party
## and `.LastLoop` pays the class's base once a level of the last member.
func _a_trainer_is_beaten() -> void:
	var party: Array = (_r.data.trainer_party(FIGHT_CLASS, FIGHT_INDEX) as Dictionary)["party"]
	var read: Array = []
	for mon: Dictionary in party:
		read.append([int(mon["level"]), int(mon["species"])])
	if not _r.check(read == FIGHT_PARTY, "%s 1 brings %s." % [
		_r.data.trainer_name(FIGHT_CLASS), str(read),
	]):
		return
	var enemy: Gen2Party = Gen2TrainerParty.build(_r.data, FIGHT_CLASS, FIGHT_INDEX)
	var generator := RandomNumberGenerator.new()
	generator.seed = FIGHT_SEED
	var battle: Gen2Battle = Gen2Battle.create_parties(
		_r.data,
		Gen2Party.create([Gen2BattleMon.create(
			_r.data, FIGHT_LEAD, FIGHT_LEAD_LEVEL,
			_r.data.moves_at_level(FIGHT_LEAD, FIGHT_LEAD_LEVEL)
		)]),
		enemy, generator, true, 0
	)
	if not _r.check(battle != null, "the trainer fight could not be built."):
		return
	battle.init_enemy_trainer(FIGHT_CLASS, true)
	var owed: int = FIGHT_BASE_MONEY * int(FIGHT_PARTY[-1][0])
	_r.check(battle.battle_reward == owed,
		"the fight pays %d, not %d." % [battle.battle_reward, owed])
	var turns: int = 0
	while not battle.is_over() and turns < FIGHT_TURN_CAP:
		if battle.mon(Gen2Battle.ENEMY).is_fainted():
			## `ReplaceFaintedEnemyMon`, which the screen owns in a real fight.
			battle.send_out(Gen2Battle.ENEMY, enemy.first_healthy())
			continue
		battle.take_turn(0, 0)
		turns += 1
	_r.check(battle.winner() == Gen2Battle.PLAYER,
		"the trainer fight ended on %s after %d turns." % [battle.winner(), turns])


## Each of those rows run to `BlackScreen`.
func _the_trainer_transitions() -> void:
	for index: int in TRAINER_TRANSITIONS:
		var transition: Gen2BattleTransition = Gen2BattleTransition.create_gen1(index)
		if not _r.check(transition != null, "transition %d has no scene." % index):
			continue
		var frames: int = 0
		while not transition.finished() and frames < TRANSITION_FRAME_CAP:
			transition.advance_frame()
			frames += 1
		_r.check(frames == int(TRAINER_TRANSITIONS[index]),
			"transition %d ran %d frames, pinned %d." % [
				index, frames, int(TRAINER_TRANSITIONS[index]),
			])
		_r.check(transition.palette_order() == Gen2BattleTransition.GEN1_BLACK_ORDER,
			"transition %d ended on order $%02X." % [index, transition.palette_order()])


func _event_text(results: Array) -> String:
	if results.is_empty():
		return ""
	return String((results[0].get("event", {}) as Dictionary).get("text", ""))
