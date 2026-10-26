class_name Gen3Fly
extends RefCounted

## field_effect.c's Fly: `Task_FlyOut` (FRLG's `FLDEFF_FLY_OUT`), `Task_FlyIn` and their bird sprite.

enum Step { NONE, OUT_POSE, OUT_SHOW_MON, OUT_LEAVE_BALL, OUT_WAIT_LEAVE, OUT_SWOOP, OUT_JUMP_ON, OUT_FLY_OFF,
	OUT_WAIT_FLY_OFF, OUT_END, IN_SWOOP, IN_WITH_BIRD, IN_JUMP_OFF, IN_POSE, IN_RETURN, IN_WAIT_RETURN, IN_END }
enum Callback { LEAVE_BALL, SWOOP, RETURN_TO_BALL, WITH_PLAYER }

const FLDEFF_USE_FLY: int = 31
const FLDEFF_FLY_IN: int = 32
const FLDEFFOBJ_BIRD: int = 26
const ANIM_GET_ON_OFF_POKEMON_WEST: int = 22
const JUMP_OFF: Array[int] = [-2, -4, -5, -6, -7, -8, -8, -8, -7, -7, -6, -5, -3, -2, 0, 2, 4, 8]
const BALL_AFFINE: Array = [[[8, 8, -30, 0], [28, 28, 0, 30], [Gen3AffineAnim.END, 0]],
	[[256, 256, 64, 0], [-10, -10, 0, 22], [Gen3AffineAnim.END, 0]]]
const WITH_PLAYER_AFFINE: Array = [[[24, 24, 0, 1], [Gen3AffineAnim.JUMP, 0]],
	[[512, 512, 0, 1], [-16, -16, 0, 1], [Gen3AffineAnim.JUMP, 1]]]

var step: int = Step.NONE
var bird: Dictionary = {}

var _objects: Gen3ObjectEvents
var _avatar: Gen3PlayerAvatar
var _flags: int = 0
var _timer: int = 0
var _mon: Array = []
var _fade: int = 0


func _init(objects: Gen3ObjectEvents) -> void:
	_objects = objects


func _frlg() -> bool:
	return _objects.camera.data.id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN]


## `FldEff_UseFly` after `Task_UseFly`'s fade-in; [param fade] is `WarpFadeOutScreen`'s fade for the destination.
func fly_out(avatar: Gen3PlayerAvatar, species: int, personality: int, ot_id: int, fade: int) -> void:
	_avatar = avatar
	_mon = [species, personality, ot_id]
	_fade = fade
	step = Step.OUT_POSE
	_objects.task_effects.append(FLDEFF_USE_FLY)


func fly_in(avatar: Gen3PlayerAvatar) -> void:
	_avatar = avatar
	step = Step.IN_SWOOP
	_objects.task_effects.append(FLDEFF_FLY_IN)


func run_task(requests: Array) -> void:
	if step == Step.NONE:
		return
	var player: Gen3ObjectEvents.ObjectEvent = _avatar.object()
	if step < Step.IN_SWOOP:
		_run_out(player, requests)
	else:
		_run_in(player)


func _run_out(player: Gen3ObjectEvents.ObjectEvent, requests: Array) -> void:
	match step:
		Step.OUT_POSE:
			if Gen3ObjectEvents.movement_overridden(player) \
					and Gen3ObjectEvents.clear_held_movement_if_finished(player) == 0:
				return
			_flags = _avatar.flags
			_avatar.prevent_step = true
			_avatar.set_state_mask(Gen3PlayerAvatar.Flag.ON_FOOT)
			_avatar.start_pose()
			step = Step.OUT_SHOW_MON
		Step.OUT_SHOW_MON:
			if Gen3ObjectEvents.clear_held_movement_if_finished(player) == 0:
				return
			_objects.field_move_mon.start(int(_mon[0]), int(_mon[1]), int(_mon[2]),
				int(_objects.camera.header["map_type"]) in Gen3ObjectEvents.OUTDOOR_MAP_TYPES, false)
			step = Step.OUT_LEAVE_BALL
		Step.OUT_LEAVE_BALL:
			if _objects.field_effect_active(Gen3ObjectEvents.FLDEFF_FIELD_MOVE_SHOW_MON):
				return
			if _flags & Gen3PlayerAvatar.Flag.SURFING:
				_avatar.set_surf_bob(Gen3ObjectEvents.Bob.JUST_MON)
			_create_bird()
			step = Step.OUT_WAIT_LEAVE
		Step.OUT_WAIT_LEAVE:
			if not bird["completed"]:
				return
			_timer = 16
			_avatar.transition(Gen3PlayerAvatar.Flag.ON_FOOT)
			_objects.set_held_movement(player, 0x02)
			step = Step.OUT_SWOOP
		Step.OUT_SWOOP:
			if _timer != 0:
				_timer -= 1
				if _timer != 0:
					return
			if Gen3ObjectEvents.clear_held_movement_if_finished(player) == 0:
				return
			requests.append({"kind": "sound", "name": "m_fly"})
			_start_swoop()
			step = Step.OUT_JUMP_ON
		_:
			_run_out_tail(player)


func _run_out_tail(player: Gen3ObjectEvents.ObjectEvent) -> void:
	match step:
		Step.OUT_JUMP_ON:
			_timer += 1
			if _timer < 8:
				return
			_objects.set_graphics_id(player, _avatar.graphics_for(Gen3PlayerAvatar.State.SURFING))
			player.anim.start(ANIM_GET_ON_OFF_POKEMON_WEST)
			player.inanimate = true
			_objects.set_held_movement(player, 0x54 if _frlg() else 0x48)
			if _flags & Gen3PlayerAvatar.Flag.SURFING and not _frlg():
				_objects.destroy_effect_sprite(player.field_effect_sprite)
			step = Step.OUT_FLY_OFF
			_timer = 0
		Step.OUT_FLY_OFF:
			_timer += 1
			if _timer < 10:
				return
			if player.held_movement_active:
				Gen3ObjectEvents.clear_held_movement(player)
			player.inanimate = false
			player.has_shadow = false
			bird["player"] = true
			if _frlg():
				bird["anim"].start(_avatar.gender * 2 + 1)
				_start_with_player_affine(0)
			step = Step.OUT_WAIT_FLY_OFF
		Step.OUT_WAIT_FLY_OFF:
			if bird["completed"]:
				_objects.sprites.weather.fade_screen(_fade, 0)
				step = Step.OUT_END
		Step.OUT_END:
			if not _objects.sprites.palette.fade_active:
				_objects.task_effects.erase(FLDEFF_USE_FLY)
				step = Step.NONE


func _run_in(player: Gen3ObjectEvents.ObjectEvent) -> void:
	match step:
		Step.IN_SWOOP:
			if Gen3ObjectEvents.movement_overridden(player) \
					and Gen3ObjectEvents.clear_held_movement_if_finished(player) == 0:
				return
			_timer = 33 if _frlg() else 17
			_flags = _avatar.flags
			_avatar.prevent_step = true
			_avatar.set_state_mask(Gen3PlayerAvatar.Flag.ON_FOOT)
			if _flags & Gen3PlayerAvatar.Flag.SURFING:
				_avatar.set_surf_bob(Gen3ObjectEvents.Bob.NONE)
			_objects.set_graphics_id(player, _avatar.graphics_for(Gen3PlayerAvatar.State.SURFING))
			Gen3ObjectEvents.turn(player, Gen3ObjectEvents.Direction.WEST)
			player.anim.start(ANIM_GET_ON_OFF_POKEMON_WEST)
			player.invisible = false
			_create_bird()
			_start_swoop()
			bird["player"] = true
			if _frlg():
				bird["anim"].start(_avatar.gender * 2 + 2)
				_start_with_player_affine(1)
			step = Step.IN_WITH_BIRD
		Step.IN_WITH_BIRD:
			if _frlg():
				_try_change_bird()
			if _timer != 0:
				_timer -= 1
				if _timer != 0:
					return
			bird["player"] = false
			player.screen_position += Vector2i(player.x2, player.jump_y)
			player.x2 = 0
			player.jump_y = 0
			step = Step.IN_JUMP_OFF
			_timer = 0
		Step.IN_JUMP_OFF:
			player.jump_y = JUMP_OFF[_timer]
			_timer += 1
			if _timer >= JUMP_OFF.size():
				step = Step.IN_POSE
		_:
			_run_in_tail(player)


func _run_in_tail(player: Gen3ObjectEvents.ObjectEvent) -> void:
	match step:
		Step.IN_POSE:
			if not bird["completed"]:
				return
			player.inanimate = false
			Gen3ObjectEvents.move_to_map_coords(player, player.current)
			player.x2 = 0
			player.jump_y = 0
			player.screen_fixed = false
			_avatar.start_pose()
			step = Step.IN_RETURN
		Step.IN_RETURN:
			if Gen3ObjectEvents.clear_held_movement_if_finished(player) != 0:
				_start_swoop()
				bird["callback"] = Callback.RETURN_TO_BALL
				step = Step.IN_WAIT_RETURN
		Step.IN_WAIT_RETURN:
			if bird["completed"]:
				_objects.sprites.pics.erase(bird)
				bird = {}
				_timer = 16
				step = Step.IN_END
		Step.IN_END:
			_timer -= 1
			if _timer != 0:
				return
			var state: int = Gen3PlayerAvatar.State.NORMAL
			if _flags & Gen3PlayerAvatar.Flag.SURFING:
				state = Gen3PlayerAvatar.State.SURFING
				_avatar.set_surf_bob(Gen3ObjectEvents.Bob.PLAYER_AND_MON)
			_objects.set_graphics_id(player, _avatar.graphics_for(state))
			Gen3ObjectEvents.turn(player, Gen3ObjectEvents.Direction.SOUTH)
			_avatar.flags = _flags
			_avatar.prevent_step = false
			_objects.task_effects.erase(FLDEFF_FLY_IN)
			step = Step.NONE


func _create_bird() -> void:
	var info: Dictionary = _objects.camera.data.world_fly_bird_graphics()
	var anim := Gen3SpriteAnim.new()
	anim.anims = info.get("anims", [])
	anim.images = info.get("images", [])
	var affine := Gen3AffineAnim.new()
	affine.enabled = false
	bird = {"sprite_slot": _objects.sprites.effect_slot(false), "anim": anim, "affine": affine,
		"size": Vector2i(int(info.get("width", 32)), int(info.get("height", 32))), "priority": 1, "subpriority": 1,
		"palette": 0, "tiles": PackedByteArray(), "x": 255, "y": 180, "x2": 0, "y2": 0,
		"position": Vector2i(255, 180), "data": PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0]), "completed": false,
		"player": false, "callback": Callback.LEAVE_BALL}
	_objects.sprites.pics.append(bird)


func _start_swoop() -> void:
	bird.merge({"callback": Callback.SWOOP, "x": 120, "y": 0, "x2": 0, "y2": 0, "completed": false,
		"player": false, "data": PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0])}, true)


func _start_with_player_affine(number: int) -> void:
	var affine: Gen3AffineAnim = bird["affine"]
	affine.anims = WITH_PLAYER_AFFINE
	affine.enabled = true
	affine.start(number)
	bird["callback"] = Callback.WITH_PLAYER


## FRLG's `TryChangeBirdSprite`: the bird back to full size drops its rider's frame and swoops on.
func _try_change_bird() -> void:
	var affine: Gen3AffineAnim = bird["affine"]
	if not affine.enabled:
		return
	var matrix: Vector4i = affine.matrix()
	if matrix.x == 0x100 or matrix.w == 0x100:
		affine.enabled = false
		(bird["anim"] as Gen3SpriteAnim).start(0)
		bird["callback"] = Callback.SWOOP


func animate() -> void:
	if bird.is_empty():
		return
	var data: PackedInt32Array = bird["data"]
	match int(bird["callback"]):
		Callback.LEAVE_BALL:
			_leave_ball(data)
		Callback.SWOOP:
			_circle(data, 140, 4)
		Callback.WITH_PLAYER:
			_circle(data, 180, 2)
		Callback.RETURN_TO_BALL:
			_return_to_ball(data)
	bird["data"] = data
	var anim: Gen3SpriteAnim = bird["anim"]
	anim.animate()
	var affine: Gen3AffineAnim = bird["affine"]
	affine.animate()
	bird["tiles"] = PackedByteArray() if anim.tiles.is_empty() \
		else _objects.camera.data.world_sprite_image(int(anim.tiles[0]), int(anim.tiles[1]))
	bird["position"] = Vector2i(_s16(int(bird["x"]) + int(bird["x2"])), _s16(int(bird["y"]) + int(bird["y2"])))
	bird["double_size"] = affine.enabled
	if affine.enabled:
		bird["matrix"] = affine.matrix()
	else:
		bird.erase("matrix")


func _leave_ball(data: PackedInt32Array) -> void:
	if bird["completed"]:
		return
	if data[0] == 0:
		var affine: Gen3AffineAnim = bird["affine"]
		affine.anims = BALL_AFFINE
		affine.enabled = true
		affine.start(0)
		bird["x"] = (128 if _avatar.gender == 0 else 118) if _frlg() else 118
		bird["y"] = -48
		data[0] = 1
		data[1] = 64
		data[2] = 256
	data[1] += data[2] >> 8
	bird["x2"] = _cos(data[1], 120)
	bird["y2"] = _sin(data[1], 120)
	if data[2] < 2048:
		data[2] += 96
	if data[1] > 129:
		bird["completed"] = true
		(bird["affine"] as Gen3AffineAnim).enabled = false


func _circle(data: PackedInt32Array, radius: int, speed: int) -> void:
	bird["x2"] = _cos(data[2], radius)
	bird["y2"] = _sin(data[2], 72)
	data[2] = (data[2] + speed) & 0xFF
	if bird["player"]:
		var player: Gen3ObjectEvents.ObjectEvent = _avatar.object()
		player.screen_fixed = true
		player.screen_position = Vector2i(_s16(int(bird["x"]) + int(bird["x2"])),
			_s16(int(bird["y"]) + int(bird["y2"]) - 8))
		player.x2 = 0
		player.jump_y = 0
	if data[2] >= 128:
		bird["completed"] = true
		if int(bird["callback"]) == Callback.WITH_PLAYER:
			(bird["affine"] as Gen3AffineAnim).enabled = false


func _return_to_ball(data: PackedInt32Array) -> void:
	if bird["completed"]:
		return
	if data[0] == 0:
		var affine: Gen3AffineAnim = bird["affine"]
		affine.anims = BALL_AFFINE
		affine.enabled = true
		affine.start(1)
		bird["x"] = (112 if _avatar.gender == 0 else 100) if _frlg() else 94
		bird["y"] = -32
		data[0] = 1
		data[1] = 240
		data[2] = 2048
		data[4] = 128
	data[1] = (data[1] + (data[2] >> 8)) & 0xFF
	data[3] += data[2] >> 8
	bird["x2"] = _cos(data[1], 32)
	bird["y2"] = _sin(data[1], 120)
	if data[2] > 256:
		data[2] -= data[4]
	if data[4] < 256:
		data[4] += 24
	if data[2] < 256:
		data[2] = 256
	if data[3] >= 60:
		bird["completed"] = true
		(bird["affine"] as Gen3AffineAnim).enabled = false
		bird["invisible"] = true


## trig.c's `Sin` and `Cos`: the table is indexed unmasked, the product truncated to s16.
static func _sin(index: int, amplitude: int) -> int:
	return _s16((amplitude * Gen3ObjectEvents.SINE[index]) >> 8)


static func _cos(index: int, amplitude: int) -> int:
	return _s16((amplitude * Gen3ObjectEvents.SINE[index + 64]) >> 8)


static func _s16(value: int) -> int:
	return ((value + 32768) & 0xFFFF) - 32768
