class_name Gen2WorldRadio
extends RefCounted

## The Pokegear radio card's tuning knob, its station table, and the music each
## station leaves in `wMapMusic`. Scene-free and stateless: a caller passes the
## knob position and the facts the source reads off WRAM and gets back the station
## that answers. Modelled here: `UpdateRadioStation`, `RadioChannels`, each
## handler's availability check, `LoadStation_*`, `PlayRadioShow`'s Rocket override
## and `StartRadioStation`'s music commit. The words a station prints are
## [Gen2RadioShow]. Channel ids are Crystal-canonical, so Gold and Silver's own
## ids from PLACES_AND_PEOPLE on sit one lower; `raw_channel()` converts.

## constants/radio_constants.asm.
const OAKS_POKEMON_TALK: int = 0
const POKEDEX_SHOW: int = 1
const POKEMON_MUSIC: int = 2
const LUCKY_CHANNEL: int = 3
const BUENAS_PASSWORD: int = 4
const PLACES_AND_PEOPLE: int = 5
const LETS_ALL_SING: int = 6
const ROCKET_RADIO: int = 7
const POKE_FLUTE_RADIO: int = 8
const UNOWN_RADIO: int = 9
const EVOLUTION_RADIO: int = 10
const NUM_RADIO_CHANNELS: int = 11
const NUM_RADIO_CHANNELS_GOLD_SILVER: int = 10

## data/radio/channel_music.asm's RadioChannelSongs, by canonical channel id.
## The Gold/Silver table is this one without its Buena's row, so indexing by
## channel rather than by position keeps one copy.
const CHANNEL_SONGS: Array[int] = [
	29,  # MUSIC_POKEMON_TALK
	9,   # MUSIC_POKEMON_CENTER
	1,   # MUSIC_TITLE
	18,  # MUSIC_GAME_CORNER
	96,  # MUSIC_BUENAS_PASSWORD, Crystal only
	21,  # MUSIC_VIRIDIAN_CITY
	19,  # MUSIC_BICYCLE
	86,  # MUSIC_ROCKET_OVERTURE
	64,  # MUSIC_POKE_FLUTE_CHANNEL
	75,  # MUSIC_RUINS_OF_ALPH_RADIO
	90,  # MUSIC_LAKE_OF_RAGE_ROCKET_RADIO
]
const MUSIC_POKE_FLUTE_CHANNEL: int = 64
## constants/music_constants.asm. Neither is a real track: they are the two
## sentinels `ExitPokegearRadio_HandleMusic` compares
## `wPokegearRadioMusicPlaying` against, which is why a tuned station's own id
## falls through both branches and keeps playing once the Pokegear closes.
const RESTART_MAP_MUSIC: int = 0xFE
const ENTER_MAP_MUSIC: int = 0xFF

## The knob is a byte stepped two at a time and capped at 80 by
## UpdateRadioStation's caller (`cp 80 / ret nc / inc [hl] / inc [hl]`).
const KNOB_MIN: int = 0
const KNOB_MAX: int = 80
const KNOB_STEP: int = 2

## constants/landmark_constants.asm, Crystal-canonical. The two tables differ by
## exactly one insertion, LANDMARK_BATTLE_TOWER inside the Johto run, so every
## landmark from it onward is one higher than Gold and Silver's and
## `profile_landmark()` is the whole conversion.
const LANDMARK_BATTLE_TOWER: int = 29
const KANTO_LANDMARK: int = 47
const LANDMARK_FAST_SHIP: int = 95
const LANDMARK_SPECIAL: int = 0
const LANDMARK_RUINS_OF_ALPH: int = 9
const LANDMARK_MAHOGANY_TOWN: int = 36
const LANDMARK_ROUTE_43: int = 37
const LANDMARK_LAKE_OF_RAGE: int = 38

## `wTimeOfDay`: .PKMNTalkAndPokedexShow runs the Pokedex Show in the morning and
## Oak's Talk the rest of the day.
const TIME_MORNING: int = 0

## engine/pokegear/pokegear.asm's RadioChannels, in table order. `knob` is the
## stored frequency value, `4 x ingame_frequency - 2`; `rule` names the check
## the handler runs before its LoadStation_ call. Two rows are profile split:
## Gold and Silver ship no Buena's Password row at all, and their Places &
## People and Let's All Sing handlers check the region but not the EXPN card.
const CHANNELS: Array[Dictionary] = [
	{"knob": 16, "rule": &"johto_talk"},
	{"knob": 28, "rule": &"johto", "channel": POKEMON_MUSIC},
	{"knob": 32, "rule": &"johto", "channel": LUCKY_CHANNEL},
	{"knob": 40, "rule": &"johto", "channel": BUENAS_PASSWORD, "crystal_only": true},
	{"knob": 52, "rule": &"ruins_of_alph", "channel": UNOWN_RADIO},
	{"knob": 64, "rule": &"kanto", "channel": PLACES_AND_PEOPLE, "crystal_expn": true},
	{"knob": 72, "rule": &"kanto", "channel": LETS_ALL_SING, "crystal_expn": true},
	{"knob": 78, "rule": &"kanto", "channel": POKE_FLUTE_RADIO, "expn": true},
	{"knob": 80, "rule": &"rocket_signal", "channel": EVOLUTION_RADIO},
]

## The strings LoadStation_* leaves in `de` for UpdateRadioStation to place under
## the dial, identical in both pins. `LoadStation_RocketRadio` really does reuse
## Let's All Sing's, though only `PlayRadioStationPointers` reaches it and a map
## radio prints no name. `LoadStation_BuenasPassword` answers with
## `NotBuenasPasswordName`, an empty string, until Team Rocket takes the tower.
##
## `.returnafterstation` places this before `PlayRadioShow` runs, so the name is
## the station the dial is on and never the Rocket broadcast standing in for it.
const STATION_NAMES: Dictionary = {
	OAKS_POKEMON_TALK: "OAK's <PK><MN> Talk",
	POKEDEX_SHOW: "#DEX Show",
	POKEMON_MUSIC: "#MON Music",
	LUCKY_CHANNEL: "Lucky Channel",
	BUENAS_PASSWORD: "BUENA'S PASSWORD",
	PLACES_AND_PEOPLE: "Places & People",
	LETS_ALL_SING: "Let's All Sing!",
	ROCKET_RADIO: "Let's All Sing!",
	POKE_FLUTE_RADIO: "# FLUTE",
	UNOWN_RADIO: "?????",
	EVOLUTION_RADIO: "?????",
}


## Every knob position the dial can stop on.
static func knob_values() -> Array[int]:
	var values: Array[int] = []
	var knob: int = KNOB_MIN
	while knob <= KNOB_MAX:
		values.append(knob)
		knob += KNOB_STEP
	return values


## The frequency the dial shows for a stored knob value.
static func frequency_for(knob: int) -> float:
	return (knob + 2) / 4.0


static func channel_count(crystal: bool = true) -> int:
	return NUM_RADIO_CHANNELS if crystal else NUM_RADIO_CHANNELS_GOLD_SILVER


## The cartridge's own id for a canonical channel, or -1 where the profile has
## no such channel.
static func raw_channel(channel: int, crystal: bool = true) -> int:
	if crystal or channel < BUENAS_PASSWORD:
		return channel
	return -1 if channel == BUENAS_PASSWORD else channel - 1


## A Crystal landmark index on the active profile.
static func profile_landmark(landmark: int, crystal: bool = true) -> int:
	if crystal or landmark < LANDMARK_BATTLE_TOWER:
		return landmark
	return landmark - 1


static func kanto_landmark(crystal: bool = true) -> int:
	return profile_landmark(KANTO_LANDMARK, crystal)


static func fast_ship_landmark(crystal: bool = true) -> int:
	return profile_landmark(LANDMARK_FAST_SHIP, crystal)


## `IsInJohto` and the Pokegear's own `.InJohto`, which agree once the landmark
## has been resolved: the Fast Ship counts as Johto and everything from
## KANTO_LANDMARK up is Kanto.
static func is_kanto_landmark(landmark: int, crystal: bool = true) -> bool:
	if landmark == fast_ship_landmark(crystal):
		return false
	return landmark >= kanto_landmark(crystal)


## The station a knob position answers with, or a no-signal result.
##
## [param context] carries what the source reads off WRAM: `landmark` (already
## resolved through GetWorldMapLocation), `crystal`, `expn_card`,
## `rocket_signal`, `rockets_in_radio_tower` and `time_of_day`.
static func station_for(knob: int, context: Dictionary = {}) -> Dictionary:
	var crystal: bool = bool(context.get("crystal", true))
	var entry: Dictionary = {}
	for candidate: Dictionary in CHANNELS:
		if int(candidate["knob"]) != knob:
			continue
		if bool(candidate.get("crystal_only", false)) and not crystal:
			break
		entry = candidate
		break
	if entry.is_empty():
		return _no_signal(knob)
	var channel: int = _channel_for_rule(entry, context)
	if channel < 0:
		return _no_signal(knob)
	var name: String = _station_name(channel, context)
	channel = _rocket_override(channel, context)
	return {
		"ok": true,
		"knob": knob,
		"frequency": frequency_for(knob),
		"channel": channel,
		"raw_channel": raw_channel(channel, crystal),
		"music": CHANNEL_SONGS[channel],
		"name": name,
	}


## The knob position a channel is carried on, or -1 where this profile has none.
## Below, `PlayRadioStationPointers`, the nine `MAPRADIO_*` rows a
## `special MapRadio` indexes. Only two are reachable: `Radio1Script` names the
## Pokemon Channel and `Radio2Script` the Lucky Channel, and those two std scripts
## are every radio on every map. `LoadStation_PokemonChannel` is a branch rather
## than a station: Kanto reads Places and People, a Johto morning the Pokedex Show,
## and any other Johto hour Oak's Pokemon Talk.
const MAP_RADIO_STATIONS: Array[int] = [
	-1, OAKS_POKEMON_TALK, POKEDEX_SHOW, POKEMON_MUSIC, LUCKY_CHANNEL,
	UNOWN_RADIO, PLACES_AND_PEOPLE, LETS_ALL_SING, ROCKET_RADIO,
]


static func map_radio_channel(station: int, kanto: bool, time_of_day: int) -> int:
	if station < 0 or station >= MAP_RADIO_STATIONS.size():
		return -1
	if station > 0:
		return MAP_RADIO_STATIONS[station]
	if kanto:
		return PLACES_AND_PEOPLE
	## `wTimeOfDay`'s own zero is MORN.
	return POKEDEX_SHOW if time_of_day == 0 else OAKS_POKEMON_TALK


static func knob_for_channel(channel: int, crystal: bool = true) -> int:
	for entry: Dictionary in CHANNELS:
		if bool(entry.get("crystal_only", false)) and not crystal:
			continue
		if int(entry.get("channel", -1)) == channel:
			return int(entry["knob"])
	return -1


## Each RadioChannels handler's own check, returning the channel it loads or -1
## for its .NoSignal branch.
static func _channel_for_rule(entry: Dictionary, context: Dictionary) -> int:
	var crystal: bool = bool(context.get("crystal", true))
	var landmark: int = int(context.get("landmark", LANDMARK_SPECIAL))
	var kanto: bool = is_kanto_landmark(landmark, crystal)
	match StringName(entry["rule"]):
		&"johto_talk":
			if kanto:
				return -1
			return POKEDEX_SHOW if int(context.get("time_of_day", TIME_MORNING)) == TIME_MORNING \
				else OAKS_POKEMON_TALK
		&"johto":
			return -1 if kanto else int(entry["channel"])
		&"kanto":
			if not kanto:
				return -1
			var wants_expn: bool = bool(entry.get("expn", false)) \
				or (crystal and bool(entry.get("crystal_expn", false)))
			if wants_expn and not bool(context.get("expn_card", false)):
				return -1
			return int(entry["channel"])
		&"ruins_of_alph":
			return int(entry["channel"]) if landmark == LANDMARK_RUINS_OF_ALPH else -1
		&"rocket_signal":
			if not bool(context.get("rocket_signal", false)):
				return -1
			var lake: Array[int] = [
				profile_landmark(LANDMARK_MAHOGANY_TOWN, crystal),
				profile_landmark(LANDMARK_ROUTE_43, crystal),
				profile_landmark(LANDMARK_LAKE_OF_RAGE, crystal),
			]
			return int(entry["channel"]) if landmark in lake else -1
	return -1


## PlayRadioShow's own preamble: while Team Rocket holds the tower, every Johto
## station below the Poke Flute channel broadcasts Rocket Radio instead. The
## three at or above it are untouched, which is why the Poke Flute channel still
## answers during the takeover.
## The name the tuned station places, which is `LoadStation_*`'s own `de` and so
## is read before the Rocket broadcast replaces the programme.
static func _station_name(channel: int, context: Dictionary) -> String:
	if channel == BUENAS_PASSWORD \
		and not bool(context.get("rockets_in_radio_tower", false)):
		return ""
	return String(STATION_NAMES.get(channel, ""))


static func _rocket_override(channel: int, context: Dictionary) -> int:
	if channel >= POKE_FLUTE_RADIO:
		return channel
	if not bool(context.get("rockets_in_radio_tower", false)):
		return channel
	if is_kanto_landmark(
		int(context.get("landmark", LANDMARK_SPECIAL)), bool(context.get("crystal", true))
	):
		return channel
	return ROCKET_RADIO


static func _no_signal(knob: int) -> Dictionary:
	return {
		"ok": false,
		"reason": &"no_signal",
		"knob": knob,
		"frequency": frequency_for(knob) if knob >= 0 else 0.0,
		"channel": -1,
		"raw_channel": -1,
		"music": -1,
		"name": "",
	}
