extends RefCounted

var _r: RefCounted = null

## Verifies `wVariableSprites` against freshly imported real caches for both
## command profiles: every object either wears a row the source wrote or is
## drawn as the player, and the table survives a save the way `wPlayerData` does.
##
## Expected values come from the pinned pokecrystal and pokegold sources:
## engine/overworld/overworld.asm's `GetMonSprite`, engine/events/std_scripts.asm's
## `InitializeEventsScript`, engine/overworld/decorations.asm's
## `ToggleDecorationsVisibility`, ram/wram.asm and engine/menus/save.asm.
##
## Two findings carry the topic. `wVariableSprites` sits inside `wPlayerData`,
## which `SaveData` copies whole into `sPlayerData`, so a row assigned in one
## session is still there in the next; keeping the table on the loaded world
## instead drew nine slots' worth of people as the player on every reload, which
## is what Route 40's swimmers reported. And a slot with no row at all is
## `.NoBreedmon`'s `WALKING_SPRITE`, which is `SPRITE_CHRIS` by coincidence of
## two constant lists, so the fallback is a symptom rather than a feature: the
## nineteen slot-carrying objects in either corpus all have a row.
##
##   Godot --headless --path . -s res://tools/validate.gd -- variable_sprites

## constants/sprite_constants.asm, the same numbers on all three cartridges.
const SPRITE_CHRIS: int = 0x01
const SPRITE_RIVAL: int = 0x04
const SPRITE_JANINE: int = 0x0A
const SPRITE_TWIN: int = 0x26
const SPRITE_LASS: int = 0x28
const SPRITE_SWIMMER_GUY: int = 0x31
const SPRITE_ROCKET: int = 0x35
const SPRITE_SUDOWOODO: int = 0x52
const SPRITE_VARS: int = 0xF0

## Every object event in either corpus that names a variable sprite, as
## [group, number, object index, slot]. Crystal's second Copycat is her female
## row and Gold and Silver ship no `KrisStateSprites` and no second object, which
## is the one place the two corpora differ; [constant CRYSTAL_ONLY] names it.
const SLOT_OBJECTS: Array = [
	[1, 14, 3, 0xF5], [8, 7, 0, 0xF6], [8, 7, 9, 0xF6], [8, 7, 10, 0xF6],
	[10, 3, 2, 0xF4], [10, 4, 0, 0xF4], [10, 4, 1, 0xF4],
	[17, 8, 1, 0xF7], [17, 8, 2, 0xF8], [17, 8, 3, 0xF9], [17, 8, 4, 0xFA],
	[17, 10, 3, 0xFC],
	[22, 1, 0, 0xF5], [22, 1, 1, 0xF5],
	[22, 2, 0, 0xF5], [22, 2, 1, 0xF5], [22, 2, 2, 0xF5], [22, 2, 3, 0xF5],
	[22, 2, 4, 0xF5],
	[24, 7, 0, 0xF0], [24, 7, 1, 0xF1], [24, 7, 2, 0xF2], [24, 7, 3, 0xF3],
	[25, 12, 0, 0xFB], [25, 12, 5, 0xFB],
]
const CRYSTAL_ONLY: Array = [[25, 12, 5, 0xFB]]

## The four `ToggleDecorationsVisibility` slots, which are filled on every entry
## to the player's bedroom rather than once at new game, and so are deliberately
## NOT in `Gen2WorldState.INITIAL_VARIABLE_SPRITES`. A reader adding them there
## would be filling a room the player has not decorated yet.
const DECORATION_SLOTS: Array[int] = [0xF0, 0xF1, 0xF2, 0xF3]

## `Gen2WorldState.INITIAL_VARIABLE_SPRITES` read back off the source, so the
## constant and this file cannot drift together.
const INITIALIZE_EVENTS: Dictionary = {
	0xF4: SPRITE_SUDOWOODO, 0xF5: SPRITE_RIVAL, 0xF6: SPRITE_ROCKET,
	0xF7: SPRITE_JANINE, 0xF8: SPRITE_JANINE, 0xF9: SPRITE_JANINE,
	0xFA: SPRITE_JANINE, 0xFB: SPRITE_LASS, 0xFC: SPRITE_LASS,
}

## Route 40, whose two male swimmers are the reported case: `SPRITE_OLIVINE_RIVAL`
## is the rival until OlivineCity's own scene retires him into a swimmer.
const ROUTE_40_GROUP: int = 22
const ROUTE_40: int = 1
const ROUTE_40_SWIMMER: Vector2i = Vector2i(14, 15)
const ROUTE_40_ENTRY: Vector2i = Vector2i(14, 17)


func run(r: RefCounted) -> void:
	_r = r
	for game_id: StringName in [&"crystal", &"gold", &"silver"]:
		var data: GameData = GameData.open(game_id)
		if data == null:
			_r.fail("%s cache is unavailable. Import roms/%s.gbc first." % [game_id, game_id])
			continue
		_verify_defaults(game_id)
		_verify_corpus(game_id, data)
		_verify_route_40(game_id, data)
		_verify_save_round_trip(game_id)


## The nine rows are the source's, and the four decoration slots are not among
## them: `ToggleDecorationsVisibility` owns those and runs every map load.
func _verify_defaults(game_id: StringName) -> void:
	var initial: Dictionary = Gen2WorldState.INITIAL_VARIABLE_SPRITES
	_r.check(
		initial.size() == INITIALIZE_EVENTS.size(),
		"%s: InitializeEventsScript writes %d slots, the state seeds %d." % [
			game_id, INITIALIZE_EVENTS.size(), initial.size(),
		]
	)
	for slot: int in INITIALIZE_EVENTS:
		_r.check(
			int(initial.get(slot, 0)) == int(INITIALIZE_EVENTS[slot]),
			"%s: slot $%02X seeds $%02X, not InitializeEventsScript's $%02X." % [
				game_id, slot, int(initial.get(slot, 0)), int(INITIALIZE_EVENTS[slot]),
			]
		)
	for slot: int in DECORATION_SLOTS:
		_r.check(
			not initial.has(slot),
			"%s: decoration slot $%02X is seeded; ToggleDecorationsVisibility owns it." % [
				game_id, slot,
			]
		)


## Every object in the corpus that names a slot, and nothing else naming one.
## The pair is what says a new slot cannot appear without a row for it.
func _verify_corpus(game_id: StringName, data: GameData) -> void:
	var expected: Dictionary = {}
	for row: Array in SLOT_OBJECTS:
		if game_id != &"crystal" and row in CRYSTAL_ONLY:
			continue
		expected["%d:%d:%d" % [row[0], row[1], row[2]]] = int(row[3])
	var found: Dictionary = {}
	for map: Gen2WorldMap in data.world_maps():
		var rows: Array = map.events.get("objects", [])
		for index: int in rows.size():
			var sprite: int = int((rows[index] as Dictionary).get("sprite", 0))
			if sprite >= SPRITE_VARS:
				found["%d:%d:%d" % [map.group, map.number, index]] = sprite
	_r.check(
		found.size() == expected.size(),
		"%s: %d objects name a variable sprite, not %d." % [
			game_id, found.size(), expected.size(),
		]
	)
	for key: String in expected:
		_r.check(
			int(found.get(key, 0)) == int(expected[key]),
			"%s: object %s names $%02X, not $%02X." % [
				game_id, key, int(found.get(key, 0)), int(expected[key]),
			]
		)
	## The whole point of the table: every slot an object stands on is either
	## seeded or filled by the bedroom's own callback, so none of them resolves
	## to the player.
	var state := Gen2WorldState.new()
	for key: String in found:
		var slot: int = int(found[key])
		var resolved: int = state.variable_sprite(slot)
		if slot in DECORATION_SLOTS:
			_r.check(
				resolved == 0,
				"%s: decoration slot $%02X is filled before the bedroom fills it." % [
					game_id, slot,
				]
			)
			continue
		_r.check(
			resolved > 0 and resolved != SPRITE_CHRIS,
			"%s: object %s on slot $%02X resolves to $%02X, which draws the player." % [
				game_id, key, slot, resolved,
			]
		)


## The reported case, end to end on the real map: Route 40's swimmer is the rival
## before Olivine's scene and the swimmer guy after it, and never the player.
func _verify_route_40(game_id: StringName, data: GameData) -> void:
	var world: Gen2WorldAPI = Gen2WorldAPI.open(
		data, ROUTE_40_GROUP, ROUTE_40, ROUTE_40_ENTRY, Gen2WorldState.new()
	)
	if not _r.check(world != null, "%s: Route 40 map 22/1 is missing." % game_id):
		return
	var swimmer: Gen2WorldObject = world.object_at(ROUTE_40_SWIMMER)
	if not _r.check(
		swimmer != null,
		"%s: nothing stands on Route 40's %s." % [game_id, ROUTE_40_SWIMMER]
	):
		return
	_r.check(
		swimmer.sprite_number == SPRITE_RIVAL,
		"%s: Route 40's swimmer is sprite $%02X, not InitializeEventsScript's $%02X." % [
			game_id, swimmer.sprite_number, SPRITE_RIVAL,
		]
	)
	# OlivineCity's rival scene ends on `variablesprite SPRITE_OLIVINE_RIVAL,
	# SPRITE_SWIMMER_GUY`, and the objects it reaches are on a map two maps away.
	world.state.set_variable_sprite(0xF5, SPRITE_SWIMMER_GUY)
	var reloaded: Gen2WorldAPI = Gen2WorldAPI.open(
		data, ROUTE_40_GROUP, ROUTE_40, ROUTE_40_ENTRY, world.state
	)
	var after: Gen2WorldObject = reloaded.object_at(ROUTE_40_SWIMMER) if reloaded != null else null
	_r.check(
		after != null and after.sprite_number == SPRITE_SWIMMER_GUY,
		"%s: Route 40's swimmer is not the swimmer guy once the slot is assigned." % game_id
	)


## `SaveData` copies `wPlayerData` whole, and `wVariableSprites` is inside it, so
## a row assigned in one session opens the next one still assigned.
func _verify_save_round_trip(game_id: StringName) -> void:
	var state := Gen2WorldState.new()
	state.set_variable_sprite(0xF5, SPRITE_SWIMMER_GUY)
	state.set_variable_sprite(0xF4, SPRITE_TWIN)
	var reopened: Gen2WorldState = Gen2WorldState.from_dict(state.to_dict())
	_r.check(
		reopened.variable_sprite(0xF5) == SPRITE_SWIMMER_GUY \
			and reopened.variable_sprite(0xF4) == SPRITE_TWIN,
		"%s: an assigned variable sprite does not survive a save." % game_id
	)
	## A state written before the table was saved carries no rows, and the slots
	## it lost are the ones InitializeEventsScript wrote.
	var older: Dictionary = state.to_dict()
	older.erase("variable_sprites")
	var restored: Gen2WorldState = Gen2WorldState.from_dict(older)
	for slot: int in INITIALIZE_EVENTS:
		_r.check(
			restored.variable_sprite(slot) == int(INITIALIZE_EVENTS[slot]),
			"%s: a save with no table reads slot $%02X as $%02X, not $%02X." % [
				game_id, slot, restored.variable_sprite(slot), int(INITIALIZE_EVENTS[slot]),
			]
		)
