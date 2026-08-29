extends RefCounted

var _r: RefCounted = null

## Verifies the two Ruins of Alph walls a field move opens, against freshly
## imported real caches. `FlashFunction` farcalls `SpecialAerodactylChamber` and
## `EscapeRopeOrDig` farcalls `SpecialKabutoChamber`, so neither is a `special`
## `tools/checks/specials.gd` can see. The flags are Crystal's alone, so the same
## two maps must answer nothing on Gold and Silver.


## constants/map_constants.asm, DUNGEONS group. Both sit at the same number in
## all three pins: the group's eight-map shift starts after them.
const RUINS_GROUP: int = Gen2WorldAPI.RUINS_OF_ALPH_GROUP
const KABUTO_CHAMBER: int = Gen2WorldAPI.RUINS_OF_ALPH_KABUTO_CHAMBER
const AERODACTYL_CHAMBER: int = Gen2WorldAPI.RUINS_OF_ALPH_AERODACTYL_CHAMBER
## `map_const`'s own two operands, and `data/maps/maps.asm`'s tileset column.
const CHAMBER_BLOCKS := Vector2i(4, 5)
const TILESET_RUINS_CRYSTAL: int = 0x1A
const TILESET_RUINS_GOLD_SILVER: int = 0x17

const WALLS: Dictionary = {
	Gen2WorldAPI.EVENT_WALL_OPENED_IN_KABUTO_CHAMBER: KABUTO_CHAMBER,
	Gen2WorldAPI.EVENT_WALL_OPENED_IN_AERODACTYL_CHAMBER: AERODACTYL_CHAMBER,
}

## `.DoDig` refuses on a zero `wDigWarpNumber` byte, so the rope needs one
## recorded. Which warp it is decides nothing about the wall.
const DIG_WARP: Dictionary = {"warp": 1, "map_group": 3, "map_number": 22}


func run(r: RefCounted) -> void:
	_r = r
	_r.each_game(func() -> void:
		_verify_chambers()
		_sweep_maps()
		_verify_flash()
		_verify_escape_rope()
	)


## Both rooms are DUNGEON and neither is dark, which is why the Aerodactyl
## branch has to run before the palette test: a Flash gated on darkness alone
## could never open that wall.
func _verify_chambers() -> void:
	for number: int in [KABUTO_CHAMBER, AERODACTYL_CHAMBER]:
		var map: Gen2WorldMap = _r.data.world_map(RUINS_GROUP, number)
		if not _r.check(map != null, "map %d/%d is missing." % [RUINS_GROUP, number]):
			continue
		_r.check(
			map.environment == Gen2WorldAPI.ENVIRONMENT_DUNGEON,
			"map %d/%d environment is %d, not DUNGEON." % [
				RUINS_GROUP, number, map.environment,
			]
		)
		_r.check(
			not Gen2WorldPalette.is_dark(map.palette),
			"map %d/%d is dark, so Flash would reach it anyway." % [RUINS_GROUP, number]
		)
		_r.check(
			map.tileset == (
				TILESET_RUINS_CRYSTAL if _r.crystal else TILESET_RUINS_GOLD_SILVER
			),
			"map %d/%d tileset is %d." % [RUINS_GROUP, number, map.tileset]
		)
		_r.check(
			Vector2i(map.width_blocks, map.height_blocks) == CHAMBER_BLOCKS,
			"map %d/%d is %dx%d blocks, not %s." % [
				RUINS_GROUP, number, map.width_blocks, map.height_blocks, CHAMBER_BLOCKS,
			]
		)


## The corpus half: each wall answers on exactly one of the cartridge's maps,
## and on none at all outside Crystal.
func _sweep_maps() -> void:
	var wanted: int = 1 if _r.crystal else 0
	for event: int in WALLS:
		var answered: Array[String] = []
		for map: Gen2WorldMap in _r.data.world_maps():
			var world: Gen2WorldAPI = _r.open_world(map.group, map.number, Vector2i.ZERO)
			if world == null:
				continue
			if world.unown_wall_event(event) == event:
				answered.append("%d/%d" % [map.group, map.number])
		_r.check(
			answered.size() == wanted,
			"event %d answers on %d maps (%s), not %d." % [
				event, answered.size(), ", ".join(answered), wanted,
			]
		)
		if wanted == 1 and answered.size() == 1:
			_r.check(
				answered[0] == "%d/%d" % [RUINS_GROUP, int(WALLS[event])],
				"event %d answers on %s." % [event, answered[0]]
			)
	_r.note("%d maps swept for the two farcalled walls." % _r.data.world_maps().size())


## `.CheckUseFlash`: badge, then `SpecialAerodactylChamber`, then the palette, so
## the chamber succeeds on a lit map where every other room is refused.
func _verify_flash() -> void:
	var state := Gen2WorldState.new()
	state.set_engine_flag(
		Gen2WorldState.badge_flag(Gen2WorldFieldMove.BADGE_ZEPHYR, _r.crystal)
	)
	var world: Gen2WorldAPI = _r.open_world(
		RUINS_GROUP, AERODACTYL_CHAMBER, Vector2i.ZERO, state
	)
	if world == null:
		return
	_r.field_move_party(world)
	var staged: Dictionary = world.flash_request()
	if not _r.crystal:
		_r.check(
			StringName(staged.get("reason", &"")) == &"not_dark",
			"Flash is not refused in the chamber: %s" % staged
		)
		return
	if not _r.check(
		bool(staged.get("ok", false)), "Flash refused in the chamber: %s" % staged
	):
		return
	world.complete_flash()
	_r.check(
		world.state.is_event_flag_active(
			Gen2WorldAPI.EVENT_WALL_OPENED_IN_AERODACTYL_CHAMBER
		),
		"Flash left the Aerodactyl wall shut."
	)
	_r.note("Flash opened the Aerodactyl wall on a map that is not dark.")


## `.escaperope`'s farcall, and the Dig branch that skips it.
func _verify_escape_rope() -> void:
	for digging: bool in [false, true]:
		var world: Gen2WorldAPI = _r.open_world(
			RUINS_GROUP, KABUTO_CHAMBER, Vector2i.ZERO
		)
		if world == null:
			return
		_r.field_move_party(world)
		world.dig_warp = DIG_WARP.duplicate()
		var answer: Dictionary = world.dig_request() if digging \
			else world.escape_rope_request()
		if not _r.check(
			bool(answer.get("ok", false)),
			"%s refused in the chamber: %s" % ["Dig" if digging else "the rope", answer]
		):
			continue
		var opened: bool = world.state.is_event_flag_active(
			Gen2WorldAPI.EVENT_WALL_OPENED_IN_KABUTO_CHAMBER
		)
		_r.check(
			opened == (_r.crystal and not digging),
			"the Kabuto wall is %s after %s." % [
				"open" if opened else "shut", "Dig" if digging else "the rope",
			]
		)
	if _r.crystal:
		_r.note("an escape rope opened the Kabuto wall and Dig did not.")
