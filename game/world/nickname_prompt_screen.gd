class_name Gen2NicknamePromptScreen
extends Control

## `GiveANickname_YesNo`, `InitNickname` and the `WasSentToBillsPCText` behind
## them, for a Pokemon that was received rather than hatched: `GivePoke`'s
## `.wildmon` branch and every `givepoke` that names no OT. Text only, because the
## routine draws nothing else: it stands over whatever screen the caller left up.
## [Gen2EggHatchScreen] keeps its own copy of the same pair rather than opening
## this one, since its question is `_BreedAskNicknameText` and its box stands over
## its own animation backdrop.

## The nickname the player settled on, emitted once, before [signal closed].
signal named(nickname: String)
signal closed()

const TILE: int = Gen2Font.TILE

enum Phase {
	ASK,
	NAMING,
	AFTER_TEXT,
	DONE,
}

var _data: GameData = null
## `wStringBuffer1`, which is the species name until the player replaces it.
var _species_name: String = ""
## `wCurPartySpecies` and `GetGender`'s answer for the row `.Pokemon` draws
## from; a caller naming by species name alone has no icon.
var _species: int = 0
var _gender_sign: int = 0
## `_WasSentToBillsPCText`/`_BallSentToPCText` when the Pokemon landed in the
## box, empty otherwise. A format, because both read the name buffer the naming
## screen has just written rather than the species name the question asked with.
var _after_text_format: String = ""
## `_CaughtAskNicknameText` unless the caller names `PokeBallEffect`'s own
## `_AskGiveNicknameText` instead.
var _question: String = ""
## Whether the YES/NO is skipped and the keyboard opened outright, which is the
## Nuzlocke's "every Pokemon is nicknamed": a question with one allowed answer
## is worse than no question.
var _forced: bool = false
var _phase: int = Phase.DONE
var _yes: bool = true
var _answer: String = ""

var _text_box: Gen2TextBox = null
var _menu_page: Gen2MenuPage = null
var _menu: TextureRect = null
var _naming: Gen2NamingScreenScreen = null


func set_context(
	data: GameData,
	species_name: String,
	after_text_format: String = "",
	question: String = "",
	forced: bool = false
) -> void:
	_data = data
	_species_name = species_name
	_after_text_format = after_text_format
	_forced = forced
	_question = question if not question.is_empty() \
		else Gen2WorldPartyHost.caught_nickname_question(species_name)


## `.Pokemon`'s icon. [param dvs] is `GetGender`'s input; -1 leaves the sign off.
func set_species(species: int, dvs: int = -1) -> void:
	_species = species
	_gender_sign = Gen2NamingScreenScreen.gender_sign(_data, species, dvs)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
	if _data == null or _species_name.is_empty():
		closed.emit()
		return
	_build()
	_answer = _species_name
	_phase = Phase.ASK
	_yes = true
	if _forced:
		_answer_question(true)
		return
	_text_box.visible = true
	## `_CaughtAskNicknameText` ends in `done`, so the last page draws no arrow:
	## what waits is the `YesNoBox` behind it.
	_text_box.show_text(_question, false)


func phase() -> int:
	return _phase


func text_lines() -> PackedStringArray:
	if _text_box == null or not _text_box.visible:
		return PackedStringArray()
	return _text_box.text_lines()


## The YES/NO cursor, so a driver can read it without a redraw. -1 when the box
## is not up, the same shape [Gen2EggHatchScreen] answers.
func nickname_cursor() -> int:
	return (0 if _yes else 1) if _phase == Phase.ASK else -1


## Whether the `YesNoBox` is up, which is `PrintText` having returned. A driver
## presses the text past its own `cont` while this is false.
func question_ready() -> bool:
	return _phase == Phase.ASK and _menu != null and _menu.visible


func naming_screen() -> Gen2NamingScreenScreen:
	return _naming


func advance_frame() -> void:
	if _phase in [Phase.DONE, Phase.NAMING]:
		return
	if _text_box != null and _text_box.visible:
		_text_box.advance_frame()
	_refresh_yes_no()


## `GiveANickname_YesNo` is `PrintText` and then `YesNoBox`, so the box appears
## only once the text it stands under owes nothing: `_CaughtAskNicknameText`'s
## own `cont` is a press, and the menu is not up while the player is spending it.
func _refresh_yes_no() -> void:
	if _phase != Phase.ASK or _menu == null:
		return
	if _text_owes_frames():
		_menu.visible = false
		return
	if not _menu.visible:
		_draw_yes_no()


func _text_owes_frames() -> bool:
	return _text_box != null \
		and (_text_box.is_revealing() or _text_box.has_pages_left())


func handle_button(button: int) -> bool:
	match _phase:
		Phase.NAMING:
			return _naming.handle_button(button) if _naming != null else false
		Phase.ASK:
			if _text_owes_frames():
				if button == Gen2Button.A:
					_text_box.advance()
					_refresh_yes_no()
					return true
				return false
			match button:
				Gen2Button.UP, Gen2Button.DOWN:
					_yes = not _yes
					_draw_yes_no()
					return true
				Gen2Button.A:
					_answer_question(_yes)
					return true
				Gen2Button.B:
					## `YesNoBox` answers B as NO, which is `.skip_nickname`.
					_answer_question(false)
					return true
		Phase.AFTER_TEXT:
			if button != Gen2Button.A:
				return false
			if _text_box != null and (_text_box.is_revealing() or _text_box.has_pages_left()):
				_text_box.advance()
				return true
			_finish()
			return true
	return false


func _build() -> void:
	_menu = TextureRect.new()
	_menu.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.visible = false
	add_child(_menu)

	_text_box = Gen2TextBox.new()
	_text_box.driven = true
	_text_box.font = Gen2Font.from_data(_data)
	var options: Gen2Options = Gen2OptionsStore.current()
	_text_box.set_frame_style(options.textbox_frame)
	_text_box.reveal_speed = options.text_reveal_speed()
	_text_box.place_at_bottom()
	_text_box.visible = false
	add_child(_text_box)


func _draw_yes_no() -> void:
	if _menu_page == null:
		_menu_page = Gen2MenuPage.from_data(_data)
	if _menu_page == null:
		return
	var box: Gen2MenuBox = Gen2MenuBox.yes_no()
	var image: Image = _menu_page.render(box, ["YES", "NO"], 0 if _yes else 1)
	Gen2PicImage.show(_menu, image)
	_menu.position = Vector2(box.border_position() * TILE)
	_menu.visible = true


func _answer_question(yes: bool) -> void:
	_menu.visible = false
	if not yes:
		_after_question()
		return
	_naming = Gen2NamingScreenScreen.new()
	if not _naming.open(
		_data,
		Gen2WorldPartyHost.nickname_prompt(_species_name),
		Gen2NamingScreenScreen.KIND_MON
	):
		_naming = null
		_after_question()
		return
	if _species > 0:
		_naming.set_species_icon(_data, _species, _gender_sign)
	_text_box.visible = false
	_naming.closed.connect(_on_named)
	add_child(_naming)
	_phase = Phase.NAMING


## `InitName`, which keeps the species name when the entry came back empty.
func _on_named(entered: String) -> void:
	var chosen: String = entered.strip_edges()
	Gen2Screen.drop(_naming)
	_naming = null
	if not chosen.is_empty():
		_answer = chosen
	_after_question()


func _after_question() -> void:
	if _after_text_format.is_empty():
		_finish()
		return
	_phase = Phase.AFTER_TEXT
	_text_box.visible = true
	_text_box.show_text(_after_text_format % _answer)


func _finish() -> void:
	if _phase == Phase.DONE:
		return
	_phase = Phase.DONE
	if _text_box != null:
		_text_box.visible = false
	if _menu != null:
		_menu.visible = false
	named.emit(_answer)
	closed.emit()
