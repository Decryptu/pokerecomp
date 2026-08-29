class_name Gen2WorldScreen
extends Control

## Cartridge-backed overworld screen.
##
## A validated world snapshot is authoritative. The explicit map and cell are
## retained as a development entry point for scene tests and cache inspection.

const BACKGROUND: Color = Color("#09111f")
const TEXT: Color = Color("#f4f7fb")
const MUTED: Color = Color("#9eacc0")
const BATTLE_SCENE: PackedScene = preload("res://game/battle/battle_screen.tscn")
const FLOWER_MAIL: int = 0xB6

const SERVICE_SCENE: PackedScene = preload("res://game/world/world_service_screen.tscn")
const START_MENU_SCENE: PackedScene = preload("res://game/world/start_menu_screen.tscn")
const PARTY_SCENE: PackedScene = preload("res://game/save/party_screen.tscn")
## The launcher is this port's boot menu and the save screen is its title
## screen, so a cartridge taken out goes to the first and a console reset to the
## second, where CONTINUE is.
const LAUNCHER_SCENE: String = "res://game/main/main.tscn"
const SAVE_SCENE: String = "res://game/save/save_screen.tscn"
const AUDIO_PLAYER_SCRIPT := preload("res://game/audio/gen2_audio_player.gd")
## How far into a view switch's close [method preview_view_cover] photographs:
## part way down the scatter, where the wipe is readable and the screen is not
## yet black.
const PREVIEW_COVER_FRAMES: int = 10
## constants/sfx_constants.asm's SFX_JUMP_OVER_LEDGE (comments there are hex,
## confirmed against neighbouring $0a/$0f/$1a), played by .TryJump as the hop
## starts. Played directly rather than through _handle_audio_request(), which
## expects a runtime request to acknowledge; a hop is movement, not a script.
## _play_current_map_music() below is the precedent for this shape.
const SFX_JUMP_OVER_LEDGE: int = 0x16
## constants/sfx_constants.asm's SFX_PLACE_PUZZLE_PIECE_DOWN, played by
## OWCutAnimation before its sprite animation. The animation itself is not
## rendered here; the sound is. Not SFX_CUT, which is $38 and is the battle
## move's own effect: the field animation shares the Unown puzzle's sound.
const SFX_CUT: int = Gen2UnownPuzzle.SFX_PLACE_PIECE
## constants/sfx_constants.asm's SFX_SURF, which is what PlayWhirlpoolSound plays
## (engine/events/field_moves.asm); there is no whirlpool-specific effect.
const SFX_WHIRLPOOL: int = 0x53
## constants/sfx_constants.asm's SFX_STRENGTH, played by MovementFunction_Strength
## as a pushed boulder starts moving, not by the menu that sets the flag.
const SFX_STRENGTH: int = 0x1B
## constants/sfx_constants.asm's SFX_BUBBLEBEAM, which Script_UsedWaterfall plays
## after its text and before the first climbing step.
const SFX_WATERFALL: int = 0x51
## constants/sfx_constants.asm's SFX_FLASH, played by `UseFlashTextScript`'s own
## `text_asm` rather than by `BlindingFlash`, which fades in silence.
const SFX_FLASH: int = 0xA9
## constants/sfx_constants.asm's SFX_SANDSTORM, which is what ShakeHeadbuttTree
## plays (engine/events/field_moves.asm). SFX_HEADBUTT is a battle-move effect
## and is referenced by nothing in either pin's overworld code.
const SFX_HEADBUTT_TREE: int = 0x6D
## `HangUp_Beep`, the click every phone call ends on.
const SFX_HANG_UP: int = 0x6B
## `.PlayPoisonSFX`, the sound the overworld poison pass plays whether or not
## anything fainted to it.
const SFX_POISON: int = 0x0B
## constants/music_constants.asm, which AnimateHallOfFame plays over the whole
## induction.
const MUSIC_HALL_OF_FAME: int = 20

## `GetWarpSFX`: the door, the warp panel, and everything else, which is a step
## out of a building. Read off the tile the step landed on, the way
## `wPlayerTileCollision` is.
const SFX_ENTER_DOOR: int = 0x1F
const SFX_WARP_TO: int = 0x13
const SFX_EXIT_BUILDING: int = 0x23
const COLL_DOOR: int = 0x71
const COLL_WARP_PANEL: int = 0x7C
## `FadeToMapMusic`'s own `ld a, 8` into `wMusicFade`, which is what the new
## map's track arrives behind.
const WARP_MUSIC_FADE_FRAMES: int = 8

@export var map_group: int = 24
@export var map_number: int = 3
@export var start_cell: Vector2i = Vector2i(4, 4)
@export_range(0, 23) var hour: int = 6
@export_range(0, 59) var minute: int = 0
@export_range(0, 6) var day: int = 0
@export_range(0, 3) var time_of_day: int = Gen2WorldPalette.TIME_MORNING
@export var encounter_seed: int = 0

var _data: GameData = null
var _injected_data: GameData = null
var _injected_save: Gen2SaveData = null
var _world: Gen2WorldAPI = null
## Whatever the mod host supplies. Typed as Node because a registered renderer
## only has to satisfy Gen2ModHost.WORLD_RENDERER_METHODS, not extend the 2D one.
var _renderer: Node = null
var _animation: Gen2WorldAnimation = null
var _effects: Gen2WorldEffects = null
## The sprites registered mods put in the world, driven a frame at a time here
## and drawn by the renderer with the map's own objects.
var _actors: Gen2WorldActors = null
var _encounters: Gen2WorldEncounters = null
## The id of the visible encounter the running battle belongs to, so its provider
## is told how the fight ended and nothing else is.
var _battle_encounter_id: StringName = &""
## The headbutt result waiting for ShakeHeadbuttTree's 32 frames to be spent.
var _pending_headbutt_finish: Dictionary = {}
## The step in flight whose `PlayerEvents` are still owed, empty while none is.
## `CheckPlayerState` reads `PLAYERSTEP_STOP_F`, so the warp, the coord events
## and the wild roll all belong to the frame the step lands on.
var _pending_step_events: Dictionary = {}
## `MapSetupScript_Door` while it is running: `{ stage, step, frames, cell }`,
## empty on every other frame. The map swaps between the two stages, which is
## where the setup script's own list sits.
var _map_fade: Dictionary = {}
## The fade one of the five fade specials is inside, `{ orders, white_fill,
## step_frames, step, frames }`, and the row it left behind once it is done. A
## `FadeOutToWhite` holds the screen white until its own `FadeInFromWhite` runs,
## so the last row of a finished fade stays applied rather than snapping back.
var _script_fade: Dictionary = {}
var _script_fade_order: int = Gen2WorldPalette.FADE_IDENTITY
var _script_fade_white: bool = false
## `DoBattleTransition` and the battle it is in front of: the encounter is
## resolved when the transition starts, and the battle screen is not built until
## it has finished.
var _battle_transition: Gen2BattleTransition = null
var _battle_transition_request: Dictionary = {}
## `wLandmarkSignTimer` and the window the sign is drawn in. The map load decides
## whether there is a sign (`Gen2WorldAPI.map_name_sign_pending`); the sixty
## passes it stands for are spent here, like every other overworld countdown.
var _map_name_sign: TextureRect = null
var _map_name_sign_passes: int = 0
## `wOverworldDelay`, counted down a hardware frame at a time so `HandleMap`
## runs once per [member Gen2WorldAPI.FRAMES_PER_OVERWORLD_PASS] of them.
var _overworld_delay: int = 0
var _text_box: Gen2TextBox = null
var _text_box_rect: Rect2i = Rect2i()
var _text_box_rect_pushed: bool = false
var _text_box_rect_held: int = 0
var _clock: Gen2WorldClock = null
var _audio_player: Gen2AudioPlayer = null
var _audio_waiting: bool = false
var _script_prompt: String = ""
var _story_picture: TextureRect = null
## `engine/menus/menu_2.asm`'s balance window, up until `closetext` redraws the
## map behind it.
var _money_window: TextureRect = null
## `SelectMonFromParty` opened by a special rather than by the start menu: which
## request is waiting on the answer, empty when the list belongs to the menu.
var _party_selection: Dictionary = {}
var _battle_host: Gen2BattleScreen = null
var _trainer_card_host: Gen2TrainerCardScreen = null
## `START_ACTION_OPEN_MOD_PAGE`'s screen, which is a mod's own list.
var _mod_page_host: Gen2ModPageScreen = null
var _pokedex_host: Gen2PokedexScreen = null
## `wPrevDexEntry`, which is plain WRAM rather than saved data: it survives the
## dex closing and reopening for as long as the game runs, the way the start
## menu cursor below survives its own screen.
var _pokedex_prev_entry: int = 0
var _service_host: Gen2WorldServiceScreen = null
var _start_menu_host: Gen2StartMenuScreen = null
var _party_host: Gen2PartyScreen = null
var _hall_of_fame_host: Gen2HallOfFameScreen = null
## `LinkCommunications`' own screen: the Trade Center's two-list menu and the
## link record sign. The Colosseum runs through the battle host instead.
var _link_host: Gen2LinkScreen = null
## The peer a Colosseum battle is being fought against, for the record
## `AddLastLinkBattleToLinkRecord` writes when it ends.
var _link_battle_peer: Dictionary = {}
## Which save slot the cable was last built for. The peer is another file on
## disk, so it is read once per slot rather than on every party refresh.
var _link_transport_slot: int = -2
var _credits_host: Gen2CreditsScreen = null
## `EvolveAfterBattle`'s own screen, opened on the overworld after a battle that
## was won and by an evolution stone from the pack.
var _evolution_host: Gen2EvolutionScreen = null
## What the evolution pass has to run when its screen closes: the pack's own
## continuation, or nothing for the after-battle pass.
var _evolution_after: Callable = Callable()
## The party the open pass applies to, which is the fought save rather than
## whatever is selected while the screen is up.
var _evolution_save: Gen2SaveData = null
## `OverworldHatchEgg`'s screen and the save whose party it has already written.
var _hatch_host: Gen2EggHatchScreen = null
var _hatch_save: Gen2SaveData = null
## `GiveANickname_YesNo`'s screen, standing between `givepoke` staging the
## request and the party host applying it.
var _nickname_host: Gen2NicknamePromptScreen = null
var _nickname_answer: String = ""
## Raised by the screenshot driver alone, which opens the prompt with no
## `givepoke` behind it and so has no request to complete when it closes.
var _nickname_preview: bool = false
## `special NameRater`'s screen and the save whose party row it may rename.
var _name_rater_host: Gen2NameRaterScreen = null
var _name_rater_save: Gen2SaveData = null
## `special MoveDeletion`'s screen. It needs no save of its own beside it: the
## moves and their PP belong to the save it was handed and it writes them itself.
var _move_deleter_host: Gen2MoveDeleterScreen = null
var _move_tutor_host: Gen2MoveTutorScreen = null
## `MoveTutor`'s answer, held between the screen's `finished` and its `closed`
## the way the Day-Care's is.
var _move_tutor_script_value: int = Gen2MoveTutor.SCRIPT_VALUE_CANCELLED
## The Day-Care's five routines, all one screen. It edits the save's party and
## the world state directly, which is what `DepositBreedmon` and `RetrieveBreedmon`
## do, so the save it was handed is kept beside it only to write nothing else.
var _day_care_host: Gen2DayCareScreen = null
var _unown_puzzle_host: Gen2UnownPuzzleScreen = null
var _diploma_host: Gen2DiplomaScreen = null
var _unown_printer_host: Gen2UnownPrinterScreen = null
var _slot_machine_host: Gen2SlotMachineScreen = null
var _card_flip_host: Gen2CardFlipScreen = null
## What `DayCareManOutside` left in wScriptVar, held between the screen finishing
## and the request completing. -1 while no routine has written one.
var _day_care_script_value: int = -1
## The renewal question a Repel running out asks, which the cartridge has no
## line for: Gen II never offers one. Authored here beside the save menu's own
## four, and the item is the one a registered provider chose rather than the one
## that wore off.
const REPEL_RENEWAL_TEXT: String = "REPEL wore off!\nUse a %s?"

## Whether a field-move message is on screen waiting for its acknowledge. The
## world is idle while it is, the same way a script text pause holds it.
var _field_move_text: bool = false
## The item the standing renewal question would spend, 0 while none is up. See
## [method _offer_repel_renewal].
var _repel_renewal_item: int = 0
## `MonMailAction`'s own two questions and the member whose mail they are about.
## `.take` asks `.MailAskSendToPCText` and, when that is refused, `.RemoveMail
## ToBag` asks `.MailLoseMessageText`: two `YesNoBox`es in a row, so which one is
## open has to be remembered as well as who it is about.
const MAIL_TAKE_NONE: int = 0
const MAIL_TAKE_ASK_PC: int = 1
const MAIL_TAKE_ASK_BAG: int = 2
var _mail_take_slot: int = -1
var _mail_take_stage: int = MAIL_TAKE_NONE
var _mail_take_name: String = ""
## `ReadPartyMonMail`'s screen, which the MAIL submenu opens over the party list.
var _mail_host: Gen2MailScreen = null

## `MonMailAction`'s six `text_far` stubs, in `data/text/common_2.asm`. Kept
## here rather than imported for the same reason BILL'S PC's own two are: no
## script points at them, so there is no table to walk.
const MAIL_ASK_SEND_TO_PC_TEXT: String = "Send the removed\nMAIL to your PC?"
const MAIL_SENT_TO_PC_TEXT: String = "The MAIL was sent\nto your PC."
const MAILBOX_FULL_TEXT: String = "Your PC's MAILBOX\nis full."
const MAIL_LOSE_MESSAGE_TEXT: String = "The MAIL will lose\nits message. OK?"
const MAIL_NO_SPACE_TEXT: String = "There's no space\nfor removing MAIL."
const MAIL_DETACHED_TEXT: String = "MAIL detached from\n%s."
## `PlayerEventScriptPointers`: an engine script the overworld runs on its own
## rather than out of a map. Each entry is one `writetext`/`waitbutton` pair and
## [member _player_event_after] is whatever the script does past its last one,
## so the blackout's two ways in spend the same presses in the same order.
var _player_event_texts: PackedStringArray = PackedStringArray()
var _player_event_after: Callable = Callable()
## Whether the text on screen owes a press of its own. A `writetext` whose last
## page ends in `<DONE>` does not: `MapTextbox` prints and returns, and the
## press is the `waitbutton` behind the command.
var _text_awaits_press: bool = true
## How many presses [method preview_text_scroll] will spend looking for one.
const PREVIEW_TEXT_PRESSES: int = 8
## `ProfOaksPCBoot`'s three texts, one page at a time, and the sfx `Rate` leaves
## for it to play once the last of them is up.
var _oak_pc_pages: Array = []
var _oak_pc_sfx: int = -1
## `DisplayUnownWords`' box, up until the `JoyWaitAorB` behind it is answered.
var _unown_wall_box: TextureRect = null
## Mirrors the source's wBattleMenuCursorPosition surviving a reopen.
var _start_menu_cursor: int = 0
## `.MenuReturns`' first entry, `.Reopen`: Pokedex, Pokemon, Pokegear and the
## trainer card all return 0 from their `StartMenu_*` handler, so the menu is
## drawn again rather than closed. Set when the menu opened the screen, so a
## Pokegear reached by a script or by the debug key still returns to the world.
var _reopen_start_menu: bool = false
var _trainer_approach: Dictionary = {}
var _active_battle_save: Gen2SaveData = null
## `wBattleScriptFlags` bit 7, which `Script_loadtrainer` sets and
## `Script_reloadmapafterbattle` reads: a trainer fight is the branch
## `MomTriesToBuySomething` sits on, a wild one the branch Bill does.
var _active_battle_trainer: bool = false
## How many battles this run has started, which is what a replay compares beside
## the party: a route that fought and one that walked past the grass reach
## different states for the same reason.
var _battles_fought: int = 0
## What the last one resolved to (`Gen2WorldBattleAdapter.OUTCOME_*`), which is
## the fight's own result rather than the party's: a lost battle heals the party
## on the way out, so the outcome is what says the turn resolved at all.
var _last_battle_outcome: StringName = &""
## The audio driver's rendered-frame count as of the last frame, for the one
## script wait that reads it. See [method Gen2AudioPlayer.timeline_updates].
var _audio_rendered_seen: int = 0
## How many frames it has stood still for, against
## [constant Gen2AudioPlayer.SERVICE_GAP_FRAMES].
var _audio_still_frames: int = 0
## Which of `HangUp`'s seven writes is on the box, so each is written once
## rather than every frame of its twenty.
var _hang_up_phase: StringName = &""
var _active_battle_persist: bool = false
var _encounter_random := RandomNumberGenerator.new()
## NPC movement rolls from its own generator, so a seeded route keeps the same
## encounters and script results however long the player stands watching.
var _object_random := RandomNumberGenerator.new()
## The Day-Care's rolls, from a stream of their own for the same reason.
var _breed_random := RandomNumberGenerator.new()
var _selected_rod: StringName = Gen2WorldEncounter.METHOD_OLD_ROD
## The overworld's hardware-frame clock: see [method _process].
var _frame_clock := Gen2WorldAnimation.FrameClock.new()
var _pass_moved: bool = false
## `(frame, button)` input, recorded from a run and played back into another.
## Both are opt-in and off in play. A replay applies a log's entries on the frame
## that recorded them, from inside the pump, so a host that owes two frames
## delivers the input of both rather than only of the later one; that is what
## makes a replay independent of the frame rate it was recorded at.
var _input_recording: Array = []
var _recording_input: bool = false
var _input_replay: Dictionary = {}
var _replaying_input: bool = false
## What a replay is holding down, in place of the runtime's own poll.
var _replay_held_direction: int = Gen2Button.NONE
## Whether a frame is being spent right now, which is what tells a press
## delivered from inside the pump from one that arrived between two frames.
var _spending_frame: bool = false
## A run of sounds the world owes the driver, spent one entry at a time by
## [method advance_frame]: `HealMachineAnim`'s, whose entries are due on a frame
## count of their own, and the ITEMFINDER's, whose are `WaitPlaySFX` and due when
## the four effect channels are free. Nothing plays two at once, since the script
## that started one is waiting on it.
var _sound_schedule: Array = []
var _sound_schedule_frame: int = 0
## Whether a screen laid out in 160x144 owns the picture, as last told to the
## renderer, and whether it has been told at all: [method _apply_interface_mask]
## runs every frame, and a renderer swapped in mid-scene has heard nothing.
var _interface_owned: bool = false
var _interface_owned_pushed: bool = false

@onready var _screen: Gen2Screen = %Screen
@onready var _caption: Label = %Caption
@onready var _hint: Label = %Hint

## The debug caption without its frame-rate tail, and that tail. The readout is
## rebuilt on a map, a step or a script, and the rate once a second, so the two
## are kept apart rather than rebuilding the whole line every drawn frame.
var _caption_text: String = ""
var _rate_text: String = ""
var _rate_reading: Dictionary = {}


func _ready() -> void:
	# The map and cell readout and the shortcut legend are scaffolding, and they
	# are also the two things standing between the player and a full screen on a
	# phone. Same flag as the shortcuts they describe. The scene keeps them
	# hidden, so a release build never draws the placeholder text for the frame
	# between the node entering the tree and this line.
	_caption.visible = Gen2DebugKeys.enabled()
	_hint.visible = Gen2DebugKeys.enabled()
	_data = _injected_data if _injected_data != null else _selected_runtime_data()
	_build_world()
	var input: Gen2InputRuntime = Gen2InputRuntime.instance()
	if input != null and not input.reset_chord_pressed.is_connected(_on_reset_chord):
		input.reset_chord_pressed.connect(_on_reset_chord)
	if input != null and not input.back_requested.is_connected(_on_back_requested):
		input.back_requested.connect(_on_back_requested)


## Why the overworld could not be built, on the two labels the debug readout
## otherwise owns. Shown in every build, unlike the readout: a release that hid
## this left the player a black screen with no reason on it. Every caller
## returns straight after, so nothing overwrites it with the readout.
func _show_load_failure(reason: String, detail: String) -> void:
	_set_caption(reason)
	_hint.text = detail
	_caption.visible = true
	_hint.visible = true


func _set_caption(text: String) -> void:
	_caption_text = text
	_caption.text = _caption_text + _rate_text


## The reading changes once a second and the line is rebuilt only then, so this is
## drawn on the frame it is measuring. `lock` shows only when there is one; `sub`
## is screen pixels to a hardware one, and 1:1 is none of the smoothing reaching
## the panel. See [method Gen2WorldAnimation.FrameClock.rate].
func _refresh_frame_rate() -> void:
	if _world == null or _caption == null or not _caption.visible:
		return
	var rate: Dictionary = _frame_clock.rate()
	if rate.is_empty() or rate == _rate_reading:
		return
	_rate_reading = rate
	var lock: int = int(rate["lock"])
	var steps: int = _screen.subpixel_steps()
	_rate_text = "   %.0f fps   hw %.0f/s   worst %.1f ms%s   sub 1:%d" % [
		float(rate["fps"]), float(rate["hardware"]), float(rate["worst_ms"]),
		"" if lock < 1 else "   lock 1:%d" % lock, steps,
	]
	_caption.text = _caption_text + _rate_text


## The two scaffolding labels off, for a capture that is diffed against a
## cartridge frame pixel for pixel rather than looked at.
func hide_debug_readout() -> void:
	if _caption != null:
		_caption.visible = false
	if _hint != null:
		_hint.visible = false


## Supplies a cache-backed data source before the scene enters the tree. The
## launcher continues to use GameRuntime; this boundary lets scene tests and
## development tools exercise an explicitly selected cache without mutating
## global runtime selection.
func set_data(data: GameData) -> void:
	_injected_data = data


## Supplies an optional validated save for a scene test or development tool.
## Normal gameplay still reads the selected slot from GameRuntime.
func set_save(save: Gen2SaveData) -> void:
	_injected_save = save


## The run's seed, in the order a run can claim one: the slot that recorded it,
## the snapshot it was opened from, the scene's own development export, then a
## fresh roll. Whatever wins is written back to the slot, so a run is
## reproducible from the frame it started rather than from the next save.
func _resolve_run_seed(save: Gen2SaveData) -> int:
	var value: int = 0
	if save != null and save.run_seed != 0:
		value = save.run_seed
	elif _world.random_seed != 0:
		value = _world.random_seed
	elif encounter_seed != 0:
		value = encounter_seed
	else:
		var rolled := RandomNumberGenerator.new()
		rolled.randomize()
		while value == 0:
			value = rolled.randi()
	if save != null:
		save.run_seed = value
		if save.run_mods.is_empty():
			save.run_mods = Gen2ModHost.instance().loaded_mods()
	return value


func _build_world() -> void:
	if _data == null:
		_show_load_failure(
			"No imported cache", "Import a supported cartridge first."
		)
		return

	var selected_save: Gen2SaveData = _injected_save if _injected_save != null else _selected_runtime_save()
	var initial_day: int = day
	var initial_hour: int = hour
	var initial_minute: int = minute
	## A world opened for a save plays that save's rules, whoever opened it.
	## `Gen2GameRuntime._activate_rules` installs the slot's own set when the
	## launcher chooses one, and nothing does when a test or a tool injects one
	## through [method set_save]: a Nuzlocke slot then played as the cartridge's
	## own game, which is the one difference a rules block exists to make.
	var save_rules: Gen2Rules = selected_save.run_rules if selected_save != null else null
	if selected_save != null and selected_save.world != null:
		_world = Gen2WorldAPI.open_snapshot(_data, selected_save.world, save_rules)
		if _world == null:
			_show_load_failure(
				"Saved overworld unavailable",
				"The saved map or player position is not valid for this cache.",
			)
			return
		## The RTC ran while the game was closed, so a save opens at the time it
		## was written at plus the real seconds since (`Gen2WorldClock.catch_up`).
		var saved_clock: Dictionary = Gen2WorldClock.catch_up(
			selected_save.world.world_day, selected_save.world.world_hour,
			selected_save.world.world_minute, selected_save.world.world_clock_stamp
		)
		initial_day = int(saved_clock.get("day", initial_day))
		initial_hour = int(saved_clock.get("hour", initial_hour))
		initial_minute = int(saved_clock.get("minute", initial_minute))
		## `TryLoadSaveFile`'s own `RestoreMysteryGift`, and `Continue`'s
		## `CopyMysteryGiftReceivedDecorationsToPC` behind it: a gift received
		## at the menu with no file open reaches the file here, and a
		## decoration that came with one reaches the PC.
		_world.state.set_mystery_gift(selected_save.mystery_gift)
		Gen2MysteryGift.restore(_world.state.mystery_gift())
		Gen2MysteryGift.copy_decorations_to_pc(
			_world.state.mystery_gift(), _data, _world.state
		)
	elif selected_save != null:
		var saveless_state := Gen2WorldState.new()
		Gen2WorldSpawn.apply_initial_decorations(saveless_state)
		_world = Gen2WorldAPI.open(
			_data, map_group, map_number, start_cell, saveless_state, save_rules
		)
	else:
		var development_state := Gen2WorldState.new(
			{}, {}, {
				Gen2WorldInventory.ITEM_OLD_ROD: 1,
				Gen2WorldPartyHost.ITEM_POKE_BALL: 1,
			}
		)
		## `InitDecorations` runs at new game, so a world the screen builds
		## without a saved one still stands in the room the player's own game
		## would put them in rather than in a bedroom with no bed.
		Gen2WorldSpawn.apply_initial_decorations(development_state)
		_world = Gen2WorldAPI.open(
			_data, map_group, map_number, start_cell, development_state
		)
	if _world == null:
		_show_load_failure(
			"Map %d/%d unavailable" % [map_group, map_number],
			"Choose an imported map and starting cell in the scene settings.",
		)
		return
	_refresh_party_summary()
	var run_seed: int = _resolve_run_seed(selected_save)
	_encounter_random.seed = run_seed
	## One seed, two streams: the second is offset so the object generator is not
	## a replay of the encounter one.
	_object_random.seed = run_seed + 1
	_breed_random.seed = run_seed + 2
	_world.random_seed = run_seed

	_world.schedule_random = _encounter_random
	_world.script_random = _encounter_random
	_world.object_random = _object_random
	_world.breed_random = _breed_random
	## `--clock=HH:MM` beats both the export defaults and the save's own, and
	## holds the clock there for the run: see [method Gen2WorldClock.pin].
	var pinned_clock: Dictionary = Gen2WorldClock.pin()
	if not pinned_clock.is_empty():
		initial_day = int(pinned_clock["day"])
		initial_hour = int(pinned_clock["hour"])
		initial_minute = int(pinned_clock["minute"])
	_clock = Gen2WorldClock.new(initial_hour, initial_minute, initial_day)
	_clock.pinned = not pinned_clock.is_empty()
	time_of_day = _clock.time_of_day()
	_animation = Gen2WorldAnimation.new()
	_effects = Gen2WorldEffects.new()
	_actors = Gen2WorldActors.new()
	_actors.set_actors(Gen2ModHost.instance().world_actors())
	## The cut leaves ride BattleAnimSineWave, which is cartridge data rather
	## than a table this could derive.
	var anim_data: Gen2BattleAnimData = Gen2BattleAnimData.from_game_data(_data)
	_effects.set_sine_table(anim_data)
	_world.set_world_clock(initial_day, initial_hour, initial_minute)
	_world.set_object_time(initial_hour, time_of_day)
	## After the clock, since the tables a provider is handed are the ones this
	## time of day resolves to.
	_encounters = Gen2WorldEncounters.new()
	_encounters.set_providers(Gen2ModHost.instance().visible_encounter_providers())
	## What [method Gen2ModHost.inventory] reads while this world is open. Bound
	## here rather than handed the world, so a mod is given the copy and never a
	## way to write the bag.
	Gen2ModHost.instance().set_inventory_source(_mod_inventory)
	Gen2ModHost.instance().set_hidden_items_source(_mod_hidden_items)
	Gen2ModHost.instance().set_progress_source(_mod_progress)
	_encounters.set_world(_world, anim_data)
	_actors.set_encounters(_encounters)
	var rods: Array[StringName] = _world.available_fishing_rods()
	if not rods.is_empty() and not rods.has(_selected_rod):
		_selected_rod = rods[0]
	_animation.configure(_world, _render_time_of_day())
	_apply_screen_fill()
	_build_renderer()
	Gen2ModHost.instance().view_changed.connect(_on_view_changed)
	_screen.view_size_changed.connect(_on_view_size_changed)
	_audio_player = AUDIO_PLAYER_SCRIPT.new()
	_audio_player.name = "AudioPlayer"
	add_child(_audio_player)
	_play_current_map_music()
	_text_box = Gen2TextBox.new()
	# The overworld owns the frame, so the reveal is spent in [method
	# advance_frame] with everything else the frame draws rather than on a second
	# clock only real time turns.
	_text_box.driven = true
	_text_box.font = Gen2Font.from_data(_data)
	_apply_text_box_options()
	_text_box.place_at_bottom()
	_text_box.visible = false
	_text_box.item_rect_changed.connect(_push_text_box_rect)
	_text_box.visibility_changed.connect(_push_text_box_rect)
	_screen.display(_text_box)
	_apply_renderer_interface_style()
	var entry_results: Array = _world.dispatch_map_entry()
	if not entry_results.is_empty():
		_show_script_results(entry_results)
	_hand_over_second_screen()
	_refresh_labels()


## Hands this world to the lower display, where the build has one.
##
## The display itself belongs to [Gen2GameRuntime] and is up in the launcher too;
## all this screen owns is which world is on it. Handed back on the way out, so
## closing a game puts the launcher's own mark back rather than leaving the last
## frame of a world nobody is playing.
func _hand_over_second_screen() -> void:
	var runtime: Gen2GameRuntime = Gen2GameRuntime.instance()
	if runtime != null:
		runtime.set_second_screen_world(_data, _world, active_save())


func _exit_tree() -> void:
	Gen2ModHost.instance().set_progress_source(Callable())
	var runtime: Gen2GameRuntime = Gen2GameRuntime.instance()
	if runtime != null:
		runtime.set_second_screen_world(null, null, null)


## Builds the view for the selected renderer and attaches it to the layer that
## renderer asked for.
##
## Constructed through the mod host, so a registered renderer replaces this view
## without the screen knowing what it draws with. A renderer answering the
## surface question false gets the screen's rectangle at window resolution
## instead of the hardware viewport, which is what a 3D or HD view needs; text
## boxes and menus above it stay hardware pixels either way.
func _build_renderer() -> void:
	if _world == null:
		return
	if _renderer != null:
		if _screen.native_size_changed.is_connected(_on_native_size_changed):
			_screen.native_size_changed.disconnect(_on_native_size_changed)
		_renderer.get_parent().remove_child(_renderer)
		Gen2Screen.drop(_renderer)
	_renderer = Gen2ModHost.instance().create_world_renderer()
	if Gen2ModHost.renderer_uses_hardware_viewport(_renderer):
		# The map fills whatever buffer SCREEN FILL gave it, so it takes the
		# buffer's own origin rather than the hardware rectangle inside it.
		_screen.display_content(_renderer, true)
	else:
		_screen.display_native(_renderer)
		_screen.native_size_changed.connect(_on_native_size_changed)
		_on_native_size_changed(_screen.native_size())
	if _renderer.has_method(Gen2ModHost.RENDERER_EFFECTS_METHOD):
		_renderer.call(Gen2ModHost.RENDERER_EFFECTS_METHOD, _effects)
	if _renderer.has_method(Gen2ModHost.RENDERER_ACTORS_METHOD):
		_renderer.call(Gen2ModHost.RENDERER_ACTORS_METHOD, _actors)
	if _renderer.has_method(Gen2ModHost.RENDERER_ENCOUNTERS_METHOD):
		_renderer.call(Gen2ModHost.RENDERER_ENCOUNTERS_METHOD, _encounters)
	## SMOOTH SCROLL again: a pass drawn a pixel at a time still steps a whole
	## hardware pixel, twelve screen ones on a laptop panel. A native view is
	## already at the window's resolution. See [member Gen2Screen.subpixel].
	_screen.subpixel = Gen2OptionsStore.current().smooth_scroll \
		and Gen2ModHost.renderer_uses_hardware_viewport(_renderer)
	_set_renderer_world()
	_renderer.set_time_of_day(_render_time_of_day())
	_apply_renderer_interface_style()


## The map under the player changed, or the view was created: the renderer and
## the mod actors are both told, since an actor is handed the same
## [Gen2WorldAPI] a renderer is and has to drop whatever it was following on the
## map it has just left.
func _set_renderer_world() -> void:
	if _world == null:
		return
	if _renderer != null:
		_renderer.set_world(_world, _animation)
	if _actors != null:
		_actors.set_world(_world)
	if _encounters != null:
		_encounters.set_world(_world)


## The text box is the screen's, not the renderer's, and over a native-layer view
## the cartridge's opaque white field is a slab across the map. A renderer may
## ask for it to be drawn through, and may be told where it is so it can compose
## around it. Both are pushed here and again whenever the box moves, resizes or
## is shown, since a renderer swapped in mid-scene has neither.
func _apply_renderer_interface_style() -> void:
	if _text_box == null:
		return
	_text_box.field_opacity = Gen2ModHost.renderer_interface_opacity(_renderer)
	# A renderer swapped in mid-scene has no rectangle, so this one is not deduped.
	_text_box_rect_pushed = false
	_push_text_box_rect()
	_interface_owned_pushed = false
	_apply_interface_mask()


## Pushed only when the rectangle actually changes, and never while a page turn
## is between the box it just closed and the box the next event opens: a renderer
## composing around the box would otherwise pan away and back inside one
## conversation. A conversation that really ends pushes the empty rectangle once,
## because the empty one differs from the occupied one it replaces.
func _push_text_box_rect() -> void:
	if _text_box == null or _text_box_rect_held > 0:
		return
	var rect: Rect2i = _text_box.occupied_rect()
	if _text_box_rect_pushed and rect == _text_box_rect:
		return
	_text_box_rect = rect
	_text_box_rect_pushed = true
	Gen2ModHost.renderer_set_text_box_rect(_renderer, rect)


## What the renderer actually draws with, which is not always the clock: a dark
## cave stays dark until Flash is used and looks like night afterwards. See
## [method Gen2WorldPalette.map_time_of_day].
func _render_time_of_day() -> int:
	if _world == null:
		return time_of_day
	return _world.map_time_of_day()


## SCREEN FILL: the overworld has more to show than the hardware framed, so it
## fills the window with map where every other screen fills it with its own field.
## Every menu, box and cursor over it stays inside the 160x144 rectangle
## [Gen2Screen] centres in the buffer. The setting itself is the screen's and is
## taken again here rather than trusted from the frame the screen was born on: a
## tool that stages a framed shot sets the option around building this scene, and
## either order has to mean the same thing. The zoom is the map's alone.
func _apply_screen_fill() -> void:
	var options: Gen2Options = Gen2OptionsStore.current()
	_screen.apply_screen_fill()
	if _screen.expanded:
		_screen.zoom_step = options.zoom_step
	_on_view_size_changed(_screen.view_size())
	_apply_interface_mask()


## A screen that hides the map takes the whole picture with it: it is laid out in
## 160x144 and has nothing to put in a wider buffer, so the surround becomes that
## screen's own field. The start menu is not one of these, being a box the map is
## still visible around, and neither is a map fade. `DoBattleTransition` is: it
## writes twenty by eighteen cells and nothing wider. The mask is drawn inside the
## hardware viewport, so raising it would crop a renderer that already filled the
## whole surface; such a renderer is told instead and closes its own surround,
## which is the only way a wedge reaches the edge of a filled window.
func _apply_interface_mask() -> void:
	var owned: bool = _battle_transition != null or _any_host_open(FULLSCREEN_HOSTS)
	_screen.interface_masked = _screen.expanded and owned \
		and Gen2ModHost.renderer_uses_hardware_viewport(_renderer)
	if _interface_owned_pushed and owned == _interface_owned:
		return
	_interface_owned = owned
	_interface_owned_pushed = true
	Gen2ModHost.renderer_set_interface_masked(_renderer, owned)


func _on_view_size_changed(size_pixels: Vector2i) -> void:
	if _world == null:
		return
	if _world.view_pixels == size_pixels:
		return
	_world.view_pixels = size_pixels
	if _renderer != null and _renderer.has_method(&"refresh"):
		_renderer.refresh()


func _on_native_size_changed(size_pixels: Vector2i) -> void:
	if _renderer != null \
		and _renderer.has_method(Gen2ModHost.RENDERER_RESIZE_METHOD):
		_renderer.call(Gen2ModHost.RENDERER_RESIZE_METHOD, size_pixels)
	Gen2ModHost.renderer_set_screen_rect(_renderer, _screen.screen_rect())


## Switches the live view without disturbing the world behind it. The choice is
## the whole view rather than the overworld's half of it, so a fight started
## after this is drawn by the same mod: nothing about the map, the player or the
## running script changes, because a renderer only ever reads them.
func select_view(id: StringName) -> Dictionary:
	var result: Dictionary = Gen2ModHost.instance().select_view(id)
	if not bool(result.get("ok", false)):
		_script_prompt = "Renderer unavailable: %s" % String(result.get("reason", "unknown"))
		_refresh_labels()
		return result
	_script_prompt = "Renderer: %s" % Gen2ModHost.instance().view_label(id)
	_refresh_labels()
	return result


## Spends the whole of a view switch's cover now, for a caller that wants the
## renderer swapped rather than the swap shown: a tool taking a photograph.
func settle_view_cover() -> void:
	_screen.settle_view_cover()


## The switch itself, wherever it was made: this screen, the launcher's mod page
## or the start menu's own row. The renderer is built inside the cover rather
## than here, because building one is a stall of its own.
func _on_view_changed(_id: StringName) -> void:
	_screen.play_view_cover(_build_renderer)


## Selects the view after the current one, wrapping. One key can then cycle every
## installed view, which is how a mod's 3D world is reached with no launcher.
func cycle_view() -> Dictionary:
	var host: Gen2ModHost = Gen2ModHost.instance()
	var ids: Array[StringName] = host.view_ids()
	if ids.size() < 2:
		_script_prompt = "No other renderer is registered"
		_refresh_labels()
		return {"ok": false, "reason": &"single_renderer"}
	var at: int = ids.find(host.selected_view())
	return select_view(ids[posmod(at + 1, ids.size())])


## Real time becomes hardware frames here and nowhere else in the overworld.
## Everything that counts frames is spent by [method advance_frame], so GAME
## SPEED reaches all of it through the clock; the day cycle underneath is the one
## deliberate reader of `delta`, because Gen II keeps a real-time clock and a
## wall-clock reading is what the day cycle wants at any speed.
func _process(delta: float) -> void:
	for _frame: int in _frame_clock.tick(delta):
		advance_frame()
	_apply_pass_fraction(_frame_clock.remainder())
	_refresh_frame_rate()
	_advance_day_cycle(delta)
	## Every drawn frame rather than every hardware frame: above sixty a drawn
	## frame can carry no hardware one, and a screen opened by the press that
	## drawn frame served would show the map around it until the next.
	_apply_interface_mask()


## SMOOTH SCROLL. Where the drawn frame stands in the pass: whole frames off
## `NextOverworldFrame`'s countdown plus the part of the next one the clock has
## banked. Banked real time and not a frame count, because a tick spends
## sometimes no frame and sometimes two and a count alone jumps 0, 1 or 2 pixels
## for nothing. Called every drawn frame, not every spent one.
func _apply_pass_fraction(remainder: float = 0.0) -> void:
	if _world == null:
		return
	var before: float = _world.pass_fraction
	## Clamped: a world that has spent no frame reads zero, a whole pass.
	var spent: float = clampf(
		float(Gen2WorldAPI.FRAMES_PER_OVERWORLD_PASS - _overworld_delay),
		0.0, float(Gen2WorldAPI.FRAMES_PER_OVERWORLD_PASS - 1)
	)
	_world.pass_fraction = 0.0 if not Gen2OptionsStore.current().smooth_scroll \
		else (spent + clampf(remainder, 0.0, 1.0)) \
			/ float(Gen2WorldAPI.FRAMES_PER_OVERWORLD_PASS)
	## Only while the pass is moving something, so a still map is drawn once.
	_refresh_if(_pass_moved and _world.pass_fraction != before)


## Spends [param count] hardware frames. Public beside [method advance_frame] so
## a test, a preview tool or a replay settles the world on the frames it owes
## rather than on a clock.
func advance_frames(count: int) -> void:
	for _frame: int in maxi(0, count):
		advance_frame()


## Every host that runs inside the map's own loop, member and the method that
## spends its frame. Their `DelayFrames` counts come from this pump rather than
## from real time, which is what makes a fight, a hatch or a trade inside a
## replay reach the same place on the same frame.
const FRAME_HOSTS: Array[Array] = [
	## `PlayRadioShow` runs from the Pokegear's own loop, so an open radio card
	## spends this frame too rather than counting one of its own.
	["_service_host", "advance_frame"],
	["_battle_host", "advance_hardware_frame"],
	["_evolution_host", "advance_frame"],
	["_link_host", "advance_frame"],
	["_hatch_host", "advance_frame"],
	["_nickname_host", "advance_frame"],
	["_name_rater_host", "advance_frame"],
	["_move_deleter_host", "advance_frame"],
	["_move_tutor_host", "advance_frame"],
	["_day_care_host", "advance_frame"],
	["_unown_puzzle_host", "advance_frame"],
	["_slot_machine_host", "advance_frame"],
	["_card_flip_host", "advance_frame"],
]


## One hardware frame of the overworld, in the order it is drawn. Every countdown
## is spent exactly once here, so each is a function of
## [member Gen2WorldAPI.frame_number] rather than of banked real time. Half of
## what follows is `HandleMap`'s own pass and runs once per two frames; the other
## half is what a command spends its own `DelayFrames` on and is not gated.
func advance_frame() -> void:
	_spending_frame = true
	## `ResetOverworldDelay` and `NextOverworldFrame`: the pass reloads the delay
	## and then spends it, so the first frame of a world is a pass and every
	## FRAMES_PER_OVERWORLD_PASS-th frame after it is the next one.
	_overworld_delay -= 1
	var map_pass: bool = _overworld_delay <= 0
	if map_pass:
		_overworld_delay = Gen2WorldAPI.FRAMES_PER_OVERWORLD_PASS
		_pass_moved = false
	_advance_presentation(map_pass)
	_apply_pass_fraction()
	_advance_movement(map_pass)
	_advance_population(map_pass)
	_advance_waits(map_pass)
	for row: Array in FRAME_HOSTS:
		var host: Object = get(row[0])
		if host != null:
			host.call(row[1])
	_spending_frame = false


## Redraws when [param moved] says something under the renderer changed.
func _refresh_if(moved: bool) -> void:
	if moved and _renderer != null:
		_pass_moved = true
		_renderer.refresh()


## The text box, the fades, the transition and the two animation timers, none of
## which the pass gates: they are what the source spends its own `DelayFrames`
## on from inside a command, plus VBlank's `GameTimer` and `AnimateTileset`.
func _advance_presentation(map_pass: bool) -> void:
	if _text_box != null:
		_text_box.accelerated = Gen2Button.text_accelerating()
		_text_box.advance_frame()
	if _world != null:
		_world.advance_frame_counter()
		if _replaying_input:
			_apply_replayed_input(_world.frame_number)
	_advance_game_time_frame()
	## Before everything the map draws: the fade owns the frame the map swaps on,
	## and nothing else runs while `RunMapSetupScript` is spending its own.
	_advance_map_fade()
	_advance_script_fade()
	## `DoBattleTransition`'s own `.loop`, which owns every frame between the
	## encounter and the battle screen.
	_advance_battle_transition()
	## Here as well as in [method _process]: a driver that spends frames without
	## a clock -- a test, a preview, a replay -- never reaches the other one.
	_apply_interface_mask()
	## `RefreshMapSprites` runs inside the setup script and `PlaceMapNameSign`
	## with the rest of the map's background, so a sign raised by the load this
	## frame carried is spent from the next one.
	if map_pass:
		_advance_map_name_sign_pass()
		## One reading a world pass, which is the rate the overworld itself runs
		## at. Costs nothing while no mod is watching.
		Gen2ModHost.instance().refresh_progress()
	_raise_map_name_sign()
	if _effects != null:
		var effects_moved: bool = _effects.advance_frame()
		if map_pass:
			effects_moved = _effects.advance_pass() or effects_moved
		_refresh_if(effects_moved)
	## `AnimateTileset` is VBlank's, not the pass's, so the water and the flowers
	## animate on every frame while the objects standing on them move on passes.
	if _animation != null and _animation.advance_frame() and _renderer != null:
		_renderer.refresh_animation()


## `GetJoypad` and `PlayerEvents` are both inside the pass, so a held direction
## starts a step on a pass and never between two. `MapEvents` starts the step and
## `HandleMapObjects` moves it in the same pass, so a walk begun from standing
## covers its first two pixels on the pass the press landed on.
func _advance_movement(map_pass: bool) -> void:
	if map_pass:
		_advance_forced_movement()
		_advance_held_direction()
		var stepped: bool = _world != null and _world.advance_player_step_pass()
		_refresh_if(stepped)
		## `CheckPlayerState` reads the step flags at the end of `HandleMap`,
		## after `HandleMapObjects`, so the step that finishes on this frame is
		## the one whose events this frame runs.
		if not _pending_step_events.is_empty() and _world != null \
			and not _world.player_step_in_progress():
			var landed: Dictionary = _pending_step_events
			_pending_step_events = {}
			_complete_player_step(landed)
		## Polled again on the pass a step lands on: the poll above ran while the
		## step was still in flight and refused it, so a held direction started the
		## next step a pass late and the walk froze a frame and doubled the next.
		if stepped and _world != null and not _world.player_step_in_progress():
			_advance_held_direction()
	## Not the pass's: an emote's own countdown stands in for the `pause` between
	## `ShowEmoteScript`'s two movements, and a script's `DelayFrames` is spent
	## from inside the command rather than by `NextOverworldFrame`.
	_refresh_if(_world != null and _world.advance_emotes_frame())


## Everything drawn on the map that is not the player. Wilds move after the
## player's own step, so an actor reading `player_step_offset_cells()` sees this
## frame, and before the actors, which draw its population.
func _advance_population(map_pass: bool) -> void:
	## Gated on the same predicate the map's own objects step behind, so a
	## provider's frame count is the time the player spent on the overworld: a
	## population stands still behind a battle, a menu, a text box and a fade.
	## Not the pass's: a wild is drawn between cells like an object mid-step.
	if _encounters != null and _objects_may_move() and _encounters.advance_frame():
		_play_encounter_sounds()
		_refresh_if(true)
	## Deliberately not gated with it: an actor owns no state the host validates
	## and is drawn only on the frames the map is, so an animation running behind
	## an overlay costs a mod nothing and freezing one would strand a walk cycle
	## mid-step.
	_refresh_if(_actors != null and _actors.advance_frame())
	_spend_actor_requests()
	_spend_hidden_item_requests()
	_spend_item_gift_requests()
	_spend_notice_requests()
	if not map_pass:
		return
	_refresh_if(_objects_may_move() and _world.advance_object_steps_pass(_object_random))
	# Not gated on _objects_may_move(): an applymovement is drawn while the
	# script that ran it is still going, which is when a script runs one.
	_refresh_if(_world != null and _world.advance_scripted_steps_pass())
	# After both trails: `ShakeGrass` is called where the step starts, so a
	# rustle taken now belongs to a step begun on this frame.
	_spawn_grass_rustles()


## What a frame owes something already waiting on it, each behind the trail it
## waits for.
func _advance_waits(map_pass: bool) -> void:
	if not _pending_headbutt_finish.is_empty() \
		and (_effects == null or not _effects.sprites_active()):
		var headbutt: Dictionary = _pending_headbutt_finish
		_pending_headbutt_finish = {}
		_finish_headbutt(headbutt)
	# After the trail, because the frame it finishes drawing is the frame the
	# script waiting on it resumes.
	if _world != null and not _world.pending_script_wait().is_empty():
		_draw_hang_up()
		var wait_results: Array = _world.advance_script_wait_frame()
		if not wait_results.is_empty():
			_show_script_results(wait_results)
	_advance_sound_schedule()
	## `_ContText`'s scroll ends on a frame rather than on a press, and the page
	## it lands on may be the text's last, which is where the script runs on.
	_continue_if_text_settled()
	if not _trainer_approach.is_empty():
		_advance_trainer_approach(map_pass)
	if _world != null and _world.phone_ring_active():
		var ring_results: Array = _world.advance_phone_ring_frame()
		if not ring_results.is_empty():
			_show_script_results(ring_results)
		_refresh_labels()
	_advance_audio_wait()


## The one wait whose condition is the audio device's rather than a counter's.
## The same rule the battle's `ANIM_WAIT_SFX` follows: a driver nobody is
## servicing leaves `effect_playing()` true for the rest of the run, so the
## rendered-frame count is what decides whether this is a wait at all.
func _advance_audio_wait() -> void:
	var audio_rendered: int = _audio_player.timeline_updates() if _audio_player != null else 0
	_audio_still_frames = 0 if audio_rendered != _audio_rendered_seen \
		else _audio_still_frames + 1
	_audio_rendered_seen = audio_rendered
	if not _audio_waiting or _audio_player == null:
		return
	if _audio_player.effect_playing() \
		and _audio_still_frames <= Gen2AudioPlayer.SERVICE_GAP_FRAMES:
		return
	_audio_waiting = false
	var audio_result: Dictionary = Gen2WorldHost.complete_runtime_request(
		_world, {"ok": true, "sound_finished": true}
	)
	if bool(audio_result.get("ok", false)):
		_show_script_results(audio_result.get("results", []))


## Whether a battle owns the screen right now. Public beside
## [method battles_fought] so a tool driving a run knows which of the two funnels
## its presses are going through, and so a replay can compare the count.
func battle_active() -> bool:
	return _battle_host != null


func battles_fought() -> int:
	return _battles_fought


func last_battle_outcome() -> StringName:
	return _last_battle_outcome


## The save this run is playing, which is what a fight writes its party back into.
## The injected one for a test or a tool, the runtime's selected slot otherwise.
func active_save() -> Gen2SaveData:
	if _active_battle_save != null:
		return _active_battle_save
	return _injected_save if _injected_save != null else _selected_runtime_save()


## Starts recording every button the world consumes, discarding any earlier log.
## What a run has to be replayable beside its seed: see [method replay_input] and
## `tools/replay_world.gd`.
func record_input() -> void:
	_input_recording = []
	_recording_input = true


## The recorded `(frame, kind, button)` entries, in the order they were consumed.
func input_recording() -> Array:
	return _input_recording.duplicate(true)


## Plays a recorded log back into this world instead of reading the input
## runtime. Every entry is applied on the frame it names, from inside the pump.
func replay_input(entries: Array) -> void:
	_input_replay = {}
	for raw: Variant in entries:
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw
		var frame: int = int(entry.get("frame", 0))
		var at: Dictionary = _input_replay.get(frame, {"hold": Gen2Button.NONE, "presses": []})
		if String(entry.get("kind", "")) == "hold":
			at["hold"] = int(entry.get("button", Gen2Button.NONE))
		else:
			(at["presses"] as Array).append(int(entry.get("button", Gen2Button.NONE)))
		_input_replay[frame] = at
	_replaying_input = true


func _apply_replayed_input(frame: int) -> void:
	var at: Dictionary = _input_replay.get(frame, {})
	_replay_held_direction = int(at.get("hold", Gen2Button.NONE))
	for button: int in at.get("presses", []) as Array:
		press_button(button)


## The Generation 2 day cycle, which is the one thing here that is not a frame
## count: the cartridge reads a real-time clock, so [Gen2WorldClock] takes real
## seconds and a replay holds it rather than converting it.
func _advance_day_cycle(delta: float) -> void:
	if _clock == null or _world == null:
		return
	var ticks: Array = _clock.advance(delta, _world)
	_world.set_world_clock(_clock.day, _clock.hour, _clock.minute)
	_apply_pokerus_days(ticks)
	if ticks.is_empty():
		return
	_update_time_of_day()
	if not _overlay_open() and not _world.script_input_waiting():
		var phone_schedule: Dictionary = _world.advance_phone_schedule(
			ticks.size(), _encounter_random
		)
		var phone_results: Array = phone_schedule.get("results", [])
		if bool(phone_schedule.get("attempted", false)) and not phone_results.is_empty():
			_show_script_results(phone_results)
	_refresh_labels()


## `.CheckTile`'s forced walk, which the source polls every frame with no input: a
## waterfall pushes the player back down and a door, staircase or cave tile steps
## them off it. The step already in progress paces it.
## PLAYERMOVEMENT_FORCE_TURN is drained here too: `.CheckTile` reads the standing
## tile before `.GetAction`'s direction is honoured, so a whirlpool spits the
## player back out with nothing pressed. Its own run is what stops it repeating,
## since the cell it leaves them on is not a whirlpool.
func _advance_forced_movement() -> void:
	if not _objects_may_move() or _world.script_input_waiting() \
		or _world.player_step_in_progress():
		return
	if StringName(_world.forced_movement().get("kind", &"none")) == &"none":
		return
	var forced: Dictionary = _world.advance_forced_movement()
	if bool(forced.get("ok", false)):
		_after_player_move(forced)


## Walking goes on while a direction is held, whatever is holding it: a key, a
## stick, a d-pad or a thumb on the on-screen controller.
##
## Polled rather than driven by repeated events, because the rate a held key
## repeats at belongs to the operating system and has nothing to do with the
## hardware. The poll runs once per hardware frame, which is what the source
## did, and [method move_player] refuses while a step is still in flight, which
## is what turns sixty polls a second into one step every sixteen frames.
func _advance_held_direction() -> void:
	## Polled before the pauses below rather than after, so a recording is what
	## was held rather than what the world did with it.
	var direction: int = _replay_held_direction if _replaying_input \
		else Gen2InputRuntime.instance().held_direction()
	if _recording_input and _world != null and direction != Gen2Button.NONE:
		_input_recording.append({
			"frame": _world.frame_number, "kind": "hold", "button": direction,
		})
	if not _objects_may_move() or _world.script_input_waiting() \
		or _world.player_step_in_progress():
		return
	## `.CheckForced` sits in front of `.GetAction` in all three of
	## `.TranslateIntoMovement`'s branches, so a player standing on ice keeps
	## walking with nothing held at all and a held direction is only obeyed when
	## `.GetAction` tests it before the slide's own.
	var held: Vector2i = Vector2i.ZERO if direction == Gen2Button.NONE \
		else Gen2Button.vector(direction)
	var walking: Vector2i = _world.effective_input_direction(held)
	if walking != Vector2i.ZERO:
		move_player(walking)
		return
	## A poll that commits nothing reaches `.StandInPlace`, which is what stops a
	## slide from resuming after the player has stepped off the ice.
	_world.note_standing_still()


## Every embedded screen that hides the map, named once for the two readers
## below: adding an overlay to one list by hand is what the Cut and Hall of Fame
## work each paid for. The start menu is a box the map is still visible around.
const FULLSCREEN_HOSTS: Array[StringName] = [
	&"_battle_host",
	&"_service_host",
	&"_party_host",
	&"_hall_of_fame_host",
	&"_trainer_card_host",
	&"_mod_page_host",
	&"_link_host",
	&"_pokedex_host",
	&"_credits_host",
	&"_evolution_host",
	&"_hatch_host",
	&"_nickname_host",
	&"_name_rater_host",
	&"_move_deleter_host",
	&"_move_tutor_host",
	&"_day_care_host",
	&"_unown_puzzle_host",
	&"_slot_machine_host",
	&"_card_flip_host",
	&"_diploma_host",
	&"_unown_printer_host",
	&"_mail_host",
]


func _any_host_open(host_names: Array[StringName]) -> bool:
	for host_name: StringName in host_names:
		if get(host_name) != null:
			return true
	return false


## Whether any embedded screen is up. The six callers below each need a different
## set of the other pauses, but they all need this one.
func _overlay_open() -> bool:
	## A map fade is not an overlay, but nothing may move or be pressed inside
	## one either: `RunMapSetupScript` runs with the joypad unread.
	return not _map_fade.is_empty() or _battle_transition != null \
		or _start_menu_host != null or _any_host_open(FULLSCREEN_HOSTS)


## Wandering objects keep to themselves while anything else owns the world: a
## trainer approach paces its own object by call count, and an overlay hides the
## map entirely. A script is not by itself one of those things, which is
## `Gen2WorldAPI.script_stops_the_map()`: the frames it spends in a wait are
## `HandleMap`'s own, so the map keeps walking around an `applymovement` except
## for the objects that command froze.
func _objects_may_move() -> bool:
	return _world != null and not _overlay_open() \
		and not _field_move_text and _oak_pc_pages.is_empty() \
		and _trainer_approach.is_empty() \
		and not _world.script_stops_the_map() \
		and not _world.phone_ring_active() \
		and not _world.fishing_busy()


## Every control the cartridge had arrives here as a [Gen2Button], whichever
## device produced it. What is left over is a development shortcut or something
## only a renderer could want.
func _unhandled_input(event: InputEvent) -> void:
	if _world == null:
		return
	var button: int = Gen2Button.pressed_in(event)
	if button != Gen2Button.NONE:
		if press_button(button):
			accept_event()
		return
	## The dex area's SELECT, the credits' A and B and the Unown puzzle's
	## directions are held states rather than presses, and those three overlays
	## are the only ones with anything to do with a release.
	var released: int = Gen2Button.released_in(event)
	if released != Gen2Button.NONE and _unown_puzzle_host != null:
		_unown_puzzle_host.release_button(released)
		accept_event()
		return
	if released != Gen2Button.NONE and _pokedex_host != null:
		_pokedex_host.release_button(released)
		accept_event()
		return
	if released != Gen2Button.NONE and _credits_host != null:
		_credits_host.release_button(released)
		accept_event()
		return
	if _handle_zoom(event):
		accept_event()
		return
	if event.is_pressed() and _handle_debug_key(event):
		accept_event()
		return
	# A mod's own declared control, before the raw leftovers: the mod hears its
	# own action id rather than an InputEvent, and the same pauses that hold a
	# renderer's events hold this one.
	if _renderer_input_free():
		var action: Dictionary = Gen2ModHost.instance().action_in(event)
		if not action.is_empty():
			Gen2ModHost.instance().emit_action(
				action["id"], action["key"], bool(action["pressed"])
			)
			accept_event()
			return
	# Everything the screen wants has been claimed above, so what reaches here is
	# what a renderer may have a use for: a free camera needs pointer and stick
	# motion, and the screen has no opinion about either.
	if _renderer_input_free() and Gen2ModHost.renderer_handles_input(_renderer, event):
		accept_event()


## One button, from whichever device produced it or from a replay, and the one
## place a press is recorded. A press between two frames is consumed by the world
## at the start of the next one, which is the frame the log names.
func press_button(button: int) -> bool:
	if _world == null or button == Gen2Button.NONE:
		return false
	if _recording_input:
		_input_recording.append({
			"frame": _world.frame_number if _spending_frame else _world.frame_number + 1,
			"kind": "press",
			"button": button,
		})
	return _handle_button(button)


## Routes one button to whatever owns the screen, and reports whether anything
## took it. A pause that owns the world swallows every button rather than
## refusing the ones it has no use for, which is what keeps a stray press from
## reaching the map behind it.
## The overlays that own the whole screen, in the order a press is offered them.
const OVERLAY_HOSTS: Array[StringName] = [
	## In front of every other overlay: `EvolveAfterBattle` runs with the map
	## loop suspended, and the pack path reaches it with the pack still open
	## behind it, so its B is the animation's cancel rather than the pack's back.
	&"_evolution_host",
	## The same rule for `OverworldHatchEgg`, which `PlayerEvents` runs with the
	## map loop suspended in exactly the same place.
	&"_hatch_host",
	## `GivePoke` runs inside `givepoke`, with the map loop suspended behind the
	## script the same way, and its own naming screen is reached through it.
	&"_nickname_host",
	## `special NameRater` runs inside `opentext`, so the map loop is suspended
	## behind it the same way and its own two screens are reached through it.
	&"_name_rater_host",
	## `special MoveTutor` and `special MoveDeletion`, the same shape again.
	&"_move_tutor_host",
	&"_move_deleter_host",
	## The Day-Care's five, one screen with the same shape again.
	&"_day_care_host",
	## `special UnownPrinter`, which owns the whole screen until B off its list.
	&"_unown_printer_host",
	## `special Diploma`, which owns the whole screen until a button, and
	## `special PrintDiploma`, which owns it until B.
	&"_diploma_host",
	## `special UnownPuzzle`, which owns the whole screen until START or the
	## last piece.
	&"_unown_puzzle_host",
	## `special SlotMachine`, which owns the whole screen until the player says
	## no to another game or runs out of coins.
	&"_slot_machine_host",
	## `special CardFlip`, the Game Corner's other machine, which owns the screen
	## on the same terms.
	&"_card_flip_host",
	## Before the PC and the party overlay because the Hall of Fame is the one
	## overlay a script opens with nothing behind it: there is no map to go back
	## to until it has finished, and it takes no cancel.
	&"_link_host",
	&"_hall_of_fame_host",
	&"_credits_host",
	## `ReadPartyMonMail`, which `MonMailAction` opens over the party list and
	## comes back to: it owns the screen while it is up.
	&"_mail_host",
	&"_party_host",
]

## The overlays that answer for themselves; a press one refuses reaches the map.
const ANSWERING_HOSTS: Array[StringName] = [
	&"_pokedex_host",
	&"_trainer_card_host",
	&"_mod_page_host",
	&"_start_menu_host",
	&"_service_host",
]


func _handle_button(button: int) -> bool:
	## First, because a battle hides the map entirely and owns every button while
	## it does. The fight takes it through this funnel rather than reading events
	## of its own, so a press inside a battle is recorded once, by the world, and
	## a replayed log reaches the fight (`tools/replay_world.gd`).
	if _battle_host != null:
		_battle_host.press_button(button)
		return true
	if _input_locked():
		return true
	for host_name: StringName in OVERLAY_HOSTS:
		var host: Object = get(host_name)
		if host != null:
			host.call(&"handle_button", button)
			return true
	if _handle_prompt_button(button):
		return true
	for host_name: StringName in ANSWERING_HOSTS:
		var host: Object = get(host_name)
		if host != null:
			return bool(host.call(&"handle_button", button))
	if _world.fishing_busy():
		if button == Gen2Button.A:
			_handle_fishing_result(_world.advance_fishing())
		return true
	if _world.script_input_waiting():
		if button == Gen2Button.A:
			_advance_script_pause()
		return true
	## The d-pad first, because `DoPlayerMovement` runs in front of
	## `CheckStandingOnIce` in `OWPlayerInput` and has already decided what a
	## direction means while a slide is running.
	if Gen2Button.is_direction(button):
		move_player(_world.effective_input_direction(Gen2Button.vector(button)))
		return true
	## `OWPlayerInput`'s own comment: "Can't perform button actions while sliding
	## on ice." `CheckStandingOnIce` stands in front of `CheckAPressOW` and
	## `CheckMenuOW`, so A, START and SELECT are all refused until the run ends.
	if _world.standing_on_ice():
		return true
	match button:
		Gen2Button.A:
			return interact()
		Gen2Button.START:
			_open_start_menu()
			return true
		Gen2Button.SELECT:
			open_select_menu()
			return true
	return false


## `DoBattleTransition` owns every frame between the encounter and the battle
## screen with the joypad unread, the same way a map fade does. Without it a
## press landing in those frames reached `script_input_waiting()` and cancelled
## the request `startbattle` was waiting on, so the script died with
## `invalid_battle_outcome`: the fight still ran, and the gym leader's badge, the
## flag behind it and everything after it never arrived. A player holding A
## through a trainer's approach is what does it.
func _input_locked() -> bool:
	return not _map_fade.is_empty() or not _trainer_approach.is_empty() \
		or _battle_transition != null or _world.phone_ring_active()


func _handle_prompt_button(button: int) -> bool:
	if _field_move_text:
		if button == Gen2Button.A:
			_acknowledge_field_move_text()
		return true
	if not _oak_pc_pages.is_empty():
		## `JoyWaitAorB`, which is what waits between each of the three texts.
		if button in [Gen2Button.A, Gen2Button.B]:
			_advance_prof_oaks_pc()
		return true
	if _unown_wall_box != null:
		## `DisplayUnownWords`' own `JoyWaitAorB`, and the click it plays after.
		if button in [Gen2Button.A, Gen2Button.B]:
			_close_unown_wall()
		return true
	return false

## The two OPTION rows a box reads, applied on every box rather than once:
## `Textbox` reads wTextboxFrame and `PrintLetterDelay` reads the text speed as
## each one is drawn, and the OPTION menu commits both on the press that changes
## them.
func _apply_text_box_options() -> void:
	if _text_box == null:
		return
	var options: Gen2Options = Gen2OptionsStore.current()
	_text_box.set_frame_style(options.textbox_frame)
	_text_box.reveal_speed = options.text_reveal_speed()


func _advance_script_pause() -> void:
	## Except a frame wait, which nothing but frames ends: the source is inside
	## WaitScriptMovement or a DelayFrames loop and reads no input there.
	if not _world.pending_script_wait().is_empty():
		return
	if _text_box != null and _text_box.visible:
		_advance_script_input()
		return
	if StringName(_world.pending_script_input().get("type", &"")) in [&"choice", &"menu"]:
		_script_prompt = "Host choice required: call choose_script_input(choice)"
		_refresh_labels()
		return
	if _world.pending_runtime_request().is_empty():
		_show_script_results(_world.run_event_queue(true))
		return
	var pending_request: Dictionary = _world.pending_runtime_request()
	if StringName(pending_request.get("kind", &"")) == &"audio_requested":
		var audio_results: Array = _handle_audio_request(pending_request)
		if not audio_results.is_empty():
			_show_script_results(audio_results)
		return
	var host_result: Dictionary = _complete_pending_request()
	if bool(host_result.get("ok", false)):
		_show_script_results(host_result.get("results", []))
		return
	_script_prompt = "Host unavailable: %s" % String(host_result.get("reason", "unknown"))
	_refresh_labels()


## One pending runtime request answered by the host with the selected save,
## which is the same call whether a press asked for it or nothing did.
func _complete_pending_request(result: Dictionary = {"ok": true}) -> Dictionary:
	var pending_save: Gen2SaveData = _injected_save if _injected_save != null \
		else _selected_runtime_save()
	return Gen2WorldHost.complete_runtime_request(
		_world, result, pending_save, _injected_save == null, _encounter_random
	)


## A request that spends no press on the cartridge, settled where it is staged.
## Empty when the host refused it, which leaves the caller its own prompt: a
## save with no party heals nothing, and that is a reason, not a press.
func _complete_unattended_request() -> Array:
	var settled: Dictionary = _complete_pending_request()
	if not bool(settled.get("ok", false)):
		_script_prompt = "Host unavailable: %s" % String(settled.get("reason", "unknown"))
		return []
	return settled.get("results", [])


## Zoom, on the keys every map program uses for it and on the wheel.
##
## Only while the map itself has the screen: a text box, a menu or a script is
## laid out against the 160x144 rectangle and moving the surface under one is
## the player losing their place. A framed screen refuses the step, since there
## is no more world to show and it would only shrink the picture
## ([method Gen2Screen.step_zoom]), and so does a view on the native layer, which
## has no hardware pixel for the ladder to count.
func _handle_zoom(event: InputEvent) -> bool:
	if not _renderer_input_free() or not _screen.expanded:
		return false
	## A view that declined the hardware buffer has no hardware pixel to scale:
	## the ladder's unit is screen pixels per one of those, and what a step moves
	## is a buffer that renderer never draws into. Its zoom is its camera's own
	## registered action, and leaving the event alone is what reaches it.
	if not Gen2ModHost.renderer_uses_hardware_viewport(_renderer):
		return false
	var delta: int = 0
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.keycode:
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				delta = 1
			KEY_MINUS, KEY_KP_SUBTRACT:
				delta = -1
			KEY_0, KEY_KP_0:
				_screen.reset_zoom()
				_persist_zoom()
				return true
	var wheel := event as InputEventMouseButton
	if wheel != null and wheel.pressed:
		if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
			delta = 1
		elif wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			delta = -1
	if delta == 0:
		return false
	_screen.step_zoom(delta)
	_persist_zoom()
	return true


func _persist_zoom() -> void:
	var options: Gen2Options = Gen2OptionsStore.current()
	if options.zoom_step == _screen.zoom_step:
		return
	options.zoom_step = _screen.zoom_step
	Gen2OptionsStore.save(options)


## Scaffolding that reaches parts of the world no cartridge control does: the
## rods, the phone list, the renderer switch and a snapshot write. Debug builds
## only, so a shipped game offers exactly the eight buttons the hardware had.
## Every method behind them stays public, which is how the preview tools drive
## the same paths without a key press.
func _handle_debug_key(event: InputEvent) -> bool:
	if not Gen2DebugKeys.enabled():
		return false
	var key: InputEventKey = event as InputEventKey
	if key == null:
		return false
	match key.keycode:
		KEY_1:
			select_fishing_rod(0)
		KEY_2:
			select_fishing_rod(1)
		KEY_3:
			select_fishing_rod(2)
		KEY_F:
			start_fishing()
		KEY_P:
			_open_phone_list()
		KEY_V:
			cycle_view()
		KEY_F5:
			var saved: Dictionary = persist_world_snapshot()
			_script_prompt = "World saved" if bool(saved.get("ok", false)) else "Save failed"
			_refresh_labels()
		_:
			return false
	return true


## Whether the overworld itself is idle. An event reaches the renderer only
## after the same overlays, pauses and hosts have each refused it.
func _renderer_input_free() -> bool:
	return _world != null and not _overlay_open() and not _field_move_text \
		and _oak_pc_pages.is_empty() and _trainer_approach.is_empty() \
		and not _world.phone_ring_active() and not _world.fishing_busy() \
		and not _world.script_input_waiting()


func move_player(direction: Vector2i) -> bool:
	if _world == null or _overlay_open() or _world.fishing_busy() \
		or _field_move_text or not _oak_pc_pages.is_empty() \
		or _world.phone_ring_active() \
		or not _trainer_approach.is_empty() or _world.script_busy() \
		or _world.player_step_in_progress():
		return false
	var movement: Dictionary = _world.player_input_move(direction)
	if not bool(movement.get("ok", false)):
		## A push bumps the player and starts the boulder, so the step reports
		## blocked while the map still changed. MovementFunction_Strength plays
		## SFX_STRENGTH here, not the menu that set the flag.
		if movement.has("boulder_pushed"):
			_play_sfx(SFX_STRENGTH)
			var pushed: Dictionary = movement["boulder_pushed"]
			if _effects != null:
				## SpawnStrengthBoulderDust runs where MovementFunction_Strength
				## starts the slide, and the dust tracks the boulder from there.
				_effects.start_boulder_dust(
					int(pushed["index"]), pushed["to_cell"], pushed["direction"],
					Gen2WorldAPI.STEP_PASSES_BOULDER_PUSH,
				)
			if _renderer != null:
				_renderer.refresh()
			_refresh_labels()
		return false
	## A whirlpool spins the player rather than moving them, so nothing a completed
	## step owes applies: no warp, no encounter, no repel step.
	## A turn on the spot costs a facing and four frames and nothing else, so it
	## owes none of what a completed step owes.
	if movement.get("kind", &"") == &"turn":
		if _renderer != null:
			_renderer.refresh()
		_refresh_labels()
		return true
	if movement.get("kind", &"") == &"forced_turn":
		if _renderer != null:
			_renderer.refresh()
		_refresh_labels()
		return true
	return _after_player_move(movement)


## What a step owes the rest of the screen on the frame it starts: the sounds
## that belong to the step itself and the redraw. Everything else waits for the
## step to land; see [method _complete_player_step]. Shared with the forced-tile
## path, which reaches it without a key press.
func _after_player_move(movement: Dictionary) -> bool:
	if movement.get("kind", &"") == &"ledge_hop":
		_play_ledge_hop_sfx()
		if _effects != null:
			## `JumpStep` spawns the shadow where the hop starts, and it tracks
			## the player over both cells of it.
			_effects.start_jump_shadow(
				-1, _world.player_cell, _world.facing_direction(),
				Gen2WorldAPI.STEP_PASSES_HOP,
			)
	## .ExitWater calls PlayMapMusic before the step, which is what drops the
	## surfing track once the player is walking again.
	if movement.get("kind", &"") == &"exit_water":
		_play_current_map_music()
	if _renderer != null:
		if movement.get("kind", &"") == &"connection":
			## `MapSetupScript_Connection`, which is the step itself rather than
			## a warp: the neighbour's blocks are loaded under a camera that
			## never stops, and its `FadeToMapMusic` is why crossing a route
			## boundary into the same track is one continuous piece. It carries
			## no `LoadMapGraphics` either, so the tile animation is re-pointed
			## at the new tileset where it stands rather than restarted.
			_animation.reload_tileset(_world, _render_time_of_day())
			_set_renderer_world()
			_fade_to_map_music()
		else:
			_renderer.refresh()
	## `CheckPlayerState` only turns `wMapEventStatus` on where the step function
	## set `PLAYERSTEP_STOP_F`, so `PlayerEvents` and everything under it run on
	## the frame the step lands rather than on the frame it was asked for. The
	## step's own frames are spent by `advance_frame`, which drains this.
	if _world != null and _world.player_step_in_progress():
		_pending_step_events = movement.duplicate(true)
		return true
	return _complete_player_step(movement)


## `PlayerEvents` for the step that has just landed: the warp it stands on, and
## then the map's own tail.
func _complete_player_step(movement: Dictionary) -> bool:
	## `CheckTileEvent` gates warps on nothing, so surfing onto a warp tile and
	## the step back onto land both reach one. `edge_warp` is
	## `DoPlayerMovement.CheckWarp`'s own answer, which has already made the
	## check `CheckWarpTile` refuses for a carpet.
	_spend_step_happiness()
	_spend_egg_steps()
	_spend_day_care_steps()
	var kind: StringName = StringName(movement.get("kind", &""))
	if kind == &"edge_warp" or (kind in [
		&"move", &"ledge_hop", &"water_move", &"exit_water", &"forced_move",
	] and _world.warp_pending()):
		## `WarpToNewMapScript`: the sound, and then `newloadmap MAPSETUP_DOOR`,
		## whose `FadeOutToWhite` runs before the map is loaded at all. The map
		## swaps when that fade lands, and everything a step still owes waits
		## for `FadeInFromWhite` behind it.
		_zero_map_name_sign_timer()
		_start_map_fade()
		return true
	return _after_map_settled()


## `StepHappiness`, which `CountStep` reaches every 256 steps and which acts on
## every second visit. [method Gen2WorldState.count_step] counts on the step
## itself, wherever it was taken; the party lives on the save, which is here.
## The cartridge raises happiness in WRAM and writes SRAM only when the player
## saves, so this touches the loaded save and persists nothing of its own.
func _spend_step_happiness() -> void:
	if _world == null or _world.state == null:
		return
	var owed: int = _world.state.take_pending_step_happiness()
	if owed <= 0:
		return
	var save: Gen2SaveData = active_save()
	if save == null:
		return
	if not Gen2WorldPartyHost.apply_step_happiness(save, owed).is_empty():
		_refresh_labels()


## `DoEggStep` and the `PLAYEREVENT_HATCH` it raises. The party lives on the
## save, so the walk counts the step and this spends it, the way
## [method _spend_step_happiness] does for `StepHappiness`.
##
## `HatchEggs` walks the whole party, so every egg the pass left on zero hatches
## in one screen rather than one per step.
func _spend_egg_steps() -> void:
	if _world == null or _world.state == null or _hatch_host != null:
		return
	var owed: int = _world.state.take_pending_egg_steps()
	if owed <= 0:
		return
	var save: Gen2SaveData = active_save()
	if save == null:
		return
	if Gen2WorldPartyHost.apply_egg_steps(save, owed) < 0:
		return
	var hatches: Array = []
	for index: int in save.party.size():
		var summary: Dictionary = Gen2WorldPartyHost.hatch_egg(_world, save, index)
		if not summary.is_empty():
			hatches.append(summary)
	if hatches.is_empty():
		return
	_open_hatch(hatches, save)


## `DoPoisonStep`, which `CountStep` reaches on the pass `wPoisonStepCount`
## carries to 4 and which resets the counter whether or not anything is
## poisoned. The party lives on the save, so the walk counts the step and this
## spends it, the way [method _spend_step_happiness] does for `StepHappiness`.
##
## Answers whether it took the screen: a faint is `PLAYEREVENT_WHITEOUT`'s own
## script, and everything a step still owes waits behind its presses.
func _spend_poison_steps() -> bool:
	if _world == null or _world.state == null or _data == null:
		return false
	if _world.state.poison_step_count() < Gen2WorldState.POISON_STEP_PHASE:
		return false
	_world.state.clear_poison_step_count()
	var save: Gen2SaveData = active_save()
	if save == null:
		return false
	var pass_result: Dictionary = Gen2WorldPartyHost.apply_poison_step(_data, save)
	if bool(pass_result.get("sfx", false)):
		_play_sfx(SFX_POISON)
	var texts: PackedStringArray = pass_result.get("texts", PackedStringArray())
	if texts.is_empty():
		if not PackedInt32Array(pass_result.get("damaged", PackedInt32Array())).is_empty():
			_refresh_labels()
		return false
	## `.CheckWhitedOut` prints every fainted member's line and only then asks
	## whether anything can still fight, so the whiteout stands behind them all.
	var lines: PackedStringArray = texts.duplicate()
	## A Nuzlocke faint is a death here too, and the poison line is the only one
	## the player sees: the row is taken off the party behind it.
	for lost: Dictionary in _reap_nuzlocke_faints(save, Gen2Nuzlocke.CAUSE_POISON):
		lines.append(Gen2Nuzlocke.death_text(Gen2Nuzlocke.grave_name(_data, lost)))
	if bool(pass_result.get("whiteout", false)):
		lines.append_array(_whiteout_texts())
		_show_player_event(lines, _finish_whiteout)
	else:
		_persist_after_poison_step(save)
		_show_player_event(lines, Callable())
	return true


## The save write the poison pass owes. `DoPoisonStep` writes WRAM and the
## cartridge commits on the player's own save, but this port keeps the party on
## disk, so a pass that moved HP is written where it happened; a whiteout writes
## once at the end of its own script instead.
func _persist_after_poison_step(save: Gen2SaveData) -> void:
	if save == null or _data == null or _injected_save != null:
		return
	var written: Dictionary = Gen2SaveStore.save(save, _data)
	if not bool(written.get("ok", false)):
		push_error("Could not save the poison step: %s" % String(written.get("message", "")))
	_refresh_labels()


## `_WhitedOutText`, with the player name the save carries, or the line that
## replaces it once a Nuzlocke has nothing left to send out.
func _whiteout_texts() -> PackedStringArray:
	var save: Gen2SaveData = active_save()
	var player_name: String = save.player_name if save != null else "<PLAYER>"
	if _nuzlocke_ends_here(save):
		return PackedStringArray([Gen2Nuzlocke.run_over_text(player_name)])
	return PackedStringArray([Gen2WorldPartyHost.whited_out_text(player_name)])


## Whether this blackout is the end of a Nuzlocke rather than a walk back to a
## Pokemon Center. A run whose every Pokemon is dead has nothing to heal: the rule
## is a full wipe ending the run, storage or no storage. Not inside the Bug
## Catching Contest: `ContestDropOffMons` masks the rest of the party into
## [member Gen2SaveData.contest_stashed_party] and leaves one Pokemon standing, so
## a faint there empties a party that is not the run's, and `Script_Whiteout`'s own
## contest branch gives the others back.
func _nuzlocke_ends_here(save: Gen2SaveData) -> bool:
	return _world != null and _world.rules != null and _world.rules.is_nuzlocke() \
		and save != null and not _world.bug_contest_active() \
		and not Gen2WorldPartyHost.party_has_fit_mon(save)


## `Script_BattleWhiteout` and `OverworldWhiteoutScript`, which differ only in
## the screen they came from: both fall into `Script_Whiteout`, so the text and
## everything behind it is one sequence here.
func _start_whiteout() -> void:
	_show_player_event(_whiteout_texts(), _finish_whiteout)


## `Script_Whiteout` past its `waitbutton`: `HealParty`, `HalveMoney`, the spawn
## and the `newloadmap MAPSETUP_WARP` behind them.
func _finish_whiteout() -> void:
	if _world == null:
		return
	var save: Gen2SaveData = active_save()
	## The Nuzlocke's own ending, in front of everything `Script_Whiteout` does:
	## nothing is healed, no money is halved and no spawn is read, because the
	## run is over rather than set back. The slot keeps what it walked to; the
	## launcher is what the player leaves through.
	if _nuzlocke_ends_here(save):
		_end_nuzlocke_run(save)
		return
	## `Script_Whiteout` tests `ENGINE_BUG_CONTEST_TIMER` after `special
	## HealParty` and before `HalveMoney`, so blacking out inside the Bug
	## Catching Contest is judged rather than paid for: no money is halved, the
	## spawn is not read, and the results gate is what the player wakes up in.
	if _world.bug_contest_active():
		Gen2WorldPartyHost.heal_party_rows(_world.data, save)
		_zero_map_name_sign_timer()
		_script_prompt = ""
		_show_script_results(_world.queue_bug_contest_results(&"whiteout"))
		return
	var recovered: Dictionary = Gen2WorldPartyHost.whiteout(
		_world, save, _injected_save == null
	)
	if not bool(recovered.get("ok", false)):
		_script_prompt = "Blackout unavailable: %s" % String(
			recovered.get("reason", "unknown")
		)
		_refresh_labels()
		return
	## `newloadmap MAPSETUP_WARP`: the spawn is on a map of its own, so the
	## renderer, the tile animation and the music all belong to it now. This is
	## the same tail an escape move owes, and `PlayerEvents` zeroes
	## `wLandmarkSignTimer` for every event but a connection and a facing change.
	_zero_map_name_sign_timer()
	_script_prompt = ""
	## `newloadmap MAPSETUP_WARP` is the whole map load, so the spawn's own
	## callbacks run and `LoadMapObjects` masks on what they wrote. Without the
	## drain the four bedroom decorations stood there, since nothing had reached
	## `ToggleDecorationsVisibility` on the map the player woke up on.
	_show_script_results(_world.run_event_queue(false))
	_refresh_after_escape()


## Ends the run for good and writes it down. Nothing else follows: the world is
## left where it fell, the save records that it is over, and every screen that
## can open a slot refuses to continue this one.
func _end_nuzlocke_run(save: Gen2SaveData) -> void:
	Gen2Nuzlocke.end_run(save.nuzlocke, _world.landmark_backup(), _world.world_day)
	_script_prompt = "The run is over."
	_zero_map_name_sign_timer()
	_refresh_labels()
	if _data == null or _injected_save != null:
		return
	var written: Dictionary = Gen2SaveStore.save(save, _data)
	if not bool(written.get("ok", false)):
		push_error("Could not save the run's end: %s" % String(written.get("message", "")))
	## The one place the overworld hands the screen back. There is nothing left
	## to play here, and the save screen is where the slot's own epitaph is: it
	## lists what the run caught and what it lost, and it will not open this one
	## again.
	if is_inside_tree():
		get_tree().change_scene_to_file.call_deferred(SAVE_SCENE)


## `Reset`, which on hardware is the four buttons wired straight to the console
## and nothing the game may decline. Nothing is written: what is on disk is what
## the last SAVE put there, which is the whole point of the shortcut.
func _soft_reset() -> void:
	if is_inside_tree():
		get_tree().change_scene_to_file.call_deferred(SAVE_SCENE)


## Offered as a B, which backs out of whatever owns the screen. Nothing on a
## bare map takes one, and a press nobody took is the pause menu.
func _on_back_requested() -> void:
	if not press_button(Gen2Button.B):
		press_button(Gen2Button.START)


## The reset chord, from anywhere the world is up. The first one ever asks first,
## over the pause menu's own box, so a player who hit four buttons by accident
## does not lose the walk between here and their last save; after that answer it
## resets where it is pressed. A fight or an overlay owning the screen has no
## room for the question, so the first chord there is refused and the second,
## once the question has been answered on the map, is not.
func _on_reset_chord() -> void:
	if _world == null:
		return
	if Gen2OptionsStore.current().soft_reset_acknowledged:
		_soft_reset()
		return
	_open_start_menu_host(func(host: Gen2StartMenuScreen) -> void:
		host.ask_soft_reset()
	)


## One player event's lines put up in order, the tail run once the last has been
## pressed past. The box and the press are the field-move message's, because a
## `writetext`/`waitbutton` pair is the same box wherever it was written.
func _show_player_event(texts: PackedStringArray, after: Callable) -> void:
	if texts.is_empty():
		_player_event_after = Callable()
		if after.is_valid():
			after.call()
		return
	_player_event_texts = texts.duplicate()
	_player_event_after = after
	var first: String = _player_event_texts[0]
	_player_event_texts.remove_at(0)
	_show_field_move_text(first)


## `DayCareStep`, which `CountStep` reaches on every step that did not hatch an
## egg: `jr nz, .hatch` jumps over the `farcall`, and the hatch screen standing
## is what says this step was one of those.
##
## The two slots live in the world state rather than on the save, so nothing here
## is a save transaction; what it can produce is `DAYCAREMAN_HAS_EGG_F`, which
## the man outside the Day-Care reads.
func _spend_day_care_steps() -> void:
	if _world == null or _world.state == null or _data == null:
		return
	var owed: int = _world.state.take_pending_day_care_steps()
	if owed <= 0 or _hatch_host != null:
		return
	for _pass: int in owed:
		Gen2WorldDayCare.step(_world.state, _data, _breed_random)


## `OverworldHatchEgg`. The rows are already written; the screen owns the
## sequence and the nickname alone.
func _open_hatch(hatches: Array, save: Gen2SaveData) -> void:
	var host := Gen2EggHatchScreen.new()
	host.set_context(_data, hatches, _nuzlocke_names_everything())
	_hatch_save = save
	host.named.connect(_on_hatch_named)
	host.closed.connect(_on_hatch_closed)
	host.cry_requested.connect(_play_species_cry)
	host.sfx_requested.connect(_play_sfx)
	host.music_requested.connect(_play_evolution_music)
	host.z_index = 30
	_hatch_host = host
	_screen.display(host)
	if _hatch_host == null:
		return
	_script_prompt = "Hatching"
	_refresh_labels()


## `InitName`, which writes whatever the naming screen left into the row's
## nickname. `.nonickname` reaches this too, with the species name.
func _on_hatch_named(party_index: int, nickname: String) -> void:
	if _hatch_save == null or party_index < 0 \
		or party_index >= _hatch_save.party.size():
		return
	var mon: Gen2SaveMon = _hatch_save.party[party_index] as Gen2SaveMon
	if mon == null:
		return
	mon.nickname = nickname
	_script_prompt = "%s hatched" % nickname


## `GivePoke`'s own prompt, for the `givepoke` sites that name no OT: thirteen
## of the fourteen, every starter among them. `GiveANickname_YesNo` stands
## between `TryAddMonToParty` and the row being named, so the request is left
## pending while the screen is up and the party host applies it with the answer.
##
## False when the routine reaches no prompt and the request may be settled where
## it was staged: an egg, a gift that names an OT, and the storage that has room
## for neither, which is `.FailedToGiveMon`.
func _open_gift_nickname(request: Dictionary) -> bool:
	if _nickname_host != null or _world == null or _data == null:
		return false
	var values: Dictionary = request.get("values", {})
	if not values.has("pokemon") or int(values.get("trainer", 0)) != 0:
		return false
	var species: int = int(values.get("pokemon", 0))
	var species_name: String = String(_data.species(species).get("name", ""))
	if species_name.is_empty():
		return false
	var save: Gen2SaveData = _injected_save if _injected_save != null \
		else _selected_runtime_save()
	var destination: StringName = Gen2WorldPartyHost.gift_destination(save)
	if destination == &"full":
		return false
	var host := Gen2NicknamePromptScreen.new()
	host.set_context(
		_data, species_name,
		Gen2WorldPartyHost.SENT_TO_BOX_FORMAT if destination == &"box" else "",
		"", _nuzlocke_names_everything()
	)
	_nickname_answer = species_name
	host.named.connect(_on_gift_named)
	host.closed.connect(_on_gift_nickname_closed)
	host.z_index = 30
	_nickname_host = host
	_screen.display(host)
	if _nickname_host == null:
		return false
	_script_prompt = "Nickname"
	_refresh_labels()
	return true


## `CheckPartyFullAfterContest`'s own `GiveANickname_YesNo`, which is the same
## question the gift path asks and reaches no "sent to BILL's PC" line: the box
## branch prints nothing and the script's `ContestResults_PartyFullText` is what
## BUGCONTEST_BOXED_MON reaches instead.
##
## False when the routine reaches no prompt: nothing was caught, and `.BoxFull`,
## which writes nothing and answers BUGCONTEST_BOXED_MON where it stands.
func _open_contest_nickname(_request: Dictionary = {}) -> bool:
	if _nickname_host != null or _world == null or _data == null or _world.state == null:
		return false
	var caught: Dictionary = _world.state.contest_mon()
	var species_name: String = String(
		_data.species(int(caught.get("species", 0))).get("name", "")
	)
	if species_name.is_empty():
		return false
	var save: Gen2SaveData = _injected_save if _injected_save != null \
		else _selected_runtime_save()
	if Gen2WorldPartyHost.gift_destination(save) == &"full":
		return false
	var host := Gen2NicknamePromptScreen.new()
	host.set_context(_data, species_name, "", "", _nuzlocke_names_everything())
	_nickname_answer = species_name
	host.named.connect(_on_gift_named)
	host.closed.connect(_on_gift_nickname_closed)
	host.z_index = 30
	_nickname_host = host
	_screen.display(host)
	if _nickname_host == null:
		return false
	_script_prompt = "Nickname"
	_refresh_labels()
	return true


## Whether every Pokemon this run receives has to carry a name. The Nuzlocke's
## third rule, and the one place the answer is spelled: the four prompts that
## ask the question read it rather than each testing the challenge.
func _nuzlocke_names_everything() -> bool:
	return _world != null and _world.rules != null and _world.rules.is_nuzlocke()


func _on_gift_named(nickname: String) -> void:
	_nickname_answer = nickname


## `InitNickname` has answered, so the row the party host is about to write
## carries the player's entry rather than `wStringBuffer1`'s species name.
func _on_gift_nickname_closed() -> void:
	var host: Gen2NicknamePromptScreen = _nickname_host
	_nickname_host = null
	if host != null:
		Gen2Screen.drop(host)
	if _renderer != null:
		_renderer.refresh()
	if _nickname_preview:
		_nickname_preview = false
		_refresh_labels()
		return
	var settled: Dictionary = _complete_pending_request({
		"ok": true, "nickname": _nickname_answer,
	})
	if not bool(settled.get("ok", false)):
		_script_prompt = "Host unavailable: %s" % String(settled.get("reason", "unknown"))
		_refresh_labels()
		return
	_show_script_results(settled.get("results", []))


func _on_hatch_closed() -> void:
	var host: Gen2EggHatchScreen = _hatch_host
	_hatch_host = null
	_hatch_save = null
	if host != null:
		Gen2Screen.drop(host)
	if _renderer != null:
		_renderer.refresh()
	_refresh_labels()


## `special NameRater`. `_NameRater` owns its own boxes and both of the screens
## it opens, so the whole routine is one host and the script stays suspended
## behind it, which is what `opentext` left it doing.
func _open_name_rater(_request: Dictionary = {}) -> bool:
	if _name_rater_host != null or _world == null or _data == null:
		return false
	var texts: Dictionary = Gen2WorldHost.name_rater_texts(_data)
	if texts.is_empty():
		_script_prompt = "Name Rater unavailable: name_rater_text_unavailable"
		return false
	var save: Gen2SaveData = _embedded_party_save()
	if save == null:
		_script_prompt = "The Name Rater needs a validated save"
		return false
	var host := Gen2NameRaterScreen.new()
	host.set_context(_data, save, texts, _world.player_name(), _world.player_id())
	host.finished.connect(_on_name_rater_finished)
	host.closed.connect(_on_name_rater_closed)
	host.z_index = 30
	_name_rater_save = save
	_name_rater_host = host
	_screen.display(host)
	_script_prompt = "Name Rater"
	_refresh_labels()
	return true


## The `CopyBytes` and the text `.done` ends on. The text is put in the world's
## own speech box rather than pressed here: `special NameRater` returns as soon
## as `PrintText` has drawn it and the script's `waitbutton` is that press.
func _on_name_rater_finished(
	party_index: int, nickname: String, ending_text: String
) -> void:
	if party_index >= 0 and _name_rater_save != null:
		Gen2WorldPartyHost.rename_party_mon(_name_rater_save, party_index, nickname)
	if not ending_text.is_empty() and _text_box != null and _text_box.font != null:
		_apply_text_box_options()
		_text_awaits_press = false
		_text_box.show_text(ending_text, false)
		_text_box.visible = true


func _on_name_rater_closed() -> void:
	var host: Gen2NameRaterScreen = _name_rater_host
	_name_rater_host = null
	_name_rater_save = null
	if host != null:
		Gen2Screen.drop(host)
	if _renderer != null:
		_renderer.refresh()
	if _world != null:
		_show_script_results(_world.complete_runtime_request({"ok": true}))
	_refresh_labels()


## The Day-Care's five specials, hosted exactly as `special NameRater` is. The
## routine writes the party, the two slots and the money itself, so nothing is
## staged: the cartridge's own routines write WRAM straight and the save is only
## committed when the player saves. Below, `special UnownPuzzle`, whose
## `FadeToMenu` and `ExitAllMenus` are what the host's own overlay already is; and
## `_Diploma`'s page, or `_PrintDiploma`'s with the printer's own status box over
## it, where the screen owns both loops and this only hands it the two things the
## page prints that the cache does not carry.
func _open_diploma(request: Dictionary) -> bool:
	if _diploma_host != null or _world == null or _data == null:
		return false
	var host := Gen2DiplomaScreen.new()
	host.z_index = 30
	## Displayed before it draws: `Gen2PicImage.show` hands the picture to the
	## screen the node stands in, and a node not in one yet tells it nothing, so
	## the surround would keep the map behind a page that fills the hardware.
	_screen.display(host)
	var save: Gen2SaveData = _injected_save if _injected_save != null \
		else _selected_runtime_save()
	var clock: Gen2GameTime = save.game_time if save != null else null
	if not host.open(
		_data, _player_display_name(),
		{
			"hours": clock.hours if clock != null else 0,
			"minutes": clock.minutes if clock != null else 0,
		},
		bool((request.get("values", {}) as Dictionary).get("printing", false))
	):
		Gen2Screen.drop(host)
		_script_prompt = "Diploma unavailable: diploma_art_unavailable"
		return false
	host.closed.connect(_on_diploma_closed)
	host.music_requested.connect(_play_music_track)
	_diploma_host = host
	## Here as well as on the next frame: a screen opened by a driver that spends
	## no frame would otherwise stand with the map around it.
	_apply_interface_mask()
	_script_prompt = "Diploma"
	_refresh_labels()
	return true


func _on_diploma_closed() -> void:
	var host: Gen2DiplomaScreen = _diploma_host
	_diploma_host = null
	if host != null:
		Gen2Screen.drop(host)
	## `Printer_RestartMapMusic`, and `ExitAllMenus` behind both specials.
	_play_current_map_music()
	_show_script_results(_world.complete_runtime_request({"ok": true}))


## `_UnownPrinter`'s browser. The dex count comes from the request rather than
## from here, so the runner and the screen answer the same `ret z`.
func _open_unown_printer(request: Dictionary) -> bool:
	if _unown_printer_host != null or _world == null or _data == null:
		return false
	var host := Gen2UnownPrinterScreen.new()
	host.z_index = 30
	_screen.display(host)
	if not host.open(
		_data, int((request.get("values", {}) as Dictionary).get("caught", 0))
	):
		Gen2Screen.drop(host)
		_script_prompt = "Unown printer unavailable: no Unown caught"
		return false
	host.closed.connect(_on_unown_printer_closed)
	host.music_requested.connect(_play_music_track)
	_unown_printer_host = host
	_apply_interface_mask()
	_script_prompt = "Unown printer"
	_refresh_labels()
	return true


func _on_unown_printer_closed() -> void:
	var host: Gen2UnownPrinterScreen = _unown_printer_host
	_unown_printer_host = null
	if host != null:
		Gen2Screen.drop(host)
	## `RestartMapMusic` behind `.pressed_b`, and `ReturnToMapFromSubmenu`.
	_play_current_map_music()
	_show_script_results(_world.complete_runtime_request({"ok": true}))


func _open_unown_puzzle(request: Dictionary) -> bool:
	if _unown_puzzle_host != null or _world == null or _data == null:
		return false
	var host := Gen2UnownPuzzleScreen.new()
	## The board is scattered from the world's own generator, so the run's seed
	## reproduces it the way it reproduces an encounter.
	if not host.open(
		_data, int((request.get("values", {}) as Dictionary).get("puzzle", 0)),
		_encounter_random
	):
		host.free()
		_script_prompt = "Unown puzzle unavailable: unown_puzzle_art_unavailable"
		return false
	host.set_audio_player(_audio_player)
	host.closed.connect(_on_unown_puzzle_closed)
	host.sfx_requested.connect(_play_sfx)
	host.z_index = 30
	_unown_puzzle_host = host
	_screen.display(host)
	_script_prompt = "Unown puzzle"
	_refresh_labels()
	return true


## `ld a, [wSolvedUnownPuzzle] / ld [wScriptVar], a`, which the chamber's own
## `iftrue` after the `closetext` branches on.
func _on_unown_puzzle_closed(solved: bool) -> void:
	var host: Gen2UnownPuzzleScreen = _unown_puzzle_host
	_unown_puzzle_host = null
	if host != null:
		Gen2Screen.drop(host)
	_script_prompt = ""
	_show_script_results(_world.complete_runtime_request({
		"ok": true, "script_value": 1 if solved else 0,
	}))


## `special SlotMachine`. `reanchormap` in front of it is what redraws the map
## behind the machine when it closes, which the host's own overlay already does.
func _open_slot_machine(request: Dictionary) -> bool:
	if _slot_machine_host != null or _world == null or _data == null:
		return false
	var values: Dictionary = request.get("values", {})
	var host := Gen2SlotMachineScreen.new()
	## The bias, the reel manipulation and both streak rolls come off the
	## world's own generator, so the run's seed reproduces a spin the way it
	## reproduces an encounter.
	if not host.open(
		_data, int(values.get("coins", _world.state.coins() if _world.state != null else 0)),
		bool(values.get("lucky", false)), _encounter_random
	):
		host.free()
		_script_prompt = "Slot machine unavailable: slots_art_unavailable"
		return false
	host.set_audio_player(_audio_player)
	host.closed.connect(_on_slot_machine_closed)
	host.sfx_requested.connect(_play_sfx)
	host.music_requested.connect(_play_music)
	host.z_index = 30
	_slot_machine_host = host
	_screen.display(host)
	_script_prompt = "Slot machine"
	_refresh_labels()
	return true


## The machine's own `wCoins`, which it has been writing all game.
func _on_slot_machine_closed(coins: int) -> void:
	var host: Gen2SlotMachineScreen = _slot_machine_host
	_slot_machine_host = null
	if host != null:
		Gen2Screen.drop(host)
	_script_prompt = ""
	## `_SlotMachine` stops `MUSIC_GAME_CORNER` nowhere, so the map's own track
	## is started again where `reanchormap` would have.
	_play_current_map_music()
	_show_script_results(_world.complete_runtime_request({
		"ok": true, "coins": coins,
	}))


## `special CardFlip`. Its objects are drawn in `wOBPals1` palette 0, which
## `CardFlip_InitAttrPals` never writes, so the map's own `PAL_OW_RED` is handed
## over with the request.
func _open_card_flip(request: Dictionary) -> bool:
	if _card_flip_host != null or _world == null or _data == null:
		return false
	var values: Dictionary = request.get("values", {})
	var host := Gen2CardFlipScreen.new()
	if not host.open(
		_data, int(values.get("coins", _world.state.coins() if _world.state != null else 0)),
		_data.overworld_sprite_palette(0, _render_time_of_day()), _encounter_random
	):
		host.free()
		_script_prompt = "Card flip unavailable: card_flip_art_unavailable"
		return false
	host.set_audio_player(_audio_player)
	host.closed.connect(_on_card_flip_closed)
	host.sfx_requested.connect(_play_sfx)
	host.music_requested.connect(_play_music)
	host.z_index = 30
	_card_flip_host = host
	_screen.display(host)
	_script_prompt = "Card flip"
	_refresh_labels()
	return true


## The table's own `wCoins`, which it has been writing all game.
func _on_card_flip_closed(coins: int) -> void:
	var host: Gen2CardFlipScreen = _card_flip_host
	_card_flip_host = null
	if host != null:
		Gen2Screen.drop(host)
	_script_prompt = ""
	## `_CardFlip` starts `MUSIC_GAME_CORNER` and stops it nowhere, so the map's
	## own track is started again where `reanchormap` would have.
	_play_current_map_music()
	_show_script_results(_world.complete_runtime_request({
		"ok": true, "coins": coins,
	}))


func _open_day_care(request: Dictionary) -> bool:
	if _day_care_host != null or _world == null or _data == null:
		return false
	var texts: Dictionary = Gen2WorldHost.day_care_texts(_data)
	if texts.is_empty():
		_script_prompt = "Day-Care unavailable: day_care_text_unavailable"
		return false
	var save: Gen2SaveData = _embedded_party_save()
	if save == null:
		_script_prompt = "The Day-Care needs a validated save"
		return false
	var host := Gen2DayCareScreen.new()
	host.set_context(
		_data, save, _world.state,
		StringName((request.get("values", {}) as Dictionary).get("role", &"man")),
		texts, _world.player_name(), _world.player_id(), _breed_random
	)
	host.finished.connect(_on_day_care_finished)
	host.closed.connect(_on_day_care_closed)
	host.cry_requested.connect(_play_species_cry)
	host.sfx_requested.connect(_play_sfx)
	host.z_index = 30
	_day_care_host = host
	_screen.display(host)
	_script_prompt = "Day-Care"
	_refresh_labels()
	return true


## `DayCareManOutside`'s own wScriptVar, and the box the map script's
## `waitbutton` presses. -1 is the four routines that write no variable.
func _on_day_care_finished(script_value: int, ending_text: String) -> void:
	_day_care_script_value = script_value
	if not ending_text.is_empty() and _text_box != null and _text_box.font != null:
		_apply_text_box_options()
		_text_awaits_press = false
		_text_box.show_text(ending_text, false)
		_text_box.visible = true


func _on_day_care_closed() -> void:
	var host: Gen2DayCareScreen = _day_care_host
	_day_care_host = null
	if host != null:
		Gen2Screen.drop(host)
	if _renderer != null:
		_renderer.refresh()
	if _world != null:
		var completion: Dictionary = {"ok": true}
		if _day_care_script_value >= 0:
			completion["script_value"] = _day_care_script_value
		_day_care_script_value = -1
		_show_script_results(_world.complete_runtime_request(completion))
	_refresh_labels()


## `special MoveDeletion`, hosted exactly as `special NameRater` is.
func _open_move_deleter(_request: Dictionary = {}) -> bool:
	if _move_deleter_host != null or _world == null or _data == null:
		return false
	var texts: Dictionary = Gen2WorldHost.move_deleter_texts(_data)
	if texts.is_empty():
		_script_prompt = "Move deleter unavailable: move_deleter_text_unavailable"
		return false
	var save: Gen2SaveData = _embedded_party_save()
	if save == null:
		_script_prompt = "The move deleter needs a validated save"
		return false
	var host := Gen2MoveDeleterScreen.new()
	host.set_context(_data, save, texts)
	host.finished.connect(_on_move_deleter_finished)
	host.closed.connect(_on_move_deleter_closed)
	host.sfx_requested.connect(_play_sfx)
	host.z_index = 30
	_move_deleter_host = host
	_screen.display(host)
	_script_prompt = "Move deleter"
	_refresh_labels()
	return true


## The screen has already written the row, since the moves and their PP belong
## to the save it was handed. What is left is the text `.done` ends on, which
## the script's own `waitbutton` presses.
func _on_move_deleter_finished(
	_party_index: int, _move_index: int, ending_text: String
) -> void:
	if ending_text.is_empty() or _text_box == null or _text_box.font == null:
		return
	_apply_text_box_options()
	_text_awaits_press = false
	_text_box.show_text(ending_text, false)
	_text_box.visible = true


func _on_move_deleter_closed() -> void:
	var host: Gen2MoveDeleterScreen = _move_deleter_host
	_move_deleter_host = null
	if host != null:
		Gen2Screen.drop(host)
	if _renderer != null:
		_renderer.refresh()
	if _world != null:
		_show_script_results(_world.complete_runtime_request({"ok": true}))
	_refresh_labels()


## `special MoveTutor`, hosted exactly as `special MoveDeletion` is. The move
## comes from the request, since `.GetMoveTutorMove` has already read the map's
## own `setval`.
func _open_move_tutor(request: Dictionary) -> bool:
	if _move_tutor_host != null or _world == null or _data == null:
		return false
	var move: int = int((request.get("values", {}) as Dictionary).get("move", 0))
	if move <= 0:
		return false
	var save: Gen2SaveData = _embedded_party_save()
	if save == null:
		_script_prompt = "The move tutor needs a validated save"
		return false
	var host := Gen2MoveTutorScreen.new()
	host.set_context(_data, _world, save, move)
	host.finished.connect(_on_move_tutor_finished)
	host.closed.connect(_on_move_tutor_closed)
	host.sfx_requested.connect(_play_sfx)
	host.z_index = 30
	_move_tutor_host = host
	_move_tutor_script_value = Gen2MoveTutor.SCRIPT_VALUE_CANCELLED
	_screen.display(host)
	_script_prompt = "Move tutor"
	_refresh_labels()
	return true


## The screen has already written the move, its PP and the happiness row. What
## is left is `LearnedMoveText`, which the map script's own `promptbutton`
## presses on the branch that reached it.
func _on_move_tutor_finished(
	script_value: int, _party_index: int, ending_text: String
) -> void:
	_move_tutor_script_value = script_value
	if ending_text.is_empty() or _text_box == null or _text_box.font == null:
		return
	_apply_text_box_options()
	_text_awaits_press = false
	_text_box.show_text(ending_text, false)
	_text_box.visible = true


func _on_move_tutor_closed() -> void:
	var host: Gen2MoveTutorScreen = _move_tutor_host
	_move_tutor_host = null
	if host != null:
		Gen2Screen.drop(host)
	if _renderer != null:
		_renderer.refresh()
	if _world != null:
		_show_script_results(_world.complete_runtime_request({
			"ok": true, "script_value": _move_tutor_script_value,
		}))
	_refresh_labels()


## Public screenshot driver for `special MoveTutor`, the same way
## [method preview_move_deleter] is. The move is MT01, the first of the three
## rows `add_mt` appends past HM07, so a cartridge without them draws nothing.
func preview_move_tutor() -> void:
	if _world == null or _data == null or _move_tutor_host != null:
		return
	var move: int = Gen2MoveTutor.move_for_value(_data, Gen2MoveTutor.VALUE_FLAMETHROWER)
	if move <= 0:
		_script_prompt = "This cartridge has no move tutor moves"
		_refresh_labels()
		return
	var save: Gen2SaveData = _embedded_party_save()
	if save == null or save.party.is_empty():
		_script_prompt = "Move tutor preview needs a party"
		_refresh_labels()
		return
	save.party[0].is_egg = false
	_injected_save = save
	_open_move_tutor({"values": {"move": move}})


## Public screenshot driver for `special MoveDeletion`, the same way
## [method preview_name_rater] is: no fixture cell reaches it.
func preview_move_deleter() -> void:
	if _world == null or _data == null or _move_deleter_host != null:
		return
	var save: Gen2SaveData = _embedded_party_save()
	if save == null or save.party.is_empty():
		_script_prompt = "Move deleter preview needs a party"
		_refresh_labels()
		return
	save.party[0].is_egg = false
	_injected_save = save
	_open_move_deleter()


## `EnterMap`'s own tail, which a warp reaches once its setup script has run and
## an ordinary step reaches on the frame it finished: the sight lines, the map's
## scripts, the two phone paths, the contest timer, and the wild roll behind all
## of them.
func _after_map_settled() -> bool:
	_refresh_labels()
	var sight_results: Array = _world.dispatch_sight_events()
	if sight_results.is_empty():
		sight_results = _world.dispatch_script_events()
	if not sight_results.is_empty():
		_zero_map_name_sign_for(sight_results)
		_show_script_results(sight_results)
		return true
	## `CheckTileEvent`'s own order: the warp and the coord events above, then
	## `CountStep`, and only then `RandomEncounter`. A poison pass that reaches a
	## script answers with carry, so the step it runs on rolls no wild, and
	## `CheckTimeEvents` below is a caller further on. `CheckSpecialPhoneCall` is
	## `CountStep`'s first test and stands in front of the counters, so the step a
	## special call rings on is charged nothing: `count_step()` already refused it,
	## and the poison pass below reads the counter that refusal left standing.
	var special_attempt: Dictionary = _world.try_special_phone_call()
	var special_results: Array = special_attempt.get("results", [])
	if bool(special_attempt.get("attempted", false)) and not special_results.is_empty():
		_zero_map_name_sign_timer()
		_show_script_results(special_results)
		return true
	if _spend_poison_steps():
		return true
	## `CountStep`'s last line, which the poison branch above jumps over when it
	## reaches a script of its own.
	_world.do_bike_step()
	var phone_attempt: Dictionary = _world.try_receive_phone_call(_encounter_random)
	var phone_results: Array = phone_attempt.get("results", [])
	if bool(phone_attempt.get("attempted", false)) and not phone_results.is_empty():
		_zero_map_name_sign_timer()
		_show_script_results(phone_results)
		return true
	## `CheckTimeEvents`' contest branch, which is read a step at a time and
	## takes the whole turn when it runs out: no encounter is rolled on the step
	## the contest ends.
	var contest_over: Array = _world.check_bug_contest_timer()
	if not contest_over.is_empty():
		_zero_map_name_sign_timer()
		_show_script_results(contest_over)
		return true
	_show_script_results([])
	## `CountStep`'s Repel countdown reaching zero, offered before
	## `RandomEncounter` and taking the step's own player event, so nothing is met
	## underneath the question.
	if _offer_repel_renewal():
		return true
	## While a provider is active the step takes no roll of its own: a wild is
	## met by walking into one. Everything else that reaches a wild, a script, a
	## rod, Headbutt, Rock Smash, Sweet Scent and the contest, keeps its own path.
	if _encounters != null and _encounters.active():
		var request: Dictionary = _encounters.battle_request_at(_world.player_cell)
		if not request.is_empty():
			_battle_encounter_id = StringName(request["visible_encounter"])
			_zero_map_name_sign_timer()
			_start_battle_request(request)
		return true
	var encounter: Dictionary = _world.encounter_request(
		_encounter_random, false, &"auto", _repel_lead_level(), _party_holds_cleanse_tag()
	)
	if not encounter.is_empty():
		## `RandomEncounter` answers `CheckTileEvent` with carry, so a wild met
		## on a step is a player event like any other.
		_zero_map_name_sign_timer()
		_start_battle_request({
			"kind": &"battle_requested",
			"values": encounter["values"],
			"encounter": encounter.duplicate(true),
		})
	return true


## The renewal offer a Repel running out owes, or false when nothing is owed.
##
## Nothing at all without a registered provider: an unregistered host answers 0
## and the step rolls exactly as it always did. The fact is held rather than
## consumed on the step it happened, so an offer landing on a step a warp, a
## script or a battle already owns waits for one that can spend it.
func _offer_repel_renewal() -> bool:
	if _world == null or _data == null or not _world.repel_expired():
		return false
	## A Repel used by hand while the offer waited has already answered it.
	if _world.repel_steps() > 0:
		_world.clear_repel_expired()
		return false
	var item: int = Gen2ModHost.instance().repel_renewal_item(_world.state.items())
	if item <= 0:
		_world.clear_repel_expired()
		return false
	if _service_host != null or _overlay_open() or _field_move_text:
		return false
	var repel: String = _data.item_name(item)
	if not _open_host_prompt(REPEL_RENEWAL_TEXT % (repel if not repel.is_empty() else "REPEL")):
		return false
	_world.clear_repel_expired()
	_repel_renewal_item = item
	return true


## YES to the renewal: the pack's own field-item transaction, so exactly one item
## is spent and its own step count applied. A mod never touches the bag.
func _renew_repel(item: int) -> void:
	_repel_renewal_item = 0
	var save: Gen2SaveData = _injected_save if _injected_save != null \
		else _selected_runtime_save()
	if save == null or _world == null:
		return
	## An injected save is a development or test one, so its item use stays in
	## memory, the same split the start menu's own pack makes.
	Gen2WorldPartyHost.use_item(_world, save, item, -1, _injected_save == null)
	_refresh_labels()


## `MapSetupScript_Door` while it is running, for a test or a preview tool that
## has to land on one of its frames: `{ stage, step, frames }`, empty on every
## other frame of the game.
func map_fade() -> Dictionary:
	return _map_fade.duplicate()


func script_fade() -> Dictionary:
	return _script_fade.duplicate()


## `WarpToNewMapScript`. `GetWarpSFX` reads the tile the step landed on, and
## `MapSetupScript_Door`'s `FadeOutToWhite` is the first thing the setup script
## spends: four palette orders, two frames each, before anything is loaded.
func _start_map_fade() -> void:
	_play_sfx(_warp_sfx())
	_map_fade = {"stage": &"out", "step": 0, "frames": Gen2WorldPalette.FADE_STEP_FRAMES}
	_apply_map_fade_step()


## `GetWarpSFX`, off `wPlayerTileCollision`.
func _warp_sfx() -> int:
	match _world.collision_code_at(_world.player_cell):
		COLL_DOOR:
			return SFX_ENTER_DOOR
		COLL_WARP_PANEL:
			return SFX_WARP_TO
	return SFX_EXIT_BUILDING


## One frame of the fade the warp is inside, spent from [method advance_frame]
## like every other countdown here. The two stages are `FadeOutToWhite` and
## `FadeInFromWhite`; the map is loaded between them, which is where the rest of
## `MapSetupScript_Door`'s list sits.
func _advance_map_fade() -> void:
	if _map_fade.is_empty():
		return
	_map_fade["frames"] = int(_map_fade["frames"]) - 1
	if int(_map_fade["frames"]) > 0:
		return
	var step: int = int(_map_fade["step"]) + 1
	var out: bool = StringName(_map_fade["stage"]) == &"out"
	if step < Gen2WorldPalette.FADE_OUT_ORDERS.size():
		_map_fade["step"] = step
		_map_fade["frames"] = Gen2WorldPalette.FADE_STEP_FRAMES
		_apply_map_fade_step()
		return
	if out:
		_swap_warped_map()
		_map_fade = {"stage": &"in", "step": 0, "frames": Gen2WorldPalette.FADE_STEP_FRAMES}
		_apply_map_fade_step()
		return
	_map_fade = {}
	_apply_map_fade_step()
	## `EnterMap` runs the map's own scripts once the setup script has finished,
	## which is the frame the fade lands on.
	_after_map_settled()


## The palette order this step of the fade draws with. `FillWhiteBGColor` is the
## fade out's alone, so the way back in flattens onto whatever the new map's own
## palette 0 holds.
func _apply_map_fade_step() -> void:
	if _renderer == null or not _renderer.has_method(Gen2ModHost.RENDERER_FADE_METHOD):
		return
	if _map_fade.is_empty():
		## The warp's fade is over; whatever a script fade left standing is what
		## the screen is drawn with, which is the identity unless one is held.
		_renderer.call(
			Gen2ModHost.RENDERER_FADE_METHOD, _script_fade_order, _script_fade_white
		)
		return
	var out: bool = StringName(_map_fade["stage"]) == &"out"
	var orders: Array[int] = Gen2WorldPalette.FADE_OUT_ORDERS if out \
		else Gen2WorldPalette.FADE_IN_ORDERS
	_renderer.call(
		Gen2ModHost.RENDERER_FADE_METHOD, orders[int(_map_fade["step"])], out
	)


## `FadeOutToWhite` and its four siblings, opened by the special and stepped from
## here. The script is already holding for the frames the fade costs, since the
## runner staged that wait; this is the row the renderer draws with on each of
## them.
func _start_script_fade(event: Dictionary) -> void:
	var orders: Array = event.get("orders", [])
	if orders.is_empty():
		return
	_script_fade = {
		"orders": orders.duplicate(),
		"white_fill": bool(event.get("white_fill", false)),
		"step_frames": maxi(1, int(event.get("step_frames", 1))),
		"step": 0,
	}
	_script_fade["frames"] = int(_script_fade["step_frames"])
	_apply_script_fade_step()


func _advance_script_fade() -> void:
	if _script_fade.is_empty():
		return
	_script_fade["frames"] = int(_script_fade["frames"]) - 1
	if int(_script_fade["frames"]) > 0:
		return
	var step: int = int(_script_fade["step"]) + 1
	if step >= (_script_fade["orders"] as Array).size():
		_script_fade = {}
		return
	_script_fade["step"] = step
	_script_fade["frames"] = int(_script_fade["step_frames"])
	_apply_script_fade_step()


func _apply_script_fade_step() -> void:
	var orders: Array = _script_fade.get("orders", [])
	var step: int = int(_script_fade.get("step", 0))
	if step >= orders.size():
		return
	_script_fade_order = int(orders[step])
	_script_fade_white = bool(_script_fade.get("white_fill", false))
	## The warp's own fade owns the renderer while it runs, so a script fade
	## under one is held rather than drawn twice.
	if _map_fade.is_empty():
		_apply_map_fade_step()


## `MapSetupScript_Door`'s own fade in ends with the map's palettes restored, so
## a row a script fade was holding is dropped where the map is.
func _clear_script_fade() -> void:
	_script_fade = {}
	_script_fade_order = Gen2WorldPalette.FADE_IDENTITY
	_script_fade_white = false


## The middle of `MapSetupScript_Door`: the map the warp names is loaded with the
## screen at its whitest, and `FadeToMapMusic` is the eight-step fade the new
## map's track arrives behind rather than a restart.
func _swap_warped_map() -> void:
	var transition: Dictionary = _world.try_warp()
	if not bool(transition.get("ok", false)):
		return
	_clear_script_fade()
	_animation.configure(_world, _render_time_of_day())
	_set_renderer_world()
	_fade_to_map_music()


## The three placings as one line. `_BugContestJudging` prints them as three
## texts of its own, which no script points at and so nothing imports; the
## placings themselves are the source's.
func _bug_contest_placings_text(judged: Dictionary) -> String:
	var parts: PackedStringArray = []
	var places: Array[String] = ["1st", "2nd", "3rd"]
	var placings: Array = judged.get("placings", [])
	for index: int in placings.size():
		var entry: Dictionary = placings[index]
		var who: String = "You" if int(entry.get("id", 0)) == Gen2WorldBugContest.PLAYER_ID \
			else "Contestant %d" % int(entry.get("id", 0))
		parts.append("%s %s, %s (%d)" % [
			places[index], who,
			String(_data.species(int(entry.get("species", 0))).get("name", "-")),
			int(entry.get("score", 0)),
		])
	return "Bug Contest: %s" % ", ".join(parts)


## `CheckRepelEffect`'s own lead: the first party member that is not fainted, or
## -1 when there is no party to read, which is what a repel compares a wild
## level against. The party lives in the save rather than in the world API, so
## the screen is the one place that can answer it.
func _repel_lead_level() -> int:
	var save: Gen2SaveData = _selected_runtime_save()
	if save == null:
		return -1
	for mon: Gen2SaveMon in save.party:
		if mon.hp > 0:
			return mon.level
	return -1


## `ApplyCleanseTagEffectOnEncounterRate` walks the whole party, fainted members
## included, and halves the rate on the first Cleanse Tag it finds.
func _party_holds_cleanse_tag() -> bool:
	var save: Gen2SaveData = _selected_runtime_save()
	if save == null:
		return false
	for mon: Gen2SaveMon in save.party:
		if mon.item == Gen2HeldItem.CLEANSE_TAG:
			return true
	return false


func interact() -> bool:
	if _world == null or _overlay_open() \
		or _field_move_text or not _oak_pc_pages.is_empty() \
		or _world.phone_ring_active() or _world.fishing_busy():
		return false
	var results: Array = _world.interact()
	if results.is_empty():
		## Only here, after every cartridge branch `PlayerEvents` tries answered
		## nothing: an actor can never shadow an object, a background event or a
		## tile branch. Its own pose is all it changes, so no player event is
		## spent and the sign timer stands.
		if _actors == null \
			or not _actors.interact(_world.facing_cell(), _world.player_facing):
			return false
		## On the frame of the press, which is what the offer promises. The
		## actor layer re-collects where the press is consumed, so nothing after
		## this sees a change to redraw for: `advance_frame` would compare a list
		## already carrying the new pose against itself and skip its own refresh,
		## and the picture would wait for the next unrelated change, which for a
		## mon icon is its two-frame flip nine frames later.
		if _renderer != null:
			_renderer.refresh()
		return true
	## `OWPlayerInput`, the last branch `PlayerEvents` tries, and a player event
	## like the rest of them.
	_zero_map_name_sign_timer()
	_show_script_results(results)
	return true


func move_right() -> void:
	move_player(Vector2i.RIGHT)


func move_left() -> void:
	move_player(Vector2i.LEFT)


func move_up() -> void:
	move_player(Vector2i.UP)


func move_down() -> void:
	move_player(Vector2i.DOWN)


## Whether the player is mid-slide, for `preview_world.gd`'s `ice_slide` kind,
## which drives until the run has started rather than spending a count.
func standing_on_ice() -> bool:
	return _world != null and _world.standing_on_ice()


## The hop's own arc, for `preview_world.gd`'s `ledge` kind, which drives to the
## top of it rather than spending a count.
func player_height_offset_pixels() -> float:
	return _world.player_height_offset_pixels() if _world != null else 0.0


## The world this screen is driving, null before one is open: a seam rather than
## the field behind it.
func world() -> Gen2WorldAPI:
	return _world


func world_snapshot() -> Dictionary:
	return {
		"map": _world.map_id() if _world != null else Vector2i(-1, -1),
		"player_cell": _world.player_cell if _world != null else Vector2i(-1, -1),
		"origin_cell": _world.visible_origin_cell() if _world != null else Vector2i(-1, -1),
		"collision": _world.collision_code_at(_world.player_cell) if _world != null else -1,
		"movement_mode": _world.movement_mode if _world != null else Gen2WorldAPI.MOVEMENT_WALK,
		"visible_objects": _world.visible_objects().size() if _world != null else 0,
		"just_battled": _world.state.just_battled() if _world != null else false,
		"fishing_state": _world.fishing_state() if _world != null else Gen2WorldFishing.STATE_IDLE,
		"swarm_map": _world.state.swarm_map() if _world != null else Vector2i(-1, -1),
		"yanma_swarm_map": _world.state.swarm_map(
			Gen2WorldState.SWARM_YANMA
		) if _world != null else Vector2i(-1, -1),
		"roaming_count": _world.state.roaming_mons().size() if _world != null else 0,
		"owned_rods": _world.available_fishing_rods() if _world != null else [],
		"owned_balls": Gen2WorldPartyHost.owned_capture_balls(_world) if _world != null else [],
		"clock": _clock.snapshot() if _clock != null else {},
		"battle_active": _battle_host != null,
		"script_prompt": _script_prompt,
	}


func world_save_snapshot() -> Gen2WorldSnapshot:
	return _world.snapshot() if _world != null else null


## Writes the current map, player and mutable world state back to the selected
## project save. Injected test saves are updated in memory instead of touching
## the user's save directory.
func persist_world_snapshot() -> Dictionary:
	if _world == null or _data == null:
		return {"ok": false, "reason": &"missing_world"}
	var save: Gen2SaveData = _injected_save if _injected_save != null else _selected_runtime_save()
	if save == null:
		return {"ok": false, "reason": &"missing_save"}
	save.world = _world.snapshot()
	## `BackupMysteryGift`, which every one of `SaveGameData`'s three entrances
	## runs: the working pair goes to the backup pair, and the backup pair is
	## what the file carries.
	Gen2MysteryGift.backup(_world.state.mystery_gift())
	save.mystery_gift = _world.state.mystery_gift().duplicate(true)
	if _injected_save != null:
		return {"ok": true, "kind": &"world_snapshot_saved", "save": save}
	return Gen2SaveStore.save(save, _data)


## `GameTimer`, one call per hardware frame. The play timer belongs to the save
## rather than to the world, since the cartridge keeps it in wPlayerData.
##
## Two source gates decide whether it counts, and neither is `_overlay_open()`:
## a battle, the pack and the start menu all keep counting. `wGameTimerPaused`
## is cleared for `Script_halloffame` alone (engine/overworld/scripting.asm:2318)
## and `wGameLogicPaused` is set by Bill's PC (engine/pokemon/bills_pc.asm:2000)
## and by saving, which costs no frames here.
func _advance_game_time_frame() -> void:
	var save: Gen2SaveData = _injected_save if _injected_save != null else _selected_runtime_save()
	if save == null or save.game_time == null:
		return
	if _hall_of_fame_host != null:
		return
	save.game_time.advance_frames(1)


## Deterministic driver for tests and screenshot tooling. The live scene uses
## the same clock through _process(delta).
func advance_world_time(seconds: float) -> Array:
	if _clock == null or _world == null:
		return []
	var ticks: Array = _clock.advance(seconds, _world)
	_world.set_world_clock(_clock.day, _clock.hour, _clock.minute)
	_apply_pokerus_days(ticks)
	if not ticks.is_empty():
		_update_time_of_day()
		_refresh_labels()
	return ticks


## `CheckPokerusTick`, which `UpdateTime` reaches with the days elapsed since the
## timer's start day. The clock here runs a minute at a time rather than being
## read off a hardware RTC, so the count is the midnights the ticks crossed.
func _apply_pokerus_days(ticks: Array) -> void:
	var days: int = 0
	for tick: Dictionary in ticks:
		if int(tick.get("hour", -1)) == 0 and int(tick.get("minute", -1)) == 0:
			days += 1
	if days <= 0:
		return
	Gen2WorldPartyHost.apply_pokerus_tick(
		_injected_save if _injected_save != null else _selected_runtime_save(), days
	)


## Public host boundary for a time/radio tick. The imported roaming graph is
## advanced once, while swarm state remains the state transaction's result.
func advance_world_schedule() -> Dictionary:
	if _world == null:
		return {"ok": false, "reason": &"missing_map"}
	var result: Dictionary = _world.advance_schedule(_encounter_random)
	_refresh_labels()
	return result


func _update_time_of_day() -> void:
	if _clock == null or _world == null:
		return
	var next_time_of_day: int = _clock.time_of_day()
	if next_time_of_day == time_of_day:
		return
	time_of_day = next_time_of_day
	_world.set_object_time(_clock.hour, time_of_day)
	if _animation != null:
		_animation.configure(_world, _render_time_of_day())
	if _renderer != null:
		_renderer.set_time_of_day(_render_time_of_day())


## Public screenshot driver for the sprites the engine draws over an object
## rather than as one. `effects` is the scripted emote, `SpawnStrengthBoulderDust`,
## `ShakeGrass` and `ShakeHeadbuttTree`; `cut` is `OWCutAnimation`'s two halves
## and the jump shadow. Each is started through the call the game makes, so this
## photographs the renderer's own path.
func preview_effect_sprites(kind: StringName = &"effects") -> void:
	if _world == null or _renderer == null:
		return
	if kind == &"cut":
		if _effects != null:
			## Both halves of `OWCutAnimation` at once, over the cell Cut would
			## clear, plus the shadow `JumpStep` spawns under a ledge hop.
			_effects.start_cut(_world.facing_cell(), 0, _world.facing_direction(), _world.player_cell)
			_effects.start_cut(_world.facing_cell(), 1, _world.facing_direction(), _world.player_cell)
			_effects.start_jump_shadow(
				-1, _world.player_cell, _world.facing_direction(),
				Gen2WorldAPI.STEP_PASSES_HOP,
			)
		_script_prompt = "Debug cut animation preview"
		_renderer.refresh()
		_refresh_labels()
		return
	if kind == &"heal_machine":
		## `HealMachineAnim` over Elm's Lab, driven to the last frame before
		## `.FlashPalettes8Times` starts: a full party is on the machine and the
		## palette is still the one `.LoadPalettes` wrote, which is the picture
		## the colours can be read off.
		if _effects != null:
			var balls: int = Gen2WorldEffects.HEAL_MACHINE_BALLS.size()
			_effects.start_heal_machine(Gen2WorldEffects.HEAL_MACHINE_ELMS_LAB, balls)
			for _frame: int in balls * Gen2WorldEffects.HEAL_MACHINE_BALL_FRAMES - 1:
				_effects.advance_frame()
		_script_prompt = "Debug heal machine preview"
		_renderer.refresh()
		_refresh_labels()
		return
	if _effects != null:
		_effects.start_headbutt_tree(_world.player_cell + Vector2i(1, 0))
		_effects.start_boulder_dust(
			-1, _world.player_cell, Vector2i.DOWN, Gen2WorldAPI.STEP_PASSES_BOULDER_PUSH
		)
		_effects.start_grass_rustle(
			-1, _world.player_cell, Gen2WorldAPI.STEP_PASSES_WALK - 1
		)
	## The nearest object rather than the first, so the emote lands inside the
	## view a capture photographs.
	var nearest: Gen2WorldObject = null
	for object: Gen2WorldObject in _world.visible_objects():
		if nearest == null or object.cell.distance_squared_to(_world.player_cell) \
			< nearest.cell.distance_squared_to(_world.player_cell):
			nearest = object
	if nearest == null:
		_script_prompt = "No visible object for the emote"
	else:
		nearest.set_emote(0, true)
		_script_prompt = "Debug effect sprite preview"
	_renderer.refresh()
	_refresh_labels()


## Public screenshot driver for the visible-encounter seam, which otherwise needs
## a mod: a shiny Pokemon of the map's own table, on the eligible cell nearest
## the player, asking for its pulse. The provider is the synthetic one below;
## everything else is the host's own path.
func preview_visible_encounter() -> void:
	_preview_visible_encounter(false)


## The same population wearing an entry's own `glow` instead: ordinary DVs, so
## the mark is the one a mod puts on a Pokemon worth stopping for rather than
## the shiny's palette and sparkle.
func preview_visible_encounter_glow() -> void:
	_preview_visible_encounter(true)


func _preview_visible_encounter(glow: bool) -> void:
	if _world == null or _encounters == null or _renderer == null:
		return
	_encounters.set_providers([PreviewEncounters.new(_world, glow)])
	advance_frames(2)
	_script_prompt = "Debug visible encounter preview"
	_renderer.refresh()
	_refresh_labels()


## What a mod's provider is, in the fewest lines that exercise the contract.
class PreviewEncounters extends RefCounted:
	## `CheckShininess`: the attack mask and three tens.
	const SHINY_DVS: int = (2 << 12) | (10 << 8) | (10 << 4) | 10
	## The light and the walk a glowing entry asks for, at the top rung so the
	## picture is the mark at its strongest rather than a frame of a breath.
	const GLOW_COLOR := Color(1.0, 0.87, 0.35)
	const GLOW_AMOUNT: float = 0.5

	var _entries: Array = []

	func _init(world: Gen2WorldAPI, glow: bool = false) -> void:
		var cells: Dictionary = world.visible_encounter_cells()
		var tables: Dictionary = world.active_encounter_tables()
		for method: Variant in cells:
			var slots: Array = (tables.get(method, {}) as Dictionary).get("slots", [])
			var nearest := Vector2(-1, -1)
			for cell: Vector2 in cells[method] as PackedVector2Array:
				if nearest.x < 0 or cell.distance_squared_to(Vector2(world.player_cell)) \
					< nearest.distance_squared_to(Vector2(world.player_cell)):
					nearest = cell
			if nearest.x < 0 or slots.is_empty():
				continue
			var entry: Dictionary = {
				"id": StringName("preview_%s" % method),
				"cell": Vector2i(nearest),
				"species": int(slots[0]["species"]),
				"level": int(slots[0]["min_level"]),
				"dvs": 0 if glow else SHINY_DVS,
				"pulse": not glow,
			}
			if glow:
				entry["glow"] = {"color": GLOW_COLOR, "amount": GLOW_AMOUNT}
			_entries.append(entry)

	func set_context(_context: Dictionary) -> void:
		pass

	func advance_frame() -> void:
		pass

	func encounters() -> Array:
		return _entries

	func battle_finished(_id: StringName, _result: Variant) -> void:
		pass


## Public screenshot driver for the actor seam's optional half, which otherwise
## needs a mod: a Pokemon one cell behind the player, pressed with A so it is
## drawn wearing the heart the press put up. The press and the cry go through
## the host's own path; only the actor is synthetic.
func preview_pet_actor() -> void:
	if _world == null or _actors == null or _renderer == null:
		return
	## Faced up so the bubble, which `MovementFunction_Emote` puts two rows above
	## the sprite, is clear of the player rather than behind them.
	_world.player_facing = Gen2WorldSprite.FACING_UP
	_actors.set_actors([PreviewPet.new(_world)])
	## Deliberately NOT followed by a refresh of its own, unlike the other
	## drivers here: the press is what has to reach the picture, and a driver
	## redrawing after it would photograph a heart that never arrived on the
	## frame it was pressed.
	interact()
	_script_prompt = "Debug pet actor preview"
	_refresh_labels()


## What a mod's actor is, in the fewest lines that exercise the optional half.
class PreviewPet extends RefCounted:
	const CYNDAQUIL: int = 155

	var _world: Gen2WorldAPI = null
	var _petted: bool = false
	var _cried: bool = false

	func _init(world: Gen2WorldAPI) -> void:
		_world = world

	func set_world(world: Gen2WorldAPI) -> void:
		_world = world

	func advance_frame() -> void:
		pass

	func sprites() -> Array:
		var entry: Dictionary = {
			"icon": _world.data.mon_menu_icon(CYNDAQUIL),
			"facing": _world.player_facing,
			"position_cells": Vector2(_cell()),
		}
		if _petted:
			entry["emote"] = Gen2WorldActors.EMOTE_HEART
		return [entry]

	func interact(cell: Vector2i, _facing: int) -> bool:
		if cell != _cell():
			return false
		_petted = true
		return true

	func take_requests() -> Array:
		if not _petted or _cried:
			return []
		_cried = true
		return [{"kind": Gen2WorldActors.REQUEST_CRY, "species": CYNDAQUIL}]

	## The faced cell, so a press with nothing in front of the player reaches it.
	func _cell() -> Vector2i:
		return _world.facing_cell()


## Public screenshot driver for `Script_pokepic`'s box. The scripts that run one
## are Elm's three balls and their neighbours, which no map reaches from a bare
## warp, so the species is named here; everything else is the branch's own call.
func preview_pokepic(species: int) -> void:
	_show_story_picture(species)
	_refresh_labels()


## Public screenshot driver for `_ContText`'s scroll: the object in front of the
## player is talked to and its text walked to the `<CONT>` that scrolls, and the
## box's own frames are then spent by hand so the picture is the same every run
## rather than whatever the wall clock reached.
func preview_text_scroll() -> void:
	if _text_box == null:
		return
	## A `BGEVENT_READ` is read from the cell below it, so the sign is faced
	## first; its own tile is a wall, so this turns rather than steps.
	move_up()
	interact()
	for _press: int in PREVIEW_TEXT_PRESSES:
		if _text_box.is_scrolling():
			break
		_advance_script_pause()
	_text_box.set_process(false)
	## One frame into the first of `TextScroll`'s two steps, where the two lines
	## sit on rows no finished page can put them on.
	_text_box.advance_scroll_frames(1.0)
	_refresh_labels()


## Public screenshot driver. It executes the first active scripted event in
## source order, which keeps the debug image tied to imported map data.
func preview_script_event() -> void:
	if _world == null:
		return
	for source: String in ["coord_events", "bg_events", "objects"]:
		for event: Dictionary in _world.current_map.events.get(source, []):
			var cell := Vector2i(int(event.get("x", -1)), int(event.get("y", -1)))
			var results: Array = _world.dispatch_events(cell, true)
			if not results.is_empty():
				_show_script_results(results)
				return
	_script_prompt = "No active script at this map's event records"
	_refresh_labels()


## Public screenshot driver for the party submenu's field-move entry. Grants the
## move's badge and teaches it to the first party member, then injects that save
## so persistence stays off, the way preview_party_transaction() does.
func preview_field_move() -> void:
	_preview_field_move(Gen2WorldFieldMove.MOVE_CUT, Gen2WorldFieldMove.BADGE_HIVE)


## The rest of that sequence, one step per call: the first chooses the submenu's
## field-move entry and shows its message, the second acknowledges it and
## commits.
func preview_field_move_use() -> void:
	_preview_field_move_use(Gen2WorldFieldMove.MOVE_CUT, Gen2WorldFieldMove.BADGE_HIVE)


## The same pair for Surf, which needs the scene opened beside water.
func preview_surf() -> void:
	_face_surfable_water()
	_preview_field_move(Gen2WorldFieldMove.MOVE_SURF, Gen2WorldFieldMove.BADGE_FOG)


func preview_surf_use() -> void:
	_face_surfable_water()
	_preview_field_move_use(Gen2WorldFieldMove.MOVE_SURF, Gen2WorldFieldMove.BADGE_FOG)


## `.TrySurf` reads the faced tile, so facing anywhere else photographs a refusal.
func _face_surfable_water() -> void:
	if _world == null:
		return
	var standing: int = _world.tile_permissions_at(_world.player_cell)
	for facing: int in [
		Gen2WorldSprite.FACING_DOWN, Gen2WorldSprite.FACING_UP,
		Gen2WorldSprite.FACING_LEFT, Gen2WorldSprite.FACING_RIGHT,
	]:
		_world.player_facing = facing
		var target: Vector2i = _world.facing_cell()
		if _world.collision_permission_at(target) != Gen2WorldCollision.WATER_TILE:
			continue
		var face: int = Gen2WorldCollision.face_mask_for_direction(
			_world.facing_direction()
		)
		if face == 0 or (standing & face) == 0:
			return


## And for Whirlpool, facing a COLL_WHIRLPOOL cell: Dragon's Den B1F, Route 41 and
## Route 27 are the only maps that carry one.
func preview_whirlpool() -> void:
	_preview_field_move(Gen2WorldFieldMove.MOVE_WHIRLPOOL, Gen2WorldFieldMove.BADGE_GLACIER)


func preview_whirlpool_use() -> void:
	_preview_field_move_use(
		Gen2WorldFieldMove.MOVE_WHIRLPOOL, Gen2WorldFieldMove.BADGE_GLACIER
	)


## And for Strength, which needs nothing in front of the player: .TryStrength
## checks the badge and stops. To watch a boulder move, press a direction into one
## after the second call; Cianwood Gym (22/5) and Ice Path B1F carry them.
func preview_strength() -> void:
	_preview_field_move(Gen2WorldFieldMove.MOVE_STRENGTH, Gen2WorldFieldMove.BADGE_PLAIN)


func preview_strength_use() -> void:
	_preview_field_move_use(
		Gen2WorldFieldMove.MOVE_STRENGTH, Gen2WorldFieldMove.BADGE_PLAIN
	)


## And for Waterfall, in the water at a fall's foot; the facing is the driver's,
## below. The climb is paced, so the frames after the second call are the climb.
func preview_waterfall() -> void:
	_stage_waterfall_world()
	_preview_field_move(Gen2WorldFieldMove.MOVE_WATERFALL, Gen2WorldFieldMove.BADGE_RISING)


func preview_waterfall_use() -> void:
	_stage_waterfall_world()
	_preview_field_move_use(Gen2WorldFieldMove.MOVE_WATERFALL, Gen2WorldFieldMove.BADGE_RISING)


## The world a climber is in: `CheckMapCanWaterfall` passes only FACE_UP, and a
## fall's foot is water, where `.CheckSurfing` puts them on the surf sprite.
func _stage_waterfall_world() -> void:
	if _world == null:
		return
	_world.player_facing = Gen2WorldSprite.FACING_UP
	_world.set_movement_mode(Gen2WorldAPI.MOVEMENT_SURF)
	_world.player_sprite_number = Gen2WorldSprite.SPRITE_SURF


## And for Flash, which checks no tile and is what makes a dark cave
## photographable at all.
func preview_flash() -> void:
	_preview_field_move(Gen2WorldFieldMove.MOVE_FLASH, Gen2WorldFieldMove.BADGE_ZEPHYR)


func preview_flash_use() -> void:
	_preview_field_move_use(Gen2WorldFieldMove.MOVE_FLASH, Gen2WorldFieldMove.BADGE_ZEPHYR)


func _preview_field_move_use(move: int, badge: int) -> void:
	if _field_move_text:
		_acknowledge_field_move_text()
		return
	_preview_field_move(move, badge)
	if _party_host != null:
		_party_host.handle_button(Gen2Button.A)


func _preview_field_move(move: int, badge: int) -> void:
	if _world == null or _data == null:
		return
	var save: Gen2SaveData = _embedded_party_save()
	if save == null or save.party.is_empty():
		_script_prompt = "Field move preview needs a party"
		_refresh_labels()
		return
	var teacher: Gen2SaveMon = save.party[0]
	teacher.moves[0] = move
	## The slot's PP with it. `Gen2SaveValidator` refuses a row carrying more PP
	## than its move has, so a Tackle at 35 replaced by a Surf at 15 left a save
	## every world transaction after it would refuse: the field move worked and
	## the next catch, purchase or party change reported nothing but failure.
	teacher.pp[0] = int(_data.move(move).get("pp", 0))
	_injected_save = save
	_world.state.set_engine_flag(Gen2WorldState.badge_flag(
		badge, Gen2WorldState.is_crystal_profile(_data)
	))
	_open_embedded_party()
	if _party_host == null:
		return
	_party_host.handle_button(Gen2Button.A)


## Public screenshot driver for the scene-free party item transaction. It uses a
## development save and keeps the result in memory, so the image demonstrates
## the real host boundary without changing a user's selected slot.
func preview_party_transaction() -> void:
	if _world == null or _data == null:
		return
	var preview_save: Gen2SaveData = Gen2SaveStore.create_development_save(_data, 0)
	if preview_save == null or preview_save.party.is_empty():
		_script_prompt = "Party transaction preview unavailable"
		_refresh_labels()
		return
	preview_save.world = _world.snapshot()
	var item_result: Dictionary = _world.state.apply_changes(
		{}, {}, {"items": {Gen2WorldPartyHost.ITEM_POTION: 1}}
	)
	if not bool(item_result.get("ok", false)):
		_script_prompt = "Party transaction preview unavailable"
		_refresh_labels()
		return
	preview_save.party[0].hp = 1
	var result: Dictionary = Gen2WorldPartyHost.use_item(
		_world, preview_save, Gen2WorldPartyHost.ITEM_POTION, 0, false
	)
	var preview_caption: String = ""
	if bool(result.get("ok", false)):
		var healed: int = int(result.get("healed", 0))
		_script_prompt = "POTION +%d HP" % healed
		preview_caption = "%s   PARTY TX: POTION +%d HP" % [_data.title(), healed]
	else:
		_script_prompt = "Party transaction failed: %s" % String(result.get("reason", "unknown"))
	_refresh_labels()
	if not preview_caption.is_empty():
		_set_caption(preview_caption)


## Public screenshot driver for the pack's item use. It grants a Potion and hurts
## the first party member on an injected save, so nothing persists, then advances
## one menu step per call: Pack, the item, USE, the target, the result.
func preview_pack_use() -> void:
	if _world == null or _data == null:
		return
	if _start_menu_host != null:
		_start_menu_host.handle_button(Gen2Button.A)
		return
	var save: Gen2SaveData = _embedded_party_save()
	if save == null or save.party.is_empty():
		_script_prompt = "Pack preview needs a party"
		_refresh_labels()
		return
	(save.party[0] as Gen2SaveMon).hp = 1
	_injected_save = save
	_world.state.apply_changes({}, {}, {"items": {Gen2WorldPartyHost.ITEM_POTION: 1}})
	_open_start_menu()
	if _start_menu_host == null:
		return
	if not _walk_start_menu_to(Gen2WorldStartMenu.ITEM_PACK):
		return
	_start_menu_host.handle_button(Gen2Button.A)


## Public screenshot driver for a field evolution, which is the pack's USE on a
## stone. Driven twice, like the other `*_use` names: the first call opens the
## pack on the stone and the second uses it on the party's first member, so the
## picture is `EvolvingText` and `CongratulationsYourPokemonText` in the pack's
## own box rather than a staged string.
func preview_item_evolution_use() -> void:
	if _world == null or _data == null:
		return
	if _start_menu_host != null:
		# USE, then the party list, then the first member.
		for _press: int in 3:
			_start_menu_host.handle_button(Gen2Button.A)
		return
	var save: Gen2SaveData = _embedded_party_save()
	if save == null or save.party.is_empty():
		_script_prompt = "Evolution preview needs a party"
		_refresh_labels()
		return
	var stone: Dictionary = _first_stone_evolution()
	if stone.is_empty():
		_script_prompt = "Evolution preview: this cache has no stone evolution"
		_refresh_labels()
		return
	var mon: Gen2SaveMon = save.party[0]
	mon.species = int(stone["species"])
	mon.nickname = String(_data.species(mon.species).get("name", ""))
	_injected_save = save
	_world.state.apply_changes({}, {}, {"items": {int(stone["item"]): 1}})
	_open_start_menu()
	if _start_menu_host == null:
		return
	if not _walk_start_menu_to(Gen2WorldStartMenu.ITEM_PACK):
		return
	_start_menu_host.handle_button(Gen2Button.A)
	var rows: Array = _start_menu_host.call("_current_pocket_items")
	for index: int in rows.size():
		if int((rows[index] as Dictionary).get("item", 0)) == int(stone["item"]):
			_start_menu_host.set("_pack_cursor", index)
			break


## Public screenshot driver for `special NameRater`, which no cell of the
## fixture maps reaches: it stands a member the player caught in the first party
## slot and opens the routine on it, so every box, both questions and the party
## list can be photographed on any map.
func preview_name_rater() -> void:
	if _world == null or _data == null or _name_rater_host != null:
		return
	var save: Gen2SaveData = _embedded_party_save()
	if save == null or save.party.is_empty():
		_script_prompt = "Name Rater preview needs a party"
		_refresh_labels()
		return
	var mon: Gen2SaveMon = save.party[0]
	mon.is_egg = false
	mon.original_trainer = save.player_name
	mon.ot_id = save.player_id
	_injected_save = save
	_world.set_player_id(save.player_id)
	_open_name_rater()


## Public screenshot driver for `_UnownPrinter`, which no fixture cell reaches
## and which a world with no caught Unown never opens: [param slot] is the
## browser's own cursor and [param printing] the page A sends.
func preview_unown_printer(slot: int = 0, printing: bool = false) -> void:
	if not _open_unown_printer({"values": {"caught": 1}}):
		return
	if _unown_printer_host == null:
		return
	for _step: int in maxi(slot, 0):
		_unown_printer_host.handle_button(Gen2Button.RIGHT)
	if printing:
		_unown_printer_host.handle_button(Gen2Button.A)


## Public screenshot driver for `_Diploma` and `_PrintDiploma`, which no fixture
## cell reaches: the diploma is one flag deep into the Hall of Fame's own script.
## [param page] is 1 or 2, and 2 is the page only a printer that answered would
## have reached.
func preview_diploma(printing: bool = false, page: int = 1) -> void:
	if not _open_diploma({"values": {"printing": printing}}):
		return
	if _diploma_host != null and page != 1:
		_diploma_host.preview_page(page)


## Public screenshot driver for `_BillsPC`, whose top menu no preview cell
## reaches: every PC on a preview map is a script's, and the machine wants a
## party before it opens at all.
func preview_bills_pc() -> void:
	if _world == null or _data == null or _service_host != null:
		return
	var save: Gen2SaveData = _embedded_party_save()
	if save == null or save.party.is_empty():
		_script_prompt = "BILL'S PC preview needs a party"
		_refresh_labels()
		return
	_injected_save = save
	_open_bills_pc()


## Public screenshot drivers for the two PCs, whose cells no preview map has:
## the Pokemon Center's machine and the bedroom's own item PC, which is the one
## that carries DECORATION.
## The machine's own list grows with the story, and its last row is postgame:
## `.ChooseWhichPCListToUse` asks for the Pokedex and then the induction. Neither
## has happened on a preview save, so this drives `halloffame`'s own two writes
## first rather than photographing a list that is missing two of its rows.
func preview_pokemon_center_pc() -> void:
	var save: Gen2SaveData = _embedded_party_save()
	if _world != null and save != null and save.hall_of_fame.is_empty():
		_world.state.set_engine_flag(Gen2WorldState.ENGINE_POKEDEX, true)
		_world.state.set_hall_of_fame(true)
		save.hall_of_fame = Gen2HallOfFame.inducted(save.hall_of_fame, save)
	## `_embedded_party_save` builds a development save when nothing is injected,
	## so the seeded one has to be the save the host is then handed.
	_injected_save = save
	_preview_pc(&"pokemon_center")


func preview_players_pc() -> void:
	_preview_pc(&"players_house")


func preview_mailbox() -> void:
	var save: Gen2SaveData = _embedded_party_save()
	if save != null and save.mailbox.is_empty():
		for author: String in ["MOM", "KURT", "BILL"]:
			save.mailbox.append(Gen2SaveMail.compose(
				Gen2SaveMail.blank_message(), author, save.player_id, 1, FLOWER_MAIL
			))
		_injected_save = save
	_preview_pc(&"players_house")


func _preview_pc(mode: StringName) -> void:
	if _world == null or _data == null or _service_host != null:
		return
	var save: Gen2SaveData = _embedded_party_save()
	if save == null or save.party.is_empty():
		_script_prompt = "The PC preview needs a party"
		_refresh_labels()
		return
	_injected_save = save
	var host: Gen2WorldServiceScreen = SERVICE_SCENE.instantiate() as Gen2WorldServiceScreen
	if host == null:
		return
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.z_index = 20
	host.set_screen(_screen)
	add_child(host)
	if not host.open_pc_machine(_world, _data, save, false, mode):
		Gen2Screen.drop(host)
		return
	host.save_action = persist_world_snapshot
	host.completed.connect(_on_service_completed)
	host.sfx_requested.connect(_play_sfx)
	host.cry_requested.connect(_play_species_cry)
	_service_host = host
	_script_prompt = "PC open"
	_refresh_labels()


## Public screenshot driver for `Mom_WithdrawDepositMenuJoypad`, whose box no
## fixture cell reaches: her house is not one of the preview maps and the dial
## stands three questions into her own routine.
func preview_mom_bank(mode: StringName, saved: int, held: int) -> void:
	if _world == null or _data == null or _service_host != null:
		return
	var host: Gen2WorldServiceScreen = SERVICE_SCENE.instantiate() as Gen2WorldServiceScreen
	if host == null:
		return
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.z_index = 20
	host.set_screen(_screen)
	add_child(host)
	if not host.open_mom_bank(_world, _data, mode, saved, held):
		Gen2Screen.drop(host)
		return
	host.save_action = persist_world_snapshot
	host.completed.connect(_on_service_completed)
	host.sfx_requested.connect(_play_sfx)
	host.cry_requested.connect(_play_species_cry)
	_service_host = host
	_refresh_labels()


## Public screenshot driver for the Day-Care's five specials, which no cell of
## the fixture maps reaches either. [param role] picks the routine; the two signs
## and the man outside need state behind them, so a slot is filled and the egg
## flag set before the screen opens.
func preview_day_care(role: StringName) -> void:
	if _world == null or _data == null or _day_care_host != null:
		return
	var save: Gen2SaveData = _embedded_party_save()
	if save == null or save.party.size() < 2:
		_script_prompt = "The Day-Care preview needs two party members"
		_refresh_labels()
		return
	_injected_save = save
	_world.set_player_id(save.player_id)
	var state: Gen2WorldState = _world.state
	if role in [&"mon1", &"mon2"]:
		for slot: int in [
			Gen2WorldDayCare.SLOT_MAN, Gen2WorldDayCare.SLOT_LADY
		]:
			state.set_day_care_mon(slot, save.party[slot] as Gen2SaveMon)
			state.set_day_care_has_mon(slot, true)
	elif role == &"outside":
		state.set_day_care_man_flags(
			state.day_care_man_flags() | Gen2WorldDayCare.MAN_HAS_EGG
		)
		state.set_day_care_egg(save.party[0] as Gen2SaveMon)
	_open_day_care({"values": {"role": role}})


## How long `preview_slot_machine` gives the loop to reach its bet menu.
const SLOT_MACHINE_MENU_FRAME_CAP: int = 16


## Public screenshot driver and scene-test entry for `special SlotMachine`,
## which only the two Game Corners reach and no fixture cell does.
##
## [param coins] is the balance the machine opens with, [param lucky] the
## `wScriptVar` the map's own `setval` leaves, and [param frames] how far into
## the game to drive: the machine is pressed past its bet menu and then handed
## A three times, which is how a spin is photographed at all.
func preview_slot_machine(
	coins: int = 100, lucky: bool = false, bet: int = 1, frames: int = 0
) -> void:
	if _world == null or _data == null or _slot_machine_host != null:
		return
	_open_slot_machine({"values": {"coins": coins, "lucky": lucky}})
	var host: Gen2SlotMachineScreen = _slot_machine_host
	if host == null:
		return
	## `SlotsAction_Init` runs on the first pass and `..._BetAndStart` on the
	## second, so the menu is two frames in rather than up at the open.
	for _frame: int in SLOT_MACHINE_MENU_FRAME_CAP:
		if host.prompt() == Gen2SlotMachine.Prompt.BET:
			break
		host.advance_frame()
	## `Slots_AskBet`'s menu opens on " 3", so a bet of one is two presses down.
	for _step: int in clampi(3 - bet, 0, 2):
		host.handle_button(Gen2Button.DOWN)
	host.handle_button(Gen2Button.A)
	## Every reel is stopped by an A press, which is the only way a spin ends at
	## all: the driver hands one over whenever the loop is waiting for it.
	for _frame: int in maxi(frames, 0):
		if _slot_machine_host == null:
			break
		## The `WaitSFX` steps are the driver's, and a screenshot spends no wall
		## clock for an effect to finish in, so each is cut rather than waited
		## out: `SFXChannelsOff` is what the cartridge does to a sound it will
		## not wait for.
		if _audio_player != null and host.machine() != null \
			and host.machine().waiting_for_sfx():
			_audio_player.stop_effects()
		host.advance_frame()
		if host.machine() != null and host.machine().jumptable_index() in [
			Gen2SlotMachine.SLOTS_WAIT_REEL1, Gen2SlotMachine.SLOTS_WAIT_REEL2,
			Gen2SlotMachine.SLOTS_WAIT_REEL3,
		]:
			host.handle_button(Gen2Button.A)


## How long `preview_card_flip` gives the loop to reach a prompt.
const CARD_FLIP_PROMPT_FRAME_CAP: int = 240


## Public screenshot driver and scene-test entry for `special CardFlip`, which
## only the two Game Corners reach and no fixture cell does.
##
## [param coins] is the balance the table opens with and [param frames] how far
## into the game to drive: every `YesNoBox` is answered YES and every
## `WaitPressAorB` pressed, so the table deals, toggles and pays without the
## driver knowing which state it is in.
func preview_card_flip(coins: int = 100, frames: int = 0) -> void:
	if _world == null or _data == null or _card_flip_host != null:
		return
	_open_card_flip({"values": {"coins": coins}})
	var host: Gen2CardFlipScreen = _card_flip_host
	if host == null:
		return
	for _frame: int in maxi(frames, 0):
		if _card_flip_host == null:
			break
		## Cut rather than waited out, the way `preview_slot_machine` does it.
		if _audio_player != null and host.game() != null \
			and host.game().waiting_for_sfx():
			_audio_player.stop_effects()
		host.advance_frame()
		match host.prompt():
			Gen2CardFlip.Prompt.YES_NO, Gen2CardFlip.Prompt.PRESS, \
			Gen2CardFlip.Prompt.CHOOSE, Gen2CardFlip.Prompt.BET:
				host.handle_button(Gen2Button.A)
			_:
				pass


## Public screenshot driver and scene-test entry for `special UnownPuzzle`,
## which only the four Ruins of Alph chambers reach and no fixture cell does.
## [param puzzle] is the `UNOWNPUZZLE_*` index the chamber's own `setval` names.
## Long enough for any of the puzzle's own effects to finish under the driver.
const PUZZLE_WAIT_FRAME_CAP: int = 240


## [param solve] walks the board into `.SolvedPuzzleConfiguration` through the
## screen's own presses, which is the only way to photograph the assembled
## picture: nothing else puts a piece anywhere.
func preview_unown_puzzle(puzzle: int, solve: bool = false) -> void:
	if _world == null or _data == null or _unown_puzzle_host != null:
		return
	_open_unown_puzzle({"values": {"puzzle": puzzle}})
	if not solve or _unown_puzzle_host == null:
		return
	var board: Gen2UnownPuzzle = _unown_puzzle_host.board()
	for piece: int in range(1, Gen2UnownPuzzle.PIECES + 1):
		_walk_puzzle_cursor(_puzzle_cell_of(board, piece))
		_press_puzzle_a()
		_walk_puzzle_cursor(_puzzle_cell_of(board, piece, true))
		_press_puzzle_a()


## `UnownPuzzle_A` ends on `WaitSFX` and the loop reads nothing until it
## returns, so a driver spending no frames would have its next press swallowed.
func _press_puzzle_a() -> void:
	var host: Gen2UnownPuzzleScreen = _unown_puzzle_host
	if host == null:
		return
	host.handle_button(Gen2Button.A)
	host.release_button(Gen2Button.A)
	## The wait is the driver's, and a screenshot spends no wall clock for it to
	## finish in, so the effect is cut rather than waited out: `SFXChannelsOff`
	## is what the cartridge itself does to a sound it will not wait for.
	if _audio_player != null:
		_audio_player.stop_effects()
	var guard: int = PUZZLE_WAIT_FRAME_CAP
	while guard > 0 and host.waiting_for_sfx():
		host.advance_frame()
		guard -= 1


## Which cell holds [param piece], or where the solved board wants it.
func _puzzle_cell_of(
	board: Gen2UnownPuzzle, piece: int, solved: bool = false
) -> int:
	for cell: int in Gen2UnownPuzzle.CELLS:
		var holds: int = Gen2UnownPuzzle.solved_piece_at(cell) if solved \
			else board.piece_at(cell)
		if holds == piece:
			return cell
	return 0


## Up and left both refuse at the edge, so pressing each a row's worth parks the
## cursor on cell 0, and the board is walked from there.
func _walk_puzzle_cursor(cell: int) -> void:
	var host: Gen2UnownPuzzleScreen = _unown_puzzle_host
	if host == null:
		return
	## Each press is released before the next: `hJoyLast` carries every held
	## button and `.Function` takes the first direction it finds, so a driver
	## that never lets go would walk up for ever.
	for _step: int in Gen2UnownPuzzle.ROWS:
		_tap_puzzle(Gen2Button.LEFT)
		_tap_puzzle(Gen2Button.UP)
	for _step: int in cell / Gen2UnownPuzzle.COLUMNS:
		_tap_puzzle(Gen2Button.DOWN)
	for _step: int in cell % Gen2UnownPuzzle.COLUMNS:
		_tap_puzzle(Gen2Button.RIGHT)


func _tap_puzzle(button: int) -> void:
	var host: Gen2UnownPuzzleScreen = _unown_puzzle_host
	if host == null:
		return
	host.handle_button(button)
	host.release_button(button)


## One of the five fade specials on the map that is already open, for a
## screenshot: the frames it spends are the script's on the real path, so this
## opens the fade and the caller advances into it.
func preview_script_fade(special: int) -> void:
	if not Gen2WorldScriptRunner.FADE_ORDERS_OF.has(special):
		return
	_start_script_fade({
		"orders": Gen2WorldScriptRunner.FADE_ORDERS_OF[special],
		"white_fill": special in Gen2WorldScriptRunner.FADE_WHITE_FILL_SPECIALS,
		"step_frames": Gen2WorldPalette.BATTLE_TOWER_FADE_STEP_FRAMES \
			if special == Gen2WorldScriptRunner.SPECIAL_BATTLE_TOWER_FADE \
			else Gen2WorldPalette.FADE_STEP_FRAMES,
	})


## Public screenshot driver and scene-test entry for `OverworldHatchEgg`: it
## stands an egg with one cycle left in the first party slot of an injected save,
## spends the egg step, and opens the sequence on whatever hatched. [param species]
## is what is inside the egg; 0 takes the first species the cache holds, so the
## driver works on all three without a table.
func preview_egg_hatch(species: int = 0) -> void:
	if _world == null or _data == null or _hatch_host != null:
		return
	var save: Gen2SaveData = _embedded_party_save()
	if save == null or save.party.is_empty():
		_script_prompt = "Hatch preview needs a party"
		_refresh_labels()
		return
	var mon: Gen2SaveMon = save.party[0]
	mon.species = species if species > 0 else 1
	mon.is_egg = true
	mon.hp = 0
	mon.nickname = "EGG"
	## One cycle left, so the pass this drains is the one that hatches it.
	mon.happiness = 1
	_injected_save = save
	if Gen2WorldPartyHost.apply_egg_steps(save, 1) < 0:
		return
	var summary: Dictionary = Gen2WorldPartyHost.hatch_egg(_world, save, 0)
	if summary.is_empty():
		return
	_open_hatch([summary], save)


## Public screenshot driver for `GiveANickname_YesNo`, which no fixture cell
## reaches: a `givepoke` is somebody's map script. The prompt is opened over the
## map with no request behind it, so its close writes nothing.
func preview_gift_nickname(species: int = 0, boxed: bool = false) -> void:
	if _world == null or _data == null or _nickname_host != null:
		return
	var chosen: int = species if species > 0 else 1
	var species_name: String = String(_data.species(chosen).get("name", ""))
	if species_name.is_empty():
		_script_prompt = "This cartridge has no species %d" % chosen
		_refresh_labels()
		return
	var host := Gen2NicknamePromptScreen.new()
	host.set_context(
		_data, species_name,
		Gen2WorldPartyHost.SENT_TO_BOX_FORMAT if boxed else ""
	)
	_nickname_answer = species_name
	_nickname_preview = true
	host.named.connect(_on_gift_named)
	host.closed.connect(_on_gift_nickname_closed)
	host.z_index = 30
	_nickname_host = host
	_screen.display(host)
	_script_prompt = "Nickname"
	_refresh_labels()


## Public screenshot driver for the blackout. It poisons the whole party down to
## its last point and spends the pass `CountStep` owes, which is the same
## `DoPoisonStep` a walk reaches: the faint line, `_WhitedOutText` behind it and
## `Script_Whiteout` behind the last press.
func preview_whiteout() -> void:
	if _world == null or _data == null:
		return
	var save: Gen2SaveData = _embedded_party_save()
	if save == null or save.party.is_empty():
		_script_prompt = "Blackout preview needs a party"
		_refresh_labels()
		return
	for mon: Gen2SaveMon in save.party:
		mon.is_egg = false
		mon.hp = 1
		mon.status = Gen2Status.POISON
	_injected_save = save
	for _step: int in Gen2WorldState.POISON_STEP_PHASE:
		_world.state.count_step()
	_spend_poison_steps()


## The first `EVOLVE_ITEM` row this cache carries, as `{species, item}`. Walked
## rather than named, so the driver works on all three without a table.
func _first_stone_evolution() -> Dictionary:
	for species: int in range(1, _data.species_count() + 1):
		for row: Dictionary in _data.evolutions(species):
			if int(row.get("method", 0)) == RomLayout.EVOLVE_ITEM:
				return {"species": species, "item": int(row.get("parameter", 0))}
	return {}


## Public screenshot driver and scene-test entry for `EvolveAfterBattle`'s own
## presentation: it stands the first party member on the first LEVEL evolution
## the cache holds and opens the screen on it, which is the one path a stone
## cannot reach, since `.pressed_b` lets B cancel this one and not that one.
##
## The party row is left alone. [method _on_evolution_resolved] applies it, the
## same way the after-battle pass does, so the preview is that pass rather than
## a picture of it.
func preview_level_evolution() -> void:
	if _world == null or _data == null:
		return
	if _evolution_host != null:
		return
	var save: Gen2SaveData = _injected_save if _injected_save != null \
		else _embedded_party_save()
	if save == null or save.party.is_empty():
		_script_prompt = "Evolution preview needs a party"
		_refresh_labels()
		return
	_injected_save = save
	var plans: Array = Gen2Evolution.after_battle(
		_data, save, [0], _world.object_time_of_day
	)
	if plans.is_empty():
		## Only when the party's own lead has nothing due: a caller that has
		## already staged one is photographing that one.
		var row: Dictionary = _first_level_evolution()
		if row.is_empty():
			_script_prompt = "Evolution preview: this cache has no level evolution"
			_refresh_labels()
			return
		var mon: Gen2SaveMon = save.party[0]
		mon.species = int(row["species"])
		mon.level = maxi(mon.level, int(row["row"].get("parameter", mon.level)))
		mon.nickname = String(_data.species(mon.species).get("name", ""))
		mon.hp = maxi(mon.hp, 1)
		mon.status = Gen2Status.NONE
		plans = Gen2Evolution.after_battle(
			_data, save, [0], _world.object_time_of_day
		)
	_open_evolution(plans, save, Callable())


func _first_level_evolution() -> Dictionary:
	for species: int in range(1, _data.species_count() + 1):
		for row: Dictionary in _data.evolutions(species):
			if int(row.get("method", 0)) == RomLayout.EVOLVE_LEVEL:
				return {"species": species, "row": row}
	return {}


## Public screenshot driver for the start menu itself: opens it, and then walks
## the cursor one entry per call, which is what photographs MENU ACCOUNT's own
## description line under the list.
func preview_start_menu() -> void:
	if _world == null or _data == null:
		return
	if _start_menu_host == null:
		_injected_save = _embedded_party_save()
		## `SetUpMenuItems` reads the world's own party count for the #MON row,
		## and the picture wants the full list rather than a saveless one.
		_refresh_party_summary()
		_open_start_menu()
		return
	_start_menu_host.handle_button(Gen2Button.DOWN)


## Public screenshot driver for the reset chord's own question, which no cell
## reaches: the chord is the console's rather than the map's. One press per call,
## so a driver calling twice photographs the `YesNoBox` rather than the first
## page of the text.
func preview_reset_question() -> void:
	if _start_menu_host == null:
		_injected_save = _embedded_party_save()
		_refresh_party_summary()
		_open_start_menu_host(func(host: Gen2StartMenuScreen) -> void:
			host.ask_soft_reset()
		)
		return
	_start_menu_host.handle_button(Gen2Button.A)


## The same for the HOME row's own question, walked to off the list the way a
## player reaches it.
func preview_launcher_question() -> void:
	if _start_menu_host == null:
		preview_start_menu()
		return
	var menu: Gen2WorldStartMenu = _start_menu_host.get("_menu")
	while menu != null and menu.selected_kind() != Gen2WorldStartMenu.ITEM_LAUNCHER:
		_start_menu_host.handle_button(Gen2Button.DOWN)
	_start_menu_host.handle_button(Gen2Button.A)


## Public screenshot driver for the cover a view switch is hidden behind: the
## switch itself, photographed part way down its close. See
## [method Gen2Screen.play_view_cover].
func preview_view_cover() -> void:
	## A `view=` argument has already chosen one and left its cover running; on
	## its own the driver switches to the next view itself.
	if not _screen.view_cover_active() and not cycle_view().get("ok", false):
		return
	_screen.step_view_cover(PREVIEW_COVER_FRAMES)


## Public screenshot driver for the MODS entry, which is where a player changes
## the view on a shipped build: one call opens the menu and walks to the row,
## and the picture is the host's own VIEW row at the top of it.
func preview_mod_views() -> void:
	if _world == null or _data == null:
		return
	if _start_menu_host == null:
		_injected_save = _embedded_party_save()
		_open_start_menu()
	if _start_menu_host == null:
		return
	if not _walk_start_menu_to(Gen2WorldStartMenu.ITEM_MODS):
		return
	_start_menu_host.handle_button(Gen2Button.A)


## Public screenshot driver for the MOVES entry, which needs a registered
## field-move source before it exists at all: one call opens the menu on the row
## and a second opens the list of moves the bag can supply.
##
## The provider and the HM are synthetic, exactly as [method preview_pet_actor]'s
## actor is; the row, the list and the move behind it are the host's own.
func preview_field_moves_menu() -> void:
	if _world == null or _data == null:
		return
	if _start_menu_host == null:
		Gen2ModHost.instance().register_field_move_source(
			&"preview", PreviewFieldMoves.new()
		)
		var crystal: bool = Gen2WorldState.is_crystal_profile(_data)
		for move: int in Gen2WorldFieldMove.HM_FIELD_MOVES:
			var item: int = _preview_hm_item(move)
			if item > 0:
				_world.state.apply_changes({}, {}, {"items": {item: 1}})
			## The row lists only what the badge allows, so a development world
			## with no badges would offer nothing at all.
			var badge: int = Gen2WorldFieldMove.badge_for_move(move)
			if badge >= 0:
				_world.state.set_engine_flag(Gen2WorldState.badge_flag(badge, crystal))
		_injected_save = _embedded_party_save()
		_open_start_menu()
	if _start_menu_host == null:
		return
	if not _walk_start_menu_to(Gen2WorldStartMenu.ITEM_FIELD_MOVES):
		return
	_start_menu_host.handle_button(Gen2Button.A)


## `GetTMHMItemMove` walked backwards: the HM whose own move is [param move], or
## 0. Only a preview needs the inverse, so it is here rather than beside the
## lookup every other caller uses.
func _preview_hm_item(move: int) -> int:
	for number: int in range(RomLayout.TMHM_TM_COUNT + 1, _data.tmhm_moves().size() + 1):
		if _data.tmhm_move(number) == move:
			return RomLayout.item_for_tmhm_number(number, _data.tmhm_moves().size())
	return 0


## What a registered field-move source is, in the fewest lines that make the
## MOVES row appear.
class PreviewFieldMoves extends RefCounted:
	func allows_field_move(_move: int) -> bool:
		return true


## Public screenshot driver for the renewal question a Repel running out asks,
## which likewise needs a registered provider before it exists. The bag, the
## countdown and the box are the host's; only the provider is synthetic.
func preview_repel_renewal() -> void:
	if _world == null or _data == null or _service_host != null:
		return
	Gen2ModHost.instance().register_repel_renewal(&"preview", PreviewRepel.new())
	_injected_save = _embedded_party_save()
	_world.state.apply_changes({}, {}, {
		"items": {PreviewRepel.REPEL: 2}, "repel_steps": 1,
	})
	_world.state.count_step()
	if not _offer_repel_renewal():
		_script_prompt = "Repel renewal preview: nothing to offer"
		_refresh_labels()


## What a registered renewal provider is: the weakest Repel owned.
class PreviewRepel extends RefCounted:
	const REPEL: int = 0x14

	func repel_to_use(inventory: Dictionary) -> int:
		return REPEL if int(inventory.get(REPEL, 0)) > 0 else 0


## Public screenshot driver for `_Option`, which is what the start menu's own
## OPTION row opens. One call, since the picture wanted is the settings screen
## and not the row that reaches it.
func preview_options() -> void:
	if _world == null or _data == null:
		return
	if _start_menu_host == null:
		_injected_save = _embedded_party_save()
		_open_start_menu()
	if _start_menu_host == null:
		return
	if not _walk_start_menu_to(Gen2WorldStartMenu.ITEM_OPTION):
		return
	_start_menu_host.handle_button(Gen2Button.A)


## Walks the open start menu's cursor onto [param kind] and answers whether it
## got there. Bounded by the row count on purpose: a row the menu is not
## offering, because its gate is shut on this save, is a cursor that never
## reaches it, and an unbounded walk there spins a core without ever rendering a
## frame. Every `preview_*` driver below goes through this.
func _walk_start_menu_to(kind: StringName) -> bool:
	if _start_menu_host == null:
		return false
	var menu: Variant = _start_menu_host.get("_menu")
	## The menu's own length, not the source list's: MOVES, MODS and whatever
	## mods registered all sit ahead of EXIT, so a list built from the eight
	## source rows can be longer than eight and a row past that was unreachable.
	for _row: int in maxi(int(menu.size()), 1):
		if menu.selected_kind() == kind:
			return true
		_start_menu_host.handle_button(Gen2Button.DOWN)
	if menu.selected_kind() == kind:
		return true
	_script_prompt = "The start menu is not offering %s" % kind
	_refresh_labels()
	return false


## Public screenshot driver for the Pokegear, reached the way a player reaches
## it: START and the POKEGEAR row. The picture is `Pokegear_LoadGFX`'s own card
## list; a card opened from it is a full screen of its own and has its own cases.
func preview_pokegear() -> void:
	if _world == null or _data == null:
		return
	if _service_host == null and _start_menu_host == null:
		_injected_save = _embedded_party_save()
		## The row is gated on ENGINE_POKEGEAR, which a world opened straight
		## onto a map has not been given yet.
		_world.state.apply_changes({}, {}, {
			"engine_flags": {Gen2WorldStartMenu.ENGINE_POKEGEAR: true},
		})
		_open_start_menu()
	if _start_menu_host != null:
		if not _walk_start_menu_to(Gen2WorldStartMenu.ITEM_POKEGEAR):
			return
		## The row opens the overlay through the same signal a press does, so
		## the card list is up by the time this returns.
		_start_menu_host.handle_button(Gen2Button.A)


## Public screenshot drivers for `SaveMenu`, one per box it puts up:
## `WouldYouLikeToSaveTheGameText` with its yes/no, `AlreadyASaveFileText` past
## `_ContText`'s own wait, and `SavingDontTurnOffThePowerText` with no question
## behind it. An injected save keeps the write in memory, the way
## [method preview_pack_toss] keeps its stack.
func preview_save_menu() -> void:
	_preview_save_menu(0)


func preview_save_overwrite() -> void:
	_preview_save_menu(2)


func preview_save_writing() -> void:
	_preview_save_menu(3)


## [param answers] is how many A presses to spend past the first question.
func _preview_save_menu(answers: int) -> void:
	if _world == null or _data == null or _start_menu_host != null:
		return
	_injected_save = _embedded_party_save()
	_open_start_menu()
	if _start_menu_host == null:
		return
	if not _walk_start_menu_to(Gen2WorldStartMenu.ITEM_SAVE):
		return
	for _press: int in answers + 1:
		_start_menu_host.handle_button(Gen2Button.A)


## Public screenshot driver for `TossMenu`. Grants a stack on an injected save
## so nothing persists, then advances one menu step per call: Pack, the item,
## TOSS, the quantity dial, the yes/no and the result.
func preview_pack_toss() -> void:
	if _world == null or _data == null:
		return
	if _start_menu_host != null:
		## The submenu opens on USE, so the cursor is walked onto TOSS before the
		## press that chooses it. Every other step is a plain A.
		if _start_menu_host.get("_mode") == Gen2StartMenuScreen.Mode.PACK_ITEM:
			var actions: Array = _start_menu_host.get("_item_actions")
			for index: int in actions.size():
				if StringName((actions[index] as Dictionary).get("action", &"")) \
					== Gen2WorldPack.ACTION_TOSS:
					_start_menu_host.set("_item_cursor", index)
					break
		_start_menu_host.handle_button(Gen2Button.A)
		return
	var save: Gen2SaveData = _embedded_party_save()
	if save == null:
		_script_prompt = "Toss preview needs a save"
		_refresh_labels()
		return
	_injected_save = save
	_world.state.apply_changes({}, {}, {"items": {Gen2WorldPartyHost.ITEM_POTION: 5}})
	_open_start_menu()
	if _start_menu_host == null:
		return
	if not _walk_start_menu_to(Gen2WorldStartMenu.ITEM_PACK):
		return
	_start_menu_host.handle_button(Gen2Button.A)


## Public screenshot driver for ForgetMove. It fills the first party member's
## four move slots and grants a TM or HM that member can learn, on an injected
## save so nothing persists, then advances one menu step per call: Pack, the
## TM/HM, USE, YES, the party member, ForgetMove's ask, and the move list.
##
## The granted item is whichever TM or HM this species can actually learn, since
## a development save's first member is whatever the cache holds; a species that
## can learn none reports that rather than opening a menu it cannot fill.
func preview_move_forget() -> void:
	if _world == null or _data == null:
		return
	if _start_menu_host != null:
		_start_menu_host.handle_button(Gen2Button.A)
		return
	var save: Gen2SaveData = _embedded_party_save()
	if save == null or save.party.is_empty():
		_script_prompt = "Forget preview needs a party"
		_refresh_labels()
		return
	var mon: Gen2SaveMon = save.party[0]
	var item: int = _teachable_tmhm_for(mon.species)
	if item <= 0:
		_script_prompt = "Forget preview: this species learns no TM or HM"
		_refresh_labels()
		return
	# Four moves the species need not know legitimately: ForgetMove is reached by
	# the slot count alone, and this is a screenshot rather than a save.
	mon.moves = [1, 2, 3, 4]
	mon.pp = [10, 10, 10, 10]
	_injected_save = save
	_world.state.apply_changes({}, {}, {"items": {item: 1}})
	_open_start_menu()
	if _start_menu_host == null:
		return
	if not _walk_start_menu_to(Gen2WorldStartMenu.ITEM_PACK):
		return
	_start_menu_host.handle_button(Gen2Button.A)
	# The pack opens on the ITEM pocket, and the granted item is in the TM/HM
	# one. The guard bounds the walk in case no such pocket is built.
	var guard: int = Gen2WorldPack.POCKET_ORDER.size() + 1
	while guard > 0 and _previewed_pocket() != Gen2WorldPack.TYPE_TM_HM:
		_start_menu_host.handle_button(Gen2Button.RIGHT)
		guard -= 1


func _previewed_pocket() -> int:
	var pockets: Array = _start_menu_host.get("_pack_pockets")
	var index: int = int(_start_menu_host.get("_pack_pocket_index"))
	if index < 0 or index >= pockets.size():
		return -1
	return int((pockets[index] as Dictionary).get("pocket", -1))


## The first TM or HM item [param species] can learn, or 0. Walks the numbers
## rather than the items, since the run is not contiguous.
func _teachable_tmhm_for(species: int) -> int:
	var count: int = _data.tmhm_moves().size()
	for number: int in range(1, count + 1):
		var move: int = _data.tmhm_move(number)
		if move > 0 and Gen2WorldTMHM.can_learn(_data, species, move):
			return RomLayout.item_for_tmhm_number(number, count)
	return 0


## Public screenshot driver for the battle-request host path. It starts the
## same request shape emitted by [Gen2WorldScriptRunner], without pretending a
## map event was present in the selected development map.
##
## [param battle_type] is `wBattleType`, so
## [constant Gen2Battle.BATTLETYPE_FORCESHINY] opens the fight the Lake of Rage
## Gyarados is met in.
func preview_battle_request(
	species: int = 16, at_level: int = 5,
	battle_type: int = Gen2Battle.BATTLETYPE_NORMAL
) -> void:
	_start_battle_request({
		"kind": &"battle_requested",
		"values": {
			"kind": &"wild", "pokemon": species, "level": at_level,
			"battle_type": battle_type,
		},
	})


## Public screenshot driver for a wild that is already standing on the map: the
## one a provider put on [param cell], met exactly as a step onto that cell meets
## it. The entry's id travels with the request, so the provider is told how the
## fight ended and can take its Pokemon off the map; a battle started any other
## way leaves the sprite standing where it was.
func preview_meet_visible_encounter(cell: Vector2i) -> bool:
	if _encounters == null or not _encounters.active():
		return false
	var request: Dictionary = _encounters.battle_request_at(cell)
	if request.is_empty():
		return false
	_battle_encounter_id = StringName(request["visible_encounter"])
	_zero_map_name_sign_timer()
	_start_battle_request(request)
	return true


## Public screenshot driver for the real wild capture bridge. It adds one
## development Master Ball, starts an imported wild encounter, and leaves the
## production battle overlay on its throw message.
## `CatchTutorial`: the Dude's own fight, which answers itself. `Route29Tutorial1`
## loads the same `loadwildmon RATTATA, 5` in front of it.
func preview_catch_tutorial() -> void:
	_start_battle_request({
		"kind": &"catch_tutorial_requested",
		"values": {
			"kind": &"wild", "pokemon": 19, "level": 5,
			"battle_type": Gen2Battle.BATTLETYPE_TUTORIAL,
			"tutorial": true, "can_lose": false,
		},
	})


func preview_capture() -> void:
	if _world == null:
		return
	var added: Dictionary = _world.state.apply_changes(
		{}, {}, {"items": {Gen2WorldPartyHost.ITEM_MASTER_BALL: 1}}
	)
	if not bool(added.get("ok", false)):
		return
	var encounter: Dictionary = _world.encounter_request(_encounter_random, true)
	if encounter.is_empty():
		_script_prompt = "No wild encounter for capture preview"
		_refresh_labels()
		return
	_start_battle_request({
		"kind": &"battle_requested",
		"values": encounter["values"],
		"encounter": encounter.duplicate(true),
	})
	call_deferred("_preview_capture_throw")


## Retried on the next idle frame rather than inside this one: a `call_deferred`
## made while the queue is flushing is appended to the flush that is running, so
## a self-deferring retry never lets a frame pass and fills the queue instead.
func _preview_capture_throw() -> void:
	if _preview_throw_master_ball():
		return
	if _battle_host != null:
		get_tree().process_frame.connect(
			_preview_capture_throw, CONNECT_ONE_SHOT | CONNECT_DEFERRED
		)


## True once the throw has been made. False while the battle has no live wild
## target yet, which is the caller's cue to spend a frame and ask again.
func _preview_throw_master_ball() -> bool:
	if _battle_host == null or _battle_host.capture_target() == null:
		return false
	var balls: Array[int] = _battle_host.available_capture_balls()
	var master_index: int = balls.find(Gen2WorldPartyHost.ITEM_MASTER_BALL)
	if master_index < 0:
		return true
	if not bool(_battle_host.begin_capture().get("ok", false)):
		return true
	_battle_host.select_capture_ball(master_index)
	_battle_host.throw_capture_ball()
	_battle_host.finish()
	return true


## Public screenshot driver for `PokeBallEffect`'s own `AskGiveNicknameText`,
## which stands over the battle rather than over the map: [method
## preview_capture]'s throw, driven past `Text_GotchaMonWasCaught` to the
## question. Answers whether the prompt is up.
func preview_catch_nickname() -> bool:
	preview_capture()
	## `DoBattleTransition` stands between the request and the fight, and the
	## throw needs the fight: the `battle` preview settles it the same way.
	settle_battle_transition()
	for _frame: int in CATCH_NICKNAME_FRAMES:
		if _battle_host == null:
			return false
		if _preview_throw_master_ball():
			break
		_battle_host.advance_hardware_frame()
	## `BattleIntroSlidingPics`, the throw line and up to four shakes, each of
	## them a box that owes frames before the press that clears it.
	for _frame: int in CATCH_NICKNAME_FRAMES:
		if _battle_host == null:
			return false
		var prompt: Gen2NicknamePromptScreen = _battle_host.get("_capture_nickname_host")
		if prompt != null:
			if prompt.question_ready():
				_script_prompt = "Nickname"
				_refresh_labels()
				return true
		else:
			_battle_host.finish()
			_battle_host.advance()
		_battle_host.advance_hardware_frame()
	return false


## Enough for the battle's own opening, the throw and the shakes, each of which
## is a box printing at the OPTION screen's own speed.
const CATCH_NICKNAME_FRAMES: int = 1200


## Public screenshot driver for a resolved imported wild encounter. It uses the
## current standing terrain and skips only the rate roll, leaving slot and surf
## level selection on the production resolver path.
func preview_wild_encounter() -> void:
	if _world == null:
		return
	var encounter: Dictionary = _world.encounter_request(_encounter_random, true)
	if encounter.is_empty():
		_script_prompt = "No normal encounter table for this map and terrain"
		_refresh_labels()
		return
	_start_battle_request({
		"kind": &"battle_requested",
		"values": encounter["values"],
		"encounter": encounter.duplicate(true),
	})


## Public screenshot driver for `.Field`: grants [param item] on an injected
## save, opens the pack on the key items and uses it, so what is photographed is
## the world's own answer with the pack already closed behind it.
func preview_field_item(item: int = Gen2WorldPack.ITEM_ITEMFINDER) -> void:
	if _world == null or _data == null or _start_menu_host != null:
		return
	_injected_save = _embedded_party_save()
	# The coins are for the Coin Case, which is the one row here whose own words
	# are a number; every other item ignores them.
	_world.state.apply_changes({}, {}, {"items": {item: 1}, "coins": 1234})
	_open_start_menu()
	if _start_menu_host == null:
		return
	if not _walk_start_menu_to(Gen2WorldStartMenu.ITEM_PACK):
		return
	_start_menu_host.handle_button(Gen2Button.A)
	# The row itself, rather than whichever one the pocket opens on: the save may
	# already own other key items, and a capture has to photograph the named one.
	if not bool(_start_menu_host.call("_select_pack_item", item)):
		return
	# The row's submenu, and then its first action, which for a key item is USE.
	_start_menu_host.handle_button(Gen2Button.A)
	_start_menu_host.handle_button(Gen2Button.A)
	if _text_box != null:
		# The box reveals a tile at a time off wall-clock delta, and a capture
		# owning its own frames spends none on that.
		_text_box.finish()


## Public screenshot and scene-test driver for the production fishing path.
## The caller can advance the cast and bite pauses with Space, Enter or Z.
func preview_fishing() -> void:
	_position_for_fishing_preview()
	start_fishing(true)


func preview_fishing_battle() -> void:
	if _world == null:
		return
	_position_for_fishing_preview()
	var started: Dictionary = start_fishing(true)
	if not bool(started.get("ok", false)):
		return
	var bite: Dictionary = _world.advance_fishing()
	if StringName(bite.get("kind", &"")) != &"fishing_bite":
		_handle_fishing_result(bite)
		return
	_handle_fishing_result(_world.advance_fishing())


func _position_for_fishing_preview() -> void:
	if _world.current_map == null or _world.current_map.fish_group <= 0:
		return
	var map_size: Vector2i = _world.map_size_cells()
	var directions: Array[Vector2i] = [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]
	for y: int in map_size.y:
		for x: int in map_size.x:
			var cell := Vector2i(x, y)
			if _world.collision_permission_at(cell) != Gen2WorldCollision.LAND_TILE:
				continue
			for direction: Vector2i in directions:
				if _world.collision_permission_at(cell + direction) != Gen2WorldCollision.WATER_TILE:
					continue
				_world.player_cell = cell
				_world.player_facing = _world.facing_for_direction(direction)
				if _renderer != null:
					_renderer.refresh()
				return


func select_fishing_rod(index: int) -> Dictionary:
	if _world == null:
		return {"ok": false, "reason": &"missing_map"}
	var rods: Array[StringName] = _world.available_fishing_rods()
	if index < 0 or index >= rods.size():
		return {"ok": false, "reason": &"invalid_rod"}
	_selected_rod = rods[index]
	_script_prompt = "Selected %s. F: cast" % Gen2WorldFishing.rod_label(_selected_rod)
	_refresh_labels()
	return {"ok": true, "rod": _selected_rod}


func start_fishing(force_encounter: bool = false) -> Dictionary:
	if _world == null:
		return {"ok": false, "reason": &"missing_map"}
	var result: Dictionary = _world.fishing_request(
		_selected_rod, _encounter_random, force_encounter
	)
	if not bool(result.get("ok", false)):
		_script_prompt = "Fishing failed: %s" % String(result.get("reason", "unknown"))
		_refresh_labels()
		return result
	_script_prompt = "Cast %s. A: wait" % String(result.get("rod_label", "ROD"))
	_refresh_labels()
	return result


func _handle_fishing_result(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		_script_prompt = "Fishing stopped: %s" % String(result.get("reason", "unknown"))
		_refresh_labels()
		return
	match StringName(result.get("kind", &"")):
		&"fishing_no_bite":
			_script_prompt = "Nothing was hooked. F: cast again"
		&"fishing_bite":
			_script_prompt = "A bite! Press A to reel in"
		&"battle_requested":
			_start_battle_request(result)
			return
		_:
			_script_prompt = "Fishing: %s" % String(result.get("kind", "unknown"))
	_refresh_labels()


## `StartBattle`: the transition first, and the battle screen only once it has
## finished. `PlayBattleMusic` runs in front of `DoBattleTransition`, so the
## map's track stops and the battle's own starts here, 170 frames before the
## fight is built, and the animation is played under it rather than in silence.
func _start_battle_request(request: Dictionary) -> void:
	if _battle_host != null or _battle_transition != null or _data == null:
		return
	_play_battle_music(request)
	_battle_transition_request = request.duplicate(true)
	_battle_transition = _build_battle_transition(request)
	if _battle_transition == null:
		_open_battle_host(_battle_transition_request)
		return
	_apply_battle_transition()
	_script_prompt = "Battle starting"
	_refresh_labels()


## `StartTrainerBattle_DetermineWhichAnimation`'s two bits, and the ball only a
## trainer's own transition draws.
func _build_battle_transition(request: Dictionary) -> Gen2BattleTransition:
	if _world == null or _data == null:
		return null
	var values: Dictionary = request.get("values", {})
	if bool(values.get("tutorial", false)):
		return null
	## A link battle starts from `LinkCommunications`' own screen rather than
	## from the map, so there is no map for `DoBattleTransition` to wipe away.
	if bool(values.get("link", false)):
		return null
	var environment: int = _world.current_map.environment if _world.current_map != null else 0
	## `cp CAVE / cp ENVIRONMENT_5 / cp DUNGEON`, the three the flash and the
	## wavy outro belong to.
	var cave: bool = environment in Gen2WorldAPI.CAVE_ENVIRONMENTS
	var lead: int = _battle_lead_level()
	var opponent: int = int(values.get("level", lead))
	return Gen2BattleTransition.create(
		lead + Gen2BattleTransition.STRONGER_MARGIN < opponent,
		cave,
		int(values.get("trainer_class", 0)) > 0,
		_render_time_of_day() == Gen2WorldPalette.TIME_DARK,
		_encounter_random,
		_data.battle_anim_sine()
	)


## `wBattleMonLevel`, which is the party's own lead rather than the battle's:
## the transition is picked before `InitBattleMon` has run.
func _battle_lead_level() -> int:
	var save: Gen2SaveData = _injected_save if _injected_save != null \
		else _selected_runtime_save()
	if save == null or save.party.is_empty():
		return 1
	return int((save.party[0] as Gen2SaveMon).level)


## `DoBattleTransition` alone, driven to [param frames] frames in, for a
## screenshot: the transition over the map it actually runs on, without the
## battle behind it. [param trainer] is the branch that draws the Poke Ball and
## floods every background tile with `PAL_BG_TEXT`.
func preview_battle_transition(frames: int, trainer: bool = false) -> void:
	_battle_transition = Gen2BattleTransition.create(
		false, false, trainer, false, _encounter_random,
		_data.battle_anim_sine() if _data != null else PackedByteArray()
	)
	_apply_interface_mask()
	_apply_battle_transition()
	for _frame: int in maxi(frames, 0):
		if _battle_transition == null:
			break
		_battle_transition.advance_frame()
		_apply_battle_transition()


## Spends `DoBattleTransition` where the caller wants the battle rather than the
## animation in front of it, which is every driver that opens one without a
## person watching.
func settle_battle_transition(limit: int = 600) -> void:
	var guard: int = limit
	while _battle_transition != null and guard > 0:
		advance_frame()
		guard -= 1


## Whether `DoBattleTransition` is still running, which is the several seconds
## between an encounter resolving and the battle screen existing.
func battle_transition_running() -> bool:
	return _battle_transition != null


func _advance_battle_transition() -> void:
	if _battle_transition == null:
		return
	_battle_transition.advance_frame()
	_apply_battle_transition()
	if not _battle_transition.finished():
		return
	var request: Dictionary = _battle_transition_request
	_battle_transition = null
	_battle_transition_request = {}
	if _renderer != null and _renderer.has_method("clear_transition"):
		_renderer.clear_transition()
	_open_battle_host(request)


## What the transition is showing right now, handed to whatever is drawing the
## map. A renderer of a mod's own that does not take it draws the map as it was,
## which is the same contract the map fade has.
func _apply_battle_transition() -> void:
	if _renderer == null or _battle_transition == null:
		return
	if not _renderer.has_method("set_transition"):
		return
	_renderer.set_transition(
		_battle_transition.cells(),
		_data.tile_indices("battle_transition") if _data != null else PackedByteArray(),
		_data.battle_transition_palette(
			_render_time_of_day() == Gen2WorldPalette.TIME_DARK
		) if _battle_transition.ball_drawn() and _data != null else PackedColorArray(),
		_battle_transition.sprites(),
		## `hLastTalked`, which `RespawnPlayerAndOpponent` keeps beside the
		## player. A wild encounter has none and leaves the player alone.
		int(_battle_transition_request.get("values", {}).get("object_index", -1)),
		## `StartTrainerBattle_Flash` writes `wBGP` and calls `DmgToCgbBGPals`
		## alone, so this is the background's order and not the map fade's:
		## the sprites standing over the wedges keep their own colours.
		_battle_transition.palette_order(),
	)


## `PlayBattleMusic`, resolved from the request rather than from a fight that
## does not exist yet. Asking twice for the same track is what the driver
## continues, so the transition and the battle screen behind it never restart the
## piece between them.
func _play_battle_music(request: Dictionary) -> void:
	if _audio_player == null or _data == null:
		return
	var landmark: int = _world.landmark_backup() if _world != null \
		else Gen2WorldRadio.LANDMARK_SPECIAL
	var track: int = Gen2WorldBattleAdapter.music_for(
		request, landmark, time_of_day, Gen2WorldState.is_crystal_profile(_data)
	)
	var record: Dictionary = _data.world_audio(&"music", track)
	if record.is_empty():
		_audio_player.stop_all()
		return
	_audio_player.play_record(record, &"map_music", _audio_assets())


func _open_battle_host(request: Dictionary) -> void:
	if _battle_host != null or _data == null:
		return
	var values: Dictionary = request.get("values", {})
	var tutorial: bool = bool(values.get("tutorial", false))
	var save: Gen2SaveData = _injected_save if _injected_save != null else _selected_runtime_save()
	_active_battle_save = save
	_active_battle_persist = save != null and _injected_save == null
	_active_battle_trainer = StringName(values.get("kind", &"")) == &"trainer"
	_battles_fought += 1
	var host: Gen2BattleScreen = BATTLE_SCENE.instantiate() as Gen2BattleScreen
	host.set_data(_data)
	host.set_audio_player(_audio_player)
	host.set_rules(_world.rules if _world != null else null)
	## Drawn from the world's own generator, so the fight's own decisions are part
	## of the run's seeded chain and a replay reproduces them without recording
	## anything about the battle. Its frames and its buttons both come through this
	## screen from here on.
	host.set_random_seed(_encounter_random.randi())
	host.set_driven(true)
	host.set_time_of_day(time_of_day)
	# The clock's row is what the battle's own heals read; the drawn row is what
	# a renderer staging the fight on this map has to match, so the context
	# carries that one.
	host.set_world_context(Gen2BattleWorldContext.capture(_world, _render_time_of_day()))
	var badges: int = _world.state.badge_mask(Gen2WorldState.is_crystal_profile(_data)) \
		if _world != null and _world.state != null else 0
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.z_index = 10
	host.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(host)
	host.battle_finished.connect(_on_battle_finished)
	host.enemy_seen.connect(_on_enemy_seen)
	host.capture_requested.connect(_on_capture_requested)
	host.dex_entry_requested.connect(_on_battle_dex_entry_requested)
	host.item_used.connect(_on_battle_item_used)
	_battle_host = host
	## Started after the connections and here rather than left to the host's own
	## deferred call: `startbattle` is a script command, so the fight belongs to
	## the frame the encounter fired on, and a run driven frame by frame (a check,
	## a replay) never reaches a deferred call at all.
	## `PlayBattleMusic` has already run, either in front of the transition or
	## here for a request that had none, and the fight is handed this screen's own
	## driver, so its first cry takes the channels the track is holding.
	_play_battle_music(request)
	host.start_world_battle(request.duplicate(true), save, badges)
	_claim_nuzlocke_encounter(host, values, save)
	## The three dex answers `PokeBallEffect` reads, taken off live state before
	## the entrance registers the sight it is about to show.
	if _world != null and _world.state != null:
		var species: int = int(values.get("pokemon", 0))
		host.set_dex_context(
			species > 0 and _world.state.has_seen_species(species),
			species > 0 and _world.state.has_caught_species(species),
			_world.state.is_engine_flag_active(Gen2WorldState.ENGINE_POKEDEX)
		)
	## After the fight exists, because starting one clears whatever capture action
	## was staged: the bag belongs to this battle rather than to the last one.
	if _world != null and not tutorial:
		## `BattleMenu_Pack`'s contest branch loads PARK_BALL and nothing else,
		## and the count is `wParkBallsRemaining` rather than the bag.
		if _world.bug_contest_active():
			host.set_capture_balls(
				[Gen2WorldPartyHost.ITEM_PARK_BALL],
				{Gen2WorldPartyHost.ITEM_PARK_BALL: _world.state.park_balls()}
			)
		else:
			host.set_capture_balls(
				Gen2WorldPartyHost.owned_capture_balls(_world), _world.state.items()
			)
			host.set_battle_pack(
				Gen2WorldPack.battle_items(_data, _world.state), _world.state.items()
			)
	## Its frames come from this screen's own pump from here on, so it must not
	## also spend real-time ones of its own.
	host.set_process(false)
	_script_prompt = "Battle in progress"
	_refresh_labels()


## The Nuzlocke's first rule, at the one place every battle is opened. An area
## gives up one encounter, and it gives it up the moment the Pokemon is met rather
## than when a ball lands: beating it or running from it spends it just the same,
## which is the rule's "no second chances". The claim is written to disk here for
## the same reason a death is, so a reload cannot hand the area back. Two wild
## battles claim nothing: the Bug Catching Contest has its own park balls, and a
## roamer belongs to no area at all, its landmark being wherever it caught the
## player.
func _claim_nuzlocke_encounter(
	host: Gen2BattleScreen, values: Dictionary, save: Gen2SaveData
) -> void:
	if _world == null:
		return
	_world.nuzlocke_area_open = -1
	if _world.rules == null or not _world.rules.is_nuzlocke() or save == null:
		return
	if StringName(values.get("kind", &"")) != &"wild" or _world.bug_contest_active():
		return
	## The catching tutorial's Pokemon is nobody's encounter: no ball is thrown
	## by the player and the fight is scripted from both sides.
	if bool(values.get("tutorial", false)):
		return
	if int(values.get("battle_type", Gen2Battle.BATTLETYPE_NORMAL)) \
		== Gen2Battle.BATTLETYPE_ROAMING:
		return
	var landmark: int = _world.landmark_backup()
	if not Gen2Nuzlocke.claim_area(
		save.nuzlocke, landmark, int(values.get("pokemon", 0))
	):
		host.set_capture_refusal(Gen2Nuzlocke.area_spent_text(_landmark_name(landmark)))
		return
	_world.nuzlocke_area_open = landmark
	_persist_after_battle(save)


## The area's own name, as the town map spells it. Empty where the cache has
## none, which is what the refusal line falls back on.
func _landmark_name(landmark: int) -> String:
	if _data == null or landmark < 0:
		return ""
	return _data.landmark_name(landmark)


## `LoadEnemyMon`'s dex write, and the `wFirstUnownSeen` write beside it: the
## letter of the first Unown the save meets is stored whether it is caught or
## only seen. Both land on live world state, so the next snapshot carries them
## exactly as the cartridge's next save does.
func _on_enemy_seen(species: int, unown_form: int) -> void:
	if _world == null or _world.state == null:
		return
	_world.state.set_species_seen(species)
	if species == RomLayout.UNOWN_SPECIES:
		_world.state.note_first_unown_seen(unown_form)


func _on_capture_requested(ball: int) -> void:
	if _battle_host == null or _world == null or _data == null:
		return
	var save: Gen2SaveData = _active_battle_save
	if save == null:
		save = Gen2SaveStore.create_development_save(_data, 0)
		if save != null:
			save.world = _world.snapshot()
		_active_battle_save = save
		_active_battle_persist = false
	## The ball is thrown from a party that has already fought: the catch's own
	## candidate is built from this save, so the fought HP and PP have to be on
	## it before the transaction opens.
	_battle_host.sync_live_party()
	var target: Gen2BattleMon = _battle_host.capture_target()
	## A contest throw is its own transaction: the ball is the contest's, the
	## catch goes to wContestMon and no save is touched.
	var result: Dictionary = (
		Gen2WorldPartyHost.capture_contest(_world, target, _encounter_random)
		if _world.bug_contest_active()
		else Gen2WorldPartyHost.capture_wild(
			_world, save, target, ball, _encounter_random, 0, _active_battle_persist,
			_battle_host.capture_battle_type(), _battle_host.capture_thrower()
		)
	)
	_battle_host.complete_capture(result)
	_refresh_labels()


## `NewPokedexEntry` behind `Text_GotchaMonWasCaught`: the page stands over the
## battle, and the battle waits for it. The world opens it because the world owns
## the dex; a cache with no entry for the species answers straight away.
func _on_battle_dex_entry_requested(species: int) -> void:
	if _battle_host == null:
		return
	if not _open_pokedex_entry({"values": {"species": species}}):
		_battle_host.complete_dex_entry()


## `UseDisposableItem` inside a battle: the effect has already landed on the
## party the battle owns, so all the world does is take the row down by one.
## `InitNickname` behind `PokeBallEffect`'s own `YesNoBox`. The battle screen
## owns the question and the keyboard, because the routine runs inside the
## fight; the row it names is on the save this screen handed the catch.
func _apply_capture_nickname(capture: Dictionary) -> void:
	var nickname: String = String(capture.get("nickname", ""))
	if nickname.is_empty() or _world == null:
		return
	var save: Gen2SaveData = _active_battle_save
	if save == null:
		return
	var named: Dictionary = Gen2WorldPartyHost.name_captured_mon(
		_world, save, capture.get("destination", {}), nickname, _active_battle_persist
	)
	if not bool(named.get("ok", false)):
		_script_prompt = "Nickname refused: %s" % String(named.get("reason", "unknown"))


func _on_battle_item_used(item: int, _target: int) -> void:
	if _world == null or _world.inventory == null:
		return
	_world.inventory.change_item_quantity(item, -1)
	if _battle_host != null:
		_battle_host.set_battle_pack(
			Gen2WorldPack.battle_items(_data, _world.state), _world.state.items()
		)
		_battle_host.set_capture_balls(
			Gen2WorldPartyHost.owned_capture_balls(_world), _world.state.items()
		)


func _on_battle_finished(result: Dictionary) -> void:
	var host: Gen2BattleScreen = _battle_host
	_battle_host = null
	if host != null:
		Gen2Screen.drop(host)
	if not String(_battle_encounter_id).is_empty():
		var fought: StringName = _battle_encounter_id
		_battle_encounter_id = &""
		if _encounters != null:
			_encounters.battle_finished(fought, result.duplicate(true))
	if _world == null:
		return
	_last_battle_outcome = StringName(result.get("outcome", &""))
	_record_roam_battle(result)
	if not _link_battle_peer.is_empty():
		_record_link_battle(result)
	## `.give_money`'s prize and `CheckPayDay`'s coins, worked out once by the
	## battle screen and handed over per account: this is the live state, and the
	## snapshot that screen wrote already carries the same credit.
	var awarded: Variant = result.get("money_awarded", {})
	if awarded is Dictionary \
			and StringName(result.get("outcome", &"")) == Gen2WorldBattleAdapter.OUTCOME_WON:
		Gen2WorldBattleAdapter.credit_earnings(_world.state, awarded as Dictionary)
	## `ExitBattle`'s own tail, in its order: `CheckPayDay`, then
	## `EvolveAfterBattle`, then `GivePokerusAndConvertBerries`, and only then
	## does the map come back. The evolution owns frames, so the rest of the exit
	## is what its screen resumes into rather than something that runs behind it.
	var fought_save: Gen2SaveData = _active_battle_save
	var plans: Array = _after_battle_evolution_plans(result, fought_save)
	if not plans.is_empty():
		_open_evolution(plans, fought_save, func() -> void:
			_finish_battle_exit(result, fought_save)
		)
		return
	_finish_battle_exit(result, fought_save)


## `BattleEnd_HandleRoamMons`, which `ExitBattle` reaches on the way out of any
## battle and which does nothing unless `wBattleType` is `BATTLETYPE_ROAMING`.
## A caught or defeated roamer empties its struct; anything else stores the HP
## and the DVs the fight leaves behind, so the next encounter is the same
## Pokemon on the bar the player left it on.
func _record_roam_battle(result: Dictionary) -> void:
	if _world == null or _world.state == null:
		return
	## `prepare()` answers the values dictionary itself under `request`, which is
	## the same shape `win_text` and `loss_text` are read out of.
	var values: Variant = result.get("request", {})
	if not values is Dictionary:
		return
	if int((values as Dictionary).get("battle_type", 0)) != Gen2Battle.BATTLETYPE_ROAMING:
		return
	var enemy: Variant = result.get("enemy", {})
	if not enemy is Dictionary or (enemy as Dictionary).is_empty():
		return
	var outcome: StringName = StringName(result.get("outcome", &""))
	var won: bool = outcome in [
		Gen2WorldBattleAdapter.OUTCOME_WON, Gen2WorldBattleAdapter.OUTCOME_CAUGHT,
	]
	_world.state.note_roam_battle_end(
		int((enemy as Dictionary).get("species", 0)), won,
		int((enemy as Dictionary).get("hp", 0)),
		int((enemy as Dictionary).get("dvs", 0)),
	)


## `AddLastLinkBattleToLinkRecord`, which runs on the way out of a Colosseum
## battle and nowhere else. A draw is what `wBattleResult` says when neither
## side was wiped out.
func _record_link_battle(result: Dictionary) -> void:
	var peer: Dictionary = _link_battle_peer
	_link_battle_peer = {}
	var outcome: StringName = StringName(result.get("outcome", &""))
	var key: StringName = &"draws"
	if outcome == Gen2WorldBattleAdapter.OUTCOME_WON:
		key = &"wins"
	elif outcome == Gen2WorldBattleAdapter.OUTCOME_LOST:
		key = &"losses"
	var save: Gen2SaveData = _active_battle_save
	if save == null:
		return
	Gen2WorldPartyHost.record_link_battle(
		_world, save, {"name": peer.get("name", ""), "id": peer.get("id", 0)},
		key, _active_battle_persist
	)


## `EvolveAfterBattle`'s `wEvolvableFlags`, read only on a battle that was won.
func _after_battle_evolution_plans(result: Dictionary, save: Gen2SaveData) -> Array:
	if _data == null or save == null or _world == null:
		return []
	if StringName(result.get("outcome", &"")) != Gen2WorldBattleAdapter.OUTCOME_WON:
		return []
	return Gen2Evolution.after_battle(
		_data, save, result.get("evolvable", []), _world.object_time_of_day
	)


## Everything `ExitBattle` does once `EvolveAfterBattle` has returned.
func _finish_battle_exit(result: Dictionary, fought_save: Gen2SaveData) -> void:
	if _world == null:
		return
	## `InitNickname` behind `PokeBallEffect`'s own `YesNoBox`, spent here rather
	## than after the map reload below: the row it names is a party index, and
	## the Nuzlocke pass under it takes rows out.
	if StringName(result.get("outcome", &"")) == Gen2WorldBattleAdapter.OUTCOME_CAUGHT:
		var caught: Dictionary = result.get("capture", {})
		if not bool(caught.get("contest", false)):
			_apply_capture_nickname(caught)
	_reap_nuzlocke_faints(fought_save, Gen2Nuzlocke.CAUSE_BATTLE)
	## The encounter this fight claimed is over, whatever it came to.
	_world.nuzlocke_area_open = -1
	if StringName(result.get("outcome", &"")) == Gen2WorldBattleAdapter.OUTCOME_WON:
		Gen2WorldPartyHost.give_pokerus_and_convert_berries(
			_data, fought_save, _world, _encounter_random
		)
		_persist_after_battle(fought_save)
	elif bool((result.get("capture", {}) as Dictionary).get("experience_awarded", false)):
		## A capture commits its own transaction when the ball lands, which is
		## before a registered policy's experience exists. The party the battle
		## synced back carries it, so this is where it reaches disk.
		_persist_after_battle(fought_save)
	var resumed: Array = _world.complete_runtime_request(result)
	if resumed.is_empty():
		## `WildBattleScript` is `randomwildmon`, `startbattle`,
		## `reloadmapafterbattle`, `end`: a wild encounter reloads the map on the
		## way out even though no script was suspended, and that reload is what
		## puts the five-step cooldown back so the next step cannot roll another.
		_world.reload_current_map()
		if _renderer != null:
			_renderer.refresh()
		if StringName(result.get("outcome", &"")) == Gen2WorldBattleAdapter.OUTCOME_CAUGHT:
			var capture: Dictionary = result.get("capture", {})
			if bool(capture.get("contest", false)):
				## The catch is only kept when the question the battle asked was
				## answered YES, or when there was nothing to replace, which the
				## host already stored.
				var caught_mon: Dictionary = capture.get("mon", {})
				if bool(capture.get("replace", false)) and not caught_mon.is_empty():
					_world.state.set_contest_mon(caught_mon)
				var held: Dictionary = _world.state.contest_mon()
				_script_prompt = "Contest: holding %s, %d PARK BALLs left" % [
					String(_data.species(int(held.get("species", 0))).get("name", "nothing")),
					_world.state.park_balls(),
				]
			else:
				var species: Dictionary = _data.species(int(capture.get("species", 0)))
				_script_prompt = "Caught %s" % String(species.get("name", "UNKNOWN"))
		else:
			_script_prompt = "Battle finished: %s" % String(
				result.get("outcome", result.get("reason", "unknown"))
			)
		## `WildBattleScript` ends in `reloadmapafterbattle` like every other
		## battle, so a wild fight that was lost reaches `Script_BattleWhiteout`
		## even though no script of the map's was suspended.
		if StringName(result.get("outcome", &"")) == Gen2WorldBattleAdapter.OUTCOME_LOST:
			_active_battle_save = null
			_active_battle_persist = false
			_start_whiteout()
			return
	else:
		_show_script_results(resumed)
	_active_battle_save = null
	_active_battle_persist = false
	## `MapSetupScript_ReloadMap`'s `ForceMapMusic`, which is `TryRestartMapMusic`:
	## a battle leaves through a map reload, and that reload is what puts the
	## map's own track back over the one `PlayBattleMusic` started.
	_play_current_map_music()
	_start_box_full_call()
	_start_mom_purchase_call()
	_refresh_labels()


## The Nuzlocke's second rule: a faint is a death, so every party member at zero HP
## is released and recorded. The battle said the line as each one fell; this is
## where the row actually goes. Written to disk the moment it happens, whatever the
## outcome was, which is the whole of the no-resets rule this project can enforce:
## quitting to the launcher and reopening the slot cannot bring anything back.
## Answers what it took, so a caller that is about to end the run can say so.
func _reap_nuzlocke_faints(save: Gen2SaveData, cause: StringName) -> Array:
	if _world == null or _world.rules == null or not _world.rules.is_nuzlocke():
		return []
	var lost: Array = Gen2Nuzlocke.reap(save, cause, _world.landmark_backup())
	if lost.is_empty():
		return []
	if save != null and _data != null and _injected_save == null:
		var written: Dictionary = Gen2SaveStore.save(save, _data)
		if not bool(written.get("ok", false)):
			push_error("Could not save the loss: %s" % String(written.get("message", "")))
	_refresh_labels()
	return lost


## Whether the run the player is in has ended for good. A Nuzlocke that has lost
## its last Pokemon can be looked at and exported, never continued.
func nuzlocke_run_over() -> bool:
	var save: Gen2SaveData = active_save()
	return save != null and Gen2Nuzlocke.run_over(save.nuzlocke)


## `Script_reloadmapafterbattle`'s `.was_wild` branch: a catch that filled its
## box staged `Script_SpecialBillCall` with `LoadMemScript`, so Bill rings once
## the map is back. The flag is spent whether or not the call could be placed,
## which is what clearing `wBattleResult` on the way out of the script does.
func _start_box_full_call() -> void:
	if _world == null or not _world.state.battle_box_full():
		return
	_world.state.set_battle_box_full(false)
	var results: Array = _world.request_caller_phone_call(
		Gen2WorldPhoneHost.CONTACT_BILL
	)
	if not results.is_empty() and bool(results[0].get("ok", false)):
		_show_script_results(results)


## `Script_reloadmapafterbattle`'s other branch. Bill rings after a wild battle
## that filled the box; Mom rings after a trainer battle, if her savings have
## reached the next thing she is buying. The two are exclusive on the cartridge
## because one bit decides which, so the flag is read here and nowhere else.
func _start_mom_purchase_call() -> void:
	if _world == null or not _active_battle_trainer:
		return
	_active_battle_trainer = false
	var bought: Dictionary = _world.mom_purchase(_encounter_random.randi())
	var results: Array = bought.get("results", [])
	if bool(bought.get("bought", false)) and not results.is_empty() \
		and bool((results[0] as Dictionary).get("ok", false)):
		_show_script_results(results)


## `EvoStoneEffect`'s evolution, which the pack has already applied: only the
## animation is left, and it is the after-battle pass's own screen so both ways
## in draw the same thing.
func _on_pack_evolution(plan: Dictionary, after: Callable) -> void:
	## No [member _evolution_save]: the row is already written, so [method
	## _on_evolution_resolved] has nothing to apply and the dex write was the
	## pack transaction's.
	_open_evolution([plan], null, after)


## `EvolveAfterBattle`'s screen. [param plans] is
## [method Gen2Evolution.after_battle]'s list, [param save] the party they are
## applied to, and [param after] whatever the caller was doing when the pass
## interrupted it, run once the last plan has been answered.
func _open_evolution(plans: Array, save: Gen2SaveData, after: Callable) -> void:
	if _evolution_host != null or _data == null or plans.is_empty():
		if after.is_valid():
			after.call()
		return
	var host := Gen2EvolutionScreen.new()
	host.set_context(_data, plans)
	_evolution_save = save
	_evolution_after = after
	host.resolved.connect(_on_evolution_resolved)
	host.closed.connect(_on_evolution_closed)
	host.cry_requested.connect(_play_species_cry)
	host.sfx_requested.connect(_play_sfx)
	host.music_requested.connect(_play_evolution_music)
	## Into the 160x144 viewport rather than over the whole window: the first box
	## is printed over the map, so it has to be composited with it the way the
	## world's own text box is.
	host.z_index = 30
	## Held before the node enters the tree: `_ready()` runs inside
	## [method Gen2Screen.display], and a screen that closes there has to find
	## itself here to be taken off again.
	_evolution_host = host
	_screen.display(host)
	if _evolution_host == null:
		return
	_script_prompt = "Evolving"
	_refresh_labels()


## `.proceed`'s own write, or `CancelEvolution` doing nothing but printing.
## `SetSeenAndCaughtMon` and `UpdateUnownDex` are here rather than in the screen:
## the screen draws, the world owns the dex and the party.
func _on_evolution_resolved(plan: Dictionary, canceled: bool) -> void:
	if canceled or _evolution_save == null or _data == null:
		return
	var index: int = int(plan.get("index", -1))
	if index < 0 or index >= _evolution_save.party.size():
		return
	var applied: Dictionary = Gen2WorldPartyHost.apply_evolution(
		_data, _evolution_save.party[index], plan.get("row", {})
	)
	if applied.is_empty() or _world == null or _world.state == null:
		return
	_world.state.set_species_caught(int(applied["register_caught"]))
	var form: int = int(applied.get("register_unown", 0))
	if form > 0:
		_world.state.update_unown_dex(form)
	## `LearnLevelMoves` teaches whatever fits an empty slot, which
	## [method Gen2WorldPartyHost.apply_evolution] has already done. A move that
	## needs `ForgetMove` is declined here: that menu lives inside the start menu
	## screen's own mode machine and this pass has no way into it, and declining
	## is one of the two answers the cartridge takes.
	_script_prompt = "%s evolved" % String(plan.get("evolving_name", ""))


func _on_evolution_closed() -> void:
	var host: Gen2EvolutionScreen = _evolution_host
	_evolution_host = null
	_evolution_save = null
	if host != null:
		Gen2Screen.drop(host)
	if _renderer != null:
		_renderer.refresh()
	var after: Callable = _evolution_after
	_evolution_after = Callable()
	if after.is_valid():
		after.call()


## `PlayMusic` from inside the animation: MUSIC_NONE stops what the map or the
## battle left playing, and MUSIC_EVOLUTION is its own track.
func _play_evolution_music(music: int) -> void:
	if _audio_player == null or _data == null:
		return
	if music == Gen2EvolutionScreen.MUSIC_NONE:
		_audio_player.stop_all()
		return
	var record: Dictionary = _data.world_audio(&"music", music)
	if record.is_empty():
		return
	_audio_player.play_record(record, &"map_music", _audio_assets())


## The save write `ExitBattle` owes once the evolution pass and Pokerus have
## both run over the party the battle already wrote.
func _persist_after_battle(save: Gen2SaveData) -> void:
	if save == null or not _active_battle_persist or _data == null:
		return
	var written: Dictionary = Gen2SaveStore.save(save, _data)
	if not bool(written.get("ok", false)):
		push_error("Could not save the battle exit: %s" % String(written.get("message", "")))


func _advance_script_input() -> void:
	if _text_box.advance():
		_continue_if_text_settled()
		return
	_text_box_rect_held += 1
	_text_box.visible = false
	_script_prompt = ""
	_show_script_results(_world.run_event_queue(true))
	_text_box_rect_held -= 1
	_push_text_box_rect()
	_refresh_labels()


## `Script_writetext` is `MapTextbox` and returns as soon as the string is placed,
## so a text ending in `<DONE>` owes no press of its own and the script runs on the
## moment its last page is up. The box reaches that page three ways: shown whole,
## turned to by the press that clears a `<PARA>`, or scrolled into by `_ContText`,
## and only the first two are a press. The scroll ends on a frame, which is why
## [method advance_frame] asks this as well; without it every `<CONT>`-terminated
## text cost one press more than the cartridge spends.
func _continue_if_text_settled() -> bool:
	if _text_box == null or not _text_box.visible or _world == null:
		return false
	if _text_awaits_press or not _oak_pc_pages.is_empty():
		return false
	if _text_box.is_scrolling() or _text_box.has_pages_left():
		return false
	if StringName(_world.pending_script_input().get("type", &"")) != &"text":
		return false
	_continue_after_text()
	return true


## Runs a script on past a text that owes no press, leaving the box up: the
## cartridge closes it at `closetext`, not at the end of a `writetext`. So the
## box is taken down only where nothing is left to print into it.
func _continue_after_text() -> void:
	_text_awaits_press = true
	_text_box_rect_held += 1
	_script_prompt = ""
	_show_script_results(_world.run_event_queue(true))
	if _text_box != null and StringName(_world.pending_script_input().get("type", &"")) \
		not in [&"text", &"button"] and _world.pending_script_wait().is_empty():
		_text_box.visible = false
	_text_box_rect_held -= 1
	_push_text_box_rect()
	_refresh_labels()


func _start_trainer_approach(request: Dictionary) -> void:
	if _world == null or not _trainer_approach.is_empty():
		return
	var values: Dictionary = request.get("values", {})
	var direction_value: Variant = values.get("direction", Vector2i.ZERO)
	var direction: Vector2i = direction_value if direction_value is Vector2i else Vector2i.ZERO
	var plan: Dictionary = _world.start_trainer_approach(
		int(values.get("object_index", -1)), direction, int(values.get("distance", 0))
	)
	if not bool(plan.get("ok", false)):
		var failed: Array = _world.complete_runtime_request({
			"ok": false,
			"reason": plan.get("reason", &"trainer_approach_failed"),
			"details": plan.duplicate(true),
		})
		_show_script_results(failed)
		return
	_trainer_approach = {
		"object_index": int(plan.get("object_index", -1)),
		"path": plan.get("path", []).duplicate(true),
		"path_index": 0,
		"emote_frames": int(plan.get("emote_frames", Gen2WorldAPI.TRAINER_SHOCK_FRAMES)),
		"movement_delay": 1,
	}
	_script_prompt = "Trainer spotted you"
	if _renderer != null:
		_renderer.refresh()
	_refresh_labels()


## One hardware frame of `SeenByTrainerScript`'s presentation: the shock emote's
## own count, the movement delay, then one planned cell at a time. The object's
## step_passes_remaining (set by
## [method Gen2WorldAPI.advance_trainer_approach_step]) is spent by the same
## frame, while step_offset() still gives the renderer 16-frame interpolation.
## [param map_pass] is whether this hardware frame runs `HandleMap`'s own pass.
## The two countdowns in front of the walk are the script's `DelayFrames` and are
## spent on every frame; the walk itself is `HandleObjectStep`'s and is not.
func _advance_trainer_approach(map_pass: bool) -> void:
	if _world == null:
		_trainer_approach = {}
		return
	var emote_frames: int = int(_trainer_approach.get("emote_frames", 0))
	if emote_frames > 0:
		_trainer_approach["emote_frames"] = emote_frames - 1
		if _renderer != null:
			_renderer.refresh()
		return
	var movement_delay: int = int(_trainer_approach.get("movement_delay", 0))
	if movement_delay > 0:
		_trainer_approach["movement_delay"] = movement_delay - 1
		return
	if not map_pass:
		return
	var object_index: int = int(_trainer_approach.get("object_index", -1))
	var stepping_object: Gen2WorldObject = _world.objects[object_index] \
		if _world != null and object_index >= 0 and object_index < _world.objects.size() else null
	if stepping_object != null and stepping_object.tick_step():
		if _renderer != null:
			_renderer.refresh()
		return
	var path: Array = _trainer_approach.get("path", [])
	var path_index: int = int(_trainer_approach.get("path_index", 0))
	if path_index < path.size():
		var direction_value: Variant = path[path_index]
		if not direction_value is Vector2i:
			_finish_trainer_approach(false, &"invalid_trainer_path", {})
			return
		var direction: Vector2i = direction_value
		var step: Dictionary = _world.advance_trainer_approach_step(
			object_index, direction
		)
		if not bool(step.get("ok", false)):
			_finish_trainer_approach(false, step.get("reason", &"trainer_approach_failed"), step)
			return
		_trainer_approach["path_index"] = path_index + 1
		if _renderer != null:
			_renderer.refresh()
		return
	var finished: Dictionary = _world.finish_trainer_approach(object_index)
	if not bool(finished.get("ok", false)):
		_finish_trainer_approach(false, finished.get("reason", &"trainer_approach_failed"), finished)
		return
	_finish_trainer_approach(true, &"", finished)


func _finish_trainer_approach(ok: bool, reason: StringName, details: Dictionary) -> void:
	var request: Dictionary = _trainer_approach.duplicate(true)
	_trainer_approach = {}
	if _world == null:
		return
	var result: Dictionary = {"ok": ok}
	if not ok:
		result["reason"] = reason
		result["details"] = details.duplicate(true)
	else:
		result["object_index"] = int(request.get("object_index", -1))
		result["path"] = request.get("path", []).duplicate(true)
	var resumed: Array = _world.complete_runtime_request(result)
	_show_script_results(resumed)


func _open_service_host() -> void:
	if _service_host != null or _world == null or _data == null:
		return
	var host: Gen2WorldServiceScreen = SERVICE_SCENE.instantiate() as Gen2WorldServiceScreen
	if host == null:
		_script_prompt = "Service scene unavailable"
		_refresh_labels()
		return
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.z_index = 20
	host.set_screen(_screen)
	add_child(host)
	var save: Gen2SaveData = _injected_save if _injected_save != null else _selected_runtime_save()
	var persist: bool = save != null and _injected_save == null
	if not host.open_pending(_world, _data, save, persist):
		Gen2Screen.drop(host)
		_script_prompt = "Service request unavailable"
		_refresh_labels()
		return
	host.save_action = persist_world_snapshot
	host.completed.connect(_on_service_completed)
	host.sfx_requested.connect(_play_sfx)
	host.cry_requested.connect(_play_species_cry)
	_service_host = host
	_script_prompt = "Service host open"
	_refresh_labels()


## Opens the induction sequence `halloffame` asks for. Public so the screenshot
## tool and the scene tests can reach it without replaying the whole route.
##
## The party is the active save's, so an injected or development save inducts
## whatever it is carrying. A cache with no font answers nothing rather than
## drawing an empty screen.
func open_hall_of_fame() -> void:
	if _hall_of_fame_host != null or _world == null or _data == null:
		return
	var save: Gen2SaveData = _active_party_save()
	if save == null:
		_script_prompt = "Hall of Fame needs a save"
		_refresh_labels()
		return
	## `HallOfFame`'s own second instruction, in front of everything the sequence
	## draws: the next CONTINUE spawns at New Bark Town rather than in the Hall.
	_world.spawn_after_champion = Gen2WorldSnapshot.SPAWN_AFTER_LANCE
	var pages: Array = Gen2HallOfFame.pages(_data, save, _world.state)
	## `AddHallOfFameEntry` runs behind `SaveGameData` and in front of the
	## animation, so the team is stored whether or not the player watches it;
	## the snapshot itself is written when the sequence ends.
	save.hall_of_fame = Gen2HallOfFame.inducted(save.hall_of_fame, save)
	## No anchor preset: this is a child of the 160x144 Gen2Screen and sizes
	## itself in native pixels, the way the story picture does.
	var host := Gen2HallOfFameScreen.new()
	host.set_context(_data, pages)
	host.closed.connect(_on_hall_of_fame_closed)
	host.rating_reached.connect(_on_hall_of_fame_rating)
	_hall_of_fame_host = host
	_screen.display(host)
	if _hall_of_fame_host == null:
		## set_context() with nothing to show closes on _ready(), which runs as
		## soon as the node enters the tree.
		return
	_play_hall_of_fame_music()
	_script_prompt = "Hall of Fame"
	_refresh_labels()


## `TradeCenter`, `Colosseum` and `TimeCapsule`, which are the same
## `LinkCommunications` opening with a different exchange behind it: the two
## trade rooms open this screen and the Colosseum opens a battle against the
## peer's own party. Answers whether the request was taken over; a false leaves
## it for the host, which settles a room with no cable on the other end.
func _open_link_room(request: Dictionary) -> bool:
	var values: Dictionary = request.get("values", {})
	if int(values.get("link_mode", 0)) == Gen2LinkSession.LINK_COLOSSEUM:
		return _start_link_battle(request)
	return _open_link_screen(Gen2LinkScreen.MODE_TRADE)


## `Colosseum`, which is `LinkCommunications` and then one battle against the
## party that came back. The transport supplies the peer's choices, and the
## record is written where `AddLastLinkBattleToLinkRecord` writes it.
func _start_link_battle(request: Dictionary) -> bool:
	var peer: Dictionary = _link_transport().peer
	var party: Array = peer.get("party", [])
	if party.is_empty():
		return false
	_link_battle_peer = peer.duplicate(true)
	_start_battle_request({
		"kind": &"link_room_requested",
		"values": {
			"kind": &"link_battle",
			"special": int((request.get("values", {}) as Dictionary).get("special", 0)),
			## `wLinkMode` is non-zero for the whole fight, which is what makes
			## the switch menu the player's own rather than the AI's.
			"link": true,
			"trainer_name": String(peer.get("name", "")),
			"enemy_party": party.duplicate(true),
		},
	})
	return true


func _open_link_screen(screen_mode: int) -> bool:
	if _link_host != null or _world == null or _data == null:
		return false
	var host := Gen2LinkScreen.new()
	host.set_context(
		_data, _world, _selected_runtime_save() if _injected_save == null \
			else _injected_save,
		_link_transport(), screen_mode, _injected_save == null
	)
	host.closed.connect(_on_link_screen_closed)
	_link_host = host
	_screen.display(host)
	if _link_host == null:
		## A cartridge whose cache has no trade border closes on `_ready()`.
		return false
	_script_prompt = "Link record" if screen_mode == Gen2LinkScreen.MODE_RECORD \
		else "Trade Center"
	_refresh_labels()
	return true


func _on_link_screen_closed() -> void:
	var host: Gen2LinkScreen = _link_host
	_link_host = null
	if host != null:
		Gen2Screen.drop(host)
	_show_script_results(_world.complete_runtime_request({"ok": true}))
	if _renderer != null:
		_renderer.refresh()
	_refresh_labels()


## The cable, on the same refresh the party mirror rides. There is no cable on
## this platform and the only second party that exists on one machine is the
## player's own other save file, so that is the peer: the first other occupied
## slot of the same cartridge. No other slot is no cable, which is what the
## receptionist's "your friend is not ready" answers.
func _refresh_link_transport(save: Gen2SaveData) -> void:
	if _world == null or _world.state == null or _data == null:
		return
	if _injected_save != null:
		## A driver that brought its own save brought its own peer too, or none;
		## a slot on disk is not this run's to reach for.
		return
	## Once per slot. This rides the party mirror's refresh, which runs whenever
	## the party changes; reading another save file that often would put disk
	## access in the middle of a battle, and the peer cannot change while this
	## slot is the one being played.
	if _link_transport_slot == save.slot:
		return
	_link_transport_slot = save.slot
	for slot: int in Gen2SaveStore.occupied_slots(save.game_id, save.rom_sha1):
		if slot == save.slot:
			continue
		var loaded: Dictionary = Gen2SaveStore.load_result(
			save.game_id, save.rom_sha1, slot, _data
		)
		if not bool(loaded.get("ok", false)):
			continue
		_world.state.set_link_transport(
			Gen2LinkTransport.to_save(loaded["save"] as Gen2SaveData)
		)
		return
	_world.state.set_link_transport(null)


func _link_transport() -> Gen2LinkTransport:
	if _world == null or _world.state == null:
		return Gen2LinkTransport.new()
	return _world.state.link_transport()


## HallOfFame calls SaveGameData before the animation, so the record is written
## whether or not the player watches it. This writes at the end instead: the
## screen owns no save state, and the snapshot it would write mid-sequence is
## the same one.
func _on_hall_of_fame_closed() -> void:
	var host: Gen2HallOfFameScreen = _hall_of_fame_host
	_hall_of_fame_host = null
	if host != null:
		Gen2Screen.drop(host)
	var written: Dictionary = persist_world_snapshot()
	_script_prompt = "Hall of Fame recorded" if bool(written.get("ok", false)) \
		else "Hall of Fame not saved: %s" % String(written.get("reason", "unknown"))
	_play_current_map_music()
	if _renderer != null:
		_renderer.refresh()
	_refresh_labels()
	## `AnimateHallOfFame` is followed by `farcall Credits` with the `wStatusFlags`
	## byte pushed before the Hall of Fame bit went into it, so this pair is never
	## skippable however many times it has been seen.
	open_credits(false)


## `ProfOaksPCRating`'s tail: `PlayMusic MUSIC_NONE` stops the induction music
## where it stands, without a fade, and the rating's own sound plays over the
## silence it leaves.
func _on_hall_of_fame_rating(sfx: int) -> void:
	if _audio_player != null:
		_audio_player.fade_out()
	_play_sfx(sfx)


## `Script_credits`, which farcalls `RedCredits` and then ends the script.
##
## [param skippable] is the `wStatusFlags` byte `Credits` is handed: `RedCredits`
## passes the live one, which by Red has the Hall of Fame bit in it, while
## `HallOfFame` pushes the byte before setting that bit, so the induction's own
## credits cannot be skipped even on a second run.
func open_credits(skippable: bool = true) -> void:
	if _credits_host != null or _world == null or _data == null:
		return
	var host := Gen2CreditsScreen.new()
	if not host.set_context(_data, skippable):
		host.free()
		_script_prompt = "The credits are not in this cache"
		_refresh_labels()
		return
	host.closed.connect(_on_credits_closed)
	host.music_requested.connect(_play_credits_music)
	host.music_fade_requested.connect(_fade_credits_music)
	_credits_host = host
	_screen.display(host)
	_script_prompt = "Credits"
	_refresh_labels()


func _on_credits_closed() -> void:
	var host: Gen2CreditsScreen = _credits_host
	_credits_host = null
	if host != null:
		Gen2Screen.drop(host)
	_play_current_map_music()
	if _renderer != null:
		_renderer.refresh()
	_script_prompt = ""
	_refresh_labels()


## `.music`, whose `PlayMusic MUSIC_NONE` and `DelayFrame` in front of the real
## call are what stop the induction's own track first.
func _play_credits_music(music: int) -> void:
	if _audio_player == null or _data == null:
		return
	_audio_player.fade_out()
	var record: Dictionary = _data.world_audio(&"music", music)
	if record.is_empty():
		return
	_audio_player.play_record(record, &"map_music", _audio_assets())


## `.end`'s `wMusicFade`, which the overworld's own player owns the way it owns
## the Hall of Fame rating's sound.
func _fade_credits_music(_music: int, frames: int) -> void:
	if _audio_player != null:
		_audio_player.fade_out(frames)


func _play_hall_of_fame_music() -> void:
	if _audio_player == null or _data == null:
		return
	var record: Dictionary = _data.world_audio(&"music", MUSIC_HALL_OF_FAME)
	if record.is_empty():
		return
	_audio_player.play_record(record, &"map_music", _audio_assets())


## Public driver for screenshot tooling and scene tests, mirroring
## _open_service_host()'s shape. The START branch in _handle_button() is the
## normal path.
func _open_start_menu() -> void:
	_open_start_menu_host(Callable())


## `SelectMenu` and `GiveTakePartyMonItem`'s GIVE both open the pack this screen
## already hosts, so they share its opener and hand it their own entry point.
## [param entry] is called with the host once it is on screen.
func _open_start_menu_host(entry: Callable) -> void:
	if _world == null or _data == null or _overlay_open() or _field_move_text \
		or not _oak_pc_pages.is_empty() \
		or not _trainer_approach.is_empty() or _world.script_busy() \
		or _world.phone_ring_active() or _world.fishing_busy():
		return
	var host: Gen2StartMenuScreen = START_MENU_SCENE.instantiate() as Gen2StartMenuScreen
	if host == null:
		_script_prompt = "Start menu scene unavailable"
		_refresh_labels()
		return
	# An injected save is a development or test one, so its item use stays in
	# memory the same way preview_party_transaction() does.
	host.set_party_context(
		_injected_save if _injected_save != null else _selected_runtime_save(),
		_injected_save == null
	)
	if not host.open(
		_world, _data, Callable(self, "persist_world_snapshot"), _start_menu_cursor
	):
		Gen2Screen.drop(host)
		_script_prompt = "Start menu unavailable"
		_refresh_labels()
		return
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.z_index = 20
	add_child(host)
	## `StartMenu`'s box stands over the map, so it is drawn into the screen the
	## map is already in rather than into one of the host's own.
	host.set_screen(_screen)
	host.action_chosen.connect(_on_start_menu_action)
	host.soft_reset_confirmed.connect(_soft_reset)
	host.closed.connect(_on_start_menu_closed)
	host.field_item_used.connect(_on_field_item_used)
	host.field_move_chosen.connect(_on_start_menu_field_move)
	host.evolution_animation_requested.connect(_on_pack_evolution)
	host.sfx_requested.connect(_play_sfx)
	_start_menu_host = host
	_script_prompt = "Start menu open"
	if entry.is_valid():
		entry.call(host)
	_refresh_labels()


## `SelectMenu`, which is the whole of what the SELECT button does in the
## overworld: the registered item, or the text saying one may be registered.
func open_select_menu() -> void:
	_open_start_menu_host(func(host: Gen2StartMenuScreen) -> void:
		host.open_registered_item()
	)


func _on_start_menu_action(kind: StringName, id: StringName = &"") -> void:
	var host: Gen2StartMenuScreen = _start_menu_host
	_start_menu_host = null
	if host != null:
		_start_menu_cursor = host.cursor()
		Gen2Screen.drop(host)
	_reopen_start_menu = kind in [
		Gen2WorldStartMenu.ITEM_POKEMON, Gen2WorldStartMenu.ITEM_POKEGEAR,
		Gen2WorldStartMenu.ITEM_PLAYER, Gen2WorldStartMenu.ITEM_POKEDEX,
		Gen2ModHost.START_ACTION_OPEN_BILLS_PC,
		Gen2ModHost.START_ACTION_OPEN_MOD_PAGE,
	]
	match kind:
		Gen2ModHost.START_ACTION_OPEN_BILLS_PC:
			_open_bills_pc()
		Gen2ModHost.START_ACTION_OPEN_MOD_PAGE:
			_open_mod_page(id)
		Gen2WorldStartMenu.ITEM_POKEMON:
			_open_embedded_party()
		Gen2WorldStartMenu.ITEM_POKEGEAR:
			_open_pokegear()
		Gen2WorldStartMenu.ITEM_PLAYER:
			_open_trainer_card()
		Gen2WorldStartMenu.ITEM_POKEDEX:
			_open_pokedex()
		Gen2WorldStartMenu.ITEM_QUIT:
			## `StartMenu_Quit`'s `FarQueueScript
			## BugCatchingContestReturnToGateScript` and the 4 it returns, which
			## is `.ExitMenuRunScript`: the menu closes and the script runs.
			_show_script_results(_world.queue_bug_contest_results(&"retired"))
		Gen2WorldStartMenu.ITEM_LAUNCHER:
			## Nothing is written: the row asked first, and a player who wanted
			## this run kept chose SAVE before it. The cartridge comes out of the
			## console exactly as it went in.
			if is_inside_tree():
				get_tree().change_scene_to_file.call_deferred(LAUNCHER_SCENE)
			return
	_refresh_labels()


## `.Reopen`, which every `StartMenu_*` handler that returns 0 lands on. The
## cursor is `wBattleMenuCursorPosition` and was kept when the menu closed.
func _reopen_start_menu_if_due() -> void:
	if not _reopen_start_menu:
		return
	_reopen_start_menu = false
	_open_start_menu()


## `StartMenu_Pokedex`'s `farcall Pokedex`. Its own B returns to the overworld,
## which is where DEXSTATE_EXIT lands too.
func _open_pokedex() -> void:
	if _pokedex_host != null or _data == null:
		return
	var host := Gen2PokedexScreen.new()
	if not host.open(_data, _world, _pokedex_prev_entry):
		host.free()
		_script_prompt = "The Pokedex needs a cache that carries its entries"
		_refresh_labels()
		return
	host.z_index = 10
	host.set_screen(_screen)
	add_child(host)
	host.closed.connect(_on_pokedex_closed)
	host.cry_requested.connect(_on_pokedex_cry_requested)
	host.sfx_requested.connect(_play_sfx)
	_pokedex_host = host
	_script_prompt = "Pokedex open"
	_refresh_labels()


## The entry screen's CRY button, which is one caller of [method
## _play_species_cry] rather than a path of its own.
func _on_pokedex_cry_requested(species: int) -> void:
	_play_species_cry(species)


func _on_pokedex_closed() -> void:
	var host: Gen2PokedexScreen = _pokedex_host
	_pokedex_host = null
	if host != null:
		_pokedex_prev_entry = host.previous_entry()
		Gen2Screen.drop(host)
	_script_prompt = "Pokedex closed"
	_reopen_start_menu_if_due()
	_refresh_labels()


## `ProfOaksPCBoot` (engine/events/prof_oaks_pc.asm): the level line, `Rate`'s
## seen and owned counts, and the rating those counts band into, each waiting for
## A or B. The special writes nothing, so the script has already run on to its
## own `end` and there is nothing to resume.
func open_prof_oaks_pc() -> void:
	if _world == null or _data == null or not _oak_pc_pages.is_empty():
		return
	var boot: Dictionary = Gen2ProfOaksPC.boot(_data, _world.state)
	if boot.is_empty():
		_script_prompt = "Prof Oak's PC needs a cache that carries its ratings"
		_refresh_labels()
		return
	_oak_pc_pages = boot["pages"]
	_oak_pc_sfx = int(boot["sfx"])
	_show_prof_oaks_pc_page()


func _show_prof_oaks_pc_page() -> void:
	if _text_box == null or _text_box.font == null:
		_close_prof_oaks_pc()
		return
	_apply_text_box_options()
	## `ProfOaksPCBoot` waits with `JoyWaitAorB`, which loads no cursor, so no
	## page of the rating blinks an arrow however it ends. `_OakPCText2` ends in
	## `prompt` and still shows none.
	_text_box.show_text(String(_oak_pc_pages[0]), false)
	_text_box.visible = true
	## `ProfOaksPCBoot` plays the sound `Rate` chose after the rating is printed,
	## not before it.
	if _oak_pc_pages.size() == 1 and _oak_pc_sfx >= 0:
		_play_sfx(_oak_pc_sfx)
	_script_prompt = "A: continue"
	_refresh_labels()


func _advance_prof_oaks_pc() -> void:
	if _text_box == null:
		_close_prof_oaks_pc()
		return
	if _text_box.advance():
		return
	_oak_pc_pages.remove_at(0)
	if _oak_pc_pages.is_empty():
		_close_prof_oaks_pc()
		return
	_show_prof_oaks_pc_page()


## `ProfOaksPCBoot` holds the script on the cartridge and nothing holds it here,
## so `OaksLab`'s own goodbye text was already queued behind these pages. It is
## put up now rather than dropped.
func _close_prof_oaks_pc() -> void:
	_oak_pc_pages = []
	_oak_pc_sfx = -1
	var pending: Dictionary = _world.pending_script_input() if _world != null else {}
	if StringName(pending.get("type", &"")) == &"text" \
		and _text_box != null and _text_box.font != null:
		_apply_text_box_options()
		# `OakPCText4` and its own `JoyWaitAorB`, the same as the pages above.
		_text_box.show_text(String(pending.get("text", "")), false)
		_text_box.visible = true
		_script_prompt = "A: advance text"
	else:
		if _text_box != null:
			_text_box.visible = false
		_script_prompt = ""
	_refresh_labels()


## `StartMenu_Status`'s `farcall TrainerCard`. Its own B returns to the
## overworld, which is where the source's own `ret` lands too.
func _open_trainer_card() -> void:
	if _trainer_card_host != null or _data == null:
		return
	var save: Gen2SaveData = _injected_save if _injected_save != null else _selected_runtime_save()
	var host := Gen2TrainerCardScreen.new()
	if not host.open(_data, _world, save):
		host.free()
		_script_prompt = "The trainer card needs a save and a cache that carries it"
		_refresh_labels()
		return
	host.z_index = 10
	## Into the hardware screen, the way the Hall of Fame goes: the card sizes
	## itself in the 160x144 space, so adding it to this Control instead would
	## draw it at one window pixel per hardware pixel in the corner.
	_screen.display(host)
	host.closed.connect(_on_trainer_card_closed)
	_trainer_card_host = host
	_script_prompt = "Trainer card open"
	_refresh_labels()


## `START_ACTION_OPEN_MOD_PAGE`: [param id] is the mod that registered the row,
## which is the same id its page is registered under.
func _open_mod_page(id: StringName) -> void:
	if _mod_page_host != null or _data == null:
		return
	var host := Gen2ModPageScreen.new()
	if not host.open(_data, id):
		host.free()
		_script_prompt = "%s registered no page" % id
		_refresh_labels()
		return
	host.z_index = 10
	_screen.display(host)
	host.closed.connect(_on_mod_page_closed)
	_mod_page_host = host
	_script_prompt = "%s page open" % id
	_refresh_labels()


func _on_mod_page_closed() -> void:
	var host: Gen2ModPageScreen = _mod_page_host
	_mod_page_host = null
	if host != null:
		Gen2Screen.drop(host)
	_script_prompt = "Mod page closed"
	_reopen_start_menu_if_due()
	_refresh_labels()


func _on_trainer_card_closed() -> void:
	var host: Gen2TrainerCardScreen = _trainer_card_host
	_trainer_card_host = null
	if host != null:
		Gen2Screen.drop(host)
	_script_prompt = "Trainer card closed"
	_reopen_start_menu_if_due()
	_refresh_labels()


func _on_start_menu_closed() -> void:
	var host: Gen2StartMenuScreen = _start_menu_host
	_start_menu_host = null
	if host != null:
		_start_menu_cursor = host.cursor()
		Gen2Screen.drop(host)
	_script_prompt = "Start menu closed"
	_refresh_labels()


## `PACKSTATE_QUITRUNSCRIPT`: the pack closes and the script the effect queued
## runs in the overworld. The words are the cartridge's own, read out of the
## cache by [method _field_item_text]; the host's wording behind it is only what
## a cache imported before those texts were carries.
func _on_field_item_used(request: Dictionary) -> void:
	var host: Gen2StartMenuScreen = _start_menu_host
	_start_menu_host = null
	if host != null:
		_start_menu_cursor = host.cursor()
		Gen2Screen.drop(host)
	## `.Field` reaches `ExitAllMenus`, so nothing reopens behind the effect.
	_reopen_start_menu = false
	if _world == null:
		_refresh_labels()
		return
	match StringName(request.get("effect", &"")):
		Gen2WorldPack.FIELD_EFFECT_BICYCLE:
			## `Script_GetOnBike` and `Script_GetOffBike`, both of which are a
			## line, a `waitbutton` and `special UpdatePlayerSprite`. The music is
			## the function's own rather than either script's.
			var on: bool = StringName(
				(request.get("bike", {}) as Dictionary).get("kind", &"")
			) == &"bike_on"
			var bike_name: String = _data.item_name(int(request.get("item", 0)))
			_show_field_move_text(
				"Got on the\n%s." % bike_name if on else "Got off\nthe %s." % bike_name
			)
			_play_current_map_music()
			if _renderer != null:
				_renderer.refresh()
		Gen2WorldPack.FIELD_EFFECT_ESCAPE_ROPE:
			_show_field_move_text(_field_item_text("escape_rope", "Used an\nESCAPE ROPE."))
			_refresh_after_escape()
		Gen2WorldPack.FIELD_EFFECT_ROD:
			var rods: Array[StringName] = _world.available_fishing_rods()
			select_fishing_rod(rods.find(StringName(request.get("rod", &""))))
			start_fishing()
		Gen2WorldPack.FIELD_EFFECT_ITEMFINDER:
			## `.Script_FoundSomething` runs `.ItemfinderSound` before its line;
			## `.Script_FoundNothing` plays nothing at all.
			if bool(request.get("found", false)):
				_start_sound_schedule(Gen2WorldScriptRunner.itemfinder_sounds())
				_advance_sound_schedule()
			_show_field_move_text(
				_field_item_text(
					"itemfinder_nearby",
					"Yes! ITEMFINDER\nindicates there's\nan item nearby."
				) if bool(request.get("found", false)) \
				else _field_item_text(
					"itemfinder_nope", "Nope! ITEMFINDER\nisn't responding."
				)
			)
		Gen2WorldPack.FIELD_EFFECT_SACRED_ASH:
			_show_field_move_text(
				_field_item_text("sacred_ash", "#MON were all\nhealed!")
			)
		## `farsjump CardKeySlotScript` and `farsjump BasementDoorScript`, each
		## `QueueScript`d by its own routine, so both run as any map script does.
		Gen2WorldPack.FIELD_EFFECT_CARD_KEY, Gen2WorldPack.FIELD_EFFECT_BASEMENT_KEY:
			_show_script_results(_world.queue_item_script(request))
		## `.SquirtbottleScript`, whose `callasm` picks between the tree's own
		## script and the line it says when nothing is in front of the player.
		Gen2WorldPack.FIELD_EFFECT_SQUIRTBOTTLE:
			if StringName(request.get("kind", &"")) == &"squirtbottle_watered":
				_show_script_results(_world.queue_item_script(request))
			else:
				_show_field_move_text(_field_item_text(
					"squirtbottle", "Sprinkled water.\nBut nothing\nhappened…"
				))
	_refresh_labels()


## One of `data/text/common_2.asm`'s field-item lines, with `<PLAYER>` filled
## from the world the way every other text's marker is. [param fallback] is what
## a cache imported before these texts were carries instead.
func _field_item_text(key: String, fallback: String) -> String:
	var text: String = _data.menu_text(key) if _data != null else ""
	if text.is_empty():
		return fallback
	return text.replace(
		Gen2WorldPC.PLAYER_MARKER, _world.player_name() if _world != null else ""
	)


## The save the embedded party view shows: the injected or selected one, or a
## development party when neither exists.
func _embedded_party_save() -> Gen2SaveData:
	var save: Gen2SaveData = _injected_save if _injected_save != null \
		else _selected_runtime_save()
	return save if save != null else Gen2SaveStore.create_development_save(_data, 0)


func _open_embedded_party() -> void:
	if _party_host != null or _world == null or _data == null:
		return
	var host: Gen2PartyScreen = PARTY_SCENE.instantiate() as Gen2PartyScreen
	if host == null:
		_script_prompt = "Party scene unavailable"
		_refresh_labels()
		return
	var save: Gen2SaveData = _embedded_party_save()
	if save == null:
		Gen2Screen.drop(host)
		_script_prompt = "Party requires a validated save"
		_refresh_labels()
		return
	host.set_context(_data, save, true)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.z_index = 20
	host.mouse_filter = Control.MOUSE_FILTER_STOP
	host.set_screen(_screen)
	add_child(host)
	host.closed.connect(_on_party_closed)
	host.action_chosen.connect(_on_party_action)
	host.sfx_requested.connect(_play_sfx)
	## `OpenPartyStats`' `PlayMonCry2` reaches the same player the Pokedex's own
	## CRY button does.
	host.cry_requested.connect(_on_pokedex_cry_requested)
	_party_host = host
	_script_prompt = "Party open"
	_refresh_labels()


func _on_party_closed(_result: Dictionary) -> void:
	var host: Gen2PartyScreen = _party_host
	_party_host = null
	if host != null:
		Gen2Screen.drop(host)
	_script_prompt = "Party closed"
	_reopen_start_menu_if_due()
	_refresh_labels()


## MonMenu_Cut and MonMenu_Surf share a shape: the party menu closes first, then
## the field-move function runs and either queues its script or pushes its own
## refusal text. Both refusals and the success message go through the hardware
## text box, and nothing changes until the acknowledge, matching Script_Cut
## reaching CutDownTreeOrGrass and UsedSurfScript reaching SurfStartStep only
## after their text.
func _on_party_action(action: Dictionary) -> void:
	var host: Gen2PartyScreen = _party_host
	_party_host = null
	if host != null:
		Gen2Screen.drop(host)
	_run_party_action(action)


## The start menu's own MOVES row, which offers the HM field moves a registered
## source supplies and no party member knows. The list closed itself, so this
## drops the menu the way a party submenu's `.quit` does and runs the move
## through the one dispatch below.
func _on_start_menu_field_move(action: Dictionary) -> void:
	var host: Gen2StartMenuScreen = _start_menu_host
	_start_menu_host = null
	if host != null:
		_start_menu_cursor = host.cursor()
		Gen2Screen.drop(host)
	_run_party_action(action)


## What a chosen field action does, whichever list chose it. A slot of -1 is a
## move used from its own HM, which changes the name and the Surf sprite only.
func _run_party_action(action: Dictionary) -> void:
	# `PokemonActionSubmenu`'s `.quit` reaches `ExitAllMenus`, so a field move
	# leaves the overworld rather than reopening the menu behind it.
	_reopen_start_menu = false
	if _world == null:
		_refresh_labels()
		return
	var kinds: Dictionary = {
		&"mon_item": _run_mon_item_action,
		&"mon_mail": _run_mon_mail_action,
		&"heal_transfer": _run_heal_transfer,
		&"field_move": _run_field_move,
	}
	var kind: StringName = StringName(action.get("kind", &""))
	if not kinds.has(kind):
		_refresh_labels()
		return
	(kinds[kind] as Callable).call(action)


## Each field move: what it asks the world, the refusal, the line and what
## follows it. Every line is [constant Gen2WorldFieldMove.USED_TEXTS]' own. Fly
## is the one row with no line: its script writes nothing before the region map.
func _field_move_rows(slot: int, user: String) -> Dictionary:
	var says: Callable = Gen2WorldFieldMove.used_text.bind(user)
	return {
		Gen2WorldFieldMove.MOVE_CUT: [
			_world.cut_request, _cut_refusal,
			says.call(Gen2WorldFieldMove.MOVE_CUT), Callable(),
		],
		Gen2WorldFieldMove.MOVE_SURF: [
			_world.surf_request.bind(_party_species(slot)), _surf_refusal,
			says.call(Gen2WorldFieldMove.MOVE_SURF), Callable(),
		],
		Gen2WorldFieldMove.MOVE_STRENGTH: [
			_world.strength_request.bind(_party_species(slot)), _strength_refusal,
			says.call(Gen2WorldFieldMove.MOVE_STRENGTH), Callable(),
		],
		Gen2WorldFieldMove.MOVE_WHIRLPOOL: [
			_world.whirlpool_request, _whirlpool_refusal,
			says.call(Gen2WorldFieldMove.MOVE_WHIRLPOOL), Callable(),
		],
		Gen2WorldFieldMove.MOVE_WATERFALL: [
			_world.waterfall_request, _waterfall_refusal,
			says.call(Gen2WorldFieldMove.MOVE_WATERFALL), Callable(),
		],
		Gen2WorldFieldMove.MOVE_FLASH: [
			_world.flash_request, _flash_refusal,
			says.call(Gen2WorldFieldMove.MOVE_FLASH), Callable(),
		],
		Gen2WorldFieldMove.MOVE_HEADBUTT: [
			_world.headbutt_request, _field_move_refused,
			says.call(Gen2WorldFieldMove.MOVE_HEADBUTT), Callable(),
		],
		Gen2WorldFieldMove.MOVE_ROCK_SMASH: [
			_world.rock_smash_request, _field_move_refused,
			says.call(Gen2WorldFieldMove.MOVE_ROCK_SMASH), Callable(),
		],
		Gen2WorldFieldMove.MOVE_FLY: [
			_world.fly_request, _field_move_refused, "", _open_fly_map,
		],
		Gen2WorldFieldMove.MOVE_SWEET_SCENT: [
			_world.sweet_scent_request.bind(_encounter_random),
			_sweet_scent_refusal.bind(user),
			says.call(Gen2WorldFieldMove.MOVE_SWEET_SCENT), _after_sweet_scent,
		],
		Gen2WorldFieldMove.MOVE_DIG: [
			_world.dig_request, _field_move_refused,
			says.call(Gen2WorldFieldMove.MOVE_DIG), _after_escape,
		],
		Gen2WorldFieldMove.MOVE_TELEPORT: [
			_world.teleport_request, _field_move_refused,
			says.call(Gen2WorldFieldMove.MOVE_TELEPORT), _after_escape,
		],
	}


func _run_field_move(action: Dictionary) -> void:
	var slot: int = int(action.get("slot", -1))
	var user: String = String(action.get("name", "")) if action.has("name") \
		else _prompted_field_move_name(slot)
	var rows: Dictionary = _field_move_rows(slot, user)
	var move: int = int(action.get("move", 0))
	if not rows.has(move):
		_show_field_move_text(_field_move_refused(&""))
		return
	var row: Array = rows[move]
	var answer: Dictionary = (row[0] as Callable).call()
	if not bool(answer.get("ok", false)):
		_show_field_move_text(
			(row[1] as Callable).call(StringName(answer.get("reason", &"")))
		)
		return
	if not String(row[2]).is_empty():
		_show_field_move_text(row[2])
	var after: Callable = row[3]
	if after.is_valid():
		after.call(answer)


func _after_sweet_scent(answer: Dictionary) -> void:
	var found: Dictionary = answer["encounter"]
	_start_battle_request({
		"kind": &"battle_requested",
		"values": found["values"],
		"encounter": found.duplicate(true),
	})


func _after_escape(_answer: Dictionary) -> void:
	_refresh_after_escape()


## GetSurfType reads wPartySpecies at wCurPartyMon; the submenu action carries
## that slot. Zero when no save or slot answers, which is no species and so the
## ordinary surf sprite.
func _party_species(slot: int) -> int:
	var save: Gen2SaveData = _active_party_save()
	if save == null or slot < 0 or slot >= save.party.size():
		return 0
	var member: Variant = save.party[slot]
	return int((member as Gen2SaveMon).species) if member is Gen2SaveMon else 0


## engine/events/overworld.asm's refusal texts, verbatim from
## data/text/common_2.asm.
func _cut_refusal(reason: StringName) -> String:
	match reason:
		&"badge_required":
			return Gen2WorldFieldMove.BADGE_REQUIRED_TEXT
		&"nothing_to_cut":
			return Gen2WorldFieldMove.CUT_NOTHING_TEXT
	return Gen2WorldFieldMove.CANT_USE_TEXT


func _surf_refusal(reason: StringName) -> String:
	match reason:
		&"badge_required":
			return Gen2WorldFieldMove.BADGE_REQUIRED_TEXT
		&"already_surfing":
			return Gen2WorldFieldMove.ALREADY_SURFING_TEXT
		&"cannot_surf":
			return Gen2WorldFieldMove.CANT_SURF_TEXT
	return Gen2WorldFieldMove.CANT_USE_TEXT


## .FailWhirlpool has no text of its own; see [method _field_move_refused]. Cut
## is the exception, not the rule.
func _whirlpool_refusal(reason: StringName) -> String:
	return _badge_or_generic(reason)


## CheckMapCanWaterfall has no message at all, so only the badge has a line.
func _waterfall_refusal(reason: StringName) -> String:
	return _badge_or_generic(reason)


## A lit map has no refusal text of its own; only the badge has a line.
func _flash_refusal(reason: StringName) -> String:
	return _badge_or_generic(reason)


func _badge_or_generic(reason: StringName) -> String:
	return Gen2WorldFieldMove.BADGE_REQUIRED_TEXT if reason == &"badge_required" \
		else Gen2WorldFieldMove.CANT_USE_TEXT


## `SweetScentNothing`, which `.SweetScent` reaches only after its own
## `writetext`/`waitbutton`: the miss is a second box, not the only one.
func _sweet_scent_refusal(_reason: StringName, user: String) -> String:
	return Gen2WorldFieldMove.used_text(Gen2WorldFieldMove.MOVE_SWEET_SCENT, user) \
		+ Gen2TextStream.PAGE_BREAK + Gen2WorldFieldMove.SWEET_SCENT_NOTHING_TEXT


## `FieldMoveFailed`, shared by every field move with no text of its own: Fly's
## `.nostormbadge` and `.indoors`, Dig's `.CantUseDigText`, Teleport, and the two
## the menu refuses through it, `TryRockSmashFromMenu` and `TryHeadbuttFromMenu`.
## `AskRockSmashScript`'s `_MaySmashText` belongs to the other path, where the
## runner owns it, and Headbutt is gated on `CheckPartyMove` and the tile alone.
func _field_move_refused(_reason: StringName) -> String:
	return Gen2WorldFieldMove.CANT_USE_TEXT


## .TryStrength's only refusal is CheckBadge's, since it checks nothing else;
## anything past it is this project's own guard, not a cartridge branch.
func _strength_refusal(reason: StringName) -> String:
	return _badge_or_generic(reason)


## `GiveTakePartyMonItem`'s two answers. TAKE is a bag transaction and says so in
## the map's own text box; GIVE needs an item, which is `.GiveItem`'s pack over
## the Pokemon already chosen.
func _run_mon_item_action(action: Dictionary) -> void:
	var slot: int = int(action.get("slot", -1))
	if StringName(action.get("option", &"")) == Gen2PartyScreen.OPTION_GIVE:
		_open_start_menu_host(func(host: Gen2StartMenuScreen) -> void:
			host.open_give(slot)
		)
		return
	var save: Gen2SaveData = _embedded_party_save()
	var result: Dictionary = Gen2WorldBagHost.take_from_party(
		_world, save, slot, _injected_save == null
	)
	var action_name: String = String(action.get("name", ""))
	if bool(result.get("ok", false)):
		_show_field_move_text(Gen2WorldPack.took_text(action_name, String(result.get("name", ""))))
		return
	match StringName(result.get("reason", &"")):
		&"not_holding":
			_show_field_move_text(Gen2WorldPack.not_holding_text(action_name))
		&"bag_full":
			_show_field_move_text(Gen2WorldPack.storage_full_text())
		_:
			_show_field_move_text(
				"%s could not hand that over (%s)." % [
					action_name, String(result.get("reason", "")),
				]
			)


## `MonMailAction`'s READ and TAKE, once the party submenu has chosen. READ is
## `ReadPartyMonMail` over the list; TAKE is `.MailAskSendToPCText` and, if that
## is refused, `.MailLoseMessageText` and the bag.
func _run_mon_mail_action(action: Dictionary) -> void:
	var slot: int = int(action.get("slot", -1))
	var save: Gen2SaveData = _embedded_party_save()
	if save == null or slot < 0 or slot >= save.party.size():
		return
	var mon: Gen2SaveMon = save.party[slot]
	if mon == null or mon.mail == null:
		return
	if StringName(action.get("option", &"")) == Gen2PartyScreen.OPTION_MAIL_READ:
		_open_mail_reader(mon.mail)
		return
	_mail_take_slot = slot
	_mail_take_name = String(action.get("name", ""))
	_mail_take_stage = MAIL_TAKE_ASK_PC
	if not _open_host_prompt(MAIL_ASK_SEND_TO_PC_TEXT):
		_mail_take_slot = -1


func _open_mail_reader(mail: Gen2SaveMail) -> void:
	if _mail_host != null:
		return
	var host := Gen2MailScreen.new()
	host.set_context(_data, mail)
	_mail_host = host
	host.z_index = 20
	host.closed.connect(_on_mail_reader_closed)
	_screen.display(host)
	_apply_interface_mask()
	_refresh_labels()


## `.read` answers 0, which `.choosemenu` takes back to the party list. Here the
## list has already closed, because [method _on_party_action] drops it before it
## dispatches: every party action in this project is answered over the map, and
## this one is not the place to make an exception.
func _on_mail_reader_closed() -> void:
	if _mail_host != null:
		Gen2Screen.drop(_mail_host)
		_mail_host = null
	_apply_interface_mask()
	_refresh_labels()


## The answer to whichever of `MonMailAction`'s two questions is open.
func _answer_mail_take(accepted: bool) -> void:
	var slot: int = _mail_take_slot
	var stage: int = _mail_take_stage
	_mail_take_slot = -1
	_mail_take_stage = MAIL_TAKE_NONE
	var save: Gen2SaveData = _embedded_party_save()
	if save == null or slot < 0:
		return
	if stage == MAIL_TAKE_ASK_PC:
		if not accepted:
			## `.RemoveMailToBag`, which is the second question rather than a
			## way out.
			_mail_take_slot = slot
			_mail_take_stage = MAIL_TAKE_ASK_BAG
			if not _open_host_prompt(MAIL_LOSE_MESSAGE_TEXT):
				_mail_take_slot = -1
			return
		var sent: Dictionary = Gen2WorldPC.mailbox_send(
			_world, save, slot, _injected_save == null
		)
		_show_field_move_text(
			MAIL_SENT_TO_PC_TEXT if bool(sent.get("ok", false)) else MAILBOX_FULL_TEXT
		)
		return
	if not accepted:
		return
	var taken: Dictionary = Gen2WorldBagHost.take_from_party(
		_world, save, slot, _injected_save == null
	)
	if not bool(taken.get("ok", false)):
		_show_field_move_text(MAIL_NO_SPACE_TEXT)
		return
	_show_field_move_text(MAIL_DETACHED_TEXT % _mail_take_name)


## `Softboiled_MilkDrinkFunction`'s two halves, once the party menu has picked
## who is giving and who is receiving. The health moves through the world's own
## transaction, since the party it changes is a save the world owns.
func _run_heal_transfer(action: Dictionary) -> void:
	var result: Dictionary = Gen2WorldPartyHost.transfer_health(
		_world, _embedded_party_save(), int(action.get("slot", -1)),
		int(action.get("target_slot", -1)), _injected_save == null
	)
	if not bool(result.get("ok", false)):
		_show_field_move_text("It won't have any effect.")
		return
	## `PARTYMENUTEXT_HEAL_HP`, which is the line every healing item shares.
	## `ItemActionText` is followed by `JoyWaitAorB`, which loads no cursor, so
	## the line waits without an arrow the way `ProfOaksPCBoot`'s pages do.
	_show_field_move_text(
		"%s\nrecovered health!" % String(action.get("target_name", "")), false
	)


## [param blink_cursor] is whether the wait behind the line is one of the three
## routines that call `LoadBlinkingCursor`, not whether it waits at all.
func _show_field_move_text(text: String, blink_cursor: bool = true) -> void:
	_field_move_text = true
	if _text_box != null and _text_box.font != null:
		_apply_text_box_options()
		_text_box.show_text(text, blink_cursor)
		_text_box.visible = true
	_script_prompt = "A: continue"
	_refresh_labels()


## The acknowledge that closes a field-move message. A staged move commits here
## rather than when it was resolved: Script_Cut reaches CutDownTreeOrGrass only
## after UseCutText, and UsedSurfScript SurfStartStep only after its waitbutton.
func _acknowledge_field_move_text() -> void:
	## A text longer than the box is several `waitbutton`s, so a press with a page
	## still behind it spends itself on the box rather than on the move. A
	## one-page text closes on the first press, which is every other caller.
	if _text_box != null and _text_box.has_pages_left():
		_text_box.advance()
		return
	## A player event's own pages come next, and its tail runs once the last has
	## been pressed past: nothing it does can be reached while a line is still up.
	if not _player_event_texts.is_empty():
		var next_text: String = _player_event_texts[0]
		_player_event_texts.remove_at(0)
		_show_field_move_text(next_text)
		return
	_field_move_text = false
	if _text_box != null:
		_text_box.visible = false
	if _player_event_after.is_valid():
		var tail: Callable = _player_event_after
		_player_event_after = Callable()
		tail.call()
		return
	if _world == null:
		_script_prompt = ""
		_refresh_labels()
		return
	if not _world.pending_cut().is_empty():
		_commit_field_move(_world.complete_cut(), "Cut")
		return
	if not _world.pending_surf().is_empty():
		_commit_field_move(_world.complete_surf(), "Surf")
		return
	if not _world.pending_whirlpool().is_empty():
		_commit_field_move(_world.complete_whirlpool(), "Whirlpool")
		return
	if not _world.pending_strength().is_empty():
		_commit_field_move(_world.complete_strength(), "Strength")
		return
	if not _world.pending_waterfall().is_empty():
		_commit_field_move(_world.complete_waterfall(), "Waterfall")
		return
	if not _world.pending_flash().is_empty():
		_commit_field_move(_world.complete_flash(), "Flash")
		return
	if not _world.pending_headbutt().is_empty():
		_commit_field_move(_world.complete_headbutt(_encounter_random), "Headbutt")
		return
	if not _world.pending_rock_smash().is_empty():
		_commit_field_move(_world.complete_rock_smash(_encounter_random), "Rock Smash")
		return
	_script_prompt = ""
	_refresh_labels()


## Each commit reports its own audio. Strength plays nothing: SFX_STRENGTH
## belongs to the boulder that moves later, not to the flag being set. All redraw
## anyway, since the party overlay closed over the map.
func _commit_field_move(applied: Dictionary, label: String) -> void:
	if bool(applied.get("ok", false)):
		match StringName(applied.get("kind", &"")):
			&"surf_applied":
				_play_current_map_music()
			&"whirlpool_applied":
				_play_sfx(SFX_WHIRLPOOL)
			&"strength_applied":
				pass
			&"waterfall_applied":
				_play_sfx(SFX_WATERFALL)
			&"flash_used":
				# The palette is the whole of what BlindingFlash changed, so the
				# renderer is told the new row rather than asked to redraw.
				_play_sfx(SFX_FLASH)
				if _renderer != null:
					_renderer.set_time_of_day(_render_time_of_day())
				if _animation != null:
					_animation.configure(_world, _render_time_of_day())
			&"headbutt_applied":
				_play_sfx(SFX_HEADBUTT_TREE)
				if _effects != null:
					_effects.start_headbutt_tree(applied.get("cell", Vector2i.ZERO))
			&"rock_smash_applied":
				_play_sfx(SFX_STRENGTH)
			_:
				## `OWCutAnimation` plays it, which is why the sound and the
				## animation start together.
				_play_sfx(SFX_CUT)
				if _effects != null and StringName(applied.get("kind", &"")) == &"cut_applied":
					_effects.start_cut(
						applied.get("cell", Vector2i.ZERO),
						int(applied.get("animation", 0)),
						_world.facing_direction(),
						_world.player_cell,
					)
		if _renderer != null:
			_renderer.refresh()
		_script_prompt = label
		if StringName(applied.get("kind", &"")) == &"headbutt_applied":
			## HeadbuttScript's `callasm ShakeHeadbuttTree` spends its 32 frames
			## before `callasm TreeMonEncounter`, so the roll's own result waits
			## for the animation rather than opening a battle over it.
			_pending_headbutt_finish = applied.duplicate(true)
			_refresh_labels()
			return
		if StringName(applied.get("kind", &"")) == &"rock_smash_applied":
			_finish_rock_smash(applied)
			return
	else:
		_script_prompt = "%s failed: %s" % [label, String(applied.get("reason", "unknown"))]
	_refresh_labels()


## HeadbuttScript after ShakeHeadbuttTree: TreeMonEncounter either reaches
## startbattle or falls to `.no_battle`. The tree is unchanged either way.
func _finish_headbutt(applied: Dictionary) -> void:
	var encounter: Variant = applied.get("encounter", {})
	if not encounter is Dictionary or (encounter as Dictionary).is_empty():
		_show_field_move_text(Gen2WorldFieldMove.HEADBUTT_NOTHING_TEXT)
		return
	_refresh_labels()
	_start_battle_request({
		"kind": &"battle_requested",
		"values": (encounter as Dictionary)["values"],
		"encounter": (encounter as Dictionary).duplicate(true),
	})


## RockSmashScript after the rock is gone: RockMonEncounter either reaches
## startbattle or `.done`, a bare `end` with no nothing-text.
func _finish_rock_smash(applied: Dictionary) -> void:
	var encounter: Variant = applied.get("encounter", {})
	if not encounter is Dictionary or (encounter as Dictionary).is_empty():
		_refresh_labels()
		return
	_refresh_labels()
	_start_battle_request({
		"kind": &"battle_requested",
		"values": (encounter as Dictionary)["values"],
		"encounter": (encounter as Dictionary).duplicate(true),
	})


func _open_phone_list() -> void:
	_open_service_overlay(&"phone_list")


## `PokeGear` itself, which is what the start menu's POKEGEAR entry reaches: the
## clock card, with the rest a `Pokegear_SwitchPage` away. The phone list opens
## on one card instead of the whole device.
func _open_pokegear() -> void:
	_open_service_overlay(&"pokegear")


## The `OPEN_BILLS_PC` start-menu action: storage on its own, through the same
## host and the same box screen the Pokemon Center's machine opens. The row is
## already gated on a party, so a refusal here is a cache or save fault rather
## than the empty-party one.
func _open_bills_pc() -> void:
	_open_service_overlay(&"bills_pc")


## The host's own YES/NO over the map: `Script_yesorno`'s box, through the same
## overlay a scripted one goes through, answered back in
## [method _on_service_completed].
func _open_host_prompt(text: String) -> bool:
	if _service_host != null or _world == null or _data == null:
		return false
	var host: Gen2WorldServiceScreen = SERVICE_SCENE.instantiate() as Gen2WorldServiceScreen
	if host == null:
		return false
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.z_index = 20
	host.set_screen(_screen)
	add_child(host)
	var save: Gen2SaveData = _injected_save if _injected_save != null \
		else _selected_runtime_save()
	if not host.open_prompt(_world, _data, save, _injected_save == null, text):
		Gen2Screen.drop(host)
		return false
	host.save_action = persist_world_snapshot
	host.completed.connect(_on_service_completed)
	host.sfx_requested.connect(_play_sfx)
	host.cry_requested.connect(_play_species_cry)
	_service_host = host
	_script_prompt = "A: answer"
	_refresh_labels()
	return true


func _open_service_overlay(kind: StringName) -> void:
	if _service_host != null or _world == null or _data == null:
		return
	var label: String = {
		&"pokegear": "Pokegear", &"bills_pc": "Storage",
	}.get(kind, "Phone list")
	var host: Gen2WorldServiceScreen = SERVICE_SCENE.instantiate() as Gen2WorldServiceScreen
	if host == null:
		_script_prompt = "%s scene unavailable" % label
		_refresh_labels()
		return
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.z_index = 20
	host.set_screen(_screen)
	add_child(host)
	var save: Gen2SaveData = _injected_save if _injected_save != null else _selected_runtime_save()
	var persist: bool = save != null and _injected_save == null
	var opened: bool = (
		host.open_pokegear(_world, _data, save, persist) if kind == &"pokegear"
		else host.open_bills_pc(_world, _data, save, persist) if kind == &"bills_pc"
		else host.open_phone_list(_world, _data, save, persist)
	)
	if not opened:
		Gen2Screen.drop(host)
		_script_prompt = "%s unavailable" % label
		_refresh_labels()
		return
	host.save_action = persist_world_snapshot
	host.completed.connect(_on_service_completed)
	host.sfx_requested.connect(_play_sfx)
	host.cry_requested.connect(_play_species_cry)
	_service_host = host
	_script_prompt = "%s open" % label
	_refresh_labels()


## `_FlyMap` as its own overlay, and the warp its answer asks for. A cancel
## leaves the player where they were, which is what `.illegal` does with the
## `-1` a B press writes.
func _open_fly_map(request: Dictionary) -> void:
	if _service_host != null or _world == null or _data == null:
		return
	var host: Gen2WorldServiceScreen = SERVICE_SCENE.instantiate() as Gen2WorldServiceScreen
	if host == null:
		_script_prompt = "Region map scene unavailable"
		_refresh_labels()
		return
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.z_index = 20
	host.set_screen(_screen)
	add_child(host)
	var save: Gen2SaveData = _injected_save if _injected_save != null \
		else _selected_runtime_save()
	if not host.open_fly_map(_world, _data, save, request):
		Gen2Screen.drop(host)
		_script_prompt = "Region map unavailable"
		_refresh_labels()
		return
	host.save_action = persist_world_snapshot
	host.completed.connect(_on_service_completed)
	host.sfx_requested.connect(_play_sfx)
	host.cry_requested.connect(_play_species_cry)
	_service_host = host
	_script_prompt = "Fly: choose a town"
	_refresh_labels()


## The answer to a host-owned YES/NO, which is not a script result either. Only
## one question asks one today, so this names it rather than keeping a queue of
## pending questions nothing else would ever put anything in.
func _apply_host_choice(results: Array) -> bool:
	for result: Dictionary in results:
		if StringName(result.get("kind", &"")) != &"host_choice":
			continue
		var accepted: bool = int(result.get("choice", 1)) == 0
		if _mail_take_slot >= 0:
			_answer_mail_take(accepted)
			_refresh_labels()
			return true
		var item: int = _repel_renewal_item
		_repel_renewal_item = 0
		if accepted and item > 0:
			_renew_repel(item)
		_refresh_labels()
		return true
	return false


## The fly map's own answer, which is not a script result: a spawn to warp to, or
## -1 for a cancel.
func _apply_fly_choice(results: Array) -> bool:
	for result: Dictionary in results:
		if StringName(result.get("kind", &"")) != &"fly_chosen":
			continue
		var spawn: int = int(result.get("spawn", -1))
		if spawn < 0:
			_refresh_labels()
			return true
		var warped: Dictionary = _world.warp_to_spawn(spawn)
		if bool(warped.get("ok", false)):
			_refresh_after_escape()
		return true
	return false


func _on_service_completed(results: Array) -> void:
	var host: Gen2WorldServiceScreen = _service_host
	_service_host = null
	if host != null:
		Gen2Screen.drop(host)
	if _apply_host_choice(results):
		return
	if _apply_fly_choice(results):
		return
	# `ExitPokegearRadio_HandleMusic`: only the radio card takes the music off the
	# map, and the restart behind it is what plays whichever station was left
	# tuned, or the map's own track when none was. Every other service leaves the
	# music where it stands, which is what `_TownMap` does with the map poster.
	if host != null and host.radio_music_playing() != Gen2WorldServiceScreen.RADIO_MUSIC_SILENT:
		_play_current_map_music()
	_show_script_results(results)
	_reopen_start_menu_if_due()


## Script event to the method that spends it, each taking the event. Four types
## are not here: `soft_reset_requested` ends the screen, `tree_shake_requested`
## has nothing for a host to start because the object animates itself for the
## frames the stream sleeps, and the rest are in [constant EVENT_FLAGS] and
## [constant EVENT_PROMPTS].
const EVENT_HANDLERS: Dictionary = {
	&"presentation_special_applied": &"_apply_presentation",
	&"contest_mons_dropped_off": &"_event_contest_drop_off",
	&"contest_mons_returned": &"_event_contest_return",
	&"hall_of_fame_requested": &"_event_hall_of_fame",
	&"credits_requested": &"_event_credits",
	&"battle_tower_opponent_loaded": &"_event_battle_tower_opponent",
	&"field_move_confirmed": &"_event_field_move_confirmed",
	&"pokemon_picture_requested": &"_event_show_picture",
	&"pokemon_picture_closed": &"_event_hide_picture",
	&"money_window_opened": &"_show_money_window",
	&"money_window_closed": &"_event_hide_money_window",
	&"party_happiness_changed": &"_apply_party_happiness",
	&"party_member_removed": &"_remove_party_member",
	&"party_mail_given": &"_give_party_mail",
	&"screen_shake_requested": &"_event_screen_shake",
}

## `presentation_special_applied` kind to the method that starts it.
const PRESENTATION_HANDLERS: Dictionary = {
	&"prof_oaks_pc_boot": &"_event_prof_oaks_pc",
	&"heal_machine_anim": &"_start_heal_machine_sounds",
	&"palette_fade": &"_start_script_fade",
}

## Events the results loop only records, and what each raises.
const EVENT_FLAGS: Dictionary = {
	## `Script_reloadmap`'s own entry method, which a warp does not share: only
	## this one re-enters the map the player is already standing on.
	&"battle_map_reload_requested": [&"map_changed", &"map_reloaded"],
	&"warp": [&"map_changed"],
	&"world_clock_changed": [&"clock_changed"],
	## `Script_reloadmapafterbattle`'s LOSE branch, which is `ScriptJump
	## Script_BattleWhiteout` and ends the script: the runner has already
	## stopped, so the sequence is started once the loop is done.
	&"blackout": [&"blacked_out"],
}

## Events with nothing for a host to do but say so.
const EVENT_PROMPTS: Array[StringName] = [
	&"rock_smash_effect_requested", &"movement_command_requested", &"item_changed",
	&"money_changed", &"coins_changed", &"movement_blocked", &"movement_failed",
]

## Runtime requests the screen answers itself. Each method takes the request and
## answers what the results loop does next: `break`, `return` when it has already
## shown its own results, or `none`.
const REQUEST_HANDLERS: Dictionary = {
	&"trainer_approach_requested": &"_request_trainer_approach",
	&"battle_requested": &"_request_battle",
	&"catch_tutorial_requested": &"_request_battle",
	&"bug_contest_judging_requested": &"_request_bug_contest_judging",
	&"quick_save_requested": &"_request_quick_save",
	&"swarm_requested": &"_request_swarm",
	&"map_radio_requested": &"_request_map_radio",
	&"audio_requested": &"_request_audio",
}

## Runtime requests the screen answers by opening a page: the method that opens
## it, and what a refusal does. `continue` leaves the script where it is,
## `prompt` falls through to the generic acknowledge, and the rest complete the
## request themselves with the values beside them.
const REQUEST_OPENERS: Dictionary = {
	&"link_record_requested": [&"_open_link_record", &"continue", {}],
	&"link_room_requested": [&"_open_link_room", &"continue", {}],
	&"party_selection_requested": [&"_open_party_selection", &"continue", {}],
	&"name_rater_requested": [&"_open_name_rater", &"continue", {}],
	&"move_deleter_requested": [&"_open_move_deleter", &"continue", {}],
	&"move_tutor_requested": [&"_open_move_tutor", &"continue", {}],
	&"day_care_requested": [&"_open_day_care", &"continue", {}],
	&"pokedex_entry_requested": [&"_open_pokedex_entry", &"continue", {}],
	## A cartridge whose cache has no slots or card flip art gives the coins back
	## untouched rather than stopping the script.
	&"slot_machine_requested": [&"_open_slot_machine", &"coins", {}],
	&"card_flip_requested": [&"_open_card_flip", &"coins", {}],
	## `ret z` on an empty dex, and the same answer for a cache with no glyphs or
	## no diploma art: the script runs straight on and writes nothing either.
	&"unown_printer_requested": [&"_open_unown_printer", &"values", {"ok": true}],
	&"diploma_requested": [&"_open_diploma", &"values", {"ok": true}],
	## A cache with no puzzle art answers an unsolved board, which is the
	## `iftrue` the map takes either way.
	&"unown_puzzle_requested": [
		&"_open_unown_puzzle", &"values", {"ok": true, "script_value": 0},
	],
	&"pokemon_requested": [&"_open_gift_nickname", &"prompt", {}],
	&"contest_mon_requested": [&"_open_contest_nickname", &"prompt", {}],
}

## Requests the service host draws, all on one screen.
const SERVICE_HOST_REQUESTS: Array[StringName] = [
	&"mart_requested", &"phone_call_requested", &"special_phone_call_requested",
	&"town_map_requested", &"apricorn_selection_requested", &"pc_requested",
	&"mom_bank_dial_requested", &"elevator_requested",
]


func _show_script_results(results: Array) -> void:
	var flags: Dictionary = {}
	for source_result: Dictionary in results:
		var result: Dictionary = Gen2ModHost.publish(Gen2ModHost.CHANNEL_WORLD, source_result)
		## Spent before the status below, and before any branch of it that leaves
		## the loop: a command's presentation effect happened before the wait the
		## same result ends on. A `break` that skipped this left a `pokepic`
		## undrawn, since `Script_pokepic` is followed by the `cry` whose runtime
		## request breaks out of the loop.
		for result_event: Dictionary in result.get("events", []):
			if not _apply_result_event(result_event, flags):
				return
		if result.has("clock"):
			flags[&"clock_changed"] = true
		var verdict: StringName = _apply_result_status(result, flags)
		if verdict == &"return":
			return
		if verdict == &"break":
			break
	_settle_after_results(flags)


## Spends one script event, raising its rows of [constant EVENT_FLAGS] in
## [param flags]. False when the screen is gone and the rest is dropped.
func _apply_result_event(event: Dictionary, flags: Dictionary) -> bool:
	var type: StringName = StringName(event.get("type", &""))
	if type == &"soft_reset_requested":
		## `special Reset` restarts the console, which is how a saved and left
		## Battle Tower challenge leaves the battle room. The save has already
		## been written by the action in front of it.
		persist_world_snapshot()
		_soft_reset()
		return false
	for flag: StringName in EVENT_FLAGS.get(type, []):
		flags[flag] = true
	if EVENT_PROMPTS.has(type):
		_script_prompt = "Applied: %s" % String(type)
	elif EVENT_HANDLERS.has(type):
		call(EVENT_HANDLERS[type], event)
	return true


func _apply_presentation(event: Dictionary) -> void:
	var kind: StringName = StringName(event.get("kind", &""))
	if PRESENTATION_HANDLERS.has(kind):
		call(PRESENTATION_HANDLERS[kind], event)


## `ContestDropOffMons` masks the party to its lead; the world state keeps the
## stashed species byte and the save keeps the members themselves.
## An event, not a runtime request: `halloffame` commits its flag and runs on,
## and the source's own `end` is the next command, so nothing is waiting to be
## resumed when this opens.
func _event_hall_of_fame(_event: Dictionary) -> void:
	open_hall_of_fame()


func _event_prof_oaks_pc(_event: Dictionary) -> void:
	open_prof_oaks_pc()


func _event_hide_picture(_event: Dictionary) -> void:
	_hide_story_picture()


func _event_hide_money_window(_event: Dictionary) -> void:
	_hide_money_window()


func _event_contest_drop_off(_event: Dictionary) -> void:
	Gen2WorldPartyHost.contest_drop_off_mons(_active_party_save())


func _event_contest_return(_event: Dictionary) -> void:
	Gen2WorldPartyHost.contest_return_mons(_active_party_save())


## `Script_credits` farcalls `RedCredits`, whose own `ld a, SPAWN_RED` puts the
## next CONTINUE on Mount Silver.
func _event_credits(_event: Dictionary) -> void:
	if _world != null:
		_world.spawn_after_champion = Gen2WorldSnapshot.SPAWN_AFTER_RED
	open_credits()


## `LoadOpponentTrainerAndPokemonWithOTSprite`'s tail: the opponent is chosen at
## random and has to appear as whoever was drawn.
func _event_battle_tower_opponent(event: Dictionary) -> void:
	_world.set_object_sprite(int(event.get("object", 0)), int(event.get("sprite", 0)))


## `iftrue Script_Cut` and its four counterparts. The move is the host's, and it
## is the same staged request and acknowledge the party submenu reaches, so the
## two ways in stay one path.
func _event_field_move_confirmed(event: Dictionary) -> void:
	_use_prompted_field_move(int(event.get("move", 0)), int(event.get("slot", -1)))


func _event_show_picture(event: Dictionary) -> void:
	_show_story_picture(int(event.get("pokemon", 0)))


func _event_screen_shake(event: Dictionary) -> void:
	if _effects != null:
		_effects.start_screen_shake(int(event.get("strength", 0)), &"screen_shake", event)
	if _renderer != null:
		_renderer.refresh()


## What the result's own status leaves the loop doing: `break`, `return` when it
## has already shown results of its own, or `none`.
func _apply_result_status(result: Dictionary, flags: Dictionary) -> StringName:
	var status: StringName = StringName(result.get("status", &""))
	if status == &"phone_ring":
		flags[&"waiting"] = true
		var ring: Dictionary = result.get("event", {})
		_script_prompt = "Phone ringing: %s" % _phone_contact_label(
			ring.get("contact", {})
		)
		return &"none"
	if status == &"recovered":
		## `_recovered_result`'s own status, raised on the same result the
		## `blackout` event is on.
		flags[&"blacked_out"] = true
		return &"none"
	if status != &"waiting":
		if not bool(result.get("ok", false)):
			flags[&"failed"] = true
			_script_prompt = "Script stopped: %s" % String(result.get("reason", "unknown"))
		return &"none"

	flags[&"waiting"] = true
	var event: Dictionary = result.get("event", {})
	var event_type: StringName = StringName(event.get("type", &""))
	if event_type == &"text":
		return _apply_text_pause(event, flags)
	if event_type == &"button":
		if _text_box != null:
			_text_box.visible = true
		_script_prompt = "A: continue script"
		return &"none"
	if event_type == &"wait":
		_script_prompt = "Script waiting on %s" % String(event.get("wait", &"frames"))
		return &"none"
	if event_type in [&"choice", &"menu"]:
		_open_service_host()
		return &"break"
	if event_type == &"runtime_request":
		return _handle_runtime_request(event.get("request", {}))
	return &"none"


## A `writetext` pause. Prof Oak's PC is the one special that draws on its own
## and whose script runs on past it, so its pages are shown first and this text
## waits behind them.
func _apply_text_pause(event: Dictionary, flags: Dictionary) -> StringName:
	if event.has("unown_wall") and _open_unown_wall(String(event.get("text", ""))):
		return &"break"
	if _text_box == null or _text_box.font == null:
		return &"none"
	# `LoadBlinkingCursor` is `Paragraph`, `_ContText` and `PromptText`; a
	# `writetext` whose text ends in `done` reaches none of them, so its last page
	# carries no arrow and the script runs straight on.
	_text_awaits_press = bool(event.get("prompt", true))
	if _oak_pc_pages.is_empty():
		_apply_text_box_options()
		_text_box.show_text(String(event.get("text", "")), _text_awaits_press)
		_text_box.visible = true
	_script_prompt = "A: advance text"
	flags[&"continue_after_text"] = true
	return &"none"


func _handle_runtime_request(request: Dictionary) -> StringName:
	var kind: StringName = StringName(request.get("kind", &""))
	if REQUEST_HANDLERS.has(kind):
		return call(REQUEST_HANDLERS[kind], request) as StringName
	if REQUEST_OPENERS.has(kind):
		var opened: StringName = _open_requested_page(kind, request)
		if opened != &"prompt":
			return opened
	elif kind in Gen2WorldHost.UNATTENDED_REQUESTS:
		var settled: Array = _complete_unattended_request()
		if settled.is_empty():
			return &"none"
		_show_script_results(settled)
		return &"return"
	elif kind in SERVICE_HOST_REQUESTS:
		_open_service_host()
		return &"break"
	_script_prompt = "Runtime request: %s, press A to acknowledge" % String(
		request.get("kind", "effect")
	)
	return &"none"


## Opens [param kind]'s page, or spends its [constant REQUEST_OPENERS] refusal.
func _open_requested_page(kind: StringName, request: Dictionary) -> StringName:
	var row: Array = REQUEST_OPENERS[kind]
	if call(row[0], request):
		return &"break"
	if row[1] == &"continue":
		return &"none"
	if row[1] == &"prompt":
		return &"prompt"
	var values: Dictionary = (row[2] as Dictionary).duplicate()
	if row[1] == &"coins":
		values = {
			"ok": true,
			"coins": int((request.get("values", {}) as Dictionary).get("coins", 0)),
		}
	_show_script_results(_world.complete_runtime_request(values))
	return &"return"


func _open_link_record(_request: Dictionary) -> bool:
	return _open_link_screen(Gen2LinkScreen.MODE_RECORD)


func _request_trainer_approach(request: Dictionary) -> StringName:
	_start_trainer_approach(request)
	return &"break"


func _request_battle(request: Dictionary) -> StringName:
	_start_battle_request(request)
	return &"break"


## `_BugContestJudging` scores the player, ranks them against the contestants who
## turned up and leaves the placing in wScriptVar, which the results script
## branches on.
func _request_bug_contest_judging(_request: Dictionary) -> StringName:
	var judged: Dictionary = _world.judge_bug_contest(_encounter_random)
	var judged_results: Array = _world.complete_runtime_request({
		"ok": true,
		"script_value": int(judged.get("player_place", 0)),
		"judging": judged.duplicate(true),
	})
	_script_prompt = _bug_contest_placings_text(judged)
	_show_script_results(judged_results)
	return &"return"


## `TryQuickSave`, which is `Link_SaveGame`: the overwrite question, the SAVING
## box and `SavedTheGame`, on the service screen where BILL'S PC's already are. A
## driver with no scene behind it still writes rather than hanging.
func _request_quick_save(_request: Dictionary) -> StringName:
	if _service_host == null and _open_quick_save_screen():
		return &"break"
	var written: Dictionary = persist_world_snapshot()
	_show_script_results(_world.complete_runtime_request({
		"ok": true,
		"script_value": 1 if bool(written.get("ok", false)) else 0,
	}))
	return &"return"


func _open_quick_save_screen() -> bool:
	var host: Gen2WorldServiceScreen = SERVICE_SCENE.instantiate() as Gen2WorldServiceScreen
	if host == null:
		return false
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.z_index = 20
	host.set_screen(_screen)
	add_child(host)
	var save: Gen2SaveData = _injected_save if _injected_save != null \
		else _selected_runtime_save()
	host.save_action = persist_world_snapshot
	if not host.open_quick_save(_world, _data, save, _injected_save == null):
		Gen2Screen.drop(host)
		return false
	host.completed.connect(_on_service_completed)
	host.sfx_requested.connect(_play_sfx)
	host.cry_requested.connect(_play_species_cry)
	_service_host = host
	_script_prompt = "Saving"
	_refresh_labels()
	return true


func _request_swarm(request: Dictionary) -> StringName:
	var values: Dictionary = request.get("values", {})
	_show_script_results(_world.complete_runtime_request({
		"ok": true,
		"active": true,
		"map_group": int(values.get("map_group", -1)),
		"map_number": int(values.get("map_number", -1)),
	}))
	return &"return"


func _request_map_radio(request: Dictionary) -> StringName:
	var radio_results: Array = _handle_map_radio_request(request)
	if not radio_results.is_empty():
		_show_script_results(radio_results)
	return &"break"


func _request_audio(request: Dictionary) -> StringName:
	var audio_results: Array = _handle_audio_request(request)
	if not audio_results.is_empty():
		_show_script_results(audio_results)
	return &"break"


func _settle_after_results(flags: Dictionary) -> void:
	if not flags.has(&"waiting") and not flags.has(&"failed"):
		_script_prompt = ""
	if flags.has(&"clock_changed"):
		_sync_host_clock()
	if _renderer != null:
		if flags.has(&"map_changed"):
			## A warp redraws the whole tilemap, so a balance window a script
			## left standing goes with it the way `closetext`'s redraw takes it.
			_hide_money_window()
			## A warp has already run `_apply_map`, which is `EnterMap` whole;
			## re-entering it here would take MAPSETUP_RELOADMAP's own poison
			## reset on a step that never asked for one.
			if flags.has(&"map_reloaded"):
				_world.reload_current_map()
			_animation.configure(_world, _render_time_of_day())
			_set_renderer_world()
			_renderer.set_time_of_day(_render_time_of_day())
			_play_current_map_music()
		else:
			_renderer.refresh()
	## Decided in the loop and spent here, because a special drawing its own pages
	## is an event on the same result as the text waiting behind them.
	if flags.has(&"continue_after_text") and _continue_if_text_settled():
		return
	if flags.has(&"blacked_out"):
		_start_whiteout()
		return
	_refresh_labels()


## What a map change owes the screen once the world has already applied it: the
## renderer, the animation and the music all belong to the map that is now under
## the player. A warp reached through a script goes through the script result
## instead; an escape move has no script here to carry it.
func _refresh_after_escape() -> void:
	if _world == null:
		return
	## `Script_AbortBugContest`'s `special ContestReturnMons`, which the warp
	## itself cannot run: the masked party members are the save's.
	if _world.take_contest_abort():
		Gen2WorldPartyHost.contest_return_mons(_active_party_save())
	_animation.configure(_world, _render_time_of_day())
	_set_renderer_world()
	if _renderer != null:
		_renderer.set_time_of_day(_render_time_of_day())
	_play_current_map_music()
	_refresh_labels()


## One frame's worth of `ShakeGrass`, for the player and for every object that
## started a step onto grass on it.
func _spawn_grass_rustles() -> void:
	if _world == null or _effects == null:
		return
	for rustle: Dictionary in _world.take_grass_rustles():
		_effects.start_grass_rustle(
			int(rustle["object_index"]), rustle["cell"], int(rustle["frames"])
		)
	if _renderer != null and _effects.sprites_active():
		_renderer.refresh()


## The yes half of an Ask*Script, running the same request the submenu does. A
## refusal is silent here: AskCutScript's `.CheckMap` falls to `closetext`.
func _use_prompted_field_move(move: int, slot: int) -> void:
	if _world == null:
		return
	var asks: Dictionary = {
		Gen2WorldFieldMove.MOVE_CUT: _world.cut_request,
		Gen2WorldFieldMove.MOVE_SURF: _world.surf_request.bind(_party_species(slot)),
		Gen2WorldFieldMove.MOVE_WHIRLPOOL: _world.whirlpool_request,
		Gen2WorldFieldMove.MOVE_WATERFALL: _world.waterfall_request,
		Gen2WorldFieldMove.MOVE_HEADBUTT: _world.headbutt_request,
	}
	if not asks.has(move):
		return
	if not bool(((asks[move] as Callable).call() as Dictionary).get("ok", false)):
		return
	_show_field_move_text(
		Gen2WorldFieldMove.used_text(move, _prompted_field_move_name(slot))
	)


## GetPartyNickname, which every one of these scripts calls before its text. A
## move used from its HM has no nickname, so the line names the player instead.
func _prompted_field_move_name(slot: int) -> String:
	if slot < 0:
		return _player_display_name()
	var save: Gen2SaveData = _active_party_save()
	if save == null or slot >= save.party.size():
		return "#MON"
	var member: Variant = save.party[slot]
	return _mon_display_name(member as Gen2SaveMon) if member is Gen2SaveMon else "#MON"


## `PlaceString`'s `<PLAYER>`, which is `wPlayerName`. With no save selected it
## says PLAYER, the fallback the start menu's STATUS row takes.
func _player_display_name() -> String:
	var player: String = _world.player_name() if _world != null else ""
	return player if not player.is_empty() else "PLAYER"


## `special DisplayCoinCaseBalance`, `..MoneyAndCoinBalance` and
## `PlaceMoneyTopRight`. Each writes the tilemap and returns, so the window
## stands over the map exactly as `Script_pokepic`'s box does and is taken away
## by the same thing: the redraw behind `closetext`.
func _show_money_window(event: Dictionary) -> void:
	if _data == null:
		return
	var drawn: Dictionary = Gen2MartPage.balance_window(
		_data, StringName(event.get("kind", &"money_top_right")),
		int(event.get("money", 0)), int(event.get("coins", 0))
	)
	if drawn.is_empty():
		return
	_hide_money_window()
	var image: Image = drawn["image"]
	_money_window = TextureRect.new()
	_money_window.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	Gen2PicImage.show(_money_window, image)
	_money_window.size = image.get_size()
	_money_window.position = Vector2(
		(drawn["at"] as Vector2i) * Gen2Font.TILE
	)
	_money_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.display(_money_window)


## Public screenshot drivers for the three, since no fixture cell reaches any of
## them: `crystal 26 2 <png> live money_top_right`, `... coin_balance` and
## `... money_and_coins`. Not `coin_case`, which is the pack's own field item.
func preview_money_top_right() -> void:
	_preview_balance_window(&"money_top_right")


func preview_coin_balance() -> void:
	_preview_balance_window(&"coin_case")


func preview_money_and_coins() -> void:
	_preview_balance_window(&"money_and_coins")


func _preview_balance_window(kind: StringName) -> void:
	if _world == null:
		return
	_show_money_window({
		"kind": kind,
		"money": _world.state.money() if _world.state != null else 0,
		"coins": _world.state.coins() if _world.state != null else 0,
	})
	_refresh_labels()


func _hide_money_window() -> void:
	if _money_window == null:
		return
	Gen2Screen.drop(_money_window)
	_money_window = null


## Whether a balance window is up, for a screenshot tool or a test that would
## otherwise have to read pixels back.
func money_window_open() -> bool:
	return _money_window != null


## `HaircutOrGrooming`'s own `call ChangeHappiness`. The row is the runner's, since
## the roll that picked it has to belong to the seeded generator; the byte it
## changes belongs to the save this screen holds. Below, `RemoveMonFromPartyOrBox`
## with REMOVE_PARTY, which `ReturnShuckie` runs on the row the player handed back,
## and `GivePokeMail`, the item onto the member's own MON_ITEM and the script's
## message into its `sPartyMail` row. Both are events rather than runtime requests:
## each routine answers nothing and runs straight on, and the write is the same
## save write a happiness change is.
func _give_party_mail(event: Dictionary) -> void:
	var save: Gen2SaveData = _embedded_party_save()
	var slot: int = int(event.get("slot", -1))
	if save == null or slot < 0 or slot >= save.party.size():
		return
	var mon: Gen2SaveMon = save.party[slot] as Gen2SaveMon
	if mon == null:
		return
	var item: int = int(event.get("item", 0))
	mon.item = item
	var message := PackedByteArray()
	for code: Variant in (event.get("message", []) as Array):
		message.append(int(code) & 0xFF)
	mon.mail = Gen2SaveMail.from_script(
		message, mon.original_trainer, int(mon.ot_id),
		int(event.get("species", mon.species)), item
	)


func _remove_party_member(event: Dictionary) -> void:
	var save: Gen2SaveData = _embedded_party_save()
	var slot: int = int(event.get("slot", -1))
	if save == null or slot < 0 or slot >= save.party.size():
		return
	save.party.remove_at(slot)


## `PlayRadio` over the map: the station's own line in a four-row box, held
## until A or B, which is what the script's own text pause already is.
func _handle_map_radio_request(request: Dictionary) -> Array:
	if _world == null:
		return []
	var values: Dictionary = request.get("values", {})
	var playing: Dictionary = _world.play_map_radio(int(values.get("station", 0)))
	if playing.is_empty():
		return _world.complete_runtime_request({"ok": true, "script_value": 0})
	var lines: PackedStringArray = playing.get("lines", PackedStringArray())
	var spoken: PackedStringArray = PackedStringArray()
	for line: String in lines:
		if not line.strip_edges().is_empty():
			spoken.append(line)
	_script_prompt = "\n".join(spoken)
	return _world.complete_runtime_request({"ok": true, "script_value": 1})


## `NewPokedexEntry`, the page and the cry a Game Corner prize opens on the
## first time its species is caught.
func _open_pokedex_entry(request: Dictionary) -> bool:
	if _world == null or _data == null or _pokedex_host != null:
		return false
	var species: int = int((request.get("values", {}) as Dictionary).get("species", 0))
	if species <= 0:
		return false
	var host := Gen2PokedexScreen.new()
	if not host.open_entry(_data, _world, species):
		host.free()
		return false
	host.z_index = 10
	host.set_screen(_screen)
	add_child(host)
	host.closed.connect(_on_pokedex_entry_closed)
	host.cry_requested.connect(_on_pokedex_cry_requested)
	host.sfx_requested.connect(_play_sfx)
	_pokedex_host = host
	_script_prompt = "Pokedex entry open"
	_refresh_labels()
	return true


## The entry closing is what resumes the script: `ExitAllMenus` behind
## `NewPokedexEntry` and then the special's own `ret`.
func _on_pokedex_entry_closed() -> void:
	var host: Gen2PokedexScreen = _pokedex_host
	_pokedex_host = null
	if host != null:
		_pokedex_prev_entry = host.previous_entry()
		Gen2Screen.drop(host)
	## A catch's page has a battle behind it rather than a script, and that
	## battle is what the page returns to.
	if _battle_host != null:
		_battle_host.complete_dex_entry()
		_refresh_labels()
		return
	if _world != null and not _world.pending_runtime_request().is_empty():
		_show_script_results(_world.complete_runtime_request({"ok": true, "script_value": 0}))
	_refresh_labels()


func _apply_party_happiness(event: Dictionary) -> void:
	var save: Gen2SaveData = _embedded_party_save()
	var slot: int = int(event.get("slot", -1))
	if save == null or slot < 0 or slot >= save.party.size():
		return
	var mon: Gen2SaveMon = save.party[slot] as Gen2SaveMon
	if mon == null:
		return
	mon.happiness = Gen2WorldPartyHost.change_happiness(
		_data, mon.happiness, int(event.get("happiness_kind", 0))
	)


## `SelectMonFromParty` opened by one of `engine/events/haircut.asm`'s four
## routines. The same list the Name Rater and the move deleter open, and the
## same `_party_host` the start menu uses, so an overlay is named in one place
## and a press reaches it through one branch.
func _open_party_selection(_request: Dictionary = {}) -> bool:
	if _party_host != null or _world == null or _data == null:
		return false
	var save: Gen2SaveData = _embedded_party_save()
	if save == null:
		_script_prompt = "Party selection needs a validated save"
		return false
	var host: Gen2PartyScreen = PARTY_SCENE.instantiate() as Gen2PartyScreen
	if host == null:
		_script_prompt = "Party scene unavailable"
		return false
	host.set_context(_data, save, true)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.z_index = 20
	host.mouse_filter = Control.MOUSE_FILTER_STOP
	host.selection_made.connect(_on_party_selection_made)
	host.sfx_requested.connect(_play_sfx)
	host.cry_requested.connect(_on_pokedex_cry_requested)
	host.set_screen(_screen)
	add_child(host)
	host.open_selection()
	_party_host = host
	_party_selection = {"save": save}
	_script_prompt = "Choose a #MON"
	_refresh_labels()
	return true


## `PartyMenuSelect`'s answer: the row for a member and the carry for CANCEL or
## B, which every one of the four routines turns into `xor a`.
func _on_party_selection_made(party_index: int) -> void:
	var host: Gen2PartyScreen = _party_host
	_party_host = null
	var save: Gen2SaveData = _party_selection.get("save", null) as Gen2SaveData
	_party_selection = {}
	if host != null:
		Gen2Screen.drop(host)
	if _world == null:
		_refresh_labels()
		return
	var result: Dictionary = {"ok": true, "party_index": -1}
	## `CheckCurPartyMonFainted` walks `wPartyMon1HP` for every slot but the
	## chosen one, so the whole column travels with the row that was picked.
	var party_fainted: Array = []
	if save != null:
		for member: Variant in save.party:
			party_fainted.append(member is Gen2SaveMon and (member as Gen2SaveMon).hp <= 0)
	if save != null and party_index >= 0 and party_index < save.party.size():
		var mon: Gen2SaveMon = save.party[party_index] as Gen2SaveMon
		if mon != null:
			result = {
				"ok": true,
				"party_index": party_index,
				## `wPartySpecies` holds EGG for an egg slot, which is the byte
				## `HaircutOrGrooming` compares against.
				"species": Gen2WorldScriptRunner.SPECIES_EGG if mon.is_egg else mon.species,
				"nickname": _mon_display_name(mon),
				"species_name": String(_data.species(mon.species).get("name", "")),
				## What the three deferred routines read off the row they were
				## handed: MON_DVS, MON_OT_ID, the OT name, MON_HAPPINESS and
				## `CheckCurPartyMonFainted`'s own question.
				"dvs": [(int(mon.dvs) >> 8) & 0xFF, int(mon.dvs) & 0xFF],
				"ot_id": int(mon.ot_id),
				"original_trainer": mon.original_trainer,
				"happiness": int(mon.happiness),
				"fainted": mon.hp <= 0,
				## MON_ITEM and the `sPartyMail` row behind it, which
				## `CheckPokeMail` reads in that order.
				"item": int(mon.item),
				"mail_message": Array(mon.mail.message) if mon.mail != null else [],
				## `ReadCaughtData`'s two bytes, unpacked the way the save keeps
				## them, plus MON_LEVEL for `SeerAdvice`.
				"level": int(mon.level),
				"caught_level": int(mon.caught_level),
				"caught_time": int(mon.caught_time),
				"caught_gender": int(mon.caught_gender),
				"caught_location": int(mon.caught_location),
				"party_fainted": party_fainted,
			}
	_show_script_results(_world.complete_runtime_request(result))
	_refresh_labels()


## `Script_pokepic`'s box over the map, which is what a starter's ball and every
## other `pokepic` shows. The map stays up behind it: `MENU_BACKUP_TILES` is what
## `ClosePokepic` restores, and an overlay that is removed does that by existing.
func _show_story_picture(species: int) -> void:
	if _data == null or _world == null:
		return
	var image: Image = Gen2PokepicPage.render(
		_data, species, _world.current_map, _render_time_of_day()
	)
	if image == null:
		return
	_hide_story_picture()
	_story_picture = TextureRect.new()
	_story_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	Gen2PicImage.show(_story_picture, image)
	_story_picture.size = image.get_size()
	_story_picture.position = Vector2(
		Gen2PokepicPage.menu_box().border_position() * Gen2Font.TILE
	)
	_story_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.display(_story_picture)


## How many of `wLandmarkSignTimer`'s sixty frames the sign has left, and zero
## when there is none up. What a test or a screenshot tool waits on.
func map_name_sign_passes() -> int:
	return _map_name_sign_passes


## `InitMapNameSign`'s own decision, raised where the map load leaves it: the
## sign is a window over the bottom four rows and the map keeps moving behind it,
## which is why a connection crossing shows one without stopping the camera.
##
## Gold and Silver ship neither the routine nor `MapEntryFrameGFX`, so the world
## asks for no sign there and the page would answer none either.
func _raise_map_name_sign() -> void:
	if _world == null or _data == null:
		return
	var landmark: int = _world.map_name_sign_pending()
	_world.clear_map_name_sign()
	if landmark < 0:
		return
	_hide_map_name_sign()
	## The timer is the setup script's, not the sheet's: a cache with no
	## `MapEntryFrameGFX` spends the same sixty frames with nothing drawn in
	## them rather than skipping them.
	_map_name_sign_passes = Gen2WorldAPI.MAP_NAME_SIGN_PASSES
	var image: Image = Gen2MapNameSignPage.render(
		_data,
		_data.landmark_name(landmark),
		_world.current_map.environment if _world.current_map != null \
			else Gen2WorldAPI.ENVIRONMENT_TOWN,
		_render_time_of_day(),
	)
	if image == null:
		return
	_map_name_sign = TextureRect.new()
	_map_name_sign.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	Gen2PicImage.show(_map_name_sign, image)
	_map_name_sign.size = image.get_size()
	_map_name_sign.position = Vector2(0, Gen2MapNameSignPage.TOP)
	_map_name_sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## `PlaceMapNameSign` returns on the frame the timer still reads 60, so the
	## window is only brought down on the frame after the one that raised it.
	_map_name_sign.visible = false
	_screen.display(_map_name_sign)


## `PlaceMapNameSign`, which counts `wLandmarkSignTimer` down a frame at a time
## and takes the window away on the frame it runs out.
func _advance_map_name_sign_pass() -> void:
	if _map_name_sign_passes <= 0:
		return
	_map_name_sign_passes -= 1
	if _map_name_sign_passes <= 0:
		_hide_map_name_sign()
		return
	if _map_name_sign != null:
		_map_name_sign.visible = true


## `PlayerEvents`' own `xor a / ld [wLandmarkSignTimer], a`, which sits behind
## `DoPlayerEvent` and is skipped for PLAYEREVENT_CONNECTION and
## PLAYEREVENT_JOYCHANGEFACING alone. Called where this screen dispatches one of
## the others, rather than keyed on a script being busy: the map's own callbacks
## are `RunMapCallback`'s work inside map setup and reach `PlayerEvents` never,
## so a queued one used to take down the very sign the map load had raised.
func _zero_map_name_sign_timer() -> void:
	_hide_map_name_sign()


## The same, for a batch of script results, since only some of them are a player
## event. `RunMapCallback`'s work is map setup and reaches `PlayerEvents` never;
## `RunSceneScript` runs its scene script and then answers carry only when that
## script set RUN_DEFERRED_SCRIPT, so a scene of bare `end`s (Route 29's two, and
## most of the map scenes in either pin) raises no event and takes no sign down.
func _zero_map_name_sign_for(results: Array) -> void:
	for result: Dictionary in results:
		match StringName((result.get("source", {}) as Dictionary).get("kind", &"")):
			&"callback":
				continue
			&"scene":
				if not bool(result.get("deferred", false)):
					continue
		_zero_map_name_sign_timer()
		return


func _hide_map_name_sign() -> void:
	_map_name_sign_passes = 0
	if _map_name_sign == null:
		return
	Gen2Screen.drop(_map_name_sign)
	_map_name_sign = null


## `DisplayUnownWords`: the chamber wall's word in a box of its own, held by
## `JoyWaitAorB`. The special stages the word as a text the runner is waiting on,
## so answering the box is what answers that wait; a cache or a map that cannot
## draw the letters falls back to the text box, which is what puts the word up
## on any host without the chamber's own tileset.
func _open_unown_wall(word: String) -> bool:
	if _world == null or _data == null or _unown_wall_box != null:
		return false
	var image: Image = Gen2UnownWallPage.render(
		_data, _world.current_tileset, _world.current_map, word, _render_time_of_day()
	)
	if image == null:
		return false
	var box: Gen2MenuBox = Gen2UnownWall.menu_box(word)
	_unown_wall_box = TextureRect.new()
	_unown_wall_box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	Gen2PicImage.show(_unown_wall_box, image)
	_unown_wall_box.size = image.get_size()
	_unown_wall_box.position = Vector2(box.border_position() * Gen2Font.TILE)
	_unown_wall_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.display(_unown_wall_box)
	_script_prompt = "A or B: close the wall"
	return true


func _close_unown_wall() -> void:
	if _unown_wall_box == null:
		return
	Gen2Screen.drop(_unown_wall_box)
	_unown_wall_box = null
	_play_sfx(Gen2BattleSwitchMenu.SFX_READ_TEXT_2)
	## The wait behind the box is the staged text the special left, so the script
	## resumes on the same press the source's `CloseWindow` returns on.
	_show_script_results(_world.run_event_queue(true))


func _hide_story_picture() -> void:
	if _story_picture != null:
		Gen2Screen.drop(_story_picture)
		_story_picture = null


func _sync_host_clock() -> void:
	if _clock == null or _world == null:
		return
	var clock: Dictionary = _world.world_clock()
	_clock.day = int(clock.get("day", _clock.day))
	_clock.hour = int(clock.get("hour", _clock.hour))
	_clock.minute = int(clock.get("minute", _clock.minute))


func _handle_audio_request(request: Dictionary) -> Array:
	if _audio_player == null:
		_script_prompt = "Audio unavailable: player is not ready"
		_refresh_labels()
		return []
	var kind: StringName = StringName(request.get("values", {}).get("kind", &""))
	if kind == &"sound_wait":
		if _audio_player.effect_playing():
			_audio_waiting = true
			_script_prompt = "Waiting for sound effect"
			_refresh_labels()
			return []
		var finished: Dictionary = Gen2WorldHost.complete_runtime_request(_world, {"ok": true})
		return finished.get("results", []) if bool(finished.get("ok", false)) else []
	var resolve_request: Dictionary = request.duplicate(true)
	if not resolve_request.has("source") and _world != null:
		resolve_request["source"] = _world.pending_runtime_request().get("source", {})
	var resolved: Dictionary = Gen2WorldHost.resolve_runtime_request(_world, resolve_request)
	if not bool(resolved.get("ok", false)):
		if kind == &"encounter_music":
			var skipped: Array = _world.complete_runtime_request({
				"ok": true, "audio_played": false,
				"audio_unavailable": resolved.get("reason", &"audio_data_unavailable"),
			})
			return skipped
		_script_prompt = "Audio unavailable: %s" % String(resolved.get("reason", "unknown"))
		_refresh_labels()
		return []
	var record: Dictionary = resolved.get("data", {}).get("audio", {})
	if kind == &"music_fadeout":
		record["fade_time"] = int(request.get("values", {}).get("fade_time", 0))
	var playback: Dictionary = _audio_player.play_record(
		record, kind, _audio_assets(),
		bool(request.get("values", {}).get("restart", false))
	)
	if not bool(playback.get("ok", false)):
		if kind == &"encounter_music":
			var skipped: Array = _world.complete_runtime_request({
				"ok": true, "audio_played": false,
				"audio_unavailable": playback.get("reason", &"audio_playback_failed"),
			})
			return skipped
		_script_prompt = "Audio unavailable: %s" % String(playback.get("reason", "unknown"))
		_refresh_labels()
		return []
	var completed: Dictionary = Gen2WorldHost.complete_runtime_request(
		_world, {"ok": true, "audio_played": bool(playback.get("played", false))}
	)
	if not bool(completed.get("ok", false)):
		_script_prompt = "Audio completion failed: %s" % String(
			completed.get("reason", "unknown")
		)
		_refresh_labels()
		return []
	return completed.get("results", [])


func _audio_assets() -> Dictionary:
	return {
		"wave_samples": _data.world_audio_asset(&"wave_samples") if _data != null else {},
		"drumkits": _data.world_audio_asset(&"drumkits") if _data != null else {},
	}


## `FadeToMapMusic`, which is what a map entered through a warp arrives behind:
## `wMusicFade` is eight and `wMusicFadeID` the map's own track, so the piece
## that was playing fades out and the new one starts where it lands. A map whose
## track is already playing keeps it, which is the routine's own `cp e`.
func _fade_to_map_music() -> void:
	if _audio_player == null or _data == null or _world == null \
		or _world.current_map == null:
		return
	_audio_player.fade_to(
		_data.world_audio(&"music", _world.state.map_music()),
		WARP_MUSIC_FADE_FRAMES, _audio_assets(),
	)


## One music track by its own index, for a screen that starts its own: the
## printer's is the first, and [method _play_current_map_music] puts the map's back.
func _play_music_track(index: int) -> void:
	if _audio_player == null or _data == null:
		return
	var record: Dictionary = _data.world_audio(&"music", index)
	if record.is_empty():
		return
	_audio_player.play_record(record, &"map_music", _audio_assets())


## Plays whatever `wMapMusic` currently holds. `Gen2WorldAPI` owns the write,
## following PlayMapMusic and its SpecialMapMusic surf override on map entry, so
## the track a tuned radio station left there survives until the player leaves the
## map. Restarting a piece already playing is a presentation difference from the
## source, which compares before it restarts.
func _play_current_map_music() -> void:
	if _audio_player == null or _data == null or _world == null or _world.current_map == null:
		return
	var track: int = _world.state.map_music()
	var record: Dictionary = _data.world_audio(&"music", track)
	if record.is_empty():
		return
	_audio_player.play_record(record, &"map_music", _audio_assets())


## An actor's one-shot outbox, drained once a world frame. A mod may not play a
## sound, so it asks for one and the host spends it: the same bargain the shiny
## pulse already has, with no dedup window needed since the mod asks once.
func _spend_actor_requests() -> void:
	if _actors == null:
		return
	for request: Dictionary in _actors.take_requests():
		if StringName(request["kind"]) == Gen2WorldActors.REQUEST_CRY:
			_play_species_cry(int(request["species"]))


func _mod_inventory() -> Dictionary:
	return _world.state.items() if _world != null else {}


## What [method Gen2ModHost.progress] reads while this world is open. The save is
## in it because the party, the boxes and the play timer are the save's, and the
## world screen is the one place that holds both.
func _mod_progress() -> Dictionary:
	return Gen2ModProgress.of(_world, active_save())


## What [method Gen2ModHost.request_hidden_item] collapses an ask against: the
## open map's own rows, with `taken` already answered off the event flag.
func _mod_hidden_items() -> Array:
	return _world.hidden_items() if _world != null else []


## A mod's item-gift asks, spent the way its hidden-item asks are and on the same
## gate: `verbosegiveitem`'s own transaction through the ordinary script path, so
## the fanfare, the box and the pacing are the world screen's exactly as they are
## for a give the map itself makes.
##
## One per frame, since the first one's box owns the world until it is pressed
## past, and the rest wait in the host's queue.
func _spend_item_gift_requests() -> void:
	if _world == null or not _world_idle_for_mod_request():
		return
	var gifts: Array[Dictionary] = Gen2ModHost.instance().take_item_gift_requests()
	for index: int in gifts.size():
		var results: Array = _world.give_item_gift(
			int(gifts[index].get("item", 0)), int(gifts[index].get("quantity", 1))
		)
		if results.is_empty():
			continue
		_zero_map_name_sign_timer()
		_show_script_results(results)
		Gen2ModHost.instance().requeue_item_gifts(gifts.slice(index + 1))
		return


## A mod's hidden-item asks, spent the same way and on the same gate: the mod
## named a cell and nothing else, and the map's own script runs it.
func _spend_hidden_item_requests() -> void:
	if _world == null or not _world_idle_for_mod_request():
		return
	var requests: Array[Vector2i] = Gen2ModHost.instance().take_hidden_item_requests()
	for index: int in requests.size():
		var results: Array = _world.take_hidden_item(requests[index])
		if results.is_empty():
			continue
		_zero_map_name_sign_timer()
		_show_script_results(results)
		## What is left goes back, in order, rather than being dropped on the
		## floor by the drain that could only spend one of them.
		Gen2ModHost.instance().requeue_hidden_items(requests.slice(index + 1))
		return


## A mod's notice asks, spent the way its hidden-item asks are and on the same
## gate. One at a time: the banner owns the bottom four rows for its own sixty
## passes, and raising a second over it would flicker rather than read.
func _spend_notice_requests() -> void:
	if _world == null or _data == null or not _world_idle_for_mod_request():
		return
	if _map_name_sign_passes > 0:
		return
	var notice: Dictionary = Gen2ModHost.instance().take_notice_request()
	if notice.is_empty():
		return
	var image: Image = Gen2MapNameSignPage.render_notice(
		_data, String(notice.get("title", "")), String(notice.get("line", "")),
		_world.current_map.environment if _world.current_map != null \
			else Gen2WorldAPI.ENVIRONMENT_TOWN,
		_render_time_of_day(),
		Gen2OptionsStore.current().textbox_frame,
	)
	if image == null:
		return
	_hide_map_name_sign()
	_map_name_sign_passes = Gen2WorldAPI.MAP_NAME_SIGN_PASSES
	_map_name_sign = TextureRect.new()
	_map_name_sign.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	Gen2PicImage.show(_map_name_sign, image)
	_map_name_sign.size = image.get_size()
	_map_name_sign.position = Vector2(0, Gen2MapNameSignPage.TOP)
	_map_name_sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon: Image = Gen2MapNameSignPage.render_notice_icon(
		_data, notice.get("icon", {}) as Dictionary, _render_time_of_day()
	)
	if icon != null:
		var badge := TextureRect.new()
		badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		Gen2PicImage.show(badge, icon)
		badge.size = icon.get_size()
		badge.position = Vector2(
			Gen2MapNameSignPage.NOTICE_ICON_AT * Gen2Font.TILE
		)
		_map_name_sign.add_child(badge)
	## The banner is brought down on the frame after the one that raised it, the
	## way `PlaceMapNameSign` leaves it.
	_map_name_sign.visible = false
	_screen.display(_map_name_sign)
	var sound: int = Gen2ModHost.notice_sound_index(
		StringName(notice.get("sound", Gen2ModHost.NOTICE_SOUND_DEFAULT))
	)
	if sound >= 0:
		_play_sfx(sound)


## Nothing of the world's own is running, which is the gate [method interact]
## applies plus a box or a script still holding the screen: a request may not
## open a text box over one that is already up.
func _world_idle_for_mod_request() -> bool:
	return not _overlay_open() and not _field_move_text \
		and _oak_pc_pages.is_empty() and not _world.phone_ring_active() \
		and not _world.fishing_busy() and not _world.script_busy() \
		and (_text_box == null or not _text_box.visible)


## `Script_cry`'s own path and the Pokedex CRY button's: `PlayCry` is an effect
## and not music, so it goes through the player a script's `cry` command uses.
func _play_species_cry(species: int) -> void:
	if _audio_player == null or _data == null:
		return
	var record: Dictionary = _data.species_cry(species)
	if record.is_empty():
		return
	_audio_player.play_record(record, &"cry", _audio_assets())


func _play_ledge_hop_sfx() -> void:
	_play_sfx(SFX_JUMP_OVER_LEDGE)


## `BattleAnimCmd_Sound` from a shiny pulse. The interpreter has no audio device,
## as it has none in a battle either, so the screen spends what its commands
## asked for. A cry is not one of them: the sparkle's script has no `anim_cry`.
func _play_encounter_sounds() -> void:
	for command: Dictionary in _encounters.frame_commands():
		if StringName(command["name"]) == Gen2BattleAnimScript.SOUND:
			_play_sfx(int((command["operands"] as Array)[1]))


func _start_heal_machine_sounds(event: Dictionary) -> void:
	_start_sound_schedule((event.get("sounds", []) as Array).duplicate(true))
	if _effects != null:
		_effects.start_heal_machine(
			int(event.get("machine_type", 0)), int(event.get("balls", 0))
		)
	_advance_sound_schedule()


func _start_sound_schedule(schedule: Array) -> void:
	_sound_schedule = schedule
	_sound_schedule_frame = 0


## One frame of that schedule, spent from the same pump the script's own wait is.
##
## A `wait` entry is `WaitPlaySFX`, and it is a real wait only while the driver
## is being serviced: a run with no audio device leaves the channels as the last
## sound left them, so `effect_playing()` would answer true for the rest of the
## run and the schedule would never drain. The rendered-frame count is what tells
## the two apart, which is what the battle screen's own `ANIM_WAIT_SFX` does.
func _advance_sound_schedule() -> void:
	while not _sound_schedule.is_empty():
		var due: Dictionary = _sound_schedule[0]
		if bool(due.get("wait", false)):
			if _audio_player != null and _audio_player.effect_playing():
				var rendered: int = _audio_player.timeline_updates()
				var still: int = 0 if int(due.get("rendered", -1)) != rendered \
					else int(due.get("still", 0)) + 1
				if still <= Gen2AudioPlayer.SERVICE_GAP_FRAMES:
					due["rendered"] = rendered
					due["still"] = still
					break
		elif int(due.get("frame", 0)) > _sound_schedule_frame:
			break
		_sound_schedule.pop_front()
		var index: int = int(due.get("index", 0))
		if StringName(due.get("kind", &"sound")) == &"music":
			_play_music(index)
		else:
			_play_sfx(index, bool(due.get("wait", false)))
	_sound_schedule_frame += 1


func _play_music(index: int) -> void:
	if _audio_player == null or _data == null:
		return
	var record: Dictionary = _data.world_audio(&"music", index)
	if record.is_empty():
		return
	_audio_player.play_record(record, &"map_music", _audio_assets())


## `PlaySFX`. [param waited] is the `WaitSFX` the source spends in front of a
## few of them; see [signal Gen2WorldServiceScreen.sfx_requested].
func _play_sfx(index: int, waited: bool = false) -> void:
	if _audio_player == null or _data == null:
		return
	var record: Dictionary = _data.world_audio(&"sfx", index)
	if record.is_empty():
		return
	_audio_player.play_record(
		record, &"waited_sfx" if waited else &"sound", _audio_assets()
	)


## The save whose party a queued script's VAR_PARTYCOUNT read and CheckPokerus
## special should see. A battle in progress may hold its own save, including a
## synthesized development one from a fallback capture, so it takes priority
## over the screen's ordinary selected save.
func _active_party_save() -> Gen2SaveData:
	if _active_battle_save != null:
		return _active_battle_save
	return _injected_save if _injected_save != null else _selected_runtime_save()


## Mirrors the active save's party size and Pokerus state onto the world so a
## queued script can answer VAR_PARTYCOUNT and CheckPokerus without the
## scene-free world owning a save. Cleared, not zeroed, when no save is
## selected, so a missing wiring fails loudly instead of reading an invented
## empty party.
func _refresh_party_summary() -> void:
	if _world == null:
		return
	var save: Gen2SaveData = _active_party_save()
	if save == null:
		_world.clear_party_summary()
		_world.clear_player_id()
		_world.set_player_name("")
		return
	## wPlayerID rides the same refresh: it belongs to the save, and
	## GetTreeScore reads it the way VAR_PARTYCOUNT reads the party mirror.
	_world.set_player_id(save.player_id)
	_world.set_player_name(save.player_name)
	_world.set_player_gender(save.gender == Gen2SaveData.GENDER_FEMALE)
	_refresh_link_transport(save)
	var has_pokerus: bool = false
	var species: Array[int] = []
	var moves: Array = []
	var names: Array = []
	var eggs: Array = []
	var fainted: Array = []
	var happiness: Array = []
	var own_ot: Array = []
	var held_items: Array = []
	var levels: Array = []
	var id_numbers: Array = []
	for member: Variant in save.party:
		if member is Gen2SaveMon:
			var mon: Gen2SaveMon = member as Gen2SaveMon
			if (int(mon.pokerus) & 0x0F) != 0:
				has_pokerus = true
			happiness.append(int(mon.happiness))
			own_ot.append(_is_own_mon(save, mon))
			held_items.append(int(mon.item))
			levels.append(int(mon.level))
			id_numbers.append(int(mon.ot_id))
			species.append(int(mon.species))
			# CheckPartyMove walks every slot's four move slots; zeroes are empty
			# slots, not moves, so they are dropped rather than searched.
			var mon_moves: Array = []
			for move: int in mon.moves:
				if move != 0:
					mon_moves.append(move)
			moves.append(mon_moves)
			names.append(_mon_display_name(mon))
			eggs.append(mon.is_egg)
			fainted.append(mon.hp <= 0)
	## The three party facts the Bug Contest's own scripts ask about, which are
	## not per-slot: whether the lead can be entered at all, the byte
	## `ContestDropOffMons` stashes, and whether what is caught can be taken home.
	var lead: Gen2SaveMon = save.party[0] if not save.party.is_empty() else null
	var second: Gen2SaveMon = save.party[1] if save.party.size() > 1 else null
	_world.set_party_summary(
		save.party.size(), has_pokerus, species, moves, names, eggs,
		{
			"lead_fainted": lead == null or lead.hp <= 0,
			"second_species": int(second.species) if second != null else 0,
			"storage_full": save.party.size() >= Gen2SaveData.MAX_PARTY \
				and not bool(save.deposit_box_slot().get("ok", false)),
			## `VAR_BOXSPACE`, which Route 29's catching tutorial reads before it
			## offers to hand a POKé BALL over.
			"box_free_space": save.box_free_space(),
			## Per slot, for the two specials that read a happiness byte or an
			## OT: `GetFirstPokemonHappiness` and
			## `FindPartyMonThatSpeciesYourTrainerID`.
			"happiness": happiness,
			"own_ot": own_ot,
			## `CheckOwnMonAnywhere`'s answer for every species at once: a mon in
			## the party or in any box carrying the player's own ID and OT name.
			"owned_species": _owned_species(save),
			## `OmanyteChamber` walks MON_ITEM backwards for a WATER STONE, which
			## is the one routine that reads a held item off the mirror.
			"held_items": held_items,
			## `BattleTower_LevelCheck` walks MON_LEVEL against the level group
			## the player chose, and `BattleTower_UbersCheck` walks it beside
			## the species list.
			"levels": levels,
			## `CheckForLuckyNumberWinners` compares the show's number against
			## every ID in the party and then against every one in storage, so
			## the boxes come over as one list the way its three passes add up.
			"id_numbers": id_numbers,
			"stored_id_numbers": _stored_id_numbers(save),
			"stored_species": _stored_species(save),
		},
		fainted
	)


## `CheckOwnMon`'s three tests: the species is the caller's question, and what is
## left is the player's own ID and OT name.
func _is_own_mon(save: Gen2SaveData, mon: Gen2SaveMon) -> bool:
	return int(mon.ot_id) == int(save.player_id) \
		and mon.original_trainer == save.player_name


## Every box slot's OT ID and species, in box then slot order. One list rather
## than fourteen because `CheckForLuckyNumberWinners` walks the open box and
## then every other box, which is every stored row exactly once.
func _stored_id_numbers(save: Gen2SaveData) -> Array:
	var out: Array = []
	for box: Variant in save.boxes:
		if not box is Gen2SaveBox:
			continue
		for slot: Variant in (box as Gen2SaveBox).slots:
			if slot is Gen2SaveMon:
				out.append(int((slot as Gen2SaveMon).ot_id))
	return out


func _stored_species(save: Gen2SaveData) -> Array:
	var out: Array = []
	for box: Variant in save.boxes:
		if not box is Gen2SaveBox:
			continue
		for slot: Variant in (box as Gen2SaveBox).slots:
			if slot is Gen2SaveMon:
				var stored: Gen2SaveMon = slot as Gen2SaveMon
				out.append(
					Gen2WorldScriptRunner.SPECIES_EGG if stored.is_egg else int(stored.species)
				)
	return out


## `CheckOwnMonAnywhere` for every species in one walk. Its own `ret z` on an
## empty party is why an empty party owns nothing even when a box does not, and
## the Day-Care is deliberately not walked: `docs/bugs_and_glitches.md` records
## that omission as the cartridge's.
func _owned_species(save: Gen2SaveData) -> Array:
	var owned: Array = []
	if save.party.is_empty():
		return owned
	var seen: Dictionary = {}
	for member: Variant in save.party:
		if member is Gen2SaveMon and _is_own_mon(save, member as Gen2SaveMon):
			seen[int((member as Gen2SaveMon).species)] = true
	for box: Variant in save.boxes:
		if not box is Gen2SaveBox:
			continue
		for slot: Variant in (box as Gen2SaveBox).slots:
			if slot is Gen2SaveMon and _is_own_mon(save, slot as Gen2SaveMon):
				seen[int((slot as Gen2SaveMon).species)] = true
	for key: Variant in seen:
		owned.append(int(key))
	owned.sort()
	return owned


## GetPartyNickname's answer for one slot, following the party screen's own rule:
## the stored nickname, or the species name when the save carries none.
func _mon_display_name(mon: Gen2SaveMon) -> String:
	if not mon.nickname.is_empty():
		return mon.nickname
	return String(_data.species(mon.species).get("name", "")) if _data != null else ""


func _refresh_labels() -> void:
	if _world == null or _data == null:
		return
	_refresh_party_summary()
	var caption: String = "%s   map %d/%d   cell %d,%d" % [
		_data.title(), _world.current_map.group, _world.current_map.number,
		_world.player_cell.x, _world.player_cell.y,
	]
	var ring: Dictionary = _world.pending_phone_ring()
	if _world.phone_ring_active() and not ring.is_empty():
		caption += "   PHONE RING %d/%d: %s" % [
			int(ring.get("ring", 0)), int(ring.get("rings", 0)),
			_phone_contact_label(ring.get("contact", {})),
		]
	_set_caption(caption)
	var rods: Array[StringName] = _world.available_fishing_rods()
	var rod_labels: Array[String] = []
	for rod: StringName in rods:
		rod_labels.append(Gen2WorldFishing.rod_label(rod))
	var owned: String = ", ".join(rod_labels) if not rod_labels.is_empty() else "none"
	var ball_labels: Array[String] = []
	if _world != null and _world.state != null:
		for ball: int in Gen2WorldPartyHost.owned_capture_balls(_world):
			ball_labels.append("%s x%d" % [_data.item_name(ball), _world.state.item_quantity(ball)])
	var balls: String = ", ".join(ball_labels) if not ball_labels.is_empty() else "none"
	var clock_text: String = "%02d:%02d" % [_clock.hour, _clock.minute] if _clock != null else "--:--"
	_hint.text = "the d-pad moves one 16px cell    raw collision %02X" % [
		_world.collision_code_at(_world.player_cell),
	]
	_hint.text += "    time %s    rods: %s    balls: %s    P: phone    F5: save" % [clock_text, owned, balls]
	var host: Gen2ModHost = Gen2ModHost.instance()
	if host.world_renderer_ids().size() > 1:
		_hint.text += "    V: view (%s)" % host.world_renderer_label(host.selected_world_renderer())
	var services: Dictionary = _data.world_service_counts()
	_hint.text += "    services menus %d marts %d phone %d music %d sfx %d cries %d" % [
		int(services.get("menus", 0)), int(services.get("marts", 0)),
		int(services.get("phone_contacts", 0)), int(services.get("music", 0)),
		int(services.get("sfx", 0)), int(services.get("cries", 0)),
	]
	if not rods.is_empty():
		_hint.text += "    1-%d: select    F: fish" % rods.size()
	if not _script_prompt.is_empty():
		_hint.text += "    " + _script_prompt


## `HangUp`'s own three writes, driven off the counted wait `hangup` staged: the
## click, the `……` and the empty box `HangUp_BoopOff` redraws, twenty frames
## each. Nothing here waits for a button, so the box is written rather than
## opened as a page.
func _draw_hang_up() -> void:
	var wait: Dictionary = _world.pending_script_wait()
	if not bool(wait.get("hang_up", false)) or _data == null \
		or _text_box == null or _text_box.font == null:
		return
	var total: int = int(wait.get("frames", 0))
	var remaining: int = _world.script_wait_remaining()
	var elapsed: int = 0 if remaining < 0 else total - remaining
	var phase: StringName = Gen2WorldPhoneRing.hang_up_phase(elapsed)
	if phase == _hang_up_phase:
		return
	_hang_up_phase = phase
	var metadata: Dictionary = _data.world_phone_metadata()
	var line: String = ""
	if phase == &"click":
		line = String(metadata.get("hang_up_click", ""))
		_play_sfx(SFX_HANG_UP)
	elif phase == &"ellipse":
		line = String(metadata.get("hang_up_ellipse", ""))
	_text_box.visible = true
	_text_box.show_text(line, false)


func _phone_contact_label(contact: Dictionary) -> String:
	if contact.is_empty():
		return "UNKNOWN CALLER"
	var caller_label: String = String(contact.get("caller_label", ""))
	if not caller_label.is_empty():
		return caller_label
	var trainer_class: int = int(contact.get("trainer_class", 0))
	if trainer_class > 0 and _data != null:
		var trainer_name: String = _data.trainer_name(trainer_class)
		if not trainer_name.is_empty():
			return "%s %d" % [trainer_name, int(contact.get("trainer_number", 0))]
	return "CONTACT %d" % int(contact.get("index", -1))


func _selected_runtime_data() -> GameData:
	return Gen2GameRuntime.data_or_any()


func _selected_runtime_save() -> Gen2SaveData:
	return Gen2GameRuntime.selected_save_or_null()
