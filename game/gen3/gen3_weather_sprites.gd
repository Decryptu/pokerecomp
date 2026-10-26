class_name Gen3WeatherSprites
extends RefCounted

## `field_weather_effect.c`'s sprite weathers: the rain, thunderstorm and downpour (Ruby's light, medium and heavy
## rain) with the lightning and its thunder, and the clouds, snow, horizontal fog (and underwater), volcanic ash,
## sandstorm, diagonal fog and underwater bubbles with their blend ramps. [method animate] is `AnimateSprites`'
## pass over every weather sprite.

## Emitted where `UpdateThunderSound` plays SE_THUNDER, or SE_THUNDER2 when [param second].
signal thunder(second: bool)

## The palettes and sheets `field_weather_effect.c` (FireRed and LeafGreen's `field_weather.c`) opens with, in ROM
## order and size; `snow` is both flakes' one-tile images.
const SHEETS: Array = [
	["cloud_palette", 0x20], ["sandstorm_palette", 0x20], ["fog_diagonal", 0x800], ["fog_horizontal", 0x800],
	["cloud", 0x800], ["snow", 0x40], ["bubble", 0x40], ["ash", 0x1000], ["rain", 0x600], ["sandstorm", 0xA00],
]
const MAX_RAIN_SPRITES: int = 24
const RAIN_SUBPRIORITY: int = 78
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
## Anims by template; frames are sheet tiles (the snowflakes' are their two one-tile images).
const RAIN_ANIMS: Array = [
	[0 | 16 << 16, Gen3SpriteAnim.JUMP],
	[8 | 3 << 16, 32 | 2 << 16, 40 | 2 << 16, Gen3SpriteAnim.END],
	[8 | 3 << 16, 16 | 3 << 16, 24 | 4 << 16, Gen3SpriteAnim.END],
]
const STILL_ANIMS: Array = [[0 | 16 << 16, Gen3SpriteAnim.END]]
const SNOW_ANIMS: Array = [[0 | 16 << 16, Gen3SpriteAnim.END], [1 | 16 << 16, Gen3SpriteAnim.END]]
const ASH_ANIMS: Array = [[0 | 60 << 16, 64 | 60 << 16, Gen3SpriteAnim.JUMP]]
const SANDSTORM_ANIMS: Array = [[0 | 3 << 16, Gen3SpriteAnim.END], [64 | 3 << 16, Gen3SpriteAnim.END]]
const BUBBLE_ANIMS: Array = [[0 | 16 << 16, 1 | 16 << 16, Gen3SpriteAnim.END]]
## `sCloudSpriteMapCoords`, on Route 120's lower half.
const CLOUD_COORDS: Array[Vector2i] = [Vector2i(0, 66), Vector2i(5, 73), Vector2i(10, 78)]
const NUM_CLOUD_SPRITES: int = 3
const NUM_SNOWFLAKE_SPRITES: int = 16
## The fogs, ash and sandstorm tile the screen with five columns of four 64x64 sprites.
const NUM_TILED_SPRITES: int = 20
const COLUMNS: int = 5
const NUM_SWIRL_SPRITES: int = 5
const SWIRL_ENTRANCE_DELAYS: Array[int] = [0, 120, 80, 160, 40]
const MIN_SANDSTORM_WAVE_INDEX: int = 0x20
const BUBBLE_START_DELAYS: Array[int] = [40, 90, 60, 90, 2, 60, 40, 30]
const BUBBLE_START_COORDS: Array[Vector2i] = [
	Vector2i(120, 160), Vector2i(376, 160), Vector2i(40, 140), Vector2i(296, 140), Vector2i(180, 130),
	Vector2i(436, 130), Vector2i(60, 160), Vector2i(436, 160), Vector2i(220, 180), Vector2i(476, 180),
	Vector2i(10, 90), Vector2i(266, 90), Vector2i(256, 160),
]
## The reflections' distortion controllers hold the two slots after it.
const LAST_FREE_SLOT: int = Gen3ObjectSprites.SPRITE_COUNT - 3
## The screen's width plus one sprite's half, past which a tiled column wraps to the left.
const TILE_WRAP: int = 240 + 32

## The sprite callbacks, rain's first.
enum Callback {
	UPDATE, WAIT, CLOUD, SNOW, SNOW_WAIT, FOG_HORIZONTAL, ASH, FOG_DIAGONAL, SANDSTORM, SWIRL_WAIT, SWIRL, BUBBLE,
}
enum Thunder {
	LOAD_RAIN, CREATE_RAIN, INIT_RAIN, WAIT_CHANGE, NEW_CYCLE, NEW_CYCLE_WAIT, INIT_CYCLE_1, INIT_CYCLE_2,
	SHORT_BOLT, TRY_NEW_BOLT, WAIT_BOLT_SHORT, INIT_BOLT_LONG, WAIT_BOLT_LONG, FADE_BOLT_LONG, END_BOLT_LONG,
}


## One weather sprite: `struct Sprite`'s fields the weathers read, `data[]` as s16, and its template's sheet,
## OAM size, priority, blend mode and palette tag (PALTAG_WEATHER_2 when [member second_palette]).
class WeatherSprite:
	extends RefCounted
	var slot: int = 0
	var x: int = 0
	var y: int = 0
	var x2: int = 0
	var y2: int = 0
	var invisible: bool = false
	var coord_offset: bool = false
	var callback: int = Callback.UPDATE
	var anim := Gen3SpriteAnim.new()
	var data := PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0])
	var sheet: String = "rain"
	var size := RAIN_SIZE
	var priority: int = 1
	var subpriority: int = 0
	var blend: bool = false
	var second_palette: bool = false
	## A sheet sprite's tile number; the snowflakes copy images instead.
	var sheet_tiles: bool = true

	## `data[]` as the cartridge holds it.
	func words() -> PackedInt32Array:
		return data


## A raindrop names its `data[0]`-`data[6]`.
class Raindrop:
	extends WeatherSprite
	var counter: int = 0
	var random: int = 0
	var pos_x: int = 0
	var pos_y: int = 0
	var splashing: bool = false
	var active: bool = false
	var waiting: bool = false

	func words() -> PackedInt32Array:
		return PackedInt32Array([counter, random, pos_x, pos_y, int(splashing), int(active), int(waiting), 0])


var sheets: Dictionary = {}
## The live weather sprites by slot, as `gSprites` holds them.
var pool: Dictionary = {}
## The field's flags, vars and its one `Random` stream, which the snowflakes draw from.
var events: Gen3EventData
## Answers `SetSpritePosToMapCoords` for the clouds.
var camera: Gen3FieldCamera
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
## `gSpriteCoordOffsetX`/`Y` as the last [method animate] set it.
var coord_offset := Vector2i.ZERO
## Answers `IsSEPlaying` for the thunder; unset, no sound effect plays, as GBA sound effects do not yet.
var is_se_playing: Callable
## Answers the sprite slots other field sprites hold, which `CreateSprite` and `CreateSpriteAtEnd` skip.
var taken_slots: Callable
var cloud_sprites: Array = []
var clouds_created: bool = false
var snowflakes: Array = []
var target_snowflakes: int = 0
var snow_visible_counter: int = 0
## `snowflakeTimer`: nothing counts it, so a snowflake that leaves the screen waits for good.
var snow_timer: int = 0
var fog_horizontal_sprites: Array = []
var fog_horizontal_created: bool = false
var fog_horizontal_pos_x: int = 0
var fog_horizontal_counter: int = 0
var fog_horizontal_offset: int = 0
var ash_sprites: Array = []
var ash_created: bool = false
var ash_base_x: int = 0
var sandstorm_sprites: Array = []
var swirl_sprites: Array = []
var sandstorm_created: bool = false
var swirls_created: bool = false
## `sandstormXOffset` and `sandstormYOffset` are u32.
var sandstorm_x_offset: int = 0
var sandstorm_y_offset: int = 0
var sandstorm_base_x: int = 0
var sandstorm_pos_y: int = 0
var sandstorm_wave_index: int = 0
var sandstorm_wave_counter: int = 0
var fog_diagonal_sprites: Array = []
var fog_diagonal_created: bool = false
var fog_diagonal_base_x: int = 0
var fog_diagonal_pos_y: int = 0
var fog_diagonal_x_counter: int = 0
var fog_diagonal_y_counter: int = 0
var fog_diagonal_x_offset: int = 0
var fog_diagonal_y_offset: int = 0
var bubbles: Array = []
var bubble_delay_counter: int = 0
var bubble_delay_index: int = 0
var bubble_coords_index: int = 0
## `bubblesSpriteCount` counts bubbles made; one that rises out of its time is not taken off.
var bubble_count: int = 0
var _emerald: bool = false


func _init(game: GameData) -> void:
	sheets = game.world_weather().get("sheets", {})
	_emerald = game.id == RomRegistry.EMERALD


static func is_rain(weather: int) -> bool:
	return weather in [Gen3FieldWeather.Weather.RAIN, Gen3FieldWeather.Weather.RAIN_THUNDERSTORM,
		Gen3FieldWeather.Weather.DOWNPOUR]


## The weathers whose callbacks this class runs; the others only aim the colour map.
static func has_sprites(weather: int) -> bool:
	return is_rain(weather) or weather in [Gen3FieldWeather.Weather.SUNNY_CLOUDS, Gen3FieldWeather.Weather.SNOW,
		Gen3FieldWeather.Weather.FOG_HORIZONTAL, Gen3FieldWeather.Weather.VOLCANIC_ASH,
		Gen3FieldWeather.Weather.SANDSTORM, Gen3FieldWeather.Weather.FOG_DIAGONAL,
		Gen3FieldWeather.Weather.UNDERWATER, Gen3FieldWeather.Weather.UNDERWATER_BUBBLES]


## `StartWeather`'s counts and created flags; a map load has already freed every sprite.
func reset() -> void:
	pool.clear()
	rain_sprite_count = 0
	current_rain_index = 0
	raindrops = []
	clouds_created = false
	snowflakes = []
	ash_created = false
	fog_horizontal_created = false
	fog_diagonal_created = false
	sandstorm_created = false
	swirls_created = false


## Each sprite weather's InitVars past the colour-map target [Gen3FieldWeather] sets.
func init_vars(weather: Gen3FieldWeather, number: int) -> void:
	match number:
		Gen3FieldWeather.Weather.SUNNY_CLOUDS:
			if not clouds_created:
				weather.set_blend_coeffs(0, 16)
		Gen3FieldWeather.Weather.SNOW:
			target_snowflakes = NUM_SNOWFLAKE_SPRITES
			snow_visible_counter = 0
		Gen3FieldWeather.Weather.FOG_HORIZONTAL, Gen3FieldWeather.Weather.UNDERWATER:
			_fog_horizontal_init_vars(weather)
		Gen3FieldWeather.Weather.VOLCANIC_ASH:
			_ash_init_vars(weather)
		Gen3FieldWeather.Weather.SANDSTORM:
			_sandstorm_init_vars(weather)
		Gen3FieldWeather.Weather.FOG_DIAGONAL:
			_fog_diagonal_init_vars(weather)
		Gen3FieldWeather.Weather.UNDERWATER_BUBBLES:
			_fog_horizontal_init_vars(weather)
			bubble_delay_index = 0
			bubble_delay_counter = BUBBLE_START_DELAYS[0]
			bubble_coords_index = 0
			bubble_count = 0
		_:
			_rain_init_vars(number)


## Each sprite weather's InitAll: its Main until the graphics are loaded, the snowflakes' callbacks with it.
func init_all(weather: Gen3FieldWeather) -> void:
	while not weather.gfx_loaded:
		main(weather)
		if weather.current == Gen3FieldWeather.Weather.SNOW:
			for flake: WeatherSprite in snowflakes:
				_update_snowflake(flake)


func main(weather: Gen3FieldWeather) -> void:
	match weather.current:
		Gen3FieldWeather.Weather.SUNNY_CLOUDS:
			_clouds_main(weather)
		Gen3FieldWeather.Weather.SNOW:
			if weather.init_step == 0 and not _update_visible_snowflakes():
				weather.gfx_loaded = true
				weather.init_step += 1
		Gen3FieldWeather.Weather.FOG_HORIZONTAL, Gen3FieldWeather.Weather.UNDERWATER:
			_fog_horizontal_main(weather)
		Gen3FieldWeather.Weather.VOLCANIC_ASH:
			_ash_main(weather)
		Gen3FieldWeather.Weather.SANDSTORM:
			_sandstorm_main(weather)
		Gen3FieldWeather.Weather.FOG_DIAGONAL:
			_fog_diagonal_main(weather)
		Gen3FieldWeather.Weather.UNDERWATER_BUBBLES:
			_bubbles_main(weather)
		Gen3FieldWeather.Weather.RAIN:
			_rain_main(weather)
		_:
			_thunderstorm_main(weather)


## Each sprite weather's Finish: true while its sprites are still going.
func finish(weather: Gen3FieldWeather) -> bool:
	match weather.current:
		Gen3FieldWeather.Weather.SUNNY_CLOUDS:
			return _clouds_finish(weather)
		Gen3FieldWeather.Weather.SNOW:
			return _snow_finish(weather)
		Gen3FieldWeather.Weather.FOG_HORIZONTAL, Gen3FieldWeather.Weather.UNDERWATER:
			return _fog_horizontal_finish(weather)
		Gen3FieldWeather.Weather.VOLCANIC_ASH:
			return _ash_finish(weather)
		Gen3FieldWeather.Weather.SANDSTORM:
			return _sandstorm_finish(weather)
		Gen3FieldWeather.Weather.FOG_DIAGONAL:
			return _fog_diagonal_finish(weather)
		Gen3FieldWeather.Weather.UNDERWATER_BUBBLES:
			return _bubbles_finish(weather)
		Gen3FieldWeather.Weather.RAIN:
			return _rain_finish(weather)
	return _thunderstorm_finish(weather)


func _rain_init_vars(number: int) -> void:
	visible_counter = 0
	visible_delay = 8 if number == Gen3FieldWeather.Weather.RAIN else 4
	downpour = number == Gen3FieldWeather.Weather.DOWNPOUR
	target_rain_count = {Gen3FieldWeather.Weather.RAIN: 10, Gen3FieldWeather.Weather.RAIN_THUNDERSTORM: 16}.get(
		number, MAX_RAIN_SPRITES)
	if number == Gen3FieldWeather.Weather.RAIN_THUNDERSTORM:
		thunder_enqueued = false


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
	var slot: int = _free_slot(true)
	var drop: Raindrop = null
	if slot >= 0:
		drop = Raindrop.new()
		_place(drop, slot, RAIN_COORDS[index], RAIN_SUBPRIORITY, RAIN_ANIMS)
		pool[slot] = drop
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


## `CreateSprite` from the first slot or `CreateSpriteAtEnd` from the last free one; -1 when none is left.
func _free_slot(from_end: bool) -> int:
	var taken: Array = (taken_slots.call() if taken_slots.is_valid() else []) + pool.keys()
	var order: Array = range(LAST_FREE_SLOT, -1, -1) if from_end else range(LAST_FREE_SLOT + 1)
	for slot: int in order:
		if not slot in taken:
			return slot
	return -1


## `CreateSpriteAt`: the template's first anim queued, a sheet sprite showing that anim's first tile.
static func _place(sprite: WeatherSprite, slot: int, at: Vector2i, subpriority: int, anims: Array) -> void:
	sprite.slot = slot
	sprite.x = at.x
	sprite.y = at.y
	sprite.subpriority = subpriority
	sprite.anim.anims = anims
	sprite.anim.image = int(anims[0][0]) & 0xFFFF


## A sprite of [param sheet] at [param at], or null when no slot is free.
func _create(sheet: String, size: Vector2i, priority: int, callback: int, at: Vector2i, subpriority: int,
		anims: Array, from_end: bool = true) -> WeatherSprite:
	var slot: int = _free_slot(from_end)
	if slot < 0:
		return null
	var sprite := WeatherSprite.new()
	_place(sprite, slot, at, subpriority, anims)
	pool[slot] = sprite
	sprite.sheet = sheet
	sprite.size = size
	sprite.priority = priority
	sprite.callback = callback
	sprite.blend = sheet not in ["snow", "bubble"]
	sprite.second_palette = sheet in ["cloud", "sandstorm"]
	return sprite


func slots() -> Array:
	return pool.keys()


## Every live weather sprite, by slot.
func all_sprites() -> Array:
	var order: Array = pool.keys()
	order.sort()
	return order.map(func(slot: int) -> WeatherSprite: return pool[slot])


## `DestroySprite` on each of [param group]'s sprites, then the group forgotten.
func _destroy(group: Array) -> void:
	for sprite: WeatherSprite in group:
		if sprite != null:
			pool.erase(sprite.slot)
	group.clear()


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
	_destroy(raindrops)
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


## Each weather sprite's callback then its anim, by slot; [param offset] is `gSpriteCoordOffsetX`/`Y`. A bubble
## that ends in its callback is not animated.
func animate(offset: Vector2i) -> void:
	coord_offset = offset
	for sprite: WeatherSprite in all_sprites():
		_callback(sprite)
		if pool.has(sprite.slot):
			sprite.anim.animate()


func _callback(sprite: WeatherSprite) -> void:
	match sprite.callback:
		Callback.UPDATE:
			_update(sprite as Raindrop)
		Callback.WAIT:
			_wait(sprite as Raindrop)
		Callback.CLOUD:
			sprite.data[0] = (sprite.data[0] + 1) & 1
			if sprite.data[0] != 0:
				sprite.x = _s16(sprite.x - 1)
		Callback.SNOW:
			_update_snowflake(sprite)
		Callback.SNOW_WAIT:
			_wait_snowflake(sprite)
		Callback.FOG_HORIZONTAL:
			sprite.y2 = coord_offset.y & 0xFF
			_tile_column(sprite, fog_horizontal_pos_x)
		Callback.ASH:
			_update_ash(sprite)
		Callback.FOG_DIAGONAL:
			sprite.y2 = _s16(fog_diagonal_pos_y)
			_tile_column(sprite, fog_diagonal_base_x)
		Callback.SANDSTORM:
			sprite.y2 = _s16(sandstorm_pos_y)
			_tile_column(sprite, sandstorm_base_x)
		Callback.SWIRL_WAIT:
			sprite.data[3] = _s16(sprite.data[3] - 1)
			if sprite.data[3] == -1:
				sprite.callback = Callback.SWIRL
		Callback.SWIRL:
			_update_swirl(sprite)
		Callback.BUBBLE:
			_update_bubble(sprite)


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


## The fogs', ash's and sandstorm's column (`data[0]`; ash's `data[2]`) from [param base], wrapping past the screen.
static func _tile_column(sprite: WeatherSprite, base: int) -> void:
	var column: int = sprite.data[2] if sprite.callback == Callback.ASH else sprite.data[0]
	sprite.x = _s16(base + 32 + column * 64)
	if sprite.x >= TILE_WRAP:
		sprite.x = (base + 480 - (4 - column) * 64) & 0x1FF


func _clouds_main(weather: Gen3FieldWeather) -> void:
	match weather.init_step:
		0:
			_create_clouds(weather)
			weather.init_step += 1
		1:
			weather.set_target_blend_coeffs(12, 8, 1)
			weather.init_step += 1
		2:
			if weather.update_blend():
				weather.gfx_loaded = true
				weather.init_step += 1


func _clouds_finish(weather: Gen3FieldWeather) -> bool:
	match weather.finish_step:
		0:
			weather.set_target_blend_coeffs(0, 16, 1)
			weather.finish_step += 1
			return true
		1:
			if weather.update_blend():
				_destroy(cloud_sprites)
				clouds_created = false
				weather.finish_step += 1
			return true
	return false


## `CreateCloudSprites`: three clouds from the first free slots, placed on the map.
func _create_clouds(weather: Gen3FieldWeather) -> void:
	if clouds_created:
		return
	weather.load_sprite_palette(sheets.get("cloud_palette", PackedByteArray()))
	cloud_sprites = []
	for index: int in NUM_CLOUD_SPRITES:
		var cell: Vector2i = CLOUD_COORDS[index] + Vector2i(Gen3MapGrid.MAP_OFFSET, Gen3MapGrid.MAP_OFFSET)
		var at: Vector2i = camera.sprite_position(cell) if camera != null else Vector2i.ZERO
		var cloud: WeatherSprite = _create("cloud", Vector2i(64, 64), 3, Callback.CLOUD, at, 0xFF, STILL_ANIMS, false)
		if cloud != null:
			cloud.coord_offset = true
		cloud_sprites.append(cloud)
	clouds_created = true


func _snow_finish(weather: Gen3FieldWeather) -> bool:
	if weather.finish_step == 0:
		target_snowflakes = 0
		snow_visible_counter = 0
		weather.finish_step += 1
	if weather.finish_step == 1:
		if not _update_visible_snowflakes():
			weather.finish_step += 1
			return false
		return true
	return false


## `UpdateVisibleSnowflakeSprites`: a snowflake more or fewer every 37 calls; false once at the target.
func _update_visible_snowflakes() -> bool:
	if snowflakes.size() == target_snowflakes:
		return false
	snow_visible_counter = (snow_visible_counter + 1) & 0xFFFF
	if snow_visible_counter > 36:
		snow_visible_counter = 0
		if snowflakes.size() < target_snowflakes:
			_create_snowflake()
		elif not snowflakes.is_empty():
			pool.erase(snowflakes.pop_back().slot)
	return snowflakes.size() != target_snowflakes


func _create_snowflake() -> void:
	var flake: WeatherSprite = _create("snow", Vector2i(8, 8), 1, Callback.SNOW, Vector2i.ZERO, RAIN_SUBPRIORITY,
		SNOW_ANIMS)
	if flake == null:
		return
	flake.sheet_tiles = false
	flake.data[4] = snowflakes.size()
	_init_snowflake(flake)
	flake.coord_offset = true
	snowflakes.append(flake)


## `InitSnowflakeSpriteMovement`: a column of the screen's eight, its speed, sway and fall time.
func _init_snowflake(flake: WeatherSprite) -> void:
	var center: Vector2i = -flake.size / 2
	var column: int = (((flake.data[4] * 5) & 7) * 30 + _random().next() % 30) & 0xFFFF
	flake.y = _s16(-3 - (coord_offset.y + center.y))
	flake.x = _s16(column - (coord_offset.x + center.x))
	flake.data[0] = _s16(flake.y * 128)
	flake.x2 = 0
	var value: int = _random().next()
	flake.data[1] = (value & 3) * 5 + 64
	flake.data[7] = flake.data[1]
	flake.anim.start(0 if value & 1 else 1)
	flake.data[3] = 0
	flake.data[2] = 2 if value & 3 == 0 else 1
	flake.data[6] = (value & 0x1F) + 210
	flake.data[5] = 0


func _wait_snowflake(flake: WeatherSprite) -> void:
	if snow_timer > 18:
		flake.invisible = false
		flake.callback = Callback.SNOW
		flake.y = _s16(250 - (coord_offset.y - (flake.size.y >> 1)))
		flake.data[0] = _s16(flake.y * 128)
		snow_timer = 0


## `UpdateSnowflakeSprite`: fall and sway, wrap across, and drop out a little under the screen.
func _update_snowflake(flake: WeatherSprite) -> void:
	var center: Vector2i = -flake.size / 2
	flake.data[0] = _s16(flake.data[0] + flake.data[1])
	flake.y = flake.data[0] >> 7
	flake.data[3] = (flake.data[3] + flake.data[2]) & 0xFF
	flake.x2 = Gen3ObjectEvents.SINE[flake.data[3]] / 64
	var x: int = (flake.x + center.x + coord_offset.x) & 0x1FF
	if x & 0x100:
		x -= 0x200
	if x < -3:
		flake.x = _s16(242 - (coord_offset.x + center.x))
	elif x > 242:
		flake.x = _s16(-3 - (coord_offset.x + center.x))
	var y: int = (flake.y + center.y + coord_offset.y) & 0xFF
	if y > 163 and y < 171:
		flake.y = _s16(250 - (coord_offset.y + center.y))
		_restart_snowflake_fall(flake)
	elif y > 242 and y < 250:
		flake.y = 163
		_restart_snowflake_fall(flake)
		flake.invisible = true
		flake.callback = Callback.SNOW_WAIT
	flake.data[5] = _s16(flake.data[5] + 1)
	if flake.data[5] == flake.data[6]:
		_init_snowflake(flake)
		flake.y = 250
		flake.invisible = true
		flake.callback = Callback.SNOW_WAIT


static func _restart_snowflake_fall(flake: WeatherSprite) -> void:
	flake.data[0] = _s16(flake.y * 128)
	flake.data[5] = 0
	flake.data[6] = 220


func _fog_horizontal_init_vars(weather: Gen3FieldWeather) -> void:
	if not fog_horizontal_created:
		fog_horizontal_counter = 0
		fog_horizontal_offset = 0
		fog_horizontal_pos_x = 0
		weather.set_blend_coeffs(0, 16)


## The scroll `FogHorizontal_Main` and `_Finish` both open with: a pixel left every four frames.
func _scroll_fog_horizontal() -> void:
	fog_horizontal_pos_x = (coord_offset.x - fog_horizontal_offset) & 0xFF
	fog_horizontal_counter = (fog_horizontal_counter + 1) & 0xFFFF
	if fog_horizontal_counter > 3:
		fog_horizontal_counter = 0
		fog_horizontal_offset = (fog_horizontal_offset + 1) & 0xFFFF


## Underwater and the bubbles share it but blend thinner.
func _fog_horizontal_main(weather: Gen3FieldWeather) -> void:
	_scroll_fog_horizontal()
	match weather.init_step:
		0:
			if not fog_horizontal_created:
				_create_fog_horizontal()
			if weather.current == Gen3FieldWeather.Weather.FOG_HORIZONTAL:
				weather.set_target_blend_coeffs(12, 8, 3)
			else:
				weather.set_target_blend_coeffs(4, 16, 0)
			weather.init_step += 1
		1:
			if weather.update_blend():
				weather.gfx_loaded = true
				weather.init_step += 1


## `CreateFogHorizontalSprites` places each sprite on its column and row.
func _create_fog_horizontal() -> void:
	fog_horizontal_sprites = _create_tiled("fog_horizontal", 2, Callback.FOG_HORIZONTAL, 0xFF)
	for sprite: WeatherSprite in fog_horizontal_sprites:
		if sprite != null:
			sprite.x = sprite.data[0] * 64 + 32
			sprite.y = sprite.data[1] * 64 + 32
			sprite.data[1] = 0
	fog_horizontal_created = true


func _fog_horizontal_finish(weather: Gen3FieldWeather) -> bool:
	_scroll_fog_horizontal()
	match weather.finish_step:
		0:
			weather.set_target_blend_coeffs(0, 16, 3)
		1:
			if not weather.update_blend():
				return true
		2:
			_destroy(fog_horizontal_sprites)
			fog_horizontal_created = false
		_:
			return false
	weather.finish_step += 1
	return true


## `CreateSpriteAtEnd` for twenty 64x64 sprites at their rows' heights, column and row in `data[0]`/`data[1]`.
func _create_tiled(sheet: String, priority: int, callback: int, subpriority: int,
		anims: Array = STILL_ANIMS) -> Array:
	var out: Array = []
	for index: int in NUM_TILED_SPRITES:
		var sprite: WeatherSprite = _create(sheet, Vector2i(64, 64), priority, callback,
			Vector2i(0, index / COLUMNS * 64), subpriority, anims)
		if sprite != null:
			sprite.data[0] = index % COLUMNS
			sprite.data[1] = index / COLUMNS
		out.append(sprite)
	return out


func _ash_init_vars(weather: Gen3FieldWeather) -> void:
	if not ash_created:
		weather.set_blend_coeffs(0, 16)
		# BLDALPHA_BLEND(64, 63): neither is a valid coefficient.
		weather.bldalpha = 63 << 8 | 64


func _ash_main(weather: Gen3FieldWeather) -> void:
	ash_base_x = coord_offset.x & 0x1FF
	while ash_base_x >= 240:
		ash_base_x -= 240
	match weather.init_step:
		0:
			weather.init_step += 1
		1:
			if not ash_created:
				_create_ash()
			weather.set_target_blend_coeffs(16, 0, 1)
			weather.init_step += 1
		2:
			if weather.update_blend():
				weather.gfx_loaded = true
				weather.init_step += 1
		_:
			weather.update_blend()


func _ash_finish(weather: Gen3FieldWeather) -> bool:
	match weather.finish_step:
		0:
			weather.set_target_blend_coeffs(0, 16, 1)
		1:
			if not weather.update_blend():
				return true
			_destroy(ash_sprites)
			ash_created = false
		2:
			weather.bldalpha = 0
			weather.finish_step += 1
			return false
		_:
			return false
	weather.finish_step += 1
	return true


## `CreateAshSprites`: column and row in `data[2]` and `data[3]`, the row's height in `data[0]`.
func _create_ash() -> void:
	ash_sprites = _create_tiled("ash", 1, Callback.ASH, 0x4E, ASH_ANIMS)
	for sprite: WeatherSprite in ash_sprites:
		if sprite != null:
			sprite.y = 0
			sprite.data[2] = sprite.data[0]
			sprite.data[3] = sprite.data[1]
			sprite.data[1] = 0
			sprite.data[0] = sprite.data[3] * 64 + 32
	ash_created = true


## `UpdateAshSprite`: down a pixel every six frames, laid across from the screen's offset.
func _update_ash(sprite: WeatherSprite) -> void:
	sprite.data[1] = _s16(sprite.data[1] + 1)
	if sprite.data[1] > 5:
		sprite.data[1] = 0
		sprite.data[0] = _s16(sprite.data[0] + 1)
	sprite.y = _s16(coord_offset.y + sprite.data[0])
	_tile_column(sprite, ash_base_x)


func _fog_diagonal_init_vars(weather: Gen3FieldWeather) -> void:
	fog_horizontal_counter = 0
	fog_horizontal_offset = 1
	if not fog_diagonal_created:
		fog_diagonal_x_counter = 0
		fog_diagonal_y_counter = 0
		fog_diagonal_x_offset = 0
		fog_diagonal_y_offset = 0
		fog_diagonal_base_x = 0
		fog_diagonal_pos_y = 0
		weather.set_blend_coeffs(0, 16)


## `UpdateFogDiagonalMovement`: a pixel left every three frames and down every five.
func _move_fog_diagonal() -> void:
	fog_diagonal_x_counter = (fog_diagonal_x_counter + 1) & 0xFFFF
	if fog_diagonal_x_counter > 2:
		fog_diagonal_x_offset = (fog_diagonal_x_offset + 1) & 0xFFFF
		fog_diagonal_x_counter = 0
	fog_diagonal_y_counter = (fog_diagonal_y_counter + 1) & 0xFFFF
	if fog_diagonal_y_counter > 4:
		fog_diagonal_y_offset = (fog_diagonal_y_offset + 1) & 0xFFFF
		fog_diagonal_y_counter = 0
	fog_diagonal_base_x = (coord_offset.x - fog_diagonal_x_offset) & 0xFF
	fog_diagonal_pos_y = (coord_offset.y + fog_diagonal_y_offset) & 0xFFFF


func _fog_diagonal_main(weather: Gen3FieldWeather) -> void:
	_move_fog_diagonal()
	match weather.init_step:
		0:
			if not fog_diagonal_created:
				fog_diagonal_sprites = _create_tiled("fog_diagonal", 2, Callback.FOG_DIAGONAL, 0xFF)
				fog_diagonal_created = true
			weather.init_step += 1
		1:
			weather.set_target_blend_coeffs(12, 8, 8)
			weather.init_step += 1
		2:
			if weather.update_blend():
				weather.gfx_loaded = true
				weather.init_step += 1


func _fog_diagonal_finish(weather: Gen3FieldWeather) -> bool:
	_move_fog_diagonal()
	match weather.finish_step:
		0:
			weather.set_target_blend_coeffs(0, 16, 1)
		1:
			if not weather.update_blend():
				return true
		2:
			_destroy(fog_diagonal_sprites)
			fog_diagonal_created = false
		_:
			return false
	weather.finish_step += 1
	return true


func _sandstorm_init_vars(weather: Gen3FieldWeather) -> void:
	if not sandstorm_created:
		sandstorm_x_offset = 0
		sandstorm_y_offset = 0
		sandstorm_wave_index = 8
		sandstorm_wave_counter = 0
		weather.set_blend_coeffs(0, 16)


## `UpdateSandstormMovement` then `UpdateSandstormWaveIndex`: the wind's sine pushes left four times as hard as
## up, its angle a step every six frames.
func _blow_sandstorm() -> void:
	var sine: int = Gen3ObjectEvents.SINE[sandstorm_wave_index]
	sandstorm_x_offset = (sandstorm_x_offset - sine * 4) & 0xFFFFFFFF
	sandstorm_y_offset = (sandstorm_y_offset - sine) & 0xFFFFFFFF
	sandstorm_base_x = (coord_offset.x + (sandstorm_x_offset >> 8)) & 0xFF
	sandstorm_pos_y = (coord_offset.y + (sandstorm_y_offset >> 8)) & 0xFFFF
	var counter: int = sandstorm_wave_counter
	sandstorm_wave_counter = (counter + 1) & 0xFFFF
	if counter > 4:
		sandstorm_wave_index = (sandstorm_wave_index + 1) & 0xFFFF
		sandstorm_wave_counter = 0


func _sandstorm_main(weather: Gen3FieldWeather) -> void:
	_blow_sandstorm()
	if sandstorm_wave_index >= 0x80 - MIN_SANDSTORM_WAVE_INDEX:
		sandstorm_wave_index = MIN_SANDSTORM_WAVE_INDEX
	match weather.init_step:
		0:
			_create_sandstorm(weather)
			weather.init_step += 1
		1:
			weather.set_target_blend_coeffs(16, 0, 0)
			weather.init_step += 1
		2:
			if weather.update_blend():
				weather.gfx_loaded = true
				weather.init_step += 1


func _sandstorm_finish(weather: Gen3FieldWeather) -> bool:
	_blow_sandstorm()
	match weather.finish_step:
		0:
			weather.set_target_blend_coeffs(0, 16, 0)
		1:
			if not weather.update_blend():
				return true
		2:
			if sandstorm_created:
				_destroy(sandstorm_sprites)
				sandstorm_created = false
			if swirls_created:
				_destroy(swirl_sprites)
				swirls_created = false
		_:
			return false
	weather.finish_step += 1
	return true


## `CreateSandstormSprites` and `CreateSwirlSandstormSprites`: the swirls rise from under the screen, each after
## its own delay, on the sheet's 32x32 frame.
func _create_sandstorm(weather: Gen3FieldWeather) -> void:
	if not sandstorm_created:
		weather.load_sprite_palette(sheets.get("sandstorm_palette", PackedByteArray()))
		sandstorm_sprites = _create_tiled("sandstorm", 1, Callback.SANDSTORM, 1, SANDSTORM_ANIMS)
		sandstorm_created = true
	if swirls_created:
		return
	swirl_sprites = []
	for index: int in NUM_SWIRL_SPRITES:
		var swirl: WeatherSprite = _create("sandstorm", Vector2i(32, 32), 1, Callback.SWIRL_WAIT,
			Vector2i(index * 48 + 24, 208), 1, SANDSTORM_ANIMS)
		if swirl != null:
			swirl.data[1] = index * 51
			swirl.data[0] = 8
			swirl.data[4] = 0x6730
			swirl.data[3] = SWIRL_ENTRANCE_DELAYS[index]
			swirl.anim.start(1)
		swirl_sprites.append(swirl)
		swirls_created = true


## `UpdateSandstormSwirlSprite`: up a pixel a frame round a widening circle, back under the screen past the top.
func _update_swirl(swirl: WeatherSprite) -> void:
	swirl.y = _s16(swirl.y - 1)
	if swirl.y < -48:
		swirl.y = 160 + 48
		swirl.data[0] = 4
	swirl.x2 = _s16(swirl.data[0] * Gen3ObjectEvents.SINE[swirl.data[1]] >> 8)
	swirl.y2 = _s16(swirl.data[0] * Gen3ObjectEvents.SINE[swirl.data[1] + 0x40] >> 8)
	swirl.data[1] = (swirl.data[1] + 10) & 0xFF
	swirl.data[2] = _s16(swirl.data[2] + 1)
	if swirl.data[2] > 8:
		swirl.data[2] = 0
		swirl.data[0] = _s16(swirl.data[0] + 1)


## `Bubbles_Main`: the horizontal fog, and a bubble from the next start every so many frames.
func _bubbles_main(weather: Gen3FieldWeather) -> void:
	_fog_horizontal_main(weather)
	bubble_delay_counter = (bubble_delay_counter + 1) & 0xFFFF
	if bubble_delay_counter <= BUBBLE_START_DELAYS[bubble_delay_index]:
		return
	bubble_delay_counter = 0
	bubble_delay_index = (bubble_delay_index + 1) % BUBBLE_START_DELAYS.size()
	var start: Vector2i = BUBBLE_START_COORDS[bubble_coords_index]
	var bubble: WeatherSprite = _create("bubble", Vector2i(8, 8), 1, Callback.BUBBLE,
		Vector2i(start.x, _s16(start.y - coord_offset.y)), 0, BUBBLE_ANIMS)
	if bubble != null:
		bubble.coord_offset = true
		bubbles.append(bubble)
		bubble_count = (bubble_count + 1) & 0xFFFF
	bubble_coords_index = (bubble_coords_index + 1) % BUBBLE_START_COORDS.size()


## Emerald frees the bubbles only once one was made, and only it forgets the count.
func _bubbles_finish(weather: Gen3FieldWeather) -> bool:
	if _fog_horizontal_finish(weather):
		return true
	if not _emerald or bubble_count != 0:
		_destroy(bubbles)
		if _emerald:
			bubble_count = 0
	return false


## `UpdateBubbleSprite`: a sway counted twice a frame, three pixels up, gone after 120 frames.
func _update_bubble(bubble: WeatherSprite) -> void:
	bubble.data[0] = _s16(bubble.data[0] + 2)
	if bubble.data[0] > 8:
		bubble.data[0] = 0
		if bubble.data[1] == 0:
			bubble.x2 = _s16(bubble.x2 + 1)
			if bubble.x2 > 4:
				bubble.data[1] = 1
		else:
			bubble.x2 = _s16(bubble.x2 - 1)
			if bubble.x2 <= 0:
				bubble.data[1] = 0
	bubble.y = _s16(bubble.y - 3)
	bubble.data[2] = _s16(bubble.data[2] + 1)
	if bubble.data[2] >= 120:
		bubbles.erase(bubble)
		pool.erase(bubble.slot)


func _random() -> Gen3Random:
	return events.random


static func _s16(value: int) -> int:
	return ((value & 0xFFFF) ^ 0x8000) - 0x8000


## OAM entries by sprite slot for [Gen3ObjectSprites]; a sprite with `coordOffsetEnabled` adds the last
## [method animate]'s offset. PALTAG_WEATHER is OBJ palette [param contrast] and PALTAG_WEATHER_2 [param picture].
func oam_entries(contrast: int, picture: int) -> Dictionary:
	var entries: Dictionary = {}
	for sprite: WeatherSprite in all_sprites():
		var at := Vector2i(sprite.x + sprite.x2, sprite.y + sprite.y2) - sprite.size / 2 \
			+ (coord_offset if sprite.coord_offset else Vector2i.ZERO)
		var bytes: int = sprite.size.x * sprite.size.y / 2
		var tiles: PackedByteArray = (sheets.get(sprite.sheet, PackedByteArray()) as PackedByteArray).slice(
			sprite.anim.image * GbaTiles.TILE_BYTES, sprite.anim.image * GbaTiles.TILE_BYTES + bytes)
		entries[sprite.slot] = {"y": at.y & 0xFF, "key": sprite.priority << 8 | sprite.subpriority,
			"invisible": sprite.invisible, "part": {"x": at.x & 0x1FF, "y": at.y & 0xFF, "flip": Vector2i.ZERO,
				"priority": sprite.priority, "palette": picture if sprite.second_palette else contrast,
				"size": sprite.size, "tiles": tiles, "blend": sprite.blend}}
	return entries
