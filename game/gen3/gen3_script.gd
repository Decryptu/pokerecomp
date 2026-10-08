class_name Gen3Script
extends RefCounted

## pret src/scrcmd.c and data/script_cmd_table.inc, including consumed operands
## of no-op handlers. Digits are ScriptReadByte/Halfword/Word widths, not macros.
const FORMAT_COUNTS: Dictionary = {
	RomRegistry.RUBY: [198, 9], RomRegistry.SAPPHIRE: [198, 9],
	RomRegistry.FIRERED: [213, 10], RomRegistry.LEAFGREEN: [213, 10],
	RomRegistry.EMERALD: [227, 13],
}
const COMMANDS: Array[String] = [
	"nop:",
	"nop1:",
	"end:",
	"return:",
	"call:4",
	"goto:4",
	"goto_if:14",
	"call_if:14",
	"gotostd:1",
	"callstd:1",
	"gotostd_if:11",
	"callstd_if:11",
	"returnram:",
	"endram:",
	"setmysteryeventstatus:1",
	"loadword:14",
	"loadbyte:11",
	"setptr:14",
	"loadbytefromptr:14",
	"setptrbyte:14",
	"copylocal:11",
	"copybyte:44",
	"setvar:22",
	"addvar:22",
	"subvar:22",
	"copyvar:22",
	"setorcopyvar:22",
	"compare_local_to_local:11",
	"compare_local_to_value:11",
	"compare_local_to_ptr:14",
	"compare_ptr_to_local:41",
	"compare_ptr_to_value:41",
	"compare_ptr_to_ptr:44",
	"compare_var_to_value:22",
	"compare_var_to_var:22",
	"callnative:4",
	"gotonative:4",
	"special:2",
	"specialvar:22",
	"waitstate:",
	"delay:2",
	"setflag:2",
	"clearflag:2",
	"checkflag:2",
	"initclock:22",
	"dotimebasedevents:",
	"gettime:",
	"playse:2",
	"waitse:",
	"playfanfare:2",
	"waitfanfare:",
	"playbgm:21",
	"savebgm:2",
	"fadedefaultbgm:",
	"fadenewbgm:2",
	"fadeoutbgm:1",
	"fadeinbgm:1",
	"warp:11122",
	"warpsilent:11122",
	"warpdoor:11122",
	"warphole:11",
	"warpteleport:11122",
	"setwarp:11122",
	"setdynamicwarp:11122",
	"setdivewarp:11122",
	"setholewarp:11122",
	"getplayerxy:22",
	"getpartysize:",
	"additem:22",
	"removeitem:22",
	"checkitemspace:22",
	"checkitem:22",
	"checkitemtype:2",
	"addpcitem:22",
	"checkpcitem:22",
	"adddecoration:2",
	"removedecoration:2",
	"checkdecor:2",
	"checkdecorspace:2",
	"applymovement:24",
	"applymovementat:2411",
	"waitmovement:2",
	"waitmovementat:211",
	"removeobject:2",
	"removeobjectat:211",
	"addobject:2",
	"addobjectat:211",
	"setobjectxy:222",
	"showobjectat:211",
	"hideobjectat:211",
	"faceplayer:",
	"turnobject:21",
	"trainerbattle:",
	"dotrainerbattle:",
	"gotopostbattlescript:",
	"gotobeatenscript:",
	"checktrainerflag:2",
	"settrainerflag:2",
	"cleartrainerflag:2",
	"setobjectxyperm:222",
	"copyobjectxytoperm:2",
	"setobjectmovementtype:21",
	"waitmessage:",
	"message:4",
	"closemessage:",
	"lockall:",
	"lock:",
	"releaseall:",
	"release:",
	"waitbuttonpress:",
	"yesnobox:11",
	"multichoice:1111",
	"multichoicedefault:11111",
	"multichoicegrid:11111",
	"drawbox:",
	"erasebox:1111",
	"drawboxtext:1111",
	"showmonpic:211",
	"hidemonpic:",
	"showcontestpainting:1",
	"braillemessage:4",
	"givemon:212441",
	"giveegg:2",
	"setmonmove:112",
	"checkpartymove:2",
	"bufferspeciesname:12",
	"bufferleadmonspeciesname:1",
	"bufferpartymonnick:12",
	"bufferitemname:12",
	"bufferdecorationname:12",
	"buffermovename:12",
	"buffernumberstring:12",
	"bufferstdstring:12",
	"bufferstring:14",
	"pokemart:4",
	"pokemartdecoration:4",
	"pokemartdecoration2:4",
	"playslotmachine:2",
	"setberrytree:111",
	"choosecontestmon:",
	"startcontest:",
	"showcontestresults:",
	"contestlinktransfer:",
	"random:2",
	"addmoney:41",
	"removemoney:41",
	"checkmoney:41",
	"showmoneybox:111",
	"hidemoneybox:",
	"updatemoneybox:111",
	"getpokenewsactive:2",
	"fadescreen:1",
	"fadescreenspeed:11",
	"setflashlevel:2",
	"animateflash:1",
	"messageautoscroll:4",
	"dofieldeffect:2",
	"setfieldeffectargument:12",
	"waitfieldeffect:2",
	"setrespawn:2",
	"checkplayergender:",
	"playmoncry:22",
	"setmetatile:2222",
	"resetweather:",
	"setweather:2",
	"doweather:",
	"setstepcallback:1",
	"setmaplayoutindex:2",
	"setobjectsubpriority:2111",
	"resetobjectsubpriority:211",
	"createvobject:112211",
	"turnvobject:11",
	"opendoor:22",
	"closedoor:22",
	"waitdooranim:",
	"setdooropen:22",
	"setdoorclosed:22",
	"addelevmenuitem:1222",
	"showelevmenu:",
	"checkcoins:2",
	"addcoins:2",
	"removecoins:2",
	"setwildbattle:212",
	"dowildbattle:",
	"setvaddress:4",
	"vgoto:4",
	"vcall:4",
	"vgoto_if:14",
	"vcall_if:14",
	"vmessage:4",
	"vbuffermessage:4",
	"vbufferstring:14",
	"showcoinsbox:11",
	"hidecoinsbox:11",
	"updatecoinsbox:11",
	"incrementgamestat:1",
	"setescapewarp:11122",
	"waitmoncry:",
	"bufferboxname:12",
	"nop1:",
	"nop1:",
	"nop1:",
	"nop1:",
	"nop1:",
	"nop1:",
	"setmodernfatefulencounter:2",
	"checkmodernfatefulencounter:2",
	"trywondercardscript:",
	"nop1:",
	"warpspinenter:11122",
	"setmonmetlocation:21",
	"moverotatingtileobjects:2",
	"turnrotatingtileobjects:",
	"initrotatingtilepuzzle:2",
	"freerotatingtilepuzzle:",
	"warpmossdeepgym:11122",
	"selectapproachingtrainer:",
	"lockfortrainer:",
	"closebraillemessage:",
	"messageinstant:4",
	"fadescreenswapbuffers:1",
	"buffertrainerclassname:12",
	"buffertrainername:12",
	"pokenavcall:4",
	"warpwhitefade:11122",
	"buffercontestname:12",
	"bufferitemnameplural:122",
]

const RS_COMMANDS: Dictionary = {
	0x0C: "gotoram:",
	0x0D: "killscript:",
	0x11: "writebytetoaddr:14",
	0x12: "loadbytefromaddr:14",
	0x1D: "compare_local_to_addr:14",
	0x1E: "compare_addr_to_local:41",
	0x1F: "compare_addr_to_value:41",
	0x20: "compare_addr_to_addr:44",
	0x50: "applymovement_at:2411",
	0x52: "waitmovement_at:211",
	0x54: "removeobject_at:211",
	0x56: "addobject_at:211",
	0x5D: "trainerbattlebegin:",
	0x64: "moveobjectoffscreen:2",
	0x72: "drawbox:1111",
	0x77: "showcontestwinner:1",
	0x94: "hidemoneybox:11",
	0x96: "getpricereduction:2",
	0x99: "setflashradius:2",
	0xA8: "setobjectpriority:2111",
	0xA9: "resetobjectpriority:211",
	0xBE: "vloadptr:4",
}

const FRLG_COMMANDS: Dictionary = {
	0x2C: "initclock:",
	0x74: "drawboxtext:",
	0x8A: "setberrytree:",
	0x96: "getpokenewsactive:",
	0xB1: "addelevmenuitem:",
	0xC7: "textcolor:1",
	0xC8: "loadhelp:4",
	0xC9: "unloadhelp:",
	0xCA: "signmsg:",
	0xCB: "normalmsg:",
	0xCC: "comparestat:14",
	0xCD: "setmonmodernfatefulencounter:2",
	0xCE: "checkmonmodernfatefulencounter:2",
	0xD0: "setworldmapflag:2",
	0xD3: "getbraillestringwidth:4",
	0xD4: "bufferitemnameplural:122",
}

## battle_setup.c's TrainerBattleLoadArgs consumes texts and optional scripts.
## Mode 9 in FRLG stores defeat/victory texts, not Hoenn's facility arguments.
const TRAINER_WIDTHS: Array[String] = [
	"12244", "122444", "122444", "1224", "122444", "12244",
	"1224444", "122444", "1224444", "12244", "12244", "12244", "12244",
]
const CONTINUATION_MODES: Array[int] = [1, 2, 6, 8]
const TERMINATORS: Array[int] = [2, 3, 5, 12, 13, 0x5E, 0x5F, 0xB9]
## DoWarp's map load replaces the context; these scripts often have no end.
const WARPS: Array[int] = [0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0xD1, 0xD7, 0xE0]

## Operands naming data a handler reads: operand index and table. `loadword 0`
## is msgbox's text, and every trainerbattle word but a continuation is a text.
const DATA_OPERANDS: Dictionary = {
	"message": [0, "texts"], "messageautoscroll": [0, "texts"],
	"messageinstant": [0, "texts"], "pokenavcall": [0, "texts"],
	"loadhelp": [0, "texts"], "bufferstring": [1, "texts"],
	"braillemessage": [0, "braille"], "getbraillestringwidth": [0, "braille"],
	"applymovement": [1, "movements"], "applymovementat": [1, "movements"],
	"applymovement_at": [1, "movements"], "pokemart": [0, "marts"],
	"pokemartdecoration": [0, "decoration_marts"], "pokemartdecoration2": [0, "decoration_marts"],
}
const DATA_TABLES: Array[String] = ["texts", "braille", "movements", "marts", "decoration_marts"]
## A null operand reads ctx->data[0]; EWRAM and IWRAM pointers name run-time buffers.
const RAM_START: int = 0x02000000
const RAM_END: int = 0x04000000
## gMovementActionFuncs' rows; MOVEMENT_ACTION_STEP_END ends a list.
const MOVEMENT_ACTIONS: Dictionary = {
	RomRegistry.RUBY: 138, RomRegistry.SAPPHIRE: 138,
	RomRegistry.FIRERED: 170, RomRegistry.LEAFGREEN: 170, RomRegistry.EMERALD: 158,
}
const MOVEMENT_STEP_END: int = 0xFE
## brailleformat's window bytes precede the six-dot cells except on FireRed and LeafGreen.
const BRAILLE_FORMAT_SIZE: int = 6
const BRAILLE_CELLS: int = 0x40
## gDecorations runs from DECOR_NONE to DECOR_REGISTEEL_DOLL.
const DECORATION_COUNT: int = 121


static func instruction(rom: RomFile, at: int) -> Dictionary:
	if not rom.in_bounds(at, 1):
		return {}
	var opcode: int = rom.u8(at)
	var definition: PackedStringArray = _definition(rom.id, opcode)
	if definition.is_empty():
		return {}
	var widths: String = definition[1]
	if opcode == 0x5C:
		if not rom.in_bounds(at + 1, 1):
			return {}
		var mode: int = rom.u8(at + 1)
		var limit: int = int(FORMAT_COUNTS[rom.id][1])
		if mode >= limit:
			return {}
		widths = TRAINER_WIDTHS[mode]
	var end: int = at + 1
	var operands: Array[int] = []
	for digit: String in widths:
		var width: int = int(digit)
		if not rom.in_bounds(end, width):
			return {}
		operands.append(_operand(rom, end, width))
		end += width
	return {"opcode": opcode, "command": definition[0], "operands": operands,
		"next_offset": end, "bytes": Array(rom.slice(at, end - at))}


static func _frlg(id: StringName) -> bool:
	return id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN]


static func _definition(id: StringName, opcode: int) -> PackedStringArray:
	if not FORMAT_COUNTS.has(id) or opcode >= int(FORMAT_COUNTS[id][0]):
		return PackedStringArray()
	var overrides: Dictionary = {}
	if _frlg(id):
		overrides = FRLG_COMMANDS
	elif id in [RomRegistry.RUBY, RomRegistry.SAPPHIRE]:
		overrides = RS_COMMANDS
	return String(overrides.get(opcode, COMMANDS[opcode])).split(":")


static func _operand(rom: RomFile, at: int, width: int) -> int:
	match width:
		1: return rom.u8(at)
		2: return rom.u16le(at)
		4: return rom.u32le(at)
	return 0


static func read(rom: RomFile, layout: Dictionary, headers: Dictionary) -> Dictionary:
	var standard: Array[int] = _standard(rom, layout)
	var trainers: Array = layout.get("trainer_battle_scripts", [])
	if standard.is_empty() or trainers.size() != 5:
		return {}
	var pending: Array = standard.duplicate()
	pending.append_array(trainers)
	_roots(headers, pending)
	var instructions: Dictionary = {}
	while not pending.is_empty():
		var at: int = int(pending.pop_back())
		var key: String = str(at)
		if instructions.has(key):
			continue
		var row: Dictionary = instruction(rom, at)
		if row.is_empty() or not _flow(rom, row, standard, trainers):
			return {}
		instructions[key] = row
		pending.append_array(row["script_offsets"])
		if bool(row["fallthrough"]):
			pending.append(row["next_offset"])
	var data: Dictionary = _data(rom, layout, instructions)
	if data.is_empty() or not _valid_boundaries(instructions, data):
		return {}
	var out: Dictionary = {"instructions": instructions, "standard": standard, "trainer_battle": trainers}
	out.merge(data)
	return out


## Instructions share no byte with each other or with data. A movement label
## inside another list shares its tail, so overlapping data must end together.
static func _valid_boundaries(instructions: Dictionary, data: Dictionary) -> bool:
	var runs: Array[Vector3i] = []
	for key: String in instructions:
		runs.append(Vector3i(int(key), int(instructions[key]["next_offset"]), 1))
	for table: String in DATA_TABLES:
		for key: String in data[table]:
			runs.append(Vector3i(int(key), int(key) + data_size(data[table][key]), 0))
	runs.sort()
	var last := Vector3i(-1, -1, 0)
	for run: Vector3i in runs:
		if run.x < last.y and (run.y != last.y or run.z == 1 or last.z == 1):
			return false
		last = run
	return true


static func data_size(record: Dictionary) -> int:
	if record.has("entries"):
		return ((record["entries"] as Array).size() + 1) * 2
	return (record["bytes"] as Array).size() + (record.get("format", []) as Array).size()


static func _data(rom: RomFile, layout: Dictionary, instructions: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for table: String in DATA_TABLES:
		out[table] = {}
	for row: Dictionary in instructions.values():
		for pointer: Array in _data_pointers(row):
			var value: int = int(pointer[1])
			if value == 0 or (value >= RAM_START and value < RAM_END):
				continue
			var at: int = Gen3Layout.rom_offset(value)
			var records: Dictionary = out[pointer[0]]
			if records.has(str(at)):
				continue
			var record: Dictionary = _data_record(rom, layout, pointer[0], at)
			if record.is_empty():
				return {}
			records[str(at)] = record
	return out


static func _data_pointers(row: Dictionary) -> Array:
	var operands: Array = row["operands"]
	var command: String = row["command"]
	if command == "loadword":
		return [["texts", operands[1]]] if int(operands[0]) == 0 else []
	if command == "trainerbattle":
		var words: Array = operands.slice(3)
		if int(operands[0]) in CONTINUATION_MODES:
			words.pop_back()
		return words.map(func(word: int) -> Array: return ["texts", word])
	if not DATA_OPERANDS.has(command):
		return []
	var role: Array = DATA_OPERANDS[command]
	return [[role[1], operands[int(role[0])]]]


static func _data_record(rom: RomFile, layout: Dictionary, table: String, at: int) -> Dictionary:
	if not rom.in_bounds(at, 1):
		return {}
	match table:
		"texts":
			var length: int = Gen3Text.span(rom.id, rom.bytes(), at, Gen3Layout.TEXT_LIMIT)
			return {} if length < 0 else {"bytes": Array(rom.slice(at, length))}
		"braille":
			return _braille(rom, at)
		"movements":
			return _movement(rom, at)
		"marts":
			return _mart(rom, at, int(layout["item_count"]))
		"decoration_marts":
			return _mart(rom, at, DECORATION_COUNT)
	return {}


static func _braille(rom: RomFile, at: int) -> Dictionary:
	var header: int = 0 if _frlg(rom.id) else BRAILLE_FORMAT_SIZE
	var cells: int = at + header
	while rom.in_bounds(cells, 1) and cells - at < Gen3Layout.TEXT_LIMIT:
		var cell: int = rom.u8(cells)
		cells += 1
		if cell == Gen3Text.EOS:
			var out: Dictionary = {"bytes": Array(rom.slice(at + header, cells - at - header))}
			if header > 0:
				out["format"] = Array(rom.slice(at, header))
			return out
		if cell >= BRAILLE_CELLS and cell != Gen3Text.NEWLINE:
			return {}
	return {}


static func _movement(rom: RomFile, at: int) -> Dictionary:
	var end: int = at
	while rom.in_bounds(end, 1) and rom.u8(end) != MOVEMENT_STEP_END:
		if rom.u8(end) >= int(MOVEMENT_ACTIONS[rom.id]):
			return {}
		end += 1
	return {"bytes": Array(rom.slice(at, end + 1 - at))} if rom.in_bounds(end, 1) else {}


## SetShopItemsForSale counts halfwords up to ITEM_NONE or DECOR_NONE.
static func _mart(rom: RomFile, at: int, count: int) -> Dictionary:
	var entries: Array[int] = []
	var row: int = at
	while at % 2 == 0 and rom.in_bounds(row, 2):
		var entry: int = rom.u16le(row)
		if entry == 0:
			return {"entries": entries}
		if entry >= count:
			return {}
		entries.append(entry)
		row += 2
	return {}


static func _standard(rom: RomFile, layout: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var at: int = int(layout.get("standard_scripts", -1))
	var count: int = int(layout.get("standard_script_count", 0))
	if count < 1 or not rom.in_bounds(at, count * 4):
		return out
	for slot: int in count:
		var offset: int = Gen3Layout.read_pointer(rom, at + slot * 4, 1, 1)
		if offset < 0:
			return []
		out.append(offset)
	return out


static func _roots(value: Variant, pending: Array) -> void:
	if value is Dictionary:
		for key: Variant in value:
			if key == "script_offset" and int(value[key]) != 0:
				pending.append(int(value[key]))
			else:
				_roots(value[key], pending)
	elif value is Array:
		for row: Variant in value:
			_roots(row, pending)


static func _flow(rom: RomFile, row: Dictionary, standard: Array[int], trainers: Array) -> bool:
	var opcode: int = int(row["opcode"])
	var operands: Array = row["operands"]
	var targets: Array[int] = []
	var fallthrough: bool = opcode not in TERMINATORS and opcode not in WARPS
	if opcode in [4, 5, 6, 7]:
		var target: int = Gen3Layout.rom_offset(int(operands.back()))
		if not rom.in_bounds(target, 1):
			return false
		targets.append(target)
	if opcode in [8, 9, 10, 11] and int(operands.back()) < standard.size():
		targets.append(standard[int(operands.back())])
		if opcode == 8:
			fallthrough = false
	if opcode == 0x5C:
		targets = _trainer_targets(rom, row, trainers)
		if targets == [-1]:
			return false
		fallthrough = false
	row.merge({"script_offsets": targets, "fallthrough": fallthrough})
	return true


static func _trainer_targets(rom: RomFile, row: Dictionary, trainers: Array) -> Array[int]:
	var operands: Array = row["operands"]
	var mode: int = int(operands[0])
	if rom.id == RomRegistry.EMERALD and mode in [10, 11]:
		return []
	var helper: int = 0
	if mode == 3 or (mode == 9 and _frlg(rom.id)):
		helper = 2
	elif mode in [4, 6, 8]:
		helper = 1
	elif mode == 5:
		helper = 3
	elif mode == 7:
		helper = 4
	var out: Array[int] = [int(trainers[helper]), int(row["next_offset"])]
	if mode in CONTINUATION_MODES:
		var continuation: int = Gen3Layout.rom_offset(int(operands.back()))
		if not rom.in_bounds(continuation, 1):
			return [-1]
		out.append(continuation)
	return out
