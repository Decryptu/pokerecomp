class_name Gen1MapScripts
extends RefCounted


const GEN1_SAFARI_RUN: String = "safari"
const GEN1_SAFARI_LABEL_RUN: String = "safari_labels"

## `EndTrainerBattle`'s `cp LOST_BATTLE`, which a catch also passes.
const GEN1_TRAINER_BEATEN: Array[StringName] = [
	Gen2WorldBattleAdapter.OUTCOME_WON, Gen2WorldBattleAdapter.OUTCOME_CAUGHT,
]

const GEN1_BATTLE_RESULTS: Dictionary = {
	Gen2WorldBattleAdapter.OUTCOME_WON: 0, Gen2WorldBattleAdapter.OUTCOME_LOST: 1,
	Gen2WorldBattleAdapter.OUTCOME_CAUGHT: 2, Gen2WorldBattleAdapter.OUTCOME_RAN: 2,
}


## `DoBoulderDustAnimation`, which `RunMapScript` reaches on every pass
## `BIT_BOULDER_DUST` stands and `BIT_SCRIPTED_NPC_MOVEMENT` does not: the
## smoke's twenty-four frames hold the map, and `SFX_CUT` follows them.
static func _gen1_boulder_dust(world: Gen2WorldAPI) -> Array:
	if world._gen1_dust_facing < 0 or world.gen1_object_movement_running():
		return []
	if world._gen1_last_boulder >= 0 and world._gen1_last_boulder < world.objects.size() \
		and (world.objects[world._gen1_last_boulder] as Gen2WorldObject).is_stepping():
		return []
	var facing: int = world._gen1_dust_facing
	world._gen1_dust_facing = -1
	var frames: int = Gen1Layout.BOULDER_DUST_STEPS * Gen1Layout.BOULDER_DUST_STEP_FRAMES
	world._gen1_steps = [Gen1FacilityScripts._gen1_wait_step(&"gen1_boulder_dust", frames, {
		"facing": facing,
		"sounds": [{"frame": frames, "gen1": true, "index": Gen1Sfx.SFX_CUT}],
	})]
	return _gen1_result(world)


## `UsedCut`'s tail: `RedrawMapView`, `AnimCut`, `SFX_CUT` and a second redraw.
static func gen1_cut_animation(world: Gen2WorldAPI, applied: Dictionary) -> Array:
	if not world._gen1 or _gen1_holding(world):
		return []
	var grass: bool = int(applied.get("animation", 0)) == Gen2WorldFieldMove.ANIMATION_GRASS
	var frames: int = Gen1Layout.cut_animation_frames(grass)
	world._gen1_steps = [_gen1_redraw_step(), Gen1FacilityScripts._gen1_wait_step(&"gen1_cut", frames, {
		"facing": world.player_facing,
		"grass": grass,
		"sounds": [{"frame": frames, "gen1": true, "index": Gen1Sfx.SFX_CUT}],
	}), _gen1_redraw_step()]
	return _gen1_result(world)


## `CheckFightingMapTrainers`: the shock bubble and `TrainerWalkUpToPlayer` in
## front of `DisplayEnemyTrainerTextAndStartBattle`, which is `TalkToTrainer`
## with BIT_SEEN_BY_TRAINER already set and so opens on the before-battle line.
static func _gen1_sight(world: Gen2WorldAPI) -> Array:
	if _gen1_holding(world):
		return []
	advance_gen1_movement_script(world)
	var dust: Array = _gen1_boulder_dust(world)
	if not dust.is_empty():
		return dust
	var ended: Array = _gen1_safari_check(world)
	if not ended.is_empty():
		return ended
	## A script that only wrote blocks holds nothing, and the trainer check follows.
	var running: Array = _gen1_map_script(world)
	if _gen1_holding(world):
		return running
	var request: Dictionary = world._find_sight_request()
	if request.is_empty():
		return running
	var event: Dictionary = request["event"]
	world._gen1_last_sprite_index = int(request["object_index"])
	var steps: Array = Gen1FacilityScripts._gen1_trainer_steps(world,
		world.current_map.text_at(int(event.get("text", 0))), event, true
	)
	if steps.is_empty():
		return running
	## `TrainerEngage` starts the piece before the bubble goes up.
	var engaged: Array = []
	Gen1FacilityScripts._gen1_engage_music(world, event, engaged)
	world._gen1_steps = engaged + [{"type": &"request", "values": {
		"kind": &"trainer_approach_requested",
		"values": {
			"object_index": int(request["object_index"]),
			"direction": request["direction"],
			"distance": int(request["distance"]),
		},
	}}] + steps
	return _gen1_joined(running, _gen1_result(world))


static func _gen1_joined(first: Array, second: Array) -> Array:
	if first.is_empty() or second.is_empty():
		return first + second
	(second[0] as Dictionary)["events"] = (first[0] as Dictionary).get("events", []) \
		+ (second[0] as Dictionary).get("events", [])
	return second


## `CheckEvent EVENT_IN_SAFARI_ZONE`, which gates the counter and the window.
static func gen1_safari_active(world: Gen2WorldAPI) -> bool:
	return world._gen1 and world.state != null \
		and world.state.is_event_flag_active(Gen1Layout.IN_SAFARI_ZONE_EVENT)


## `SafariZoneCheckSteps`: the counter is read before it is decremented.
static func gen1_count_safari_step(world: Gen2WorldAPI) -> bool:
	if not gen1_safari_active(world):
		return false
	if world.state.safari_steps() <= 0:
		world._gen1_safari_game_over = true
		return true
	world.state.set_safari_steps(world.state.safari_steps() - 1)
	return false


## `SafariZoneGameOver`, reached from `SafariZoneCheck`'s ball count as well as
## from the step counter: the box, the warp to the gate and the state it leaves.
static func _gen1_safari_check(world: Gen2WorldAPI) -> Array:
	if not gen1_safari_active(world):
		world._gen1_safari_game_over = false
		return []
	if not world._gen1_safari_game_over and world.state.safari_balls() > 0:
		return []
	world._gen1_safari_game_over = false
	var steps: Array = []
	## `SafariGameOverText`'s first line is the timer rather than the bag.
	if world.state.safari_balls() > 0:
		steps.append(_gen1_safari_box(world, "times_up"))
	steps.append(_gen1_safari_box(world, "game_over"))
	steps.append({
		"type": &"flag", "flag": Gen1Layout.SAFARI_GAME_OVER_EVENT, "set": true,
	})
	var byte: int = gen1_safari_gate_byte(world)
	if byte >= 0:
		steps.append({
			"type": &"map_script", "byte": byte,
			"value": Gen1Layout.SAFARI_SCRIPT_LEAVING,
		})
	steps.append({
		"type": &"warp_to", "map": Gen1Layout.SAFARI_ZONE_GATE_MAP,
		"warp": Gen1Layout.SAFARI_GAME_OVER_WARP,
	})
	world._gen1_steps = steps
	return _gen1_result(world)


static func _gen1_leave_safari_zone(world: Gen2WorldAPI) -> void:
	if not gen1_safari_active(world):
		return
	world.state.set_event_flag(Gen1Layout.IN_SAFARI_ZONE_EVENT, false)
	world.state.set_safari_balls(0)
	var byte: int = gen1_safari_gate_byte(world)
	if byte >= 0:
		world.state.set_gen1_map_script(byte, 0)


## `TEXT_BLACKED_OUT`'s tail: the balls, the steps, the flag and both gate bytes.
static func gen1_map_blackout(world: Gen2WorldAPI) -> void:
	if not world._gen1 or world.data == null or not Gen1Layout.poison_blackout_ends_safari(world.data.id):
		return
	_gen1_leave_safari_zone(world)
	world.state.set_safari_steps(0)
	world._gen1_saved_coord_index = 0


static func _gen1_safari_box(world: Gen2WorldAPI, name: String) -> Dictionary:
	if world.data == null:
		return {"type": &"text", "text": ""}
	var text: String = world.data.special_text(GEN1_SAFARI_RUN, name)
	if text.is_empty():
		text = world.data.special_text(GEN1_SAFARI_LABEL_RUN, name)
	return {"type": &"text", "text": Gen1ScriptNodes.gen1_filled_text(world, text)}


## `wSafariZoneGateCurScript`'s offset, read off the gate's own dispatch: it is
## the one map whose state a routine outside that map writes.
static func gen1_safari_gate_byte(world: Gen2WorldAPI) -> int:
	return _gen1_map_script_byte_of(world, Gen1Layout.SAFARI_ZONE_GATE_MAP)


static func _gen1_map_script_byte_of(world: Gen2WorldAPI, number: int) -> int:
	var map: Gen2WorldMap = world.data.world_map(0, number) if world.data != null else null
	return _gen1_dispatch_byte(world, map) if map != null else -1


## `w<Map>CurScript`'s value for the map stood on, or -1 where the map
## dispatches on none.
static func gen1_map_script_state(world: Gen2WorldAPI) -> int:
	var byte: int = _gen1_map_script_byte(world)
	return world.state.gen1_map_script(byte) if byte >= 0 and world.state != null else -1


static func _gen1_map_script_byte(world: Gen2WorldAPI) -> int:
	return _gen1_dispatch_byte(world, world.current_map) if world.current_map != null else -1


## The table sits behind whatever the entry script tests first, which is a
## branch on Pallet Town, Oak's Lab and Viridian Mart, so every arm is walked.
static func _gen1_dispatch_byte(world: Gen2WorldAPI, map: Gen2WorldMap) -> int:
	return _gen1_dispatch_byte_in(world, map.scripts.get("entry", []) as Array)


static func _gen1_dispatch_byte_in(world: Gen2WorldAPI, nodes: Array) -> int:
	for node: Dictionary in nodes:
		if String(node.get("op", "")) == "map_script_table":
			return int(node["byte"])
		for key: String in Gen1Layout.SCRIPT_BRANCH_KEYS:
			if node.has(key):
				var byte: int = _gen1_dispatch_byte_in(world, node[key] as Array)
				if byte >= 0:
					return byte
	return -1


static func _gen1_map_state_nodes(world: Gen2WorldAPI, index: int) -> Array:
	for row: Dictionary in world.current_map.scripts.get("states", []) as Array:
		if int(row.get("id", -1)) == index:
			return row.get("nodes", []) as Array
	return []


## `RunMapScript`, which `JoypadOverworld` runs every frame: what stands in
## front of `CallFunctionInTable` and then the state the map's byte selects.
static func _gen1_map_script(world: Gen2WorldAPI) -> Array:
	if world.current_map == null or world.state == null:
		return []
	if not world._gen1_entry_steps.is_empty():
		world._gen1_steps = world._gen1_entry_steps
		world._gen1_entry_steps = []
		return _gen1_result(world)
	var entry: Array = world._gen1_map_script_nodes(world._gen1_map_load_pending)
	world._gen1_map_load_pending = 0
	if entry.is_empty():
		return []
	var steps: Array = []
	if not Gen1ScriptNodes._gen1_resolve_script(world, entry, steps, Gen1ScriptNodes._gen1_run(world, {})) or steps.is_empty():
		return []
	world._gen1_steps = steps
	return _gen1_result(world)


## Whether a Generation 1 interaction is still standing in front of the map.
static func _gen1_holding(world: Gen2WorldAPI) -> bool:
	return not world._gen1_steps.is_empty()


static func _gen1_step(world: Gen2WorldAPI, type: StringName) -> Dictionary:
	if world._gen1_steps.is_empty():
		return {}
	var step: Dictionary = world._gen1_steps[0]
	return step if StringName(step.get("type", &"")) == type else {}


## The result the head step is waiting on, empty once the list is spent. What a
## row writes takes no turn of its own and is spent on the way past, and the
## balance window one of those draws rides on the result behind it.
static func _gen1_result(world: Gen2WorldAPI) -> Array:
	_gen1_battle_last(world)
	var events: Array = []
	while not world._gen1_steps.is_empty() and _gen1_written(world, world._gen1_steps[0], events, world._gen1_steps):
		world._gen1_steps.pop_front()
	if world._gen1_steps.is_empty():
		_gen1_close_money_window(world, events)
		return [] if events.is_empty() \
			else [{"ok": true, "status": &"done", "events": events}]
	_gen1_stand_sprites_still(world)
	var result: Dictionary = _gen1_waiting_result(world, world._gen1_steps[0])
	result["events"] = events + (result.get("events", []) as Array)
	return [result]


## `DisplayTextIDInit`'s `.spriteStandStillLoop`: `and $fc` on every image
## index, the counter behind it untouched.
static func _gen1_stand_sprites_still(world: Gen2WorldAPI) -> void:
	for object: Gen2WorldObject in world.objects:
		if object.active and not object.deleted and object.is_stepping():
			object.frame = 0


## `OverworldLoop` reads `wCurOpponent` once the script has returned, so the
## rest of a row stands in front of its battle: Yellow's initial catch training
## sets its event behind the store and the throw reads it.
static func _gen1_battle_last(world: Gen2WorldAPI) -> void:
	var battles: Array = []
	var rest: Array = []
	for step: Dictionary in world._gen1_steps:
		var request: Dictionary = step.get("values", {}) if step.get("type", &"") == &"request" else {}
		(battles if StringName(request.get("kind", &"")) == &"battle_requested" else rest).append(step)
	if not battles.is_empty() and not rest.is_empty():
		world._gen1_steps = rest + battles


## `ReadTrainer` reads `wLoneAttackNo` and `wRivalStarter` as they stand when
## the fight opens: a gym's row writes the byte behind `InitBattleEnemyParameters`.
static func _gen1_stamped_request(world: Gen2WorldAPI, request: Dictionary) -> Dictionary:
	if StringName(request.get("kind", &"")) != &"battle_requested":
		return request.duplicate(true)
	var values: Variant = request.get("values", {})
	if not values is Dictionary or StringName((values as Dictionary).get("kind", &"")) != &"trainer":
		return request.duplicate(true)
	var stamped: Dictionary = request.duplicate(true)
	var stamped_values: Dictionary = stamped["values"]
	stamped_values["lone_attack"] = int(world._gen1_volatile.get("gym_leader", 0))
	stamped_values["rival_starter"] = world.state.gen1_starter("rival") if world.state != null else 0
	return stamped


## `SetLastBlackoutMap`, whose whole body is the rest-house list: healing in one
## of the Safari Zone's three leaves the map a blackout lands on where it was.
static func _gen1_record_blackout_map(world: Gen2WorldAPI) -> void:
	if world.current_map == null or world.data == null \
		or world.data.gen1_special_warp_list("rest_houses").has(world.current_map.number):
		return
	world._gen1_last_blackout_map = world._gen1_last_map


## `AfterDisplayingTextID` redraws the map behind the row, which takes a balance
## window down the way `closetext`'s redraw takes Generation 2's.
static func _gen1_close_money_window(world: Gen2WorldAPI, events: Array) -> void:
	if not world._gen1_money_window:
		return
	world._gen1_money_window = false
	events.append({"type": &"text_closed"})


static func _gen1_waiting_result(world: Gen2WorldAPI, step: Dictionary) -> Dictionary:
	var type: StringName = StringName(step["type"])
	if type == &"request":
		return {
			"ok": true, "status": &"waiting",
			"event": {"type": &"runtime_request", "request": _gen1_stamped_request(world, step["values"])},
		}
	if type == &"choice":
		return {"ok": true, "status": &"waiting", "event": {"type": &"choice"}}
	## `WaitForTextScrollButtonPress`; `arrow` is a printed box's blinking one.
	if type == &"button":
		return {
			"ok": true, "status": &"waiting", "event": {
				"type": &"button", "box": false, "arrow": bool(step.get("arrow", false)),
			},
			"events": (step.get("events", []) as Array).duplicate(true),
		}
	## A counted wait and whatever it starts on the frame it opens on.
	if type == &"wait":
		return {
			"ok": true, "status": &"waiting",
			"event": (step["values"] as Dictionary).duplicate(true),
			"events": (step.get("events", []) as Array).duplicate(true),
		}
	## `AfterDisplayingTextID` ends every box on `WaitForTextScrollButtonPress`
	## unless the row set `wDoNotWaitForButtonPress...` before its last one.
	return {
		"ok": true, "status": &"waiting",
		"event": {
			"type": &"text",
			"text": String(step["text"]),
			"prompt": bool(step.get("press", true)),
		},
	}


## [param steps] is the list [param step] heads, which an in-view block queues onto.
static func _gen1_written(world: Gen2WorldAPI, step: Dictionary, events: Array, steps: Array) -> bool:
	match StringName(step["type"]):
		&"money":
			world.state.apply_changes({}, {}, {
				"money": {Gen2WorldMartHost.MONEY_ACCOUNT: int(step["amount"])},
			})
			return true
		&"coins":
			world.state.apply_changes({}, {}, {"coins": int(step["amount"])})
			return true
		&"money_box":
			world._gen1_money_window = true
			events.append({
				"type": &"money_window_opened",
				"kind": StringName(step.get("kind", &"money_top_right")),
				"money": world.state.money(Gen2WorldMartHost.MONEY_ACCOUNT) if world.state != null else 0,
				"coins": world.state.coins() if world.state != null else 0,
			})
			return true
		&"flag":
			if bool(step.get("engine", false)):
				world.state.set_engine_flag(int(step["flag"]), bool(step["set"]))
			else:
				world.state.set_event_flag(int(step["flag"]), bool(step["set"]))
			return true
		&"items":
			world.state.apply_changes({}, {}, {"items": step["items"]})
			return true
		&"fossil":
			world.gen1_fossil[String(step["which"])] = int(step["value"])
			return true
		&"toggle":
			gen1_toggle_object(world, int(step["index"]), bool(step["hidden"]))
			return true
		&"drop_last_warp":
			world._gen1_warps_dropped += 1
			return true
		## `SetLastBlackoutMap` names the map a script wrote; the nurse's own
		## step carries none and takes `wLastMap` instead.
		&"blackout_map":
			if step.has("map"):
				world._gen1_last_blackout_map = int(step["map"])
			else:
				_gen1_record_blackout_map(world)
			return true
		&"map_script":
			world.state.set_gen1_map_script(int(step["byte"]), int(step["value"]))
			return true
		&"saved_coord_index":
			world._gen1_saved_coord_index = int(step["value"])
			return true
		&"last_map":
			world._gen1_last_map = int(step["map"])
			return true
		&"safari_balls":
			world.state.set_safari_balls(int(step["count"]))
			return true
		&"safari_steps":
			world.state.set_safari_steps(int(step["steps"]))
			return true
		&"starter":
			_gen1_record_starter(world, step)
			return true
	return _gen1_linked(world, step, events, steps)


static func _gen1_record_starter(world: Gen2WorldAPI, step: Dictionary) -> void:
	world.state.set_gen1_starter(String(step["who"]), int(step["value"]))
	if String(step["who"]) == "player":
		world.state.apply_changes({}, {}, {"starter_species": world.data.gen1_dex_of_index(int(step["value"]))})


## The rest of [method _gen1_written]: what the cable club writes.
static func _gen1_linked(world: Gen2WorldAPI, step: Dictionary, events: Array, steps: Array) -> bool:
	match StringName(step["type"]):
		&"link_state":
			world.state.link_session().gen1_link_state = int(step["value"])
			return true
		&"link_connected":
			world.state.link_session().gen1_link_connected = bool(step["set"])
			return true
		&"special_warp":
			var warped: Dictionary = Gen1FacilityScripts._gen1_special_warp(world, String(step["name"]))
			if not warped.is_empty():
				events.append(warped)
			return true
		&"cable_club_return":
			events.append_array(Gen1FacilityScripts.gen1_return_to_cable_club_room(world))
			return true
		&"cup_menu":
			var cup: Array = Gen1FacilityScripts._gen1_cup_menu_steps(world)
			for index: int in cup.size():
				steps.insert(1 + index, cup[index])
			return true
		&"stadium_cup":
			world.state.link_session().gen1_stadium_cup = int(step["cup"])
			return true
	return _gen1_kept(world, step, events, steps)


## The rest of [method _gen1_written]: what a row leaves behind it.
static func _gen1_kept(world: Gen2WorldAPI, step: Dictionary, events: Array, steps: Array) -> bool:
	match StringName(step["type"]):
		&"scratch":
			world._gen1_scratch[int(step["address"])] = int(step["value"])
			return true
		&"volatile":
			## The byte itself, `wGymLeaderNo` being `wLoneAttackNo` too.
			world._gen1_volatile[String(step["name"])] = int(step.get("value", 1 if bool(step["set"]) else 0))
			return true
		&"map_load":
			world._gen1_map_load_pending |= 1 << int(step["bit"])
			return true
		&"byte":
			world.state.set_gen1_byte(String(step["name"]), int(step["value"]))
			return true
		&"pikachu":
			_gen1_pikachu_written(world, String(step["what"]), step["value"])
			return true
		&"pikachu_movement":
			if world.pikachu != null:
				world.pikachu.start_movement(step["bytes"], bool(step["refresh"]))
			return true
		&"text_table":
			world._gen1_text_table = int(step["table"])
			return true
		&"npc_movement_script":
			_gen1_start_movement_script(world, int(step["table"]), int(step["object"]))
			return true
		&"npc_trade":
			world.state.apply_changes({}, {}, {"npc_trades": {int(step["trade_id"]): true}})
			return true
		&"event":
			events.append((step["event"] as Dictionary).duplicate(true))
			return true
		&"wait":
			## A `WaitForSoundToFinish` with no driver to ask ends where it starts.
			if not bool((step["values"] as Dictionary).get("until_sound", false)) \
					or world.sound_playing.is_valid() or world.channel_playing.is_valid():
				return false
			events.append_array((step.get("events", []) as Array).duplicate(true))
			return true
	return _gen1_drawn(world, step, events, steps)


## The rest of [method _gen1_written]: what a row moves or redraws.
static func _gen1_drawn(world: Gen2WorldAPI, step: Dictionary, events: Array, steps: Array) -> bool:
	match StringName(step["type"]):
		&"object_facing":
			world._gen1_last_sprite_index = int(step["index"])
			_turn_gen1_object(world, int(step["index"]), int(step["facing"]), events)
			return true
		&"player_coord":
			if int(step["axis"]) == 0:
				world.player_cell.y = int(step["value"])
			else:
				world.player_cell.x = int(step["value"])
			return true
		&"emote":
			_gen1_show_emote(world, int(step["object"]), int(step["kind"]))
			return true
		&"object_path":
			world._gen1_last_sprite_index = int(step["index"])
			events.append_array(_gen1_walk_object(world,
				int(step["index"]), _gen1_path_to_player(world, step)
			))
			return true
		&"warp_to":
			events.append(_gen1_warp_to(world, int(step["map"]), int(step["warp"])))
			return true
		&"object_position", &"object_position_save", &"object_position_restore":
			_gen1_object_position_step(world, step)
			return true
		&"walk":
			events.append_array(_gen1_walk_player(world, step["moves"] as Array))
			if bool(step.get("spinner", false)) and world.gen1_player_movement_running():
				world._gen1_spinning = true
				world._gen1_spin_facing = world.player_facing
			return true
		&"object_move":
			world._gen1_last_sprite_index = int(step["index"])
			events.append_array(_gen1_walk_object(world,
				int(step["index"]), step["moves"] as Array
			))
			return true
		&"object_stay":
			world._gen1_last_sprite_index = int(step["index"])
			_gen1_stand_object(world, int(step["index"]))
			return true
		&"player_facing":
			world.player_facing = int(step["facing"])
			return true
		&"riding":
			world.set_movement_mode(StringName(step["mode"]))
			return true
		&"erase_rows":
			world.erase_screen_rows(int(step["first_row"]), int(step["rows"]), int(step["tile"]))
			return true
		&"block":
			_gen1_block_written(world, step, events, steps)
			return true
	return false


## `PrintCardKeyText` writes `wCardKeyDoorY` and its neighbour behind the box,
## so the floor's own callback can flag the door next load.
static func _gen1_block_written(world: Gen2WorldAPI, step: Dictionary, events: Array, steps: Array) -> void:
	if bool(step.get("card_key", false)) and world.state != null:
		world.state.set_card_key_door(Vector2i(int(step["x"]), int(step["y"])))
	var changed: Dictionary = world.change_block(int(step["x"]), int(step["y"]), int(step["block"]))
	if not bool(changed.get("ok", false)):
		return
	events.append(changed)
	if bool(step.get("redraw", true)) and _gen1_block_in_view(world, int(step["x"]), int(step["y"])):
		steps.insert(1, _gen1_redraw_step())


static func _gen1_redraw_step() -> Dictionary:
	return Gen1FacilityScripts._gen1_wait_step(&"gen1_redraw", Gen1Layout.REDRAW_MAP_VIEW_FRAMES)


## `ReplaceTileBlock` redraws when the block's padded address lies within four
## rows plus six blocks of `wCurrentTileBlockMapViewPointer`, compared linearly.
static func _gen1_block_in_view(world: Gen2WorldAPI, block_x: int, block_y: int) -> bool:
	if world.current_map == null:
		return false
	var stride: int = world.current_map.width_blocks + Gen1Layout.MAP_BORDER_BLOCKS * 2
	var offset: int = (block_y - (world.player_cell.y >> 1) + 2) * stride \
		+ block_x - (world.player_cell.x >> 1) + 2
	return offset >= 0 and offset < 4 * stride + 6


## The follower's routines a row calls and an emotion's own commands; Red and
## Blue have nothing to write.
static func _gen1_pikachu_written(world: Gen2WorldAPI, what: String, value: Variant) -> void:
	if world.pikachu == null:
		return
	match what:
		"following":
			world.pikachu.set_following(bool(value))
		"drawing":
			world.pikachu.set_drawing(bool(value))
		"spawn_state":
			world.pikachu.spawn_state = int(value)
		"schedule_spawn":
			world.pikachu.schedule_after_map_load(world.gen1_pikachu_view(false))
		"emote":
			world.pikachu.show_emote(int(value))
		"turn_away":
			world.pikachu.face_away_from(world.gen1_player_facing())
		"face":
			world.pikachu.pose(int(value))


## `PIKACHU_SPRITE_INDEX` is slot fifteen, past any map's own objects.
static func _gen1_show_emote(world: Gen2WorldAPI, index: int, kind: int) -> void:
	if index < 0:
		world.set_player_emote(kind, true, Gen1Layout.EMOTE_FRAMES)
	elif index == Gen1Pikachu.SPRITE_INDEX - 1 and world.pikachu != null:
		world.pikachu.show_emote(kind)
	elif index < world.objects.size():
		(world.objects[index] as Gen2WorldObject).set_emote(kind, true, Gen1Layout.EMOTE_FRAMES)


## `FindPathToPlayer`: greater axis first, `hNPCPlayerYDistance` moved by the caller.
static func _gen1_path_to_player(world: Gen2WorldAPI, step: Dictionary) -> Array:
	var target: int = int(step["target"])
	if target < 0 or target >= world.objects.size():
		return []
	var from: Vector2i = (world.objects[target] as Gen2WorldObject).cell
	## BIT_PLAYER_LOWER_Y is set when the object is north of the player, and
	## the perspective byte complements both bits before the path is read.
	var lower_y: bool = from.y < world.player_cell.y
	var lower_x: bool = from.x < world.player_cell.x
	if int(step["perspective"]) != 0:
		lower_y = not lower_y
		lower_x = not lower_x
	var dy: int = absi(world.player_cell.y - from.y) + int(step["y_adjust"])
	var dx: int = absi(world.player_cell.x - from.x)
	var moves: Array = []
	var walked_y: int = 0
	var walked_x: int = 0
	while moves.size() < Gen1Layout.NPC_MOVEMENT_MAX:
		var left_y: int = absi(dy - walked_y)
		var left_x: int = absi(dx - walked_x)
		if left_y == 0 and left_x == 0:
			break
		if left_x > left_y:
			moves.append(Gen1Layout.MOVE_LEFT if lower_x else Gen1Layout.MOVE_RIGHT)
			walked_x += 1
		else:
			moves.append(Gen1Layout.MOVE_UP if lower_y else Gen1Layout.MOVE_DOWN)
			walked_y += 1
	return moves


static func _gen1_warp_to(world: Gen2WorldAPI, map_number: int, warp: int) -> Dictionary:
	var target_map: Gen2WorldMap = world.data.world_map(0, map_number) if world.data != null else null
	if target_map == null:
		return {}
	## `LoadDestinationWarpPosition` reaches the row with `add a / add a`, so
	## `wDestinationWarpID` counts from zero as a `warp_event`'s `\4 - 1` does.
	var warps: Array = target_map.events.get("warps", [])
	if warp < 0 or warp >= warps.size():
		return {}
	var row: Dictionary = warps[warp]
	var from_map: Vector2i = world.map_id()
	var rest: Array = world._gen1_steps  ## The state's own steps behind the warp still stand.
	world._apply_map(
		target_map, world.data.world_tileset(target_map.tileset),
		Vector2i(int(row["x"]), int(row["y"])), true, 0, Gen2WorldAPI.MAP_ENTRY_DOOR
	)
	world._gen1_steps = rest
	return {"type": &"warp", "from_map": from_map, "to_map": world.map_id(), "to_cell": world.player_cell}


static func _gen1_object_position_step(world: Gen2WorldAPI, step: Dictionary) -> void:
	var index: int = int(step["index"])
	var type: StringName = StringName(step["type"])
	if type == &"object_position":
		_gen1_place_object(world, index, String(step["axis"]), int(step["value"]))
	elif index < 0 or index >= world.objects.size():
		return
	elif type == &"object_position_save":
		world._gen1_saved_object_position = {"index": index, "cell": world.objects[index].cell}
	elif int(world._gen1_saved_object_position.get("index", -1)) == index:
		var cell: Vector2i = world._gen1_saved_object_position["cell"]
		_gen1_place_object(world, index, "y", cell.y)
		_gen1_place_object(world, index, "x", cell.x)


static func _gen1_place_object(world: Gen2WorldAPI, index: int, axis: String, value: int) -> void:
	if index < 0 or index >= world.objects.size():
		return
	var object: Gen2WorldObject = world.objects[index]
	if axis == "y":
		object.cell.y = value
	else:
		object.cell.x = value
	world._remember_object_position(object)


static func _gen1_start_movement_script(world: Gen2WorldAPI, table: int, object: int) -> void:
	world._gen1_movement_script = {
		"table": table, "object": object, "function": 0, "steps": 0,
		"toggle_index": _gen1_toggle_index(world, object),
	}


static func gen1_movement_script_running(world: Gen2WorldAPI) -> bool:
	return not world._gen1_movement_script.is_empty()


static func advance_gen1_movement_script(world: Gen2WorldAPI) -> Array:
	if world._gen1_movement_script.is_empty() or world.current_map == null:
		return []
	var events: Array = []
	var table: int = int(world._gen1_movement_script["table"])
	var function: int = int(world._gen1_movement_script["function"])
	if table == Gen1Layout.MOVEMENT_SCRIPT_PALLET:
		_gen1_pallet_movement(world, function, events)
	else:
		_gen1_pewter_movement(world, table, function, events)
	return events


static func _gen1_movement_lists(world: Gen2WorldAPI, table: int) -> Dictionary:
	return world.current_map.movement_scripts.get(table, {}) if world.current_map != null else {}


static func _gen1_pallet_movement(world: Gen2WorldAPI, function: int, events: Array) -> void:
	var object: int = int(world._gen1_movement_script["object"])
	match function:
		0:
			var steps: int = world.player_cell.x - Gen1Layout.PALLET_PATH_LEFT_COLUMN
			world._gen1_movement_script["steps"] = steps
			if steps == 0:
				world._gen1_movement_script["function"] = 3
				return
			var moves: Array = []
			moves.resize(steps)
			moves.fill(Gen1Layout.MOVE_LEFT)
			events.append_array(_gen1_walk_object(world, object, moves))
			world._gen1_movement_script["function"] = 1
		1:
			if world.gen1_object_movement_running():
				return
			events.append_array(_gen1_walk_player(world, [
				{"direction": Gen1Layout.MOVE_LEFT, "steps": int(world._gen1_movement_script["steps"])},
			]))
			world._gen1_movement_script["function"] = 2
		2, 3:
			if function == 2 and world.gen1_player_movement_running():
				return
			var lists: Dictionary = _gen1_movement_lists(world, Gen1Layout.MOVEMENT_SCRIPT_PALLET)
			events.append_array(_gen1_walk_player(world, lists.get("player", [])))
			events.append_array(_gen1_walk_object(world, object, lists.get("object", [])))
			world._gen1_movement_script["function"] = 4
		4:
			if world.gen1_player_movement_running():
				return
			gen1_toggle_object(world, int(world._gen1_movement_script["toggle_index"]), true)
			world._gen1_movement_script = {}


## `PewterGuys` writes the player's row over the last press `DecodeRLEList` wrote.
static func _gen1_pewter_movement(world: Gen2WorldAPI, table: int, function: int, events: Array) -> void:
	if function == 0:
		var lists: Dictionary = _gen1_movement_lists(world, table)
		var walk: Array = (lists.get("player", []) as Array).duplicate(true)
		for row: Dictionary in lists.get("approaches", []):
			if int(row["y"]) != world.player_cell.y or int(row["x"]) != world.player_cell.x:
				continue
			if not walk.is_empty():
				(walk[0] as Dictionary)["steps"] = int((walk[0] as Dictionary)["steps"]) - 1
			walk = (row["presses"] as Array) + walk
			break
		events.append_array(_gen1_walk_player(world, walk))
		events.append_array(_gen1_walk_object(world,
			int(world._gen1_movement_script["object"]), lists.get("object", [])
		))
		world._gen1_movement_script["function"] = 1
	elif not world.gen1_player_movement_running():
		world._gen1_movement_script = {}


## The override the next object load reads, and the object standing now.
static func _turn_gen1_object(world: Gen2WorldAPI, index: int, facing: int, events: Array) -> void:
	if world.current_map == null or index < 0 or index >= world.objects.size():
		return
	world._apply_object_override(&"object_facing", {
		"map_group": world.current_map.group, "map_number": world.current_map.number,
		"object_index": index, "facing": facing,
	})
	(world.objects[index] as Gen2WorldObject).facing = facing
	events.append({"type": &"object_turned", "object_index": index, "facing": facing})


## Spends the head step and answers with whatever the next one waits on.
## [param choice] is the row a YES/NO was answered with.
static func _gen1_advance(world: Gen2WorldAPI, choice: int, result: Dictionary = {}) -> Array:
	var step: Dictionary = world._gen1_steps.pop_front()
	if StringName(step.get("type", &"")) == &"choice":
		var branch: Array = step.get("yes" if choice == 0 else "no", [])
		world._gen1_steps = branch.duplicate(true) + world._gen1_steps
	elif step.has("trade"):
		world._gen1_steps = Gen1FacilityScripts._gen1_trade_after_selection(world, step, result) + world._gen1_steps
	elif step.has("day_care"):
		world._gen1_steps = Gen1FacilityScripts._gen1_day_care_after_selection(world, result) + world._gen1_steps
	elif step.has("cry_after"):
		world._gen1_steps = Gen1FacilityScripts._gen1_cry_after(world, step, result) + world._gen1_steps
	elif step.has("elevator"):
		_gen1_ride_elevator(world, result)
	elif step.has("slot_machine") and result.has("coins"):
		world._gen1_steps.push_front({"type": &"coins", "amount": int(result["coins"])})
	elif step.has("surfing") and result.has("hi_score"):
		Gen1ScriptNodes.set_gen1_surf_hi_score(world, int(result["hi_score"]))
	elif step.has("replies") or step.has("pokedex") or step.has("list_menu"):
		world._gen1_steps = _gen1_menu_answered(step, int(result.get("row", -1))) + world._gen1_steps
	elif step.has("answers"):
		var answers: Array = step["answers"]
		var row: int = int(result.get("row", -1))
		if row < 0 or row >= answers.size() - 1:
			row = answers.size() - 1
		world._gen1_steps = (answers[row] as Array).duplicate(true) + world._gen1_steps
	elif step.has("later"):
		world._gen1_steps = _gen1_resolve_later(world, step, result) + world._gen1_steps
	elif step.has("ok"):
		## `accepted` is the carry `_GivePokemon` answers in.
		world._gen1_steps = (step[
			"ok" if bool(result.get("accepted", false)) else "full"
		] as Array).duplicate(true) + world._gen1_steps
	_gen1_battle_won(world, step, result)
	return _gen1_result(world)


static func _gen1_menu_answered(step: Dictionary, chosen: int) -> Array:
	if step.has("replies") or step.has("pokedex"):
		var replies: Array = step.get("replies", step.get("pokedex", []))
		## The cache's numbers are floats, which `Array.has` tells from an int.
		if chosen < 0 or chosen >= replies.size() or _gen1_row_named(step["quit"], chosen):
			return []
		if step.has("pokedex"):
			return [{"type": &"request", "values": {
				"kind": &"pokedex_entry_requested",
				"values": {"species": int(replies[chosen])},
			}}, step]
		return [{"type": &"text", "text": String(replies[chosen])}, step]
	var listed: Array = step["rows"]
	if chosen < 0 or chosen >= listed.size():
		return (step["done"] as Array).duplicate(true)
	return [{"type": &"text", "text": String((listed[chosen] as Dictionary)["text"])}, step]


static func _gen1_row_named(rows: Array, row: int) -> bool:
	for named: Variant in rows:
		if int(named) == row:
			return true
	return false


## The side a staged request came back on, with its answer on the run.
static func _gen1_resolve_later(world: Gen2WorldAPI, step: Dictionary, result: Dictionary) -> Array:
	var run: Dictionary = (step.get("run", {}) as Dictionary).duplicate(true)
	var cancelled: bool = true
	if StringName(step.get("answer", &"")) == &"printed":
		cancelled = not bool(result.get("printed", false))
	elif StringName(step.get("answer", &"")) == &"party_index":
		cancelled = int(result.get("party_index", -1)) < 0
		if not cancelled:
			run["party"] = {
				"index": int(result["party_index"]),
				"nickname": String(result.get("nickname", "")),
				"ot_id": int(result.get("ot_id", -1)),
				"original_trainer": String(result.get("original_trainer", "")),
			}
	else:
		var entered: String = String(result.get("name", ""))
		cancelled = entered.is_empty()
		if not cancelled:
			var buffers: Dictionary = run.get("buffers", {})
			buffers[int((step["values"]["values"] as Dictionary)["buffer"])] = entered
			run["buffers"] = buffers
	var steps: Array = []
	var nodes: Array = (step["later"] as Dictionary)["then" if cancelled else "else"]
	return steps if Gen1ScriptNodes._gen1_resolve_script(world, nodes, steps, run) else []


static func _gen1_ride_elevator(world: Gen2WorldAPI, result: Dictionary) -> void:
	var floor_row: Variant = result.get("floor", null)
	if not floor_row is Dictionary:
		return
	world._gen1_warp_entry = {
		"warp": int((floor_row as Dictionary)["warp"]),
		"map": int((floor_row as Dictionary)["map"]),
	}
	world._gen1_steps.push_front(Gen1FacilityScripts._gen1_wait_step(&"gen1_elevator_shake", Gen1Layout.ELEVATOR_SHAKE_FRAMES, {"shake": true}
	))


## `EndTrainerBattle` flags a beaten opponent, and its `cp OPP_ID_OFFSET` skips
## `HideObject` for a trainer, so only a standing wild goes off the map. It sets
## both map-load bits, and `StartTrainerBattle` left the map's script on row 2.
static func _gen1_battle_won(world: Gen2WorldAPI, step: Dictionary, result: Dictionary) -> void:
	if result.has("outcome"):
		world._gen1_battle_outcome = StringName(result["outcome"])
		world._gen1_battle_result = int(result.get(
			"battle_result", GEN1_BATTLE_RESULTS.get(world._gen1_battle_outcome, 0)
		))
	var flag: int = int(step.get("trainer_flag", -1))
	if flag < 0 or world.state == null or not result.has("outcome"):
		return
	world._gen1_map_load_pending = Gen1Layout.MAP_LOAD_BOTH
	var byte: int = _gen1_map_script_byte(world)
	if byte >= 0 and not _gen1_map_state_nodes(world, Gen2WorldAPI.GEN1_END_BATTLE_STATE).is_empty():
		world.state.set_gen1_map_script(byte, Gen2WorldAPI.GEN1_END_BATTLE_STATE)
	if StringName(result.get("outcome", &"")) not in GEN1_TRAINER_BEATEN:
		return
	world.state.set_event_flag(flag)
	if bool(step.get("standing_wild", false)):
		gen1_toggle_object(world, _gen1_toggle_index(world, int(step.get("object_index", -1))), true)
	world.load_object_masks()
	var ending: Array = []  ## `TextCommand_ASM` behind the end-battle line the fight printed.
	for node: Dictionary in step.get("end_script", []) as Array:
		if String(node.get("op", "")) != "text":
			ending.append(node)
	var steps: Array = []
	if not ending.is_empty() and Gen1ScriptNodes._gen1_resolve_script(world, ending, steps, Gen1ScriptNodes._gen1_run(world, {})):
		world._gen1_steps = steps + world._gen1_steps


## `CollisionCheckOnLand` skips every test while `wSimulatedJoypadStatesIndex`
## stands, so only the map bounds refuse.
static func _gen1_walk_player(world: Gen2WorldAPI, moves: Array) -> Array:
	var generated: Array = []
	for leg: Dictionary in moves:
		if int(leg["direction"]) == Gen1Layout.MOVE_NONE:
			for _pass: int in int(leg["steps"]):
				world._queue_player_step(Vector2i.ZERO, 1, false, Vector2i.ZERO, Gen2WorldAPI.STEP_KIND_WALK)
			continue
		var direction: Vector2i = world.movement_direction(int(leg["direction"]))
		for _step: int in int(leg["steps"]):
			var destination: Vector2i = world.player_cell + direction
			if not world._cell_in_bounds(destination):
				world._queue_player_step(Vector2i.ZERO, 0, false, direction, Gen2WorldAPI.STEP_KIND_WALK)
				generated.append({
					"type": &"movement_blocked", "player": true, "cell": destination,
				})
				return generated
			world.player_cell = destination
			world._queue_player_step(
				direction, Gen2WorldAPI.STEP_PASSES_WALK, false, direction, Gen2WorldAPI.STEP_KIND_WALK
			)
	return generated


## `MoveSprite`, whose whole list is queued here and drawn a step at a time by
## [method advance_scripted_steps_pass]. `CanWalkOntoTile` allows a scripted step
## outright, so only the map bounds refuse one.
static func _gen1_walk_object(world: Gen2WorldAPI, index: int, moves: Array) -> Array:
	var generated: Array = []
	if world.current_map == null or index < 0 or index >= world.objects.size():
		return generated
	var object: Gen2WorldObject = world.objects[index]
	_gen1_stand_object(world, index)
	var facing: int = object.facing
	for row: int in moves:
		var direction: Vector2i = world.movement_direction(row)
		facing = world.facing_for_direction(direction)
		var destination: Vector2i = object.cell + direction
		if not world._cell_in_bounds(destination):
			## `NormalStep` writes the facing before `GetNextTile` refuses, so a
			## step off the map turns the object where it stands.
			object.queue_step(Vector2i.ZERO, 0, false, direction)
			generated.append({
				"type": &"movement_blocked", "object_index": index, "cell": destination,
			})
			continue
		var vacated: Vector2i = object.cell
		object.cell = destination
		var passes: int = Gen2WorldAPI.STEP_PASSES_FAST if row >= Gen1Layout.NPC_RUN_FIRST else Gen2WorldAPI.STEP_PASSES_WALK
		object.queue_step(direction, passes, false, direction, Gen2WorldAPI.STEP_KIND_WALK)
		world._advance_followers(index, vacated)
	var key: String = world._object_key(world.current_map.group, world.current_map.number, index)
	world._object_position_overrides[key] = object.cell
	world._object_facing_overrides[key] = facing
	return generated


## `SetSpriteMovementBytesToFF`: STAY over movement byte 1 and NONE over byte 2,
## WRAM the next map load fills from `wMapSpriteData`, so nothing is recorded.
static func _gen1_stand_object(world: Gen2WorldAPI, index: int) -> void:
	if index < 0 or index >= world.objects.size():
		return
	(world.objects[index] as Gen2WorldObject).movement = Gen1Layout.object_movement(
		Gen1Layout.OBJECT_MOVEMENT_STAY, Gen1Layout.OBJECT_MOVEMENT_NONE
	)


## `ShowObject` and `HideObject`: one `wToggleableObjectFlags` bit by global
## index, and `UpdateSprites` behind it.
static func gen1_toggle_object(world: Gen2WorldAPI, index: int, hidden: bool) -> void:
	if index < 0 or world.state == null or world.data == null:
		return
	world.state.set_object_toggled(index, hidden == world.data.gen1_toggle_on(index))
	world.load_object_masks()


static func _gen1_toggle_index(world: Gen2WorldAPI, object_index: int) -> int:
	if object_index < 0 or object_index >= world.objects.size():
		return -1
	return (world.objects[object_index] as Gen2WorldObject).toggle_index
