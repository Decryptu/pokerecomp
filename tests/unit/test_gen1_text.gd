extends GutTest

## The Generation 1 codec, which shares its letter, digit and punctuation runs
## with Generation 2 and nothing below $80.


func _bytes(values: Array) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	for value: int in values:
		out.append(value)
	return out


func test_the_letter_runs_decode() -> void:
	# "RHYDON", the cartridge's own first species name.
	var data: PackedByteArray = _bytes([0x91, 0x87, 0x98, 0x83, 0x8E, 0x8D, 0x50])
	assert_eq(Gen1Text.decode(data, 0, 10), "RHYDON")


func test_a_fixed_width_name_drops_its_padding() -> void:
	var data: PackedByteArray = _bytes([0x8C, 0x84, 0x96, 0x50, 0x50, 0x50, 0x50])
	assert_eq(Gen1Text.decode_fixed(data, 0, 7), "MEW")


func test_digits_and_the_space_decode() -> void:
	assert_eq(Gen1Text.character(0xF6), "0")
	assert_eq(Gen1Text.character(0xFF), "9")
	assert_eq(Gen1Text.character(0x7F), " ")


func test_a_ligature_is_one_tile() -> void:
	assert_eq(Gen1Text.character(0xBD), "'s")
	assert_eq(Gen1Text.encoded_length("it's"), 3)


func test_the_word_codes_decode_to_their_words() -> void:
	assert_eq(Gen1Text.character(0x54), "POKé")
	assert_eq(Gen1Text.character(0x5D), "TRAINER")
	assert_eq(Gen1Text.character(0x52), "<PLAYER>")


func test_an_unmapped_byte_is_never_dropped() -> void:
	# A byte with no character means the offset table is wrong, so it has to be
	# visible rather than silently skipped.
	assert_eq(Gen1Text.character(0x01), "<01>")


func test_a_sequence_walks_terminator_to_terminator() -> void:
	var data: PackedByteArray = _bytes([0x82, 0x94, 0x93, 0x50, 0x85, 0x8B, 0x98, 0x50])
	assert_eq(Gen1Text.decode_sequence(data, 0, 2, 20), PackedStringArray(["CUT", "FLY"]))


func test_encoding_is_the_inverse_over_the_printable_range() -> void:
	var text: String = "PIKACHU 25!"
	assert_eq(Gen1Text.decode(Gen1Text.encode(text), 0, text.length()), text)


func test_an_undrawable_character_becomes_a_question_mark() -> void:
	assert_eq(Gen1Text.encode("~"), _bytes([Gen1Text.UNKNOWN]))


func test_a_dex_description_ends_on_dexend_and_breaks_on_its_line_codes() -> void:
	# TX_START, "AB", <LINE>, "CD", <DEXEND>, then a byte past the end.
	var data: PackedByteArray = _bytes([
		0x00, 0x80, 0x81, 0x4F, 0x82, 0x83, Gen1Text.DEX_END, 0x84,
	])
	assert_eq(Gen1Text.decode_dex_text(data, 0, 32), "AB\nCD")


func test_decoding_stops_at_the_end_of_the_buffer() -> void:
	assert_eq(Gen1Text.decode(_bytes([0x80]), 0, 40), "A")
	assert_eq(Gen1Text.decode(PackedByteArray(), 0, 40), "")
