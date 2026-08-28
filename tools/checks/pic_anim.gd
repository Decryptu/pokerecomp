extends RefCounted

var _r: RefCounted = null
var _collisions: int = 0

## Sweeps `AnimateFrontpic` over the whole corpus on all three cartridges: every
## species and every Unown letter, both scripts, every frame each names, run to
## completion. What a sampled case cannot say: a frame's tile numbers are remapped
## by the pic's own height, a bitmask is 4, 5 or 7 bytes for the same reason, and
## the three sizes are 84, 84 and 83 of Crystal's 251. The invariants are the
## cartridge's own arithmetic: a frame names as many tiles as its bitmask has set
## bits, every tile is inside the run `GetAnimatedEnemyFrontpic` loads, every script
## terminates, and Gold and Silver have no records at all.

const FIRST_SPECIES: int = 1
const LAST_SPECIES: int = RomLayout.SPECIES_COUNT

## `PokeAnim_PlaceGraphic`'s box and the tiles behind it.
const BOX_TILES: int = Gen2PicImage.FRONTPIC_TILES * Gen2PicImage.FRONTPIC_TILES

## Long enough for any script here to have ended: the longest is well under a
## hundred frames and the sweep needs a bound rather than a measurement.
const FRAME_CAP: int = 600


func run(r: RefCounted) -> void:
	_r = r
	_r.each_game(_check_game)


func _check_game() -> void:
	var records: int = 0
	var frames: int = 0
	var sizes: Dictionary = {}
	_collisions = 0
	for species: int in range(FIRST_SPECIES, LAST_SPECIES + 1):
		var forms: Array = [0]
		if species == RomLayout.UNOWN_SPECIES:
			forms = range(1, RomLayout.UNOWN_FORMS + 1)
		for form: int in forms:
			var record: Dictionary = _r.data.pic_animation(species, form)
			if record.is_empty():
				continue
			records += 1
			var height: int = int(record["height"])
			sizes[height] = int(sizes.get(height, 0)) + 1
			frames += _check_record(record, species, form)

	if not _r.crystal:
		# `AnimateFrontpic` does not exist in pokegold: no `anim.asm`, no
		# bitmasks and no frames, and both send-outs reach `PlayStereoCry`.
		_r.check(records == 0, "%d pic animations on a cartridge that has none." % records)
		_r.note("pic_anim none, as pokegold ships none")
		return

	_r.check(
		records == LAST_SPECIES + RomLayout.UNOWN_FORMS - 1,
		"pic_anim has %d records, not the 251 species and 26 Unown letters." % records
	)
	_r.note("pic_anim %d records over %d frames, heights %s, %d frames reach the player's own run" % [
		records, frames, sizes, _collisions
	])


## One record's frames and both of its scripts. Answers how many frames it holds.
func _check_record(record: Dictionary, species: int, form: int) -> int:
	var where: String = "species %d" % species if form == 0 else "Unown %d" % form
	var height: int = int(record["height"])
	var mask_bytes: int = RomLayout.pic_anim_bitmask_bytes(height)
	if not _r.check(mask_bytes > 0, "%s has height %d, which has no bitmask size." % [
		where, height
	]):
		return 0

	# The run the cartridge loads: the padded box, then `w * h` tiles behind it.
	var subject: int = BOX_TILES + height * height
	var list: Array = record["frames"] as Array
	for index: int in list.size():
		var frame: PackedByteArray = list[index]
		if not _r.check(frame.size() >= mask_bytes, "%s frame %d is shorter than its bitmask." % [
			where, index
		]):
			continue
		var bits: int = 0
		for at: int in mask_bytes:
			for bit: int in 8:
				bits += (int(frame[at]) >> bit) & 1
		_r.check(frame.size() == mask_bytes + bits, "%s frame %d names %d tiles for %d bits." % [
			where, index, frame.size() - mask_bytes, bits
		])
		var reaches: bool = false
		for at: int in range(mask_bytes, frame.size()):
			var tile: int = RomLayout.pic_anim_box_tile(int(frame[at]), height)
			_r.check(tile < subject, "%s frame %d names tile %d, past the %d loaded." % [
				where, index, tile, subject
			])
			# `PokeAnim_SetVBank1`'s reason: the block's own 49 is `AppearUser`'s
			# `$31` for the player's back pic, so an animated square has to be
			# read off its own sheet or the two pictures share tile numbers.
			reaches = reaches or tile >= Gen2BattleScreenMap.PLAYER_BASE_TILE
		if reaches:
			_collisions += 1

	for mirrored: bool in [false, true]:
		for kind: int in Gen2PicAnimation.SCENES:
			_run_scene(record, kind, mirrored, subject, where)
	return list.size()


## One whole scene, to the frame `PokeAnim_Finish` sets its own exit on. Every
## box the animation leaves has to be drawable, which is the only thing the
## renderer asks of it.
func _run_scene(
	record: Dictionary, kind: int, mirrored: bool, subject: int, where: String
) -> void:
	var animation := Gen2PicAnimation.new(record, kind, mirrored)
	var spent: int = 0
	while not animation.finished() and spent < FRAME_CAP:
		animation.advance()
		spent += 1
		for tile: int in animation.box:
			if tile >= subject:
				_r.check(false, "%s scene %d draws tile %d, past the %d loaded." % [
					where, kind, tile, subject
				])
				return
	_r.check(animation.finished(), "%s scene %d did not end within %d frames." % [
		where, kind, FRAME_CAP
	])
