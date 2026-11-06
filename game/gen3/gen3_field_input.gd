class_name Gen3FieldInput
extends RefCounted # field_control_avatar.c's tile tables and step counters. Behaviors are `MB_*`; scripts are `native_scripts` keys.

const ENGINES: Dictionary = {
	RomRegistry.RUBY: &"ruby", RomRegistry.SAPPHIRE: &"ruby", RomRegistry.FIRERED: &"firered",
	RomRegistry.LEAFGREEN: &"firered", RomRegistry.EMERALD: &"emerald",
}
const COUNTER_BEHAVIOR: int = 0x80
const MOVE_SURF: int = 57
const WATERFALL_BEHAVIOR: int = 0x13
const FAST_WATER_BEHAVIOR: int = 0x11
const CRACKED_FLOOR_HOLE: int = 0x66
const CONNECTION_DIVE: int = 5
const CONNECTION_EMERGE: int = 6
const MAP_TYPE_UNDERWATER: int = 5
const MAP_TYPE_SECRET_BASE: int = 9
const CALL_MAP_TYPES: Array[int] = [1, 2, 3, 6] # Town, city, route, ocean route.
const GAME_STAT_STEPS: int = 5
const GAME_STAT_ENTERED_HOF: int = 10
const STATUS_POISONED: int = 0x88 # STATUS1_POISON | STATUS1_TOXIC_POISON.
const SIGN_INHIBIT_FRAMES: int = 6 # script.c::SetWalkingIntoSignVars.
const HIDDEN_ITEM_KINDS: Array[int] = [5, 6, 7]
const SAFARI_STEPS: Dictionary = {&"ruby": 500, &"firered": 600, &"emerald": 500}
const SS_TIDAL_MAX_STEPS: int = 205
const POISON_PERIOD: Dictionary = {&"ruby": 4, &"firered": 5, &"emerald": 4}

const FLAGS: Dictionary = { # `FLAG_HIDDEN_ITEMS_START`, badges, `FLAG_SYS_*` and step-counter `VAR_*`.
	&"ruby": {"hidden": 0x258, "surf": 0x80B, "waterfall": 0x80E, "dive": 0x80D, "safari": 0x82C, "cruise": 0x82D,
		"repel": 0x4021, "friendship": 0x402A, "poison": 0x402B, "cruise_steps": 0x404A},
	&"firered": {"hidden": 0x3E8, "surf": 0x824, "waterfall": 0x826, "safari": 0x800, "cruise": 0x802,
		"repel": 0x4020, "friendship": 0x4021, "poison": 0x4022},
	&"emerald": {"hidden": 0x1F4, "surf": 0x86B, "waterfall": 0x86E, "dive": 0x86D, "safari": 0x88C, "cruise": 0x88D,
		"repel": 0x4021, "friendship": 0x402A, "poison": 0x402B, "cruise_steps": 0x404A},
}
const HOENN_METATILES: Dictionary = {0x86: "tv", 0x83: "pc", 0x8B: "closed_sootopolis_door", 0x84: "cable_box_results",
	0x87: "pokeblock_feeder", 0x8C: "trick_house_door", 0x85: "region_map", 0x8E: "running_shoes_manual",
	0xE0: "picture_book_shelf", 0xE1: "book_shelf", 0xE2: "pokemon_center_book_shelf", 0xE3: "vase", 0xE4: "trash_can",
	0xE5: "shop_shelf", 0xE6: "blueprint"}
const EMERALD_METATILES: Dictionary = {0xEA: "sky_pillar_closed_door", 0xE8: "wireless_box_results",
	0xE7: "cable_box_results", 0x8F: "questionnaire", 0xE9: "trainer_hill_timer"}
const FRLG_METATILES: Dictionary = {0x83: "pc", 0x85: "region_map", 0x81: "book_shelf", 0x82: "mart_shelf", 0x90: "food",
	0xA0: "impressive_machine", 0x93: "blueprint", 0xA1: "video_game", 0xA2: "burglary", 0x97: "computer",
	0xA3: "trainer_tower_time", 0x86: "tv", 0x89: "cabinet", 0x8A: "kitchen", 0x8B: "dresser", 0x8C: "snacks",
	0x94: "painting", 0x95: "power_plant_machine", 0x96: "telephone", 0x98: "advertising_poster", 0x99: "tasty_food",
	0x9A: "trash_can", 0x9B: "cup", 0x9E: "blinking_lights", 0x9F: "neatly_lined_up_tools", 0x8D: "wireless_monitor",
	0x8F: "questionnaire", 0x8E: "battle_records", 0x91: "indigo_goal", 0x92: "indigo_authority",
	0x88: "pokemart_sign", 0x87: "pokecenter_sign"}
const NORTH_ONLY: Dictionary = {&"ruby": [0x86], &"emerald": [0x86, 0xE8, 0xE7], &"firered": [0x86, 0x8D, 0x8E, 0x88, 0x87]} # `MetatileBehavior_IsPlayerFacing*`.
const FRLG_SIGNS: Dictionary = {0x87: "pokecenter_sign", 0x88: "pokemart_sign", 0x91: "indigo_goal", 0x92: "indigo_authority"}
const FRLG_SIGNPOST: int = 0x84 # `MB_SIGNPOST` reads the background event instead of a fixed script.
const SECRET_BASE_METATILES: Dictionary = { # These also need the player's elevation to match the tile's.
	0xB0: "secret_base_pc", 0xB1: "record_mixing_pc", 0xBF: "sand_ornament",
	0xC4: "shield_or_toy_tv"}
const HOENN_WARPS: Dictionary = { # A warp presentation, or `script:` a native script after SetupWarp.
	0x60: "warp", 0x6C: "warp", 0x6E: "warp", 0x61: "warp", 0x69: "warp", 0x6A: "escalator",
	0x6B: "escalator", 0x29: "lavaridge_b1f", 0x68: "lavaridge_1f", 0x67: "teleport", 0x0F: "script:fall_down_hole_mt_pyre"}
const EMERALD_WARPS: Dictionary = {0x0E: "mossdeep_gym", 0x70: "spin_exit"}
const FRLG_WARPS: Dictionary = {0x60: "warp", 0x61: "warp", 0x69: "warp", 0x6A: "escalator", 0x6B: "escalator",
	0x68: "lavaridge_1f", 0x67: "teleport", 0x66: "script:fall_warp", 0x71: "union_room"}
const DOORS: Dictionary = {&"ruby": [0x69, 0x8D], &"firered": [0x69], &"emerald": [0x69, 0x8D]} # `MetatileBehavior_IsDoor`.
const NON_ANIM_DOORS: Dictionary = {&"ruby": [0x60, 0x6C, 0x6E], &"firered": [0x60], &"emerald": [0x60, 0x6C, 0x6E]}
const DEEP_SOUTH_WARP: int = 0x6E
const LADDER: int = 0x61
const MAP_TYPE_INDOOR: int = 8
const MAP_TYPES_ABOVE_CAVES: Array[int] = [1, 2, 3, 5, 6, 7, 8, 9] # fldeff_flash.c's `sTransitionTypes`: all but underground.
const MAP_TYPE_OCEAN_ROUTE: int = 6
const RUBY_CYCLING_ENTRANCES: Array[Vector2i] = [Vector2i(29, 11), Vector2i(29, 12)] # Route 110's, which are indoors.
const RUBY_NO_CYCLING: Array[Vector2i] = [Vector2i(24, 36), Vector2i(24, 42)] # Seafloor Cavern Room 9, Cave of Origin B4F.
const RUBY_NO_CYCLING_TYPES: Array[int] = [MAP_TYPE_INDOOR, MAP_TYPE_UNDERWATER, MAP_TYPE_SECRET_BASE]
const FRLG_SEAFOAM_ON_FOOT: Array[Vector2i] = [Vector2i(1, 86), Vector2i(1, 87)] # B3F and B4F's currents.
const HOENN_DIVEABLE: Array[int] = [0x11, 0x12, 0x14]
const HOENN_UNABLE_TO_EMERGE: Array[int] = [0x19, 0x2A]
const FRLG_STAIR_EXITS: Dictionary = {0x6C: 3, 0x6E: 3, 0x6D: 4, 0x6F: 4} # Up/down-right face west, up/down-left east.
const HOENN_ARROW_WARPS: Array = [[0x65, 0x6D, 0x1C], [0x64, 0x1B], [0x63], [0x62]]
const FRLG_ARROW_WARPS: Array = [[0x65], [0x64], [0x63], [0x62]]
const STORY_CALLS: Array = [ # field_specials.c's `ShouldDo*Call`: flag, step counter var, steps, script.
	[0x88, 0x40F2, 250, "wally_call"], [0x8A, 0x40F3, 10, "scott_fortree_call"],
	[0x72, 0x40F5, 10, "scott_frontier_call"], [0x80, 0x40F4, 250, "roxanne_call"], [0x75, 0x40F6, 250, "rival_rayquaza_call"]]

var engine: StringName
var flags: Dictionary
var safari_steps: int = 0 # `sSafariZoneStepCounter`, which is not saved.
var _events: Gen3EventData


func _init(events: Gen3EventData) -> void:
	_events = events
	engine = ENGINES[events.game]
	flags = FLAGS[engine]


func arrow_warps(direction: int) -> Array:
	return (FRLG_ARROW_WARPS if engine == &"firered" else HOENN_ARROW_WARPS)[direction - 1]


func is_door(behavior: int) -> bool:
	return behavior in DOORS[engine]


func is_non_anim_door(behavior: int) -> bool:
	return behavior in NON_ANIM_DOORS[engine]


func biking_allowed(map: Vector2i, header: Dictionary) -> bool: # Overworld_IsBikingAllowed.
	if engine != &"ruby":
		return bool(header.get("allow_cycling", false))
	if map in RUBY_CYCLING_ENTRANCES:
		return true
	return int(header.get("map_type", 0)) not in RUBY_NO_CYCLING_TYPES and map not in RUBY_NO_CYCLING


func initial_flags(stored: int, map: Vector2i, header: Dictionary, surfable: bool) -> int: # GetAdjustedInitialTransitionFlags over [param stored], one flag as `StoreInitialPlayerAvatarState` keeps it.
	var map_type: int = int(header.get("map_type", 0))
	if map_type != MAP_TYPE_INDOOR and _events.flag_get(flags["cruise"]):
		return Gen3PlayerAvatar.Flag.ON_FOOT
	if map_type == MAP_TYPE_UNDERWATER:
		return Gen3PlayerAvatar.Flag.UNDERWATER
	if surfable and engine == &"firered" and map in FRLG_SEAFOAM_ON_FOOT:
		return Gen3PlayerAvatar.Flag.ON_FOOT
	if surfable:
		return Gen3PlayerAvatar.Flag.SURFING
	if not biking_allowed(map, header) or stored not in [Gen3PlayerAvatar.Flag.MACH_BIKE, Gen3PlayerAvatar.Flag.ACRO_BIKE]:
		return Gen3PlayerAvatar.Flag.ON_FOOT
	return stored


func initial_direction(stored_direction: int, stored_flags: int, initial: int, behavior: int, map_type: int) -> int: # GetAdjustedInitialDirection, [param initial] being what [method initial_flags] returned.
	if map_type == MAP_TYPE_OCEAN_ROUTE and _events.flag_get(flags["cruise"]):
		return Gen3ObjectEvents.Direction.EAST
	if engine != &"firered" and behavior == DEEP_SOUTH_WARP:
		return Gen3ObjectEvents.Direction.NORTH
	if is_non_anim_door(behavior) or is_door(behavior):
		return Gen3ObjectEvents.Direction.SOUTH
	for direction: int in range(Gen3ObjectEvents.Direction.SOUTH, Gen3ObjectEvents.Direction.EAST + 1):
		if behavior in arrow_warps(direction):
			return Gen3ObjectEvents.OPPOSITE[direction]
	if engine == &"firered" and FRLG_STAIR_EXITS.has(behavior):
		return FRLG_STAIR_EXITS[behavior]
	var water: Array[int] = [Gen3PlayerAvatar.Flag.SURFING, Gen3PlayerAvatar.Flag.UNDERWATER]
	if stored_flags in water and initial in water and stored_flags != initial or behavior == LADDER:
		return stored_direction
	return Gen3ObjectEvents.Direction.SOUTH


func warp_mode(behavior: int) -> String:
	if engine == &"firered":
		return String(FRLG_WARPS.get(behavior, ""))
	return String(HOENN_WARPS.get(behavior, EMERALD_WARPS.get(behavior, "") if engine == &"emerald" else ""))


func metatile_script(behavior: int, direction: int, same_elevation: bool) -> String: # GetInteractedMetatileScript.
	if behavior in NORTH_ONLY[engine] and direction != Gen3ObjectEvents.Direction.NORTH:
		return ""
	if engine == &"firered":
		return String(FRLG_METATILES.get(behavior, ""))
	if behavior in HOENN_METATILES:
		return HOENN_METATILES[behavior]
	if engine == &"emerald" and behavior in EMERALD_METATILES:
		return EMERALD_METATILES[behavior]
	return String(SECRET_BASE_METATILES.get(behavior, "")) if same_elevation else ""


func sign_script(behavior: int, direction: int) -> String: # GetFacingSignpostType's fixed signs, all FireRed.
	if behavior in NORTH_ONLY[engine] and direction != Gen3ObjectEvents.Direction.NORTH:
		return ""
	return String(FRLG_SIGNS.get(behavior, ""))


func silent_script(key: String) -> bool: # TryStartInteractionScript plays SE_SELECT for all but the PCs.
	return key in ["pc", "brendan_pc", "may_pc", "secret_base_pc", "record_mixing_pc"] \
		or engine == &"emerald" and key in ["sand_ornament", "shield_or_toy_tv"]


func hidden_item_flag(row: Dictionary) -> int:
	return int(flags["hidden"]) + int(row["hidden_item_id"])


func dive_kind(behavior: int, map_type: int) -> int: # TrySetDiveWarp's tests, before its warp lookup: a connection type or 0.
	if map_type == MAP_TYPE_UNDERWATER and behavior not in HOENN_UNABLE_TO_EMERGE:
		return CONNECTION_EMERGE
	return CONNECTION_DIVE if behavior in HOENN_DIVEABLE else 0


func step_script(map_type: int, forced: bool, requests: Array) -> String: # TryStartStepCountScript: a script to start, or empty. Ruby ignores [param forced].
	_events.var_set(flags["friendship"], (_events.var_get(flags["friendship"]) + 1) % 128)
	if _events.var_get(flags["friendship"]) == 0:
		requests.append({"kind": "party_walk_friendship"})
	if not forced or engine == &"ruby":
		if _poison_step(map_type, requests):
			return "field_poison"
		var call: String = _story_call(map_type) if engine == &"emerald" else ""
		if not call.is_empty():
			return call
	if _events.flag_get(flags["safari"]):
		safari_steps -= 1
		if safari_steps == 0:
			return "safari_times_up"
	return _cruise_step()


func repel_script(forced: bool) -> String: # UpdateRepelCounter; FireRed's caller tests forced tiles.
	var steps: int = _events.var_get(flags["repel"])
	if steps == 0 or engine == &"firered" and forced:
		return ""
	_events.var_set(flags["repel"], steps - 1)
	return "repel_wore_off" if steps == 1 else ""


func enter_safari() -> void: # EnterSafariMode's step count; balls belong to battle.
	_events.flag_set(flags["safari"])
	safari_steps = SAFARI_STEPS[engine]


func exit_safari() -> void:
	_events.flag_clear(flags["safari"])
	safari_steps = 0


func _poison_step(map_type: int, requests: Array) -> bool: # UpdatePoisonStepCounter and field_poison.c::DoPoisonFieldEffect.
	if map_type == MAP_TYPE_SECRET_BASE:
		return false
	_events.var_set(flags["poison"], (_events.var_get(flags["poison"]) + 1) % POISON_PERIOD[engine])
	if _events.var_get(flags["poison"]) != 0:
		return false
	var poisoned: int = 0
	var fainted: int = 0
	for mon: Dictionary in _events.party:
		if int(mon.get("status", 0)) & STATUS_POISONED == 0:
			continue
		mon["hp"] = maxi(int(mon["hp"]) - 1, 0)
		poisoned += 1
		fainted += int(mon["hp"] == 0)
	if poisoned != 0:
		requests.append({"kind": "poison_flash"})
	return fainted != 0


func _story_call(map_type: int) -> String:
	for row: Array in STORY_CALLS:
		if _events.flag_get(row[0]) and map_type in CALL_MAP_TYPES:
			_events.var_set(row[1], _events.var_get(row[1]) + 1)
			if _events.var_get(row[1]) >= int(row[2]):
				return row[3]
	return ""


func _cruise_step() -> String: # CountSSTidalStep; FireRed has no such step.
	if not flags.has("cruise_steps") or not _events.flag_get(flags["cruise"]):
		return ""
	_events.var_set(flags["cruise_steps"], _events.var_get(flags["cruise_steps"]) + 1)
	return "ss_tidal_step" if _events.var_get(flags["cruise_steps"]) >= SS_TIDAL_MAX_STEPS else ""
