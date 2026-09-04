class_name Gen2TextStream
extends RefCounted

## `home/text.asm`'s printer: the layer above [Gen2Text]. A cartridge text is two
## languages, not one. `DoTextUntilTerminator` reads *text commands*, `$00` to
## `$16`, each with its own operand width; `TX_START` hands what follows to
## `PlaceString`, which reads *characters*. The same byte means different things
## in the two: `$16` is `TX_FAR` to one and `<CR>` to the other, and `$50` ends a
## literal for one and the whole text for the other, which is why a reader that
## treated it as a page break walked straight into the next text. Names are
## substituted here, because `PrintPlayerName` is a `CheckDict` entry.

## `macros/scripts/text.asm`, the `TextCommands` indices.
const TX_START: int = 0x00
const TX_RAM: int = 0x01
const TX_BCD: int = 0x02
const TX_MOVE: int = 0x03
const TX_BOX: int = 0x04
const TX_LOW: int = 0x05
const TX_PROMPT_BUTTON: int = 0x06
const TX_SCROLL: int = 0x07
const TX_START_ASM: int = 0x08
const TX_DECIMAL: int = 0x09
const TX_PAUSE: int = 0x0A
const TX_DOTS: int = 0x0C
const TX_WAIT_BUTTON: int = 0x0D
const TX_STRINGBUFFER: int = 0x14
const TX_DAY: int = 0x15
const TX_FAR: int = 0x16
const TX_END: int = 0x50

## `<PLAY_G>`, which is `TX_STRINGBUFFER`'s byte read as a character rather than
## as a command. `constants/charmap.asm` maps it and `CheckDict` sends it to
## `PlaceGenderedPlayerName`, so it is the player's name; 243 Crystal texts use
## it and no Gold or Silver text does, their `CheckDict` having no entry for it.
const CHAR_PLAY_G: int = 0x14

## What an unfilled slot in a decoded text opens with. A caller that knows the
## value puts it in through [method fill_marker]; one that does not can at least
## see that something belongs there.
const RAM_MARKER: String = "<RAM_"
const NUMBER_MARKER: String = "<NUM_"

## `TextSFX`: the seven command bytes that play an effect and `WaitSFX`.
const TX_SOUND: Array[int] = [0x0B, 0x0E, 0x0F, 0x10, 0x11, 0x12, 0x13]

## Generation 1's `TextCommands` agree as far as `TX_PAUSE` and then part: $14 to
## $16 are three more cries where Crystal has the buffer, the weekday and TX_FAR.
const GEN1_TX_SOUND: Array[int] = [
	0x0B, 0x0E, 0x0F, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16,
]
const GEN1_TX_FAR: int = 0x17

## `CheckDict` entries that are not characters.
const CHAR_NULL: int = 0x00
const CHAR_BSP: int = 0x1F
const CHAR_LF: int = 0x22
const CHAR_WBR: int = 0x25
const CHAR_PAGE: int = 0x49
const CHAR_CONT_RAW: int = 0x4B
const CHAR_SCROLL: int = 0x4C
const CHAR_NEXT: int = 0x4E
const CHAR_LINE: int = 0x4F
const CHAR_PARA: int = 0x51
const CHAR_CONT: int = 0x55
const CHAR_DONE: int = 0x57
const CHAR_PROMPT: int = 0x58
const CHAR_DEXEND: int = 0x5F

## What the two waits become in the laid-out string. `Paragraph` clears the box
## and starts again at the top line; `_ContText` scrolls by one line and starts at
## the bottom, so the line above stays on screen. A layout that cannot tell them
## apart drops a line every time a paragraph runs past two lines. Private-use code
## points rather than control characters: a cache is JSON and Godot writes U+000B
## as `\v`, which JSON has no escape for.
const PAGE_BREAK: String = "\ue000"
const SCROLL_BREAK: String = "\ue001"
## `_ContTextNoPause`, which `<SCROLL>` and `TextCommand_SCROLL` reach directly:
## the same two `TextScroll`s with no `PromptButton` in front of them, so the box
## rolls on without a press.
const SCROLL_NOWAIT_BREAK: String = "\ue002"

## `GetWeekday`'s `.Days`, which `TextCommand_DAY` follows with "DAY".
const WEEKDAYS: Array[String] = [
	"SUN", "MON", "TUES", "WEDNES", "THURS", "FRI", "SATUR",
]

## What a character does to the laid-out string instead of drawing itself.
## Anything not here is a glyph or a name.
const BREAKS: Dictionary = {
	CHAR_LF: "\n", CHAR_NEXT: "\n", CHAR_LINE: "\n",
	CHAR_PARA: PAGE_BREAK,
	CHAR_CONT: SCROLL_BREAK, CHAR_CONT_RAW: SCROLL_BREAK,
	CHAR_SCROLL: SCROLL_NOWAIT_BREAK,
	CHAR_WBR: "", CHAR_BSP: " ", CHAR_DEXEND: ".",
}

## Generation 1's, whose `PlaceNextChar` has no `<LF>`, `<BSP>` or `<WBR>` and
## reaches `PageChar` on the $49 Crystal spends on `<MOM>`.
const GEN1_BREAKS: Dictionary = {
	CHAR_PAGE: "\n", CHAR_NEXT: "\n", CHAR_LINE: "\n",
	CHAR_PARA: PAGE_BREAK,
	CHAR_CONT: SCROLL_BREAK, CHAR_CONT_RAW: SCROLL_BREAK,
	CHAR_SCROLL: SCROLL_NOWAIT_BREAK,
	CHAR_DEXEND: ".",
}

## `CheckDict`'s `print_name` entries: the [param context] key each code reads.
const NAMES: Dictionary = {
	CHAR_PLAY_G: "player", 0x52: "player", 0x53: "rival", 0x49: "mom",
	0x38: "red", 0x39: "green", 0x3F: "enemy", 0x59: "target", 0x5A: "user",
}

## Generation 1's four; its other `print_name` entries spell whole words rather
## than reading RAM, so [Gen1Text] answers them.
const GEN1_NAMES: Dictionary = {
	0x52: "player", 0x53: "rival", 0x59: "target", 0x5A: "user",
}


## Runs a text from [param offset] to its terminator.
##
## [param context] carries what the print-time codes read: `player`, `rival`,
## `mom`, `red`, `green`, `enemy`, `target` and `user` names, a `buffers`
## dictionary for `TX_STRINGBUFFER`, a `ram` dictionary keyed by address for
## `TX_RAM`, a `weekday` index for `TX_DAY`, and a `far` [Callable] taking
## (bank, address) and answering the bytes, for `TX_FAR`.
static func decode(
	data: PackedByteArray, offset: int = 0, context: Dictionary = {}
) -> Dictionary:
	if data.is_empty():
		return {"ok": false, "reason": &"missing_text"}
	return _run(data, offset, context, 0)


static func _run(
	data: PackedByteArray, offset: int, context: Dictionary, depth: int
) -> Dictionary:
	var gen1: bool = is_gen1(context)
	var far_command: int = GEN1_TX_FAR if gen1 else TX_FAR
	var sounds: Array[int] = GEN1_TX_SOUND if gen1 else TX_SOUND
	var out: String = ""
	var at: int = offset
	var prompt: bool = false
	while at < data.size():
		var command: int = int(data[at])
		at += 1
		if command == TX_END:
			return {"ok": true, "text": out, "bytes": at, "prompt": prompt}
		if command == TX_START:
			var placed: Dictionary = _place(data, at, context)
			out += String(placed["text"])
			at = int(placed["at"])
			if bool(placed.get("truncated", false)):
				return _truncated(out, &"missing_text_terminator")
			if bool(placed.get("ended", false)):
				return {
					"ok": true, "text": out, "bytes": at,
					"prompt": bool(placed.get("prompt", false)),
				}
			continue
		if command in sounds:
			# The effect plays and `WaitSFX` holds the printer; nothing is drawn.
			continue
		if command == far_command:
			return _far_command(data, at, context, depth, out)
		if command == TX_START_ASM:
			# `jp hl` into code. Nothing after it can be read as text.
			return {"ok": true, "text": out, "bytes": at, "prompt": prompt}
		var step: Dictionary = _step_command(data, at, context, command)
		if step.has("reason"):
			return _truncated(out, StringName(step["reason"]))
		if step.is_empty():
			return {
				"ok": false, "reason": &"unknown_text_command",
				"text": out, "command": command,
			}
		out += String(step.get("text", ""))
		at = int(step["at"])
		prompt = prompt or bool(step.get("prompt", false))
	return {"ok": false, "reason": &"missing_text_terminator", "text": out}


## `TextCommand_FAR`'s three operands and the text they name, which ends the
## text the command appears in either way.
static func _far_command(
	data: PackedByteArray, at: int, context: Dictionary, depth: int, out: String
) -> Dictionary:
	if not _has(data, at, 3):
		return _truncated(out, &"truncated_text_far")
	var far: Dictionary = _far(
		context, int(data[at + 2]), data[at] | (data[at + 1] << 8), depth
	)
	var text: String = out + String(far.get("text", ""))
	if not bool(far.get("ok", false)):
		return {"ok": false, "reason": far.get("reason", &"invalid_far_text"), "text": text}
	return {
		"ok": true, "text": text, "bytes": at + 3,
		"prompt": bool(far.get("prompt", false)),
	}


## A `reason` means the operands ran off the end; empty means another opcode.
static func _step_command(
	data: PackedByteArray, at: int, context: Dictionary, command: int
) -> Dictionary:
	match command:
		TX_RAM:
			if not _has(data, at, 2):
				return {"reason": &"truncated_text_ram"}
			return {"text": _ram_string(context, data[at] | (data[at + 1] << 8)), "at": at + 2}
		TX_STRINGBUFFER:
			if not _has(data, at, 1):
				return {"reason": &"truncated_text_buffer"}
			return {"text": _buffer_string(context, int(data[at])), "at": at + 1}
		TX_DOTS:
			if not _has(data, at, 1):
				return {"reason": &"truncated_text_dots"}
			return {"text": "…".repeat(maxi(int(data[at]), 0)), "at": at + 1}
		TX_DAY:
			return {"text": _weekday(context) + "DAY", "at": at}
		TX_LOW:
			return {"text": "\n", "at": at}
		TX_SCROLL:
			return {"text": SCROLL_NOWAIT_BREAK, "at": at}
		TX_PROMPT_BUTTON, TX_WAIT_BUTTON:
			# Both wait for a press; only the first shows the arrow, which is
			# the box's business rather than the string's.
			return {"text": PAGE_BREAK, "at": at, "prompt": true}
		TX_PAUSE:
			return {"at": at}
		TX_DECIMAL:
			# `text_decimal address, bytes, digits`: a number printed out of
			# live RAM. Marked rather than skipped, the way TX_RAM is, so a
			# caller that does know the value can put it in and one that does
			# not can see that a number belongs there.
			if not _has(data, at, 3):
				return {"reason": &"truncated_text_command"}
			return {
				"text": _decimal_string(context, data[at] | (data[at + 1] << 8)),
				"at": at + 3,
			}
		TX_BCD:
			# `dw address, db flags`, a packed-decimal number out of live RAM.
			# Marked the way TX_DECIMAL is; no Crystal text uses it, and every
			# Generation 1 one that does is a price.
			if not _has(data, at, 3):
				return {"reason": &"truncated_text_command"}
			return {
				"text": _decimal_string(context, data[at] | (data[at + 1] << 8)),
				"at": at + 3,
			}
		TX_MOVE:
			# `dw address` alone, and it prints nothing. Reading a third byte here
			# slid every command behind it.
			if not _has(data, at, 2):
				return {"reason": &"truncated_text_command"}
			return {"at": at + 2}
		TX_BOX:
			if not _has(data, at, 4):
				return {"reason": &"truncated_text_command"}
			return {"at": at + 4}
	return {}


## `PlaceString`/`CheckDict`: characters until the `@` that ends the literal.
static func _place(data: PackedByteArray, offset: int, context: Dictionary) -> Dictionary:
	var gen1: bool = is_gen1(context)
	var breaks: Dictionary = GEN1_BREAKS if gen1 else BREAKS
	var out: String = ""
	var at: int = offset
	while at < data.size():
		var byte: int = int(data[at])
		at += 1
		if byte == TX_END:
			return {"text": out, "at": at, "ended": false}
		# `NullChar` prints a debugging error string, so it ends the text rather
		# than being reproduced.
		if byte == CHAR_DONE or byte == CHAR_NULL:
			return {"text": out, "at": at, "ended": true, "prompt": false}
		if byte == CHAR_PROMPT:
			return {"text": out, "at": at, "ended": true, "prompt": true}
		if breaks.has(byte):
			out += String(breaks[byte])
			continue
		out += _dict(byte, context, gen1)
	# Off the end of the data with no `@`, `<DONE>` or `<PROMPT>`: the text
	# is truncated, which is a wrong offset rather than a finished string.
	return {"text": out, "at": at, "truncated": true}


## The `print_name` half of `CheckDict`; everything else is a glyph the
## generation's own codec answers. `PlaceGenderedPlayerName` places `wPlayerName`.
static func _dict(byte: int, context: Dictionary, gen1: bool) -> String:
	var names: Dictionary = GEN1_NAMES if gen1 else NAMES
	if names.has(byte):
		var key: String = String(names[byte])
		return _name(context, key, "<%s>" % key.to_upper())
	return Gen1Text.character(byte) if gen1 else Gen2Text.character(byte)


## Whether [param context] names a Generation 1 cartridge; absent is Generation 2.
static func is_gen1(context: Dictionary) -> bool:
	return int(context.get("generation", RomRegistry.GEN2)) == RomRegistry.GEN1


static func _name(context: Dictionary, key: String, fallback: String) -> String:
	var value: String = String(context.get(key, ""))
	return value if not value.is_empty() else fallback


## The print-time names still standing as markers, keyed as [constant NAMES]
## values are. Generation 1's texts are decoded at import, with no save to read
## a name out of.
static func fill_names(text: String, names: Dictionary) -> String:
	var out: String = text
	for key: String in names:
		out = out.replace("<%s>" % key.to_upper(), String(names[key]))
	return out


## Replaces the first marker of [param prefix] in [param text] with
## [param value]. The address inside a marker is the profile's own WRAM, so a
## screen substitutes by position rather than by naming one.
static func fill_marker(text: String, prefix: String, value: String) -> String:
	var at: int = text.find(prefix)
	if at < 0:
		return text
	var end: int = text.find(">", at)
	if end < 0:
		return text
	return text.substr(0, at) + value + text.substr(end + 1)


## Every marker of [param prefix], not just the first. `_NameRaterPerfectNameText`
## names `wStringBuffer1` twice, and a text with one marker is unchanged by the
## second pass.
static func fill_all_markers(text: String, prefix: String, value: String) -> String:
	var out: String = text
	while out.find(prefix) >= 0:
		var filled: String = fill_marker(out, prefix, value)
		if filled == out:
			break
		out = filled
	return out


static func _ram_string(context: Dictionary, address: int) -> String:
	var ram: Variant = context.get("ram", {})
	if ram is Dictionary and (ram as Dictionary).has(address):
		return String((ram as Dictionary)[address])
	return "%s%04X>" % [RAM_MARKER, address]


static func _decimal_string(context: Dictionary, address: int) -> String:
	var decimals: Variant = context.get("decimals", {})
	if decimals is Dictionary and (decimals as Dictionary).has(address):
		return String((decimals as Dictionary)[address])
	return "%s%04X>" % [NUMBER_MARKER, address]


static func _buffer_string(context: Dictionary, buffer: int) -> String:
	var buffers: Variant = context.get("buffers", {})
	if buffers is Dictionary and (buffers as Dictionary).has(buffer):
		return String((buffers as Dictionary)[buffer])
	return "<BUFFER_%d>" % buffer


## `GetWeekday`'s own answer, which `TextCommand_DAY` and the Pokegear's clock
## card both print.
static func weekday_name(day: int) -> String:
	return WEEKDAYS[posmod(day, WEEKDAYS.size())]


static func _weekday(context: Dictionary) -> String:
	return weekday_name(int(context.get("weekday", 0)))


## `TextCommand_FAR` banks in and runs the target as a whole text of its own.
## Bounded: a text that pointed at itself would otherwise never return.
static func _far(context: Dictionary, bank: int, address: int, depth: int) -> Dictionary:
	if depth >= 4:
		return {"ok": false, "reason": &"text_far_too_deep"}
	var resolver: Variant = context.get("far", null)
	if not resolver is Callable or not (resolver as Callable).is_valid():
		return {"ok": false, "reason": &"text_far_unresolved"}
	var bytes: Variant = (resolver as Callable).call(bank, address)
	if not bytes is PackedByteArray or (bytes as PackedByteArray).is_empty():
		return {"ok": false, "reason": &"text_far_unresolved"}
	return _run(bytes as PackedByteArray, 0, context, depth + 1)


static func _truncated(text: String, reason: StringName) -> Dictionary:
	return {"ok": false, "reason": reason, "text": text}


static func _has(data: PackedByteArray, at: int, count: int) -> bool:
	return at >= 0 and at + count <= data.size()
