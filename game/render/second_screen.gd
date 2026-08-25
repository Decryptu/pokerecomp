class_name Gen2SecondScreen
extends Control

## The lower display: one of the game's own pages, with a row of tabs under it.
##
## Every page here is the screen the START menu opens, built and drawn exactly
## as the overworld builds it, and then never handed a button. That is what
## "read only" means in this file: the pages are not copies with a viewer's
## shortcuts taken out, they are the same nodes with no input routed to them, so
## a page cannot drift from the one the player sees on the top screen and cannot
## change anything either.
##
## The tab row is the one thing that takes a touch. It moves the cursor in
## [Gen2SecondScreenTabs] and nothing else; which tabs exist at all is the START
## menu's own gate, so a page appears on the frame the cartridge would have
## offered it and not before.
##
## Everything is drawn inside a [SubViewport] the size of [member canvas_size],
## in hardware pixels, because that is what a host has to hand a display: a
## second panel is reached by a bitmap and a scale factor, and a canvas of a few
## hundred pixels a side is a copy small enough to make sixty times a second
## where the panel's own 1240x1080 is not.

## The page, which is the cartridge's own screen and never another size.
const PAGE_SIZE := Vector2i(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
## The underline that says which tab is open: two rows at the foot of the tab
## row's interior, inset so two neighbouring tabs never touch. Drawn in the
## frame's own ink, because the interior is the same white every menu box has.
const UNDERLINE_HEIGHT: int = 2
const UNDERLINE_INSET: int = 4
## The shortest tab row that still fits a border, the tallest icon and that
## underline. A host with a taller panel gets a taller row and the icons centre
## in it. Two tiles of border, because a menu box has one at each end.
const MIN_TAB_HEIGHT: int = Gen2Font.TILE * 2 + Gen2SecondScreenTabs.ICON_MAX
const CANVAS_MIN := Vector2i(PAGE_SIZE.x, PAGE_SIZE.y + MIN_TAB_HEIGHT)

## The two colours every text box in the game is drawn with, and the two the tab
## row is drawn with for the same reason: it is a menu box, so it is white with
## the frame the player chose around it.
const INK: int = 3
const PAPER: int = 0
const FIELD_COLOR := Color(0.0, 0.0, 0.0, 1.0)

## What the panel shows with no world on it, drawn in the launcher's own
## language rather than the cartridge's: an empty cartridge silhouette, the
## project's name and a line saying nothing is running.
##
## The launcher measures in points, so the design is written in these units and
## drawn at whatever whole multiple of them the panel is; a launcher unit is
## about a point at [constant IDLE_UNITS] on a handheld's lower display.
const IDLE_UNITS: int = 540
## The silhouette's height in launcher units, and the panel this screen assumes
## before a host has said what it really is.
const IDLE_CARTRIDGE: float = 200.0
const IDLE_PANEL := Vector2i(1240, 1080)
## The line under the name, which is the whole of what this page says.
const IDLE_LINE: String = "No game running"

## Emitted after the shown page changes, so a host knows a still picture is worth
## sending again even when nothing is animating.
signal page_changed(kind: StringName)
## Emitted after the drawn surface has been rebuilt. A host that only copies a
## still picture when it changes listens to this; one copying an animating page
## every tick does not need it.
signal redrawn()

## The whole drawn surface, in hardware pixels. Never smaller than
## [constant CANVAS_MIN]: the page is a fixed 160x144 and the tab row has to hold
## an icon.
## The display this is shown on, in its own pixels. Only the idle screen is drawn
## at this size: it is launcher UI rather than hardware pixels, and type laid out
## in a 206-pixel canvas and blown up six times is unreadable.
var panel_size: Vector2i = IDLE_PANEL:
	set(value):
		var clamped := Vector2i(maxi(value.x, 64), maxi(value.y, 64))
		if panel_size == clamped:
			return
		panel_size = clamped
		if _idle != null:
			_build_page()
		else:
			_relayout()

var canvas_size: Vector2i = CANVAS_MIN:
	set(value):
		var clamped := Vector2i(
			maxi(value.x, CANVAS_MIN.x), maxi(value.y, CANVAS_MIN.y)
		)
		if canvas_size == clamped:
			return
		canvas_size = clamped
		_relayout()

var _data: GameData = null
var _world: Gen2WorldAPI = null
var _save: Gen2SaveData = null
var _tabs := Gen2SecondScreenTabs.new()

var _viewport: SubViewport = null
var _screen: Gen2Screen = null
var _strip: Control = null
## The row's own box: the cartridge's frame around the white every menu box has,
## redrawn when the row changes rather than every frame.
var _strip_art: TextureRect = null
## The launcher's own page, kept so a panel resized after it was built is filled
## by it.
var _idle: Control = null
## The page on screen, whichever of the cartridge's screens it is, and which tab
## built it. Kept so a rebuild is skipped when the answer would be the same node.
var _page: Node = null
var _page_kind: StringName = &""
## The tab row's icons, one [TextureRect] per tab, rebuilt with the tab set.
var _icons: Array[TextureRect] = []
## What [method _gate] answered when the row was last built.
var _gate_read: String = ""
## The cartridge's glyphs, for the frame around the tab row.
var _glyphs: Gen2Font = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	## A caller may hand over the world before this is in the tree, which is what
	## a tool building the screen in `_initialize` does. The world is kept either
	## way and read here once there is something to draw it into.
	refresh()


## The world this mirrors. Called once by the host that owns the overworld; every
## later change is picked up by [method refresh].
func set_world(data: GameData, world: Gen2WorldAPI, save: Gen2SaveData) -> void:
	if data != _data:
		_glyphs = null
	_data = data
	_world = world
	_save = save
	## A world handed over, or taken away, is not something the gate string can
	## express on its own: an absent world answers the same empty string as the
	## last absent one did.
	_gate_read = "<unread>"
	refresh()


## Re-reads the world: which tabs are open, and whether the page on screen is
## still the one the cursor names.
##
## Called every hardware frame and does nothing on almost all of them: the gates
## are three numbers and the row's one live picture is the party's lead, so the
## whole question is a short string. Rebuilding the START menu here instead would
## allocate one per frame for an answer that changes about six times a game.
func refresh() -> void:
	if _viewport == null:
		return
	var gate: String = _gate()
	if gate == _gate_read:
		return
	_gate_read = gate
	var chosen: StringName = _tabs.selected_kind()
	_tabs = Gen2SecondScreenTabs.from_world(_world)
	if not chosen.is_empty():
		_tabs.select(chosen)
	_build_row()
	if _tabs.selected_kind() != _page_kind:
		_build_page()
	else:
		_redraw_strip()


## Everything the tab row is a function of: the three gates `SetUpMenuItems`
## reads, and the lead the #MON tab wears.
func _gate() -> String:
	if _world == null or _world.state == null:
		return ""
	return "%d|%d|%d|%d|%d" % [
		int(_world.party_summary().get("count", 0)),
		int(_world.state.is_engine_flag_active(Gen2WorldStartMenu.ENGINE_POKEDEX)),
		int(_world.state.is_engine_flag_active(Gen2WorldStartMenu.ENGINE_POKEGEAR)),
		_lead_species(),
		int(_lead_is_egg()),
	]


## Which tab a tap at [param at] landed on, counting from zero, or -1 for a tap
## that missed the row.
##
## Static and pure, so where a touch lands is asserted without a display: the row
## is the only part of this screen that takes one.
static func tab_index_at(at: Vector2, canvas: Vector2i, count: int) -> int:
	if count <= 0 or canvas.x <= 0:
		return -1
	if at.y < float(PAGE_SIZE.y) or at.y >= float(canvas.y):
		return -1
	if at.x < 0.0 or at.x >= float(canvas.x):
		return -1
	## The inverse of [method tab_cell]'s own division rather than a second one:
	## a cell starts at `index * width / count`, so the tab a pixel is in is the
	## largest index whose start is not past it. Dividing the pixel by the count
	## instead disagrees with the cells wherever the width does not divide evenly.
	return ((int(at.x) + 1) * count - 1) / canvas.x


## One tab's share of the row, in canvas pixels. Whole pixels, and the last cell
## takes whatever the division left over, so the row is exactly as wide as the
## canvas.
static func tab_cell(index: int, canvas: Vector2i, count: int) -> Rect2i:
	var tabs: int = maxi(count, 1)
	var left: int = index * canvas.x / tabs
	var right: int = (index + 1) * canvas.x / tabs
	return Rect2i(left, 0, right - left, maxi(canvas.y - PAGE_SIZE.y, 0))


## The tab the tap at [param at] landed on, in canvas pixels, or the empty name
## for a tap that missed the row.
##
## Public because a host on a real panel converts its own touch to these pixels
## and a test drives it without one.
func tab_at(at: Vector2) -> StringName:
	var index: int = tab_index_at(at, canvas_size, _tabs.size())
	if index < 0:
		return &""
	return StringName((_tabs.items()[index] as Dictionary).get("kind", &""))


## A touch on the tab row, in canvas pixels. Answers whether it opened a page.
##
## The only input this screen accepts, and the reason it stays read only: there
## is no path from here into a page.
func touch(at: Vector2) -> bool:
	var kind: StringName = tab_at(at)
	if kind.is_empty() or kind == _tabs.selected_kind():
		return false
	if not _tabs.select(kind):
		return false
	_build_page()
	return true


## Opens [param kind], answering whether that tab exists. For a preview or a
## check driving the panel without a touch; a player reaches it through
## [method touch].
func select_tab(kind: StringName) -> bool:
	if not _tabs.select(kind):
		return false
	if kind != _page_kind:
		_build_page()
	return true


## The tab the cursor is on, for a host reporting what the panel shows.
func selected_kind() -> StringName:
	return _tabs.selected_kind()


## The drawn surface as pixels, which is what a panel behind a bitmap is handed.
## Null before the viewport has drawn a frame.
func frame() -> Image:
	if _viewport == null:
		return null
	var texture: ViewportTexture = _viewport.get_texture()
	return texture.get_image() if texture != null else null


## The viewport itself, for a host that can show it directly rather than copy it.
func viewport() -> SubViewport:
	return _viewport


func _build() -> void:
	Gen2Screen.drop_children(self)
	## A [SubViewportContainer] is not used: it would size the viewport to
	## whatever the control is, and the canvas is a fixed count of hardware
	## pixels that the display scales rather than a resolution the window picks.
	_viewport = SubViewport.new()
	_viewport.name = "Viewport"
	_viewport.transparent_bg = false
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var shown := TextureRect.new()
	shown.name = "Shown"
	shown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shown.texture = _viewport.get_texture()
	add_child(shown)

	var field := ColorRect.new()
	field.name = "Field"
	field.color = FIELD_COLOR
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(field)

	var scene: PackedScene = load(Gen2Screen.SCENE_PATH) as PackedScene
	_screen = scene.instantiate() as Gen2Screen if scene != null else null
	if _screen != null:
		_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		## The packed scene anchors to its parent's whole rectangle, which inside
		## a viewport is the whole canvas. The page is a fixed 160x144 placed in
		## it, so the anchors are cleared before [method _relayout] positions it.
		_screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		## The packed scene also grows in both directions, which would move the
		## page's own corner every time its size was set.
		_screen.grow_horizontal = Control.GROW_DIRECTION_END
		_screen.grow_vertical = Control.GROW_DIRECTION_END
		_viewport.add_child(_screen)

	_strip = Control.new()
	_strip.name = "Tabs"
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(_strip)
	_strip_art = TextureRect.new()
	_strip_art.name = "Box"
	_strip_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_strip.add_child(_strip_art)
	_relayout()
	_build_row()
	_build_page()


## Whether the panel is showing the launcher's own page rather than one of the
## cartridge's. The two are drawn at different resolutions, so this decides the
## viewport's size as well as what is in it.
func idle() -> bool:
	return _tabs.is_empty()


## Whether what is drawn changes by itself. Every page the cartridge owns has
## something moving on it -- the party's icons bob, the card's colon blinks, the
## region map's player walks -- and the launcher's own page has nothing.
func animated() -> bool:
	return not idle()


func _relayout() -> void:
	if _viewport == null:
		return
	var quiet: bool = idle()
	_viewport.size = panel_size if quiet else canvas_size
	if _screen != null:
		_screen.visible = not quiet
	if _strip != null:
		_strip.visible = not quiet
	if quiet:
		_place_idle()
		return
	var field: ColorRect = _viewport.get_node_or_null(^"Field") as ColorRect
	if field != null:
		field.size = Vector2(canvas_size)
	if _screen != null:
		## The page is the hardware's own rectangle, centred across a canvas that
		## may be wider. It is given exactly its own size, so the screen inside
		## it draws at one whole pixel per hardware pixel.
		_screen.size = Vector2(PAGE_SIZE)
		_screen.position = Vector2(float((canvas_size.x - PAGE_SIZE.x) / 2), 0.0)
	if _strip != null:
		_strip.position = Vector2(0.0, float(PAGE_SIZE.y))
		_strip.size = Vector2(float(canvas_size.x), float(canvas_size.y - PAGE_SIZE.y))
		_redraw_strip()
	_place_icons()
	_place_idle()


## The party's lead, whose menu icon is the #MON tab's. Zero for an empty party,
## which is also when that tab is absent.
func _lead_species() -> int:
	if _world == null:
		return 0
	var summary: Dictionary = _world.party_summary()
	var species: Variant = summary.get("species", [])
	if not species is Array or (species as Array).is_empty():
		return 0
	return int((species as Array)[0])


func _lead_is_egg() -> bool:
	if _world == null:
		return false
	var eggs: Variant = _world.party_summary().get("eggs", [])
	if not eggs is Array or (eggs as Array).is_empty():
		return false
	return bool((eggs as Array)[0])


## `wPlayerGender`, which picks Kris's pack, her card picture and her palettes.
func _is_female() -> bool:
	if _world != null:
		return _world.player_female()
	return _save != null and _save.gender == Gen2SaveData.GENDER_FEMALE


func _build_row() -> void:
	for icon: TextureRect in _icons:
		Gen2Screen.drop(icon)
	_icons = []
	var female: bool = _is_female()
	for entry: Dictionary in _tabs.items():
		var kind: StringName = StringName(entry.get("kind", &""))
		var picture: Image = Gen2SecondScreenTabs.icon(
			_data, kind, _lead_species(), female, _lead_is_egg()
		)
		var rect := TextureRect.new()
		rect.name = String(kind)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		## Each icon is the size of the picture the cartridge draws rather than a
		## common cell, so a bag is a bag rather than a crop of one. A cache that
		## cannot supply one leaves the cell empty and still counted, so the row
		## keeps its shape.
		rect.size = Vector2(
			Gen2SecondScreenTabs.ICON_SIZE, Gen2SecondScreenTabs.ICON_SIZE
		)
		if picture != null:
			Gen2PicImage.show(rect, picture)
			rect.size = Vector2(picture.get_size())
		_strip.add_child(rect)
		_icons.append(rect)
	_place_icons()


func _place_icons() -> void:
	if _strip == null or _icons.is_empty():
		return
	## The interior, which is the row less the border tile at each end. The
	## underline sits in the bottom of it, so the icons centre above that.
	var top: float = float(Gen2Font.TILE)
	var room: float = _strip.size.y - Gen2Font.TILE * 2 - UNDERLINE_HEIGHT
	for index: int in _icons.size():
		var cell: Rect2 = _cell(index)
		var icon: TextureRect = _icons[index]
		icon.position = Vector2(
			cell.position.x + floorf((cell.size.x - icon.size.x) * 0.5),
			top + maxf(floorf((room - icon.size.y) * 0.5), 0.0),
		)


## The launcher's page fills the panel, and the panel's size is settled by the
## host after this screen is already in the tree, so the size is applied here
## rather than where the page is built.
func _place_idle() -> void:
	if _idle == null:
		return
	_idle.position = Vector2.ZERO
	_idle.size = Vector2(panel_size)
	for child: Node in _idle.get_children():
		if child is Control:
			(child as Control).size = Vector2(panel_size)


func _cell(index: int) -> Rect2:
	return Rect2(tab_cell(index, canvas_size, _icons.size()))


## The row as the cartridge would have drawn it: the player's own text-box frame
## around white paper, with the open tab underlined in the frame's ink.
##
## Redrawn when the tab set or the chosen tab changes, not per frame. Nothing
## here is invented: the six frame tiles are `LoadFrame`'s own, chosen by the
## same FRAME option the boxes on the top screen wear.
func _redraw_strip() -> void:
	if _strip == null or _strip_art == null:
		return
	var width: int = canvas_size.x
	var height: int = int(_strip.size.y)
	if width <= 0 or height <= 0:
		return
	_strip_art.position = Vector2.ZERO
	_strip_art.size = Vector2(float(width), float(height))
	var paper := PackedByteArray()
	paper.resize(width * height)
	## A row with no tabs on it is not an empty menu box, it is no menu box: the
	## panel is showing the launcher's own picture and there is nothing to pick.
	paper.fill(INK if _icons.is_empty() else PAPER)
	var glyphs: Gen2Font = _font()
	if not _icons.is_empty() and glyphs != null:
		_draw_box(glyphs, paper, width, height)
		_draw_underline(paper, width, height)
	Gen2PicImage.show(_strip_art, Gen2PicImage.from_indices(
		paper, width, height,
		Gen2Palette.pic_palette(PackedColorArray([Color.WHITE, Color.BLACK]))
	))


## The six frame tiles around the row.
##
## Placed by hand rather than through [method Gen2Font.draw_box], because that
## one takes whole tiles in both directions and this row is a whole number of
## tiles in neither: the border tiles are laid at the four edges and the runs
## between them overlap rather than stopping short, which a uniform edge tile
## does not show.
func _draw_box(glyphs: Gen2Font, into: PackedByteArray, width: int, height: int) -> void:
	var style: int = Gen2OptionsStore.current().textbox_frame
	var tile: int = Gen2Font.TILE
	var right: int = width - tile
	var bottom: int = height - tile
	var horizontal: int = RomLayout.FRAME_FIRST_CODE + RomLayout.FRAME_HORIZONTAL
	var vertical: int = RomLayout.FRAME_FIRST_CODE + RomLayout.FRAME_VERTICAL
	var x: int = tile
	while x < right:
		glyphs.draw_frame_code(style, horizontal, into, width, mini(x, right - 1), 0)
		glyphs.draw_frame_code(style, horizontal, into, width, mini(x, right - 1), bottom)
		x += tile
	var y: int = tile
	while y < bottom:
		glyphs.draw_frame_code(style, vertical, into, width, 0, mini(y, bottom - 1))
		glyphs.draw_frame_code(style, vertical, into, width, right, mini(y, bottom - 1))
		y += tile
	for corner: Array in [
		[RomLayout.FRAME_TOP_LEFT, 0, 0], [RomLayout.FRAME_TOP_RIGHT, right, 0],
		[RomLayout.FRAME_BOTTOM_LEFT, 0, bottom],
		[RomLayout.FRAME_BOTTOM_RIGHT, right, bottom],
	]:
		glyphs.draw_frame_code(
			style, RomLayout.FRAME_FIRST_CODE + int(corner[0]), into, width,
			int(corner[1]), int(corner[2])
		)


func _draw_underline(into: PackedByteArray, width: int, height: int) -> void:
	var cell: Rect2i = tab_cell(_tabs.cursor, canvas_size, _icons.size())
	var left: int = cell.position.x + UNDERLINE_INSET
	var span: int = maxi(cell.size.x - UNDERLINE_INSET * 2, 1)
	var top: int = height - Gen2Font.TILE - UNDERLINE_HEIGHT
	for row: int in UNDERLINE_HEIGHT:
		var y: int = top + row
		if y < 0 or y >= height:
			continue
		for column: int in span:
			var x: int = left + column
			if x < 0 or x >= width:
				continue
			into[y * width + x] = INK


func _font() -> Gen2Font:
	if _glyphs == null and _data != null:
		_glyphs = Gen2Font.from_data(_data)
	return _glyphs


## Replaces the page with the one the cursor names. Every branch builds the
## overworld's own screen the way the overworld builds it, less the signal
## connections: nothing here listens for a page closing, because nothing here
## can close one.
func _build_page() -> void:
	if _screen == null:
		return
	if _page != null:
		Gen2Screen.drop(_page)
		_page = null
	_idle = null
	_screen.clear()
	_page_kind = _tabs.selected_kind()
	if _page_kind.is_empty():
		_page = _build_idle()
		_redraw_strip()
		page_changed.emit(_page_kind)
		return
	match _page_kind:
		Gen2WorldStartMenu.ITEM_POKEDEX:
			_page = _build_pokedex()
		Gen2WorldStartMenu.ITEM_POKEMON:
			_page = _build_party()
		Gen2WorldStartMenu.ITEM_PACK:
			_page = _build_pack()
		Gen2WorldStartMenu.ITEM_POKEGEAR:
			_page = _build_pokegear()
		Gen2WorldStartMenu.ITEM_PLAYER:
			_page = _build_trainer_card()
	_relayout()
	page_changed.emit(_page_kind)
	redrawn.emit()


## What the panel shows with no world on it: the launcher is up, or a game has
## just been closed, and the game's own pages are not a thing that exists yet.
##
## Drawn in the launcher's own language rather than the cartridge's, because at
## this point there may be no cartridge: the shelf is a list of bays and one of
## them is empty. It is the shelf's own silhouette for a slot with nothing in it,
## with the project's name under it, on the same field every launcher page has.
##
## Laid out in the panel's own pixels at a whole multiple of the launcher's
## units, so the type is rasterised at the size it is shown rather than blown up
## from a 206-pixel canvas.
func _build_idle() -> Node:
	var skin: Gen2LauncherTheme = Gen2LauncherTheme.active()
	var units: int = idle_scale(panel_size)
	var page := Control.new()
	page.name = "Idle"
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.size = Vector2(panel_size)
	page.theme = skin.control_theme()

	var backdrop := TextureRect.new()
	backdrop.texture = skin.backdrop_texture()
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.size = Vector2(panel_size)
	page.add_child(backdrop)

	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.size = Vector2(panel_size)
	page.add_child(centre)

	var column: VBoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_MD * units)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var holder := CenterContainer.new()
	## Any id: the silhouette is the same shape for all three and its prompt, which
	## is the only part that names one, is off.
	var slot: Gen2Cartridge = Gen2Cartridge.create(skin, RomRegistry.ORDER[0])
	slot.set_imported(false)
	## The shape, not the invitation: an empty bay on the shelf asks for a dump
	## to be dropped on it, and nothing can be dropped on a panel.
	slot.set_bay_prompt(false)
	var tall: float = IDLE_CARTRIDGE * float(units)
	slot.custom_minimum_size = Vector2(tall * Gen2Cartridge.ASPECT, tall)
	holder.add_child(slot)
	column.add_child(holder)
	column.add_child(_idle_label(
		skin, ProjectSettings.get_setting("application/config/name", "pokerecomp"),
		Gen2LauncherTheme.FONT_TITLE * units, skin.text
	))
	column.add_child(_idle_label(
		skin, IDLE_LINE, Gen2LauncherTheme.FONT_SMALL * units, skin.muted
	))
	centre.add_child(column)

	_viewport.add_child(page)
	_idle = page
	_place_idle()
	return page


## The whole multiple of the launcher's own units this panel is. One on anything
## smaller than [constant IDLE_UNITS] tall, which is a desktop window rather than
## a handheld's lower display.
static func idle_scale(panel: Vector2i) -> int:
	return maxi(int(round(float(panel.y) / float(IDLE_UNITS))), 1)


static func _idle_label(
	skin: Gen2LauncherTheme, text: String, points: int, colour: Color
) -> Label:
	var label: Label = Gen2LauncherUI.title(skin, text, points)
	label.add_theme_color_override("font_color", colour)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _build_pokedex() -> Node:
	if _data == null or _world == null:
		return null
	var host := Gen2PokedexScreen.new()
	if not host.open(_data, _world):
		host.free()
		return null
	host.set_read_only(true)
	host.set_screen(_screen)
	_viewport.add_child(host)
	return host


func _build_party() -> Node:
	if _data == null or _save == null:
		return null
	var scene: PackedScene = load("res://game/save/party_screen.tscn") as PackedScene
	var host: Gen2PartyScreen = scene.instantiate() as Gen2PartyScreen if scene != null \
		else null
	if host == null:
		return null
	host.set_context(_data, _save, true)
	host.set_read_only(true)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_screen(_screen)
	_viewport.add_child(host)
	return host


## The pack has no screen of its own: the START menu owns it as a mode, and that
## mode is a cursor this display does not have. The listing is therefore built
## straight off [Gen2WorldPack] and [Gen2PackPage], which is what the START menu
## draws too, with the cursor left on the first row.
func _build_pack() -> Node:
	if _data == null or _world == null or _world.state == null:
		return null
	var page: Gen2PackPage = Gen2PackPage.from_data(_data)
	if page == null or not page.ready():
		return null
	var pockets: Array = Gen2WorldPack.build(_data, _world.state)
	if pockets.is_empty():
		return null
	var pocket: Dictionary = pockets[0]
	var items: Array = pocket.get("items", [])
	## No CANCEL row and no cursor: both are furniture for a press this display
	## cannot take.
	var rows: Array = Gen2WorldPack.list_rows(
		_data, int(pocket.get("pocket", 0)), items, 0, false
	)
	var description: String = ""
	if not items.is_empty():
		description = Gen2WorldPack.row_description(
			_data, int((items[0] as Dictionary).get("item", 0))
		)
	var picture: Image = page.image(
		_data,
		page.pocket_map(0, rows, -1, description, _data.pack_pocket_name(0)),
		0,
		_is_female(),
	)
	if picture == null:
		return null
	var rect := TextureRect.new()
	rect.name = "Pack"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.size = Vector2(PAGE_SIZE)
	Gen2PicImage.show(rect, picture)
	_screen.display(rect)
	return rect


## The MAP card where the player owns it, and the CLOCK card where they do not.
## Both are cards the Pokegear itself opens on, so this tab shows whatever the
## cartridge would have shown a player who pressed it.
func _build_pokegear() -> Node:
	if _data == null or _world == null or _world.state == null:
		return null
	var owned: Array = Gen2PokegearScreen.owned_card_ids(_world.state)
	var female: bool = _is_female()
	if owned.has(Gen2PokegearScreen.CARD_MAP):
		var map := Gen2TownMapScreen.new()
		map.set_screen(_screen)
		_viewport.add_child(map)
		if not map.open(
			_data,
			_world.landmark_backup(),
			_world.state.hall_of_fame(),
			Gen2TownMap.SCREEN_POKEGEAR_CARD,
			owned,
			female,
			_world.map_time_of_day(),
		):
			Gen2Screen.drop(map)
			return null
		return map
	var card := Gen2PokegearScreen.new()
	card.set_screen(_screen)
	_viewport.add_child(card)
	if not card.open(
		_data,
		Gen2PokegearScreen.CARD_CLOCK,
		owned,
		_data.pokegear_text("press_button"),
		"",
		_world.map_time_of_day(),
	):
		Gen2Screen.drop(card)
		return null
	var clock: Dictionary = _world.world_clock()
	card.set_clock(
		int(clock.get("day", 0)), int(clock.get("hour", 0)), int(clock.get("minute", 0))
	)
	return card


func _build_trainer_card() -> Node:
	if _data == null or _world == null or _save == null:
		return null
	var host := Gen2TrainerCardScreen.new()
	if not host.open(_data, _world, _save):
		host.free()
		return null
	## The card sizes itself in the 160x144 space, so it goes on the screen's own
	## interface layer rather than beside it.
	_screen.display(host)
	return host


func _gui_input(event: InputEvent) -> void:
	var pressed: Vector2 = Vector2.INF
	var touched := event as InputEventScreenTouch
	if touched != null and touched.pressed:
		pressed = touched.position
	var clicked := event as InputEventMouseButton
	if clicked != null and clicked.pressed and clicked.button_index == MOUSE_BUTTON_LEFT:
		pressed = clicked.position
	if pressed == Vector2.INF or size.x <= 0.0 or size.y <= 0.0:
		return
	## The control may be shown at any size; a tap is reported in canvas pixels
	## because that is the only space the tab row is laid out in.
	touch(Vector2(
		pressed.x * float(canvas_size.x) / size.x,
		pressed.y * float(canvas_size.y) / size.y
	))
