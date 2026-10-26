class_name Gen3SecretPower
extends RefCounted

## Secret Power in Emerald's fldeff_misc.c and Ruby's fldeff_secretpower.c, with `ToggleSecretBaseEntranceMetatile`.

const FLDEFF_USE_CAVE: int = 11
const FLDEFF_USE_TREE: int = 26
const FLDEFF_USE_SHRUB: int = 27
const FLDEFF_CAVE: int = 55
const FLDEFF_TREE: int = 56
const FLDEFF_SHRUB: int = 57
const USE_EFFECTS: Dictionary = {FLDEFF_USE_CAVE: FLDEFF_CAVE, FLDEFF_USE_TREE: FLDEFF_TREE,
	FLDEFF_USE_SHRUB: FLDEFF_SHRUB}
const SCRIPTS: Dictionary = {FLDEFF_USE_CAVE: "cave_use_secret_power", FLDEFF_USE_TREE: "tree_use_secret_power",
	FLDEFF_USE_SHRUB: "shrub_use_secret_power"}
const SOUNDS: Dictionary = {FLDEFF_CAVE: "m_rock_throw", FLDEFF_TREE: "m_scratch", FLDEFF_SHRUB: "m_poison_powder"}
const MB_CAVES: Array[int] = [0x90, 0x92, 0x94, 0x9A]
const MB_TREE_LEFT: int = 0x96
const MB_SHRUB: int = 0x98
const MB_TREE_RIGHT: int = 0x9C
const BG_EVENT_SECRET_BASE: int = 8
const MAP_OFFSET: int = 7
const VAR_RESULT: int = 0x800D
const VAR_CURRENT_SECRET_BASE: int = 0x4054
const MAPGRID_IMPASSABLE: int = 0xC00
## `sSecretBaseEntranceMetatiles` (Ruby's `gUnknown_083D1358`) as closed, open pairs.
const ENTRANCES: Array = [[0x026, 0x036], [0x027, 0x037], [0x1A0, 0x1A1], [0x1A8, 0x1A9], [0x1B0, 0x1B1],
	[0x208, 0x210], [0x271, 0x278]]
## `AdjustSecretPowerSpritePixelOffsets` by `DIR_*`, from the player's OAM corner; Emerald moves the bikes' 8 right.
const OFFSETS: Dictionary = {1: Vector2i(8, 40), 2: Vector2i(8, 8), 3: Vector2i(-8, 24), 4: Vector2i(24, 24)}
const SIZE: Vector2i = Vector2i(16, 16)
const OPEN_FRAMES: int = 40
const CAVE_TOGGLE_FRAME: int = 20

var sprite: Dictionary = {}
var active: bool = false

var _objects: Gen3ObjectEvents
var _player: Gen3ObjectEvents.ObjectEvent
## `gFieldEffectArguments[7]`, which only a tree spot sets.
var _tree_anim: int = 0


func _init(objects: Gen3ObjectEvents) -> void:
	_objects = objects


## The script `gPostMenuFieldCallback` starts; -1 when the player owns a base or faces no spot to the north.
func set_up(player: Gen3ObjectEvents.ObjectEvent) -> int:
	var events: Gen3EventData = _objects.events
	if events.game not in [RomRegistry.RUBY, RomRegistry.SAPPHIRE, RomRegistry.EMERALD]:
		return -1
	var owned: bool = not events.secret_bases.is_empty() and events.secret_bases[0] != 0
	events.var_set(VAR_RESULT, int(owned))
	if owned or player.facing != Gen3ObjectEvents.Direction.NORTH:
		return -1
	var at: Vector2i = player.current + Gen3FieldCamera.DIRECTIONS[player.facing]
	var behavior: int = _objects.camera.grid.behavior_at(at.x, at.y) & 0xFF
	var effect: int = FLDEFF_USE_CAVE if behavior in MB_CAVES else -1
	if behavior in [MB_TREE_LEFT, MB_TREE_RIGHT]:
		effect = FLDEFF_USE_TREE
	elif behavior == MB_SHRUB:
		effect = FLDEFF_USE_SHRUB
	if effect < 0:
		return -1
	_set_current_base(at)
	return _objects.camera.data.world_native_script_offset(SCRIPTS[effect])


## `SetCurSecretBaseIdFromPosition`, which keeps the last id off a base's event, then `TrySetCurSecretBaseIndex`.
func _set_current_base(at: Vector2i) -> void:
	var events: Gen3EventData = _objects.events
	for row: Dictionary in _objects.camera.data.world_map_events(_objects.camera.group, _objects.camera.number) \
			.get("backgrounds", []):
		if int(row["kind"]) == BG_EVENT_SECRET_BASE \
				and at == Vector2i(int(row["x"]), int(row["y"])) + Vector2i(MAP_OFFSET, MAP_OFFSET):
			events.current_secret_base = int(row["secret_base_id"])
			break
	var index: int = events.secret_bases.find(events.current_secret_base)
	events.var_set(VAR_RESULT, int(index >= 0))
	if index >= 0:
		events.var_set(VAR_CURRENT_SECRET_BASE, index)


func start(use_effect: int, player: Gen3ObjectEvents.ObjectEvent, on_bike: bool) -> void:
	_player = player
	var effect: int = USE_EFFECTS[use_effect]
	var info: Dictionary = _objects.camera.data.world_secret_power_graphics(effect)
	var palette: int = _objects.sprites.load_effect_palette(info)
	if effect == FLDEFF_TREE:
		var at: Vector2i = player.current + Gen3FieldCamera.DIRECTIONS[player.facing]
		var behavior: int = _objects.camera.grid.behavior_at(at.x, at.y) & 0xFFF
		if behavior == MB_TREE_LEFT:
			_tree_anim = 0
		if behavior == MB_TREE_RIGHT:
			_tree_anim = 2
	var offset: Vector2i = OFFSETS.get(player.facing, Vector2i.ZERO)
	if on_bike and _objects.events.game == RomRegistry.EMERALD and player.facing in [1, 2]:
		offset.x = 16
	var corner: Vector2i = Gen3ObjectSprites.corner(player, _objects.graphics_info(player.graphics_id),
		_objects.camera.screen_origin())
	var anim := Gen3SpriteAnim.new()
	anim.anims = info.get("anims", [])
	anim.images = info.get("images", [])
	sprite = {"sprite_slot": _objects.sprites.effect_slot(false), "effect": effect, "anim": anim,
		"position": Vector2i(corner.x & 0x1FF, corner.y & 0xFF) + offset, "size": SIZE, "priority": 2,
		"subpriority": 148, "palette": palette & 0xF, "tiles": PackedByteArray(), "started": false, "timer": 0}
	_objects.sprites.pics.append(sprite)
	active = true
	if effect == FLDEFF_TREE and _tree_anim in [1, 3]:
		_toggle_entrance()


## The `SpriteCB_*Entrance*` callbacks, then `AnimateSprite`.
func animate() -> Array:
	if not active:
		return []
	var effect: int = int(sprite["effect"])
	var anim: Gen3SpriteAnim = sprite["anim"]
	var out: Array = []
	if not sprite["started"]:
		sprite["started"] = true
		if effect == FLDEFF_TREE:
			anim.anim_num = _tree_anim
		out.append({"kind": "sound", "name": SOUNDS[effect]})
	elif int(sprite["timer"]) < 0:
		return _end()
	elif effect == FLDEFF_TREE:
		sprite["timer"] = int(sprite["timer"]) + 1
		if int(sprite["timer"]) >= OPEN_FRAMES:
			if _tree_anim in [0, 2]:
				_toggle_entrance()
			sprite["timer"] = -1
	elif int(sprite["timer"]) < OPEN_FRAMES:
		sprite["timer"] = int(sprite["timer"]) + 1
		if int(sprite["timer"]) == CAVE_TOGGLE_FRAME:
			_toggle_entrance()
	else:
		sprite["timer"] = -1
	anim.animate()
	sprite["tiles"] = PackedByteArray() if anim.tiles.is_empty() \
		else _objects.camera.data.world_sprite_image(int(anim.tiles[0]), int(anim.tiles[1]))
	sprite["flip"] = Vector2i(int(anim.h_flip), int(anim.v_flip))
	return out


func _end() -> Array:
	_objects.sprites.pics.erase(sprite)
	_objects.sprites.free_effect_palette(sprite)
	sprite = {}
	active = false
	return [{"kind": "script_enable"}]


func _toggle_entrance() -> void:
	var at: Vector2i = _player.current + Gen3FieldCamera.DIRECTIONS[_player.facing]
	var grid: Gen3MapGrid = _objects.camera.grid
	var id: int = grid.metatile_id_at(at.x, at.y)
	for side: int in 2:
		for pair: Array in ENTRANCES:
			if int(pair[side]) == id:
				grid.set_metatile_id(at.x, at.y, int(pair[1 - side]) | MAPGRID_IMPASSABLE)
				return
