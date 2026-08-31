class_name Gen2WorldScript
extends RefCounted

## Shared Generation 2 overworld script command definitions.
##
## The cartridge stores one command byte followed by command-specific operands.
## This file describes the byte layout for the commands used by the bounded
## overworld runner. Unknown commands remain visible to the caller instead of
## being guessed or skipped.

const SCALL: int = 0x00
const FARSCALL: int = 0x01
const MEMCALL: int = 0x02
const SJUMP: int = 0x03
const FARSJUMP: int = 0x04
const MEMJUMP: int = 0x05
const IFEQUAL: int = 0x06
const IFNOTEQUAL: int = 0x07
const IFFALSE: int = 0x08
const IFTRUE: int = 0x09
const IFGREATER: int = 0x0A
const IFLESS: int = 0x0B
const JUMPSTD: int = 0x0C
const CALLSTD: int = 0x0D
const CALLASM: int = 0x0E
const SPECIAL: int = 0x0F
const MEMCALLASM: int = 0x10
const CHECKMAPSCENE: int = 0x11
const SETMAPSCENE: int = 0x12
const CHECKSCENE: int = 0x13
const SETSCENE: int = 0x14
const SETVAL: int = 0x15
const ADDVAL: int = 0x16
const RANDOM: int = 0x17
const CHECKVER: int = 0x18
const READMEM: int = 0x19
const WRITEMEM: int = 0x1A
const LOADMEM: int = 0x1B
const READVAR: int = 0x1C
const WRITEVAR: int = 0x1D
const LOADVAR: int = 0x1E
const GIVEITEM: int = 0x1F
const TAKEITEM: int = 0x20
const CHECKITEM: int = 0x21
const GIVEMONEY: int = 0x22
const TAKEMONEY: int = 0x23
const CHECKMONEY: int = 0x24
const GIVECOINS: int = 0x25
const TAKECOINS: int = 0x26
const CHECKCOINS: int = 0x27
const ADDCELLNUM: int = 0x28
const DELCELLNUM: int = 0x29
const CHECKCELLNUM: int = 0x2A
const CHECKTIME: int = 0x2B
const CHECKPOKE: int = 0x2C
const GIVEPOKE: int = 0x2D
const GIVEEGG: int = 0x2E
const GIVEPOKEMAIL: int = 0x2F
const CHECKPOKEMAIL: int = 0x30
const CHECKEVENT: int = 0x31
const CLEAREVENT: int = 0x32
const SETEVENT: int = 0x33
const CHECKFLAG: int = 0x34
const CLEARFLAG: int = 0x35
const SETFLAG: int = 0x36
const WILDON: int = 0x37
const WILDOFF: int = 0x38
const XYCOMPARE: int = 0x39
const WARPMOD: int = 0x3A
const BLACKOUTMOD: int = 0x3B
const WARP: int = 0x3C
const GETMONEY: int = 0x3D
const GETCOINS: int = 0x3E
const GETNUM: int = 0x3F
const GETMONNAME: int = 0x40
const GETITEMNAME: int = 0x41
const GETCURLANDMARKNAME: int = 0x42
const GETTRAINERNAME: int = 0x43
const GETSTRING: int = 0x44
const ITEMNOTIFY: int = 0x45
const POCKETISFULL: int = 0x46
const OPENTEXT: int = 0x47
const REANCHORMAP: int = 0x48
const CLOSETEXT: int = 0x49
const WRITEUNUSEDBYTE: int = 0x4A
const FARWRITETEXT: int = 0x4B
const WRITETEXT: int = 0x4C
const REPEATTEXT: int = 0x4D
const YESORNO: int = 0x4E
const LOADMENU: int = 0x4F
const CLOSEWINDOW: int = 0x50
const JUMPTEXTFACEPLAYER: int = 0x51
const FARJUMPTEXT: int = 0x52
const JUMPTEXT: int = 0x53
const WAITBUTTON: int = 0x54
const PROMPTBUTTON: int = 0x55
const GOLD_FACEPLAYER: int = 0x6A
const FACEPLAYER: int = 0x6B
const GOLD_ENDCALLBACK: int = 0x8F
const GOLD_END: int = 0x90
const ENDCALLBACK: int = 0x90
const END: int = 0x91

## Gold/Silver raw opcodes for the trainer intro sequence. Crystal inserted
## farjumptext at raw $52, so every Gold/Silver opcode at or above $52 shifts
## up by one in Crystal's raw byte stream; see raw_opcode().
const GOLD_LOADTEMPTRAINER: int = 0x5B
const GOLD_STARTBATTLE: int = 0x5E
const GOLD_RELOADMAPAFTERBATTLE: int = 0x5F
const GOLD_TRAINERFLAGACTION: int = 0x62
const GOLD_SCRIPTTALKAFTER: int = 0x64
const GOLD_ENCOUNTERMUSIC: int = 0x7F

const TEXT_START: int = 0x00
## World text uses the source text-command stream. $50 is a page control;
## $57 (done) ends the text box and $58 (prompt) pauses for a prompt.
## `<PARA>`, which waits for a press and clears the box. $50 is `@`, the
## terminator, and reading it as a page break walked `_OakText2` straight
## into the two texts after it.
const TEXT_PAGE: int = 0x51
const TEXT_TERMINATOR: int = 0x57
const TEXT_PROMPT: int = 0x58

## Long map-entry initialization callbacks can include the cartridge's full
## event-variable setup routine, which is larger than one hundred commands.
const MAX_COMMANDS: int = 512
const MAX_CALL_DEPTH: int = 8
const MAX_SCRIPT_BYTES: int = 512
const MAX_TEXT_BYTES: int = 1024

## constants/script_constants.asm's cmdqueue block. An entry is
## `dbw type, address` plus two filler bytes; four fit in wCmdQueue.
const CMDQUEUE_ENTRY_SIZE: int = 5
## `elevfloor` (macros/scripts/maps.asm): `db floor, warp` then `map_id`'s
## `db group, number`. The list opens with a floor count and ends on a `db -1`.
const ELEVATOR_FLOOR_SIZE: int = 4
const ELEVATOR_TERMINATOR: int = 0xFF
const MAX_ELEVATOR_FLOORS: int = 16
const CMDQUEUE_CAPACITY: int = 4
const CMDQUEUE_NULL: int = 0
const CMDQUEUE_STONETABLE: int = 2

## macros/scripts/maps.asm's `stonetable warp_id, object_id, script`, which is
## `db warp_id, object_id` then `dw script`, ending at a $ff warp id. Only two
## maps ship one, so the bound is generous rather than tight.
const STONETABLE_ROW_SIZE: int = 4
const STONETABLE_TERMINATOR: int = 0xFF
const MAX_STONETABLE_ROWS: int = 16


static func pointer_key(bank: int, address: int) -> String:
	return "%d:%04X" % [bank, address]


## Every opcode's command name, on pokegold's numbering. The eight commands the
## two profiles spell differently are [constant PROFILE_COMMAND_NAMES]; an opcode
## in neither is not a command on this profile.
const COMMAND_NAMES: Dictionary = {
	SCALL: &"scall",
	FARSCALL: &"farscall",
	MEMCALL: &"memcall",
	SJUMP: &"sjump",
	FARSJUMP: &"farsjump",
	MEMJUMP: &"memjump",
	IFEQUAL: &"ifequal",
	IFNOTEQUAL: &"ifnotequal",
	IFFALSE: &"iffalse",
	IFTRUE: &"iftrue",
	IFGREATER: &"ifgreater",
	IFLESS: &"ifless",
	JUMPSTD: &"jumpstd",
	CALLSTD: &"callstd",
	CALLASM: &"callasm",
	SPECIAL: &"special",
	MEMCALLASM: &"memcallasm",
	CHECKMAPSCENE: &"checkmapscene",
	SETMAPSCENE: &"setmapscene",
	CHECKSCENE: &"checkscene",
	SETSCENE: &"setscene",
	SETVAL: &"setval",
	ADDVAL: &"addval",
	RANDOM: &"random",
	CHECKVER: &"checkver",
	READMEM: &"readmem",
	WRITEMEM: &"writemem",
	LOADMEM: &"loadmem",
	READVAR: &"readvar",
	WRITEVAR: &"writevar",
	LOADVAR: &"loadvar",
	GIVEITEM: &"giveitem",
	TAKEITEM: &"takeitem",
	CHECKITEM: &"checkitem",
	GIVEMONEY: &"givemoney",
	TAKEMONEY: &"takemoney",
	CHECKMONEY: &"checkmoney",
	GIVECOINS: &"givecoins",
	TAKECOINS: &"takecoins",
	CHECKCOINS: &"checkcoins",
	ADDCELLNUM: &"addcellnum",
	DELCELLNUM: &"delcellnum",
	CHECKCELLNUM: &"checkcellnum",
	CHECKTIME: &"checktime",
	CHECKPOKE: &"checkpoke",
	GIVEPOKE: &"givepoke",
	GIVEEGG: &"giveegg",
	GIVEPOKEMAIL: &"givepokemail",
	CHECKPOKEMAIL: &"checkpokemail",
	CHECKEVENT: &"checkevent",
	CLEAREVENT: &"clearevent",
	SETEVENT: &"setevent",
	CHECKFLAG: &"checkflag",
	CLEARFLAG: &"clearflag",
	SETFLAG: &"setflag",
	WILDON: &"wildon",
	WILDOFF: &"wildoff",
	XYCOMPARE: &"xycompare",
	WARPMOD: &"warpmod",
	BLACKOUTMOD: &"blackoutmod",
	WARP: &"warp",
	GETMONEY: &"getmoney",
	GETCOINS: &"getcoins",
	GETNUM: &"getnum",
	GETMONNAME: &"getmonname",
	GETITEMNAME: &"getitemname",
	GETCURLANDMARKNAME: &"getcurlandmarkname",
	GETTRAINERNAME: &"gettrainername",
	GETSTRING: &"getstring",
	ITEMNOTIFY: &"itemnotify",
	POCKETISFULL: &"pocketisfull",
	OPENTEXT: &"opentext",
	REANCHORMAP: &"reanchormap",
	CLOSETEXT: &"closetext",
	WRITEUNUSEDBYTE: &"writeunusedbyte",
	FARWRITETEXT: &"farwritetext",
	WRITETEXT: &"writetext",
	REPEATTEXT: &"repeattext",
	YESORNO: &"yesorno",
	LOADMENU: &"loadmenu",
	CLOSEWINDOW: &"closewindow",
	JUMPTEXTFACEPLAYER: &"jumptextfaceplayer",
	FACEPLAYER: &"faceplayer",
}

## The opcodes Crystal and pokegold give different names, as [crystal, gold]. An
## empty name is an opcode that profile does not have.
const PROFILE_COMMAND_NAMES: Dictionary = {
	FARJUMPTEXT: [&"farjumptext", &"jumptext"],
	JUMPTEXT: [&"jumptext", &"waitbutton"],
	WAITBUTTON: [&"waitbutton", &"promptbutton"],
	PROMPTBUTTON: [&"promptbutton", &"pokepic"],
	GOLD_FACEPLAYER: [&"", &"faceplayer"],
	GOLD_ENDCALLBACK: [&"", &"endcallback"],
	ENDCALLBACK: [&"endcallback", &"end"],
	END: [&"end", &""],
}


static func command_name(opcode: int, crystal_commands: bool = true) -> StringName:
	var later_name: StringName = _later_command_name(opcode, crystal_commands)
	if not later_name.is_empty():
		return later_name
	if PROFILE_COMMAND_NAMES.has(opcode):
		return PROFILE_COMMAND_NAMES[opcode][0 if crystal_commands else 1]
	return COMMAND_NAMES.get(opcode, &"")


## Command widths in bytes, opcode run by width, on pokegold's numbering. The
## eight the two profiles disagree about are [constant PROFILE_COMMAND_WIDTHS];
## an opcode in neither falls through to the two tables further down.
const COMMAND_WIDTHS: Dictionary = {
	0: [
		GIVEPOKE
	],
	1: [
		CHECKSCENE, CHECKVER, WILDON, WILDOFF, ITEMNOTIFY, POCKETISFULL, OPENTEXT,
		CLOSETEXT, YESORNO, CLOSEWINDOW, WAITBUTTON, ENDCALLBACK
	],
	2: [
		GETCOINS,
		SETSCENE, SETVAL, ADDVAL, RANDOM, READVAR, WRITEVAR, CHECKITEM, ADDCELLNUM,
		DELCELLNUM, CHECKCELLNUM, CHECKTIME, CHECKPOKE, GETNUM, GETCURLANDMARKNAME,
		REANCHORMAP, WRITEUNUSEDBYTE
	],
	3: [
		SCALL, MEMCALL, SJUMP, MEMJUMP, WRITETEXT, JUMPTEXTFACEPLAYER, IFFALSE, IFTRUE,
		JUMPSTD, CALLSTD, READMEM, WRITEMEM, XYCOMPARE, GIVEPOKEMAIL, CHECKPOKEMAIL,
		LOADMENU, SPECIAL, MEMCALLASM, CHECKMAPSCENE, LOADVAR, GIVEITEM, TAKEITEM,
		GIVECOINS, TAKECOINS, CHECKCOINS, CHECKFLAG, CLEARFLAG, SETFLAG, CLEAREVENT,
		SETEVENT, BLACKOUTMOD, GETMONEY, GETMONNAME, GETITEMNAME, GIVEEGG, CHECKEVENT,
		REPEATTEXT
	],
	4: [
		FARSCALL, FARSJUMP, CALLASM, FARWRITETEXT, IFEQUAL, IFNOTEQUAL, IFGREATER, IFLESS,
		LOADMEM, SETMAPSCENE, WARPMOD, GETTRAINERNAME, GETSTRING
	],
	5: [
		GIVEMONEY, TAKEMONEY, CHECKMONEY, WARP
	],
}

## [constant COMMAND_WIDTHS] flattened to opcode: width, built once.
static var WIDTH_OF: Dictionary = _width_of(COMMAND_WIDTHS)


static func _width_of(runs: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for width: int in runs:
		for opcode: int in runs[width]:
			out[opcode] = width
	return out

## The opcodes the two profiles give different widths, as [crystal, gold]. A zero
## falls through to the later table rather than meaning "no command".
const PROFILE_COMMAND_WIDTHS: Dictionary = {
	FARJUMPTEXT: [4, 3],
	JUMPTEXT: [3, 1],
	PROMPTBUTTON: [1, 2],
	GOLD_FACEPLAYER: [0, 1],
	FACEPLAYER: [1, 0],
	GOLD_ENDCALLBACK: [0, 1],
	END: [1, 0],
}


static func command_width(opcode: int, crystal_commands: bool = true) -> int:
	if PROFILE_COMMAND_WIDTHS.has(opcode):
		var profile_width: int = PROFILE_COMMAND_WIDTHS[opcode][0 if crystal_commands else 1]
		if profile_width > 0:
			return profile_width
	if WIDTH_OF.has(opcode):
		return WIDTH_OF[opcode]
	if crystal_commands:
		var crystal_width: int = _crystal_only_command_width(opcode)
		if crystal_width > 0:
			return crystal_width
	return _later_command_width(source_opcode(opcode, crystal_commands))


## Widths for the commands Crystal has and pokegold does not, plus the one
## command whose operands differ between them. Everything else shares
## pokegold's table through source_opcode().
static func _crystal_only_command_width(opcode: int) -> int:
	match opcode:
		0x9F: return 3 # verbosegiveitemvar: item, var
		0xA0: return 4 # swarm: flag, map group, map number (pokegold omits the flag)
		0xA4: return 2 # battletowertext
		0xA5: return 3 # getlandmarkname
		0xA6: return 3 # gettrainerclassname
		0xA7: return 4 # getname
		0xA8: return 2 # wait
		0xA9: return 1 # checksave
	return 0


static func _later_command_width(opcode: int) -> int:
	## Gold/Silver command widths from pokegold's ScriptCommandTable. Crystal
	## inserts farjumptext at $52, so commands after $54 are shifted by one.
	match opcode:
		0x55:
			return 2
		0x56, 0x57, 0x58, 0x59, 0x5A, 0x5B, 0x5E, 0x5F, 0x64, 0x65, 0x66, 0x6A, 0x70, 0x7A, 0x7B, 0x7F, 0x81, 0x82, 0x85, 0x86, 0x87, 0x8D, 0x8F, 0x90, 0x92, 0x98, 0x9C, 0x9F, 0xA0:
			return 1
		0x5C, 0x5D, 0x69, 0x6B, 0x6C, 0x6F, 0x75, 0x76, 0x7C, 0x7E, 0x83, 0x84, 0x8C, 0x8E, 0x94, 0x97, 0x9B, 0x9D, 0x9E:
			return 3
		0x60, 0x61, 0x62, 0x67, 0x6D, 0x6E, 0x72, 0x73, 0x77, 0x7D, 0x89, 0x8A, 0x8B, 0x91, 0x95, 0x96, 0x99, 0x9A:
			return 2
		0x68, 0x71, 0x74, 0x78, 0x79, 0x80, 0x88, 0x93:
			return 4
		0x63:
			return 5
		0xA1:
			return 6
	return 0


## The names Crystal gives the seven raw bytes it inserted, which have no
## pokegold opcode to resolve through.
const CRYSTAL_ONLY_COMMAND_NAMES: Dictionary = {
	0x9F: &"verbosegiveitemvar",
	0xA4: &"battletowertext",
	0xA5: &"getlandmarkname",
	0xA6: &"gettrainerclassname",
	0xA7: &"getname",
	0xA8: &"wait",
	0xA9: &"checksave",
}

## The commands past $55, on pokegold's numbering, which is what
## [method source_opcode] normalizes both profiles onto.
const LATER_COMMAND_NAMES: Dictionary = {
	0x55: &"pokepic",
	0x56: &"closepokepic",
	0x57: &"2dmenu",
	0x58: &"verticalmenu",
	0x59: &"loadpikachudata",
	0x5A: &"randomwildmon",
	0x5B: &"loadtemptrainer",
	0x5C: &"loadwildmon",
	0x5D: &"loadtrainer",
	0x5E: &"startbattle",
	0x5F: &"reloadmapafterbattle",
	0x60: &"catchtutorial",
	0x61: &"trainertext",
	0x62: &"trainerflagaction",
	0x63: &"winlosstext",
	0x64: &"scripttalkafter",
	0x65: &"endifjustbattled",
	0x66: &"checkjustbattled",
	0x67: &"setlasttalked",
	0x68: &"applymovement",
	0x69: &"applymovementlasttalked",
	0x6A: &"faceplayer",
	0x6B: &"faceobject",
	0x6C: &"variablesprite",
	0x6D: &"disappear",
	0x6E: &"appear",
	0x6F: &"follow",
	0x70: &"stopfollow",
	0x71: &"moveobject",
	0x72: &"writeobjectxy",
	0x73: &"loademote",
	0x74: &"showemote",
	0x75: &"turnobject",
	0x76: &"follownotexact",
	0x77: &"earthquake",
	0x78: &"changemapblocks",
	0x79: &"changeblock",
	0x7A: &"reloadmap",
	0x7B: &"refreshmap",
	0x7C: &"writecmdqueue",
	0x7D: &"delcmdqueue",
	0x7E: &"playmusic",
	0x7F: &"encountermusic",
	0x80: &"musicfadeout",
	0x81: &"playmapmusic",
	0x82: &"dontrestartmapmusic",
	0x83: &"cry",
	0x84: &"playsound",
	0x85: &"waitsfx",
	0x86: &"warpsound",
	0x87: &"specialsound",
	0x88: &"autoinput",
	0x89: &"newloadmap",
	0x8A: &"pause",
	0x8B: &"deactivatefacing",
	0x8C: &"sdefer",
	0x8D: &"warpcheck",
	0x8E: &"stopandsjump",
	0x8F: &"endcallback",
	0x90: &"end",
	0x91: &"reloadend",
	0x92: &"endall",
	0x93: &"pokemart",
	0x94: &"elevator",
	0x95: &"trade",
	0x96: &"askforphonenumber",
	0x97: &"phonecall",
	0x98: &"hangup",
	0x99: &"describedecoration",
	0x9A: &"fruittree",
	0x9B: &"specialphonecall",
	0x9C: &"checkphonecall",
	0x9D: &"verbosegiveitem",
	0x9E: &"swarm",
	0x9F: &"halloffame",
	0xA0: &"credits",
	0xA1: &"warpfacing",
}


static func _later_command_name(opcode: int, crystal_commands: bool) -> StringName:
	if opcode < 0x55:
		return &""
	## $55 is the seam between the two tables: pokegold's `pokepic` and Crystal's
	## own `promptbutton`, which is one byte and has no species. The base table
	## already splits them, and answering `pokepic` here shadowed it, so every one
	## of Crystal's promptbuttons decoded under the wrong name and
	## `command_at` read the next command's first byte as a species.
	if crystal_commands and opcode == PROMPTBUTTON:
		return &""
	if crystal_commands and CRYSTAL_ONLY_COMMAND_NAMES.has(opcode):
		return CRYSTAL_ONLY_COMMAND_NAMES[opcode]
	return LATER_COMMAND_NAMES.get(source_opcode(opcode, crystal_commands), &"")


## Normalizes a raw command byte onto pokegold's numbering, which every width,
## name and handler table here is keyed with. Crystal's stream inserts two commands
## pokegold does not have, `farjumptext` at $52 and `verbosegiveitemvar` at $9f, so
## Crystal is one ahead from $53 and two ahead from $a0, and the commands Crystal
## added themselves have no source opcode: callers handle those from the raw byte
## before asking. The low boundary is $56 rather than $53 because every caller
## resolves farjumptext, jumptext, waitbutton and promptbutton from the raw opcode
## first.
static func source_opcode(opcode: int, crystal_commands: bool = true) -> int:
	if not crystal_commands or opcode < 0x56:
		return opcode
	return opcode - 2 if opcode >= 0xA0 else opcode - 1


## The inverse of [method source_opcode], for a caller holding a pokegold opcode
## that needs the raw byte this profile's stream uses.
static func raw_opcode(source_opcode_value: int, crystal_commands: bool = true) -> int:
	if not crystal_commands or source_opcode_value < 0x52:
		return source_opcode_value
	return source_opcode_value + 2 if source_opcode_value >= 0x9E else source_opcode_value + 1


## Converts a raw SPECIAL operand into the Crystal-canonical index the runner's
## handlers are numbered with. data/events/special_pointers.asm's
## SpecialsPointers agrees for the first 47 entries, then Crystal inserts
## BattleTowerFade at 47 and a mobile/Battle Tower block at 109, so Gold/Silver
## 47-107 sit one lower and its last three entries land after that block.
## Gold/Silver 110 is MrChrono, which Crystal has no entry for; -1 leaves it
## unhandled rather than aliasing it onto an unrelated routine.
static func special_index(raw_special: int, crystal_commands: bool = true) -> int:
	if crystal_commands or raw_special <= 46:
		return raw_special
	match raw_special:
		108: return 166
		109: return 167
		110: return -1
		111: return 168
	return raw_special + 1


static func is_endcallback(opcode: int, crystal_commands: bool = true) -> bool:
	return opcode == ENDCALLBACK if crystal_commands else opcode == GOLD_ENDCALLBACK


static func is_end(opcode: int, crystal_commands: bool = true) -> bool:
	return opcode == END if crystal_commands else opcode == GOLD_END


static func is_terminal(opcode: int, crystal_commands: bool = true) -> bool:
	return is_end(opcode, crystal_commands) or is_endcallback(opcode, crystal_commands)


## pokegold-numbered opcodes whose handler reaches ScriptJump, Script_end or
## Script_endall unconditionally, so the bytes after the command are never read
## as one. Two near misses are deliberately absent: `endifjustbattled`'s
## `jp Script_end` sits behind a `ret z`, and `reloadmapafterbattle` jumps only
## on LOSE and otherwise falls into `Script_reloadmap`, whose `StopScript`
## leaves the script pointer where it stands (Route30.asm resumes on the
## `loadmem` after it).
const NON_RETURNING_SOURCE_OPCODES: Array[int] = [
	0x03, 0x04, 0x05,  ## sjump, farsjump, memjump
	0x0C,  ## jumpstd
	0x51,  ## jumptextfaceplayer
	0x64,  ## scripttalkafter
	0x8E, 0x8F, 0x90, 0x91, 0x92,  ## stopandsjump, endcallback, end, reloadend, endall
	0x99, 0x9A,  ## describedecoration, fruittree
	0x9F, 0xA0,  ## halloffame, credits
]


## Whether the command at [param opcode] is followed by another command.
##
## A linear walk over a script stops here, not at [method is_terminal]: a script
## that ends in `jumptext` is followed by the text it named, and a `jumpstd`
## table by its pointers. Only the live runner, which dispatches one command at
## a time and is told where to go next, uses `is_terminal`.
static func continues_after(opcode: int, crystal_commands: bool = true) -> bool:
	if is_text_jump(opcode, crystal_commands):
		return false
	return source_opcode(opcode, crystal_commands) not in NON_RETURNING_SOURCE_OPCODES


static func is_waitbutton(opcode: int, crystal_commands: bool = true) -> bool:
	return opcode == WAITBUTTON if crystal_commands else opcode == 0x53


static func is_promptbutton(opcode: int, crystal_commands: bool = true) -> bool:
	return opcode == PROMPTBUTTON if crystal_commands else opcode == 0x54


static func is_text_jump(opcode: int, crystal_commands: bool = true) -> bool:
	return opcode in [FARJUMPTEXT, JUMPTEXT] if crystal_commands else opcode in [0x51, 0x52]


static func is_text_pointer_command(opcode: int, crystal_commands: bool = true) -> bool:
	if opcode in [WRITETEXT, FARWRITETEXT, JUMPTEXTFACEPLAYER]:
		return true
	return is_text_jump(opcode, crystal_commands)


static func read_u16(data: PackedByteArray, offset: int) -> int:
	return int(data[offset]) | (int(data[offset + 1]) << 8)


## The three operand kinds, which are also their widths in bytes: `db`, `dw` and
## the money commands' own three.
const OPERAND_U8: int = 1
const OPERAND_U16: int = 2
const OPERAND_MONEY: int = 3

## Each command's operands in the order the macro emits them, read from the byte
## after the opcode. Keyed by the raw byte, for the commands both profiles share.
const OPERANDS: Dictionary = {
	SPECIAL: [["value", OPERAND_U16]],
	IFEQUAL: [["value", OPERAND_U8], ["address", OPERAND_U16]],
	IFNOTEQUAL: [["value", OPERAND_U8], ["address", OPERAND_U16]],
	IFGREATER: [["value", OPERAND_U8], ["address", OPERAND_U16]],
	IFLESS: [["value", OPERAND_U8], ["address", OPERAND_U16]],
	LOADMEM: [["address", OPERAND_U16], ["value", OPERAND_U8]],
	CHECKMAPSCENE: [["map_group", OPERAND_U8], ["map_number", OPERAND_U8]],
	SETMAPSCENE: [
		["map_group", OPERAND_U8],
		["map_number", OPERAND_U8],
		["scene", OPERAND_U8]
	],
	SETSCENE: [["scene", OPERAND_U8]],
	SETVAL: [["value", OPERAND_U8]],
	ADDVAL: [["value", OPERAND_U8]],
	RANDOM: [["value", OPERAND_U8]],
	READVAR: [["value", OPERAND_U8]],
	WRITEVAR: [["value", OPERAND_U8]],
	CHECKITEM: [["value", OPERAND_U8]],
	ADDCELLNUM: [["value", OPERAND_U8]],
	DELCELLNUM: [["value", OPERAND_U8]],
	CHECKCELLNUM: [["value", OPERAND_U8]],
	CHECKTIME: [["value", OPERAND_U8]],
	CHECKPOKE: [["value", OPERAND_U8]],
	GETNUM: [["value", OPERAND_U8]],
	GETCURLANDMARKNAME: [["value", OPERAND_U8]],
	REANCHORMAP: [["value", OPERAND_U8]],
	WRITEUNUSEDBYTE: [["value", OPERAND_U8]],
	LOADVAR: [["value", OPERAND_U8], ["value_2", OPERAND_U8]],
	GIVEITEM: [["value", OPERAND_U8], ["value_2", OPERAND_U8]],
	TAKEITEM: [["value", OPERAND_U8], ["value_2", OPERAND_U8]],
	GIVEEGG: [["value", OPERAND_U8], ["value_2", OPERAND_U8]],
	GIVEMONEY: [["account", OPERAND_U8], ["amount_bytes", OPERAND_MONEY]],
	TAKEMONEY: [["account", OPERAND_U8], ["amount_bytes", OPERAND_MONEY]],
	CHECKMONEY: [["account", OPERAND_U8], ["amount_bytes", OPERAND_MONEY]],
	GETMONEY: [["account", OPERAND_U8], ["string_buffer", OPERAND_U8]],
	GETMONNAME: [["pokemon", OPERAND_U8], ["string_buffer", OPERAND_U8]],
	GETITEMNAME: [["item", OPERAND_U8], ["string_buffer", OPERAND_U8]],
	GETTRAINERNAME: [
		["trainer_group", OPERAND_U8],
		["trainer_id", OPERAND_U8],
		["string_buffer", OPERAND_U8]
	],
	GETSTRING: [["address", OPERAND_U16], ["string_buffer", OPERAND_U8]],
	CLEAREVENT: [["flag", OPERAND_U16]],
	SETEVENT: [["flag", OPERAND_U16]],
	CHECKFLAG: [["flag", OPERAND_U16]],
	CLEARFLAG: [["flag", OPERAND_U16]],
	SETFLAG: [["flag", OPERAND_U16]],
	CHECKEVENT: [["flag", OPERAND_U16]],
	GIVECOINS: [["value", OPERAND_U16]],
	TAKECOINS: [["value", OPERAND_U16]],
	CHECKCOINS: [["value", OPERAND_U16]],
	BLACKOUTMOD: [["map_group", OPERAND_U8], ["map_number", OPERAND_U8]],
	WARPMOD: [
		["warp_id", OPERAND_U8],
		["map_group", OPERAND_U8],
		["map_number", OPERAND_U8]
	],
	WARP: [
		["map_group", OPERAND_U8],
		["map_number", OPERAND_U8],
		["x", OPERAND_U8],
		["y", OPERAND_U8]
	],
	REPEATTEXT: [["value", OPERAND_U8], ["value_2", OPERAND_U8]],
	GETCOINS: [["string_buffer", OPERAND_U8]],
}

## The rows Crystal reads differently: the commands it inserted, which have no
## pokegold opcode behind them. A row here is the whole answer.
const CRYSTAL_OPERANDS: Dictionary = {
	0x9F: [["item", OPERAND_U8], ["variable", OPERAND_U8]],
	0xA0: [
		["flag", OPERAND_U8], ["map_group", OPERAND_U8], ["map_number", OPERAND_U8]
	],
	0xA4: [["value", OPERAND_U8]],
	0xA5: [["landmark", OPERAND_U8], ["string_buffer", OPERAND_U8]],
	0xA6: [["trainer_group", OPERAND_U8], ["string_buffer", OPERAND_U8]],
	0xA7: [
		["name_type", OPERAND_U8], ["value", OPERAND_U8],
		["string_buffer", OPERAND_U8]
	],
	0xA8: [["value", OPERAND_U8]],
}

## The commands past the seam, on pokegold's numbering.
const LATER_OPERANDS: Dictionary = {
	0x55: [["pokemon", OPERAND_U8]],
	0x5C: [["pokemon", OPERAND_U8], ["level", OPERAND_U8]],
	0x5D: [["trainer_group", OPERAND_U8], ["trainer_id", OPERAND_U8]],
	0x60: [["value", OPERAND_U8]],
	0x61: [["value", OPERAND_U8]],
	0x62: [["value", OPERAND_U8]],
	0x63: [["win_address", OPERAND_U16], ["loss_address", OPERAND_U16]],
	0x67: [["object_id", OPERAND_U8]],
	0x68: [["object_id", OPERAND_U8], ["address", OPERAND_U16]],
	0x69: [["address", OPERAND_U16]],
	0x6B: [["object_id", OPERAND_U8], ["object_id_2", OPERAND_U8]],
	0x6C: [["value", OPERAND_U8], ["value_2", OPERAND_U8]],
	0x6D: [["object_id", OPERAND_U8]],
	0x6E: [["object_id", OPERAND_U8]],
	0x72: [["object_id", OPERAND_U8]],
	0x6F: [["object_id", OPERAND_U8], ["object_id_2", OPERAND_U8]],
	0x76: [["object_id", OPERAND_U8], ["object_id_2", OPERAND_U8]],
	0x71: [["object_id", OPERAND_U8], ["x", OPERAND_U8], ["y", OPERAND_U8]],
	0x74: [["value", OPERAND_U8], ["object_id", OPERAND_U8], ["value_2", OPERAND_U8]],
	0x75: [["object_id", OPERAND_U8], ["facing", OPERAND_U8]],
	0x77: [["value", OPERAND_U8]],
	0x78: [["bank", OPERAND_U8], ["address", OPERAND_U16]],
	0x88: [["bank", OPERAND_U8], ["address", OPERAND_U16]],
	0x79: [["x", OPERAND_U8], ["y", OPERAND_U8], ["block", OPERAND_U8]],
	0x7C: [["address", OPERAND_U16]],
	0x7E: [["address", OPERAND_U16]],
	0x8C: [["address", OPERAND_U16]],
	0x8E: [["address", OPERAND_U16]],
	0x94: [["address", OPERAND_U16]],
	0x97: [["address", OPERAND_U16]],
	0x9B: [["address", OPERAND_U16]],
	0x7D: [["value", OPERAND_U8]],
	0x89: [["value", OPERAND_U8]],
	0x8A: [["value", OPERAND_U8]],
	0x8B: [["value", OPERAND_U8]],
	0x80: [["value", OPERAND_U16], ["value_2", OPERAND_U8]],
	0x83: [["value", OPERAND_U16]],
	0x84: [["value", OPERAND_U16]],
	0x93: [["value", OPERAND_U8], ["address", OPERAND_U16]],
	0x95: [["value", OPERAND_U8]],
	0x96: [["value", OPERAND_U8]],
	0x99: [["value", OPERAND_U8]],
	0x9A: [["value", OPERAND_U8]],
	0x9D: [["item", OPERAND_U8], ["quantity", OPERAND_U8]],
	0x9E: [["map_group", OPERAND_U8], ["map_number", OPERAND_U8]],
	0xA1: [
		["facing", OPERAND_U8],
		["map_group", OPERAND_U8],
		["map_number", OPERAND_U8],
		["x", OPERAND_U8],
		["y", OPERAND_U8]
	],
}


## One command's operands, in the order [constant OPERANDS] lists them.
static func _read_operands(
	command: Dictionary, data: PackedByteArray, offset: int, rows: Array
) -> void:
	var at: int = offset + 1
	for row: Array in rows:
		var kind: int = int(row[1])
		if kind == OPERAND_U16:
			command[String(row[0])] = read_u16(data, at)
		elif kind == OPERAND_MONEY:
			command[String(row[0])] = PackedByteArray([
				int(data[at]), int(data[at + 1]), int(data[at + 2])
			])
		else:
			command[String(row[0])] = int(data[at])
		at += kind


static func command_at(
	data: PackedByteArray, offset: int, crystal_commands: bool = true
) -> Dictionary:
	if offset < 0 or offset >= data.size():
		return {"ok": false, "reason": &"truncated_opcode", "offset": offset}
	var opcode: int = int(data[offset])
	var width: int = command_width(opcode, crystal_commands)
	if opcode == GIVEPOKE:
		return _givepoke_command_at(data, offset)
	if width <= 0:
		return {
			"ok": false,
			"reason": &"unsupported_command",
			"offset": offset,
			"opcode": opcode,
			"name": command_name(opcode, crystal_commands),
		}
	if offset + width > data.size():
		return {
			"ok": false,
			"reason": &"truncated_operands",
			"offset": offset,
			"opcode": opcode,
			"name": command_name(opcode, crystal_commands),
			"width": width,
		}
	var command: Dictionary = {
		"ok": true,
		"offset": offset,
		"opcode": opcode,
		"name": command_name(opcode, crystal_commands),
		"width": width,
	}
	if opcode in [SCALL, MEMCALL, SJUMP, MEMJUMP, MEMCALLASM, WRITETEXT, JUMPTEXTFACEPLAYER,
		IFFALSE, IFTRUE, JUMPSTD, CALLSTD, READMEM, WRITEMEM, XYCOMPARE,
		GIVEPOKEMAIL, CHECKPOKEMAIL, LOADMENU] \
		or (crystal_commands and opcode == JUMPTEXT) \
		or (not crystal_commands and opcode == FARJUMPTEXT):
		command["address"] = read_u16(data, offset + 1)
		return command
	if opcode in [FARSCALL, FARSJUMP, FARWRITETEXT, CALLASM] \
		or (crystal_commands and opcode == FARJUMPTEXT):
		command["bank"] = int(data[offset + 1])
		command["address"] = read_u16(data, offset + 2)
		return command
	if crystal_commands and CRYSTAL_OPERANDS.has(opcode):
		_read_operands(command, data, offset, CRYSTAL_OPERANDS[opcode])
		return command
	_read_operands(command, data, offset, OPERANDS.get(opcode, []))
	var source: int = source_opcode(opcode, crystal_commands)
	## Crystal's own $55 is `promptbutton`, one byte and no species; only
	## pokegold's $55 is `pokepic`. See [method _later_command_name].
	if source == 0x55 and command["name"] != &"pokepic":
		return command
	_read_operands(command, data, offset, LATER_OPERANDS.get(source, []))
	return command


static func _givepoke_command_at(data: PackedByteArray, offset: int) -> Dictionary:
	## givepoke is the one base command whose width depends on its trainer flag.
	## The macro emits four operands for an ordinary gift and two extra near
	## pointers when the gift carries trainer data.
	var base_width: int = 5
	if offset < 0 or offset + base_width > data.size():
		return {
			"ok": false, "reason": &"truncated_operands", "offset": offset,
			"opcode": GIVEPOKE, "name": &"givepoke", "width": base_width,
		}
	var trainer: int = int(data[offset + 4])
	var width: int = 9 if trainer != 0 else base_width
	if offset + width > data.size():
		return {
			"ok": false, "reason": &"truncated_operands", "offset": offset,
			"opcode": GIVEPOKE, "name": &"givepoke", "width": width,
		}
	var command: Dictionary = {
		"ok": true, "offset": offset, "opcode": GIVEPOKE, "name": &"givepoke",
		"width": width, "pokemon": int(data[offset + 1]),
		"level": int(data[offset + 2]), "item": int(data[offset + 3]),
		"trainer": trainer,
	}
	if trainer != 0:
		command["nickname_address"] = read_u16(data, offset + 5)
		command["ot_name_address"] = read_u16(data, offset + 7)
	return command


static func scan_references(
	data: PackedByteArray, bank: int, _address: int, crystal_commands: bool = true
) -> Dictionary:
	## Scans only commands understood by this slice. An unknown command stops the
	## scan because its operand width cannot be inferred safely.
	var out: Dictionary = {
		"scripts": [], "texts": [], "movements": [],
		"command_queues": [], "elevators": [],
	}
	var at: int = 0
	var command_count: int = 0
	while at < data.size() and command_count < MAX_COMMANDS:
		var command: Dictionary = command_at(data, at, crystal_commands)
		if not bool(command.get("ok", false)):
			break
		var opcode: int = int(command["opcode"])
		_scan_opcode(out, command, opcode, bank, crystal_commands)
		_scan_source_opcode(
			out, command, Gen2WorldScript.source_opcode(opcode, crystal_commands), bank
		)
		at += int(command["width"])
		command_count += 1
		if not continues_after(opcode, crystal_commands):
			break
	return out


static func _scan_opcode(
	out: Dictionary, command: Dictionary, opcode: int, bank: int, crystal_commands: bool
) -> void:
	var scripts: Array = out["scripts"]
	var texts: Array = out["texts"]
	match opcode:
		SCALL, SJUMP:
			scripts.append({"bank": bank, "address": int(command["address"])})
		IFEQUAL, IFNOTEQUAL, IFFALSE, IFTRUE, IFGREATER, IFLESS:
			scripts.append({"bank": bank, "address": int(command["address"])})
		FARSCALL, FARSJUMP:
			scripts.append({"bank": int(command["bank"]), "address": int(command["address"])})
		WRITETEXT, JUMPTEXTFACEPLAYER:
			texts.append({"bank": bank, "address": int(command["address"])})
		GETSTRING:
			texts.append({"bank": bank, "address": int(command["address"])})
		JUMPTEXT:
			if crystal_commands:
				texts.append({"bank": bank, "address": int(command["address"])})
		FARWRITETEXT:
			texts.append({"bank": int(command["bank"]), "address": int(command["address"])})
		FARJUMPTEXT:
			if crystal_commands:
				texts.append({"bank": int(command["bank"]), "address": int(command["address"])})
			else:
				texts.append({"bank": bank, "address": int(command["address"])})


static func _scan_source_opcode(
	out: Dictionary, command: Dictionary, source: int, bank: int
) -> void:
	match source:
		0x68, 0x69:
			(out["movements"] as Array).append({"bank": bank, "address": int(command["address"])})
		0x63:
			var texts: Array = out["texts"]
			texts.append({"bank": bank, "address": int(command["win_address"])})
			texts.append({"bank": bank, "address": int(command["loss_address"])})
		0x8C, 0x8E:
			(out["scripts"] as Array).append({"bank": bank, "address": int(command["address"])})
		0x97:
			## phonecall passes a caller-name text pointer to PhoneCall. It is
			## not a script pointer and must be collected as text data.
			(out["texts"] as Array).append({"bank": bank, "address": int(command["address"])})
		0x7C:
			## writecmdqueue points at a cmdqueue entry, which is data rather
			## than script, so it is collected as its own kind.
			(out["command_queues"] as Array).append({
				"bank": bank, "address": int(command["address"]),
			})
		0x94:
			## elevator points at an `elevfloor` list, which is data rather than
			## script, and `Elevator.LoadPointer` reads it out of the map scripts
			## bank the command itself sits in.
			(out["elevators"] as Array).append({"bank": bank, "address": int(command["address"])})


## Decodes one `cmdqueue` entry: `dbw type, address` and two filler bytes
## (macros/scripts/maps.asm). Answers the type and the data pointer only; what
## the pointer means is the type's business.
static func decode_command_queue_entry(data: PackedByteArray) -> Dictionary:
	if data.size() < CMDQUEUE_ENTRY_SIZE:
		return {"ok": false, "reason": &"short_command_queue_entry"}
	var type: int = data[0]
	if type == CMDQUEUE_NULL:
		return {"ok": false, "reason": &"null_command_queue"}
	return {
		"ok": true,
		"type": type,
		"address": data[1] | (data[2] << 8),
	}


## Decodes a `stonetable`, the only cmdqueue payload either game ships.
##
## Rows are `warp_id, object_id, script` until a $ff warp id, and the ids are
## the source's own: the warp is one-based, as `.check_on_warp` counts it, and
## the object is an `object_const_def` constant, which starts at 2, so it is two
## more than the map's own object index.
static func decode_stone_table(data: PackedByteArray) -> Dictionary:
	var rows: Array = []
	var at: int = 0
	while at < data.size() and rows.size() <= MAX_STONETABLE_ROWS:
		if data[at] == STONETABLE_TERMINATOR:
			return {"ok": true, "rows": rows, "bytes": at + 1}
		if at + STONETABLE_ROW_SIZE > data.size():
			break
		rows.append({
			"warp": data[at],
			"object": data[at + 1],
			"script": data[at + 2] | (data[at + 3] << 8),
		})
		at += STONETABLE_ROW_SIZE
	return {"ok": false, "reason": &"unterminated_stone_table", "rows": rows}


## Decodes an `elevfloor` list: the floor count, then one row per floor until
## the `db -1`. `Elevator.LoadFloors` reads the count and walks the rows at a
## four-byte stride, and `Elevator_GoToFloor` copies a row's last three bytes
## straight over `wBackupWarpNumber`, which is what the warp out of the car
## then spends.
static func decode_elevator_floors(data: PackedByteArray) -> Dictionary:
	if data.is_empty():
		return {"ok": false, "reason": &"short_elevator_list"}
	var count: int = data[0]
	if count <= 0 or count > MAX_ELEVATOR_FLOORS:
		return {"ok": false, "reason": &"unsupported_elevator_count", "count": count}
	var floors: Array = []
	var at: int = 1
	while floors.size() < count:
		if at >= data.size() or data[at] == ELEVATOR_TERMINATOR:
			return {"ok": false, "reason": &"short_elevator_list", "floors": floors}
		if at + ELEVATOR_FLOOR_SIZE > data.size():
			return {"ok": false, "reason": &"short_elevator_list", "floors": floors}
		floors.append({
			"floor": data[at],
			"warp": data[at + 1],
			"map_group": data[at + 2],
			"map_number": data[at + 3],
		})
		at += ELEVATOR_FLOOR_SIZE
	if at >= data.size() or data[at] != ELEVATOR_TERMINATOR:
		return {"ok": false, "reason": &"unterminated_elevator_list", "floors": floors}
	return {"ok": true, "floors": floors, "bytes": at + 1}


## A world text with nothing to substitute into it. Anything carrying a name,
## a string buffer or a `text_far` goes through [Gen2TextStream] with a
## context; this is the bare form a tool or a fixture reads.
static func decode_text(data: PackedByteArray) -> Dictionary:
	return Gen2TextStream.decode(data)
