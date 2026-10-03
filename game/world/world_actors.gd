class_name Gen2WorldActors
extends RefCounted

## The sprites a mod puts in the world: one `advance_frame` per world frame, one
## `sprites()` read per drawn one, in no snapshot. A mod names cartridge art; the
## strip, palette, rate and a step's walk are resolved here.

## Checked at registration, where the mod's name is still in hand.
const ACTOR_METHODS: Array[String] = ["set_world", "advance_frame", "sprites"]
## Optional, offered only to an actor that defines it. See [method interact].
const ACTOR_INTERACT_METHOD: String = "interact"
## Optional, drained once a world frame. See [method take_requests].
const ACTOR_REQUESTS_METHOD: String = "take_requests"

## constants/script_constants.asm's EMOTE_* order, which is
## [constant Gen2Layout.EMOTE_NAMES]' too. Named here so a mod asking for one over
## its own sprite names it rather than counting the array. The last four are the
## engine's own overlays rather than `showemote` arguments, and a mod naming one
## gets that sheet drawn where the bubble would be.
const EMOTE_NONE: int = -1
const EMOTE_SHOCK: int = 0
const EMOTE_QUESTION: int = 1
const EMOTE_HAPPY: int = 2
const EMOTE_SAD: int = 3
const EMOTE_HEART: int = 4
const EMOTE_BOLT: int = 5
const EMOTE_SLEEP: int = 6
const EMOTE_FISH: int = 7
const EMOTE_SHADOW: int = 8
const EMOTE_ROD: int = 9
const EMOTE_BOULDER_DUST: int = 10
const EMOTE_GRASS_RUSTLE: int = 11

const REQUEST_CRY: StringName = &"cry"
const REQUEST_BATTLE: StringName = &"battle"
const REQUEST_POKEMON_GIFT: StringName = &"pokemon_gift"
const REQUEST_CATCH_DEMO: StringName = &"catch_demo"
const REQUEST_TEXT: StringName = &"text"
const REQUEST_STEP: StringName = &"step"
const REQUEST_YES_NO: StringName = &"yes_no"
const ACTOR_REQUEST_COMPLETED_METHOD: String = "request_completed"
const REQUEST_KINDS: Array[StringName] = [
	REQUEST_CRY, REQUEST_BATTLE, REQUEST_POKEMON_GIFT, REQUEST_CATCH_DEMO, REQUEST_TEXT,
	REQUEST_STEP, REQUEST_YES_NO,
]
const MAX_QUEUED_STEPS: int = 8

## `.Frameset_PartyMon`: two OAM sets of eight, nine passes each because
## `GetSpriteAnimFrame` returns the entry on the pass that loads the duration
## too. An actor is not a party row, so no `SetPartyMonIconAnimSpeed` slowdown.
const ICON_FRAME_FRAMES: int = 9
const ICON_FRAMES: int = 2

var _actors: Array = []
## The visible-encounter population, drawn in the same pass. See
## [method set_encounters].
var _encounters: Gen2WorldEncounters = null
var _world: Gen2WorldAPI = null
## Held rather than re-read, so a mod's `sprites()` is asked once a frame however
## many times the screen redraws and two views agree.
var _sprites: Array = []
var _frame: int = 0
var _walks: Dictionary = {}


## [param actors] is [method Gen2ModHost.world_actors], in registration order,
## which is the order they are drawn in within one row.
func set_actors(actors: Array) -> void:
	_actors = actors
	_collect()


## The visible-encounter population, drawn through this layer so it sorts into
## the same rows as the actors.
func set_encounters(encounters: Gen2WorldEncounters) -> void:
	_encounters = encounters
	_collect()


func has_actors() -> bool:
	return not _actors.is_empty() or (_encounters != null and _encounters.active())


## The map changed, or the view was created.
func set_world(world: Gen2WorldAPI) -> void:
	_world = world
	for key: String in _walks.keys():
		_end_walk(key, &"map_changed")
	for actor: Object in _actors:
		actor.call("set_world", world)
	_collect()


## One world frame, spent after the player's step so an actor reading
## `player_step_offset_cells()` sees this frame. Answers whether anything moved.
func advance_frame() -> bool:
	if not has_actors():
		return false
	_frame += 1
	for actor: Object in _actors:
		actor.call("advance_frame")
	return refresh_pose()


## The pose again at the fraction the drawn frame stands at: [method
## advance_frame] is the hardware clock's and this is the panel's.
func refresh_pose() -> bool:
	if not has_actors():
		return false
	var before: Array = _sprites
	_collect()
	return _changed(before, _sprites)


## One map pass of every walking body. Answers whether anything moved.
func advance_steps() -> bool:
	if _walks.is_empty():
		return false
	for key: String in _walks.keys():
		var walk: Dictionary = _walks[key]
		var body: Gen2WorldObject = walk["body"]
		body.tick_step()
		if body.is_stepping():
			continue
		var queue: Array = walk["queue"]
		var landed: Dictionary = _step_result(walk, true)
		answer(walk["actor"], landed)
		if queue.is_empty() or not _start_step(key, queue.pop_front()):
			_walks.erase(key)
	return refresh_pose()


## A press of A [method Gen2WorldAPI.interact] left unanswered, offered in
## registration order; the first actor answering true consumes it.
func interact(cell: Vector2i, facing: int) -> bool:
	for actor: Object in _actors:
		if not actor.has_method(ACTOR_INTERACT_METHOD):
			continue
		if bool(actor.call(ACTOR_INTERACT_METHOD, cell, facing)):
			_collect()
			return true
	return false


## Each actor's one-shot outbox, validated against [constant REQUEST_KINDS] so
## the screen is handed only requests it can spend. A `step` is spent here.
func take_requests() -> Array:
	var out: Array = []
	for actor: Object in _actors:
		if not actor.has_method(ACTOR_REQUESTS_METHOD):
			continue
		var answered: Variant = actor.call(ACTOR_REQUESTS_METHOD)
		if not answered is Array:
			continue
		for entry: Variant in answered as Array:
			var request: Dictionary = _resolve_request(entry)
			if request.is_empty():
				continue
			request["actor"] = actor
			if request["kind"] == REQUEST_STEP:
				_request_step(request)
			else:
				out.append(request)
	return out


static func answer(actor: Object, result: Dictionary) -> void:
	if is_instance_valid(actor) and actor.has_method(ACTOR_REQUEST_COMPLETED_METHOD):
		actor.call(ACTOR_REQUEST_COMPLETED_METHOD, result.duplicate(true))


func _resolve_request(entry: Variant) -> Dictionary:
	if not entry is Dictionary:
		return {}
	var row: Dictionary = entry as Dictionary
	var kind := StringName(row.get("kind", &""))
	if not REQUEST_KINDS.has(kind):
		return {}
	var species: int = int(row.get("species", 0))
	if kind == REQUEST_CRY:
		# The record lookup is the real gate; this only keeps a zero out of it.
		if species <= 0:
			return {}
		return {"kind": kind, "species": species}
	if _world == null:
		return {}
	if kind == REQUEST_POKEMON_GIFT:
		return {
			"kind": kind, "species": species, "level": int(row.get("level", 0)),
			"tag": StringName(row.get("tag", &"")),
		}
	if kind == REQUEST_TEXT or kind == REQUEST_YES_NO:
		var text: String = _request_text(row.get("text", ""))
		if text.is_empty():
			return {}
		return {"kind": kind, "text": text, "tag": StringName(row.get("tag", &""))}
	if kind == REQUEST_STEP:
		var direction: Variant = row.get("direction", null)
		if direction is not Vector2i or not Gen2WorldEncounters.STEP_DIRECTIONS.has(direction):
			return {}
		return {
			"kind": kind, "id": StringName(row.get("id", &"")), "direction": direction,
			"tag": StringName(row.get("tag", &"")),
		}
	var named: Dictionary = Gen2WorldBattleAdapter.mod_wild(_world.data, row)
	if named.has("refused"):
		return {}
	var values: Dictionary = named["values"]
	values["kind"] = &"wild"
	values["mod_tag"] = StringName(row.get("tag", &""))
	if kind == REQUEST_CATCH_DEMO:
		values.merge(_catch_demo_values())
	return {"kind": kind, "values": values}


## A string, or an array of them each opening a new box as `para` does.
static func _request_text(raw: Variant) -> String:
	var pages: Array = raw if raw is Array else [raw]
	var kept: PackedStringArray = PackedStringArray()
	for page: Variant in pages:
		if page is not String or (page as String).strip_edges().is_empty():
			return ""
		if Gen2TextLayout.unfilled_marker(page as String) != "":
			return ""
		kept.append((page as String).strip_edges())
	return Gen2TextStream.PAGE_BREAK.join(kept)


## The Dude's `catchtutorial BATTLETYPE_TUTORIAL`, or Generation 1's old man.
func _catch_demo_values() -> Dictionary:
	if _world.data.generation == RomRegistry.GEN1:
		return Gen1Layout.battle_type_values(Gen1Layout.BATTLE_TYPE_OLD_MAN)
	return {"battle_type": Gen2Battle.BATTLETYPE_TUTORIAL, "tutorial": true, "can_lose": false}


func _body_key(actor: Object, id: StringName) -> String:
	return "%d/%s" % [actor.get_instance_id(), id]


func _request_step(request: Dictionary) -> void:
	var actor: Object = request["actor"]
	var key: String = _body_key(actor, StringName(request["id"]))
	if _walks.has(key):
		var queue: Array = _walks[key]["queue"]
		if queue.size() < MAX_QUEUED_STEPS:
			queue.append(request)
		else:
			answer(actor, _refusal(request, &"step_queue_full"))
		return
	var stand: Dictionary = _standing_entry(actor, StringName(request["id"]))
	if stand.is_empty():
		answer(actor, _refusal(request, &"unknown_id"))
		return
	## A map object no map holds, walked as one is.
	var body := Gen2WorldObject.new()
	body.movement = Gen2WorldObject.MOVEMENT_SCRIPTED
	body.active = true
	body.cell = Vector2i((stand["position_cells"] as Vector2).round())
	body.facing = int(stand["facing"])
	_walks[key] = {"body": body, "actor": actor, "id": request["id"], "queue": []}
	if not _start_step(key, request):
		_walks.erase(key)


## `InitStep` turns the body before [method Gen2WorldAPI.can_object_walk_to] asks.
func _start_step(key: String, request: Dictionary) -> bool:
	var walk: Dictionary = _walks[key]
	var body: Gen2WorldObject = walk["body"]
	var direction: Vector2i = request["direction"]
	walk["tag"] = request["tag"]
	body.apply_direction(direction)
	var destination: Vector2i = body.cell + direction
	if _world == null or not _world.can_object_walk_to(destination, body, direction):
		answer(walk["actor"], _step_result(walk, false))
		return false
	body.cell = destination
	body.start_step(direction, Gen2WorldAPI.STEP_PASSES_NPC_WALK)
	_collect()
	return true


func _end_walk(key: String, reason: StringName) -> void:
	var walk: Dictionary = _walks[key]
	_walks.erase(key)
	var result: Dictionary = _step_result(walk, false)
	result["reason"] = reason
	answer(walk["actor"], result)
	for queued: Dictionary in walk["queue"]:
		answer(walk["actor"], _refusal(queued, reason))


func _step_result(walk: Dictionary, ok: bool) -> Dictionary:
	var body: Gen2WorldObject = walk["body"]
	var result: Dictionary = {
		"ok": ok, "kind": REQUEST_STEP, "id": walk["id"], "tag": walk.get("tag", &""),
		"cell": body.cell, "facing": body.facing,
	}
	if not ok:
		result["reason"] = &"blocked"
	return result


static func _refusal(request: Dictionary, reason: StringName) -> Dictionary:
	return {
		"ok": false, "kind": REQUEST_STEP, "reason": reason, "id": request["id"],
		"tag": request["tag"],
	}


func _standing_entry(actor: Object, id: StringName) -> Dictionary:
	if id.is_empty():
		return {}
	var order: int = _actors.find(actor)
	for sprite: Dictionary in _sprites:
		if int(sprite["order"]) == order and sprite["id"] == id:
			return sprite
	return {}


## { sprite, facing, frame, position_cells, span, height_offset_pixels, colors,
## emote }, sorted by the row stood on and then by registration order, the way
## the map's own objects are. `colors` is empty but for a visible encounter, and
## `emote` is [constant EMOTE_NONE] unless one was asked for.
func sprites() -> Array:
	return _sprites


func _collect() -> void:
	_sprites = []
	if _world == null or _world.data == null:
		return
	for index: int in _actors.size():
		for entry: Variant in _actors[index].call("sprites"):
			var resolved: Dictionary = _resolve(entry, index)
			if not resolved.is_empty():
				_sprites.append(resolved)
	var solid: Array[Vector2i] = []
	for sprite: Dictionary in _sprites:
		if not sprite["solid"]:
			continue
		var walk: Variant = _walks.get(_body_key(_actors[sprite["order"]], sprite["id"]))
		if walk is Dictionary:
			## `IsNPCAtCoord` compares both the cell a step leaves and the one it takes.
			var body: Gen2WorldObject = (walk as Dictionary)["body"]
			solid.append_array([body.cell, body.vacating_cell()])
		else:
			solid.append(Vector2i((sprite["position_cells"] as Vector2).round()))
	_world.set_actor_cells(solid)
	if _encounters != null:
		for entry: Variant in _encounters.actor_entries():
			var resolved: Dictionary = _resolve(entry, _actors.size())
			if not resolved.is_empty():
				_sprites.append(resolved)
	_sprites.sort_custom(_sort)


## One entry of a mod's answer. Art the cache does not carry is dropped rather
## than drawn as a placeholder.
func _resolve(entry: Variant, order: int) -> Dictionary:
	if not entry is Dictionary:
		return {}
	var row: Dictionary = entry as Dictionary
	var sprite: Gen2WorldSprite = null
	if row.has("icon"):
		sprite = _world.data.overworld_icon(int(row["icon"]))
		if sprite != null:
			# A map object's icon never animates: `GetUsedSprite` copies its
			# eight tiles into both VRAM halves, so `Facings`' walking rows
			# land on the same picture. An actor asks for both frames.
			sprite.animate_icon_frames = true
	elif row.has("sprite"):
		sprite = _world.data.overworld_sprite(int(row["sprite"]))
	if sprite == null:
		return {}
	var facing: int = clampi(
		int(row.get("facing", Gen2WorldSprite.FACING_DOWN)),
		Gen2WorldSprite.FACING_DOWN, Gen2WorldSprite.FACING_RIGHT
	)
	var id := StringName(row.get("id", &""))
	var position := Vector2(row.get("position_cells", Vector2.ZERO))
	var frame: int = _frame_for(sprite, row)
	var span: Dictionary = _resolved_span(row)
	var walk: Variant = _walks.get(_body_key(_actors[order], id)) \
		if order < _actors.size() and not id.is_empty() else null
	if walk is Dictionary:
		var body: Gen2WorldObject = (walk as Dictionary)["body"]
		var fraction: float = _world.pass_fraction
		position = Vector2(body.cell) + body.step_offset_cells(fraction)
		span = body.step_span(fraction)
		facing = body.drawn_facing()
		if sprite.sprite_type != Gen2WorldSprite.TYPE_MON_ICON:
			frame = body.frame
	return {
		"sprite": sprite,
		"facing": facing,
		"frame": frame,
		"position_cells": position,
		"order": order,
		"id": id,
		# An overworld sprite wears one of the map's own sprite palettes. A
		# visible encounter wears the SPECIES' four colours instead, which is the
		# only way a shiny one is a shiny one before the battle starts. A view
		# that does not read this draws the ordinary palette and is not wrong.
		"colors": row.get("colors", PackedColorArray()),
		# `step_span`'s own shape, or empty: a fractional cell cuts across a fold.
		"span": span,
		# The hop's second axis, so a view that folds plan into height stands a
		# card on the arc rather than on the ground under it.
		"height_offset_pixels": _span_height_offset_pixels(span),
		# `SpawnEmote`'s bubble, two rows above the sprite. State rather than an
		# edge: it is up for as long as the entry keeps asking, so the mod owns
		# the duration and the host owns the pixels.
		"emote": _resolve_emote(row),
		"solid": bool(row.get("solid", false)),
	}


## A span missing an end is no span rather than a wrong one.
static func _resolved_span(row: Dictionary) -> Dictionary:
	var span: Variant = row.get("span", null)
	if span is not Dictionary:
		return {}
	var entry: Dictionary = span
	if not entry.has("from") or not entry.has("to"):
		return {}
	return {
		"from": Vector2i(entry["from"]),
		"to": Vector2i(entry["to"]),
		"progress": clampf(float(entry.get("progress", 0.0)), 0.0, 1.0),
		"kind": StringName(entry.get("kind", &"step")),
	}


## [method Gen2WorldObject.height_offset_pixels] for an actor, off the span it
## already carries: zero unless its kind is a hop.
static func _span_height_offset_pixels(span: Dictionary) -> float:
	if not Gen2WorldAPI.JUMP_STEP_KINDS.has(span.get("kind", &"")):
		return 0.0
	return float(-Gen2WorldAPI.jump_offset_for(float(span["progress"])))


## An out-of-range index is no emote rather than a wrong sheet, the way art the
## cache does not carry is dropped rather than drawn as a placeholder.
func _resolve_emote(row: Dictionary) -> int:
	var emote: int = int(row.get("emote", EMOTE_NONE))
	if emote < 0 or emote >= Gen2Layout.EMOTE_NAMES.size():
		return EMOTE_NONE
	return emote


## `.Frameset_PartyMon`'s rate for an icon, or [method Gen2WorldObject.walk_frame]'s.
func _frame_for(sprite: Gen2WorldSprite, row: Dictionary) -> int:
	if sprite.sprite_type != Gen2WorldSprite.TYPE_MON_ICON:
		return clampi(int(row.get("frame", 0)), 0, 3)
	@warning_ignore("integer_division")
	# Frame 1 is `Gen2WorldSprite.is_walking_frame`'s, which reads the strip's
	# second half.
	var step: int = (_frame / ICON_FRAME_FRAMES) % ICON_FRAMES
	return step


func _sort(first: Dictionary, second: Dictionary) -> bool:
	var first_y: float = (first["position_cells"] as Vector2).y
	var second_y: float = (second["position_cells"] as Vector2).y
	if is_equal_approx(first_y, second_y):
		return int(first["order"]) < int(second["order"])
	return first_y < second_y


func _changed(before: Array, after: Array) -> bool:
	if before.size() != after.size():
		return true
	for index: int in before.size():
		var was: Dictionary = before[index]
		var now: Dictionary = after[index]
		if was["position_cells"] != now["position_cells"] \
			or was["span"] != now["span"] \
			or int(was["facing"]) != int(now["facing"]) \
			or int(was["frame"]) != int(now["frame"]) \
			or int(was["emote"]) != int(now["emote"]) \
			or (was["sprite"] as Gen2WorldSprite).number \
				!= (now["sprite"] as Gen2WorldSprite).number:
			return true
	return false
