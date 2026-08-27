class_name Gen2ModPageScreen
extends Control

## The one screen a mod may put behind a start-menu row
## ([constant Gen2ModHost.START_ACTION_OPEN_MOD_PAGE]), embedded in the overworld
## the way the trainer card and the Hall of Fame are.
##
## A record of what a run has done is what the cartridge's own trainer card is,
## and this is drawn the same way: the screen's own frame and font, paged with
## the d-pad and left with B. The mod supplies rows and nothing else, so it needs
## no node, no renderer and no art; the icons are
## [method Gen2MapNameSignPage.render_notice_icon]'s vocabulary, which is the one
## an actor and a battle annotation already share.
##
## A locked row is drawn the way the Pokedex draws an unseen entry: the label is
## replaced by `?`, which is what `PrintDexEntry`'s unseen branch does, and its
## icon is left off.

signal closed()

const TILE: int = Gen2Font.TILE
const COLUMNS: int = Gen2Screen.WIDTH / TILE
const ROWS: int = Gen2Screen.HEIGHT / TILE

## The whole screen as one `menu_coords 0, 0, 19, 17` box with a title on its
## border, which is `MenuHeader_*`'s own shape for a list that fills the screen.
const BOX_FLAGS: int = Gen2MenuBox.STATICMENU_PLACE_TITLE
## Two tiles per row, the height of an icon and of `ROW_STEP` both.
const ROW_TILES: int = 2
const VISIBLE_ROWS: int = 8
## Inside the border: the icon in the first two columns, the label beside it and
## the detail under the label.
const ICON_COLUMN: int = 1
const TEXT_COLUMN: int = 4
const FIRST_ROW: int = 1
## What one line may be once the frame and the icon have taken their columns.
const TEXT_COLUMNS: int = COLUMNS - TEXT_COLUMN - 1
## `PrintDexEntry`'s own unseen row.
const LOCKED_LABEL: String = "?"
## `MenuHeader_*`'s own `db 1` title indent, which is what keeps the corner tile.
const TITLE_INDENT: int = 1

var _data: GameData = null
var _page: Gen2MenuPage = null
var _title: String = ""
var _rows: Array = []
var _scroll: int = 0
var _background: TextureRect = null
var _icons: Array = []


## Optional the way the other overlays are: a mod with no page registered, or a
## cache with no font, answers false and the caller keeps the start menu open.
func open(data: GameData, id: StringName) -> bool:
	_data = data
	if _data == null:
		return false
	var entry: Dictionary = Gen2ModHost.instance().page(id)
	if entry.is_empty():
		return false
	_page = Gen2MenuPage.from_data(_data)
	if _page == null:
		return false
	_title = String(entry.get("title", ""))
	_rows = Gen2ModHost.instance().page_rows(id)
	_scroll = 0
	if is_inside_tree() and _background != null:
		_refresh()
	return true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
	_background = TextureRect.new()
	_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	if _page != null:
		_refresh()


func row_count() -> int:
	return _rows.size()


func scroll() -> int:
	return _scroll


## The d-pad scrolls a window rather than moving a cursor: there is nothing to
## choose here, the way there is nothing to choose on a trainer card. B leaves.
func handle_button(button: int) -> bool:
	match button:
		Gen2Button.B, Gen2Button.START:
			closed.emit()
			return true
		Gen2Button.UP:
			return _scroll_by(-1)
		Gen2Button.DOWN:
			return _scroll_by(1)
		Gen2Button.LEFT:
			return _scroll_by(-VISIBLE_ROWS)
		Gen2Button.RIGHT:
			return _scroll_by(VISIBLE_ROWS)
	return false


func _scroll_by(delta: int) -> bool:
	var last: int = maxi(0, _rows.size() - VISIBLE_ROWS)
	var next: int = clampi(_scroll + delta, 0, last)
	if next == _scroll:
		return false
	_scroll = next
	_refresh()
	return true


## The rows on screen now, which is what a test or a screenshot reads back.
func visible_rows() -> Array:
	return _rows.slice(_scroll, _scroll + VISIBLE_ROWS)


func _refresh() -> void:
	if _background == null or _page == null:
		return
	var box: Gen2MenuBox = Gen2MenuBox.from_coords(0, 0, COLUMNS - 1, ROWS - 1, BOX_FLAGS)
	## `ScrollingMenu_UpdateDisplay`'s own arrows, which is how every scrolled
	## list in the game says there is more below and above.
	box.scrolling_arrows = _rows.size() > VISIBLE_ROWS
	box.scroll = _scroll
	var extras: Array = []
	for index: int in visible_rows().size():
		var row: Dictionary = visible_rows()[index]
		var top: int = FIRST_ROW + index * ROW_TILES
		var locked: bool = bool(row.get("locked", false))
		extras.append({
			"text": LOCKED_LABEL if locked else String(row.get("label", "")),
			"at": Vector2i(TEXT_COLUMN, top),
			"max_tiles": TEXT_COLUMNS,
		})
		if not locked and not String(row.get("detail", "")).is_empty():
			extras.append({
				"text": String(row["detail"]), "at": Vector2i(TEXT_COLUMN, top + 1),
				"max_tiles": TEXT_COLUMNS,
			})
	## `PlaceMenuStrings`' own indent: a title sits on the top border one column
	## in, so the box keeps its corner.
	Gen2PicImage.show(_background, _page.render(box, [], -1, _title, TITLE_INDENT, extras))
	_refresh_icons()


## The icons over the drawn page, as objects with their own palettes, exactly as
## the trainer card draws its badges over the card.
func _refresh_icons() -> void:
	for icon: TextureRect in _icons:
		icon.queue_free()
	_icons = []
	for index: int in visible_rows().size():
		var row: Dictionary = visible_rows()[index]
		if bool(row.get("locked", false)):
			continue
		var image: Image = Gen2MapNameSignPage.render_notice_icon(
			_data, row.get("icon", {}) as Dictionary
		)
		if image == null:
			continue
		var sprite := TextureRect.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		Gen2PicImage.show(sprite, image)
		sprite.size = image.get_size()
		sprite.position = Vector2(
			ICON_COLUMN * TILE, (FIRST_ROW + index * ROW_TILES) * TILE
		)
		add_child(sprite)
		_icons.append(sprite)
