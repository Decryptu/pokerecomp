class_name Gen2WorldScriptFlow
extends RefCounted

## What holds on every path from each event to each script command, which a
## straight read loses behind `iftrue`. Conditions are [Gen2WorldStory]'s; a path
## testing one both ways is dropped, and `setevent` forgets its own flag.

const MAX_STEPS: int = 800000
const MAX_ORIGINS: int = 8
const ANYWHERE: String = "*"
const PLAYER: int = 0
const VAR_BADGES: int = 0x07
## `object_const_def` is `const_def 2`: the first `object_event` is object 2.
const FIRST_OBJECT: int = 2
const TESTS: Dictionary = {&"checkevent": "e", &"checkflag": "f", &"checkitem": "i"}
const JUMPS: Array[StringName] = [
	&"scall", &"sjump", &"iftrue", &"iffalse", &"ifequal", &"ifnotequal", &"ifgreater",
	&"ifless", &"sdefer", &"stopandsjump",
]
const FAR_JUMPS: Array[StringName] = [&"farscall", &"farsjump"]
const STD_JUMPS: Array[StringName] = [&"jumpstd", &"callstd"]

var _data: GameData = null
var _crystal: bool = true
var _code: Dictionary = {}
var _decoded: Dictionary = {}
## Command key to `{origin: conditions}`, [constant ANYWHERE] past too many.
var _state: Dictionary = {}
## Origin to its place; `[group, number, -1]` is a map callback.
var _places_by_name: Dictionary = {}
var _queue: Array = []
var _queued: Dictionary = {}
var _std: Dictionary = {}
## `[sets, requires, at]` per trainer, whose flag the battle sets.
var _beaten: Array = []
var _implied: Dictionary = {}


static func build(data: GameData, start: Vector2i = Gen2WorldProgression.START_MAP) -> Gen2WorldScriptFlow:
	var out := Gen2WorldScriptFlow.new()
	out._data = data
	out._crystal = Gen2WorldState.is_crystal_profile(data)
	out._walk_all()
	var implied: Dictionary = out._implications(start)
	if implied.is_empty():
		return out
	var closed := Gen2WorldScriptFlow.new()
	closed._data = data
	closed._crystal = out._crystal
	closed._implied = implied
	closed._walk_all()
	return closed


func _walk_all() -> void:
	for map: Gen2WorldMap in _data.world_maps():
		_enter_map(map)
	_enter_phone()
	_run()


static func key_of(bank: int, address: int) -> int:
	return (bank & 0xFF) << 24 | (address & 0xFFFFFF)


## What holds on every path to the command, or null when no event reaches it.
func conditions_at(bank: int, address: int) -> Variant:
	var key: int = key_of(bank, address)
	if not _state.has(key):
		return null
	return _meet_all(_state[key]).keys()


## The one `[x, y]` event cell of [param map] that reaches the command, or null.
func cell_at(bank: int, address: int, map: Vector2i) -> Variant:
	var places: Array = _places(key_of(bank, address))
	if places.size() != 1 or (places[0] as Array).size() != 4:
		return null
	var at: Array = places[0]
	if int(at[0]) != map.x or int(at[1]) != map.y:
		return null
	return Vector2i(int(at[2]), int(at[3]))


func map_at(bank: int, address: int) -> Variant:
	var maps: Array = _maps_of(_places(key_of(bank, address)))
	return maps[0] if maps.size() == 1 else null


func _enter_map(map: Gen2WorldMap) -> void:
	var bank: int = int(map.events.get("bank", 0))
	var here := Vector2i(map.group, map.number)
	for object: Dictionary in map.events.get("objects", []) as Array:
		var conds: Dictionary = {}
		if int(object.get("event_flag", -1)) >= 0:
			conds["!e:%d" % int(object["event_flag"])] = true
		var at: Array = [map.group, map.number, int(object.get("x", 0)), int(object.get("y", 0))]
		match int(object.get("object_type", -1)):
			Gen2WorldObject.OBJECTTYPE_SCRIPT:
				_enter(bank, int(object.get("script", 0)), conds, at)
			Gen2WorldObject.OBJECTTYPE_TRAINER:
				var trainer: Dictionary = object.get("trainer", {})
				_enter(bank, int(trainer.get("after_script", 0)), conds, at)
				if int(trainer.get("event_flag", -1)) >= 0:
					_beaten.append([["e:%d" % int(trainer["event_flag"])], conds.keys(), [at]])
	for event: Dictionary in map.events.get("bg_events", []) as Array:
		_enter_bg(bank, event, [map.group, map.number, int(event.get("x", 0)), int(event.get("y", 0))])
	for event: Dictionary in map.events.get("coord_events", []) as Array:
		var scene: String = Gen2WorldStory.scene(map.group, map.number, int(event.get("scene", 0)))
		_enter(bank, int(event.get("script", 0)), {scene: true},
			[map.group, map.number, int(event.get("x", 0)), int(event.get("y", 0))])
	var script_bank: int = int(map.scripts.get("bank", bank))
	for row: Dictionary in map.scripts.get("scenes", []) as Array:
		var scene: String = Gen2WorldStory.scene(here.x, here.y, int(row.get("id", 0)))
		_enter(script_bank, int(row.get("script", 0)), {scene: true}, [here.x, here.y])
	for row: Dictionary in map.scripts.get("callbacks", []) as Array:
		_enter(script_bank, int(row.get("script", 0)), {}, [here.x, here.y, -1])


## `BGEVENT_IFSET` and `BGEVENT_IFNOTSET` point at `dw event, script`.
func _enter_bg(bank: int, event: Dictionary, at: Array) -> void:
	var type: int = int(event.get("type", -1))
	var address: int = int(event.get("script", 0))
	if type <= Gen2WorldAPI.BGEVENT_LEFT:
		_enter(bank, address, {}, at)
		return
	if type != Gen2WorldAPI.BGEVENT_IFSET and type != Gen2WorldAPI.BGEVENT_IFNOTSET:
		return
	var record: PackedByteArray = _data.world_script(bank, address)
	if record.size() < 4:
		return
	var flag: int = int(record[0]) | int(record[1]) << 8
	var test: String = ("e:%d" if type == Gen2WorldAPI.BGEVENT_IFSET else "!e:%d") % flag
	_enter(bank, int(record[2]) | int(record[3]) << 8, {test: true}, at)


func _enter_phone() -> void:
	for index: int in _data.world_phone_contact_count():
		var contact: Dictionary = _data.world_phone_contact(index)
		for role: String in ["caller_script", "callee_script"]:
			var script: Dictionary = contact.get(role, {})
			_enter(int(script.get("bank", -1)), int(script.get("address", 0)), {}, [])
	for index: int in 32:
		var special: Dictionary = _data.world_special_phone_call(index)
		if special.is_empty():
			break
		var script: Dictionary = special.get("script", {})
		_enter(int(script.get("bank", -1)), int(script.get("address", 0)), {}, [])


func _enter(bank: int, address: int, conds: Dictionary, at: Array) -> void:
	if bank < 0 or address <= 0:
		return
	var key: int = key_of(bank, address)
	if not _code.has(key):
		var bytes: PackedByteArray = _data.world_script(bank, address)
		if bytes.is_empty():
			return
		_code[key] = [bytes, 0]
	var name: String = str(at) if not at.is_empty() else ANYWHERE
	_places_by_name[name] = at
	_merge(key, {name: conds})


func _merge(key: int, incoming: Dictionary) -> void:
	var changed: bool = not _state.has(key)
	if changed:
		_state[key] = {}
	var held: Dictionary = _state[key]
	var collapsed: bool = held.has(ANYWHERE) and held.size() == 1
	for name: String in incoming:
		changed = _meet(held, ANYWHERE if collapsed else name, _closed(incoming[name])) or changed
	if not collapsed and (held.size() > MAX_ORIGINS or (held.has(ANYWHERE) and held.size() > 1)):
		var all: Dictionary = _meet_all(held)
		held.clear()
		held[ANYWHERE] = all
		changed = true
	if changed and not _queued.has(key):
		_queued[key] = true
		_queue.append(key)


func _closed(conds: Dictionary) -> Dictionary:
	if _implied.is_empty():
		return conds
	var out: Dictionary = conds.duplicate()
	for condition: String in conds:
		for implied: String in _implied.get(condition, []):
			if not out.has(Gen2WorldStory.negate(implied)):
				out[implied] = true
	return out


## Each positive fact written to what every write of it held, which a path holding
## the fact keeps; a new game's facts and a scene's resting 0 imply nothing.
func _implications(start: Vector2i) -> Dictionary:
	var met: Dictionary = {}
	var free: Dictionary = {}
	for row: Array in _beaten:
		for fact: String in row[0]:
			_narrow(met, fact, row[1])
	for key: int in _state:
		var command: Dictionary = _decode(key)
		if command.is_empty():
			continue
		for name: String in _state[key]:
			var place: Array = _places_by_name.get(name, [])
			for fact: String in _facts(command, [place] if not place.is_empty() else []):
				if place.size() == 3 and int(place[0]) == start.x and int(place[1]) == start.y:
					free[fact] = true
				_narrow(met, fact, (_state[key][name] as Dictionary).keys())
	var out: Dictionary = {}
	for fact: String in met:
		if not free.has(fact) and not fact.begins_with("!") and not fact.ends_with("=0") \
			and not (met[fact] as Dictionary).is_empty():
			out[fact] = met[fact]
	for _pass: int in out.size():
		if not _widen(out):
			break
	var lists: Dictionary = {}
	for fact: String in out:
		lists[fact] = (out[fact] as Dictionary).keys()
	return lists


static func _narrow(met: Dictionary, fact: String, conds: Array) -> void:
	var positive: Dictionary = {}
	for condition: String in conds:
		if not condition.begins_with("!") and condition != fact:
			positive[condition] = true
	if not met.has(fact):
		met[fact] = positive
		return
	for condition: String in (met[fact] as Dictionary).keys():
		if not positive.has(condition):
			(met[fact] as Dictionary).erase(condition)


static func _widen(implied: Dictionary) -> bool:
	var grew: bool = false
	for fact: String in implied:
		var held: Dictionary = implied[fact]
		for condition: String in held.keys():
			for further: String in (implied.get(condition, {}) as Dictionary):
				if further != fact and not held.has(further):
					held[further] = true
					grew = true
	return grew


static func _meet(held: Dictionary, name: String, conds: Dictionary) -> bool:
	if not held.has(name):
		held[name] = conds.duplicate()
		return true
	var mine: Dictionary = held[name]
	var shrunk: bool = false
	for condition: String in mine.keys():
		if not conds.has(condition):
			mine.erase(condition)
			shrunk = true
	return shrunk


static func _meet_all(held: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var first: bool = true
	for name: String in held:
		if first:
			out = (held[name] as Dictionary).duplicate()
			first = false
			continue
		for condition: String in out.keys():
			if not (held[name] as Dictionary).has(condition):
				out.erase(condition)
	return out


func _run() -> void:
	for _step: int in MAX_STEPS:
		if _queue.is_empty():
			return
		var key: int = _queue.pop_back()
		_queued.erase(key)
		var command: Dictionary = _decode(key)
		if command.is_empty():
			continue
		var held: Dictionary = _state[key]
		for edge: Array in _edges(key, command):
			var incoming: Dictionary = {}
			for name: String in held:
				var conds: Dictionary = _carry(held[name], command)
				var test: String = edge[1]
				if test.is_empty():
					incoming[name] = conds
				elif not conds.has(Gen2WorldStory.negate(test)):
					incoming[name] = conds.merged({test: true})
			if not incoming.is_empty():
				_merge(int(edge[0]), incoming)


func _decode(key: int) -> Dictionary:
	if _decoded.has(key):
		return _decoded[key]
	var code: Array = _code.get(key, [])
	var command: Dictionary = {}
	if not code.is_empty():
		command = Gen2WorldScript.command_at(code[0], int(code[1]), _crystal)
	if not bool(command.get("ok", false)):
		command = {}
	_decoded[key] = command
	return command


func _carry(conds: Dictionary, command: Dictionary) -> Dictionary:
	var kind: String = ""
	match StringName(command["name"]):
		&"setevent", &"clearevent":
			kind = "e"
		&"setflag", &"clearflag":
			kind = "f"
	if kind.is_empty():
		return conds
	var flag: String = "%s:%d" % [kind, int(command.get("flag", 0))]
	if not conds.has(flag) and not conds.has("!" + flag):
		return conds
	var out: Dictionary = conds.duplicate()
	out.erase(flag)
	out.erase("!" + flag)
	return out


## `[key, condition]` per command that can run next: a test and its branch send
## each side its own answer.
func _edges(key: int, command: Dictionary) -> Array:
	var bank: int = key >> 24
	var address: int = key & 0xFFFFFF
	var code: Array = _code[key]
	var width: int = int(command["width"])
	var name: StringName = command["name"]
	if TESTS.has(name) or name == &"special" \
		or (name == &"readvar" and int(command.get("value", -1)) == VAR_BADGES):
		var branch: Array = _branch(bank, address, code, command)
		if not branch.is_empty():
			return branch
	var out: Array = []
	if Gen2WorldScript.continues_after(int(command["opcode"]), _crystal):
		out.append([_follow(bank, address + width, code[0], int(code[1]) + width), ""])
	if name in JUMPS:
		out.append([_locate(bank, int(command["address"]), key), ""])
	elif name in FAR_JUMPS:
		out.append([_locate(int(command["bank"]), int(command["address"]), -1), ""])
	elif name in STD_JUMPS:
		out.append([_standard(int(command["address"])), ""])
	return out.filter(func(edge: Array) -> bool: return int(edge[0]) >= 0)


func _branch(bank: int, address: int, code: Array, command: Dictionary) -> Array:
	var at: int = int(code[1]) + int(command["width"])
	var jump: Dictionary = Gen2WorldScript.command_at(code[0], at, _crystal)
	var answers: Array = _answers(command, jump)
	if answers.is_empty():
		return []
	var after: int = address + int(command["width"]) + int(jump["width"])
	var out: Array = [
		[_locate(bank, int(jump["address"]), key_of(bank, address)), answers[0]],
		[_follow(bank, after, code[0], at + int(jump["width"])), answers[1]],
	]
	return out.filter(func(edge: Array) -> bool: return int(edge[0]) >= 0)


## What each side of [param command]'s test learns: `b:N` off `readvar VAR_BADGES`,
## `x:N` a `special`'s true answer, which the proof never grants.
static func _answers(command: Dictionary, jump: Dictionary) -> Array:
	if not bool(jump.get("ok", false)):
		return []
	var name: StringName = jump["name"]
	if StringName(command["name"]) == &"special":
		var answered: String = "x:%d" % int(command.get("value", 0))
		match name:
			&"iftrue":
				return [answered, ""]
			&"iffalse":
				return ["", answered]
		return []
	if TESTS.has(command["name"]):
		if not name in [&"iftrue", &"iffalse"] or _temporary(command):
			return []
		var test: String = "%s:%d" % [TESTS[command["name"]], int(command.get("flag", command.get("value", 0)))]
		var taken: String = test if name == &"iftrue" else Gen2WorldStory.negate(test)
		return [taken, Gen2WorldStory.negate(taken)]
	var value: int = int(jump.get("value", 0))
	match name:
		&"ifgreater":
			return ["b:%d" % (value + 1), "!b:%d" % (value + 1)]
		&"ifless":
			return ["!b:%d" % value, "b:%d" % value]
		&"ifequal":
			return ["b:%d" % value, ""]
	return []


func _follow(bank: int, address: int, bytes: PackedByteArray, offset: int) -> int:
	var key: int = key_of(bank, address)
	if not _code.has(key):
		if offset >= bytes.size():
			return _locate(bank, address, -1)
		_code[key] = [bytes, offset]
	return key


## A jump's bytes: its own script, the blob it left, or a covering slice.
func _locate(bank: int, address: int, from: int) -> int:
	var key: int = key_of(bank, address)
	if _code.has(key):
		return key
	var exact: PackedByteArray = _data.world_script(bank, address)
	if not exact.is_empty():
		_code[key] = [exact, 0]
		return key
	if from >= 0 and (from >> 24) == bank:
		var code: Array = _code[from]
		var offset: int = address - ((from & 0xFFFFFF) - int(code[1]))
		if offset >= 0 and offset < (code[0] as PackedByteArray).size():
			_code[key] = [code[0], offset]
			return key
	var slice: PackedByteArray = _data.world_script_at(bank, address)
	if slice.is_empty():
		return -1
	_code[key] = [slice, 0]
	return key


func _standard(index: int) -> int:
	if _std.has(index):
		return _std[index]
	var entry: Dictionary = _data.world_standard_script(index)
	var bytes: PackedByteArray = entry.get("data", PackedByteArray())
	var key: int = -1
	if not bytes.is_empty() and int(entry.get("bank", -1)) >= 0:
		key = key_of(int(entry["bank"]), int(entry["address"]))
		if not _code.has(key):
			_code[key] = [bytes, 0]
	_std[index] = key
	return key


func _places(key: int) -> Array:
	var out: Array = []
	for name: String in _state.get(key, {}):
		if name == ANYWHERE:
			return []
		out.append(_places_by_name[name])
	return out


static func _stored(place: Array) -> Array:
	return place.slice(0, 2) if place.size() == 3 else place


## One setter per event reaching a write: events, engine flags, scenes, blocks,
## and the objects `disappear` and `appear` hide and show.
func write_setters(story: Gen2WorldStory, start: Vector2i) -> void:
	for row: Array in _beaten:
		story.add_setter(row[0], row[1], row[2])
	var keys: Array = _state.keys()
	keys.sort()
	for key: int in keys:
		var command: Dictionary = _decode(key)
		if command.is_empty():
			continue
		for name: String in _state[key]:
			var place: Array = _places_by_name.get(name, [])
			var sets: Array = _facts(command, [place] if not place.is_empty() else [])
			if sets.is_empty():
				continue
			if place.size() == 3 and int(place[0]) == start.x and int(place[1]) == start.y:
				story.initial.append_array(sets)
				continue
			story.add_setter(sets, (_state[key][name] as Dictionary).keys(),
				[_stored(place)] if not place.is_empty() else [])


func _facts(command: Dictionary, places: Array) -> Array:
	var flag: int = int(command.get("flag", 0))
	if _temporary(command):
		return []
	match StringName(command["name"]):
		&"setevent":
			return ["e:%d" % flag]
		&"clearevent":
			return ["!e:%d" % flag]
		&"setflag":
			return ["f:%d" % flag]
		&"clearflag":
			return ["!f:%d" % flag]
		&"setmapscene":
			return [Gen2WorldStory.scene(
				int(command["map_group"]), int(command["map_number"]), int(command["scene"])
			)]
		&"setscene":
			if not places.is_empty():
				return [Gen2WorldStory.scene(int(places[0][0]), int(places[0][1]), int(command["scene"]))]
		&"disappear", &"appear":
			return _object_facts(command, places)
		&"changeblock":
			if not places.is_empty():
				return [Gen2WorldStory.block(_maps_of(places)[0], _block_of(command))]
	return []


## `Script_changeblock` halves the cells into `GetBlockLocation`'s block.
static func _block_of(command: Dictionary) -> Vector2i:
	return Vector2i(int(command.get("x", 0)) & ~1, int(command.get("y", 0)) & ~1)


## The eight events every map load clears, which no fact outlives.
static func _temporary(command: Dictionary) -> bool:
	return StringName(command["name"]) in [&"checkevent", &"setevent", &"clearevent"] \
		and int(command.get("flag", -1)) in Gen2WorldState.TEMPORARY_MAP_RELOAD_FLAGS


## A script `warp` is a one-way link, open once its event's conditions hold.
func write_links(story: Gen2WorldStory) -> void:
	var keys: Array = _state.keys()
	keys.sort()
	for key: int in keys:
		var command: Dictionary = _decode(key)
		if command.is_empty() or not StringName(command["name"]) in [&"warp", &"warpfacing"]:
			continue
		var target: Gen2WorldMap = _data.world_map(int(command["map_group"]), int(command["map_number"]))
		if target == null:
			continue
		for name: String in _state[key]:
			if name == ANYWHERE:
				continue
			story.links.append({
				"at": [_stored(_places_by_name[name])],
				"requires": (_state[key][name] as Dictionary).keys(),
				"to": [target.group, target.number, int(command["x"]), int(command["y"])],
			})


## A rewritten block is a gate on its cells until the rewrite runs.
func write_block_gates(story: Gen2WorldStory) -> void:
	var seen: Dictionary = {}
	var keys: Array = _state.keys()
	keys.sort()
	for key: int in keys:
		var command: Dictionary = _decode(key)
		if command.is_empty() or StringName(command["name"]) != &"changeblock":
			continue
		for place: Array in _places(key):
			var map := Vector2i(int(place[0]), int(place[1]))
			var block: Vector2i = _block_of(command)
			var fact: String = Gen2WorldStory.block(map, block)
			if seen.has(fact):
				continue
			seen[fact] = true
			story.add_gate(map, [
				block, block + Vector2i.RIGHT, block + Vector2i.DOWN, block + Vector2i.ONE,
			], ["!" + fact])


func _object_facts(command: Dictionary, places: Array) -> Array:
	var index: int = int(command.get("object_id", 0)) - FIRST_OBJECT
	if index < 0 or places.is_empty():
		return []
	var map: Gen2WorldMap = _data.world_map(int(places[0][0]), int(places[0][1]))
	var objects: Array = map.events.get("objects", []) if map != null else []
	if index >= objects.size() or int((objects[index] as Dictionary).get("event_flag", -1)) < 0:
		return []
	var flag: int = int((objects[index] as Dictionary)["event_flag"])
	return ["e:%d" % flag] if StringName(command["name"]) == &"disappear" else ["!e:%d" % flag]


static func _maps_of(places: Array) -> Array:
	var out: Array = []
	for place: Array in places:
		var map := Vector2i(int(place[0]), int(place[1]))
		if not out.has(map):
			out.append(map)
	return out


## A coord event that walks the player off is a gate: its cell stays closed while
## what every walk off it tested holds, its scene included.
func write_coord_gates(story: Gen2WorldStory) -> void:
	for map: Gen2WorldMap in _data.world_maps():
		var bank: int = int(map.events.get("bank", 0))
		for event: Dictionary in map.events.get("coord_events", []) as Array:
			var at: Array = [map.group, map.number, int(event.get("x", 0)), int(event.get("y", 0))]
			var closing: Variant = _pushed_while(key_of(bank, int(event.get("script", 0))), str(at))
			if closing != null:
				story.add_gate(Vector2i(map.group, map.number), [Vector2i(int(at[2]), int(at[3]))], closing)


## What every path from this event to walking the player off holds, or null.
func _pushed_while(entry: int, origin: String) -> Variant:
	var seen: Dictionary = {}
	var pending: Array = [entry]
	var pushes: Dictionary = {}
	while not pending.is_empty() and seen.size() < 512:
		var key: int = pending.pop_back()
		if seen.has(key) or not (_state.get(key, {}) as Dictionary).has(origin):
			continue
		seen[key] = true
		var command: Dictionary = _decode(key)
		if command.is_empty():
			continue
		if _walks_player(command):
			pushes[origin + str(key)] = _state[key][origin]
		for edge: Array in _edges(key, command):
			pending.append(int(edge[0]))
	if pushes.is_empty():
		return null
	return _meet_all(pushes).keys()


## `applymovement PLAYER`, or `follow` with the player behind someone.
static func _walks_player(command: Dictionary) -> bool:
	match StringName(command["name"]):
		&"applymovement":
			return int(command.get("object_id", -1)) == PLAYER
		&"follow":
			return int(command.get("object_id_2", -1)) == PLAYER
	return false
