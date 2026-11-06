class_name Gen3FieldView
extends TextureRect # [Gen3FieldScreen] in a window: the pad at the GBA's frame rate. Requests with no screen yet print and move on.

const FRAME_SECONDS: float = 280896.0 / 16777216.0
const MAX_CATCH_UP: int = 2
const REPORTED: Array[String] = ["start_menu_action", "trainer_battle", "wild_battle", "mart", "field_special", "dofieldeffect",
	"script_error", "white_out"]

var screen: Gen3FieldScreen
var _clock: float = 0.0
var _held: Array[int] = []
var _image_texture: ImageTexture


static func open(game: GameData, group: int, number: int, at: Vector2i) -> Gen3FieldView: # Null where the player cannot stand.
	var field: Gen3FieldScreen = Gen3FieldScreen.open(game, group, number, at)
	if field == null:
		return null
	var view := Gen3FieldView.new()
	view.screen = field
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view._image_texture = ImageTexture.create_from_image(field.picture())
	view.texture = view._image_texture
	return view


func _process(delta: float) -> void:
	_clock += delta
	var frames: int = mini(int(_clock / FRAME_SECONDS), MAX_CATCH_UP)
	_clock = fposmod(_clock, FRAME_SECONDS)
	for frame: int in frames:
		advance()
	if frames > 0:
		_image_texture.update(screen.picture())


func advance() -> void:
	var held: Array[int] = []
	var pressed: Array[int] = []
	for button: int in PokeButton.ALL:
		if PokeButton.held(button):
			held.append(button)
			if button not in _held:
				pressed.append(button)
	_held = held
	for row: Dictionary in screen.frame(held, pressed):
		_settle(row)


func _settle(row: Dictionary) -> void:
	var kind: String = row["kind"]
	if kind not in REPORTED:
		return
	print("gen3 field: ", row)
	match kind:
		"start_menu_action":
			screen.return_to_start_menu(row["action"] != Gen3FieldStartMenu.SAVE and row["action"] != Gen3FieldStartMenu.RETIRE)
		"trainer_battle":
			screen.host.finish_battle(Gen3TrainerBattle.Outcome.WON)
		"wild_battle":
			screen.host.finish_wild_battle(Gen3TrainerBattle.Outcome.WON)
		"mart", "field_special", "dofieldeffect":
			screen.host.finish_wait()
