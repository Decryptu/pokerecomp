extends RefCounted

## A fresh Generation 1 game played the way a player plays it, on all three
## cartridges: the intro's screens to their save, then the world screen to the
## first badge, every button through `press_button`, the driver clocked by the
## frame, and a freeze on any [constant STALL_FRAMES] with nothing moving.

const CheckRun := preload("res://tools/lib/check_run.gd")

const SAVE_ROOT: String = "user://gen1_played_slots"
const PRESET_ROW: int = 1
## The opening to the title is about 3000 frames, the speech about as many again.
const INTRO_FRAMES: int = 12000
## Ten seconds with nothing on the screen moving is a freeze, whatever it waits on.
const STALL_FRAMES: int = 600
## A leg's budget. Oak's speech in the lab is about 2000 frames with every box
## pressed at once; the forest is a wild fight every few steps and three
## trainers, and Brock's two are slow at level 20.
const LEG_FRAMES: int = 12000
const LEG_BUDGETS: Dictionary = {"forest_to_north_gate": 36000, "brock": 24000}
## `BATTLE_PRESS_FRAMES` in replay_world.gd: slow enough that a box waiting for
## a press is not pressed twice.
const PRESS_EVERY: int = 8
## How long a thumb stays on A: the title reads `hJoyHeld`, and a poll every
## other frame misses a one-frame tap the way the hardware does.
const HOLD_FRAMES: int = 4

const REDS_HOUSE_1F: int = 37
const PALLET_TOWN: int = 0
const OAKS_LAB: int = 40
const ROUTE_1: int = 12
const VIRIDIAN_CITY: int = 1
const VIRIDIAN_POKECENTER: int = 41
const VIRIDIAN_MART: int = 42
const ROUTE_2: int = 13
const VIRIDIAN_FOREST_SOUTH_GATE: int = 50
const VIRIDIAN_FOREST: int = 51
const VIRIDIAN_FOREST_NORTH_GATE: int = 47
const PEWTER_CITY: int = 2
const PEWTER_GYM: int = 54

## `PalletTownDefaultScript` stops the player at `wYCoord == 1`, Yellow's at 0.
const PALLET_NORTH_PATH: Dictionary = {
	&"red": Vector2i(10, 1), &"blue": Vector2i(10, 1), &"yellow": Vector2i(10, 0),
}
const LAB_STARTER_BALLS: Dictionary = {
	&"red": Vector2i(6, 4), &"blue": Vector2i(6, 4), &"yellow": Vector2i(7, 4),
}
const LAB_BELOW_OAK := Vector2i(5, 3)
## The nurse stands on (3,1) behind her counter, faced from two cells below;
## Mom stands on (5,4) of the ground floor.
const BELOW_NURSE := Vector2i(3, 3)
const BELOW_MOM := Vector2i(5, 5)
const BELOW_BROCK := Vector2i(4, 2)

const EVENT_GOT_STARTER: int = 34
const EVENT_BATTLED_RIVAL_IN_OAKS_LAB: int = 35
const EVENT_GOT_POKEDEX: int = 37
const EVENT_GOT_OAKS_PARCEL: int = 57
const EVENT_GOT_TM34: int = 118
const EVENT_BEAT_BROCK: int = 119
const OAKS_PARCEL: int = 0x46
const BIT_BOULDERBADGE: int = 0
## The levels a player grinds to on Route 1, before Viridian Forest and before
## Brock, and the Route 22 catch every starter needs against him: a MANKEY with
## LOW KICK. The check writes them the way the save editor does, so a fight is
## decided by the engine and not by luck.
const ROUTE_1_LEVEL: int = 8
const FOREST_LEVEL: int = 12
const BROCK_LEVEL: int = 20
const MANKEY_DEX: int = 56
## The run's own seed, so every wild roll and every fight replays the same.
const RUN_SEED: int = 7

var _r: CheckRun
var _screen: Gen2WorldScreen = null
var _editor: Gen2SaveEditor = null
var _frames: int = 0
var _pressed_at: int = -PRESS_EVERY
var _last_signature: String = ""
var _still: int = 0
var _nickname_refused: bool = false
var _held_direction: int = PokeButton.NONE
var _let_go: int = 0


func run(r: CheckRun) -> void:
	_r = r
	Gen2SaveStore.use_root(SAVE_ROOT)
	r.each_game_of(RomRegistry.GEN1, _play)
	Gen2SaveStore.use_root("")


## Each row is [label, goal, done]; a Callable row runs as it is.
func _legs() -> Array:
	var up: int = Gen2WorldSprite.FACING_UP
	return [
		["bedroom_to_1f", _warp_to(REDS_HOUSE_1F), _on_map(REDS_HOUSE_1F)],
		["house_to_pallet", _warp_to(PALLET_TOWN), _on_map(PALLET_TOWN)],
		["north_path_to_lab", _walk(PALLET_NORTH_PATH[_r.game_id]), _on_map(OAKS_LAB)],
		["starter", _talk(LAB_STARTER_BALLS[_r.game_id], up), _flag(EVENT_GOT_STARTER)],
		["rival_and_out", _warp_to(PALLET_TOWN), _on_map(PALLET_TOWN)],
		_flag_check(EVENT_BATTLED_RIVAL_IN_OAKS_LAB, "the rival was not fought on the way out."),
		["pallet_to_home", _warp_to(REDS_HOUSE_1F), _on_map(REDS_HOUSE_1F)],
		["mom", _talk(BELOW_MOM, up), _healed()],
		["home_out", _warp_to(PALLET_TOWN), _on_map(PALLET_TOWN)],
		_grind.bind(ROUTE_1_LEVEL, 0),
		["pallet_to_route_1", _cross(Vector2i.UP, ROUTE_1), _on_map(ROUTE_1)],
		["route_1_to_viridian", _cross(Vector2i.UP, VIRIDIAN_CITY), _on_map(VIRIDIAN_CITY)],
		["viridian_mart", _warp_to(VIRIDIAN_MART), _flag(EVENT_GOT_OAKS_PARCEL)],
		["mart_out", _warp_to(VIRIDIAN_CITY), _on_map(VIRIDIAN_CITY)],
		["viridian_to_route_1", _cross(Vector2i.DOWN, ROUTE_1), _on_map(ROUTE_1)],
		["route_1_to_pallet", _cross(Vector2i.DOWN, PALLET_TOWN), _on_map(PALLET_TOWN)],
		["pallet_to_lab", _warp_to(OAKS_LAB), _on_map(OAKS_LAB)],
		["pokedex", _talk(LAB_BELOW_OAK, up), _flag(EVENT_GOT_POKEDEX)],
		["lab_out", _warp_to(PALLET_TOWN), _on_map(PALLET_TOWN)],
		["pallet_to_home_again", _warp_to(REDS_HOUSE_1F), _on_map(REDS_HOUSE_1F)],
		["mom_again", _talk(BELOW_MOM, up), _healed()],
		["home_out_again", _warp_to(PALLET_TOWN), _on_map(PALLET_TOWN)],
		["pallet_to_route_1_again", _cross(Vector2i.UP, ROUTE_1), _on_map(ROUTE_1)],
		["route_1_to_viridian_again", _cross(Vector2i.UP, VIRIDIAN_CITY), _on_map(VIRIDIAN_CITY)],
		["viridian_center", _warp_to(VIRIDIAN_POKECENTER), _on_map(VIRIDIAN_POKECENTER)],
		["nurse", _talk(BELOW_NURSE, up), _healed()],
		["center_out", _warp_to(VIRIDIAN_CITY), _on_map(VIRIDIAN_CITY)],
		_grind.bind(FOREST_LEVEL, 0),
		["viridian_to_route_2", _cross(Vector2i.UP, ROUTE_2), _on_map(ROUTE_2)],
		["route_2_to_south_gate", _warp_to(VIRIDIAN_FOREST_SOUTH_GATE), _on_map(VIRIDIAN_FOREST_SOUTH_GATE)],
		["south_gate_to_forest", _warp_to(VIRIDIAN_FOREST), _on_map(VIRIDIAN_FOREST)],
		["forest_to_north_gate", _warp_to(VIRIDIAN_FOREST_NORTH_GATE), _on_map(VIRIDIAN_FOREST_NORTH_GATE)],
		["north_gate_to_route_2", _warp_to(ROUTE_2), _on_map(ROUTE_2)],
		["route_2_to_pewter", _cross(Vector2i.UP, PEWTER_CITY), _on_map(PEWTER_CITY)],
		_grind.bind(BROCK_LEVEL, MANKEY_DEX),
		["pewter_gym", _warp_to(PEWTER_GYM), _on_map(PEWTER_GYM)],
		["brock", _talk(BELOW_BROCK, up), _flag(EVENT_BEAT_BROCK)],
		_badge_check,
		["gym_out", _warp_to(PEWTER_CITY), _on_map(PEWTER_CITY)],
	]


func _play() -> void:
	var trace: PackedStringArray = OS.get_environment("PLAYED_TRACE").split(":")
	if trace.size() == 2 and trace[0] != String(_r.game_id):
		return
	_frames = 0
	_pressed_at = -PRESS_EVERY
	_nickname_refused = false
	_held_direction = PokeButton.NONE
	_let_go = 0
	var save: Gen2SaveData = _play_intro()
	if save == null:
		return
	save.run_seed = RUN_SEED
	_screen = _open_screen(save)
	if _screen == null:
		return
	_editor = Gen2SaveEditor.new()
	_editor.data = _r.data
	_editor.save = save
	var ok: bool = true
	for row: Variant in _legs():
		ok = row.call() if row is Callable else _leg(String(row[0]), row[1], row[2])
		if not ok:
			break
	if ok:
		_r.note("gen1 played: the first badge in %d frames, %d battles" % [
			_frames, _screen.battles_fought()])
	_r.close_screen(_screen)
	_screen = null


func _flag_check(flag: int, message: String) -> Callable:
	return func() -> bool:
		return _r.check(_screen.world().event_flag_active(flag), message)


func _badge_check() -> bool:
	var state: Gen2WorldState = _screen.world().state
	return _r.check(state.is_engine_flag_active(Gen2WorldState.gen1_badge_flag(BIT_BOULDERBADGE)),
			"Brock gave no badge.") \
		and _r.check(int(state.items().get(OAKS_PARCEL, 0)) == 0
			and _screen.world().event_flag_active(EVENT_GOT_TM34), "the bag holds %s." % [state.items()])


## `NewGame` from the copyright screen through `OakSpeech` to the save it
## writes: A pressed and let go whenever the intro owes no frame, the preset
## name row taken at the keyboard.
func _play_intro() -> Gen2SaveData:
	var intro := Gen2IntroScreen.new()
	var written: Array = []
	intro.finished.connect(func(save: Gen2SaveData) -> void: written.append(save))
	intro.failed.connect(func(message: String) -> void: _r.fail("the intro failed: %s" % message))
	intro.begin(_r.data, 0, "", false)
	(Engine.get_main_loop() as SceneTree).root.add_child(intro)
	intro.set_process(false)
	var presses: int = 0
	var spent: int = 0
	_still = 0
	while written.is_empty() and spent < INTRO_FRAMES:
		if _frames - _pressed_at == HOLD_FRAMES:
			intro.release_button(PokeButton.A)
		if intro.animation_frames_left() == 0 and _frames - _pressed_at >= PRESS_EVERY:
			var screen: Control = intro.current()
			if screen != null and screen.has_method(&"choosing_name") and bool(screen.call(&"choosing_name")):
				for _row: int in PRESET_ROW:
					intro.handle_button(PokeButton.DOWN)
			intro.handle_button(PokeButton.A)
			_pressed_at = _frames
			presses += 1
		intro.advance_frames(1)
		spent += 1
		_frames += 1
		if _stalled_on(_intro_where(intro)):
			_r.fail("the intro froze after %d frames: %s" % [spent, _intro_where(intro)])
			break
	_r.check(not written.is_empty(), "the intro reached no save in %d frames and %d presses." % [spent, presses])
	(Engine.get_main_loop() as SceneTree).root.remove_child(intro)
	intro.free()
	_r.note("gen1 played: %-28s %5d frames, %d presses" % ["intro", spent, presses])
	return written[0] if not written.is_empty() else null


func _intro_where(intro: Gen2IntroScreen) -> String:
	var screen: Control = intro.current()
	if screen == null:
		return "no screen"
	var splash: Gen2SplashScreen = screen as Gen2SplashScreen
	if splash != null:
		return "splash %s frame %d" % [splash.visible_image(), (splash.get("_cinema") as Gen2BootCinema).frame()]
	var speech: Gen2OakSpeechScreen = screen as Gen2OakSpeechScreen
	if speech != null:
		var box: Gen2TextBox = speech.get("_text_box")
		return "speech %s naming=%s menu=%s" % [
			"\n".join(box.text_lines()) if box != null else "", speech.naming(), speech.choosing_name()]
	return screen.get_class()


func _open_screen(save: Gen2SaveData) -> Gen2WorldScreen:
	var screen: Gen2WorldScreen = (load("res://game/world/world_screen.tscn") as PackedScene).instantiate()
	screen.set_data(_r.data)
	screen.set_save(save)
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.set_process(false)
	if screen.world() == null:
		_r.fail("the world screen did not open on the intro's save.")
		_r.close_screen(screen)
		return null
	return screen


## Goals. Each answers the next button on an idle map, or NONE when there. A
## door mat the landing did not take is left by walking into the edge behind
## it, which `ExtraWarpCheck` answers off the facing.
func _walk(cell: Vector2i) -> Callable:
	return func(world: Gen2WorldAPI) -> int:
		if world.player_cell != cell:
			return _step_toward(world, cell, Vector2i.ZERO)
		return _warp_press(world, cell)


func _warp_press(world: Gen2WorldAPI, cell: Vector2i) -> int:
	if world.warp_at(cell).is_empty():
		return PokeButton.NONE
	for direction: Vector2i in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
		if not world.can_walk_to(cell + direction, direction) \
			and bool(world.call(&"_gen1_extra_warp_check", cell, direction)):
			return _direction_button(direction)
	return PokeButton.NONE


func _talk(cell: Vector2i, facing: int) -> Callable:
	return func(world: Gen2WorldAPI) -> int:
		if world.player_cell != cell:
			return _step_toward(world, cell, Vector2i.ZERO)
		if world.player_facing != facing:
			return _direction_button(Gen2WorldAPI.SIGHT_STEPS[facing])
		return PokeButton.A


func _cross(direction: Vector2i, map: int) -> Callable:
	return func(world: Gen2WorldAPI) -> int:
		if _crosses(world, world.player_cell, direction, map):
			return _direction_button(direction)
		return _step_toward(world, Vector2i(-1, -1), direction, map)


## The first warp onto [param map] a walk reaches: a gate's door has a wall
## cell beside it that carries the same warp.
func _warp_to(map: int) -> Callable:
	return func(world: Gen2WorldAPI) -> int:
		for warp: Dictionary in world.current_map.events.get("warps", []):
			var target: int = int(warp.get("map_number", -1))
			if (world.gen1_last_map() if target == Gen1Layout.WARP_TO_LAST_MAP else target) != map:
				continue
			var button: int = _walk(Vector2i(int(warp["x"]), int(warp["y"]))).call(world)
			if button != PokeButton.NONE:
				return button
		return PokeButton.NONE


## Predicates that end a leg.
func _on_map(map: int) -> Callable:
	return func(world: Gen2WorldAPI) -> bool:
		return world.map_id() == Vector2i(0, map)


func _flag(flag: int) -> Callable:
	return func(world: Gen2WorldAPI) -> bool:
		return world.event_flag_active(flag)


func _healed() -> Callable:
	return func(_world: Gen2WorldAPI) -> bool:
		for mon: Gen2SaveMon in _screen.active_save().party:
			if mon.hp < _editor.max_hp_for(mon) or mon.status != 0:
				return false
		return true


func _party() -> Array:
	var out: Array = []
	for mon: Gen2SaveMon in _screen.active_save().party:
		out.append("%s L%d %d/%d" % [
			_r.data.species(mon.species).get("name", mon.species), mon.level, mon.hp, _editor.max_hp_for(mon)])
	return out


## Frames spent until [param done], every one of them pressed as a player would.
func _leg(label: String, goal: Callable, done: Callable) -> bool:
	var world: Gen2WorldAPI = _screen.world()
	var spent: int = 0
	var budget: int = int(LEG_BUDGETS.get(label, LEG_FRAMES))
	_still = 0
	while spent < budget:
		if done.call(world) and _idle():
			_r.note("gen1 played: %-28s %5d frames, on map %d at %s, party %s, bag %s" % [
				label, spent, world.map_id().y, world.player_cell, _party(), world.state.items()])
			return true
		var button: int = _button_for(goal)
		if OS.get_environment("PLAYED_TRACE").ends_with(label) and spent % 4 == 0:
			print("  f%d btn=%d %s" % [spent, button, _where()])
		if button != PokeButton.NONE:
			_screen.press_button(button)
			_pressed_at = _frames
		_screen.advance_frame()
		spent += 1
		_frames += 1
		if _stalled_on(_where()):
			_r.fail("%s froze after %d frames: %s" % [label, spent, _where()])
			return false
	_r.fail("%s did not finish in %d frames: %s" % [label, budget, _where()])
	return false


func _idle() -> bool:
	var world: Gen2WorldAPI = _screen.world()
	var box: Gen2TextBox = _screen.get("_text_box")
	return _screen.get("_battle_host") == null and not _any_host() \
		and not (box != null and box.visible) and not world.script_busy() \
		and not world.scripted_movement_in_progress() and not world.gen1_movement_script_running() \
		and not world.gen1_map_load_pending() and world.pending_runtime_request().is_empty() \
		and world.pending_script_wait().is_empty() and not world.script_input_waiting() \
		and not world.player_step_in_progress() and not bool(_screen.call(&"_input_locked"))


func _any_host() -> bool:
	for name: StringName in Gen2WorldScreen.OVERLAY_HOSTS + Gen2WorldScreen.ANSWERING_HOSTS:
		if _screen.get(name) != null:
			return true
	return false


## The player's one decision a frame.
func _button_for(goal: Callable) -> int:
	var world: Gen2WorldAPI = _screen.world()
	if bool(_screen.call(&"_input_locked")):
		return PokeButton.NONE
	if _screen.get("_battle_host") != null:
		return _battle_button()
	if _screen.get("_service_host") != null:
		return _choice_button()
	if _any_host():
		return _paced(PokeButton.A)
	var box: Gen2TextBox = _screen.get("_text_box")
	if box != null and box.visible:
		return PokeButton.NONE if box.is_revealing() else _paced(PokeButton.A)
	if world.script_input_waiting():
		return _paced(PokeButton.A)
	if not _idle():
		return PokeButton.NONE
	return _let_go_between(int(goal.call(world)))


func _paced(button: int) -> int:
	return button if _frames - _pressed_at >= PRESS_EVERY else PokeButton.NONE


## `wCheckFor180DegreeTurn` is armed by a poll with nothing held, so a thumb
## moving from one direction to another leaves the pad for a pass between,
## or the new direction is a bump with the old facing kept.
func _let_go_between(button: int) -> int:
	if not PokeButton.is_direction(button):
		_held_direction = PokeButton.NONE
		return button
	if button != _held_direction and _let_go < Gen2WorldAPI.FRAMES_PER_OVERWORLD_PASS:
		_let_go += 1
		return PokeButton.NONE
	_let_go = 0
	_held_direction = button
	return button


## FIGHT, the move that hurts most, A on every box, and the first standing
## member when one has to come out.
func _battle_button() -> int:
	var host: Gen2BattleScreen = _screen.get("_battle_host")
	var snapshot: Dictionary = host.battle_snapshot()
	if not bool(snapshot.get("ready", false)):
		return PokeButton.NONE
	if StringName(snapshot.get("switch_stage", &"")) == &"pick":
		if not bool(snapshot.get("switch_forced", false)):
			return _paced(PokeButton.B)
		var cursor: int = int(snapshot.get("switch_cursor", 0))
		var party: Gen2Party = (host.get("_battle") as Gen2Battle).party(Gen2Battle.PLAYER)
		if cursor < party.mons.size() and (party.mons[cursor] as Gen2BattleMon).is_fainted():
			return _paced(PokeButton.DOWN)
	match StringName(snapshot.get("menu_stage", &"")):
		&"main":
			var position: int = int(snapshot.get("menu_position", Gen2BattleMenu.FIGHT))
			if position in [Gen2BattleMenu.PACK, Gen2BattleMenu.RUN]:
				return _paced(PokeButton.UP)
			if position == Gen2BattleMenu.PKMN:
				return _paced(PokeButton.LEFT)
		&"move":
			if int(snapshot.get("move_cursor", 0)) != _best_move_row(host.info_snapshot()):
				return _paced(PokeButton.DOWN)
	return _paced(PokeButton.A)


## The row whose power times effectiveness is highest, with PP left.
func _best_move_row(info: Dictionary) -> int:
	var best: int = 0
	var best_score: float = -1.0
	var rows: Array = info.get("move_rows", [])
	for index: int in rows.size():
		var row: Dictionary = rows[index]
		if int(row.get("pp", 0)) <= 0 or bool(row.get("disabled", false)):
			continue
		var score: float = float(_r.data.move(int(row["move"])).get("power", 0)) \
			* float(row.get("effectiveness", 0))
		if score > best_score:
			best_score = score
			best = index
	return best


## YES to everything but a nickname, which is the second row.
func _choice_button() -> int:
	var text: String = String(_screen.world().pending_script_input().get("text", ""))
	if text.contains("nickname") and not _nickname_refused:
		_nickname_refused = true
		return PokeButton.DOWN
	return _paced(PokeButton.A)


## The next step of the shortest walk to [param cell], or to any cell a step
## [param edge] from crosses onto map [param map]; NONE when there or unreachable.
func _step_toward(world: Gen2WorldAPI, cell: Vector2i, edge: Vector2i, map: int = -1) -> int:
	if world.player_cell == cell:
		return PokeButton.NONE
	var frontier: Array[Vector2i] = [world.player_cell]
	var previous: Dictionary = {world.player_cell: Vector2i.ZERO}
	var found: Vector2i = Vector2i(-1, -1)
	while not frontier.is_empty():
		var at: Vector2i = frontier.pop_front()
		if at == cell or (edge != Vector2i.ZERO and _crosses(world, at, edge, map)):
			found = at
			break
		for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = at + direction
			if previous.has(next) or world.step_blocked_from(at, direction) or not world.can_walk_to(next):
				continue
			if next != cell and (world.warp_pending(next, direction) or not world.gen1_dungeon_hole_at(next).is_empty()):
				continue
			previous[next] = direction
			frontier.append(next)
	if found.x < 0:
		return PokeButton.NONE
	var cursor: Vector2i = found
	var first: Vector2i = Vector2i.ZERO
	while cursor != world.player_cell:
		first = previous[cursor]
		cursor -= first
	return _direction_button(first)


func _crosses(world: Gen2WorldAPI, at: Vector2i, edge: Vector2i, map: int) -> bool:
	var target: Dictionary = world.connection_target(at, edge)
	return bool(target.get("ok", false)) and int(target.get("map_number", -1)) == map


func _direction_button(direction: Vector2i) -> int:
	match direction:
		Vector2i.UP: return PokeButton.UP
		Vector2i.DOWN: return PokeButton.DOWN
		Vector2i.LEFT: return PokeButton.LEFT
		Vector2i.RIGHT: return PokeButton.RIGHT
	return PokeButton.NONE


## Whether nothing observable has moved for [constant STALL_FRAMES].
func _stalled_on(signature: String) -> bool:
	if signature != _last_signature:
		_last_signature = signature
		_still = 0
		return false
	_still += 1
	return _still >= STALL_FRAMES


## The battle's own box, page by page: a win text is ten pages of one message.
func _battle_box_state(battle: Gen2BattleScreen) -> Array:
	if battle == null:
		return []
	var box: Gen2TextBox = battle.get("_box")
	var snapshot: Dictionary = battle.battle_snapshot()
	return [
		box.visible, box.is_revealing(), box.has_pages_left(), battle.frames_running(),
		snapshot.get("awaits_press"), snapshot.get("switch_stage"), snapshot.get("menu_stage"),
		battle.get("_forget_stage"),
	]


func _where() -> String:
	var world: Gen2WorldAPI = _screen.world()
	var box: Gen2TextBox = _screen.get("_text_box")
	var hosts: PackedStringArray = []
	for name: StringName in Gen2WorldScreen.OVERLAY_HOSTS + Gen2WorldScreen.ANSWERING_HOSTS:
		if _screen.get(name) != null:
			hosts.append(String(name))
	var battle: Gen2BattleScreen = _screen.get("_battle_host")
	var player: Gen2AudioPlayer = _screen.get("_audio_player")
	return JSON.stringify({
		"map": world.map_id().y, "cell": [world.player_cell.x, world.player_cell.y],
		"facing": world.player_facing,
		"box": "\n".join(box.text_lines()) if box != null and box.visible else "",
		"revealing": box != null and box.visible and box.is_revealing(),
		"hosts": hosts,
		"battle": battle.battle_snapshot().get("message", "") if battle != null else null,
		"battle_box": _battle_box_state(battle),
		"input": world.pending_script_input().get("type", ""),
		"request": world.pending_runtime_request().get("kind", ""),
		"wait": world.pending_script_wait(),
		"busy": world.script_busy(),
		"movement": world.scripted_movement_in_progress(),
		"map_script": world.gen1_map_script_state(),
		"locked": _screen.call(&"_input_locked"),
		"fade": _screen.map_fade(),
		"audio": player.audio_status().get("active_channels", []),
		"alarm": player.low_health_alarm(),
	})


## The grind a player does in the grass, written in one go: the level, the
## moves the learnset has taught by it, full health, and the catch that leads.
func _grind(level: int, caught: int) -> bool:
	var save: Gen2SaveData = _screen.active_save()
	if not _r.check(not save.party.is_empty(), "no party to grind."):
		return false
	if caught > 0:
		if not _r.check(bool(_editor.add_party_member(caught, level).get("ok", false)),
			"the party could not take %d." % caught):
			return false
		save.party.push_front(save.party.pop_back())
	for mon: Gen2SaveMon in save.party:
		_editor.set_level(mon, level)
		var known: Array = _r.data.moves_at_level(mon.species, level)
		for slot: int in Gen2SaveMon.MAX_MOVES:
			_editor.set_move(mon, slot, int(known[slot]) if slot < known.size() else Gen2SaveEditor.NO_MOVE)
		mon.hp = _editor.max_hp_for(mon)
		mon.ot_id = save.player_id
		mon.original_trainer = save.player_name
	_screen.call(&"_refresh_party_summary")
	_r.note("gen1 played: %-28s level %d, party %s" % ["grind", level, _party()])
	return true
