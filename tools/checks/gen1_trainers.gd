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
	&"red": {"text_asm": 642, "headers": 322, "trainers": 310, "wilds": 12, "coded": 3},
	&"blue": {"text_asm": 642, "headers": 322, "trainers": 310, "wilds": 12, "coded": 3},
	&"yellow": {"text_asm": 695, "headers": 317, "trainers": 305, "wilds": 12, "coded": 3},
}
## The header texts whose machine code does more than print, by map and the
## flag each sets; Yellow moved the LIFT KEY's `ShowObject` to the end text.
const CODED_HEADER_FLAGS: Dictionary = {
	&"red": {"113:after": 2302, "199:end": 1653, "202:after": 1702},
	&"blue": {"113:after": 2302, "199:end": 1653, "202:after": 1702},
	&"yellow": {"113:after": 2302, "199:end": 1653, "202:end": 1702},
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
const FIGHT_BASE_MONEY: int = 15
const FIGHT_LEAD: int = 1
const FIGHT_LEAD_LEVEL: int = 50
const FIGHT_SEED: int = 20260930
const FIGHT_TURN_CAP: int = 64

## Classes running each layer, classes past `GenericAI`, and the use counts
## summed. Yellow drops layer 3 from four classes.
const AI_CENSUS: Dictionary = {
	&"red": {"layer1": 45, "layer2": 8, "layer3": 21, "routines": 19, "uses": 116},
	&"blue": {"layer1": 45, "layer2": 8, "layer3": 21, "routines": 19, "uses": 116},
	&"yellow": {"layer1": 45, "layer2": 8, "layer3": 17, "routines": 19, "uses": 116},
}
## Each routine's action at 1 HP with a status, as the `Random` bytes of 256
## that reach it: `cp n / ret nc` is n, Agatha's potion 129 - 20, no roll 256.
const ROUTINE_SHARES: Dictionary = {
	"generic": {},
	"juggler": {"switch": 65},
	"blackbelt": {Gen1TrainerAI.X_ATTACK: 32},
	"giovanni": {Gen1TrainerAI.GUARD_SPEC: 65},
	"cooltrainer_m": {Gen1TrainerAI.X_ATTACK: 65},
	"cooltrainer_f": {Gen1TrainerAI.HYPER_POTION: 256},
	"brock": {Gen1TrainerAI.FULL_HEAL: 256},
	"misty": {Gen1TrainerAI.X_DEFEND: 65},
	"lt_surge": {Gen1TrainerAI.X_SPEED: 65},
	"erika": {Gen1TrainerAI.SUPER_POTION: 129},
	"koga": {Gen1TrainerAI.X_ATTACK: 65},
	"koga_yellow": {Gen1TrainerAI.X_ATTACK: 32},
	"blaine": {Gen1TrainerAI.SUPER_POTION: 65},
	"blaine_yellow": {Gen1TrainerAI.SUPER_POTION: 65},
	"sabrina": {Gen1TrainerAI.HYPER_POTION: 65},
	"sabrina_yellow": {Gen1TrainerAI.X_DEFEND: 65},
	"rival2": {Gen1TrainerAI.POTION: 32},
	"rival3": {Gen1TrainerAI.FULL_RESTORE: 32},
	"lorelei": {Gen1TrainerAI.SUPER_POTION: 129},
	"bruno": {Gen1TrainerAI.X_DEFEND: 65},
	"agatha": {"switch": 20, Gen1TrainerAI.SUPER_POTION: 109},
	"lance": {Gen1TrainerAI.HYPER_POTION: 129},
}
const ROUTINE_SEEDS: int = 512
const SHARE_TOLERANCE: float = 0.04

## Class, party, member, slot, move and `wLoneAttackNo`: Brock's Onix,
## Lorelei's fifth and the champion's Pidgeot and Venusaur.
const BROCK_CLASS: int = 34
const LORELEI_CLASS: int = 44
const RIVAL3_CLASS: int = 43
const BULBASAUR_INDEX: int = 0x99
const SPECIAL_MOVE_ROWS: Dictionary = {
	&"red": [
		[BROCK_CLASS, 0, 2, 3, 0x75, 1], [LORELEI_CLASS, 0, 5, 3, 0x3B, 0],
		[RIVAL3_CLASS, 0, 1, 3, 0x8F, 0], [RIVAL3_CLASS, 0, 6, 3, 0x48, 0],
	],
	&"blue": [
		[BROCK_CLASS, 0, 2, 3, 0x75, 1], [LORELEI_CLASS, 0, 5, 3, 0x3B, 0],
		[RIVAL3_CLASS, 0, 1, 3, 0x8F, 0], [RIVAL3_CLASS, 0, 6, 3, 0x48, 0],
	],
	&"yellow": [
		[BROCK_CLASS, 0, 2, 3, 0x14, 0], [BROCK_CLASS, 0, 2, 4, 0x75, 0],
		[LORELEI_CLASS, 0, 5, 3, 0x3B, 0], [RIVAL3_CLASS, 0, 6, 3, 0x62, 0],
	],
}
## Pewter Gym, Brock's cell, and Onix's third slot: `LoneMoves`' BIDE behind
## his row's `ld a, $1` on Red and Blue, Yellow's own ungated BIND.
const PEWTER_GYM: int = 0x36
const BROCK_APPROACH := Vector2i(4, 2)
const BROCK_LONE_ATTACK: int = 1
const BROCK_ONIX_MOVE: Dictionary = {&"red": 0x75, &"blue": 0x75, &"yellow": 0x14}

## Every row, `LoneMoves`' eight on each `$FF` party of Red and Blue.
const SPECIAL_MOVE_CENSUS: Dictionary = {&"red": 314, &"blue": 314, &"yellow": 102}

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
	_the_ai_tables()
	_the_special_moves()
	_the_headers()
	_every_trainer_is_talked_to()
	_every_trainer_sees()
	_a_trainer_is_beaten()
	_the_gym_leader_stamps_the_lone_move()
	_every_routine_acts()
	_the_trainer_transitions()


func _the_ai_tables() -> void:
	var census: Dictionary = {"layer1": 0, "layer2": 0, "layer3": 0, "routines": 0, "uses": 0}
	for trainer_class: int in range(1, CLASS_COUNT + 1):
		var attributes: Dictionary = _r.data.trainer_attributes(trainer_class)
		for layer: int in attributes["ai_layers"]:
			census["layer%d" % layer] = int(census.get("layer%d" % layer, 0)) + 1
		census["uses"] += int(attributes["ai_count"])
		var routine: String = String(attributes["ai_routine"])
		if not _r.check(Gen1TrainerAI.ROUTINES.has(routine),
			"class %d names AI routine '%s'." % [trainer_class, routine]):
			continue
		if routine != "generic":
			census["routines"] += 1
	_r.check(census == AI_CENSUS[_r.game_id],
		"the AI tables read %s, pinned %s." % [str(census), str(AI_CENSUS[_r.game_id])])


func _the_special_moves() -> void:
	var rows: int = 0
	for trainer_class: int in range(1, CLASS_COUNT + 1):
		for index: int in _r.data.trainer_party_count(trainer_class):
			rows += (_r.data.trainer_party(trainer_class, index)["special_moves"] as Array).size()
	_r.check(rows == int(SPECIAL_MOVE_CENSUS[_r.game_id]),
		"%d special move rows, pinned %d." % [rows, int(SPECIAL_MOVE_CENSUS[_r.game_id])])
	for row: Array in SPECIAL_MOVE_ROWS[_r.game_id]:
		var context: Dictionary = {"lone_attack": int(row[5]), "rival_starter": BULBASAUR_INDEX}
		var party: Gen2Party = Gen2TrainerParty.build(_r.data, int(row[0]), int(row[1]), null, context)
		var member: Gen2BattleMon = party.at(int(row[2]) - 1) if party != null else null
		if not _r.check(member != null, "class %d party %d has no member %d." % [row[0], row[1], row[2]]):
			continue
		var slot: int = int(row[3]) - 1
		var move: int = int(member.moves[slot]) if slot < member.moves.size() else 0
		_r.check(move == int(row[4]) and member.pp_left(slot) > 0,
			"class %d member %d slot %d knows move %d with %d PP, wanted %d." % [
				row[0], row[2], row[3], move, member.pp_left(slot), row[4],
			])
		if int(row[5]) == 0:
			continue
		var plain: Gen2Party = Gen2TrainerParty.build(_r.data, int(row[0]), int(row[1]))
		var without: int = int(plain.at(int(row[2]) - 1).moves[slot]) \
			if slot < plain.at(int(row[2]) - 1).moves.size() else 0
		_r.check(without != int(row[4]),
			"class %d member %d knows its lone move with wLoneAttackNo clear." % [row[0], row[2]])


## `wGymLeaderNo` is written behind `InitBattleEnemyParameters`, so the request
## carries it as it stands when the fight opens and `ReadTrainer` reads it.
func _the_gym_leader_stamps_the_lone_move() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, PEWTER_GYM, BROCK_APPROACH)
	if world == null:
		return
	world.player_facing = Gen2WorldSprite.FACING_UP
	if not _r.check(not world.interact().is_empty(), "Brock said nothing."):
		return
	var request: Dictionary = _request_after(world)
	var values: Dictionary = request.get("values", {})
	if not _r.check(int(values.get("trainer_group", 0)) == BROCK_CLASS
		and int(values.get("lone_attack", 0)) == BROCK_LONE_ATTACK,
		"Brock's row asked for %s." % str(request)):
		return
	var prepared: Dictionary = Gen2WorldBattleAdapter.prepare(
		_r.data, request, Gen2WorldBattleAdapter.fallback_party(_r.data)
	)
	var onix: Gen2BattleMon = (prepared.get("enemy_party") as Gen2Party).at(1) \
		if bool(prepared.get("ok", false)) else null
	var known: Array = onix.moves if onix != null else []
	_r.check(known.size() > 2 and int(known[2]) == int(BROCK_ONIX_MOVE[_r.game_id]),
		"Brock's Onix knows %s." % str(known))
	world.complete_runtime_request({"outcome": Gen2WorldBattleAdapter.OUTCOME_WON})


## `TrainerAI` over every class's first party at 1 HP with a burn and a bench,
## so every gate but the roll passes.
func _every_routine_acts() -> void:
	var generator := RandomNumberGenerator.new()
	var lead: Gen2BattleMon = Gen2BattleMon.create(
		_r.data, FIGHT_LEAD, FIGHT_LEAD_LEVEL, _r.data.moves_at_level(FIGHT_LEAD, FIGHT_LEAD_LEVEL)
	)
	var routines: Dictionary = {}
	for trainer_class: int in range(1, CLASS_COUNT + 1):
		var routine: String = String(_r.data.trainer_attributes(trainer_class)["ai_routine"])
		if routines.has(routine) or _r.data.trainer_party_count(trainer_class) == 0:
			continue
		routines[routine] = true
		var enemy: Gen2Party = Gen2TrainerParty.build(_r.data, trainer_class, 0)
		if enemy.size() < 2:
			enemy = Gen2Party.create([enemy.at(0), Gen2BattleMon.create(
				_r.data, FIGHT_LEAD, FIGHT_LEAD_LEVEL, [1]
			)])
		var battle: Gen2Battle = Gen2Battle.create_parties(
			_r.data, Gen2Party.of(lead), enemy, generator, true, 0
		)
		battle.init_enemy_trainer(trainer_class, true)
		var census: Dictionary = {}
		for seed_value: int in ROUTINE_SEEDS:
			generator.seed = seed_value
			battle.gen1_ai_count = Gen1TrainerAI.COUNT_UNLOADED
			battle.mon(Gen2Battle.ENEMY).hp = 1
			battle.mon(Gen2Battle.ENEMY).status = Gen2Status.BURN
			var action: Dictionary = Gen1TrainerAI.trainer_action(battle, generator)
			if action.is_empty():
				continue
			var kind: Variant = int(action.get("item", 0))
			if StringName(action["type"]) == Gen2Battle.ACTION_SWITCH:
				kind = "switch"
			census[kind] = int(census.get(kind, 0)) + 1
		var expected: Dictionary = ROUTINE_SHARES[routine]
		var same_kinds: bool = census.size() == expected.size()
		for kind: Variant in expected:
			same_kinds = same_kinds and census.has(kind)
		if not _r.check(same_kinds,
			"%s reached %s, expected %s." % [routine, str(census), str(expected.keys())]):
			continue
		for kind: Variant in expected:
			var share: float = float(census[kind]) / float(ROUTINE_SEEDS)
			_r.check(absf(share - float(expected[kind]) / 256.0) < SHARE_TOLERANCE,
				"%s reached %s on %.3f of rolls, expected %d of 256." % [
					routine, str(kind), share, int(expected[kind]),
				])
	_r.note("gen1 trainers %d AI routines act at their shares" % routines.size())


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
## The map's own script runs first and may redraw a gate behind the last fight.
func _engaged_at(world: Gen2WorldAPI, cell: Vector2i) -> int:
	world.player_cell = cell
	var opened: Array = world.dispatch_sight_events()
	if opened.is_empty() or not world.script_busy():
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
	var census: Dictionary = {"text_asm": 0, "headers": 0, "trainers": 0, "wilds": 0, "coded": 0}
	var coded: Dictionary = {}
	for map: Gen2WorldMap in _r.data.world_maps():
		for row: Dictionary in map.texts:
			if int(row.get("command", 0)) == Gen1Layout.TEXT_ASM:
				census["text_asm"] += 1
			if row.has("trainer"):
				census["headers"] += 1
				_one_header(map, row["trainer"])
				for name: String in ["before", "after", "end"]:
					var flag: int = _first_flag((row["trainer"] as Dictionary).get("%s_script" % name, []))
					if flag < 0:
						continue
					census["coded"] += 1
					coded["%d:%s" % [map.number, name]] = flag
		for object: Dictionary in map.events["objects"] as Array:
			var header: Dictionary = _header_for(map, object)
			if header.is_empty():
				continue
			## Both kinds carry the type, the range and the header's own flag.
			_r.check(int(object.get("object_type", 0)) == Gen2WorldObject.OBJECTTYPE_TRAINER
				and int(object.get("sight_range", -1)) == int(header["sight_range"])
				and int((object.get("trainer", {}) as Dictionary).get("event_flag", 0))
					== int(header["event_flag"]),
				"map %d's header row is object type %d seeing %d on flag %d." % [
					map.number, int(object.get("object_type", 0)),
					int(object.get("sight_range", -1)),
					int((object.get("trainer", {}) as Dictionary).get("event_flag", 0)),
				])
			if object.has("trainer_class"):
				census["trainers"] += 1
				_one_trainer_object(map, object)
			else:
				census["wilds"] += 1
				_r.check(int(object.get("toggle_index", -1)) >= 0,
					"map %d's standing wild is outside ToggleableObjectStates." % map.number)
	_r.check(census == HEADER_CENSUS[_r.game_id],
		"the header census reads %s." % str(census))
	_r.check(coded == CODED_HEADER_FLAGS[_r.game_id], "the coded header texts set %s." % [coded])
	_r.note("gen1 trainers %d headers on %d text_asm rows" % [
		int(census["headers"]), int(census["text_asm"]),
	])


func _first_flag(script: Array) -> int:
	for node: Dictionary in script:
		if String(node.get("op", "")) == "flag":
			return int(node["flag"])
	return -1


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
	if not _r.check(_event_text(opened) == world.gen1_filled_text(String(header["before"])),
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
	var answered: bool = _r.check(
		_event_text(again) == world.gen1_filled_text(String(header["after"])),
		"%s finished with %s." % [where, _event_text(again)]
	)
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
	for member: Gen2BattleMon in enemy.mons:
		for slot: int in member.moves.size():
			_r.check(member.pp_left(slot) == int(_r.data.move(int(member.moves[slot])).get("pp", 0)),
				"an opponent's move %d spent PP." % int(member.moves[slot]))


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
