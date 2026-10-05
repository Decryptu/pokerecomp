class_name Gen1SramMons
extends RefCounted

## The Pokemon half of a Generation 1 `.sav`: `box_struct`, `party_struct`, the
## lists around them and the Hall of Fame (`macros/ram.asm`, pokered and
## pokeyellow alike).

const NAME_LENGTH: int = 11
const BOX_MON_SIZE: int = 33
const PARTY_MON_SIZE: int = 44
const PARTY_LENGTH: int = 6
const BOX_CAPACITY: int = 20
## Ends a species list, and a Hall of Fame team shorter than six.
const LIST_END: int = 0xFF
const PP_MASK: int = 0x3F
const PP_UP_SHIFT: int = 6

## `box_struct` offsets; `party_struct` adds the level and five stats.
const AT_HP: int = 1
const AT_BOX_LEVEL: int = 3
const AT_STATUS: int = 4
const AT_TYPES: int = 5
const AT_CATCH_RATE: int = 7
const AT_MOVES: int = 8
const AT_OT_ID: int = 12
const AT_EXP: int = 14
const AT_STAT_EXP: int = 17
const AT_DVS: int = 27
const AT_PP: int = 29
const AT_LEVEL: int = 33
const AT_STATS: int = 34

## `HOF_MON`: species, level, name, three unread bytes.
const HOF_MON_SIZE: int = 16
const HOF_TEAM_SIZE: int = PARTY_LENGTH * HOF_MON_SIZE
const HOF_CAPACITY: int = 50
const HOF_NAME_AT: int = 2


static func read_mon(ctx: Gen1SramContext, at: int, party: bool) -> Gen2SaveMon:
	var mon := Gen2SaveMon.new()
	var index: int = ctx.u8(at)
	mon.species = ctx.dex_of(index)
	if mon.species == 0:
		ctx.refuse("a Pokemon is species $%02X, which no Pokedex entry names" % index)
		return null
	mon.catch_rate = ctx.u8(at + AT_CATCH_RATE)
	mon.moves = []
	mon.pp = []
	mon.pp_ups = []
	for slot: int in Gen2SaveMon.MAX_MOVES:
		var pp: int = ctx.u8(at + AT_PP + slot)
		mon.moves.append(ctx.u8(at + AT_MOVES + slot))
		mon.pp.append(pp & PP_MASK)
		mon.pp_ups.append(pp >> PP_UP_SHIFT)
	mon.ot_id = ctx.u16(at + AT_OT_ID)
	mon.exp = ctx.u24(at + AT_EXP)
	for slot: int in Gen2SaveMon.STAT_EXP_KEYS.size():
		mon.stat_exp[Gen2SaveMon.STAT_EXP_KEYS[slot]] = ctx.u16(at + AT_STAT_EXP + 2 * slot)
	mon.dvs = ctx.u16(at + AT_DVS)
	mon.hp = ctx.u16(at + AT_HP)
	mon.status = ctx.u8(at + AT_STATUS)
	mon.level = ctx.u8(at + (AT_LEVEL if party else AT_BOX_LEVEL))
	if party:
		mon.stats = _read_stats(ctx, at)
	return mon


## One Special stat answers for both.
static func _read_stats(ctx: Gen1SramContext, at: int) -> Dictionary:
	var special: int = ctx.u16(at + AT_STATS + 8)
	return {
		"hp": ctx.u16(at + AT_STATS), "attack": ctx.u16(at + AT_STATS + 2),
		"defense": ctx.u16(at + AT_STATS + 4), "speed": ctx.u16(at + AT_STATS + 6),
		"sp_attack": special, "sp_defense": special,
	}


static func write_mon(ctx: Gen1SramContext, at: int, mon: Gen2SaveMon, party: bool) -> void:
	var species: Dictionary = ctx.data.species(mon.species)
	var types: Array = species.get("types", [0, 0])
	ctx.raw[at] = ctx.index_of(mon.species)
	ctx.put16(at + AT_HP, mon.hp)
	ctx.raw[at + AT_BOX_LEVEL] = mon.level
	ctx.raw[at + AT_STATUS] = mon.status
	ctx.raw[at + AT_TYPES] = int(types[0])
	ctx.raw[at + AT_TYPES + 1] = int(types[1])
	ctx.raw[at + AT_CATCH_RATE] = mon.catch_rate
	for slot: int in Gen2SaveMon.MAX_MOVES:
		ctx.raw[at + AT_MOVES + slot] = int(mon.moves[slot])
		ctx.raw[at + AT_PP + slot] = ((int(mon.pp_ups[slot]) << PP_UP_SHIFT) & ~PP_MASK & 0xFF) \
			| (int(mon.pp[slot]) & PP_MASK)
	ctx.put16(at + AT_OT_ID, mon.ot_id)
	ctx.put24(at + AT_EXP, mon.exp)
	for slot: int in Gen2SaveMon.STAT_EXP_KEYS.size():
		ctx.put16(at + AT_STAT_EXP + 2 * slot, int(mon.stat_exp.get(Gen2SaveMon.STAT_EXP_KEYS[slot], 0)))
	ctx.put16(at + AT_DVS, mon.dvs)
	if party:
		ctx.raw[at + AT_LEVEL] = mon.level
		_write_stats(ctx, at, mon, species)


static func _write_stats(
	ctx: Gen1SramContext, at: int, mon: Gen2SaveMon, species: Dictionary
) -> void:
	var stats: Dictionary = mon.stats
	if stats.size() != Gen2BattleMon.STAT_KEYS.size():
		stats = Gen2Stats.all_stats(
			species.get("stats", {}), mon.dvs, mon.stat_exp, mon.level
		)
	var keys: Array[String] = ["hp", "attack", "defense", "speed", "sp_attack"]
	for slot: int in keys.size():
		ctx.put16(at + AT_STATS + 2 * slot, int(stats[keys[slot]]))


static func read_name(ctx: Gen1SramContext, at: int) -> String:
	return Gen1Text.decode_fixed(ctx.raw, at, NAME_LENGTH)


## A name the file already spells keeps its padding.
static func write_name(ctx: Gen1SramContext, at: int, text: String) -> void:
	if read_name(ctx, at) == text:
		return
	var encoded: PackedByteArray = Gen1Text.encode(text)
	ctx.fill(at, NAME_LENGTH, Gen1Text.TERMINATOR)
	for index: int in mini(encoded.size(), NAME_LENGTH - 1):
		ctx.raw[at + index] = encoded[index]


## `wPartyCount` and `wBoxCount` open one shape: count, species list, structs,
## OT names, nicknames.
static func read_list(
	ctx: Gen1SramContext, at: int, capacity: int, party: bool
) -> Array:
	var out: Array = []
	var count: int = ctx.u8(at)
	var size: int = PARTY_MON_SIZE if party else BOX_MON_SIZE
	if count > capacity or ctx.u8(at + 1 + count) != LIST_END:
		ctx.refuse("a Pokemon list holds %d entries or no end marker" % count)
		return out
	var mons_at: int = at + capacity + 2
	var ot_at: int = mons_at + capacity * size
	var nick_at: int = ot_at + capacity * NAME_LENGTH
	for slot: int in count:
		var mon: Gen2SaveMon = read_mon(ctx, mons_at + slot * size, party)
		if mon == null:
			return []
		if ctx.index_of(mon.species) != ctx.u8(at + 1 + slot):
			ctx.refuse("a Pokemon list names a species its struct does not hold")
			return []
		mon.original_trainer = read_name(ctx, ot_at + slot * NAME_LENGTH)
		mon.nickname = read_name(ctx, nick_at + slot * NAME_LENGTH)
		out.append(mon)
	return out


## A list that already reads back as [param mons] is left untouched, stale tail
## included; one that changed is rewritten whole with its tail cleared.
static func write_list(
	ctx: Gen1SramContext, at: int, capacity: int, party: bool, mons: Array
) -> void:
	var before := Gen1SramContext.new()
	before.game_id = ctx.game_id
	before.raw = ctx.raw
	before.data = ctx.data
	if _dicts(read_list(before, at, capacity, party)) == _dicts(mons) and before.ok():
		return
	var size: int = PARTY_MON_SIZE if party else BOX_MON_SIZE
	var mons_at: int = at + capacity + 2
	var ot_at: int = mons_at + capacity * size
	var nick_at: int = ot_at + capacity * NAME_LENGTH
	ctx.raw[at] = mons.size()
	ctx.fill(at + 1, capacity + 1, LIST_END)
	ctx.fill(mons_at, capacity * size, 0)
	for slot: int in capacity:
		if slot >= mons.size():
			write_name(ctx, ot_at + slot * NAME_LENGTH, "")
			write_name(ctx, nick_at + slot * NAME_LENGTH, "")
			continue
		var mon: Gen2SaveMon = mons[slot]
		ctx.raw[at + 1 + slot] = ctx.index_of(mon.species)
		write_mon(ctx, mons_at + slot * size, mon, party)
		write_name(ctx, ot_at + slot * NAME_LENGTH, mon.original_trainer)
		write_name(ctx, nick_at + slot * NAME_LENGTH, mon.nickname)


static func _dicts(mons: Array) -> Array:
	var out: Array = []
	for mon: Gen2SaveMon in mons:
		out.append(mon.to_dict())
	return out


static func read_box(ctx: Gen1SramContext, at: int) -> Gen2SaveBox:
	var box := Gen2SaveBox.new()
	var mons: Array = read_list(ctx, at, BOX_CAPACITY, false)
	for slot: int in mons.size():
		box.slots[slot] = mons[slot]
	return box


static func write_box(ctx: Gen1SramContext, at: int, box: Gen2SaveBox) -> void:
	var mons: Array = []
	for mon: Variant in box.slots:
		if mon != null:
			mons.append(mon)
	write_list(ctx, at, BOX_CAPACITY, false, mons)


## `sHallOfFame` holds teams oldest first and no count each: a team's number is
## its place under `wNumHoFTeams`, less the ones shifted out.
static func read_hall(ctx: Gen1SramContext, at: int, total: int) -> Array:
	var kept: int = mini(total, HOF_CAPACITY)
	var out: Array = []
	for team: int in kept:
		var mons: Array = []
		for slot: int in PARTY_LENGTH:
			var mon_at: int = at + team * HOF_TEAM_SIZE + slot * HOF_MON_SIZE
			var index: int = ctx.u8(mon_at)
			if index == LIST_END or index == 0:
				break
			var species: int = ctx.dex_of(index)
			if species == 0:
				ctx.refuse("the Hall of Fame holds species $%02X, which no Pokedex entry names" % index)
				return []
			mons.append({
				"species": species, "ot_id": 0, "dvs": 0, "level": ctx.u8(mon_at + 1),
				"nickname": Gen1Text.decode_fixed(ctx.raw, mon_at + HOF_NAME_AT, NAME_LENGTH),
			})
		out.push_front({"win_count": total - kept + team + 1, "mons": mons})
	return out


## A port record also carries an OT ID and DVs a team never stores.
static func _kept(records: Array) -> Array:
	var out: Array = []
	for record: Dictionary in records:
		var mons: Array = []
		for mon: Dictionary in record.get("mons", []) as Array:
			mons.append([int(mon.get("species", 0)), int(mon.get("level", 0)), String(mon.get("nickname", ""))])
		out.append([int(record.get("win_count", 0)), mons])
	return out


static func write_hall(ctx: Gen1SramContext, at: int, records: Array) -> void:
	var before := Gen1SramContext.new()
	before.game_id = ctx.game_id
	before.raw = ctx.raw
	before.data = ctx.data
	if _kept(read_hall(before, at, ctx.u8(Gen1SramWorld.HOF_TEAMS_AT))) == _kept(records) \
		and before.ok():
		return
	for age: int in records.size():
		var team: int = records.size() - 1 - age
		var team_at: int = at + team * HOF_TEAM_SIZE
		ctx.fill(team_at, HOF_TEAM_SIZE, 0)
		var mons: Array = (records[age] as Dictionary).get("mons", []) as Array
		for slot: int in PARTY_LENGTH:
			var mon_at: int = team_at + slot * HOF_MON_SIZE
			if slot >= mons.size():
				ctx.raw[mon_at] = LIST_END
				break
			var mon: Dictionary = mons[slot]
			ctx.raw[mon_at] = ctx.index_of(int(mon.get("species", 0)))
			ctx.raw[mon_at + 1] = int(mon.get("level", 0))
			write_name(ctx, mon_at + HOF_NAME_AT, String(mon.get("nickname", "")))
