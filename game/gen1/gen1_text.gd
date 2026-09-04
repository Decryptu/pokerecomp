class_name Gen1Text
extends RefCounted

## The Generation 1 character encoding, for the international ROMs. One byte per
## character terminated by $50, the alphabet in runs: $80 is "A", $A0 is "a",
## $F6 is "0". Generation 2 kept those runs, so a name reads the same through
## either codec; everything below $80 differs and is the text engine's own
## commands. Codes standing for a word or a print-time name stay bracketed, so
## nothing decodes to a silently wrong glyph.

const TERMINATOR: int = 0x50
const SPACE: int = 0x7F
## `<LINE>`, `<NEXT>`, `<PAGE>` and `<PARA>`: the breaks a text stream writes.
const LINE: int = 0x4F
const NEXT_LINE: int = 0x4E
const PAGE: int = 0x49
const PARAGRAPH: int = 0x51
## `TX_FAR` hands the rest of a string to a `dab` pointer; `TX_START` is what
## the `text` macro opens every far string with.
const TEXT_FAR: int = 0x17
const TEXT_START: int = 0x00
## `<DEXEND>`, the byte a Pokedex description ends on.
const DEX_END: int = 0x5F

## The lowest code with a tile of its own, which is also the line between what
## [method encode] can write and what only [method decode] understands.
const FIRST_PRINTABLE: int = 0x80

## What an unencodable character becomes: "?", because a question mark on screen
## is a bug someone will report and a dropped character is not.
const UNKNOWN: int = 0xE6

## The codes below [constant FIRST_PRINTABLE] that stand for a word or a name.
const CONTROL_CHARACTERS: Dictionary = {
	0x49: "<PAGE>",
	0x4A: "<PKMN>",
	0x4B: "<CONT>",
	0x4C: "<SCROLL>",
	0x4E: "<NEXT>",
	0x4F: "<LINE>",
	0x51: "<PARA>",
	0x52: "<PLAYER>",
	0x53: "<RIVAL>",
	0x54: "POKé",
	0x55: "<CONT>",
	0x56: "……",
	0x57: "<DONE>",
	0x58: "<PROMPT>",
	0x59: "<TARGET>",
	0x5A: "<USER>",
	0x5B: "PC",
	0x5C: "TM",
	0x5D: "TRAINER",
	0x5E: "ROCKET",
	0x5F: "<DEXEND>",
}

## Characters above [constant FIRST_PRINTABLE] outside the letter and digit
## runs. $BB to $BF and $E4 to $E5 are the apostrophe ligatures, one tile each.
const EXTRA_CHARACTERS: Dictionary = {
	0x9A: "(", 0x9B: ")", 0x9C: ":", 0x9D: ";", 0x9E: "[", 0x9F: "]",
	0xBA: "é", 0xBB: "'d", 0xBC: "'l", 0xBD: "'s", 0xBE: "'t", 0xBF: "'v",
	0xE0: "'", 0xE1: "<PK>", 0xE2: "<MN>", 0xE3: "-", 0xE4: "'r", 0xE5: "'m",
	0xE6: "?", 0xE7: "!", 0xE8: ".",
	0xEC: "▷", 0xED: "▶", 0xEE: "▼", 0xEF: "♂",
	0xF0: "¥", 0xF1: "×", 0xF2: ".", 0xF3: "/", 0xF4: ",", 0xF5: "♀",
}

## The longest sequence one tile stands for: a ligature is two characters.
const MAX_LIGATURE: int = 2

static var _table: Dictionary = {}
static var _codes: Dictionary = {}


## Up to a terminator or [param max_length] characters, whichever comes first.
static func decode(data: PackedByteArray, offset: int, max_length: int) -> String:
	var out: String = ""
	for i: int in max_length:
		var at: int = offset + i
		if at < 0 or at >= data.size():
			break
		var byte: int = data[at]
		if byte == TERMINATOR:
			break
		out += character(byte)
	return out


## A fixed-width field: `MonsterNames` pads with $50 and every reader takes ten
## bytes, so the padding is dropped rather than read as a mid-string end.
static func decode_fixed(data: PackedByteArray, offset: int, length: int) -> String:
	return decode(data, offset, length)


## [param count] consecutive terminated strings. Move, item and trainer names
## are stored this way, each on the byte after the last one's terminator, so one
## wrong byte slides every name after it. [param max_length] is a runaway guard.
static func decode_sequence(
	data: PackedByteArray, offset: int, count: int, max_length: int
) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var at: int = offset
	for i: int in count:
		if at < 0 or at >= data.size():
			break
		out.append(decode(data, at, max_length))
		at = terminated_end(data, at, max_length)
	return out


## Just past the terminator: a Pokedex entry's height follows its category.
static func terminated_end(data: PackedByteArray, offset: int, max_length: int) -> int:
	var end: int = offset
	while end < data.size() and data[end] != TERMINATOR and end - offset < max_length:
		end += 1
	return end + 1


## A Pokedex description: ends on `<DEXEND>` rather than a terminator, and its
## `<LINE>` and `<PAGE>` breaks become newlines.
static func decode_dex_text(data: PackedByteArray, offset: int, max_length: int) -> String:
	var out: String = ""
	for i: int in max_length:
		var at: int = offset + i
		if at < 0 or at >= data.size():
			break
		var byte: int = data[at]
		if byte == DEX_END or byte == TERMINATOR:
			break
		if byte == TEXT_START:
			continue
		if byte == LINE or byte == NEXT_LINE or byte == PAGE:
			out += "\n"
			continue
		out += character(byte)
	return out


## A string to the codes that draw it, one tile each: [method decode]'s inverse
## over the printable range. Anything with no tile becomes [constant UNKNOWN]
## rather than being dropped.
static func encode(text: String) -> PackedByteArray:
	var codes: Dictionary = _encodings()
	var out: PackedByteArray = PackedByteArray()
	var at: int = 0
	while at < text.length():
		var taken: int = 0
		# Longest first, so "'s" wins over a "'" with no "s" code after it.
		for length: int in range(mini(MAX_LIGATURE, text.length() - at), 0, -1):
			var candidate: String = text.substr(at, length)
			if codes.has(candidate):
				out.append(codes[candidate])
				taken = length
				break
		if taken == 0:
			out.append(UNKNOWN)
			taken = 1
		at += taken
	return out


static func encoded_length(text: String) -> int:
	return encode(text).size()


static func character(byte: int) -> String:
	var table: Dictionary = _characters()
	if table.has(byte):
		return table[byte]
	# Never drop an unknown byte: it means the offset table is wrong.
	return "<%02X>" % byte


static func _characters() -> Dictionary:
	if not _table.is_empty():
		return _table
	var table: Dictionary = {}
	for i: int in 26:
		table[0x80 + i] = char("A".unicode_at(0) + i)
		table[0xA0 + i] = char("a".unicode_at(0) + i)
	for i: int in 10:
		table[0xF6 + i] = char("0".unicode_at(0) + i)
	table[SPACE] = " "
	table.merge(EXTRA_CHARACTERS)
	table.merge(CONTROL_CHARACTERS)
	_table = table
	return _table


## Built once. Where two codes draw the same character the first wins, which is
## why $F2's decimal point does not displace $E8's.
static func _encodings() -> Dictionary:
	if not _codes.is_empty():
		return _codes
	var codes: Dictionary = {}
	for byte: int in _characters():
		if byte < FIRST_PRINTABLE and byte != SPACE:
			continue
		var glyph: String = _characters()[byte]
		if not codes.has(glyph):
			codes[glyph] = byte
	_codes = codes
	return _codes
