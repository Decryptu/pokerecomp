class_name Gen1SramAdapter
extends RefCounted

## Red, Blue and Yellow SRAM against the save model, reached through
## [Gen2SramAdapter]. It carries the trainer too, so what has no byte or no
## place is refused rather than dropped. Export patches a checksummed image and
## leaves every unmapped byte alone. Layout: `ram/sram.asm` and
## `engine/menus/save.asm`, identical in all three games.

const SRAM_SIZE: int = 0x8000
## `sGameData` and the `sMainDataCheckSum` byte that ends it.
const SAVE_AT: int = Gen1SramWorld.NAME_AT
const SAVE_END: int = 0x3523
const PARTY_AT: int = 0x2F2C
const CURRENT_BOX_AT: int = 0x30C0
## `sHallOfFame`: bank 0, no checksum.
const HALL_AT: int = 0x0598
## `sBox1` and `sBox7`: six boxes, their sum, one sum each.
const BOX_BANKS: Array[int] = [0x4000, 0x6000]
const BOX_SIZE: int = 0x462
const BOXES_PER_BANK: int = 6
const BOX_COUNT: int = Gen1Layout.BOX_COUNT
## `BIT_HAS_CHANGED_BOXES`: until the first CHANGE BOX the banks are junk.
const BOXES_CHANGED_BIT: int = 0x80
const BOX_NUMBER_MASK: int = 0x7F


static func import_bytes(
	game_id: StringName,
	rom_sha1: String,
	slot: int,
	raw: PackedByteArray,
	data: GameData = null
) -> Dictionary:
	var gate: Dictionary = _gate(game_id, rom_sha1, slot, raw)
	if not gate["ok"]:
		return gate
	if data == null:
		return _failure("a cartridge save is read through the selected cartridge cache")
	if not _checksum_matches(raw):
		return _failure("the cartridge save failed its checksum")
	var ctx: Gen1SramContext = _context(game_id, raw, data)
	var save := Gen2SaveData.new()
	save.game_id = game_id
	save.rom_sha1 = rom_sha1
	save.slot = slot
	Gen1SramWorld.read(ctx, save)
	save.party = Gen1SramMons.read_list(ctx, PARTY_AT, Gen1SramMons.PARTY_LENGTH, true)
	_read_boxes(ctx, save)
	save.hall_of_fame = Gen1SramMons.read_hall(
		ctx, HALL_AT, ctx.u8(Gen1SramWorld.HOF_TEAMS_AT)
	)
	if not ctx.refusal.is_empty():
		return _failure(ctx.refusal)
	var validation: Dictionary = Gen2SaveValidator.validate(save, data)
	if not validation["ok"]:
		return _failure("cartridge save is invalid: %s" % validation["message"])
	return {"ok": true, "message": "", "save": save, "copy": "primary", "raw": ctx.raw}


## Patches every mapped field into the valid image [param raw].
static func export_bytes(save: Gen2SaveData, raw: PackedByteArray, data: GameData) -> Dictionary:
	if save == null:
		return _failure("the save is missing")
	var gate: Dictionary = _gate(save.game_id, save.rom_sha1, save.slot, raw)
	if not gate["ok"]:
		return gate
	if data == null:
		return _failure("the selected cartridge cache is required for export")
	var validation: Dictionary = Gen2SaveValidator.validate(save, data)
	if not validation["ok"]:
		return _failure("save cannot be exported: %s" % validation["message"])
	var mod_content: Dictionary = Gen2SramAdapter.mod_content_refusal(save)
	if not mod_content["ok"]:
		return mod_content
	if not _checksum_matches(raw):
		return _failure("the cartridge image to patch failed its checksum")
	var ctx: Gen1SramContext = _context(save.game_id, raw, data)
	_check_species(ctx, save)
	Gen1SramWorld.write(ctx, save)
	Gen1SramMons.write_list(ctx, PARTY_AT, Gen1SramMons.PARTY_LENGTH, true, save.party)
	_write_boxes(ctx, save)
	_write_hall(ctx, save)
	if not ctx.refusal.is_empty():
		return _failure(ctx.refusal)
	ctx.raw[SAVE_END] = _checksum(ctx.raw, SAVE_AT, SAVE_END)
	return {"ok": true, "message": "", "raw": ctx.raw, "copy": "primary"}


static func _context(game_id: StringName, raw: PackedByteArray, data: GameData) -> Gen1SramContext:
	var ctx := Gen1SramContext.new()
	ctx.game_id = game_id
	ctx.raw = raw.duplicate()
	ctx.data = data
	return ctx


static func _gate(
	game_id: StringName, rom_sha1: String, slot: int, raw: PackedByteArray
) -> Dictionary:
	if RomRegistry.generation_for(game_id) != RomRegistry.GEN1:
		return _failure("unsupported cartridge game %s" % game_id)
	if RomRegistry.sha1_for(game_id) != rom_sha1:
		return _failure("the save belongs to an unsupported cartridge revision")
	if slot < 0 or slot >= Gen2SaveStore.MAX_SLOTS:
		return _failure("save slot %d is out of range" % slot)
	if raw.size() < SRAM_SIZE:
		return _failure("cartridge save is shorter than 32 KiB")
	return {"ok": true, "message": ""}


## `CalcCheckSum`. Only `LoadMainData` tests one; the boxes' sums are never read.
static func _checksum(raw: PackedByteArray, from: int, to: int) -> int:
	var sum: int = 0
	for at: int in range(from, to):
		sum = (sum + int(raw[at])) & 0xFF
	return (~sum) & 0xFF


static func _checksum_matches(raw: PackedByteArray) -> bool:
	return int(raw[SAVE_END]) == _checksum(raw, SAVE_AT, SAVE_END)


@warning_ignore("integer_division")
static func _box_at(box: int) -> int:
	return int(BOX_BANKS[box / BOXES_PER_BANK]) + (box % BOXES_PER_BANK) * BOX_SIZE


## The current box is `sCurBoxData`; its own bank row is stale.
static func _read_boxes(ctx: Gen1SramContext, save: Gen2SaveData) -> void:
	var number: int = ctx.u8(Gen1SramWorld.CURRENT_BOX_AT)
	var current: int = number & BOX_NUMBER_MASK
	if current >= BOX_COUNT:
		ctx.refuse("the current box is %d, and the cartridge has %d" % [current + 1, BOX_COUNT])
		return
	save.current_box = current
	for box: int in BOX_COUNT:
		if box == current:
			save.boxes[box] = Gen1SramMons.read_box(ctx, CURRENT_BOX_AT)
		elif number & BOXES_CHANGED_BIT != 0:
			save.boxes[box] = Gen1SramMons.read_box(ctx, _box_at(box))


static func _write_boxes(ctx: Gen1SramContext, save: Gen2SaveData) -> void:
	if save.current_box < 0 or save.current_box >= BOX_COUNT:
		ctx.refuse("the current box is %d, and the cartridge has %d" % [save.current_box + 1, BOX_COUNT])
		return
	for box: int in range(BOX_COUNT, save.boxes.size()):
		if (save.boxes[box] as Gen2SaveBox).occupied_count() > 0:
			ctx.refuse("box %d holds Pokemon, and the cartridge has %d boxes" % [box + 1, BOX_COUNT])
	var number: int = ctx.u8(Gen1SramWorld.CURRENT_BOX_AT)
	var changed: bool = number & BOXES_CHANGED_BIT != 0
	for box: int in BOX_COUNT:
		changed = changed or (box != save.current_box and (save.boxes[box] as Gen2SaveBox).occupied_count() > 0)
	ctx.raw[Gen1SramWorld.CURRENT_BOX_AT] = save.current_box | (BOXES_CHANGED_BIT if changed else 0)
	Gen1SramMons.write_box(ctx, CURRENT_BOX_AT, save.boxes[save.current_box])
	if not changed:
		return
	## `EmptyAllSRAMBoxes` empties the current box's row too.
	for box: int in BOX_COUNT:
		if box != save.current_box:
			Gen1SramMons.write_box(ctx, _box_at(box), save.boxes[box])
		elif number & BOXES_CHANGED_BIT == 0:
			Gen1SramMons.write_box(ctx, _box_at(box), Gen2SaveBox.new())
	for bank: int in BOX_BANKS:
		_seal_bank(ctx, bank)


static func _seal_bank(ctx: Gen1SramContext, bank: int) -> void:
	var sums: int = bank + BOXES_PER_BANK * BOX_SIZE
	ctx.raw[sums] = _checksum(ctx.raw, bank, sums)
	for index: int in BOXES_PER_BANK:
		var at: int = bank + index * BOX_SIZE
		ctx.raw[sums + 1 + index] = _checksum(ctx.raw, at, at + BOX_SIZE)


static func _write_hall(ctx: Gen1SramContext, save: Gen2SaveData) -> void:
	if save.hall_of_fame.size() > Gen1SramMons.HOF_CAPACITY:
		ctx.refuse("%d Hall of Fame teams, and the cartridge keeps %d" % [
			save.hall_of_fame.size(), Gen1SramMons.HOF_CAPACITY,
		])
		return
	var beaten: bool = save.world != null and save.world.world_state.hall_of_fame()
	ctx.raw[Gen1SramWorld.HOF_TEAMS_AT] = maxi(
		Gen2HallOfFame.win_count(save.hall_of_fame), 1 if beaten else 0
	)
	Gen1SramMons.write_hall(ctx, HALL_AT, save.hall_of_fame)


static func _check_species(ctx: Gen1SramContext, save: Gen2SaveData) -> void:
	var mons: Array = save.party.duplicate()
	for box: Variant in save.boxes:
		mons.append_array((box as Gen2SaveBox).slots)
	for record: Variant in save.hall_of_fame:
		for mon: Variant in (record as Dictionary).get("mons", []) as Array:
			if ctx.index_of(int((mon as Dictionary).get("species", 0))) == 0:
				ctx.refuse("the Hall of Fame holds a species the cartridge does not number")
	for mon: Variant in mons:
		if mon != null and ctx.index_of((mon as Gen2SaveMon).species) == 0:
			ctx.refuse("species %d has no cartridge index" % (mon as Gen2SaveMon).species)


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}
