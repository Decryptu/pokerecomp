class_name Gen3Bike
extends RefCounted

## `bike.c`: Hoenn's Mach and Acro Bikes, the Acro Bike's input history, and FRLG's one bike, which Cycling Road
## pulls downhill. [Gen3PlayerAvatar] owns it as `gPlayerAvatar`'s bike fields.

enum Speed { STANDING, NORMAL, FAST, FASTER, FASTEST }
enum Acro { NORMAL, TURNING, WHEELIE_STANDING, BUNNY_HOP, WHEELIE_MOVING, SIDE_JUMP, TURN_JUMP }
enum AcroTransition { FACE, TURN, MOVING, NORMAL_TO_WHEELIE, WHEELIE_TO_NORMAL, WHEELIE_IDLE, HOP_STANDING,
	HOP_MOVING, SIDE_JUMP, TURN_JUMP, WHEELIE_MOVING, WHEELIE_RISING, WHEELIE_LOWERING }
enum Slope { NORMAL, TURNING, SLOPE }
enum SlopeTransition { FACE, TURN, MOVE, DOWNHILL, UPHILL }
## Hoenn's `MOVEMENT_ACTION_ACRO_*` families in order from the wheelie face; Ruby's sit two below Emerald's.
enum Wheelie { FACE, POP, END_FACE, HOP_FACE, HOP, JUMP, IN_PLACE, POP_MOVE, MOVE, END_MOVE }
const KEY_B: int = 2
const KEY_RIGHT: int = 16
const KEY_LEFT: int = 32
const KEY_UP: int = 64
const KEY_DOWN: int = 128
const MB_BUMPY_SLOPE: int = 0xD1
const VERTICAL_RAILS: Array[int] = [0xD3, 0xD5]
const HORIZONTAL_RAILS: Array[int] = [0xD4, 0xD6]
## FRLG's pull-down cells; `GetBikeCollisionAt` answers its cracked ice with `COLLISION_COUNT`.
const PULL_DOWN: Array[int] = [0xD0, 0xD1]
const MB_CRACKED_ICE: int = 0x27
const COLLISION_COUNT: int = 14
const JUMP_TIMER: int = 4
const TURN_JUMPS: Array[int] = [0x4B, 0x4A, 0x4D, 0x4C]

var avatar: Gen3PlayerAvatar
var state: int = Acro.NORMAL
var new_direction: int = 0
var frame_counter: int = 0
var speed: int = Speed.STANDING
## Nibble histories of the d-pad and of A, B, SELECT and START, newest low, with their frame timers.
var direction_history: int = 0
var button_history: int = 0
var direction_timers := PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0])
var button_timers := PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0])
## `gBikeCyclingChallenge` and `gBikeCollisions`, which the Cycling Road challenge's specials set and read.
var cycling_challenge: bool = false
var cycling_collisions: int = 0
var _direction: int = 0
var _wheelie_base: int = 0x64


func _init(owner: Gen3PlayerAvatar, game: StringName) -> void:
	avatar = owner
	_wheelie_base = 0x62 if game in [RomRegistry.RUBY, RomRegistry.SAPPHIRE] else 0x64


func clear_state() -> void:
	state = Acro.NORMAL
	new_direction = 0
	frame_counter = 0
	speed = Speed.STANDING
	direction_history = 0
	button_history = 0
	direction_timers.fill(0)
	button_timers.fill(0)


func update_counter_speed(counter: int) -> void:
	frame_counter = counter
	speed = counter + (counter >> 1)


func _still() -> void:
	frame_counter = 0
	speed = Speed.STANDING


func player_speed() -> int:
	if avatar.flags & Gen3PlayerAvatar.Flag.MACH_BIKE:
		return [Speed.NORMAL, Speed.FAST, Speed.FASTEST][frame_counter]
	if avatar.flags & Gen3PlayerAvatar.Flag.ACRO_BIKE:
		return Speed.FASTER
	if avatar.flags & (Gen3PlayerAvatar.Flag.SURFING | Gen3PlayerAvatar.Flag.DASH):
		return Speed.FAST
	return Speed.NORMAL


## `GetOnOffBike`: the request is `MUS_CYCLING`, which FRLG may skip for the map's music.
func get_on_off(transition_flags: int) -> Array:
	if avatar.flags & (Gen3PlayerAvatar.Flag.MACH_BIKE | Gen3PlayerAvatar.Flag.ACRO_BIKE):
		avatar.transition(Gen3PlayerAvatar.Flag.ON_FOOT)
		return [{"kind": "special_map_music"}]
	avatar.transition(transition_flags)
	return [{"kind": "cycling_music"}]


## `Bike_HandleBumpySlopeJump`, from the Acro Bike's transition: the wheelie is held from its second frame.
func handle_bumpy_slope_jump() -> void:
	var player: Gen3ObjectEvents.ObjectEvent = avatar.object()
	if not avatar.flags & Gen3PlayerAvatar.Flag.ACRO_BIKE \
			or avatar.objects.camera.grid.behavior_at(player.current.x, player.current.y) & 0xFF != MB_BUMPY_SLOPE:
		return
	state = Acro.WHEELIE_STANDING
	avatar.objects.set_graphics_id(player, avatar.graphics_for(Gen3PlayerAvatar.State.ACRO_BIKE))
	player.anim.start(Gen3ObjectEvents.ANIM_STD_COUNT
		+ Gen3ObjectEvents.DIRECTION_ANIM_OFFSETS[player.movement_direction])
	player.anim.seek(1)


## `Bike_TryAcroBikeHistoryUpdate`; a changed input stops the bike.
func update_history(held_keys: int) -> void:
	if not avatar.flags & Gen3PlayerAvatar.Flag.ACRO_BIKE:
		return
	var direction: int = dpad_direction(held_keys)
	if direction == direction_history & 0xF:
		direction_timers[0] = mini(direction_timers[0] + 1, 0xFF)
	else:
		direction_history = _push(direction_history, direction_timers, direction)
		speed = Speed.STANDING
	var buttons: int = held_keys & 0xF
	if buttons == button_history & 0xF:
		button_timers[0] = mini(button_timers[0] + 1, 0xFF)
	else:
		button_history = _push(button_history, button_timers, buttons)
		speed = Speed.STANDING


static func _push(history: int, timers: PackedByteArray, value: int) -> int:
	for index: int in range(timers.size() - 1, 0, -1):
		timers[index] = timers[index - 1]
	timers[0] = 1
	return ((history << 4) | value) & 0xFFFFFFFF


static func dpad_direction(held_keys: int) -> int:
	for row: Array in [[KEY_UP, 2], [KEY_DOWN, 1], [KEY_LEFT, 3], [KEY_RIGHT, 4]]:
		if held_keys & int(row[0]):
			return int(row[1])
	return 0


## `AcroBike_GetJumpDirection`: the newest d-pad entry and B alone, both pressed within `JUMP_TIMER` frames.
func jump_direction() -> int:
	var direction: int = direction_history & 0xF
	if direction < 1 or direction > 4 or button_history & 0xF != KEY_B \
			or direction_timers[0] > JUMP_TIMER or button_timers[0] > JUMP_TIMER:
		return 0
	return direction


func move(direction: int, new_keys: int, held_keys: int, requests: Array) -> void:
	_direction = direction
	if avatar.frlg:
		_slope_transition(_slope_input(held_keys), requests)
	elif avatar.flags & Gen3PlayerAvatar.Flag.MACH_BIKE:
		_move_mach(requests)
	else:
		_acro_transition(_acro_input(new_keys, held_keys), requests)


## `GetMachBikeTransition`: `MACH_TRANS_KEEP_MOVING` indexes `TrySpeedUp` and `MACH_TRANS_START_MOVING`
## `TrySlowDown`, so letting go or turning while rolling slows down the old way.
func _move_mach(requests: Array) -> void:
	var moving: int = avatar.object().movement_direction
	var rolling: bool = speed != Speed.STANDING
	if _direction == 0 or (_direction != moving and avatar.running_state != Gen3PlayerAvatar.Running.MOVING):
		var turning: bool = _direction != 0 and not rolling
		avatar.running_state = Gen3PlayerAvatar.Running.TURN_DIRECTION if turning \
			else (Gen3PlayerAvatar.Running.MOVING if rolling else Gen3PlayerAvatar.Running.NOT_MOVING)
		if turning:
			_mach_turn(_direction)
		elif rolling:
			_mach_slow_down(moving, requests)
		else:
			_mach_face(moving)
		return
	avatar.running_state = Gen3PlayerAvatar.Running.MOVING
	_mach_speed_up(_direction, requests)


func _mach_face(direction: int) -> void:
	avatar.face(direction)
	_still()


func _mach_turn(direction: int) -> void:
	if not _can_face(direction):
		_mach_face(avatar.object().facing)
		return
	avatar.set_anim(avatar.action(&"in_place_fast", direction), Gen3PlayerAvatar.Copy.FACE)
	_still()


func _mach_speed_up(direction: int, requests: Array) -> void:
	var moving: int = avatar.object().movement_direction
	if not _can_face(direction):
		if speed != Speed.STANDING:
			_mach_slow_down(moving, requests)
		else:
			_mach_face(moving)
		return
	var collision: int = _collision(direction, requests)
	if collision > 0 and collision < Gen3PlayerAvatar.Collision.VERTICAL_RAIL:
		_mach_collide(collision, direction, requests)
		return
	_mach_ride(direction)
	speed = frame_counter + (frame_counter >> 1)
	frame_counter = mini(frame_counter + 1, 2)


func _mach_slow_down(direction: int, requests: Array) -> void:
	if speed != Speed.STANDING:
		speed -= 1
		frame_counter = speed
	var collision: int = _collision(direction, requests)
	if collision > 0 and collision < Gen3PlayerAvatar.Collision.VERTICAL_RAIL:
		_mach_collide(collision, direction, requests)
	else:
		_mach_ride(direction)


func _mach_ride(direction: int) -> void:
	var family: StringName = [&"walk_normal", &"walk_fast", &"walk_faster"][frame_counter]
	avatar.set_anim(avatar.action(family, direction), Gen3PlayerAvatar.Copy.WALK)


func _mach_collide(collision: int, direction: int, requests: Array) -> void:
	if collision == Gen3PlayerAvatar.Collision.LEDGE_JUMP:
		avatar.jump_ledge(direction, requests)
		return
	_still()
	_bump(collision, direction, requests)


## `PlayerOnBikeCollide`, Emerald's Faraway Island Mew without the sound; no bump past a task-starting collision.
func _bump(collision: int, direction: int, requests: Array) -> void:
	var mew: bool = collision == Gen3PlayerAvatar.Collision.OBJECT_EVENT and avatar.colliding_with_mew(direction)
	if mew or collision < Gen3PlayerAvatar.Collision.STOP_SURFING or collision > Gen3PlayerAvatar.Collision.ROTATING_GATE:
		if not mew:
			avatar.collision_sound(direction, requests)
		avatar.set_anim(avatar.action(&"in_place_normal", direction), Gen3PlayerAvatar.Copy.WALK)


## `GetBikeCollision`: a cell [method Gen3PlayerAvatar.running_disallowed_by_behavior] refuses blocks a bike.
func _collision(direction: int, requests: Array) -> int:
	var at: Vector2i = avatar.object().current + Gen3FieldCamera.DIRECTIONS[direction]
	var behavior: int = avatar.objects.camera.grid.behavior_at(at.x, at.y) & 0xFF
	var collision: int = avatar.collide(avatar.collision_at(avatar.object(), at, direction), direction, requests)
	if collision > Gen3PlayerAvatar.Collision.OBJECT_EVENT:
		return collision
	if avatar.frlg and behavior == MB_CRACKED_ICE:
		return COLLISION_COUNT
	if collision == Gen3PlayerAvatar.Collision.NONE and avatar.running_disallowed_by_behavior(behavior):
		collision = Gen3PlayerAvatar.Collision.IMPASSABLE
	if collision != Gen3PlayerAvatar.Collision.NONE and not avatar.frlg and cycling_challenge:
		cycling_collisions = mini(cycling_collisions + 1, 100)
	return collision


func _can_face(direction: int) -> bool:
	var behavior: int = avatar.object().current_behavior
	if direction in [Gen3ObjectEvents.Direction.WEST, Gen3ObjectEvents.Direction.EAST]:
		return behavior not in VERTICAL_RAILS
	return behavior not in HORIZONTAL_RAILS


func _bumpy() -> bool:
	return avatar.object().current_behavior == MB_BUMPY_SLOPE


func _set_running(running: int) -> void:
	avatar.running_state = running


func _acro_input(new_keys: int, held_keys: int) -> int:
	match state:
		Acro.NORMAL:
			return _acro_normal(new_keys, held_keys)
		Acro.TURNING:
			return _acro_turning()
		Acro.WHEELIE_STANDING:
			return _acro_wheelie_standing(new_keys, held_keys)
		Acro.BUNNY_HOP:
			return _acro_bunny_hop(new_keys, held_keys)
		Acro.WHEELIE_MOVING:
			return _acro_wheelie_moving(new_keys, held_keys)
		Acro.SIDE_JUMP:
			var player: Gen3ObjectEvents.ObjectEvent = avatar.object()
			player.facing_locked = false
			Gen3ObjectEvents.set_direction(player, player.facing)
	state = Acro.NORMAL
	return _acro_input(new_keys, held_keys)


func _acro_normal(new_keys: int, held_keys: int) -> int:
	var moving: int = avatar.object().movement_direction
	frame_counter = 0
	if _direction == 0:
		_direction = moving
		_set_running(Gen3PlayerAvatar.Running.NOT_MOVING)
		if new_keys & KEY_B:
			state = Acro.WHEELIE_STANDING
			return AcroTransition.NORMAL_TO_WHEELIE
		return AcroTransition.FACE
	if _direction == moving and held_keys & KEY_B and speed == Speed.STANDING:
		speed += 1
		state = Acro.WHEELIE_MOVING
		return AcroTransition.WHEELIE_RISING
	if _direction != moving and avatar.running_state != Gen3PlayerAvatar.Running.MOVING:
		state = Acro.TURNING
		new_direction = _direction
		_set_running(Gen3PlayerAvatar.Running.NOT_MOVING)
		return _acro_input(new_keys, held_keys)
	_set_running(Gen3PlayerAvatar.Running.MOVING)
	return AcroTransition.MOVING


## `AcroBikeHandleInputTurning` waits six frames for the jump input before turning.
func _acro_turning() -> int:
	_direction = new_direction
	frame_counter = (frame_counter + 1) & 0xFF
	if frame_counter > 6:
		_set_running(Gen3PlayerAvatar.Running.TURN_DIRECTION)
		state = Acro.NORMAL
		_still()
		return AcroTransition.TURN
	var moving: int = avatar.object().movement_direction
	if _direction == jump_direction():
		_still()
		speed = Speed.NORMAL
		if _direction == Gen3ObjectEvents.OPPOSITE[moving]:
			state = Acro.TURN_JUMP
			return AcroTransition.TURN_JUMP
		_set_running(Gen3PlayerAvatar.Running.MOVING)
		state = Acro.SIDE_JUMP
		return AcroTransition.SIDE_JUMP
	_direction = moving
	return AcroTransition.FACE


func _acro_wheelie_standing(_new_keys: int, held_keys: int) -> int:
	var moving: int = avatar.object().movement_direction
	_set_running(Gen3PlayerAvatar.Running.NOT_MOVING)
	if held_keys & KEY_B:
		frame_counter = (frame_counter + 1) & 0xFF
	else:
		frame_counter = 0
		if not _bumpy():
			_direction = moving
			state = Acro.NORMAL
			_still()
			return AcroTransition.WHEELIE_TO_NORMAL
	if frame_counter >= 40:
		_direction = moving
		state = Acro.BUNNY_HOP
		_still()
		return AcroTransition.HOP_STANDING
	if _direction == moving:
		_set_running(Gen3PlayerAvatar.Running.MOVING)
		state = Acro.WHEELIE_MOVING
		_still()
		return AcroTransition.WHEELIE_MOVING
	if _direction == 0:
		_direction = moving
	else:
		_set_running(Gen3PlayerAvatar.Running.TURN_DIRECTION)
	return AcroTransition.WHEELIE_IDLE


func _acro_bunny_hop(new_keys: int, held_keys: int) -> int:
	var moving: int = avatar.object().movement_direction
	if not held_keys & KEY_B:
		_still()
		if _bumpy():
			state = Acro.WHEELIE_STANDING
			return _acro_input(new_keys, held_keys)
		_direction = moving
		_set_running(Gen3PlayerAvatar.Running.NOT_MOVING)
		state = Acro.NORMAL
		return AcroTransition.WHEELIE_TO_NORMAL
	if _direction == 0:
		_direction = moving
		_set_running(Gen3PlayerAvatar.Running.NOT_MOVING)
		return AcroTransition.HOP_STANDING
	if _direction != moving and avatar.running_state != Gen3PlayerAvatar.Running.MOVING:
		_set_running(Gen3PlayerAvatar.Running.TURN_DIRECTION)
		return AcroTransition.HOP_STANDING
	_set_running(Gen3PlayerAvatar.Running.MOVING)
	return AcroTransition.HOP_MOVING


## `AcroBikeHandleInputWheelieMoving` compares the facing, not the movement direction.
func _acro_wheelie_moving(new_keys: int, held_keys: int) -> int:
	var facing: int = avatar.object().facing
	if not held_keys & KEY_B:
		_still()
		if _bumpy():
			state = Acro.WHEELIE_STANDING
			return _acro_input(new_keys, held_keys)
		state = Acro.NORMAL
		if _direction == 0:
			_direction = facing
			_set_running(Gen3PlayerAvatar.Running.NOT_MOVING)
			return AcroTransition.WHEELIE_TO_NORMAL
		if _direction != facing and avatar.running_state != Gen3PlayerAvatar.Running.MOVING:
			_set_running(Gen3PlayerAvatar.Running.NOT_MOVING)
			return AcroTransition.WHEELIE_TO_NORMAL
		_set_running(Gen3PlayerAvatar.Running.MOVING)
		return AcroTransition.WHEELIE_LOWERING
	if _direction == 0:
		_direction = facing
		state = Acro.WHEELIE_STANDING
		_set_running(Gen3PlayerAvatar.Running.NOT_MOVING)
		_still()
		return AcroTransition.WHEELIE_IDLE
	if _direction != facing and avatar.running_state != Gen3PlayerAvatar.Running.MOVING:
		_set_running(Gen3PlayerAvatar.Running.NOT_MOVING)
		return AcroTransition.WHEELIE_IDLE
	_set_running(Gen3PlayerAvatar.Running.MOVING)
	return AcroTransition.WHEELIE_MOVING


func _wheelie(family: int, direction: int, copy: int, hop: bool, requests: Array) -> void:
	if hop:
		requests.append({"kind": "sound", "name": "bike_hop"})
	avatar.set_anim(Gen3ObjectEvents.direction_action(_wheelie_base + family * 4, direction), copy)


func _acro_transition(transition: int, requests: Array) -> void:
	var direction: int = _direction
	var moving: int = avatar.object().movement_direction
	var fixed: int = direction if _can_face(direction) else moving
	match transition:
		AcroTransition.FACE:
			avatar.face(direction)
		AcroTransition.TURN:
			avatar.face(fixed)
		AcroTransition.MOVING:
			_acro_moving(direction, requests)
		AcroTransition.NORMAL_TO_WHEELIE:
			_wheelie(Wheelie.POP, fixed, Gen3PlayerAvatar.Copy.FACE, false, requests)
		AcroTransition.WHEELIE_TO_NORMAL:
			_wheelie(Wheelie.END_FACE, fixed, Gen3PlayerAvatar.Copy.FACE, false, requests)
		AcroTransition.WHEELIE_IDLE:
			_wheelie(Wheelie.FACE, fixed, Gen3PlayerAvatar.Copy.FACE, false, requests)
		AcroTransition.HOP_STANDING:
			_wheelie(Wheelie.HOP_FACE, fixed, Gen3PlayerAvatar.Copy.FACE, true, requests)
		AcroTransition.HOP_MOVING:
			_acro_hop_moving(direction, requests)
		AcroTransition.SIDE_JUMP:
			_acro_side_jump(direction, requests)
		AcroTransition.TURN_JUMP:
			requests.append({"kind": "sound", "name": "bike_hop"})
			avatar.set_anim(TURN_JUMPS[maxi(direction, 1) - 1], Gen3PlayerAvatar.Copy.FACE)
		_:
			_acro_wheelie_move(transition, direction, requests)


func _acro_moving(direction: int, requests: Array) -> void:
	if not _can_face(direction):
		avatar.face(avatar.object().movement_direction)
		return
	var collision: int = _collision(direction, requests)
	if collision > 0 and collision < Gen3PlayerAvatar.Collision.VERTICAL_RAIL:
		if collision == Gen3PlayerAvatar.Collision.LEDGE_JUMP:
			avatar.jump_ledge(direction, requests)
		else:
			_bump(collision, direction, requests)
		return
	avatar.set_anim(avatar.action(&"ride_current", direction), Gen3PlayerAvatar.Copy.WALK)


func _acro_hop_moving(direction: int, requests: Array) -> void:
	if not _can_face(direction):
		_wheelie(Wheelie.HOP_FACE, avatar.object().movement_direction, Gen3PlayerAvatar.Copy.FACE, true, requests)
		return
	var collision: int = _collision(direction, requests)
	if collision != Gen3PlayerAvatar.Collision.NONE and collision != Gen3PlayerAvatar.Collision.WHEELIE_HOP:
		if collision == Gen3PlayerAvatar.Collision.LEDGE_JUMP:
			_wheelie(Wheelie.JUMP, direction, Gen3PlayerAvatar.Copy.JUMP_2, true, requests)
			return
		if collision >= Gen3PlayerAvatar.Collision.STOP_SURFING and collision <= Gen3PlayerAvatar.Collision.ROTATING_GATE:
			return
		if collision < Gen3PlayerAvatar.Collision.VERTICAL_RAIL:
			_wheelie(Wheelie.HOP_FACE, direction, Gen3PlayerAvatar.Copy.FACE, true, requests)
			return
	_wheelie(Wheelie.HOP, direction, Gen3PlayerAvatar.Copy.WALK, true, requests)


## `AcroBikeTransition_SideJump`: a rail along the jump lets it through.
func _acro_side_jump(direction: int, requests: Array) -> void:
	var collision: int = _collision(direction, requests)
	if collision == Gen3PlayerAvatar.Collision.PUSHED_BOULDER:
		return
	var vertical: bool = direction in [Gen3ObjectEvents.Direction.NORTH, Gen3ObjectEvents.Direction.SOUTH]
	var along: Array = [Gen3PlayerAvatar.Collision.ISOLATED_VERTICAL_RAIL, Gen3PlayerAvatar.Collision.VERTICAL_RAIL] \
		if vertical else [Gen3PlayerAvatar.Collision.ISOLATED_HORIZONTAL_RAIL, Gen3PlayerAvatar.Collision.HORIZONTAL_RAIL]
	if collision != Gen3PlayerAvatar.Collision.NONE \
			and (collision < Gen3PlayerAvatar.Collision.ISOLATED_VERTICAL_RAIL or collision in along):
		avatar.face(direction if _can_face(direction) else avatar.object().movement_direction)
		return
	requests.append({"kind": "sound", "name": "bike_hop"})
	avatar.object().facing_locked = true
	avatar.set_anim(avatar.action(&"jump", direction), Gen3PlayerAvatar.Copy.WALK)


func _acro_wheelie_move(transition: int, direction: int, requests: Array) -> void:
	var moving: int = avatar.object().movement_direction
	var still: int = {AcroTransition.WHEELIE_MOVING: Wheelie.FACE, AcroTransition.WHEELIE_RISING: Wheelie.POP,
		AcroTransition.WHEELIE_LOWERING: Wheelie.END_FACE}[transition]
	if not _can_face(direction):
		_wheelie(still, moving, Gen3PlayerAvatar.Copy.FACE, false, requests)
		return
	var collision: int = _collision(direction, requests)
	if collision > 0 and collision < Gen3PlayerAvatar.Collision.VERTICAL_RAIL:
		if transition == AcroTransition.WHEELIE_LOWERING:
			if collision == Gen3PlayerAvatar.Collision.LEDGE_JUMP:
				avatar.jump_ledge(direction, requests)
			elif collision < Gen3PlayerAvatar.Collision.STOP_SURFING \
					or collision > Gen3PlayerAvatar.Collision.ROTATING_GATE:
				_wheelie(Wheelie.END_FACE, direction, Gen3PlayerAvatar.Copy.FACE, false, requests)
		elif collision == Gen3PlayerAvatar.Collision.LEDGE_JUMP:
			_wheelie(Wheelie.JUMP, direction, Gen3PlayerAvatar.Copy.JUMP_2, true, requests)
		elif collision == Gen3PlayerAvatar.Collision.WHEELIE_HOP or (collision < Gen3PlayerAvatar.Collision.STOP_SURFING
				and _bumpy()):
			_wheelie(Wheelie.FACE, direction, Gen3PlayerAvatar.Copy.FACE, false, requests)
		elif collision < Gen3PlayerAvatar.Collision.STOP_SURFING:
			requests.append({"kind": "sound", "name": "wall_hit"})
			_wheelie(Wheelie.IN_PLACE, direction, Gen3PlayerAvatar.Copy.WALK, false, requests)
		return
	var family: int = {AcroTransition.WHEELIE_MOVING: Wheelie.MOVE, AcroTransition.WHEELIE_RISING: Wheelie.POP_MOVE,
		AcroTransition.WHEELIE_LOWERING: Wheelie.END_MOVE}[transition]
	_wheelie(family, direction, Gen3PlayerAvatar.Copy.WALK, false, requests)
	if transition != AcroTransition.WHEELIE_LOWERING:
		_set_running(Gen3PlayerAvatar.Running.MOVING)


## FRLG's `sBikeInputHandlers`: off B, a pull-down cell rolls the bike downhill unless the d-pad points up the road.
func _slope_input(held_keys: int) -> int:
	var moving: int = avatar.object().movement_direction
	var pulled: bool = avatar.object().current_behavior in PULL_DOWN
	match state:
		Slope.TURNING:
			_direction = new_direction
			_set_running(Gen3PlayerAvatar.Running.TURN_DIRECTION)
			state = Slope.NORMAL
			_still()
			return SlopeTransition.TURN
		Slope.SLOPE:
			if pulled:
				if _direction != moving:
					return _slope_turn(held_keys)
				_set_running(Gen3PlayerAvatar.Running.MOVING)
				return SlopeTransition.DOWNHILL if _direction < Gen3ObjectEvents.Direction.NORTH else SlopeTransition.UPHILL
			state = Slope.NORMAL
			return _slope_face_or_move(moving, false)
	frame_counter = 0
	if pulled and (not held_keys & KEY_B or _direction != 0):
		state = Slope.SLOPE
		_set_running(Gen3PlayerAvatar.Running.MOVING)
		return SlopeTransition.DOWNHILL if not held_keys & KEY_B and _direction < Gen3ObjectEvents.Direction.NORTH \
			else SlopeTransition.UPHILL
	return _slope_face_or_move(moving, true)


func _slope_turn(held_keys: int) -> int:
	state = Slope.TURNING
	new_direction = _direction
	_set_running(Gen3PlayerAvatar.Running.NOT_MOVING)
	return _slope_input(held_keys)


## A Cycling Road slope's exit cannot turn in place; level ground turns when the bike is not rolling.
func _slope_face_or_move(moving: int, can_turn: bool) -> int:
	if _direction == 0:
		_direction = moving
		_set_running(Gen3PlayerAvatar.Running.NOT_MOVING)
		return SlopeTransition.FACE
	if can_turn and _direction != moving and avatar.running_state != Gen3PlayerAvatar.Running.MOVING:
		return _slope_turn(0)
	_set_running(Gen3PlayerAvatar.Running.MOVING)
	return SlopeTransition.MOVE


## FRLG's `sBikeTransitions`; its rail predicates are stubs, so every direction can be faced.
func _slope_transition(transition: int, requests: Array) -> void:
	var direction: int = _direction
	match transition:
		SlopeTransition.FACE, SlopeTransition.TURN:
			avatar.face(direction)
		SlopeTransition.MOVE:
			var collision: int = _collision(direction, requests)
			if collision > 0 and collision <= Gen3PlayerAvatar.Collision.ISOLATED_HORIZONTAL_RAIL:
				if collision == Gen3PlayerAvatar.Collision.LEDGE_JUMP:
					avatar.jump_ledge(direction, requests)
				elif collision < Gen3PlayerAvatar.Collision.STOP_SURFING \
						or collision > Gen3PlayerAvatar.Collision.DIRECTIONAL_STAIR_WARP:
					avatar.collision_sound(direction, requests)
					avatar.set_anim(avatar.action(&"in_place_normal", direction), Gen3PlayerAvatar.Copy.WALK)
				return
			var fast: bool = collision == COLLISION_COUNT or avatar.on_rock_stairs(direction)
			avatar.set_anim(avatar.action(&"walk_fast" if fast else &"ride_current", direction), Gen3PlayerAvatar.Copy.WALK)
		SlopeTransition.DOWNHILL:
			var collision: int = _collision(Gen3ObjectEvents.Direction.SOUTH, requests)
			if collision == Gen3PlayerAvatar.Collision.NONE:
				avatar.set_anim(avatar.action(&"walk_faster", Gen3ObjectEvents.Direction.SOUTH), Gen3PlayerAvatar.Copy.WALK)
			elif collision == Gen3PlayerAvatar.Collision.LEDGE_JUMP:
				avatar.jump_ledge(Gen3ObjectEvents.Direction.SOUTH, requests)
		SlopeTransition.UPHILL:
			if _collision(direction, requests) == Gen3PlayerAvatar.Collision.NONE:
				avatar.set_anim(avatar.action(&"walk_normal", direction), Gen3PlayerAvatar.Copy.WALK)
