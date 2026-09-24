class_name Gen2WorldStory
extends RefCounted

## The cartridge's story as [Gen2WorldProgression] reads it, kept in the
## [Gen2WorldCatalog] sidecar. Conditions and facts share one spelling: `e:N` an
## event set (`!e:N` clear), `f:N` an engine flag, `i:N` an item held, `t:N` a
## Generation 1 toggle shown, `s:G:N=V` map G:N's scene or map script state,
## `c:G:N:X:Y` a block rewritten, `b:N` at least N badges, `o:N` species owned,
## `x:N` special N answered true.

## `{sets, requires, at}`, places `[group, number(, x, y)]`; no place is anywhere.
var setters: Array = []
## `{map, cells, closing}`, a closing list per thing standing there: the cells
## are walls until one condition of every list has flipped.
var gates: Array = []
## Map key to the `[x, y]` cells a standing person fills for good.
var walls: Dictionary = {}
## The facts a new game starts with: `InitializeEventsScript`'s own.
var initial: Array = []
## `{at, requires, to}`: a script's `warp`, once its conditions hold.
var links: Array = []
## Scene facts a gate's own push sets on the way back to its resting scene.
var transient: Dictionary = {}


static func negate(condition: String) -> String:
	return condition.substr(1) if condition.begins_with("!") else "!" + condition


static func scene(group: int, number: int, value: int) -> String:
	return "s:%d:%d=%d" % [group, number, value]


## A row's `requires` entry in this spelling, or empty for one nothing reads.
static func condition_of(requirement: Dictionary) -> String:
	if requirement.has("scene"):
		var at: Array = requirement["scene"]
		return scene(int(at[0]), int(at[1]), int(at[2]))
	var body: String = ""
	for key: String in REQUIREMENT_KINDS:
		if requirement.has(key):
			body = "%s:%d" % [REQUIREMENT_KINDS[key], int(requirement[key])]
	if body.is_empty() or not bool(requirement.get("clear", false)):
		return body
	return "!" + body


const REQUIREMENT_KINDS: Dictionary = {
	"item": "i", "engine_flag": "f", "event": "e", "toggle": "t", "badges": "b",
	"owned": "o", "special": "x",
}


## A `requires` entry: one of [constant REQUIREMENT_KINDS]' keys, `clear` when
## negated, or `{scene: [g, n, v]}`.
static func requirement_of(condition: String) -> Dictionary:
	var clear: bool = condition.begins_with("!")
	var body: String = condition.substr(1) if clear else condition
	var kind: String = body.get_slice(":", 0)
	var value: String = body.substr(kind.length() + 1)
	if kind == "s":
		var parts: PackedStringArray = value.replace("=", ":").split(":")
		return {"scene": [parts[0].to_int(), parts[1].to_int(), parts[2].to_int()]}
	var out: Dictionary = {}
	for key: String in REQUIREMENT_KINDS:
		if REQUIREMENT_KINDS[key] == kind:
			out[key] = value.to_int()
	if clear:
		out["clear"] = true
	return out


static func block(map: Vector2i, cell: Vector2i) -> String:
	return "c:%d:%d:%d:%d" % [map.x, map.y, cell.x, cell.y]


static func place(map: Vector2i, cell: Variant = null) -> Array:
	if cell is Vector2i:
		return [map.x, map.y, (cell as Vector2i).x, (cell as Vector2i).y]
	return [map.x, map.y]


func add_setter(sets: Array, requires: Array, at: Array) -> void:
	if sets.is_empty():
		return
	setters.append({"sets": sets, "requires": requires, "at": at})


## [param paths] marks one of many paths to one push. See [method merge_gates].
func add_gate(map: Vector2i, cells: Array, closing: Array, paths: bool = false) -> void:
	var stored: Array = []
	for cell: Vector2i in cells:
		stored.append([cell.x, cell.y])
	gates.append({"map": [map.x, map.y], "cells": stored, "closing": [closing], "paths": paths})


func add_wall(map: Vector2i, cell: Vector2i) -> void:
	var key: String = "%d:%d" % [map.x, map.y]
	var list: Array = walls.get(key, [])
	list.append([cell.x, cell.y])
	walls[key] = list


const STATIONARY: Array[int] = [
	Gen2WorldObject.MOVEMENT_STILL, Gen2WorldObject.MOVEMENT_SPINRANDOM_SLOW,
	Gen2WorldObject.MOVEMENT_FIXED_DOWN, Gen2WorldObject.MOVEMENT_FIXED_UP,
	Gen2WorldObject.MOVEMENT_FIXED_LEFT, Gen2WorldObject.MOVEMENT_FIXED_RIGHT,
	Gen2WorldObject.MOVEMENT_SPINRANDOM_FAST, Gen2WorldObject.MOVEMENT_POKEMON,
	Gen2WorldObject.MOVEMENT_SUDOWOODO, Gen2WorldObject.MOVEMENT_SPINCOUNTERCLOCKWISE,
	Gen2WorldObject.MOVEMENT_SPINCLOCKWISE,
]


## A person who never moves fills a cell: for good, or as a gate while the flag
## (Generation 1's toggle) that hides them says they are there.
func write_objects(data: GameData) -> void:
	var gen1: bool = data.generation == RomRegistry.GEN1
	for map: Gen2WorldMap in data.world_maps():
		var here := Vector2i(map.group, map.number)
		for object: Dictionary in map.events.get("objects", []) as Array:
			if not _stands(object, gen1):
				continue
			var cell := Vector2i(int(object.get("x", 0)), int(object.get("y", 0)))
			var closing: String = _shown_while(object, gen1)
			if closing.is_empty():
				add_wall(here, cell)
			else:
				add_gate(here, [cell], [closing])


static func _stands(object: Dictionary, gen1: bool) -> bool:
	if not int(object.get("movement", 0)) in STATIONARY:
		return false
	if gen1:
		return not object.has("item") and not object.has("trainer_class")
	return int(object.get("object_type", -1)) == Gen2WorldObject.OBJECTTYPE_SCRIPT \
		and int(object.get("hour_1", -1)) < 0


static func _shown_while(object: Dictionary, gen1: bool) -> String:
	if gen1:
		return "t:%d" % int(object["toggle_index"]) if object.has("toggle_index") else ""
	var flag: int = int(object.get("event_flag", -1))
	return "!e:%d" % flag if flag >= 0 else ""


## `ItemUsePokeFlute` sets the flag each Snorlax's map script wakes it on.
func write_gen1_flutes() -> void:
	for flute: Dictionary in Gen1Layout.SNORLAX_FLUTES:
		add_setter(["e:%d" % int(flute["fight"])], [
			"i:%d" % Gen1Layout.ITEM_POKE_FLUTE, "!e:%d" % int(flute["beat"]),
		], [[0, int(flute["map"])]])


## One gate per cell: the paths to one push close it on what they all share, and
## anything else standing there adds a list of its own.
func merge_gates() -> void:
	var by_cell: Dictionary = {}
	var paths: Dictionary = {}
	for gate: Dictionary in gates:
		var closing: Array = gate["closing"][0]
		for cell: Array in gate["cells"]:
			var name: String = "%s:%s" % [str(gate["map"]), str(cell)]
			if not by_cell.has(name):
				by_cell[name] = {"map": gate["map"], "cells": [cell], "closing": []}
			if not bool(gate["paths"]):
				(by_cell[name]["closing"] as Array).append(closing)
			elif paths.has(name):
				paths[name] = (paths[name] as Array).filter(func(c: String) -> bool: return closing.has(c))
			else:
				paths[name] = closing
	gates = []
	for name: String in by_cell:
		var closing: Array = (by_cell[name]["closing"] as Array).duplicate()
		closing.append(paths.get(name, []))
		by_cell[name]["closing"] = closing.filter(func(list: Array) -> bool: return not list.is_empty())
		if not (by_cell[name]["closing"] as Array).is_empty():
			gates.append(by_cell[name])
	_keep_guards(by_cell)


## A person who never moves is a wall only beside a gate, as the guard who fills
## the rest of its corridor: elsewhere a script walks the player past them.
func _keep_guards(by_cell: Dictionary) -> void:
	for key: String in walls.keys():
		var map: String = "[%s]" % key.replace(":", ", ")
		walls[key] = (walls[key] as Array).filter(func(cell: Array) -> bool:
			for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if by_cell.has("%s:%s" % [map, str([int(cell[0]) + step.x, int(cell[1]) + step.y])]):
					return true
			return false)
		if (walls[key] as Array).is_empty():
			walls.erase(key)


func to_dict() -> Dictionary:
	return {
		"setters": setters, "gates": gates, "walls": walls, "initial": initial, "links": links,
		"transient": transient,
	}


static func from_dict(source: Variant) -> Gen2WorldStory:
	var out := Gen2WorldStory.new()
	if not source is Dictionary:
		return out
	var raw: Dictionary = _ints(source)
	out.setters = raw.get("setters", [])
	out.gates = raw.get("gates", [])
	out.walls = raw.get("walls", {})
	out.initial = raw.get("initial", [])
	out.links = raw.get("links", [])
	out.transient = raw.get("transient", {})
	return out


static func _ints(value: Variant) -> Variant:
	if value is float:
		return int(value)
	if value is Array:
		var list: Array = []
		for entry: Variant in value as Array:
			list.append(_ints(entry))
		return list
	if value is Dictionary:
		var out: Dictionary = {}
		for key: Variant in value as Dictionary:
			out[key] = _ints((value as Dictionary)[key])
		return out
	return value
