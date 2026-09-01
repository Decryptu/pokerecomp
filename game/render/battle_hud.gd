class_name Gen2BattleHud
extends RefCounted

## The two status panels a battle draws, on the tile grid the hardware uses.
## Neither is a box but an edge and two corners with the contents printed inside,
## which is why both come from the HUD sheets. Only the player's carries HP as
## numbers and an exp bar. Node-free: it writes indices into a buffer.

const TILE: int = Gen2Font.TILE

## The widest maximum `ComputeHPBarPixels` divides by unshifted.
const BAR_DIVISOR_MAX: int = 0xFF

## The HP bar is six tiles of eight pixels; the exp bar is eight.
const HP_BAR_TILES: int = 6
const EXP_BAR_TILES: int = 8

## The enemy's panel: name, then level, then the bar and the edge under it.
const ENEMY_NAME: Vector2i = Vector2i(1, 0)
## `DrawEnemyHUDBorder`'s `hlcoord 1, 1`, under the name's first letter.
const ENEMY_CAUGHT: Vector2i = Vector2i(1, 1)
const ENEMY_LEVEL: Vector2i = Vector2i(6, 1)
const ENEMY_BAR: Vector2i = Vector2i(2, 2)
const ENEMY_EDGE: Vector2i = Vector2i(1, 2)

## The player's, which is the same idea mirrored and two rows taller.
const PLAYER_NAME: Vector2i = Vector2i(10, 7)
const PLAYER_LEVEL: Vector2i = Vector2i(14, 8)
const PLAYER_BAR: Vector2i = Vector2i(10, 9)
const PLAYER_HP: Vector2i = Vector2i(11, 10)
const PLAYER_EXP: Vector2i = Vector2i(10, 11)
const PLAYER_EDGE: Vector2i = Vector2i(18, 10)

## How many tiles of edge run along the bottom of a panel.
const EDGE_TILES: int = 8

## Both HP numbers are printed three columns wide, right-aligned, with a slash
## between them.
const HP_DIGITS: int = 3

var font: Gen2Font = null
var tiles: Gen2BattleTiles = null


## Reads what it draws with out of a cache, or null if any of it is missing.
static func from_data(data: GameData) -> Gen2BattleHud:
	var glyphs: Gen2Font = Gen2Font.from_data(data)
	var page: Gen2BattleTiles = Gen2BattleTiles.from_data(data)
	if glyphs == null or page == null:
		return null

	var out := Gen2BattleHud.new()
	out.font = glyphs
	out.tiles = page
	return out


## How much of a bar is lit, in pixels.
##
## A Pokémon that is alive never shows an empty bar: the games round down and put
## one pixel back, so fainting is the only thing that empties it.
## `ComputeHPBarPixels`' divisor is one byte, so a maximum over 255 has product and
## divisor shifted right two bits first, both shifts truncating.
static func bar_pixels(current: int, maximum: int, length: int) -> int:
	if maximum <= 0 or current <= 0:
		return 0
	if current >= maximum:
		return length
	var product: int = current * length
	var divisor: int = maximum
	if maximum > BAR_DIVISOR_MAX:
		product >>= 2
		divisor >>= 2
	@warning_ignore("integer_division")
	var lit: int = product / divisor
	return maxi(lit, 1)


## The enemy's panel except for the bar's fill: the name, the level, the "HP:"
## label, the cap that closes the bar and the edge under it. [param caught] is
## `DrawEnemyHUDBorder`'s ball, drawn on a wild battle whose species the Pokedex
## already has caught. The fill is a layer of its own as the one thing on the
## panel that is not black on white, which keeps the palette choice where the
## colour is.
func draw_enemy(
	into: PackedByteArray, width: int, name: String, level: int, caught: bool = false
) -> void:
	font.draw_text(name, into, width, ENEMY_NAME.x * TILE, ENEMY_NAME.y * TILE)
	if caught:
		tiles.draw(
			Gen2BattleTiles.CAUGHT_BALL, into, width,
			ENEMY_CAUGHT.x * TILE, ENEMY_CAUGHT.y * TILE
		)
	draw_level(into, width, ENEMY_LEVEL, level)
	draw_bar_frame(into, width, ENEMY_BAR, Gen2BattleTiles.HP_BAR_END)

	# The edge, which starts beside the bar and turns under it.
	var left: int = ENEMY_EDGE.x * TILE
	var top: int = ENEMY_EDGE.y * TILE
	tiles.draw(Gen2BattleTiles.ENEMY_SIDE, into, width, left, top)
	tiles.draw(Gen2BattleTiles.ENEMY_CORNER, into, width, left, top + TILE)
	tiles.draw_run(Gen2BattleTiles.HUD_BOTTOM, EDGE_TILES, into, width, left + TILE, top + TILE)
	tiles.draw(
		Gen2BattleTiles.ENEMY_BOTTOM_RIGHT, into, width,
		left + (EDGE_TILES + 1) * TILE, top + TILE
	)


## The player's panel, likewise without its two bars: it carries HP as numbers
## as well, and an exp bar sunk into its bottom edge.
func draw_player(
	into: PackedByteArray, width: int, name: String, level: int, hp: int, max_hp: int
) -> void:
	font.draw_text(name, into, width, PLAYER_NAME.x * TILE, PLAYER_NAME.y * TILE)
	draw_level(into, width, PLAYER_LEVEL, level)
	draw_bar_frame(into, width, PLAYER_BAR, Gen2BattleTiles.HP_BAR_END + 1)

	# Right-aligned in a fixed field, as the games print any number in a panel:
	# the digits line up and the leading spaces draw nothing.
	font.draw_text(
		"%s/%s" % [str(hp).lpad(HP_DIGITS), str(max_hp).lpad(HP_DIGITS)], into, width,
		PLAYER_HP.x * TILE, PLAYER_HP.y * TILE
	)

	# The edge, drawn before the exp bar because the bar sits in it: the games
	# lay the bottom edge down and then print the bar over the middle of it.
	var right: int = PLAYER_EDGE.x * TILE
	var top: int = PLAYER_EDGE.y * TILE
	tiles.draw(Gen2BattleTiles.PLAYER_SIDE, into, width, right, top)
	tiles.draw(Gen2BattleTiles.PLAYER_BOTTOM_RIGHT, into, width, right, top + TILE)
	tiles.draw_run(
		Gen2BattleTiles.HUD_BOTTOM, EDGE_TILES, into, width,
		right - EDGE_TILES * TILE, top + TILE
	)
	tiles.draw(
		Gen2BattleTiles.PLAYER_BOTTOM_LEFT, into, width,
		right - (EDGE_TILES + 1) * TILE, top + TILE
	)


## The fill of one HP bar, which is all that is drawn in the bar's own colour.
func draw_hp_bar(
	into: PackedByteArray, width: int, at: Vector2i, hp: int, max_hp: int
) -> void:
	var lit: int = bar_pixels(hp, max_hp, HP_BAR_TILES * TILE)
	var left: int = (at.x + 2) * TILE
	for tile: int in HP_BAR_TILES:
		var within: int = clampi(lit - tile * TILE, 0, TILE)
		if within <= 0:
			continue
		tiles.draw(
			Gen2BattleTiles.HP_BAR_EMPTY + within, into, width, left + tile * TILE, at.y * TILE
		)


## The exp bar, whose ends are the HP bar's own tiles. [param pixels] is
## `PlaceExpBar`'s `b`: a pixel count and never a ratio, `CalcExpBar` having
## divided already. It starts at `hlcoord 17, 11` and writes with `ld [hld], a`,
## so the run walks left from the right-hand end, and writes $62 for every tile
## the fill did not reach. [param at] is the bar's left-hand tile, the HUD's own
## everywhere but the stats screen's (11,16).
func draw_exp_bar(
	into: PackedByteArray, width: int, pixels: int, at: Vector2i = PLAYER_EXP
) -> void:
	var remaining: int = clampi(pixels, 0, EXP_BAR_TILES * TILE)
	var right: int = at.x + EXP_BAR_TILES - 1
	var top: int = at.y * TILE

	for tile: int in EXP_BAR_TILES:
		var number: int = Gen2BattleTiles.HP_BAR_EMPTY
		if remaining >= TILE:
			number = Gen2BattleTiles.HP_BAR_FULL
			remaining -= TILE
		elif remaining > 0:
			number = Gen2BattleTiles.EXP_BAR_FIRST_PARTIAL + remaining - 1
			remaining = 0
		tiles.draw(number, into, width, (right - tile) * TILE, top)


## The level symbol and the number after it, which is how a level is written
## everywhere in these games until the number needs three digits.
func draw_level(into: PackedByteArray, width: int, at: Vector2i, level: int) -> void:
	var column: int = at.x
	if Gen2Font.level_glyph_shown(level):
		tiles.draw(Gen2BattleTiles.LEVEL, into, width, at.x * TILE, at.y * TILE)
		column += 1
	font.draw_text("%d" % level, into, width, column * TILE, at.y * TILE)


## "HP:", the empty bar and the cap that closes it: everything about a bar that
## does not depend on how full it is.
func draw_bar_frame(into: PackedByteArray, width: int, at: Vector2i, cap: int) -> void:
	var left: int = at.x * TILE
	var top: int = at.y * TILE
	tiles.draw(Gen2BattleTiles.HP_LABEL, into, width, left, top)
	tiles.draw(Gen2BattleTiles.HP_LABEL + 1, into, width, left + TILE, top)
	tiles.draw_run(
		Gen2BattleTiles.HP_BAR_EMPTY, HP_BAR_TILES, into, width, left + 2 * TILE, top
	)
	tiles.draw(cap, into, width, left + (2 + HP_BAR_TILES) * TILE, top)
