class_name Gen1SramWorld
extends RefCounted

## The trainer half of a Generation 1 `.sav`: `sPlayerName` and `sMainData`
## (`wMainDataStart` .. `wMainDataEnd`). All three games agree below but for
## Yellow's Pikachu fields; `test_gen1_sram.gd` pins them to `Gen1Layout`.

const NAME_AT: int = 0x2598
const MAIN_AT: int = 0x25A3

const DEX_AT: int = MAIN_AT
const DEX_BYTES: int = 19
const BAG_AT: int = MAIN_AT + 0x26
const BAG_CAPACITY: int = 20
const MONEY_AT: int = MAIN_AT + 0x50
const RIVAL_NAME_AT: int = MAIN_AT + 0x53
const BADGES_AT: int = MAIN_AT + 0x5F
const PLAYER_ID_AT: int = MAIN_AT + 0x62
const MAP_PAL_OFFSET_AT: int = MAIN_AT + 0x66
const CUR_MAP_AT: int = MAIN_AT + 0x67
const VIEW_POINTER_AT: int = MAIN_AT + 0x68
const Y_AT: int = MAIN_AT + 0x6A
const X_AT: int = MAIN_AT + 0x6B
const Y_BLOCK_AT: int = MAIN_AT + 0x6C
const X_BLOCK_AT: int = MAIN_AT + 0x6D
const LAST_MAP_AT: int = MAIN_AT + 0x6E
const PC_AT: int = MAIN_AT + 0x243
const PC_CAPACITY: int = 50
const CURRENT_BOX_AT: int = MAIN_AT + 0x2A9
const HOF_TEAMS_AT: int = MAIN_AT + 0x2AB
const COINS_AT: int = MAIN_AT + 0x2AD
const TOGGLES_AT: int = MAIN_AT + 0x2AF
const TOGGLE_COUNT: int = 256
const MAP_SCRIPTS_AT: int = MAIN_AT + 0x2F9
const MAP_SCRIPT_BYTES: int = Gen1Layout.MAP_SCRIPT_BYTES
const WALK_BIKE_SURF_AT: int = MAIN_AT + 0x409
const SAFARI_STEPS_AT: int = MAIN_AT + 0x416
const FOSSIL_AT: int = MAIN_AT + 0x418
const STARTERS_AT: int = MAIN_AT + 0x41E
const PLAYER_STARTER_AT: int = MAIN_AT + 0x420
const LAST_BLACKOUT_AT: int = MAIN_AT + 0x422
const STATUS_FLAGS_6_AT: int = MAIN_AT + 0x43B
const TRADES_AT: int = MAIN_AT + 0x440
const CARD_KEY_AT: int = MAIN_AT + 0x448
const LOCKS_AT: int = MAIN_AT + 0x44C
const EVENT_FLAGS_AT: int = MAIN_AT + 0x450
const PLAY_TIME_AT: int = MAIN_AT + 0x74A
const SAFARI_BALLS_AT: int = MAIN_AT + 0x750
const DAY_CARE_AT: int = MAIN_AT + 0x751
const DAY_CARE_NAME_AT: int = MAIN_AT + 0x752
const DAY_CARE_OT_AT: int = MAIN_AT + 0x75D
const DAY_CARE_MON_AT: int = MAIN_AT + 0x768

## Yellow's `wPikachu*` and `wSurfingMinigameHiScore`, padding elsewhere.
const PIKACHU_FLAGS_AT: int = MAIN_AT + 0x139
const PIKACHU_HAPPINESS_AT: int = MAIN_AT + 0x179
const PIKACHU_EMOTION_AT: int = MAIN_AT + 0x1A5
const SURF_SCORE_AT: int = MAIN_AT + 0x19E
## The two `wPikachuOverworldStateFlags` bits a map keeps.
const PIKACHU_KEPT_FLAGS: int = 0x0A

## `Gen1Layout.ENGINE_FLAG_BYTES`' runs, numbered by `engine_flag_base`.
const FLAG_RUNS: Dictionary = {
	"status_flags_4": MAIN_AT + 0x437,
	"obtained_hidden_items": MAIN_AT + 0x3F9,
	"obtained_hidden_coins": MAIN_AT + 0x407,
	"town_visited": MAIN_AT + 0x414,
	"status_flags_1": MAIN_AT + 0x431,
	"elite_4_flags": MAIN_AT + 0x43D,
	"beat_gym_flags": MAIN_AT + 0x433,
	"pikachu_map_script_flags": MAIN_AT + 0x19C,
}
const YELLOW_RUN: String = "pikachu_map_script_flags"

## `wOverworldMap`, which `wCurrentTileBlockMapViewPointer` points into.
const OVERWORLD_MAP: int = 0xC6E8
const MAP_BORDER: int = 3
const WALK: int = 0
const BIKE: int = 1
const SURF: int = 2
const SECOND_LOCK_ALT: String = "second_lock_trash_can_alt"
const SAVED_BYTES: Array[String] = [
	"first_lock_trash_can", "second_lock_trash_can", SECOND_LOCK_ALT,
	"surf_hi_score_low", "surf_hi_score_high",
]
## Script scratch the port saves and the cartridge does not: cleared WRAM, and
## the map header `LoadMapHeader` rewrites on CONTINUE.
const VOLATILE_BYTES: Array[String] = ["lucky_slot_index", "cur_map_text_ptr_high"]


static func read(ctx: Gen1SramContext, save: Gen2SaveData) -> void:
	save.player_name = Gen1SramMons.read_name(ctx, NAME_AT)
	save.player_id = ctx.u16(PLAYER_ID_AT)
	save.game_time = PokeGameTime.create(
		ctx.u8(PLAY_TIME_AT), ctx.u8(PLAY_TIME_AT + 2), ctx.u8(PLAY_TIME_AT + 3),
		ctx.u8(PLAY_TIME_AT + 4), ctx.u8(PLAY_TIME_AT + 1) != 0
	)
	var world := Gen2WorldSnapshot.new()
	_read_position(ctx, world)
	world.rival_name = Gen1SramMons.read_name(ctx, RIVAL_NAME_AT)
	world.gen1_fossil = _read_fossil(ctx)
	if ctx.game_id == RomRegistry.YELLOW:
		world.gen1_pikachu = _read_pikachu(ctx)
	world.world_state = Gen2WorldState.from_dict(_read_state(ctx))
	save.world = world


static func _read_position(ctx: Gen1SramContext, world: Gen2WorldSnapshot) -> void:
	world.map_id = Vector2i(0, ctx.u8(CUR_MAP_AT))
	world.player_cell = Vector2i(ctx.u8(X_AT), ctx.u8(Y_AT))
	## `ResetPlayerSpriteData` stands a Continue facing down.
	world.player_facing = Gen2WorldSprite.FACING_DOWN
	var mode: int = ctx.u8(WALK_BIKE_SURF_AT)
	if mode == BIKE:
		world.movement_mode = Gen2WorldAPI.MOVEMENT_BIKE
		world.player_sprite_number = Gen1Layout.bike_sprite(ctx.game_id)
	elif mode == SURF:
		world.movement_mode = Gen2WorldAPI.MOVEMENT_SURF
		world.player_sprite_number = Gen2WorldSprite.SPRITE_SEEL
	elif mode != WALK:
		ctx.refuse("wWalkBikeSurfState is %d, which is none of walking, biking and surfing" % mode)
	world.gen1_last_map = ctx.u8(LAST_MAP_AT)
	world.gen1_last_blackout_map = ctx.u8(LAST_BLACKOUT_AT)
	world.gen1_map_pal_offset = ctx.u8(MAP_PAL_OFFSET_AT)


static func _read_fossil(ctx: Gen1SramContext) -> Dictionary:
	var out: Dictionary = {}
	if ctx.u8(FOSSIL_AT) != 0:
		out["item"] = ctx.u8(FOSSIL_AT)
	if ctx.u8(FOSSIL_AT + 1) != 0:
		out["mon"] = ctx.u8(FOSSIL_AT + 1)
	return out


static func _read_pikachu(ctx: Gen1SramContext) -> Dictionary:
	return {
		"happiness": ctx.u8(PIKACHU_HAPPINESS_AT), "mood": ctx.u8(PIKACHU_HAPPINESS_AT + 1),
		"emotion_modifier": ctx.u8(PIKACHU_EMOTION_AT),
		"flags": ctx.u8(PIKACHU_FLAGS_AT) & PIKACHU_KEPT_FLAGS,
		"spawn_state": ctx.u8(PIKACHU_FLAGS_AT + 1),
	}


## The `Gen2WorldState.to_dict` shape, so `from_dict` decides what a state holds.
static func _read_state(ctx: Gen1SramContext) -> Dictionary:
	var starter: int = ctx.u8(PLAYER_STARTER_AT)
	var state: Dictionary = {
		"event_flags": _read_bits(ctx, EVENT_FLAGS_AT, Gen1Layout.EVENT_FLAG_BYTES, 0),
		"engine_flags": _read_engine_flags(ctx),
		"items": _read_items(ctx, BAG_AT, BAG_CAPACITY, "the bag"),
		"pc_items": _read_items(ctx, PC_AT, PC_CAPACITY, "the item PC"),
		"money": {0: _read_bcd(ctx, MONEY_AT, 3, "the money")},
		"coins": _read_bcd(ctx, COINS_AT, 2, "the coin count"),
		"seen_species": _read_dex(ctx, DEX_AT + DEX_BYTES),
		"caught_species": _read_dex(ctx, DEX_AT),
		"toggled_objects": _read_toggles(ctx),
		"gen1_map_scripts": _read_map_scripts(ctx),
		"gen1_starters": {"player": starter, "rival": ctx.u8(STARTERS_AT)},
		"starter_species": ctx.dex_of(starter),
		"safari_balls": ctx.u8(SAFARI_BALLS_AT),
		"safari_steps": ctx.u16(SAFARI_STEPS_AT),
		"card_key_door": [ctx.u8(CARD_KEY_AT + 1), ctx.u8(CARD_KEY_AT)],
		"gen1_bytes": _read_bytes(ctx),
		"npc_trades": _read_bits(ctx, TRADES_AT, 2, 0),
	}
	_read_day_care(ctx, state)
	return state


static func _read_bits(ctx: Gen1SramContext, at: int, bytes: int, first: int) -> Dictionary:
	var out: Dictionary = {}
	for index: int in bytes:
		var value: int = ctx.u8(at + index)
		for bit: int in 8:
			if (value >> bit) & 1 == 1:
				out[first + index * 8 + bit] = true
	return out


static func _read_engine_flags(ctx: Gen1SramContext) -> Dictionary:
	var out: Dictionary = {}
	for run: String in FLAG_RUNS:
		if run == YELLOW_RUN and ctx.game_id != RomRegistry.YELLOW:
			continue
		out.merge(_read_bits(
			ctx, int(FLAG_RUNS[run]), int(Gen1Layout.ENGINE_FLAG_BYTES[run]),
			Gen1Layout.engine_flag_base(run)
		))
	var badges: int = ctx.u8(BADGES_AT)
	for bit: int in 8:
		if (badges >> bit) & 1 == 1:
			out[Gen2WorldState.gen1_badge_flag(bit)] = true
	if (ctx.u8(STATUS_FLAGS_6_AT) >> Gen1Layout.ALWAYS_ON_BIKE_BIT) & 1 == 1:
		out[Gen2WorldState.ENGINE_ALWAYS_ON_BIKE] = true
	## `wNumHoFTeams` is what the port reads as `ENGINE_HALL_OF_FAME`.
	if ctx.u8(HOF_TEAMS_AT) > 0:
		out[Gen2WorldState.ENGINE_HALL_OF_FAME] = true
	return out


## A count, `item, quantity` pairs, then $FF. The port keeps one stack per item.
static func _read_items(
	ctx: Gen1SramContext, at: int, capacity: int, what: String
) -> Dictionary:
	var out: Dictionary = {}
	var count: int = ctx.u8(at)
	if count > capacity or ctx.u8(at + 1 + 2 * count) != Gen1SramMons.LIST_END:
		ctx.refuse("%s holds %d stacks or no end marker" % [what, count])
		return out
	for slot: int in count:
		var item: int = ctx.u8(at + 1 + 2 * slot)
		var quantity: int = ctx.u8(at + 2 + 2 * slot)
		if item == 0 or quantity == 0 or quantity > 99:
			ctx.refuse("%s holds item $%02X x%d" % [what, item, quantity])
		elif out.has(item):
			ctx.refuse("%s holds item $%02X in two stacks, and the port keeps one" % [what, item])
		out[item] = quantity
	return out


static func _read_bcd(ctx: Gen1SramContext, at: int, bytes: int, what: String) -> int:
	var value: int = 0
	for index: int in bytes:
		var pair: int = ctx.u8(at + index)
		if (pair >> 4) > 9 or (pair & 0xF) > 9:
			ctx.refuse("%s is not packed decimal" % what)
			return 0
		value = value * 100 + (pair >> 4) * 10 + (pair & 0xF)
	return value


static func _read_dex(ctx: Gen1SramContext, at: int) -> Dictionary:
	var bits: Dictionary = _read_bits(ctx, at, DEX_BYTES, 1)
	var out: Dictionary = {}
	for dex: int in Gen1Layout.SPECIES_COUNT:
		if bits.has(dex + 1):
			out[dex + 1] = true
	return out


## A set bit hides; the port keeps what left `ToggleableObjectStates`' row.
static func _read_toggles(ctx: Gen1SramContext) -> Dictionary:
	var out: Dictionary = {}
	for index: int in TOGGLE_COUNT:
		var hidden: bool = (ctx.u8(TOGGLES_AT + (index >> 3)) >> (index & 7)) & 1 == 1
		if ctx.data != null and hidden == ctx.data.gen1_toggle_on(index):
			out[index] = true
	return out


static func _read_map_scripts(ctx: Gen1SramContext) -> Dictionary:
	var out: Dictionary = {}
	for index: int in MAP_SCRIPT_BYTES:
		if ctx.u8(MAP_SCRIPTS_AT + index) != 0:
			out[index] = ctx.u8(MAP_SCRIPTS_AT + index)
	return out


static func _read_bytes(ctx: Gen1SramContext) -> Dictionary:
	var out: Dictionary = {
		"first_lock_trash_can": ctx.u8(LOCKS_AT), "second_lock_trash_can": ctx.u8(LOCKS_AT + 1),
	}
	if ctx.game_id == RomRegistry.YELLOW:
		out[SECOND_LOCK_ALT] = ctx.u8(LOCKS_AT + 2)
		out["surf_hi_score_low"] = ctx.u8(SURF_SCORE_AT)
		out["surf_hi_score_high"] = ctx.u8(SURF_SCORE_AT + 1)
	return out


static func _read_day_care(ctx: Gen1SramContext, state: Dictionary) -> void:
	if ctx.u8(DAY_CARE_AT) == 0:
		return
	var mon: Gen2SaveMon = Gen1SramMons.read_mon(ctx, DAY_CARE_MON_AT, false)
	if mon == null:
		return
	mon.original_trainer = Gen1SramMons.read_name(ctx, DAY_CARE_OT_AT)
	mon.nickname = Gen1SramMons.read_name(ctx, DAY_CARE_NAME_AT)
	state["day_care_man"] = Gen2WorldDayCare.MAN_HAS_MON
	state["day_care_mons"] = [mon.to_dict(), {}]


static func write(ctx: Gen1SramContext, save: Gen2SaveData) -> void:
	Gen1SramMons.write_name(ctx, NAME_AT, save.player_name)
	ctx.put16(PLAYER_ID_AT, save.player_id)
	_write_time(ctx, save.game_time)
	if save.world == null:
		return
	var world: Gen2WorldSnapshot = save.world
	var state: Dictionary = world.world_state.to_dict()
	_check_state(ctx, state)
	_write_position(ctx, world)
	Gen1SramMons.write_name(ctx, RIVAL_NAME_AT, world.rival_name)
	ctx.raw[FOSSIL_AT] = int(world.gen1_fossil.get("item", 0))
	ctx.raw[FOSSIL_AT + 1] = int(world.gen1_fossil.get("mon", 0))
	if ctx.game_id == RomRegistry.YELLOW:
		_write_pikachu(ctx, world.gen1_pikachu)
	_write_flags(ctx, state)
	_write_inventory(ctx, state)
	_write_progress(ctx, state)
	_write_day_care(ctx, state)


static func _write_time(ctx: Gen1SramContext, time: PokeGameTime) -> void:
	if time == null:
		return
	ctx.raw[PLAY_TIME_AT] = mini(time.hours, 0xFF)
	ctx.raw[PLAY_TIME_AT + 1] = 0xFF if time.capped else 0
	ctx.raw[PLAY_TIME_AT + 2] = time.minutes
	ctx.raw[PLAY_TIME_AT + 3] = time.seconds
	ctx.raw[PLAY_TIME_AT + 4] = time.frames


## The block coordinates and view pointer follow the cell: rewritten only when
## it moved.
static func _write_position(ctx: Gen1SramContext, world: Gen2WorldSnapshot) -> void:
	var map: Gen2WorldMap = ctx.data.world_map(world.map_id.x, world.map_id.y)
	if map == null or world.map_id.x != 0:
		ctx.refuse("map %d/%d is not a Generation 1 map" % [world.map_id.x, world.map_id.y])
		return
	var cell: Vector2i = world.player_cell
	if ctx.u8(CUR_MAP_AT) != map.number or ctx.u8(X_AT) != cell.x or ctx.u8(Y_AT) != cell.y:
		var width: int = (map.collision_width >> 1) + 2 * MAP_BORDER
		ctx.raw[CUR_MAP_AT] = map.number
		ctx.raw[X_AT] = cell.x
		ctx.raw[Y_AT] = cell.y
		ctx.raw[X_BLOCK_AT] = cell.x & 1
		ctx.raw[Y_BLOCK_AT] = cell.y & 1
		var view: int = OVERWORLD_MAP + ((cell.y >> 1) + 1) * width + (cell.x >> 1) + 1
		ctx.raw[VIEW_POINTER_AT] = view & 0xFF
		ctx.raw[VIEW_POINTER_AT + 1] = view >> 8
	ctx.raw[WALK_BIKE_SURF_AT] = {
		Gen2WorldAPI.MOVEMENT_BIKE: BIKE, Gen2WorldAPI.MOVEMENT_SURF: SURF,
	}.get(world.movement_mode, WALK)
	ctx.raw[LAST_MAP_AT] = world.gen1_last_map
	ctx.raw[LAST_BLACKOUT_AT] = world.gen1_last_blackout_map
	ctx.raw[MAP_PAL_OFFSET_AT] = world.gen1_map_pal_offset


static func _write_pikachu(ctx: Gen1SramContext, pikachu: Dictionary) -> void:
	ctx.raw[PIKACHU_HAPPINESS_AT] = int(pikachu.get("happiness", Gen1Pikachu.HAPPINESS_START))
	ctx.raw[PIKACHU_HAPPINESS_AT + 1] = int(pikachu.get("mood", Gen1Pikachu.MOOD_START))
	ctx.raw[PIKACHU_EMOTION_AT] = int(pikachu.get("emotion_modifier", 0)) & 0xFF
	ctx.raw[PIKACHU_FLAGS_AT] = (ctx.u8(PIKACHU_FLAGS_AT) & ~PIKACHU_KEPT_FLAGS & 0xFF) \
		| (int(pikachu.get("flags", 0)) & PIKACHU_KEPT_FLAGS)
	ctx.raw[PIKACHU_FLAGS_AT + 1] = int(pikachu.get("spawn_state", Gen1Pikachu.SPAWN_ON_PLAYER))


static func _write_bits(
	ctx: Gen1SramContext, at: int, bytes: int, first: int, wanted: Dictionary
) -> void:
	for index: int in bytes:
		var value: int = 0
		for bit: int in 8:
			if wanted.has(first + index * 8 + bit):
				value |= 1 << bit
		ctx.raw[at + index] = value


## What the cartridge has no byte for is refused, not dropped.
static func _check_state(ctx: Gen1SramContext, state: Dictionary) -> void:
	_check_keys(ctx, state["event_flags"], Gen1Layout.EVENT_FLAG_BYTES * 8, "event flag")
	_check_keys(ctx, state["npc_trades"], 16, "in-game trade")
	_check_keys(ctx, state["gen1_map_scripts"], MAP_SCRIPT_BYTES, "map script byte")
	_check_keys(ctx, state["toggled_objects"], TOGGLE_COUNT, "toggleable object")
	_check_keys(ctx, state["seen_species"], Gen1Layout.SPECIES_COUNT + 1, "Pokedex entry")
	_check_keys(ctx, state["caught_species"], Gen1Layout.SPECIES_COUNT + 1, "Pokedex entry")
	_check_keys(ctx, state["items"], Gen1SramMons.LIST_END, "item")
	_check_keys(ctx, state["pc_items"], Gen1SramMons.LIST_END, "item")
	for stack: Dictionary in [state["items"], state["pc_items"]]:
		for item: Variant in stack:
			if int(stack[item]) > 99:
				ctx.refuse("item $%02X is stacked past 99" % int(item))
	for name: Variant in state["gen1_bytes"] as Dictionary:
		if not String(name) in SAVED_BYTES and not String(name) in VOLATILE_BYTES:
			ctx.refuse("script byte %s has no place in the cartridge file" % String(name))


static func _check_keys(ctx: Gen1SramContext, flags: Dictionary, limit: int, what: String) -> void:
	for key: Variant in flags:
		if int(key) < 0 or int(key) >= limit:
			ctx.refuse("%s %d has no place in the cartridge file" % [what, int(key)])


static func _write_flags(ctx: Gen1SramContext, state: Dictionary) -> void:
	var events: Dictionary = state["event_flags"]
	_write_bits(ctx, EVENT_FLAGS_AT, Gen1Layout.EVENT_FLAG_BYTES, 0, events)
	_write_bits(ctx, TRADES_AT, 2, 0, state["npc_trades"])
	var wanted: Dictionary = (state["engine_flags"] as Dictionary).duplicate()
	for run: String in FLAG_RUNS:
		if run == YELLOW_RUN and ctx.game_id != RomRegistry.YELLOW:
			continue
		var base: int = Gen1Layout.engine_flag_base(run)
		var bytes: int = int(Gen1Layout.ENGINE_FLAG_BYTES[run])
		_write_bits(ctx, int(FLAG_RUNS[run]), bytes, base, wanted)
		for flag: int in range(base, base + bytes * 8):
			wanted.erase(flag)
	var badges: Dictionary = {}
	for bit: int in 8:
		if wanted.has(Gen2WorldState.gen1_badge_flag(bit)):
			badges[bit] = true
		wanted.erase(Gen2WorldState.gen1_badge_flag(bit))
	_write_bits(ctx, BADGES_AT, 1, 0, badges)
	var bike: int = 1 << Gen1Layout.ALWAYS_ON_BIKE_BIT
	ctx.raw[STATUS_FLAGS_6_AT] = (ctx.u8(STATUS_FLAGS_6_AT) & ~bike & 0xFF) \
		| (bike if wanted.has(Gen2WorldState.ENGINE_ALWAYS_ON_BIKE) else 0)
	wanted.erase(Gen2WorldState.ENGINE_ALWAYS_ON_BIKE)
	wanted.erase(Gen2WorldState.ENGINE_HALL_OF_FAME)
	for flag: Variant in wanted:
		ctx.refuse("engine flag %d has no byte in a Generation 1 save" % int(flag))


static func _write_inventory(ctx: Gen1SramContext, state: Dictionary) -> void:
	_write_items(ctx, BAG_AT, BAG_CAPACITY, state["items"], "the bag")
	_write_items(ctx, PC_AT, PC_CAPACITY, state["pc_items"], "the item PC")
	_write_bcd(ctx, MONEY_AT, 3, int((state["money"] as Dictionary).get(0, 0)))
	_write_bcd(ctx, COINS_AT, 2, int(state["coins"]))
	_write_dex(ctx, DEX_AT + DEX_BYTES, state["seen_species"])
	_write_dex(ctx, DEX_AT, state["caught_species"])


static func _write_items(
	ctx: Gen1SramContext, at: int, capacity: int, items: Dictionary, what: String
) -> void:
	if items.size() > capacity:
		ctx.refuse("%s holds %d stacks and the cartridge keeps %d" % [what, items.size(), capacity])
		return
	ctx.raw[at] = items.size()
	var slot: int = 0
	for item: Variant in items:
		ctx.raw[at + 1 + 2 * slot] = int(item)
		ctx.raw[at + 2 + 2 * slot] = int(items[item])
		slot += 1
	ctx.raw[at + 1 + 2 * slot] = Gen1SramMons.LIST_END


@warning_ignore("integer_division")
static func _write_bcd(ctx: Gen1SramContext, at: int, bytes: int, value: int) -> void:
	var left: int = clampi(value, 0, int(pow(100.0, bytes)) - 1)
	for index: int in range(bytes - 1, -1, -1):
		var pair: int = left % 100
		ctx.raw[at + index] = ((pair / 10) << 4) | (pair % 10)
		left /= 100


static func _write_dex(ctx: Gen1SramContext, at: int, species: Dictionary) -> void:
	for dex: int in Gen1Layout.SPECIES_COUNT:
		var byte: int = at + (dex >> 3)
		var mask: int = 1 << (dex & 7)
		ctx.raw[byte] = (ctx.u8(byte) & ~mask & 0xFF) | (mask if species.has(dex + 1) else 0)


static func _write_progress(ctx: Gen1SramContext, state: Dictionary) -> void:
	var toggled: Dictionary = state["toggled_objects"]
	var hidden: Dictionary = {}
	for index: int in TOGGLE_COUNT:
		if toggled.has(index) == ctx.data.gen1_toggle_on(index):
			hidden[index] = true
	_write_bits(ctx, TOGGLES_AT, TOGGLE_COUNT >> 3, 0, hidden)
	var scripts: Dictionary = state["gen1_map_scripts"]
	for index: int in MAP_SCRIPT_BYTES:
		ctx.raw[MAP_SCRIPTS_AT + index] = int(scripts.get(index, 0))
	var starters: Dictionary = state["gen1_starters"]
	ctx.raw[STARTERS_AT] = int(starters.get("rival", 0))
	ctx.raw[PLAYER_STARTER_AT] = int(starters.get("player", 0))
	ctx.raw[SAFARI_BALLS_AT] = int(state["safari_balls"])
	ctx.put16(SAFARI_STEPS_AT, int(state["safari_steps"]))
	var door: Array = state["card_key_door"]
	ctx.raw[CARD_KEY_AT + 1] = int(door[0])
	ctx.raw[CARD_KEY_AT] = int(door[1])
	var bytes: Dictionary = state["gen1_bytes"]
	ctx.raw[LOCKS_AT] = int(bytes.get("first_lock_trash_can", 0))
	ctx.raw[LOCKS_AT + 1] = int(bytes.get("second_lock_trash_can", 0))
	if ctx.game_id == RomRegistry.YELLOW:
		ctx.raw[LOCKS_AT + 2] = int(bytes.get(SECOND_LOCK_ALT, 0))
		ctx.raw[SURF_SCORE_AT] = int(bytes.get("surf_hi_score_low", 0))
		ctx.raw[SURF_SCORE_AT + 1] = int(bytes.get("surf_hi_score_high", 0))


static func _write_day_care(ctx: Gen1SramContext, state: Dictionary) -> void:
	var mons: Array = state.get("day_care_mons", []) as Array
	var held: bool = int(state.get("day_care_man", 0)) & Gen2WorldDayCare.MAN_HAS_MON != 0
	if not held or mons.is_empty() or (mons[0] as Dictionary).is_empty():
		ctx.raw[DAY_CARE_AT] = 0
		return
	var mon: Gen2SaveMon = Gen2SaveMon.from_dict(mons[0])
	if ctx.index_of(mon.species) == 0:
		ctx.refuse("the Day-Care holds species %d, which has no cartridge index" % mon.species)
		return
	ctx.raw[DAY_CARE_AT] = 1
	Gen1SramMons.write_name(ctx, DAY_CARE_NAME_AT, mon.nickname)
	Gen1SramMons.write_name(ctx, DAY_CARE_OT_AT, mon.original_trainer)
	Gen1SramMons.write_mon(ctx, DAY_CARE_MON_AT, mon, false)
