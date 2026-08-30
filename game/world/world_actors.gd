class_name Gen2WorldActors
extends RefCounted

## The sprites a mod puts in the world, driven and resolved by the host: a mod
## wanting a follower or a marker registers an actor rather than a whole renderer,
## and the screen drives it with one `advance_frame` per world frame and a
## `sprites()` read per DRAWN one. PRESENTATION and nothing else: an actor's sprite
## occupies no cell, blocks nothing, is talked to by nobody, is seen by no trainer
## and is in no snapshot, which is why it is a layer of its own rather than a map
## object. A mod names cartridge art and never composes pixels, the strip, palette
## and animation rate being resolved here.

## Checked at registration, where the mod's name is still in hand.
const ACTOR_METHODS: Array[String] = ["set_world", "advance_frame", "sprites"]
## Optional, offered only to an actor that defines it. See [method interact].
const ACTOR_INTERACT_METHOD: String = "interact"
## Optional, drained once a world frame. See [method take_requests].
const ACTOR_REQUESTS_METHOD: String = "take_requests"

## constants/script_constants.asm's EMOTE_* order, which is
## [constant RomLayout.EMOTE_NAMES]' too. Named here so a mod asking for one over
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

## The kinds [method take_requests] passes on. Anything else a mod puts in its
## outbox is dropped here rather than reaching the screen.
const REQUEST_CRY: StringName = &"cry"
const REQUEST_KINDS: Array[StringName] = [REQUEST_CRY]

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


## [param actors] is [method Gen2ModHost.world_actors], in registration order,
## which is the order they are drawn in within one row.
func set_actors(actors: Array) -> void:
	_actors = actors
	_collect()


## The host's own visible-encounter layer, whose population is drawn through this
## one so a wild standing on the map sorts into the same rows and reaches both
## views. What it IS is not presentation and lives in [Gen2WorldEncounters]; what
## it looks like is one more sprite here.
func set_encounters(encounters: Gen2WorldEncounters) -> void:
	_encounters = encounters
	_collect()


func has_actors() -> bool:
	return not _actors.is_empty() or (_encounters != null and _encounters.active())


## The map changed, or the view was created.
func set_world(world: Gen2WorldAPI) -> void:
	_world = world
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


## A press of A that no cartridge object, background event or tile branch
## answered, offered to the actors in registration order; the first answering true
## consumes it. [param cell] is the player's faced cell and [param facing] their
## own, so an actor tests its own pose and the host invents no occupancy for a
## sprite that occupies nothing. Offered ONLY after
## [method Gen2WorldAPI.interact] answered nothing, so nothing is shadowed.
func interact(cell: Vector2i, facing: int) -> bool:
	for actor: Object in _actors:
		if not actor.has_method(ACTOR_INTERACT_METHOD):
			continue
		if bool(actor.call(ACTOR_INTERACT_METHOD, cell, facing)):
			## The press is spent, so what the actor changed about its own pose
			## is on screen this frame rather than on the next advance.
			_collect()
			return true
	return false


## An actor's one-shot outbox, drained once a world frame and emptied by the
## drain. A pose belongs in [method sprites], which is a read; an edge belongs
## here, asked for once and spent once.
##
## Every entry is validated against [constant REQUEST_KINDS] here, so the screen
## is handed requests it can spend rather than whatever a mod wrote.
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
			if not request.is_empty():
				out.append(request)
	return out


func _resolve_request(entry: Variant) -> Dictionary:
	if not entry is Dictionary:
		return {}
	var row: Dictionary = entry as Dictionary
	var kind := StringName(row.get("kind", &""))
	if not REQUEST_KINDS.has(kind):
		return {}
	if kind == REQUEST_CRY:
		var species: int = int(row.get("species", 0))
		# The record lookup is the real gate; this only keeps a zero out of it.
		if species <= 0:
			return {}
		return {"kind": kind, "species": species}
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
	var span: Dictionary = _resolved_span(row)
	return {
		"sprite": sprite,
		"facing": facing,
		"frame": _frame_for(sprite),
		"position_cells": Vector2(row.get("position_cells", Vector2.ZERO)),
		"order": order,
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
	if emote < 0 or emote >= RomLayout.EMOTE_NAMES.size():
		return EMOTE_NONE
	return emote


## A mon icon steps through its two at `.Frameset_PartyMon`'s rate; anything else
## stands, since `Facings`' walking rows belong to a step this layer never takes.
func _frame_for(sprite: Gen2WorldSprite) -> int:
	if sprite.sprite_type != Gen2WorldSprite.TYPE_MON_ICON:
		return 0
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
