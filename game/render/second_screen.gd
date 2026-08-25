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
## row, inset so two neighbouring tabs never touch.
const UNDERLINE_HEIGHT: int = 2
const UNDERLINE_INSET: int = 4
## The shortest tab row that still fits the tallest icon with a little air and
## that underline. A host with a taller panel gets a taller row.
const MIN_TAB_HEIGHT: int = Gen2SecondScreenTabs.ICON_MAX + UNDERLINE_HEIGHT + 6
const CANVAS_MIN := Vector2i(PAGE_SIZE.x, PAGE_SIZE.y + MIN_TAB_HEIGHT)

const FIELD_COLOR := Color(0.0, 0.0, 0.0, 1.0)
const MARK_COLOR := Color(1.0, 1.0, 1.0, 1.0)

## Emitted after the shown page changes, so a host knows a still picture is worth
## sending again even when nothing is animating.
signal page_changed(kind: StringName)

## The whole drawn surface, in hardware pixels. Never smaller than
## [constant CANVAS_MIN]: the page is a fixed 160x144 and the tab row has to hold
## an icon.
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
## The page on screen, whichever of the cartridge's screens it is, and which tab
## built it. Kept so a rebuild is skipped when the answer would be the same node.
var _page: Node = null
var _page_kind: StringName = &""
## The tab row's icons, one [TextureRect] per tab, rebuilt with the tab set.
var _icons: Array[TextureRect] = []
## What [method _gate] answered when the row was last built.
var _gate_read: String = ""


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
	_data = data
	_world = world
	_save = save
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
	_strip.draw.connect(_draw_strip)
	_viewport.add_child(_strip)
	_relayout()
	_build_row()
	_build_page()


func _relayout() -> void:
	if _viewport == null:
		return
	_viewport.size = canvas_size
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
		_strip.queue_redraw()
	_place_icons()


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
	var room: float = _strip.size.y - UNDERLINE_HEIGHT
	for index: int in _icons.size():
		var cell: Rect2 = _cell(index)
		var icon: TextureRect = _icons[index]
		icon.position = Vector2(
			cell.position.x + floorf((cell.size.x - icon.size.x) * 0.5),
			maxf(floorf((room - icon.size.y) * 0.5), 0.0),
		)


func _cell(index: int) -> Rect2:
	return Rect2(tab_cell(index, canvas_size, _icons.size()))


func _draw_strip() -> void:
	if _strip == null:
		return
	_strip.draw_rect(Rect2(Vector2.ZERO, _strip.size), FIELD_COLOR)
	if _icons.is_empty():
		return
	var cell: Rect2 = _cell(_tabs.cursor)
	_strip.draw_rect(
		Rect2(
			Vector2(cell.position.x + UNDERLINE_INSET, _strip.size.y - UNDERLINE_HEIGHT),
			Vector2(maxf(cell.size.x - UNDERLINE_INSET * 2, 1.0), UNDERLINE_HEIGHT),
		),
		MARK_COLOR
	)


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
	_screen.clear()
	_page_kind = _tabs.selected_kind()
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
	if _strip != null:
		_strip.queue_redraw()
	page_changed.emit(_page_kind)


func _build_pokedex() -> Node:
	if _data == null or _world == null:
		return null
	var host := Gen2PokedexScreen.new()
	if not host.open(_data, _world):
		host.free()
		return null
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
	var rows: Array = Gen2WorldPack.list_rows(
		_data, int(pocket.get("pocket", 0)), items
	)
	var description: String = ""
	if not items.is_empty():
		description = Gen2WorldPack.row_description(
			_data, int((items[0] as Dictionary).get("item", 0))
		)
	var picture: Image = page.image(
		_data,
		page.pocket_map(0, rows, 0, description, _data.pack_pocket_name(0)),
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
