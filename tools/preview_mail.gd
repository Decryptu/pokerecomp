extends SceneTree

## Captures `ReadAnyMail` against a real imported cache. The ten mail types are the
## one screen in this project drawn through four cartridge colours rather than a
## white-to-black pair, and every one is a different VRAM window over the same 1bpp
## run, so the picture is what says a transcription is right.
##   Godot --headless --path . -s res://tools/preview_mail.gd -- crystal /tmp/mail.png [type]
## [type] is a `MailGFXPointers` index, 0 to 9, or `all` for a contact sheet.

const COLUMNS: int = 5
const SAMPLE_SPECIES: int = 1

## Two lines that fill the first exactly, so the break is where the picture
## shows it rather than where a short message would leave it.
const SAMPLE_LINE_1: String = "HAVE A GOOD DAY!"
const SAMPLE_LINE_2: String = "SEE YOU SOON"
const SAMPLE_AUTHOR: String = "GOLD"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Usage: preview_mail.gd -- <game> <output.png> [type|all]")
		quit(1)
		return
	if Gen2ToolPath.refuses(args[1]):
		quit(2)
		return

	var data: GameData = GameData.open(StringName(args[0]))
	if data == null:
		push_error("No cache for %s. Import roms/%s.gbc first." % [args[0], args[0]])
		quit(1)
		return
	var page: Gen2MailPage = Gen2MailPage.from_data(data)
	if page == null or not page.ready():
		push_error("The %s cache carries no mail graphics." % args[0])
		quit(1)
		return

	var wanted: String = args[2] if args.size() > 2 else "all"
	var types: Array = range(RomLayout.MAIL_PALETTE_COUNT) if wanted == "all" \
		else [clampi(int(wanted), 0, RomLayout.MAIL_PALETTE_COUNT - 1)]
	var columns: int = mini(COLUMNS, types.size())
	@warning_ignore("integer_division")
	var rows: int = (types.size() + columns - 1) / columns
	var sheet: Image = Image.create_empty(
		columns * Gen2Screen.WIDTH, rows * Gen2Screen.HEIGHT, false, Image.FORMAT_RGBA8
	)
	for index: int in types.size():
		var type: int = int(types[index])
		var indices: PackedByteArray = page.draw(_sample(type))
		var tile: Image = Gen2PicImage.from_indices(
			indices, Gen2Screen.WIDTH, Gen2Screen.HEIGHT, data.mail_palette(type)
		)
		@warning_ignore("integer_division")
		sheet.blit_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), Vector2i(
			(index % columns) * Gen2Screen.WIDTH, (index / columns) * Gen2Screen.HEIGHT
		))
	if sheet.save_png(args[1]) != OK:
		push_error("Could not write %s" % args[1])
		quit(1)
		return
	print("Wrote %s (%dx%d), %d mail types." % [
		args[1], sheet.get_width(), sheet.get_height(), types.size(),
	])
	quit(0)


## `ComposeMailMessage`'s own result for [param index]'s item.
func _sample(index: int) -> Gen2SaveMail:
	var entry: PackedByteArray = Gen2SaveMail.blank_message()
	var first: PackedByteArray = Gen2Text.encode(SAMPLE_LINE_1)
	for at: int in first.size():
		entry[at] = first[at]
	var second: PackedByteArray = Gen2Text.encode(SAMPLE_LINE_2)
	for at: int in second.size():
		entry[Gen2SaveMail.LINE_LENGTH + 1 + at] = second[at]
	return Gen2SaveMail.compose(
		entry, SAMPLE_AUTHOR, 0x1234, SAMPLE_SPECIES, Gen2MailPage.ITEM_NUMBERS[index]
	)
