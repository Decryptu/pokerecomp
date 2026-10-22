class_name Gen3FieldWeather
extends RefCounted

## `field_weather.c`'s palette half over a [Gen3Palette]: `BuildColorMaps`' two map sets, the weather task
## (`Task_WeatherInit`, `Task_WeatherMain`), the four palette states, `FadeScreen`, the drought cycle and the
## BLDALPHA coefficients; the saved weather and its translation (`field_weather_effect.c`); and Emerald's
## alternating Groudon/Kyogre weather. Each weather's colour-map target is modeled, and the rain weathers through
## [Gen3WeatherSprites]; the other sprite weathers' sprites and blend ramps are not, so they finish at once.

enum Weather {
	NONE, SUNNY_CLOUDS, SUNNY, RAIN, SNOW, RAIN_THUNDERSTORM, FOG_HORIZONTAL, VOLCANIC_ASH, SANDSTORM,
	FOG_DIAGONAL, UNDERWATER, SHADE, DROUGHT, DOWNPOUR, UNDERWATER_BUBBLES, ABNORMAL,
	ROUTE119_CYCLE = 20, ROUTE123_CYCLE = 21,
}
enum PalState { CHANGING_WEATHER, SCREEN_FADING_IN, SCREEN_FADING_OUT, IDLE }
enum ColorMap { NONE, DARK_CONTRAST, CONTRAST }
enum Fade { FROM_BLACK, TO_BLACK, FROM_WHITE, TO_WHITE }
enum Task { NONE, INIT, MAIN }

const COLOR_MAPS: int = 19
const DROUGHT_TABLES: int = 6
const DROUGHT_BYTES: int = 0x2000
const RGB_WHITEALPHA: int = 0xFFFF
const FOG_COLOR: int = 28 | 31 << 5 | 28 << 10
## Ruby and Sapphire leave this colour alone in OBJ palettes 0 and 12-15: RGB(31, 12, 11).
const RUBY_KEPT_COLOR: int = 31 | 12 << 5 | 11 << 10
const RUBY_KEPT_PALETTES: Array[int] = [16, 28, 29, 30, 31]
## `AllocSpritePalette(PALTAG_WEATHER)` right after `InitObjectEventPalettes` reserves the twelve object slots.
const WEATHER_SPRITE_SLOT: int = 12
const GAME_STAT_GOT_RAINED_ON: int = 40
const ABNORMAL_DELAY: int = 600
const CYCLE_LENGTH: int = 4
const ROUTE119_CYCLE_WEATHERS: Array[int] = [Weather.SUNNY, Weather.RAIN, Weather.RAIN_THUNDERSTORM, Weather.RAIN]
const ROUTE123_CYCLE_WEATHERS: Array[int] = [Weather.SUNNY, Weather.SUNNY, Weather.RAIN, Weather.SUNNY]
## The weathers whose InitVars aim at colour map 3 with a 20-frame step; the rest aim at 0.
const DARK_WEATHERS: Array[int] = [Weather.RAIN, Weather.SNOW, Weather.RAIN_THUNDERSTORM, Weather.SHADE,
	Weather.DOWNPOUR]
## `FadeScreen` and the fade-in keep their own palettes under these.
const FADE_WEATHERS: Array[int] = [Weather.RAIN, Weather.RAIN_THUNDERSTORM, Weather.DOWNPOUR, Weather.SNOW,
	Weather.FOG_HORIZONTAL, Weather.SHADE, Weather.DROUGHT]
const SPRITE_COLOR_MAPS: Array[int] = [
	ColorMap.CONTRAST, ColorMap.DARK_CONTRAST, ColorMap.CONTRAST, ColorMap.CONTRAST, ColorMap.CONTRAST,
	ColorMap.CONTRAST, ColorMap.DARK_CONTRAST, ColorMap.DARK_CONTRAST, ColorMap.DARK_CONTRAST,
	ColorMap.DARK_CONTRAST, ColorMap.CONTRAST, ColorMap.DARK_CONTRAST, ColorMap.DARK_CONTRAST,
	ColorMap.DARK_CONTRAST, ColorMap.DARK_CONTRAST, ColorMap.DARK_CONTRAST,
]

var palette: Gen3Palette
var events: Gen3EventData
var sprites: Gen3WeatherSprites
var _ruby: bool = false
var _frlg: bool = false
var _emerald: bool = false
var _sprite_palette := PackedByteArray()
## Emerald's colours as the ROM holds them; Hoenn's deltas, summed into [member _drought] a table a call.
var _drought_source: Array = []
var _drought: Array[PackedInt32Array] = []
var base_types := PackedByteArray()
var types := PackedByteArray()
var dark_contrast_maps: Array[PackedByteArray] = []
var contrast_maps: Array[PackedByteArray] = []

var task: int = Task.NONE
## FireRed and LeafGreen's `Drought_InitAll` never returns: their table load is dummied out and never finishes.
var locked: bool = false
var current: int = Weather.NONE
var next: int = Weather.NONE
var color_map_index: int = 0
var target_index: int = 0
var step_delay: int = 0
var step_counter: int = 0
var state: int = PalState.IDLE
var ready_for_init: bool = false
var change_complete: bool = true
var finish_step: int = 0
var init_step: int = 0
var gfx_loaded: bool = false
var fade_dest_color: int = 0
var fade_screen_counter: int = 0
var fade_in_first_frame: bool = false
var fade_in_timer: int = 0
var lightened_fog: Array[int] = []
var contrast_slot: int = WEATHER_SPRITE_SLOT
var picture_slot: int = WEATHER_SPRITE_SLOT
var blend_eva: int = 0
var blend_evb: int = 0
var target_eva: int = 0
var target_evb: int = 0
var blend_delay: int = 0
var blend_frame_counter: int = 0
var blend_update_counter: int = 0
## REG_BLDALPHA as the coefficients last wrote it.
var bldalpha: int = 0
var drought_stage: int = 0
var drought_last_stage: int = 0
var drought_timer: int = 0
var drought_state: int = 0
var drought_frame_delay: int = 5
var drought_load_index: int = 0
## Emerald's `Task_DoAbnormalWeather`: alive, its two weathers, state and delay; `sCurrentAbnormalWeather`.
var abnormal_task: bool = false
var abnormal_weathers: Array[int] = [Weather.DROUGHT, Weather.DOWNPOUR]
var abnormal_state: int = 0
var abnormal_delay: int = 0
var current_abnormal: int = Weather.DOWNPOUR


func _init(game: GameData, palettes: Gen3Palette, event_data: Gen3EventData) -> void:
	palette = palettes
	events = event_data
	_ruby = game.id in [RomRegistry.RUBY, RomRegistry.SAPPHIRE]
	_frlg = game.id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN]
	_emerald = game.id == RomRegistry.EMERALD
	sprites = Gen3WeatherSprites.new(game)
	var weather: Dictionary = game.world_weather()
	_sprite_palette = weather.get("palette", PackedByteArray())
	_drought_source = weather.get("drought", [])
	if weather.get("summed", false):
		for table: PackedByteArray in _drought_source:
			_drought.append(_words(table))
	var background: int = 13 if _frlg else 14
	for index: int in 16:
		base_types.append(ColorMap.DARK_CONTRAST if index < background else ColorMap.NONE)
	for type: int in SPRITE_COLOR_MAPS:
		base_types.append(type)
	types = base_types.duplicate()


static func _words(bytes: PackedByteArray) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(bytes.size() / 2)
	for index: int in out.size():
		out[index] = bytes.decode_u16(index * 2)
	return out


## `StartWeather`, unless the main task already runs. Its palette goes into [member Gen3Palette.unfaded] only.
func start() -> void:
	if task == Task.MAIN:
		return
	var at: int = (Gen3Palette.OBJ_OFFSET + WEATHER_SPRITE_SLOT * 16) * 2
	for index: int in _sprite_palette.size():
		palette.unfaded[at + index] = _sprite_palette[index]
	build_color_maps()
	contrast_slot = WEATHER_SPRITE_SLOT
	picture_slot = WEATHER_SPRITE_SLOT if _frlg else WEATHER_SPRITE_SLOT + 1
	sprites.reset()
	lightened_fog.clear()
	set_blend_coeffs(16, 0)
	current = Weather.NONE
	state = PalState.IDLE
	ready_for_init = false
	change_complete = true
	task = Task.INIT


## `BuildColorMaps`: three darker maps then sixteen brighter ones per colour value, the darkened set losing a
## sixteenth a map and shadows below 12 brightening at half the rate.
func build_color_maps() -> void:
	types = base_types.duplicate()
	dark_contrast_maps = _color_maps(true)
	contrast_maps = _color_maps(false)


static func _color_maps(darkened: bool) -> Array[PackedByteArray]:
	var flat := PackedByteArray()
	flat.resize(COLOR_MAPS * 32)
	for value: int in 32:
		var brightness: int = value << 8
		var delta: int = (value << 8) / 16 if darkened else 0
		for index: int in 3:
			brightness -= delta
			flat[index * 32 + value] = brightness >> 8
		var base: int = brightness
		delta = (0x1F00 - brightness) / (COLOR_MAPS - 3)
		for index: int in range(3, COLOR_MAPS):
			brightness += delta
			if value < 12 and brightness - base > 0:
				brightness -= (brightness - base) / 2
			flat[index * 32 + value] = mini(brightness >> 8, 31)
	var maps: Array[PackedByteArray] = []
	for index: int in COLOR_MAPS:
		maps.append(flat.slice(index * 32, index * 32 + 32))
	return maps


func set_next(weather: int) -> void:
	if next != weather and current == weather:
		_init_vars(weather)
	change_complete = false
	next = weather
	finish_step = 0


func set_current_and_next(weather: int) -> void:
	current = weather
	next = weather


func set_current_and_next_no_delay(weather: int) -> void:
	set_current_and_next(weather)
	ready_for_init = true


## One `RunTasks` pass of the weather's tasks: Emerald's alternating weather (priority 0) and then the weather
## task (priority 80).
func run_tasks() -> void:
	if locked:
		return
	if abnormal_task:
		_run_abnormal()
	if task == Task.INIT:
		if ready_for_init:
			_init_all(current)
			task = Task.MAIN
	elif task == Task.MAIN:
		_run_main()


## `Task_WeatherMain`. Emerald holds a finished weather while the screen fades out.
func _run_main() -> void:
	if current != next:
		if not _finish(current) and not (_emerald and state == PalState.SCREEN_FADING_OUT):
			_init_vars(next)
			step_counter = 0
			state = PalState.CHANGING_WEATHER
			current = next
			change_complete = true
	else:
		_main(current)
	match state:
		PalState.CHANGING_WEATHER:
			_update_color_map()
		PalState.SCREEN_FADING_IN:
			_fade_in_with_weather()


## Each weather's InitVars, as far as the palettes and the rain go.
func _init_vars(weather: int) -> void:
	init_step = 0
	gfx_loaded = false
	target_index = 3 if weather in DARK_WEATHERS else 0
	step_delay = 0 if weather in [Weather.NONE, Weather.DROUGHT] else 20
	if Gen3WeatherSprites.is_rain(weather):
		sprites.init_vars(weather)


func _init_all(weather: int) -> void:
	_init_vars(weather)
	if weather == Weather.DROUGHT:
		while not gfx_loaded and not locked:
			_drought_main()
			locked = _frlg and init_step == 2
	elif Gen3WeatherSprites.is_rain(weather):
		while not gfx_loaded:
			sprites.main(self)


func _main(weather: int) -> void:
	if weather == Weather.DROUGHT:
		_drought_main()
	elif Gen3WeatherSprites.is_rain(weather):
		sprites.main(self)


## The rain weathers' Finish holds the change until their raindrops are gone; every other modeled weather's
## returns FALSE at once.
func _finish(weather: int) -> bool:
	return sprites.finish(self) if Gen3WeatherSprites.is_rain(weather) else false


## `UpdateWeatherColorMap`: one map a step toward the target, every [member step_delay] frames.
func _update_color_map() -> void:
	if color_map_index == target_index:
		state = PalState.IDLE
		return
	step_counter = (step_counter + 1) & 0xFF
	if step_counter >= step_delay:
		step_counter = 0
		color_map_index += 1 if color_map_index < target_index else -1
		apply_color_map(0, 32, color_map_index)


## `FadeInScreenWithWeather`.
func _fade_in_with_weather() -> void:
	fade_in_timer = (fade_in_timer + 1) & 0xFF
	if fade_in_timer > 1:
		fade_in_first_frame = false
	if current in [Weather.RAIN, Weather.RAIN_THUNDERSTORM, Weather.DOWNPOUR, Weather.SNOW, Weather.SHADE]:
		if not _fade_in_step(3):
			_fade_in_done(3)
	elif current == Weather.DROUGHT:
		if not _fade_in_step(-6):
			_fade_in_done(-6)
	elif current == Weather.FOG_HORIZONTAL:
		if fade_screen_counter != 16:
			fade_screen_counter += 1
			_apply_fog_blend(16 - fade_screen_counter, fade_dest_color)
		else:
			_fade_in_done(0)
	elif not palette.fade_active:
		_fade_in_done(target_index)


func _fade_in_done(index: int) -> void:
	color_map_index = index
	state = PalState.IDLE


## `FadeInScreen_RainShowShade` and `FadeInScreen_Drought`: false once the map is reached.
func _fade_in_step(index: int) -> bool:
	if fade_screen_counter == 16:
		return false
	fade_screen_counter += 1
	if fade_screen_counter >= 16:
		apply_color_map(0, 32, index)
		fade_screen_counter = 16
		return false
	if index < 0:
		_apply_drought_with_blend(index, 16 - fade_screen_counter, fade_dest_color)
	else:
		_apply_color_map_with_blend(0, 32, index, 16 - fade_screen_counter, fade_dest_color)
	return true


## `ApplyColorMap`: a positive index through the contrast maps, a negative one through the drought tables
## (which FireRed and LeafGreen leave out, writing nothing), zero a plain copy.
func apply_color_map(first_slot: int, count: int, index: int) -> void:
	if index == 0:
		palette.copy_unfaded(first_slot * 16, count * 16)
		return
	if index < 0 and (_frlg or _drought.size() < -index):
		return
	for slot: int in range(first_slot, first_slot + count):
		if types[slot] == ColorMap.NONE:
			palette.copy_unfaded(slot * 16, 16)
			continue
		var map: PackedByteArray = PackedByteArray() if index < 0 else _contrast_map(slot, index - 1)
		for color: int in range(slot * 16, slot * 16 + 16):
			var from: int = palette.unfaded_color(color)
			if _ruby and from == RUBY_KEPT_COLOR and slot in RUBY_KEPT_PALETTES:
				continue
			var to: int = _drought[-index - 1][drought_index(from)] if index < 0 \
				else map[from & 31] | map[(from >> 5) & 31] << 5 | map[(from >> 10) & 31] << 10
			palette.faded.encode_u16(color * 2, to)


func _contrast_map(slot: int, index: int) -> PackedByteArray:
	if types[slot] == ColorMap.CONTRAST or slot - 16 == contrast_slot:
		return contrast_maps[index]
	return dark_contrast_maps[index]


## `DROUGHT_COLOR_INDEX`: four bits a channel.
static func drought_index(color: int) -> int:
	return ((color >> 1) & 0xF) | ((color >> 2) & 0xF0) | ((color >> 3) & 0xF00)


## `ApplyColorMapWithBlend`. Unlike [method apply_color_map] it never gives the weather's sprite slot the
## contrast map.
func _apply_color_map_with_blend(first_slot: int, count: int, index: int, coeff: int, color: int) -> void:
	for slot: int in range(first_slot, first_slot + count):
		if types[slot] == ColorMap.NONE:
			palette.blend(slot * 16, 16, coeff, color)
			continue
		var map: PackedByteArray = dark_contrast_maps[index - 1] if types[slot] == ColorMap.DARK_CONTRAST \
			else contrast_maps[index - 1]
		for at: int in range(slot * 16, slot * 16 + 16):
			var from: int = palette.unfaded_color(at)
			var mapped: int = map[from & 31] | map[(from >> 5) & 31] << 5 | map[(from >> 10) & 31] << 10
			palette.faded.encode_u16(at * 2, _blend_channels(mapped, coeff, color))


## The weather's own per-channel blend: the same floor as `BlendPalette`, on u8 channels.
static func _blend_channels(from: int, coeff: int, color: int) -> int:
	var out: int = 0
	for shift: int in [0, 5, 10]:
		var channel: int = (from >> shift) & 31
		out |= ((channel + ((((color >> shift) & 31) - channel) * coeff >> 4)) & 0xFF) << shift
	return out & 0xFFFF


## `ApplyDroughtColorMapWithBlend`. FireRed and LeafGreen blend the unfaded colour with no table.
func _apply_drought_with_blend(index: int, coeff: int, color: int) -> void:
	if not _frlg and _drought.size() < -index:
		return
	for slot: int in 32:
		if types[slot] == ColorMap.NONE:
			palette.blend(slot * 16, 16, coeff, color)
			continue
		for at: int in range(slot * 16, slot * 16 + 16):
			var from: int = palette.unfaded_color(at)
			if not _frlg:
				from = _drought[-index - 1][drought_index(from)]
			palette.faded.encode_u16(at * 2, _blend_channels(from, coeff, color))


## `ApplyFogBlend`: everything toward [param color], the marked sprite palettes lightened first.
func _apply_fog_blend(coeff: int, color: int) -> void:
	palette.blend(0, 256, coeff, color)
	for slot: int in range(16, 32):
		if not slot in lightened_fog:
			palette.blend(slot * 16, 16, coeff, color)
			continue
		for at: int in range(slot * 16, slot * 16 + 16):
			var from: int = palette.unfaded_color(at)
			var lightened: int = 0
			for pair: Array in [[0, 28], [5, 31], [10, 28]]:
				var channel: int = (from >> int(pair[0])) & 31
				lightened |= ((channel + ((int(pair[1]) - channel) * 3 >> 2)) & 31) << int(pair[0])
			palette.faded.encode_u16(at * 2, _blend_channels(lightened, coeff, color))


## `ApplyWeatherColorMapIfIdle`.
func apply_if_idle(index: int) -> void:
	if state == PalState.IDLE:
		apply_color_map(0, 32, index)
		color_map_index = index


## `ApplyWeatherColorMapIfIdle_Gradual`; its u8 arguments land in s8 fields.
func apply_if_idle_gradual(index: int, target: int, delay: int) -> void:
	if state == PalState.IDLE:
		state = PalState.CHANGING_WEATHER
		color_map_index = _s8(index)
		target_index = _s8(target)
		step_counter = 0
		step_delay = delay & 0xFF
		apply_if_idle(color_map_index)


static func _s8(value: int) -> int:
	return ((value & 0xFF) ^ 0x80) - 0x80


## `ApplyWeatherColorMapToPal`.
func apply_to_palette(slot: int) -> void:
	apply_color_map(slot, 1, color_map_index)


## `FadeScreen`. The weathers that keep their own palettes fade in through [method run_tasks] instead of a
## palette fade.
func fade_screen(mode: int, delay: int) -> void:
	if mode < Fade.FROM_BLACK or mode > Fade.TO_WHITE:
		return
	var color: int = RGB_WHITEALPHA if mode in [Fade.FROM_WHITE, Fade.TO_WHITE] else 0
	var own: bool = current in FADE_WEATHERS
	if mode in [Fade.TO_BLACK, Fade.TO_WHITE]:
		if own:
			palette.unfaded = palette.faded.duplicate()
		palette.begin_fade(Gen3Palette.ALL, delay, 0, 16, color)
		state = PalState.SCREEN_FADING_OUT
		return
	fade_dest_color = color
	if own:
		fade_screen_counter = 0
	else:
		palette.begin_fade(Gen3Palette.ALL, delay, 16, 0, color)
	state = PalState.SCREEN_FADING_IN
	fade_in_first_frame = true
	fade_in_timer = 0
	set_blend_coeffs(blend_eva, blend_evb)
	ready_for_init = true


func is_not_fading_in() -> bool:
	return state != PalState.SCREEN_FADING_IN


## `UpdateSpritePaletteWithWeather` for OBJ palette [param slot], after something loaded it.
func update_sprite_palette(slot: int) -> void:
	var index: int = 16 + slot
	match state:
		PalState.SCREEN_FADING_IN:
			if fade_in_first_frame:
				if current == Weather.FOG_HORIZONTAL:
					_mark_fog_palette(index)
				for at: int in range(index * 16, index * 16 + 16):
					palette.faded.encode_u16(at * 2, fade_dest_color)
		PalState.SCREEN_FADING_OUT:
			for at: int in range(index * 32, index * 32 + 32):
				palette.unfaded[at] = palette.faded[at]
			palette.blend(index * 16, 16, palette.fade_y, palette.fade_color)
		_:
			if current != Weather.FOG_HORIZONTAL:
				apply_color_map(index, 1, color_map_index)
			else:
				palette.blend(index * 16, 16, 12, FOG_COLOR)


func _mark_fog_palette(index: int) -> void:
	if lightened_fog.size() < 6:
		lightened_fog.append(index)


## `LoadCustomWeatherSpritePalette`.
func load_sprite_palette(bytes: PackedByteArray) -> void:
	palette.load(bytes, Gen3Palette.OBJ_OFFSET + picture_slot * 16)
	update_sprite_palette(picture_slot)


## `PreservePaletteInWeather`: [param slot] (of 32) keeps its colours until [method reset_preserved].
func preserve_palette(slot: int) -> void:
	types = base_types.duplicate()
	types[slot] = ColorMap.NONE


func reset_preserved() -> void:
	types = base_types.duplicate()


func set_screen_fade_out() -> void:
	state = PalState.SCREEN_FADING_OUT


func set_pal_state_idle() -> void:
	state = PalState.IDLE


func set_blend_coeffs(eva: int, evb: int) -> void:
	blend_eva = eva
	blend_evb = evb
	target_eva = eva
	target_evb = evb
	bldalpha = eva | evb << 8


func set_target_blend_coeffs(eva: int, evb: int, delay: int) -> void:
	target_eva = eva
	target_evb = evb
	blend_delay = delay & 0xFF
	blend_frame_counter = 0
	blend_update_counter = 0


## `Weather_UpdateBlend`: EVA and EVB a step each on alternate updates; true once both arrive.
func update_blend() -> bool:
	if blend_eva == target_eva and blend_evb == target_evb:
		return true
	blend_frame_counter = (blend_frame_counter + 1) & 0xFF
	if blend_frame_counter > blend_delay:
		blend_frame_counter = 0
		blend_update_counter = (blend_update_counter + 1) & 0xFF
		if blend_update_counter & 1:
			blend_eva += signi(target_eva - blend_eva)
		else:
			blend_evb += signi(target_evb - blend_evb)
	bldalpha = blend_eva | blend_evb << 8
	return blend_eva == target_eva and blend_evb == target_evb


## `Drought_Main`: wait out a colour-map change, load the tables, then ramp to stage 6 and cycle.
func _drought_main() -> void:
	match init_step:
		0:
			if state != PalState.CHANGING_WEATHER:
				init_step += 1
		1:
			drought_load_index = 1
			init_step += 1
		2:
			if not _load_drought_tables():
				init_step += 1
		3:
			_drought_state_init()
			init_step += 1
		4:
			_drought_state_run()
			if drought_stage == 6:
				gfx_loaded = true
				init_step += 1
		_:
			_drought_state_run()


## `LoadDroughtWeatherPalettes`: Ruby and Sapphire sum one table a call (the first from RGB(1, 1, 1), each
## later one onto the one before) and Emerald's are in ROM, finishing on the first call. FireRed and LeafGreen's
## loader does nothing, so they never finish.
func _load_drought_tables() -> bool:
	if drought_load_index >= 32:
		return false
	if _frlg:
		return true
	if not _ruby or drought_load_index >= 7:
		drought_load_index = 32
		return false
	var index: int = drought_load_index - 1
	var table: PackedInt32Array = _words(_drought_source[index])
	if index == 0:
		table[0] = 1 | 1 << 5 | 1 << 10
		for at: int in range(1, table.size()):
			table[at] = (table[at] + table[at - 1]) & 0xFFFF
	else:
		for at: int in table.size():
			table[at] = (table[at] + _drought[index - 1][at]) & 0xFFFF
	if _drought.size() <= index:
		_drought.resize(index + 1)
	_drought[index] = table
	drought_load_index += 1
	if drought_load_index == 7:
		drought_load_index = 32
	return drought_load_index < 32


func _drought_state_init() -> void:
	drought_stage = 0
	drought_timer = 0
	drought_state = 0
	drought_last_stage = 0
	drought_frame_delay = 5


## `DroughtStateRun`: up a stage every six frames to 6, then follow the sine between 1 and 5; state 2 (ramping
## back down to 3) has no setter.
func _drought_state_run() -> void:
	match drought_state:
		0:
			drought_timer += 1
			if drought_timer > drought_frame_delay:
				drought_timer = 0
				apply_if_idle(-drought_stage - 1)
				drought_stage += 1
				if drought_stage > 5:
					drought_last_stage = drought_stage
					drought_state = 1
					drought_timer = 60
		1:
			drought_timer = (drought_timer + 3) & 0x7F
			drought_stage = ((Gen3ObjectEvents.SINE[drought_timer] - 1) >> 6) + 2
			if drought_stage != drought_last_stage:
				apply_if_idle(-drought_stage - 1)
			drought_last_stage = drought_stage
		2:
			drought_timer += 1
			if drought_timer > drought_frame_delay:
				drought_timer = 0
				drought_stage -= 1
				apply_if_idle(-drought_stage - 1)
				if drought_stage == 3:
					drought_state = 0


## `SetSavedWeather`: the translated weather into the save, counting a fresh rain.
func set_saved(weather: int) -> void:
	var old: int = events.weather
	events.weather = translate(weather)
	if events.weather != old and events.weather in [Weather.RAIN, Weather.RAIN_THUNDERSTORM]:
		events.increment_stat(GAME_STAT_GOT_RAINED_ON)


func set_saved_from_header(header: Dictionary) -> void:
	set_saved(int(header.get("weather", Weather.NONE)))


## `SetWeather`.
func set_weather(weather: int) -> void:
	set_saved(weather)
	set_next(events.weather)


## `TranslateWeatherNum`: the two route cycles by the day's stage; Emerald alone keeps `WEATHER_ABNORMAL`.
func translate(weather: int) -> int:
	weather &= 0xFF
	if weather == Weather.ROUTE119_CYCLE:
		return ROUTE119_CYCLE_WEATHERS[events.weather_cycle_stage]
	if weather == Weather.ROUTE123_CYCLE:
		return ROUTE123_CYCLE_WEATHERS[events.weather_cycle_stage]
	if weather <= Weather.UNDERWATER_BUBBLES or (weather == Weather.ABNORMAL and _emerald):
		return weather
	return Weather.NONE


## `UpdateWeatherPerDay`.
func update_per_day(increment: int) -> void:
	events.weather_cycle_stage = ((events.weather_cycle_stage + increment) & 0xFFFF) % CYCLE_LENGTH


## `DoCurrentWeather`: change to the saved weather.
func do_current() -> void:
	set_next(_saved_or_abnormal())


## `ResumePausedWeather`: start in the saved weather.
func resume_paused() -> void:
	set_current_and_next(_saved_or_abnormal())


## Emerald's abnormal weather starts or keeps its task and answers with the weather it is on; any other weather
## ends the task and resets it to start on the downpour.
func _saved_or_abnormal() -> int:
	var weather: int = events.weather
	if not _emerald:
		return weather
	if weather == Weather.ABNORMAL:
		if not abnormal_task:
			_create_abnormal_task()
		return current_abnormal
	abnormal_task = false
	current_abnormal = Weather.DOWNPOUR
	return weather


## `CreateAbnormalWeatherTask`: the other of the two weathers comes first, 600 frames on.
func _create_abnormal_task() -> void:
	abnormal_task = true
	abnormal_state = 0
	abnormal_delay = ABNORMAL_DELAY
	if current_abnormal == Weather.DROUGHT:
		abnormal_weathers = [Weather.DOWNPOUR, Weather.DROUGHT]
	else:
		current_abnormal = Weather.DOWNPOUR
		abnormal_weathers = [Weather.DROUGHT, Weather.DOWNPOUR]


## `Task_DoAbnormalWeather`: `tDelay-- <= 0` reads the delay before taking one off.
func _run_abnormal() -> void:
	var due: bool = abnormal_delay <= 0
	abnormal_delay -= 1
	if due:
		set_next(abnormal_weathers[abnormal_state])
		current_abnormal = abnormal_weathers[abnormal_state]
		abnormal_delay = ABNORMAL_DELAY
		abnormal_state ^= 1
