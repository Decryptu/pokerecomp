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
const UPPER_A: int = 0xBB
const LOWER_A: int = 0xD5
const DIGIT_0: int = 0xA1
const LETTERS: int = 26
const DIGITS: int = 10

const CHARACTERS: Dictionary = {
	0x00: " ", 0x01: "À", 0x02: "Á", 0x03: "Â", 0x04: "Ç", 0x05: "È", 0x06: "É",
	0x07: "Ê", 0x08: "Ë", 0x09: "Ì", 0x0B: "Î", 0x0C: "Ï", 0x0D: "Ò", 0x0E: "Ó",
	0x0F: "Ô", 0x10: "Œ", 0x11: "Ù", 0x12: "Ú", 0x13: "Û", 0x14: "Ñ", 0x15: "ß",
	0x16: "à", 0x17: "á", 0x19: "ç", 0x1A: "è", 0x1B: "é", 0x1C: "ê", 0x1D: "ë",
	0x1E: "ì", 0x20: "î", 0x21: "ï", 0x22: "ò", 0x23: "ó", 0x24: "ô", 0x25: "œ",
	0x26: "ù", 0x27: "ú", 0x28: "û", 0x29: "ñ", 0x2A: "º", 0x2B: "ª", 0x2D: "&",
	0x2E: "+", 0x35: "=", 0x36: ";", 0x51: "¿", 0x52: "¡", 0x53: "<PK>", 0x5A: "Í", 0x5B: "%",
	0x5C: "(", 0x5D: ")", 0x68: "â", 0x6F: "í", 0x85: "<", 0x86: ">",
	0xAB: "!", 0xAC: "?", 0xAD: ".", 0xAE: "-", 0xAF: "·", 0xB0: "…", 0xB1: "“",
	0xB2: "”", 0xB3: "‘", 0xB4: "'", 0xB5: "♂", 0xB6: "♀", 0xB7: "¥", 0xB8: ",",
	0xB9: "×", 0xBA: "/", 0xEF: "▶", 0xF0: ":", 0xF1: "Ä", 0xF2: "Ö", 0xF3: "Ü",
	0xF4: "ä", 0xF5: "ö", 0xF6: "ü", NEWLINE: "\n",
}


static func character(code: int) -> String:
	if code >= UPPER_A and code < UPPER_A + LETTERS:
		return String.chr(0x41 + code - UPPER_A)
	if code >= LOWER_A and code < LOWER_A + LETTERS:
		return String.chr(0x61 + code - LOWER_A)
	if code >= DIGIT_0 and code < DIGIT_0 + DIGITS:
		return String.chr(0x30 + code - DIGIT_0)
	return String(CHARACTERS.get(code, "<$%02X>" % code))


static func decode_fixed(data: PackedByteArray, offset: int, length: int) -> String:
	var out: String = ""
	var end: int = mini(offset + length, data.size())
	var at: int = offset
	while at < end and data[at] != EOS:
		var word: String = _word_at(data, at, end)
		if word.is_empty():
			out += character(data[at])
			at += 1
		else:
			out += word
			at += (WORD_TILES[word] as Array).size()
	return out


static func _word_at(data: PackedByteArray, at: int, end: int) -> String:
	for word: String in WORD_TILES:
		var codes: Array = WORD_TILES[word]
		if at + codes.size() > end:
			continue
		if codes == Array(data.slice(at, at + codes.size())):
			return word
	return ""


## Whether a string at [param offset] ends within [param limit] bytes.
static func ends_within(data: PackedByteArray, offset: int, limit: int) -> bool:
	if offset < 0:
		return false
	for at: int in range(offset, mini(offset + limit, data.size())):
		if data[at] == EOS:
			return true
	return false
