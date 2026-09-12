class_name Gen1Pikachu
extends RefCounted

## Yellow's starter walking behind the player: `engine/pikachu/pikachu_follow.asm`
## run once an overworld pass over the sprite slot the map never zeroes, with
## `pikachu_status.asm`'s party test and `pikachu_happiness.asm`'s two bytes.
## Cells are the struct's map coordinates less the four the cartridge adds, and
## `pixel` is the sprite's screen position put back into map pixels.

## `SPRITE_FACING_*`, which the struct stores as the image row.
const FACING_DOWN: int = 0
const FACING_UP: int = 4
const FACING_LEFT: int = 8
const FACING_RIGHT: int = 12
## The follow buffer's commands: a step and, from five up, a two-cell hop.
const CMD_DOWN: int = 1
const CMD_UP: int = 2
const CMD_LEFT: int = 3
const CMD_RIGHT: int = 4
const CMD_HOP: int = 5
## `wPikachuFollowCommandBuffer` is sixteen bytes; the cartridge never checks.
const BUFFER_SIZE: int = 16
## `wPikachuOverworldStateFlags`.
const FLAG_NOT_FOLLOWING: int = 1 << 1
const FLAG_TRICK: int = 1 << 2
const FLAG_NO_DRAW: int = 1 << 3
const FLAG_CONNECTION: int = 1 << 4
const FLAG_STEP_HIDDEN: int = 1 << 5
const FLAG_HIDDEN: int = 1 << 7
## `wPikachuSpawnStateFlags`.
const SPAWN_FLAG_FOLLOWING: int = 1 << 5
const SPAWN_FLAG_SURFING: int = 1 << 6
const SPAWN_FLAG_STARTER: int = 1 << 7
## `wPikachuSpawnState`: where the next placement puts the sprite.
const SPAWN_ON_PLAYER: int = 0
const SPAWN_RIGHT: int = 1
const SPAWN_BEHIND: int = 2
const SPAWN_ON_PLAYER_DOWN: int = 3
const SPAWN_BELOW: int = 4
const SPAWN_ABOVE: int = 5
const SPAWN_LEFT: int = 6
const SPAWN_IN_FRONT: int = 7
## `wSpritePikachuStateData1MovementStatus`'s low seven bits.
const STATUS_SPAWN: int = 0
const STATUS_DECIDE: int = 1
const STATUS_IDLE: int = 2
const STATUS_WALK: int = 3
const STATUS_HOP: int = 4
const STATUS_FAST: int = 5
const STATUS_ARC: int = 6
const STATUS_STEP_IN_PLACE: int = 7
const STATUS_SHUFFLE: int = 8
const STATUS_SPIN: int = 9
const STATUS_FACE_PLAYER: int = 0x80
const IMAGE_HIDDEN: int = -1
const PICTURE_ID: int = 0x49
## `PIKACHU_SPRITE_INDEX`: slot fifteen of `wSpriteStateData1`.
const SPRITE_INDEX: int = 0x0F
const IMAGE_BASE: int = 0x10
const CELL_PIXELS: int = 16
## `InitPlayerData2`'s two bytes.
const HAPPINESS_START: int = 90
const MOOD_START: int = 0x80
## `PIKAHAPPY_*`, one-based rows of `HappinessChangeTable`.
const HAPPY_LEVELUP: int = 1
const HAPPY_USEDITEM: int = 2
const HAPPY_USEDXITEM: int = 3
const HAPPY_GYMLEADER: int = 4
const HAPPY_USEDTMHM: int = 5
const HAPPY_WALKING: int = 6
const HAPPY_DEPOSITED: int = 7
const HAPPY_FAINTED: int = 8
const HAPPY_PSNFNT: int = 9
const HAPPY_CARELESSTRAINER: int = 10
const HAPPY_TRADE: int = 11
const HAPPINESS_CHANGES: Array = [
	[5, 3, 2], [5, 3, 2], [1, 1, 0], [3, 2, 1], [1, 1, 0], [2, 1, 1],
	[-3, -3, -5], [-1, -1, -1], [-5, -5, -10], [-5, -5, -10], [-10, -10, -20],
]
const MOODS: Array = [0x8A, 0x83, 0x80, 0x80, 0x94, 0x80, 0x62, 0x6C, 0x62, 0x6C, 0x00]
## `Pointer_fc7e3`: facing, x step, y step and status for commands one to eight.
const COMMAND_ROWS: Array = [
	[0, 0, 1, STATUS_WALK], [4, 0, -1, STATUS_WALK],
	[8, -1, 0, STATUS_WALK], [12, 1, 0, STATUS_WALK],
	[0, 0, 1, STATUS_HOP], [4, 0, -1, STATUS_HOP],
	[8, -1, 0, STATUS_HOP], [12, 1, 0, STATUS_HOP],
]
## `Pointer_fc8d6`, read from the last row down: a y lift and an x sway.
const ARC_ROWS: Array = [
	[0, 0], [-2, 1], [-4, 2], [-2, 3], [0, 4], [-2, 3], [-4, 2], [-2, 1], [0, 0],
	[-2, -1], [-4, -2], [-2, -3], [0, -4], [-2, -3], [-4, -2], [-2, -1], [0, 0],
]
const ARC_PASSES: int = 0x11
const STEP_IN_PLACE_PASSES: int = 0x30
const SHUFFLE_PASSES: int = 0x20
const TRICK_REST_PASSES: int = 0x10
const IDLE_PASSES: int = 0x20
const TRICK_FRAME_PASSES: int = 8
const WALK_PASSES: int = 8
const FAST_PASSES: int = 4
const HAPPY_WALK_THRESHOLD: int = 80
## `IsSpriteInFrontOfPlayer`'s exact match and `wPikachuCollisionCounter`'s eight.
const COLLISION_PASSES: int = 8
## `EmotionBubble`'s `ld c, 60`.
const EMOTE_FRAMES: int = 60
## `.Facings`, clockwise.
const CLOCKWISE: Dictionary = {
	FACING_DOWN: FACING_LEFT, FACING_LEFT: FACING_UP,
	FACING_UP: FACING_RIGHT, FACING_RIGHT: FACING_DOWN,
}
## `SetPikachuSpawnOutside`'s two lists and its named maps.
const OUTSIDE_BELOW_MAPS: Array[int] = [0xC2, 0x4C, 0x4F, 0xBA, 0xBE, 0xB8, 0x54]
const OUTSIDE_FACING_MAPS: Array[int] = [0x2F, 0xE6, 0x3E, 0x5E, 0x80, 0x31, 0xA4]
const OAKS_LAB: int = 0x28
const ROUTE_22_GATE: int = 0xC1
const ROUTE_2_GATE: int = 0x31
const MT_MOON_B1F: int = 0x3C
const ROCK_TUNNEL_1F: int = 0x52
const VIRIDIAN_FOREST_NORTH_GATE: int = 0x2F
const VIRIDIAN_FOREST_SOUTH_GATE: int = 0x32
## `Pointer_fc68e`.
const WARP_PAD_RIGHT_MAPS: Array[int] = [
	0x33, 0xDD, 0xDF, 0xE0, 0xE1, 0xDE, 0xEC, 0x7F, 0xA8, 0xA9, 0xAA,
]

## `wPikachuHappiness`, `wPikachuMood` and `wPikachuEmotionModifier`.
var happiness: int = HAPPINESS_START
var mood: int = MOOD_START
var emotion_modifier: int = 0
var flags: int = 0
var spawn_state: int = SPAWN_ON_PLAYER
var spawn_flags: int = 0
var collision_counter: int = 0
## `wStepCounter`, zeroed by `ClearVariablesOnEnterMap`.
var step_counter: int = 0
## Whether A found the follower in front of the player: `wd435`.
var talked_to: bool = false
var ailing: bool = false
var asleep: bool = false

var picture_id: int = 0
var status: int = STATUS_SPAWN
var image: int = IMAGE_HIDDEN
var facing: int = FACING_DOWN
var step: Vector2i = Vector2i.ZERO
var cell: Vector2i = Vector2i(-4, -4)
var pixel: Vector2i = Vector2i.ZERO
var intra_counter: int = 0
var anim_frame: int = 0
var walk_counter: int = 0
var grass_priority: bool = false
## `wd432` and `wd431`: the arc row the pixels currently carry.
var arc_offset: Vector2i = Vector2i.ZERO
## Oldest first; `wPikachuFollowCommandBufferSize` is `size() - 1`.
var buffer: Array[int] = []
## `ShowPikachuEmoteBubble`: `EmotionBubble` over slot fifteen for its sixty frames.
var emote: int = -1
var emote_frames: int = 0


## What the follower reads off the player each pass: the cell `wYCoord` holds,
## which is the one being left while a step is in flight, the facing as
## `SPRITE_FACING_*`, `wWalkCounter`, the pixels that step has spent, and the
## flags the routines test.
class View:
	var cell: Vector2i = Vector2i.ZERO
	var facing: int = FACING_DOWN
	var walk_counter: int = 0
	var step_pixels: Vector2i = Vector2i.ZERO
	var riding: bool = false
	var biking: bool = false
	var font_loaded: bool = false
	var spinning: bool = false
	var ledge: bool = false
	var player_image: int = 0


func visible() -> bool:
	return image != IMAGE_HIDDEN


func show_emote(kind: int) -> void:
	emote = kind
	emote_frames = EMOTE_FRAMES


## One hardware frame of the bubble; true on the frame it goes away.
func tick_emote() -> bool:
	if emote_frames <= 0:
		return false
	emote_frames -= 1
	return emote_frames == 0


func following() -> bool:
	return (flags & FLAG_NOT_FOLLOWING) == 0


func drawn_facing() -> int:
	return (image & 0x0C) >> 2


func drawn_frame() -> int:
	return image & 0x03


## The cell whose tiles `.GetNPCCurrentTile` reads under the sprite.
func grass_cell() -> Vector2i:
	return Vector2i((pixel.x + 2) >> 4, pixel.y >> 4)


func to_dict() -> Dictionary:
	return {
		"happiness": happiness, "mood": mood, "emotion_modifier": emotion_modifier,
		"flags": flags & (FLAG_NOT_FOLLOWING | FLAG_NO_DRAW), "spawn_state": spawn_state,
	}


func restore(source: Dictionary) -> void:
	happiness = clampi(int(source.get("happiness", HAPPINESS_START)), 0, 255)
	mood = clampi(int(source.get("mood", MOOD_START)), 0, 255)
	emotion_modifier = int(source.get("emotion_modifier", 0))
	flags = int(source.get("flags", 0)) & (FLAG_NOT_FOLLOWING | FLAG_NO_DRAW)
	spawn_state = int(source.get("spawn_state", SPAWN_ON_PLAYER))


## `IsSurfingPikachuInParty`, run every pass: both party bits, off the summary
## the screen keeps. `CheckPikachuStatusCondition` is the starter's status byte.
func set_party(
	starter_alive: bool, surfing: bool, starter_ailing: bool = false,
	starter_asleep: bool = false
) -> void:
	spawn_flags &= ~(SPAWN_FLAG_STARTER | SPAWN_FLAG_SURFING)
	if starter_alive:
		spawn_flags |= SPAWN_FLAG_STARTER
	if surfing:
		spawn_flags |= SPAWN_FLAG_SURFING
	ailing = starter_ailing
	asleep = starter_asleep


## `GetPikaPicAnimationScriptIndex`: the mood picks a column of the happiness
## table and the happiness its row, each the first threshold not below it.
func mood_emotion(tables: Dictionary) -> int:
	var column: int = 0
	for row: Array in tables.get("moods", []):
		column = int(row[1])
		if int(row[0]) >= mood:
			break
	for row: Array in tables.get("happiness", []):
		if int(row[0]) >= happiness or row == tables["happiness"][-1]:
			return int(row[column])
	return 0


func starter_alive() -> bool:
	return (spawn_flags & SPAWN_FLAG_STARTER) != 0


func surfing() -> bool:
	return (spawn_flags & SPAWN_FLAG_SURFING) != 0


## `ModifyPikachuHappiness`: the row's column is the happiness hundred, the
## table's own sign test is `cp 100`, and the mood only moves toward the row's
## value.
func modify_happiness(kind: int, starter_in_slot: bool = true) -> void:
	if not starter_alive() or not starter_in_slot or kind < HAPPY_LEVELUP or kind > HAPPY_TRADE:
		return
	var column: int = 0 if happiness < 100 else (1 if happiness < 200 else 2)
	var change: int = int(HAPPINESS_CHANGES[kind - 1][column])
	happiness = clampi(happiness + change, 0, 255)
	var target: int = int(MOODS[kind - 1])
	if target == 0x80:
		return
	if target < 0x80:
		if mood >= target:
			mood = target
		return
	if mood < target and emotion_modifier == 0:
		mood = target


## `StepCountCheck`'s `dec [wStepCounter]` and `UpdatePikachuHappinessAndMood`
## behind the poison check: a coin flip for happiness on the step the byte
## wraps to zero, and the mood walking one toward 128.
func count_step(coin: bool) -> void:
	step_counter = (step_counter - 1) & 0xFF
	if step_counter == 0 and coin:
		modify_happiness(HAPPY_WALKING)
	if mood == 0x80:
		emotion_modifier = 0
		return
	mood += 1 if mood < 0x80 else -1
	if mood == 0x80:
		emotion_modifier = 0


func set_mood(value: int, modifier: int) -> void:
	mood = value
	emotion_modifier = modifier


## `Func_fcc08`: the command a player step appends, read off the direction
## pressed. `HandleLedges` simulates two presses for one hop and `Func_fcc64`
## toggles bit 6 between them, which is one command a hop.
func on_player_step(direction: Vector2i, hop: bool, riding: bool) -> void:
	if not _may_append(riding):
		return
	var command: int = _direction_command(direction)
	if command > 0:
		_append(command + (CMD_HOP - 1 if hop else 0))


## `Func_fcc23`.
func _may_append(riding: bool) -> bool:
	return (flags & (FLAG_STEP_HIDDEN | FLAG_HIDDEN)) == 0 \
		and (spawn_flags & SPAWN_FLAG_STARTER) != 0 and not riding


static func _direction_command(direction: Vector2i) -> int:
	if direction == Vector2i.UP:
		return CMD_UP
	if direction == Vector2i.DOWN:
		return CMD_DOWN
	if direction == Vector2i.LEFT:
		return CMD_LEFT
	if direction == Vector2i.RIGHT:
		return CMD_RIGHT
	return 0


func _append(command: int) -> void:
	if buffer.size() < BUFFER_SIZE:
		buffer.append(command)


## `SchedulePikachuSpawnForAfterText`, from `LoadMapHeader` and two scripts.
func schedule_after_map_load(view: View) -> void:
	if (flags & FLAG_CONNECTION) != 0:
		flags &= ~FLAG_CONNECTION
		_place(view)
		spawn_state = SPAWN_ON_PLAYER
		facing = view.facing
		return
	flags &= ~FLAG_NOT_FOLLOWING
	_clear_sprite()
	image = IMAGE_HIDDEN
	buffer.clear()
	_calculate_facing(view)


## `.loadNewMap`: a connection crossed.
func on_connection() -> void:
	flags |= FLAG_CONNECTION
	spawn_state = SPAWN_BEHIND


## `WarpFound2`'s three placements, chosen by which map the warp leaves from and
## which it names. [param destination] is the map loaded, [param leaving] the
## map left, and [param facing] the player's on the warp cell.
func on_warp(
	from_outside: bool, to_last_map: bool, destination: int, leaving: int, player_facing: int
) -> void:
	if from_outside:
		spawn_state = _spawn_outside(destination, player_facing)
	elif to_last_map:
		spawn_state = SPAWN_RIGHT if leaving in [ROUTE_22_GATE, ROUTE_2_GATE] \
			and player_facing == FACING_UP else SPAWN_ON_PLAYER_DOWN
	else:
		spawn_state = _spawn_warp_pad(destination, player_facing)


## `SetPikachuSpawnOutside`, run on the way into a building from a town or route.
func _spawn_outside(destination: int, player_facing: int) -> int:
	if destination == OAKS_LAB:
		return SPAWN_LEFT
	if destination == ROUTE_22_GATE:
		return SPAWN_ON_PLAYER_DOWN if player_facing == FACING_DOWN else SPAWN_RIGHT
	if destination in [MT_MOON_B1F, ROCK_TUNNEL_1F]:
		return SPAWN_ON_PLAYER_DOWN
	if destination in OUTSIDE_BELOW_MAPS:
		return SPAWN_BELOW
	if destination in OUTSIDE_FACING_MAPS and player_facing == FACING_DOWN:
		return SPAWN_ON_PLAYER_DOWN
	return SPAWN_RIGHT


## `SetPikachuSpawnWarpPad`, run between two indoor maps.
func _spawn_warp_pad(destination: int, player_facing: int) -> int:
	if destination == VIRIDIAN_FOREST_NORTH_GATE:
		return SPAWN_RIGHT if player_facing == FACING_UP else SPAWN_ON_PLAYER
	if destination == VIRIDIAN_FOREST_SOUTH_GATE:
		return SPAWN_ON_PLAYER if player_facing == FACING_DOWN else SPAWN_RIGHT
	return SPAWN_RIGHT if destination in WARP_PAD_RIGHT_MAPS else SPAWN_ON_PLAYER


## `Func_1510` and `Func_151d`: hidden from the choice of a Fly, a Teleport, a
## rope or a warp pad until the landing animation has ended.
func set_hidden(hidden: bool) -> void:
	if hidden:
		flags |= FLAG_HIDDEN
		image = IMAGE_HIDDEN
	else:
		flags &= ~FLAG_HIDDEN


## `DisablePikachuOverworldSpriteDrawing` and its enable.
func set_drawing(drawing: bool) -> void:
	if drawing:
		flags &= ~FLAG_NO_DRAW
	else:
		flags |= FLAG_NO_DRAW
		image = IMAGE_HIDDEN


## `DisablePikachuFollowingPlayer` and `EnablePikachuFollowingPlayer`.
func set_following(value: bool) -> void:
	if value:
		flags &= ~FLAG_NOT_FOLLOWING
	else:
		flags |= FLAG_NOT_FOLLOWING


## `CollisionCheckOnWater.stopSurfing`: on the player's cell once the step onto
## land has ended, and out of sight until then.
func on_surf_ended() -> void:
	spawn_state = SPAWN_ON_PLAYER_DOWN
	flags |= FLAG_STEP_HIDDEN


## `_AdvancePlayerSprite` clears the bit on the pass a step lands.
func on_player_step_landed() -> void:
	flags &= ~FLAG_STEP_HIDDEN


## `StarterPikachuEmotionCommand_turnawayfromplayer`.
func face_away_from(player_facing: int) -> void:
	facing = player_facing ^ 4


## `IsSpriteInFrontOfPlayer`'s exact test on slot fifteen: drawn, and standing
## on the pixel the faced cell owns.
func stands_in_front(player_cell: Vector2i, direction: Vector2i) -> bool:
	return visible() and picture_id != 0 \
		and pixel == (player_cell + direction) * CELL_PIXELS


## `CollisionCheckOnLand`'s Pikachu case: B held walks through, so does a spent
## counter, and the counter is spent one pass a poll.
func blocks_step(b_held: bool) -> bool:
	status |= STATUS_FACE_PLAYER
	if not following() or b_held or collision_counter == 0:
		return false
	collision_counter -= 1
	return collision_counter != 0


## `IsPikachuRightNextToPlayer`: the same cell or an orthogonal neighbour.
func is_next_to(player_cell: Vector2i) -> bool:
	var offset: Vector2i = cell - player_cell
	return absi(offset.x) + absi(offset.y) <= 1


## `GetPikachuFacingDirection`: where the player stands from the follower, or
## `$ff` on the same cell.
func facing_toward_player(player_cell: Vector2i) -> int:
	if cell.y != player_cell.y:
		return FACING_UP if cell.y > player_cell.y else FACING_DOWN
	if cell.x != player_cell.x:
		return FACING_LEFT if cell.x > player_cell.x else FACING_RIGHT
	return 0xFF


## `SpawnPikachu_`, the slot's turn in `_UpdateSprites`. True when anything
## drawn changed.
func advance_pass(view: View, random: RandomNumberGenerator) -> bool:
	var before: Array = [image, pixel, facing, grass_priority]
	flags &= ~FLAG_TRICK
	if _try_spawn(view) and _on_screen(view):
		if (status & STATUS_FACE_PLAYER) != 0:
			_faced(view)
		elif view.font_loaded or not following():
			_stand(view)
		else:
			_run_state(view, random)
	return before != [image, pixel, facing, grass_priority]


## `TrySpawnPikachu`.
func _try_spawn(view: View) -> bool:
	if not _should_spawn(view):
		image = IMAGE_HIDDEN
		status = STATUS_SPAWN
		return false
	if status == STATUS_SPAWN:
		_place(view)
		_calculate_facing(view)
		spawn_state = SPAWN_ON_PLAYER
	return true


## `ShouldPikachuSpawn`.
func _should_spawn(view: View) -> bool:
	return (flags & (FLAG_STEP_HIDDEN | FLAG_HIDDEN)) == 0 and starter_alive() and not view.riding


## `CalculatePikachuPlacementCoords`: a cell beside the player per the spawn
## state, and `$fe` in the movement byte.
func _place(view: View) -> void:
	var offset: Vector2i = Vector2i.ZERO
	match spawn_state:
		SPAWN_RIGHT:
			offset = Vector2i.RIGHT
		SPAWN_BEHIND:
			offset = -_facing_vector(view.facing)
		SPAWN_BELOW:
			offset = Vector2i.DOWN
		SPAWN_ABOVE:
			offset = Vector2i.UP
		SPAWN_LEFT:
			offset = Vector2i.LEFT
		SPAWN_IN_FRONT:
			offset = _facing_vector(view.facing)
		SPAWN_ON_PLAYER, SPAWN_ON_PLAYER_DOWN:
			offset = Vector2i.ZERO
		_:
			offset = Vector2i.RIGHT
	cell = view.cell + offset
	spawn_flags |= SPAWN_FLAG_FOLLOWING


static func _facing_vector(value: int) -> Vector2i:
	match value:
		FACING_UP:
			return Vector2i.UP
		FACING_LEFT:
			return Vector2i.LEFT
		FACING_RIGHT:
			return Vector2i.RIGHT
	return Vector2i.DOWN


## `CalculatePikachuFacingDirection`.
func _calculate_facing(view: View) -> void:
	picture_id = PICTURE_ID
	image = IMAGE_HIDDEN
	match spawn_state:
		SPAWN_ON_PLAYER, SPAWN_RIGHT, SPAWN_BELOW, SPAWN_LEFT:
			facing = view.facing
		SPAWN_ON_PLAYER_DOWN:
			facing = FACING_DOWN
		SPAWN_IN_FRONT:
			facing = view.facing ^ 4
		_:
			_compute_facing(view)


## `ClearPikachuSpriteStateData`.
func _clear_sprite() -> void:
	picture_id = 0
	status = STATUS_SPAWN
	image = 0
	facing = FACING_DOWN
	step = Vector2i.ZERO
	cell = Vector2i(-4, -4)
	pixel = Vector2i.ZERO
	intra_counter = 0
	anim_frame = 0
	walk_counter = 0
	grass_priority = false


## `WillPikachuSpawnOnTheScreen`: `IsObjectMovingOffEdgeOfScreen`'s window
## about the player, and the grass byte off the cell underneath.
func _on_screen(view: View) -> bool:
	var offset: Vector2i = cell - view.cell
	if offset.y < -4 or offset.y > 4 or offset.x < -4 or offset.x > 5:
		image = IMAGE_HIDDEN
		return false
	grass_priority = _grass_under.call(grass_cell()) if _grass_under.is_valid() else false
	return true


var _grass_under: Callable = Callable()


## The tileset's answer to `wGrassTile` under a cell, supplied by the world.
func set_grass_reader(reader: Callable) -> void:
	_grass_under = reader


## `Func_fc745`: `IsSpriteInFrontOfPlayer` set the face-player bit on the slot.
## The counter takes the grass byte `a` still holds.
func _faced(view: View) -> void:
	status &= ~STATUS_FACE_PLAYER
	walk_counter = 0x80 if grass_priority else 0
	if not following():
		facing = view.facing ^ 4
	intra_counter = 0
	anim_frame = 0
	_update_walking_sprite(view)


## `Func_fc76a`: a text box open or the follower asleep.
func _stand(view: View) -> void:
	intra_counter = 0
	anim_frame = 0
	_update_walking_sprite(view)
	if view.walk_counter == 0:
		_init_screen_position(view)
	status = STATUS_DECIDE
	walk_counter = 0
	_refresh_follow(view)


func _run_state(view: View, random: RandomNumberGenerator) -> void:
	var state: int = status & 0x7F
	match state:
		STATUS_SPAWN:
			_spawn(view)
		STATUS_DECIDE:
			_decide(view, random)
		STATUS_IDLE:
			_idle(view, random)
		STATUS_WALK:
			_walk_pass(view, not (view.biking and not view.ledge))
		STATUS_HOP, STATUS_FAST:
			_walk_pass(view, false)
		STATUS_ARC:
			_arc_pass(view)
		STATUS_STEP_IN_PLACE:
			_trick_pass(view, func() -> void: anim_frame = (anim_frame + 1) & 3)
		STATUS_SHUFFLE:
			_trick_pass(view, func() -> void: anim_frame ^= 1)
		STATUS_SPIN:
			_trick_pass(view, func() -> void: facing = int(CLOCKWISE[facing]))
		_:
			_spawn(view)


## `Func_fc793`.
func _spawn(view: View) -> void:
	_refresh_follow(view)
	_init_screen_position(view)
	image = IMAGE_HIDDEN
	status = STATUS_DECIDE


## `Func_fc7aa`: the oldest command, if the buffer holds more than the one it
## keeps.
func _decide(view: View, random: RandomNumberGenerator) -> void:
	var command: int = _pop_oldest()
	if command == 0:
		_idle(view, random)
		return
	var row: Array = COMMAND_ROWS[command - 1]
	facing = int(row[0])
	step = Vector2i(int(row[1]), int(row[2]))
	status = int(row[3])
	if status == STATUS_HOP:
		walk_counter = WALK_PASSES
		cell += step * 2
		_walk_pass(view, false)
		return
	if buffer.size() >= 3:
		walk_counter = FAST_PASSES
		status = STATUS_FAST
		cell += step
		_walk_pass(view, false)
		return
	walk_counter = WALK_PASSES
	cell += step
	_walk_pass(view, not (view.biking and not view.ledge))


## `Func_fc803`.
func _idle(view: View, random: RandomNumberGenerator) -> void:
	if _on_player_cell(view):
		return
	walk_counter = (walk_counter - 1) & 0xFF
	if walk_counter == 0:
		var newest: int = buffer[-1] if not buffer.is_empty() else 0
		if newest >= CMD_HOP:
			_start_trick(view, newest, random)
			return
		walk_counter = IDLE_PASSES
		facing = _roll(random) & 0x0C
	intra_counter = 0
	anim_frame = 0
	_update_walking_sprite(view)


## `hRandomAdd` after `call Random`, or a scripted byte when a trace has taken
## the cartridge's own `Random` over the same way.
var roll_source: Callable = Callable()


func _roll(random: RandomNumberGenerator) -> int:
	if roll_source.is_valid():
		return int(roll_source.call()) & 0xFF
	return random.randi() & 0xFF


## `Func_fc842`: one of four tricks behind a hop, and its first pass at once.
func _start_trick(view: View, command: int, random: RandomNumberGenerator) -> void:
	match _roll(random) & 3:
		0:
			facing = ((command - 1) * 4) & 0x0C
			status = STATUS_ARC
			arc_offset = Vector2i.ZERO
			walk_counter = ARC_PASSES
			_arc_pass(view)
		1:
			status = STATUS_STEP_IN_PLACE
			walk_counter = STEP_IN_PLACE_PASSES
			_trick_pass(view, func() -> void: anim_frame = (anim_frame + 1) & 3)
		2:
			status = STATUS_SHUFFLE
			walk_counter = SHUFFLE_PASSES
			_trick_pass(view, func() -> void: anim_frame ^= 1)
		_:
			status = STATUS_SPIN
			walk_counter = SHUFFLE_PASSES
			_trick_pass(view, func() -> void: facing = int(CLOCKWISE[facing]))


## `asm_fc9c3`, `asm_fc9ee` and `asm_fca1c`: two pixels a pass, or four.
func _walk_pass(view: View, single: bool) -> void:
	pixel += step * (2 if single else 4)
	_advance_walk_frame()
	_update_walking_sprite(view)
	walk_counter -= 1
	if walk_counter != 0:
		return
	step = Vector2i.ZERO
	_compute_facing(view)
	status = STATUS_DECIDE


## `GetPikachuWalkingAnimationSpeed`: a frame every two passes, or every five
## below eighty happiness.
func _advance_walk_frame() -> void:
	var limit: int = 5 if happiness < HAPPY_WALK_THRESHOLD else 2
	intra_counter += 1
	if intra_counter != limit:
		return
	intra_counter = 0
	anim_frame = (anim_frame + 1) & 3


## `asm_fc87f`: the arc rows over the standing pixels, given up the pass the
## player moves.
func _arc_pass(view: View) -> void:
	if view.walk_counter != 0:
		pixel -= arc_offset
		arc_offset = Vector2i.ZERO
		_trick_rest()
		return
	flags |= FLAG_TRICK
	var row: Array = ARC_ROWS[walk_counter - 1]
	var wanted := Vector2i(int(row[1]), int(row[0]))
	pixel += wanted - arc_offset
	arc_offset = wanted
	walk_counter -= 1
	if walk_counter == 0:
		_trick_rest()


## `asm_fc904`, `asm_fc937` and `asm_fc969`: [param advance] every eighth pass.
func _trick_pass(view: View, advance: Callable) -> void:
	if view.walk_counter != 0:
		_trick_rest()
		return
	flags |= FLAG_TRICK
	intra_counter += 1
	if intra_counter == TRICK_FRAME_PASSES:
		intra_counter = 0
		advance.call()
	_update_walking_sprite(view)
	walk_counter -= 1
	if walk_counter == 0:
		_trick_rest()


## `Func_fc835`.
func _trick_rest() -> void:
	walk_counter = TRICK_REST_PASSES
	status = STATUS_DECIDE


## `UpdatePikachuWalkingSprite`.
func _update_walking_sprite(view: View) -> void:
	if (flags & FLAG_NO_DRAW) != 0:
		image = IMAGE_HIDDEN
		return
	if view.spinning:
		image = view.player_image & 0x0F
		return
	if view.font_loaded:
		if _on_player_cell(view):
			return
		image = facing
		return
	image = facing | anim_frame


## `Func_fcae2`: out of sight on the player's own cell.
func _on_player_cell(view: View) -> bool:
	if cell != view.cell:
		return false
	image = IMAGE_HIDDEN
	return true


## `InitializeSpriteScreenPosition`, put back into map pixels: the screen it
## measures from has scrolled by whatever the player's step has spent.
func _init_screen_position(view: View) -> void:
	pixel = cell * CELL_PIXELS + view.step_pixels


## `RefreshPikachuFollow`.
func _refresh_follow(view: View) -> void:
	buffer.clear()
	var command: int = _compute_follow_command(view)
	if command > 0:
		_append(command)


## `ComputePikachuFollowCommand`: the step or hop that reaches the player, or
## zero on the player's cell.
func _compute_follow_command(view: View) -> int:
	var dy: int = view.cell.y - cell.y
	if dy != 0:
		if dy > 0:
			return CMD_DOWN if dy < 2 else CMD_HOP
		return CMD_UP if -dy < 2 else CMD_HOP + 1
	var dx: int = view.cell.x - cell.x
	if dx == 0:
		return 0
	if dx > 0:
		return CMD_RIGHT if dx < 2 else CMD_HOP + 3
	return CMD_LEFT if -dx < 2 else CMD_HOP + 2


## `Func_fcc92`: the oldest command, when two or more stand in the buffer.
func _pop_oldest() -> int:
	if buffer.size() < 2:
		return 0
	return buffer.pop_front()


## `ComputePikachuFacingDirection`: the newest command's direction when the
## buffer holds more than one, the way to the player otherwise.
func _compute_facing(view: View) -> void:
	if buffer.size() >= 2:
		facing = ((buffer[-1] - 1) & 3) * 4
		return
	if cell.y != view.cell.y:
		facing = FACING_DOWN if cell.y < view.cell.y else FACING_UP
	elif cell.x != view.cell.x:
		facing = FACING_RIGHT if cell.x < view.cell.x else FACING_LEFT
	else:
		facing = view.facing


## `ApplyPikachuMovementData_`: a map script's own choreography, run on the slot
## in place of the state machine, one `ExecutePikachuMovementCommand` loop per
## pass. The state it keeps between commands is WRAM the cartridge never clears.
class Movement:
	var bytes: PackedByteArray
	var at: int = 0
	## `TryApplyPikachuMovementData` refreshes the follow behind the script.
	var refresh: bool = false
	var row: Array = []
	var ended: bool = true
	var shadow: bool = false
	var timer: int = 0
	var subtimer: int = 0
	var grass_saved: bool = false


## `PikachuMovementDatabase` as runs: first code, last code, `func1` at the
## first code, `param1`, `func2`, `param2`. $80 is a byte read off the script.
const MOVEMENT_RUNS: Array = [
	[0x00, 0x00, 0x01, 0x00, 0x00, 0x00], [0x01, 0x08, 0x03, 0x80, 0x01, 0x00],
	[0x09, 0x10, 0x03, 0x80, 0x06, 0x00], [0x11, 0x18, 0x03, 0x80, 0x03, 0x80],
	[0x19, 0x1C, 0x03, 0x80, 0x07, 0x80], [0x1D, 0x24, 0x0B, 0x27, 0x02, 0x00],
	[0x25, 0x2C, 0x0B, 0x0F, 0x02, 0x00], [0x2D, 0x34, 0x0B, 0x0F, 0x08, 0x17],
	[0x35, 0x38, 0x13, 0x0F, 0x06, 0x00], [0x39, 0x39, 0x02, 0x80, 0x04, 0x00],
	[0x3A, 0x3A, 0x02, 0x80, 0x05, 0x00], [0x3B, 0x3B, 0x02, 0x80, 0x03, 0x80],
	[0x3C, 0x3C, 0x02, 0x80, 0x07, 0x80], [0x3D, 0x3D, 0x02, 0x80, 0x09, 0x80],
	[0x3E, 0x3E, 0x02, 0x80, 0x06, 0x00],
]
const MOVEMENT_END: int = 0x3F
const MOVEMENT_PARAM_FROM_SCRIPT: int = 0x80
## `PIKASTEPDIR_*` and `UpdatePikachuPosition`'s vectors in that order.
const STEP_VECTORS: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1),
]
## `PikaMovementFunc1_Step*`'s six `.Data` tables, by facing, for funcs 5 to 10.
const STEP_TURNS: Array = [
	{FACING_DOWN: 3, FACING_UP: 2, FACING_LEFT: 0, FACING_RIGHT: 1},
	{FACING_DOWN: 2, FACING_UP: 3, FACING_LEFT: 1, FACING_RIGHT: 0},
	{FACING_DOWN: 5, FACING_UP: 6, FACING_LEFT: 4, FACING_RIGHT: 7},
	{FACING_DOWN: 4, FACING_UP: 7, FACING_LEFT: 6, FACING_RIGHT: 5},
	{FACING_DOWN: 7, FACING_UP: 4, FACING_LEFT: 5, FACING_RIGHT: 6},
	{FACING_DOWN: 6, FACING_UP: 5, FACING_LEFT: 7, FACING_RIGHT: 4},
]
## `Data_fd731`, the turn ring `PikaMovementFunc2_TurnClockwise` walks.
const TURN_RING: Array[int] = [FACING_DOWN, FACING_LEFT, FACING_UP, FACING_RIGHT]
const MOVEMENT_FUNC1_END: int = 0x17

var movement: Movement = null
## `wPikaSpriteY`/`X`, `wPikachuMovementYOffset`/`X` and `wCurPikaMovementSpriteImageIdx`.
var movement_base: Vector2i = Vector2i.ZERO
var movement_offset: Vector2i = Vector2i.ZERO
var movement_image: int = 0
## The one `DelayFrame` the script spends after its last command.
var movement_overrun: int = 0


func movement_running() -> bool:
	return movement != null


func start_movement(bytes: PackedByteArray, refresh: bool = false) -> void:
	movement = Movement.new()
	movement.bytes = bytes
	movement.refresh = refresh


## `RefreshPikachuFollow` from outside the state machine.
func refresh_follow(view: View) -> void:
	_refresh_follow(view)


## The script's own pixels: the base and the sideways offset are the ground, the
## upward offset the height, and the shadow is drawn while the height stands.
func movement_height() -> int:
	return -movement_offset.y if movement != null else 0


func movement_shadow() -> bool:
	return movement != null and movement.shadow


static func movement_row(code: int) -> Array:
	for run: Array in MOVEMENT_RUNS:
		if code >= int(run[0]) and code <= int(run[1]):
			return [int(run[2]) + code - int(run[0]), int(run[3]), int(run[4]), int(run[5])]
	return []


func _movement_byte() -> int:
	var m: Movement = movement
	if m.at >= m.bytes.size():
		return MOVEMENT_END
	m.at += 1
	return m.bytes[m.at - 1]


## `LoadPikachuMovementCommandData` and the head of `ExecutePikachuMovementCommand`.
func _load_movement_command() -> bool:
	var m: Movement = movement
	var row: Array = movement_row(_movement_byte())
	if row.is_empty():
		return false
	for slot: int in [1, 3]:
		if int(row[slot]) == MOVEMENT_PARAM_FROM_SCRIPT:
			row[slot] = _movement_byte()
	m.row = row
	m.ended = false
	m.timer = 0
	m.subtimer = 0
	m.grass_saved = grass_priority
	return true


## One loop of `ExecutePikachuMovementCommand`, two frames on the cartridge.
## True while the script still runs.
func advance_movement_pass(view: View) -> bool:
	var m: Movement = movement
	if m == null:
		return false
	if m.ended and not _load_movement_command():
		movement = null
		movement_overrun = 1
		if m.refresh:
			_refresh_follow(view)
		return false
	m.shadow = false
	_movement_func1(int(m.row[0]), int(m.row[1]))
	_movement_func2(int(m.row[2]), int(m.row[3]))
	image = movement_image & 0x0F
	pixel = movement_base + movement_offset
	if m.shadow:
		grass_priority = false
	if m.ended:
		grass_priority = m.grass_saved
	return true


## `CheckPikachuStepTimer1` and `2`: true on the pass the count runs out.
func _movement_timer(param: int, mask: int, second: bool) -> bool:
	var m: Movement = movement
	var count: int = (param & mask) + 1
	if second:
		m.subtimer += 1
		if m.subtimer != count:
			return false
		m.subtimer = 0
		return true
	m.timer += 1
	if m.timer != count:
		return false
	m.timer = 0
	return true


## `GetPikachuStepVectorMagnitude`: bits 5 and 6 of the parameter, plus one.
static func _movement_magnitude(param: int) -> int:
	return ((param >> 5) & 3) + 1


func _movement_func1(code: int, param: int) -> void:
	var m: Movement = movement
	match code:
		0x00, MOVEMENT_FUNC1_END:
			m.ended = true
		0x01:
			movement_base = pixel
			movement_offset = Vector2i.ZERO
			m.ended = true
		0x02:
			m.ended = _movement_timer(param, 0x1F, false)
		0x03:
			_movement_step_vector(facing >> 2, param)
		0x04:
			_movement_step_vector((facing ^ 4) >> 2, param)
		0x05, 0x06, 0x07, 0x08, 0x09, 0x0A:
			_movement_step_vector(int((STEP_TURNS[code - 0x05] as Dictionary)[facing]), param)
		0x0B, 0x0C, 0x0D, 0x0E:
			facing = (code - 0x0B) << 2
			_movement_move(code - 0x0B, param)
		0x0F, 0x10, 0x11, 0x12:
			_movement_move(code - 0x0B, param)
		0x13, 0x14, 0x15, 0x16:
			facing = (code - 0x13) << 2
			m.ended = true


## `PikaMovementFunc1_ApplyStepVector`: pixels alone, the cell never moves.
func _movement_step_vector(direction: int, param: int) -> void:
	movement_base += STEP_VECTORS[direction] * _movement_magnitude(param)
	movement.ended = _movement_timer(param, 0x1F, false)


## `PikaMovementFunc1_MoveDiagonally`: the cell follows on the last pass.
func _movement_move(direction: int, param: int) -> void:
	movement_base += STEP_VECTORS[direction] * _movement_magnitude(param)
	if not _movement_timer(param, 0x1F, false):
		return
	cell += STEP_VECTORS[direction]
	movement.ended = true


func _movement_func2(code: int, param: int) -> void:
	match code:
		0x00:
			intra_counter = 0
			anim_frame = 0
			movement_image = IMAGE_BASE | facing
		0x01:
			_movement_walk_image(movement_image & 0x0C, param)
		0x02:
			_movement_walk_image(facing, param)
		0x03:
			_movement_turn_image((param & 0x40) != 0, param)
		0x04:
			_movement_turn_image(true, param)
		0x05:
			_movement_turn_image(false, param)
		0x06:
			movement_image = IMAGE_BASE | (movement_image & 0x0C)
		0x07:
			_movement_jump_image(movement_image & 0x0C, param)
		0x08:
			_movement_jump_image(facing, param)
		0x09:
			movement_image = IMAGE_BASE | facing
			movement_offset.y = _movement_sine(param)


## `PikaMovementFunc2_UpdateSpriteImageIdx`: the frame counter steps when the
## second timer runs out, and bits 2 and 3 of it pick the walking frame.
func _movement_walk_image(direction: int, param: int) -> void:
	if _movement_timer(param, 0x0F, true):
		anim_frame = (anim_frame + 1) & 0xFF
	movement_image = IMAGE_BASE | direction | ((anim_frame >> 2) & 3)


func _movement_turn_image(clockwise: bool, param: int) -> void:
	var direction: int = movement_image & 0x0C
	if _movement_timer(param, 0x0F, true):
		var index: int = TURN_RING.find(direction)
		direction = TURN_RING[(index + (1 if clockwise else -1) + 4) % 4]
	movement_image = IMAGE_BASE | direction


## `PikaMovementFunc2_UpdateJump`: `PikaMovementFunc2_Timer` runs the frame off
## the intra counter, and the sine lifts the sprite and puts a shadow under it.
func _movement_jump_image(direction: int, param: int) -> void:
	intra_counter = (intra_counter + 1) & 3
	if intra_counter == 0:
		anim_frame = (anim_frame + 1) & 3
	movement_image = IMAGE_BASE | direction | anim_frame
	movement_offset.y = _movement_sine(param)
	movement.shadow = movement_offset.y != 0


## `PikaMovementFunc_Sine`: the low nibble is the height, the next three bits
## how fast the subtimer runs around `SineWave_3f`'s half turn, entered a
## quarter turn in so the arc goes up.
func _movement_sine(param: int) -> int:
	var m: Movement = movement
	var height: int = (param & 0x0F) + 1
	m.subtimer = (m.subtimer + (1 << ((param >> 4) & 7))) & 0xFF
	var angle: int = (m.subtimer + 0x20) & 0x3F
	var sine: int = (roundi(sin(float(angle & 0x1F) * PI / 32.0) * 256.0) * height) >> 8
	return sine if angle < 0x20 else -sine
