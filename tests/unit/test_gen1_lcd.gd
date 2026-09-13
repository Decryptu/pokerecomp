extends GutTest

## [Gen1Lcd] draws a frame the way the Game Boy's LCD does: signed or unsigned
## tile addressing off `rLCDC`, the window from `rWY`, ten objects a line in
## OAM order with the lowest X in front, `OAM_PRIO` behind any background colour
## but 0, and a scroll override per scanline. Every case here is a tile or two
## on a blank map, checked pixel by pixel.

var _lcd: Gen1Lcd


func before_each() -> void:
	_lcd = Gen1Lcd.new()
	_lcd.bgp = 0xE4
	_lcd.obp0 = 0xE4
	_lcd.obp1 = 0xE4


## A strip of one tile whose every pixel is [param index].
func _solid(index: int) -> PackedByteArray:
	var strip := PackedByteArray()
	strip.resize(Gen1Lcd.TILE_PIXELS)
	strip.fill(index)
	return strip


func _pixel(shades: PackedByteArray, x: int, y: int) -> int:
	return shades[y * Gen1Lcd.WIDTH + x]


func test_background_ids_under_128_read_from_vchars2_when_blocks_is_clear() -> void:
	_lcd.load_tiles(Gen1Lcd.SIGNED_BASE + 5, _solid(3), 1, 0, 1)
	_lcd.load_tiles(5, _solid(1), 1, 0, 1)
	_lcd.maps[0][0] = 5
	_lcd.lcdc = Gen1Lcd.LCDC_ON | Gen1Lcd.LCDC_BG
	assert_eq(_pixel(_lcd.render(), 0, 0), 3, "LCDC_BLOCK21 reads id 5 at $9050")
	_lcd.lcdc |= Gen1Lcd.LCDC_BLOCKS
	assert_eq(_pixel(_lcd.render(), 0, 0), 1, "LCDC_BLOCK01 reads it at $8050")


func test_ids_from_128_up_read_from_vchars1_either_way() -> void:
	_lcd.load_tiles(0x90, _solid(2), 1, 0, 1)
	_lcd.maps[0][0] = 0x90
	_lcd.lcdc = Gen1Lcd.LCDC_ON | Gen1Lcd.LCDC_BG
	assert_eq(_pixel(_lcd.render(), 0, 0), 2)
	_lcd.lcdc |= Gen1Lcd.LCDC_BLOCKS
	assert_eq(_pixel(_lcd.render(), 0, 0), 2)


func test_the_scroll_wraps_the_map_and_the_bg_map_bit_picks_the_map() -> void:
	_lcd.load_tiles(Gen1Lcd.SIGNED_BASE + 1, _solid(1), 1, 0, 1)
	_lcd.maps[1][31 * Gen1Lcd.MAP_SIDE + 31] = 1
	_lcd.lcdc = Gen1Lcd.LCDC_ON | Gen1Lcd.LCDC_BG | Gen1Lcd.LCDC_BG_MAP
	_lcd.scx = 248
	_lcd.scy = 248
	var shades: PackedByteArray = _lcd.render()
	assert_eq(_pixel(shades, 0, 0), 1, "the map's last cell sits under (0, 0) at a 248 scroll")
	assert_eq(_pixel(shades, 8, 8), 0)
	_lcd.lcdc &= ~Gen1Lcd.LCDC_BG_MAP
	assert_eq(_pixel(_lcd.render(), 0, 0), 0, "vBGMap0 is blank")


func test_the_window_covers_the_background_from_wy() -> void:
	_lcd.load_tiles(Gen1Lcd.SIGNED_BASE + 1, _solid(1), 1, 0, 1)
	_lcd.load_tiles(Gen1Lcd.SIGNED_BASE + 2, _solid(2), 1, 0, 1)
	_lcd.fill_map(0, 1)
	_lcd.fill_map(1, 2)
	_lcd.lcdc = Gen1Lcd.LCDC_DEFAULT
	_lcd.wy = 64
	var shades: PackedByteArray = _lcd.render()
	assert_eq(_pixel(shades, 0, 63), 1)
	assert_eq(_pixel(shades, 0, 64), 2, "the window's own map from its first line")
	assert_eq(_pixel(shades, 159, 143), 2)


func test_objects_draw_through_their_palette_and_skip_colour_0() -> void:
	var strip := PackedByteArray()
	for pixel: int in Gen1Lcd.TILE_PIXELS:
		strip.append(0 if pixel % Gen1Lcd.TILE == 0 else 2)
	_lcd.load_tiles(3, strip, 1, 0, 1)
	_lcd.obp1 = 0b00110000
	_lcd.set_sprite(0, 16 + 10, 8 + 20, 3, Gen1Lcd.OAM_PAL1)
	_lcd.lcdc = Gen1Lcd.LCDC_ON | Gen1Lcd.LCDC_OBJS
	var shades: PackedByteArray = _lcd.render()
	assert_eq(_pixel(shades, 20, 10), 0, "colour 0 of an object is transparent")
	assert_eq(_pixel(shades, 21, 10), 3, "OBP1 maps colour 2 to shade 3")
	assert_eq(_pixel(shades, 27, 17), 3)


func test_the_lowest_x_wins_and_priority_hides_behind_the_background() -> void:
	_lcd.load_tiles(1, _solid(1), 1, 0, 1)
	_lcd.load_tiles(2, _solid(2), 1, 0, 1)
	_lcd.set_sprite(0, 16, 12, 1, 0)
	_lcd.set_sprite(1, 16, 8, 2, 0)
	_lcd.lcdc = Gen1Lcd.LCDC_ON | Gen1Lcd.LCDC_OBJS | Gen1Lcd.LCDC_BG
	assert_eq(_pixel(_lcd.render(), 4, 0), 2, "slot 1 is further left")
	_lcd.load_tiles(Gen1Lcd.SIGNED_BASE + 7, _solid(3), 1, 0, 1)
	_lcd.maps[0][0] = 7
	_lcd.set_sprite(1, 16, 8, 2, Gen1Lcd.OAM_PRIO)
	var shades: PackedByteArray = _lcd.render()
	assert_eq(_pixel(shades, 4, 0), 3, "OAM_PRIO under background colour 3")
	assert_eq(_pixel(shades, 10, 0), 1, "the other object keeps its pixel on the blank cell")


func test_flips_mirror_the_tile() -> void:
	var strip := PackedByteArray()
	strip.resize(Gen1Lcd.TILE_PIXELS)
	strip[0] = 1
	_lcd.load_tiles(0, strip, 1, 0, 1)
	_lcd.set_sprite(0, 16, 8, 0, Gen1Lcd.OAM_XFLIP | Gen1Lcd.OAM_YFLIP)
	_lcd.lcdc = Gen1Lcd.LCDC_ON | Gen1Lcd.LCDC_OBJS
	var shades: PackedByteArray = _lcd.render()
	assert_eq(_pixel(shades, 7, 7), 1)
	assert_eq(_pixel(shades, 0, 0), 0)


func test_only_ten_objects_draw_on_a_line() -> void:
	_lcd.load_tiles(1, _solid(1), 1, 0, 1)
	for slot: int in 11:
		_lcd.set_sprite(slot, 16, 8 + slot * 8, 1, 0)
	_lcd.lcdc = Gen1Lcd.LCDC_ON | Gen1Lcd.LCDC_OBJS
	var shades: PackedByteArray = _lcd.render()
	assert_eq(_pixel(shades, 9 * 8, 0), 1)
	assert_eq(_pixel(shades, 10 * 8, 0), 0, "the eleventh is not scanned")


func test_a_line_override_scrolls_its_own_line_or_the_next() -> void:
	_lcd.load_tiles(Gen1Lcd.SIGNED_BASE + 1, _solid(1), 1, 0, 1)
	_lcd.maps[0][1] = 1
	_lcd.lcdc = Gen1Lcd.LCDC_ON | Gen1Lcd.LCDC_BG
	var overrides := PackedInt32Array()
	overrides.resize(Gen1Lcd.HEIGHT)
	overrides.fill(-1)
	overrides[4] = 8
	_lcd.line_scx = overrides
	var shades: PackedByteArray = _lcd.render()
	assert_eq(_pixel(shades, 0, 4), 1, "an rLY poll lands on its own line")
	assert_eq(_pixel(shades, 0, 5), 0)
	_lcd.line_lag = 1
	shades = _lcd.render()
	assert_eq(_pixel(shades, 0, 4), 0)
	assert_eq(_pixel(shades, 0, 5), 1, "the LCD interrupt's write lands on the next")


func test_an_lcd_that_is_off_is_white() -> void:
	_lcd.load_tiles(Gen1Lcd.SIGNED_BASE, _solid(3), 1, 0, 1)
	_lcd.lcdc = Gen1Lcd.LCDC_BG
	assert_eq(_lcd.render().count(0), Gen1Lcd.WIDTH * Gen1Lcd.HEIGHT)


func test_the_attribute_map_paints_inside_line_and_outside() -> void:
	# `BlkPacket_GameFreakIntro`'s first row: %111, palette 1 inside and on the
	# line of (5, 11)-(7, 13), 0 outside.
	var map: PackedByteArray = Gen1OpeningPage.attribute_map([[7, 5, 5, 11, 7, 13]])
	assert_eq(map[11 * 20 + 5], 1, "the line")
	assert_eq(map[12 * 20 + 6], 1, "inside")
	assert_eq(map[0], 0, "outside")
	# `BlkPacket_Titlescreen`'s middle row, %010 with palette 1 on the line of a
	# box two rows high: every cell of it is on the line.
	map = Gen1OpeningPage.attribute_map([[3, 0, 0, 0, 19, 7], [2, 5, 0, 8, 19, 9]])
	assert_eq(map[8 * 20 + 10], 1)
	assert_eq(map[9 * 20 + 0], 1)
	assert_eq(map[7 * 20 + 10], 0)
	# A row painting the inside alone paints its line with it.
	map = Gen1OpeningPage.attribute_map([[1, 2, 2, 2, 6, 6]])
	assert_eq(map[2 * 20 + 2], 2)
	assert_eq(map[4 * 20 + 4], 2)
	assert_eq(map[0], 0)
