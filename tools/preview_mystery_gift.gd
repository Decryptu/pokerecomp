extends SceneTree

## Captures the Mystery Gift screen against a real imported cache.
##   Godot --headless --path . -s res://tools/preview_mystery_gift.gd -- <game> <out.png> [box]
## [box] is `prompt` or one of `DoMysteryGift`'s eight outcome names, or `all` for a
## contact sheet, which is the default. The frame is the one picture that differs
## between the two cartridges for a reason: Crystal builds it out of one run and two
## palettes and Gold and Silver out of three runs and one.

const COLUMNS: int = 3
const PARTNER: String = "KRIS"
const PLAYER: String = "GOLD"
const GIFT: String = "BERRY"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Usage: preview_mystery_gift.gd -- <game> <output.png> [box|all]")
		quit(1)
		return
	if PokeToolPath.refuses(args[1]):
		quit(2)
		return
	var data: GameData = GameData.open(StringName(args[0]))
	if data == null:
		push_error("No cache for %s. Import roms/%s.gbc first." % [args[0], args[0]])
		quit(1)
		return
	var page: Gen2MysteryGiftPage = Gen2MysteryGiftPage.from_data(data)
	if page == null:
		push_error("The %s cache carries no Mystery Gift screen." % args[0])
		quit(1)
		return

	var boxes: Array[String] = ["prompt"]
	for outcome: StringName in Gen2MysteryGift.OUTCOME_ORDER:
		boxes.append(String(outcome))
	var wanted: String = args[2] if args.size() > 2 else "all"
	if wanted != "all":
		if wanted not in boxes:
			push_error("Unknown box %s." % wanted)
			quit(1)
			return
		boxes = [wanted] as Array[String]

	var columns: int = mini(COLUMNS, boxes.size())
	@warning_ignore("integer_division")
	var rows: int = (boxes.size() + columns - 1) / columns
	var sheet: Image = Image.create_empty(
		columns * Gen2Screen.WIDTH, rows * Gen2Screen.HEIGHT, false, Image.FORMAT_RGBA8
	)
	for index: int in boxes.size():
		var tile: Image = page.render(_text(data, boxes[index]))
		@warning_ignore("integer_division")
		sheet.blit_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), Vector2i(
			(index % columns) * Gen2Screen.WIDTH, (index / columns) * Gen2Screen.HEIGHT
		))
	if sheet.save_png(args[1]) != OK:
		push_error("Could not write %s" % args[1])
		quit(1)
		return
	print("Wrote %s (%dx%d), %d boxes, %d palettes." % [
		args[1], sheet.get_width(), sheet.get_height(), boxes.size(),
		page.palette.size() / 4,
	])
	quit(0)


## The prompt is the page's own; every other box is one of the eight imported
## stubs with the two names and the gift filled in.
func _text(data: GameData, box: String) -> String:
	if box == "prompt":
		return ""
	var pages: Array = Gen2TextLayout.lay_out(
		Gen2MysteryGiftScreen.box_text(data, StringName(box), PARTNER, PLAYER, GIFT),
		Gen2MysteryGiftPage.MESSAGE_COLUMNS, Gen2MysteryGiftPage.MESSAGE_ROWS
	)
	return "\n".join(pages[0] as PackedStringArray) if not pages.is_empty() else ""
