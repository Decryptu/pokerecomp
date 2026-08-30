class_name Gen2TradeAnimation
extends RefCounted

## `TradeAnimation` and `TradeAnimationPlayer2` (engine/movie/trade_animation.asm),
## the movie both a link trade and an `NPCTrade` run. `DoTradeAnimation` is one
## command a frame and then `PlaySpriteAnimations`, so that is the shape here, and
## [member _delay] is the frames a command spends inside `DelayFrames` with nothing
## else running. The screen is a tilemap of character codes, which is what the
## cartridge writes; [Gen2TradeAnimationPage] draws it.

const MUSIC_EVOLUTION: int = 0x22
const SFX_POKEBALLS_PLACED_ON_TABLE: int = 0x03
const SFX_POTION: int = 0x04
const SFX_GOT_SAFARI_BALLS: int = 0x0C
const SFX_SWITCH_POKEMON: int = 0x20
const SFX_BALL_POOF: int = 0x29
const SFX_GIVE_TRADEMON: int = 0xB7
const SFX_GET_TRADEMON: int = 0xB8

const COLUMNS: int = 20
const ROWS: int = 18
const MAP_COLUMNS: int = 32
const MAP_ROWS: int = 32

const TILE: int = 8
const BLANK: int = 0x7F
const PIC_TILES: int = 7
const PIC_AT: Vector2i = Vector2i(7, 2)

const EGG: int = 0xFD

const PLAYER_1: int = 0
const PLAYER_2: int = 1

const CRYSTAL_JUMPTABLE: Array[StringName] = [
	&"advance", &"show_givemon_data", &"show_getmon_data",
	&"enter_link_tube_1", &"enter_link_tube_2", &"exit_link_tube",
	&"tube_to_ot_1", &"tube_to_ot_2", &"tube_to_ot_3", &"tube_to_ot_4",
	&"tube_to_ot_5", &"tube_to_ot_6", &"tube_to_ot_7", &"tube_to_ot_8",
	&"tube_to_player_1", &"tube_to_player_2", &"tube_to_player_3",
	&"tube_to_player_4", &"tube_to_player_5", &"tube_to_player_6",
	&"tube_to_player_7", &"tube_to_player_8",
	&"sent_to_ot_text", &"ot_bids_farewell", &"take_care_of_text",
	&"ot_sends_text_1", &"ot_sends_text_2",
	&"setup_givemon_scroll", &"do_givemon_scroll", &"frontpic_scroll_start",
	&"textbox_scroll_start", &"scroll_out_right", &"scroll_out_right_2",
	&"wait_80", &"wait_40", &"rocking_ball", &"drop_ball", &"wait_anim",
	&"wait_anim_2", &"poof", &"bulge_through_tube", &"give_trademon_sfx",
	&"get_trademon_sfx", &"end", &"animate_frontpic", &"wait_96",
	&"wait_80_if_ot_egg", &"wait_180_if_ot_egg",
]
const GOLD_SILVER_JUMPTABLE: Array[StringName] = [
	&"advance", &"show_givemon_data", &"show_getmon_data",
	&"enter_link_tube_1", &"enter_link_tube_2", &"exit_link_tube",
	&"tube_to_ot_1", &"tube_to_ot_2", &"tube_to_ot_3", &"tube_to_ot_4",
	&"tube_to_ot_5", &"tube_to_ot_6", &"tube_to_ot_7", &"tube_to_ot_8",
	&"tube_to_player_1", &"tube_to_player_2", &"tube_to_player_3",
	&"tube_to_player_4", &"tube_to_player_5", &"tube_to_player_6",
	&"tube_to_player_7", &"tube_to_player_8",
	&"sent_to_ot_text", &"ot_bids_farewell", &"take_care_of_text",
	&"ot_sends_text_1", &"ot_sends_text_2",
	&"setup_givemon_scroll", &"do_givemon_scroll", &"frontpic_scroll_start",
	&"textbox_scroll_start", &"scroll_out_right", &"scroll_out_right_2",
	&"wait_80", &"rocking_ball", &"drop_ball", &"wait_anim", &"poof",
	&"bulge_through_tube", &"give_trademon_sfx", &"get_trademon_sfx", &"end",
]

const CRYSTAL_SCRIPTS: Array[Array] = [
	[
		&"setup_givemon_scroll", &"show_givemon_data", &"do_givemon_scroll",
		&"wait_80", &"wait_96", &"poof", &"rocking_ball", &"enter_link_tube_1",
		&"wait_anim", &"bulge_through_tube", &"wait_anim", &"textbox_scroll_start",
		&"give_trademon_sfx", &"tube_to_ot_1", &"sent_to_ot_text",
		&"scroll_out_right",
		&"ot_sends_text_1", &"ot_bids_farewell", &"wait_40", &"scroll_out_right",
		&"get_trademon_sfx", &"tube_to_player_1", &"enter_link_tube_1",
		&"drop_ball", &"exit_link_tube", &"wait_anim", &"show_getmon_data",
		&"poof", &"wait_anim", &"frontpic_scroll_start", &"animate_frontpic",
		&"wait_80_if_ot_egg", &"textbox_scroll_start", &"take_care_of_text",
		&"scroll_out_right", &"end",
	],
	[
		&"ot_sends_text_2", &"ot_bids_farewell", &"wait_40", &"scroll_out_right",
		&"get_trademon_sfx", &"tube_to_ot_1", &"enter_link_tube_1", &"drop_ball",
		&"exit_link_tube", &"wait_anim", &"show_getmon_data", &"poof",
		&"wait_anim", &"frontpic_scroll_start", &"animate_frontpic",
		&"wait_180_if_ot_egg", &"textbox_scroll_start", &"take_care_of_text",
		&"scroll_out_right",
		&"setup_givemon_scroll", &"show_givemon_data", &"do_givemon_scroll",
		&"wait_40", &"poof", &"rocking_ball", &"enter_link_tube_1", &"wait_anim",
		&"bulge_through_tube", &"wait_anim", &"textbox_scroll_start",
		&"give_trademon_sfx", &"tube_to_player_1", &"sent_to_ot_text",
		&"scroll_out_right", &"end",
	],
]
const GOLD_SILVER_SCRIPTS: Array[Array] = [
	[
		&"setup_givemon_scroll", &"show_givemon_data", &"do_givemon_scroll",
		&"wait_80", &"poof", &"rocking_ball", &"enter_link_tube_1", &"wait_anim",
		&"bulge_through_tube", &"wait_anim", &"textbox_scroll_start",
		&"give_trademon_sfx", &"tube_to_ot_1", &"sent_to_ot_text",
		&"scroll_out_right",
		&"ot_sends_text_1", &"ot_bids_farewell", &"scroll_out_right",
		&"get_trademon_sfx", &"tube_to_player_1", &"enter_link_tube_1",
		&"drop_ball", &"exit_link_tube", &"wait_anim", &"show_getmon_data",
		&"poof", &"wait_anim", &"frontpic_scroll_start", &"wait_80",
		&"textbox_scroll_start", &"take_care_of_text", &"scroll_out_right",
		&"end",
	],
	[
		&"ot_sends_text_2", &"ot_bids_farewell", &"scroll_out_right",
		&"get_trademon_sfx", &"tube_to_ot_1", &"enter_link_tube_1", &"drop_ball",
		&"exit_link_tube", &"wait_anim", &"show_getmon_data", &"poof",
		&"wait_anim", &"frontpic_scroll_start", &"wait_80",
		&"textbox_scroll_start", &"take_care_of_text", &"scroll_out_right",
		&"setup_givemon_scroll", &"show_givemon_data", &"do_givemon_scroll",
		&"wait_80", &"poof", &"rocking_ball", &"enter_link_tube_1", &"wait_anim",
		&"bulge_through_tube", &"wait_anim", &"textbox_scroll_start",
		&"give_trademon_sfx", &"tube_to_player_1", &"sent_to_ot_text",
		&"scroll_out_right", &"end",
	],
]

const FRAMESET_END: StringName = &"end"
const FRAMESET_DELETE: StringName = &"delete"
const FRAMESET_RESTART: StringName = &"restart"
const FLIP_X: int = 1

const OAM_BALL_1: int = 0
const OAM_BALL_2: int = 1
const OAM_POOF_1: int = 2
const OAM_POOF_2: int = 3
const OAM_POOF_3: int = 4
const OAM_BULGE_1: int = 5
const OAM_BULGE_2: int = 6
const OAM_ICON_1: int = 7
const OAM_ICON_2: int = 8
const OAM_BUBBLE: int = 9

const FRAMESETS: Dictionary = {
	&"ball": {"frames": [[OAM_BALL_1, 32, 0]], "end": FRAMESET_END},
	&"ball_wobble": {
		"frames": [
			[OAM_BALL_1, 3, 0], [OAM_BALL_2, 3, 0], [OAM_BALL_1, 3, 0],
			[OAM_BALL_2, 3, FLIP_X],
		],
		"end": FRAMESET_RESTART,
	},
	&"poof": {
		"frames": [[OAM_POOF_1, 4, 0], [OAM_POOF_2, 4, 0], [OAM_POOF_3, 4, 0]],
		"end": FRAMESET_DELETE,
	},
	&"bulge": {
		"frames": [[OAM_BULGE_1, 3, 0], [OAM_BULGE_2, 3, 0]], "end": FRAMESET_RESTART,
	},
	&"icon": {
		"frames": [[OAM_ICON_1, 7, 0], [OAM_ICON_2, 7, 0]], "end": FRAMESET_RESTART,
	},
	&"bubble": {"frames": [[OAM_BUBBLE, 32, 0]], "end": FRAMESET_END},
}

const OBJECTS: Dictionary = {
	&"ball": {"frameset": &"ball", "func": &"ball"},
	&"poof": {"frameset": &"poof", "func": &"none"},
	&"bulge": {"frameset": &"bulge", "func": &"bulge"},
	&"icon": {"frameset": &"icon", "func": &"in_tube"},
	&"bubble": {"frameset": &"bubble", "func": &"in_tube"},
}
const DICT_DEFAULT_TILE: int = 0x62

const ANIM_STRUCTS: int = 10
const SHADOW_OAM_SPRITES: int = 40
const OAM_SET_SIZES: Array[int] = [4, 4, 16, 16, 16, 4, 4, 4, 4, 16]

const TUBE_STATE_0: int = 0
const TUBE_STATE_1: int = 1
const TUBE_STATE_2: int = 2

const CABLE_END_LEFT: int = 0x5B
const CABLE_PLUG: int = 0x5D
const CABLE_CORNER: int = 0x5F
const CABLE_STRAIGHT: int = 0x60
const CABLE_VERTICAL: int = 0x61

const STATS_RULE_ROW: Array[int] = [0x7A, 0x7A, 0x7A, 0x7F, 0x74, 0xE8]
const STATS_ID_ROW: Array[int] = [0x73, 0x74, 0xE8]
const GENDER_CODES: Array[int] = [0x7F, 0xEF, 0xF5]

const SPEECH_BOX: Rect2i = Rect2i(0, 12, 20, 6)
const SPEECH_TEXT_AT: Vector2i = Vector2i(1, 14)
const BOX_CODES: Array[int] = [0x79, 0x7A, 0x7B, 0x7C, 0x7D, 0x7E]
const LINK_TIMECAPSULE: int = Gen2LinkTransport.LINK_TIMECAPSULE

var _data: GameData = null
var _sine: Gen2BattleAnimData = null
var _player: Dictionary = {}
var _ot: Dictionary = {}
var _sender_1: String = ""
var _sender_2: String = ""
var _sendmon: int = 0
var _getmon: int = 0

var _jumptable_names: Array[StringName] = CRYSTAL_JUMPTABLE
var _commands: Dictionary = {}
var _script: Array = []
var _script_at: int = 0
var _jumptable: int = 0
var _exit: bool = false

var _counter: int = 0
var _counter2: int = 0
var _delay: int = 0
var _frame: int = 0

var _scx: int = 0
var _wx: int = 7
var _wy: int = 0x90
var _map_target: int = 0

var _tilemap: PackedByteArray = PackedByteArray()
var _bg_map: PackedByteArray = PackedByteArray()
var _window_map: PackedByteArray = PackedByteArray()

var _actors: Array[Dictionary] = []
var _anim_count: int = 0
var _shadow: Array[Dictionary] = []
var _object_sheet: StringName = &"ball"

var _pic_pixels: PackedByteArray = PackedByteArray()
var _pic_palette: PackedColorArray = PackedColorArray()
## Which tile of it each cell shows: the animation's frames are in bank 1.
var _pic_box: PackedByteArray = PackedByteArray()
var _animation: Gen2PicAnimation = null
var _bgp: int = 0xE4
var _obp0: int = 0xE4
var _tube_palette: bool = false
var _crystal: bool = true
var _link_mode: int = 0
var _icon_species: int = 0

var _events: Array[Dictionary] = []


## [param context] is [method Gen2WorldPartyHost.trade_animation_context]' two
## halves. A null [param data] draws nothing; a host asks [method available].
static func create(
	data: GameData, sine: Gen2BattleAnimData, context: Dictionary, half: int = PLAYER_1
) -> Gen2TradeAnimation:
	var out := Gen2TradeAnimation.new()
	out._data = data
	out._sine = sine
	out._player = (context.get("player", {}) as Dictionary).duplicate(true)
	out._ot = (context.get("ot", {}) as Dictionary).duplicate(true)
	out._link_mode = int(context.get("link_mode", 0))
	out._build(half)
	return out


static func available(data: GameData) -> bool:
	return data != null and data.has_trade_anim()


func _build(half: int) -> void:
	_crystal = Gen2WorldState.is_crystal_profile(_data)
	_jumptable_names = CRYSTAL_JUMPTABLE if _crystal else GOLD_SILVER_JUMPTABLE
	var scripts: Array[Array] = CRYSTAL_SCRIPTS if _crystal else GOLD_SILVER_SCRIPTS
	_script = scripts[PLAYER_2 if half == PLAYER_2 else PLAYER_1]
	## `LinkTradeAnim_LoadTradePlayerNames`, whose arguments the second entry
	## point swaps.
	var first: Dictionary = _ot if half == PLAYER_2 else _player
	var second: Dictionary = _player if half == PLAYER_2 else _ot
	_sender_1 = String(first.get("sender_name", ""))
	_sender_2 = String(second.get("sender_name", ""))
	_sendmon = int(first.get("species", 0))
	_getmon = int(second.get("species", 0))
	_commands = _command_table()
	_actors.resize(ANIM_STRUCTS)
	_tilemap = _blank_run(COLUMNS * ROWS)
	_bg_map = _blank_run(MAP_COLUMNS * MAP_ROWS)
	_window_map = _blank_run(MAP_COLUMNS * MAP_ROWS)
	_emit(&"play_music", {"music": MUSIC_EVOLUTION})


static func _blank_run(cells: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(cells)
	out.fill(BLANK)
	return out


func finished() -> bool:
	return _exit


func frame() -> int:
	return _frame


func scroll_x() -> int:
	return _scx


func window() -> Vector2i:
	return Vector2i(_wx, _wy)


func bg_map() -> PackedByteArray:
	return _bg_map


func window_map() -> PackedByteArray:
	return _window_map


func tilemap() -> PackedByteArray:
	return _tilemap


func sprites() -> Array[Dictionary]:
	return _shadow


func object_sheet() -> StringName:
	return _object_sheet


func background_palette_index() -> int:
	return _bgp


func object_palette_index() -> int:
	return _obp0


func icon_species() -> int:
	return _icon_species


func tube_palette() -> bool:
	return _tube_palette


func frontpic_pixels() -> PackedByteArray:
	return _pic_pixels


func frontpic_palette() -> PackedColorArray:
	return _pic_palette


func frontpic_box() -> PackedByteArray:
	return _pic_box


func drain_events() -> Array[Dictionary]:
	var out: Array[Dictionary] = _events.duplicate(true)
	_events.clear()
	return out


func advance_frame() -> Array[Dictionary]:
	if _exit:
		return drain_events()
	_frame += 1
	if _delay > 0:
		_delay -= 1
		return drain_events()
	_run_command()
	if _exit:
		return drain_events()
	_run_sprites()
	_counter2 = (_counter2 + 1) & 0xFF
	return drain_events()


func settle(limit: int = 20000) -> int:
	var guard: int = limit
	while not _exit and guard > 0:
		advance_frame()
		guard -= 1
	return _frame


func _run_command() -> void:
	var name: StringName = _jumptable_names[_jumptable] \
		if _jumptable >= 0 and _jumptable < _jumptable_names.size() else &"end"
	(_commands[name] as Callable).call()


func _command_table() -> Dictionary:
	return {
		&"advance": _cmd_advance,
		&"show_givemon_data": _cmd_show_givemon_data,
		&"show_getmon_data": _cmd_show_getmon_data,
		&"enter_link_tube_1": _cmd_enter_link_tube_1,
		&"enter_link_tube_2": _cmd_enter_link_tube_2,
		&"exit_link_tube": _cmd_exit_link_tube,
		&"tube_to_ot_1": _cmd_tube_to_ot_1,
		&"tube_to_ot_2": _cmd_tube_to_ot_2,
		&"tube_to_ot_3": _cmd_tube_to_ot_3,
		&"tube_to_ot_4": _cmd_tube_to_ot_4,
		&"tube_to_ot_5": _cmd_tube_wait,
		&"tube_to_ot_6": _cmd_tube_long_wait,
		&"tube_to_ot_7": _cmd_tube_wait,
		&"tube_to_ot_8": _cmd_tube_done,
		&"tube_to_player_1": _cmd_tube_to_player_1,
		&"tube_to_player_2": _cmd_tube_wait,
		&"tube_to_player_3": _cmd_tube_to_player_3,
		&"tube_to_player_4": _cmd_tube_to_player_4,
		&"tube_to_player_5": _cmd_tube_to_player_5,
		&"tube_to_player_6": _cmd_tube_long_wait,
		&"tube_to_player_7": _cmd_tube_wait,
		&"tube_to_player_8": _cmd_tube_done,
		&"sent_to_ot_text": _cmd_sent_to_ot_text,
		&"ot_bids_farewell": _cmd_ot_bids_farewell,
		&"take_care_of_text": _cmd_take_care_of_text,
		&"ot_sends_text_1": _cmd_ot_sends_text_1,
		&"ot_sends_text_2": _cmd_ot_sends_text_2,
		&"setup_givemon_scroll": _cmd_setup_givemon_scroll,
		&"do_givemon_scroll": _cmd_do_givemon_scroll,
		&"frontpic_scroll_start": _cmd_frontpic_scroll_start,
		&"textbox_scroll_start": _cmd_textbox_scroll_start,
		&"scroll_out_right": _cmd_scroll_out_right,
		&"scroll_out_right_2": _cmd_scroll_out_right_2,
		&"wait_80": _cmd_wait_80,
		&"wait_40": _cmd_wait_40,
		&"wait_96": _cmd_wait_96,
		&"wait_80_if_ot_egg": _cmd_wait_80_if_ot_egg,
		&"wait_180_if_ot_egg": _cmd_wait_180_if_ot_egg,
		&"rocking_ball": _cmd_rocking_ball,
		&"drop_ball": _cmd_drop_ball,
		&"wait_anim": _cmd_wait_anim,
		&"wait_anim_2": _cmd_wait_anim,
		&"poof": _cmd_poof,
		&"bulge_through_tube": _cmd_bulge_through_tube,
		&"give_trademon_sfx": _cmd_give_trademon_sfx,
		&"get_trademon_sfx": _cmd_get_trademon_sfx,
		&"animate_frontpic": _cmd_animate_frontpic,
		&"end": _cmd_end,
	}


func _cmd_advance() -> void:
	if _script_at >= _script.size():
		_exit = true
		return
	_jumptable = _jumptable_names.find(StringName(_script[_script_at]))
	_script_at += 1


func _increment() -> void:
	_jumptable += 1


func _cmd_end() -> void:
	_exit = true


func _cmd_show_givemon_data() -> void:
	_show_stats(_player)
	_show_frontpic(&"player")
	_emit(&"play_cry", {"species": int(_player.get("species", 0))})
	_cmd_advance()


func _cmd_show_getmon_data() -> void:
	_show_stats(_ot)
	_show_frontpic(&"ot")
	if not _crystal:
		_emit(&"play_cry", {"species": int(_ot.get("species", 0))})
	_cmd_advance()


func _cmd_animate_frontpic() -> void:
	if _animation == null:
		if _data == null or int(_ot.get("species", 0)) == EGG:
			_cmd_advance()
			return
		_show_stats(_ot)
		_show_frontpic(&"ot")
		var record: Dictionary = _data.pic_animation(int(_ot.get("species", 0)))
		if record.is_empty():
			_cmd_advance()
			return
		_animation = Gen2PicAnimation.new(record, Gen2PicAnimation.ANIM_MON_TRADE)
	if _animation.advance() != &"":
		_emit(&"play_cry", {"species": int(_ot.get("species", 0))})
	_pic_box = _animation.box
	if not _animation.finished():
		return
	_animation = null
	_reset_frontpic_box()
	_cmd_advance()


func _cmd_enter_link_tube_1() -> void:
	_clear_tilemap()
	_scx = 0xA0
	_copy_box(
		_tilemap_run("link_cable_tilemap"),
		RomLayout.TRADE_ANIM_LINK_CABLE_SIZE, Vector2i(8, 2)
	)
	_wait_bg_map()
	_tube_palette = true
	_bgp = 0xE4
	_obp0 = 0xE4
	_emit(&"play_sfx", {"sfx": SFX_POTION})
	_increment()
	## `call DelayFrame` between the scroll register and the tilemap write.
	_delay += 1


func _cmd_enter_link_tube_2() -> void:
	if _scx == 0:
		_delay += 80
		_cmd_advance()
		return
	_scx = (_scx + 4) & 0xFF


func _cmd_exit_link_tube() -> void:
	if _scx == 0xA0:
		_clear_tilemap()
		_scx = 0
		_cmd_advance()
		return
	_scx = (_scx - 4) & 0xFF


func _cmd_setup_givemon_scroll() -> void:
	_wx = 0x8F
	_scx = 0x88
	_wy = 0x50
	_cmd_advance()


func _cmd_do_givemon_scroll() -> void:
	if _wx == 7:
		_scx = 0
		_cmd_advance()
		return
	_wx = (_wx - 4) & 0xFF
	_scx = (_scx - 4) & 0xFF


func _cmd_frontpic_scroll_start() -> void:
	_wx = 7
	_wy = 0x50
	_cmd_advance()


func _cmd_textbox_scroll_start() -> void:
	_wx = 7
	_wy = 0x90
	_cmd_advance()


func _cmd_scroll_out_right() -> void:
	_map_target = 1
	_wait_bg_map()
	_wx = 7
	_wy = 0
	_map_target = 0
	_clear_tilemap()
	_increment()
	_delay += 1


func _cmd_scroll_out_right_2() -> void:
	if _wx < 0xA1:
		## Gold and Silver's own `inc a / inc a`, against Crystal's `add $4`.
		_wx += 4 if _crystal else 2
		return
	_map_target = 1
	_wait_bg_map()
	_wx = 7
	_wy = 0x90
	_map_target = 0
	_cmd_advance()


func _cmd_wait_80() -> void:
	_delay += 80
	_cmd_advance()


func _cmd_wait_40() -> void:
	_delay += 40
	_cmd_advance()


func _cmd_wait_96() -> void:
	_delay += 96
	_cmd_advance()


## `IsOTTrademonEgg` advances the script pointer before it looks.
func _cmd_wait_80_if_ot_egg() -> void:
	_cmd_advance()
	if int(_ot.get("species", 0)) == EGG:
		_delay += 80


func _cmd_wait_180_if_ot_egg() -> void:
	_cmd_advance()
	if int(_ot.get("species", 0)) == EGG:
		_delay += 180


func _cmd_wait_anim() -> void:
	if _counter > 0:
		_counter -= 1
		return
	_cmd_advance()


func _cmd_give_trademon_sfx() -> void:
	_cmd_advance()
	_emit(&"play_sfx", {"sfx": SFX_GIVE_TRADEMON})


func _cmd_get_trademon_sfx() -> void:
	_cmd_advance()
	_emit(&"play_sfx", {"sfx": SFX_GET_TRADEMON})


func _cmd_rocking_ball() -> void:
	_load_ball_gfx()
	_spawn(&"ball", Vector2i(88, 84))
	_cmd_advance()
	## Gold and Silver rock the ball for twice as long.
	_counter = 32 if _crystal else 64


func _cmd_drop_ball() -> void:
	_load_ball_gfx()
	var actor: Dictionary = _spawn(&"ball", Vector2i(88, 84))
	if not actor.is_empty():
		actor["jumptable"] = 1
		actor["y_offset"] = 0xDC
	_cmd_advance()
	_counter = 56


func _cmd_poof() -> void:
	_load_ball_gfx()
	_spawn(&"poof", Vector2i(88, 84))
	_cmd_advance()
	_counter = 16
	_emit(&"play_sfx", {"sfx": SFX_BALL_POOF})


func _cmd_bulge_through_tube() -> void:
	_obp0 = 0xE4
	_spawn(&"bulge", Vector2i(88, 40))
	_cmd_advance()
	_counter = 64 if _crystal else 128


func _load_ball_gfx() -> void:
	_object_sheet = &"ball"


func _cmd_tube_to_ot_1() -> void:
	_place_stats_on_tube(RomLayout.TRADE_ANIM_RIGHT_ARROW_CODE)
	_icon_species = _sendmon
	_init_tube_anim(TUBE_STATE_0, Vector2i(88, 44), 0)


func _cmd_tube_to_player_1() -> void:
	_place_stats_on_tube(RomLayout.TRADE_ANIM_LEFT_ARROW_CODE)
	_icon_species = _getmon
	_init_tube_anim(TUBE_STATE_2, Vector2i(148, 76), 4)


func _init_tube_anim(state: int, at: Vector2i, anim_state: int) -> void:
	_clear_sprite_anims()
	for column: int in 12:
		_bg_map[3 * MAP_COLUMNS + 20 + column] = CABLE_STRAIGHT
	_tube_anim_tilemap(state)
	_scx = 0
	_wx = 7
	_wy = 0x70
	_object_sheet = &"bubble"
	for object: StringName in [&"icon", &"bubble"]:
		var actor: Dictionary = _spawn(object, at)
		if not actor.is_empty():
			actor["jumptable"] = anim_state
	_wait_bg_map()
	_tube_palette = true
	_bgp = 0xE4
	_obp0 = 0xD0
	_increment()
	_counter = 92


func _cmd_tube_to_ot_2() -> void:
	_flash_bg_pals()
	_scx = (_scx + 2) & 0xFF
	if _scx != 0x50:
		return
	_tube_anim_tilemap(TUBE_STATE_1)
	_increment()


func _cmd_tube_to_ot_3() -> void:
	_flash_bg_pals()
	_scx = (_scx + 2) & 0xFF
	if _scx != 0xA0:
		return
	_tube_anim_tilemap(TUBE_STATE_2)
	_increment()


func _cmd_tube_to_ot_4() -> void:
	_flash_bg_pals()
	_scx = (_scx + 2) & 0xFF
	if _scx != 0:
		return
	_increment()


func _cmd_tube_to_player_3() -> void:
	_flash_bg_pals()
	_scx = (_scx - 2) & 0xFF
	if _scx != 0xB0:
		return
	_tube_anim_tilemap(TUBE_STATE_1)
	_increment()


func _cmd_tube_to_player_4() -> void:
	_flash_bg_pals()
	_scx = (_scx - 2) & 0xFF
	if _scx != 0x60:
		return
	_tube_anim_tilemap(TUBE_STATE_0)
	_increment()


func _cmd_tube_to_player_5() -> void:
	_flash_bg_pals()
	_scx = (_scx - 2) & 0xFF
	if _scx != 0:
		return
	_increment()


func _cmd_tube_wait() -> void:
	_flash_bg_pals()
	if _counter > 0:
		_counter -= 1
		return
	_increment()


func _cmd_tube_long_wait() -> void:
	_counter = 128
	_increment()


func _cmd_tube_done() -> void:
	_clear_sprite_anims()
	_bg_map = _blank_run(MAP_COLUMNS * MAP_ROWS)
	_window_map = _blank_run(MAP_COLUMNS * MAP_ROWS)
	_clear_tilemap()
	_scx = 0
	_wy = 0x90
	_object_sheet = &"ball"
	_wait_bg_map()
	_tube_palette = false
	_bgp = 0xE4
	_obp0 = 0xE4
	_cmd_advance()


func _flash_bg_pals() -> void:
	if _counter2 & 0x7 != 0:
		return
	_bgp ^= 0x3C


func _cmd_sent_to_ot_text() -> void:
	## `LINK_TIMECAPSULE` skips the 189 frames of `_MonNameSentToText`, an empty box.
	if _link_mode == LINK_TIMECAPSULE:
		_print_text(_box_text("was_sent"))
		_delay += 80
		_cmd_advance()
		return
	_print_text([])
	_delay += 189
	_print_text(_box_text("was_sent"))
	_delay += 80 + 128
	_cmd_advance()


func _cmd_ot_bids_farewell() -> void:
	_print_text(_box_text("bids_farewell"))
	_delay += 80
	_print_text(_box_text("name_bids_farewell"))
	_delay += 80
	_cmd_advance()


func _cmd_take_care_of_text() -> void:
	_clear_rows(10, 8)
	_print_text(_box_text("take_good_care"))
	_delay += 80
	_cmd_advance()


func _cmd_ot_sends_text_1() -> void:
	_print_text(_box_text("for_your_mon_sends"))
	_delay += 80
	_print_text(_box_text("ot_sends"))
	_delay += 80 + 14
	_cmd_advance()


func _cmd_ot_sends_text_2() -> void:
	_print_text(_box_text("will_trade"))
	_delay += 80
	_print_text(_box_text("for_your_mon_will_trade"))
	_delay += 80 + 14
	_cmd_advance()


func _box_text(name: String) -> Array:
	if _data == null:
		return []
	var text: String = _data.special_text("trade", name)
	if text.is_empty():
		return []
	for buffer: String in [
		"player_trademon_species_name", "player_trademon_sender_name",
		"ot_trademon_species_name", "ot_trademon_sender_name",
	]:
		var address: int = _data.special_text_ram(buffer)
		if address < 0:
			continue
		text = text.replace(
			"%s%04X>" % [Gen2TextStream.RAM_MARKER, address], _buffer_value(buffer)
		)
	var pages: Array = Gen2TextLayout.lay_out(
		text, SPEECH_BOX.size.x - 2, Gen2TextBox.LINE_SPACING
	)
	return Array(pages[0]) if not pages.is_empty() else []


func _buffer_value(buffer: String) -> String:
	match buffer:
		"player_trademon_species_name":
			return String(_player.get("species_name", ""))
		"ot_trademon_species_name":
			return String(_ot.get("species_name", ""))
		"player_trademon_sender_name":
			return _sender_1
		_:
			return _sender_2


func _print_text(lines: Array) -> void:
	_draw_box(SPEECH_BOX)
	for line: int in lines.size():
		_place_string(
			String(lines[line]),
			SPEECH_TEXT_AT + Vector2i(0, line * Gen2TextBox.LINE_SPACING)
		)
	_wait_bg_map()


func _place_stats_on_tube(arrow: int) -> void:
	_map_target = 1
	_clear_tilemap()
	for column: int in COLUMNS:
		_tilemap[column] = 0x7A
	_place_string(_sender_1, Vector2i(0, 1))
	_place_string(_sender_2, Vector2i(COLUMNS - _sender_2.length(), 3))
	for column: int in 6:
		_tilemap[2 * COLUMNS + 7 + column] = arrow
	_wait_bg_map()
	_map_target = 0
	_clear_tilemap()


func _tube_anim_tilemap(state: int) -> void:
	_clear_tilemap()
	if state == TUBE_STATE_1:
		for column: int in COLUMNS:
			_tilemap[3 * COLUMNS + column] = CABLE_STRAIGHT
		_wait_bg_map()
		return
	if state == TUBE_STATE_2:
		_tube_anim_tilemap_two()
		_wait_bg_map()
		return
	_tilemap[3 * COLUMNS + 9] = CABLE_END_LEFT
	for column: int in 10:
		_tilemap[3 * COLUMNS + 10 + column] = CABLE_STRAIGHT
	_copy_box(
		_tilemap_run("game_boy_tilemap"),
		RomLayout.TRADE_ANIM_GAME_BOY_SIZE, Vector2i(3, 2)
	)
	_wait_bg_map()


func _tube_anim_tilemap_two() -> void:
	for column: int in 0x11:
		_tilemap[3 * COLUMNS + column] = CABLE_STRAIGHT
	_tilemap[3 * COLUMNS + 17] = CABLE_PLUG
	for row: int in 3:
		_tilemap[(4 + row) * COLUMNS + 17] = CABLE_VERTICAL
	_tilemap[7 * COLUMNS + 16] = CABLE_CORNER
	_tilemap[7 * COLUMNS + 17] = CABLE_END_LEFT
	_copy_box(
		_tilemap_run("game_boy_tilemap"),
		RomLayout.TRADE_ANIM_GAME_BOY_SIZE, Vector2i(10, 6)
	)


func _show_stats(side: Dictionary) -> void:
	_map_target = 1
	_clear_tilemap()
	_draw_box(Rect2i(3, 0, 15, 8))
	if int(side.get("species", 0)) == EGG:
		_place_string("EGG", Vector2i(4, 2))
		_place_string("OT/?????", Vector2i(4, 4))
		_place_codes(STATS_ID_ROW, Vector2i(4, 6))
		_place_string("?????", Vector2i(4 + STATS_ID_ROW.size(), 6))
		_wait_bg_map()
		_map_target = 0
		return
	_place_codes(STATS_RULE_ROW, Vector2i(4, 0))
	_place_string("OT/", Vector2i(4, 4))
	_place_codes(STATS_ID_ROW, Vector2i(4, 6))
	_place_string(
		str(int(side.get("species", 0))).lpad(3, "0"), Vector2i(10, 0)
	)
	## Crystal alone writes a space over the cell the number ended on.
	if _crystal:
		_tilemap[13] = BLANK
	_place_string(String(side.get("species_name", "")), Vector2i(4, 2))
	_place_ot(side)
	_place_string(str(int(side.get("ot_id", 0))).lpad(5, "0"), Vector2i(7, 6))
	_wait_bg_map()
	_map_target = 0


func _place_ot(side: Dictionary) -> void:
	var name: String = String(side.get("ot_name", ""))
	_place_string(name, Vector2i(7, 4))
	if not _crystal:
		return
	var gender: int = int(side.get("caught_gender", 0))
	if gender >= GENDER_CODES.size():
		gender = 0
	_place_codes([GENDER_CODES[gender]], Vector2i(7 + name.length() + 1, 4))


func _show_frontpic(side: StringName) -> void:
	var record: Dictionary = _ot if side == &"ot" else _player
	var species: int = int(record.get("species", 0))
	_pic_pixels = PackedByteArray()
	_pic_palette = PackedColorArray()
	var pic: Dictionary = {} if _data == null \
		else (_data.egg_pic() if species == EGG else _data.species_pic(species))
	if not pic.is_empty():
		_pic_pixels = Gen2BattleRenderer.padded_pic(
			_data, pic, PIC_TILES, true,
			{} if species == EGG else _data.species_pic_animation(species)
		)
		_pic_palette = _data.egg_palette() if species == EGG \
			else _data.palette(species, bool(record.get("shiny", false)))
	_clear_tilemap()
	_reset_frontpic_box()
	for column: int in PIC_TILES:
		for row: int in PIC_TILES:
			_tilemap[(PIC_AT.y + row) * COLUMNS + PIC_AT.x + column] = \
				column * PIC_TILES + row
	_wait_bg_map()


func _reset_frontpic_box() -> void:
	_pic_box = PackedByteArray()
	_pic_box.resize(PIC_TILES * PIC_TILES)
	for cell: int in _pic_box.size():
		_pic_box[cell] = cell


func _tilemap_run(name: String) -> PackedByteArray:
	return PackedByteArray() if _data == null else _data.trade_anim_tilemap(name)


func _clear_tilemap() -> void:
	_tilemap.fill(BLANK)
	_wait_bg_map()


func _clear_rows(top: int, rows: int) -> void:
	for cell: int in rows * COLUMNS:
		_tilemap[top * COLUMNS + cell] = BLANK
	_wait_bg_map()


## `UpdateBGMap`, into whichever map `hBGMapAddress` names. A third of the rows a
## frame on the cartridge and all of them here, the standing divergence.
func _wait_bg_map() -> void:
	var into: PackedByteArray = _window_map if _map_target == 1 else _bg_map
	for row: int in ROWS:
		for column: int in COLUMNS:
			into[row * MAP_COLUMNS + column] = _tilemap[row * COLUMNS + column]


func _draw_box(box: Rect2i) -> void:
	var codes: Array[int] = BOX_CODES
	var right: int = box.position.x + box.size.x - 1
	var bottom: int = box.position.y + box.size.y - 1
	_write(codes[0], box.position)
	_write(codes[2], Vector2i(right, box.position.y))
	_write(codes[4], Vector2i(box.position.x, bottom))
	_write(codes[5], Vector2i(right, bottom))
	for column: int in range(box.position.x + 1, right):
		_write(codes[1], Vector2i(column, box.position.y))
		_write(codes[1], Vector2i(column, bottom))
	for row: int in range(box.position.y + 1, bottom):
		_write(codes[3], Vector2i(box.position.x, row))
		_write(codes[3], Vector2i(right, row))
		for column: int in range(box.position.x + 1, right):
			_write(BLANK, Vector2i(column, row))


func _place_string(text: String, at: Vector2i) -> void:
	_place_codes(Array(Gen2Text.encode(text)), at)


func _place_codes(codes: Array, at: Vector2i) -> void:
	for index: int in codes.size():
		_write(int(codes[index]), at + Vector2i(index, 0))


func _write(code: int, at: Vector2i) -> void:
	if at.x < 0 or at.x >= COLUMNS or at.y < 0 or at.y >= ROWS:
		return
	_tilemap[at.y * COLUMNS + at.x] = code


func _copy_box(cells: PackedByteArray, size: Vector2i, at: Vector2i) -> void:
	if cells.size() < size.x * size.y:
		return
	for row: int in size.y:
		for column: int in size.x:
			_write(int(cells[row * size.x + column]), at + Vector2i(column, row))


func _clear_sprite_anims() -> void:
	_actors.clear()
	_actors.resize(ANIM_STRUCTS)
	_anim_count = 0
	_shadow = []


func _spawn(object: StringName, at: Vector2i) -> Dictionary:
	var slot: int = -1
	for index: int in _actors.size():
		if (_actors[index] as Dictionary).is_empty():
			slot = index
			break
	if slot < 0:
		return {}
	_anim_count = (_anim_count + 1) & 0xFF
	if _anim_count == 0:
		_anim_count = 1
	var actor: Dictionary = {
		"index": _anim_count,
		"object": object,
		"frameset": StringName((OBJECTS[object] as Dictionary)["frameset"]),
		"func": StringName((OBJECTS[object] as Dictionary)["func"]),
		"vtile": DICT_DEFAULT_TILE,
		"x": at.x, "y": at.y,
		"x_offset": 0, "y_offset": 0,
		"duration": 0, "frame": -1,
		"jumptable": 0, "var1": 0, "var2": 0,
	}
	_actors[slot] = actor
	return actor


func _run_sprites() -> void:
	for slot: int in _actors.size():
		if bool((_actors[slot] as Dictionary).get("deinit", false)):
			_actors[slot] = {}
	_shadow = []
	var room: int = SHADOW_OAM_SPRITES
	for slot: int in _actors.size():
		var actor: Dictionary = _actors[slot]
		if actor.is_empty():
			continue
		if not _run_sprite_func(actor):
			actor["deinit"] = true
		if not _advance_actor(actor):
			_actors[slot] = {}
			continue
		var entry: Array = _actor_frame(actor)
		if entry.is_empty():
			continue
		_shadow.append({
			"at": Vector2i(
				(int(actor["x"]) + int(actor["x_offset"])) & 0xFF,
				(int(actor["y"]) + int(actor["y_offset"])) & 0xFF,
			),
			"set": int(entry[0]),
			"flip_x": bool(int(entry[2]) & FLIP_X),
			"vtile": int(actor["vtile"]),
		})
		room -= OAM_SET_SIZES[int(entry[0])]
		if room <= 0:
			return


func _run_sprite_func(actor: Dictionary) -> bool:
	match StringName(actor["func"]):
		&"ball":
			return _sprite_ball(actor)
		&"bulge":
			return _sprite_bulge(actor)
		&"in_tube":
			return _sprite_in_tube(actor)
	return true


func _sprite_ball(actor: Dictionary) -> bool:
	match int(actor["jumptable"]):
		0:
			actor["frameset"] = &"ball_wobble"
			actor["frame"] = -1
			actor["duration"] = 0
			actor["jumptable"] = 2
			actor["var1"] = 0x20
		1:
			actor["jumptable"] = 4
			actor["var1"] = 0x30
			actor["var2"] = 0x24
		2:
			return _sprite_ball_settle(actor)
		3:
			return _sprite_ball_rise(actor)
		4:
			return _sprite_ball_bounce(actor)
		_:
			return false
	return true


func _sprite_ball_settle(actor: Dictionary) -> bool:
	if int(actor["var1"]) != 0:
		actor["var1"] = int(actor["var1"]) - 1
		return true
	actor["jumptable"] = 3
	actor["var1"] = 0x40
	return _sprite_ball_rise(actor)


func _sprite_ball_rise(actor: Dictionary) -> bool:
	var angle: int = int(actor["var1"])
	if angle < 48:
		_emit(&"play_sfx", {"sfx": SFX_GOT_SAFARI_BALLS})
		return false
	## `dec [hl]` leaves `a` holding the angle the sine is read at.
	actor["var1"] = angle - 1
	actor["y_offset"] = _sine_at(angle, 40)
	return true


func _sprite_ball_bounce(actor: Dictionary) -> bool:
	if int(actor["var2"]) == 0:
		actor["y_offset"] = 0
		actor["jumptable"] = 5
		return true
	actor["y_offset"] = _sine_at(int(actor["var1"]), int(actor["var2"]))
	actor["var1"] = (int(actor["var1"]) + 1) & 0xFF
	if int(actor["var1"]) & 0x3F != 0:
		return true
	actor["var1"] = 0x20
	actor["var2"] = (int(actor["var2"]) - 0x0C) & 0xFF
	_emit(&"play_sfx", {"sfx": SFX_SWITCH_POKEMON})
	return true


func _sprite_bulge(actor: Dictionary) -> bool:
	var x: int = int(actor["x"])
	## Crystal's `inc [hl]` twice against Gold and Silver's one, which is why
	## theirs is given twice as long to cross.
	actor["x"] = (x + (2 if _crystal else 1)) & 0xFF
	if x >= 0xB0:
		return false
	if x & 0x3 != 0:
		return true
	_emit(&"play_sfx", {"sfx": SFX_POKEBALLS_PLACED_ON_TABLE})
	return true


func _sprite_in_tube(actor: Dictionary) -> bool:
	match int(actor["jumptable"]):
		0:
			actor["jumptable"] = 1
			actor["var1"] = 0x80
			return true
		1:
			var timer: int = int(actor["var1"])
			actor["var1"] = (timer - 1) & 0xFF
			if timer != 0:
				return true
			actor["jumptable"] = 2
			return _tube_move_right(actor)
		2:
			return _tube_move_right(actor)
		3:
			return _tube_move_down(actor)
		4:
			return _tube_move_up(actor)
		5:
			return _tube_move_left(actor)
	var wait: int = int(actor["var1"])
	actor["var1"] = (wait - 1) & 0xFF
	return wait != 0


func _tube_move_right(actor: Dictionary) -> bool:
	if int(actor["x"]) < 0x94:
		actor["x"] = int(actor["x"]) + 1
		return true
	actor["jumptable"] = 3
	return _tube_move_down(actor)


func _tube_move_down(actor: Dictionary) -> bool:
	if int(actor["y"]) < 0x4C:
		actor["y"] = int(actor["y"]) + 1
		return true
	return false


func _tube_move_up(actor: Dictionary) -> bool:
	if int(actor["y"]) != 0x2C:
		actor["y"] = int(actor["y"]) - 1
		return true
	actor["jumptable"] = 5
	return _tube_move_left(actor)


func _tube_move_left(actor: Dictionary) -> bool:
	if int(actor["x"]) != 0x58:
		actor["x"] = int(actor["x"]) - 1
		return true
	actor["jumptable"] = 6
	actor["var1"] = 0x80
	return true


func _advance_actor(actor: Dictionary) -> bool:
	var frameset: Dictionary = FRAMESETS[StringName(actor["frameset"])]
	var frames: Array = frameset["frames"]
	if int(actor["duration"]) > 0:
		actor["duration"] = int(actor["duration"]) - 1
		return true
	var next: int = int(actor["frame"]) + 1
	if next >= frames.size():
		match StringName(frameset["end"]):
			FRAMESET_DELETE:
				return false
			FRAMESET_RESTART:
				next = 0
			_:
				next = maxi(frames.size() - 1, 0)
	actor["frame"] = next
	actor["duration"] = int((frames[next] as Array)[1])
	return true


func _actor_frame(actor: Dictionary) -> Array:
	var frames: Array = (FRAMESETS[StringName(actor["frameset"])] as Dictionary)["frames"]
	var at: int = int(actor["frame"])
	return frames[at] if at >= 0 and at < frames.size() else []


func _sine_at(angle: int, amplitude: int) -> int:
	return 0 if _sine == null else Gen2BattleAnimFunctions.sine_of(_sine, angle, amplitude)


func _emit(type: StringName, values: Dictionary) -> void:
	var event: Dictionary = values.duplicate()
	event["type"] = type
	event["frame"] = _frame
	_events.append(event)
