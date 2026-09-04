extends GutTest

const GEN2_ROM_SIZE: int = RomRegistry.SIZES[RomRegistry.GEN2]

## These tests never touch a real cartridge; the repo has none and must never
## gain one. Synthetic files cover the rejection paths, and the accept path is
## covered by asserting the registry's own hashes round-trip. Hashing a genuine
## ROM is a manual check: `tools/verify_rom.gd` (see README.md).

const SCRATCH_DIR: String = "user://test_roms"

var _made: PackedStringArray = []


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(SCRATCH_DIR)
	_made = []


func after_each() -> void:
	for path: String in _made:
		DirAccess.remove_absolute(path)


func _write_file(row_name: String, size: int, fill: int = 0) -> String:
	var path: String = "%s/%s" % [SCRATCH_DIR, row_name]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	var buffer: PackedByteArray = []
	buffer.resize(size)
	buffer.fill(fill)
	file.store_buffer(buffer)
	file.close()
	_made.append(path)
	return path


func test_missing_file_reports_not_found() -> void:
	var result: Dictionary = RomVerifier.identify("user://definitely_absent.gbc")
	assert_eq(result["status"], RomVerifier.Status.NOT_FOUND)


func test_wrong_size_is_rejected_before_hashing() -> void:
	var path: String = _write_file("small.gbc", 1024)
	var result: Dictionary = RomVerifier.identify(path)
	assert_eq(result["status"], RomVerifier.Status.WRONG_SIZE)
	# Rejected on size alone, so we never paid for the hash.
	assert_eq(result["sha1"], "")


func test_right_size_but_unknown_contents_is_rejected() -> void:
	var path: String = _write_file("blank.gbc", GEN2_ROM_SIZE)
	var result: Dictionary = RomVerifier.identify(path)
	assert_eq(result["status"], RomVerifier.Status.UNKNOWN_ROM)
	assert_eq(result["sha1"].length(), 40, "sha1 should be 40 hex chars")


func test_sha1_matches_a_known_vector() -> void:
	# sha1("abc"), so a broken hashing path fails here rather than silently
	# rejecting every real cartridge as unknown.
	var path: String = "%s/abc.bin" % SCRATCH_DIR
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("abc")
	file.close()
	_made.append(path)
	assert_eq(
		RomVerifier.sha1_of_file(path),
		"a9993e364706816aba3e25717850c26c9cd0d89d"
	)


func test_sha1_of_unreadable_file_is_empty() -> void:
	assert_eq(RomVerifier.sha1_of_file("user://nope.bin"), "")


func test_registry_holds_every_supported_cartridge() -> void:
	assert_eq(RomRegistry.BY_SHA1.size(), RomRegistry.ORDER.size())
	assert_eq(RomRegistry.ids_of_generation(RomRegistry.GEN1).size(), 3)
	assert_eq(RomRegistry.ids_of_generation(RomRegistry.GEN2).size(), 3)


func test_every_row_carries_a_generation_with_a_dump_size() -> void:
	for id: StringName in RomRegistry.ORDER:
		var generation: int = RomRegistry.generation_for(id)
		assert_true(RomRegistry.SIZES.has(generation), "%s has no size" % id)
		assert_eq(RomRegistry.size_for(id), int(RomRegistry.SIZES[generation]))


func test_a_gen1_sized_file_passes_the_prefilter() -> void:
	# The prefilter refused everything but 2 MiB before Gen 1 was listed, which
	# would have rejected Red on its length rather than on its hash.
	var path: String = _write_file("gen1.gb", RomRegistry.SIZES[RomRegistry.GEN1])
	assert_eq(RomVerifier.identify(path)["status"], RomVerifier.Status.UNKNOWN_ROM)


func test_every_registry_id_round_trips() -> void:
	for id: StringName in RomRegistry.ORDER:
		var sha1: String = RomRegistry.sha1_for(id)
		assert_eq(sha1.length(), 40, "%s should have a 40-char sha1" % id)
		assert_true(RomRegistry.is_known(sha1), "%s should be known" % id)
		assert_eq(RomRegistry.lookup(sha1)["id"], id)
		assert_false(RomRegistry.title_for(id).is_empty())


func test_lookup_is_case_insensitive() -> void:
	var sha1: String = RomRegistry.sha1_for(RomRegistry.CRYSTAL)
	assert_true(RomRegistry.is_known(sha1.to_upper()))


func test_hashes_are_lowercase_hex() -> void:
	# lookup() lowercases its argument, so an uppercase key in the table would
	# be permanently unreachable.
	var hex := RegEx.create_from_string("^[0-9a-f]{40}$")
	for sha1: String in RomRegistry.BY_SHA1:
		assert_not_null(hex.search(sha1), "%s is not lowercase hex" % sha1)


func test_unknown_id_yields_no_hash() -> void:
	assert_eq(RomRegistry.sha1_for(&"emerald"), "")
	assert_eq(RomRegistry.title_for(&"emerald"), "")
	assert_eq(RomRegistry.generation_for(&"emerald"), 0)
	assert_eq(RomRegistry.size_for(&"emerald"), 0)
	assert_false(RomRegistry.is_playable(&"emerald"))
