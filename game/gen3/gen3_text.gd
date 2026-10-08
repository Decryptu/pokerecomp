class_name Gen3Text
extends RefCounted

## pret's English `charmap.txt`, the same on all five. A code with no glyph
## stays bracketed as hex rather than decoding to a wrong character.

## Tile runs that draw one word, spelled like Generation 2's `<PKMN>`: `PKMN` is
## $53 $54 and `POKEBLOCK`, in the berry descriptions, $55 to $59.
const WORD_TILES: Dictionary = {
	"<PKMN>": [0x53, 0x54],
	"<POKEBLOCK>": [0x55, 0x56, 0x57, 0x58, 0x59],
}

const EOS: int = 0xFF
const NEWLINE: int = 0xFE
const PLACEHOLDER: int = 0xFD
const EXT_CTRL_CODE: int = 0xFC
const UPPER_A: int = 0xBB
const LOWER_A: int = 0xD5
const DIGIT_0: int = 0xA1
const LETTERS: int = 26
const DIGITS: int = 10

## GetExtCtrlCodeLength: the code byte and its arguments after `FC`. Ruby and
## Sapphire's table ends at EXT_CTRL_CODE_ENG; a code past either end is refused.
const EXT_CTRL_CODES: Array = [
	["NAME_END", 1], ["COLOR", 2], ["HIGHLIGHT", 2], ["SHADOW", 2],
	["COLOR_HIGHLIGHT_SHADOW", 4], ["PALETTE", 2], ["FONT", 2], ["RESET_FONT", 1],
	["PAUSE", 2], ["PAUSE_UNTIL_PRESS", 1], ["WAIT_SE", 1], ["PLAY_BGM", 3],
	["ESCAPE", 2], ["SHIFT_RIGHT", 2], ["SHIFT_DOWN", 2], ["FILL_WINDOW", 1],
	["PLAY_SE", 3], ["CLEAR", 2], ["SKIP", 2], ["CLEAR_TO", 2],
	["MIN_LETTER_SPACING", 2], ["JPN", 1], ["ENG", 1], ["PAUSE_MUSIC", 1],
	["RESUME_MUSIC", 1],
]
const RS_EXT_CTRL_CODE_COUNT: int = 23
## PLAY_BGM and PLAY_SE read one halfword rather than two bytes.
const WORD_ARGUMENT_CODES: Array[int] = [0x0B, 0x10]
## ExpandPlaceholder's IDs; Sapphire and Emerald swap Ruby's version names.
const PLACEHOLDERS: Array[String] = [
	"UNKNOWN_STR", "PLAYER", "STR_VAR_1", "STR_VAR_2", "STR_VAR_3", "KUN", "RIVAL", "VERSION",
]
const HOENN_PLACEHOLDERS: Array[String] = ["MAGMA", "AQUA", "MAXIE", "ARCHIE", "GROUDON", "KYOGRE"]
const SWAPPED_PLACEHOLDERS: Array[String] = ["AQUA", "MAGMA", "ARCHIE", "MAXIE", "KYOGRE", "GROUDON"]
## FireRed, LeafGreen and Emerald's RenderText reads one argument after each of
## these; Ruby and Sapphire's PrintNextChar draws them as glyphs.
const ARGUMENT_CHARACTERS: Dictionary = {0xF7: "DYNAMIC", 0xF8: "KEYPAD_ICON", 0xF9: "EXTRA_SYMBOL"}

const CHARACTERS: Dictionary = {
	0x00: " ", 0x01: "À", 0x02: "Á", 0x03: "Â", 0x04: "Ç", 0x05: "È", 0x06: "É",
	0x07: "Ê", 0x08: "Ë", 0x09: "Ì", 0x0B: "Î", 0x0C: "Ï", 0x0D: "Ò", 0x0E: "Ó",
	0x0F: "Ô", 0x10: "Œ", 0x11: "Ù", 0x12: "Ú", 0x13: "Û", 0x14: "Ñ", 0x15: "ß",
	0x16: "à", 0x17: "á", 0x19: "ç", 0x1A: "è", 0x1B: "é", 0x1C: "ê", 0x1D: "ë",
	0x1E: "ì", 0x20: "î", 0x21: "ï", 0x22: "ò", 0x23: "ó", 0x24: "ô", 0x25: "œ",
	0x26: "ù", 0x27: "ú", 0x28: "û", 0x29: "ñ", 0x2A: "º", 0x2B: "ª", 0x2C: "<SUPER_ER>",
	0x2D: "&", 0x2E: "+", 0x34: "<LV>", 0x35: "=", 0x36: ";", 0x51: "¿", 0x52: "¡", 0x53: "<PK>",
	0x5A: "Í", 0x5B: "%", 0x5C: "(", 0x5D: ")", 0x68: "â", 0x6F: "í", 0x77: "<UNK_SPACER>",
	0x79: "↑", 0x7A: "↓", 0x7B: "←", 0x7C: "→", 0x84: "<SUPER_E>", 0x85: "<", 0x86: ">",
	0xA0: "<SUPER_RE>", 0xAB: "!", 0xAC: "?", 0xAD: ".", 0xAE: "-", 0xAF: "·", 0xB0: "…", 0xB1: "“",
	0xB2: "”", 0xB3: "‘", 0xB4: "'", 0xB5: "♂", 0xB6: "♀", 0xB7: "¥", 0xB8: ",",
	0xB9: "×", 0xBA: "/", 0xEF: "▶", 0xF0: ":", 0xF1: "Ä", 0xF2: "Ö", 0xF3: "Ü",
	0xF4: "ä", 0xF5: "ö", 0xF6: "ü", 0xFA: "<PROMPT_SCROLL>", 0xFB: "<PROMPT_CLEAR>",
	NEWLINE: "\n",
}


static func character(code: int) -> String:
	if code >= UPPER_A and code < UPPER_A + LETTERS:
		return String.chr(0x41 + code - UPPER_A)
	if code >= LOWER_A and code < LOWER_A + LETTERS:
		return String.chr(0x61 + code - LOWER_A)
	if code >= DIGIT_0 and code < DIGIT_0 + DIGITS:
		return String.chr(0x30 + code - DIGIT_0)
	return String(CHARACTERS.get(code, "<$%02X>" % code))


static func _ruby_engine(id: StringName) -> bool:
	return id in [RomRegistry.RUBY, RomRegistry.SAPPHIRE]


## Bytes the renderer reads for the unit at [param at]; zero for a code it cannot read.
static func unit_width(id: StringName, data: PackedByteArray, at: int) -> int:
	var code: int = data[at]
	if code == PLACEHOLDER or (code in ARGUMENT_CHARACTERS and not _ruby_engine(id)):
		return 2
	if code != EXT_CTRL_CODE:
		return 1
	if at + 1 >= data.size():
		return 0
	var ext: int = data[at + 1]
	var count: int = RS_EXT_CTRL_CODE_COUNT if _ruby_engine(id) else EXT_CTRL_CODES.size()
	return 1 + int(EXT_CTRL_CODES[ext][1]) if ext < count else 0


## Bytes from [param offset] through EOS, or -1 when no EOS ends a string of
## readable units within [param limit]. An argument byte of $FF is not an end.
static func span(id: StringName, data: PackedByteArray, offset: int, limit: int) -> int:
	if offset < 0:
		return -1
	var end: int = mini(offset + limit, data.size())
	var at: int = offset
	while at < end:
		if data[at] == EOS:
			return at + 1 - offset
		var width: int = unit_width(id, data, at)
		if width == 0 or at + width > end:
			return -1
		at += width
	return -1


static func ends_within(id: StringName, data: PackedByteArray, offset: int, limit: int) -> bool:
	return span(id, data, offset, limit) > 0


static func decode_fixed(id: StringName, data: PackedByteArray, offset: int, length: int) -> String:
	var out: String = ""
	var end: int = mini(offset + length, data.size())
	var at: int = offset
	while at < end and data[at] != EOS:
		var word: String = _word_at(data, at, end)
		var width: int = unit_width(id, data, at)
		if not word.is_empty():
			out += word
			at += (WORD_TILES[word] as Array).size()
		elif width > 1 and at + width <= end:
			out += _control(id, data, at, width)
			at += width
		else:
			out += character(data[at]) if width == 1 else "<$%02X>" % data[at]
			at += 1
	return out


static func _control(id: StringName, data: PackedByteArray, at: int, width: int) -> String:
	var code: int = data[at]
	if code in ARGUMENT_CHARACTERS:
		return "<%s %d>" % [ARGUMENT_CHARACTERS[code], data[at + 1]]
	if code == PLACEHOLDER:
		return _placeholder(id, data[at + 1])
	var ext: int = data[at + 1]
	var token: String = String(EXT_CTRL_CODES[ext][0])
	if ext in WORD_ARGUMENT_CODES:
		return "<%s %d>" % [token, data.decode_u16(at + 2)]
	for argument: int in range(at + 2, at + width):
		token += " %d" % data[argument]
	return "<%s>" % token


static func _placeholder(id: StringName, placeholder: int) -> String:
	if placeholder < PLACEHOLDERS.size():
		return "<%s>" % PLACEHOLDERS[placeholder]
	var names: Array[String] = SWAPPED_PLACEHOLDERS \
		if id in [RomRegistry.SAPPHIRE, RomRegistry.EMERALD] else HOENN_PLACEHOLDERS
	var index: int = placeholder - PLACEHOLDERS.size()
	return "<%s>" % names[index] if index < names.size() else "<$FD %02X>" % placeholder


static func _word_at(data: PackedByteArray, at: int, end: int) -> String:
	for word: String in WORD_TILES:
		var codes: Array = WORD_TILES[word]
		if at + codes.size() > end:
			continue
		if codes == Array(data.slice(at, at + codes.size())):
			return word
	return ""
