class_name Gen3HealMachine
extends RefCounted # field_effect.c's glowing Poke Balls with the Pokemon Center's or Hall of Fame's monitors; Hoenn's subsprite monitors draw as one picture.

enum Glow { PLACE_BALLS, TRY_FANFARE, FLASH_1, FLASH_2, WAIT_AFTER_FLASH, DUMMY, WAIT_FANFARE, IDLE }
enum Art { GLOW, MONITOR, HOF_BIG, HOF_SMALL }
enum Callback { BALL, MONITOR, HOENN_HOF, FRLG_HOF }

const FLDEFF_POKECENTER_HEAL: int = 25
const FLDEFF_HALL_OF_FAME_RECORD: int = 62
const GLOW_PALETTE_TAG: int = 0x1007
const GENERAL_PALETTE_TAG: int = 0x1004
const HOF_PALETTE_TAG: int = 0x1010
const BALL_OFFSETS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(6, 0), Vector2i(0, 4), Vector2i(6, 4), Vector2i(0, 8),
	Vector2i(6, 8)]
const GLOW_LEVELS: Array[int] = [16, 12, 8, 0] # `sPokeballGlowReds` and `sPokeballGlowGreens`; `sPokeballGlowBlues` is zero.
const FLASH_COLORS: Dictionary = {8: 3, 6: 2, 2: 1, 5: 0, 3: 0} # Palette colours by their phase ahead of `sCounter` in `PokeballGlowEffect_Flash1`.
const HOENN_HOF_SMALL: Array[Vector2i] = [Vector2i(40, 8), Vector2i(72, 8), Vector2i(168, 8), Vector2i(200, 8)]
const HOF_FLIPS: int = 127

var active: bool = false
var glow_state: int = Glow.IDLE

var _objects_ref: WeakRef
var _objects: Gen3ObjectEvents:
	get: return _objects_ref.get_ref()
var _effect: int = 0
var _task_state: int = 0
var _glowing: bool = false
var _left: int = 0
var _timer: int = 0
var _counter: int = 0
var _rounds: int = 0
var _hof_flash: bool = false
var _glow_palette: int = 0
var _sprites: Array[Dictionary] = []


func _init(objects: Gen3ObjectEvents) -> void:
	_objects_ref = weakref(objects)


func _frlg() -> bool:
	return _objects.camera.data.id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN]


func _heals() -> bool:
	return _effect == FLDEFF_POKECENTER_HEAL


func start(effect: int) -> void: # `FldEff_PokecenterHeal` or `FldEff_HallOfFameRecord`; an empty party, which no script reaches, would stay in `PokeballGlowEffect_PlaceBalls`.
	_effect = effect
	_left = clampi(_objects.events.party.size(), 1, BALL_OFFSETS.size())
	_task_state = 0
	_timer = 0
	_counter = 0
	_rounds = 0
	_hof_flash = false
	glow_state = Glow.PLACE_BALLS
	active = true
	_objects.task_effects.append(effect)


func run_task() -> void:
	if not active:
		return
	match _task_state:
		0:
			_glow_palette = _objects.sprites.load_effect_palette(_objects.camera.data.world_heal_graphics(Art.GLOW))
			_glowing = true
			_create_monitors()
			_task_state = 1
		1:
			if glow_state > Glow.TRY_FANFARE:
				_start_monitors()
				_task_state = 2
		2:
			if glow_state > Glow.WAIT_AFTER_FLASH:
				_task_state = 3
		3:
			if glow_state > Glow.WAIT_FANFARE:
				_glowing = false
				active = false
				_objects.task_effects.erase(_effect)


func _create_monitors() -> void:
	var frlg: bool = _frlg()
	if _heals():
		_add(Art.MONITOR, Vector2i(128 if frlg else 124, 24), 2, 0, Callback.MONITOR, true)
	elif not frlg:
		_add(Art.HOF_BIG, Vector2i(120, 24), 2, 0, Callback.HOENN_HOF, true)
		for at: Vector2i in HOENN_HOF_SMALL:
			_add(Art.HOF_SMALL, at, 0, 0, Callback.HOENN_HOF, true)


func _start_monitors() -> void:
	if not _heals():
		_hof_flash = true
		if _frlg():
			_add(Art.HOF_BIG, Vector2i(120, 25), 0, 0, Callback.FRLG_HOF, false)
		return
	for sprite: Dictionary in _sprites:
		if int(sprite["callback"]) == Callback.MONITOR:
			sprite["invisible"] = false
			(sprite["anim"] as Gen3SpriteAnim).start(1)


func _add(art: int, at: Vector2i, priority: int, subpriority: int, callback: int, invisible: bool) -> void:
	var slot: int = _objects.sprites.effect_slot()
	var info: Dictionary = _objects.camera.data.world_heal_graphics(art)
	if slot < 0 or info.is_empty():
		return
	var anim := Gen3SpriteAnim.new()
	anim.anims = info["anims"]
	anim.images = info["images"]
	var sprite: Dictionary = {"sprite_slot": slot, "anim": anim, "callback": callback, "position": at,
		"size": Vector2i(int(info["width"]), int(info["height"])), "priority": priority, "subpriority": subpriority,
		"palette": _objects.sprites.load_effect_palette(info), "tiles": PackedByteArray(), "invisible": invisible,
		"timer": 0, "flips": 0}
	_objects.sprites.pics.append(sprite)
	_sprites.append(sprite)


func animate() -> Array: # `AnimateSprites`: the balls' invisible controller, then every sprite's callback and animation.
	var out: Array = []
	if _glowing:
		_step_glow(out)
	for sprite: Dictionary in _sprites.duplicate():
		if _step_callback(sprite):
			_free(sprite)
			continue
		var anim: Gen3SpriteAnim = sprite["anim"]
		anim.animate()
		sprite["tiles"] = PackedByteArray() if anim.tiles.is_empty() \
			else _objects.camera.data.world_sprite_image(int(anim.tiles[0]), int(anim.tiles[1]))
	return out


func _step_callback(sprite: Dictionary) -> bool: # True when the sprite frees itself.
	var anim: Gen3SpriteAnim = sprite["anim"]
	match int(sprite["callback"]):
		Callback.BALL:
			return glow_state > Glow.WAIT_AFTER_FLASH
		Callback.HOENN_HOF:
			if _hof_flash:
				if int(sprite["timer"]) <= 1:
					sprite["timer"] = 16
					sprite["invisible"] = not sprite["invisible"]
				else:
					sprite["timer"] = int(sprite["timer"]) - 1
				sprite["flips"] = int(sprite["flips"]) + 1
			return int(sprite["flips"]) > HOF_FLIPS
	return anim.ended


func _free(sprite: Dictionary) -> void:
	_sprites.erase(sprite)
	_objects.sprites.pics.erase(sprite)
	_objects.sprites.free_effect_palette(sprite)


func _step_glow(out: Array) -> void:
	match glow_state:
		Glow.PLACE_BALLS: _place_balls(out)
		Glow.TRY_FANFARE:
			_timer -= 1
			if _timer == 0:
				glow_state = Glow.FLASH_1
				_timer = 8
				_counter = 0
				_rounds = 0
				if _heals():
					out.append({"kind": "fanfare", "name": "mus_heal"})
		Glow.FLASH_1: _flash_rising()
		Glow.FLASH_2: _flash_falling()
		Glow.WAIT_AFTER_FLASH:
			_timer -= 1
			if _timer == 0:
				glow_state = Glow.DUMMY
		Glow.DUMMY: glow_state = Glow.WAIT_FANFARE
		Glow.WAIT_FANFARE: glow_state = Glow.IDLE # `IsFanfareTaskInactive`: no GBA music driver holds it yet.


func _place_balls(out: Array) -> void:
	if _timer != 0:
		_timer -= 1
	if _timer == 0:
		_timer = 25
		var first: Vector2i = Vector2i(93, 36) if _heals() else Vector2i(117, 60 if _frlg() else 52)
		_add(Art.GLOW, first + BALL_OFFSETS[_counter], 2, 0xFF if _frlg() else 0, Callback.BALL, false)
		_counter += 1
		_left -= 1
		out.append({"kind": "sound", "name": "ball"})
	if _left == 0:
		_timer = 32
		glow_state = Glow.TRY_FANFARE


func _flash_rising() -> void:
	_timer -= 1
	if _timer == 0:
		_timer = 8
		_counter = (_counter + 1) & 3
		if _counter == 0:
			_rounds += 1
	for color: int in FLASH_COLORS:
		_tint(color, (_counter + int(FLASH_COLORS[color])) & 3)
	if _rounds > 2:
		glow_state = Glow.FLASH_2
		_timer = 8
		_counter = 0


func _flash_falling() -> void:
	_timer -= 1
	if _timer == 0:
		_timer = 8
		_counter = (_counter + 1) & 3
		if _counter == 3:
			glow_state = Glow.WAIT_AFTER_FLASH
			_timer = 30
	for color: int in FLASH_COLORS:
		_tint(color, _counter)


func _tint(color: int, phase: int) -> void:
	var level: int = GLOW_LEVELS[phase]
	_objects.sprites.palette.multiply_inverted(Gen3Palette.OBJ_OFFSET + _glow_palette * 16 + color, level, level, 0)
