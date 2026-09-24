class_name Gen2WorldDrawList
extends RefCounted

## Everything the overworld draws over its map this frame, resolved once: every
## sprite as rows in draw order and the frame-wide background edits under them.
## The built-in renderer and `set_draw_list` read the same one, so no two views
## resolve a sprite apart. The screen writes the state.

const KIND_SPRITE: StringName = &"sprite"
const KIND_TILES: StringName = &"tiles"
const KIND_GRASS: StringName = &"grass"
const KIND_PULSE: StringName = &"pulse"
## What a row's `origin` is measured in: world pixels, pixels of the drawn
## surface, or pixels of the 160x144 screen inside it.
const ANCHOR_WORLD: StringName = &"world"
const ANCHOR_VIEW: StringName = &"view"
const ANCHOR_SCREEN: StringName = &"screen"
const OWNER_PLAYER: int = Gen2WorldObject.PLAYER_INDEX
const OWNER_NONE: int = Gen2WorldObject.NONE_INDEX
const OWNER_ACTOR: int = -3

const CELL: int = Gen2WorldAPI.CELL_PIXELS
## `.InitSprite`'s `add OAM_Y_OFS - 4`: every map object and tracking sprite
## stands four pixels above its cell; a sprite anim and the grass take none.
const SPRITE_LIFT := Vector2(0, -4)
## Where a cell-sized picture meets the ground: its bottom centre.
const GROUND := Vector2(CELL * 0.5, CELL)
## The enemy battler's box: the shiny pulse's OAM is laid out around its centre,
## which is put on the walk cell's.
const BATTLER_CENTRE := Vector2(
	(Gen2BattleScreenMap.ENEMY_AT.x + 0.5 * Gen2BattleScreenMap.ENEMY_SIDE) * PokeTiles.TILE_WIDTH,
	(Gen2BattleScreenMap.ENEMY_AT.y + 0.5 * Gen2BattleScreenMap.ENEMY_SIDE) * PokeTiles.TILE_HEIGHT
)
## `LoadPikachuShadowOAMData`: the ledge shadow's tile and its mirror.
const SHADOW_TILES: Array = [
	{"tile": 0, "offset": Vector2i(0, 12), "flip_x": false, "flip_y": false},
	{"tile": 0, "offset": Vector2i(8, 12), "flip_x": true, "flip_y": false},
]

## `HideSprites`: no map object and no player reaches OAM.
var sprites_hidden: bool = false
## The map fade's palette order and `FillWhiteBGColor`, the step last offered.
var fade_order: int = Gen2WorldPalette.FADE_IDENTITY
var fade_white_fill: bool = false
## `LoadPoisonBGPals`, which floods the background alone.
var poison_flash: bool = false
var time_of_day: int = Gen2WorldPalette.TIME_MORNING
## [constant Gen2ModHost.RENDERER_DRAW_REACH_METHOD]'s answer.
var reach_pixels: int = 0

var _world: Gen2WorldAPI = null
var _effects: Gen2WorldEffects = null
var _actors: Gen2WorldActors = null
var _encounters: Gen2WorldEncounters = null
var _transition_sprites: int = Gen2BattleTransition.SPRITES_ALL
var _transition_opponent: int = -1
var _transition_palette := PackedColorArray()
var _sheets: Dictionary = {}
## One resolve's colours per palette row, converted once however many read it.
var _colors: Dictionary = {}


func _init(
	world: Gen2WorldAPI = null, effects: Gen2WorldEffects = null,
	actors: Gen2WorldActors = null, encounters: Gen2WorldEncounters = null
) -> void:
	_world = world
	_effects = effects
	_actors = actors
	_encounters = encounters


## `DoBattleTransition`'s hold on OAM: which objects it left, the opponent
## `RespawnPlayerAndOpponent` keeps, and the trainer flood `.copypals` also
## writes over the tree and rock palettes.
func set_transition(left: int, opponent: int, palette: PackedColorArray) -> void:
	_transition_sprites = left
	_transition_opponent = opponent
	_transition_palette = palette


func clear_transition() -> void:
	set_transition(Gen2BattleTransition.SPRITES_ALL, -1, PackedColorArray())


## The whole frame: [method sprites] and every frame-wide value beside it.
func frame() -> Dictionary:
	return {
		"sprites": sprites(),
		"background_offset": background_offset(),
		"hidden_tree_cells": hidden_tree_cells(),
		"hidden_tree_tile": Gen2WorldEffects.HEADBUTT_TREE_HIDDEN_TILE,
		"tile_overrides": tile_overrides(),
		"band_scroll": band_scroll(),
		"fade_order": fade_order,
		"white_fill": fade_white_fill,
		"poison_flash": poison_flash,
		"sprites_hidden": sprites_hidden,
		"time_of_day": time_of_day,
	}


## `StepFunction_ScreenShake` and the Generation 1 elevator: hSCY alone, so the
## background moves and no sprite does.
func background_offset() -> Vector2:
	return _effects.offset() if _effects != null else Vector2.ZERO


## The cells whose four tiles `HideHeadbuttTree` has replaced with
## `hidden_tree_tile` while the tree's own sprite anim plays.
func hidden_tree_cells() -> Array:
	return _effects.hidden_tree_cells() if _effects != null else []


func tile_overrides() -> Dictionary:
	return _world.screen_tile_overrides() if _world != null else {}


## `VermilionDock_SyncScrollWithLY`: screen lines `top` to `bottom` scrolled
## `offset` pixels left, or empty.
func band_scroll() -> Dictionary:
	if _effects == null or not _effects.ss_anne_active() \
		or _effects.ss_anne_band_offset() <= 0:
		return {}
	return {
		"top": Gen1Layout.SS_ANNE_BAND_TOP, "bottom": Gen1Layout.SS_ANNE_BAND_BOTTOM,
		"offset": _effects.ss_anne_band_offset(),
	}


## The rows, in the order the cartridge's OAM puts them on screen.
func sprites() -> Array:
	var out: Array = []
	if _world == null or _world.data == null \
		or _transition_sprites == Gen2BattleTransition.SPRITES_NONE:
		return out
	_colors.clear()
	var battlers_only: bool = _transition_sprites == Gen2BattleTransition.SPRITES_BATTLERS
	var effects: Array = _effects.sprites() if _effects != null else []
	var player: Dictionary = _player_owner()
	if not sprites_hidden:
		for entry: Dictionary in _row_entries(battlers_only):
			_add_entry(out, entry, effects, battlers_only)
		_add_player(out, player)
	if not battlers_only:
		_add_free(out, effects, player)
	return out


## One effect sheet's tiles, the Generation 1 Cut strips included.
func sheet(sheet_name: String) -> Dictionary:
	if _world == null or _world.data == null:
		return {}
	if not _sheets.has(sheet_name):
		var found: Dictionary = _gen1_cut_sheet(sheet_name)
		_sheets[sheet_name] = found if not found.is_empty() \
			else _world.data.overworld_effect(sheet_name)
	return _sheets[sheet_name]


## A sprite row's picture in [param colors]; the row's own are before the fade.
func sprite_image(row: Dictionary, colors: PackedColorArray) -> Image:
	var sprite: Gen2WorldSprite = row.get("sprite", null)
	if sprite == null or _world == null or _world.data == null:
		return null
	var indices: PackedByteArray = _world.data.overworld_icon_indices(sprite.icon_number) \
		if sprite.sprite_type == Gen2WorldSprite.TYPE_MON_ICON \
		else _world.data.overworld_sprite_indices(sprite.number)
	var big: int = int(row.get("big_shape", Gen2WorldSprite.BIG_SHAPE_NONE))
	if big != Gen2WorldSprite.BIG_SHAPE_NONE:
		return Gen2WorldSprite.big_image_for(sprite, indices, colors, big)
	return Gen2WorldSprite.image_for(
		sprite, indices, colors, int(row["facing"]), int(row["frame"])
	)


## One 8x8 tile of an effect sheet. Index 0 is transparent: these are sprites.
func tile_image(
	sheet_name: String, tile: int, colors: PackedColorArray, flip_x: bool = false,
	flip_y: bool = false
) -> Image:
	var found: Dictionary = sheet(sheet_name)
	if found.is_empty():
		return null
	var indices: PackedByteArray = found["indices"]
	var tiles: int = int(found["tiles"])
	if tile < 0 or tile >= tiles or indices.size() < tiles * PokeTiles.TILE_PIXELS:
		return null
	var image := Image.create(PokeTiles.TILE_WIDTH, PokeTiles.TILE_HEIGHT, false, Image.FORMAT_RGBA8)
	var width: int = tiles * PokeTiles.TILE_WIDTH
	for y: int in PokeTiles.TILE_HEIGHT:
		for x: int in PokeTiles.TILE_WIDTH:
			var index: int = int(indices[y * width + tile * PokeTiles.TILE_WIDTH + x])
			var color: Color = colors[index] if index < colors.size() else Color.MAGENTA
			if index == 0:
				color.a = 0.0
			image.set_pixel(x, y, color)
	if flip_x:
		image.flip_x()
	if flip_y:
		image.flip_y()
	return image


## A pulse row's tile of `ANIM_SEND_OUT_MON`, in the battle object palette it names.
func pulse_image(row: Dictionary) -> Image:
	var strip: PackedByteArray = _world.data.battle_anim_gfx_indices(int(row["gfx"]))
	var tile: int = int(row["tile"])
	@warning_ignore("integer_division")
	var width: int = strip.size() / PokeTiles.TILE_HEIGHT
	if width <= 0 or (tile + 1) * PokeTiles.TILE_WIDTH > width:
		return null
	var pixels := PackedByteArray()
	pixels.resize(PokeTiles.TILE_PIXELS)
	for y: int in PokeTiles.TILE_HEIGHT:
		var from: int = y * width + tile * PokeTiles.TILE_WIDTH
		for x: int in PokeTiles.TILE_WIDTH:
			pixels[y * PokeTiles.TILE_WIDTH + x] = strip[from + x]
	var attributes: int = int(row["attributes"])
	var image: Image = Gen2PicImage.from_indices(
		pixels, PokeTiles.TILE_WIDTH, PokeTiles.TILE_HEIGHT,
		_world.data.battle_object_palette(attributes & Gen2BattleAnimObject.OAM_PALETTE, row["pair"]),
		true
	)
	if (attributes & Gen2BattleAnimObject.OAM_XFLIP) != 0:
		image.flip_x()
	if (attributes & Gen2BattleAnimObject.OAM_YFLIP) != 0:
		image.flip_y()
	return image


## The object pass's rows: the map's objects, a mod's actors, Yellow's slot
## fifteen and the connected maps' people.
func _row_entries(battlers_only: bool) -> Array:
	var objects: Array = _world.visible_objects()
	objects.sort_custom(_sort_objects)
	var drawn: Array = []
	for object: Gen2WorldObject in objects:
		if battlers_only and object.index != _transition_opponent:
			continue
		drawn.append({"object": object, "row": float(object.cell.y)})
	if battlers_only:
		return drawn
	if _actors != null:
		for sprite: Dictionary in _actors.sprites():
			drawn.append({"actor": sprite, "row": (sprite["position_cells"] as Vector2).y})
	var follower: Dictionary = _world.gen1_pikachu_sprite()
	if not follower.is_empty():
		drawn.append({"actor": follower, "row": (follower["position_cells"] as Vector2).y})
	_add_connected(drawn)
	drawn.sort_custom(_sort_drawn)
	return drawn


## The connected maps' people within [member reach_pixels] and two cells of the
## surface. The cartridge's `ReadObjectEvents` reads the loaded map alone.
func _add_connected(drawn: Array) -> void:
	if _world.view_pixels == Gen2WorldAPI.VIEW_PIXELS and reach_pixels <= 0:
		return
	var reach := Rect2(_world.view_origin_subpixel(), Vector2(_world.view_pixels)) \
		.grow(float(reach_pixels + 2 * CELL))
	for entry: Dictionary in _world.connected_map_objects():
		var neighbour: Gen2WorldObject = entry["object"]
		var offset: Vector2i = entry["offset"]
		if neighbour.active and neighbour.sprite != null \
			and reach.has_point(Vector2((neighbour.cell + offset) * CELL)):
			drawn.append({
				"object": neighbour, "offset": offset,
				"row": float(offset.y + neighbour.cell.y),
			})


## A mod's actors sort into the objects' rows, after the map's own on a tie.
func _sort_drawn(first: Dictionary, second: Dictionary) -> bool:
	if is_equal_approx(float(first["row"]), float(second["row"])):
		if first.has("object") and second.has("object"):
			return _sort_objects(first["object"], second["object"])
		return first.has("object")
	return float(first["row"]) < float(second["row"])


func _sort_objects(first: Gen2WorldObject, second: Gen2WorldObject) -> bool:
	if first.cell.y == second.cell.y:
		return first.index < second.index
	return first.cell.y < second.cell.y


func _add_entry(out: Array, entry: Dictionary, effects: Array, battlers_only: bool) -> void:
	if entry.has("actor"):
		_add_actor(out, entry["actor"])
		return
	var object: Gen2WorldObject = entry["object"]
	var shift: Vector2i = entry.get("offset", Vector2i.ZERO)
	var fraction: float = _world.pass_fraction
	var height: float = object.height_offset_pixels()
	var owner: Dictionary = _owner(
		object.index if shift == Vector2i.ZERO else OWNER_NONE, ANCHOR_WORLD,
		Vector2((object.cell + shift) * CELL) + Vector2(object.step_offset(CELL, fraction))
			+ SPRITE_LIFT,
		Vector2(object.cell + shift) + object.step_offset_cells(fraction),
		_shifted(object.step_span(fraction), shift), height
	)
	if object.sprite != null:
		_add_sprite(
			out, owner, &"object" if shift == Vector2i.ZERO else &"connected",
			object.sprite, object.palette, object.drawn_facing(), object.frame,
			Vector2(0, -height), object.big_object_shape()
		)
	if shift != Vector2i.ZERO:
		return
	if _world.in_grass(object.cell):
		_add_grass(out, owner, Vector2.ZERO, object.cell)
	if object.emote_visible:
		_add_emote(out, owner, object.emote_id, Vector2.ZERO)
	if not battlers_only:
		_add_carried(out, owner, effects, object.index)


## A row shaped as [method Gen2WorldActors.sprites] shapes one, or Yellow's
## follower: its position is its own pixels, its bubble outlives its picture.
func _add_actor(out: Array, entry: Dictionary) -> void:
	var cells: Vector2 = entry["position_cells"]
	var height: float = float(entry.get("height_offset_pixels", 0.0))
	var owner: Dictionary = _owner(
		OWNER_ACTOR, ANCHOR_WORLD, cells * float(CELL) + SPRITE_LIFT, cells,
		entry.get("span", {}), height
	)
	var jump := Vector2(0, -height)
	if bool(entry.get("shadow", false)):
		_add_tiles(
			out, owner, &"shadow", String(Gen2WorldEffects.SPRITE_SHADOW),
			Gen2WorldEffects.PAL_OW_EMOTE, SHADOW_TILES, Vector2.ZERO
		)
	if not bool(entry.get("hidden", false)):
		_add_sprite(
			out, owner, &"actor", entry["sprite"], 0, int(entry["facing"]),
			int(entry["frame"]), jump, Gen2WorldSprite.BIG_SHAPE_NONE,
			entry.get("colors", PackedColorArray())
		)
		var grass: Vector2i = entry.get(
			"grass_cell", Vector2i(roundi(cells.x), roundi(cells.y))
		)
		if _world.in_grass(grass):
			_add_grass(out, owner, jump, grass)
	_add_emote(out, owner, int(entry.get("emote", Gen2WorldActors.EMOTE_NONE)), Vector2.ZERO)


func _player_owner() -> Dictionary:
	return _owner(
		OWNER_PLAYER, ANCHOR_VIEW, Vector2(_world.player_view_pixel()) + SPRITE_LIFT,
		_world.player_position_cells(), _world.player_step_span(),
		_world.player_height_offset_pixels()
	)


## `disappear PLAYER` and a skyfall's start take object zero out of OAM.
func _add_player(out: Array, owner: Dictionary) -> void:
	var anim: Dictionary = _effects.player_anim() if _effects != null else {}
	if not anim.is_empty():
		_add_player_anim(out, owner, anim)
		return
	if not _world.player_visible() or _world.player_skyfall_hidden():
		return
	var sprite: Gen2WorldSprite = _world.player_sprite()
	var jump := Vector2(0, _world.player_jump_offset())
	if sprite == null:
		_add_sprite(out, owner, &"player", null, 0, 0, 0, Vector2.ZERO)
		return
	var fishing: String = _fishing_sheet() if _world.fishing_busy() else ""
	var body: Dictionary = _add_sprite(
		out, owner, &"player", sprite, _world.player_palette(),
		_world.player_drawn_facing(), _world.player_walk_frame(), jump
	)
	if not fishing.is_empty():
		_add_fishing_body(out, owner, body, fishing, jump)
	if _world.in_grass(_world.player_cell):
		_add_grass(out, owner, jump, _world.player_cell)
	if not fishing.is_empty():
		var rod: Dictionary = Gen2WorldEffects.FISHING_ROD_TILES[clampi(
			_world.player_facing, 0, Gen2WorldEffects.FISHING_ROD_TILES.size() - 1
		)]
		_add_tiles(out, owner, &"fishing_rod", fishing, _world.player_palette(), [{
			"tile": int(rod["tile"]), "offset": rod["offset"] as Vector2i,
			"flip_x": bool(rod["flip_x"]), "flip_y": false,
		}], jump)
	_add_emote(out, owner, _world.player_emote(), jump)


## `LoadFishingGFX`: the standing picture to the waist and the sheet's pair under it.
func _add_fishing_body(
	out: Array, owner: Dictionary, body: Dictionary, fishing: String, jump: Vector2
) -> void:
	var half: float = float(CELL) * 0.5
	body["region"] = Rect2(0, 0, CELL, half)
	var pair: Array = Gen2WorldEffects.FISHING_BODY_TILES[clampi(
		_world.player_facing, 0, Gen2WorldEffects.FISHING_BODY_TILES.size() - 1
	)]
	var tiles: Array = []
	for cell: int in pair.size():
		tiles.append({
			"tile": int(pair[cell]["tile"]), "offset": Vector2i(cell * PokeTiles.TILE_WIDTH, 0),
			"flip_x": bool(pair[cell]["flip_x"]), "flip_y": false,
		})
	_add_tiles(
		out, owner, &"fishing_body", fishing, _world.player_palette(), tiles,
		jump + Vector2(0, half)
	)


func _fishing_sheet() -> String:
	var own: String = Gen2WorldEffects.FISHING_SHEETS[1 if _world.player_female() else 0]
	if not sheet(own).is_empty():
		return own
	var fallback: String = Gen2WorldEffects.FISHING_SHEETS[0]
	return fallback if not sheet(fallback).is_empty() else ""


## `PrepareOAMData`'s player under `_LeaveMapAnim` and `EnterMapAnim`, clipped
## to the 160x144 pane; `LeaveMapThroughHoleAnim` moves the top half a row down.
func _add_player_anim(out: Array, owner: Dictionary, anim: Dictionary) -> void:
	if bool(anim.get("hidden", false)):
		return
	var bird: bool = bool(anim.get("bird", false))
	var sprite: Gen2WorldSprite = _world.data.overworld_sprite(Gen1Layout.SPRITE_BIRD) \
		if bird else _world.player_sprite()
	if sprite == null:
		return
	var image: int = int(anim.get("image", 0))
	var offset := Vector2(
		int(anim.get("x", Gen1Layout.PLAYER_SPRITE_PIXELS.x)) - Gen1Layout.PLAYER_SPRITE_PIXELS.x,
		int(anim.get("y", Gen1Layout.PLAYER_SPRITE_PIXELS.y)) - Gen1Layout.PLAYER_SPRITE_PIXELS.y
	)
	var row: Dictionary = _add_sprite(
		out, owner, &"bird" if bird else &"player", sprite, _world.player_palette(),
		image >> 2, image & 3, offset
	)
	row["clip_to_screen"] = true
	if bool(anim.get("half", false)):
		row["region"] = Rect2(0, 0, CELL, float(CELL) * 0.5)
		row["offset"] = offset + Vector2(0, float(CELL) * 0.5)


## The sprites the source draws from `wShadowOAMSprite36` up: the player's own
## effects, the sprite anims over a cell, the fixed screen OAM and the pulse.
func _add_free(out: Array, effects: Array, player: Dictionary) -> void:
	_add_carried(out, player, effects, OWNER_PLAYER)
	for sprite: Dictionary in effects:
		if int(sprite["object_index"]) == OWNER_NONE:
			var cell: Vector2i = sprite["cell"]
			_add_effect(out, _owner(
				OWNER_NONE, ANCHOR_WORLD, Vector2(cell * CELL), Vector2(cell), {}, 0.0
			), sprite)
	var screen: Dictionary = _owner(
		OWNER_NONE, ANCHOR_SCREEN, Vector2.ZERO, Vector2.ZERO, {}, 0.0
	)
	for sprite: Dictionary in effects:
		if bool(sprite.get("screen", false)):
			var first: int = out.size()
			_add_effect(out, screen, sprite)
			for row: Dictionary in out.slice(first):
				_stand_on_map(row)
	_add_pulse(out)


## A screen row stands as a cell effect on the map cell under its picture's centre.
func _stand_on_map(row: Dictionary) -> void:
	var corner: Vector2 = _world.view_origin_subpixel() \
		+ Vector2(Gen2Screen.hardware_corner(_world.view_pixels))
	var cell := Vector2i(((corner + _picture(row).get_center()) / float(CELL)).floor())
	row["position_cells"] = Vector2(cell)
	row["ground"] = Vector2(cell * CELL) + GROUND - corner


func _picture(row: Dictionary) -> Rect2:
	var at: Vector2 = row["origin"] + row["offset"]
	if row["kind"] != KIND_TILES:
		return Rect2(at, Vector2(CELL, CELL))
	var box := Rect2()
	for tile: Dictionary in row["tiles"]:
		var piece := Rect2(
			at + Vector2(tile["offset"] as Vector2i),
			Vector2(PokeTiles.TILE_WIDTH, PokeTiles.TILE_HEIGHT)
		)
		box = piece if not box.has_area() else box.merge(piece)
	return box


## The dust, the rustle and the shadow track the object that spawned them.
func _add_carried(out: Array, owner: Dictionary, effects: Array, index: int) -> void:
	for sprite: Dictionary in effects:
		if not bool(sprite.get("screen", false)) and int(sprite["object_index"]) == index:
			_add_effect(out, owner, sprite)


func _add_effect(out: Array, owner: Dictionary, sprite: Dictionary) -> void:
	if sprite.has("icon"):
		_add_fly_mon(out, owner, sprite)
		return
	var tiles: Array = []
	for tile: Dictionary in sprite["tiles"]:
		tiles.append({
			"tile": int(tile["tile"]), "offset": tile["offset"] as Vector2i,
			"flip_x": bool(tile["flip_x"]), "flip_y": bool(tile.get("flip_y", false)),
		})
	_add_tiles(
		out, owner, StringName(sprite["kind"]), String(sprite["kind"]),
		int(sprite["palette"]), tiles, Vector2.ZERO, int(sprite.get("rotation", 0))
	)


## `.OAMData_RedWalk` names PAL_OW_RED, so the icon wears the player's palette.
func _add_fly_mon(out: Array, owner: Dictionary, sprite: Dictionary) -> void:
	var tiles: Array = sprite["tiles"]
	var icon: Gen2WorldSprite = _world.data.overworld_icon(int(sprite["icon"])) \
		if not tiles.is_empty() else null
	if icon == null:
		return
	var tile: Dictionary = tiles[0]
	var row: Dictionary = _add_sprite(
		out, owner, Gen2WorldEffects.SPRITE_FLY_MON, icon, 0,
		Gen2WorldSprite.FACING_UP if int(tile["tile"]) == 1 else Gen2WorldSprite.FACING_DOWN,
		0, Vector2(tile["offset"] as Vector2i), Gen2WorldSprite.BIG_SHAPE_NONE,
		_sprite_colors(int(sprite["palette"]))
	)
	row["flip_x"] = bool(tile["flip_x"])


## The shiny pulse: `ANIM_SEND_OUT_MON`'s objects, drawn where the Pokemon stands.
func _add_pulse(out: Array) -> void:
	if _encounters == null:
		return
	var anchor: Variant = _encounters.pulse_anchor()
	if not anchor is Vector2:
		return
	var at: Vector2 = anchor
	var owner: Dictionary = _owner(
		OWNER_ACTOR, ANCHOR_WORLD, at + Vector2(CELL, CELL) * 0.5 - BATTLER_CENTRE,
		at / float(CELL), {}, 0.0
	)
	owner["ground"] = at + GROUND
	var window: Array = _encounters.pulse_tiles()
	var pair: Array = _encounters.pulse_battler_pair()
	for entry: Variant in _encounters.pulse_sprites():
		if not entry is Dictionary:
			continue
		var sprite: Dictionary = entry
		var slot: int = int(sprite.get("tile", 0)) - Gen2BattleAnimObject.BASE_TILE
		# `anim_battlergfx_*` moves a battler as objects and has no picture here.
		if slot < 0 or slot >= window.size() or not window[slot] is Dictionary \
			or not (window[slot] as Dictionary).has("gfx"):
			continue
		var row: Dictionary = _row(owner, KIND_PULSE, &"pulse", Vector2(
			float(int(sprite.get("x", 0)) - 8), float(int(sprite.get("y", 0)) - 16)
		))
		row["gfx"] = int(window[slot]["gfx"])
		row["tile"] = int(window[slot]["tile"])
		row["attributes"] = int(sprite.get("attributes", 0))
		row["pair"] = pair
		out.append(row)


## `SpawnEmote`: four tiles two rows above the sprite.
func _add_emote(out: Array, owner: Dictionary, emote: int, offset: Vector2) -> void:
	if emote < 0 or emote >= Gen2Layout.EMOTE_NAMES.size():
		return
	var tiles: Array = []
	for index: int in 4:
		tiles.append({
			"tile": index, "offset": Vector2i((index & 1) * 8, (index >> 1) * 8 - 16),
			"flip_x": false, "flip_y": false,
		})
	_add_tiles(
		out, owner, &"emote", Gen2Layout.EMOTE_NAMES[emote], Gen2WorldEffects.PAL_OW_EMOTE,
		tiles, offset
	)


## `SetTallGrassFlags`' IN_GRASS_F: the map's own tiles over the lower half of
## the sprite at `offset`, colour 0 left out, which is OAM_PRIO.
func _add_grass(out: Array, owner: Dictionary, offset: Vector2, cell: Vector2i) -> void:
	var row: Dictionary = _row(owner, KIND_GRASS, &"grass", offset)
	row["cell"] = cell
	out.append(row)


func _add_sprite(
	out: Array, owner: Dictionary, role: StringName, sprite: Gen2WorldSprite,
	palette: int, facing: int, step_frame: int, offset: Vector2,
	big_shape: int = Gen2WorldSprite.BIG_SHAPE_NONE,
	colors: PackedColorArray = PackedColorArray()
) -> Dictionary:
	var row: Dictionary = _row(owner, KIND_SPRITE, role, offset)
	var resolved: int = sprite.default_palette if sprite != null and palette == 0 else palette
	row["sprite"] = sprite
	row["palette"] = resolved
	row["colors"] = colors if not colors.is_empty() else _sprite_colors(resolved)
	row["facing"] = facing
	row["frame"] = step_frame
	row["big_shape"] = big_shape
	row["flip_x"] = false
	row["region"] = Rect2()
	row["clip_to_screen"] = false
	out.append(row)
	return row


func _add_tiles(
	out: Array, owner: Dictionary, role: StringName, sheet_name: String, palette: int,
	tiles: Array, offset: Vector2, rotation: int = 0
) -> void:
	var row: Dictionary = _row(owner, KIND_TILES, role, offset)
	row["sheet"] = sheet_name
	row["palette"] = palette
	row["colors"] = _effect_colors(sheet(sheet_name), palette, rotation)
	row["tiles"] = tiles
	out.append(row)


func _owner(
	index: int, anchor: StringName, origin: Vector2, cells: Vector2, span: Dictionary,
	height: float
) -> Dictionary:
	return {
		"owner": index, "anchor": anchor, "origin": origin, "position_cells": cells,
		"span": span, "height_offset_pixels": height, "ground": origin + GROUND,
	}


func _row(owner: Dictionary, kind: StringName, role: StringName, offset: Vector2) -> Dictionary:
	var row: Dictionary = owner.duplicate()
	row["kind"] = kind
	row["role"] = role
	row["offset"] = offset
	return row


## A connected map's span, in this map's cell numbering.
static func _shifted(span: Dictionary, shift: Vector2i) -> Dictionary:
	if span.is_empty() or shift == Vector2i.ZERO:
		return span
	var moved: Dictionary = span.duplicate()
	moved["from"] = (span["from"] as Vector2i) + shift
	moved["to"] = (span["to"] as Vector2i) + shift
	return moved


## `.copypals` writes the trainer flood over PAL_OW_TREE and PAL_OW_ROCK as well,
## so a boulder or a fruit tree turns with the background it stands on.
func _sprite_colors(palette: int) -> PackedColorArray:
	if not _transition_palette.is_empty() \
		and palette in [Gen2WorldEffects.PAL_OW_TREE, Gen2WorldEffects.PAL_OW_ROCK]:
		return _transition_palette
	return _object_colors(palette)


func _object_colors(palette: int) -> PackedColorArray:
	if not _colors.has(palette):
		_colors[palette] = Gen2WorldPalette.overworld_sprite_colors(
			_world.data, _world.current_map, palette, time_of_day,
			_world.gen1_last_map(), _world.gen1_map_pal_offset
		)
	return _colors[palette]


## A sheet with `colors` of its own is the heal machine, which `.FlashPalettes`
## rotates left [param rotation] times. Generation 1's machine wears `rOBP1`,
## which `FlashSprite8Times` xors $28 into, and the smoke the map's own four
## through a DMG order. Everything else wears the palette its spawn named.
func _effect_colors(found: Dictionary, palette: int, rotation: int) -> PackedColorArray:
	var own: PackedColorArray = found.get("colors", PackedColorArray())
	if not own.is_empty():
		var rotated := PackedColorArray()
		for slot: int in own.size():
			rotated.append(own[(slot + rotation) % own.size()])
		return rotated
	if palette == Gen2WorldEffects.OBP_PALETTE:
		return Gen2WorldPalette.fade_palette(_gen1_map_colors(), rotation)
	if palette == Gen2WorldEffects.HEAL_MACHINE_PALETTE \
		and _world.data.generation == RomRegistry.GEN1:
		var map_colors: PackedColorArray = _gen1_map_colors()
		var flashed: int = Gen1Layout.HEAL_MACHINE_OBP1_FLASH if rotation & 1 else 0
		return Gen2WorldPalette.fade_palette(map_colors, Gen1Layout.HEAL_MACHINE_OBP1 ^ flashed)
	return _object_colors(palette)


func _gen1_map_colors() -> PackedColorArray:
	return Gen2WorldPalette.gen1_map_colors(
		_world.data, _world.current_map, _world.gen1_last_map()
	)


## `InitCutAnimOAM` copies its tiles out of `Overworld_GFX` for a tree and
## `MoveAnimationTiles1` for grass, so the cut records index those strips whole.
func _gen1_cut_sheet(sheet_name: String) -> Dictionary:
	var strip := PackedByteArray()
	if sheet_name == Gen2WorldEffects.SPRITE_GEN1_CUT_TREE:
		strip = _world.data.world_tileset_indices(Gen1Layout.TILESET_OVERWORLD)
	elif sheet_name == Gen2WorldEffects.SPRITE_GEN1_CUT_GRASS:
		strip = _world.data.battle_anim_gfx_indices(0)
	if strip.is_empty():
		return {}
	@warning_ignore("integer_division")
	var tiles: int = strip.size() / PokeTiles.TILE_PIXELS
	return {
		"name": sheet_name, "tiles": tiles, "vtile": 0, "colors": PackedColorArray(),
		"indices": strip,
	}
