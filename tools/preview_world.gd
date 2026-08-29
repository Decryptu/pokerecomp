extends SceneTree

## Renders one imported map's expanded 4x4-tile blocks to a PNG, or photographs
## the real screen on that map. `live help` prints [constant KIND_HELP], which is
## every kind and what its two numbers mean.
##
##   Godot --headless --path . -s res://tools/preview_world.gd -- gold 1 1 /tmp/w.png
##   Godot --path . -s res://tools/preview_world.gd -- crystal 26 2 /tmp/out.png \
##       live [kind] [x y] [WxH] [touch] [framed] [zoom=<n>] [view=<mod id>]

## Every `live` kind, what its two numbers mean and what it draws. Data rather
## than a comment, because `live help` prints it. A kind may also be any
## `preview_*` driver on the world screen without that prefix, which is driven
## twice when its name ends in `_use`, or one of [constant FIELD_ITEMS]' names,
## which is the pack's USE on that item.
const KIND_HELP: Dictionary = {
	&"effects": "cell: the emote, boulder dust, grass rustle and headbutt tree over the first visible object",
	&"battle": "cell: the wild fight preview_battle_request starts, settled past its transition",
	&"catch_tutorial": "frames: the Dude's own fight, which answers itself, that many frames in",
	&"cut": "cell: OWCutAnimation's two halves and the jump shadow",
	&"tile_anim": "frames: the map that many AnimateTileset frames in",
	&"unown_wall": "cell: DisplayUnownWords' box. Group 3 maps 23 to 26 say HO-OH, ESCAPE, WATER, LIGHT",
	&"mart": "cell in front of the counter: BuyMenu",
	&"mart_sell": "cell in front of the counter: the SELL row (DepositSellPack)",
	&"pokepic": "cell: Script_pokepic's box over the map, holding Chikorita",
	&"pet_actor": "cell: a mod's world actor one cell ahead, pressed with A so it wears a showemote heart",
	&"warp": "warp tile: MapSetupScript_Door at its whitest, the frame the new map loads on",
	&"script_fade": "special, frames: one of the five fade specials over the map",
	&"door": "door mat: .CheckWarp's carpet, standing on an interior door's mat",
	&"ice_slide": "direction, frames: DoPlayerMovement.CheckForced's run. Direction is down, up, left, right",
	&"ledge": "start cell: the ledge hop at the top of its arc, walking south until one allows it",
	&"map_name_sign": "cell: InitMapNameSign's window, raised by walking west onto the neighbouring map",
	&"yes_no": "script, presses: Script_yesorno's box over the map's script",
	&"battle_tower": "A presses, DOWN presses: BattleTower1FReceptionistScript, talked to from the cell below her",
	&"name_rater": "presses: special NameRater. 0 is the introduction, 2 the last page with YES/NO, 4 the party list",
	&"move_deleter": "presses: special MoveDeletion, the same three stages",
	&"gift_nickname": "presses, species: GiveANickname_YesNo. 1 the question, 2 the WasSentToBillsPCText behind NO; add 1000 for the box branch",
	&"unown_printer": "slot, page: _UnownPrinter's browser. Slot 26 is the vacant one; page 1 is what A sends to a printer that is not there",
	&"diploma": "loop, page: _Diploma's page. 1 stands _PrintDiploma's connection error over it; page 2 needs a printer that answered",
	&"bills_pc": "rows down, A presses: _BillsPC's top menu and the lists behind it",
	&"players_pc": "rows down, A presses: the bedroom's item PC",
	&"pokemon_center_pc": "rows down, A presses: the Pokemon Center's machine",
	&"mom_bank": "wallet, balance, both in hundreds: Mom_WithdrawDepositMenuJoypad's dial. Add 1000 for the WITHDRAW header",
	&"move_tutor": "presses: special MoveTutor. 0 is ChooseMonToLearnTMHM's list, not a box",
	&"day_care": "presses, routine: 0 the man, 1 the lady, 2 the man outside, 3 and 4 the two signs",
	&"slot_machine": "frames, bet: special SlotMachine. Bet is 1 to 3, plus 4 for the lucky machine",
	&"card_flip": "frames, coins in hundreds: special CardFlip",
	&"unown_puzzle": "frames, picture: special UnownPuzzle. 0 Kabuto, 1 Omanyte, 2 Aerodactyl, 3 Ho-Oh, 4 to 7 solved",
	&"visible_encounter": "cell: a shiny of the map's own table on the eligible cell nearest the player",
	&"visible_encounter_glow": "cell: the same population with ordinary DVs wearing an entry's glow",
	&"field_moves_menu": "cell: the start menu's MOVES row and the HM list. Needs a registered field-move source",
	&"repel_renewal": "cell: the question a Repel running out asks. Needs a registered renewal provider",
	&"mod_notice": "badge: Gen2ModHost.request_notice's banner over the map, wearing that badge",
	&"mod_page": "badges won: START_ACTION_OPEN_MOD_PAGE's screen, listing the eight Johto badges",
	&"reset_question": "none: the reset chord's own question, asked once ever. Driven twice",
	&"launcher_question": "none: the HOME row's question, walked to off the list. Driven twice",
}


## `TrainerCard_JohtoBadgesOAM`'s eight, for the two mod-surface kinds: the only
## badge art the cartridge has.
const BADGE_NAMES: Array[String] = [
	"ZEPHYRBADGE", "HIVEBADGE", "PLAINBADGE", "FOGBADGE",
	"MINERALBADGE", "STORMBADGE", "GLACIERBADGE", "RISINGBADGE",
]

## `.forced_dpad`'s own order, which the first number indexes.
const ICE_SLIDE_BUTTONS: Array[int] = [
	Gen2Button.DOWN, Gen2Button.UP, Gen2Button.LEFT, Gen2Button.RIGHT,
]

const WINDOW_SIZE := Vector2i(1152, 648)
## What the live mode actually opens in, which a phone-shaped argument replaces.
var _window: Vector2i = WINDOW_SIZE
## The renderer to photograph, empty for whichever one the installation last
## chose. Restored after the capture so a preview never changes that choice.
var _view: StringName = &""
## `bare`: the debug readout off, so the capture is the screen and nothing else.
var _bare: bool = false
## `hour=<n>`: the clock the map is drawn on, since an outdoor map's palette is
## `wTimeOfDay`'s and a capture diffed against a cartridge frame has to be on
## the same one. -1 leaves the scene's own.
var _hour: int = -1
var _restore_view: StringName = &""
## Longer than a step onto a warp tile and the fade behind it, for the `warp`
## kind, which drives to a frame rather than spending a count.
const WARP_FRAME_CAP: int = 120
## How long one of the two routines' boxes may take to finish printing, which is
## a text speed rather than a count this file knows.
const MON_SPECIAL_FRAME_CAP: int = 600
## The Day-Care's five routines, in the order the second number picks them.
const DAY_CARE_ROLES: Array[StringName] = [
	&"man", &"lady", &"outside", &"mon1", &"mon2",
]


## `UpdateJumpPosition`'s highest `.y_offsets` entry, which is where the `ledge`
## kind photographs the hop.
const LEDGE_ARC_TOP: float = 12.0
## The `kind`s that are a pack USE rather than a staged sprite, and the item
## each one uses. Every one of them is driven through the pack's own key item
## pocket, so the picture is the screen's answer and not a staged state.
const FIELD_ITEMS: Dictionary = {
	&"field_item": Gen2WorldPack.ITEM_ITEMFINDER,
	&"bike": Gen2WorldPack.ITEM_BICYCLE,
	&"coin_case": Gen2WorldPack.ITEM_COIN_CASE,
	&"squirtbottle": Gen2WorldPack.ITEM_SQUIRTBOTTLE,
	&"card_key": Gen2WorldPack.ITEM_CARD_KEY,
	&"basement_key": Gen2WorldPack.ITEM_BASEMENT_KEY,
}

## The three whose effect reads what the player is facing. Each is photographed
## from the cell below its own target, so one press turns without moving: the
## tree, the slot and the door all block their own cell.
const FACE_UP_FIRST: Array[StringName] = [
	&"squirtbottle", &"card_key", &"basement_key",
]

## `ElmsLabScript`'s left ball, which is the first `pokepic` a new game shows.
const POKEPIC_SPECIES: int = 152

## How a `kind` names one of [Gen2WorldScreen]'s own screenshot drivers, so
## every `preview_*` on it is reachable from here rather than from nothing.
const SCREEN_DRIVER: String = "preview_%s"

## The clerk's own text box, which is the one press between `pokemart` and the
## welcome the buy screen opens on. One more reaches the list, two the quantity
## dial and three the yes/no.
const MART_PRESSES: int = 1
## Frames spent between two presses of a driven menu, so the box a press opened
## owes nothing before the next one lands: nothing shortens a printing text.
const TEXT_SETTLE_FRAMES: int = 20

## Hardware frames spent after the sprites are staged. Two puts the grass rustle on
## its first facing and the boulder dust on its second, so every one is up and none
## is on the frame it was spawned. Two kinds are a moment inside an animation
## instead: Cut's tree stands three frames before it splits, and the waterfall
## climb runs four passes a cell, so 26 lands a few cells up.
const STAGED_FRAMES: int = 2
const STAGED_FRAMES_BY_KIND: Dictionary = {&"cut": 12, &"waterfall_use": 26}

var _screen: Gen2WorldScreen = null
var _output_path: String = ""
var _frames: int = 0
var _kind: StringName = &"effects"
## The two numbers after the kind. Most kinds read them as the cell the player
## stands on; a few read them as their own arguments.
var _cell := Vector2i(-1, -1)
## `<kind>@x,y`: the cell for a kind whose own two numbers are not one, which is
## `battle_transition`. `battle_transition@5,7` photographs the animation with
## the player standing on that cell, which is how the grass over a sprite's legs
## is photographed with the transition already written over it.
var _kind_cell := Vector2i(-1, -1)


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 4:
		push_error("Usage: preview_world.gd -- <game> <group> <map> <output.png> [live]")
		quit(1)
		return

	if Gen2ToolPath.refuses(args[3]):
		quit(2)
		return

	var data: GameData = GameData.open(StringName(args[0]))
	if args.size() >= 5 and args[4] == "live":
		if data == null:
			push_error("No cache for %s. Import roms/%s.gbc first." % [args[0], args[0]])
			quit(1)
			return
		_output_path = args[3]
		if not _read_live_options(args):
			return
		_build_live(
			data, int(args[1]), int(args[2]),
			Vector2i(int(args[6]), int(args[7])) if args.size() >= 8 else Vector2i(-1, -1),
		)
		return
	var map: Gen2WorldMap = data.world_map(int(args[1]), int(args[2])) if data != null else null
	var tileset: Gen2WorldTileset = data.world_tileset(map.tileset) if map != null else null
	if data == null or map == null or tileset == null:
		push_error("The requested imported map is not available.")
		quit(1)
		return

	var image: Image = _render(data, map, tileset)
	var error: int = image.save_png(args[3])
	if error != OK:
		push_error("Could not write %s (error %d)." % [args[3], error])
		quit(1)
		return

	print("Wrote %s (%dx%d), tileset %d, %d warps, %d objects." % [
		args[3], image.get_width(), image.get_height(), map.tileset,
		(map.events.get("warps", []) as Array).size(),
		(map.events.get("objects", []) as Array).size(),
	])
	quit(0)


func _read_live_options(args: PackedStringArray) -> bool:
	var kind_arg: String = args[5] if args.size() >= 6 else "effects"
	if kind_arg == "help":
		for kind: StringName in KIND_HELP:
			print("%-24s %s" % [kind, KIND_HELP[kind]])
		quit(0)
		return false
	if kind_arg.contains("@"):
		var halves: PackedStringArray = kind_arg.split("@")
		kind_arg = halves[0]
		var at: PackedStringArray = halves[1].split(",")
		if at.size() == 2:
			_kind_cell = Vector2i(int(at[0]), int(at[1]))
	_kind = StringName(kind_arg)
	if args.size() >= 9:
		var shape: PackedStringArray = args[8].split("x")
		if shape.size() == 2:
			_window = Vector2i(int(shape[0]), int(shape[1]))
	for extra: String in args.slice(9):
		if extra == "touch":
			var options: Gen2Options = Gen2OptionsStore.current()
			options.touch_mode = Gen2Options.TOUCH_ALWAYS
			Gen2InputRuntime.instance().apply_options(options)
		elif extra == "framed":
			Gen2OptionsStore.current().screen_fill = false
		elif extra.begins_with("zoom="):
			Gen2OptionsStore.current().zoom_step = int(extra.trim_prefix("zoom="))
		elif extra.begins_with("view="):
			_view = StringName(extra.trim_prefix("view="))
		elif extra == "bare":
			_bare = true
		elif extra.begins_with("hour="):
			_hour = int(extra.trim_prefix("hour="))
	return true


## The production screen on a real map, with every effect sprite running at
## once. Each is started through the same call the game makes, so what is
## photographed is the renderer's own path rather than a drawing of it.
func _build_live(data: GameData, group: int, number: int, cell: Vector2i) -> void:
	DisplayServer.window_set_size(_window)
	root.set_content_scale_size(_window)
	root.size = _window
	var packed: PackedScene = load("res://game/world/world_screen.tscn")
	_screen = packed.instantiate() as Gen2WorldScreen
	_screen.map_group = group
	_screen.map_number = number
	if _hour >= 0:
		_screen.hour = _hour
	_cell = cell
	## The transition reads them as a frame count and a branch rather than as a
	## cell, so the player is left where the map puts them.
	if _kind_cell.x >= 0:
		_screen.start_cell = _kind_cell
	elif cell.x >= 0 and _kind not in [
		&"battle_transition", &"level_evolution", &"egg_hatch", &"name_rater",
		&"move_deleter", &"move_tutor", &"day_care", &"unown_puzzle", &"slot_machine",
		&"card_flip", &"tile_anim", &"ice_slide", &"whiteout", &"gift_nickname",
	]:
		_screen.start_cell = cell
	## Pinned so two captures of the same map are the same picture: the seed the
	## screen resolves is what a wandering NPC's own generator is built from.
	_screen.encounter_seed = 1
	_screen.set_data(data)
	root.add_child(_screen)
	current_scene = _screen
	## The screen counts hardware frames off wall-clock delta, so a capture that
	## let it run would photograph a different frame of each animation every
	## time. It owns none of them here: the staged frames below are spent by
	## hand.
	_screen.set_process(false)


## Spends whatever one of the two routines' boxes still owes, plus the frame
## `advance_frame` reads it on: `PrintText` returning is what opens a `YesNoBox`.
## Three legal entrants at the level the room list opens on, so the driven
## receptionist reaches the level menu rather than the rules refusal.
func _stage_battle_tower_party() -> void:
	var save: Gen2SaveData = _screen.active_save()
	if save == null:
		save = Gen2SaveStore.create_development_save(_screen._data, 0)
		_screen.set_save(save)
	save.party = []
	for slot: int in Gen2BattleTower.PARTY_LENGTH:
		var mon: Gen2SaveMon = Gen2SaveBattleAdapter.from_battle_mon(
			Gen2BattleMon.create(_screen._data, 155 + slot * 3, 10, [33])
		)
		save.party.append(mon)
	_screen._refresh_party_summary()


func _settle_mon_special(host_property: String) -> void:
	for _frame: int in MON_SPECIAL_FRAME_CAP:
		var routine: Control = _screen.get(host_property)
		## The routine's last box is handed back to the map, which reveals it on
		## its own clock, so a closed host still owes the frames its ending text
		## is printing. Photographing on the frame the host went away shows an
		## empty box.
		var box: Gen2TextBox = routine.get("_text_box") if routine != null \
			else _screen.get("_text_box") as Gen2TextBox
		if box == null or not box.is_revealing():
			break
		_screen.advance_frame()
	_screen.advance_frame()


## The kinds that drove themselves to the frame they want. Every other kind
## stages a sprite and then spends the frames it needs.
const SELF_DRIVEN_KINDS: Array[StringName] = [
	&"warp", &"door", &"map_name_sign", &"ledge", &"heal_machine",
	&"battle", &"battle_transition", &"level_evolution", &"egg_hatch",
	&"catch_tutorial",
	&"name_rater", &"move_deleter", &"move_tutor", &"day_care",
	&"ice_slide", &"whiteout", &"view_cover", &"gift_nickname",
	&"catch_nickname", &"mom_bank", &"bills_pc", &"players_pc",
	&"pokemon_center_pc", &"start_menu", &"mod_notice", &"mod_page",
	&"reset_question", &"launcher_question",
]


## What stages each preview kind, as the driver that stages it. A kind the table
## does not name is a field item, one of the screen's own `preview_*` drivers, or
## an overworld effect sprite, in that order.
const STAGERS: Dictionary = {
	&"unown_wall": &"_stage_unown_wall",
	&"battle": &"_stage_battle",
	&"catch_tutorial": &"_stage_catch_tutorial",
	&"battle_transition": &"_stage_battle_transition",
	&"script_fade": &"_stage_script_fade",
	&"level_evolution": &"_stage_level_evolution",
	&"egg_hatch": &"_stage_egg_hatch",
	&"gift_nickname": &"_stage_gift_nickname",
	&"whiteout": &"_stage_whiteout",
	&"unown_puzzle": &"_stage_unown_puzzle",
	&"slot_machine": &"_stage_slot_machine",
	&"tile_anim": &"_stage_tile_anim",
	&"card_flip": &"_stage_card_flip",
	&"day_care": &"_stage_day_care",
	&"name_rater": &"_stage_party_routine",
	&"move_deleter": &"_stage_party_routine",
	&"move_tutor": &"_stage_party_routine",
	&"battle_tower": &"_stage_battle_tower",
	&"yes_no": &"_stage_yes_no",
	&"mart": &"_stage_mart",
	&"mart_sell": &"_stage_mart",
	&"elevator": &"_stage_elevator",
	&"warp": &"_stage_warp",
	&"door": &"_stage_door",
	&"ledge": &"_stage_ledge",
	&"ice_slide": &"_stage_ice_slide",
	&"map_name_sign": &"_stage_map_name_sign",
	&"mod_notice": &"_stage_mod_notice",
	&"mod_page": &"_stage_mod_page",
	&"pokepic": &"_stage_pokepic",
	&"unown_printer": &"_stage_unown_printer",
	&"diploma": &"_stage_diploma",
	&"start_menu": &"_stage_start_menu",
	&"bills_pc": &"_stage_pc",
	&"players_pc": &"_stage_pc",
	&"mailbox": &"_stage_pc",
	&"pokemon_center_pc": &"_stage_pc",
	&"mom_bank": &"_stage_mom_bank",
}


## Puts the screen in the state the picture wants. Called once, on the frame the
## screen is ready.
func _stage_kind() -> void:
	if STAGERS.has(_kind):
		call(STAGERS[_kind])
		return
	if FIELD_ITEMS.has(_kind):
		if _kind in FACE_UP_FIRST:
			_screen.move_up()
		_screen.preview_field_item(int(FIELD_ITEMS[_kind]))
		return
	if _screen.has_method(SCREEN_DRIVER % _kind):
		## The screen's own `preview_*` drivers, by their name without the
		## prefix. A `*_use` driver is one step per call, so it is called
		## twice: the first opens the menu and the second answers it.
		_screen.call(SCREEN_DRIVER % _kind)
		if String(_kind).ends_with("_use") or String(_kind).ends_with("_question"):
			_screen.call(SCREEN_DRIVER % _kind)
		return
	if not _bare:
		_screen.preview_effect_sprites(_kind)


func _process(_delta: float) -> bool:
	if _screen == null:
		return false
	_frames += 1
	## Again, and after the screen is in the tree: a node whose script defines
	## `_process` has its processing turned back on when it is made ready, so the
	## call in [method _build_live] alone leaves the screen spending frames of
	## its own beside the ones staged below.
	_screen.set_process(false)
	if _frames == 1:
		_choose_view()
	if _frames == 2:
		_stage_kind()
		if not _bare and _kind not in SELF_DRIVEN_KINDS:
			for _frame: int in int(STAGED_FRAMES_BY_KIND.get(_kind, STAGED_FRAMES)):
				_screen.advance_frame()
	if _frames < 18:
		return false
	## The map and cell readout and the shortcut legend are scaffolding drawn
	## over the screen, so a capture meant for a pixel diff against a cartridge
	## frame has to be taken without them.
	if _bare:
		_screen.hide_debug_readout()
	var image: Image = Gen2ToolPath.capture(root)
	if image == null:
		quit(1)
		return true
	var error: Error = image.save_png(_output_path)
	if error != OK:
		push_error("Could not write %s (error %d)" % [_output_path, error])
		quit(1)
		return true
	print("Wrote %s (%dx%d)" % [_output_path, image.get_width(), image.get_height()])
	_restore_selected_view()
	quit(0)
	return true


## The chamber's own `bg_event ..., BGEVENT_UP`: face the wall from the cell below it
## and read it, which is the only way in.
func _stage_unown_wall() -> void:
	_screen.move_up()
	_screen.interact()
	## `writetext` is one page: the first press finishes the reveal the
	## text speed is still spending, and the second ends the page, which
	## is what runs `special DisplayUnownWords` and puts the box up.
	_screen.press_button(Gen2Button.A)
	_screen.press_button(Gen2Button.A)


## Past the transition and into the fight it opens, which is the one picture a battle
## renderer staged on the map draws.
func _stage_battle() -> void:
	_screen.preview_battle_request()
	_screen.settle_battle_transition()
	_screen.advance_frames(STAGED_FRAMES)


## `CatchTutorial`, played by `DudeAutoInputs` rather than by anybody. The first
## number is how many frames in to photograph: nothing here presses anything.
func _stage_catch_tutorial() -> void:
	_screen.preview_catch_tutorial()
	_screen.settle_battle_transition()
	_screen.advance_frames(maxi(_cell.x, STAGED_FRAMES))


## `DoBattleTransition` over the map it runs on. The first of the two numbers is how
## many frames into it to photograph rather than a cell, since a transition is two
## hundred of them and every one is a different picture; the second is 1 for a
## trainer's, which is the branch that draws the Poke Ball and floods the map.
func _stage_battle_transition() -> void:
	_screen.preview_battle_transition(_cell.x, _cell.y != 0)


## One of the five fade specials over the map it runs on. The first number is the
## special (46 `FadeOutToWhite`, 47 `BattleTowerFade`, 48 `FadeOutToBlack`, 49
## `FadeInFromWhite`, 50 `FadeInFromBlack`) and the second how many of its frames to
## spend before the picture, since each of the four rows is a different screen.
func _stage_script_fade() -> void:
	_screen.preview_script_fade(maxi(_cell.x, 0))
	for _frame: int in maxi(_cell.y, 0):
		_screen.advance_frame()


## `EvolveAfterBattle`'s own screen, which is a few hundred frames of picture. The
## first number is how far into it to photograph rather than a cell, the way
## `battle_transition`'s is; the box is pressed past on the frames it is waiting on,
## since neither `PrintText` nor `DelayFrames` shortens for a screenshot.
func _stage_level_evolution() -> void:
	_screen.preview_level_evolution()
	for _frame: int in maxi(_cell.x, 0):
		_screen.advance_frame()
		var evolving: Gen2EvolutionScreen = _screen.get("_evolution_host")
		if evolving == null:
			break
		if evolving.awaiting_press():
			_screen.press_button(Gen2Button.A)


## `OverworldHatchEgg`, driven the same way and for the same reason: the sequence is
## five hundred frames of picture, so the first number is how far into it to
## photograph and the second is the species inside the egg, 0 for the first the cache
## holds.
func _stage_egg_hatch() -> void:
	_screen.preview_egg_hatch(maxi(_cell.y, 0))
	for _frame: int in maxi(_cell.x, 0):
		_screen.advance_frame()
		var hatching: Gen2EggHatchScreen = _screen.get("_hatch_host")
		if hatching == null:
			break
		if hatching.awaiting_press():
			_screen.press_button(Gen2Button.A)


## `GivePoke`'s own prompt. The presses are spent behind the frames the box owes,
## since nothing shortens a printing text; the second number's thousands digit is the
## box branch.
func _stage_gift_nickname() -> void:
	_screen.preview_gift_nickname(maxi(_cell.y, 0) % 1000, _cell.y >= 1000)
	_settle_mon_special("_nickname_host")
	for _press: int in maxi(_cell.x, 0):
		var prompt: Gen2NicknamePromptScreen = _screen.get("_nickname_host")
		if prompt == null:
			break
		## NO on the question, so the mode photographs the routine's own
		## boxes; the keyboard behind YES has `preview_naming_screen.gd`.
		_screen.press_button(
			Gen2Button.B if prompt.question_ready() else Gen2Button.A
		)
		_settle_mon_special("_nickname_host")


## `Script_Whiteout`, which no fixture cell reaches: the party is poisoned down to its
## last point and the pass `CountStep` owes is spent. The first number is how many of
## its presses to spend, so 0 is the faint line, 1 the first page of `_WhitedOutText`
## and 3 the map the player wakes up on.
func _stage_whiteout() -> void:
	_screen.preview_whiteout()
	## The box reveals a letter at a time at the OPTION menu's own speed,
	## so each press is given behind the frames its page costs.
	for _press: int in maxi(_cell.x, 0) + 1:
		for _frame: int in 120:
			_screen.advance_frame()
		if _press < maxi(_cell.x, 0):
			_screen.press_button(Gen2Button.A)


## `special UnownPuzzle`, which no fixture cell reaches. The first number is how many
## frames into the board to photograph and the second which picture: 0 Kabuto, 1
## Omanyte, 2 Aerodactyl, 3 Ho-Oh. The empty cursor blinks off `hVBlankCounter`, so a
## frame with bit 4 clear photographs a board with no cursor on it. 4 to 7 are the
## same four pictures with the board walked into `.SolvedPuzzleConfiguration` through
## the screen's own presses, which is the only way to photograph the assembled
## picture.
func _stage_unown_puzzle() -> void:
	_screen.preview_unown_puzzle(
		maxi(_cell.y, 0) % RomLayout.UNOWN_PUZZLE_PICTURES.size(),
		maxi(_cell.y, 0) >= RomLayout.UNOWN_PUZZLE_PICTURES.size()
	)
	for _frame: int in maxi(_cell.x, 0):
		if _screen.get("_unown_puzzle_host") == null:
			break
		_screen.advance_frame()


## `special SlotMachine`, which no fixture cell reaches either. The first number is
## how many frames into the game to photograph and the second is the bet, 1 to 3, plus
## 4 for the lucky machine the Game Corner's own `random 6` picks one time in six.
func _stage_slot_machine() -> void:
	var slots_bet: int = maxi(_cell.y, 0) % 4
	_screen.preview_slot_machine(
		100, maxi(_cell.y, 0) >= 4, maxi(slots_bet, 1), maxi(_cell.x, 0)
	)


## `AnimateTileset` runs once a hardware frame, so any frame of a map's own water,
## flowers, lava or cave scroll is reachable by spending them: the first number is how
## many, and the cell goes in `tile_anim@x,y` as usual.
func _stage_tile_anim() -> void:
	for _spent: int in maxi(_cell.x, 0):
		_screen.advance_frame()


## `special CardFlip`, which no fixture cell reaches either. The first number is how
## many frames into the game to photograph and the second the balance in hundreds of
## coins, 0 meaning 100.
func _stage_card_flip() -> void:
	_screen.preview_card_flip(
		maxi(_cell.y, 0) * 100 if _cell.y > 0 else 100, maxi(_cell.x, 0)
	)


## The Day-Care's five, driven the way the two above are. The first number is how many
## presses into the routine to photograph and the second is which routine: 0 the man,
## 1 the lady, 2 the man outside, 3 and 4 the two signs.
func _stage_day_care() -> void:
	_screen.preview_day_care(DAY_CARE_ROLES[clampi(
		_cell.y, 0, DAY_CARE_ROLES.size() - 1
	)])
	_settle_mon_special("_day_care_host")
	for _press: int in maxi(_cell.x, 0):
		if _screen.get("_day_care_host") == null:
			break
		_screen.press_button(Gen2Button.A)
		_settle_mon_special("_day_care_host")


## `special NameRater` and `special MoveDeletion`, neither of which any fixture cell
## reaches. The first number is how many presses into the routine to photograph: 2 is
## the introduction's last page with its YES/NO up, 4 the party list, and so on.
## Presses are spent only once the box owes no frames, since nothing shortens a
## printing text.
func _stage_party_routine() -> void:
	_screen.call(SCREEN_DRIVER % _kind)
	var host_property: String = "_%s_host" % _kind
	_settle_mon_special(host_property)
	for _press: int in maxi(_cell.x, 0):
		if _screen.get(host_property) == null:
			break
		_screen.press_button(Gen2Button.A)
		_settle_mon_special(host_property)


## `BattleTower1FReceptionistScript` from the cell below her, which is where
## `Script_WalkToBattleTowerElevator` puts the player back. The first number is how
## many A presses to spend, walking the welcome box, the explanation question and the
## three-row menu; the second is how many DOWN presses on whichever menu is up.
## `_CheckForBattleTowerRules` refuses anything but three different species holding
## three different items, and the development save's party is not one.
func _stage_battle_tower() -> void:
	_stage_battle_tower_party()
	_screen.press_button(Gen2Button.UP)
	_screen.interact()
	for _frame: int in TEXT_SETTLE_FRAMES:
		_screen.advance_frame()
	for _press: int in maxi(_cell.x, 0):
		_screen.press_button(Gen2Button.A)
		for _frame: int in TEXT_SETTLE_FRAMES:
			_screen.advance_frame()
	for _press: int in maxi(_cell.y, 0):
		_screen.press_button(Gen2Button.DOWN)
		for _frame: int in TEXT_SETTLE_FRAMES:
			_screen.advance_frame()


## `Script_yesorno`'s own box: the NPC beside the player is talked to and each page
## answered until the choice the script ends on is up, which is what photographs
## `YesNoMenuHeader.MenuData`'s cursor. `crystal 26 3 ... yes_no 31 6` is
## Cherrygrove's guide.
func _stage_yes_no() -> void:
	_screen.press_button(Gen2Button.RIGHT)
	_screen.interact()
	for _press: int in WARP_FRAME_CAP:
		if StringName(_screen._world.pending_script_input().get(
			"command", &"")) == &"yesorno":
			break
		_screen.press_button(Gen2Button.A)
		for _frame: int in 20:
			_screen.advance_frame()


## The clerk behind the counter, talked to from the cell in front of him: his
## `pokemart` is what opens `BuyMenu`, so the shop is reached the way a player reaches
## it. The presses are the dialog's own, the welcome box first and then the list.
func _stage_mart() -> void:
	_screen.press_button(Gen2Button.LEFT)
	_screen.interact()
	for _press: int in MART_PRESSES:
		_screen.press_button(Gen2Button.A)
	## `StandardMart`'s BUY/SELL/QUIT loop is what the welcome box hands
	## the shop to. `mart` takes its BUY row, `mart_sell` the one below.
	if _kind == &"mart_sell":
		_screen.press_button(Gen2Button.DOWN)
	_screen.press_button(Gen2Button.A)


## The floor panel, read from the cell below it: `bg_event 3, 0`'s own `elevator` is
## what opens the floor list. The car has to know where it is standing first, which is
## what `warpmod` gives it, so the map's own script is left to run before the panel is
## read. The number is how many DOWN presses to spend on the list.
func _stage_elevator() -> void:
	var car: Gen2WorldAPI = _screen.get("_world")
	var door: Dictionary = (car.current_map.events.get("warps", []) as Array)[0]
	## `.FindCurrentFloor` matches the backup warp's map, which walking
	## into the car through its own -1 door is what writes. A preview
	## opens the map instead of walking to it, so the floor the door
	## names stands in for the one the player came from.
	car.backup_warp = {
		"warp": 1,
		"map_group": int(door["map_group"]),
		"map_number": int(door["map_number"]),
	}
	_screen.press_button(Gen2Button.UP)
	_screen.interact()
	for _press: int in maxi(_cell.x, 0):
		_screen.press_button(Gen2Button.DOWN)


## `MapSetupScript_Door` at its whitest: the step onto the warp tile and then
## `FadeOutToWhite`'s last order, which is the frame the map is loaded on.
func _stage_warp() -> void:
	for _frame: int in WARP_FRAME_CAP:
		## The first press turns, the second steps: the player is facing
		## the room rather than the stairs when the map opens.
		_screen.move_up()
		_screen.advance_frame()
		var fade: Dictionary = _screen.map_fade()
		if StringName(fade.get("stage", &"")) == &"out" \
			and int(fade.get("step", 0)) == Gen2WorldPalette.FADE_OUT_ORDERS.size() - 1:
			break


## `CheckDirectionalWarp`'s carpet: the step onto an interior door's mat lands and
## takes no warp, which is what this photographs. The press after it is `.CheckWarp`,
## and that is the one that warps.
func _stage_door() -> void:
	for _frame: int in WARP_FRAME_CAP:
		_screen.move_down()
		_screen.advance_frame()
		if Gen2WorldCollision.is_directional_warp(
			int(_screen.world_snapshot().get("collision", -1))
		):
			## player_cell commits when the step starts, so the frames
			## the player is still walking are spent before the picture.
			_screen.advance_frames(
				Gen2WorldAPI.passes_in_frames(Gen2WorldAPI.STEP_PASSES_WALK)
			)
			break


## `StepFunction_PlayerJump` at the top of its arc: the player is walked south until a
## cell allows the hop below it, and the picture is the frame `UpdateJumpPosition`
## draws highest (`crystal 24 4 ... ledge 5 4`).
func _stage_ledge() -> void:
	for _frame: int in WARP_FRAME_CAP:
		_screen.move_down()
		_screen.advance_frame()
		if _screen.player_height_offset_pixels() >= LEDGE_ARC_TOP:
			break


## `DoPlayerMovement.CheckForced`: one press starts the run and the frames after it
## are the slide's own, since nothing is held. The first number is the direction in
## `.forced_dpad` order, down, up, left, right, and the second how many frames to
## spend after the press; the cell goes in `ice_slide@x,y` (`crystal 3 61 ...
## ice_slide@11,29 3 40`).
func _stage_ice_slide() -> void:
	var slide_button: int = ICE_SLIDE_BUTTONS[posmod(maxi(_cell.x, 0), 4)]
	for _press: int in WARP_FRAME_CAP:
		if _screen.standing_on_ice():
			break
		_screen.press_button(slide_button)
		_screen.advance_frame()
	for _spent: int in maxi(_cell.y, 0):
		_screen.advance_frame()


## `MapSetupScript_Connection`'s `InitMapNameSign`: walked west off New Bark Town's
## edge onto Route 29, photographed while the sign the crossing raised is still up
## (`crystal 24 4 ... map_name_sign 0 6`). The camera and the tile animation both keep
## running behind it, which is the whole point of the row.
func _stage_map_name_sign() -> void:
	for _frame: int in WARP_FRAME_CAP:
		_screen.move_left()
		_screen.advance_frame()
		if _screen.map_name_sign_passes() > 0 \
			and _screen.map_name_sign_passes() < Gen2WorldAPI.MAP_NAME_SIGN_PASSES:
			break


## `Gen2ModHost.request_notice`'s banner, raised over the map the way
## `InitMapNameSign` raises the landmark one. The first number is which badge the icon
## shows.
func _stage_mod_notice() -> void:
	Gen2ModHost.instance().request_notice(&"preview", {
		"title": "BADGE WON",
		"line": BADGE_NAMES[clampi(_cell.x, 0, BADGE_NAMES.size() - 1)],
		"icon": {"badge": clampi(_cell.x, 0, 7)},
		"sound": &"none",
	})
	for _frame: int in WARP_FRAME_CAP:
		_screen.advance_frame()
		if _screen.map_name_sign_passes() > 0 \
			and _screen.map_name_sign_passes() < Gen2WorldAPI.MAP_NAME_SIGN_PASSES:
			break


## `START_ACTION_OPEN_MOD_PAGE`'s screen, with the eight Johto badges listed and the
## first number saying how many are won.
func _stage_mod_page() -> void:
	var won: int = clampi(_cell.x, 0, BADGE_NAMES.size())
	Gen2ModHost.instance().register_page(&"preview", {
		"title": "BADGES",
		"rows": func() -> Array:
			var rows: Array = []
			for badge: int in BADGE_NAMES.size():
				rows.append({
					"label": BADGE_NAMES[badge],
					"detail": "WON" if badge < won else "",
					"icon": {"badge": badge},
					"locked": badge >= won,
				})
			return rows,
	})
	_screen._open_mod_page(&"preview")
	_screen.advance_frame()


func _stage_pokepic() -> void:
	_screen.preview_pokepic(POKEPIC_SPECIES)


## `_UnownPrinter`'s browser: the first number is the slot, where 26 is the vacant
## one, and the second is 1 for the page A sends.
func _stage_unown_printer() -> void:
	_screen.preview_unown_printer(maxi(_cell.x, 0), _cell.y >= 1)


## `_Diploma`'s page, `_PrintDiploma`'s with the printer's own status box over it, and
## page 2 behind a printer that answered: the first number is 1 for the printing loop
## and the second the page.
func _stage_diploma() -> void:
	_screen.preview_diploma(_cell.x >= 1, maxi(_cell.y, 1))


## `SetUpMenuItems`' own gates opened, because the list worth photographing is the
## eight rows a finished save carries: they fill the box exactly, so the host's MODS
## row and any a mod registered are what the window has to be scrolled to. The first
## number is how many rows down to walk before the picture, and a second number of 1
## or more runs the Bug Catching Contest, which is the list `SetUpMenuItems` drops
## PACK from and puts QUIT in SAVE's slot.
func _stage_start_menu() -> void:
	if _cell.y >= 1:
		var contest_world: Gen2WorldAPI = _screen.get("_world")
		contest_world.state.set_engine_flag(Gen2WorldState.engine_flag(
			Gen2WorldState.ENGINE_BUG_CONTEST_TIMER,
			Gen2WorldState.is_crystal_profile(contest_world.data)
		))
		contest_world.state.set_park_balls(Gen2WorldBugContest.BALLS)
		## A second number of 2 or more has something caught, which is
		## the LEVEL row `StartMenu_PrintBugContestStatus` skips while
		## `wContestMon` is still zero.
		if _cell.y >= 2:
			contest_world.state.set_contest_mon({
				"species": 10, "level": 7, "max_hp": 22, "hp": 22,
			})
	_screen.get("_world").state.set_engine_flag(
		Gen2WorldStartMenu.ENGINE_POKEDEX, true
	)
	_screen.get("_world").state.set_engine_flag(
		Gen2WorldStartMenu.ENGINE_POKEGEAR, true
	)
	_screen.preview_start_menu()
	for _down: int in maxi(_cell.x, 0):
		_screen.press_button(Gen2Button.DOWN)
		_screen.advance_frame()


## `_BillsPC`, which no preview cell reaches: the first number is how many rows down
## the top menu to stand and the second how many A presses to spend from there, so `1
## 1` is the DEPOSIT list and `1 2` its submenu on the first party member.
func _stage_pc() -> void:
	_screen.call(SCREEN_DRIVER % _kind)
	for _down: int in maxi(_cell.x, 0):
		_screen.press_button(Gen2Button.DOWN)
		_screen.advance_frame()
	for _press: int in maxi(_cell.y, 0):
		_screen.press_button(Gen2Button.A)
		_screen.advance_frame()


## `Mom_SetUpDepositMenu` and its withdraw twin, which no fixture cell reaches: her
## house is not a preview map and the dial stands three questions into `BankOfMom`.
func _stage_mom_bank() -> void:
	_screen.preview_mom_bank(
		Gen2WorldMoneyDial.MODE_WITHDRAW if _cell.y >= 1000 \
			else Gen2WorldMoneyDial.MODE_DEPOSIT,
		(maxi(_cell.y, 0) % 1000) * 100, maxi(_cell.x, 0) * 100
	)
## The mod's own renderer, once there is one to choose: `_initialize` runs before
## the autoloads are in the tree, so nothing is registered while the screen is
## being built and the choice has to wait for the first frame.
func _choose_view() -> void:
	## Remembered whether or not this run chooses one: the `view_cover` driver
	## switches views itself, and the choice is persisted wherever it is made.
	_restore_view = Gen2ModHost.instance().selected_view()
	if _view.is_empty():
		return
	var chosen: Dictionary = _screen.select_view(_view)
	## A live switch is covered by a wipe whose middle is the build; a
	## photograph wants the picture behind it rather than the wipe, unless the
	## wipe is what is being photographed.
	if _kind != &"view_cover":
		_screen.settle_view_cover()
	if not bool(chosen.get("ok", false)):
		push_error("View %s unavailable: %s. Did you pass --mods?" % [
			_view, chosen.get("reason", "unknown")
		])


## A view is chosen per installation and persisted, so a capture that chose one
## puts the player's own back rather than leaving them on a mod's renderer.
func _restore_selected_view() -> void:
	if _restore_view.is_empty():
		return
	Gen2ModHost.instance().select_view(_restore_view)


func _render(data: GameData, map: Gen2WorldMap, tileset: Gen2WorldTileset) -> Image:
	var width: int = map.width_blocks * RomLayout.MAP_BLOCK_TILE_WIDTH * Gen2Tiles.TILE_WIDTH
	var height: int = map.height_blocks * RomLayout.MAP_BLOCK_TILE_WIDTH * Gen2Tiles.TILE_HEIGHT
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var pixels: PackedByteArray = data.map_tile_indices(map, tileset)
	var atlas_width: int = tileset.tile_count * Gen2Tiles.TILE_WIDTH
	var palettes: Array = Gen2WorldPalette.tile_palettes(data, map, tileset)

	for tile_y: int in map.height_blocks * RomLayout.MAP_BLOCK_TILE_WIDTH:
		for tile_x: int in map.width_blocks * RomLayout.MAP_BLOCK_TILE_WIDTH:
			var block: int = map.block_at(tile_x >> 2, tile_y >> 2)
			var tile: int = tileset.tile_index(block, (tile_y & 3) * 4 + (tile_x & 3))
			for pixel_y: int in Gen2Tiles.TILE_HEIGHT:
				for pixel_x: int in Gen2Tiles.TILE_WIDTH:
					var color_index: int = 0
					var palette := PackedColorArray()
					if tile < tileset.tile_count:
						color_index = pixels[pixel_y * atlas_width + tile * 8 + pixel_x]
						palette = palettes[tile]
					var color: Color = palette[color_index] if color_index < palette.size() else Color.MAGENTA
					image.set_pixel(
						tile_x * 8 + pixel_x, tile_y * 8 + pixel_y,
						color
					)

	# Mark event coordinates in a restrained red so the screenshot shows that
	# geometry and event data come from the same imported map record.
	for event: Dictionary in map.events.get("warps", []):
		_draw_marker(image, int(event["x"]), int(event["y"]), Color("#d34a5a"))
	for event: Dictionary in map.events.get("objects", []):
		var x: int = int(event["x"])
		var y: int = int(event["y"])
		if x >= 0 and y >= 0 and x < map.collision_width and y < map.collision_height:
			_draw_marker(image, x, y, Color("#3e6ed8"))
	return image


func _draw_marker(image: Image, cell_x: int, cell_y: int, color: Color) -> void:
	var pixel_x: int = cell_x * 16 + 4
	var pixel_y: int = cell_y * 16 + 4
	for y: int in 8:
		for x: int in 8:
			if pixel_x + x < image.get_width() and pixel_y + y < image.get_height():
				image.set_pixel(pixel_x + x, pixel_y + y, color)
