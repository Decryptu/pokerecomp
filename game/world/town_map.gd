class_name Gen2TownMap
extends RefCounted

## `_TownMap` and the Pokegear's MAP card (engine/pokegear/pokegear.asm) as state
## rather than pixels. The two share `PokegearMap_UpdateLandmarkName` and the
## cursor walk and differ only in the frame, which is [Gen2TownMapPage]'s, and in
## what the Fast Ship counts as. Landmark numbering is [Gen2WorldRadio]'s.

## `PokegearMap_JohtoMap`'s own `ld e, JOHTO_LANDMARK`.
const JOHTO_LANDMARK: int = 1

## `TownMap_GetKantoLandmarkLimits`' pre-Hall of Fame window. Crystal's numbers;
## see [method _shift].
const LANDMARK_VICTORY_ROAD: int = 0x58
const LANDMARK_ROUTE_28: int = 0x5E

const REGION_JOHTO: int = 0
const REGION_KANTO: int = 1
## What the cache calls each region map, which is the pinned file name.
const REGION_NAMES: Array[String] = ["johto", "kanto"]

## `_TownMap` is the poster and the `OverworldTownMap` special; the card is the
## Pokegear's second page; the dex area is `Pokedex_GetArea`, which draws both.
const SCREEN_TOWN_MAP: StringName = &"town_map"
const SCREEN_POKEGEAR_CARD: StringName = &"pokegear_card"
const SCREEN_DEX_AREA: StringName = &"dex_area"
## `_FlyMap`: the same maps with the cursor walking `FLY_*` indexes instead of
## landmarks, skipping every flypoint the player has not visited.
const SCREEN_FLY: StringName = &"fly"

## Kanto's default flypoint, and the one `FlyMap` tests before drawing Kanto.
const FLY_INDIGO: int = Gen2Layout.FLYPOINT_COUNT - 1

var crystal: bool = true
var screen: StringName = SCREEN_TOWN_MAP
## `wTownMapPlayerIconLandmark`, which is where the player icon is drawn and
## which region the screen opens on.
var player_landmark: int = JOHTO_LANDMARK
## `wTownMapCursorLandmark`, which `Pokedex_GetArea` reuses to hold the region it
## is showing rather than a landmark.
var cursor: int = JOHTO_LANDMARK
## `STATUSFLAGS_HALL_OF_FAME_F`, which the dex area reads on every right press
## rather than once.
var hall_of_fame: bool = false
## For the fly map's walk alone; empty on every other screen.
var visited_flypoints: Array[int] = []
var _first: int = JOHTO_LANDMARK
var _last: int = JOHTO_LANDMARK
## Generation 1 walks tables rather than a landmark window: `TownMapOrder` on
## the map itself and `wFlyLocationsList` on the fly map, whose unvisited towns
## stand at [constant Gen1Layout.TOWN_MAP_NOT_VISITED].
var gen1: bool = false
var rows: PackedInt32Array = PackedInt32Array()
## `wWhichTownMapLocation`, which `.enterLoop` leaves at zero while the cursor
## stands on `wCurMap`, so the first UP press walks to the second row.
var row_index: int = 0
## Whether `.townMapLoop`'s own `ClearScreenArea` has run, which the screen each
## of the three opened on skipped.
var row_cleared: bool = false
## Which of the two fly arrows the last press blanked, and -1 before any.
var arrow_hidden: int = -1


## `FlyMap`, opened on the region the player is in with the cursor on its default
## flypoint. [param visited] is what `CheckIfVisitedFlypoint` answers for, the
## `wVisitedSpawns` bit of each spawn; `.NoKanto` falls back to Johto's map
## unless Indigo Plateau is among them. The default is reachable whether or not
## it was visited, which is the source's quirk and why New Bark always flies.
static func fly(
	landmark: int, in_kanto: bool, visited: Array[int], is_crystal: bool
) -> Gen2TownMap:
	var out := Gen2TownMap.new()
	out.crystal = is_crystal
	out.screen = SCREEN_FLY
	out.visited_flypoints = visited.duplicate()
	# `.MapHud` hands `TownMapPlayerIcon` the landmark it popped, so the icon
	# still says where the player stands while the cursor walks flypoints.
	out.player_landmark = landmark
	if in_kanto and visited.has(FLY_INDIGO):
		out._first = Gen2Layout.KANTO_FLYPOINT
		out._last = Gen2Layout.FLYPOINT_COUNT - 1
		out.cursor = FLY_INDIGO
	else:
		out._first = 0
		out._last = Gen2Layout.KANTO_FLYPOINT - 1
		out.cursor = 0
	return out


## `DisplayTownMap`. [param map] is `wCurMap`, which `.enterLoop` draws the
## cursor on before the loop proper, and [param order] is `TownMapOrder`.
static func create_gen1(
	map: int, order: PackedInt32Array, on_screen: StringName = SCREEN_TOWN_MAP
) -> Gen2TownMap:
	var out := Gen2TownMap.new()
	out.gen1 = true
	out.crystal = false
	out.screen = on_screen
	out.rows = order
	out.player_landmark = map
	out.cursor = map
	return out


## `LoadTownMap_Fly` over `BuildFlyLocationsList`'s answer: one entry a town, the
## map id where it was visited and `NOT_VISITED` where it was not. The list opens
## on its first row whether or not that town was visited, which is the source's
## own `ld hl, wFlyLocationsList`.
static func fly_gen1(map: int, towns: PackedInt32Array) -> Gen2TownMap:
	var out: Gen2TownMap = create_gen1(map, towns, SCREEN_FLY)
	out.cursor = towns[0] if towns.size() > 0 else map
	return out


## `TownMap_GetCurrentLandmark` has already run, so [param landmark] is resolved
## and never `LANDMARK_SPECIAL`. [param after_hall_of_fame] opens the whole Kanto map.
static func create(
	landmark: int, is_crystal: bool, after_hall_of_fame: bool = false,
	on_screen: StringName = SCREEN_TOWN_MAP
) -> Gen2TownMap:
	var out := Gen2TownMap.new()
	out.crystal = is_crystal
	out.screen = on_screen
	out.hall_of_fame = after_hall_of_fame
	out.player_landmark = landmark
	if on_screen == SCREEN_DEX_AREA:
		# `.Area` sets hWY to 144, so the window is off and BG map 0, Johto's, is
		# what `Pokedex_GetArea` opens on whatever landmark the player is at.
		out.cursor = REGION_JOHTO
		return out
	if out.region() == REGION_KANTO:
		# `TownMap_GetKantoLandmarkLimits`' two branches end on the same
		# `KANTO_LANDMARK_LAST`; only the first landmark moves.
		out._first = Gen2WorldRadio.kanto_landmark(is_crystal) if after_hall_of_fame \
			else out._shift(LANDMARK_VICTORY_ROAD)
		out._last = out._shift(LANDMARK_ROUTE_28)
	else:
		out._first = JOHTO_LANDMARK
		out._last = Gen2WorldRadio.kanto_landmark(is_crystal) - 1
	# `_TownMap` never clamps the cursor into the window, so a Kanto map opened
	# before the Hall of Fame starts below Victory Road and one press walks in.
	out.cursor = landmark
	return out


## Gold and Silver ship no `BATTLE TOWER`, so every landmark past it is one lower.
func _shift(landmark: int) -> int:
	if crystal:
		return landmark
	return landmark - 1


## `_TownMap` picks by number alone, so the Fast Ship shows Kanto there;
## `InitPokegearTilemap.Map` tests it first and shows Johto.
func region() -> int:
	if gen1:
		return REGION_KANTO
	if screen == SCREEN_DEX_AREA:
		return cursor
	# `.NoKanto` is what puts a player standing in Kanto on Johto's map.
	if screen == SCREEN_FLY:
		return REGION_KANTO if _first == Gen2Layout.KANTO_FLYPOINT else REGION_JOHTO
	if screen == SCREEN_POKEGEAR_CARD \
		and player_landmark == Gen2WorldRadio.fast_ship_landmark(crystal):
		return REGION_JOHTO
	return REGION_KANTO if player_landmark >= Gen2WorldRadio.kanto_landmark(crystal) \
		else REGION_JOHTO


static func region_name(region_id: int) -> String:
	return REGION_NAMES[clampi(region_id, REGION_JOHTO, REGION_KANTO)]


## `.CheckPlayerLocation`: whether the dex area draws the player icon at all.
func player_in_region() -> bool:
	if gen1:
		return true
	var player: int = REGION_KANTO if Gen2WorldRadio.is_kanto_landmark(
		player_landmark, crystal
	) else REGION_JOHTO
	return player == region()


func first_landmark() -> int:
	return _first


func last_landmark() -> int:
	return _last


## `.pressed_up` and `.pressed_down` wrap round the window's ends rather than
## stopping at them. The dex area walks regions instead: `.left` shows Johto and
## `.right` Kanto, the second only past the Hall of Fame, and each returns
## without redrawing when that region is already up.
func press(button: int) -> bool:
	if gen1:
		return _press_gen1(button)
	if screen == SCREEN_DEX_AREA:
		match button:
			PokeButton.LEFT:
				if cursor == REGION_JOHTO:
					return false
				cursor = REGION_JOHTO
				return true
			PokeButton.RIGHT:
				if not hall_of_fame or cursor == REGION_KANTO:
					return false
				cursor = REGION_KANTO
				return true
		return false
	match button:
		PokeButton.UP:
			cursor = _first if cursor >= _last else cursor + 1
			_skip_unvisited(1)
			return true
		PokeButton.DOWN:
			cursor = _last if cursor == _first else cursor - 1
			_skip_unvisited(-1)
			return true
	return false


## `.pressedUp` and `.pressedDown` on both Generation 1 screens. The map's own
## walk wraps through `TownMapOrder`; the fly map's skips an unvisited town and
## wraps down through them too, where `.wrapToStartOfList` does not.
func _press_gen1(button: int) -> bool:
	var step: int = 1 if button == PokeButton.UP else -1
	if button != PokeButton.UP and button != PokeButton.DOWN:
		return false
	row_cleared = true
	arrow_hidden = 0 if step > 0 else 1
	if rows.is_empty():
		return true
	row_index = wrapi(row_index + step, 0, rows.size())
	if screen == SCREEN_FLY:
		_skip_unvisited_gen1(step)
	cursor = rows[row_index]
	return true


## `cp NOT_VISITED / jr z`, which walks on in the direction the press went.
## `.wrapToStartOfList` skips the test, so an unvisited first town is landed on;
## the first town is always visited, so nothing here has to guard against it.
func _skip_unvisited_gen1(step: int) -> void:
	while rows[row_index] == Gen1Layout.TOWN_MAP_NOT_VISITED and row_index > 0:
		row_index = wrapi(row_index + step, 0, rows.size())


## `.ScrollNext` and `.ScrollPrev`'s loop, wrapping the way one press does. The
## window is at most twelve wide and always holds the default, so it terminates.
func _skip_unvisited(step: int) -> void:
	if screen != SCREEN_FLY:
		return
	for _guard: int in Gen2Layout.FLYPOINT_COUNT:
		if visited_flypoints.has(cursor) or cursor == _default_flypoint():
			return
		if step > 0:
			cursor = _first if cursor >= _last else cursor + 1
		else:
			cursor = _last if cursor == _first else cursor - 1


## The flypoint the map opened on, which the source leaves reachable regardless.
func _default_flypoint() -> int:
	return FLY_INDIGO if _first == Gen2Layout.KANTO_FLYPOINT else 0
