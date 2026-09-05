extends RefCounted

var _r: RefCounted = null

## Verifies the sprites the overworld draws over an object rather than as one,
## against freshly imported real caches: `data/sprites/emotes.asm`'s twelve sheets
## and ShakeHeadbuttTree's own. Every expectation comes from the pinned sources: the
## emote table's tile numbers are `Facings`' own, and all three cartridges ship the
## art itself byte identical, which is what the cross-cartridge comparison checks. A
## sheet read at the wrong offset decodes neighbouring code into legal-looking
## pixels, so shape alone would not catch it.

## The names Gen2WorldImporter writes, with the tile count and VRAM tile each
## record must name.
const EXPECTED: Array = [
	["shock", 4, 0xF8], ["question", 4, 0xF8], ["happy", 4, 0xF8], ["sad", 4, 0xF8],
	["heart", 4, 0xF8], ["bolt", 4, 0xF8], ["sleep", 4, 0xF8], ["fish", 4, 0xF8],
	["shadow", 1, 0xFC], ["rod", 2, 0xFC], ["boulder_dust", 2, 0xFE],
	["grass_rustle", 1, 0xFE], ["headbutt_tree", 8, 0x84], ["cut_tree", 4, 0x84],
	["cut_grass", 4, 0x80], ["heal_machine", 2, 0x7C], ["chris_fish", 8, 0x02],
]

const CRYSTAL_ONLY: Array = [["kris_fish", 8, 0x02]]

## `gfx/overworld/heal_machine.pal`, the one sheet that carries a palette of its
## own instead of wearing an overworld one: `RGB 31, 31, 31`, `RGB 31, 19, 10`,
## `RGB 31, 07, 01` and black, packed the way the cartridge stores them and
## identical on all three.
const HEAL_MACHINE_COLORS: Array[int] = [0x7FFF, 0x2A7F, 0x04FF, 0x0000]

var _first: Dictionary = {}


## The one sheet Generation 1 draws over the map. It wears `rOBP1` rather than a
## palette of its own, and its monitor is three rows of $7E where Crystal's is two.
const GEN1_EXPECTED: Array = [["heal_machine", 2, 0x7C]]

## `PokeCenterOAMData` read back to the pixel each object reaches the screen at:
## the monitor, then six balls in two mirrored columns five rows apart.
const GEN1_OAM: Array = [
	[Vector2i(44, 20), 0, false],
	[Vector2i(40, 27), 1, false], [Vector2i(48, 27), 1, true],
	[Vector2i(40, 32), 1, false], [Vector2i(48, 32), 1, true],
	[Vector2i(40, 37), 1, false], [Vector2i(48, 37), 1, true],
]


func run(r: RefCounted) -> void:
	_r = r
	_first = {}
	_r.each_game(_check_game)
	_first = {}
	_r.each_game_of(RomRegistry.GEN1, _check_gen1_game)


## The same sheet checks, plus the OAM table and the two `rOBP1` bytes.
func _check_gen1_game() -> void:
	_check_sheets(GEN1_EXPECTED)
	_r.check(
		Gen2WorldEffects.gen1_heal_machine_oam() == GEN1_OAM,
		"the heal machine OAM is %s." % [Gen2WorldEffects.gen1_heal_machine_oam()]
	)
	## `ld a, $e0 / ldh [rOBP1]` and `ld d, $28 / call FlashSprite8Times`: the
	## xor swaps the two inner shades and leaves the ends alone.
	_r.check(
		Gen1Layout.HEAL_MACHINE_SHADES == [[0, 0, 2, 3], [0, 2, 0, 3]],
		"the heal machine shades are %s." % [Gen1Layout.HEAL_MACHINE_SHADES]
	)


func _check_game() -> void:
	var expected: Array = EXPECTED.duplicate()
	if Gen2WorldState.is_crystal_profile(_r.data):
		expected.append_array(CRYSTAL_ONLY)
	_check_sheets(expected)


func _check_sheets(expected: Array) -> void:
	var lit: int = 0
	for row: Array in expected:
		var name: String = String(row[0])
		var sheet: Dictionary = _r.data.overworld_effect(name)
		if not _r.check(not sheet.is_empty(), "the %s sheet is not in the cache." % name):
			continue
		_r.check(
			int(sheet["tiles"]) == int(row[1]),
			"%s is %d tiles, not the source's %d." % [name, int(sheet["tiles"]), int(row[1])]
		)
		_r.check(
			int(sheet["vtile"]) == int(row[2]),
			"%s loads to tile $%02X, not $%02X." % [name, int(sheet["vtile"]), int(row[2])]
		)
		var indices: PackedByteArray = sheet["indices"]
		if not _r.check(
			indices.size() == int(row[1]) * PokeTiles.TILE_PIXELS,
			"%s decoded %d pixels, not %d." % [
				name, indices.size(), int(row[1]) * PokeTiles.TILE_PIXELS,
			]
		):
			continue
		var drawn: int = 0
		for index: int in indices:
			_r.check(index <= 3, "%s holds colour index %d." % [name, index])
			if index != 0:
				drawn += 1
		# Index 0 is the transparent one, so a sheet of nothing but zeroes is a
		# sheet that would draw nothing at all.
		_r.check(drawn > 0, "%s is blank." % name)
		lit += drawn
		if _first.has(name):
			_r.check(
				_first[name] == indices,
				"%s differs from the same sheet on the other cartridges." % name
			)
		else:
			_first[name] = indices
		var colors: PackedColorArray = sheet.get("colors", PackedColorArray())
		if name == "heal_machine" and _r.data.generation == RomRegistry.GEN2:
			if _r.check(
				colors.size() == HEAL_MACHINE_COLORS.size(),
				"the heal machine carries %d colours, not four." % colors.size()
			):
				for slot: int in colors.size():
					var want: Color = PokePalette.from_packed(HEAL_MACHINE_COLORS[slot])
					_r.check(
						colors[slot].is_equal_approx(want),
						"heal machine colour %d is %s, not the source's %s." % [
							slot, colors[slot], want,
						]
					)
		else:
			_r.check(colors.is_empty(), "%s carries a palette it has no source for." % name)
	_r.note("overworld effects: %d sheets, %d drawn pixels." % [expected.size(), lit])
