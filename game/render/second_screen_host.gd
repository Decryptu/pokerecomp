class_name Gen2SecondScreenHost
extends Node

## Puts a [Gen2SecondScreen] on a real second display, and reports touches back.
##
## There are two ways a second panel is reached and this owns both, because the
## screen above must not know which one it got:
##
## | Backend | Where it runs | How a frame arrives |
## |---|---|---|
## | `panel` | A handheld whose lower display is a secondary Android display | the platform plugin, one bitmap per drawn frame |
## | `window` | Any desktop | a second [Window] holding the screen itself |
##
## The panel backend copies pixels rather than sharing a rendering context, and
## that is the whole reason [Gen2SecondScreen] draws in hardware pixels instead
## of the panel's own: a copy of a 206x180 picture is 148 KB and one of a
## 1240x1080 panel is 5.4 MB, and the far side can scale a bitmap by a whole
## number for nothing. Sharing a context instead would mean a Vulkan swapchain
## per display, which this project cannot have while it renders through the
## compatibility backend.
##
## The plugin is named by [constant PLUGIN], and is absent on every platform but
## Android; [method available] is false there and nothing above this cares.

## The Android plugin singleton. Its contract is four calls and three signals:
##
## - `open() -> bool`, `close()`, `panel_size() -> PackedInt32Array` of two
## - `present(pixels: PackedByteArray, width: int, height: int)`
## - `panel_connected(width, height)`, `panel_disconnected()`,
##   `panel_touched(x, y)` in the presented picture's own pixels
## Not the screen's own class name: a plugin singleton is a global identifier in
## GDScript, and one that collided would shadow [Gen2SecondScreen] on Android
## and nowhere else.
const PLUGIN: String = "Gen2SecondScreenPanel"

## The panel a `window` backend pretends to be, so what is looked at on a desktop
## is the canvas a real lower display would ask for rather than the smallest one
## this screen can draw. An AYN Thor's is 1240x1080; a handheld with another one
## is a whole scale away and the layout does not change.
const WINDOW_PANEL := Vector2i(1240, 1080)
## Four whole pixels per hardware pixel, which fits the window on an ordinary
## laptop. The panel itself gets six.
const WINDOW_SCALE: int = 4

## The panel is a still page most of the time and a slow animation the rest, so
## it is copied at half the host's rate rather than every drawn frame. The
## trainer card's colon and the party's icons are the only things on it that
## move, and both are slower than this.
const PANEL_HZ: float = 30.0

const BACKEND_NONE: StringName = &"none"
const BACKEND_PANEL: StringName = &"panel"
const BACKEND_WINDOW: StringName = &"window"

var backend: StringName = BACKEND_NONE

var _view: Gen2SecondScreen = null
var _plugin: Object = null
var _window: Window = null
var _since_present: float = 0.0


## Attaches [param view] to whatever second display this build can reach, or
## answers null when there is none.
##
## [param mode] is [member Gen2Options.second_screen]. The view is not built
## here: the world owns it, because it mirrors the world, and this only decides
## where it is drawn.
static func attach(view: Gen2SecondScreen, mode: StringName = &"auto") -> Gen2SecondScreenHost:
	if view == null or mode == &"off":
		return null
	var host := Gen2SecondScreenHost.new()
	host.name = "SecondScreenHost"
	host._view = view
	if host._attach_panel():
		return host
	if mode == &"window" and host._attach_window():
		return host
	host.free()
	return null


## Whether this build can reach a lower panel at all, which is the plugin being
## present and answering with a size. False on every desktop and on an Android
## device with one display.
static func available() -> bool:
	var plugin: Object = _singleton()
	if plugin == null:
		return false
	return _plugin_panel_size(plugin) != Vector2i.ZERO


static func _singleton() -> Object:
	return Engine.get_singleton(PLUGIN) if Engine.has_singleton(PLUGIN) else null


## The plugin answers a pair of integers rather than a [Vector2i]: an Android
## plugin marshals primitives and arrays, and no engine vector type among them.
## A plugin singleton is asked rather than interrogated: `has_method` answers
## false on a [JNISingleton] whose calls all work, so a guard written that way
## turns every device with a panel into a device without one.
static func _plugin_panel_size(plugin: Object) -> Vector2i:
	if plugin == null:
		return Vector2i.ZERO
	var size: Variant = plugin.call("panel_size")
	## Either packed or plain: which of the two an `int[]` arrives as is the
	## platform's business, and a caller that insists on one gets nothing on a
	## device that sends the other.
	if size is PackedInt32Array:
		var packed: PackedInt32Array = size
		return Vector2i(packed[0], packed[1]) if packed.size() >= 2 else Vector2i.ZERO
	if size is Array:
		var plain: Array = size
		return Vector2i(int(plain[0]), int(plain[1])) if plain.size() >= 2 else Vector2i.ZERO
	return Vector2i.ZERO


## The panel this is drawn on, in its own pixels, or zero for a `window` backend
## sized by the desktop.
func panel_size() -> Vector2i:
	if backend == BACKEND_PANEL:
		return _plugin_panel_size(_plugin)
	if _window != null:
		return _window.size
	return Vector2i.ZERO


func close() -> void:
	if _plugin != null:
		_plugin.call("close")
	_plugin = null
	if _window != null:
		## The view came from the world's own tree and goes back to it, so
		## closing the window does not take the screen with it.
		if _view != null and _view.get_parent() == _window:
			_window.remove_child(_view)
		_window.queue_free()
		_window = null
	backend = BACKEND_NONE
	set_process(false)


func _exit_tree() -> void:
	close()


func _attach_panel() -> bool:
	_plugin = _singleton()
	var size: Vector2i = _plugin_panel_size(_plugin)
	if size == Vector2i.ZERO:
		_plugin = null
		return false
	if _plugin.has_signal("panel_touched"):
		_plugin.connect("panel_touched", _on_panel_touched)
	if _plugin.has_signal("panel_disconnected"):
		_plugin.connect("panel_disconnected", _on_panel_disconnected)
	if not bool(_plugin.call("open")):
		_plugin = null
		return false
	backend = BACKEND_PANEL
	_view.canvas_size = canvas_for(size)
	## The control draws nothing on the game's own window: the panel is fed by
	## the viewport inside it, which has a size of its own and keeps drawing.
	_view.position = Vector2.ZERO
	_view.size = Vector2.ZERO
	set_process(true)
	return true


func _attach_window() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	_view.canvas_size = canvas_for(WINDOW_PANEL)
	var canvas: Vector2i = _view.canvas_size
	_window = Window.new()
	_window.title = "pokerecomp: second screen"
	_window.size = canvas * WINDOW_SCALE
	_window.content_scale_size = canvas
	_window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	## A machine with a second monitor puts it there, which is the case this
	## backend is really for; one without gets an ordinary window beside the game.
	if DisplayServer.get_screen_count() > 1:
		_window.current_screen = 1
	add_child(_window)
	if _view.get_parent() != null:
		_view.get_parent().remove_child(_view)
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_window.add_child(_view)
	backend = BACKEND_WINDOW
	set_process(false)
	return true


## The largest hardware-pixel canvas that fills [param panel] at a whole scale.
##
## Whole numbers only, for the reason [Gen2Screen] gives: a hardware pixel drawn
## as 6.43 screen pixels crawls. The leftover is a bar the far side fills with
## the field colour, and it is never more than one scale factor wide.
static func canvas_for(panel: Vector2i) -> Vector2i:
	var minimum: Vector2i = Gen2SecondScreen.CANVAS_MIN
	if panel.x < minimum.x or panel.y < minimum.y:
		return minimum
	var scale: int = maxi(mini(panel.x / minimum.x, panel.y / minimum.y), 1)
	return Vector2i(maxi(panel.x / scale, minimum.x), maxi(panel.y / scale, minimum.y))


func _process(delta: float) -> void:
	if backend != BACKEND_PANEL or _view == null or _plugin == null:
		return
	_since_present += delta
	if _since_present < 1.0 / PANEL_HZ:
		return
	_since_present = 0.0
	var picture: Image = _view.frame()
	if picture == null:
		return
	if picture.get_format() != Image.FORMAT_RGBA8:
		picture.convert(Image.FORMAT_RGBA8)
	_plugin.call(
		"present", picture.get_data(), picture.get_width(), picture.get_height()
	)


## A touch reported by the panel, already in the presented picture's own pixels:
## the plugin knows the scale it drew with and this side never has to.
func _on_panel_touched(x: float, y: float) -> void:
	if _view != null:
		_view.touch(Vector2(x, y))


func _on_panel_disconnected() -> void:
	close()
