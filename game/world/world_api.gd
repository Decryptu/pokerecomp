class_name Gen2WorldAPI
extends RefCounted

## Scene-free runtime access to one imported Generation 2 map.
##
## The API works in walk cells: every cell is a 2x2 group of 8x8 graphics
## tiles. It owns player position, camera framing and live object state, while
## event flags are supplied through a separate scene-free world state.

const VIEW_CELLS: Vector2i = Vector2i(10, 9)
const VIEW_TILES: Vector2i = VIEW_CELLS * RomLayout.MAP_BLOCK_CELL_WIDTH
const CELL_PIXELS: int = Gen2Tiles.TILE_WIDTH * RomLayout.MAP_BLOCK_CELL_WIDTH
## The screen the cartridge draws, in pixels: 160x144.
const VIEW_PIXELS: Vector2i = VIEW_CELLS * CELL_PIXELS
## `ChangeMap` copies a map into the middle of `wOverworldMapBlocks`, which is
## three blocks wider than the map on every side (`home/map.asm`). That margin
## is what a connection strip fills and what a 20x18 screen can reach at a map
## edge; nothing past it exists on the cartridge at all.
const BUFFER_BLOCKS: int = 3
## How far [method map_placements] walks the connection graph, and how many maps
## it may place. Three hops reaches the towns either side of the routes next to
## this map, which is as much as the furthest zoom shows; the cap is what stops
## a walk of the whole region on a map that has many ways out.
const PLACEMENT_HOPS: int = 3
const PLACEMENT_LIMIT: int = 24
## The overworld object coordinate used by the player sprite. The 20x18 screen
## is not symmetrically centred around a 16x16 object: the source loads four
## walk cells before the player on each axis (`_LoadOverworldTilemap`).
const PLAYER_VIEW_CELL: Vector2i = Vector2i(4, 4)
const MOVEMENT_WALK: StringName = &"walk"
const MOVEMENT_SURF: StringName = &"surf"
const MOVEMENT_BIKE: StringName = &"bike"
## constants/sprite_constants.asm's first real id, and what GetMonSprite answers
## for a variable sprite no script has assigned yet.
const SPRITE_CHRIS: int = 1
## `GetMonSprite`'s two `.BreedMon` bytes, which are the species in the day
## care's own slots rather than an entry in any sprite table.
const SPRITE_DAY_CARE_MON_1: int = 0xE0
const SPRITE_DAY_CARE_MON_2: int = 0xE1
const TRAINER_SHOCK_EMOTE: int = 0
## `SeenByTrainerScript`'s `showemote EMOTE_SHOCK, LAST_TALKED, 30`
## (engine/events/trainer_scripts.asm), read the way every other `showemote` is:
## the operand is `wScriptDelay` and `ShowEmoteScript`'s `pause 0` spends
## two frames a unit (`Gen2WorldScriptRunner.PAUSE_FRAMES_PER_UNIT`).
const TRAINER_SHOCK_FRAMES: int = 60
## StepVectors' normal row: 2 pixels a frame for 8, the player's own walk. The
## trainer approach shares it; see advance_trainer_approach_step().
const STEP_PASSES_WALK: int = 8
## A ledge hop is two chained STEP_WALK cells: `StepFunction_PlayerJump`'s
## .initjump/.stepjump then .initland/.stepland, each timed by the walk's own
## InitStep. `UpdateJumpPosition` is the arc player_jump_offset() exposes.
const STEP_PASSES_HOP: int = STEP_PASSES_WALK * 2
## StepVectors' slow row: 1 pixel a frame for 16. _RandomWalkContinue calls
## InitStep with a direction of 0 to 3, which indexes it.
const STEP_PASSES_NPC_WALK: int = 16
## MovementFunction_Strength calls InitStep with `direction | 0`, so a pushed
## boulder indexes that same slow row and slides at a wandering NPC's speed.
const STEP_PASSES_BOULDER_PUSH: int = STEP_PASSES_NPC_WALK
## `Movement_tree_shake`'s own `ld a, 24`, spent as a STEP_TYPE_SLEEP.
const TREE_SHAKE_FRAMES: int = 24
## StepVectors' fast row: 4 pixels a frame for 4, reached through `STEP_BIKE`.
const STEP_PASSES_FAST: int = 4
## `StepFunction_Turn`: two frames standing, the new facing, two more.
const STEP_PASSES_TURN: int = 4
## `Script_ForcedMovement`'s `step_dig 16`, twice per whirlpool.
const FORCED_TURN_SLEEP_PASSES: int = 16
## How long each scripted step command takes, from the `STEP_*` speed it hands
## `InitStep` and that row of `StepVectors`. They differ only in the step type
## set over the top, and the turning rows keep the direction the command names.
## The frames are one cell's; the three jumping rows cover two. `turn_step` is
## not here: `TurnStep` never calls `InitStep`, so it sits with `turn_head`.
const SCRIPTED_STEP_PASSES: Dictionary = {
	&"slow_step": STEP_PASSES_NPC_WALK,
	&"step": STEP_PASSES_WALK,
	&"big_step": STEP_PASSES_FAST,
	&"slow_slide_step": STEP_PASSES_NPC_WALK,
	&"slide_step": STEP_PASSES_WALK,
	&"fast_slide_step": STEP_PASSES_FAST,
	&"slow_jump_step": STEP_PASSES_NPC_WALK,
	&"jump_step": STEP_PASSES_WALK,
	&"fast_jump_step": STEP_PASSES_FAST,
	&"turn_away": STEP_PASSES_NPC_WALK,
	&"turn_in": STEP_PASSES_WALK,
	&"turn_waterfall": STEP_PASSES_FAST,
}
const STEP_KIND_WALK: StringName = &"step"
const STEP_KIND_HOP: StringName = &"jump_step"
const STEP_KIND_TURN: StringName = &"turn"

## SCRIPTED_STEP_PASSES' three hops: two cells and `UpdateJumpPosition`'s arc.
const JUMP_STEP_KINDS: Array[StringName] = [
	&"slow_jump_step", &"jump_step", &"fast_jump_step",
]
## The two commands that only change a facing: `TurnHead` writes the direction
## and stands, `TurnStep` writes it two frames in and stands for two more.
const SCRIPTED_TURN_KINDS: Array[StringName] = [&"turn_head", &"turn_step"]
## RandomStepDuration_Slow and _Fast mask the source random byte before storing
## it as the wait preceding the next movement decision.
const IDLE_MASK_SLOW: int = 0x7F
const IDLE_MASK_FAST: int = 0x1F
## `StepFunction_Sleep` decrements before testing, so a rolled 0 wraps to 256.
const IDLE_PASSES_WRAP: int = 256
## `IsObjectMovingOffEdgeOfScreen`'s window, relative to the player, who stands
## four cells into the ten by nine `wXCoord`/`wYCoord` name. Inclusive.
const OBJECT_SCREEN_MIN: Vector2i = Vector2i(-4, -4)
const OBJECT_SCREEN_MAX: Vector2i = Vector2i(5, 4)

## Crystal background event types from script_constants.asm. READ and the four
## facing variants point directly at a script. IFSET and IFNOTSET point at a
## four-byte conditional record containing an event flag and script pointer.
## ITEM points at the `hiddenitem` macro's three bytes rather than at code.
const BGEVENT_READ: int = 0
const BGEVENT_UP: int = 1
const BGEVENT_DOWN: int = 2
const BGEVENT_RIGHT: int = 3
const BGEVENT_LEFT: int = 4
const BGEVENT_IFSET: int = 5
const BGEVENT_IFNOTSET: int = 6
const BGEVENT_ITEM: int = 7
const BGEVENT_COPY: int = 8

## `HandleMap` spends `NextOverworldFrame` in the middle of every pass and
## `MaxOverworldDelay` is 2 (engine/overworld/events.asm), so the whole
## overworld runs one pass per two hardware frames: every map object's step,
## every landmark sign countdown and every joypad read is a pass's, never a
## screen frame's. Measured on a real cartridge with
## `.claude/oracle/overworld/trace_walk.py`: an ordinary walk step is eight
## passes of two pixels and sixteen frames. Every `PASSES` count below is in
## that unit, and [Gen2WorldScreen] is what spends the two frames.
const FRAMES_PER_OVERWORLD_PASS: int = 2

## How far into the pass above the drawn frame stands: 0.0 on the pass, 0.5 on
## the frame after it. A Game Boy's panel smeared its two-pixel jolt and a modern
## one does not, so SMOOTH SCROLL halves the step rather than changing it.
## Presentation only, and zero is what the cartridge drew.
var pass_fraction: float = 0.0


## Hardware frames for a count of overworld passes. Anything spending frames
## against a duration read off the source, a driver or a preview, goes through
## this rather than multiplying by hand.
static func passes_in_frames(passes: int) -> int:
	return passes * FRAMES_PER_OVERWORLD_PASS


## `InitMapNameSign`. `wCurLandmark` is -1 on a map with no name to show, and the
## five landmarks `.CheckSpecialMap` names get no sign either, alongside
## `LANDMARK_SPECIAL`. Crystal indices, since the sign is Crystal's own screen. The
## two National Park gates are that group's maps 15 and 17, which
## `.CheckNationalParkGate` names because their environment is not `GATE`.
## Below, a `warp_event`'s destination byte for `-1`, which names
## [member backup_warp]: six warp events across five maps carry it.
const BACKUP_WARP_DESTINATION: int = 0xFF
const MAP_NAME_SIGN_NO_LANDMARK: int = -1
## `wLandmarkSignTimer`, decremented once per `PlaceMapNameSign` and so once
## per overworld pass, which is two hardware frames.
const MAP_NAME_SIGN_PASSES: int = 60
const NATIONAL_PARK_GATE_GROUP: int = 10
const NATIONAL_PARK_GATE_MAPS: Array[int] = [15, 17]
const MAP_NAME_SIGN_SILENT_LANDMARKS: Array[int] = [
	Gen2WorldRadio.LANDMARK_SPECIAL,
	0x11,  # LANDMARK_RADIO_TOWER
	0x46,  # LANDMARK_LAV_RADIO_TOWER
	0x3B,  # LANDMARK_UNDERGROUND_PATH
	0x5A,  # LANDMARK_INDIGO_PLATEAU
	0x44,  # LANDMARK_POWER_PLANT
]

var data: GameData = null
## What this run diverges from the cartridge on, and which challenge it is played
## under. Read-only to a mod: a rule that changed mid-run would make the save it
## produced unreproducible, which is the whole reason it belongs to the run.
var rules: Gen2Rules = null
## The landmark whose one Nuzlocke encounter is standing in front of the player
## right now, or -1 for none. Set by whoever opens a wild battle and read by
## [method Gen2WorldPartyHost.capture_wild], which is what keeps a ball from
## being thrown at an area that has already given up its Pokemon. Not part of
## the snapshot: a run reloaded mid-battle has no encounter open.
var nuzlocke_area_open: int = -1
var state: Gen2WorldState = null
var inventory: Gen2WorldInventory = null
var current_map: Gen2WorldMap = null
var current_tileset: Gen2WorldTileset = null
var player_cell: Vector2i = Vector2i.ZERO
var player_facing: int = Gen2WorldSprite.FACING_DOWN
var objects: Array = []
## Object zero: `showemote`'s bubble and `disappear`'s deletion, the two things
## the object commands write onto the player beyond the fields above.
var _player_object: Gen2WorldObject = Gen2WorldObject.new()
var object_hour: int = 6
var object_time_of_day: int = Gen2WorldPalette.TIME_MORNING
var world_day: int = 0
var world_hour: int = 6
var world_minute: int = 0
var dst_enabled: bool = false
var movement_mode: StringName = MOVEMENT_WALK
## Whether the next committed walk takes bike speed. No cartridge state: the
## screen polls [method Gen2ModHost.run_button_held] and pushes it in, so a
## replay reproduces a run rather than reading a live keyboard.
var run_held: bool = false
## `DOWN`, `UP`, `LEFT`, `RIGHT`: the direction constants' own order, which is
## both `.FinishFacing`'s row order and `.GetAction`'s test order.
const TURNING_DIRECTION_ORDER: Array[Vector2i] = [
	Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT,
]
## `wPlayerTurningDirection`: 0 while standing, `$80 | direction` once
## `DoPlayerMovement.DoStep` has committed a step or a turn. Only the input path
## writes it, which is why a scripted `applymovement` leaves it where it stands.
## `CheckStandingOnIce`'s `cp $f0` is dead in both pins: nothing writes $F0.
var _player_turning_direction: int = 0
## wPlayerState resolved through ChrisStateSprites, which is the only part of
## that state a renderer reads. movement_mode carries the rest; the two surfing
## states differ from each other here and nowhere else.
var player_sprite_number: int = Gen2WorldSprite.SPRITE_PLAYER
## `wLastSpawnMapGroup`/`wLastSpawnMapNumber`: the outdoor map the player last
## walked into a Pokemon Center from, which is what a blackout and a Teleport
## both turn back into a spawn. `(-1, -1)` is a game that has entered none, and
## `GetWhiteoutSpawn`'s own answer for that is `SPAWN_HOME`.
var last_spawn_map: Vector2i = Vector2i(-1, -1)
## `wDigWarpNumber`, `wDigMapGroup` and `wDigMapNumber`: the warp and outdoor map
## the player last came into a cave through, which is where Dig and an Escape
## Rope put them back. Empty until one is walked.
var dig_warp: Dictionary = {}
## Whether the escape just taken ran `Script_AbortBugContest` with a contest
## running. Not saved: it is read by the host on the same frame the warp is
## applied, and a save written after that has the restored party in it.
var _contest_abort_pending: bool = false
## `wBackupWarpNumber`, `wBackupMapGroup` and `wBackupMapNumber`: where a warp
## whose destination is -1 sends the player, and whose landmark a map with
## `LANDMARK_SPECIAL` borrows. `GetWarpDestCoords`'s `.backup` writes it on
## arriving at such a warp and `Script_warpmod` writes it outright; empty is a
## game that has walked through none, which is what a slot written before this
## existed truthfully says.
var backup_warp: Dictionary = {}
## `wSpawnAfterChampion`, which the induction and Red's credits write and the
## next CONTINUE spends; see [member Gen2WorldSnapshot.spawn_after_champion].
var spawn_after_champion: int = Gen2WorldSnapshot.SPAWN_AFTER_NONE
## `wPrevLandmark`, which is not saved on the cartridge either: `NewGame` writes
## New Bark Town into it and `FinishContinueFunction` sets SHOWN_MAP_NAME_SIGN so
## the map a loaded game opens on raises no sign. Opening a world is both of
## those, so the map it opens on is what the field starts as.
var _prev_landmark: int = MAP_NAME_SIGN_NO_LANDMARK
var _map_name_sign: int = MAP_NAME_SIGN_NO_LANDMARK
var _script_queue: Array = []
var _active_script: Gen2WorldScriptRunner = null
var _map_entry_scene_pending: bool = false
## Whether this visit to the current map has already run its scene script. The
## cartridge runs one on `MAPSETUP_ENTER` and not again until the next one, so a
## host that dispatches an entry twice must not get two.
var _map_entry_scene_ran: bool = false
var _object_visibility_overrides: Dictionary = {}
var _transient_object_visibility_overrides: Dictionary = {}
## Live cells and facings written by moveobject, turnobject, followers and the
## trainer approach. The cartridge keeps the same values in wMapObjects, which
## a map load rebuilds from ROM, so these do not outlive the loaded map; see
## _apply_map(). Flagged disappear/appear visibility is persistent; flagless and
## movement-level visibility uses a transient override cleared by map rebuild.
var _object_position_overrides: Dictionary = {}
var _object_facing_overrides: Dictionary = {}
var _object_followers: Dictionary = {}
## `LoadMapObjects` runs `MAPCALLBACK_OBJECTS` and then `LoadObjectMasks`, so a
## map load owes its masks once the callbacks it queued have run and not before:
## the flag one of them writes is read by the other. Raised by every map load and
## spent by [method run_event_queue] when the queue drains.
var _object_masks_pending: bool = false
var _block_overrides: Dictionary = {}
## [method map_placements], built on first use and dropped with the map it is
## measured from.
var _map_placements: Dictionary = {}
## [method connected_map_objects], built and dropped beside the placements.
var _connected_objects: Array = []
## Bumped whenever a `changeblock` or a map load moves a block byte, so a view
## that caches the block buffer knows when to read it again.
var block_revision: int = 0
## The drawn surface in hardware pixels, which is [constant VIEW_PIXELS] unless
## a view has asked for more. The extra is spread evenly around the screen the
## cartridge would have drawn, so the player keeps the place
## [constant PLAYER_VIEW_CELL] puts him in and only the surround grows.
var view_pixels: Vector2i = VIEW_PIXELS
## One resolved but uncommitted field move each, held between its `*_request()`
## and `complete_*()` the way Script_Cut holds wCutWhirlpool* across its
## writetext. Every one is cleared with the loaded map, since a request cannot
## outlive the map it was made on: most name a cell, block or object index that
## belongs to it, and Strength, Flash and the escapes, which name none, would
## otherwise refuse every later use with `*_in_progress`.
var _pending_cut: Dictionary = {}
var _pending_surf: Dictionary = {}
var _pending_whirlpool: Dictionary = {}
var _pending_strength: Dictionary = {}
var _pending_escape: Dictionary = {}
var _pending_waterfall: Dictionary = {}
var _pending_flash: Dictionary = {}
## The encounter behind this one is rolled on the commit, since TreeMonEncounter
## runs after UseHeadbuttText.
var _pending_headbutt: Dictionary = {}
var _pending_rock_smash: Dictionary = {}
## wPlayerID, mirrored from the selected save the way _party_summary mirrors
## its party. GetTreeScore is the only reader; -1 means no save has set one,
## which refuses rather than scoring against an invented zero.
var _player_id: int = -1
## wPlayerName, mirrored the same way. `<PLAYER>` is a print-time code in
## every text that greets the player by name, so a script cannot print one
## without it; empty leaves the marker rather than inventing a trainer.
var _player_name: String = ""
## wPlayerGender's PLAYERGENDER_FEMALE_F, mirrored from the save the way the
## trainer ID is. Crystal only: pokegold ships no KrisStateSprites, so a Gold or
## Silver world stays male whatever a caller sets.
var _player_female: bool = false
var _command_queues: Dictionary = {}
var _next_command_queue_id: int = 0
var _fishing: Gen2WorldFishing = Gen2WorldFishing.new()
## Supplies the roaming jumps performed during map setup. A caller that needs a
## reproducible route sets its own generator; otherwise map setup randomizes.
var schedule_random: RandomNumberGenerator = null
## Supplies the source RANDOM command and the phone routines that roll. Kept
## apart from schedule_random so seeding one route does not shift the other.
## A null generator leaves each invocation to randomize its own.
var script_random: RandomNumberGenerator = null
## Supplies the wandering and spinning movement templates. Kept apart from the
## other two so seeding NPC motion cannot shift an encounter, a phone roll or a
## script's RANDOM result.
var object_random: RandomNumberGenerator = null
## Supplies the radio shows' own rolls, apart from the three above for the same
## reason they are apart from each other: reading the radio must not move a
## wild encounter or an NPC.
var radio_random: RandomNumberGenerator = null
## Supplies `DayCareStep`'s two rolls and `DayCare_InitBreeding`'s counter. Apart
## from the other four for the same reason: a step spent breeding must not move
## the wild encounter that step could also have rolled.
var breed_random: RandomNumberGenerator = null
## The programme the open radio card is reading, built by tune_radio() and
## dropped when the card closes or the dial finds dead air.
var _radio_show: Gen2RadioShow = null
## `wBuenasPassword` and `DAILYFLAGS2_BUENAS_PASSWORD_F`, and `wLuckyIDNumber`.
## None of the three is in the save model, so each is rolled once per world and
## kept here rather than persisted.
var _buenas_password: int = -1
var _buenas_password_today: bool = false
var _lucky_number: int = -1
## The seed the three generators above were built from, mirrored here so a
## snapshot records what a run can be reproduced with. Zero means nothing seeded
## them and the run is not reproducible.
var random_seed: int = 0
## Hardware frames this world has been advanced by, monotonic from the frame the
## snapshot it was opened from recorded. Every overworld timer is a countdown
## spent by the same pump, so a seed, an input log and this number are what make
## a run replayable. Advanced only by [method advance_frame_counter].
var frame_number: int = 0
var _last_schedule: Dictionary = {}
var _phone_ring: Gen2WorldPhoneRing = null
var _phone_ring_request: Dictionary = {}
## Transient presentation offset for the player's own walk step. player_cell
## already holds the committed destination; this only paces how far behind it
## a renderer draws the sprite. Never read by collision, events or the
## snapshot.
var _player_step_direction: Vector2i = Vector2i.ZERO
var _player_step_passes_total: int = 0
var _player_step_passes_remaining: int = 0
var _player_step_began: bool = false
## Whether the step in flight is a ledge hop, which is the only one the source
## gives a jump arc. See player_jump_offset().
var _player_jumping: bool = false
## The rest of a scripted movement stream the player still has to be drawn
## walking, the way Gen2WorldObject.queued_steps holds an object's.
var _player_queued_steps: Array = []
## Whether the trail above belongs to a scripted stream rather than to a walk
## the player asked for. Gen2WorldObject.scripted_steps for the player, and what
## keeps an ordinary step in flight out of scripted_movement_in_progress().
var _player_scripted_steps: bool = false
## The player's own OBJECT_STEP_FRAME. See Gen2WorldObject.step_frame.
var _player_step_frame: int = 0
var _player_step_kind: StringName = &""
## OBJECT_STEP_FRAME's spin use. See [method Gen2WorldMovement.spin_advance].
var _player_spin_frame: int = 0
## What runs when the player's queued run drains.
var _player_step_tail: Callable = Callable()
## Frames left of the counted wait a script is standing in, -1 while it is not
## standing in one or has not started counting.
var _script_wait_frames: int = -1
## Read-only mirror of the selected save's party, refreshed by the screen
## whenever the save or party changes. Gen2WorldAPI does not own a save, so
## this stays optional; a script that reads it while empty fails rather than
## reporting an invented zero. Never written by the script runner.
var _party_summary: Dictionary = {}

const PHONE_ENTRANCE_COLLISIONS: Array[int] = [0x71, 0x79, 0x7A, 0x7B]


## Opens one map through the public cartridge-content API.
## Returns null when the cache does not contain the requested map or tileset.
static func open(
	game_data: GameData,
	group: int,
	number: int,
	start_cell: Vector2i,
	world_state: Gen2WorldState = null,
	world_rules: Gen2Rules = null,
) -> Gen2WorldAPI:
	if game_data == null:
		return null
	var map: Gen2WorldMap = game_data.world_map(group, number)
	if map == null:
		return null
	var tileset: Gen2WorldTileset = game_data.world_tileset(map.tileset)
	if tileset == null:
		return null
	return Gen2WorldAPI.new(game_data, map, tileset, start_cell, world_state, world_rules)


## Opens a validated map/player snapshot without silently clamping its cell.
static func open_snapshot(
	game_data: GameData, world_snapshot: Gen2WorldSnapshot, world_rules: Gen2Rules = null
) -> Gen2WorldAPI:
	if game_data == null or world_snapshot == null:
		return null
	var map: Gen2WorldMap = game_data.world_map(world_snapshot.map_id.x, world_snapshot.map_id.y)
	if map == null or world_snapshot.world_state == null:
		return null
	if world_snapshot.player_cell.x < 0 or world_snapshot.player_cell.y < 0 \
		or world_snapshot.player_cell.x >= map.collision_width \
		or world_snapshot.player_cell.y >= map.collision_height:
		return null
	if world_snapshot.player_facing < Gen2WorldSprite.FACING_DOWN \
		or world_snapshot.player_facing > Gen2WorldSprite.FACING_RIGHT:
		return null
	if world_snapshot.movement_mode not in [MOVEMENT_WALK, MOVEMENT_SURF, MOVEMENT_BIKE]:
		return null
	if world_snapshot.world_day < 0 or world_snapshot.world_day >= Gen2WorldClock.DAYS_PER_WEEK \
		or world_snapshot.world_hour < 0 or world_snapshot.world_hour >= Gen2WorldClock.HOURS_PER_DAY \
		or world_snapshot.world_minute < 0 \
		or world_snapshot.world_minute >= Gen2WorldClock.MINUTES_PER_HOUR:
		return null
	var tileset: Gen2WorldTileset = game_data.world_tileset(map.tileset)
	if tileset == null:
		return null
	var out := Gen2WorldAPI.new(
		game_data, map, tileset, world_snapshot.player_cell, world_snapshot.world_state,
		world_rules
	)
	out.player_facing = world_snapshot.player_facing
	out.movement_mode = world_snapshot.movement_mode
	out.player_sprite_number = world_snapshot.player_sprite_number
	out.world_day = world_snapshot.world_day
	out.world_hour = world_snapshot.world_hour
	out.world_minute = world_snapshot.world_minute
	out.dst_enabled = world_snapshot.dst_enabled
	out.random_seed = world_snapshot.random_seed
	out.frame_number = world_snapshot.frame_number
	out.last_spawn_map = world_snapshot.last_spawn_map
	out.dig_warp = world_snapshot.dig_warp.duplicate()
	out.backup_warp = world_snapshot.backup_warp.duplicate()
	## `.SpawnAfterE4` and `.AfterRed`, which stand between `ClockContinue` and
	## `FinishContinueFunction`: the map the slot was written on is loaded and
	## then left, so everything a map load owes has already run when the spawn
	## warp happens. `PostCreditsSpawn` clears the byte behind itself.
	out.spawn_after_champion = world_snapshot.spawn_after_champion
	var spawn: int = world_snapshot.continue_spawn_index()
	if spawn >= 0:
		out.spawn_after_champion = Gen2WorldSnapshot.SPAWN_AFTER_NONE
		out.warp_to_spawn(spawn)
	return out


func _init(
	game_data: GameData,
	map: Gen2WorldMap,
	tileset: Gen2WorldTileset,
	start_cell: Vector2i = Vector2i.ZERO,
	world_state: Gen2WorldState = null,
	world_rules: Gen2Rules = null,
) -> void:
	data = game_data
	# Opening a world is the run starting, so its rules become the installed ones:
	# the statics that read them ([Gen2Experience], [Gen2Damage], [Gen2BattleAI])
	# take no world object, and one installed set is what keeps them from
	# disagreeing with this one. A null set leaves the shipped behaviour alone.
	rules = world_rules if world_rules != null else Gen2Rules.active()
	Gen2Rules.install(rules)
	state = world_state if world_state != null else Gen2WorldState.new()
	state.changed.connect(_on_world_state_changed)
	inventory = Gen2WorldInventory.new(data, state)
	state.ensure_roaming_mons(data.world_roaming_mons())
	current_map = map
	_map_placements = {}
	_connected_objects = []
	block_revision += 1
	current_tileset = tileset
	player_cell = _clamp_cell(start_cell)
	# Opening a world is `StartMap`, which falls into `EnterMap`: the five-step
	# cooldown is set here for the same reason _apply_map() sets it on a warp.
	state.set_wild_encounter_cooldown(Gen2WorldState.WILD_ENCOUNTER_COOLDOWN_STEPS)
	_prev_landmark = map_name_sign_landmark()
	_load_objects()
	_apply_map_music()


func map_id() -> Vector2i:
	return Vector2i(current_map.group, current_map.number) if current_map != null else Vector2i(-1, -1)


## GetWorldMapLocation: the current map's own landmark, with no fallback. Every
## reader but `InitMapNameSign` wants [method landmark_backup] instead.
func landmark() -> int:
	return current_map.location if current_map != null else Gen2WorldRadio.LANDMARK_SPECIAL


## The same lookup with the `LANDMARK_SPECIAL` fallback `RegionCheck`, `FlyMap`,
## `Pokedex_GetLandmark` and both `TownMap_*` routines spell out: a map with no
## landmark of its own borrows [member backup_warp]'s. Six maps carry it and only
## one is ordinary, POKECENTER_2F being every Pokemon Center's own upstairs, so
## the region a radio, a battle track and the dex area answer with is the backup's
## on every visit. `SetCaughtData` tests POKECENTER_2F by name rather than the
## landmark, and the two agree everywhere a caught mon can be made.
func landmark_backup() -> int:
	var here: int = landmark()
	if here != Gen2WorldRadio.LANDMARK_SPECIAL or backup_warp.is_empty() or data == null:
		return here
	var backup: Gen2WorldMap = data.world_map(
		int(backup_warp["map_group"]), int(backup_warp["map_number"])
	)
	return backup.location if backup != null else here


## `InitMapNameSign`'s own `wCurLandmark`: a gate borrows nobody's name, so its
## landmark is -1 and no sign is ever raised on it. `.CheckNationalParkGate`
## names the two gates whose environment is not `GATE` and folds them in.
func map_name_sign_landmark() -> int:
	if current_map == null:
		return MAP_NAME_SIGN_NO_LANDMARK
	if current_map.environment == ENVIRONMENT_GATE \
		or (current_map.group == NATIONAL_PARK_GATE_GROUP
			and NATIONAL_PARK_GATE_MAPS.has(current_map.number)):
		return MAP_NAME_SIGN_NO_LANDMARK
	return landmark()


## The landmark a sign is waiting to be raised for, or -1 for no sign. Read once
## by the host, which owns the sixty frames it is up for; `InitMapNameSign`
## itself only decides and loads.
func map_name_sign_pending() -> int:
	return _map_name_sign


func clear_map_name_sign() -> void:
	_map_name_sign = MAP_NAME_SIGN_NO_LANDMARK


## `InitMapNameSign`, which every map setup script but the submenu's reaches.
##
## The sign is Crystal's own screen: pokegold ships neither `MapEntryFrameGFX`
## nor the routine, so the whole decision is skipped there. `wPrevLandmark` is
## written on both branches, which is what makes a walk through a gate silent on
## the way out as well as the way in.
func _init_map_name_sign() -> void:
	var current: int = map_name_sign_landmark()
	var previous: int = _prev_landmark
	_prev_landmark = current
	_map_name_sign = MAP_NAME_SIGN_NO_LANDMARK
	if not Gen2WorldState.is_crystal_profile(data):
		return
	## `.CheckMovingWithinLandmark`: the same landmark, or arriving from a map
	## that had none.
	if current == previous or previous == Gen2WorldRadio.LANDMARK_SPECIAL:
		return
	if current == MAP_NAME_SIGN_NO_LANDMARK \
		or MAP_NAME_SIGN_SILENT_LANDMARKS.has(current):
		return
	_map_name_sign = current


## `GetMapMusic`'s two special header values and what it answers them with, the
## same numbers on all three cartridges.
const MUSIC_MAHOGANY_MART: int = 0x64
const RADIO_TOWER_MUSIC: int = 0x80
const MUSIC_CHERRYGROVE_CITY: int = 0x26
const MUSIC_ROCKET_HIDEOUT: int = 0x48
const MUSIC_BUG_CATCHING_CONTEST_RANKING: int = 0x58


## GetMapMusic_MaybeSpecial: SpecialMapMusic answers first, so MUSIC_SURF crosses
## map loads and the two National Park gates play the ranking piece for a contest.
func map_music_track() -> int:
	if movement_mode == MOVEMENT_SURF:
		return Gen2WorldFieldMove.MUSIC_SURF
	if _is_national_park_gate() and bug_contest_active():
		return MUSIC_BUG_CATCHING_CONTEST_RANKING
	## `BikeFunction` writes `wMapMusic` itself; `SpecialMapMusic`'s own `.bike`
	## branch is unreferenced.
	if movement_mode == MOVEMENT_BIKE:
		return Gen2WorldFieldMove.MUSIC_BICYCLE
	return _map_header_music()


func _is_national_park_gate() -> bool:
	return current_map != null and current_map.group == NATIONAL_PARK_GATE_GROUP \
		and NATIONAL_PARK_GATE_MAPS.has(current_map.number)


## `GetMapMusic`: a raw header is the wrong piece on six maps. The Radio Tower's
## five carry `RADIO_TOWER_MUSIC | MUSIC_GOLDENROD_CITY`, $BD unmasked.
func _map_header_music() -> int:
	if current_map == null:
		return Gen2WorldState.MUSIC_NONE
	var header: int = current_map.music
	var crystal: bool = Gen2WorldState.is_crystal_profile(data)
	if header == MUSIC_MAHOGANY_MART:
		return MUSIC_ROCKET_HIDEOUT if state.is_engine_flag_active(
			Gen2WorldState.engine_flag(Gen2WorldState.ENGINE_ROCKETS_IN_MAHOGANY, crystal)
		) else MUSIC_CHERRYGROVE_CITY
	if (header & RADIO_TOWER_MUSIC) == 0:
		return header
	if state.is_engine_flag_active(Gen2WorldState.engine_flag(
		Gen2WorldState.ENGINE_ROCKETS_IN_RADIO_TOWER, crystal
	)):
		return Gen2WorldRadio.MUSIC_ROCKET_OVERTURE
	return header & (RADIO_TOWER_MUSIC - 1)


## PlayMapMusic, which every map entry and every change of movement mode runs.
## Answers whether the track actually changed, which is both the source's own "do
## not restart the same piece" rule and what keeps a tuned station playing.
func _apply_map_music() -> bool:
	return state.play_map_music(map_music_track())


## The WRAM facts RadioChannels reads before it answers a knob position.
func radio_context() -> Dictionary:
	var crystal: bool = Gen2WorldState.is_crystal_profile(data)
	var tower: int = Gen2WorldState.ENGINE_ROCKETS_IN_RADIO_TOWER if crystal \
		else Gen2WorldState.ENGINE_ROCKETS_IN_RADIO_TOWER_GOLD_SILVER
	return {
		"landmark": landmark_backup(),
		"crystal": crystal,
		"expn_card": state.is_engine_flag_active(Gen2WorldState.ENGINE_EXPN_CARD),
		"rocket_signal": state.is_engine_flag_active(Gen2WorldState.ENGINE_ROCKET_SIGNAL),
		"rockets_in_radio_tower": state.is_engine_flag_active(tower),
		"time_of_day": int(world_clock().get("time_of_day", Gen2WorldRadio.TIME_MORNING)),
	}


func radio_station() -> Dictionary:
	return Gen2WorldRadio.station_for(state.radio_knob(), radio_context())


## Moves the dial and loads whatever station answers, which is
## UpdateRadioStation plus the LoadStation_ call it jumps to and
## StartRadioStation's music commit.
##
## A station's own music id is neither ENTER_MAP_MUSIC nor RESTART_MAP_MUSIC, so
## ExitPokegearRadio_HandleMusic takes neither branch when the Pokegear closes
## and the tuned track stays in `wMapMusic`. That is the whole mechanism behind
## the Poke Flute channel waking Snorlax.
func tune_radio(knob: int) -> Dictionary:
	state.set_radio_knob(knob)
	var tuned: Dictionary = radio_station()
	if not bool(tuned.get("ok", false)):
		# NoRadioStation: no channel, and the map's own music comes back.
		state.set_radio_channel(-1)
		state.set_map_music(map_music_track())
		_radio_show = null
		return tuned
	state.set_radio_channel(int(tuned["channel"]))
	state.set_map_music(int(tuned["music"]))
	_start_radio_show(int(tuned["channel"]))
	return tuned


func radio_show() -> Gen2RadioShow:
	return _radio_show


## `PlayRadioShow`, dispatched once a hardware frame while the radio card is
## open. Answers whether the box changed, so the host redraws only then.
func advance_radio_frame() -> bool:
	if _radio_show == null:
		return false
	_radio_show.set_hour(int(world_clock().get("hour", 12)))
	var changed_box: bool = _radio_show.advance_frame()
	var track: int = _radio_show.pending_music
	if track >= 0:
		_radio_show.pending_music = -1
		state.set_map_music(track)
	_buenas_password = _radio_show.buenas_password
	_buenas_password_today = _radio_show.buenas_password_today
	## `wBuenasPassword` is saved player data rather than a byte the radio owns:
	## the show draws it, and Buena's own menu reads it a session later.
	if _buenas_password >= 0:
		state.set_buenas_password(_buenas_password)
	return changed_box


## `LoadStation_`'s own jump into `RadioJumptable`, with the WRAM facts the
## shows read beyond the dial's.
func _start_radio_show(channel: int) -> void:
	var crystal: bool = Gen2WorldState.is_crystal_profile(data)
	var clock: Dictionary = world_clock()
	if radio_random == null:
		radio_random = RandomNumberGenerator.new()
		radio_random.randomize()
	if _lucky_number < 0:
		# `ResetLuckyNumberShowFlag`'s weekly roll, which has no saved home here.
		_lucky_number = radio_random.randi_range(0, 99999)
	_radio_show = Gen2RadioShow.start(data, channel, {
		"crystal": crystal,
		"weekday": world_day,
		"hour": int(clock.get("hour", 12)),
		"caught": state.caught_species().keys(),
		"hall_of_fame": state.hall_of_fame(),
		"kanto_badges": (state.badge_mask(crystal) >> 8) & 0xFF,
		"lucky_number": _lucky_number,
	}, radio_random)
	_radio_show.buenas_password = _buenas_password if _buenas_password >= 0 \
		else state.buenas_password()
	_radio_show.buenas_password_today = _buenas_password_today


## `PlayRadio`, the radio a `special MapRadio` switches on over the map. The
## station is the same show the Pokegear card reads, so it goes through
## `_start_radio_show` rather than growing a second reader; what differs is that
## nothing tuned a dial, so the knob and the channel the save keeps are left
## where they stand.
func play_map_radio(station: int) -> Dictionary:
	var channel: int = Gen2WorldRadio.map_radio_channel(
		station,
		Gen2WorldRadio.is_kanto_landmark(
			landmark_backup(), Gen2WorldState.is_crystal_profile(data)
		),
		object_time_of_day
	)
	if channel < 0:
		return {}
	_start_radio_show(channel)
	if _radio_show == null:
		return {}
	## `.PlayStation` runs the station's own entry once and then draws its box,
	## which is the line the player reads before the loop starts.
	_radio_show.advance_frame()
	_buenas_password = _radio_show.buenas_password
	_buenas_password_today = _radio_show.buenas_password_today
	if _buenas_password >= 0:
		state.set_buenas_password(_buenas_password)
	return {
		"channel": channel,
		"station": station,
		"lines": _radio_show.lines(),
		"music": Gen2WorldRadio.CHANNEL_SONGS[channel] \
			if channel < Gen2WorldRadio.CHANNEL_SONGS.size() else 0,
	}


## Closing the radio card. ExitPokegearRadio_HandleMusic restores the map's own
## music only for the two sentinels; a real station id falls through both, so
## whatever was tuned keeps playing.
func close_radio() -> void:
	_radio_show = null
	if state.radio_channel() < 0:
		state.set_map_music(map_music_track())


func snapshot() -> Gen2WorldSnapshot:
	return Gen2WorldSnapshot.from_world(self)


func map_size_cells() -> Vector2i:
	if current_map == null:
		return Vector2i.ZERO
	return Vector2i(current_map.collision_width, current_map.collision_height)


func map_size_pixels() -> Vector2i:
	return map_size_cells() * CELL_PIXELS


## The 6x5-metatile surrounding-page origin, which follows the player off the
## edge of the map and changes only on a 2x2-walk-cell block boundary.
##
## `GetMapScreenCoords` (`home/map.asm:1065`) stores
## `floor(wXCoord / 2) - 2`, and likewise for Y, in wOverworldMapAnchor. It
## clamps nothing. wPlayerMetatileX/Y carry the odd-cell remainder separately;
## see [method visible_subcell_offset_cells].
func visible_origin_cell() -> Vector2i:
	if current_map == null:
		return Vector2i.ZERO
	return Vector2i(
		floori(float(player_cell.x) / float(RomLayout.MAP_BLOCK_CELL_WIDTH))
			* RomLayout.MAP_BLOCK_CELL_WIDTH - PLAYER_VIEW_CELL.x,
		floori(float(player_cell.y) / float(RomLayout.MAP_BLOCK_CELL_WIDTH))
			* RomLayout.MAP_BLOCK_CELL_WIDTH - PLAYER_VIEW_CELL.y
	)


## wPlayerMetatileX/Y: the walk-cell remainder within the page's leading block.
func visible_subcell_offset_cells() -> Vector2i:
	if current_map == null:
		return Vector2i.ZERO
	return Vector2i(
		posmod(player_cell.x, RomLayout.MAP_BLOCK_CELL_WIDTH),
		posmod(player_cell.y, RomLayout.MAP_BLOCK_CELL_WIDTH),
	)


## Top-left walk cell selected from the surrounding page while standing still.
func visible_screen_origin_cell() -> Vector2i:
	return visible_origin_cell() + visible_subcell_offset_cells()


func player_view_cell() -> Vector2i:
	return player_cell - visible_screen_origin_cell()


## The player's presentation position in walk cells: the committed cell plus any
## in-flight step. A renderer that frames its own view reads this instead of
## composing player_cell and player_step_offset_cells() itself. player_cell
## stays the authoritative logical cell.
func player_position_cells() -> Vector2:
	return Vector2(player_cell) + player_step_offset_cells()


## The framed screen's top-left in fractional walk cells. This is the page
## anchor plus wPlayerMetatileX/Y plus the in-flight hSCX/hSCY scroll. It remains
## unclamped, so connection and border strips can enter the viewport.
func visible_origin_cells() -> Vector2:
	if current_map == null:
		return Vector2.ZERO
	return player_position_cells() - Vector2(PLAYER_VIEW_CELL)


## Half of whatever surround a view wider than the hardware's added, in whole
## pixels. The camera and the player's own pixel are both measured from this, so
## a surround with an odd side cannot round the two apart.
func view_surround_offset() -> Vector2i:
	return Vector2i(
		floori((view_pixels.x - VIEW_PIXELS.x) * 0.5),
		floori((view_pixels.y - VIEW_PIXELS.y) * 0.5),
	)


## The drawn surface's top-left in world pixels, which is
## [method visible_origin_cells] for a hardware-sized view. Whole pixels: the map
## quads and every sprite standing on them are placed from this one number.
func view_origin_pixels() -> Vector2:
	return view_origin_subpixel().round()


## The same before it is rounded, for a surface able to draw between two pixels.
func view_origin_subpixel() -> Vector2:
	return visible_origin_cells() * float(CELL_PIXELS) \
		- Vector2(view_surround_offset())


## The player's screen pixel, which is PLAYER_VIEW_CELL for as long as the
## player is the thing the view is framed on. `_UpdateSprites` and `ScrollScreen`
## are one after the other at the end of `HandleMapBackground`, so the shadow OAM
## a pass wrote and the scroll it computed are latched by the same VBlank and the
## drawn player never leaves its resting pixel. Only a height offset moves it.
func player_pixel_position() -> Vector2i:
	return Vector2i(
		(player_position_cells() - visible_origin_cells()) * float(CELL_PIXELS)
	)


## The player's pixel inside the drawn surface, which is
## [method player_pixel_position] plus [method view_surround_offset]. The two are
## the same value on a 160x144 view.
func player_view_pixel() -> Vector2i:
	return player_pixel_position() + view_surround_offset()


func player_step_in_progress() -> bool:
	return _player_step_passes_remaining > 0


## `UpdateJumpPosition`'s `.y_offsets`: the pixel a jumping sprite is drawn above
## its own cell, one entry per frame of the hop.
const JUMP_OFFSETS: Array[int] = [
	-4, -6, -8, -10, -11, -12, -12, -12, -11, -10, -9, -8, -6, -4, 0, 0,
]


## [method player_height_offset_pixels] in the renderer's own downward-positive
## draw space.
func player_jump_offset() -> int:
	if not _player_jumping or _player_step_passes_total <= 0:
		return 0
	var spent: int = _player_step_passes_total - _player_step_passes_remaining
	return jump_offset_at(spent, _player_step_passes_total)


## The table entry a hop is on [param progress] of the way through its flight.
## `UpdateJumpPosition` indexes it with an accumulator stepped by the step vector
## and halved, so every duration covers the same table at its own rate: the
## proportion is the accumulator.
static func jump_offset_for(progress: float) -> int:
	var index: int = floori(clampf(progress, 0.0, 1.0) * float(JUMP_OFFSETS.size()))
	return JUMP_OFFSETS[clampi(index, 0, JUMP_OFFSETS.size() - 1)]


## The same for a caller holding the passes rather than the proportion.
static func jump_offset_at(spent: int, total: int) -> int:
	if total <= 0:
		return 0
	return jump_offset_for(float(spent) / float(total))


## How far above the ground the player is drawn this frame, in world pixels and
## positive upward. Zero at rest, on an ordinary step and on the frame a hop
## completes. Presentation only: the cell, the collision and the triggers are at
## the landing cell while this is above zero.
func player_height_offset_pixels() -> float:
	return float(-player_jump_offset())


## The in-flight step's presentation offset in fractional walk cells, from 1.0
## cell behind player_cell down to zero, so a renderer that does not think in
## hardware pixels can smooth against it without reverse-engineering CELL_PIXELS.
## A scripted movement commits its path at once, so while its trail drains this is
## as many cells behind as the player has left to be drawn walking.
func player_step_offset_cells() -> Vector2:
	return step_behind_cells(
		_player_queued_steps, _player_step_direction,
		_player_step_passes_remaining, _player_step_passes_total, pass_fraction
	)


## How far into its own run the step in flight is. The one place the fraction is
## spent, so a span and an offset taken apart cannot disagree by half a pass.
static func step_progress(remaining: int, total: int, fraction: float = 0.0) -> float:
	if remaining <= 0 or total <= 0:
		return 0.0
	return 1.0 - maxf(float(remaining) - fraction, 0.0) / float(total)


## The cells a step in flight is still behind its landing cell, for the player
## and for every object: two answers computed apart slide the map under them.
static func step_behind_cells(
	queued: Array, direction: Vector2i, remaining: int, total: int,
	fraction: float = 0.0
) -> Vector2:
	var behind := Vector2.ZERO
	for entry: Dictionary in queued:
		behind -= Vector2(entry["direction"] as Vector2i)
	if remaining > 0 and total > 0:
		behind -= Vector2(direction) \
			* (maxf(float(remaining) - fraction, 0.0) / float(total))
	return behind


## The two cells the step in flight runs between: `{from, to, progress, kind}`,
## and `{}` while nothing steps. [method player_step_offset_cells] is this summed
## over the run, which cannot be taken apart again once a stream turns. A renderer
## whose plan is not a plain grid puts both ends through its own geometry and
## moves between the answers, which a fractional cell cannot do across a fold.
func player_step_span() -> Dictionary:
	if _player_step_passes_remaining <= 0 or _player_step_passes_total <= 0:
		return {}
	var ahead := Vector2i.ZERO
	for entry: Dictionary in _player_queued_steps:
		ahead += entry["direction"] as Vector2i
	var landing: Vector2i = player_cell - ahead
	return {
		"from": landing - _player_step_direction,
		"to": landing,
		"progress": step_progress(
			_player_step_passes_remaining, _player_step_passes_total, pass_fraction
		),
		"kind": _player_step_kind,
	}


## Which movement the step in flight is, so a renderer draws a waterfall climb as
## a climb rather than a walk north: a scripted stream answers the command's own
## name, one of [constant SCRIPTED_STEP_PASSES]' keys. Empty while nothing steps.
func player_step_kind() -> StringName:
	return _player_step_kind if _player_step_passes_remaining > 0 else &""


## The facing the player is DRAWN with: [member player_facing] except while a
## spinning command walks. The spin also writes OBJECT_DIRECTION, so a stream
## that ends leaves [member player_facing] where it stopped.
func player_drawn_facing() -> int:
	if player_step_kind() in Gen2WorldMovement.SPINNING_KINDS:
		return Gen2WorldMovement.spin_facing(_player_spin_frame)
	return player_facing


## The player's `Facings` frame, 0 to 3. `Gen2WorldObject.walk_frame()` for an
## object; the player's own step is paced here rather than on a record.
func player_walk_frame() -> int:
	## StepFunction_Turn writes OBJECT_WALKING = STANDING for the whole four
	## frames. Once an ordinary step ends, SetFacingStanding selects the standing
	## drawing even though OBJECT_STEP_FRAME itself retains its counter.
	if _player_step_passes_remaining <= 0 or _player_step_direction == Vector2i.ZERO:
		return 0
	if _player_step_kind in Gen2WorldMovement.SLIDING_KINDS:
		return 0
	return (_player_step_frame >> 2) & 3


func _start_player_step(
	direction: Vector2i, frames: int, jumping: bool = false,
	kind: StringName = STEP_KIND_WALK
) -> void:
	_player_queued_steps.clear()
	_player_scripted_steps = false
	_begin_player_step(direction, frames, jumping, kind)


## One step of a scripted stream, behind whatever the player is already walking.
## See [method Gen2WorldObject.queue_step], which takes the same [param facing].
func _queue_player_step(
	direction: Vector2i, frames: int, jumping: bool = false,
	facing: Vector2i = Vector2i.ZERO, kind: StringName = STEP_KIND_WALK
) -> void:
	if _player_step_passes_remaining > 0 or not _player_queued_steps.is_empty():
		_player_scripted_steps = true
		_player_queued_steps.append({
			"direction": direction, "frames": maxi(0, frames), "jumping": jumping,
			"facing": facing, "kind": kind,
		})
		return
	_face_player_toward(facing)
	## See [method Gen2WorldObject.queue_step]: a turn with nothing to spend
	## leaves the stream's wait nothing to end on.
	if frames <= 0 and direction == Vector2i.ZERO:
		return
	_player_scripted_steps = true
	_begin_player_step(direction, frames, jumping, kind)


func _face_player_toward(direction: Vector2i) -> void:
	if direction != Vector2i.ZERO:
		player_facing = facing_for_direction(direction)


## The player's half of [method Gen2WorldObject._start_next_queued_step].
func _start_next_player_step() -> void:
	while not _player_queued_steps.is_empty():
		var next: Dictionary = _player_queued_steps.pop_front()
		_face_player_toward(next.get("facing", Vector2i.ZERO))
		if int(next["frames"]) > 0 or next["direction"] != Vector2i.ZERO:
			_begin_player_step(
				next["direction"], int(next["frames"]), bool(next.get("jumping", false)),
				StringName(next.get("kind", STEP_KIND_WALK))
			)
			return
	_player_scripted_steps = false
	_player_step_kind = &""
	_run_player_step_tail()


func _run_player_step_tail() -> void:
	if not _player_step_tail.is_valid():
		return
	var tail: Callable = _player_step_tail
	_player_step_tail = Callable()
	tail.call()


func _begin_player_step(
	direction: Vector2i, frames: int, jumping: bool = false,
	kind: StringName = STEP_KIND_WALK
) -> void:
	_player_step_kind = kind
	## `StepFunction_PlayerJump` and `StepFunction_NPCJump` are the only step
	## types that run `UpdateJumpPosition`, and every other step type replaces
	## them, so the arc belongs to the hop that set it and to nothing begun after
	## it. `_try_ledge_hop` and a `jump_step` raise the flag again.
	_player_jumping = jumping
	_player_step_direction = direction
	_player_step_passes_total = maxi(0, frames)
	_player_step_passes_remaining = _player_step_passes_total
	_player_step_began = direction != Vector2i.ZERO


func _clear_player_step() -> void:
	## A map load re-derives the player state itself, so dropping a tail loses
	## nothing; running it against the cell being left would.
	_player_step_tail = Callable()
	_player_step_kind = &""
	_player_spin_frame = 0
	_player_step_began = false
	_player_jumping = false
	_player_step_direction = Vector2i.ZERO
	_player_step_passes_total = 0
	_player_step_passes_remaining = 0
	_player_queued_steps.clear()
	_player_scripted_steps = false
	_player_step_frame = 0


## Spends one hardware frame of the player's walk-step offset.
##
## This only shrinks a presentation offset that starts and ends at player_cell;
## it never changes player_cell, collision or event results, and a caller that
## never starts a step sees no difference.
func advance_player_step_pass() -> bool:
	if _player_step_passes_remaining <= 0:
		return false
	if _player_step_kind in Gen2WorldMovement.SPINNING_KINDS:
		_player_spin_frame = Gen2WorldMovement.spin_advance(_player_spin_frame)
	if not _player_step_kind in Gen2WorldMovement.SLIDING_KINDS:
		_player_step_frame = (_player_step_frame + 1) & 0x0F
	_player_step_passes_remaining -= 1
	if _player_step_passes_remaining <= 0:
		_start_next_player_step()
	return true


## GetPlayerSprite: the sprite for the player's current state, not a fixed one.
func player_sprite() -> Gen2WorldSprite:
	return data.overworld_sprite(player_sprite_number) if data != null else null


func set_movement_mode(mode: StringName) -> Dictionary:
	if mode not in [MOVEMENT_WALK, MOVEMENT_SURF, MOVEMENT_BIKE]:
		return {"ok": false, "reason": &"invalid_movement_mode", "mode": mode}
	movement_mode = mode
	return {"ok": true, "mode": movement_mode}


## Sets the read-only party mirror a queued script's VAR_PARTYCOUNT read, its
## CheckPokerus special and its checkpoke consult. `has_pokerus` is the source's
## own low-nibble check across the party, computed by the caller because this
## class does not read [Gen2SaveMon] fields. [param moves] mirrors the move slots
## for `CheckPartyMove` and [param names] the display names for
## `GetPartyNickname`. [param eggs] marks the slots `CheckPartyMove` skips, since
## an egg carries the moves it will hatch with. [param extra] carries the few party
## facts that are not per-slot. Only an absent summary fails a script-visible read.
func set_party_summary(
	count: int, has_pokerus: bool, species: Array[int] = [] as Array[int],
	moves: Array = [], names: Array = [], eggs: Array = [], extra: Dictionary = {},
	fainted: Array = []
) -> Dictionary:
	if count < 0:
		return {"ok": false, "reason": &"invalid_party_summary", "count": count}
	_party_summary = {
		"count": count, "pokerus": has_pokerus, "species": species.duplicate(),
		"moves": moves.duplicate(true), "names": names.duplicate(),
		"eggs": eggs.duplicate(),
		## Per slot, beside the three per-slot arrays above. `lead_fainted` in
		## `extra` is the same fact about slot 0 and stays: the Bug Contest's own
		## scripts ask it by that name.
		"fainted": fainted.duplicate(),
	}
	for key: Variant in extra:
		_party_summary[key] = extra[key]
	return {"ok": true}


## CheckPartyMove: the first party slot whose own move list carries [param move_id],
## or -1 when none does. Eggs are skipped, empty and terminator slots end the walk,
## and the answer is the slot index the source leaves in `wCurPartyMon`. Every
## field move is gated on this: the party submenu reaches `CutFunction` and friends
## only for a mon that knows the move, and the overworld prompts each call
## `CheckPartyMove` themselves, so there is no path in either game that uses a
## field move the party does not know.
func party_slot_with_move(move_id: int) -> int:
	var moves: Array = _party_summary.get("moves", [])
	var eggs: Array = _party_summary.get("eggs", [])
	for slot: int in moves.size():
		if slot < eggs.size() and bool(eggs[slot]):
			continue
		if moves[slot] is Array and (moves[slot] as Array).has(move_id):
			return slot
	return -1


## Which of the two sources a field move is being used from. See
## [method field_move_source].
const FIELD_MOVE_SOURCE_PARTY: StringName = &"party"
const FIELD_MOVE_SOURCE_ITEM: StringName = &"item"


## WHERE a field move would be used from: `{kind, move, slot, item}`, and `{}`
## when nothing can use it. The party answers first and exactly what [method
## party_slot_with_move] did; only when no slot knows the move is an alternate
## source considered, and only for the seven HM moves. The badge is deliberately
## not part of this, since every `Try*OW` tests `CheckBadge` in its own order.
func field_move_source(move_id: int) -> Dictionary:
	var slot: int = party_slot_with_move(move_id)
	if slot >= 0:
		return {
			"kind": FIELD_MOVE_SOURCE_PARTY, "move": move_id, "slot": slot, "item": 0,
		}
	var item: int = item_field_move_source(move_id)
	if item <= 0:
		return {}
	return {"kind": FIELD_MOVE_SOURCE_ITEM, "move": move_id, "slot": -1, "item": item}


## The HM in the bag that teaches [param move_id] while a registered provider
## allows it, or 0. Which item teaches which move is `GetTMHMItemMove`'s answer
## rather than a second table.
func item_field_move_source(move_id: int) -> int:
	if data == null or state == null \
		or not Gen2WorldFieldMove.is_hm_field_move(move_id) \
		or not Gen2ModHost.allows_item_field_move(move_id):
		return 0
	for raw_item: Variant in state.items():
		var item: int = int(raw_item)
		if Gen2WorldTMHM.is_hm(item) and Gen2WorldTMHM.move_for_item(data, item) == move_id:
			return item
	return 0


## Every HM field move an item can supply and the party cannot, as
## `{move, item, badge}` in [constant Gen2WorldFieldMove.HM_FIELD_MOVES] order.
## The badge IS applied here, unlike in [method field_move_source]: a row that
## can only answer "a new BADGE is required" is not worth offering.
func item_field_move_offers() -> Array:
	var out: Array = []
	if data == null or state == null:
		return out
	var crystal: bool = Gen2WorldState.is_crystal_profile(data)
	for move_id: int in Gen2WorldFieldMove.HM_FIELD_MOVES:
		var source: Dictionary = field_move_source(move_id)
		if StringName(source.get("kind", &"")) != FIELD_MOVE_SOURCE_ITEM:
			continue
		var badge: int = Gen2WorldFieldMove.badge_for_move(move_id)
		if badge >= 0 and not state.is_engine_flag_active(
			Gen2WorldState.badge_flag(badge, crystal)
		):
			continue
		out.append({"move": move_id, "item": int(source["item"]), "badge": badge})
	return out


## Cleared so a stale count cannot answer a read after the caller stops
## refreshing it, for example when the injected preview save closes.
func clear_party_summary() -> void:
	_party_summary = {}


## Empty until a caller sets one: a script-visible read fails rather than
## inventing a count.
func party_summary() -> Dictionary:
	return _party_summary.duplicate()


func available_fishing_rods() -> Array[StringName]:
	return inventory.owned_rods() if inventory != null else []


func fishing_state() -> StringName:
	return _fishing.state()


func fishing_busy() -> bool:
	return _fishing.is_busy()


func facing_cell() -> Vector2i:
	return player_cell + facing_direction()


## The unit step the player's own facing points at, which is what every table
## keyed by `wPlayerDirection` is indexed by.
func facing_direction() -> Vector2i:
	return _direction_for_facing(player_facing)


## The cell CheckFacingObject searches, which is the faced one doubled away when
## the tile between is a counter (`engine/overworld/npc_movement.asm`). A mart
## clerk, a gym receptionist and the Radio Tower's Radio Card woman are all
## talked to across one.
func object_facing_cell() -> Vector2i:
	var direction: Vector2i = _direction_for_facing(player_facing)
	var faced: Vector2i = player_cell + direction
	if Gen2WorldCollision.is_counter(collision_code_at(faced)):
		return faced + direction
	return faced


func fishing_request(
	rod: StringName,
	random: RandomNumberGenerator = null,
	force_encounter: bool = false,
) -> Dictionary:
	if current_map == null or data == null:
		return _fishing_failure(&"missing_map")
	if inventory == null or not inventory.owns_rod(rod):
		return _fishing_failure(&"rod_not_owned")
	var context: Dictionary = _fishing_context(rod)
	if not bool(context.get("ok", false)):
		return _fishing_failure(StringName(context.get("reason", &"cannot_fish")))
	return _fishing.begin(
		rod,
		context["record"],
		int(context["fish_group"]),
		int(context["selected_fish_group"]),
		object_time_of_day,
		data.world_fishing_time_groups(),
		map_id(),
		player_cell,
		player_facing,
		context["facing_cell"],
		movement_mode,
		random,
		force_encounter,
	)


func advance_fishing() -> Dictionary:
	return _fishing.advance()


func cancel_fishing() -> Dictionary:
	return _fishing.cancel()


## `engine/events/unown_walls.asm`'s two farcalled chambers: `FlashFunction`
## reaches `SpecialAerodactylChamber` and `EscapeRopeOrDig`'s escape-rope branch
## reaches `SpecialKabutoChamber`, so neither is a `special` the runner can see.
## Ho-Oh's and Omanyte's are, and live there. Crystal's alone.
const RUINS_OF_ALPH_GROUP: int = 3
const RUINS_OF_ALPH_KABUTO_CHAMBER: int = 24
const RUINS_OF_ALPH_AERODACTYL_CHAMBER: int = 26
const EVENT_WALL_OPENED_IN_KABUTO_CHAMBER: int = 807
const EVENT_WALL_OPENED_IN_AERODACTYL_CHAMBER: int = 809
const UNOWN_WALL_MAPS: Dictionary = {
	EVENT_WALL_OPENED_IN_KABUTO_CHAMBER: RUINS_OF_ALPH_KABUTO_CHAMBER,
	EVENT_WALL_OPENED_IN_AERODACTYL_CHAMBER: RUINS_OF_ALPH_AERODACTYL_CHAMBER,
}


## [param event] while the player stands in that wall's own chamber, or -1,
## which is each routine's `GetMapAttributesPointer` comparison.
func unown_wall_event(event: int) -> int:
	if current_map == null or data == null \
		or not Gen2WorldState.is_crystal_profile(data) \
		or current_map.group != RUINS_OF_ALPH_GROUP \
		or current_map.number != int(UNOWN_WALL_MAPS.get(event, -1)):
		return -1
	return event


## engine/events/overworld.asm's CutFunction. Every field move below is staged
## rather than applied, since each script shows its text and waits before it
## changes anything: `*_request` records and `complete_*` writes. The refusal
## order is load bearing: `.CheckAble` tests ENGINE_HIVEBADGE before the tile.
func cut_request() -> Dictionary:
	if current_map == null or current_tileset == null:
		return _cut_failure(&"missing_map")
	if not _pending_cut.is_empty():
		return _cut_failure(&"cut_in_progress")
	## TryCutOW asks CheckPartyMove before the badge; the submenu path cannot
	## reach here without the move at all.
	if field_move_source(Gen2WorldFieldMove.MOVE_CUT).is_empty():
		return _cut_failure(&"move_not_known")
	var crystal: bool = Gen2WorldState.is_crystal_profile(data)
	if not state.is_engine_flag_active(
		Gen2WorldState.badge_flag(Gen2WorldFieldMove.BADGE_HIVE, crystal)
	):
		return _cut_failure(&"badge_required")
	var target: Vector2i = facing_cell()
	if not Gen2WorldFieldMove.cuttable(collision_code_at(target)):
		return _cut_failure(&"nothing_to_cut")
	var block_cell: Vector2i = _script_block_cell(target)
	var replacement: Dictionary = Gen2WorldFieldMove.cut_replacement(
		current_map.tileset, block_at(block_cell.x, block_cell.y), crystal
	)
	if not bool(replacement.get("ok", false)):
		return _cut_failure(&"nothing_to_cut")
	_pending_cut = {
		"ok": true,
		"kind": &"cut_requested",
		"move": Gen2WorldFieldMove.MOVE_CUT,
		"cell": target,
		"block_cell": block_cell,
		"block": int(replacement["block"]),
		"animation": int(replacement["animation"]),
	}
	return _pending_cut.duplicate(true)


func pending_cut() -> Dictionary:
	return _pending_cut.duplicate(true)


## CutDownTreeOrGrass, which writes wOverworldMapBlocks: change_block() drops the
## override on a map load exactly as re-reading the block data from ROM does, so
## the tree regrows on the next visit.
func complete_cut() -> Dictionary:
	if _pending_cut.is_empty():
		return _cut_failure(&"no_pending_cut")
	var request: Dictionary = _pending_cut
	_pending_cut = {}
	var block_cell: Vector2i = request["block_cell"]
	var changed: Dictionary = change_block(block_cell.x, block_cell.y, int(request["block"]))
	if not bool(changed.get("ok", false)):
		return changed
	return {
		"ok": true,
		"kind": &"cut_applied",
		"move": int(request["move"]),
		"cell": request["cell"],
		"block_cell": block_cell,
		"block": int(request["block"]),
		"animation": int(request["animation"]),
	}


static func _cut_failure(reason: StringName) -> Dictionary:
	return {"ok": false, "kind": &"cut_failed", "reason": reason}


## SurfFunction .TrySurf. The badge is tested before the player's own state and
## before the tile, so a player without the Fog Badge is told about the badge
## whether or not the water in front is surfable, CheckBadge itself being what
## pushes that text. [param species] is the chosen party member's, for GetSurfType.
func surf_request(species: int = 0) -> Dictionary:
	if current_map == null or current_tileset == null:
		return _surf_failure(&"missing_map")
	if not _pending_surf.is_empty():
		return _surf_failure(&"surf_in_progress")
	var crystal: bool = Gen2WorldState.is_crystal_profile(data)
	if not state.is_engine_flag_active(
		Gen2WorldState.badge_flag(Gen2WorldFieldMove.BADGE_FOG, crystal)
	):
		return _surf_failure(&"badge_required")
	## Surf is the one move whose overworld prompt asks CheckPartyMove after the
	## badge rather than before it (`TrySurfOW`).
	if field_move_source(Gen2WorldFieldMove.MOVE_SURF).is_empty():
		return _surf_failure(&"move_not_known")
	if always_on_bike():
		return _surf_failure(&"cannot_surf")
	if movement_mode == MOVEMENT_SURF:
		return _surf_failure(&"already_surfing")
	var target: Vector2i = facing_cell()
	if collision_permission_at(target) != Gen2WorldCollision.WATER_TILE:
		return _surf_failure(&"cannot_surf")
	var direction: Vector2i = _direction_for_facing(player_facing)
	# CheckDirection: the standing cell's own permissions must not wall off the
	# way the player faces.
	var face: int = Gen2WorldCollision.face_mask_for_direction(direction)
	if face != 0 and (tile_permissions_at(player_cell) & face) != 0:
		return _surf_failure(&"cannot_surf")
	# CheckFacingObject is Crystal only. pokegold's .TrySurf omits it and carries
	# the "You can Surf on top of NPCs" bug comment.
	if crystal and object_at(target) != null:
		return _surf_failure(&"cannot_surf")
	_pending_surf = {
		"ok": true,
		"kind": &"surf_requested",
		"move": Gen2WorldFieldMove.MOVE_SURF,
		"cell": target,
		"direction": direction,
		"sprite": Gen2WorldFieldMove.surf_sprite(species),
	}
	return _pending_surf.duplicate(true)


func pending_surf() -> Dictionary:
	return _pending_surf.duplicate(true)


## The rest of UsedSurfScript after its waitbutton: writevar VAR_MOVEMENT,
## UpdatePlayerSprite, then SurfStartStep's single slow_step into the water.
## An applymovement rather than input, so it spends no repel step, rolls no
## encounter and is not re-validated.
func complete_surf() -> Dictionary:
	if _pending_surf.is_empty():
		return _surf_failure(&"no_pending_surf")
	var request: Dictionary = _pending_surf
	_pending_surf = {}
	movement_mode = MOVEMENT_SURF
	player_sprite_number = int(request["sprite"])
	player_cell = request["cell"]
	_apply_map_music()
	_start_player_step(request["direction"], STEP_PASSES_NPC_WALK, false, &"slow_step")
	return {
		"ok": true,
		"kind": &"surf_applied",
		"move": int(request["move"]),
		"cell": player_cell,
		"sprite": player_sprite_number,
	}


static func _surf_failure(reason: StringName) -> Dictionary:
	return {"ok": false, "kind": &"surf_failed", "reason": reason}


## WhirlpoolFunction .TryWhirlpool, filling the same wCutWhirlpool* slots Cut
## does. ENGINE_GLACIERBADGE before the tile, and no player state at all, so a
## player facing a whirlpool from land resolves too.
func whirlpool_request() -> Dictionary:
	if current_map == null or current_tileset == null:
		return _whirlpool_failure(&"missing_map")
	if not _pending_whirlpool.is_empty():
		return _whirlpool_failure(&"whirlpool_in_progress")
	## TryWhirlpoolOW asks CheckPartyMove before the badge.
	if field_move_source(Gen2WorldFieldMove.MOVE_WHIRLPOOL).is_empty():
		return _whirlpool_failure(&"move_not_known")
	if not state.is_engine_flag_active(Gen2WorldState.badge_flag(
		Gen2WorldFieldMove.BADGE_GLACIER, Gen2WorldState.is_crystal_profile(data)
	)):
		return _whirlpool_failure(&"badge_required")
	var target: Vector2i = facing_cell()
	if not Gen2WorldFieldMove.whirlpool_tile(collision_code_at(target)):
		return _whirlpool_failure(&"nothing_to_whirlpool")
	var block_cell: Vector2i = _script_block_cell(target)
	var replacement: Dictionary = Gen2WorldFieldMove.whirlpool_replacement(
		current_map.tileset, block_at(block_cell.x, block_cell.y)
	)
	if not bool(replacement.get("ok", false)):
		return _whirlpool_failure(&"nothing_to_whirlpool")
	_pending_whirlpool = {
		"ok": true,
		"kind": &"whirlpool_requested",
		"move": Gen2WorldFieldMove.MOVE_WHIRLPOOL,
		"cell": target,
		"block_cell": block_cell,
		"block": int(replacement["block"]),
		"animation": int(replacement["animation"]),
	}
	return _pending_whirlpool.duplicate(true)


func pending_whirlpool() -> Dictionary:
	return _pending_whirlpool.duplicate(true)


## DisappearWhirlpool, which writes the replacement block as CutDownTreeOrGrass
## does, so the whirlpool returns with the next map load.
func complete_whirlpool() -> Dictionary:
	if _pending_whirlpool.is_empty():
		return _whirlpool_failure(&"no_pending_whirlpool")
	var request: Dictionary = _pending_whirlpool
	_pending_whirlpool = {}
	var block_cell: Vector2i = request["block_cell"]
	var changed: Dictionary = change_block(block_cell.x, block_cell.y, int(request["block"]))
	if not bool(changed.get("ok", false)):
		return changed
	return {
		"ok": true,
		"kind": &"whirlpool_applied",
		"move": int(request["move"]),
		"cell": request["cell"],
		"block_cell": block_cell,
		"block": int(request["block"]),
		"animation": int(request["animation"]),
	}


static func _whirlpool_failure(reason: StringName) -> Dictionary:
	return {"ok": false, "kind": &"whirlpool_failed", "reason": reason}


## WaterfallFunction .TryWaterfall: CheckBadge ENGINE_RISINGBADGE, then
## CheckMapCanWaterfall, which is `wPlayerDirection & $c` being FACE_UP and
## wTileUp satisfying CheckWaterfallTile. No player state, so it neither
## requires nor refuses surfing.
func waterfall_request() -> Dictionary:
	if current_map == null or current_tileset == null:
		return _waterfall_failure(&"missing_map")
	if not _pending_waterfall.is_empty():
		return _waterfall_failure(&"waterfall_in_progress")
	## TryWaterfallOW asks CheckPartyMove before the badge.
	if field_move_source(Gen2WorldFieldMove.MOVE_WATERFALL).is_empty():
		return _waterfall_failure(&"move_not_known")
	if not state.is_engine_flag_active(Gen2WorldState.badge_flag(
		Gen2WorldFieldMove.BADGE_RISING, Gen2WorldState.is_crystal_profile(data)
	)):
		return _waterfall_failure(&"badge_required")
	## CheckMapCanWaterfall tests the facing before the tile, and only FACE_UP
	## passes: a waterfall faced from any other direction is not climbable even
	## though the same cell would answer the tile test.
	if player_facing != Gen2WorldSprite.FACING_UP:
		return _waterfall_failure(&"wrong_facing")
	var target: Vector2i = facing_cell()
	if not Gen2WorldFieldMove.waterfall_tile(collision_code_at(target)):
		return _waterfall_failure(&"nothing_to_climb")
	_pending_waterfall = {
		"ok": true,
		"kind": &"waterfall_requested",
		"move": Gen2WorldFieldMove.MOVE_WATERFALL,
		"cell": target,
	}
	return _pending_waterfall.duplicate(true)


func pending_waterfall() -> Dictionary:
	return _pending_waterfall.duplicate(true)


## Script_UsedWaterfall's loop: `applymovement PLAYER, .WaterfallStep` is one
## `turn_waterfall UP`, repeated by `.CheckContinueWaterfall` while the cell the
## player now stands on answers CheckWaterfallTile, so the climb ends on the first
## cell that is not a waterfall. Each step is an applymovement: no collision, no
## repel step, no encounter. Paced like a scripted stream, the cell committing at
## once and the column drawn a cell at a time, so a renderer can carry the player
## up the fall's face. [method _finish_waterfall_climb] is what the run drains
## into, and the answer reports the mode it will leave.
func complete_waterfall() -> Dictionary:
	if _pending_waterfall.is_empty():
		return _waterfall_failure(&"no_pending_waterfall")
	var request: Dictionary = _pending_waterfall
	_pending_waterfall = {}
	var size: Vector2i = map_size_cells()
	var cell: Vector2i = player_cell
	var climbed: int = 0
	## A fall drawn up to the top row ends there: `.CheckContinueWaterfall` reads
	## the border block above it, never a waterfall, so the cartridge stops one row
	## into padding this has no cell for. Silver Cave Room 2's is the only one.
	while climbed < size.y:
		var next: Vector2i = cell + Vector2i.UP
		if next.y < 0:
			break
		cell = next
		climbed += 1
		if not Gen2WorldFieldMove.waterfall_tile(collision_code_at(cell)):
			break
	if climbed <= 0:
		return _waterfall_failure(&"climb_did_not_finish")
	player_cell = cell
	player_facing = Gen2WorldSprite.FACING_UP
	var passes: int = int(SCRIPTED_STEP_PASSES[&"turn_waterfall"])
	for _step: int in climbed:
		_queue_player_step(Vector2i.UP, passes, false, Vector2i.UP, &"turn_waterfall")
	_player_step_tail = _finish_waterfall_climb
	return {
		"ok": true,
		"kind": &"waterfall_applied",
		"move": int(request["move"]),
		"cell": cell,
		"steps": climbed,
		"passes": climbed * passes,
		"movement_mode": _setup_movement_mode(cell),
	}


## `SetFacingCounterclockwiseSpin` writes OBJECT_DIRECTION, which is
## `wPlayerDirection` itself, and `movement_step_sleep`'s OBJECT_ACTION_STAND
## reads it back rather than restoring anything: the climb ends a quarter turn
## per cell round from DOWN. The landing state follows, as a warp's does.
func _finish_waterfall_climb() -> void:
	player_facing = Gen2WorldMovement.spin_facing(_player_spin_frame)
	_apply_map_setup_player_state()


static func _waterfall_failure(reason: StringName) -> Dictionary:
	return {"ok": false, "kind": &"waterfall_failed", "reason": reason}


## FlashFunction .CheckUseFlash. Flash is the one field move that checks no tile
## at all: its whole test is the badge and then whether this map is a dark one,
## which is the map header's own palette byte rather than anything under the
## player. The Aerodactyl chamber's branch is a Ruins of Alph puzzle that is not
## implemented, so the palette is the only way through.
func flash_request() -> Dictionary:
	if current_map == null:
		return _flash_failure(&"missing_map")
	if not _pending_flash.is_empty():
		return _flash_failure(&"flash_in_progress")
	if field_move_source(Gen2WorldFieldMove.MOVE_FLASH).is_empty():
		return _flash_failure(&"move_not_known")
	## The badge is checked before the map, so a player without it is told about
	## the badge even standing in the dark.
	if not state.is_engine_flag_active(Gen2WorldState.badge_flag(
		Gen2WorldFieldMove.BADGE_ZEPHYR, Gen2WorldState.is_crystal_profile(data)
	)):
		return _flash_failure(&"badge_required")
	## `.CheckUseFlash` asks `SpecialAerodactylChamber` before the palette, so
	## Flash works in that one room whatever the light.
	var chamber: int = unown_wall_event(EVENT_WALL_OPENED_IN_AERODACTYL_CHAMBER)
	if chamber < 0:
		if not Gen2WorldPalette.is_dark(current_map.palette):
			return _flash_failure(&"not_dark")
		if state.used_flash():
			return _flash_failure(&"already_lit")
	_pending_flash = {
		"ok": true,
		"kind": &"flash_requested",
		"move": Gen2WorldFieldMove.MOVE_FLASH,
		"wall_event": chamber,
	}
	return _pending_flash.duplicate(true)


func pending_flash() -> Dictionary:
	return _pending_flash.duplicate(true)


## `BlindingFlash`, reached only after Script_UseFlash's text: the flag goes on
## and every palette the map draws with changes with it.
func complete_flash() -> Dictionary:
	if _pending_flash.is_empty():
		return _flash_failure(&"no_pending_flash")
	var wall_event: int = int(_pending_flash.get("wall_event", -1))
	_pending_flash = {}
	state.set_used_flash(true)
	if wall_event >= 0:
		state.set_event_flag(wall_event, true)
	return {
		"ok": true,
		"kind": &"flash_used",
		"time_of_day": map_time_of_day(),
		"wall_event": wall_event,
	}


static func _flash_failure(reason: StringName) -> Dictionary:
	return {"ok": false, "kind": &"flash_failed", "reason": reason}


## TryHeadbuttOW and TryHeadbuttFromMenu; the roll belongs to the commit, since
## HeadbuttScript reaches TreeMonEncounter only after UseHeadbuttText. Headbutt is
## the one field move with no badge at all: TryHeadbuttOW is CheckPartyMove and
## nothing else, TryHeadbuttFromMenu the faced tile and nothing else. Its refusal
## is FieldMoveFailed's generic _CantUseItemText.
func headbutt_request() -> Dictionary:
	if current_map == null or current_tileset == null:
		return _headbutt_failure(&"missing_map")
	if not _pending_headbutt.is_empty():
		return _headbutt_failure(&"headbutt_in_progress")
	if party_slot_with_move(Gen2WorldFieldMove.MOVE_HEADBUTT) < 0:
		return _headbutt_failure(&"move_not_known")
	var target: Vector2i = facing_cell()
	if not Gen2WorldFieldMove.headbutt_tile(collision_code_at(target)):
		return _headbutt_failure(&"nothing_to_headbutt")
	_pending_headbutt = {
		"ok": true,
		"kind": &"headbutt_requested",
		"move": Gen2WorldFieldMove.MOVE_HEADBUTT,
		"cell": target,
	}
	return _pending_headbutt.duplicate(true)


func pending_headbutt() -> Dictionary:
	return _pending_headbutt.duplicate(true)


## TreeMonEncounter: the map's treemon set, then GetTreeMons' profile limit,
## then GetTreeMon's score and rolls. A miss is `.no_battle`, so it is an applied
## result with an empty encounter rather than a failure. The tree stands:
## ShakeHeadbuttTree is an animation, not a block change.
func complete_headbutt(random: RandomNumberGenerator) -> Dictionary:
	if _pending_headbutt.is_empty():
		return _headbutt_failure(&"no_pending_headbutt")
	if random == null:
		return _headbutt_failure(&"missing_generator")
	if data == null or current_map == null:
		return _headbutt_failure(&"missing_map")
	if _player_id < 0:
		return _headbutt_failure(&"missing_player_id")
	var request: Dictionary = _pending_headbutt
	_pending_headbutt = {}
	var cell: Vector2i = request["cell"]
	var encounter: Dictionary = _treemon_encounter(cell, random)
	return {
		"ok": true,
		"kind": &"headbutt_applied",
		"move": int(request["move"]),
		"cell": cell,
		"encounter": encounter,
	}


## GetTreeMonSet, GetTreeMons and GetTreeMon over the imported tables. Returns
## the wild-battle shape the other encounter paths return, so a host opens a
## headbutt battle exactly as it opens a grass one.
func _treemon_encounter(cell: Vector2i, random: RandomNumberGenerator) -> Dictionary:
	var set_number: int = data.treemon_set_for_map(current_map.group, current_map.number)
	if not Gen2WorldTreemon.set_is_usable(
		set_number, Gen2WorldState.is_crystal_profile(data)
	):
		return {}
	var resolved: Dictionary = Gen2WorldTreemon.resolve(
		data.treemon_set(set_number), cell, _player_id, random
	)
	if resolved.is_empty():
		return {}
	var species: int = int(resolved["species"])
	var level: int = int(resolved["level"])
	var asleep: bool = Gen2WorldTreemon.starts_asleep(
		species, data.asleep_treemons(object_time_of_day)
	)
	return {
		"kind": &"wild_encounter_requested",
		"method": Gen2WorldEncounter.METHOD_HEADBUTT,
		"source": Gen2WorldEncounter.SOURCE_TREE,
		"pokemon": species,
		"level": level,
		"map": map_id(),
		"cell": player_cell,
		"facing_cell": cell,
		"movement": movement_mode,
		"treemon_set": set_number,
		"score": int(resolved["score"]),
		"encounter_roll": int(resolved["encounter_roll"]),
		"slot_roll": int(resolved["slot_roll"]),
		"asleep": asleep,
		"values": {
			"kind": &"wild",
			"pokemon": species,
			"level": level,
			"battle_type": Gen2Battle.BATTLETYPE_TREE,
			"asleep": asleep,
		},
	}


static func _headbutt_failure(reason: StringName) -> Dictionary:
	return {"ok": false, "kind": &"headbutt_failed", "reason": reason}


## TryRockSmashFromMenu; the roll and the rock both belong to the commit. Rock
## Smash asks neither a badge nor a tile: `GetFacingObject` is `CheckFacingObject`
## and then the faced object's own `MAPOBJECT_MOVEMENT` byte against
## `SPRITEMOVEDATA_SMASHABLE_ROCK`, so the question is which object is in front
## rather than what the ground is, and it reads the doubled cell `interact()` does.
func rock_smash_request() -> Dictionary:
	if current_map == null or current_tileset == null:
		return _rock_smash_failure(&"missing_map")
	if not _pending_rock_smash.is_empty():
		return _rock_smash_failure(&"rock_smash_in_progress")
	if party_slot_with_move(Gen2WorldFieldMove.MOVE_ROCK_SMASH) < 0:
		return _rock_smash_failure(&"move_not_known")
	var target: Vector2i = object_facing_cell()
	var rock: Gen2WorldObject = object_at(target)
	if rock == null or not rock.is_smashable_rock():
		return _rock_smash_failure(&"nothing_to_smash")
	_pending_rock_smash = {
		"ok": true,
		"kind": &"rock_smash_requested",
		"move": Gen2WorldFieldMove.MOVE_ROCK_SMASH,
		"cell": target,
		"object_index": rock.index,
	}
	return _pending_rock_smash.duplicate(true)


func pending_rock_smash() -> Dictionary:
	return _pending_rock_smash.duplicate(true)


## RockSmashScript after its text: `disappear LAST_TALKED` and then
## `RockMonEncounter`. The rock goes whether or not anything comes out of it,
## because the disappear is before the roll.
func complete_rock_smash(random: RandomNumberGenerator) -> Dictionary:
	if _pending_rock_smash.is_empty():
		return _rock_smash_failure(&"no_pending_rock_smash")
	if random == null:
		return _rock_smash_failure(&"missing_generator")
	if data == null or current_map == null:
		return _rock_smash_failure(&"missing_map")
	var request: Dictionary = _pending_rock_smash
	_pending_rock_smash = {}
	var object_index: int = int(request["object_index"])
	smash_object(object_index)
	return {
		"ok": true,
		"kind": &"rock_smash_applied",
		"move": int(request["move"]),
		"cell": request["cell"],
		"object_index": object_index,
		"encounter": _rock_encounter(random),
	}


## `Script_disappear`: `DeleteObjectStruct` plus
## `ApplyEventActionAppearDisappear`, which writes the object's event flag only
## when it has one. Fifteen of the sixteen rocks carry `-1` and are back on the
## next visit; Mt. Moon Square's stays smashed and gates the Clefairy dance.
func smash_object(object_index: int) -> Dictionary:
	if current_map == null or object_index < 0 or object_index >= objects.size():
		return {"ok": false, "reason": &"missing_object"}
	var object: Gen2WorldObject = objects[object_index]
	## DeleteObjectStruct only, with no visibility override behind it: a map
	## load runs ReadObjectEvents and rebuilds every object from map data, so
	## what survives a reload is the event flag and nothing else.
	object.deleted = true
	object.active = false
	if object.event_flag > 0:
		state.set_event_flag(object.event_flag, true)
	return {"ok": true, "object_index": object_index, "event_flag": object.event_flag}


## RockMonEncounter over the imported RockMonMaps and the ROCK set. No
## BATTLETYPE_TREE, so nothing out of a rock starts asleep.
func _rock_encounter(random: RandomNumberGenerator) -> Dictionary:
	var set_number: int = data.treemon_set_for_map(
		current_map.group, current_map.number, true
	)
	if not Gen2WorldTreemon.set_is_usable(
		set_number, Gen2WorldState.is_crystal_profile(data)
	):
		return {}
	var resolved: Dictionary = Gen2WorldTreemon.rock_encounter(
		data.treemon_set(set_number), random
	)
	if resolved.is_empty():
		return {}
	var species: int = int(resolved["species"])
	var level: int = int(resolved["level"])
	return {
		"kind": &"wild_encounter_requested",
		"method": Gen2WorldEncounter.METHOD_ROCK_SMASH,
		"source": Gen2WorldEncounter.SOURCE_ROCK,
		"pokemon": species,
		"level": level,
		"map": map_id(),
		"cell": player_cell,
		"movement": movement_mode,
		"treemon_set": set_number,
		"encounter_roll": int(resolved["encounter_roll"]),
		"slot_roll": int(resolved["slot_roll"]),
		"values": {"kind": &"wild", "pokemon": species, "level": level},
	}


static func _rock_smash_failure(reason: StringName) -> Dictionary:
	return {"ok": false, "kind": &"rock_smash_failed", "reason": reason}


## Mirrors the selected save's wPlayerID, as set_party_summary() mirrors its
## party. Unset refuses rather than scoring against zero.
func set_player_id(new_player_id: int) -> Dictionary:
	if new_player_id < 0 or new_player_id > 0xFFFF:
		return {"ok": false, "reason": &"invalid_player_id", "player_id": new_player_id}
	_player_id = new_player_id
	return {"ok": true}


func player_id() -> int:
	return _player_id


## Mirrors the selected save's wPlayerName, for the `<PLAYER>` code.
func set_player_name(name: String) -> Dictionary:
	_player_name = name.strip_edges()
	return {"ok": true}


func player_name() -> String:
	return _player_name


## `GetPlayerSprite`'s table choice, mirrored from the save. Setting it re-runs
## the PLAYER_NORMAL lookup a map load does, so an open world picks it up at once.
func set_player_gender(female: bool) -> Dictionary:
	_player_female = female and Gen2WorldState.is_crystal_profile(data)
	if movement_mode == MOVEMENT_WALK:
		player_sprite_number = _walking_sprite()
	return {"ok": true, "female": _player_female}


func player_female() -> bool:
	return _player_female


## `InitPlayerObject` writes the palette onto the player object rather than
## reading the sprite's default row, so the renderer is told which one.
func player_palette() -> int:
	return Gen2WorldSprite.player_palette(_player_female)


## ChrisStateSprites' or KrisStateSprites' PLAYER_NORMAL row.
func _walking_sprite() -> int:
	return Gen2WorldSprite.player_normal_sprite(_player_female)


func clear_player_id() -> void:
	_player_id = -1


## Which palette row the current map draws with, once its own header byte, the
## clock and the Flash flag have all had their say.
func map_time_of_day() -> int:
	if current_map == null:
		return Gen2WorldPalette.TIME_MORNING
	return Gen2WorldPalette.map_time_of_day(
		current_map.palette, object_time_of_day, state.used_flash()
	)


## StrengthFunction .TryStrength, which unlike the others is a badge check and
## nothing else: no faced tile, no block table, no player state, and no check that
## a boulder is even in front. Its `.AlreadyUsingStrength` branch is annotated
## unreferenced in both pins, so an already-active flag is not a refusal here.
## [param species] is the chosen member's, for SetStrengthFlag's wStrengthSpecies.
func strength_request(species: int = 0) -> Dictionary:
	if current_map == null or current_tileset == null:
		return _strength_failure(&"missing_map")
	if not _pending_strength.is_empty():
		return _strength_failure(&"strength_in_progress")
	if not state.is_engine_flag_active(Gen2WorldState.badge_flag(
		Gen2WorldFieldMove.BADGE_PLAIN, Gen2WorldState.is_crystal_profile(data)
	)):
		return _strength_failure(&"badge_required")
	_pending_strength = {
		"ok": true,
		"kind": &"strength_requested",
		"move": Gen2WorldFieldMove.MOVE_STRENGTH,
		"species": species,
	}
	return _pending_strength.duplicate(true)


func pending_strength() -> Dictionary:
	return _pending_strength.duplicate(true)


## SetStrengthFlag: the engine flag plus wStrengthSpecies, which is only read
## back by Script_UsedStrength's own cry. `ResetBikeFlags` takes it off again on
## the next map, so a boulder outlives nothing but the map it stands on.
func complete_strength() -> Dictionary:
	if _pending_strength.is_empty():
		return _strength_failure(&"no_pending_strength")
	var request: Dictionary = _pending_strength
	_pending_strength = {}
	state.set_engine_flag(
		Gen2WorldState.strength_active_flag(Gen2WorldState.is_crystal_profile(data)), true
	)
	return {
		"ok": true,
		"kind": &"strength_applied",
		"move": int(request["move"]),
		"species": int(request["species"]),
	}


## BIKEFLAGS_STRENGTH_ACTIVE_F, the one condition CheckStrengthBoulder reads.
func strength_active() -> bool:
	return state.is_engine_flag_active(
		Gen2WorldState.strength_active_flag(Gen2WorldState.is_crystal_profile(data))
	)


static func _strength_failure(reason: StringName) -> Dictionary:
	return {"ok": false, "kind": &"strength_failed", "reason": reason}


## Environments a wild encounter is rolled on any tile of. `CAVE` and `DUNGEON`
## jump straight to the ice test, which is what puts encounters on a cave floor
## rather than only on its grass.
const ENVIRONMENT_TOWN: int = 1
const ENVIRONMENT_ROUTE: int = 2
const ENVIRONMENT_INDOOR: int = 3
const ENVIRONMENT_CAVE: int = 4
const ENVIRONMENT_5: int = 5
const ENVIRONMENT_GATE: int = 6
const ENVIRONMENT_DUNGEON: int = 7
## The three `StartTrainerBattle_DetermineWhichAnimation` calls a cave, which is
## what puts a battle on the flash-and-wave transition rather than the spin.
const CAVE_ENVIRONMENTS: Array[int] = [
	ENVIRONMENT_CAVE, ENVIRONMENT_5, ENVIRONMENT_DUNGEON,
]

## `TILESET_POKECENTER` and `TILESET_POKECOM_CENTER`, the two `.SetSpawn`
## respawns in. The second is Crystal's alone and its number is past the split,
## so no profile of Gold or Silver has a map wearing it.
const TILESET_POKECENTER: int = 0x07
const TILESET_POKECENTER_GOLD_SILVER: int = 0x06
const TILESET_POKECOM_CENTER: int = 0x15

## `.SaveDigWarp`'s two refusals by name: Mount Moon Square and the Tin Tower
## roof, outdoor maps reached from indoor ones, which Dig and an Escape Rope must
## not put the player back on. Both sit in `GROUP_FAST_SHIP` at the same numbers
## in both pins, since that group's rows do not move.
const OUTDOOR_MAPS_INSIDE_INDOOR_ONES: Array[Vector2i] = [
	Vector2i(15, 10), Vector2i(15, 12),
]


## Whether `ENGINE_BUG_CONTEST_TIMER` is set, which is the one thing that says a
## contest is running (`CheckTimeEvents`, `RandomEncounter`).
func bug_contest_active() -> bool:
	return state.bug_contest_active(Gen2WorldState.is_crystal_profile(data))


## `StartBugContestTimer` and `GiveParkBalls`: twenty balls, no caught Pokemon
## and the clock the contest is counted from. The flag itself is the script's
## own `setflag`, which runs before this.
func start_bug_contest() -> Dictionary:
	state.set_contest_mon({})
	state.set_park_balls(Gen2WorldBugContest.BALLS)
	state.set_bug_contest_started(world_clock())
	return {
		"ok": true,
		"kind": &"bug_contest_started",
		"park_balls": state.park_balls(),
		"minutes": Gen2WorldBugContest.MINUTES,
	}


## `CheckBugContestTimer` as `CheckTimeEvents` calls it: how many minutes are
## left, and whether this reading is the one that ends the contest. Answers zero
## minutes when no contest is running, which is what `VAR_BUGCONTEST_MINS_REMAINING`
## reads there too.
func bug_contest_minutes_remaining() -> int:
	if not bug_contest_active():
		return 0
	return Gen2WorldBugContest.minutes_remaining(
		state.bug_contest_started(), world_clock()
	)


## `BugContestResultsWarpScript`'s index in `StdScripts`, 22 in both pins the way
## `StrengthBoulderScript` is 14. It warps to the results gate and falls into
## `BugContestResultsScript`, which clears `ENGINE_BUG_CONTEST_TIMER` and judges.
const STD_BUG_CONTEST_RESULTS_WARP: int = 22


## `CheckTimeEvents`' contest branch: the timer is read once a step and the
## reading that runs out queues `BugCatchingContestOverScript`, the sound, the
## line and the warp back to the gate. Out of balls reaches the same warp through
## `BugCatchingContestOutOfBallsScript`, so both are one answer. Answers the
## queued results, or an empty Array while the contest runs on.
func check_bug_contest_timer() -> Array:
	if not bug_contest_active():
		return []
	var over: StringName = &""
	if bug_contest_minutes_remaining() <= 0:
		over = &"time_up"
	elif state.park_balls() <= 0:
		over = &"out_of_balls"
	if over == &"":
		return []
	return queue_bug_contest_results(over)


## `jumpstd BugContestResultsWarpScript`, which three readings reach: the timer
## above, the last ball, and `Script_Whiteout`'s own `iftrue .bug_contest`.
## Answers the queued results, or an empty Array when the cache holds no such
## standard script.
func queue_bug_contest_results(reason: StringName) -> Array:
	var entry: Dictionary = data.world_standard_script(STD_BUG_CONTEST_RESULTS_WARP) \
		if data != null else {}
	if entry.is_empty():
		return []
	_enqueue_script({
		"kind": &"bug_contest_over",
		"reason": reason,
		"map_group": current_map.group if current_map != null else -1,
		"map_number": current_map.number if current_map != null else -1,
		"cell": player_cell,
		"bank": int(entry.get("bank", -1)),
		"script": int(entry.get("address", -1)),
	})
	return run_event_queue(false)


## `BugContestResultsWarpScript`'s own tail: the flag is cleared, the balls and
## the timer go with it, and the Pokemon that was caught stays for the judging
## the results gate runs.
func end_bug_contest() -> Dictionary:
	var crystal: bool = Gen2WorldState.is_crystal_profile(data)
	state.set_engine_flag(
		Gen2WorldState.engine_flag(Gen2WorldState.ENGINE_BUG_CONTEST_TIMER, crystal), false
	)
	state.set_park_balls(0)
	state.set_bug_contest_started({})
	return {"ok": true, "kind": &"bug_contest_ended"}


## `_BugContestJudging`: the player's own score against the five contestants who
## turned up, and where that placed them.
func judge_bug_contest(random: RandomNumberGenerator) -> Dictionary:
	var caught: Dictionary = state.contest_mon()
	var result: Dictionary = Gen2WorldBugContest.judge(
		int(caught.get("species", 0)),
		Gen2WorldBugContest.score(caught),
		data.bug_contestants(),
		state.withdrawn_bug_contestants(),
		random if random != null else RandomNumberGenerator.new()
	)
	result["ok"] = true
	result["kind"] = &"bug_contest_judged"
	result["score"] = Gen2WorldBugContest.score(caught)
	result["caught"] = caught
	return result


## `CanEncounterWildMon`: the whole condition on the tile the player stands on,
## before the rate is read. Without it every step on open ground rolls, which is
## an encounter outside the grass and several times the cartridge's rate.
func can_encounter_wild_mon() -> bool:
	return can_encounter_wild_mon_at(player_cell)


## `CanEncounterWildMon` asked of a cell the player is not standing on, which is
## what a visible encounter needs before it may put one there. The engine flag is
## the map's, the rest is the cell's.
func can_encounter_wild_mon_at(cell: Vector2i) -> bool:
	if state.wild_encounters_off():
		return false
	var code: int = collision_code_at(cell)
	var environment: int = current_map.environment if current_map != null else 0
	if environment != ENVIRONMENT_CAVE and environment != ENVIRONMENT_DUNGEON \
		and not Gen2WorldCollision.gates_encounter(code):
		return false
	return not Gen2WorldCollision.is_ice(code)


## Every cell of the current map a wild could be met on, grouped the way
## [method encounter_request] resolves the terrain: WATER_TILE is `surf`,
## LAND_TILE is `grass`, and a cave or dungeon floor is grass drawn as grass or
## not. One narrowing on [method can_encounter_wild_mon]: a cell nothing can
## stand on is not offered, since a cave's walls pass the gate. Collision only.
func visible_encounter_cells() -> Dictionary:
	var out: Dictionary = {
		Gen2WorldEncounter.METHOD_GRASS: PackedVector2Array(),
		Gen2WorldEncounter.METHOD_SURF: PackedVector2Array(),
	}
	if current_map == null or state.wild_encounters_off():
		return out
	var size: Vector2i = map_size_cells()
	for y: int in size.y:
		for x: int in size.x:
			var cell := Vector2i(x, y)
			if not can_encounter_wild_mon_at(cell):
				continue
			var permission: int = collision_permission_at(cell)
			if permission == Gen2WorldCollision.WATER_TILE:
				out[Gen2WorldEncounter.METHOD_SURF].append(Vector2(cell))
			elif permission == Gen2WorldCollision.LAND_TILE:
				out[Gen2WorldEncounter.METHOD_GRASS].append(Vector2(cell))
	return out


## `wildoff`. The only thing that empties [method visible_encounter_cells] while
## one map is up, and a script may run it at any point in a walk.
func wild_encounters_off() -> bool:
	return state.wild_encounters_off()


## What [method active_encounter_tables] resolves against and nothing else: the
## hour the objects are drawn at, the Bug Contest and a swarm on this map. Three
## reads rather than two table builds, so a caller may ask every frame.
func encounter_tables_key() -> Array:
	if current_map == null or data == null:
		return []
	return [
		object_time_of_day,
		bug_contest_active(),
		state.swarm_active_on(current_map.group, current_map.number),
	]


## The wild table each method would resolve against right now, with the Bug
## Contest's and the swarm's substitutions made and the time of day picked.
## `slots` is the flat `{species, min_level, max_level}` list a roll would choose
## from, which a caller populating a map with visible Pokemon must not derive for
## itself. The bounds are equal but for the Bug Contest's own level roll.
func active_encounter_tables() -> Dictionary:
	var out: Dictionary = {}
	if current_map == null or data == null:
		return out
	for method: StringName in [Gen2WorldEncounter.METHOD_GRASS, Gen2WorldEncounter.METHOD_SURF]:
		var source: StringName = Gen2WorldEncounter.SOURCE_NORMAL
		var record: Dictionary = data.world_encounter(
			method, current_map.group, current_map.number
		)
		if bug_contest_active() and method == Gen2WorldEncounter.METHOD_GRASS:
			out[method] = {
				"source": Gen2WorldBugContest.SOURCE_CONTEST,
				"slots": Gen2WorldBugContest.active_slots(data.bug_contest_mons()),
			}
			continue
		if state.swarm_active_on(current_map.group, current_map.number):
			var swarm_method: StringName = &"swarm_grass" \
				if method == Gen2WorldEncounter.METHOD_GRASS else &"swarm_water"
			var swarm_record: Dictionary = data.world_encounter(
				swarm_method, current_map.group, current_map.number
			)
			if not swarm_record.is_empty():
				record = swarm_record
				source = Gen2WorldEncounter.SOURCE_SWARM
		if record.is_empty():
			continue
		out[method] = {
			"source": source,
			"slots": Gen2WorldEncounter.active_slots(record, method, object_time_of_day),
		}
	return out


## Rolls an encounter from the current map. Auto mode preserves the existing
## terrain behavior; an explicit rod method uses the map header's fishing
## group. The caller supplies the generator so tests can reproduce a result.
func encounter_request(
	random: RandomNumberGenerator = null, force_encounter: bool = false,
	method: StringName = &"auto", lead_level: int = -1,
	cleanse_tag: bool = false
) -> Dictionary:
	if current_map == null or data == null:
		return {}
	if method in ROD_METHODS:
		return _fishing_request(method, random, force_encounter)
	if method != &"auto" and method not in [
		Gen2WorldEncounter.METHOD_GRASS, Gen2WorldEncounter.METHOD_SURF,
	]:
		return {}
	## `RandomEncounter`'s own two gates, in its order: the cooldown a map entry
	## set, then `CanEncounterWildMon`. A forced request is a preview or a story
	## walk asking for the table's answer rather than the step's, so it skips
	## both the way it already skips the rate roll.
	if not force_encounter:
		if state.consume_wild_encounter_cooldown():
			return {}
		if not can_encounter_wild_mon():
			return {}
	var permission: int = collision_permission_at(player_cell)
	var terrain_method: StringName = method
	if terrain_method == &"auto" and permission == Gen2WorldCollision.WATER_TILE:
		terrain_method = Gen2WorldEncounter.METHOD_SURF
	elif terrain_method == &"auto" and permission == Gen2WorldCollision.LAND_TILE:
		terrain_method = Gen2WorldEncounter.METHOD_GRASS
	if terrain_method not in [Gen2WorldEncounter.METHOD_GRASS, Gen2WorldEncounter.METHOD_SURF]:
		return {}
	## `RandomEncounter`'s Bug Contest branch, which replaces the map's own
	## tables with `ContestMons` and the rate with the standing tile's own.
	if bug_contest_active():
		return _bug_contest_request(random, force_encounter, lead_level, cleanse_tag)
	var source: StringName = Gen2WorldEncounter.SOURCE_NORMAL
	var record: Dictionary = data.world_encounter(terrain_method, current_map.group, current_map.number)
	if state.swarm_active_on(current_map.group, current_map.number):
		var swarm_method: StringName = &"swarm_grass" if terrain_method == Gen2WorldEncounter.METHOD_GRASS else &"swarm_water"
		var swarm_record: Dictionary = data.world_encounter(
			swarm_method, current_map.group, current_map.number
		)
		if not swarm_record.is_empty():
			record = swarm_record
			source = Gen2WorldEncounter.SOURCE_SWARM
	var resolved: Dictionary = Gen2WorldEncounter.resolve(
		record, terrain_method, object_time_of_day, random, force_encounter, {
			"source": source,
			"roaming_mons": state.roaming_mons(),
			"map_group": current_map.group,
			"map_number": current_map.number,
			"repel_steps": state.repel_steps(),
			"lead_level": lead_level,
			"map_music": state.map_music(),
			"cleanse_tag": cleanse_tag,
			## `ChooseWildEncounter`'s own `ld a, [wUnlockedUnowns] / and a`, and
			## the guard that keeps `CheckUnownLetter`'s reroll answerable: on a
			## save that has solved no Ruins of Alph puzzle there is no letter to
			## give an Unown, so the step finds nothing rather than a Pokemon.
			"unlocked_unowns": state.unlocked_unowns(
				Gen2WorldState.is_crystal_profile(data)
			),
		}
	)
	if resolved.is_empty():
		return {}
	resolved["map"] = map_id()
	resolved["cell"] = player_cell
	resolved["fish_group"] = current_map.fish_group
	resolved["movement"] = movement_mode
	return resolved


## The three rods, which `FishFunction` reaches rather than `RandomEncounter`.
const ROD_METHODS: Array[StringName] = [
	Gen2WorldEncounter.METHOD_OLD_ROD,
	Gen2WorldEncounter.METHOD_GOOD_ROD,
	Gen2WorldEncounter.METHOD_SUPER_ROD,
]


func _fishing_request(
	method: StringName, random: RandomNumberGenerator, force_encounter: bool
) -> Dictionary:
	if inventory == null or not inventory.owns_rod(method):
		return {}
	var context: Dictionary = _fishing_context(method)
	if not bool(context.get("ok", false)):
		return {}
	var fishing: Dictionary = Gen2WorldEncounter.resolve_fishing(
		context["record"], method, object_time_of_day, data.world_fishing_time_groups(),
		random, force_encounter
	)
	if fishing.is_empty():
		return {}
	fishing["map"] = map_id()
	fishing["cell"] = player_cell
	fishing["fish_group"] = int(context["fish_group"])
	fishing["selected_fish_group"] = int(context["selected_fish_group"])
	fishing["movement"] = movement_mode
	fishing["facing"] = player_facing
	fishing["facing_cell"] = context["facing_cell"]
	return fishing


## `RandomEncounter`'s Bug Contest branch, which replaces the map's own tables
## with `ContestMons` and the rate with the standing tile's own.
func _bug_contest_request(
	random: RandomNumberGenerator, force_encounter: bool, lead_level: int,
	cleanse_tag: bool
) -> Dictionary:
	var contest: Dictionary = Gen2WorldBugContest.resolve(
		data.bug_contest_mons(),
		Gen2WorldCollision.is_long_grass(collision_code_at(player_cell)),
		random if random != null else RandomNumberGenerator.new(),
		force_encounter,
		{
			"map_music": state.map_music(),
			"cleanse_tag": cleanse_tag,
			"repel_steps": state.repel_steps(),
			"lead_level": lead_level,
		}
	)
	if contest.is_empty():
		return {}
	contest["map"] = map_id()
	contest["cell"] = player_cell
	contest["movement"] = movement_mode
	return contest



func set_repel_steps(steps: int) -> void:
	state.set_repel_steps(steps)


func repel_steps() -> int:
	return state.repel_steps()


## Whether a step has run an active Repel out and nobody has spent the fact yet.
## See [method Gen2WorldState.repel_expired].
func repel_expired() -> bool:
	return state != null and state.repel_expired()


func clear_repel_expired() -> void:
	if state != null:
		state.clear_repel_expired()


func set_swarm_map(
	map_key: Vector2i, active: bool = true, fishing_species: int = 0,
	kind: int = Gen2WorldState.SWARM_DUNSPARCE,
) -> void:
	state.set_swarm_map(map_key, active, fishing_species, kind)


func roaming_mons() -> Array:
	return state.roaming_mons()


func advance_roaming(
	random: RandomNumberGenerator = null, entry: int = MAP_ENTRY_CONNECTION
) -> Array:
	var rows: Array = data.world_roaming_maps()
	match int(ROAM_BY_MAP_ENTRY.get(entry, ROAM_NONE)):
		ROAM_UPDATE:
			return state.advance_roaming(rows, random, map_id())
		ROAM_JUMP:
			return state.jump_roaming(rows, random, map_id())
	return []


## `Continue`'s own `farcall JumpRoamMons`, which is in the menu rather than in
## `MapSetupScript_Continue`: opening a file scatters the beasts once.
func jump_roaming(random: RandomNumberGenerator = null) -> Array:
	return state.jump_roaming(data.world_roaming_maps(), random, map_id())


## `hMapEntryMethod`, which picks the `MapSetupScripts` entry a map load runs.
const MAP_ENTRY_WARP: int = 0xF1
const MAP_ENTRY_CONTINUE: int = 0xF2
const MAP_ENTRY_RELOADMAP: int = 0xF3
const MAP_ENTRY_TELEPORT: int = 0xF4
const MAP_ENTRY_DOOR: int = 0xF5
const MAP_ENTRY_FALL: int = 0xF6
const MAP_ENTRY_CONNECTION: int = 0xF7
const MAP_ENTRY_LINKRETURN: int = 0xF8
const MAP_ENTRY_TRAIN: int = 0xF9
const MAP_ENTRY_SUBMENU: int = 0xFA
const MAP_ENTRY_BADWARP: int = 0xFB
const MAP_ENTRY_FLY: int = 0xFC

const ROAM_NONE: int = 0
const ROAM_UPDATE: int = 1
const ROAM_JUMP: int = 2

## Which roaming routine each setup script carries, with the fall-throughs in
## `data/maps/setup_scripts.asm` spent: `_Fall` runs `_Door`'s body and `_Door`
## runs `_Train`'s, and `_Teleport` runs `_Fly`'s. A method named by no row moves
## no roamer, so a script `warp`, a blackout and a `reloadmap` move none.
const ROAM_BY_MAP_ENTRY: Dictionary = {
	MAP_ENTRY_TELEPORT: ROAM_JUMP,
	MAP_ENTRY_DOOR: ROAM_UPDATE,
	MAP_ENTRY_FALL: ROAM_UPDATE,
	MAP_ENTRY_CONNECTION: ROAM_UPDATE,
	MAP_ENTRY_TRAIN: ROAM_UPDATE,
	MAP_ENTRY_FLY: ROAM_JUMP,
}


## Applies one host schedule tick to the imported roaming graph. Swarm state is
## returned alongside it so a clock, radio event or save host can publish one
## coherent update without reaching into Gen2WorldState.
func advance_schedule(
	random: RandomNumberGenerator = null, entry: int = MAP_ENTRY_CONNECTION
) -> Dictionary:
	if random == null and not state.roaming_mons().is_empty():
		return {
			"ok": false,
			"kind": &"world_schedule_failed",
			"reason": &"missing_schedule_random",
			"roaming": [],
			"swarm_map": state.swarm_map(),
			"yanma_swarm_map": state.swarm_map(Gen2WorldState.SWARM_YANMA),
			"fishing_swarm_species": state.fishing_swarm_species(),
		}
	var moved: Array = advance_roaming(random, entry)
	return {
		"ok": true,
		"kind": &"world_schedule_updated",
		"roaming": moved,
		"swarm_map": state.swarm_map(),
		"yanma_swarm_map": state.swarm_map(Gen2WorldState.SWARM_YANMA),
		"fishing_swarm_species": state.fishing_swarm_species(),
	}


func set_world_clock(day: int, hour: int, minute: int) -> void:
	var next_day: int = posmod(day, Gen2WorldClock.DAYS_PER_WEEK)
	if next_day != world_day and state != null:
		state.reset_daily_flags(
			Gen2WorldState.is_crystal_profile(data), schedule_random
		)
	world_day = next_day
	world_hour = posmod(hour, Gen2WorldClock.HOURS_PER_DAY)
	world_minute = posmod(minute, Gen2WorldClock.MINUTES_PER_HOUR)


func world_clock() -> Dictionary:
	return {"day": world_day, "hour": world_hour, "minute": world_minute}


func daylight_saving_time_enabled() -> bool:
	return dst_enabled


func set_daylight_saving_time_enabled(enabled: bool) -> void:
	dst_enabled = enabled


func phone_ring_active() -> bool:
	return _phone_ring != null and not _phone_ring.is_finished()


func pending_phone_ring() -> Dictionary:
	if _phone_ring == null:
		return {}
	var ring: Dictionary = _phone_ring.snapshot()
	ring["kind"] = _phone_ring_request.get("kind", &"phone_incoming")
	ring["phone"] = (_phone_ring_request.get("phone", {}) as Dictionary).duplicate(true)
	ring["contact"] = (_phone_ring_request.get("contact", {}) as Dictionary).duplicate(true)
	return ring


## Advances the source ring timing and starts the imported phone script when
## both rings have completed. A phone ring is transient runtime state and is
## intentionally absent from world snapshots.
func advance_phone_ring_frame() -> Array:
	if _phone_ring == null:
		return []
	var progress: Dictionary = _phone_ring.advance_frame()
	if not bool(progress.get("finished", false)):
		return []
	var request: Dictionary = _phone_ring_request.duplicate(true)
	_phone_ring = null
	_phone_ring_request = {}
	_enqueue_script(request)
	return run_event_queue(false)


## Queues a source-style incoming call after checking the entrance, receive
## timer, random roll, service map, registration, time and same-map rules.
func request_incoming_phone_call(
	standing_on_entrance: bool = true,
	timer_ready: bool = true,
	random_byte: int = 0,
	force: bool = false,
	selection_byte: int = 0,
) -> Array:
	if phone_ring_active():
		return [{"ok": true, "status": &"phone_ring", "event": pending_phone_ring()}]
	var resolved: Dictionary = Gen2WorldPhoneHost.resolve_incoming(
		data, state, current_map, world_hour, standing_on_entrance, timer_ready,
		random_byte, force, selection_byte
	)
	if not bool(resolved.get("ok", false)):
		return [{"ok": false, "status": &"phone_unavailable", "reason": resolved.get("reason", &"phone_unavailable")}]
	var contact: Dictionary = resolved["contact"]
	var request: Dictionary = {
		"kind": &"phone_incoming",
		"map_group": current_map.group,
		"map_number": current_map.number,
		"bank": int(resolved["script"]["bank"]),
		"script": int(resolved["script"]["address"]),
		"phone": resolved["phone"],
		"contact": contact,
		"reset_receive_timer": true,
	}
	return _start_phone_ring(request)


## `MomTriesToBuySomething` whole: the decision, the purchase and the call, in
## the source's order. [param random_row] is `RandomRange` over `MomItems_1`,
## passed in the way every other roll here is.
##
## Answers `{ ok, bought, reason, results }`. `bought` is false when nothing was
## due, and the trigger balance the walk climbed to is still stored, because
## `.AddMoney` writes it before `.less_than` returns.
func mom_purchase(random_row: int = 0) -> Dictionary:
	if data == null or state == null:
		return {"ok": false, "reason": &"mom_data_unavailable", "results": []}
	var resolved: Dictionary = Gen2WorldMomPhone.resolve(
		data, state, current_map, random_row
	)
	if not bool(resolved.get("ok", false)):
		if resolved.has("trigger_balance"):
			state.set_mom_purchase(
				state.mom_item_index(), state.mom_item_set(),
				int(resolved["trigger_balance"])
			)
		return {
			"ok": true, "bought": false,
			"reason": resolved.get("reason", &"mom_bought_nothing"), "results": [],
		}
	var item: int = int(resolved["item"])
	var doll: bool = bool(resolved["doll"])
	## `Mom_GiveItemOrDoll`. The item half is `ReceiveItem` into `wNumPCItems`,
	## and a full PC returns before `MomBuysItem_DeductFunds`, so she keeps the
	## money and tries the same row again next time.
	if doll:
		Gen2WorldDecoration.set_owned(data, state, item)
	else:
		var held: int = state.pc_item_quantity(item)
		if held == 0 and state.pc_items().size() >= Gen2WorldPack.MAX_PC_ITEMS:
			return {"ok": true, "bought": false, "reason": &"pc_full", "results": []}
		var stored: Dictionary = state.apply_changes({}, {}, {
			"pc_items": {item: mini(held + 1, Gen2WorldPack.MAX_ITEM_STACK)},
		})
		if not bool(stored.get("ok", false)):
			return {"ok": true, "bought": false, "reason": &"pc_full", "results": []}
	## `MomBuysItem_DeductFunds`, and then `.ASMFunction`'s three writes.
	var savings: int = state.money(Gen2WorldScriptRunner.ACCOUNT_MOMS_MONEY)
	state.apply_changes({}, {}, {
		"money": {
			Gen2WorldScriptRunner.ACCOUNT_MOMS_MONEY:
				maxi(savings - int(resolved["cost"]), 0),
		},
	})
	state.set_mom_purchase(
		int(resolved["next_index"]), int(resolved["set"]),
		int(resolved["trigger_balance"])
	)
	return {
		"ok": true,
		"bought": true,
		"doll": doll,
		"item": item,
		"cost": int(resolved["cost"]),
		"results": request_caller_phone_call(
			Gen2WorldMomPhone.CONTACT_MOM, data.mom_phone_script(doll)
		),
	}


## `Script_SpecialBillCall`: `LoadCallerScript PHONE_BILL` and then
## `Script_ReceivePhoneCall`, which is the same two rings an incoming call
## spends. Nothing gates it, so the only caller is the event that owes it.
## [param script_override] is `Mom_GetScriptPointer`'s own answer: her call is
## the one place the contact's `PHONE_CONTACT_SCRIPT2` is written before the ring
## rather than read out of the table.
func request_caller_phone_call(
	contact_id: int, script_override: Dictionary = {}
) -> Array:
	if phone_ring_active():
		return [{"ok": true, "status": &"phone_ring", "event": pending_phone_ring()}]
	if current_map == null:
		return [{"ok": false, "status": &"phone_unavailable", "reason": &"missing_map"}]
	var resolved: Dictionary = Gen2WorldPhoneHost.resolve_caller(data, contact_id)
	if not bool(resolved.get("ok", false)):
		return [{
			"ok": false, "status": &"phone_unavailable",
			"reason": resolved.get("reason", &"phone_unavailable"),
		}]
	var script: Dictionary = resolved["script"]
	if not script_override.is_empty():
		script = script_override
	return _start_phone_ring({
		"kind": &"phone_incoming",
		"map_group": current_map.group,
		"map_number": current_map.number,
		"bank": int(script.get("bank", 0)),
		"script": int(script.get("address", 0)),
		"phone": resolved["phone"],
		"contact": resolved["contact"],
		"reset_receive_timer": true,
	})


## Queues a source-style special call. The pending call remains in world state
## until the imported phone script clears VAR_SPECIALPHONECALL.
func request_special_phone_call(call_id: int) -> Array:
	if phone_ring_active():
		return [{"ok": true, "status": &"phone_ring", "event": pending_phone_ring()}]
	var resolved: Dictionary = Gen2WorldPhoneHost.resolve_special(
		data, current_map, call_id, world_hour
	)
	if not bool(resolved.get("ok", false)):
		return [{
			"ok": false, "status": &"special_phone_unavailable",
			"reason": resolved.get("reason", &"special_phone_unavailable"),
		}]
	var request: Dictionary = {
		"kind": &"phone_special",
		"map_group": current_map.group,
		"map_number": current_map.number,
		"bank": int(resolved["script"]["bank"]),
		"script": int(resolved["script"]["address"]),
		"phone": resolved["phone"],
		"contact": resolved["contact"],
		"special_call_id": call_id,
		"reset_receive_timer": true,
	}
	return _start_phone_ring(request, 30)


## `CheckSpecialPhoneCall`'s own carry, without starting the call: a pending
## call whose condition holds ends the step at `CountStep`'s first test, so
## [method count_step] charges nothing on the step the phone rings.
func special_phone_call_ready() -> bool:
	if state == null or current_map == null:
		return false
	var call_id: int = state.pending_special_phone_call()
	if call_id <= 0:
		return false
	return bool(Gen2WorldPhoneHost.resolve_special(
		data, current_map, call_id, world_hour
	).get("ok", false))


## `CountStep` whole: the two guards in front of the counters, which every step
## taken here goes through. A special call about to ring and a Repel that has
## just worn off each reach `.doscript`, and neither step is counted.
func count_step() -> bool:
	if state == null or special_phone_call_ready():
		return false
	return state.count_step()


## `DoBikeStep`, which `CountStep` reaches behind the poison branch: the three
## gates in front of the counter, and the flag the queued call is paid for with.
## Answers whether the bike shop owner's call was queued.
func do_bike_step() -> bool:
	if state == null or current_map == null:
		return false
	var flag: int = Gen2WorldState.engine_flag(
		Gen2WorldState.ENGINE_BIKE_SHOP_CALL, Gen2WorldState.is_crystal_profile(data)
	)
	var armed: bool = movement_mode == MOVEMENT_BIKE and state.is_engine_flag_active(flag)
	if not state.do_bike_step(
		armed, Gen2WorldPhoneHost.map_has_phone_service(current_map)
	):
		return false
	state.set_engine_flag(flag, false)
	return true


## Checks the pending special call before ordinary step effects, matching the
## source CountStep path. A failed condition leaves the pending call queued.
func try_special_phone_call() -> Dictionary:
	if state == null:
		return {"ok": false, "reason": &"missing_world_state", "attempted": false}
	var call_id: int = state.pending_special_phone_call()
	if call_id <= 0:
		return {"ok": true, "attempted": false, "results": []}
	var resolved: Dictionary = Gen2WorldPhoneHost.resolve_special(
		data, current_map, call_id, world_hour
	)
	if not bool(resolved.get("ok", false)):
		return {
			"ok": true,
			"attempted": false,
			"call_id": call_id,
			"reason": resolved.get("reason", &"special_phone_unavailable"),
			"results": [],
		}
	return {
		"ok": true,
		"attempted": true,
		"call_id": call_id,
		"results": request_special_phone_call(call_id),
	}


## Advances the receive timer by completed game minutes. The source checks the
## entrance before it checks the timer, so a due call waits until the player is
## standing on a door, staircase or cave tile.
func advance_phone_schedule(
	minutes: int = 1,
	random: RandomNumberGenerator = null,
	selection_byte: int = -1,
	force: bool = false
) -> Dictionary:
	if state == null:
		return {"ok": false, "reason": &"missing_world_state", "timer_ready": false}
	if phone_ring_active():
		return {
			"ok": true,
			"timer_ready": state.phone_receive_ready(),
			"ringing": true,
			"results": [{"ok": true, "status": &"phone_ring", "event": pending_phone_ring()}],
		}
	var crossed: bool = state.advance_phone_receive_timer(minutes)
	var attempt: Dictionary = {
		"ok": true,
		"timer_ready": state.phone_receive_ready(),
		"timer_crossed": crossed,
		"results": [],
	}
	if not state.phone_receive_ready() or not standing_on_phone_entrance():
		return attempt
	var random_byte: int = random.randi_range(0, 255) if random != null else 0
	var chosen: int = selection_byte
	if chosen < 0:
		chosen = random.randi_range(0, 255) if random != null else 0
	state.consume_phone_receive_timer()
	attempt["attempted"] = true
	attempt["results"] = request_incoming_phone_call(
		true, true, random_byte, force, chosen
	)
	return attempt


## Checks a due receive timer after movement or map setup. This covers the
## source path where elapsed time made the timer ready away from an entrance.
func try_receive_phone_call(
	random: RandomNumberGenerator = null, selection_byte: int = -1, force: bool = false
) -> Dictionary:
	return advance_phone_schedule(0, random, selection_byte, force)


func standing_on_phone_entrance(cell: Vector2i = player_cell) -> bool:
	return PHONE_ENTRANCE_COLLISIONS.has(collision_code_at(cell))


func registered_phone_contacts() -> Array:
	return Gen2WorldPhoneHost.registered_contact_summaries(data, state)


## Queues the selected outgoing caller script. Pokegear presentation can use
## this boundary without duplicating phone eligibility rules in a scene.
func request_outgoing_phone_call(contact_id: int) -> Array:
	if phone_ring_active():
		return [{"ok": true, "status": &"phone_ring", "event": pending_phone_ring()}]
	var resolved: Dictionary = Gen2WorldPhoneHost.resolve_outgoing(
		data, state, current_map, contact_id, world_hour
	)
	if not bool(resolved.get("ok", false)):
		return [{"ok": false, "status": &"phone_unavailable", "reason": resolved.get("reason", &"phone_unavailable")}]
	var request: Dictionary = {
		"kind": &"phone_outgoing",
		"map_group": current_map.group,
		"map_number": current_map.number,
		"bank": int(resolved["script"]["bank"]),
		"script": int(resolved["script"]["address"]),
		"phone": resolved["phone"],
		"contact": resolved["contact"],
	}
	return _start_phone_ring(request)


func _start_phone_ring(request: Dictionary, lead_frames: int = 0) -> Array:
	if _phone_ring != null:
		return [{"ok": false, "status": &"phone_unavailable", "reason": &"phone_ring_active"}]
	_phone_ring_request = request.duplicate(true)
	_phone_ring = Gen2WorldPhoneRing.new(lead_frames)
	return [{
		"ok": true,
		"status": &"phone_ring",
		"event": pending_phone_ring(),
		"request": request.duplicate(true),
	}]


func _fishing_group_for_state(group: int) -> int:
	var fishing_swarm: int = state.fishing_swarm_species()
	if fishing_swarm == 0:
		return group
	if group == 11 and fishing_swarm == 0xD3:
		return 6
	if group == 12 and fishing_swarm == 0xDF:
		return 7
	return group


func _fishing_context(rod: StringName) -> Dictionary:
	if not Gen2WorldFishing.is_rod(rod):
		return {"ok": false, "reason": &"invalid_rod"}
	if inventory == null or not inventory.owns_rod(rod):
		return {"ok": false, "reason": &"rod_not_owned"}
	if movement_mode == MOVEMENT_SURF:
		return {"ok": false, "reason": &"cannot_fish_while_surfing"}
	var target: Vector2i = facing_cell()
	if collision_permission_at(target) != Gen2WorldCollision.WATER_TILE:
		return {"ok": false, "reason": &"not_facing_water"}
	var fish_group: int = current_map.fish_group
	var selected_group: int = _fishing_group_for_state(fish_group)
	var record: Dictionary = data.world_fishing_group(selected_group)
	if fish_group <= 0 or selected_group <= 0 or record.is_empty():
		return {"ok": false, "reason": &"no_fishing_group"}
	return {
		"ok": true,
		"fish_group": fish_group,
		"selected_fish_group": selected_group,
		"record": record,
		"facing_cell": target,
	}


## Counts one hardware frame, ahead of the advance_*_frame() calls that spend it.
## [method Gen2WorldScreen.advance_frame] is the only caller.
func advance_frame_counter() -> int:
	frame_number += 1
	return frame_number


## One hardware frame of every object's emote countdown, the player's included.
func advance_emotes_frame() -> bool:
	var changed: bool = _player_object.tick_emote()
	for object: Gen2WorldObject in objects:
		changed = object.tick_emote() or changed
	return changed


func player_emote() -> int:
	return _player_object.emote_id if _player_object.emote_visible \
		else Gen2WorldActors.EMOTE_NONE


func set_player_emote(emote_id: int, visible: bool, duration: int = 0) -> void:
	_player_object.set_emote(emote_id, visible, duration)


## False while `disappear PLAYER` holds: `DeleteObjectStruct` on object zero.
func player_visible() -> bool:
	return not _player_object.deleted


## The grass rustles `NormalStep` spawned this frame, taken once. `ShakeGrass` runs
## where a step starts, for whichever object is stepping and for the player alike,
## when the tile that step commits to is grass by `SetTallGrassFlags`' own test.
## The temporary object it spawns lives one frame less than the step, tracks the
## object that spawned it and is drawn over that object's own sprite. Returned
## rather than emitted because nothing in the world reads it: it is presentation,
## and [Gen2WorldEffects] holds it while it runs. Object index -1 is the player.
func take_grass_rustles() -> Array:
	var out: Array = []
	if _player_step_began:
		_player_step_began = false
		if Gen2WorldCollision.is_grass(collision_code_at(player_cell)):
			out.append({
				"object_index": -1,
				"cell": player_cell,
				"frames": maxi(0, _player_step_passes_total - 1),
			})
	for object: Gen2WorldObject in objects:
		if not object.step_began:
			continue
		object.step_began = false
		if not object.active or object.deleted:
			continue
		if not Gen2WorldCollision.is_grass(collision_code_at(object.cell)):
			continue
		out.append({
			"object_index": object.index,
			"cell": object.cell,
			"frames": maxi(0, object.step_passes_total - 1),
		})
	return out


## Builds the source trainer approach path. The cartridge's
## ComputePathToWalkToPlayer routine emits the longer axis first, with the
## final movement removed by TrainerWalkToPlayer so the trainer stops before
## the player. This helper keeps that path rule deterministic and scene-free.
static func trainer_approach_path(start_cell: Vector2i, target_cell: Vector2i) -> Array:
	var path: Array = []
	var x_delta: int = target_cell.x - start_cell.x
	var y_delta: int = target_cell.y - start_cell.y
	var x_direction: Vector2i = Vector2i.RIGHT if x_delta > 0 else Vector2i.LEFT
	var y_direction: Vector2i = Vector2i.DOWN if y_delta > 0 else Vector2i.UP
	var x_steps: int = abs(x_delta)
	var y_steps: int = abs(y_delta)
	if x_steps >= y_steps:
		for _step: int in x_steps:
			path.append(x_direction)
		for _step: int in y_steps:
			path.append(y_direction)
	else:
		for _step: int in y_steps:
			path.append(y_direction)
		for _step: int in x_steps:
			path.append(x_direction)
	return path


## Starts the scene-free portion of SeenByTrainerScript that follows the
## encounter-music request. The screen owns pacing; the API owns validation,
## emote state and the logical object position.
func start_trainer_approach(
	object_index: int, direction: Vector2i, distance: int
) -> Dictionary:
	var plan: Dictionary = trainer_approach_plan(object_index, direction, distance)
	if not bool(plan.get("ok", false)):
		return plan
	var object: Gen2WorldObject = objects[object_index]
	object.set_emote(TRAINER_SHOCK_EMOTE, true, TRAINER_SHOCK_FRAMES)
	plan["emote_id"] = TRAINER_SHOCK_EMOTE
	plan["emote_frames"] = TRAINER_SHOCK_FRAMES
	plan["step_passes"] = STEP_PASSES_WALK
	return plan


## Returns the source trainer approach target and movement directions without
## mutating the world. A sight distance of one produces the source's empty
## movement buffer and leaves the trainer in place.
func trainer_approach_plan(
	object_index: int, direction: Vector2i, distance: int
) -> Dictionary:
	if current_map == null or object_index < 0 or object_index >= objects.size():
		return {"ok": false, "reason": &"invalid_trainer_object"}
	if direction not in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		return {"ok": false, "reason": &"invalid_trainer_direction"}
	var object: Gen2WorldObject = objects[object_index]
	if object.object_type != Gen2WorldObject.OBJECTTYPE_TRAINER:
		return {"ok": false, "reason": &"not_a_trainer"}
	var target_cell: Vector2i = object.cell
	if distance > 1:
		target_cell = player_cell - direction
	var path: Array = trainer_approach_path(object.cell, target_cell)
	return {
		"ok": true,
		"object_index": object_index,
		"start_cell": object.cell,
		"target_cell": target_cell,
		"path": path,
		"distance": distance,
		"direction": direction,
	}


## Applies one step from an already validated approach plan and starts that
## object's presentation offset for the pacing caller to consume; the object's cell
## is already the destination when this returns. Only the map bounds refuse: the
## approach is `applymovementlasttalked wMovementBuffer` and its steps reach
## NormalStep, which never calls CanObjectMoveInDirection, which is what walks
## Cerulean Gym's swimmers over their own pool. STEP_PASSES_WALK, not the slow row:
## TrainerWalkToPlayer passes 1 in d and `.GetPathToPlayer` hands it to
## ComputePathToWalkToPlayer, whose `ld b, a` selects `.MovementData`'s `step` row.
func advance_trainer_approach_step(object_index: int, direction: Vector2i) -> Dictionary:
	if current_map == null or object_index < 0 or object_index >= objects.size():
		return {"ok": false, "reason": &"invalid_trainer_object"}
	var object: Gen2WorldObject = objects[object_index]
	var destination: Vector2i = object.cell + direction
	object.apply_direction(direction)
	if not _cell_in_bounds(destination):
		return {
			"ok": false, "reason": &"movement_blocked",
			"object_index": object_index, "cell": destination,
		}
	object.cell = destination
	object.start_step(direction, STEP_PASSES_WALK)
	var key: String = _object_key(current_map.group, current_map.number, object_index)
	_object_position_overrides[key] = object.cell
	_object_facing_overrides[key] = object.facing
	return {
		"ok": true, "type": &"trainer_approach_step",
		"object_index": object_index, "cell": object.cell,
		"direction": direction,
	}


## Completes the source writeobjectxy and faceobject portion of the trainer
## intro after the final movement step.
func finish_trainer_approach(object_index: int) -> Dictionary:
	if current_map == null or object_index < 0 or object_index >= objects.size():
		return {"ok": false, "reason": &"invalid_trainer_object"}
	var object: Gen2WorldObject = objects[object_index]
	object.set_emote(TRAINER_SHOCK_EMOTE, false)
	object.facing = _facing_toward(object.cell, player_cell)
	var key: String = _object_key(current_map.group, current_map.number, object_index)
	_object_position_overrides[key] = object.cell
	_object_facing_overrides[key] = object.facing
	player_facing = _facing_toward(player_cell, object.cell)
	return {
		"ok": true, "type": &"trainer_approach_finished",
		"object_index": object_index, "cell": object.cell,
		"facing": object.facing, "player_facing": player_facing,
	}


func set_object_time(hour: int, time_of_day: int) -> void:
	object_hour = clampi(hour, 0, 23)
	object_time_of_day = clampi(time_of_day, 0, 3)
	for object: Gen2WorldObject in objects:
		## The flag half of the test is the one the object table was built with,
		## not the live one: see [member Gen2WorldObject.flag_hidden]. The time
		## half is live, because `CheckObjectTime` runs from the clock callback
		## while the map is up.
		object.active = object.visible_at(object_hour, object_time_of_day) \
			and not object.flag_hidden
		var key: String = _object_key(current_map.group, current_map.number, object.index)
		if _object_visibility_overrides.has(key):
			object.active = bool(_object_visibility_overrides[key])
		if object.deleted:
			object.active = false
	## `CheckObjectTime` runs from the clock callback for whatever is on the
	## screen, and these are on it.
	for entry: Dictionary in _connected_objects:
		var neighbour: Gen2WorldObject = entry["object"]
		neighbour.active = neighbour.visible_at(object_hour, object_time_of_day) \
			and not neighbour.flag_hidden


func set_event_flag(flag: int, active: bool = true) -> void:
	state.set_event_flag(flag, active)


func clear_event_flag(flag: int) -> void:
	state.clear_event_flag(flag)


func event_flag_active(flag: int) -> bool:
	return state.is_event_flag_active(flag)


## The objects a renderer can draw: active, not deleted, and with graphics this
## build imported. Drawing is the only thing that may ask for a sprite; see
## [method active_objects] for everything else.
func visible_objects() -> Array:
	var out: Array = []
	for object: Gen2WorldObject in objects:
		if object.active and not object.deleted and object.sprite != null:
			out.append(object)
	return out


## Every object that is really there, whether or not this build can draw it.
##
## `ReadObjectEvents` builds `wMapObjects` from the map's own event data and
## `LoadSpriteGFX` fills VRAM afterwards, so on the cartridge an object exists
## before, and independently of, its graphics. Collision, interaction, sight and
## NPC movement all walk the object table and none of them asks what loaded.
## Keeping the two apart here is what stops a missing sprite from quietly
## deleting an object out of the world as well as off the screen.
func active_objects() -> Array:
	var out: Array = []
	for object: Gen2WorldObject in objects:
		if object.active and not object.deleted:
			out.append(object)
	return out


## IsNPCAtCoord, which is both the collision test and the interaction lookup.
## A big object answers for any of the four cells it fills, which is what makes
## Vermilion's Snorlax talkable from the cells SnorlaxAwake lists.
func object_at(cell: Vector2i, visible_only: bool = true) -> Gen2WorldObject:
	for object: Gen2WorldObject in objects:
		if not object.occupies(cell) or object.deleted or (visible_only and not object.active):
			continue
		return object
	return null


func block_at(block_x: int, block_y: int) -> int:
	if current_map == null:
		return 0
	return _map_block_at(current_map, block_x, block_y)


func change_block(block_x: int, block_y: int, block: int) -> Dictionary:
	if current_map == null or current_tileset == null:
		return {"ok": false, "reason": &"missing_map"}
	if block_x < 0 or block_y < 0 or block_x >= current_map.width_blocks \
		or block_y >= current_map.height_blocks:
		return {
			"ok": false, "reason": &"invalid_block_cell",
			"cell": Vector2i(block_x, block_y),
		}
	if block < 0 or block >= current_tileset.block_count:
		return {"ok": false, "reason": &"invalid_block", "block": block}
	var key: String = _block_key(current_map, block_x, block_y)
	if block == current_map.block_at(block_x, block_y):
		_block_overrides.erase(key)
	else:
		_block_overrides[key] = block
	block_revision += 1
	return {
		"ok": true,
		"kind": &"block_change",
		"cell": Vector2i(block_x, block_y),
		"block": block,
	}


func command_queues() -> Array:
	var out: Array = []
	for key: Variant in _command_queues:
		out.append((_command_queues[key] as Dictionary).duplicate(true))
	return out


func apply_command_queue_write(bank: int, address: int) -> Dictionary:
	var key: String = "%d:%04X" % [bank, address]
	var queue_id: int = _next_command_queue_id
	_next_command_queue_id += 1
	var queue: Dictionary = {"id": queue_id, "bank": bank, "address": address}
	# The imported payload, so a written queue carries what it does and not only
	# where it came from. A queue the cartridge has no entry for stays pointer
	# only, which is what every type but CMDQUEUE_STONETABLE is.
	if data != null:
		var record: Dictionary = data.world_command_queue(bank, address)
		if not record.is_empty():
			queue["type"] = int(record.get("type", 0))
			queue["rows"] = record.get("rows", [])
	_command_queues[key] = queue
	return {"ok": true, "kind": &"command_queue_written", "queue": _command_queues[key]}


## The one-based warp index `HandleStoneQueue.check_on_warp` counts, or 0 when
## the cell carries no warp event. One-based because the source's
## `.found_warp` answers `count - remaining + 1`.
func warp_index_at(cell: Vector2i) -> int:
	if current_map == null:
		return 0
	var warps: Array = current_map.events.get("warps", [])
	for index: int in warps.size():
		var event: Dictionary = warps[index]
		if int(event.get("x", -1)) == cell.x and int(event.get("y", -1)) == cell.y:
			return index + 1
	return 0


## `CmdQueue_StoneTable` and `HandleStoneQueue`, as one question: which script does
## this boulder's cell fire? The source's own order, all five tests. The object
## must be a Strength boulder, standing on a pit tile, not mid-step, on a warp
## event, and named by a written CMDQUEUE_STONETABLE row for that warp; any refusal
## answers an empty Dictionary. The row's object id is an `object_const_def`
## constant, which starts at 2, so it is compared against the object's own index
## plus two, the same mapping `applymovement` uses.
func stone_queue_script(boulder: Gen2WorldObject) -> Dictionary:
	if boulder == null or not boulder.is_strength_boulder() or boulder.is_stepping():
		return {}
	if not Gen2WorldCollision.is_pit_tile(collision_code_at(boulder.cell)):
		return {}
	var warp: int = warp_index_at(boulder.cell)
	if warp <= 0:
		return {}
	var object_id: int = boulder.index + 2
	for key: Variant in _command_queues:
		var queue: Dictionary = _command_queues[key]
		if int(queue.get("type", 0)) != Gen2WorldScript.CMDQUEUE_STONETABLE:
			continue
		for row: Dictionary in queue.get("rows", []):
			if int(row.get("warp", -1)) != warp or int(row.get("object", -1)) != object_id:
				continue
			# The row scripts were collected under the queue's own bank, which is
			# the map script bank the writecmdqueue ran in.
			return {"bank": int(queue.get("bank", 0)), "script": int(row.get("script", 0))}
	return {}


func apply_command_queue_delete(queue_id: int) -> Dictionary:
	for key: Variant in _command_queues:
		var queue: Dictionary = _command_queues[key]
		if int(queue.get("id", -1)) != queue_id:
			continue
		_command_queues.erase(key)
		return {"ok": true, "kind": &"command_queue_deleted", "queue_id": queue_id}
	return {"ok": true, "kind": &"command_queue_deleted", "queue_id": queue_id, "removed": false}


## The expanded graphics tile at a map-space tile coordinate, or -1 outside
## the map. A map block contains sixteen tiles in row-major order.
func tile_index_at(tile_x: int, tile_y: int) -> int:
	if current_map == null or current_tileset == null:
		return -1
	var map_tile_width: int = current_map.width_blocks * RomLayout.MAP_BLOCK_TILE_WIDTH

	if tile_x < 0 or tile_y < 0 or tile_x >= map_tile_width \
		or tile_y >= current_map.height_blocks * RomLayout.MAP_BLOCK_TILE_WIDTH:
		return -1

	var block: int = block_at(
		floori(float(tile_x) / float(RomLayout.MAP_BLOCK_TILE_WIDTH)),
		floori(float(tile_y) / float(RomLayout.MAP_BLOCK_TILE_WIDTH)),
	)
	var local_tile: int = (tile_y & 3) * RomLayout.MAP_BLOCK_TILE_WIDTH + (tile_x & 3)
	return current_tileset.tile_index(block, local_tile)


## Returns the visible 20x18 graphics-tile page in row-major order. Map padding
## is expanded through [method drawn_block_at], just like LoadMetatiles.
##
## This is [method tile_index_at] for 360 tiles, written out rather than called
## 360 times: it is on the draw path, and the per-tile call did the same block
## division and bounds check for every tile of the same block row.
func visible_tile_indices() -> PackedInt32Array:
	return tile_indices_in_window(
		visible_screen_origin_cell() * RomLayout.MAP_BLOCK_CELL_WIDTH,
		VIEW_TILES,
	)


## Expands an arbitrary graphics-tile window through the same block-buffer path
## as the hardware page. The renderer requests one extra row and column while a
## fractional hSCX/hSCY offset exposes the far edge of the screen.
func tile_indices_in_window(origin: Vector2i, size: Vector2i) -> PackedInt32Array:
	var out := PackedInt32Array()
	if size.x <= 0 or size.y <= 0:
		return out
	out.resize(size.x * size.y)
	out.fill(-1)
	if current_map == null or current_tileset == null:
		return out

	# The window follows the player off the map, so a tile coordinate can be
	# negative and the block divisions have to floor rather than truncate.
	var tile_width: int = RomLayout.MAP_BLOCK_TILE_WIDTH
	for y: int in size.y:
		var tile_y: int = origin.y + y
		var row: int = y * size.x
		var block_y: int = floori(float(tile_y) / float(tile_width))
		var local_row: int = posmod(tile_y, tile_width) * tile_width
		for x: int in size.x:
			var tile_x: int = origin.x + x
			var block: int = drawn_block_at(
				floori(float(tile_x) / float(tile_width)), block_y
			)
			out[row + x] = current_tileset.tile_index(
				block, local_row + posmod(tile_x, tile_width)
			)
	return out


## The block a tile is drawn from, which is not always the block that is there.
##
## `LoadMetatiles` (`home/map.asm:120`) substitutes `wMapBorderBlock` for any
## block byte of `$00`, and the padding `ChangeMap` puts around the map is that
## same border block wherever no connection fills it. Both are graphics only:
## `GetCoordTileCollision` (`home/map.asm:2065`) reads the raw byte and answers
## -1 for `$00`, which is why [method block_at] is left alone and the collision
## path never comes through here.
func drawn_block_at(block_x: int, block_y: int) -> int:
	return drawn_block_for(data, current_map, block_x, block_y, _block_overrides)


## [method drawn_block_at] for a view wider than the hardware's own.
##
## Inside `wOverworldMapBlocks` this is [method drawn_block_at] byte for byte,
## so nothing a 20x18 screen can reach changes. Past it the cartridge holds
## nothing at all, and a view that reaches further would show border block to
## the horizon; the connection graph places whole neighbouring maps there
## instead ([method map_placements]), and the border block still fills what no
## map covers.
func expanded_block_at(block_x: int, block_y: int) -> int:
	if current_map == null:
		return 0
	if in_hardware_buffer(current_map, block_x, block_y):
		return drawn_block_at(block_x, block_y)
	for placement: Dictionary in map_placements().values():
		var map: Gen2WorldMap = placement["map"]
		var origin: Vector2i = placement["origin"]
		var local := Vector2i(block_x - origin.x, block_y - origin.y)
		if local.x < 0 or local.y < 0 \
			or local.x >= map.width_blocks or local.y >= map.height_blocks:
			continue
		var block: int = _overridden_block_at(map, local.x, local.y, _block_overrides)
		return map.border_block if block == 0 else block
	return current_map.border_block


## Whether a block coordinate is one `ChangeMap` writes: the map's own blocks
## plus the three-block margin around them.
static func in_hardware_buffer(map: Gen2WorldMap, block_x: int, block_y: int) -> bool:
	if map == null:
		return false
	return block_x >= -BUFFER_BLOCKS and block_y >= -BUFFER_BLOCKS \
		and block_x < map.width_blocks + BUFFER_BLOCKS \
		and block_y < map.height_blocks + BUFFER_BLOCKS


## Every map the connection graph reaches from the current one, keyed
## `"group:number"`, each with its origin in the current map's block
## coordinates. The current map is not in it: it is the origin.
##
## Built once per map load and kept, since the graph is header data and nothing
## a run does moves a map. Ordered nearest first, so a caller that draws them in
## order draws the far ones under the near ones.
func map_placements() -> Dictionary:
	if _map_placements.is_empty() and current_map != null:
		_map_placements = placements_around(data, current_map)
	return _map_placements


## [method map_placements] for a map that is not the loaded one, which is what a
## test and the importer's own checks have.
static func placements_around(
	data_source: GameData, map: Gen2WorldMap, hops: int = PLACEMENT_HOPS
) -> Dictionary:
	var out: Dictionary = {}
	if data_source == null or map == null:
		return out
	var root: String = "%d:%d" % [map.group, map.number]
	var placed: Dictionary = {root: Vector2i.ZERO}
	var queue: Array = [{"map": map, "origin": Vector2i.ZERO, "hops": 0}]
	var at: int = 0
	while at < queue.size() and out.size() < PLACEMENT_LIMIT:
		var entry: Dictionary = queue[at]
		at += 1
		var source: Gen2WorldMap = entry["map"]
		if int(entry["hops"]) >= hops:
			continue
		for connection: Dictionary in source.connections:
			var target: Gen2WorldMap = data_source.world_map(
				int(connection.get("map_group", -1)),
				int(connection.get("map_number", -1)),
			)
			if target == null:
				continue
			var key: String = "%d:%d" % [target.group, target.number]
			if placed.has(key):
				continue
			var origin: Vector2i = (entry["origin"] as Vector2i) + connection_origin_blocks(
				source, target, connection
			)
			placed[key] = origin
			out[key] = {"map": target, "origin": origin}
			queue.append({"map": target, "origin": origin, "hops": int(entry["hops"]) + 1})
	return out


## Where [param target] sits, in [param source]'s block coordinates, for a
## connection running [param connection] out of [param source].
##
## The four cases are `_connected_drawn_block_at`'s own arithmetic read the
## other way round: it takes a padding block to a cell of the target, and this
## takes the target's own origin to a block of the source. Both come from
## `FillMapConnections`' pointer sums, and having them in one place is what
## keeps a strip and the map behind it from disagreeing by a block.
static func connection_origin_blocks(
	source: Gen2WorldMap, target: Gen2WorldMap, connection: Dictionary
) -> Vector2i:
	## The macro stores the offset in cells, and every strip lookup halves it.
	var along_x: int = -floori(float(int(connection.get("x_offset", 0))) / 2.0)
	var along_y: int = -floori(float(int(connection.get("y_offset", 0))) / 2.0)
	match String(connection.get("direction", "")):
		"north":
			return Vector2i(along_x, -target.height_blocks)
		"south":
			return Vector2i(along_x, source.height_blocks)
		"west":
			return Vector2i(-target.width_blocks, along_y)
		"east":
			return Vector2i(source.width_blocks, along_y)
	return Vector2i.ZERO


## The same fold for a map that is not the loaded one, which is what a battle
## staged on a map has: [Gen2BattleWorldContext] names the map and hands over no
## world, deliberately, so there is no `current_map` to read.
##
## [param block_overrides] is a live `changeblock` table, keyed as
## [method _block_key] keys one. A caller with no world has none, and a map with
## no world has had no block edited.
static func drawn_block_for(
	data_source: GameData,
	map: Gen2WorldMap,
	block_x: int,
	block_y: int,
	block_overrides: Dictionary = {},
) -> int:
	if map == null:
		return 0
	var block: int = -1
	if block_x >= 0 and block_y >= 0 \
		and block_x < map.width_blocks and block_y < map.height_blocks:
		block = _overridden_block_at(map, block_x, block_y, block_overrides)
	else:
		block = _connected_drawn_block_at(
			data_source, map, block_x, block_y, block_overrides
		)
	if block < 0:
		return map.border_block
	return map.border_block if block == 0 else block


## Reads the three-block connection padding assembled by FillMapConnections.
## Its north, south, west, east call order matters at overlapping corners, so
## records are checked backwards and the later east/west strip wins there.
static func _connected_drawn_block_at(
	data_source: GameData,
	map: Gen2WorldMap,
	block_x: int,
	block_y: int,
	block_overrides: Dictionary,
) -> int:
	if data_source == null:
		return -1
	for index: int in range(map.connections.size() - 1, -1, -1):
		var connection: Dictionary = map.connections[index]
		var direction: String = String(connection.get("direction", ""))
		if not _block_is_in_connection_strip(map, block_x, block_y, direction, connection):
			continue
		var target: Gen2WorldMap = data_source.world_map(
			int(connection.get("map_group", -1)),
			int(connection.get("map_number", -1)),
		)
		if target == null:
			continue
		## The strip's own arithmetic is [method connection_origin_blocks] read
		## the other way round: that places the target's origin in this map's
		## blocks, and this takes a padding block to a cell of the target.
		var target_cell: Vector2i = Vector2i(block_x, block_y) \
			- connection_origin_blocks(map, target, connection)
		if target_cell.x < 0 or target_cell.y < 0 \
			or target_cell.x >= target.width_blocks or target_cell.y >= target.height_blocks:
			continue
		return _overridden_block_at(target, target_cell.x, target_cell.y, block_overrides)
	return -1


static func _block_is_in_connection_strip(
	map: Gen2WorldMap, block_x: int, block_y: int, direction: String, connection: Dictionary
) -> bool:
	var in_padding: bool = false
	match direction:
		"north":
			in_padding = block_y >= -3 and block_y < 0
		"south":
			in_padding = block_y >= map.height_blocks \
				and block_y < map.height_blocks + 3
		"west":
			in_padding = block_x >= -3 and block_x < 0
		"east":
			in_padding = block_x >= map.width_blocks \
				and block_x < map.width_blocks + 3
	if not in_padding:
		return false

	# The macro stores `_len - _src`, not merely the target map dimension.
	# Respecting the byte is what reproduces the exact partial strip when a map
	# is offset far enough that either its source or destination begins in the
	# three-block padding. Zero supports old hand-built caches that predate the
	# imported record fields; target bounds still constrain those below.
	var length: int = int(connection.get("length", 0))
	if length <= 0:
		return true
	var horizontal: bool = direction == "north" or direction == "south"
	var stored_offset: int = int(connection.get("x_offset" if horizontal else "y_offset", 0))
	var map_offset_blocks: int = -floori(float(stored_offset) / 2.0)
	var destination_start: int = maxi(map_offset_blocks, -3)
	var along: int = block_x if horizontal else block_y
	return along >= destination_start and along < destination_start + length


func _map_block_at(map: Gen2WorldMap, block_x: int, block_y: int) -> int:
	return _overridden_block_at(map, block_x, block_y, _block_overrides)


static func _overridden_block_at(
	map: Gen2WorldMap, block_x: int, block_y: int, block_overrides: Dictionary
) -> int:
	if not block_overrides.is_empty():
		var key: String = _block_key(map, block_x, block_y)
		if block_overrides.has(key):
			return int(block_overrides[key])
	return map.block_at(block_x, block_y)


## The raw cartridge permission byte at a walk cell.
##
## The imported grid already holds the code the tileset gave each cell, so it is
## the answer unless a changeblock has replaced the block this cell belongs to.
## An overridden block has to be looked up in the tileset instead, because the
## imported grid still describes the block the cartridge shipped.
func collision_code_at(cell: Vector2i) -> int:
	if current_map == null or current_tileset == null:
		return -1
	if _block_overrides.is_empty():
		return current_map.collision_at(cell.x, cell.y)
	var block_x: int = floori(float(cell.x) / float(RomLayout.MAP_BLOCK_CELL_WIDTH))
	var block_y: int = floori(float(cell.y) / float(RomLayout.MAP_BLOCK_CELL_WIDTH))
	var block: int = block_at(block_x, block_y)
	if block == current_map.block_at(block_x, block_y):
		return current_map.collision_at(cell.x, cell.y)
	return current_tileset.collision_index(
		block,
		cell.x & (RomLayout.MAP_BLOCK_CELL_WIDTH - 1),
		cell.y & (RomLayout.MAP_BLOCK_CELL_WIDTH - 1),
	)


func collision_permission_at(cell: Vector2i) -> int:
	return Gen2WorldCollision.permission_for(collision_code_at(cell))


## home/map.asm's GetMovementPermissions for a player standing at [param cell]:
## the standing code's own walled edges plus each neighbour's wall facing back,
## profile-split per Gen2WorldCollision.tile_permissions(). A neighbour outside
## the map answers -1, which side_wall_face_mask() treats as no wall; the
## cartridge would read a border block there, but callers already refuse an
## out-of-map destination before this matters.
func tile_permissions_at(cell: Vector2i) -> int:
	return Gen2WorldCollision.tile_permissions(
		collision_code_at(cell),
		collision_code_at(cell + Vector2i.UP),
		collision_code_at(cell + Vector2i.DOWN),
		collision_code_at(cell + Vector2i.LEFT),
		collision_code_at(cell + Vector2i.RIGHT),
		Gen2WorldState.is_crystal_profile(data),
	)


## Returns the raw warp record at a cell, or an empty Dictionary when the
## player is not standing on one. Warp destinations are one-based in the
## cartridge data, matching the map macro that writes them.
func warp_at(cell: Vector2i = player_cell) -> Dictionary:
	if current_map == null:
		return {}
	for event: Dictionary in current_map.events.get("warps", []):
		if int(event.get("x", -1)) == cell.x and int(event.get("y", -1)) == cell.y:
			return event.duplicate(true)
	return {}


## Returns all decoded event records at a cell in cartridge checking order.
## Script pointers remain data; this method does not interpret them.
func events_at(cell: Vector2i = player_cell) -> Array:
	if current_map == null:
		return []
	var out: Array = []
	for source: String in ["warps", "coord_events", "bg_events", "objects"]:
		var rows: Array = current_map.events.get(source, [])
		for index: int in rows.size():
			var raw: Dictionary = rows[index]
			if int(raw.get("x", -1)) != cell.x or int(raw.get("y", -1)) != cell.y:
				continue
			var event: Dictionary = raw.duplicate(true)
			event["kind"] = StringName(source)
			## Its place in its own list, which is the only stable name a bg
			## event has: [Gen2WorldCatalog] addresses an item under a tile by it.
			event["event_index"] = index
			if source == "objects":
				event["object_index"] = index
			out.append(event)
	return out


## Public event boundary for the screen and future systems. By default it
## reports active decoded records without interpreting cartridge scripts. The
## optional execution flag keeps the old raw-data call stable while exposing
## the queued interpreter to callers that are ready for it.
func dispatch_events(cell: Vector2i = player_cell, execute_scripts: bool = false) -> Array:
	var events: Array = _active_events_at(cell)
	if execute_scripts:
		if _active_script == null and _script_queue.is_empty():
			_enqueue_script_events(events)
		return run_event_queue(false)
	return events


## The step path, `CheckTileEvent` (engine/overworld/events.asm): coordinate
## events only. Background events and object scripts need `CheckAPressOW`, so
## they belong to interact(); a walk onto a cell carrying one runs nothing.
## dispatch_events(cell, true) is the explicit-execution call that still reaches
## every record.
func dispatch_script_events(cell: Vector2i = player_cell) -> Array:
	if _active_script == null and _script_queue.is_empty():
		var stepped: Array = []
		for event: Dictionary in _active_events_at(cell):
			if event.get("kind", &"") == &"coord_events":
				stepped.append(event)
		_enqueue_script_events(stepped)
	return run_event_queue(false)


## Queues the first visible trainer who can see the player, matching the
## cartridge's trainer scan order. A trainer sees only along its facing axis,
## and a nonzero event flag prevents the encounter from being queued.
func dispatch_sight_events() -> Array:
	if _active_script != null or not _script_queue.is_empty():
		return run_event_queue(false)
	var request: Dictionary = _find_sight_request()
	if request.is_empty():
		return []
	_enqueue_script(request)
	return run_event_queue(false)


func script_input_waiting() -> bool:
	return _active_script != null and _active_script.is_waiting()


## True while a script holds the world, either running or still queued. A host
## that drives ambient motion checks this so a script keeps sole ownership of
## the objects it may be moving.
func script_busy() -> bool:
	return _active_script != null or not _script_queue.is_empty()


## Whether the script holding the world is one that stops the map around it.
##
## `ScriptEvents` runs inside `HandleMap`, and `HandleMapObjects` runs on the
## same iteration, so a script standing in `WaitScript` or `WaitScriptMovement`
## leaves every object that is not frozen stepping: `FreezeAllOtherObjects` is
## what stops them, per object, and `applymovement` is its only caller. What
## does stop the whole map is a textbox, a menu or a host screen, each of which
## is a loop of its own that never reaches `HandleMap`.
func script_stops_the_map() -> bool:
	return script_busy() and pending_script_wait().is_empty()


func pending_runtime_request() -> Dictionary:
	return _active_script.pending_runtime_request() if _active_script != null else {}


const PARTY_HOLDER_REQUESTS: Dictionary = {
	&"day_care_requested": &"day_care",
	&"trade_requested": &"trade",
	&"party_heal_requested": &"heal_machine",
}

const PARTY_HOLDER_DAY_CARE_ROLES: Array[StringName] = [&"man", &"lady"]

const PARTY_HOLDER_WAITS: Dictionary = {
	&"heal_machine_anim": &"heal_machine",
}

const PARTY_HOLDER_HALL_OF_FAME: StringName = &"hall_of_fame"


func party_holder() -> StringName:
	var request: Dictionary = pending_runtime_request()
	var kind: StringName = StringName(request.get("kind", &""))
	if kind == &"day_care_requested":
		var values: Dictionary = request.get("values", {})
		return &"day_care" if StringName(values.get("role", &"")) \
			in PARTY_HOLDER_DAY_CARE_ROLES else &""
	if PARTY_HOLDER_REQUESTS.has(kind):
		return PARTY_HOLDER_REQUESTS[kind]
	var wait: Dictionary = pending_script_wait()
	var holder: StringName = PARTY_HOLDER_WAITS.get(StringName(wait.get("kind", &"")), &"")
	if holder == &"heal_machine" \
		and int(wait.get("machine_type", 0)) == Gen2WorldEffects.HEAL_MACHINE_HALL_OF_FAME:
		return PARTY_HOLDER_HALL_OF_FAME
	return holder


func party_with_player() -> bool:
	return String(party_holder()).is_empty()


func pending_script_input() -> Dictionary:
	return _active_script.pending_input() if _active_script != null else {}


## The frame wait a running script is standing in, empty when it is not standing
## in one. Distinct from [method pending_script_input] and
## [method pending_runtime_request] because no host answers it: only frames do,
## through [method advance_script_wait].
func pending_script_wait() -> Dictionary:
	return _active_script.pending_wait() if _active_script != null else {}


## Starts one callback type from the current map's callback table. A type of -1
## runs all callbacks in their stored order.
func dispatch_callbacks(callback_type: int = -1) -> Array:
	if current_map == null:
		return []
	if _active_script == null and _script_queue.is_empty():
		_queue_map_callbacks(callback_type)
	return run_event_queue(false)


## Runs the callbacks that belong to entering the current map. The scene calls this
## once after opening a new or validated snapshot; map transitions already queue
## the same callback set from `_apply_map()`. The scene script is armed only once
## per entry: `MAPSETUP_ENTER` runs it as part of the map load, so a second call is
## a caller dispatching twice rather than a second entry, and replaying the scene
## would walk its `applymovement`s again, which is what put the Dragon Shrine's
## player through the north wall. The callbacks are re-queued, since each is
## written to run whenever the map is refreshed.
func dispatch_map_entry() -> Array:
	if current_map == null:
		return []
	if _active_script == null and _script_queue.is_empty():
		_queue_map_callbacks(-1)
		if not _map_entry_scene_ran:
			_map_entry_scene_pending = true
	var events: Array = run_event_queue(false)
	load_object_masks()
	return events


## `LoadObjectMasks`, which is what actually masks an object rather than
## `ReadObjectEvents`: that one copies every event into `wMapObjects` without
## looking at a flag. `MapSetupScript_Warp` runs `LoadMapAttributes`, then
## `HandleNewMap`, whose `MAPCALLBACK_NEWMAP` is where `ToggleDecorationsVisibility`
## sets the four `EVENT_PLAYERS_HOUSE_2F_*` flags, and only then `LoadMapObjects`,
## which calls this. So a flag a map-entry callback writes is read *after* it is
## written; reading it while the record is built puts the console, both dolls and
## the big doll in the player's bedroom on a new game.
func load_object_masks() -> void:
	_object_masks_pending = false
	for object: Gen2WorldObject in objects:
		object.flag_hidden = object.event_flag_active(state)
	## `LoadObjectMasks` writes one mask byte an object out of `GetObjectTimeMask`
	## and `CheckObjectFlag` together, which is what this already is.
	set_object_time(object_hour, object_time_of_day)


## Starts the first active scripted object in the cell the player is facing.
## This is the explicit interaction boundary for NPCs, signs and item-like
## objects. It never executes a hidden object or invents a fallback action.
func interact() -> Array:
	if _active_script != null or not _script_queue.is_empty():
		return run_event_queue(false)
	var target: Vector2i = facing_cell()
	var events: Array = []
	## TryObjectEvent runs before TryBGEvent in the cartridge event loop. Keep
	## that order even though events_at() exposes the cache's source order.
	## Only the object half looks across a counter: CheckFacingBGEvent and
	## TryTileCollisionEvent both read the plain GetFacingTileCoord, which is
	## what keeps a Pokemon Center PC on the counter itself reachable.
	for event: Dictionary in _active_events_at(object_facing_cell()):
		if event.get("kind", &"") == &"objects" and event.has("script"):
			events.append(event)
	for event: Dictionary in _active_events_at(target):
		if event.get("kind", &"") != &"bg_events":
			continue
		if _bg_event_interacts(event) and _script_address_for_event(event) > 0:
			events.append(event)
	if not events.is_empty():
		_enqueue_script_events(events)
		return run_event_queue(false)
	## TryTileCollisionEvent runs last, only when neither an object nor a
	## background event answered (engine/overworld/events.asm PlayerEvents).
	var tile_request: Dictionary = _tile_collision_script_request(target)
	if tile_request.is_empty():
		## The rest of TryTileCollisionEvent: the five field-move branches, in
		## the source's own order, each of which is a Try*OW gate and an ask.
		tile_request = _field_move_prompt_request(target)
	if tile_request.is_empty():
		return []
	_enqueue_script(tile_request)
	return run_event_queue(false)


## TryTileCollisionEvent from `.cut` on. The faced tile picks the branch, in the
## source's order: a cut tree, then a whirlpool, then a waterfall, then a headbutt
## tree, and `.surf` as the fallback any other tile reaches. Only the tile-shaped
## half of each gate is answered here, because only this layer can read the map;
## the party and the badge belong to the runner, which replays the Ask*Script.
## `.surf` is the one branch that is silent rather than refused when its own tile
## checks fail, so an ordinary wall produces no request at all.
func _field_move_prompt_request(cell: Vector2i) -> Dictionary:
	if current_map == null or current_tileset == null or data == null:
		return {}
	var collision: int = collision_code_at(cell)
	var move_id: int = 0
	var tile_ok: bool = true
	if Gen2WorldFieldMove.cut_tree_tile(collision):
		move_id = Gen2WorldFieldMove.MOVE_CUT
	elif Gen2WorldFieldMove.whirlpool_tile(collision):
		move_id = Gen2WorldFieldMove.MOVE_WHIRLPOOL
		tile_ok = bool(Gen2WorldFieldMove.whirlpool_replacement(
			current_map.tileset, block_at(_script_block_cell(cell).x, _script_block_cell(cell).y)
		).get("ok", false))
	elif Gen2WorldFieldMove.waterfall_tile(collision):
		move_id = Gen2WorldFieldMove.MOVE_WATERFALL
		## CheckMapCanWaterfall is the facing and the tile above, which is this
		## cell only when the player faces up.
		tile_ok = player_facing == Gen2WorldSprite.FACING_UP
	elif Gen2WorldFieldMove.headbutt_tile(collision):
		move_id = Gen2WorldFieldMove.MOVE_HEADBUTT
	elif _surf_prompt_applies(cell):
		move_id = Gen2WorldFieldMove.MOVE_SURF
	if move_id == 0:
		return {}
	return {
		"kind": &"field_move_prompt",
		"map_group": current_map.group,
		"map_number": current_map.number,
		"cell": cell,
		"bank": 0,
		"script": 0,
		"move": move_id,
		"tile_ok": tile_ok,
	}


## TrySurfOW's own checks, less the badge and the party the runner makes: not
## already surfing, facing water, CheckDirection's face mask and the bike flag
## Route 16 and Route 17 set.
func _surf_prompt_applies(cell: Vector2i) -> bool:
	if movement_mode == MOVEMENT_SURF or always_on_bike():
		return false
	if collision_permission_at(cell) != Gen2WorldCollision.WATER_TILE:
		return false
	var face: int = Gen2WorldCollision.face_mask_for_direction(
		_direction_for_facing(player_facing)
	)
	return face == 0 or (tile_permissions_at(player_cell) & face) == 0


## engine/events/std_collision.asm's CheckFacingTileForStdScript. Keyed by the
## faced cell's collision code, not its tile ID despite the source's own
## comment: GetFacingTileCoord returns wTileUp/Down/Left/Right, which
## GetMovementPermissions fills from GetCoordTileCollision. Returns an empty
## Dictionary when the code has no entry in TileCollisionStdScripts.
func _tile_collision_script_request(cell: Vector2i) -> Dictionary:
	if current_map == null or data == null:
		return {}
	var collision: int = collision_code_at(cell)
	var index: int = Gen2WorldCollision.tile_collision_std_index(
		collision, Gen2WorldState.is_crystal_profile(data)
	)
	if index < 0:
		return {}
	var entry: Dictionary = data.world_standard_script(index)
	if entry.is_empty():
		return {}
	return {
		"kind": &"tile_collision",
		"map_group": current_map.group,
		"map_number": current_map.number,
		"cell": cell,
		"bank": int(entry.get("bank", -1)),
		"script": int(entry.get("address", -1)),
	}


## Acknowledge the current text/button pause and continue the first queued
## script. Completed results retain the source event so a screen can react to
## them without reaching into the runner.
func run_event_queue(acknowledge: bool = false, choice: int = -1) -> Array:
	var results: Array = []
	var accept: bool = acknowledge
	var selected_choice: int = choice
	while true:
		if _active_script == null:
			if _script_queue.is_empty():
				if _map_entry_scene_pending:
					_map_entry_scene_pending = false
					_queue_map_scene()
					if not _script_queue.is_empty():
						continue
				if _object_masks_pending:
					load_object_masks()
				break
			var request: Dictionary = _script_queue.pop_front()
			_active_script = Gen2WorldScriptRunner.begin(
				data, state, request, Callable(self, "_validate_script_warp"),
				script_random
			)
		var result: Dictionary = _active_script.advance(accept, selected_choice)
		accept = false
		selected_choice = -1
		if StringName(result.get("status", &"")) == &"waiting":
			results.append(_apply_result_events(result))
			break
		results.append(_finish_script_result(result))
		_clear_active_script()
	return results


## Completes an explicit menu or yes/no host input without allowing a default
## selection to leak into cartridge script state.
func choose_script_input(choice: int) -> Array:
	return run_event_queue(true, choice)


## Cancels the current menu or choice and resumes the queued script with a
## false result. This is distinct from choosing an imported option.
func cancel_script_input() -> Array:
	if _active_script == null:
		return []
	var results: Array = []
	var advanced: Dictionary = _active_script.cancel_input()
	if StringName(advanced.get("status", &"")) == &"waiting":
		results.append(_apply_result_events(advanced))
		return results
	results.append_array(_resume_after(advanced))
	return results


## Completes the currently pending host-owned request and resumes the same
## scene-free script invocation. The world API owns the runner lifecycle, so a
## screen never needs to reach into the runner or replace its state.
func complete_runtime_request(result: Dictionary) -> Array:
	if _active_script == null:
		return []
	var results: Array = []
	var advanced: Dictionary = _active_script.complete_runtime_request(result)
	if StringName(advanced.get("status", &"")) == &"waiting":
		results.append(_apply_result_events(advanced))
		return results
	if StringName(advanced.get("status", &"")) == &"recovered":
		results.append(advanced)
		_clear_active_script()
		_script_queue.clear()
		return results
	results.append_array(_resume_after(advanced))
	return results


## Closes out a resumed invocation and runs whatever was queued behind it. Both
## resume boundaries, a cancelled input and a completed host request, end the
## same way, and the terminal result must not be finished twice.
func _resume_after(advanced: Dictionary) -> Array:
	var results: Array = []
	results.append(
		_finish_script_result(advanced) if bool(advanced.get("ok", false)) else advanced
	)
	_clear_active_script()
	results.append_array(_drain_script_queue())
	return results


## Starts each queued script in turn and stops at the first one that waits for the
## host. A warp applied while resuming a host request leaves the destination's map
## scene pending exactly as one applied inside [method run_event_queue] does, so
## this has to pick it up too. Boarding the S.S. Aqua is where that shows:
## `OlivinePortSailorAtGangwayScript` warps mid-script and the ship's own
## `FastShip1FEnterShipScript` walks the player away from the door, so dropping it
## left the player boxed in against the sailor who blocks it.
func _drain_script_queue() -> Array:
	var results: Array = []
	while _active_script == null:
		if _script_queue.is_empty():
			if not _map_entry_scene_pending:
				break
			_map_entry_scene_pending = false
			_queue_map_scene()
			if _script_queue.is_empty():
				break
		var request: Dictionary = _script_queue.pop_front()
		_active_script = Gen2WorldScriptRunner.begin(
			data, state, request, Callable(self, "_validate_script_warp"),
			script_random
		)
		var next: Dictionary = _active_script.advance()
		if StringName(next.get("status", &"")) == &"waiting":
			results.append(_apply_result_events(next))
			break
		results.append(_finish_script_result(next) if bool(next.get("ok", false)) else next)
		_clear_active_script()
	return results


## `StopScript` leaves nothing frozen behind it: `ApplyMovement`'s freeze is
## released by the wait it staged, and a script that ends or is abandoned before
## that wait completes would otherwise leave the map standing still for good.
func _clear_active_script() -> void:
	_active_script = null
	unfreeze_all_objects()


func _active_events_at(cell: Vector2i) -> Array:
	var out: Array = []
	for event: Dictionary in events_at(cell):
		# Object records below are matched against their live cells. A source
		# movement or trainer approach can move one away from its cached cell.
		if event.get("kind", &"") == &"objects":
			continue
		if event.get("kind", &"") == &"bg_events" \
			and not _bg_event_condition_active(event):
			continue
		elif event.get("kind", &"") == &"coord_events" \
			and not _coord_event_condition_active(event):
			continue
		out.append(event)
	if current_map == null:
		return out
	var rows: Array = current_map.events.get("objects", [])
	for object: Gen2WorldObject in objects:
		# occupies() rather than the cell, so a big object answers from any of
		# the four it fills the way IsNPCAtCoord does.
		if not object.active or not object.occupies(cell) \
			or object.index < 0 or object.index >= rows.size() \
			or not rows[object.index] is Dictionary:
			continue
		var event: Dictionary = (rows[object.index] as Dictionary).duplicate(true)
		event["x"] = object.cell.x
		event["y"] = object.cell.y
		event["kind"] = &"objects"
		event["object_index"] = object.index
		out.append(event)
	return out


func _enqueue_script_events(events: Array) -> void:
	var bank: int = int(current_map.events.get("bank", 0)) if current_map != null else 0
	for event: Dictionary in events:
		if event.get("kind", &"") == &"warps" or not event.has("script"):
			continue
		var script_address: int = _script_address_for_event(event)
		if script_address <= 0:
			continue
		var request: Dictionary = {
			"kind": event.get("kind", &""),
			"map_group": current_map.group,
			"map_number": current_map.number,
			"cell": Vector2i(int(event.get("x", 0)), int(event.get("y", 0))),
			"bank": bank,
			"script": script_address,
			"event": event.duplicate(true),
		}
		# hLastTalked, which GetFacingObject writes before an object's script
		# runs. Without it every `disappear LAST_TALKED` in an ordinary object
		# script resolves to object -1: the trainer and item-ball requests below
		# carry their own, so only the plain object case was missing one.
		if event.get("kind", &"") == &"objects" and event.has("object_index"):
			request["object_index"] = int(event["object_index"])
		var trainer_request: Dictionary = _trainer_request_for_event(event)
		if not trainer_request.is_empty():
			request = trainer_request
		var item_ball_request: Dictionary = _item_ball_request_for_event(event)
		if not item_ball_request.is_empty():
			request = item_ball_request
		var hidden_item_request: Dictionary = _hidden_item_request_for_event(event)
		if not hidden_item_request.is_empty():
			request = hidden_item_request
		_enqueue_script(request)


## ObjectEventTypeArray's `.itemball` (engine/overworld/events.asm): an item
## ball's script pointer is not a script. The two bytes it points at are the
## `itemball` macro's `db item, quantity`, copied into `wItemBallData`, and what
## runs is PLAYEREVENT_ITEMBALL's FindItemInBallScript. Decoding them here is
## what keeps the runner from parsing item data as opcodes.
func _item_ball_request_for_event(event: Dictionary) -> Dictionary:
	if event.get("kind", &"") != &"objects" or current_map == null or data == null:
		return {}
	var object_index: int = int(event.get("object_index", -1))
	if object_index < 0 or object_index >= objects.size():
		return {}
	var object: Gen2WorldObject = objects[object_index]
	if object.object_type != Gen2WorldObject.OBJECTTYPE_ITEMBALL:
		return {}
	var pointer: int = int(event.get("script", object.event_script))
	if pointer <= 0:
		return {}
	var bank: int = int(current_map.events.get("bank", 0))
	var raw: PackedByteArray = data.world_script(bank, pointer)
	if raw.size() < 2 or int(raw[0]) <= 0:
		return {}
	## The catalog addresses a ball by its map and its object index, so a mod
	## that moved what is in it is read here rather than in the runner: these two
	## bytes are data, not a command anything executes.
	var patched: Dictionary = _catalogued_item(object_index, int(raw[0]), maxi(1, int(raw[1])))
	return {
		"kind": &"item_ball",
		"map_group": current_map.group,
		"map_number": current_map.number,
		"cell": object.cell,
		"bank": bank,
		"script": pointer,
		"object_index": object.index,
		"event": event.duplicate(true),
		"item": int(patched["item"]),
		"quantity": int(patched["quantity"]),
	}


## One item site's row from [Gen2WorldCatalog], by the map event it is. Answers
## the cartridge's own numbers when no mod has moved it.
func _catalogued_item(event_index: int, item: int, quantity: int) -> Dictionary:
	var fallback: Dictionary = {"item": item, "quantity": quantity}
	if data == null or current_map == null or not data.has_content_overlay():
		return fallback
	var row: Dictionary = data.catalog().check(Gen2WorldCatalog.pack_event_id(
		Gen2WorldCatalog.KIND_ITEM, current_map.group, current_map.number, event_index
	))
	if row.is_empty():
		return fallback
	return {"item": int(row["item"]), "quantity": maxi(1, int(row["quantity"]))}


## `.itemifset`'s own record (engine/overworld/events.asm): a BGEVENT_ITEM
## pointer is not a script either. The three bytes it points at are the
## `hiddenitem` macro's `dwb event, item`, copied into wHiddenItemData before
## HiddenItemScript runs, so the flag comes first as a little-endian word and
## the item last. Decoding them here is what keeps the runner from parsing item
## data as opcodes, exactly as _item_ball_request_for_event() does.
func _hidden_item_record(event: Dictionary) -> Dictionary:
	if data == null or current_map == null:
		return {"ok": false, "reason": &"missing_bg_event_context"}
	var pointer: int = int(event.get("script", 0))
	if pointer <= 0:
		return {"ok": false, "reason": &"invalid_hidden_item", "pointer": pointer}
	var raw: PackedByteArray = data.world_script(
		int(current_map.events.get("bank", 0)), pointer
	)
	if raw.size() < 3 or int(raw[2]) <= 0:
		return {"ok": false, "reason": &"invalid_hidden_item", "pointer": pointer}
	## A hidden item is indexed after the map's objects, which is the order the
	## catalog walked them in. Its own event flag is the site's completion and is
	## never a patch.
	var index: int = (current_map.events.get("objects", []) as Array).size() \
		+ maxi(0, int(event.get("event_index", 0)))
	return {
		"ok": true,
		"flag": int(raw[0]) | (int(raw[1]) << 8),
		"item": int(_catalogued_item(index, int(raw[2]), 1)["item"]),
	}


func _hidden_item_request_for_event(event: Dictionary) -> Dictionary:
	if event.get("kind", &"") != &"bg_events" or current_map == null:
		return {}
	if int(event.get("type", -1)) != BGEVENT_ITEM:
		return {}
	var record: Dictionary = _hidden_item_record(event)
	if not bool(record.get("ok", false)):
		return {}
	return {
		"kind": &"hidden_item",
		"map_group": current_map.group,
		"map_number": current_map.number,
		"cell": Vector2i(int(event.get("x", 0)), int(event.get("y", 0))),
		"bank": int(current_map.events.get("bank", 0)),
		"script": int(event.get("script", 0)),
		"event": event.duplicate(true),
		"item": int(record["item"]),
		"flag": int(record["flag"]),
	}


func _trainer_request_for_event(event: Dictionary) -> Dictionary:
	if event.get("kind", &"") != &"objects" or current_map == null:
		return {}
	var object_index: int = int(event.get("object_index", -1))
	if object_index < 0 or object_index >= objects.size():
		return {}
	var object: Gen2WorldObject = objects[object_index]
	if object.object_type != Gen2WorldObject.OBJECTTYPE_TRAINER \
		or object.trainer_data.is_empty():
		return {}
	var trainer: Dictionary = object.trainer_data.duplicate(true)
	var beaten: bool = object.trainer_flag_active(state)
	var script_address: int = int(trainer.get("after_script", 0)) if beaten \
		else int(event.get("script", object.event_script))
	if script_address <= 0:
		return {}
	var request: Dictionary = {
		"kind": &"trainer",
		"map_group": current_map.group,
		"map_number": current_map.number,
		"cell": object.cell,
		"bank": int(current_map.events.get("bank", 0)),
		"script": script_address,
		"object_index": object.index,
		"event": event.duplicate(true),
		"trainer": trainer,
		"trainer_phase": &"after" if beaten else &"initial",
	}
	request["event"]["trainer"] = trainer.duplicate(true)
	return request


func _bg_event_interacts(event: Dictionary) -> bool:
	var event_type: int = int(event.get("type", -1))
	match event_type:
		## `.itemifset` checks its flag and reads; unlike `.up`/`.down`/`.left`/
		## `.right` it never looks at wPlayerDirection.
		BGEVENT_READ, BGEVENT_IFSET, BGEVENT_IFNOTSET, BGEVENT_ITEM:
			return true
		BGEVENT_UP:
			return player_facing == Gen2WorldSprite.FACING_UP
		BGEVENT_DOWN:
			return player_facing == Gen2WorldSprite.FACING_DOWN
		BGEVENT_LEFT:
			return player_facing == Gen2WorldSprite.FACING_LEFT
		BGEVENT_RIGHT:
			return player_facing == Gen2WorldSprite.FACING_RIGHT
	return false


func _bg_event_condition_active(event: Dictionary) -> bool:
	var event_type: int = int(event.get("type", -1))
	## `.itemifset` opens with CheckBGEventFlag and `jp nz, .dontread`, so a
	## hidden item answers only while its own flag is still clear.
	if event_type == BGEVENT_ITEM:
		var hidden: Dictionary = _hidden_item_record(event)
		return bool(hidden.get("ok", false)) and not event_flag_active(int(hidden["flag"]))
	if event_type not in [BGEVENT_IFSET, BGEVENT_IFNOTSET]:
		return true
	var conditional: Dictionary = _bg_event_condition(event)
	if not bool(conditional.get("ok", false)):
		return false
	var active: bool = event_flag_active(int(conditional["flag"]))
	return active if event_type == BGEVENT_IFSET else not active


func _bg_event_condition(event: Dictionary) -> Dictionary:
	if data == null or current_map == null:
		return {"ok": false, "reason": &"missing_bg_event_context"}
	var pointer: int = int(event.get("script", 0))
	var raw: PackedByteArray = data.world_script(
		int(current_map.events.get("bank", 0)), pointer
	)
	if raw.size() < 4:
		return {"ok": false, "reason": &"invalid_bg_event_condition", "pointer": pointer}
	return {
		"ok": true,
		"flag": int(raw[0]) | (int(raw[1]) << 8),
		"script": int(raw[2]) | (int(raw[3]) << 8),
	}


func _script_address_for_event(event: Dictionary) -> int:
	if event.get("kind", &"") != &"bg_events":
		return int(event.get("script", 0))
	var event_type: int = int(event.get("type", -1))
	if event_type in [BGEVENT_IFSET, BGEVENT_IFNOTSET]:
		if not _bg_event_condition_active(event):
			return -1
		return int(_bg_event_condition(event).get("script", -1))
	if event_type in [BGEVENT_READ, BGEVENT_UP, BGEVENT_DOWN, BGEVENT_RIGHT, BGEVENT_LEFT]:
		return int(event.get("script", 0))
	## An ITEM pointer is item data, not code; the address only has to be
	## non-zero for _enqueue_script() to take the request built beside it.
	if event_type == BGEVENT_ITEM and _bg_event_condition_active(event):
		return int(event.get("script", 0))
	return -1


func _enqueue_script(request: Dictionary) -> void:
	## The two queued requests with no address of their own, both of which the
	## runner synthesizes a body for the way it does for an item ball: a
	## field-move prompt, whose Ask*Script the source reaches through CallScript
	## on a link-time address the pins do not resolve, and a mod's item gift,
	## which no script anywhere makes.
	if int(request.get("script", 0)) <= 0 \
		and StringName(request.get("kind", &"")) not in [&"field_move_prompt", &"item_gift"]:
		return
	if not request.has("collision"):
		var cell_value: Variant = request.get("cell", player_cell)
		var cell: Vector2i = cell_value if cell_value is Vector2i else player_cell
		request["collision"] = collision_code_at(cell)
	if not request.has("clock"):
		request["clock"] = world_clock()
	if current_map != null and not request.has("environment"):
		request["environment"] = current_map.environment
	if not request.has("facing"):
		request["facing"] = player_facing
	if not request.has("player_cell"):
		## `wXCoord`/`wYCoord`. Distinct from "cell", which is whichever cell the
		## script hangs off: a background event's faced tile or an object's own
		## square. SnorlaxAwake wants where the player is standing.
		request["player_cell"] = player_cell
	## wPlayerID, which `ReadCaughtData` compares a row's OT ID against.
	if not request.has("player_id") and _player_id >= 0:
		request["player_id"] = _player_id
	if not request.has("party") and not _party_summary.is_empty():
		request["party"] = _party_summary.duplicate()
	if not request.has("field_move_items"):
		var alternates: Dictionary = _field_move_items()
		if not alternates.is_empty():
			request["field_move_items"] = alternates
	if not request.has("player_name") and not _player_name.is_empty():
		request["player_name"] = _player_name
	if not request.has("object_event_flags"):
		request["object_event_flags"] = _object_event_flags()
	_script_queue.append(request)


## The runner reads `CheckPartyMove` off the party mirror and can reach neither
## the bag nor the mod host, so an item standing in for an HM is resolved here.
func _field_move_items() -> Dictionary:
	var alternates: Dictionary = {}
	for move_id: int in Gen2WorldFieldMove.HM_FIELD_MOVES:
		var item: int = item_field_move_source(move_id)
		if item > 0:
			alternates[move_id] = item
	return alternates


## `disappear` and `appear` write an object's event flag inside the script, so
## the runner, holding no object table, is handed one flag per object index.
func _object_event_flags() -> Array[int]:
	var flags: Array[int] = []
	for object: Gen2WorldObject in objects:
		flags.append(object.event_flag)
	return flags



func _queue_map_callbacks(callback_type: int) -> void:
	if current_map == null:
		return
	var bank: int = int(current_map.scripts.get("bank", 0))
	for callback: Dictionary in current_map.scripts.get("callbacks", []):
		if callback_type >= 0 and int(callback.get("type", -1)) != callback_type:
			continue
		_enqueue_script({
			"kind": &"callback",
			"callback_type": int(callback.get("type", -1)),
			"map_group": current_map.group,
			"map_number": current_map.number,
			"bank": bank,
			"script": int(callback.get("script", 0)),
		})


func _queue_map_scene() -> void:
	if current_map == null:
		return
	_map_entry_scene_ran = true
	var scenes: Array = current_map.scripts.get("scenes", [])
	if scenes.is_empty():
		return
	var current_scene: int = state.map_scene(current_map.group, current_map.number)
	for scene: Dictionary in scenes:
		if int(scene.get("id", -1)) != current_scene:
			continue
		_enqueue_script({
			"kind": &"scene",
			"map_group": current_map.group,
			"map_number": current_map.number,
			"scene": current_scene,
			"bank": int(current_map.scripts.get("bank", 0)),
			"script": int(scene.get("script", 0)),
		})
		break


func _coord_event_condition_active(event: Dictionary) -> bool:
	var scenes: Array = current_map.scripts.get("scenes", []) if current_map != null else []
	if scenes.is_empty():
		return true
	return int(event.get("scene", -1)) == state.map_scene(current_map.group, current_map.number)


## Script event to the method that applies it, each taking the event and
## answering the events it generated.
const SCRIPT_EVENT_HANDLERS: Dictionary = {
	&"warp_check_requested": &"_script_warp_check",
	&"player_facing_requested": &"_script_player_facing",
	&"player_movement_requested": &"_apply_player_movement",
	&"object_movement_requested": &"_apply_object_movement",
	&"object_write_position": &"_script_write_object_position",
	&"map_block_changed": &"_script_change_block",
	&"map_reload_requested": &"_script_reload_map",
	&"map_refresh_requested": &"_script_refresh_map",
	&"bug_contest_started": &"_script_start_bug_contest",
	&"bug_contestants_selected": &"_script_select_contestants",
	&"contest_mons_dropped_off": &"_script_contest_drop_off",
	&"contest_mons_returned": &"_script_contest_return",
	&"warp_to_spawn_point": &"_script_warp_to_spawn",
	&"wild_encounters_changed": &"_script_wild_encounters",
	&"command_queue_written": &"_script_queue_write",
	&"command_queue_deleted": &"_script_queue_delete",
	&"object_follow": &"_script_object_follow",
	&"object_stop_follow": &"_script_object_stop_follow",
	&"player_face_object": &"_script_player_face_object",
}

## The three that edit the loaded object itself, all behind the same bounds test.
const LOCAL_OBJECT_EVENTS: Array[StringName] = [
	&"object_deleted", &"object_emote", &"object_event_flag",
]

## The five that record an override the next object load reads.
const OBJECT_OVERRIDE_EVENTS: Array[StringName] = [
	&"object_visibility", &"object_position", &"object_facing",
	&"object_face_player", &"object_face_object",
]


func _apply_script_object_events(raw_events: Variant) -> Array:
	var generated: Array = []
	if not raw_events is Array:
		return generated
	var reload_objects: bool = false
	for raw_event: Variant in raw_events as Array:
		if not raw_event is Dictionary:
			continue
		var event: Dictionary = raw_event as Dictionary
		var type: StringName = StringName(event.get("type", &""))
		if SCRIPT_EVENT_HANDLERS.has(type):
			generated.append_array(call(SCRIPT_EVENT_HANDLERS[type], event) as Array)
		elif type == &"variable_sprite_changed":
			var slot: int = int(event.get("variable_sprite", -1))
			var sprite: int = int(event.get("sprite", 0))
			if slot < Gen2WorldScriptRunner.VARIABLE_SPRITE_BASE or sprite <= 0:
				generated.append({"type": &"variable_sprite_change_failed"})
				continue
			state.set_variable_sprite(slot, sprite)
			## The table is `wPlayerData`, not the loaded map, so the people
			## SCREEN FILL draws on the maps next door resolve through it too.
			_connected_objects = []
			reload_objects = true
			generated.append({
				"type": &"variable_sprite_changed",
				"variable_sprite": slot, "sprite": sprite,
			})
		elif type in LOCAL_OBJECT_EVENTS:
			generated.append_array(_apply_local_object_event(type, event))
		elif type in OBJECT_OVERRIDE_EVENTS:
			reload_objects = _apply_object_override(type, event) or reload_objects
	if reload_objects and current_map != null:
		_load_objects(true)
	return generated


## Script_warpcheck asks whether the player is standing on a warp and takes it if
## so, which is how the Burned Tower rival scene drops the player through the
## hole it just opened. A cell with no warp answers nothing, exactly as
## WarpCheck's carry does.
func _script_warp_check(_event: Dictionary) -> Array:
	var checked: Dictionary = try_warp()
	return [{
		"type": &"warp_check",
		"taken": bool(checked.get("ok", false)),
		"transition": checked.duplicate(true),
	}]


## Script_warpfacing writes the player's facing before the warp and the map load
## never touches it, so the facing outlives the transition. Lance's room is where
## it shows: `warpfacing UP` is what the player enters the Hall of Fame facing.
func _script_player_facing(event: Dictionary) -> Array:
	player_facing = int(event.get("facing", player_facing))
	return [{"type": &"player_facing", "facing": player_facing}]


func _script_write_object_position(event: Dictionary) -> Array:
	var index: int = int(event.get("object_index", Gen2WorldObject.NONE_INDEX))
	if index == Gen2WorldObject.PLAYER_INDEX \
		or not _event_names_loaded_object(event, index):
		return [{"type": &"object_change_failed", "reason": &"invalid_object"}]
	var key: String = _object_key(
		int(event.get("map_group", -1)), int(event.get("map_number", -1)), index
	)
	_object_position_overrides[key] = (objects[index] as Gen2WorldObject).cell
	return [{
		"type": &"object_position_written",
		"object_index": index, "cell": _object_position_overrides[key],
	}]


func _script_change_block(event: Dictionary) -> Array:
	if current_map == null or int(event.get("map_group", -1)) != current_map.group \
		or int(event.get("map_number", -1)) != current_map.number:
		return [{"type": &"map_change_failed", "reason": &"invalid_map"}]
	var source_cell := Vector2i(int(event.get("x", -1)), int(event.get("y", -1)))
	var block_cell: Vector2i = _script_block_cell(source_cell)
	var changed: Dictionary = change_block(
		block_cell.x, block_cell.y, int(event.get("block", -1))
	)
	if not bool(changed.get("ok", false)):
		return [{
			"type": &"map_change_failed",
			"reason": changed.get("reason", &"invalid_block"),
			"source_cell": source_cell,
			"block_cell": block_cell,
		}]
	changed["source_cell"] = source_cell
	return [{"type": &"map_block_changed", "change": changed}]


func _script_reload_map(_event: Dictionary) -> Array:
	return [reload_current_map()]


func _script_refresh_map(_event: Dictionary) -> Array:
	return [{"type": &"map_refreshed", "map": map_id()}]


func _script_start_bug_contest(_event: Dictionary) -> Array:
	return [start_bug_contest()]


func _script_select_contestants(_event: Dictionary) -> Array:
	var withdrawn: Dictionary = Gen2WorldBugContest.select_withdrawn(
		schedule_random if schedule_random != null else RandomNumberGenerator.new()
	)
	for index: int in Gen2WorldBugContest.NUM_CONTESTANTS:
		state.set_event_flag(
			Gen2WorldState.EVENT_BUG_CATCHING_CONTESTANT_FIRST + index,
			bool(withdrawn.get(index, false))
		)
	return [{"type": &"bug_contestants_selected", "withdrawn": withdrawn.keys()}]


func _script_contest_drop_off(event: Dictionary) -> Array:
	state.set_contest_second_party_species(int(event.get("second_species", 0)))
	return [{
		"type": &"contest_mons_dropped_off",
		"second_species": state.contest_second_party_species(),
	}]


func _script_contest_return(_event: Dictionary) -> Array:
	state.set_contest_second_party_species(0)
	return [{"type": &"contest_mons_returned"}]


func _script_warp_to_spawn(_event: Dictionary) -> Array:
	warp_to_spawn_point()
	return [{"type": &"warp_to_spawn_point"}]


func _script_wild_encounters(event: Dictionary) -> Array:
	var enabled: bool = bool(event.get("enabled", true))
	state.set_wild_encounters_off(not enabled)
	return [{"type": &"wild_encounters_changed", "enabled": enabled}]


func _script_queue_write(event: Dictionary) -> Array:
	return [apply_command_queue_write(
		int(event.get("bank", 0)), int(event.get("address", 0))
	)]


func _script_queue_delete(event: Dictionary) -> Array:
	return [apply_command_queue_delete(int(event.get("queue_id", -1)))]


## `wObjectFollow_Leader` and `wObjectFollow_Follower` are one byte each, so a
## second `follow` replaces the pair rather than adding to it.
func _script_object_follow(event: Dictionary) -> Array:
	_start_object_follow(event)
	return []


func _script_object_stop_follow(_event: Dictionary) -> Array:
	_object_followers.clear()
	return []


func _script_player_face_object(event: Dictionary) -> Array:
	var target: int = int(event.get("target_index", Gen2WorldObject.NONE_INDEX))
	if target >= 0 and _event_names_loaded_object(event, target):
		player_facing = _facing_toward(
			player_cell, (objects[target] as Gen2WorldObject).cell
		)
	return []


## Whether [param event] names the loaded map and an actor on it: an object in
## range, or the player. An event that edits one is refused rather than applied
## to whatever sits at that index on another map.
func _event_names_loaded_object(event: Dictionary, index: int) -> bool:
	if current_map == null \
		or int(event.get("map_group", -1)) != current_map.group \
		or int(event.get("map_number", -1)) != current_map.number:
		return false
	return index == Gen2WorldObject.PLAYER_INDEX \
		or (index >= 0 and index < objects.size())


func _object_record(index: int) -> Gen2WorldObject:
	if index == Gen2WorldObject.PLAYER_INDEX:
		return _player_object
	return objects[index] if index >= 0 and index < objects.size() else null


func _apply_local_object_event(type: StringName, event: Dictionary) -> Array:
	var index: int = int(event.get("object_index", Gen2WorldObject.NONE_INDEX))
	if not _event_names_loaded_object(event, index):
		return [{"type": &"object_change_failed", "reason": &"invalid_object"}]
	var object: Gen2WorldObject = _object_record(index)
	match type:
		&"object_deleted":
			object.deleted = true
			object.active = false
			_object_followers.erase(_object_key(
				int(event.get("map_group", -1)), int(event.get("map_number", -1)), index
			))
			return [{"type": &"object_deleted", "object_index": index}]
		&"object_emote":
			object.set_emote(
				int(event.get("emote_id", -1)), bool(event.get("visible", false)),
				int(event.get("duration", 0))
			)
		&"object_event_flag":
			if object.event_flag > 0:
				state.set_event_flag(object.event_flag, bool(event.get("active", false)))
	return []


## Records what the next object load reads back, and answers whether one is due.
func _apply_object_override(type: StringName, event: Dictionary) -> bool:
	var map_group: int = int(event.get("map_group", -1))
	var map_number: int = int(event.get("map_number", -1))
	var index: int = int(event.get("object_index", Gen2WorldObject.NONE_INDEX))
	if index == Gen2WorldObject.PLAYER_INDEX:
		return _apply_player_override(type, event)
	if index < 0:
		return false
	var key: String = _object_key(map_group, map_number, index)
	var names_loaded: bool = _event_names_loaded_object(event, index)
	match type:
		&"object_visibility":
			_object_visibility_overrides[key] = bool(event.get("active", false))
			if index < objects.size() \
				and (objects[index] as Gen2WorldObject).event_flag <= 0:
				_transient_object_visibility_overrides[key] = true
			else:
				_transient_object_visibility_overrides.erase(key)
		&"object_position":
			var cell: Variant = event.get("cell", Vector2i.ZERO)
			if not cell is Vector2i:
				return false
			_object_position_overrides[key] = cell
		&"object_facing":
			_object_facing_overrides[key] = clampi(
				int(event.get("facing", Gen2WorldSprite.FACING_DOWN)),
				Gen2WorldSprite.FACING_DOWN, Gen2WorldSprite.FACING_RIGHT
			)
		&"object_face_player":
			if names_loaded:
				_object_facing_overrides[key] = _facing_toward(
					(objects[index] as Gen2WorldObject).cell, player_cell
				)
		&"object_face_object":
			var target: int = int(event.get("target_index", -1))
			if names_loaded and target >= 0 and target < objects.size():
				_object_facing_overrides[key] = _facing_toward(
					(objects[index] as Gen2WorldObject).cell,
					(objects[target] as Gen2WorldObject).cell
				)
	return true


## The same writes against object zero. Nothing is recorded for the next object
## load, and `ApplyEventActionAppearDisappear` finds the player's event flag is
## -1, so `disappear PLAYER` has no flag half either.
func _apply_player_override(type: StringName, event: Dictionary) -> bool:
	if not _event_names_loaded_object(event, Gen2WorldObject.PLAYER_INDEX):
		return false
	match type:
		&"object_visibility":
			_player_object.deleted = not bool(event.get("active", false))
		&"object_position":
			var cell: Variant = event.get("cell", Vector2i.ZERO)
			if not cell is Vector2i:
				return false
			player_cell = cell
		&"object_facing":
			player_facing = clampi(
				int(event.get("facing", Gen2WorldSprite.FACING_DOWN)),
				Gen2WorldSprite.FACING_DOWN, Gen2WorldSprite.FACING_RIGHT
			)
		&"object_face_object":
			var target: int = int(event.get("target_index", Gen2WorldObject.NONE_INDEX))
			if target >= 0 and target < objects.size():
				player_facing = _facing_toward(
					player_cell, (objects[target] as Gen2WorldObject).cell
				)
	return false


func _movement_stream(event: Dictionary) -> PackedByteArray:
	if event.has("movement"):
		return PackedByteArray(event["movement"])
	return data.world_movement(
		int(event.get("bank", 0)), int(event.get("address", 0))
	)


func _apply_object_movement(event: Dictionary) -> Array:
	var generated: Array = []
	var map_group: int = int(event.get("map_group", -1))
	var map_number: int = int(event.get("map_number", -1))
	var object_index: int = int(event.get("object_index", -1))
	if current_map == null or map_group != current_map.group or map_number != current_map.number \
		or object_index < 0 or object_index >= objects.size():
		generated.append({"type": &"movement_failed", "reason": &"invalid_object"})
		return generated
	var decoded: Dictionary = Gen2WorldMovement.decode(_movement_stream(event))
	if not bool(decoded.get("ok", false)):
		generated.append({
			"type": &"movement_failed", "reason": decoded.get("reason", &"invalid_movement"),
			"object_index": object_index,
		})
		return generated
	var object: Gen2WorldObject = objects[object_index]
	var key: String = _object_key(map_group, map_number, object_index)
	## `ApplyMovement` freezes the map around the object it is about to walk,
	## and the wait this command stages is what thaws it again.
	freeze_all_other_objects(object_index)
	## Where the stream leaves the object looking. The drawn facing trails the
	## walk one step at a time, so the record the next map load restores is this
	## rather than whichever step is on screen when the stream is applied.
	var final_facing: int = object.facing
	for command: Dictionary in decoded.get("commands", []):
		var kind: StringName = StringName(command.get("kind", &""))
		if kind in SCRIPTED_TURN_KINDS:
			## Queued rather than applied, so a turn behind a walk turns where
			## the walk ends. `queue_step` drains an entry of no frames itself.
			var turn: Vector2i = _movement_direction(int(command.get("direction", 0)))
			object.queue_step(Vector2i.ZERO, 0, false, turn)
			final_facing = facing_for_direction(turn)
			continue
		if SCRIPTED_STEP_PASSES.has(kind):
			var direction: Vector2i = _movement_direction(int(command.get("direction", 0)))
			var jumping: bool = kind in JUMP_STEP_KINDS
			var cells: int = 2 if jumping else 1
			var destination: Vector2i = object.cell + direction * cells
			final_facing = facing_for_direction(direction)
			if _cell_in_bounds(destination):
				var vacated: Vector2i = object.cell
				object.cell = destination
				# The cell commits here, as it does for every other step in this
				# runtime; only the drawing trails. A stream applies in one call,
				# so the whole path is queued and drawn a step at a time by
				# advance_scripted_steps_pass().
				object.queue_step(
					direction * cells, int(SCRIPTED_STEP_PASSES[kind]) * cells, jumping,
					direction, kind,
				)
				_advance_followers(object_index, vacated)
			else:
				## `NormalStep` writes the facing before `GetNextTile` refuses,
				## so a step off the map turns the object where it stands.
				object.queue_step(Vector2i.ZERO, 0, false, direction)
				generated.append({
					"type": &"movement_blocked", "object_index": object_index,
					"cell": destination,
				})
			continue
		if not _movement_effect(kind, command, object, key, object_index, generated):
			break
	_object_position_overrides[key] = object.cell
	_object_facing_overrides[key] = final_facing
	return generated


## One movement command that is not a step or a turn. False ends the stream.
func _movement_effect(
	kind: StringName, command: Dictionary, object: Gen2WorldObject, key: String,
	object_index: int, generated: Array
) -> bool:
	match kind:
		&"show_object":
			object.deleted = false
			object.active = true
			_object_visibility_overrides[key] = true
			_transient_object_visibility_overrides[key] = true
		&"hide_object":
			object.active = false
			_object_visibility_overrides[key] = false
			_transient_object_visibility_overrides[key] = true
		&"remove_object":
			object.deleted = true
			object.active = false
			_object_followers.erase(key)
			generated.append({"type": &"object_deleted", "object_index": object_index})
			return false
		&"show_emote":
			object.set_emote(object.emote_id, true)
		&"hide_emote":
			object.set_emote(object.emote_id, false)
		&"step_sleep":
			## STEP_TYPE_SLEEP counts OBJECT_STEP_DURATION down one frame at a
			## time before the stream reads its next command, so a sleep is part
			## of what an applymovement wait waits for.
			object.queue_wait(int(command.get("length", 0)))
		&"step_stop":
			return false
		&"tree_shake":
			## `Movement_tree_shake` shakes the object, not the screen: the
			## stream sleeps 24 frames while OBJECT_ACTION_WEIRD_TREE cycles
			## its drawing. The event stays for a host that plays a sound
			## over it; nothing else is asked of it.
			object.queue_tree_shake(TREE_SHAKE_FRAMES)
			generated.append({
				"type": &"tree_shake_requested",
				"object_index": object_index,
				"cell": object.cell,
				"frames": TREE_SHAKE_FRAMES,
			})
		&"rock_smash":
			generated.append({
				"type": &"rock_smash_effect_requested",
				"object_index": object_index,
				"cell": object.cell,
			})
		&"set_sliding", &"remove_sliding", &"fix_facing", &"remove_fixed_facing":
			pass
		_:
			generated.append({
				"type": &"movement_command_requested", "object_index": object_index,
				"command": command.duplicate(true),
			})
	return true



func _clear_transient_object_visibility_overrides() -> void:
	for key: String in _transient_object_visibility_overrides:
		_object_visibility_overrides.erase(key)
	_transient_object_visibility_overrides.clear()


## A scripted step commits its cell without a permission check: every step
## command reaches `NormalStep` (`engine/overworld/movement.asm`), whose
## `InitStep`/`GetNextTile` (`engine/overworld/map_objects.asm`) only compute the
## vector, and the movement command set has no collision toggle. Walking through
## walls is what several cutscenes are built on, the S.S. Aqua's
## `SSAquaCaptainsCabinWarpsToGrandpasCabinMovement` among them: it crosses five
## wall rows to carry the player from the captain's cabin into the grandpa's.
## Only the map bounds still refuse.
func _apply_player_movement(event: Dictionary) -> Array:
	var generated: Array = []
	var map_group: int = int(event.get("map_group", -1))
	var map_number: int = int(event.get("map_number", -1))
	if current_map == null or map_group != current_map.group or map_number != current_map.number:
		return [{"type": &"movement_failed", "reason": &"invalid_map"}]
	var decoded: Dictionary = Gen2WorldMovement.decode(_movement_stream(event))
	if not bool(decoded.get("ok", false)):
		return [{
			"type": &"movement_failed", "reason": decoded.get("reason", &"invalid_movement"),
			"player": true,
		}]
	## The player is object struct 0, so `applymovement PLAYER` freezes every
	## map object exactly as an NPC's own does.
	freeze_all_other_objects(-1)
	for command: Dictionary in decoded.get("commands", []):
		var kind: StringName = StringName(command.get("kind", &""))
		if kind in SCRIPTED_TURN_KINDS:
			## Queued behind whatever is still walking, so the turn lands where
			## the walk ends rather than on the frame the stream was applied.
			_queue_player_step(
				Vector2i.ZERO, 0, false,
				_movement_direction(int(command.get("direction", 0))), kind,
			)
			continue
		if SCRIPTED_STEP_PASSES.has(kind):
			var direction: Vector2i = _movement_direction(int(command.get("direction", 0)))
			var jumping: bool = kind in JUMP_STEP_KINDS
			var cells: int = 2 if jumping else 1
			var destination: Vector2i = player_cell + direction * cells
			if _cell_in_bounds(destination):
				var vacated: Vector2i = player_cell
				player_cell = destination
				_queue_player_step(
					direction * cells, int(SCRIPTED_STEP_PASSES[kind]) * cells, jumping,
					direction, kind,
				)
				_advance_followers(-1, vacated)
			else:
				## `NormalStep` writes the facing before the refusal, so a step
				## off the map turns the player where they stand.
				_queue_player_step(Vector2i.ZERO, 0, false, direction, kind)
				generated.append({
					"type": &"movement_blocked", "player": true, "cell": destination,
				})
			continue
		if kind in [&"step_end", &"step_stop"]:
			break
		if kind == &"step_shake":
			generated.append({
				"type": &"screen_shake_requested",
				"strength": int(command.get("value", 0)),
				"source": &"player_movement",
			})
			continue
		if kind == &"step_sleep":
			# The player's half of the same wait: Script_earthquake's own stream is
			# `step_shake` and then a sleep, and the sleep is all of its duration.
			_queue_player_step(
				Vector2i.ZERO, Gen2WorldObject.sleep_frames(int(command.get("length", 0))),
				false, Vector2i.ZERO, kind
			)
			continue
		if kind in [
			&"step_wait_end", &"set_sliding", &"remove_sliding",
			&"fix_facing", &"remove_fixed_facing",
		]:
			continue
		generated.append({
			"type": &"movement_command_requested", "player": true,
			"command": command.duplicate(true),
		})
	return generated


func _movement_direction(direction: int) -> Vector2i:
	match direction & 3:
		0:
			return Vector2i.DOWN
		1:
			return Vector2i.UP
		2:
			return Vector2i.LEFT
		3:
			return Vector2i.RIGHT
	return Vector2i.ZERO


func _cell_in_bounds(cell: Vector2i) -> bool:
	if current_map == null:
		return false
	return cell.x >= 0 and cell.y >= 0 \
		and cell.x < current_map.collision_width and cell.y < current_map.collision_height


func _object_key(map_group: int, map_number: int, object_index: int) -> String:
	return "%d:%d:%d" % [map_group, map_number, object_index]


static func _block_key(map: Gen2WorldMap, block_x: int, block_y: int) -> String:
	return "%d:%d:%d:%d" % [map.group, map.number, block_x, block_y]


func _facing_toward(from: Vector2i, to: Vector2i) -> int:
	var delta: Vector2i = to - from
	if abs(delta.x) > abs(delta.y):
		return Gen2WorldSprite.FACING_RIGHT if delta.x > 0 else Gen2WorldSprite.FACING_LEFT
	if delta.y != 0:
		return Gen2WorldSprite.FACING_DOWN if delta.y > 0 else Gen2WorldSprite.FACING_UP
	return Gen2WorldSprite.FACING_DOWN


func _validate_script_warp(map_group: int, map_number: int, cell: Vector2i) -> Dictionary:
	var target_map: Gen2WorldMap = data.world_map(map_group, map_number) if data != null else null
	if target_map == null:
		return {"ok": false, "reason": &"missing_map"}
	var target_tileset: Gen2WorldTileset = data.world_tileset(target_map.tileset) if data != null else null
	if target_tileset == null:
		return {"ok": false, "reason": &"missing_tileset"}
	if cell.x < 0 or cell.y < 0 or cell.x >= target_map.collision_width \
		or cell.y >= target_map.collision_height:
		return {"ok": false, "reason": &"invalid_target_cell"}
	return {"ok": true}


## Applies what a script emitted before it stopped, whether it stopped for good
## or only to pause. A pause is a resume point rather than an ending in the
## source: `applymovement` yields the frame it has queued the stream, and the
## object has to be walking while the script waits for it. The runner drains its
## own event list per result, so nothing here is applied twice.
func _apply_result_events(result: Dictionary) -> Dictionary:
	if not result.has("events"):
		return result
	for generated: Dictionary in _apply_script_object_events(result.get("events", [])):
		result["events"].append(generated)
	for event: Dictionary in result.get("events", []):
		## `Script_blackoutmod`'s own two writes. `wLastSpawnMapGroup` and
		## `wLastSpawnMapNumber` are the pair a Pokemon Center entrance sets and
		## the pair `GetWhiteoutSpawn` reads, so the command lands on the same
		## field rather than on a destination of its own.
		if StringName(event.get("type", &"")) == &"blackout_destination_changed":
			last_spawn_map = Vector2i(
				int(event.get("map_group", 0)), int(event.get("map_number", 0))
			)
		## `Script_warpmod`'s own three writes, the same field a -1 warp's
		## arrival records for itself.
		if StringName(event.get("type", &"")) == &"backup_warp_changed":
			backup_warp = {
				"warp": int(event.get("warp", 0)),
				"map_group": int(event.get("map_group", 0)),
				"map_number": int(event.get("map_number", 0)),
			}
	return result


func _finish_script_result(result: Dictionary) -> Dictionary:
	## Before the refusal: the commands in front of the failing one did run.
	if not bool(result.get("ok", false)):
		return _apply_result_events(result)
	if result.has("clock"):
		var clock: Dictionary = result.get("clock", {})
		set_world_clock(
			int(clock.get("day", world_day)),
			int(clock.get("hour", world_hour)),
			int(clock.get("minute", world_minute))
		)
	if result.has("dst_enabled"):
		set_daylight_saving_time_enabled(bool(result.get("dst_enabled", false)))
	_apply_result_events(result)
	var warp: Variant = result.get("warp", {})
	if warp is Dictionary and not (warp as Dictionary).is_empty():
		var transition: Dictionary = _apply_script_warp(warp as Dictionary)
		if not bool(transition.get("ok", false)):
			result["ok"] = false
			result["status"] = &"failed"
			result["reason"] = transition.get("reason", &"warp_failed")
			return result
		result["events"].append({"type": &"warp", "transition": transition})
	return result


func _apply_script_warp(request: Dictionary) -> Dictionary:
	var map_group: int = int(request.get("map_group", -1))
	var map_number: int = int(request.get("map_number", -1))
	var cell := Vector2i(int(request.get("x", -1)), int(request.get("y", -1)))
	var validation: Dictionary = _validate_script_warp(map_group, map_number, cell)
	if not bool(validation.get("ok", false)):
		return validation
	var target_map: Gen2WorldMap = data.world_map(map_group, map_number)
	var target_tileset: Gen2WorldTileset = data.world_tileset(target_map.tileset)
	var from_map: Vector2i = map_id()
	var from_cell: Vector2i = player_cell
	var custom_facing: bool = request.has("facing")
	if custom_facing:
		player_facing = int(request["facing"])
	_apply_map(target_map, target_tileset, cell, custom_facing)
	return {
		"ok": true,
		"kind": &"warp",
		"from_map": from_map,
		"from_cell": from_cell,
		"to_map": map_id(),
		"to_cell": player_cell,
		"destination": request.duplicate(true),
	}


## Resolves and applies an ordinary warp at the current cell. The destination
## field selects a one-based warp in the destination map, as in the original map
## macro; an invalid target leaves this API unchanged and returns an error record.
## Below, `CheckWarpTile`'s own answer without walking through the warp, for a
## host that spends `MapSetupScript_Door`'s fade before the map swaps.
## `CheckWarpTile` is `GetDestinationWarpNumber` and then `CheckDirectionalWarp`,
## which clears carry on the four warp carpets: landing on one of those warps
## nothing, and only [method edge_warp_ready] takes it.
func warp_pending(cell: Vector2i = player_cell) -> bool:
	var code: int = collision_code_at(cell)
	return not warp_at(cell).is_empty() \
		and Gen2WorldCollision.is_warp_tile(code) \
		and not Gen2WorldCollision.is_directional_warp(code)


## `DoPlayerMovement.CheckWarp`: the player is standing on the warp carpet that
## names [param direction], is already facing that way, and the cell carries a
## warp. The press takes the warp instead of bumping, which is why an interior
## door is stood on first and walked into afterwards.
func edge_warp_ready(direction: Vector2i) -> bool:
	var code: int = collision_code_at(player_cell)
	if Gen2WorldCollision.directional_warp_direction(code) != direction:
		return false
	## `ld a, [wPlayerDirection] / rrca / rrca` against wWalkingDirection: the
	## facing has to agree with the press, which a turn from the same cell buys.
	if facing_for_direction(direction) != player_facing:
		return false
	return not warp_at(player_cell).is_empty()


func try_warp(cell: Vector2i = player_cell) -> Dictionary:
	var source_warp: Dictionary = warp_at(cell)
	if source_warp.is_empty():
		return {}
	## CheckWarpCollision gates every warp on the tile's own code, so a
	## warp_event sitting on ordinary floor never fires. Burned Tower B1F's
	## (10,8) is one, and the walk to the beasts crosses it.
	if not Gen2WorldCollision.is_warp_tile(collision_code_at(cell)):
		return {}
	var target_group: int = int(source_warp.get("map_group", -1))
	var target_number: int = int(source_warp.get("map_number", -1))
	var target_map: Gen2WorldMap = data.world_map(target_group, target_number) if data != null else null
	if target_map == null:
		return {
			"ok": false,
			"kind": &"warp",
			"reason": &"missing_map",
			"from_map": map_id(),
			"from_cell": cell,
		}

	## `CopyWarpData`'s own `cp -1`: a warp whose destination byte is -1 names no
	## warp and no map of its own, and the three bytes at `wBackupWarpNumber` are
	## read contiguously in its place. The map named beside such a byte is a
	## placeholder (POKECENTER_2F names itself), so it is replaced too.
	var destination_index: int = int(source_warp.get("destination", 0)) - 1
	if int(source_warp.get("destination", 0)) == BACKUP_WARP_DESTINATION:
		if backup_warp.is_empty():
			return {
				"ok": false,
				"kind": &"warp",
				"reason": &"no_backup_warp",
				"from_map": map_id(),
				"from_cell": cell,
			}
		destination_index = int(backup_warp["warp"]) - 1
		target_group = int(backup_warp["map_group"])
		target_number = int(backup_warp["map_number"])
		target_map = data.world_map(target_group, target_number) if data != null else null
		if target_map == null:
			return {
				"ok": false,
				"kind": &"warp",
				"reason": &"missing_map",
				"from_map": map_id(),
				"from_cell": cell,
			}
	var target_warps: Array = target_map.events.get("warps", [])
	if destination_index < 0 or destination_index >= target_warps.size():
		return {
			"ok": false,
			"kind": &"warp",
			"reason": &"missing_destination",
			"from_map": map_id(),
			"from_cell": cell,
		}

	var target_tileset: Gen2WorldTileset = data.world_tileset(target_map.tileset) if data != null else null
	if target_tileset == null:
		return {
			"ok": false,
			"kind": &"warp",
			"reason": &"missing_tileset",
			"from_map": map_id(),
			"from_cell": cell,
		}

	var target_warp: Dictionary = (target_warps[destination_index] as Dictionary).duplicate(true)
	var from_map: Vector2i = map_id()
	var from_cell: Vector2i = cell
	## `GetWarpDestCoords`'s `.backup`, which runs on arrival: a warp that is
	## itself a -1 warp records the warp and the map the player came from, and
	## that is what walking back out of it spends. Behind the read above, as in
	## the source, so a -1 warp taken back out of a -1 warp reads the old value.
	if int(target_warp.get("destination", 0)) == BACKUP_WARP_DESTINATION:
		var walked: int = warp_index_at(cell)
		if walked > 0:
			backup_warp = {
				"warp": walked, "map_group": from_map.x, "map_number": from_map.y,
			}
	# `wPrevWarp` is the warp walked through, which is what a Dig or an Escape
	# Rope comes back out of. `WarpToNewMapScript`, the pitfall and the magnet
	# train name DOOR, FALL and TRAIN, which are one setup-script body.
	_apply_map(
		target_map, target_tileset,
		Vector2i(int(target_warp["x"]), int(target_warp["y"])), false,
		warp_index_at(cell), MAP_ENTRY_DOOR
	)
	return {
		"ok": true,
		"kind": &"warp",
		"from_map": from_map,
		"from_cell": from_cell,
		"to_map": map_id(),
		"to_cell": player_cell,
		"source": source_warp,
		"destination": target_warp,
	}


## Resolves the source connection for a cardinal step beyond the current map. The
## stored offsets are the signed cell offsets the cartridge's connection macro
## generates, and no map mutation occurs when the target is invalid. Below, where
## a step would land, resolved without moving anyone, and every refusal
## `try_connection()` reports. A caller planning a walk asks that rather than
## testing the edge coordinate, because a connection spans only part of its edge:
## Route 8 is forty cells wide and its east connection covers nine of them.
func connection_target(cell: Vector2i, direction: Vector2i) -> Dictionary:
	var direction_name: String = _direction_name(direction)
	if direction_name.is_empty() or current_map == null or data == null:
		return {}
	if not _cell_at_connection_edge(cell, direction_name):
		return {"ok": false, "reason": &"not_at_edge", "direction": direction_name}
	var source_connection: Dictionary = {}
	for connection: Dictionary in current_map.connections:
		if String(connection.get("direction", "")) == direction_name:
			source_connection = connection.duplicate(true)
			break
	if source_connection.is_empty():
		return {}

	var target_group: int = int(source_connection.get("map_group", -1))
	var target_number: int = int(source_connection.get("map_number", -1))
	var target_map: Gen2WorldMap = data.world_map(target_group, target_number)
	if target_map == null:
		return {"ok": false, "reason": &"missing_map", "direction": direction_name}
	if data.world_tileset(target_map.tileset) == null:
		return {"ok": false, "reason": &"missing_tileset", "direction": direction_name}

	var target_cell: Vector2i
	match direction_name:
		"north":
			target_cell = Vector2i(
				cell.x + int(source_connection.get("x_offset", 0)),
				target_map.collision_height - 1,
			)
		"south":
			target_cell = Vector2i(cell.x + int(source_connection.get("x_offset", 0)), 0)
		"west":
			target_cell = Vector2i(
				target_map.collision_width - 1,
				cell.y + int(source_connection.get("y_offset", 0)),
			)
		"east":
			target_cell = Vector2i(0, cell.y + int(source_connection.get("y_offset", 0)))
		_:
			return {}
	if target_cell.x < 0 or target_cell.y < 0 \
		or target_cell.x >= target_map.collision_width \
		or target_cell.y >= target_map.collision_height:
		return {"ok": false, "reason": &"invalid_target_cell", "direction": direction_name}
	## A connected step is still a step. The cartridge copies the connection strip
	## into the same block buffer the current map lives in, so `GetTileCollision`
	## reads the neighbour's real collision and `.CheckLandPerms` refuses a wall
	## across an edge exactly as it does inside one. Without this the edge itself
	## was the only test, and Route 6's northwest corner walked into (10,35) of
	## Saffron City, a wall cell with no walkable neighbour at all.
	if not _connection_step_allows(target_map, target_cell, direction):
		return {"ok": false, "reason": &"blocked_target_cell", "direction": direction_name}
	return {
		"ok": true,
		"direction": direction_name,
		"map_group": target_group,
		"map_number": target_number,
		"cell": target_cell,
		"source": source_connection,
	}


func try_connection(direction: Vector2i) -> Dictionary:
	var direction_name: String = _direction_name(direction)
	if direction_name.is_empty() or current_map == null or data == null:
		return {}
	if not _at_connection_edge(direction_name):
		return {
			"ok": false,
			"kind": &"connection",
			"reason": &"not_at_edge",
			"from_map": map_id(),
			"from_cell": player_cell,
			"direction": direction_name,
		}
	var resolved: Dictionary = connection_target(player_cell, direction)
	if resolved.is_empty():
		return {}
	if not bool(resolved.get("ok", false)):
		return {
			"ok": false,
			"kind": &"connection",
			"reason": resolved.get("reason", &"invalid_target_cell"),
			"from_map": map_id(),
			"from_cell": player_cell,
			"direction": direction_name,
		}
	var target_map: Gen2WorldMap = data.world_map(
		int(resolved["map_group"]), int(resolved["map_number"])
	)
	var target_tileset: Gen2WorldTileset = data.world_tileset(target_map.tileset)
	var target_cell: Vector2i = resolved["cell"]

	var from_map: Vector2i = map_id()
	var from_cell: Vector2i = player_cell
	_apply_map(
		target_map, target_tileset, target_cell, false, 0, MAP_ENTRY_CONNECTION
	)
	## `CheckMovingOffEdgeOfMap` answers a step that has ALREADY landed: the
	## player walks the whole step onto the cell the connection strip's blocks
	## are drawn in, and only then does `EdgeWarpScript`'s `MAPSETUP_CONNECTION`
	## re-anchor the map around it. So a crossing costs exactly the frames any
	## other step does. `_apply_map` clears the step it inherits, so the step is
	## begun after it; the cell it is drawn walking out of is the new map's own
	## connection strip, which is the same picture the old map's edge was.
	player_facing = facing_for_direction(direction)
	_do_step(direction)
	_start_player_step(direction, _step_frames_for_movement())
	return {
		"ok": true,
		"kind": &"connection",
		"direction": direction_name,
		"from_map": from_map,
		"from_cell": from_cell,
		"to_map": map_id(),
		"to_cell": player_cell,
		"source": resolved.get("source", {}),
	}


## [param direction] is the attempted movement direction, matching
## .CheckLandPerms/.CheckSurfPerms ANDing wFacingDirection against
## wTilePermissions computed at the player's current cell. Vector2i.ZERO skips
## that test for callers that only want the destination's plain permission.
func can_walk_to(cell: Vector2i, direction: Vector2i = Vector2i.ZERO) -> bool:
	if not _step_permission_allows(cell, direction):
		return false
	return object_at(cell) == null


## _step_permission_allows() for a cell on a map that is not loaded yet: the
## leave-side face mask still reads the current map, the destination permission
## the connected one. No block override can apply to a map this world has not
## drawn, so the map's own collision is exact.
func _connection_step_allows(
	target_map: Gen2WorldMap, target_cell: Vector2i, direction: Vector2i
) -> bool:
	var face: int = Gen2WorldCollision.face_mask_for_direction(direction)
	if face != 0 and (tile_permissions_at(player_cell) & face) != 0:
		return false
	var permission: int = Gen2WorldCollision.permission_for(
		target_map.collision_at(target_cell.x, target_cell.y)
	)
	if movement_mode == MOVEMENT_SURF:
		if collision_permission_at(player_cell) == Gen2WorldCollision.WATER_TILE:
			return permission in [Gen2WorldCollision.LAND_TILE, Gen2WorldCollision.WATER_TILE]
		return permission == Gen2WorldCollision.WATER_TILE
	return permission == Gen2WorldCollision.LAND_TILE


## .CheckLandPerms/.CheckSurfPerms alone, without .CheckNPC. Split out because
## the source runs the two in that order and only reaches the NPC test when the
## permission passed, which is what makes a boulder on a wall unpushable.
func _step_permission_allows(cell: Vector2i, direction: Vector2i) -> bool:
	if current_map == null or cell.x < 0 or cell.y < 0 \
		or cell.x >= current_map.collision_width or cell.y >= current_map.collision_height:
		return false
	if direction != Vector2i.ZERO:
		var face: int = Gen2WorldCollision.face_mask_for_direction(direction)
		if face != 0 and (tile_permissions_at(player_cell) & face) != 0:
			return false
	var permission: int = collision_permission_at(cell)
	if movement_mode == MOVEMENT_SURF:
		var current_permission: int = collision_permission_at(player_cell)
		if current_permission == Gen2WorldCollision.WATER_TILE:
			return permission in [Gen2WorldCollision.LAND_TILE, Gen2WorldCollision.WATER_TILE]
		return permission == Gen2WorldCollision.WATER_TILE
	return permission == Gen2WorldCollision.LAND_TILE


## [param direction] matches CanObjectMoveInDirection's CanObjectLeaveTile
## (moving's own cell) and WillObjectBumpIntoTile (the destination) side-wall
## checks; Vector2i.ZERO skips them for callers that only want the destination
## permission and occupancy. A swimming object wants the opposite permission:
## CanObjectMoveInDirection branches on OBJECT_PALETTE's SWIMMING bit into
## WillObjectBumpIntoLand, which refuses anything but WATER_TILE, where the
## not-swimming branch refuses anything but LAND_TILE. Everything after that
## branch is shared, so only the permission differs.
func can_object_walk_to(
	cell: Vector2i, moving: Gen2WorldObject, direction: Vector2i = Vector2i.ZERO
) -> bool:
	if current_map == null or moving == null:
		return false
	var checked_cells: Array[Vector2i] = _object_landing_cells(moving, cell, direction)
	for checked: Vector2i in checked_cells:
		if checked.x < 0 or checked.y < 0 \
			or checked.x >= current_map.collision_width \
			or checked.y >= current_map.collision_height:
			return false
	var wanted: int = Gen2WorldCollision.WATER_TILE if moving.is_swimming() \
		else Gen2WorldCollision.LAND_TILE
	for checked: Vector2i in checked_cells:
		if Gen2WorldCollision.permission_for(collision_code_at(checked)) != wanted:
			return false
	if direction != Vector2i.ZERO and Gen2WorldCollision.side_wall_step_blocked(
		collision_code_at(moving.cell), collision_code_at(cell), direction
	):
		return false
	return _cells_unoccupied(checked_cells, moving)


## `WillObjectBumpIntoSomeoneElse`: `IsNPCAtCoord` over every struct, the
## player's included, on both pairs. See [method Gen2WorldObject.vacating_cell].
func _cells_unoccupied(cells: Array[Vector2i], moving: Gen2WorldObject) -> bool:
	for object: Gen2WorldObject in objects:
		if object == moving or not object.active or object.deleted:
			continue
		for checked: Vector2i in cells:
			if object.occupies(checked) or object.vacating_cell() == checked:
				return false
	var player_vacating: Vector2i = player_cell - _player_step_direction \
		if player_step_in_progress() else player_cell
	for checked: Vector2i in cells:
		if checked == player_cell or checked == player_vacating:
			return false
	return true



## `WillObjectRemainOnWater` checks the two cells a big object newly occupies.
## With no direction a caller is asking about the whole footprint.
func _object_landing_cells(
	moving: Gen2WorldObject, destination: Vector2i, direction: Vector2i
) -> Array[Vector2i]:
	if not moving.is_big_object():
		return [destination]
	var offsets: Array[Vector2i] = [
		Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE,
	]
	if direction == Vector2i.ZERO:
		return offsets.map(func(offset: Vector2i) -> Vector2i: return destination + offset)
	var previous_anchor: Vector2i = moving.cell
	var cells: Array[Vector2i] = []
	for offset: Vector2i in offsets:
		var target: Vector2i = destination + offset
		var was_occupied: bool = false
		for previous_offset: Vector2i in offsets:
			if target == previous_anchor + previous_offset:
				was_occupied = true
				break
		if not was_occupied:
			cells.append(target)
	return cells


## Advances the movement templates whose source behavior is data-driven in this
## slice. Scripted movement is executed by the script runner, while followers
## advance after each successful player step.
##
## One decision per eligible object per call. A caller wanting the source's
## pacing uses advance_object_steps_pass(), which spends the durations.
func advance_objects(random: RandomNumberGenerator) -> int:
	var moved: int = 0
	for object: Gen2WorldObject in objects:
		if not object.active or not object.movement_supported():
			continue
		if _decide_object_movement(object, random):
			moved += 1
	return moved


## One object's turn at StepFunction_FromMovement: the movement template picks
## a facing or a direction, then records how long the resulting step or wait
## lasts. Returns true when the object committed to a new cell.
func _decide_object_movement(object: Gen2WorldObject, random: RandomNumberGenerator) -> bool:
	if _decide_object_spin(object, random):
		return false
	var direction: Vector2i = object.next_direction(random)
	if direction == Vector2i.ZERO:
		return false
	# InitStep writes the facing before CanObjectMoveInDirection is asked, so a
	# refused step still turns the object.
	object.apply_direction(direction)
	var destination: Vector2i = object.cell + direction
	if not object.can_leave_to(destination) \
		or not _object_stays_on_screen(destination) \
		or not can_object_walk_to(destination, object, direction):
		# _RandomWalkContinue's .new_duration branch: a blocked object keeps its
		# cell and waits again before trying another direction.
		object.start_idle(_rolled_idle_passes(random, IDLE_MASK_SLOW))
		return false
	object.cell = destination
	object.start_step(direction, STEP_PASSES_NPC_WALK)
	return true


## The four spin templates: pick a facing, wait, never step.
func _decide_object_spin(object: Gen2WorldObject, random: RandomNumberGenerator) -> bool:
	if object.movement in Gen2WorldObject.SPIN_NEXT_FACING:
		var table: Array = Gen2WorldObject.SPIN_NEXT_FACING[object.movement]
		object.facing = int(table[clampi(object.facing, 0, table.size() - 1)])
		object.start_idle(Gen2WorldObject.SPIN_HOLD_PASSES)
		return true
	if object.movement == Gen2WorldObject.MOVEMENT_SPINRANDOM_SLOW:
		object.facing = random.randi() & 3
		object.start_idle(_rolled_idle_passes(random, IDLE_MASK_SLOW))
		return true
	if object.movement != Gen2WorldObject.MOVEMENT_SPINRANDOM_FAST:
		return false
	# MovementFunction_RandomSpinFast turns a repeat into the opposite facing,
	# `xor %00001100` on the direction being `^ 3` here, so it never stands twice.
	var rolled: int = random.randi() & 3
	object.facing = rolled if rolled != object.facing else rolled ^ 3
	object.start_idle(_rolled_idle_passes(random, IDLE_MASK_FAST))
	return true


## `RandomStepDuration_Slow` and `_Fast`. See [constant IDLE_PASSES_WRAP].
func _rolled_idle_passes(random: RandomNumberGenerator, mask: int) -> int:
	var rolled: int = random.randi() & mask
	return rolled if rolled > 0 else IDLE_PASSES_WRAP


## `IsObjectMovingOffEdgeOfScreen`, the refusal beside the movement radius in
## `CanObjectMoveInDirection`; MOVE_ANYWHERE skips both. Measured: Cherrygrove's
## teacher settles on the far cell of its band from four columns, not eight.
func _object_stays_on_screen(destination: Vector2i) -> bool:
	var offset: Vector2i = destination - player_cell
	return offset.x >= OBJECT_SCREEN_MIN.x and offset.x <= OBJECT_SCREEN_MAX.x \
		and offset.y >= OBJECT_SCREEN_MIN.y and offset.y <= OBJECT_SCREEN_MAX.y


## One hardware frame of the data-driven movement templates.
##
## An object spends a frame of an in-flight step, a frame of its wait, or takes
## a decision: STEP_TYPE_CONTINUE_WALK, _SLEEP and _FROM_MOVEMENT. The cell
## commits when the step starts, as InitStep does, and the offset trails.
func advance_object_steps_pass(random: RandomNumberGenerator) -> bool:
	if random == null or objects.is_empty():
		return false
	var changed: bool = false
	for object: Gen2WorldObject in objects:
		if not object.active or object.deleted:
			continue
		# A scripted trail belongs to advance_scripted_steps_pass(). Draining it
		# here too would walk it at twice the speed while both drivers run.
		if object.scripted_steps:
			continue
		# `HandleStepType` returns before every step function while FROZEN_F is
		# set, so a frozen object spends no step frame, no wait frame and takes
		# no decision. `applymovement` is what freezes the rest of the map.
		if object.frozen:
			continue
		# A step in flight is drained whatever put it there, so a pushed boulder
		# slides even though its template decides nothing.
		# StepFunction_StrengthBoulder rolls no wait, which is why only a
		# deciding template reaches start_idle below.
		if object.is_stepping():
			if object.tick_step():
				changed = true
				if not object.is_stepping() and object.movement_advances():
					# StepFunction_ContinueWalk rolls a new wait the moment
					# the step duration reaches zero.
					object.start_idle(_rolled_idle_passes(random, IDLE_MASK_SLOW))
			continue
		# `MovementFunction_Bouncing` decides nothing and leaves the picture to
		# OBJECT_ACTION_BOUNCE, which `HandleObjectAction` runs every pass. No
		# _remember_object_position(): this is a drawing, not a facing.
		if object.movement == Gen2WorldObject.MOVEMENT_POKEMON:
			if object.tick_bounce():
				changed = true
			continue
		if not object.movement_advances():
			continue
		if object.tick_idle():
			continue
		var facing_before: int = object.facing
		if _decide_object_movement(object, random):
			_remember_object_position(object)
			changed = true
		elif object.facing != facing_before:
			_remember_object_position(object)
			changed = true
	return changed


## Drains the presentation trail an `applymovement` left, and nothing else.
## Separate from [method advance_object_steps_pass] because a caller stops
## calling that while a script runs, which is when a stream needs drawing. No
## cell is written: every one the stream names committed when it was applied.
## Below, `FreezeAllOtherObjects`: `ApplyMovement` freezes every object with a
## sprite and clears the bit on the one it is about to move, and
## `UnfreezeFollowerObject` behind it keeps a `follow` pair walking together.
func freeze_all_other_objects(moving_index: int) -> void:
	for slot: int in objects.size():
		var object: Gen2WorldObject = objects[slot]
		object.frozen = object.active and not object.deleted and slot != moving_index
	_unfreeze_follower_of(moving_index)


## `UnfreezeAllObjects`, which `WaitScript` and `WaitScriptMovement` both run the
## frame their wait ends: the freeze lasts exactly as long as the wait an
## `applymovement` staged.
func unfreeze_all_objects() -> void:
	for object: Gen2WorldObject in objects:
		object.frozen = false


## The follower of [param leader_index], which is the pair `_object_followers`
## keys by the follower and names the leader in `target_index`.
func _unfreeze_follower_of(leader_index: int) -> void:
	if current_map == null:
		return
	for key: String in _object_followers:
		var separator: PackedStringArray = key.split(":")
		if separator.size() != 3 or int(separator[0]) != current_map.group \
			or int(separator[1]) != current_map.number:
			continue
		if int((_object_followers[key] as Dictionary).get("target_index", -2)) != leader_index:
			continue
		var follower_index: int = int(separator[2])
		if follower_index >= 0 and follower_index < objects.size():
			objects[follower_index].frozen = false


func advance_scripted_steps_pass() -> bool:
	var changed: bool = false
	for object: Gen2WorldObject in objects:
		if object.scripted_steps and not object.deleted and object.tick_step():
			changed = true
	return changed


## Spends the frames a script is waiting on and resumes it the frame its wait
## ends, returning whatever that produced.
##
## The two waits are `ScriptEvents`'s own: SCRIPT_WAIT_MOVEMENT, which ends when
## the stream an `applymovement` started has been drawn, and the counted delay
## `pause`, `wait`, `deactivatefacing` and `showemote` spend. A host calls this
## once per frame beside [method advance_scripted_steps_pass], which is what
## draws the movement the first one waits for.
func advance_script_wait_frame() -> Array:
	var wait: Dictionary = pending_script_wait()
	if wait.is_empty():
		_script_wait_frames = -1
		return []
	if StringName(wait.get("wait", &"")) == Gen2WorldScriptRunner.WAIT_MOVEMENT:
		if scripted_movement_in_progress():
			return []
		return _complete_script_wait()
	if _script_wait_frames < 0:
		_script_wait_frames = maxi(0, int(wait.get("frames", 0)))
	if _script_wait_frames > 0:
		_script_wait_frames -= 1
	if _script_wait_frames > 0:
		return []
	return _complete_script_wait()


## How many frames of the counted wait are left, or -1 when none is running or
## it has not been entered yet. What a host draws the wait's own animation from.
func script_wait_remaining() -> int:
	return _script_wait_frames


## Whether anything a script set walking is still being drawn. This is
## wStateFlags' SCRIPTED_MOVEMENT_STATE_F: one flag for all of them, cleared by
## whichever stream reaches its own `step_end`.
func scripted_movement_in_progress() -> bool:
	if _player_scripted_steps and player_step_in_progress():
		return true
	for object: Gen2WorldObject in objects:
		if object.scripted_steps and not object.deleted:
			return true
	return false


func _complete_script_wait() -> Array:
	_script_wait_frames = -1
	## `WaitScript` and `WaitScriptMovement` both run `UnfreezeAllObjects` the
	## frame their wait ends, before they hand the script back to `SCRIPT_READ`.
	unfreeze_all_objects()
	if _active_script == null:
		return []
	var advanced: Dictionary = _active_script.complete_wait()
	if StringName(advanced.get("status", &"")) == &"waiting":
		return [_apply_result_events(advanced)]
	return _resume_after(advanced)


## One hardware frame of every presentation a script waits on, for a caller with
## no render loop of its own: the trails and then the wait that is watching them.
## A screen calls the three parts itself, in the order it already draws them.
func advance_script_presentation_frame() -> Array:
	advance_player_step_pass()
	advance_scripted_steps_pass()
	return advance_script_wait_frame()


## Spends whole waits at the hardware frame rate until the script is no longer
## standing in one, and returns what resuming it produced last. The entry point
## for a headless caller that has nothing to draw; [param frame_limit] bounds a
## wait nothing can end rather than hanging on it, so a caller checks
## [method pending_script_wait] afterwards to tell a spent wait from a stuck one.
func finish_script_waits(frame_limit: int = 1024) -> Array:
	var results: Array = []
	for _frame: int in frame_limit:
		if pending_script_wait().is_empty():
			break
		var spent: Array = advance_script_presentation_frame()
		if not spent.is_empty():
			results = spent
	return results


## Keeps a moved or turned object's live cell and facing across the map reloads
## that rebuild object records, the same way the trainer approach does.
func _remember_object_position(object: Gen2WorldObject) -> void:
	if current_map == null:
		return
	var key: String = _object_key(current_map.group, current_map.number, object.index)
	_object_position_overrides[key] = object.cell
	_object_facing_overrides[key] = object.facing


## `StartFollow` runs `SetLeaderIfVisible` first and returns on its carry, so a
## leader that is not on the map leaves the pair that was already following
## alone; only `SetFollowerIfVisible` drops it, through the `ResetFollower` it
## opens with. `FollowNotExact` additionally places the follower beside the
## leader at once, taking the X axis first
## (engine/overworld/map_objects.asm, engine/overworld/player_object.asm).
func _start_object_follow(event: Dictionary) -> void:
	if current_map == null:
		return
	var map_group: int = int(event.get("map_group", -1))
	var map_number: int = int(event.get("map_number", -1))
	if map_group != current_map.group or map_number != current_map.number:
		return
	var follower_index: int = int(
		event.get("object_index", Gen2WorldObject.NONE_INDEX)
	)
	var leader_index: int = int(event.get("target_index", Gen2WorldObject.NONE_INDEX))
	if not _follow_object_is_visible(leader_index):
		return
	_object_followers.clear()
	if not _follow_object_is_visible(follower_index):
		return
	var exact: bool = bool(event.get("exact", true))
	var follow_key: String = _object_key(map_group, map_number, follower_index)
	_object_followers[follow_key] = {"target_index": leader_index, "exact": exact}
	if exact:
		return
	var leader_cell: Vector2i = player_cell if leader_index < 0 \
		else (objects[leader_index] as Gen2WorldObject).cell
	var follower_cell: Vector2i = player_cell if follower_index < 0 \
		else (objects[follower_index] as Gen2WorldObject).cell
	if follower_cell.x != leader_cell.x:
		follower_cell = leader_cell + Vector2i(signi(follower_cell.x - leader_cell.x), 0)
	elif follower_cell.y != leader_cell.y:
		follower_cell = leader_cell + Vector2i(0, signi(follower_cell.y - leader_cell.y))
	if follower_index < 0:
		player_cell = follower_cell
	else:
		var follower: Gen2WorldObject = objects[follower_index]
		follower.cell = follower_cell
		_remember_object_position(follower)


func _follow_object_is_visible(object_index: int) -> bool:
	if object_index < 0:
		return object_index == Gen2WorldObject.PLAYER_INDEX and player_visible()
	if object_index >= objects.size():
		return false
	var object: Gen2WorldObject = objects[object_index]
	return object.active and not object.deleted


## Every follower of [param leader_index] steps into the cell that leader has just
## left. `follow` names the leader first and the follower second, and the follower
## may be the player, so this is driven by an object's scripted step as well as by
## a player one; [param leader_index] is -1 for the player. Follower steps commit
## on the map bounds alone, for the same reason a scripted step and a trainer
## approach do: MovementFunction_Follow is HandleMovementData over the queued
## leader commands, so every one of them lands in NormalStep and never reaches
## CanObjectMoveInDirection.
func _advance_followers(
	leader_index: int, leader_from_cell: Vector2i, passes: int = STEP_PASSES_WALK
) -> void:
	if current_map == null:
		return
	var relations: Array = []
	for key: String in _object_followers:
		var separator: PackedStringArray = key.split(":")
		if separator.size() != 3 or int(separator[0]) != current_map.group \
			or int(separator[1]) != current_map.number:
			continue
		var relation: Dictionary = _object_followers[key]
		if int(relation.get("target_index", -1)) != leader_index:
			continue
		relations.append({"index": int(separator[2]), "relation": relation.duplicate(true)})
	relations.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return int(first["index"]) < int(second["index"])
	)
	for entry: Dictionary in relations:
		_step_follower(
			int(entry["index"]), leader_from_cell,
			bool((entry["relation"] as Dictionary).get("exact", true)), passes
		)


## One follower's step toward [param target_cell], which is the cell its leader
## has just left. An index below zero is the player, who is the object the
## source counts as zero and who is the follower in every `follow <NPC>, PLAYER`.
func _step_follower(
	follower_index: int, target_cell: Vector2i, exact: bool,
	passes: int = STEP_PASSES_WALK
) -> void:
	var follower_cell: Vector2i = player_cell
	var follower: Gen2WorldObject = null
	if follower_index >= 0:
		if follower_index >= objects.size():
			return
		follower = objects[follower_index]
		if not follower.active or follower.deleted:
			return
		follower_cell = follower.cell
	## The queue holds the leader's own command bytes one step behind it, so a
	## follower steps into the cell just vacated however close it already is;
	## only a follower standing in that cell has nothing to walk to.
	var delta: Vector2i = target_cell - follower_cell
	if delta == Vector2i.ZERO:
		return
	var direction: Vector2i
	if exact and abs(delta.x) != 0 and abs(delta.y) != 0:
		# Exact followers preserve the leader's cardinal path instead of
		# cutting a diagonal corner.
		direction = Vector2i(signi(delta.x), 0) if abs(delta.x) >= abs(delta.y) \
			else Vector2i(0, signi(delta.y))
	elif not exact and delta.x != 0:
		# MovementFunction_FollowNotExact checks X before Y.
		direction = Vector2i(signi(delta.x), 0)
	elif abs(delta.x) >= abs(delta.y):
		direction = Vector2i(signi(delta.x), 0)
	else:
		direction = Vector2i(0, signi(delta.y))
	var destination: Vector2i = follower_cell + direction
	if not _cell_in_bounds(destination):
		return
	# The leader's own step duration, not the slower wandering one:
	# QueueFollowerFirstStep queues `movement_step` and the queue after it holds
	# the leader's own command bytes. A running player leaves a follower on the
	# walk row a cell behind every step. The facing rides that queued step, since
	# a whole stream queues in one call and MovementFunction_Follow turns a
	# follower as each step begins rather than all at once.
	if follower == null:
		player_cell = destination
		_queue_player_step(direction, passes, false, direction)
		return
	follower.cell = destination
	follower.queue_step(direction, passes, false, direction)
	var override_key: String = _object_key(
		current_map.group, current_map.number, follower_index
	)
	_object_position_overrides[override_key] = follower.cell
	_object_facing_overrides[override_key] = facing_for_direction(direction)


## Moves one cell or enters a neighboring map when the step leaves a connected map
## edge. Below, `DoPlayerMovement`, which is what a button press reaches:
## `.CheckTurning` and then [method move_result]'s `.TryStep`. `.CheckTurning` runs
## before any collision check, so a direction that differs from the current facing
## turns on the spot even into a wall and the walk happens on the next poll; it
## guards on `wPlayerTurningDirection`, so a turn is only taken from a standstill.
## Only the input path has it: `applymovement` never reaches `DoPlayerMovement`,
## which is why a scripted walk turns nothing.
func player_input_move(direction: Vector2i) -> Dictionary:
	if abs(direction.x) + abs(direction.y) != 1:
		return {"ok": false, "kind": &"move", "reason": &"invalid_direction"}
	if player_step_in_progress():
		return {"ok": false, "kind": &"move", "reason": &"step_in_progress"}
	## `.CheckTile` overwrites the pressed direction, so a forced walk is not a
	## turn however the facing sits; move_result owns that branch.
	var forced: StringName = StringName(forced_movement().get("kind", &"none"))
	## `.CheckTurning`'s own first test is `wPlayerTurningDirection`, so a turn is
	## only ever taken from a standstill. On ice that byte stays set between
	## steps, which is what makes a slide change direction without spending a
	## turn on it.
	if forced == &"none" and _player_turning_direction == 0:
		var pressed_facing: int = facing_for_direction(direction)
		if pressed_facing != player_facing:
			player_facing = pressed_facing
			_do_step(direction)
			_start_player_step(Vector2i.ZERO, STEP_PASSES_TURN, false, STEP_KIND_TURN)
			return {
				"ok": true, "kind": &"turn", "facing": player_facing, "cell": player_cell,
			}
	var stepped: Dictionary = move_result(direction)
	if bool(stepped.get("ok", false)):
		return stepped
	## `.CheckWarp` sits after `.TryStep` and `.TryJump` and before `.NotMoving`,
	## so a carpet is only reached once the step into it has been refused, which
	## it always is: the cell past a door carpet is the map's own wall or edge.
	## `.StandInPlace` spends no step, so the warp is taken on the press.
	if forced == &"none" and edge_warp_ready(direction):
		## `.CheckWarp` calls `.StandInPlace` before it returns the warp.
		_stand_in_place()
		return {
			"ok": true,
			"kind": &"edge_warp",
			"from_map": map_id(),
			"from_cell": player_cell,
			"to_map": map_id(),
			"to_cell": player_cell,
		}
	return stepped


func move_result(direction: Vector2i) -> Dictionary:
	if phone_ring_active():
		## `StopPlayerForEvent`, which is what an event interrupting a walk runs:
		## it clears the turning direction, so a slide does not resume after it.
		_stand_in_place()
		return {"ok": false, "kind": &"move", "reason": &"phone_ring_active"}
	if abs(direction.x) + abs(direction.y) != 1:
		return {"ok": false, "kind": &"move", "reason": &"invalid_direction"}
	if current_map == null:
		return {"ok": false, "kind": &"move", "reason": &"missing_map"}
	## .CheckTile runs before .CheckTurning and .TryStep/.TrySurf and overwrites
	## wWalkingDirection, so the standing tile wins over the pressed direction.
	var forced: Dictionary = forced_movement()
	var forced_walk: bool = false
	match StringName(forced.get("kind", &"none")):
		&"force_turn":
			return _forced_turn()
		&"walk":
			direction = forced["direction"]
			forced_walk = true
	var destination: Vector2i = player_cell + direction
	if destination.x < 0 or destination.y < 0 \
		or destination.x >= current_map.collision_width \
		or destination.y >= current_map.collision_height:
		var transition: Dictionary = try_connection(direction)
		if not transition.is_empty():
			## `CheckTileEvent` branches to `.map_connection` before it reaches
			## `CountStep`, so the step that leaves a map costs no repel step;
			## try_connection() owns the facing and the step's own frames.
			return transition
		return _refused_move(direction, &"map_edge")
	if forced_walk:
		return _forced_step(direction, destination)
	if not can_walk_to(destination, direction):
		## .CheckNPC runs after .CheckLandPerms and before .TryJump, and its own
		## comment says a movable boulder is treated the same as any NPC in front:
		## both .bump. So a push starts the boulder and still refuses the player,
		## and .bump returns without carry, so the ledge hop is tried afterwards
		## exactly as it would have been.
		var pushed: Dictionary = _try_push_boulder(direction, destination)
		var hop: Dictionary = _try_ledge_hop(direction)
		if not hop.is_empty():
			return hop
		if not pushed.is_empty():
			return pushed
		return _refused_move(direction, &"blocked")
	var from_map: Vector2i = map_id()
	var from_cell: Vector2i = player_cell
	## .TrySurf's .ExitWater: .GetOutOfWater restores PLAYER_NORMAL and the walking
	## sprite before .DoStep runs, so the state is already back to walking while
	## the step onto land is still being taken.
	var exiting_water: bool = movement_mode == MOVEMENT_SURF \
		and collision_permission_at(destination) == Gen2WorldCollision.LAND_TILE
	var kind: StringName = &"move"
	if exiting_water:
		movement_mode = MOVEMENT_WALK
		player_sprite_number = _walking_sprite()
		_apply_map_music()
		kind = &"exit_water"
	elif movement_mode == MOVEMENT_SURF:
		kind = &"water_move"
	## `.TryStep` reads `wPlayerTileCollision`, the cell being left, and its ice
	## branch sits in front of `.BikeCheck`.
	var kind_of_step: StringName = STEP_KIND_WALK
	var passes: int = _step_frames_for_movement()
	if Gen2WorldCollision.is_ice(collision_code_at(from_cell)):
		kind_of_step = &"fast_slide_step"
		passes = STEP_PASSES_FAST
	player_cell = destination
	player_facing = facing_for_direction(direction)
	count_step()
	_advance_followers(-1, from_cell, passes)
	_do_step(direction)
	_start_player_step(direction, passes, false, kind_of_step)
	return {
		"ok": true,
		"kind": kind,
		"from_map": from_map,
		"from_cell": from_cell,
		"to_map": from_map,
		"to_cell": player_cell,
	}


## `.NotMoving`: `._WalkInPlace` clears the turning byte and `.BumpSound` plays
## SFX_BUMP, unless `.CheckWarp` raised `wWalkingIntoEdgeWarp`, which it does
## whenever the standing cell carries the carpet naming the pressed direction,
## warp or no warp. `.Surf` never runs `.CheckWarp`.
func _refused_move(direction: Vector2i, reason: StringName) -> Dictionary:
	_stand_in_place()
	var into_carpet: bool = movement_mode != MOVEMENT_SURF \
		and Gen2WorldCollision.directional_warp_direction(
			collision_code_at(player_cell)
		) == direction
	return {"ok": false, "kind": &"move", "reason": reason, "bump": not into_carpet}


## `.DoStep`'s own tail: the walking direction is stored as `$80 | direction`
## for `.CheckForced` to read back next poll. Every branch of `DoPlayerMovement`
## that commits a step or a turn passes through here; nothing else does.
func _do_step(direction: Vector2i) -> void:
	_player_turning_direction = 0x80 | TURNING_DIRECTION_ORDER.find(direction)


## `.StandInPlace` and `._WalkInPlace`, which differ only in the movement byte
## they queue and both clear the turning direction. Reached by every poll that
## commits nothing, so on any tile but ice the byte is zero between steps.
func _stand_in_place() -> void:
	_player_turning_direction = 0


## A poll of `DoPlayerMovement` that committed nothing: `.Standing` reaches
## `.StandInPlace`. The screen's own frame pump is where a poll with nothing
## held happens, since a press is what reaches [method player_input_move].
func note_standing_still() -> void:
	_stand_in_place()


## `CheckStandingOnIce`. `PLAYER_SKATE` is deliberately absent: no script in
## either pin sets it, so the collision code is the whole test.
func standing_on_ice() -> bool:
	if _player_turning_direction == 0 or current_map == null:
		return false
	return Gen2WorldCollision.is_ice(collision_code_at(player_cell))


## `.CheckForced`, then `.GetAction`. `and PAD_BUTTONS` drops the whole d-pad
## before the slide's own direction is OR'd in, so a held key reaches
## `.GetAction` on no frame of a slide.
func effective_input_direction(held: Vector2i) -> Vector2i:
	if not standing_on_ice():
		return held
	return TURNING_DIRECTION_ORDER[_player_turning_direction & 3]


## .CheckTile for the cell the player stands on: whether the tile overrides input,
## and with what. [code]none[/code] leaves ordinary movement alone.
func forced_movement() -> Dictionary:
	if current_map == null:
		return {"kind": &"none"}
	return Gen2WorldCollision.forced_action(collision_code_at(player_cell))


## Whatever the standing tile forces, with no input: the source polls .CheckTile
## every frame rather than only on a press. Empty when the tile forces nothing.
func advance_forced_movement() -> Dictionary:
	var forced: Dictionary = forced_movement()
	match StringName(forced.get("kind", &"none")):
		&"force_turn":
			return _forced_turn()
		&"walk":
			return move_result(forced["direction"])
	return {}


## PLAYERMOVEMENT_FORCE_TURN, which queues Script_ForcedMovement: it reads
## VAR_FACING and runs `step_dig 16`, `turn_in <back>`, `step_dig 16`,
## `turn_head <back>`. `turn_in` reaches `TurningStep` and so `InitStep`, which
## moves a cell, so a whirlpool spits the player back rather than holding them.
## `step_dig` is `STEP_TYPE_SLEEP` with OBJECT_ACTION_SPIN: it spins in place.
func _forced_turn() -> Dictionary:
	var back: Vector2i = -_direction_for_facing(player_facing)
	var landing: Vector2i = player_cell + back
	var from_cell: Vector2i = player_cell
	if _cell_in_bounds(landing):
		player_cell = landing
		_advance_followers(-1, from_cell)
	player_facing = facing_for_direction(back)
	## `Movement_step_dig` seeds OBJECT_STEP_FRAME from its direction, so the spin
	## opens on `.facings`' row for it rather than at DOWN.
	_player_spin_frame = (TURNING_DIRECTION_ORDER.find(back) << 4) & 0x30
	_queue_player_step(Vector2i.ZERO, FORCED_TURN_SLEEP_PASSES, false, back, &"step_dig")
	if player_cell != from_cell:
		_queue_player_step(back, STEP_PASSES_WALK, false, back, &"turn_in")
	_queue_player_step(Vector2i.ZERO, FORCED_TURN_SLEEP_PASSES, false, back, &"step_dig")
	return {
		"ok": true,
		"kind": &"forced_turn",
		"cell": player_cell,
		"from_cell": from_cell,
		"facing": player_facing,
		"passes": FORCED_TURN_SLEEP_PASSES * 2
			+ (STEP_PASSES_WALK if player_cell != from_cell else 0),
	}


## .continue_walk: STEP_WALK through .DoStep, which never consults permissions, so
## a forced step commits into a cell an ordinary step would refuse, and reaches
## .CheckTile before .TrySurf, so it never runs .ExitWater either. No shipped map
## places a forced tile where either matters.
func _forced_step(direction: Vector2i, destination: Vector2i) -> Dictionary:
	var from_map: Vector2i = map_id()
	var from_cell: Vector2i = player_cell
	player_cell = destination
	player_facing = facing_for_direction(direction)
	count_step()
	_advance_followers(-1, from_cell)
	_do_step(direction)
	_start_player_step(direction, STEP_PASSES_WALK)
	return {
		"ok": true,
		"kind": &"forced_move",
		"from_map": from_map,
		"from_cell": from_cell,
		"to_map": from_map,
		"to_cell": player_cell,
	}


## `.CheckStrengthBoulder`, then the boulder's own `MovementFunction_Strength`.
## The source splits these across two frames with nothing observable between, so
## both resolve in one call; the player is not moved and the caller still reports
## a blocked step. Refusals in order: BIKEFLAGS_STRENGTH_ACTIVE_F, a boulder that
## is not standing, then the destination it would take. A boulder standing on a
## pit stops for good, which is Blackthorn Gym 2F's puzzle. [param destination]'s
## permission is read here because `.CheckLandPerms` runs before `.CheckNPC`.
func _try_push_boulder(direction: Vector2i, destination: Vector2i) -> Dictionary:
	if not strength_active():
		return {}
	if not _step_permission_allows(destination, direction):
		return {}
	var boulder: Gen2WorldObject = object_at(destination)
	if boulder == null or not boulder.is_strength_boulder() or boulder.is_stepping():
		return {}
	if Gen2WorldCollision.is_pit_tile(collision_code_at(boulder.cell)):
		return {}
	var landing: Vector2i = boulder.cell + direction
	# CanObjectMoveInDirection with the boulder's own flags: WONT_DELETE,
	# FIXED_FACING, SLIDING and MOVE_ANYWHERE, palette bit STRENGTH_BOULDER and
	# no NOCLIP or SWIMMING. That leaves the destination's land permission, both
	# side-wall rules, and IsNPCAtCoord over the object structs, which start at
	# the player's own. can_object_walk_to() is those four tests.
	if not can_object_walk_to(landing, boulder, direction):
		return {}
	boulder.cell = landing
	# The stone queue is asked here, on the call that commits the cell, for the
	# same reason the push itself is resolved here: the source waits for the
	# boulder to reach STANDING, and nothing between those frames asks the
	# boulder anything or moves it again.
	var fall: Dictionary = stone_queue_script(boulder)
	# FIXED_FACING is set on the boulder's movement data, so InitStep skips the
	# OBJECT_DIRECTION write and the sprite keeps facing down while it slides.
	boulder.start_step(direction, STEP_PASSES_BOULDER_PUSH)
	_remember_object_position(boulder)
	var pushed: Dictionary = {
		"index": boulder.index,
		"from_cell": landing - direction,
		"to_cell": landing,
		"direction": direction,
	}
	if not fall.is_empty():
		pushed["fall_script"] = int(fall["script"])
		_enqueue_script({
			"kind": &"stone_table",
			"map_group": current_map.group,
			"map_number": current_map.number,
			"cell": landing,
			"bank": int(fall["bank"]),
			"script": int(fall["script"]),
			"object_index": boulder.index,
		})
	return {
		"ok": false,
		"kind": &"move",
		"reason": &"blocked",
		"boulder_pushed": pushed,
	}


## engine/overworld/player_movement.asm's .TryJump, reached only after an ordinary
## step into [param direction] is blocked. Reads the collision code of the cell
## the player already stands on, not the faced cell; on a match the player covers
## two cells in one bounded action, bypassing collision on both the intervening
## and landing cells as the source does. An empty Dictionary means no hop, so the
## caller falls through to an ordinary blocked result. Surfing refuses outright,
## since .Surf calls .TrySurf then jumps straight to .NotMoving; a landing cell
## outside the map is refused too, as out-of-range cells always block here.
func _try_ledge_hop(direction: Vector2i) -> Dictionary:
	if movement_mode == MOVEMENT_SURF:
		return {}
	if not Gen2WorldCollision.allows_hop(collision_code_at(player_cell), direction):
		return {}
	var landing: Vector2i = player_cell + direction * 2
	if landing.x < 0 or landing.y < 0 \
		or landing.x >= current_map.collision_width \
		or landing.y >= current_map.collision_height:
		return {}
	var from_map: Vector2i = map_id()
	var from_cell: Vector2i = player_cell
	player_cell = landing
	player_facing = facing_for_direction(direction)
	count_step()
	_advance_followers(-1, from_cell)
	_do_step(direction)
	_start_player_step(direction * 2, STEP_PASSES_HOP, true, STEP_KIND_HOP)
	return {
		"ok": true,
		"kind": &"ledge_hop",
		"from_map": from_map,
		"from_cell": from_cell,
		"to_map": from_map,
		"to_cell": player_cell,
	}


## Moves exactly one walk cell in a cardinal direction, or two when a ledge
## hop applies. Diagonal, zero and out-of-bounds moves are rejected without
## changing the player position.
func move(direction: Vector2i) -> bool:
	return bool(move_result(direction).get("ok", false))


func _clamp_cell(cell: Vector2i) -> Vector2i:
	var size: Vector2i = map_size_cells()
	return Vector2i(
		clampi(cell.x, 0, maxi(0, size.x - 1)),
		clampi(cell.y, 0, maxi(0, size.y - 1)),
	)


func _direction_name(direction: Vector2i) -> String:
	match direction:
		Vector2i.UP:
			return "north"
		Vector2i.DOWN:
			return "south"
		Vector2i.LEFT:
			return "west"
		Vector2i.RIGHT:
			return "east"
	return ""


func _direction_for_facing(facing: int) -> Vector2i:
	match facing:
		Gen2WorldSprite.FACING_UP:
			return Vector2i.UP
		Gen2WorldSprite.FACING_LEFT:
			return Vector2i.LEFT
		Gen2WorldSprite.FACING_RIGHT:
			return Vector2i.RIGHT
	return Vector2i.DOWN


func facing_for_direction(direction: Vector2i) -> int:
	match direction:
		Vector2i.UP:
			return Gen2WorldSprite.FACING_UP
		Vector2i.DOWN:
			return Gen2WorldSprite.FACING_DOWN
		Vector2i.LEFT:
			return Gen2WorldSprite.FACING_LEFT
		Vector2i.RIGHT:
			return Gen2WorldSprite.FACING_RIGHT
	return player_facing


func _fishing_failure(reason: StringName) -> Dictionary:
	return {
		"ok": false,
		"kind": &"fishing_failed",
		"reason": reason,
		"state": Gen2WorldFishing.STATE_IDLE,
	}


func _at_connection_edge(direction_name: String) -> bool:
	return _cell_at_connection_edge(player_cell, direction_name)


func _cell_at_connection_edge(cell: Vector2i, direction_name: String) -> bool:
	if current_map == null:
		return false
	match direction_name:
		"north":
			return cell.y == 0
		"south":
			return cell.y == current_map.collision_height - 1
		"west":
			return cell.x == 0
		"east":
			return cell.x == current_map.collision_width - 1
	return false


## engine/overworld/map_setup.asm's CheckUpdatePlayerSprite, which every warp and
## connection reaches through warp_connection.asm: the player state is re-derived
## from the cell landed on rather than carried over.
func _apply_map_setup_player_state() -> void:
	var mode: StringName = _setup_movement_mode(player_cell)
	if mode == movement_mode:
		return
	movement_mode = mode
	player_sprite_number = _map_setup_sprite(mode)


func _map_setup_sprite(mode: StringName) -> int:
	if mode == MOVEMENT_SURF:
		return Gen2WorldSprite.SPRITE_SURF
	if mode == MOVEMENT_BIKE:
		return Gen2WorldSprite.player_bike_sprite(_player_female)
	return _walking_sprite()


## `.ResetSurfingOrBikingState`'s three, and no more: a cave and a gate are
## legal to ride through, which is why `.CheckEnvironment` mounts one there.
const BIKE_DISMOUNT_ENVIRONMENTS: Array[int] = [
	ENVIRONMENT_INDOOR, ENVIRONMENT_5, ENVIRONMENT_DUNGEON,
]


## `CheckUpdatePlayerSprite`'s three branches in its own order: `.CheckForcedBiking`,
## then `.CheckSurfing`, then `.ResetSurfingOrBikingState`.
func _setup_movement_mode(cell: Vector2i) -> StringName:
	if state != null and state.is_engine_flag_active(
		Gen2WorldState.always_on_bike_flag(data)
	):
		return MOVEMENT_BIKE
	if collision_permission_at(cell) == Gen2WorldCollision.WATER_TILE:
		return MOVEMENT_SURF
	if movement_mode == MOVEMENT_SURF:
		return MOVEMENT_WALK
	if movement_mode == MOVEMENT_BIKE and current_map != null \
		and BIKE_DISMOUNT_ENVIRONMENTS.has(current_map.environment):
		return MOVEMENT_WALK
	return movement_mode


func _apply_map(
	target_map: Gen2WorldMap,
	target_tileset: Gen2WorldTileset,
	target_cell: Vector2i,
	custom_facing: bool = false,
	from_warp: int = 0,
	entry: int = MAP_ENTRY_WARP,
) -> void:
	# The one breadcrumb a bug report cannot do without: every warp, connection
	# and load reaches this, so a log always says which map the player was on.
	Gen2Diagnostics.trace("map", "group %d map %d, tileset %d, cell %s" % [
		target_map.group, target_map.number, target_map.tileset, target_cell,
	])
	_record_escape_points(target_map, from_warp)
	## `RefreshPlayerSprite` clears `wPlayerTurningDirection`, and every warp and
	## connection reaches it, so a slide never survives a map change.
	_stand_in_place()
	_block_overrides.clear()
	block_revision += 1
	_pending_cut.clear()
	_pending_surf.clear()
	_pending_whirlpool.clear()
	_pending_strength.clear()
	_pending_escape.clear()
	_pending_waterfall.clear()
	_pending_headbutt.clear()
	_pending_rock_smash.clear()
	_pending_flash.clear()
	# home/map.asm's map load calls ReadObjectEvents, which calls
	# ClearObjectStructs and re-reads every object event from ROM. moveobject
	# writes MAPOBJECT_X_COORD/Y_COORD in that same rebuilt table, so a scripted
	# position never survives a map load; a MAPCALLBACK_OBJECTS callback
	# re-applies it while its condition holds. Keeping these overrides across a
	# map change left objects where an earlier visit had put them:
	# ElmsLabMoveElmCallback moves Elm to (3, 4) during SCENE_ELMSLAB_MEET_ELM,
	# and the story then found nothing at his authored (5, 2) on returning.
	_object_position_overrides.clear()
	_object_facing_overrides.clear()
	# `appear`/`disappear` with an object event flag persist through the source's
	# temporary map-flag reset. Flagless visibility and movement-level show/hide
	# are live-map changes, so only those overrides expire on a map load.
	_clear_transient_object_visibility_overrides()
	state.reset_map_reload_flags()
	# EnterMap's own SetUpFiveStepWildEncounterCooldown, which is why the first
	# steps out of a door are quiet.
	state.set_wild_encounter_cooldown(Gen2WorldState.WILD_ENCOUNTER_COOLDOWN_STEPS)
	# HandleNewMap's own resets: ResetBikeFlags drops a used Strength with the
	# map, ResetFlashIfOutOfCave puts the light out on a route or a town, and
	# HandleContinueMap behind it runs ClearCmdQueue over every written queue.
	state.reset_bike_flags(Gen2WorldState.is_crystal_profile(data))
	state.clear_flash_if_outdoors(target_map.environment)
	_command_queues.clear()
	current_map = target_map
	_map_placements = {}
	_connected_objects = []
	block_revision += 1
	current_tileset = target_tileset
	player_cell = _clamp_cell(target_cell)
	# RefreshPlayerSprite calls CheckWarpFacingDown, then applies a scripted
	# PLAYERSPRITESETUP_CUSTOM_FACING override last. This makes a staircase entry
	# face its automatic downward exit instead of retaining the direction used on
	# the previous map.
	if not custom_facing and Gen2WorldCollision.faces_down_on_spawn(
		collision_code_at(player_cell)
	):
		player_facing = Gen2WorldSprite.FACING_DOWN
	_apply_map_setup_player_state()
	_clear_player_step()
	# _load_objects() rebuilds every record, so in-flight object steps end with
	# the objects that owned them.
	_load_objects()
	# The cartridge moves roaming Pokémon in map setup, not on a timer, so a
	# player who stands still does not watch them cross Johto, and which routine
	# a load runs is the entry method's to say.
	_last_schedule = advance_schedule(schedule_random, entry)
	# PlayMapMusic runs in map setup, so leaving a map is what ends a tuned radio
	# station: its own track is not this map's, so the comparison fails and the
	# map's music wins.
	_apply_map_music()
	_init_map_name_sign()
	_queue_map_callbacks(-1)
	_map_entry_scene_pending = true
	_map_entry_scene_ran = false
	_object_masks_pending = true


## `.SaveDigWarp` and `.SetSpawn`, which run on a map change and only ever fire
## on the way from an outdoor map into an indoor one. The dig warp is the warp
## the player came through, so it is recorded only on the path that used one; a
## scripted `warp` names a destination rather than a warp number and leaves the
## last walked one standing, as `wPrevWarp` does. Mount Moon Square and the Tin
## Tower roof are outdoor maps reached from indoor ones, refused by name.
func _record_escape_points(target_map: Gen2WorldMap, from_warp: int) -> void:
	if current_map == null or not _is_outdoor(current_map.environment) \
			or not _is_indoor(target_map.environment):
		return
	var from_map: Vector2i = map_id()
	# One-based, as `warp_index_at` counts and as a `warp_event` destination is:
	# zero is a map change that walked through no warp at all.
	if from_warp > 0 and not OUTDOOR_MAPS_INSIDE_INDOOR_ONES.has(from_map):
		dig_warp = {
			"warp": from_warp, "map_group": from_map.x, "map_number": from_map.y,
		}
	var tileset: int = target_map.tileset
	if tileset == pokecenter_tileset() or tileset == TILESET_POKECOM_CENTER:
		last_spawn_map = from_map


## `CheckOutdoorMap` and `CheckIndoorMap` (`home/map.asm`), which are what both
## of the recorders above are gated on.
static func _is_outdoor(environment: int) -> bool:
	return environment in [ENVIRONMENT_TOWN, ENVIRONMENT_ROUTE]


static func _is_indoor(environment: int) -> bool:
	return environment in [
		ENVIRONMENT_INDOOR, ENVIRONMENT_CAVE, ENVIRONMENT_DUNGEON, ENVIRONMENT_GATE,
	]


## `TILESET_POKECENTER`, which is one lower on Gold and Silver: pokegold ships no
## `TILESET_BATTLE_TOWER_OUTSIDE`, so every tileset past it sits one down.
func pokecenter_tileset() -> int:
	return TILESET_POKECENTER if Gen2WorldState.is_crystal_profile(data) \
		else TILESET_POKECENTER_GOLD_SILVER


## `IsSpawnPoint`: which spawn a map is, or -1 for a map that is none.
func spawn_index_of(map: Vector2i) -> int:
	if data == null:
		return -1
	for index: int in data.spawn_point_count():
		var point: Dictionary = data.spawn_point(index)
		if int(point["map_group"]) == map.x and int(point["map_number"]) == map.y:
			return index
	return -1


## `GetWhiteoutSpawn`: the spawn a blackout puts the player at. The last Pokemon
## Center's own outdoor map when that map is a spawn point, and `SPAWN_HOME`
## when it is not or when none has been entered.
func whiteout_spawn() -> int:
	var index: int = spawn_index_of(last_spawn_map)
	return index if index >= 0 else RomLayout.SPAWN_HOME


## `Script_AbortBugContest`, which is `checkflag ENGINE_BUG_CONTEST_TIMER`, the
## once-a-day flag and `special ContestReturnMons`. The mons themselves are the
## party host's, so this answers whether they are owed rather than moving them.
func abort_bug_contest() -> Dictionary:
	if not bug_contest_active():
		return {"ok": true, "kind": &"bug_contest_abort", "aborted": false}
	var crystal: bool = Gen2WorldState.is_crystal_profile(data)
	state.set_engine_flag(
		Gen2WorldState.engine_flag(Gen2WorldState.ENGINE_DAILY_BUG_CONTEST, crystal), true
	)
	return {"ok": true, "kind": &"bug_contest_abort", "aborted": true}


## `WarpToSpawnPoint`, whose whole body is two `res` on `wStatusFlags2`. It is
## the timer flag rather than the contest's balls or its clock that a running
## contest is known by, so clearing it is what ends one.
func warp_to_spawn_point() -> Dictionary:
	var crystal: bool = Gen2WorldState.is_crystal_profile(data)
	for flag: int in [
		Gen2WorldState.ENGINE_SAFARI_ZONE, Gen2WorldState.ENGINE_BUG_CONTEST_TIMER,
	]:
		state.set_engine_flag(Gen2WorldState.engine_flag(flag, crystal), false)
	return {"ok": true, "kind": &"warp_to_spawn_point"}


## The two-line tail every escape from a map shares: `farscall
## Script_AbortBugContest` then `special WarpToSpawnPoint`, in `.FlyScript`,
## `.UsedDigOrEscapeRopeScript`, `.TeleportScript` and `Script_Whiteout`. It
## lives on the two warps below rather than on each of the four callers, because
## those two warps are the whole of what an escape does here.
func _escape_map_tail() -> void:
	if bool(abort_bug_contest().get("aborted", false)):
		_contest_abort_pending = true
	warp_to_spawn_point()


## Whether the escape just taken aborted a running contest, read once. The party
## the contest masked off belongs to the save, so the host is what puts it back.
func take_contest_abort() -> bool:
	var pending: bool = _contest_abort_pending
	_contest_abort_pending = false
	return pending


## `EnterMapSpawnPoint` plus the map load behind it: the player put down at
## spawn [param index], facing the way a warp leaves them. Answers the same
## record a warp does, or a refusal when the cache holds no such spawn.
func warp_to_spawn(index: int, entry: int = MAP_ENTRY_WARP) -> Dictionary:
	var point: Dictionary = data.spawn_point(index) if data != null else {}
	if point.is_empty():
		return {"ok": false, "kind": &"spawn_warp", "reason": &"missing_spawn"}
	var target_map: Gen2WorldMap = data.world_map(
		int(point["map_group"]), int(point["map_number"])
	)
	var target_tileset: Gen2WorldTileset = data.world_tileset(target_map.tileset) \
		if target_map != null else null
	if target_map == null or target_tileset == null:
		return {"ok": false, "kind": &"spawn_warp", "reason": &"missing_map"}
	var from_map: Vector2i = map_id()
	var from_cell: Vector2i = player_cell
	_escape_map_tail()
	_apply_map(
		target_map, target_tileset, Vector2i(int(point["x"]), int(point["y"])),
		false, 0, entry
	)
	return {
		"ok": true,
		"kind": &"spawn_warp",
		"spawn": index,
		"from_map": from_map,
		"from_cell": from_cell,
		"to_map": map_id(),
		"to_cell": player_cell,
	}


## `FlyFunction`'s `.TryFly`: the badge and the map, which is everything it can
## refuse on before the region map is drawn. The choice itself belongs to
## whoever draws that map; [method warp_to_spawn] is what answers it.
func fly_request() -> Dictionary:
	if current_map == null:
		return _fly_failure(&"missing_map")
	if field_move_source(Gen2WorldFieldMove.MOVE_FLY).is_empty():
		return _fly_failure(&"move_not_known")
	if not state.is_engine_flag_active(Gen2WorldState.badge_flag(
		Gen2WorldFieldMove.BADGE_STORM, Gen2WorldState.is_crystal_profile(data)
	)):
		return _fly_failure(&"badge_required")
	if not _is_outdoor(current_map.environment):
		return _fly_failure(&"indoors")
	return {
		"ok": true,
		"kind": &"fly_requested",
		"move": Gen2WorldFieldMove.MOVE_FLY,
		"in_kanto": Gen2WorldRadio.is_kanto_landmark(
			landmark_backup(), Gen2WorldState.is_crystal_profile(data)
		),
		"visited": visited_flypoints(),
	}


static func _fly_failure(reason: StringName) -> Dictionary:
	return {"ok": false, "kind": &"fly_failed", "reason": reason}


## `CheckIfVisitedFlypoint` over the whole table: which `FLY_*` indexes the
## player may fly to. The bit tested is `wVisitedSpawns` at the flypoint's own
## spawn, which is what this project keeps as the `ENGINE_FLYPOINT_*` run.
func visited_flypoints() -> Array[int]:
	var out: Array[int] = []
	if data == null:
		return out
	var crystal: bool = Gen2WorldState.is_crystal_profile(data)
	for index: int in data.flypoint_count():
		var spawn: int = int(data.flypoint(index).get("spawn", -1))
		if spawn < 0:
			continue
		if state.is_engine_flag_active(Gen2WorldState.flypoint_flag(spawn, crystal)):
			out.append(index)
	return out


## `SweetScentEncounter`: a wild where one could have been stepped into. Its
## gates in order are `CanEncounterWildMon`, the Bug Contest's tables, then the
## rate and `ChooseWildEncounter`. The rate is read and never rolled against.
func sweet_scent_request(random: RandomNumberGenerator = null) -> Dictionary:
	if current_map == null or data == null:
		return _sweet_scent_failure(&"missing_map")
	if party_slot_with_move(Gen2WorldFieldMove.MOVE_SWEET_SCENT) < 0:
		return _sweet_scent_failure(&"move_not_known")
	if not can_encounter_wild_mon():
		return _sweet_scent_failure(&"no_encounter")
	var encounter: Dictionary = encounter_request(random, true)
	if encounter.is_empty():
		return _sweet_scent_failure(&"no_encounter")
	return {
		"ok": true,
		"kind": &"sweet_scent_requested",
		"move": Gen2WorldFieldMove.MOVE_SWEET_SCENT,
		"encounter": encounter,
	}


static func _sweet_scent_failure(reason: StringName) -> Dictionary:
	return {"ok": false, "kind": &"sweet_scent_failed", "reason": reason}


## `TeleportFunction`: the outdoor-only escape to the last Pokemon Center, whose
## whole test is the map being outdoors and that spawn being a spawn point. No
## badge. Staged rather than applied: `.TeleportScript` prints its line on the
## map being left and spends `pause 60` before `special WarpToSpawnPoint`.
func teleport_request() -> Dictionary:
	if current_map == null:
		return _teleport_failure(&"missing_map")
	if party_slot_with_move(Gen2WorldFieldMove.MOVE_TELEPORT) < 0:
		return _teleport_failure(&"move_not_known")
	if not _is_outdoor(current_map.environment):
		return _teleport_failure(&"not_outdoors")
	var spawn: int = spawn_index_of(last_spawn_map)
	if spawn < 0:
		return _teleport_failure(&"no_spawn_point")
	return _stage_escape(&"teleport_requested", Gen2WorldFieldMove.MOVE_TELEPORT, spawn)


static func _teleport_failure(reason: StringName) -> Dictionary:
	return {"ok": false, "kind": &"teleport_failed", "reason": reason}


## `DigFunction`, `EscapeRopeOrDig` with the Dig half of its type byte: a cave or
## a dungeon and a recorded dig warp, out through the warp the player came in by.
## The source's three bytes each refusing on zero is this record being empty.
func dig_request() -> Dictionary:
	if current_map == null:
		return _dig_failure(&"missing_map")
	if party_slot_with_move(Gen2WorldFieldMove.MOVE_DIG) < 0:
		return _dig_failure(&"move_not_known")
	var checked: StringName = _check_can_dig()
	if checked != &"":
		return _dig_failure(checked)
	return _stage_escape(&"dig_requested", Gen2WorldFieldMove.MOVE_DIG, -1)


## `DoPlayerMovement`'s own speed for a committed step: `STEP_BIKE` while riding,
## which is `big_step` and so four frames, and `STEP_WALK`'s eight otherwise.
## `.BikeCheck`'s downhill branch is not modelled: `BIKEFLAGS_DOWNHILL_F` is set
## by nothing in either pin, so no map can ask for the slower non-down step.
## [member run_held] is the one addition the cartridge has no branch for, and it
## reaches the walk alone.
func _step_frames_for_movement() -> int:
	if movement_mode == MOVEMENT_BIKE:
		return STEP_PASSES_FAST
	return STEP_PASSES_FAST if run_held and movement_mode == MOVEMENT_WALK \
		else STEP_PASSES_WALK


## `BikeFunction`'s `.TryBike`: `.CheckEnvironment` first, then the state the
## player is in. `BIKEFLAGS_ALWAYS_ON_BIKE_F` queues `Script_CantGetOffBike`
## rather than refusing, so `.done` answers 1 and the pack closes on its line.
## The three scripts are the caller's, each being text and a sprite update.
func bike_request() -> Dictionary:
	if current_map == null:
		return _bike_failure(&"missing_map")
	if not _can_ride_bike_here():
		return _bike_failure(&"cannot_use_bike")
	if movement_mode == MOVEMENT_WALK:
		movement_mode = MOVEMENT_BIKE
		player_sprite_number = Gen2WorldSprite.player_bike_sprite(_player_female)
		_apply_map_music()
		return {
			"ok": true, "kind": &"bike_on",
			"music": state.map_music(),
			"sprite": player_sprite_number,
		}
	if movement_mode != MOVEMENT_BIKE:
		return _bike_failure(&"cannot_use_bike")
	if always_on_bike():
		return {"ok": true, "kind": &"bike_cant_get_off", "sprite": player_sprite_number}
	movement_mode = MOVEMENT_WALK
	player_sprite_number = _walking_sprite()
	_apply_map_music()
	return {
		"ok": true, "kind": &"bike_off",
		"music": state.map_music(),
		"sprite": player_sprite_number,
	}


## `BIKEFLAGS_ALWAYS_ON_BIKE_F`: Route 16 and Route 17 set it, and it refuses
## both getting off and surfing.
func always_on_bike() -> bool:
	return state != null \
		and state.is_engine_flag_active(Gen2WorldState.always_on_bike_flag(data))


## `.CheckEnvironment`: outdoors, a cave or a gate, and standing on a tile whose
## permission's low nibble is `FLOOR_TILE`. Water and every wall code fail it.
func _can_ride_bike_here() -> bool:
	if not _is_outdoor(current_map.environment) \
		and current_map.environment not in [ENVIRONMENT_CAVE, ENVIRONMENT_GATE]:
		return false
	return (collision_permission_at(player_cell) & 0x0F) == Gen2WorldCollision.LAND_TILE


static func _bike_failure(reason: StringName) -> Dictionary:
	return {"ok": false, "kind": &"bike_failed", "reason": reason}


## `EscapeRopeFunction`, which is `EscapeRopeOrDig` with the other type byte: the
## same `.CheckCanDig` and the same `.DoDig`, without a move to know. The type
## only picks which text the queued script says and whether `.FailDig` says
## anything at all, so the refusal here is the item's silent one.
func escape_rope_request() -> Dictionary:
	if current_map == null:
		return _escape_rope_failure(&"missing_map")
	var checked: StringName = _check_can_dig()
	if checked != &"":
		return _escape_rope_failure(checked)
	## `.escaperope`'s `farcall SpecialKabutoChamber`, which runs while the
	## chamber is still the loaded map.
	var wall_event: int = unown_wall_event(EVENT_WALL_OPENED_IN_KABUTO_CHAMBER)
	if wall_event >= 0:
		state.set_event_flag(wall_event, true)
	var staged: Dictionary = _stage_escape(&"escape_rope_requested", 0, -1)
	staged["wall_event"] = wall_event
	_pending_escape["wall_event"] = wall_event
	return staged


## The three escapes print their line on the map they leave: a `waitbutton` or
## `pause 60` sits behind it and `special WarpToSpawnPoint` behind that.
## [param spawn] below zero is the recorded dig warp rather than a spawn.
func _stage_escape(kind: StringName, move_id: int, spawn: int) -> Dictionary:
	_pending_escape = {"ok": true, "kind": kind, "move": move_id, "spawn": spawn}
	return _pending_escape.duplicate(true)


func pending_escape() -> Dictionary:
	return _pending_escape.duplicate(true)


## The warp the staged escape owes, taken once its line has been acknowledged.
func complete_escape() -> Dictionary:
	if _pending_escape.is_empty():
		return {"ok": false, "kind": &"escape_failed", "reason": &"no_pending_escape"}
	var staged: Dictionary = _pending_escape
	_pending_escape = {}
	var spawn: int = int(staged["spawn"])
	## Dig and an Escape Rope both `newloadmap MAPSETUP_DOOR`, which
	## [method warp_to_dig_point] carries; `.TeleportScript` names its own.
	var warped: Dictionary = warp_to_spawn(spawn, MAP_ENTRY_TELEPORT) if spawn >= 0 \
		else warp_to_dig_point()
	if not bool(warped.get("ok", false)):
		return {
			"ok": false, "kind": &"escape_failed",
			"reason": StringName(warped.get("reason", &"no_dig_warp")),
		}
	staged["kind"] = &"escape_applied"
	staged["warp"] = warped
	return staged


## `.CheckCanDig`: a cave or a dungeon, and all three bytes of the recorded dig
## warp non-zero. Empty when it passes, otherwise the reason it did not.
func _check_can_dig() -> StringName:
	if current_map.environment not in [ENVIRONMENT_CAVE, ENVIRONMENT_DUNGEON]:
		return &"not_in_a_cave"
	if dig_warp.is_empty():
		return &"no_dig_warp"
	return &""


static func _dig_failure(reason: StringName) -> Dictionary:
	return {"ok": false, "kind": &"dig_failed", "reason": reason}


static func _escape_rope_failure(reason: StringName) -> Dictionary:
	return {"ok": false, "kind": &"escape_rope_failed", "reason": reason}


## `CheckForHiddenItems`, the whole of the Itemfinder: a BGEVENT_ITEM whose flag
## is still clear, four cells up and left of the player and four down and five
## right. Below, every BGEVENT_ITEM on the map as `{cell, item, flag, taken}`,
## scene-free so a probe can walk a map with no game running. An event whose three
## bytes do not decode is dropped rather than offered with a zero item.
func hidden_items() -> Array:
	var out: Array = []
	if current_map == null:
		return out
	var rows: Array = current_map.events.get("bg_events", [])
	for index: int in rows.size():
		var bg_event: Dictionary = (rows[index] as Dictionary).duplicate(true)
		if int(bg_event.get("type", -1)) != BGEVENT_ITEM:
			continue
		## `event_index` the way [method events_at] stamps it: it is the only
		## stable name a background event has, and [Gen2WorldCatalog] addresses a
		## patched item under a tile by it. Without it every record on a map
		## reads index 0 and a mod is told the wrong item.
		bg_event["event_index"] = index
		var record: Dictionary = _hidden_item_record(bg_event)
		if not bool(record.get("ok", false)):
			continue
		out.append({
			"cell": Vector2i(int(bg_event.get("x", 0)), int(bg_event.get("y", 0))),
			"item": int(record["item"]),
			"flag": int(record["flag"]),
			"taken": event_flag_active(int(record["flag"])),
		})
	return out


## The map's own hidden-item script at [param cell], queued and run through the
## ordinary path, so the bag write, the event flag, the save, `verbosegiveitem`'s
## FOUND text, its fanfare and its pack-full branch are all the host's exactly as
## a player walking onto the cell would get them. Answers the script results the
## way [method interact] does, and an empty array when the cell holds no hidden
## item, when it has already been taken, or when a script is already running.
func take_hidden_item(cell: Vector2i) -> Array:
	if current_map == null or _active_script != null or not _script_queue.is_empty():
		return []
	## [method events_at] rather than the raw list: it is what stamps `kind` and
	## `event_index`, both of which the request below is built from.
	for event: Dictionary in events_at(cell):
		if event.get("kind", &"") != &"bg_events" or int(event.get("type", -1)) != BGEVENT_ITEM:
			continue
		## The same gate `_active_events_at` applies to a background event, so a
		## flag already set answers nothing rather than giving the item twice.
		if not _bg_event_condition_active(event):
			continue
		var request: Dictionary = _hidden_item_request_for_event(event)
		if request.is_empty():
			continue
		_enqueue_script(request)
		return run_event_queue(false)
	return []


## `verbosegiveitem`'s own transaction for [param item], queued and run through
## the ordinary script path, so the bag write, the save, the received line, the
## fanfare and the pack-full branch are all the host's exactly as they are for a
## give the map makes. Answers the script results [method take_hidden_item] does,
## and an empty array when the item is not one the cartridge knows or when a script
## is already running. There is no cell, no event flag and no map behind it: the
## mod named the item and nothing else.
func give_item_gift(item: int, quantity: int = 1) -> Array:
	if current_map == null or _active_script != null or not _script_queue.is_empty():
		return []
	if item <= 0 or data == null or data.item_name(item).is_empty():
		return []
	_enqueue_script({
		"kind": &"item_gift",
		"map_group": current_map.group,
		"map_number": current_map.number,
		"bank": int(current_map.events.get("bank", 0)),
		"item": item,
		"quantity": maxi(1, quantity),
	})
	return run_event_queue(false)


func hidden_item_nearby() -> bool:
	if current_map == null:
		return false
	for entry: Dictionary in hidden_items():
		if bool(entry["taken"]):
			continue
		var offset: Vector2i = player_cell - (entry["cell"] as Vector2i)
		if offset.x < -5 or offset.x > 4 or offset.y < -4 or offset.y > 4:
			continue
		return true
	return false


## The three maps `engine/events/card_key.asm`, `basement_key.asm` and
## `squirtbottle.asm` name by constant before they do anything else. Each row is
## the Crystal id and the Gold and Silver one; group 3 runs eight lower on
## pokegold from `UNION_CAVE_1F`, which is what moves the underground.
const KEY_ITEM_MAPS: Dictionary = {
	&"RADIO_TOWER_3F": {&"crystal": Vector2i(3, 19), &"gold": Vector2i(3, 19)},
	&"GOLDENROD_UNDERGROUND": {&"crystal": Vector2i(3, 53), &"gold": Vector2i(3, 45)},
	&"ROUTE_36": {&"crystal": Vector2i(10, 3), &"gold": Vector2i(10, 3)},
}

## The two tiles `GetFacingTileCoord`'s results are compared against. The source
## writes them in the object coordinate space, which is four cells ahead of the
## map's own on each axis (`cp 18` / `cp 6` and `cp 22` / `cp 10`); both are the
## cell the map's own `bg_event` for that door sits on.
const CARD_KEY_SLOT_CELL: Vector2i = Vector2i(14, 2)
const BASEMENT_DOOR_CELL: Vector2i = Vector2i(18, 6)


func _is_on_key_item_map(name: StringName) -> bool:
	if current_map == null:
		return false
	var row: Dictionary = KEY_ITEM_MAPS[name]
	var id: Vector2i = row[&"crystal"] if Gen2WorldState.is_crystal_profile(data) \
		else row[&"gold"]
	return map_id() == id


## `_CardKey`: the map, then `wPlayerDirection & %1100` against `OW_UP`, then the
## faced tile. Everything it passes is `QueueScript` on a `farsjump` to
## `CardKeySlotScript`, which no importer pins by name; the map's own
## `bg_event 14, 2, BGEVENT_UP` is that script, and it is the tile the routine
## already insists the player is facing.
func card_key_request() -> Dictionary:
	if not _is_on_key_item_map(&"RADIO_TOWER_3F"):
		return {"ok": false, "kind": &"card_key_failed", "reason": &"wrong_map"}
	if player_facing != Gen2WorldSprite.FACING_UP:
		return {"ok": false, "kind": &"card_key_failed", "reason": &"not_facing_slot"}
	if facing_cell() != CARD_KEY_SLOT_CELL:
		return {"ok": false, "kind": &"card_key_failed", "reason": &"not_facing_slot"}
	return _faced_bg_event_script_request(&"card_key_used", &"card_key_failed")


## `_BasementKey`, which is `_CardKey` without the direction test: the door is a
## `BGEVENT_READ`, so it answers whichever way the player is facing it from.
func basement_key_request() -> Dictionary:
	if not _is_on_key_item_map(&"GOLDENROD_UNDERGROUND"):
		return {"ok": false, "kind": &"basement_key_failed", "reason": &"wrong_map"}
	if facing_cell() != BASEMENT_DOOR_CELL:
		return {"ok": false, "kind": &"basement_key_failed", "reason": &"not_facing_door"}
	return _faced_bg_event_script_request(&"basement_key_used", &"basement_key_failed")


## `_Squirtbottle`, which differs from the other two in never failing:
## `wItemEffectSucceeded` is set before the script is queued, and
## `.CheckCanUseSquirtbottle` only picks which half of it runs. So the refusal is
## the queued script's own `_SquirtbottleNothingText` rather than `.Oak`.
##
## The test is `GetFacingObject` and `cp SPRITEMOVEDATA_SUDOWOODO`, the same
## shape rock_smash_request() uses, behind the Route 36 map check.
func squirtbottle_request() -> Dictionary:
	var nothing: Dictionary = {"ok": true, "kind": &"squirtbottle_nothing"}
	if not _is_on_key_item_map(&"ROUTE_36"):
		return nothing
	var tree: Gen2WorldObject = object_at(object_facing_cell())
	if tree == null or not tree.is_sudowoodo():
		return nothing
	var script: Dictionary = _watered_weird_tree_script(tree.index)
	if script.is_empty():
		return nothing
	script["ok"] = true
	script["kind"] = &"squirtbottle_watered"
	script["bank"] = int(current_map.events.get("bank", 0))
	return script


## `WateredWeirdTreeScript` is a label inside `SudowoodoScript` that no event
## points at, so the cache carries no pointer of its own. Its position is
## structural instead: the object's script opens `checkitem SQUIRTBOTTLE / iftrue
## .Fight`, and the label sits just past the `closetext` that ends `.Fight`'s
## yes/no ask. `.Fight` is a branch target and so is cached, which is why the
## answer is that address and an offset into it rather than a bare address.
## Empty for anything that does not decode that way.
func _watered_weird_tree_script(object_index: int) -> Dictionary:
	if data == null or current_map == null:
		return {}
	var rows: Array = current_map.events.get("objects", [])
	if object_index < 0 or object_index >= rows.size():
		return {}
	var bank: int = int(current_map.events.get("bank", 0))
	## Both opcodes sit below `$52`, where the two command tables still agree,
	## so neither needs resolving through Gen2WorldScript.raw_opcode().
	var branch: int = _script_command_end(
		bank, int((rows[object_index] as Dictionary).get("script", 0)),
		Gen2WorldScript.IFTRUE, true
	)
	if branch <= 0:
		return {}
	var offset: int = _script_command_end(bank, branch, Gen2WorldScript.CLOSETEXT, false)
	return {"script": branch, "offset": offset} if offset > 0 else {}


## Walks a script from [param address] to the first [param opcode]. Answers that
## command's branch target when [param branch] is set, and otherwise how many
## bytes in the command after it starts. 0 for a stream that ends or fails to
## decode first, which is what leaves a caller with no label to jump to.
func _script_command_end(bank: int, address: int, opcode: int, branch: bool) -> int:
	var crystal: bool = data.id != &"gold" and data.id != &"silver"
	var raw: PackedByteArray = data.world_script(bank, address)
	var offset: int = 0
	while offset < raw.size():
		var command: Dictionary = Gen2WorldScript.command_at(raw, offset, crystal)
		if not bool(command.get("ok", false)):
			return 0
		offset += int(command["width"])
		if int(command["opcode"]) == opcode:
			return int(command.get("address", 0)) if branch else offset
	return 0


## The `farsjump` the two key items end on: the script the faced cell's own
## background event names, which is the label each routine jumps to.
func _faced_bg_event_script_request(kind: StringName, failure: StringName) -> Dictionary:
	for event: Dictionary in _active_events_at(facing_cell()):
		if event.get("kind", &"") != &"bg_events":
			continue
		var script: int = _script_address_for_event(event)
		if script <= 0:
			continue
		return {
			"ok": true,
			"kind": kind,
			"bank": int(current_map.events.get("bank", 0)),
			"script": script,
			"cell": facing_cell(),
		}
	return {"ok": false, "kind": failure, "reason": &"missing_script"}


## `QueueScript` for a resolved key-item effect: the request the pack answered
## with is queued and run, so its script reaches the host exactly as an
## interaction's does.
func queue_item_script(request: Dictionary) -> Array:
	if current_map == null or int(request.get("script", 0)) <= 0:
		return []
	_enqueue_script({
		"kind": StringName(request.get("kind", &"item_script")),
		"map_group": current_map.group,
		"map_number": current_map.number,
		"cell": player_cell,
		"bank": int(request.get("bank", 0)),
		"script": int(request.get("script", 0)),
		"offset": int(request.get("offset", 0)),
	})
	return run_event_queue(false)


## `.TryFish`'s own refusals, asked without casting: the pack has to know whether
## `FishFunction` would reach `.FailFish` before it decides to close.
func fishing_check(rod: StringName) -> Dictionary:
	if current_map == null or data == null:
		return {"ok": false, "reason": &"missing_map"}
	var context: Dictionary = _fishing_context(rod)
	return {"ok": true} if bool(context.get("ok", false)) \
		else {"ok": false, "reason": StringName(context.get("reason", &"cannot_fish"))}


## `.DoDig`: the recorded dig warp copied into `wNextWarp` and walked out of, so
## the player lands on the outdoor map's own warp tile. Shared by Dig and by an
## Escape Rope, which is the same routine with a different type byte.
func warp_to_dig_point() -> Dictionary:
	if dig_warp.is_empty():
		return {"ok": false, "kind": &"dig_warp", "reason": &"no_dig_warp"}
	var target_map: Gen2WorldMap = data.world_map(
		int(dig_warp["map_group"]), int(dig_warp["map_number"])
	) if data != null else null
	var target_tileset: Gen2WorldTileset = data.world_tileset(target_map.tileset) \
		if target_map != null else null
	if target_map == null or target_tileset == null:
		return {"ok": false, "kind": &"dig_warp", "reason": &"missing_map"}
	var warps: Array = target_map.events.get("warps", [])
	var index: int = int(dig_warp["warp"]) - 1
	if index < 0 or index >= warps.size():
		return {"ok": false, "kind": &"dig_warp", "reason": &"missing_destination"}
	var destination: Dictionary = warps[index]
	var from_map: Vector2i = map_id()
	var from_cell: Vector2i = player_cell
	_escape_map_tail()
	_apply_map(
		target_map, target_tileset,
		Vector2i(int(destination["x"]), int(destination["y"])),
		false, 0, MAP_ENTRY_DOOR
	)
	return {
		"ok": true,
		"kind": &"dig_warp",
		"warp": int(dig_warp["warp"]),
		"from_map": from_map,
		"from_cell": from_cell,
		"to_map": map_id(),
		"to_cell": player_cell,
	}


## The schedule update produced by the most recent map change, for a host that
## wants to report where the roamers went.
func last_schedule() -> Dictionary:
	return _last_schedule.duplicate(true)


## Reloads the current map's live object records without changing the player
## cell or queuing a second map transition. This is the host effect of
## [code]reloadmapafterbattle[/code] when the suspended script resumes.
func reload_current_map() -> Dictionary:
	if current_map == null or current_tileset == null:
		return {"ok": false, "reason": &"missing_map"}
	_block_overrides.clear()
	block_revision += 1
	_pending_cut.clear()
	_pending_surf.clear()
	_pending_whirlpool.clear()
	_pending_strength.clear()
	_pending_escape.clear()
	_pending_waterfall.clear()
	_pending_headbutt.clear()
	_pending_rock_smash.clear()
	_pending_flash.clear()
	_clear_transient_object_visibility_overrides()
	state.reset_map_reload_flags()
	# `Script_reloadmap` asks for MAPSTATUS_ENTER, so a battle's own reload runs
	# EnterMap and takes its five-step cooldown with it: that is what stops a
	# second wild the step after the first.
	state.set_wild_encounter_cooldown(Gen2WorldState.WILD_ENCOUNTER_COOLDOWN_STEPS)
	# `EnterMap`'s one entry-method branch: `hMapEntryMethod` is
	# MAPSETUP_RELOADMAP here and nowhere else, and that method alone zeroes
	# `wPoisonStepCount`. So a battle, a `reloadmap` and the catch tutorial each
	# start the four-step poison phase again, and a warp or a door does not.
	state.clear_poison_step_count()
	_load_objects()
	return {"ok": true, "kind": &"reload_map", "map": map_id(), "cell": player_cell}


func _on_world_state_changed() -> void:
	set_object_time(object_hour, object_time_of_day)
	## RefreshMapSprites runs CheckUpdatePlayerSprite after HandleNewMap's own
	## callback, and Route 16 and Route 17 set the flag from theirs.
	if always_on_bike() and movement_mode != MOVEMENT_BIKE:
		_apply_map_setup_player_state()


## `GetMonSprite` itself: a variable slot resolves through the table and is
## re-read, because a script may assign one a Pokemon sprite, and an unassigned
## slot answers `WALKING_SPRITE`. A day care byte keeps its own id here and is
## read for its species by [method _mon_icon_for_sprite]; an empty slot is
## `.NoBreedmon`, which is the same 1.
func _resolved_sprite(sprite_number: int) -> int:
	var resolved: int = sprite_number
	## The table is a byte per slot and a slot may name another one, so the walk
	## is bounded rather than trusted to end.
	for _pass: int in 4:
		if resolved == SPRITE_DAY_CARE_MON_1 or resolved == SPRITE_DAY_CARE_MON_2:
			return resolved if _day_care_species(resolved) > 0 else SPRITE_CHRIS
		if resolved < Gen2WorldScriptRunner.VARIABLE_SPRITE_BASE:
			return resolved
		var assigned: int = state.variable_sprite(resolved) if state != null else 0
		if assigned == 0:
			return SPRITE_CHRIS
		resolved = assigned
	return SPRITE_CHRIS


## `SpriteMons` for the thirty-five reusable shapes, and `ReadMonMenuIcon` on
## the species itself for the two day care bytes, which is what
## `LoadOverworldMonIcon` does with `wBreedMon1Species` and `wBreedMon2Species`.
func _mon_icon_for_sprite(sprite_number: int) -> int:
	if sprite_number == SPRITE_DAY_CARE_MON_1 or sprite_number == SPRITE_DAY_CARE_MON_2:
		return data.mon_menu_icon(_day_care_species(sprite_number)) if data != null else 0
	return Gen2WorldSprite.mon_icon_for_sprite(sprite_number)


func _day_care_species(sprite_number: int) -> int:
	if state == null:
		return 0
	var mon: Gen2SaveMon = state.day_care_mon(
		0 if sprite_number == SPRITE_DAY_CARE_MON_1 else 1
	)
	return 0 if mon == null else mon.species


## One row of a map's object events as a live object. `GetMonSprite`'s `.Variable`
## branch reads wVariableSprites and falls through to `.NoBreedmon` on a zero slot,
## whose `ld a, WALKING_SPRITE` is 1 and so `SPRITE_CHRIS` by coincidence of two
## constant lists. Reaching that fallback is the exception: every slot any map
## stands an object on has a row, so an object drawn as the player means the table
## lost one. Below, `LoadOpponentTrainerAndPokemonWithOTSprite`'s tail, which
## writes a sprite number straight into `wMapObjects` because the Battle Tower's
## opponent is drawn at random and its object event carries a placeholder.
func set_object_sprite(index: int, sprite_number: int) -> Dictionary:
	if index < 0 or index >= objects.size() or sprite_number <= 0:
		return {"ok": false, "reason": &"invalid_object_sprite", "object": index}
	var object: Gen2WorldObject = objects[index] as Gen2WorldObject
	object.sprite_number = sprite_number
	var icon_number: int = _mon_icon_for_sprite(sprite_number)
	object.sprite = data.overworld_icon(icon_number) if icon_number > 0 \
		else data.overworld_sprite(sprite_number)
	set_object_time(object_hour, object_time_of_day)
	return {"ok": true, "object": index, "sprite": sprite_number}


func _object_from_event(index: int, value: Dictionary) -> Gen2WorldObject:
	var sprite_number: int = _resolved_sprite(int(value.get("sprite", 0)))
	var sprite: Gen2WorldSprite = null
	var icon_number: int = _mon_icon_for_sprite(sprite_number)
	if icon_number > 0:
		sprite = data.overworld_icon(icon_number)
	else:
		sprite = data.overworld_sprite(sprite_number)
	var object_event: Dictionary = value.duplicate(true)
	object_event["sprite"] = sprite_number
	return Gen2WorldObject.from_event(index, object_event, sprite)


## The people standing on the maps [method map_placements] puts around this one,
## for a view wide enough to see them. Deliberately not part of [member objects]:
## `ReadObjectEvents` fills `wMapObjects` from the loaded map alone, so on the
## cartridge a connected map's people do not exist until its own map load builds
## them. These take no step, run no script, answer no collision and are not talked
## to; they stand where their map's event data puts them, which is what a town seen
## from the route next to it looks like. Each entry is `{object, offset}`, the
## offset being the map's own origin in walk cells.
func connected_map_objects() -> Array:
	if not _connected_objects.is_empty() or current_map == null or data == null:
		return _connected_objects
	for placement: Dictionary in map_placements().values():
		var map: Gen2WorldMap = placement["map"]
		var offset: Vector2i = (placement["origin"] as Vector2i) \
			* RomLayout.MAP_BLOCK_CELL_WIDTH
		var rows: Array = map.events.get("objects", [])
		for index: int in rows.size():
			var object: Gen2WorldObject = _object_from_event(index, rows[index])
			if object.sprite == null:
				continue
			object.flag_hidden = object.event_flag_active(state)
			object.active = object.visible_at(object_hour, object_time_of_day) \
				and not object.flag_hidden
			if not object.active:
				continue
			_connected_objects.append({"object": object, "offset": offset})
	return _connected_objects


## [param carry_presentation] keeps the live emote and movement trail of the
## records being replaced, for the reloads that happen inside one visit to a map
## rather than on the way into it. See Gen2WorldObject.carry_presentation_from().
func _load_objects(carry_presentation: bool = false) -> void:
	var previous: Array = objects if carry_presentation else []
	## `ReadObjectEvents` clears every object struct, object zero included.
	if not carry_presentation:
		_player_object = Gen2WorldObject.new()
	objects = []
	if current_map == null or data == null:
		return
	var rows: Array = current_map.events.get("objects", [])
	for index: int in rows.size():
		var object: Gen2WorldObject = _object_from_event(index, rows[index])
		var key: String = _object_key(current_map.group, current_map.number, index)
		if _object_position_overrides.has(key):
			object.cell = _object_position_overrides[key]
		if _object_facing_overrides.has(key):
			object.facing = int(_object_facing_overrides[key])
		## A reload that carries presentation is a refresh under a running
		## script, not a map load, so the flag answer is carried with it rather
		## than re-read: [method load_object_masks] is a map-setup step.
		if index < previous.size():
			object.carry_presentation_from(previous[index] as Gen2WorldObject)
			object.flag_hidden = (previous[index] as Gen2WorldObject).flag_hidden
		else:
			object.flag_hidden = object.event_flag_active(state)
		objects.append(object)
	set_object_time(object_hour, object_time_of_day)


## The source changeblock macro receives walk-cell coordinates. The cartridge
## adds four tile coordinates before resolving the padded block buffer. Since
## one block contains two walk cells and the live map exposes only its interior,
## the resulting local block is floor((source + 4) / 2) - 2.
func _script_block_cell(source_cell: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(source_cell.x + 4) / 2.0) - 2,
		floori(float(source_cell.y + 4) / 2.0) - 2,
	)


func _find_sight_request() -> Dictionary:
	if current_map == null or state.trainer_sightings_off():
		return {}
	var bank: int = int(current_map.events.get("bank", 0))
	var rows: Array = current_map.events.get("objects", [])
	for object: Gen2WorldObject in objects:
		if not object.active \
			or object.object_type != Gen2WorldObject.OBJECTTYPE_TRAINER \
			or object.sight_range <= 0 or object.event_script <= 0:
			continue
		if object.event_flag_active(state) or object.trainer_flag_active(state):
			continue
		var sight: Dictionary = _sight_distance(object)
		if sight.is_empty() or int(sight["distance"]) > object.sight_range:
			continue
		if object.index < 0 or object.index >= rows.size() or not rows[object.index] is Dictionary:
			continue
		var event: Dictionary = (rows[object.index] as Dictionary).duplicate(true)
		event["kind"] = &"objects"
		event["object_index"] = object.index
		event["trigger"] = &"sight"
		var request: Dictionary = _trainer_request_for_event(event)
		if request.is_empty():
			request = {
				"kind": &"sight",
				"map_group": current_map.group,
				"map_number": current_map.number,
				"cell": object.cell,
				"bank": bank,
				"script": object.event_script,
				"object_index": object.index,
				"event": event,
			}
		request["kind"] = &"sight"
		request["distance"] = int(sight["distance"])
		request["direction"] = sight["direction"]
		return request
	return {}


func _sight_distance(object: Gen2WorldObject) -> Dictionary:
	var delta: Vector2i = player_cell - object.cell
	var direction: Vector2i = Vector2i.ZERO
	match object.facing:
		Gen2WorldSprite.FACING_DOWN:
			if delta.x == 0 and delta.y > 0:
				direction = Vector2i.DOWN
		Gen2WorldSprite.FACING_UP:
			if delta.x == 0 and delta.y < 0:
				direction = Vector2i.UP
		Gen2WorldSprite.FACING_LEFT:
			if delta.y == 0 and delta.x < 0:
				direction = Vector2i.LEFT
		Gen2WorldSprite.FACING_RIGHT:
			if delta.y == 0 and delta.x > 0:
				direction = Vector2i.RIGHT
	if direction == Vector2i.ZERO:
		return {}
	return {"distance": absi(delta.x) + absi(delta.y), "direction": direction}
