class_name Gen2WorldProgression
extends RefCounted

## Whether a proposed placement can still be finished: one closure over the
## [Gen2WorldCatalog], its [Gen2WorldStory] and the regions of
## [Gen2WorldReachability]. A check or a story script counts once its place is
## reached and its conditions hold, what it sets holds from then on, and a gate
## opens once a condition closing it flips. Answers with the first critical
## check that never became reachable.

const REASON_UNREACHABLE: StringName = &"unreachable_check"
const REASON_NO_CATALOG: StringName = &"missing_catalog"

const MAX_ROUNDS: int = 512
## The change every badge raises, which flags, counts and HM badges wait on.
const BADGE_KEY: String = "#badge"

## `Gen2WorldSpawn`'s new-game map; Generation 1's is `NewGameWarp`'s row.
const START_MAP := Vector2i(Gen2WorldSpawn.NEW_BARK_GROUP, Gen2WorldSpawn.PLAYERS_HOUSE_2F)


static func start_map(data: GameData) -> Vector2i:
	if data.generation == RomRegistry.GEN1:
		return Vector2i(0, int(data.gen1_new_game_warp().get("map", 0)))
	return START_MAP


## Where a new game stands, as a [Gen2WorldStory] place.
static func start_place(data: GameData) -> Array:
	if data.generation == RomRegistry.GEN1:
		var warp: Dictionary = data.gen1_new_game_warp()
		return [0, int(warp.get("map", 0)), int(warp.get("x", 0)), int(warp.get("y", 0))]
	return Gen2WorldStory.place(START_MAP, Gen2WorldSpawn.HOME_CELL)


## Cache directory to the scratch cache, overlay, catalog, graph and plan.
static var _scratch: Dictionary = {}


## Drops the scratch caches. For a test that rewrote a cache under the same path.
static func reset() -> void:
	_scratch.clear()


## Validates [param patches], check id to the fields a mod proposes, WITHOUT
## installing them: rows resolve through an overlay of this call's own. Answers
## `{ok, reached, critical, missing: {check, requirement, kind}}`, deterministic.
static func validate(data: GameData, patches: Dictionary = {}) -> Dictionary:
	if data == null:
		return {"ok": false, "reason": REASON_NO_CATALOG, "reached": 0, "critical": 0}
	## Built once per cartridge: only the overlay changes between seeds.
	if not _scratch.has(data.directory):
		var opened: GameData = GameData.open_directory(data.directory)
		if opened == null:
			return {"ok": false, "reason": REASON_NO_CATALOG, "reached": 0, "critical": 0}
		var fresh := Gen2ContentOverlay.new()
		opened.set_content_overlay(fresh)
		var catalog: Gen2WorldCatalog = opened.catalog()
		_scratch[data.directory] = {
			"overlay": fresh, "catalog": catalog, "start": start_place(opened),
			"walk": Gen2WorldReachability.build(opened, catalog.story()),
			"plan": _plan(catalog),
		}
	var held: Dictionary = _scratch[data.directory]
	var overlay: Gen2ContentOverlay = held["overlay"]
	overlay.clear_owner(&"progression")
	var ids: Array = patches.keys()
	ids.sort()
	for id: Variant in ids:
		overlay.patch(
			Gen2ContentOverlay.KIND_CHECK, &"progression", int(id), patches[id]
		)
	return _answer(_run(held["catalog"], held["walk"], held["plan"], held["start"]))


## What no placement changes: rows' places and conditions, the setters read,
## what can be set at all, the new game's facts, the gates each change opens.
static func _plan(catalog: Gen2WorldCatalog) -> Dictionary:
	var story: Gen2WorldStory = catalog.story()
	var rows: Dictionary = {}
	var read: Dictionary = {}
	for row: Dictionary in catalog.rows():
		var conds: Array = []
		for requirement: Variant in row.get("requires", []):
			var condition: String = Gen2WorldStory.condition_of(requirement)
			if not condition.is_empty():
				conds.append(condition)
				read[condition] = true
		var place: Array = _place_of(row)
		rows[int(row["id"])] = {"conds": conds, "place": place, "key": str(place)}
	var gate_index: Dictionary = {}
	for index: int in story.gates.size():
		for list: Array in story.gates[index]["closing"]:
			for condition: String in list:
				read[_flip_key(condition)] = true
				_index(gate_index, _flip_key(condition), index)
				_index(gate_index, BADGE_KEY, index)
	for link: Dictionary in story.links:
		for condition: String in link["requires"]:
			read[condition] = true
	var initial: Dictionary = {}
	for fact: String in story.initial:
		initial[fact] = true
	var setters: Array = _setters_read(story, read)
	var settable: Dictionary = {}
	for setter: Dictionary in setters:
		for fact: String in setter["sets"]:
			settable[fact] = true
	return {
		"rows": rows, "setters": setters, "settable": settable, "initial": initial,
		"gates": story.gates, "items": catalog.item_sources(), "links": story.links,
		"gate_index": gate_index, "badge_of": {}, "moves_of": {}, "transient": story.transient,
	}


## The change that can flip [param condition]: its negation, or any scene.
static func _flip_key(condition: String) -> String:
	return condition.get_slice("=", 0) if condition.begins_with("s:") \
		else Gen2WorldStory.negate(condition)


static func _index(index: Dictionary, key: String, value: int) -> void:
	var list: Array = index.get(key, [])
	if not list.has(value):
		list.append(value)
	index[key] = list


static func _place_of(row: Dictionary) -> Array:
	if not row.has("map"):
		return []
	var map: Vector2i = row["map"]
	return Gen2WorldStory.place(map, row.get("cell", null))


## The setters some condition reads, their own conditions read in turn.
static func _setters_read(story: Gen2WorldStory, read: Dictionary) -> Array:
	var kept: Dictionary = {}
	var grew: bool = true
	while grew:
		grew = false
		for index: int in story.setters.size():
			if kept.has(index) or not _read_any(story.setters[index]["sets"], read):
				continue
			kept[index] = true
			grew = true
			for condition: String in story.setters[index]["requires"]:
				read[condition] = true
	var out: Array = []
	for index: int in story.setters.size():
		if kept.has(index):
			out.append(story.setters[index])
	return out


static func _read_any(sets: Array, read: Dictionary) -> bool:
	for fact: String in sets:
		if read.has(fact) or read.has(fact.get_slice("=", 0)):
			return true
	return false


## The closure, answering with its final state. A task, a row or a setter,
## waits for its place, then on its first condition that does not hold.
static func _run(
	catalog: Gen2WorldCatalog, walk: Gen2WorldReachability, plan: Dictionary, start: Array
) -> Dictionary:
	var rows: Array = catalog.rows()
	rows.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return int(first["id"]) < int(second["id"])
	)
	var state: Dictionary = {
		"catalog": catalog, "plan": plan, "items": {}, "badges": {},
		"facts": (plan["initial"] as Dictionary).duplicate(), "scenes": {},
		"walk": walk, "start": start, "moves": {}, "open": {}, "graph_id": 0,
		"changed": {}, "blocked": {}, "waiting": _tasks(plan, rows), "reached_rows": {},
		"rows": rows, "fresh": [], "by_node": {}, "new_items": [], "teaching": [], "usable": {},
	}
	_reflood(state)
	var closed: Dictionary = _closed_at_start(state)
	var links: Array = range((plan["links"] as Array).size())
	var changed: Variant = null
	for _round: int in MAX_ROUNDS:
		_open_gates(state, closed, changed)
		_open_links(state, links)
		if changed == null or (changed as Dictionary).has(BADGE_KEY) or not (state["new_items"] as Array).is_empty():
			_refresh_moves(state)
		if changed != null:
			_unblock(state, changed)
		var grew: bool = not (state["fresh"] as Array).is_empty()
		_place_fresh(state)
		changed = state["changed"]
		state["changed"] = {}
		if not (changed as Dictionary).is_empty() or grew:
			continue
		## A new move set's graph is taken once nothing else moves.
		if state["usable"] == state["moves"]:
			break
		state["moves"] = state["usable"]
		_reflood(state)
	return state


## One task per row, and one per place a setter stands at.
static func _tasks(plan: Dictionary, rows: Array) -> Array:
	var out: Array = []
	for row: Dictionary in rows:
		var fixed: Dictionary = (plan["rows"] as Dictionary).get(int(row["id"]), {})
		out.append({
			"conds": fixed.get("conds", []), "place": fixed.get("place", []),
			"key": fixed.get("key", ""), "row": row,
		})
	for setter: Dictionary in plan["setters"]:
		var at: Array = setter["at"] if not (setter["at"] as Array).is_empty() else [[]]
		for place: Array in at:
			out.append({"conds": setter["requires"], "setter": setter, "place": place, "key": str(place)})
	return out


## The first critical check never reached, as `missing`.
static func _answer(state: Dictionary) -> Dictionary:
	var catalog: Gen2WorldCatalog = state["catalog"]
	var reached: Dictionary = state["reached_rows"]
	var critical: Array = (state["rows"] as Array).filter(func(row: Dictionary) -> bool:
		return catalog.is_progression(row))
	for row: Dictionary in critical:
		if not reached.has(int(row["id"])):
			return {
				"ok": false, "reason": REASON_UNREACHABLE,
				"reached": reached.size(), "critical": critical.size(),
				"missing": {
					"check": int(row["id"]), "kind": StringName(row["kind"]),
					"requirement": _blocker(state, row),
				},
			}
	return {"ok": true, "reached": reached.size(), "critical": critical.size(), "missing": {}}


static func _reflood(state: Dictionary) -> void:
	var walk: Gen2WorldReachability = state["walk"]
	var built: Dictionary = walk.graph(state["moves"])
	var reached := PackedByteArray()
	reached.resize(int(built["count"]))
	Gen2WorldReachability.spread(
		built, reached, Array(walk.place_nodes(built, state["start"])), state["open"], state["fresh"]
	)
	state["graph"] = built
	state["reached"] = reached
	state["graph_id"] = int(state["graph_id"]) + 1
	state["replace"] = true


## The gates closed at a new game, with their lists holding then; a list that
## does not hold then stays open.
static func _closed_at_start(state: Dictionary) -> Dictionary:
	var closed: Dictionary = {}
	var gates: Array = state["plan"]["gates"]
	for index: int in gates.size():
		var lists: Array = []
		for list: Array in gates[index]["closing"]:
			if _all_hold_at_start(state, list):
				lists.append(list)
		if not lists.is_empty():
			closed[index] = lists
		else:
			Gen2WorldReachability.open_gate(state["graph"], state["reached"], index, state["open"], state["fresh"])
	return closed


static func _all_hold_at_start(state: Dictionary, list: Array) -> bool:
	for condition: String in list:
		if not _holds_at_start(state, condition):
			return false
	return true


static func _holds_at_start(state: Dictionary, condition: String) -> bool:
	var initial: Dictionary = state["plan"]["initial"]
	if condition.begins_with("s:"):
		return initial.has(condition) or condition.ends_with("=0")
	if condition.begins_with("!"):
		return not initial.has(condition.substr(1))
	if condition.begins_with("b:") or (condition.begins_with("f:") and _badge_of_flag(state, condition) >= 0):
		return false
	return initial.has(condition)


## Opens each closed gate [param changed] can reach (all at first) whose every
## list flipped.
static func _open_gates(state: Dictionary, closed: Dictionary, changed: Variant) -> void:
	var candidates: Array = closed.keys()
	if changed != null:
		var index: Dictionary = state["plan"]["gate_index"]
		var asked: Dictionary = {}
		for key: String in changed:
			for gate: int in index.get(key, []):
				asked[gate] = true
		candidates = asked.keys().filter(func(gate: int) -> bool: return closed.has(gate))
	for gate: int in candidates:
		var lists: Array = []
		for list: Array in closed[gate]:
			if not _any_flipped(state, list):
				lists.append(list)
		closed[gate] = lists
		if lists.is_empty():
			closed.erase(gate)
			Gen2WorldReachability.open_gate(state["graph"], state["reached"], gate, state["open"], state["fresh"])


static func _any_flipped(state: Dictionary, list: Array) -> bool:
	for condition: String in list:
		if _flipped(state, condition):
			return true
	return false


static func _open_links(state: Dictionary, pending: Array) -> void:
	var base: int = (state["plan"]["gates"] as Array).size()
	var left: Array = []
	for index: int in pending:
		if _first_unmet(state, state["plan"]["links"][index]["requires"]).is_empty():
			Gen2WorldReachability.open_gate(
				state["graph"], state["reached"], base + index, state["open"], state["fresh"]
			)
		else:
			left.append(index)
	pending.assign(left)


## Whether a closing condition no longer holds: its negation holds, or the
## map's scene moved off it to other than the push's own step.
static func _flipped(state: Dictionary, condition: String) -> bool:
	if condition.begins_with("s:"):
		var map: String = condition.get_slice("=", 0)
		var transient: Dictionary = state["plan"]["transient"]
		for value: Variant in (state["scenes"] as Dictionary).get(map, {}):
			var fact: String = map + "=" + str(value)
			if fact != condition and not transient.has(fact):
				return true
		return false
	if condition.begins_with("i:"):
		return false
	return _holds(state, Gen2WorldStory.negate(condition))


## Whether [param condition] can hold: a fact set or one no script sets (the
## engine's own), an item in hand or on no check, a badge for its flag.
static func _holds(state: Dictionary, condition: String) -> bool:
	var plan: Dictionary = state["plan"]
	if condition.begins_with("i:"):
		var item: int = condition.substr(2).to_int()
		return (state["items"] as Dictionary).has(item) or not (plan["items"] as Dictionary).has(item)
	if condition.begins_with("!i:") or condition.begins_with("!b:"):
		return true
	if condition.begins_with("b:"):
		return (state["badges"] as Dictionary).size() >= condition.substr(2).to_int()
	if condition.begins_with("f:") and _badge_of_flag(state, condition) >= 0:
		return (state["badges"] as Dictionary).has(_badge_of_flag(state, condition))
	if (state["facts"] as Dictionary).has(condition) or not (plan["settable"] as Dictionary).has(condition):
		return true
	if condition.begins_with("!"):
		return not (plan["initial"] as Dictionary).has(condition.substr(1))
	return condition.begins_with("s:") and condition.ends_with("=0")


static func _badge_of_flag(state: Dictionary, condition: String) -> int:
	var flag: int = condition.trim_prefix("!").substr(2).to_int()
	var known: Dictionary = state["plan"]["badge_of"]
	if not known.has(flag):
		known[flag] = (state["catalog"] as Gen2WorldCatalog).badge_for_engine_flag(flag)
	return int(known[flag])


## The change the first unmet condition waits on, or empty when all hold.
static func _first_unmet(state: Dictionary, conds: Array) -> String:
	var catalog: Gen2WorldCatalog = state["catalog"]
	for condition: String in conds:
		if not _holds(state, condition):
			return BADGE_KEY if condition.begins_with("b:") or condition.begins_with("f:") else condition
		if condition.begins_with("i:"):
			var badge: int = catalog.badge_for_hm_item(condition.substr(2).to_int())
			if badge >= 0 and not (state["badges"] as Dictionary).has(badge):
				return BADGE_KEY
	return ""


static func _placed(state: Dictionary, task: Dictionary) -> bool:
	var place: Array = task.get("place", [])
	if place.is_empty():
		return true
	if int(task.get("graph", -1)) != int(state["graph_id"]):
		task["nodes"] = (state["walk"] as Gen2WorldReachability).place_nodes(
			state["graph"], place, task["key"]
		)
		task["graph"] = state["graph_id"]
	var reached: PackedByteArray = state["reached"]
	for node: int in task["nodes"]:
		if reached[node] != 0:
			return true
	return false


## Asks the tasks waiting on nodes newly reached; after a new graph, all.
static func _place_fresh(state: Dictionary) -> void:
	var fresh: Array = state["fresh"]
	state["fresh"] = []
	if bool(state.get("replace", false)):
		state["replace"] = false
		state["by_node"] = {}
		var waiting: Array = state["waiting"]
		state["waiting"] = []
		for task: Dictionary in waiting:
			if not bool(task.get("placed", false)):
				_place(state, task)
		return
	var by_node: Dictionary = state["by_node"]
	for node: int in fresh:
		if by_node.has(node):
			var tasks: Array = by_node[node]
			by_node.erase(node)
			for task: Dictionary in tasks:
				if not bool(task.get("placed", false)):
					_place(state, task)


static func _place(state: Dictionary, task: Dictionary) -> void:
	if _placed(state, task):
		task["placed"] = true
		_try(state, task)
		return
	(state["waiting"] as Array).append(task)
	for node: int in task["nodes"]:
		var list: Array = (state["by_node"] as Dictionary).get(node, [])
		list.append(task)
		state["by_node"][node] = list


static func _unblock(state: Dictionary, changed: Dictionary) -> void:
	var blocked: Dictionary = state["blocked"]
	for key: String in changed:
		if blocked.has(key):
			var tasks: Array = blocked[key]
			blocked.erase(key)
			for task: Dictionary in tasks:
				_try(state, task)


static func _try(state: Dictionary, task: Dictionary) -> void:
	var unmet: String = _first_unmet(state, task["conds"])
	if not unmet.is_empty():
		var list: Array = (state["blocked"] as Dictionary).get(unmet, [])
		list.append(task)
		state["blocked"][unmet] = list
		return
	if task.has("row"):
		_take_row(state, task["row"])
	else:
		_apply_setter(state, task["setter"])


static func _take_row(state: Dictionary, row: Dictionary) -> void:
	state["reached_rows"][int(row["id"])] = true
	## What the check hands over is in hand from now on.
	if row.has("item") and int(row["item"]) > 0:
		state["items"][int(row["item"])] = true
		state["changed"]["i:%d" % int(row["item"])] = true
		(state["new_items"] as Array).append(int(row["item"]))
	if StringName(row["kind"]) == Gen2WorldCatalog.KIND_BADGE:
		state["badges"][int(row["badge"])] = true
		state["changed"][BADGE_KEY] = true


static func _apply_setter(state: Dictionary, setter: Dictionary) -> void:
	for fact: String in setter["sets"]:
		if (state["facts"] as Dictionary).has(fact):
			continue
		state["facts"][fact] = true
		state["changed"][fact] = true
		if fact.begins_with("s:"):
			var map: String = fact.get_slice("=", 0)
			var scenes: Dictionary = (state["scenes"] as Dictionary).get(map, {})
			scenes[fact.get_slice("=", 1).to_int()] = true
			state["scenes"][map] = scenes
			state["changed"][map] = true


## The first unmet condition as a requirement, an HM bringing its badge.
static func _met(state: Dictionary, conds: Array) -> Dictionary:
	var catalog: Gen2WorldCatalog = state["catalog"]
	for condition: String in conds:
		if not _holds(state, condition):
			if condition.begins_with("f:") and _badge_of_flag(state, condition) >= 0:
				return {"badge": _badge_of_flag(state, condition)}
			return Gen2WorldStory.requirement_of(condition)
		if condition.begins_with("i:"):
			var item: int = condition.substr(2).to_int()
			var badge: int = catalog.badge_for_hm_item(item)
			if badge >= 0 and not (state["badges"] as Dictionary).has(badge):
				return {"badge": badge, "for_item": item}
	return {}


static func _blocker(state: Dictionary, row: Dictionary) -> Dictionary:
	var fixed: Dictionary = (state["plan"]["rows"] as Dictionary).get(int(row["id"]), {})
	var task: Dictionary = {"place": fixed.get("place", []), "key": fixed.get("key", "")}
	if not _placed(state, task):
		return {"map": row["map"]}
	return _met(state, fixed.get("conds", []))


## The field moves in use: a TM or HM in the bag and its badge, if any.
static func _refresh_moves(state: Dictionary) -> void:
	var catalog: Gen2WorldCatalog = state["catalog"]
	var known: Dictionary = state["plan"]["moves_of"]
	var teaching: Array = state["teaching"]
	for item: int in state["new_items"]:
		if not known.has(item):
			var move: int = catalog.field_move_for_item(item)
			known[item] = [move, catalog.badge_for_move(move) if move > 0 else -1]
		if int(known[item][0]) > 0:
			teaching.append(known[item])
	(state["new_items"] as Array).clear()
	var usable: Dictionary = {}
	for pair: Array in teaching:
		if int(pair[1]) < 0 or (state["badges"] as Dictionary).has(int(pair[1])):
			usable[int(pair[0])] = true
	state["usable"] = usable
