class_name Gen3ScriptHost
extends RefCounted

const FRAME_TABLE: int = 2
const KEY_BITS: Array[int] = [0, 64, 128, 32, 16, 1, 2, 8, 4] # PokeButton id to GBA joypad bit.
const KEY_A: int = 1
const KEY_B: int = 2
const KEY_SELECT: int = 4
const KEY_START: int = 8
const KEY_RIGHT: int = 16
const KEY_LEFT: int = 32
const MOVEMENT_STEP_END: int = 0xFE
const MAP_SCRIPT_ON_DIVE_WARP: int = 6
const TIMED_SPECIALS: Array[String] = ["DoPCTurnOnEffect", "DoPCTurnOffEffect", "Script_FadeOutMapMusic"] # Presentation the script runs past.
const VAR_0X8004: int = 0x8004
const VAR_0X8005: int = 0x8005
const VAR_0X8006: int = 0x8006
const VAR_FACING: int = 0x800C
const VAR_LAST_TALKED: int = 0x800F
const VAR_TEXT_COLOR: int = 0x8012
const TEXT_COLOR_DEFAULT: int = 0xFF
const TEXT_COLOR_NEUTRAL: int = 3
const SPECIALS: Dictionary = { # `data/specials.inc` rows under Emerald's names.
	&"ruby": {31: "NoOp", 148: "GetPlayerBigGuyGirlString", 0: "HealPlayerParty", 51: "GetTrainerBattleMode", 52: "ShowTrainerIntroSpeech", 53: "ShowTrainerCantBattleSpeech",
		54: "GetTrainerFlag", 55: "DoTrainerApproach", 56: "PlayTrainerEncounterMusic",
		57: "ShouldTryRematchBattle", 58: "IsTrainerReadyForRematch",
		61: "HasEnoughMonsForDoubleBattle", 131: "CalculatePlayerPartyCount",
		142: "DrawWholeMapView", 180: "GetBattleOutcome", 314: "SetTrainerFacingDirection",
		60: "ShowPokemonStorageSystemPC", 95: "ShowEasyChatScreen", 150: "SetHiddenItemFlag",
		196: "ShowLinkBattleRecords", 199: "TryFieldPoisonWhiteOut", 200: "SetCB2WhiteOut", 204: "ResetSSTidalFlag",
		205: "EnterSafariMode", 206: "ExitSafariMode", 214: "DoPCTurnOnEffect", 215: "DoPCTurnOffEffect",
		249: "BedroomPC", 250: "PlayerPC", 251: "FieldShowRegionMap", 262: "ScriptMenu_CreatePCMultichoice",
		263: "AccessHallOfFamePC", 319: "DoFallWarp", 332: "Script_FadeOutMapMusic"},
	&"firered": {31: "NoOp", 148: "GetPlayerBigGuyGirlString", 295: "Script_FacePlayer", 296: "Script_ClearHeldMovement", 0: "HealPlayerParty", 51: "GetTrainerBattleMode", 52: "ShowTrainerIntroSpeech",
		53: "ShowTrainerCantBattleSpeech", 54: "GetTrainerFlag", 55: "DoTrainerApproach",
		56: "PlayTrainerEncounterMusic", 57: "ShouldTryRematchBattle", 58: "IsTrainerReadyForRematch",
		59: "BattleSetup_StartRematchBattle", 61: "HasEnoughMonsForDoubleBattle", 131: "CalculatePlayerPartyCount",
		132: "CountPartyNonEggMons", 142: "DrawWholeMapView",
		180: "GetBattleOutcome", 314: "SetTrainerFacingDirection", 388: "QuestLogNoOp", 391: "QuestLogNoOp",
		392: "QuestLogNoOp", 361: "QuestLogNoOp", 399: "SetBattledTrainerFlag", 408: "QuestLogNoOp", 409: "QuestLogNoOp",
		60: "ShowPokemonStorageSystemPC", 95: "ShowEasyChatScreen", 150: "SetHiddenItemFlag",
		196: "ShowLinkBattleRecords", 199: "TryFieldPoisonWhiteOut", 200: "SetCB2WhiteOut", 205: "EnterSafariMode",
		206: "ExitSafariMode", 214: "DoPCTurnOnEffect", 215: "DoPCTurnOffEffect", 249: "BedroomPC", 250: "PlayerPC",
		251: "FieldShowRegionMap", 262: "ScriptMenu_CreatePCMultichoice", 263: "AccessHallOfFamePC",
		319: "DoFallWarp", 332: "Script_FadeOutMapMusic", 346: "DoPicboxCancel", 350: "CheckAddCoins",
		362: "IsWirelessAdapterConnected", 366: "ShowWirelessCommunicationScreen", 369: "DisableMsgBoxWalkaway",
		381: "NoOp", 382: "NoOp", 383: "NoOp", 400: "NoOp", 406: "BufferTMHMMoveName"},
	&"emerald": {32: "NoOp", 151: "GetPlayerBigGuyGirlString", 297: "Script_FacePlayer", 298: "Script_ClearHeldMovement",
		473: "CountPlayerTrainerStars", 0: "HealPlayerParty", 54: "GetTrainerBattleMode", 55: "ShowTrainerIntroSpeech",
		56: "ShowTrainerCantBattleSpeech", 57: "GetTrainerFlag", 58: "DoTrainerApproach",
		59: "PlayTrainerEncounterMusic", 60: "ShouldTryRematchBattle", 61: "IsTrainerReadyForRematch",
		62: "BattleSetup_StartRematchBattle", 64: "HasEnoughMonsForDoubleBattle", 134: "CalculatePlayerPartyCount",
		135: "CountPartyNonEggMons", 145: "DrawWholeMapView",
		183: "GetBattleOutcome", 316: "SetTrainerFacingDirection", 519: "PlayerFaceTrainerAfterBattle",
		523: "TryPrepareSecondApproachingTrainer",
		63: "ShowPokemonStorageSystemPC", 98: "ShowEasyChatScreen", 153: "SetHiddenItemFlag",
		199: "ShowLinkBattleRecords", 202: "TryFieldPoisonWhiteOut", 203: "SetCB2WhiteOut", 207: "ResetSSTidalFlag",
		208: "EnterSafariMode", 209: "ExitSafariMode", 217: "DoPCTurnOnEffect", 218: "DoPCTurnOffEffect",
		252: "BedroomPC", 253: "PlayerPC", 254: "FieldShowRegionMap", 265: "ScriptMenu_CreatePCMultichoice",
		266: "AccessHallOfFamePC", 321: "DoFallWarp", 334: "Script_FadeOutMapMusic", 344: "NoOp",
		414: "BufferTMHMMoveName", 415: "IsWirelessAdapterConnected", 419: "ShowWirelessCommunicationScreen"},
}
const HANDLERS: Dictionary = {
	"special": &"_special_command", "specialvar": &"_special_command",
	"yesnobox": &"_menu_command", "multichoice": &"_menu_command", "multichoicedefault": &"_menu_command",
	"multichoicegrid": &"_menu_command", "pokemart": &"_mart_command", "pokemartdecoration": &"_mart_command",
	"pokemartdecoration2": &"_mart_command", "braillemessage": &"_braille_command",
	"setfieldeffectargument": &"_field_effect_command", "dofieldeffect": &"_field_effect_command",
	"trainerbattle": &"_trainer_command", "dotrainerbattle": &"_trainer_command",
	"trainerbattlebegin": &"_trainer_command", "gotopostbattlescript": &"_trainer_command",
	"gotobeatenscript": &"_trainer_command", "selectapproachingtrainer": &"_trainer_command",
}

var input: Gen3FieldInput
var warps := Gen3Warp.new()
var warp_pending: bool = false
var field_tasks := Callable() # The screen's half of `RunTasks`: given the script's requests, it returns those it left.
var _warp_reset_avatar: bool = false
var context: Gen3ScriptContext
var avatar: Gen3PlayerAvatar
var objects: Gen3ObjectEvents
var services: Gen3ScriptServices
var battle: Gen3TrainerBattle
var trainers: Gen3TrainerSee
var selected_slot: int = -1
var message_visible: bool = false
var signpost: bool = false # script.c's `sMsgIsSignpost`, which picks FRLG's frame.
var message_running: bool = false
var _wait: String = ""
var _lock_task: bool = false
var _player_frozen: bool = false
var _selected_frozen: bool = false
var _moving_id: int = 0
var _wait_map := Vector2i.ZERO
var _movements: Dictionary = {}
var _output: Array[Dictionary] = []
var _foreground_active: bool = false
var _executing: Gen3ScriptContext
var _field_arguments: Dictionary = {}
var _approached_slots: Array[int] = []
var _layout_id: int = 0 # `setmaplayoutindex`'s `gSaveBlock1Ptr->mapLayoutId`; zero keeps the header's.
var _sign_cancelable: bool = false # script.c's `sMsgBoxIsCancelable`.
var _sign_inhibit: int = 0 # `gWalkAwayFromSignInhibitTimer`.
var _walkaway_disabled: bool = false # script.c's `sMsgBoxWalkawayDisabled`.


func _init(player: Gen3PlayerAvatar) -> void:
	avatar = player
	objects = player.objects
	context = Gen3ScriptContext.new(objects.camera.data, objects.events)
	input = Gen3FieldInput.new(objects.events)
	services = Gen3ScriptServices.new(objects.camera.data, objects.events)
	services.gender = avatar.gender
	battle = Gen3TrainerBattle.new(objects.events.game)
	trainers = Gen3TrainerSee.new(objects, avatar)
	warps.location = Gen3Warp.record(objects.camera.group, objects.camera.number, -1,
		avatar.object().current.x - Gen3MapGrid.MAP_OFFSET, avatar.object().current.y - Gen3MapGrid.MAP_OFFSET)


func start(at: int, selected: int = -1) -> void:
	selected_slot = selected
	_wait = ""
	_sign_cancelable = false # ScriptContext_SetupScript.
	_walkaway_disabled = false
	context.start(at)
	_foreground_active = true
	objects.events.controls_locked = true


func resume() -> void:
	context.resume()
	if context.state == Gen3ScriptContext.State.RUNNING:
		objects.events.controls_locked = true


func finish_message() -> void:
	message_running = false


func finish_wait() -> void: # Ends a `Gen3ScriptContext.HOST_WAITS` command once the screen's sound, fade, door or effect is over.
	if _wait == "host":
		_wait = "done"


func choose(value: int) -> void: # The player's answer to a `yesnobox` or `multichoice`: `VAR_RESULT`, 127 for B in a multichoice.
	objects.events.var_set(Gen3ScriptServices.VAR_RESULT, value)
	resume()


func finish_battle(outcome: int) -> Array[Dictionary]: # `CB2_EndTrainerBattle`, with a [enum Gen3TrainerBattle.Outcome]: a loss emits `white_out` and leaves the script stopped.
	objects.events.battle_outcome = outcome
	if not battle.finish(outcome, objects.events):
		return [{"kind": "white_out"}]
	resume()
	return []


func try_frame_script() -> bool:
	if objects.events.controls_locked or context.state != Gen3ScriptContext.State.STOPPED:
		return false
	if not context.start_map_script(objects.camera.group, objects.camera.number, FRAME_TABLE):
		return false
	selected_slot = -1
	_wait = ""
	_foreground_active = true
	objects.events.controls_locked = true
	return true


func run_map_script(type: int) -> Array[Dictionary]: # script.c::RunScriptImmediately has a separate context and no frame tasks.
	if type == FRAME_TABLE:
		return []
	_output = []
	var immediate := Gen3ScriptContext.new(objects.camera.data, objects.events)
	if not immediate.start_map_script(objects.camera.group, objects.camera.number, type):
		return []
	return _run_immediate(immediate)


func _run_immediate(immediate: Gen3ScriptContext) -> Array[Dictionary]:
	_executing = immediate
	for iteration: int in 10000:
		_collect(immediate.tick(10000, false, _command))
		if immediate.state in [Gen3ScriptContext.State.STOPPED, Gen3ScriptContext.State.FAULT]:
			return _output
		if immediate.state == Gen3ScriptContext.State.WAITING: # ScriptContext_Stop only stops the global context.
			immediate.resume()
		elif immediate.state == Gen3ScriptContext.State.NATIVE_WAIT: # Nothing would ever finish it inside pret's loop.
			immediate.fail(immediate.offset, "immediate_script_wait")
			_collect([immediate.error])
			return _output
	immediate.fail(immediate.offset, "instruction_budget")
	_collect([immediate.error])
	return _output


func tick(pressed: int = PokeButton.NONE) -> Array[Dictionary]:
	_output = []
	_executing = context
	var native_complete: bool = _native_complete(pressed)
	if not warp_pending: # Gen3Script.WARPS ends the cached graph; map loading replaces this context.
		_collect(context.tick(10000, native_complete, _command))
	if _foreground_active and context.state in [Gen3ScriptContext.State.STOPPED, Gen3ScriptContext.State.FAULT]:
		objects.events.controls_locked = warp_pending
		_foreground_active = false
	_step_movements()
	_step_lock_task()
	return _output


func step(held: Array[int] = [], pressed: Array[int] = []) -> Array: # overworld.c::DoCB1_Overworld then OverworldBasic.
	var requests: Array = []
	avatar.update_tile_state()
	requests.append_array(trainers.run_tasks())
	var held_keys: int = _keys(held)
	var new_keys: int = _keys(pressed)
	_cancel_signpost(held_keys, new_keys, requests)
	if not objects.events.controls_locked and not _process_input(held_keys, new_keys, requests):
		requests.append_array(avatar.step(Gen3Bike.dpad_direction(held_keys), new_keys, held_keys))
	var button: int = PokeButton.A if PokeButton.A in pressed else (PokeButton.B if PokeButton.B in pressed else PokeButton.NONE)
	requests.append_array(tick(button))
	if field_tasks.is_valid():
		requests = field_tasks.call(requests)
	requests.append_array(avatar.step_movement_tasks())
	requests.append_array(objects.step_movements(avatar.flags & Gen3PlayerAvatar.Flag.DASH != 0,
		avatar.tile_state == Gen3PlayerAvatar.Tile.CENTER))
	var output: Array = []
	for request: Dictionary in requests:
		match String(request["kind"]):
			"script_enable": resume()
			"script": start(int(request["offset"]), selected_slot)
			_: output.append(request)
	return output


func _process_input(held: int, pressed: int, requests: Array) -> bool: # field_control_avatar.c::ProcessPlayerFieldInput.
	objects.events.var_set(VAR_LAST_TALKED, 0)
	selected_slot = -1
	objects.events.var_set(VAR_TEXT_COLOR, TEXT_COLOR_DEFAULT) # ResetFacingNpcOrSignpostVars.
	signpost = false
	if _try_trainers() or try_frame_script():
		return true
	var buttons: bool = avatar.accepts_field_buttons()
	if buttons and pressed & KEY_B and not avatar.frlg and _try_dive(true):
		return true
	var settled: bool = avatar.tile_state == Gen3PlayerAvatar.Tile.CENTER and not avatar.on_forced_tile()
	if settled and _process_settled(held, requests):
		return true
	var direction: int = Gen3Bike.dpad_direction(held)
	if direction != avatar.object().facing or not settled and avatar.tile_state != Gen3PlayerAvatar.Tile.NOT_MOVING:
		direction = 0
	if direction != 0 and (_try_arrow_warp(direction, requests) or _try_walk_into_sign(held, requests)):
		return true
	return _process_front_input(direction, pressed if buttons else 0, requests)


func _process_settled(held: int, requests: Array) -> bool: # The tookStep block and FireRed's first sign test.
	if avatar.running_state == Gen3PlayerAvatar.Running.MOVING and _on_step(requests):
		return true
	return Gen3Bike.dpad_direction(held) in [0, avatar.object().facing] and _try_walk_into_sign(held, requests)


func _process_front_input(direction: int, pressed: int, requests: Array) -> bool: # The cell ahead, then the menus.
	if pressed & KEY_A and interact(requests):
		return true
	if direction != 0 and _try_door_warp(direction, requests):
		return true
	if pressed & KEY_A and not avatar.frlg and _try_dive(false):
		return true
	return _try_menu_buttons(pressed, requests)


func _try_menu_buttons(pressed: int, requests: Array) -> bool:
	if pressed & KEY_START:
		requests.append({"kind": "start_menu"})
		objects.events.controls_locked = true
		return true
	return pressed & KEY_SELECT != 0 and _use_registered_item(requests)


func _use_registered_item(requests: Array) -> bool: # UseRegisteredKeyItemOnField; [method end_field_menu] returns the controls.
	var events: Gen3EventData = objects.events
	if events.registered_item != 0:
		if events.bag.has(events.registered_item, 1):
			events.controls_locked = true
			requests.append({"kind": "use_registered_item", "item": events.registered_item})
			return true
		events.registered_item = 0
	return _start_native("select_without_item")


func end_field_menu() -> void: # The START menu or a registered item has given the field back.
	objects.events.controls_locked = false


func _start_native(key: String, selected: int = -1) -> bool:
	var at: int = objects.camera.data.world_native_script_offset(key)
	if at < 0:
		return false
	start(at, selected)
	return true


func _on_step(requests: Array) -> bool: # The tookStep block and TryStartStepBasedScript.
	var events: Gen3EventData = objects.events
	events.increment_stat(Gen3FieldInput.GAME_STAT_STEPS)
	if _try_coord_event(requests):
		return true
	var player: Gen3ObjectEvents.ObjectEvent = avatar.object()
	var behavior: int = objects.camera.grid.behavior_at(player.current.x, player.current.y) & 0xFF
	if _try_warp(player.current, player.previous_elevation, input.warp_mode(behavior), behavior, requests):
		return true
	if not avatar.frlg and behavior == Gen3FieldInput.CRACKED_FLOOR_HOLE:
		return _start_native("fall_down_hole")
	var forced: bool = avatar.flags & Gen3PlayerAvatar.Flag.FORCED_MOVE != 0
	var key: String = input.step_script(int(objects.camera.header.get("map_type", 0)), forced, requests)
	if key.is_empty():
		key = input.repel_script(forced)
	return not key.is_empty() and _start_native(key)


func _try_dive(emerge: bool) -> bool: # TrySetupDiveEmergeScript and TrySetupDiveDownScript.
	if not objects.events.flag_get(input.flags["dive"]):
		return false
	var kind: int = _dive_kind()
	if kind != (Gen3FieldInput.CONNECTION_EMERGE if emerge else Gen3FieldInput.CONNECTION_DIVE) or not _set_dive_warp(kind):
		return false
	return _start_native("use_dive_underwater" if emerge else "use_dive")


func _dive_kind() -> int:
	var player: Gen3ObjectEvents.ObjectEvent = avatar.object()
	return input.dive_kind(objects.camera.grid.behavior_at(player.current.x, player.current.y) & 0xFF,
		int(objects.camera.header.get("map_type", 0)))


func _set_dive_warp(kind: int) -> bool: # overworld.c::SetDiveWarp: a dive connection, else what ON_DIVE_WARP left.
	var at: Vector2i = avatar.object().current - Vector2i.ONE * Gen3MapGrid.MAP_OFFSET
	for row: Dictionary in objects.camera.header.get("connections", []):
		if int(row["direction"]) == kind:
			warps.destination = Gen3Warp.record(int(row["group"]), int(row["number"]), -1, at.x, at.y)
			return true
	run_map_script(MAP_SCRIPT_ON_DIVE_WARP)
	if warps.dive.is_empty():
		return false
	warps.destination = warps.dive.duplicate()
	return true


func finish_dive() -> Array[Dictionary]: # FLDEFF_USE_DIVE's end: dive_warp, then the fade the `warp` request names.
	_output = []
	var kind: int = _dive_kind()
	if kind != 0 and _set_dive_warp(kind):
		_begin_warp("dive", false)
	return _output


func _try_trainers() -> bool: # trainer_see.c::CheckForTrainersWantingBattle and its ConfigureAndSetUp callers.
	if not trainers.check_trainers(services.usable_mons() >= 2):
		return false
	var data: GameData = objects.camera.data
	battle.reset_opponents()
	for index: int in trainers.approaching.size():
		trainers.approaching_id = index
		var row: Dictionary = data.world_script_instruction(int(trainers.approaching[index]["script_offset"]))
		if row.is_empty() or row["command"] != "trainerbattle":
			continue
		_select_trainer(int(trainers.approaching[index]["slot"]))
		battle.configure(row["operands"], int(row["next_offset"]), index)
	trainers.approaching_id = 0
	start(data.world_native_script_offset("trainer_approach"), selected_slot)
	return true


func _select_trainer(slot: int) -> void:
	selected_slot = slot
	objects.events.var_set(VAR_LAST_TALKED, objects.objects[slot].local_id)


func _front_elevation() -> int:
	var player: Gen3ObjectEvents.ObjectEvent = avatar.object()
	return player.previous_elevation if objects.camera.grid.elevation_at(player.current.x, player.current.y) != 0 else 0


func _try_arrow_warp(direction: int, requests: Array) -> bool: # TryArrowWarp and FireRed's directional stairs.
	var player: Gen3ObjectEvents.ObjectEvent = avatar.object()
	var behavior: int = objects.camera.grid.behavior_at(player.current.x, player.current.y) & 0xFF
	if behavior in input.arrow_warps(direction):
		return _try_warp(player.current, player.previous_elevation, "warp", behavior, requests)
	if not avatar.frlg or behavior not in Gen3PlayerAvatar.FRLG_STAIR_WARPS.get(direction, []):
		return false
	var biking: bool = avatar.flags & (Gen3PlayerAvatar.Flag.MACH_BIKE | Gen3PlayerAvatar.Flag.ACRO_BIKE) != 0
	if not _try_warp(player.current, player.previous_elevation, "stairs", behavior, requests):
		return false
	if biking:
		avatar.transition(Gen3PlayerAvatar.Flag.ON_FOOT)
	requests.back()["delay"] = 12 if biking else 0
	return true


func _try_door_warp(direction: int, requests: Array) -> bool: # TryDoorWarp; secret base doors wait on the bases.
	if direction != Gen3ObjectEvents.Direction.NORTH:
		return false
	var at: Vector2i = avatar.object().current + Gen3FieldCamera.DIRECTIONS[direction]
	var behavior: int = objects.camera.grid.behavior_at(at.x, at.y) & 0xFF
	return behavior == Gen3PlayerAvatar.MB_WARP_DOOR and _try_warp(at, _front_elevation(), "door", behavior, requests)


func _try_warp(at: Vector2i, elevation: int, mode: String, behavior: int, requests: Array) -> bool: # SetupWarp, then the `Do*Warp` that [param mode] names or a `script:`.
	if mode.is_empty():
		return false
	var id: int = _warp_event_at(at, elevation)
	if id < 0 or not warps.from_event(objects.camera.data, objects.camera.group, objects.camera.number, id, at - Vector2i.ONE * Gen3MapGrid.MAP_OFFSET):
		return false
	if mode.begins_with("script:"):
		return _start_native(mode.trim_prefix("script:"))
	_output = []
	_begin_warp(mode, false, behavior)
	requests.append_array(_output)
	return true


func _warp_event_at(at: Vector2i, elevation: int) -> int: # GetWarpEventAtPosition.
	var rows: Array = objects.camera.data.world_map_events(objects.camera.group, objects.camera.number).get("warps", [])
	for index: int in rows.size():
		var row: Dictionary = rows[index]
		if Vector2i(int(row["x"]), int(row["y"])) + Vector2i.ONE * Gen3MapGrid.MAP_OFFSET == at and int(row["elevation"]) in [0, elevation]:
			return index
	return -1


func _events_at(kind: String, at: Vector2i, elevation: int) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for row: Dictionary in objects.camera.data.world_map_events(objects.camera.group, objects.camera.number).get(kind, []):
		if Vector2i(int(row["x"]), int(row["y"])) + Vector2i.ONE * Gen3MapGrid.MAP_OFFSET == at and int(row["elevation"]) in [0, elevation]:
			found.append(row)
	return found


func _try_coord_event(requests: Array) -> bool: # field_control_avatar.c::TryRunCoordEventScript; immediate rows continue the search.
	var player: Gen3ObjectEvents.ObjectEvent = avatar.object()
	for row: Dictionary in _events_at("coords", player.current, player.previous_elevation):
		var at: int = int(row["script_offset"])
		var trigger: int = int(row["variable"])
		if at == 0:
			var weather: Dictionary = {1: 1, 2: 2, 3: 3, 4: 4, 5: 5, 6: 6, 7: 9, 8: 7, 9: 8, 10: 11, 11: 12, 20: 20, 21: 21}
			if weather.has(trigger) and objects.sprites.weather != null:
				objects.sprites.weather.set_weather(weather[trigger])
			elif weather.has(trigger):
				requests.append({"kind": "weather", "weather": weather[trigger]})
		elif trigger == 0:
			_output = []
			var immediate := Gen3ScriptContext.new(objects.camera.data, objects.events)
			immediate.start(at)
			requests.append_array(_run_immediate(immediate))
		elif objects.events.var_get(trigger) == (int(row["value"]) & 0xFF):
			start(at)
			return true
	return false


func interact(requests: Array = []) -> bool: # TryStartInteractionScript, each source tried in GetInteractionScript's order.
	var player: Gen3ObjectEvents.ObjectEvent = avatar.object()
	var direction: int = player.facing
	if objects.events.controls_locked or direction < 1 or direction > 4:
		return false
	var front: Vector2i = player.current + Gen3FieldCamera.DIRECTIONS[direction]
	var elevation: int = _front_elevation()
	var behavior: int = objects.camera.grid.behavior_at(front.x, front.y) & 0xFF
	var slot: int = _interacted_slot(front, direction, elevation, behavior)
	var at: int = _object_script(slot, direction) if slot >= 0 else -1
	if at < 0:
		slot = -1
		at = _background_script(front, direction, elevation)
	var key: String = ""
	if at < 0:
		key = input.metatile_script(behavior, direction, objects.camera.grid.elevation_at(front.x, front.y) == elevation)
		key = _water_script(behavior) if key.is_empty() else key
		at = objects.camera.data.world_native_script_offset(key) if not key.is_empty() else -1
	if at < 0:
		return false
	if not _interaction_is_silent(at, key):
		requests.append({"kind": "sound", "name": "select"})
	if avatar.frlg and slot < 0 and (behavior == Gen3FieldInput.FRLG_SIGNPOST or not input.sign_script(behavior, direction).is_empty()):
		signpost = true
	start(at, slot)
	return true


func _interaction_is_silent(at: int, key: String) -> bool:
	if input.silent_script(key):
		return true
	var data: GameData = objects.camera.data
	return at in [data.world_native_script_offset("brendan_pc"), data.world_native_script_offset("may_pc")]


func _background_script(at: Vector2i, direction: int, elevation: int) -> int: # GetInteractedBackgroundEventScript; negative finds nothing.
	var rows: Array[Dictionary] = _events_at("backgrounds", at, elevation)
	if rows.is_empty():
		return -1
	var row: Dictionary = rows[0] # GetBackgroundEventAtPosition selects the first row, even when its facing check fails.
	var kind: int = int(row["kind"])
	if kind in Gen3FieldInput.HIDDEN_ITEM_KINDS:
		return _hidden_item_script(row, direction)
	if kind == 8 and not avatar.frlg or kind >= 1 and kind <= 4 and direction != [0, 2, 1, 4, 3][kind]:
		return -1 # `BG_EVENT_SECRET_BASE` needs the bases' save records.
	var script: int = int(row.get("script_offset", 0))
	if avatar.frlg:
		objects.events.var_set(VAR_FACING, direction)
	return script if script > 0 else objects.camera.data.world_native_script_offset("test_signpost")


func _hidden_item_script(row: Dictionary, direction: int) -> int:
	var events: Gen3EventData = objects.events
	if bool(row.get("underfoot", false)):
		return -1
	var flag: int = input.hidden_item_flag(row)
	events.var_set(VAR_0X8004, flag)
	events.var_set(VAR_0X8005, int(row["item"]))
	if avatar.frlg:
		events.var_set(VAR_0X8006, int(row["quantity"]))
		events.var_set(VAR_FACING, direction)
	return -1 if events.flag_get(flag) else objects.camera.data.world_native_script_offset("hidden_item")


func _water_script(behavior: int) -> String: # GetInteractedWaterScript.
	var surfing: bool = avatar.flags & Gen3PlayerAvatar.Flag.SURFING != 0
	var has_surf: bool = not surfing and objects.events.party.any(func(mon: Dictionary) -> bool: return Gen3FieldInput.MOVE_SURF in mon["moves"])
	var events: Gen3EventData = objects.events
	if avatar.frlg and behavior == Gen3FieldInput.FAST_WATER_BEHAVIOR and has_surf:
		return "current_too_fast"
	if has_surf and events.flag_get(input.flags["surf"]) and avatar.facing_fishable_water():
		return "use_surf"
	if behavior != Gen3FieldInput.WATERFALL_BEHAVIOR:
		return ""
	var north: bool = avatar.object().movement_direction == Gen3ObjectEvents.Direction.NORTH
	return "use_waterfall" if surfing and north and events.flag_get(input.flags["waterfall"]) else "cannot_use_waterfall"


func _try_walk_into_sign(held: int, requests: Array) -> bool: # TrySetUpWalkIntoSignpostScript, FireRed's; left and right never read a sign.
	var player: Gen3ObjectEvents.ObjectEvent = avatar.object()
	var direction: int = player.facing
	if not avatar.frlg or held & (KEY_LEFT | KEY_RIGHT) or direction not in [Gen3ObjectEvents.Direction.NORTH, Gen3ObjectEvents.Direction.SOUTH]:
		return false
	var front: Vector2i = player.current + Gen3FieldCamera.DIRECTIONS[direction]
	var behavior: int = objects.camera.grid.behavior_at(front.x, front.y) & 0xFF
	var data: GameData = objects.camera.data
	var key: String = input.sign_script(behavior, direction)
	var at: int = data.world_native_script_offset(key) if not key.is_empty() else -1
	if at < 0 and behavior == Gen3FieldInput.FRLG_SIGNPOST:
		var rows: Array[Dictionary] = _events_at("backgrounds", front, _front_elevation())
		if not rows.is_empty():
			var script: int = int(rows[0].get("script_offset", 0))
			at = script if script > 0 else data.world_native_script_offset("test_signpost")
	if at < 0:
		return false
	objects.events.var_set(VAR_FACING, direction)
	start(at)
	_sign_inhibit = Gen3FieldInput.SIGN_INHIBIT_FRAMES
	_sign_cancelable = true
	signpost = true
	return true


func _cancel_signpost(held: int, pressed: int, requests: Array) -> void: # FieldInput_HandleCancelSignpost.
	if context.state == Gen3ScriptContext.State.STOPPED:
		return
	if _sign_inhibit > 0:
		_sign_inhibit -= 1
		return
	if not _sign_cancelable:
		return
	var direction: int = Gen3Bike.dpad_direction(held)
	var turned: bool = direction != 0 and direction != avatar.object().facing
	if turned and _walkaway_disabled or not turned and pressed & KEY_START == 0:
		return
	_start_native("cancel_message_box")
	if not turned:
		requests.append({"kind": "start_menu"})


func _interacted_slot(at: Vector2i, direction: int, elevation: int, behavior: int) -> int: # GetInteractedObjectEventScript, including a counter's second cell.
	var slot: int = objects.at_position(at, elevation)
	if slot >= 0 and not objects.objects[slot].is_player:
		return slot
	if behavior != Gen3FieldInput.COUNTER_BEHAVIOR:
		return -1
	at += Gen3FieldCamera.DIRECTIONS[direction]
	slot = objects.at_position(at, elevation)
	return -1 if slot < 0 or objects.objects[slot].is_player else slot


func _object_script(slot: int, direction: int) -> int:
	var object: Gen3ObjectEvents.ObjectEvent = objects.objects[slot]
	objects.events.var_set(VAR_LAST_TALKED, object.local_id)
	objects.events.var_set(VAR_FACING, direction)
	var at: int = int(objects.template_by_id(object.local_id, object.map_number, object.map_group).get("script_offset", 0))
	return at if at > 0 else -1


static func _keys(buttons: Array[int]) -> int:
	var keys: int = 0
	for button: int in buttons:
		if button >= 0 and button < KEY_BITS.size():
			keys |= KEY_BITS[button]
	return keys


func _collect(events: Array[Dictionary]) -> void:
	for event: Dictionary in events:
		if event["type"] != "script_command":
			var request: Dictionary = event.duplicate(true)
			request["kind"] = request["type"]
			request.erase("type")
			_output.append(request)


func _command(event: Dictionary) -> void:
	var command: String = event["command"]
	if _executing != context and (command in Gen3ScriptContext.NATIVE_COMMANDS or command in Gen3ScriptContext.WARP_COMMANDS
			or command in Gen3ScriptContext.HOST_WAITS or command in Gen3ScriptContext.STOPPING_COMMANDS):
		_executing.fail(int(event["offset"]), "immediate_script_wait", event)
		return
	if _route(command, event):
		return
	var operands: Array = event["operands"]
	match command:
		"message", "messageautoscroll", "messageinstant", "pokenavcall":
			_show_message(event)
		"closemessage": _close_message()
		"waitmessage", "waitbuttonpress": _wait = command
		"lock", "lockall", "lockfortrainer": _lock(command != "lockall")
		"release", "releaseall": _release(command == "release")
		"faceplayer": _face_player()
		"turnobject":
			var target: Gen3ObjectEvents.ObjectEvent = _movement_object(objects.events.var_get(int(operands[0])) & 0xFF, Vector2i(objects.camera.group, objects.camera.number))
			if target != null:
				Gen3ObjectEvents.turn(target, int(operands[1]))
		"applymovement", "applymovementat", "applymovement_at":
			var map: Vector2i = _command_map(operands, 2)
			_moving_id = objects.events.var_get(int(operands[0])) & 0xFF
			_start_movement(_moving_id, map, int(operands[1]), event)
		"waitmovement", "waitmovementat", "waitmovement_at":
			var local_id: int = objects.events.var_get(int(operands[0])) & 0xFF
			if local_id != 0:
				_moving_id = local_id
			_wait_map = _command_map(operands, 1)
			_wait = "movement"


func _face_player() -> void:
	if _selected() != null:
		objects.set_held_movement(_selected(), avatar.action(&"face", Gen3ObjectEvents.OPPOSITE[avatar.object().facing]))


func _route(command: String, event: Dictionary) -> bool:
	if command in Gen3ScriptContext.WARP_COMMANDS or command.begins_with("set") and command.ends_with("warp"):
		_warp_command(event)
	elif command in Gen3ScriptContext.OBJECT_COMMANDS:
		_object_command(command, event["operands"])
	elif HANDLERS.has(command):
		call(HANDLERS[command], event)
	elif command in Gen3ScriptServices.COMMANDS:
		if not services.run(command, event["operands"], _executing):
			_executing.fail(int(event["offset"]), "unsupported_command", event)
	elif command in Gen3ScriptContext.PRESENTATION or command in Gen3ScriptContext.HOST_WAITS \
			or command in Gen3ScriptContext.STOPPING_COMMANDS:
		_present(event)
	else:
		return false
	return true


func _present(event: Dictionary) -> void:
	var command: String = event["command"]
	var operands: Array = event["operands"].duplicate()
	var through_vars: Array = Gen3ScriptContext.PRESENTATION.get(command, Gen3ScriptContext.HOST_WAITS.get(command, []))
	for index: int in through_vars:
		operands[index] = objects.events.var_get(int(operands[index]))
	if command == "setmaplayoutindex":
		_layout_id = int(operands[0])
		return
	if command == "textcolor":
		objects.events.var_set(VAR_TEXT_COLOR + 1, objects.events.var_get(VAR_TEXT_COLOR))
		objects.events.var_set(VAR_TEXT_COLOR, int(operands[0]))
		return
	if command in ["signmsg", "normalmsg"]:
		signpost = command == "signmsg"
		return
	if command in ["setweather", "resetweather", "doweather"] and _weather_command(command, operands):
		return
	if command in Gen3ScriptContext.HOST_WAITS:
		_wait = "host"
	_output.append({"kind": command, "operands": operands})


func _weather_command(command: String, operands: Array) -> bool: # False without a field weather, leaving it to the caller.
	var weather: Gen3FieldWeather = objects.sprites.weather
	if weather == null:
		return false
	match command:
		"setweather": weather.set_saved(int(operands[0]))
		"resetweather": weather.set_saved_from_header(objects.camera.header)
		"doweather": weather.do_current()
	return true


func _menu_command(event: Dictionary) -> void:
	var command: String = event["command"]
	var operands: Array = event["operands"]
	var request: Dictionary = {"kind": "menu", "left": int(operands[0]), "top": int(operands[1])}
	objects.events.var_set(Gen3ScriptServices.VAR_RESULT, 0xFF)
	if command == "yesnobox":
		request["choices"] = ["YES", "NO"]
		request["yes_no"] = true
	else:
		request["choices"] = objects.camera.data.world_multichoice(int(operands[2]))
		request["default"] = int(operands[3]) if command == "multichoicedefault" else 0
		request["columns"] = int(operands[3]) if command == "multichoicegrid" else 1
		request["ignore_b"] = int(operands.back()) & 1 != 0 # FRLG's bit 1 only lets a quest log show the menu.
	_output.append(request)


func _mart_command(event: Dictionary) -> void:
	var command: String = event["command"]
	var table: String = "marts" if command == "pokemart" else "decoration_marts"
	var row: Dictionary = objects.camera.data.world_script_data(table, Gen3Layout.rom_offset(int(event["operands"][0])))
	if row.is_empty():
		_executing.fail(int(event["offset"]), "missing_mart", event)
		return
	_output.append({"kind": "mart", "mode": command, "items": row["entries"]})


func _braille_command(event: Dictionary) -> void:
	var row: Dictionary = objects.camera.data.world_script_data("braille", Gen3Layout.rom_offset(int(event["operands"][0])))
	if row.is_empty():
		_executing.fail(int(event["offset"]), "missing_text", event)
		return
	_output.append({"kind": "braillemessage", "bytes": PackedByteArray(row["bytes"])})


func _field_effect_command(event: Dictionary) -> void:
	var operands: Array = event["operands"]
	if event["command"] == "setfieldeffectargument":
		var value: int = objects.events.var_get(int(operands[1]))
		_field_arguments[int(operands[0])] = (value ^ 0x8000) - 0x8000 # gFieldEffectArguments holds (s16)VarGet.
		return
	_output.append({"kind": "dofieldeffect", "effect": objects.events.var_get(int(operands[0])),
		"arguments": _field_arguments.duplicate()})


func _trainer_command(event: Dictionary) -> void:
	match String(event["command"]):
		"trainerbattle": _configure_battle(event)
		"selectapproachingtrainer":
			selected_slot = int(trainers.approaching[trainers.approaching_id]["slot"])
		"dotrainerbattle", "trainerbattlebegin":
			_approached_slots.assign(trainers.approaching.map(func(row: Dictionary) -> int: return int(row["slot"])))
			_output.append(battle.begin(trainers.approaching.size()))
			trainers.approaching.clear() # gNoOfApproachingTrainers ends here, unlike gTrainerApproachedPlayer.
		"gotopostbattlescript": _executing.offset = battle.end_script
		"gotobeatenscript":
			var script: int = battle.beaten_script()
			if script < 0:
				_release(false)
			_executing.offset = script


func _configure_battle(event: Dictionary) -> void:
	var at: int = _executing.offset
	if not battle.configure(event["operands"], at, trainers.approaching_id):
		_executing.fail(int(event["offset"]), "unsupported_command", event)
		return
	if battle.sets_map_vars(trainers.approaching_id) and battle.local_id != 0:
		objects.events.var_set(VAR_LAST_TALKED, battle.local_id)
		var object: Gen3ObjectEvents.ObjectEvent = objects.by_identity(battle.local_id, objects.camera.number, objects.camera.group)
		selected_slot = objects.objects.find(object)
	if battle.mode in [Gen3TrainerBattle.Mode.SET_TRAINER_A, Gen3TrainerBattle.Mode.SET_TRAINER_B]:
		_executing.offset = -1
		return
	var frlg: bool = objects.events.game in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN]
	_executing.offset = objects.camera.data.world_trainer_battle_script(Gen3Script.trainer_script_index(battle.mode, frlg))


func _special_command(event: Dictionary) -> void:
	var operands: Array = event["operands"]
	var table: Dictionary = SPECIALS[input.engine]
	var name: String = table.get(int(operands.back()), "")
	if name.is_empty():
		_executing.fail(int(event["offset"]), "unsupported_special", event)
		return
	var value: int = _special(name)
	if event["command"] == "specialvar":
		objects.events.var_set(int(operands[0]), value)


func _special(name: String) -> int: # One row of [constant SPECIALS]: its return value, which `specialvar` stores.
	var events: Gen3EventData = objects.events
	match name:
		"GetTrainerFlag": return int(battle.flag_set(events))
		"GetTrainerBattleMode": return battle.mode
		"PlayTrainerEncounterMusic":
			_trainer_music()
		"SetTrainerFacingDirection":
			if _selected() != null:
				Gen3ObjectEvents.set_trainer_movement_type(_selected(), Gen3ObjectEvents.TRAINER_FACING_TYPES[_selected().facing])
		"ShowTrainerIntroSpeech": _show_trainer_speech(battle.intro_speech(trainers.approaching_id))
		"ShowTrainerCantBattleSpeech": _show_trainer_speech(battle.cannot_speech)
		"HasEnoughMonsForDoubleBattle": events.var_set(Gen3ScriptServices.VAR_RESULT, services.doubles_state())
		"TryPrepareSecondApproachingTrainer":
			events.var_set(Gen3ScriptServices.VAR_RESULT, int(trainers.prepare_second_trainer()))
		"DoTrainerApproach": _output.append_array(trainers.start_approach())
		"ShouldTryRematchBattle", "IsTrainerReadyForRematch": return 0 # Nothing fills trainerRematches yet.
		"PlayerFaceTrainerAfterBattle": _face_trainer_after_battle()
		"GetBattleOutcome": return events.battle_outcome
		"CalculatePlayerPartyCount": return events.party.size()
		"CountPartyNonEggMons": return events.party.filter(func(mon: Dictionary) -> bool: return not bool(mon["egg"])).size()
		"SetBattledTrainerFlag": events.flag_set(Gen3TrainerBattle.TRAINER_FLAGS_START + battle.opponent_a)
		"HealPlayerParty": _output.append({"kind": "heal_party"})
		"DrawWholeMapView": _output.append({"kind": "redraw_map"})
		_: return _field_special(name)
	return 0


func _field_special(name: String) -> int: # The specials field_control_avatar.c's scripts run.
	var events: Gen3EventData = objects.events
	match name:
		"SetHiddenItemFlag": events.flag_set(events.var_get(VAR_0X8004))
		"BufferTMHMMoveName": return services.buffer_tm_move(events.var_get(VAR_0X8004))
		"CheckAddCoins": return int(events.var_get(Gen3ScriptServices.VAR_RESULT) + events.var_get(VAR_0X8006) <= 9999)
		"TryFieldPoisonWhiteOut": _field_poison_white_out()
		"DoFallWarp": _begin_warp("fall", true)
		"DoPicboxCancel": _close_message()
		"EnterSafariMode": input.enter_safari()
		"ExitSafariMode": input.exit_safari()
		"ResetSSTidalFlag": events.flag_clear(input.flags["cruise"])
		"DisableMsgBoxWalkaway": _walkaway_disabled = true
		"IsWirelessAdapterConnected": return 0 # No wireless adapter; the script says so.
		"NoOp", "QuestLogNoOp": pass
		"SetCB2WhiteOut": _output.append({"kind": "white_out"})
		_: return _player_special(name)
	return 0


func _player_special(name: String) -> int:
	match name:
		"GetPlayerBigGuyGirlString": services.strings[0] = "BIG GIRL" if avatar.gender else "BIG GUY"
		"Script_FacePlayer": _face_player()
		"Script_ClearHeldMovement":
			if _selected() != null and _selected().held_movement_active:
				Gen3ObjectEvents.clear_held_movement(_selected())
		"CountPlayerTrainerStars": return int(objects.events.stats.get(Gen3FieldInput.GAME_STAT_ENTERED_HOF, 0) != 0) # Pokedex, paintings and symbols have no models.
		_: _screen_special(name)
	return 0


func _screen_special(name: String) -> void: # Opens the screen [param name] does; one without a `waitstate` after it is `ScriptContext_Stop`, so resume() when closed.
	_output.append({"kind": "field_special", "name": name})
	if name not in TIMED_SPECIALS and objects.camera.data.world_script_instruction(_executing.offset).get("command", "") != "waitstate":
		_executing.state = Gen3ScriptContext.State.WAITING


func _field_poison_white_out() -> void: # field_poison.c::Task_TryFieldPoisonWhiteOut; the screen prints each faint, then resume().
	var events: Gen3EventData = objects.events
	var names: Array[String] = []
	for mon: Dictionary in events.party:
		if not bool(mon["egg"]) and int(mon["hp"]) == 0 and int(mon.get("status", 0)) & Gen3FieldInput.STATUS_POISONED != 0:
			mon["status"] = 0
			names.append(String(mon["nickname"]))
	events.var_set(Gen3ScriptServices.VAR_RESULT, int(services.usable_mons() == 0))
	_output.append({"kind": "poison_fainted", "names": names})
	_executing.state = Gen3ScriptContext.State.WAITING


func _trainer_music() -> void:
	if battle.mode not in Gen3TrainerBattle.NO_MUSIC_MODES:
		var id: int = battle.opponent_b if trainers.approaching_id != 0 else battle.opponent_a
		_output.append({"kind": "trainer_music", "trainer": id})


func _show_trainer_speech(pointer: int) -> void:
	_show_message({"command": "message", "operands": [pointer], "offset": _executing.offset})


func _face_trainer_after_battle() -> void: # `PlayerFaceTrainerAfterBattle`: the trainer who spotted the player, else the way the player already faces.
	var player: Gen3ObjectEvents.ObjectEvent = avatar.object()
	var direction: int = player.facing
	if trainers.approached_player and battle.face_index < _approached_slots.size():
		direction = Gen3ObjectEvents.OPPOSITE[objects.objects[_approached_slots[battle.face_index]].facing]
	var bytes := PackedByteArray([avatar.action(&"face", direction), MOVEMENT_STEP_END])
	_movements[objects.objects.find(player)] = {"bytes": bytes, "at": 0, "finished": false}
	_moving_id = Gen3ObjectEvents.LOCALID_PLAYER


func _map_coords(operands: Array, at: int) -> Vector2i:
	var x: int = objects.events.var_get(int(operands[at]))
	var y: int = objects.events.var_get(int(operands[at + 1]))
	return Vector2i((x ^ 0x8000) - 0x8000, (y ^ 0x8000) - 0x8000)


func _object_command(command: String, operands: Array) -> void:
	if command == "setmetatile":
		var at: Vector2i = _map_coords(operands, 0) + Vector2i.ONE * Gen3MapGrid.MAP_OFFSET
		var tile: int = objects.events.var_get(int(operands[2]))
		if objects.events.var_get(int(operands[3])) != 0:
			tile |= Gen3MapGrid.COLLISION_MASK
		objects.camera.grid.set_metatile_id(at.x, at.y, tile)
		return
	if command == "getplayerxy":
		if avatar != null:
			var at: Vector2i = avatar.object().current - Vector2i.ONE * Gen3MapGrid.MAP_OFFSET
			objects.events.var_set(int(operands[0]), at.x)
			objects.events.var_set(int(operands[1]), at.y)
		return
	var local_id: int = objects.events.var_get(int(operands[0])) & 0xFF
	var map: Vector2i = _command_map(operands, 1) if command.ends_with("at") else Vector2i(objects.camera.group, objects.camera.number)
	var object: Gen3ObjectEvents.ObjectEvent = _movement_object(local_id, map)
	match command:
		"removeobject", "removeobjectat", "removeobject_at": objects.remove(local_id, map.y, map.x)
		"addobject", "addobjectat", "addobject_at":
			var template: Dictionary = objects.template_by_id(local_id, map.y, map.x)
			if not template.is_empty():
				objects.spawn(template, map.y, map.x)
		"setobjectxyperm": objects.set_template_coords(local_id, _map_coords(operands, 1))
		"setobjectmovementtype": objects.set_template_movement_type(local_id, int(operands[1]))
		"setobjectxy":
			if object != null:
				Gen3ObjectEvents.move_to_map_coords(object, _map_coords(operands, 1) + Vector2i.ONE * Gen3MapGrid.MAP_OFFSET)
		"copyobjectxytoperm":
			if object != null:
				objects.override_template_coords(object)
		"showobjectat", "hideobjectat":
			if object != null:
				object.invisible = command == "hideobjectat"


func _warp_command(event: Dictionary) -> void:
	var command: String = event["command"]
	var operands: Array = event["operands"]
	var target: Dictionary
	if command == "warphole":
		var at: Vector2i = avatar.object().current - Vector2i.ONE * Gen3MapGrid.MAP_OFFSET
		if int(operands[0]) == 0xFF and int(operands[1]) == 0xFF:
			target = warps.fall_destination(at)
		else:
			target = Gen3Warp.record(int(operands[0]), int(operands[1]), -1, at.x, at.y)
	else:
		target = Gen3Warp.record(int(operands[0]), int(operands[1]), int(operands[2]),
			objects.events.var_get(int(operands[3])), objects.events.var_get(int(operands[4])))
	match command:
		"setdynamicwarp": warps.dynamic = target
		"setdivewarp": warps.dive = target
		"setholewarp": warps.hole = target
		"setescapewarp": warps.escape = target
		"setwarp": warps.destination = target
		_:
			if target.is_empty() or objects.camera.data.world_map_header(int(target["group"]), int(target["number"])).is_empty():
				_executing.fail(int(event["offset"]), "missing_warp_map", event)
				return
			warps.destination = target
			_begin_warp(command, true)


func _begin_warp(mode: String, reset_avatar: bool, behavior: int = 0) -> void:
	warp_pending = true
	_warp_reset_avatar = reset_avatar
	objects.events.controls_locked = true
	_output.append({"kind": "warp", "mode": mode, "behavior": behavior, "destination": warps.destination.duplicate()})


func complete_warp() -> Array[Dictionary]:
	if not warp_pending:
		return []
	var data: GameData = objects.camera.data
	var at: Vector2i = warps.position(data)
	var camera: Gen3FieldCamera = Gen3FieldCamera.open(data, int(warps.destination["group"]), int(warps.destination["number"]), at)
	if camera == null:
		return [{"kind": "script_error", "reason": "missing_warp_map", "destination": warps.destination.duplicate()}]
	var events: Gen3EventData = objects.events
	var gender: int = avatar.gender
	var stored_direction: int = Gen3ObjectEvents.Direction.SOUTH if _warp_reset_avatar else avatar.object().facing
	var stored_flags: int = Gen3PlayerAvatar.Flag.ON_FOOT if _warp_reset_avatar else avatar.initial_flags()
	var palettes: Gen3Palette = objects.sprites.palette
	var weather: Gen3FieldWeather = objects.sprites.weather
	warps.location["x"] = avatar.object().current.x - Gen3MapGrid.MAP_OFFSET
	warps.location["y"] = avatar.object().current.y - Gen3MapGrid.MAP_OFFSET
	warps.commit()
	events.clear_temp()
	var next_grid: Gen3MapGrid = camera.grid
	camera.grid = objects.camera.grid
	objects.camera = camera
	objects.load_templates()
	context = Gen3ScriptContext.new(data, events)
	_foreground_active = false
	_wait = ""
	_lock_task = false
	_movements.clear()
	selected_slot = -1
	message_visible = false
	message_running = false
	_layout_id = 0
	var previous_grid: Gen3MapGrid = camera.grid
	if weather != null:
		weather.set_saved_from_header(camera.header)
	var output: Array[Dictionary] = run_map_script(3)
	camera.grid = next_grid # overworld.c::LoadMapFromWarp runs ON_TRANSITION before InitMap/ON_LOAD.
	if _layout_id != 0:
		camera.grid = Gen3MapGrid.open(data, camera.group, camera.number, previous_grid, _layout_id)
		camera.header["layout_id"] = _layout_id
	output.append_array(run_map_script(1))
	var templates: Array = objects.templates
	objects = Gen3ObjectEvents.new(camera, events, palettes)
	objects.templates = templates
	objects.sprites.weather = weather
	if weather != null: # ResumeMap: after InitObjectEventPalettes, whose reset would free the weather's slots.
		weather.start()
		weather.resume_paused()
	output.append_array(run_map_script(5)) # ResumeMap comes before InitObjectEventsLocal, so these scripts only change what spawns.
	var cell: Vector2i = at + Vector2i.ONE * Gen3MapGrid.MAP_OFFSET
	var behavior: int = camera.grid.behavior_at(cell.x, cell.y) & 0xFF
	var map := Vector2i(camera.group, camera.number)
	var initial: int = input.initial_flags(stored_flags, map, camera.header, data.world_surfable(behavior))
	var direction: int = input.initial_direction(stored_direction, stored_flags, initial, behavior, int(camera.header.get("map_type", 0)))
	avatar = Gen3PlayerAvatar.open(objects, cell, direction, gender)
	avatar.transition(initial)
	avatar.track_camera()
	objects.spawn_in_view()
	trainers = Gen3TrainerSee.new(objects, avatar)
	output.append_array(run_map_script(4))
	warp_pending = false
	events.controls_locked = false
	output.append({"kind": "map_loaded", "group": camera.group, "number": camera.number, "position": at})
	return output


func _command_map(operands: Array, at: int) -> Vector2i:
	return Vector2i(int(operands[at]), int(operands[at + 1])) if operands.size() > at else Vector2i(objects.camera.group, objects.camera.number)


func _show_message(event: Dictionary) -> void:
	if message_running and event["command"] != "messageinstant":
		return
	var pointer: int = int(event["operands"][0])
	var row: Dictionary = objects.camera.data.world_script_data("texts", Gen3Layout.rom_offset(pointer))
	if row.is_empty():
		_executing.fail(int(event["offset"]), "missing_text", event)
		return
	var bytes := PackedByteArray(row["bytes"])
	message_visible = true
	if event["command"] != "messageinstant":
		message_running = true
	var text: String = Gen3Text.decode_fixed(objects.events.game, bytes, 0, bytes.size())
	_output.append({"kind": "message", "mode": event["command"], "bytes": bytes, "color": _text_color(),
		"text": Gen3Text.expand_placeholders(text, services.placeholders())})


func _text_color() -> int: # field_specials.c::ContextNpcGetTextColor, which only FRLG has.
	var color: int = objects.events.var_get(VAR_TEXT_COLOR)
	if not avatar.frlg:
		return TEXT_COLOR_NEUTRAL
	if color != TEXT_COLOR_DEFAULT:
		return color
	var selected: Gen3ObjectEvents.ObjectEvent = _selected()
	if selected == null:
		return TEXT_COLOR_NEUTRAL
	var table: PackedByteArray = objects.camera.data.world_text_box().get("colors", PackedByteArray())
	var at: int = selected.graphics_id >> 1
	return (table[at] >> ((selected.graphics_id & 1) << 2)) & 15 if at < table.size() else TEXT_COLOR_NEUTRAL


func _close_message() -> void:
	message_visible = false
	message_running = false
	_output.append({"kind": "close_message"})


func _selected() -> Gen3ObjectEvents.ObjectEvent:
	if selected_slot < 0 or selected_slot >= objects.objects.size():
		return null
	var object: Gen3ObjectEvents.ObjectEvent = objects.objects[selected_slot]
	return object if object.active else null


func _lock(with_selected: bool) -> void: # event_object_lock.c::FreezeObjects_WaitForPlayerAndSelected.
	var lock_selected: bool = with_selected and _selected() != null
	objects.freeze_except_player(selected_slot if lock_selected else -1)
	_player_frozen = false
	_selected_frozen = not lock_selected
	if lock_selected and not _selected().single_movement_active:
		Gen3ObjectEvents.freeze(_selected())
		_selected_frozen = true
	_lock_task = true
	_wait = "lock"


func _step_lock_task() -> void:
	if not _lock_task:
		return
	if not _player_frozen and avatar.tile_state != Gen3PlayerAvatar.Tile.TRANSITION:
		avatar.freeze_for_script()
		_player_frozen = true
	var selected: Gen3ObjectEvents.ObjectEvent = _selected()
	if not _selected_frozen and (selected == null or not selected.single_movement_active):
		if selected != null:
			Gen3ObjectEvents.freeze(selected)
		_selected_frozen = true
	if _player_frozen and _selected_frozen:
		_lock_task = false


func _release(with_selected: bool) -> void:
	_close_message()
	if with_selected and _selected() != null:
		Gen3ObjectEvents.clear_held_movement_if_finished(_selected())
	Gen3ObjectEvents.clear_held_movement_if_finished(avatar.object())
	for slot: int in _movements:
		Gen3ObjectEvents.unfreeze(objects.objects[slot])
	_movements.clear()
	objects.unfreeze_all()


func _native_complete(pressed: int) -> bool:
	if context.state != Gen3ScriptContext.State.NATIVE_WAIT:
		return false
	match _wait:
		"waitmessage": return not message_running
		"waitbuttonpress": return pressed in [PokeButton.A, PokeButton.B]
		"movement": return movement_finished(_moving_id, _wait_map)
		"done": return true
		"lock":
			if not _lock_task:
				avatar.stop_for_script()
				return true
	return false


func _movement_object(local_id: int, map: Vector2i) -> Gen3ObjectEvents.ObjectEvent:
	if local_id == Gen3ObjectEvents.LOCALID_PLAYER:
		return avatar.object() if avatar != null else null
	return objects.by_identity(local_id, map.y, map.x)


func movement_finished(local_id: int, map: Vector2i) -> bool:
	var object: Gen3ObjectEvents.ObjectEvent = _movement_object(local_id, map)
	if object == null:
		return true
	var slot: int = objects.objects.find(object)
	return not _movements.has(slot) or bool(_movements[slot]["finished"])


func _start_movement(local_id: int, map: Vector2i, pointer: int, event: Dictionary) -> void:
	var object: Gen3ObjectEvents.ObjectEvent = _movement_object(local_id, map)
	if object == null:
		return
	var slot: int = objects.objects.find(object)
	if _movements.has(slot) and not bool(_movements[slot]["finished"]):
		return
	var row: Dictionary = objects.camera.data.world_script_data("movements", Gen3Layout.rom_offset(pointer))
	if row.is_empty():
		_executing.fail(int(event["offset"]), "missing_movement", event)
		return
	_movements[slot] = {"bytes": PackedByteArray(row["bytes"]), "at": 0, "finished": false}


func _step_movements() -> void: # script_movement.c::ScriptMovement_TakeStep; a finished slot stays reserved until release.
	for slot: int in _movements:
		var object: Gen3ObjectEvents.ObjectEvent = objects.objects[slot]
		var row: Dictionary = _movements[slot]
		if object.held_movement_active and Gen3ObjectEvents.clear_held_movement_if_finished(object) == 0:
			continue
		var bytes: PackedByteArray = row["bytes"]
		var action: int = bytes[int(row["at"])]
		if action == Gen3Script.MOVEMENT_STEP_END:
			row["finished"] = true
			Gen3ObjectEvents.freeze(object)
		elif not objects.set_held_movement(object, action):
			row["at"] = int(row["at"]) + 1
