class_name Gen3WeatherSprites
extends RefCounted

## `field_weather_effect.c`'s rain, thunderstorm and downpour (Ruby's light, medium and heavy rain): 24 raindrop
## sprites, how many show, and the lightning and its thunder. [method animate] is `AnimateSprites`' pass.

## Emitted where `UpdateThunderSound` plays SE_THUNDER, or SE_THUNDER2 when [param second].
signal thunder(second: bool)

const RAIN_TILE_BYTES: int = 0x600
const MAX_RAIN_SPRITES: int = 24
const RAIN_SUBPRIORITY: int = 78
const RAIN_PRIORITY: int = 1
const RAIN_SIZE := Vector2i(16, 32)
const RAIN_COORDS: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(0, 160), Vector2i(0, 64), Vector2i(144, 224), Vector2i(144, 128), Vector2i(32, 32),
	Vector2i(32, 192), Vector2i(32, 96), Vector2i(72, 128), Vector2i(72, 32), Vector2i(72, 192), Vector2i(216, 96),
	Vector2i(216, 0), Vector2i(104, 160), Vector2i(104, 64), Vector2i(104, 224), Vector2i(144, 0),
	Vector2i(144, 160), Vector2i(144, 64), Vector2i(32, 224), Vector2i(32, 128), Vector2i(72, 32),
	Vector2i(72, 192), Vector2i(48, 96),
]
## `sRainSpriteMovement` (Q.4 pixels a frame) and `sRainSpriteFallingDurations`, by downpour.
const RAIN_MOVEMENT: Array[Vector2i] = [Vector2i(-0x68, 0xD0), Vector2i(-0xA0, 0x140)]
const RAIN_DURATIONS: Array[Vector2i] = [Vector2i(18, 7), Vector2i(12, 10)]
## `sRainSpriteAnimCmds`: falling, then the splash and the downpour's heavier one; frames are sheet tiles.
const RAIN_ANIMS: Array = [
	[0 | 16 << 16, Gen3SpriteAnim.JUMP],
	[8 | 3 << 16, 32 | 2 << 16, 40 | 2 << 16, Gen3SpriteAnim.END],
	[8 | 3 << 16, 16 | 3 << 16, 24 | 4 << 16, Gen3SpriteAnim.END],
]
## The reflections' distortion controllers hold the two slots after it.
const LAST_FREE_SLOT: int = Gen3ObjectSprites.SPRITE_COUNT - 3

enum Callback { UPDATE, WAIT }
enum Thunder {
	LOAD_RAIN, CREATE_RAIN, INIT_RAIN, WAIT_CHANGE, NEW_CYCLE, NEW_CYCLE_WAIT, INIT_CYCLE_1, INIT_CYCLE_2,
	SHORT_BOLT, TRY_NEW_BOLT, WAIT_BOLT_SHORT, INIT_BOLT_LONG, WAIT_BOLT_LONG, FADE_BOLT_LONG, END_BOLT_LONG,
}


## One raindrop: `struct Sprite`'s fields the rain reads and its `data[0]`-`data[6]` as s16.
class Raindrop:
	extends RefCounted
	var slot: int = 0
	var x: int = 0
	var y: int = 0
	var invisible: bool = false
	var coord_offset: bool = false
	var callback: int = Callback.UPDATE
	var anim := Gen3SpriteAnim.new()
	var counter: int = 0
	var random: int = 0
	var pos_x: int = 0
	var pos_y: int = 0
	var splashing: bool = false
	var active: bool = false
	var waiting: bool = false


var rain_tiles := PackedByteArray()
## `rainSprites`, null where `CreateSpriteAtEnd` found no slot.
var raindrops: Array = []
var rain_sprite_count: int = 0
var current_rain_index: int = 0
var target_rain_count: int = 0
var visible_counter: int = 0
var visible_delay: int = 0
var downpour: bool = false
var thunder_timer: int = 0
var thunder_se_timer: int = 0
var thunder_allow_end: bool = false
var thunder_long_bolt: bool = false
var thunder_short_bolts: int = 0
var thunder_enqueued: bool = false
var coord_offset := Vector2i.ZERO
## Answers `IsSEPlaying` for the thunder; unset, no sound effect plays, as GBA sound effects do not yet.
var is_se_playing: Callable
## Answers the sprite slots other field sprites hold, which `CreateSpriteAtEnd` skips.
var taken_slots: Callable


func _init(game: GameData) -> void:
	rain_tiles = game.world_weather().get("rain", PackedByteArray())


static func is_rain(weather: int) -> bool:
	return weather in [Gen3FieldWeather.Weather.RAIN, Gen3FieldWeather.Weather.RAIN_THUNDERSTORM,
		Gen3FieldWeather.Weather.DOWNPOUR]


func reset() -> void:
	rain_sprite_count = 0
	current_rain_index = 0


func init_vars(weather: int) -> void:
	visible_counter = 0
	visible_delay = 8 if weather == Gen3FieldWeather.Weather.RAIN else 4
	downpour = weather == Gen3FieldWeather.Weather.DOWNPOUR
	target_rain_count = {Gen3FieldWeather.Weather.RAIN: 10, Gen3FieldWeather.Weather.RAIN_THUNDERSTORM: 16}.get(
		weather, MAX_RAIN_SPRITES)
	if weather == Gen3FieldWeather.Weather.RAIN_THUNDERSTORM:
		thunder_enqueued = false


func main(weather: Gen3FieldWeather) -> void:
	if weather.current == Gen3FieldWeather.Weather.RAIN:
		_rain_main(weather)
	else:
		_thunderstorm_main(weather)


## `Rain_Finish` and `Thunderstorm_Finish`: true while the raindrops are still going.
func finish(weather: Gen3FieldWeather) -> bool:
	if weather.current == Gen3FieldWeather.Weather.RAIN:
		return _rain_finish(weather)
	return _thunderstorm_finish(weather)


func _rain_main(weather: Gen3FieldWeather) -> void:
	match weather.init_step:
		0:
			weather.init_step += 1
		1:
			if not _create_raindrop():
				weather.init_step += 1
		2:
			if not _update_visible():
				weather.gfx_loaded = true
				weather.init_step += 1


func _rain_finish(weather: Gen3FieldWeather) -> bool:
	if weather.finish_step == 0:
		if is_rain(weather.next):
			weather.finish_step = 0xFF
			return false
		target_rain_count = 0
		weather.finish_step += 1
	if weather.finish_step == 1:
		if not _update_visible():
			_destroy_raindrops()
			weather.finish_step += 1
			return false
		return true
	return false


func _thunderstorm_finish(weather: Gen3FieldWeather) -> bool:
	match weather.finish_step:
		0, 1:
			if weather.finish_step == 0:
				thunder_allow_end = false
				weather.finish_step += 1
			_thunderstorm_main(weather)
			if thunder_allow_end:
				if is_rain(weather.next):
					return false
				target_rain_count = 0
				weather.finish_step += 1
		2:
			if not _update_visible():
				_destroy_raindrops()
				thunder_enqueued = false
				weather.finish_step += 1
				return false
		_:
			return false
	return true


## `Thunderstorm_Main`: (short bolt){1,2} (long bolt)?, thunder on the cycle's last bolt.
func _thunderstorm_main(weather: Gen3FieldWeather) -> void:
	_update_thunder_sound(weather.events.random)
	var step: int = weather.init_step
	if step <= Thunder.WAIT_CHANGE:
		_thunderstorm_rain(weather)
	elif step <= Thunder.NEW_CYCLE_WAIT:
		if step == Thunder.NEW_CYCLE:
			thunder_allow_end = true
			thunder_timer = weather.events.random.next() % 360 + 360
			weather.init_step += 1
		thunder_timer = (thunder_timer - 1) & 0xFFFF
		if thunder_timer == 0:
			weather.init_step += 1
	elif step <= Thunder.TRY_NEW_BOLT:
		_short_bolts(weather)
	else:
		_long_bolt(weather)


func _thunderstorm_rain(weather: Gen3FieldWeather) -> void:
	match weather.init_step:
		Thunder.LOAD_RAIN:
			weather.init_step += 1
		Thunder.CREATE_RAIN:
			if not _create_raindrop():
				weather.init_step += 1
		Thunder.INIT_RAIN:
			if not _update_visible():
				weather.gfx_loaded = true
				weather.init_step += 1
		Thunder.WAIT_CHANGE:
			if weather.state != Gen3FieldWeather.PalState.CHANGING_WEATHER:
				weather.init_step = Thunder.INIT_CYCLE_1


func _short_bolts(weather: Gen3FieldWeather) -> void:
	var random: Gen3Random = weather.events.random
	if weather.init_step == Thunder.INIT_CYCLE_1:
		thunder_allow_end = true
		thunder_long_bolt = random.next() % 2 == 1
		weather.init_step += 1
		return
	if weather.init_step == Thunder.INIT_CYCLE_2:
		thunder_short_bolts = (random.next() & 1) + 1
		weather.init_step += 1
	if weather.init_step == Thunder.SHORT_BOLT:
		weather.apply_if_idle(19)
		if not thunder_long_bolt and thunder_short_bolts == 1:
			_enqueue_thunder(random, 20)
		thunder_timer = random.next() % 3 + 6
		weather.init_step += 1
		return
	thunder_timer = (thunder_timer - 1) & 0xFFFF
	if thunder_timer != 0:
		return
	weather.apply_if_idle(3)
	thunder_allow_end = true
	thunder_short_bolts = (thunder_short_bolts - 1) & 0xFF
	if thunder_short_bolts != 0:
		thunder_timer = random.next() % 16 + 60
		weather.init_step = Thunder.WAIT_BOLT_SHORT
	elif not thunder_long_bolt:
		weather.init_step = Thunder.NEW_CYCLE
	else:
		weather.init_step = Thunder.INIT_BOLT_LONG


func _long_bolt(weather: Gen3FieldWeather) -> void:
	var random: Gen3Random = weather.events.random
	match weather.init_step:
		Thunder.WAIT_BOLT_SHORT:
			if _tick_thunder():
				weather.init_step = Thunder.SHORT_BOLT
		Thunder.INIT_BOLT_LONG:
			thunder_timer = random.next() % 16 + 60
			weather.init_step += 1
		Thunder.WAIT_BOLT_LONG:
			if _tick_thunder():
				_enqueue_thunder(random, 100)
				weather.apply_if_idle(19)
				thunder_timer = (random.next() & 0xF) + 30
				weather.init_step += 1
		Thunder.FADE_BOLT_LONG:
			if _tick_thunder():
				weather.apply_if_idle_gradual(19, 3, 5)
				weather.init_step += 1
		Thunder.END_BOLT_LONG:
			if weather.state == Gen3FieldWeather.PalState.IDLE:
				thunder_allow_end = true
				weather.init_step = Thunder.NEW_CYCLE


func _tick_thunder() -> bool:
	thunder_timer = (thunder_timer - 1) & 0xFFFF
	return thunder_timer == 0


func _enqueue_thunder(random: Gen3Random, frames: int) -> void:
	if not thunder_enqueued:
		thunder_se_timer = random.next() % frames
		thunder_enqueued = true


func _update_thunder_sound(random: Gen3Random) -> void:
	if not thunder_enqueued:
		return
	if thunder_se_timer != 0:
		thunder_se_timer -= 1
		return
	if is_se_playing.is_valid() and is_se_playing.call():
		return
	thunder.emit(random.next() & 1 == 0)
	thunder_enqueued = false


## `CreateRainSprite`: one raindrop a call; false once all 24 exist, when each gets its callback.
func _create_raindrop() -> bool:
	if rain_sprite_count == MAX_RAIN_SPRITES:
		return false
	var index: int = rain_sprite_count
	var slot: int = _free_slot()
	var drop: Raindrop = null
	if slot >= 0:
		drop = Raindrop.new()
		drop.slot = slot
		drop.x = RAIN_COORDS[index].x
		drop.y = RAIN_COORDS[index].y
		drop.anim.anims = RAIN_ANIMS
		drop.random = index * 145 % 600
		_start_fall(drop)
		_init_movement(drop, index * 9)
		drop.invisible = true
	if raindrops.size() <= index:
		raindrops.resize(index + 1)
	raindrops[index] = drop
	rain_sprite_count += 1
	if rain_sprite_count != MAX_RAIN_SPRITES:
		return true
	for each: Raindrop in raindrops:
		if each != null:
			each.callback = Callback.WAIT if each.waiting else Callback.UPDATE
	return false


func _free_slot() -> int:
	var taken: Array = (taken_slots.call() if taken_slots.is_valid() else []) + slots()
	for slot: int in range(LAST_FREE_SLOT, -1, -1):
		if not slot in taken:
			return slot
	return -1


func slots() -> Array:
	var out: Array = []
	for drop: Raindrop in raindrops:
		if drop != null:
			out.append(drop.slot)
	return out


## `UpdateVisibleRainSprites`: a raindrop more or fewer toward the target; false once there.
func _update_visible() -> bool:
	if current_rain_index == target_rain_count:
		return false
	visible_counter = (visible_counter + 1) & 0xFFFF
	if visible_counter > visible_delay:
		visible_counter = 0
		if current_rain_index < target_rain_count:
			raindrops[current_rain_index].active = true
			current_rain_index += 1
		else:
			current_rain_index -= 1
			raindrops[current_rain_index].active = false
			raindrops[current_rain_index].invisible = true
	return true


func _destroy_raindrops() -> void:
	raindrops.clear()
	rain_sprite_count = 0


## `StartRainSpriteFall`: a tile on the 30x20 grid from the raindrop's own LCG, rewound by its fall.
func _start_fall(drop: Raindrop) -> void:
	if drop.random == 0:
		drop.random = 361
	var value: int = (drop.random * 1103515245 + 12345) & 0xFFFFFFFF
	drop.random = ((value & 0x7FFF0000) >> 16) % 600
	var frames: int = RAIN_DURATIONS[int(downpour)].x
	var movement: Vector2i = RAIN_MOVEMENT[int(downpour)]
	drop.pos_x = _s16((drop.random % 30 << 7) - movement.x * frames)
	drop.pos_y = _s16((drop.random / 30 << 7) - movement.y * frames)
	drop.anim.start(0)
	drop.splashing = false
	drop.coord_offset = false
	drop.counter = frames


func _init_movement(drop: Raindrop, frames: int) -> void:
	var duration: Vector2i = RAIN_DURATIONS[int(downpour)]
	for fall: int in frames / (duration.x + duration.y):
		_start_fall(drop)
	var left: int = frames % (duration.x + duration.y)
	if left < duration.x:
		for frame: int in left:
			_update(drop)
		drop.waiting = false
	else:
		drop.counter = left - duration.x
		drop.invisible = true
		drop.waiting = true


## Each raindrop's callback then its anim, by slot; [param offset] is `gSpriteCoordOffsetX`/`Y`.
func animate(offset: Vector2i) -> void:
	coord_offset = offset
	var drops: Array = raindrops.filter(func(drop: Raindrop) -> bool: return drop != null)
	drops.sort_custom(func(a: Raindrop, b: Raindrop) -> bool: return a.slot < b.slot)
	for drop: Raindrop in drops:
		if drop.callback == Callback.WAIT:
			_wait(drop)
		else:
			_update(drop)
		drop.anim.animate()


## `UpdateRainSprite`: fall, shown while active and near the screen, then splash pinned to the map.
func _update(drop: Raindrop) -> void:
	if drop.splashing:
		if drop.anim.ended:
			drop.invisible = true
			_start_fall(drop)
		return
	var movement: Vector2i = RAIN_MOVEMENT[int(downpour)]
	drop.pos_x = _s16(drop.pos_x + movement.x)
	drop.pos_y = _s16(drop.pos_y + movement.y)
	drop.x = drop.pos_x >> 4
	drop.y = drop.pos_y >> 4
	drop.invisible = not (drop.active and drop.x >= -8 and drop.x <= 248 and drop.y >= -16 and drop.y <= 176)
	drop.counter = _s16(drop.counter - 1)
	if drop.counter == 0:
		drop.anim.start(int(downpour) + 1)
		drop.splashing = true
		drop.x = _s16(drop.x - coord_offset.x)
		drop.y = _s16(drop.y - coord_offset.y)
		drop.coord_offset = true


func _wait(drop: Raindrop) -> void:
	if drop.counter == 0:
		_start_fall(drop)
		drop.callback = Callback.UPDATE
	else:
		drop.counter = _s16(drop.counter - 1)


static func _s16(value: int) -> int:
	return ((value & 0xFFFF) ^ 0x8000) - 0x8000


## OAM entries by sprite slot for [Gen3ObjectSprites]; a splash adds [param offset].
func oam_entries(offset: Vector2i, palette: int) -> Dictionary:
	var entries: Dictionary = {}
	for drop: Raindrop in raindrops:
		if drop == null:
			continue
		var at := Vector2i(drop.x, drop.y) - RAIN_SIZE / 2 + (offset if drop.coord_offset else Vector2i.ZERO)
		var tiles: PackedByteArray = rain_tiles.slice(drop.anim.image * GbaTiles.TILE_BYTES,
			(drop.anim.image + 8) * GbaTiles.TILE_BYTES)
		entries[drop.slot] = {"y": at.y & 0xFF, "key": RAIN_PRIORITY << 8 | RAIN_SUBPRIORITY,
			"invisible": drop.invisible, "part": {"x": at.x & 0x1FF, "y": at.y & 0xFF, "flip": Vector2i.ZERO,
				"priority": RAIN_PRIORITY, "palette": palette, "size": RAIN_SIZE, "tiles": tiles}}
	return entries
