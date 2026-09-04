class_name Gen2Screen
extends Control

## A Game Boy Color screen: 160x144 pixels, scaled by a whole number to fit. What
## the game draws goes into a [SubViewport] blown up by an integer factor, since
## any other scale resamples an 8x8 tile into something that crawls when it moves.
## [method display_native] is a second layer behind it at window resolution, and
## [member expanded] widens the buffer instead of framing it while
## [method display] still centres a 160x144 rectangle in it. SCREEN FILL is read
## here rather than by each screen.

const WIDTH: int = 160
const HEIGHT: int = 144
## Loaded rather than preloaded: this script is the scene's own, and a preload
## of it here is a cycle. [method host_for] is the only caller and the loader
## caches after the first.
const SCENE_PATH: String = "res://game/render/gen2_screen.tscn"
## Below one screen pixel per hardware pixel the picture is halved rather than
## stepped, which is what puts a whole region in a window.
const MIN_SCALE: float = 0.25
## An expanded buffer grows by whole map blocks, so half the difference from the
## hardware screen is always a whole tile and the interface rectangle inside it
## lands on the grid every screen is laid out against.
const BUFFER_STEP: int = 32
## How far past the fitting scale a player may zoom out. Three steps reaches
## MIN_SCALE from a 1x window, and the same three from any other.
const ZOOM_OUT_STEPS: int = 3
## The most steps of one hardware pixel [member subpixel] will draw at. Each
## costs the whole buffer's fill rate, and six already turns a twelve-pixel jump
## into a two-pixel one.
const SUBPIXEL_STEPS_MAX: int = 6

## After a resize changes the factor. Nothing in the game should care.
signal scale_changed(factor: int)
## After the native layer's rectangle changes; a view drawn there sizes to this.
signal native_size_changed(size: Vector2i)
## After the drawn buffer changes size, in hardware pixels. A view that fills it
## reads this rather than assuming 160x144.
signal view_size_changed(size: Vector2i)
## After [member expanded] is switched, so the frame around the screen can hand
## it a different rectangle.
signal expanded_changed(expanded: bool)

var scale_factor: int = 1
## Whether the buffer grows to the control instead of being framed inside it.
var expanded: bool = false:
	set(value):
		if expanded == value:
			return
		expanded = value
		clip_contents = value
		expanded_changed.emit(value)
		_fit()
## Whole steps away from the fitting scale, positive towards the player.
var zoom_step: int = 0:
	get:
		return _zoom_step
	set(value):
		var stepped: int = clampi(value, _min_zoom_step(), _max_zoom_step())
		if _zoom_step == stepped:
			return
		_zoom_step = stepped
		_fit()

var _zoom_step: int = 0

## Whether the buffer is drawn at a whole multiple of its own resolution, so a
## view in it can place itself on a screen pixel rather than a hardware one.
## Everything keeps hardware-pixel coordinates: the canvas transform does the
## magnification the container used to and the picture is the same one.
var subpixel: bool = false:
	set(value):
		if subpixel == value:
			return
		subpixel = value
		_fit()

var _subpixel_steps: int = 1

## Whether the buffer outside the 160x144 rectangle is filled by this screen.
##
## On by default, and the reason a screen written without a thought for the
## window is still not letterboxed: a screen laid out in 160x144 has nothing of
## its own to put in a wider buffer, so the surround is its own field and the
## boxes it draws read as standing in a bigger one. Only a view that fills the
## whole buffer itself -- the map, a renderer staged on it -- turns this off.
var interface_masked: bool = true:
	set(value):
		if interface_masked == value:
			return
		interface_masked = value
		if _mask != null:
			_mask.visible = value

## What the surround is painted with: the shown picture's own field, so a screen
## carries its background out to the window edge wherever it is opened. Followed
## automatically from [method Gen2PicImage.show], the one place a screen hands a
## redrawn picture to the node that shows it; a screen with more art than the
## hardware framed hands [method set_backdrop] the real thing instead. Meaningless
## until something has said what it is: see [method has_field].
var surround_color: Color = Color.BLACK:
	set(value):
		var told: bool = _field_told
		_field_told = true
		if surround_color == value and told:
			return
		surround_color = value
		if _mask != null:
			_mask.queue_redraw()

## Whether anything has said what [member surround_color] is.
##
## "Not told yet" is not "told it is black", and the difference is a whole class
## of bug: a screen laid out over another -- a menu box over the map, a question
## over a picture -- has no field of its own, and painting the default over the
## surround cuts whatever it is standing on back to 160x144 with bars around it.
## An untold screen paints no surround at all.
var _field_told: bool = false
## Who told it, so the colour goes when that screen does and the next one starts
## from untold rather than inheriting a field it never drew.
var _field_source: Node = null

var _view_size: Vector2i = Vector2i(WIDTH, HEIGHT)
var _draw_scale: float = 1.0
## What [method set_backdrop] was given, drawn instead of [member surround_color]
## while it is the size of the buffer.
var _backdrop: ImageTexture = null
## Whose art it is, so it goes when that screen does.
var _backdrop_source: Node = null

@onready var _container: SubViewportContainer = %Container
@onready var _viewport: SubViewport = %Viewport
@onready var _native: Control = %Native
## The 160x144 rectangle interface is laid out in, moved to the middle of a
## wider buffer rather than the buffer's corner.
var _interface: Control = null
## Where [method display_content] puts a view laid out in the hardware's own
## 160x144: the same rectangle [member _interface] covers, below the mask.
var _content: Control = null
## Drawn between the content and the interface: see [member interface_masked].
var _mask: Control = null
## The cover a view switch is hidden behind, above both layers rather than
## inside either: see [method play_view_cover].
var _cover: Control = null
var _cover_cells: PackedByteArray = PackedByteArray()
## Each frame of the close, kept so the open is the same picture backwards.
var _cover_frames: Array[PackedByteArray] = []
var _cover_index: int = 0
var _cover_opening: bool = false
## What the black middle runs. Cleared as it is called, so a cover interrupted
## after that point cannot run it twice.
var _cover_rebuild: Callable = Callable()
var _cover_clock := Gen2WorldAnimation.FrameClock.new()


func _ready() -> void:
	# The viewport's size is the container's divided by the shrink factor, and
	# writing it directly is refused at runtime.
	resized.connect(_fit)
	_viewport.canvas_item_default_texture_filter = \
		Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_content = Control.new()
	_content.name = "Content"
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.size = Vector2(WIDTH, HEIGHT)
	_content.clip_contents = true
	_viewport.add_child(_content)
	_mask = Control.new()
	_mask.name = "Mask"
	_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask.visible = interface_masked
	_mask.draw.connect(_draw_mask)
	_viewport.add_child(_mask)
	_interface = Control.new()
	_interface.name = "Interface"
	_interface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interface.size = Vector2(WIDTH, HEIGHT)
	# The viewport used to be exactly the Game Boy screen and clipped anything
	# drawn past it, which is a slide-in's own edge. An expanded buffer no longer
	# does, so the rectangle it was clipped against does it instead.
	_interface.clip_contents = true
	_viewport.add_child(_interface)
	## Outside the viewport, because it covers a native renderer as well: the
	## viewport is composited over the native layer and a cover inside it would
	## leave a 3D view showing through.
	_cover = Control.new()
	_cover.name = "Cover"
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.visible = false
	_cover.draw.connect(_draw_cover)
	add_child(_cover)
	set_process(false)
	apply_screen_fill()
	_fit()


## Takes SCREEN FILL from the options file and applies it, for every screen rather
## than the two that remembered to ask. What a screen puts in the room is its own
## business; having the room is not. Public and idempotent because the option is
## the file's, so a caller that changed it after this entered the tree is obeyed.
func apply_screen_fill() -> void:
	expanded = Gen2OptionsStore.current().screen_fill


## Inside the screen, in hardware pixels: position it in the 160x144 space.
##
## Everything placed this way is interface, and sits above whatever
## [method display_content] put there, in the order it was placed.
func display(node: Node) -> void:
	_interface.add_child(node)


## Renderer content, in hardware pixels, kept below every node [method display]
## placed. A renderer rebuilt mid-screen would otherwise be appended after a live
## text box and paint over it. [param fills_buffer] is a view that draws the whole
## expanded surface and gets the buffer's own origin; a view that does not is laid
## out in the hardware's 160x144 like everything else here and is clipped to it,
## since in the buffer's corner it would sit off to one side with the boxes above
## it somewhere else.
func display_content(node: Node, fills_buffer: bool = false) -> void:
	if not fills_buffer:
		_content.add_child(node)
		return
	_viewport.add_child(node)
	_viewport.move_child(node, 0)


## On the layer behind, in [method native_size] window pixels; the hardware
## viewport is composited over it.
func display_native(node: Node) -> void:
	_native.add_child(node)


func native_size() -> Vector2i:
	return Vector2i((Vector2(_view_size) * _draw_scale).round())


## The drawn buffer in hardware pixels: 160x144 unless [member expanded].
func view_size() -> Vector2i:
	return _view_size



## The cartridge's own 160x144 screen, in the native layer's own pixels.
##
## A view on that layer is handed a rectangle and told nothing else, and every
## hardware-pixel number it is given -- the text box's, first -- has to land
## somewhere inside it. Framed, that mapping was the layer itself, since the
## rectangle was a whole multiple of 160x144. Expanded it is not, so the screen
## says where.
func screen_rect() -> Rect2i:
	var drawn: Vector2 = Vector2(WIDTH, HEIGHT) * _draw_scale
	var at: Vector2 = (_interface.position if _interface != null else Vector2.ZERO) \
		* _draw_scale
	return Rect2i(Vector2i(at.round()), Vector2i(drawn.round()))


## The largest whole number of window pixels per hardware pixel that fits.
## Public because [Gen2GameFrame] sizes the on-screen controller off it.
static func fit_factor(area: Vector2) -> int:
	return maxi(1, mini(int(area.x) / WIDTH, int(area.y) / HEIGHT))


## Screen pixels per hardware pixel at [param step] away from a fitting scale of
## [param fit]. Whole numbers on the way in; on the way out the last three steps
## halve instead, since one screen pixel per hardware pixel is as far as whole
## numbers go and a survey of a region needs to be further out than that.
static func scale_at(fit: int, step: int) -> float:
	var raw: int = maxi(fit, 1) + step
	if raw >= 1:
		return float(raw)
	return maxf(pow(0.5, float(1 - raw)), MIN_SCALE)


## One step of zoom, reported as the scale it settled on. Refused unless the
## screen is expanded: framed at 160x144 there is no more world to show and a
## step would only shrink the picture.
func step_zoom(delta: int) -> float:
	if not expanded:
		return _draw_scale
	zoom_step = zoom_step + delta
	return _draw_scale


func reset_zoom() -> void:
	zoom_step = 0


## Frees everything on screen, on both layers.
func clear() -> void:
	clear_backdrop()
	clear_field()
	for parent: Node in [_interface, _content, _native]:
		for child: Node in parent.get_children():
			drop(child)
	for child: Node in _viewport.get_children():
		if child != _interface and child != _content and child != _mask:
			drop(child)


## Takes a node off the screen now and frees it at the end of the frame.
## `queue_free` on its own only does the second half: the node stays in the tree,
## and drawn, until the frame it was dropped on is served, so a replacement added
## on the same frame is composited over its predecessor rather than instead of it.
## Inside a [Container] the two are laid out side by side. Static, and the one way
## a screen drops a child it is replacing.
static func drop(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var parent: Node = node.get_parent()
	if parent != null:
		parent.remove_child(node)
	node.queue_free()


## The same from an [method Node._exit_tree], where the removal above is refused.
## A parent is blocked from removing a child while it is already removing one, and
## every screen that hosts a view it does not own drops that view as it leaves:
## both hang off the same parent, so the parent is mid-removal when the drop
## arrives. Hiding is the whole of what the removal was for here, since nothing
## replaces a view whose screen is going.
static func drop_on_exit(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var item: CanvasItem = node as CanvasItem
	if item != null:
		item.hide()
	node.queue_free()


## The same for every child of [param parent], which is what a row list being
## rebuilt in place wants.
static func drop_children(parent: Node) -> void:
	if parent == null:
		return
	for child: Node in parent.get_children():
		drop(child)


func viewport() -> SubViewport:
	return _viewport


## The layer [method display] puts a screen on: the 160x144 rectangle, centred
## in the buffer. For a caller that has to know where in the viewport the
## interface sits, which is above whatever [method display_content] drew.
func interface_layer() -> Control:
	return _interface


## Where the hardware's own 160x144 sits inside the buffer, in buffer pixels.
##
## What a screen drawing a backdrop has to leave alone: the picture it hands
## [method set_backdrop] is the buffer's size, and this is the hole its own
## frame is already filling.
func interface_origin() -> Vector2i:
	return Vector2i(_interface.position) if _interface != null else Vector2i.ZERO


## The screen [param node] is drawn on, or null outside one.
##
## The walk rather than a stored reference: a screen is added to whichever host
## has one and freed by it, and neither end should have to hold the other.
##
## The outermost one, not the nearest, for a node that is somehow inside two.
static func owner_of(node: Node) -> Gen2Screen:
	var at: Node = node
	var found: Gen2Screen = null
	while at != null:
		if at is Gen2Screen:
			found = at
		at = at.get_parent()
	return found


## The screen a host's own 160x144 view belongs in: [param handed] is the one the
## opener gave it, failing that the one [param node] is already standing in,
## failing both a new one over [param node], which is what a host opened on its
## own really does need. A second screen over a window that already has one is
## what made the surround ambiguous: two viewports each pick their own scale and
## their own place for the hardware rectangle, so an overlay meant to sit on the
## map is drawn at a different size beside it. One window, one screen.
static func host_for(node: Control, handed: Gen2Screen = null) -> Gen2Screen:
	if handed != null:
		return handed
	var found: Gen2Screen = owner_of(node)
	if found != null:
		return found
	var scene: PackedScene = load(SCENE_PATH) as PackedScene
	var built: Gen2Screen = scene.instantiate() as Gen2Screen if scene != null else null
	if built == null:
		return null
	built.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	built.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(built)
	return built


## Real art for the surround, the size of [method view_size], from
## [param source]. A flat [member surround_color] is what a screen laid out in
## 160x144 has to offer; a screen whose background is more than one colour draws
## the whole buffer instead and hands it here. Only the surround is taken from it,
## so the hardware rectangle stays exactly the picture the cartridge drew. Dropped
## with [param source], so the screen after it does not inherit its sky.
func set_backdrop(source: Node, image: Image) -> void:
	if image == null or Vector2i(image.get_width(), image.get_height()) != _view_size:
		if _backdrop_source == source:
			clear_backdrop()
		return
	_backdrop = Gen2PicImage.refreshed_texture(_backdrop, image)
	if _backdrop_source != source:
		_backdrop_source = source
		if source != null and not source.tree_exited.is_connected(_on_backdrop_source_gone):
			source.tree_exited.connect(_on_backdrop_source_gone, CONNECT_ONE_SHOT)
	if _mask != null:
		_mask.queue_redraw()


func clear_backdrop() -> void:
	_backdrop = null
	_backdrop_source = null
	if _mask != null:
		_mask.queue_redraw()


func _on_backdrop_source_gone() -> void:
	clear_backdrop()


## The 160x144 field a screen stands on when it is a colour rather than a
## picture: a [ColorRect] that says what colour it is, so the screen around it
## carries the same one out to the window.
##
## [method Gen2PicImage.show] is that seam for a screen drawn as a picture and
## this is the other half of it. It reports on every draw rather than on a
## setter, so a fade that recolours the field takes the surround with it without
## the screen doing the fade knowing this exists.
class Field extends ColorRect:
	## Quantised the way a picture beside it is: a 15-bit colour kept as a float
	## is truncated on its way into an image and rounded on its way through a
	## ColorRect, so a surround and the screen over it can be a unit apart in one
	## channel. `SuperPalettes`' own white is one such colour.
	static func create(of_color: Color) -> Field:
		var out := Field.new()
		out.color = Gen2PicImage.quantized(PackedColorArray([of_color]))[0]
		out.mouse_filter = Control.MOUSE_FILTER_IGNORE
		out.size = Vector2(WIDTH, HEIGHT)
		return out

	func _draw() -> void:
		Gen2Screen.note_field(self, color)


## Takes the surround's colour from a field a screen has just drawn.
static func note_field(target: CanvasItem, field: Color) -> void:
	if target == null or field.a <= 0.0:
		return
	if Vector2i(target.get_rect().size) != Vector2i(WIDTH, HEIGHT):
		return
	var screen: Gen2Screen = owner_of(target)
	if screen == null or not screen.expanded:
		return
	screen._take_field(target, field)


## Takes the surround's colour from a picture a screen has just drawn. Called from
## [method Gen2PicImage.show] rather than by each screen: that is the one place a
## redrawn picture reaches the node showing it, so the surround follows a palette
## fade and a screen swap without either knowing this exists. Only a picture the
## size of the hardware screen counts, and only one opaque everywhere it is
## sampled. Whether the surround is showing is deliberately not a condition: the
## mask goes up on the same frame in the other order, so a colour recorded only
## while it was up would be the colour of the screen before this one.
static func note_picture(target: CanvasItem, image: Image) -> void:
	if target == null or image == null:
		return
	if image.get_width() != WIDTH or image.get_height() != HEIGHT:
		return
	var screen: Gen2Screen = owner_of(target)
	if screen == null or not screen.expanded:
		return
	var field: Color = Gen2PicImage.field_color(image)
	if field.a <= 0.0:
		return
	screen._take_field(target, field)


## Whether anything has said what [member surround_color] is. False leaves the
## surround unpainted: see [member _field_told].
func has_field() -> bool:
	return _field_told


## Records [param field] and who drew it. A field belongs to one screen at a
## time, so the last opaque one wins and the colour is forgotten when the node
## that drew it goes.
func _take_field(source: Node, field: Color) -> void:
	surround_color = field
	if _field_source == source:
		return
	_field_source = source
	if source == null:
		return
	var gone: Callable = _on_field_source_gone.bind(source)
	if not source.tree_exited.is_connected(gone):
		source.tree_exited.connect(gone, CONNECT_ONE_SHOT)


func _on_field_source_gone(source: Node) -> void:
	if _field_source != source:
		return
	clear_field()


## Forgets what the surround is, so a screen taken off leaves the next one
## untold rather than standing on its colour.
func clear_field() -> void:
	_field_source = null
	if not _field_told:
		return
	_field_told = false
	if _mask != null:
		_mask.queue_redraw()


## Hides a view switch behind the cartridge's own way of going black. Building a
## renderer is a stall, and nothing on one thread can animate over its own freeze,
## but the middle of a wipe is a still picture: the close is spent on the renderer
## still running, [param rebuild] is called on the frame the screen is fully
## black, and the open is spent on the one it built.
## `StartTrainerBattle_SpeckleToBlack` is the pattern, so the switch reads as the
## game's own and costs no art. Around the switch rather than at one caller,
## because every way of choosing a view reaches [signal Gen2ModHost.view_changed].
func play_view_cover(rebuild: Callable) -> void:
	if not _can_animate_cover():
		if rebuild.is_valid():
			rebuild.call()
		return
	## A second switch before the first has finished: the first one's rebuild is
	## owed either way, and a cover restarted from black has nothing to hide.
	_run_cover_rebuild()
	_cover_rebuild = rebuild
	_cover_frames = _cover_close_frames()
	_cover_index = 0
	_cover_opening = false
	_cover_clock.reset()
	_cover_cells = _cover_frames[0]
	_cover.visible = true
	_cover.queue_redraw()
	set_process(true)


func view_cover_active() -> bool:
	return _cover != null and _cover.visible


## Spends the whole cover now, for a caller that wants the switch done rather
## than shown: a tool taking a photograph, or a test.
func settle_view_cover() -> void:
	_run_cover_rebuild()
	_cover_frames = []
	_cover_cells = PackedByteArray()
	_cover_index = 0
	_cover_opening = false
	if _cover != null:
		_cover.visible = false
	set_process(false)


## Spends [param frames] hardware frames of a running cover, for a tool
## photographing the wipe itself rather than what it uncovers. The clock stops
## with it: a driver that steps the cover by hand owns its pace, or the frames
## it spends taking the picture would finish the wipe underneath it.
func step_view_cover(frames: int) -> void:
	set_process(false)
	for _frame: int in frames:
		if not view_cover_active():
			return
		_advance_cover()


func _process(delta: float) -> void:
	if not view_cover_active():
		set_process(false)
		return
	for _frame: int in _cover_clock.tick(delta):
		_advance_cover()
		if not view_cover_active():
			return


## One hardware frame of the cover: down the close, the rebuild on the black
## frame, then back up the same frames.
func _advance_cover() -> void:
	if not _cover_opening:
		_cover_index += 1
		if _cover_index >= _cover_frames.size():
			_run_cover_rebuild()
			_cover_opening = true
			_cover_index = _cover_frames.size() - 1
	else:
		_cover_index -= 1
		if _cover_index < 0:
			settle_view_cover()
			return
	_cover_cells = _cover_frames[_cover_index]
	_cover.queue_redraw()


func _run_cover_rebuild() -> void:
	if not _cover_rebuild.is_valid():
		return
	var rebuild: Callable = _cover_rebuild
	_cover_rebuild = Callable()
	rebuild.call()


## The close, frame by frame, ending on the screen fully black.
func _cover_close_frames() -> Array[PackedByteArray]:
	var out: Array[PackedByteArray] = []
	var outro: Gen2BattleTransition = Gen2BattleTransition.create_outro()
	out.append(outro.cells().duplicate())
	while outro.advance_frame():
		out.append(outro.cells().duplicate())
	return out


func _can_animate_cover() -> bool:
	return is_inside_tree() and not Engine.is_editor_hint() 		and DisplayServer.get_name() != "headless"


## The transition's twenty by eighteen cells over the whole control, letterbox
## included: what it covers is the switch, not the hardware screen, and a
## renderer drawing at window resolution has no 160x144 rectangle to stop at.
func _draw_cover() -> void:
	if _cover_cells.is_empty():
		return
	var cell := Vector2(
		size.x / float(Gen2BattleTransition.COLUMNS),
		size.y / float(Gen2BattleTransition.ROWS),
	)
	for row: int in Gen2BattleTransition.ROWS:
		for column: int in Gen2BattleTransition.COLUMNS:
			if _cover_cells[row * Gen2BattleTransition.COLUMNS + column] 				== Gen2BattleTransition.CELL_NONE:
				continue
			_cover.draw_rect(
				Rect2(
					Vector2(float(column) * cell.x, float(row) * cell.y),
					## Rounded up, so two cells meet rather than leave a seam.
					Vector2(ceilf(cell.x), ceilf(cell.y))
				),
				Color.BLACK, true
			)


## The surround, drawn rather than left empty: four rectangles around the 160x144
## the interface is laid out in. Not a filled surface, because the middle is not
## always the interface's -- a battle transition is the renderer's own screen and
## has to stay visible inside it.
##
## A backdrop the size of the buffer is drawn through the same four bands, so a
## screen with real art out there paints it and a screen without paints its own
## field colour.
func _draw_mask() -> void:
	var inside := Rect2(_interface.position, Vector2(WIDTH, HEIGHT))
	var whole := Vector2(_view_size)
	var backdrop: bool = _backdrop != null \
		and _backdrop.get_size() == Vector2(whole)
	# Nothing rather than the default: an untold screen is one standing over
	# another, and a band of black is what cut the map back to 160x144.
	if not backdrop and not _field_told:
		return
	for band: Rect2 in [
		Rect2(Vector2.ZERO, Vector2(whole.x, inside.position.y)),
		Rect2(Vector2(0.0, inside.end.y), Vector2(whole.x, whole.y - inside.end.y)),
		Rect2(Vector2(0.0, inside.position.y), Vector2(inside.position.x, inside.size.y)),
		Rect2(
			Vector2(inside.end.x, inside.position.y),
			Vector2(whole.x - inside.end.x, inside.size.y),
		),
	]:
		if band.size.x <= 0.0 or band.size.y <= 0.0:
			continue
		if backdrop:
			_mask.draw_texture_rect_region(_backdrop, band, band)
		else:
			_mask.draw_rect(band, surround_color, true)


func _min_zoom_step() -> int:
	return 1 - fit_factor(size) - ZOOM_OUT_STEPS


func _max_zoom_step() -> int:
	return fit_factor(size)


## The buffer a scale of [param at_scale] needs to cover [param area], rounded up
## to a whole block on each axis past the hardware's own screen so the 160x144
## interface rectangle lands on a whole tile.
static func buffer_for(area: Vector2, at_scale: float) -> Vector2i:
	var wanted := Vector2i(
		maxi(ceili(area.x / maxf(at_scale, MIN_SCALE)), WIDTH),
		maxi(ceili(area.y / maxf(at_scale, MIN_SCALE)), HEIGHT),
	)
	return Vector2i(
		WIDTH + ceili(float(wanted.x - WIDTH) / float(BUFFER_STEP)) * BUFFER_STEP,
		HEIGHT + ceili(float(wanted.y - HEIGHT) / float(BUFFER_STEP)) * BUFFER_STEP,
	)


## The finest step [param whole] divides into, the container shrinking the buffer
## by a whole number and [constant SUBPIXEL_STEPS_MAX] being the ceiling. One with
## no divisor under it is a prime, and only a small window asks for those.
static func _subpixel_for(whole: int) -> int:
	for steps: int in range(mini(whole, SUBPIXEL_STEPS_MAX), 1, -1):
		if whole % steps == 0:
			return steps
	return whole


func subpixel_steps() -> int:
	return _subpixel_steps


func _fit() -> void:
	var factor: int = fit_factor(size)
	# A resize moves the fitting scale, so a step chosen against the old one can
	# fall outside the ladder. Clamped on the field rather than through the
	# property, which would come straight back into this.
	_zoom_step = clampi(_zoom_step, _min_zoom_step(), _max_zoom_step())
	var scale_now: float = scale_at(factor, _zoom_step) if expanded else float(factor)
	var view: Vector2i = buffer_for(size, scale_now) if expanded \
		else Vector2i(WIDTH, HEIGHT)
	var drawn: Vector2 = Vector2(view) * scale_now

	# A whole-number scale keeps the proven shrink path, where the container is
	# the drawn size and the viewport is that divided by what the canvas
	# transform does not magnify. Below one the shrink cannot express the ratio,
	# so the container is the buffer and the texture is scaled down instead.
	var steps: int = 1
	if scale_now >= 1.0 and is_equal_approx(scale_now, roundf(scale_now)):
		var whole: int = int(roundf(scale_now))
		steps = _subpixel_for(whole) if subpixel else 1
		_container.stretch_shrink = whole / steps
		_container.scale = Vector2.ONE
		_container.size = drawn
	else:
		_container.stretch_shrink = 1
		_container.size = Vector2(view)
		_container.scale = Vector2(scale_now, scale_now)
	_subpixel_steps = steps
	_viewport.canvas_transform = Transform2D().scaled(Vector2(steps, steps))
	# Nearest is what keeps a hardware pixel a square block of screen pixels, in
	# here and in the viewport that [member subpixel] magnifies inside, and it is
	# the wrong answer in the one place the picture is made smaller rather than
	# larger: dropping three pixels in four turns a tree wall into moire.
	_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if scale_now >= 1.0 \
		else CanvasItem.TEXTURE_FILTER_LINEAR
	# Centred rather than anchored: an uneven margin is visible.
	_container.position = ((size - drawn) * 0.5).floor()
	_native.size = drawn
	_native.position = _container.position
	if _mask != null:
		_mask.size = Vector2(view)
		_mask.queue_redraw()
	if _interface != null:
		_interface.position = ((Vector2(view - Vector2i(WIDTH, HEIGHT)) * 0.5)
			/ float(PokeTiles.TILE_WIDTH)).floor() * float(PokeTiles.TILE_WIDTH)
		_interface.size = Vector2(WIDTH, HEIGHT)
		_content.position = _interface.position
		_content.size = _interface.size

	_draw_scale = scale_now
	if view != _view_size:
		_view_size = view
		view_size_changed.emit(view)
	if factor != scale_factor:
		scale_factor = factor
		scale_changed.emit(factor)
	native_size_changed.emit(Vector2i(drawn))
