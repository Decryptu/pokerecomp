class_name PokePalette
extends RefCounted

## Game Boy Color palette entries. A colour is 15 bits packed little-endian as
## $0BBBBBGG GGGRRRRR, five bits per channel, red low, bit 15 ignored. A stored
## Pokemon palette holds only two colours, every pic using index 0 for white and 3
## for black, and each species stores two such pairs, normal and shiny, which is
## all being shiny means to the renderer.

const COLOR_BYTES: int = 2
## The two middle colours a pic is drawn with. A trainer class stores one such
## pair and nothing else: only a Pokémon can be shiny.
const PAIR_BYTES: int = COLOR_BYTES * 2
## A species' entry: two pairs, normal and shiny.
const ENTRY_BYTES: int = PAIR_BYTES * 2
const COLORS_PER_PIC: int = 4


static func decode_color(data: PackedByteArray, offset: int) -> Color:
	if offset < 0 or offset + COLOR_BYTES > data.size():
		return Color.MAGENTA
	return from_packed(data[offset] | (data[offset + 1] << 8))


## The cache stores colours as the cartridge's own 15-bit value rather than as
## anything wider, so nothing is rounded on the way in and out.
static func from_packed(packed: int) -> Color:
	return Color(
		_expand(packed & 0x1F),
		_expand((packed >> 5) & 0x1F),
		_expand((packed >> 10) & 0x1F),
	)


## The four colours a pic is drawn with, in index order.
static func pic_palette(middle: PackedColorArray) -> PackedColorArray:
	var out: PackedColorArray = PackedColorArray([Color.WHITE])
	out.append_array(middle)
	out.append(Color.BLACK)
	return out


## The four shades a Game Boy shows where nothing has applied a palette.
static func monochrome() -> PackedColorArray:
	return pic_palette(PackedColorArray([
		Color(0.66, 0.66, 0.66), Color(0.33, 0.33, 0.33),
	]))


## One palette read through a Game Boy shade register, [param shades] holding
## the shade each colour index selects. `rBGP` is %11100100 wherever a map is
## drawn, which is the identity and gives the palette back unchanged; an object
## register is not, and its index 0 is transparent whatever shade it names.
static func through_shades(colors: PackedColorArray, shades: Array[int]) -> PackedColorArray:
	var out := PackedColorArray()
	for shade: int in shades:
		out.append(colors[shade] if shade >= 0 and shade < colors.size() else Color.MAGENTA)
	return out


## Reads one species' entry as { normal, shiny }, each a two-colour array.
static func decode_entry(data: PackedByteArray, offset: int) -> Dictionary:
	return {
		"normal": PackedColorArray([
			decode_color(data, offset),
			decode_color(data, offset + COLOR_BYTES),
		]),
		"shiny": PackedColorArray([
			decode_color(data, offset + COLOR_BYTES * 2),
			decode_color(data, offset + COLOR_BYTES * 3),
		]),
	}


## 5 bits to a float. Scaling by 31 rather than 32 keeps $1F exactly white,
## which matters because the two implied colours are pure white and black.
static func _expand(component: int) -> float:
	return float(component) / 31.0
