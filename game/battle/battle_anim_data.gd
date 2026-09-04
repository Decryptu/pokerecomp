class_name Gen2BattleAnimData
extends RefCounted

## The imported battle animation tables, read the way the cartridge reads them.
## An importer caches a table as a whole region because every pointer inside one
## is bank-local; this resolves them, an address minus the region's base being an
## index into its bytes, which is what `add hl, de` does with the bank paged in.
## Crystal gives each table a region; Generation 1 interleaves all four through
## bank $1E, so it caches one and [method gen1_pointer] takes the table.

## `BattleAnimObjects` row fields, in the order `InitBattleAnimation` copies them.
const OBJECT_FIELDS: Array[StringName] = [
	&"flags", &"y_fix", &"frameset", &"function", &"palette", &"gfx",
]

## Crystal's four regions, one table each.
const GEN2_REGIONS: Array[StringName] = [&"scripts", &"objects", &"framesets", &"oam_sets"]
## Generation 1's one, whose four tables are interleaved inside it.
const GEN1_REGION: StringName = &"anims"
## Where three of them stand in it; `AttackAnimationPointers` is its base.
const GEN1_TABLES: Array[StringName] = [&"subanims", &"frame_blocks", &"base_coords"]

var _regions: Dictionary = {}
var _gfx: Array = []
var _sine: PackedByteArray = PackedByteArray()
var _profile: StringName = &"crystal"
var _tables: Dictionary = {}
var _special_effects: PackedInt32Array = PackedInt32Array()
var _falling_deltas: PackedInt32Array = PackedInt32Array()


## Built from a cache. Returns null when the cache carries no animation layer,
## so a caller can tell "not imported" from "imported and empty".
static func from_game_data(data: GameData) -> Gen2BattleAnimData:
	if data == null:
		return null
	var is_gen1: bool = data.generation == RomRegistry.GEN1
	var regions: Dictionary = {}
	for name: StringName in ([GEN1_REGION] if is_gen1 else GEN2_REGIONS):
		var region_data: Dictionary = data.battle_anim_region(name)
		if region_data.is_empty():
			return null
		regions[name] = region_data
	var sheets: Array = []
	for index: int in data.battle_anim_gfx_count():
		sheets.append(data.battle_anim_gfx(index))
	if not is_gen1:
		return create(regions, sheets, data.battle_anim_sine(), data.id)
	var tables: Dictionary = {}
	for name: StringName in GEN1_TABLES:
		tables[name] = data.battle_anim_table(name)
	return create_gen1(
		regions[GEN1_REGION], sheets, tables,
		data.battle_anim_special_effects(), data.battle_anim_falling_deltas(), data.id
	)


static func create(
	regions: Dictionary, sheets: Array, sine: PackedByteArray = PackedByteArray(),
	profile_name: StringName = &"crystal"
) -> Gen2BattleAnimData:
	var out := Gen2BattleAnimData.new()
	out._regions = regions
	out._gfx = sheets
	out._sine = sine
	out._profile = profile_name
	return out


## The Generation 1 layer: one region, the three table addresses inside it, and
## the two flat tables the engine reads beside them.
static func create_gen1(
	anims: Dictionary, sheets: Array, tables: Dictionary,
	effects: PackedInt32Array, deltas: PackedInt32Array,
	profile_name: StringName = &"red"
) -> Gen2BattleAnimData:
	var out: Gen2BattleAnimData = create({GEN1_REGION: anims}, sheets, PackedByteArray(), profile_name)
	out._tables = tables
	out._special_effects = effects
	out._falling_deltas = deltas
	return out


## Which cartridge this came from. Only the bg effect table reads it, and only
## because pokegold's is one entry shorter than Crystal's; nothing else in the
## layer is profile_name split.
func profile() -> StringName:
	return _profile


## One `BattleAnimSineWave` word, which is the amplitude `BattleAnim_Sine`
## multiplies. Entry 16 is $0100, so the table is not eight-bit and is read
## rather than derived. Out of range answers zero, the way [method byte_at] does.
func sine_word(index: int) -> int:
	var at: int = index * 2
	if at < 0 or at + 2 > _sine.size():
		return 0
	return _sine[at] | (_sine[at + 1] << 8)


## Whether this is the Generation 1 layer, which is what a reader parts on
## rather than the profile name.
func gen1() -> bool:
	return _regions.has(GEN1_REGION)


func gen1_pointer(table: StringName, index: int) -> int:
	var at: int = int(_tables.get(table, -1))
	return -1 if at < 0 else word_at(GEN1_REGION, at + index * Gen1Layout.POINTER_SIZE)


## One `FrameBlockBaseCoords` row as the y and x `DrawFrameBlock` adds.
func gen1_base_coord(index: int) -> Vector2i:
	var at: int = int(_tables.get(&"base_coords", -1))
	if at < 0 or index < 0 or index >= Gen1Layout.BASE_COORD_COUNT:
		return Vector2i.ZERO
	at += index * Gen1Layout.BASE_COORD_SIZE
	return Vector2i(byte_at(GEN1_REGION, at + 1), byte_at(GEN1_REGION, at))


## One `FrameBlockPointers` entry as the `dbsprite` rows behind its count byte,
## each [code]{ y, x, tile, attributes }[/code]. `FRAMEBLOCK_00` holds none, and
## `FrameBlock62` counts fifteen where sixteen are written, so its last is never
## drawn: the count byte is what the cartridge reads and what this reads.
func gen1_frame_block(index: int) -> Array:
	var address: int = gen1_pointer(&"frame_blocks", index)
	if address < 0 or index < 0 or index >= Gen1Layout.FRAME_BLOCK_COUNT:
		return []
	var out: Array = []
	for sprite: int in byte_at(GEN1_REGION, address):
		var at: int = address + 1 + sprite * Gen1Layout.FRAME_BLOCK_SPRITE_SIZE
		out.append({
			"y": byte_at(GEN1_REGION, at),
			"x": byte_at(GEN1_REGION, at + 1),
			"tile": byte_at(GEN1_REGION, at + 2),
			"attributes": byte_at(GEN1_REGION, at + 3),
		})
	return out


## One `SubanimationPointers` entry as [code]{ kind, rows }[/code] in
## `PlaySubanimation`'s own order. `kind` is the header's `SUBANIMTYPE_*`, which
## `LoadSubanimation` turns into a transform against whose turn it is.
func gen1_subanim(index: int) -> Dictionary:
	var address: int = gen1_pointer(&"subanims", index)
	if address < 0 or index < 0 or index >= Gen1Layout.SUBANIM_COUNT:
		return {}
	var header: int = byte_at(GEN1_REGION, address)
	var rows: Array = []
	for row: int in header & Gen1Layout.SUBANIM_COUNT_MASK:
		var at: int = address + 1 + row * Gen1Layout.SUBANIM_ROW_SIZE
		rows.append({
			"frame_block": byte_at(GEN1_REGION, at),
			"base_coord": byte_at(GEN1_REGION, at + 1),
			"mode": byte_at(GEN1_REGION, at + 2),
		})
	return {"kind": header >> Gen1Layout.SUBANIM_TYPE_SHIFT, "rows": rows}


## One `FallingObjects_DeltaXs` entry, which the two objects that walk off the
## nine-byte table read out of the routine behind it.
func gen1_falling_delta(index: int) -> int:
	return _falling_deltas[index] if index >= 0 and index < _falling_deltas.size() else 0


## Whether `SpecialEffectPointers` names [param id]. An animation byte at or
## above `FIRST_SE_ID` that it does not name would run off the table's end.
func gen1_has_special_effect(id: int) -> bool:
	return _special_effects.has(id)


func region(name: StringName) -> Dictionary:
	var value: Variant = _regions.get(name, null)
	return value if value is Dictionary else {}


## One byte of a region, addressed the way the cartridge addresses it. Out of
## range answers zero, which is what [method RomFile.u8] does and for the same
## reason: a walk whose length is only known once decoded should end honestly
## rather than fault.
func byte_at(name: StringName, address: int) -> int:
	var entry: Dictionary = region(name)
	if entry.is_empty():
		return 0
	var at: int = address - int(entry["address"])
	var data: PackedByteArray = entry["data"]
	return data[at] if at >= 0 and at < data.size() else 0


func word_at(name: StringName, address: int) -> int:
	return byte_at(name, address) | (byte_at(name, address + 1) << 8)


## Entry [param index] of a region's own two-byte pointer table, which is the
## first bytes of the region.
func pointer(name: StringName, index: int) -> int:
	var entry: Dictionary = region(name)
	if entry.is_empty() or index < 0 or index >= int(entry["count"]):
		return -1
	return word_at(name, int(entry["address"]) + index * 2)


func count(name: StringName) -> int:
	var entry: Dictionary = region(name)
	return int(entry["count"]) if not entry.is_empty() else 0


## One `battleanimobj` row. Empty past the end of `BattleAnimObjects`.
func object_row(index: int) -> Dictionary:
	if index < 0 or index >= count(&"objects"):
		return {}
	var base: int = int(region(&"objects")["address"]) \
		+ index * Gen2Layout.BATTLE_ANIM_OBJECT_SIZE
	var out: Dictionary = {}
	for field: int in OBJECT_FIELDS.size():
		out[OBJECT_FIELDS[field]] = byte_at(&"objects", base + field)
	return out


## Where `BattleAnimFrameData`'s stream for [param frameset] starts.
func frameset_address(frameset: int) -> int:
	return pointer(&"framesets", frameset)


## One `battleanimoam` row: the tile offset it adds, how many `dbsprite`
## records follow and where they are.
func oam_set(index: int) -> Dictionary:
	if index < 0 or index >= count(&"oam_sets"):
		return {}
	var base: int = int(region(&"oam_sets")["address"]) \
		+ index * Gen2Layout.BATTLE_ANIM_OAM_SET_SIZE
	return {
		"vtile": byte_at(&"oam_sets", base + Gen2BattleAnimImporter.OAM_SET_VTILE),
		"length": byte_at(&"oam_sets", base + Gen2BattleAnimImporter.OAM_SET_LENGTH),
		"address": word_at(&"oam_sets", base + Gen2BattleAnimImporter.OAM_SET_POINTER),
	}


## One `dbsprite`: y, x, tile offset, attributes.
func oam_sprite(address: int, index: int) -> Dictionary:
	var at: int = address + index * Gen2Layout.BATTLE_ANIM_OAM_SPRITE_SIZE
	return {
		"y": byte_at(&"oam_sets", at),
		"x": byte_at(&"oam_sets", at + 1),
		"tile": byte_at(&"oam_sets", at + 2),
		"attributes": byte_at(&"oam_sets", at + 3),
	}


## One `AnimObjGFX` row, or empty past the table.
func gfx(index: int) -> Dictionary:
	if index < 0 or index >= _gfx.size():
		return {}
	var row: Variant = _gfx[index]
	return row if row is Dictionary else {}


func gfx_count() -> int:
	return _gfx.size()
