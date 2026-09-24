extends RefCounted

## A fresh game played on all six cartridges the way a player plays it: the
## intro to its save, then the world screen to a gym badge, every button
## through `press_button` and the driver clocked by the frame.

const CheckRun := preload("res://tools/lib/check_run.gd")

const SAVE_ROOT: String = "user://played_slots"
const PRESET_ROW: int = 1
const INTRO_FRAMES: int = 12000
## Ten seconds with nothing on the screen moving is a freeze, whatever it waits on.
const STALL_FRAMES: int = 600
const LEG_FRAMES: int = 12000
const LEG_BUDGETS: Dictionary = {
	"parcel": 60000, "parcel_to_lab": 36000, "mystery_egg": 60000, "egg_to_lab": 36000,
	"forest_to_north_gate": 36000, "mr_pokemon": 24000, "brock": 24000, "route_31_to_gate": 24000, "falkner": 24000,
	"route_32_to_union_cave": 36000, "union_cave_to_route_33": 36000, "rockets": 36000,
	"bugsy": 36000, "pewter_to_route_3": 36000, "route_3_to_route_4": 60000, "route_4_to_mt_moon": 36000,
	"mt_moon_1f_to_b1f": 24000, "super_nerd": 36000, "mt_moon_b1f_to_route_4": 24000, "misty": 36000,
}
## Slow enough that a box waiting for a press is not pressed twice.
const PRESS_EVERY: int = 8
## How long a thumb stays on A: the title reads `hJoyHeld` every other frame.
const HOLD_FRAMES: int = 4

const REDS_HOUSE_1F := Vector2i(0, 37)
const PALLET_TOWN := Vector2i(0, 0)
const OAKS_LAB := Vector2i(0, 40)
const ROUTE_1 := Vector2i(0, 12)
const VIRIDIAN_CITY := Vector2i(0, 1)
const VIRIDIAN_POKECENTER := Vector2i(0, 41)
const ROUTE_2 := Vector2i(0, 13)
const VIRIDIAN_FOREST_SOUTH_GATE := Vector2i(0, 50)
const VIRIDIAN_FOREST := Vector2i(0, 51)
const VIRIDIAN_FOREST_NORTH_GATE := Vector2i(0, 47)
const PEWTER_CITY := Vector2i(0, 2)
const PEWTER_GYM := Vector2i(0, 54)
const CERULEAN_CITY := Vector2i(0, 3)
const ROUTE_3 := Vector2i(0, 14)
const ROUTE_4 := Vector2i(0, 15)
const MT_MOON_1F := Vector2i(0, 59)
const MT_MOON_B1F := Vector2i(0, 60)
const MT_MOON_B2F := Vector2i(0, 61)
const CERULEAN_GYM := Vector2i(0, 65)
const MT_MOON_1F_LADDER := Vector2i(5, 5)
const MT_MOON_NERD_CELL := Vector2i(13, 8)
const MT_MOON_BELOW_DOME := Vector2i(12, 7)
const MT_MOON_B2F_EXIT_LADDER := Vector2i(5, 7)
const MT_MOON_B1F_EXIT := Vector2i(27, 3)
const MISTY := Vector2i(4, 2)

## `map_constants.asm` and `event_flags.asm`, shared by all three Generation 2 pins.
const ROUTE_29 := Vector2i(24, 3)
const NEW_BARK_TOWN := Vector2i(24, 4)
const ELMS_LAB := Vector2i(24, 5)
const PLAYERS_HOUSE_1F := Vector2i(24, 6)
const ROUTE_30 := Vector2i(26, 1)
const ROUTE_31 := Vector2i(26, 2)
const CHERRYGROVE_CITY := Vector2i(26, 3)
const MR_POKEMONS_HOUSE := Vector2i(26, 10)
const ROUTE_31_VIOLET_GATE := Vector2i(26, 11)
const VIOLET_CITY := Vector2i(10, 5)
const VIOLET_GYM := Vector2i(10, 7)
const VIOLET_POKECENTER := Vector2i(10, 10)
const ROUTE_32 := Vector2i(10, 1)
const KURTS_HOUSE := Vector2i(8, 4)
const AZALEA_GYM := Vector2i(8, 5)
const ROUTE_33 := Vector2i(8, 6)
const AZALEA_TOWN := Vector2i(8, 7)
## Crystal's dungeon group carries eight maps Gold's and Silver's does not.
const UNION_CAVE_1F: Dictionary = {true: Vector2i(3, 37), false: Vector2i(3, 29)}
const SLOWPOKE_WELL_B1F: Dictionary = {true: Vector2i(3, 40), false: Vector2i(3, 32)}

## `PalletTownDefaultScript` stops the player at `wYCoord == 1`, Yellow's at 0.
const PALLET_NORTH_PATH: Dictionary = {
	&"red": Vector2i(10, 1), &"blue": Vector2i(10, 1), &"yellow": Vector2i(10, 0),
}
const LAB_STARTER_BALLS: Dictionary = {
	&"red": Vector2i(6, 4), &"blue": Vector2i(6, 4), &"yellow": Vector2i(7, 4),
}
const LAB_BELOW_OAK := Vector2i(5, 3)
## Below the nurse's (3,1) behind her counter and Mom's (5,4).
const BELOW_NURSE := Vector2i(3, 3)
const BELOW_MOM := Vector2i(5, 5)
const BELOW_BROCK := Vector2i(4, 2)
## Elm's first ball is on (6,3), Elm on (5,2) and Falkner on (5,1).
const BELOW_ELMS_BALL := Vector2i(6, 4)
const BELOW_ELM := Vector2i(5, 3)
const BELOW_FALKNER := Vector2i(5, 2)
## Below Elm's aide, Kurt, Bugsy and the well Rocket, whose win warps to Kurt's.
const BELOW_AIDE := Vector2i(4, 4)
const BELOW_KURT := Vector2i(3, 3)
const BELOW_BUGSY := Vector2i(5, 8)
const BELOW_WELL_ROCKET := Vector2i(5, 3)
## `MeetCopScript`'s coord event, which walks the officer off (5,3).
const OFFICER_TRIGGER := Vector2i(4, 5)
const SCENE_ELMSLAB_NOOP: int = 2

const EVENT_GOT_STARTER: int = 34
const EVENT_BATTLED_RIVAL_IN_OAKS_LAB: int = 35
const EVENT_GOT_POKEDEX: int = 37
const EVENT_GOT_TM34: int = 118
const EVENT_BEAT_BROCK: int = 119
const OAKS_PARCEL: int = 0x46
const MYSTERY_EGG: int = 0x45
## Yellow's Mt. Moon run puts it right behind the 1F trainers.
const EVENT_GOT_DOME_FOSSIL: Dictionary = {
	&"red": 0x570 + 14, &"blue": 0x570 + 14, &"yellow": 0x570 + 8,
}
const EVENT_GOT_A_POKEMON_FROM_ELM: int = 26
const EVENT_GOT_MYSTERY_EGG_FROM_MR_POKEMON: int = 30
const EVENT_GAVE_MYSTERY_EGG_TO_ELM: int = 31
const EVENT_GOT_TOGEPI_EGG_FROM_ELMS_AIDE: int = 45
const EVENT_AZALEA_TOWN_SLOWPOKETAIL_ROCKET: int = 1786
const ENGINE_POKEGEAR: int = 4
## Grind levels, with the MANKEY (LOW KICK) Brock needs and the ODDISH for Misty;
## the save editor writes them, so the engine decides every fight.
const ROUTE_1_LEVEL: int = 8
const FOREST_LEVEL: int = 12
const BROCK_LEVEL: int = 20
const MANKEY_DEX: int = 56
const MT_MOON_LEVEL: int = 22
const MISTY_LEVEL: int = 28
const ODDISH_DEX: int = 43
const ROUTE_29_LEVEL: int = 8
const FALKNER_LEVEL: int = 16
const BUGSY_LEVEL: int = 22
## The run's own seed, so every wild roll and every fight replays the same.
const RUN_SEED: int = 7
const RETRIES: int = 3
const RETRY_LEVELS: int = 4
const UNREACHED: int = 1 << 30
const GIRL_LAST_LEG: String = "rival"

var _r: CheckRun
var _screen: Gen2WorldScreen = null
var _editor: Gen2SaveEditor = null
var _frames: int = 0
var _pressed_at: int = -PRESS_EVERY
var _last_signature: String = ""
var _still: int = 0
var _nickname_refused: bool = false
var _held_direction: int = PokeButton.NONE
var _let_go: int = 0
var _gender: int = Gen2SaveData.GENDER_MALE
var _grind_level: int = 0
var _bonus: int = 0
var _fight: Array = []
var _lost: bool = false
var _sites: Dictionary = {}
var _walks: Gen2WorldReachability = null
var _graph: Dictionary = {}
var _reverse: Array = []
var _distances_to: Dictionary = {}


func run(r: CheckRun) -> void:
	_r = r
	Gen2SaveStore.use_root(SAVE_ROOT)
	r.each_game_of(RomRegistry.GEN1, _play)
	r.each_game_of(RomRegistry.GEN2, _play)
	Gen2SaveStore.use_root("")


## Each row is [label, goal, done]; a Callable row runs as it is.
func _legs() -> Array:
	return _gen1_legs() if _r.data.generation == RomRegistry.GEN1 else _gen2_legs()


## Mom, Elm's walk-up, his aide and the Cherrygrove rival are all met on the way.
func _gen2_legs() -> Array:
	var up: int = Gen2WorldSprite.FACING_UP
	return [
		["bedroom_to_1f", _warp_to(PLAYERS_HOUSE_1F), _on_map(PLAYERS_HOUSE_1F)],
		["mom_and_out", _warp_to(NEW_BARK_TOWN), _on_map(NEW_BARK_TOWN)],
		_engine_check(ENGINE_POKEGEAR, "Mom handed over no Pokegear."),
		["new_bark_to_lab", _warp_to(ELMS_LAB), _on_map(ELMS_LAB)],
		["starter", _talk(BELOW_ELMS_BALL, up), _flag(EVENT_GOT_A_POKEMON_FROM_ELM)],
		["lab_out", _warp_to(NEW_BARK_TOWN), _on_map(NEW_BARK_TOWN)],
		_grind.bind(ROUTE_29_LEVEL, 0),
		["new_bark_to_route_29", _cross(Vector2i.LEFT, ROUTE_29), _on_map(ROUTE_29)],
		["route_29_to_cherrygrove", _cross(Vector2i.LEFT, CHERRYGROVE_CITY), _on_map(CHERRYGROVE_CITY)],
		["cherrygrove_to_route_30", _cross(Vector2i.UP, ROUTE_30), _on_map(ROUTE_30)],
		["mr_pokemon", _warp_to(MR_POKEMONS_HOUSE), _flag(EVENT_GOT_MYSTERY_EGG_FROM_MR_POKEMON)],
		["mr_pokemon_out", _warp_to(ROUTE_30), _on_map(ROUTE_30)],
		["route_30_to_cherrygrove", _cross(Vector2i.DOWN, CHERRYGROVE_CITY), _on_map(CHERRYGROVE_CITY)],
		["rival", _cross(Vector2i.RIGHT, ROUTE_29), _on_map(ROUTE_29)],
		["route_29_to_new_bark", _cross(Vector2i.RIGHT, NEW_BARK_TOWN), _on_map(NEW_BARK_TOWN)],
		_site_check(MYSTERY_EGG),
		["mystery_egg", _fetch(MYSTERY_EGG), _holds(MYSTERY_EGG)],
		["egg_to_lab", _route(ELMS_LAB), _on_map(ELMS_LAB)],
		["officer", _walk(OFFICER_TRIGGER), _scene(ELMS_LAB, SCENE_ELMSLAB_NOOP)],
		["elm", _talk(BELOW_ELM, up), _flag(EVENT_GAVE_MYSTERY_EGG_TO_ELM)],
		["lab_out_again", _warp_to(NEW_BARK_TOWN), _on_map(NEW_BARK_TOWN)],
		_grind.bind(FALKNER_LEVEL, 0),
		["new_bark_to_route_29_again", _cross(Vector2i.LEFT, ROUTE_29), _on_map(ROUTE_29)],
		["route_29_to_cherrygrove_again", _cross(Vector2i.LEFT, CHERRYGROVE_CITY), _on_map(CHERRYGROVE_CITY)],
		["cherrygrove_to_route_30_again", _cross(Vector2i.UP, ROUTE_30), _on_map(ROUTE_30)],
		["route_30_to_route_31", _cross(Vector2i.UP, ROUTE_31), _on_map(ROUTE_31)],
		["route_31_to_gate", _warp_to(ROUTE_31_VIOLET_GATE), _on_map(ROUTE_31_VIOLET_GATE)],
		["gate_to_violet", _warp_to(VIOLET_CITY), _on_map(VIOLET_CITY)],
		["violet_center", _warp_to(VIOLET_POKECENTER), _on_map(VIOLET_POKECENTER)],
		_hurt,
		["nurse", _talk(BELOW_NURSE, up), _healed()],
		["center_out", _warp_to(VIOLET_CITY), _on_map(VIOLET_CITY)],
		["violet_gym", _warp_to(VIOLET_GYM), _on_map(VIOLET_GYM)],
		["falkner", _talk(BELOW_FALKNER, up), _engine(_badge_at(VIOLET_GYM))],
		["gym_out", _warp_to(VIOLET_CITY), _on_map(VIOLET_CITY)],
		["violet_center_again", _warp_to(VIOLET_POKECENTER), _on_map(VIOLET_POKECENTER)],
		["togepi_egg", _talk(BELOW_AIDE, up), _flag(EVENT_GOT_TOGEPI_EGG_FROM_ELMS_AIDE)],
		["center_out_again", _warp_to(VIOLET_CITY), _on_map(VIOLET_CITY)],
		["violet_to_route_32", _cross(Vector2i.DOWN, ROUTE_32), _on_map(ROUTE_32)],
		["route_32_to_union_cave", _warp_to(UNION_CAVE_1F[_r.crystal]), _on_map(UNION_CAVE_1F[_r.crystal])],
		["union_cave_to_route_33", _warp_to(ROUTE_33), _on_map(ROUTE_33)],
		["route_33_to_azalea", _cross(Vector2i.LEFT, AZALEA_TOWN), _on_map(AZALEA_TOWN)],
		["azalea_to_kurt", _warp_to(KURTS_HOUSE), _on_map(KURTS_HOUSE)],
		["kurt", _talk(BELOW_KURT, up), _flag(EVENT_AZALEA_TOWN_SLOWPOKETAIL_ROCKET)],
		["kurt_out", _warp_to(AZALEA_TOWN), _on_map(AZALEA_TOWN)],
		_grind.bind(BUGSY_LEVEL, 0),
		["azalea_to_well", _warp_to(SLOWPOKE_WELL_B1F[_r.crystal]), _on_map(SLOWPOKE_WELL_B1F[_r.crystal])],
		["rockets", _walk(BELOW_WELL_ROCKET), _on_map(KURTS_HOUSE)],
		["kurt_out_again", _warp_to(AZALEA_TOWN), _on_map(AZALEA_TOWN)],
		["azalea_gym", _warp_to(AZALEA_GYM), _on_map(AZALEA_GYM)],
		["bugsy", _talk(BELOW_BUGSY, up), _engine(_badge_at(AZALEA_GYM))],
		["bugsy_gym_out", _warp_to(AZALEA_TOWN), _on_map(AZALEA_TOWN)],
	]


func _gen1_legs() -> Array:
	var up: int = Gen2WorldSprite.FACING_UP
	return [
		["bedroom_to_1f", _warp_to(REDS_HOUSE_1F), _on_map(REDS_HOUSE_1F)],
		["house_to_pallet", _warp_to(PALLET_TOWN), _on_map(PALLET_TOWN)],
		["north_path_to_lab", _walk(PALLET_NORTH_PATH[_r.game_id]), _on_map(OAKS_LAB)],
		["starter", _talk(LAB_STARTER_BALLS[_r.game_id], up), _flag(EVENT_GOT_STARTER)],
		["rival_and_out", _warp_to(PALLET_TOWN), _on_map(PALLET_TOWN)],
		_flag_check(EVENT_BATTLED_RIVAL_IN_OAKS_LAB, "the rival was not fought on the way out."),
		["pallet_to_home", _warp_to(REDS_HOUSE_1F), _on_map(REDS_HOUSE_1F)],
		["mom", _talk(BELOW_MOM, up), _healed()],
		["home_out", _warp_to(PALLET_TOWN), _on_map(PALLET_TOWN)],
		_grind.bind(ROUTE_1_LEVEL, 0),
		_site_check(OAKS_PARCEL),
		["parcel", _fetch(OAKS_PARCEL), _holds(OAKS_PARCEL)],
		["parcel_to_lab", _route(OAKS_LAB), _on_map(OAKS_LAB)],
		["pokedex", _talk(LAB_BELOW_OAK, up), _flag(EVENT_GOT_POKEDEX)],
		["lab_out", _warp_to(PALLET_TOWN), _on_map(PALLET_TOWN)],
		["pallet_to_home_again", _warp_to(REDS_HOUSE_1F), _on_map(REDS_HOUSE_1F)],
		["mom_again", _talk(BELOW_MOM, up), _healed()],
		["home_out_again", _warp_to(PALLET_TOWN), _on_map(PALLET_TOWN)],
		["pallet_to_route_1_again", _cross(Vector2i.UP, ROUTE_1), _on_map(ROUTE_1)],
		["route_1_to_viridian_again", _cross(Vector2i.UP, VIRIDIAN_CITY), _on_map(VIRIDIAN_CITY)],
		["viridian_center", _warp_to(VIRIDIAN_POKECENTER), _on_map(VIRIDIAN_POKECENTER)],
		_hurt,
		["nurse", _talk(BELOW_NURSE, up), _healed()],
		["center_out", _warp_to(VIRIDIAN_CITY), _on_map(VIRIDIAN_CITY)],
		_grind.bind(FOREST_LEVEL, 0),
		["viridian_to_route_2", _cross(Vector2i.UP, ROUTE_2), _on_map(ROUTE_2)],
		["route_2_to_south_gate", _warp_to(VIRIDIAN_FOREST_SOUTH_GATE), _on_map(VIRIDIAN_FOREST_SOUTH_GATE)],
		["south_gate_to_forest", _warp_to(VIRIDIAN_FOREST), _on_map(VIRIDIAN_FOREST)],
		["forest_to_north_gate", _warp_to(VIRIDIAN_FOREST_NORTH_GATE), _on_map(VIRIDIAN_FOREST_NORTH_GATE)],
		["north_gate_to_route_2", _warp_to(ROUTE_2), _on_map(ROUTE_2)],
		["route_2_to_pewter", _cross(Vector2i.UP, PEWTER_CITY), _on_map(PEWTER_CITY)],
		_grind.bind(BROCK_LEVEL, MANKEY_DEX),
		["pewter_gym", _warp_to(PEWTER_GYM), _on_map(PEWTER_GYM)],
		["brock", _talk(BELOW_BROCK, up), _flag(EVENT_BEAT_BROCK)],
		_badge_check,
		["gym_out", _warp_to(PEWTER_CITY), _on_map(PEWTER_CITY)],
		["pewter_to_route_3", _cross(Vector2i.RIGHT, ROUTE_3), _on_map(ROUTE_3)],
		["route_3_to_route_4", _cross(Vector2i.UP, ROUTE_4), _on_map(ROUTE_4)],
		_grind.bind(MT_MOON_LEVEL, 0),
		["route_4_to_mt_moon", _warp_to(MT_MOON_1F), _on_map(MT_MOON_1F)],
		["mt_moon_1f_to_b1f", _walk(MT_MOON_1F_LADDER), _on_map(MT_MOON_B1F)],
		["mt_moon_b1f_to_b2f", _warp_to(MT_MOON_B2F), _on_map(MT_MOON_B2F)],
		["super_nerd", _walk(MT_MOON_NERD_CELL), _at(MT_MOON_NERD_CELL)],
		["dome_fossil", _talk(MT_MOON_BELOW_DOME, up), _flag(EVENT_GOT_DOME_FOSSIL[_r.game_id])],
		["mt_moon_b2f_to_b1f", _walk(MT_MOON_B2F_EXIT_LADDER), _on_map(MT_MOON_B1F)],
		["mt_moon_b1f_to_route_4", _walk(MT_MOON_B1F_EXIT), _on_map(ROUTE_4)],
		["route_4_to_cerulean", _cross(Vector2i.RIGHT, CERULEAN_CITY), _on_map(CERULEAN_CITY)],
		_grind.bind(MISTY_LEVEL, ODDISH_DEX),
		["cerulean_gym", _warp_to(CERULEAN_GYM), _on_map(CERULEAN_GYM)],
		["misty", _talk_to(MISTY), _engine(_badge_at(CERULEAN_GYM))],
		["cerulean_gym_out", _warp_to(CERULEAN_CITY), _on_map(CERULEAN_CITY)],
	]


func _play() -> void:
	var trace: PackedStringArray = OS.get_environment("PLAYED_TRACE").split(":")
	if trace.size() == 2 and trace[0] != String(_r.game_id):
		return
	## `--mods` plays with the installed mods loaded, the way most players run it.
	if Gen2GameRuntime.mods_are_allowed():
		GameRuntime.select_game(_r.game_id)
		_r.note("played: mods %s" % [Gen2ModHost.instance().loaded_mods()])
	_walks = null
	_distances_to.clear()
	_play_as(Gen2SaveData.GENDER_MALE)
	if _r.crystal:
		_play_as(Gen2SaveData.GENDER_FEMALE)


## Crystal's girl has her own sprites, lines and back pic: played to the rival.
func _play_as(gender: int) -> void:
	_gender = gender
	_frames = 0
	_pressed_at = -PRESS_EVERY
	_nickname_refused = false
	_held_direction = PokeButton.NONE
	_let_go = 0
	_bonus = 0
	_sites.clear()
	var save: Gen2SaveData = _play_intro()
	if save == null or not _r.check(save.gender == gender, "the intro wrote gender %d." % save.gender):
		return
	save.run_seed = RUN_SEED
	_screen = _open_screen(save)
	if _screen == null:
		return
	_editor = Gen2SaveEditor.new()
	_editor.data = _r.data
	_editor.save = save
	if _walk_legs(gender):
		_r.note("played: %s in %d frames, %d battles" % [
			"the last badge" if gender == Gen2SaveData.GENDER_MALE else GIRL_LAST_LEG,
			_frames, _screen.battles_fought()])
	_r.close_screen(_screen)
	_screen = null


## A whiteout trains the party and walks again from the last leg that set out
## where it woke up; only legs run twice.
func _walk_legs(gender: int) -> bool:
	var legs: Array = _legs()
	var starts: Dictionary = {}
	var losses: Dictionary = {}
	var replay_to: int = -1
	var index: int = 0
	while index < legs.size():
		var row: Variant = legs[index]
		if row is Callable:
			if index >= replay_to and not row.call():
				return false
		else:
			starts[index] = _screen.world().map_id()
			if not _leg(String(row[0]), row[1], row[2]):
				var back: int = _retry(legs, index, starts, losses) if _lost else -1
				if back < 0:
					return false
				replay_to = maxi(replay_to, index)
				index = back
				continue
			if gender == Gen2SaveData.GENDER_FEMALE and row[0] == GIRL_LAST_LEG:
				break
		index += 1
	return true


func _retry(legs: Array, index: int, starts: Dictionary, losses: Dictionary) -> int:
	var label: String = String(legs[index][0])
	losses[label] = int(losses.get(label, 0)) + 1
	if not _r.check(int(losses[label]) <= RETRIES, "lost to %s %d times, party %s." % [
		label.to_upper(), losses[label], _party()]):
		return -1
	var map: Vector2i = _screen.world().map_id()
	for back: int in range(index, -1, -1):
		if legs[back] is Array and starts.get(back) == map:
			_bonus += RETRY_LEVELS
			return back if _grind(_grind_level, 0) else -1
	_r.fail("%s whited out to map %s, where no leg sets out." % [label, map])
	return -1


func _flag_check(flag: int, message: String) -> Callable:
	return func() -> bool:
		return _r.check(_screen.world().event_flag_active(flag), message)


func _engine_check(flag: int, message: String) -> Callable:
	return func() -> bool:
		return _r.check(_screen.world().state.is_engine_flag_active(flag), message)


func _badge_check() -> bool:
	var state: Gen2WorldState = _screen.world().state
	return _r.check(state.is_engine_flag_active(_badge_at(PEWTER_GYM)), "Brock gave no badge.") \
		and _r.check(int(state.items().get(OAKS_PARCEL, 0)) == 0
			and _screen.world().event_flag_active(EVENT_GOT_TM34), "the bag holds %s." % [state.items()])


## `NewGame` through `OakSpeech` to its save: A pressed and let go whenever the
## intro owes no frame, the preset name row taken at the keyboard.
func _play_intro() -> Gen2SaveData:
	var intro := Gen2IntroScreen.new()
	var written: Array = []
	intro.finished.connect(func(save: Gen2SaveData) -> void: written.append(save))
	intro.failed.connect(func(message: String) -> void: _r.fail("the intro failed: %s" % message))
	intro.begin(_r.data, 0, "", false)
	(Engine.get_main_loop() as SceneTree).root.add_child(intro)
	intro.set_process(false)
	var presses: int = 0
	var spent: int = 0
	_still = 0
	while written.is_empty() and spent < INTRO_FRAMES:
		if _frames - _pressed_at == HOLD_FRAMES:
			intro.release_button(PokeButton.A)
		if _intro_reads_press(intro) and _frames - _pressed_at >= PRESS_EVERY:
			var screen: Control = intro.current()
			if screen is Gen2GenderScreen and _gender == Gen2SaveData.GENDER_FEMALE:
				intro.handle_button(PokeButton.DOWN)
			if screen != null and screen.has_method(&"choosing_name") and bool(screen.call(&"choosing_name")):
				for _row: int in PRESET_ROW:
					intro.handle_button(PokeButton.DOWN)
			intro.handle_button(PokeButton.A)
			_pressed_at = _frames
			presses += 1
		intro.advance_frames(1)
		spent += 1
		_frames += 1
		if _stalled_on(_intro_where(intro)):
			_r.fail("the intro froze after %d frames: %s" % [spent, _intro_where(intro)])
			break
	_r.check(not written.is_empty(), "the intro reached no save in %d frames and %d presses." % [spent, presses])
	(Engine.get_main_loop() as SceneTree).root.remove_child(intro)
	intro.free()
	_r.note("played: %-28s %5d frames, %d presses" % ["intro", spent, presses])
	return written[0] if not written.is_empty() else null


## Generation 2's splash takes a press in every phase; its frame count is a timer.
func _intro_reads_press(intro: Gen2IntroScreen) -> bool:
	if _r.data.generation != RomRegistry.GEN1 and intro.current() is Gen2SplashScreen:
		return true
	return intro.animation_frames_left() == 0


func _intro_where(intro: Gen2IntroScreen) -> String:
	var screen: Control = intro.current()
	if screen == null:
		return "no screen"
	var splash: Gen2SplashScreen = screen as Gen2SplashScreen
	if splash != null:
		return "splash %s frame %d" % [splash.visible_image(), (splash.get("_cinema") as Gen2BootCinema).frame()]
	var speech: Gen2OakSpeechScreen = screen as Gen2OakSpeechScreen
	if speech != null:
		var box: Gen2TextBox = speech.get("_text_box")
		return "speech %s naming=%s menu=%s" % [
			"\n".join(box.text_lines()) if box != null else "", speech.naming(), speech.choosing_name()]
	return screen.get_class()


func _open_screen(save: Gen2SaveData) -> Gen2WorldScreen:
	var screen: Gen2WorldScreen = (load("res://game/world/world_screen.tscn") as PackedScene).instantiate()
	screen.set_data(_r.data)
	screen.set_save(save)
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.set_process(false)
	if screen.world() == null:
		_r.fail("the world screen did not open on the intro's save.")
		_r.close_screen(screen)
		return null
	return screen


## Goals: the next button on an idle map, or NONE when there. A mat is left
## into the edge behind it, or its carpet's own direction.
func _walk(cell: Vector2i) -> Callable:
	return func(world: Gen2WorldAPI) -> int:
		if world.player_cell != cell:
			return _step_toward(world, _is(cell))
		return _warp_press(world, cell)


func _is(cell: Vector2i) -> Callable:
	return func(at: Vector2i) -> bool:
		return at == cell


func _warp_press(world: Gen2WorldAPI, cell: Vector2i) -> int:
	if world.warp_at(cell).is_empty():
		return PokeButton.NONE
	if _r.data.generation != RomRegistry.GEN1:
		return _direction_button(Gen2WorldCollision.directional_warp_direction(world.gen2_code_at(cell)))
	for direction: Vector2i in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
		if not world.can_walk_to(cell + direction, direction) \
			and bool(world.call(&"_gen1_extra_warp_check", cell, direction)):
			return _direction_button(direction)
	return PokeButton.NONE


func _talk(cell: Vector2i, facing: int) -> Callable:
	return func(world: Gen2WorldAPI) -> int:
		if world.player_cell != cell:
			return _step_toward(world, _is(cell))
		if world.player_facing != facing:
			return _direction_button(Gen2WorldAPI.SIGHT_STEPS[facing])
		return PokeButton.A


## [param target] faced from the first side a walk reaches.
func _talk_to(target: Vector2i) -> Callable:
	return func(world: Gen2WorldAPI) -> int:
		return _talk_button(world, target)


func _talk_button(world: Gen2WorldAPI, target: Vector2i) -> int:
	for side: Vector2i in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
		if world.player_cell == target + side:
			var facing: int = int(Gen2WorldAPI.SIGHT_STEPS.find_key(-side))
			return _direction_button(-side) if world.player_facing != facing else PokeButton.A
	for side: Vector2i in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
		var button: int = _step_toward(world, _is(target + side))
		if button != PokeButton.NONE:
			return button
	return PokeButton.NONE


func _cross(direction: Vector2i, map: Vector2i) -> Callable:
	return func(world: Gen2WorldAPI) -> int:
		if _crosses(world, world.player_cell, direction, map):
			return _direction_button(direction)
		return _step_toward(world, func(at: Vector2i) -> bool: return _crosses(world, at, direction, map))


## The nearest exit landing closer to [param map] in the region graph, gates open.
func _route(map: Vector2i) -> Callable:
	return func(world: Gen2WorldAPI) -> int:
		return _route_button(world, Gen2WorldStory.place(map))


func _route_button(world: Gen2WorldAPI, place: Array) -> int:
	var distances: PackedInt32Array = _distances(place)
	var here: int = _place_distance(distances, Gen2WorldStory.place(world.map_id(), world.player_cell))
	var closer: Callable = func(at: Vector2i) -> bool: return _exit_at(world, distances, at).x < here
	if closer.call(world.player_cell):
		return _exit_at(world, distances, world.player_cell).y
	return _step_toward(world, closer)


func _exit_at(world: Gen2WorldAPI, distances: PackedInt32Array, at: Vector2i) -> Vector2i:
	var best := Vector2i(UNREACHED, PokeButton.NONE)
	var warp: Dictionary = world.warp_at(at)
	if not warp.is_empty():
		best = Vector2i(_place_distance(distances, _warp_landing(world, warp)), _warp_press(world, at))
	for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var target: Dictionary = world.connection_target(at, direction)
		if not bool(target.get("ok", false)):
			continue
		var map := Vector2i(int(target["map_group"]), int(target["map_number"]))
		var distance: int = _place_distance(distances, Gen2WorldStory.place(map, target["cell"]))
		if distance < best.x:
			best = Vector2i(distance, _direction_button(direction))
	return best


## The place a warp lands on: Generation 1's destinations count from zero.
func _warp_landing(world: Gen2WorldAPI, warp: Dictionary) -> Array:
	var target: Vector2i = _warp_target(world, warp)
	var index: int = int(warp.get("destination", 0))
	if _r.data.generation != RomRegistry.GEN1:
		index -= 1
	var map: Gen2WorldMap = _r.data.world_map(target.x, target.y)
	var warps: Array = map.events.get("warps", []) if map != null else []
	if index < 0 or index >= warps.size():
		return Gen2WorldStory.place(target)
	return Gen2WorldStory.place(target, Vector2i(int(warps[index]["x"]), int(warps[index]["y"])))


func _warp_target(world: Gen2WorldAPI, warp: Dictionary) -> Vector2i:
	var target := Vector2i(int(warp.get("map_group", 0)), int(warp.get("map_number", -1)))
	if _r.data.generation == RomRegistry.GEN1 and target.y == Gen1Layout.WARP_TO_LAST_MAP:
		target.y = world.gen1_last_map()
	return target


func _place_distance(distances: PackedInt32Array, place: Array) -> int:
	var best: int = UNREACHED
	for node: int in _walks.place_nodes(_graph, place):
		best = mini(best, distances[node])
	return best


func _distances(place: Array) -> PackedInt32Array:
	if _walks == null:
		_walks = Gen2WorldReachability.build(_r.data, _r.data.catalog().story())
		_graph = _walks.graph({})
		_reverse = _reversed(_graph)
	var key: String = str(place)
	if _distances_to.has(key):
		return _distances_to[key]
	var out := PackedInt32Array()
	out.resize(_reverse.size())
	out.fill(UNREACHED)
	var frontier: Array = Array(_walks.place_nodes(_graph, place))
	for node: int in frontier:
		out[node] = 0
	while not frontier.is_empty():
		var node: int = frontier.pop_front()
		for from: int in _reverse[node]:
			if out[from] == UNREACHED:
				out[from] = out[node] + 1
				frontier.append(from)
	_distances_to[key] = out
	return out


static func _reversed(built: Dictionary) -> Array:
	var out: Array = []
	for _node: int in int(built["count"]):
		out.append([])
	for node: int in int(built["count"]):
		for target: int in built["edges"][node]:
			(out[target] as Array).append(node)
		for gate: int in (built["into_gate"] as Dictionary).get(node, []):
			(out[int(built["gates"][gate]["portal"])] as Array).append(node)
	return out


## The key item's site as patched, routed to and talked to, a walker followed.
func _fetch(item: int) -> Callable:
	return func(world: Gen2WorldAPI) -> int:
		var site: Dictionary = _site_of(item)
		var cell: Vector2i = site.get("cell", Vector2i(-1, -1))
		if world.map_id() == site.get("map") and cell.x >= 0:
			var button: int = _talk_button(world, _live_cell(world, cell))
			if button != PokeButton.NONE:
				return button
		return _route_button(world, Gen2WorldStory.place(site.get("map", Vector2i(-1, -1)), cell))


func _site_of(item: int) -> Dictionary:
	if not _sites.has(item):
		_sites[item] = {}
		for row: Dictionary in _r.data.catalog().rows(Gen2WorldCatalog.KIND_ITEM):
			if int(row.get("item", 0)) == item and row.has("map"):
				_sites[item] = row
				break
	return _sites[item]


func _site_check(item: int) -> Callable:
	return func() -> bool:
		var site: Dictionary = _site_of(item)
		_r.note("played: %s is handed out on map %s at %s" % [
			_r.data.item(item).get("name", item), site.get("map"), site.get("cell")])
		return _r.check(not site.is_empty(), "no site hands out item %d." % item)


func _live_cell(world: Gen2WorldAPI, cell: Vector2i) -> Vector2i:
	for object: Gen2WorldObject in world.active_objects():
		if object.initial_cell == cell:
			return object.cell
	return cell


## The first warp onto [param map] a walk reaches: a gate's door has a wall
## cell beside it that carries the same warp.
func _warp_to(map: Vector2i) -> Callable:
	return func(world: Gen2WorldAPI) -> int:
		for warp: Dictionary in world.current_map.events.get("warps", []):
			if _warp_target(world, warp) != map:
				continue
			var button: int = _walk(Vector2i(int(warp["x"]), int(warp["y"]))).call(world)
			if button != PokeButton.NONE:
				return button
		return PokeButton.NONE


## Predicates that end a leg.
func _on_map(map: Vector2i) -> Callable:
	return func(world: Gen2WorldAPI) -> bool:
		return world.map_id() == map


func _flag(flag: int) -> Callable:
	return func(world: Gen2WorldAPI) -> bool:
		return world.event_flag_active(flag)


func _at(cell: Vector2i) -> Callable:
	return func(world: Gen2WorldAPI) -> bool:
		return world.player_cell == cell


func _scene(map: Vector2i, scene: int) -> Callable:
	return func(world: Gen2WorldAPI) -> bool:
		return world.state.map_scene(map.x, map.y) == scene


func _engine(flag: int) -> Callable:
	return func(world: Gen2WorldAPI) -> bool:
		return world.state.is_engine_flag_active(flag)


## The engine flag of the badge the gym on [param map] hands out, as patched.
func _badge_at(map: Vector2i) -> int:
	for row: Dictionary in _r.data.catalog().rows(Gen2WorldCatalog.KIND_BADGE):
		if row.get("map") == map:
			## `gen1_badge_flag` reads Crystal's table too.
			var crystal_table: bool = _r.crystal or _r.data.generation == RomRegistry.GEN1
			return Gen2WorldState.badge_flag(int(row.get("badge", -1)), crystal_table)
	return -1


func _holds(item: int) -> Callable:
	return func(world: Gen2WorldAPI) -> bool:
		return world.state.item_quantity(item) > 0


func _healed() -> Callable:
	return func(_world: Gen2WorldAPI) -> bool:
		for mon: Gen2SaveMon in _screen.active_save().party:
			if not mon.is_egg and (mon.hp < _editor.max_hp_for(mon) or mon.status != 0):
				return false
		return true


func _hurt() -> bool:
	for mon: Gen2SaveMon in _screen.active_save().party:
		if not mon.is_egg:
			mon.hp = maxi(1, mon.hp / 2)
	_screen.call(&"_refresh_party_summary")
	return true


func _party() -> Array:
	var out: Array = []
	for mon: Gen2SaveMon in _screen.active_save().party:
		out.append("%s L%d %d/%d" % [
			_r.data.species(mon.species).get("name", mon.species), mon.level, mon.hp, _editor.max_hp_for(mon)])
	return out


## Frames spent until [param done], every one of them pressed as a player would.
func _leg(label: String, goal: Callable, done: Callable) -> bool:
	var world: Gen2WorldAPI = _screen.world()
	var spent: int = 0
	var budget: int = int(LEG_BUDGETS.get(label, LEG_FRAMES))
	_still = 0
	_lost = false
	_fight = []
	while spent < budget:
		var idle: bool = _idle()
		if idle and done.call(world):
			_r.note("played: %-28s %5d frames, on map %s at %s, party %s, bag %s" % [
				label, spent, world.map_id(), world.player_cell, _party(), world.state.items()])
			return true
		if idle and _whited_out(world):
			_lost = true
			_r.note("played: %-28s %5d frames, lost and whited out to map %s at %s" % [
				label, spent, world.map_id(), world.player_cell])
			return false
		if _screen.battle_active():
			_fight = [world.map_id(), _screen.battles_fought()]
		var button: int = _button_for(goal)
		if OS.get_environment("PLAYED_TRACE").ends_with(label) and spent % 4 == 0:
			print("  f%d btn=%d %s" % [spent, button, _where()])
		if button != PokeButton.NONE:
			_screen.press_button(button)
			_pressed_at = _frames
		_screen.advance_frame()
		spent += 1
		_frames += 1
		if _stalled_on(_where()):
			_r.fail("%s froze after %d frames: %s" % [label, spent, _where()])
			return false
	_r.fail("%s did not finish in %d frames: %s" % [label, budget, _where()])
	return false


## Whether the last fight was lost and left the player elsewhere, asked once.
func _whited_out(world: Gen2WorldAPI) -> bool:
	if _fight.is_empty():
		return false
	var lost: bool = _screen.last_battle_outcome() == Gen2WorldBattleAdapter.OUTCOME_LOST \
		and _screen.battles_fought() == int(_fight[1]) and world.map_id() != _fight[0]
	_fight = []
	return lost


func _idle() -> bool:
	var world: Gen2WorldAPI = _screen.world()
	var box: Gen2TextBox = _screen.get("_text_box")
	return _screen.get("_battle_host") == null and not _any_host() \
		and not (box != null and box.visible) and not world.script_busy() \
		and not world.scripted_movement_in_progress() and not world.gen1_movement_script_running() \
		and not world.gen1_map_load_pending() and world.pending_runtime_request().is_empty() \
		and world.pending_script_wait().is_empty() and not world.script_input_waiting() \
		and not world.player_step_in_progress() and not bool(_screen.call(&"_input_locked"))


func _any_host() -> bool:
	for name: StringName in Gen2WorldScreen.OVERLAY_HOSTS + Gen2WorldScreen.ANSWERING_HOSTS:
		if _screen.get(name) != null:
			return true
	return false


## The player's one decision a frame.
func _button_for(goal: Callable) -> int:
	var world: Gen2WorldAPI = _screen.world()
	if bool(_screen.call(&"_input_locked")):
		return PokeButton.NONE
	if _screen.get("_battle_host") != null:
		return _battle_button()
	if _screen.get("_service_host") != null:
		return _choice_button()
	if _any_host():
		return _paced(PokeButton.A)
	var box: Gen2TextBox = _screen.get("_text_box")
	if box != null and box.visible:
		return PokeButton.NONE if box.is_revealing() else _paced(PokeButton.A)
	if world.script_input_waiting():
		return _paced(PokeButton.A)
	if not _idle():
		return PokeButton.NONE
	return _let_go_between(int(goal.call(world)))


func _paced(button: int) -> int:
	return button if _frames - _pressed_at >= PRESS_EVERY else PokeButton.NONE


## `wCheckFor180DegreeTurn` is armed by a poll with nothing held, so a new
## direction leaves the pad for a pass first, or it is a bump.
func _let_go_between(button: int) -> int:
	if not PokeButton.is_direction(button):
		_held_direction = PokeButton.NONE
		return button
	if button != _held_direction and _let_go < Gen2WorldAPI.FRAMES_PER_OVERWORLD_PASS:
		_let_go += 1
		return PokeButton.NONE
	_let_go = 0
	_held_direction = button
	return button


## FIGHT, the move that hurts most, A on every box, the first member standing.
func _battle_button() -> int:
	var host: Gen2BattleScreen = _screen.get("_battle_host")
	var snapshot: Dictionary = host.battle_snapshot()
	if not bool(snapshot.get("ready", false)):
		return PokeButton.NONE
	if StringName(snapshot.get("switch_stage", &"")) == &"pick":
		if not bool(snapshot.get("switch_forced", false)):
			return _paced(PokeButton.B)
		var cursor: int = int(snapshot.get("switch_cursor", 0))
		var party: Gen2Party = (host.get("_battle") as Gen2Battle).party(Gen2Battle.PLAYER)
		if cursor < party.mons.size() and (party.mons[cursor] as Gen2BattleMon).is_fainted():
			return _paced(PokeButton.DOWN)
	match StringName(snapshot.get("menu_stage", &"")):
		&"main":
			var position: int = int(snapshot.get("menu_position", Gen2BattleMenu.FIGHT))
			if position in [Gen2BattleMenu.PACK, Gen2BattleMenu.RUN]:
				return _paced(PokeButton.UP)
			if position == Gen2BattleMenu.PKMN:
				return _paced(PokeButton.LEFT)
		&"move":
			if int(snapshot.get("move_cursor", 0)) != _best_move_row(host.info_snapshot()):
				return _paced(PokeButton.DOWN)
	return _paced(PokeButton.A)


## The row whose power times effectiveness is highest, with PP left.
func _best_move_row(info: Dictionary) -> int:
	var best: int = 0
	var best_score: float = -1.0
	var rows: Array = info.get("move_rows", [])
	for index: int in rows.size():
		var row: Dictionary = rows[index]
		if int(row.get("pp", 0)) <= 0 or bool(row.get("disabled", false)):
			continue
		var score: float = float(_r.data.move(int(row["move"])).get("power", 0)) \
			* float(row.get("effectiveness", 0))
		if score > best_score:
			best_score = score
			best = index
	return best


## YES to everything but a nickname, which is the second row.
func _choice_button() -> int:
	var text: String = String(_screen.world().pending_script_input().get("text", ""))
	if text.contains("nickname") and not _nickname_refused:
		_nickname_refused = true
		return PokeButton.DOWN
	return _paced(PokeButton.A)


## The next step to the nearest cell [param goal] accepts; NONE on one or none.
func _step_toward(world: Gen2WorldAPI, goal: Callable) -> int:
	if goal.call(world.player_cell):
		return PokeButton.NONE
	var frontier: Array[Vector2i] = [world.player_cell]
	var previous: Dictionary = {world.player_cell: Vector2i.ZERO}
	var found: Vector2i = Vector2i(-1, -1)
	while not frontier.is_empty():
		var at: Vector2i = frontier.pop_front()
		if goal.call(at):
			found = at
			break
		for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = _neighbour(world, at, direction, goal)
			if next.x < 0 or previous.has(next):
				continue
			previous[next] = next - at
			frontier.append(next)
	if found.x < 0:
		return PokeButton.NONE
	var cursor: Vector2i = found
	var first: Vector2i = Vector2i.ZERO
	while cursor != world.player_cell:
		first = previous[cursor]
		cursor -= first
	return _direction_button(first.sign())


## The cell a press toward [param direction] reaches from [param at]: a step, a
## ledge hop two cells on, or (-1, -1). A warp or a hole is only ever a goal.
func _neighbour(world: Gen2WorldAPI, at: Vector2i, direction: Vector2i, goal: Callable) -> Vector2i:
	var next: Vector2i = at + direction
	if world.step_blocked_from(at, direction) or not world.can_walk_to(next):
		next = at + direction * 2
		if not world.allows_hop_at(at, direction) or not world.can_walk_to(next):
			return Vector2i(-1, -1)
	if (world.warp_pending(next, direction) or not world.gen1_dungeon_hole_at(next).is_empty()) \
		and not goal.call(next):
		return Vector2i(-1, -1)
	return next


func _crosses(world: Gen2WorldAPI, at: Vector2i, edge: Vector2i, map: Vector2i) -> bool:
	var target: Dictionary = world.connection_target(at, edge)
	return bool(target.get("ok", false)) \
		and Vector2i(int(target.get("map_group", 0)), int(target.get("map_number", -1))) == map


func _direction_button(direction: Vector2i) -> int:
	match direction:
		Vector2i.UP: return PokeButton.UP
		Vector2i.DOWN: return PokeButton.DOWN
		Vector2i.LEFT: return PokeButton.LEFT
		Vector2i.RIGHT: return PokeButton.RIGHT
	return PokeButton.NONE


## Whether nothing observable has moved for [constant STALL_FRAMES].
func _stalled_on(signature: String) -> bool:
	if signature != _last_signature:
		_last_signature = signature
		_still = 0
		return false
	_still += 1
	return _still >= STALL_FRAMES


## The battle's own box, page by page: a win text is ten pages of one message.
func _battle_box_state(battle: Gen2BattleScreen) -> Array:
	if battle == null:
		return []
	var box: Gen2TextBox = battle.get("_box")
	var snapshot: Dictionary = battle.battle_snapshot()
	return [
		box.visible, box.is_revealing(), box.has_pages_left(), battle.frames_running(),
		snapshot.get("awaits_press"), snapshot.get("switch_stage"), snapshot.get("menu_stage"),
		battle.get("_forget_stage"),
	]


func _where() -> String:
	var world: Gen2WorldAPI = _screen.world()
	var box: Gen2TextBox = _screen.get("_text_box")
	var hosts: PackedStringArray = []
	for name: StringName in Gen2WorldScreen.OVERLAY_HOSTS + Gen2WorldScreen.ANSWERING_HOSTS:
		if _screen.get(name) != null:
			hosts.append(String(name))
	var battle: Gen2BattleScreen = _screen.get("_battle_host")
	var player: Gen2AudioPlayer = _screen.get("_audio_player")
	return JSON.stringify({
		"map": world.map_id().y, "cell": [world.player_cell.x, world.player_cell.y],
		"facing": world.player_facing,
		"box": "\n".join(box.text_lines()) if box != null and box.visible else "",
		"revealing": box != null and box.visible and box.is_revealing(),
		"hosts": hosts,
		"battle": battle.battle_snapshot().get("message", "") if battle != null else null,
		"battle_box": _battle_box_state(battle),
		"input": world.pending_script_input().get("type", ""),
		"request": world.pending_runtime_request().get("kind", ""),
		"wait": world.pending_script_wait(),
		"busy": world.script_busy(),
		"movement": world.scripted_movement_in_progress(),
		"map_script": world.gen1_map_script_state(),
		"locked": _screen.call(&"_input_locked"),
		"fade": _screen.map_fade(),
		"audio": player.audio_status().get("active_channels", []),
		"alarm": player.low_health_alarm(),
	})


## The grind and the catch that leads, each whiteout adding [constant RETRY_LEVELS].
func _grind(target: int, caught: int) -> bool:
	_grind_level = target
	var level: int = target + _bonus
	var save: Gen2SaveData = _screen.active_save()
	if not _r.check(not save.party.is_empty(), "no party to grind."):
		return false
	if caught > 0:
		if not _r.check(bool(_editor.add_party_member(caught, level).get("ok", false)),
			"the party could not take %d." % caught):
			return false
		save.party.push_front(save.party.pop_back())
	for mon: Gen2SaveMon in save.party:
		if mon.is_egg:
			continue
		_editor.set_level(mon, level)
		var known: Array = _r.data.moves_at_level(mon.species, level)
		for slot: int in Gen2SaveMon.MAX_MOVES:
			_editor.set_move(mon, slot, int(known[slot]) if slot < known.size() else Gen2SaveEditor.NO_MOVE)
		mon.hp = _editor.max_hp_for(mon)
		mon.ot_id = save.player_id
		mon.original_trainer = save.player_name
	_screen.call(&"_refresh_party_summary")
	_r.note("played: %-28s level %d, party %s" % ["grind", level, _party()])
	return true
