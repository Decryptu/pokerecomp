class_name Gen2LauncherSheet
extends Control

## A modal card over the launcher, used instead of an OS dialog: Godot's own open
## a second window with its own decorations, which no amount of theming makes
## belong here and which mobile has no place to put. Sized against the window
## rather than against its own content, because a [CenterContainer] grants a card
## its minimum size whatever that is and a sheet with more rows than the window is
## tall hung its actions off the bottom edge. The body scrolls and the card is
## capped, so the title, the actions and the way out are always on screen.

signal closed

## The widest a sheet is drawn, and how much window is left around it when the
## window is narrower or shorter than that.
const MAX_WIDTH: float = 420.0
const MARGIN: float = 24.0

var _theme: Gen2LauncherTheme = null
var _body: VBoxContainer = null
var _actions: VBoxContainer = null
var _dismiss: Gen2LauncherHint = null
var _card: Gen2LauncherCard = null
var _scroll: Gen2LauncherScroll = null
## The card's own chrome: the title row, the actions row and the padding, which
## is what the body has to fit inside the window WITHOUT.
var _column: VBoxContainer = null
## What had focus before the sheet opened, so closing puts it back rather than
## stranding a pad with nothing selected.
var _restore_focus: Control = null


static func create(palette: Gen2LauncherTheme, title: String) -> Gen2LauncherSheet:
	var sheet := Gen2LauncherSheet.new()
	sheet._theme = palette
	sheet._build(title)
	return sheet


func _build(title: String) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.34 if not _theme.is_dark() else 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			close()
	)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	_card = Gen2LauncherCard.floating(_theme, Gen2LauncherTheme.RADIUS_LG, 26, 34)
	centre.add_child(_card)

	_column = Gen2LauncherUI.column(Gen2LauncherUI.GAP_MD)
	_card.add_child(_column)

	var heading: Label = Gen2LauncherUI.title(_theme, title)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(heading)

	_scroll = Gen2LauncherScroll.create()
	_column.add_child(_scroll)
	_body = Gen2LauncherUI.column(Gen2LauncherUI.GAP_MD)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.content().add_child(_body)

	# The body scrolls and so sits inside the pane's ring inset; the actions do
	# not, and would otherwise be that much wider than every row above them.
	_actions = Gen2LauncherUI.column(Gen2LauncherUI.GAP_MD)
	_column.add_child(_inset(_actions))

	# A cross in the corner never says with what, which is the pad's question.
	_dismiss = Gen2LauncherHint.create(_theme, &"ui_cancel", "Close")
	_dismiss.set_focusable(true)
	_dismiss.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dismiss.pressed.connect(close)
	_column.add_child(_inset(_dismiss))

	## The window, and the rows themselves: a sheet is filled after it is built,
	## so the fit is redone when the body grows rather than only when it opens.
	add_to_group(Gen2FocusGuard.MODAL_GROUP)
	resized.connect(_fit)
	_scroll.content().minimum_size_changed.connect(_fit)
	_fit()


## Fits the card inside the window: the width first, then whatever height is
## left for the rows once the title and the actions have taken theirs. The scroll
## pane asks for exactly its content while that fits, so a sheet small enough to
## fit is drawn exactly as it was before it could scroll.
func _fit() -> void:
	if _card == null or _scroll == null or size == Vector2.ZERO:
		return
	var width: float = minf(MAX_WIDTH, size.x - MARGIN * 2.0)
	_card.custom_minimum_size.x = maxf(width, 0.0)
	var chrome: float = _card.get_combined_minimum_size().y - _scroll.custom_minimum_size.y
	var room: float = size.y - MARGIN * 2.0 - chrome
	# The pane's content, not the rows: it keeps room for a ring around them, and
	# measuring the rows alone left the pane short by it.
	_scroll.custom_minimum_size.y = maxf(
		minf(_scroll.content().get_combined_minimum_size().y, room), 0.0
	)


func _inset(control: Control) -> MarginContainer:
	var holder := MarginContainer.new()
	for side: String in ["left", "right"]:
		holder.add_theme_constant_override("margin_" + side, Gen2LauncherScroll.RING_INSET)
	holder.add_child(control)
	return holder


func body() -> VBoxContainer:
	return _body


func add_action(button: Control) -> void:
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actions.add_child(button)


## Opens over [param host]. The card scales rather than moves, because the
## [CenterContainer] holding it owns its position and would undo a slide.
func open(host: Control) -> void:
	var viewport: Viewport = host.get_viewport()
	_restore_focus = viewport.gui_get_focus_owner() if viewport != null else null
	host.add_child(self)
	modulate.a = 0.0
	await get_tree().process_frame
	# The sheet is modal, so focus goes into it whatever the player is using: a
	# pad needs it to navigate and a keyboard needs it for the cancel below.
	var first: Control = _first_focus()
	if first != null:
		first.grab_focus()
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2(0.96, 0.96)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.14)
	tween.tween_property(_card, "scale", Vector2.ONE, 0.22).set_ease(
		Tween.EASE_OUT
	).set_trans(Tween.TRANS_BACK)


## Where an opened sheet puts the pad. A subclass with a better answer than the
## first control on the card overrides this.
func _first_focus() -> Control:
	return Gen2FocusGuard.first_focusable(_card)


func close() -> void:
	if _restore_focus != null and is_instance_valid(_restore_focus):
		_restore_focus.grab_focus()
	closed.emit()
	Gen2Screen.drop(self)


## Unhandled rather than [method Control._gui_input], which only ever reaches the
## focused control: the sheet itself never holds focus, so a cancel pressed on a
## button inside it would have gone nowhere.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Handled on the viewport: the hint bar listens for the same press.
		get_viewport().set_input_as_handled()
		close()
