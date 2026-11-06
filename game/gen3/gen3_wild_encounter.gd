class_name Gen3WildEncounter
extends RefCounted # `wild_encounter.c`'s standard encounters and `field_control_avatar.c`'s immunity steps. Roamers, outbreaks, Feebas and the frontier wait on their own records.

const MAX_RATE: int = 1600
const IMMUNITY_STEPS: int = 4
const NEW_METATILE_ODDS: int = 60 # AllowWildCheckOnNewMetatile.
const BIKE_FLAGS: int = Gen3PlayerAvatar.Flag.MACH_BIKE | Gen3PlayerAvatar.Flag.ACRO_BIKE
const BRIDGES: Dictionary = { # `MetatileBehavior_IsBridgeOverWater` and Ruby's `_IsBridge`; FireRed's is a stub.
	&"ruby": [0x70, 0x71, 0x72, 0x73], &"firered": [], &"emerald": [0x70, 0x71, 0x72, 0x73, 0x7C, 0x7D, 0x7E, 0x7F]}
const FLUTE_FLAGS: Dictionary = {&"ruby": [0x84D, 0x84E], &"firered": [0x803, 0x804], &"emerald": [0x8AD, 0x8AE]} # `FLAG_SYS_ENC_UP_ITEM`, `_DOWN_ITEM`.
const ALTERING_CAVE_VAR: Dictionary = {&"firered": 0x4024, &"emerald": 0x403E}
const SOOTOPOLIS: Vector2i = Vector2i(0, 7)
const LEGENDARIES_IN_SOOTOPOLIS: int = 0x53
const ENCOUNTER_TYPE_SHIFT: int = 24 # METATILE_ATTRIBUTE_ENCOUNTER_TYPE.
const ENCOUNTER_LAND: int = 1
const ENCOUNTER_WATER: int = 2
const CLEANSE_TAG: int = 190
const SANDSTORM: int = 8
const TYPE_STEEL: int = 8
const TYPE_ELECTRIC: int = 13
const STENCH: int = 1
const SAND_VEIL: int = 8
const STATIC: int = 9
const INTIMIDATE: int = 22
const ILLUMINATE: int = 35
const MAGNET_PULL: int = 42
const PRESSURE: int = 46
const KEEN_EYE: int = 51
const HUSTLE: int = 55
const ARENA_TRAP: int = 71
const VITAL_SPIRIT: int = 72
const WHITE_SMOKE: int = 73

var disabled: bool = false # `sWildEncountersDisabled`.
var _data: GameData
var _events: Gen3EventData
var _engine: StringName
var _steps: int = 0 # `sWildEncounterImmunitySteps`; FireRed's `stepsSinceLastEncounter`.
var _previous: int = 0
var _rate_buff: int = 0
var _frlg_rng: int = 0 # `sWildEncounterData.rngState`, its own stream on FireRed.


func _init(data: GameData, events: Gen3EventData, engine: StringName) -> void:
	_data = data
	_events = events
	_engine = engine
	_frlg_rng = events.random.value >> 16 # SeedWildEncounterRng(Random()), without moving the stream the field shares.


func restart_immunity() -> void: # RestartWildEncounterImmunitySteps, after a warp or a battle.
	_rate_buff = 0
	_steps = 0


func check(map: Vector2i, behavior: int, attributes: int, avatar_flags: int) -> Dictionary: # CheckStandardWildEncounter: the `species`, `level` and `area` to fight, empty for none.
	if _engine == &"firered":
		return _check_frlg(map, behavior, attributes, avatar_flags)
	if _steps < IMMUNITY_STEPS:
		_steps += 1
		_previous = behavior
		return {}
	var previous: int = _previous
	_previous = behavior
	var mon: Dictionary = _standard(map, behavior, previous, avatar_flags)
	if not mon.is_empty():
		_steps = 0
		if _engine == &"emerald":
			_previous = 0
	return mon


func _standard(map: Vector2i, behavior: int, previous: int, avatar_flags: int) -> Dictionary: # StandardWildEncounter.
	if disabled:
		return {}
	var encounters: bool = _data.world_encounter_tile(behavior)
	var water: bool = _data.world_surfable(behavior)
	if encounters and not water:
		return _attempt("land", map, behavior, previous, avatar_flags)
	if encounters and water or avatar_flags & Gen3PlayerAvatar.Flag.SURFING and behavior in BRIDGES[_engine]:
		if _engine == &"emerald" and map == SOOTOPOLIS and _events.flag_get(LEGENDARIES_IN_SOOTOPOLIS):
			return {}
		return _attempt("surf", map, behavior, previous, avatar_flags)
	return {}


func _attempt(method: StringName, map: Vector2i, behavior: int, previous: int, avatar_flags: int) -> Dictionary:
	var info: Dictionary = _info(method, map)
	if info.is_empty() or previous != behavior and _events.random.next() % 100 >= NEW_METATILE_ODDS:
		return {}
	if not _rate_test(int(info["rate"]), avatar_flags):
		return {}
	return _generate(info, method)


func _check_frlg(map: Vector2i, behavior: int, attributes: int, avatar_flags: int) -> Dictionary: # TryStandardWildEncounter.
	var type: int = (attributes >> ENCOUNTER_TYPE_SHIFT) & 7
	var method: StringName = &"land" if type == ENCOUNTER_LAND else &"surf"
	var info: Dictionary = _info(method, map) if type in [ENCOUNTER_LAND, ENCOUNTER_WATER] else {}
	if info.is_empty() or disabled or not _cooldown_passed(int(info["rate"])):
		_previous = behavior
		return {}
	var previous: int = _previous
	_previous = behavior
	if previous != behavior and _events.random.next() % 100 >= NEW_METATILE_ODDS:
		return {}
	var rate: int = int(info["rate"])
	var mon: Dictionary = _generate(info, method) if _rate_test(rate, avatar_flags) else {}
	if mon.is_empty():
		_rate_buff += rate
	else:
		_rate_buff = 0
		_steps = 0
	return mon


func _cooldown_passed(encounter_rate: int) -> bool: # HandleWildEncounterCooldown, in its 256ths.
	var base: int = 0 if encounter_rate >= 80 else (8 if encounter_rate < 10 else 8 - encounter_rate / 10)
	var min_steps: int = base * 256
	var odds: int = 5 * 256
	var flute: int = _flute()
	if flute > 0:
		min_steps -= min_steps / 2
		odds += odds / 2
	elif flute < 0:
		min_steps *= 2
		odds /= 2
	if int(_lead().get("item", 0)) == CLEANSE_TAG:
		min_steps += min_steps / 3
		odds -= odds / 3
	var ability: int = _ability()
	if ability == STENCH:
		min_steps *= 2
		odds /= 2
	elif ability == ILLUMINATE:
		min_steps /= 2
		odds *= 2
	if _steps >= min_steps / 256:
		return true
	_steps += 1
	return _events.random.next() % 100 < odds / 256


func _flute() -> int: # ApplyFluteEncounterRateMod's two flags: above zero the White Flute, below it the Black.
	var flags: Array = FLUTE_FLAGS[_engine]
	return 1 if _events.flag_get(int(flags[0])) else (-1 if _events.flag_get(int(flags[1])) else 0)


func _rate_test(base: int, avatar_flags: int) -> bool: # WildEncounterCheck.
	var rate: int = base * 16
	if avatar_flags & BIKE_FLAGS:
		rate = rate * 80 / 100
	if _engine == &"firered":
		rate += _rate_buff * 16 / 200
	var flute: int = _flute()
	rate += rate / 2 if flute > 0 else (-rate + rate / 2 if flute < 0 else 0)
	if int(_lead().get("item", 0)) == CLEANSE_TAG:
		rate = rate * 2 / 3
	rate = mini(_ability_rate(rate), MAX_RATE)
	return _rate_roll() % MAX_RATE < rate


func _ability_rate(rate: int) -> int:
	var ability: int = _ability()
	if ability == STENCH:
		return rate / 2
	if ability == ILLUMINATE:
		return rate * 2
	if _engine != &"emerald":
		return rate
	if ability == WHITE_SMOKE:
		return rate / 2
	if ability == ARENA_TRAP:
		return rate * 2
	return rate / 2 if ability == SAND_VEIL and _events.weather == SANDSTORM else rate


func _rate_roll() -> int: # FireRed's WildEncounterRandom: ISO_RANDOMIZE2 on a stream of its own.
	if _engine != &"firered":
		return _events.random.next()
	_frlg_rng = (_frlg_rng * 0x41C64E6D + 12345) & 0xFFFFFFFF
	return _frlg_rng >> 16


func _generate(info: Dictionary, method: StringName) -> Dictionary: # TryGenerateWildMon with WILD_CHECK_REPEL and, on Emerald, WILD_CHECK_KEEN_EYE.
	var slots: Array = info["slots"]
	var index: int = _influenced_slot(slots, method)
	if index < 0:
		index = _roll_slot(slots)
	var row: Dictionary = slots[index]
	var level: int = _level(row)
	if not _allowed_by_repel(level) or _engine == &"emerald" and _keen_eye_refuses(level):
		return {}
	return {"species": int(row["species"]), "level": level, "area": String(method)}


func _influenced_slot(slots: Array, method: StringName) -> int: # TryGetAbilityInfluencedWildMonIndex; pret's non-BUGFIX build scans 12 water rows, past the table's five.
	if _engine != &"emerald":
		return -1
	if method == &"land":
		var pulled: int = _typed_slot(slots, TYPE_STEEL, MAGNET_PULL)
		if pulled >= 0:
			return pulled
	return _typed_slot(slots, TYPE_ELECTRIC, STATIC)


func _typed_slot(slots: Array, type: int, ability: int) -> int:
	if _ability() != ability or _events.random.next() % 2 != 0:
		return -1
	var matches: Array[int] = []
	for index: int in slots.size():
		var types: Array = _data.species(int(slots[index]["species"])).get("types", [0, 0])
		if int(types[0]) == type or int(types[1]) == type:
			matches.append(index)
	if matches.is_empty() or matches.size() == slots.size():
		return -1
	return matches[_events.random.next() % matches.size()]


func _roll_slot(slots: Array) -> int: # ChooseWildMonIndex_Land and _WaterRock: `gWildMon*Chances` total 100.
	var roll: int = _events.random.next() % 100
	var sum: int = 0
	for index: int in slots.size():
		sum += int(slots[index]["chance"])
		if roll < sum:
			return index
	return slots.size() - 1


func _level(row: Dictionary) -> int: # ChooseWildMonLevel.
	var low: int = mini(int(row["min_level"]), int(row["max_level"]))
	var high: int = maxi(int(row["min_level"]), int(row["max_level"]))
	var roll: int = _events.random.next() % (high - low + 1)
	if _engine == &"emerald" and _ability() in [HUSTLE, VITAL_SPIRIT, PRESSURE]:
		if _events.random.next() % 2 == 0:
			return high
		if roll != 0:
			roll -= 1
	return low + roll


func _allowed_by_repel(level: int) -> bool: # IsWildLevelAllowedByRepel.
	if _events.var_get(int(Gen3FieldInput.FLAGS[_engine]["repel"])) == 0:
		return true
	for mon: Dictionary in _events.party:
		if int(mon.get("hp", 0)) > 0 and not mon.get("egg", false):
			return level >= int(mon.get("level", 0))
	return false


func _keen_eye_refuses(level: int) -> bool: # IsAbilityAllowingEncounter.
	var ours: int = int(_lead().get("level", 0))
	return _ability() in [KEEN_EYE, INTIMIDATE] and ours > 5 and level <= ours - 5 and _events.random.next() % 2 == 0


func _info(method: StringName, map: Vector2i) -> Dictionary: # GetCurrentMapWildMonHeaderId, which offsets Altering Cave's row by its set.
	var variant: int = 0
	if _data.world_encounter_variant_count(method, map.x, map.y) > 1 and ALTERING_CAVE_VAR.has(_engine):
		variant = _events.var_get(int(ALTERING_CAVE_VAR[_engine]))
		variant = variant if variant < _data.world_encounter_variant_count(method, map.x, map.y) else 0
	return _data.world_encounter(method, map.x, map.y, variant)


func _lead() -> Dictionary:
	return _events.party[0] if not _events.party.is_empty() else {}


func _ability() -> int: # GetMonAbility of the first slot, none for an egg.
	var lead: Dictionary = _lead()
	if lead.is_empty() or lead.get("egg", false):
		return 0
	var abilities: Array = _data.species(int(lead["species"])).get("abilities", [])
	var slot: int = int(lead.get("ability_slot", 0))
	if abilities.is_empty():
		return 0
	return int(abilities[slot]) if slot < abilities.size() and int(abilities[slot]) != 0 else int(abilities[0])
