class_name Gen3Palette
extends RefCounted

## `palette.c`'s two colour buffers and its normal fade. `LoadPalette` writes both; the fade, `BlendPalette` and
## the weather write [member faded] from [member unfaded]; VBlank's `TransferPlttBuffer` shows [member faded].

const COLORS: int = 512
const OBJ_OFFSET: int = 256
const ALL: int = 0xFFFFFFFF
enum Status { DONE = 0, ACTIVE = 1, DELAY = 2, LOADING = 0xFF }

## `sprite.c`'s tagged slots start past the reserved object palettes.
var sprite_tags: Dictionary = {}
var reserved_sprite_count: int = 12

var unfaded := PackedByteArray()
var faded := PackedByteArray()
## `gPaletteFade`, normal mode. [member fade_selected] is `multipurpose1`, and what VBlank waits on.
var fade_active: bool = false
var fade_selected: int = 0
var fade_y: int = 0
var fade_target: int = 0
var fade_color: int = 0
var fade_delay: int = 0
var fade_delay_counter: int = 0
var fade_delta: int = 2
var fade_decreasing: bool = false
var fade_obj_toggle: bool = false
var fade_finishing: bool = false
var fade_finishing_counter: int = 0
var transfer_pending: bool = false


func _init() -> void:
	unfaded.resize(COLORS * 2)
	faded.resize(COLORS * 2)


## `LoadPalette`: [param bytes] at colour [param offset] in both buffers.
func load(bytes: PackedByteArray, offset: int) -> void:
	for index: int in mini(bytes.size(), (COLORS - offset) * 2):
		unfaded[offset * 2 + index] = bytes[index]
		faded[offset * 2 + index] = bytes[index]


## `AllocSpritePalette`; exhaustion returns 0xFF. LoadSpritePalette looks up existing tags before calling it.
func alloc_sprite(tag: int) -> int:
	for slot: int in range(reserved_sprite_count, 16):
		if sprite_tags.get(slot, 0xFFFF) == 0xFFFF:
			sprite_tags[slot] = tag
			return slot
	return 0xFF


func sprite_index(tag: int) -> int:
	for slot: int in range(reserved_sprite_count, 16):
		if sprite_tags.get(slot, 0xFFFF) == tag:
			return slot
	return 0xFF


func unfaded_color(index: int) -> int:
	return unfaded.decode_u16(index * 2)


func faded_color(index: int) -> int:
	return faded.decode_u16(index * 2)


## `CpuFastCopy` of [param count] colours from [member unfaded] to [member faded].
func copy_unfaded(offset: int, count: int) -> void:
	for index: int in count:
		faded.encode_u16((offset + index) * 2, unfaded_color(offset + index))


## `BlendPalette`: [param count] unfaded colours [param coeff]/16 of the way to [param color], into
## [member faded]. The shift floors, so a darkening step can land one below the exact sixteenth.
func blend(offset: int, count: int, coeff: int, color: int) -> void:
	for index: int in count:
		faded.encode_u16((offset + index) * 2, blend_color(unfaded_color(offset + index), coeff, color))


static func blend_color(from: int, coeff: int, color: int) -> int:
	var out: int = 0
	for shift: int in [0, 5, 10]:
		var channel: int = (from >> shift) & 31
		out |= (channel + ((((color >> shift) & 31) - channel) * coeff >> 4)) << shift
	return out & 0xFFFF


## `BeginNormalPaletteFade`, refused while a fade runs. A negative [param delay] speeds the step instead.
func begin_fade(selected: int, delay: int, start_y: int, target_y: int, color: int) -> bool:
	if fade_active:
		return false
	fade_delta = 2
	if delay < 0:
		fade_delta = (fade_delta - delay) & 15
		delay = 0
	fade_selected = selected & ALL
	fade_delay = delay & 63
	fade_delay_counter = fade_delay
	fade_y = start_y & 31
	fade_target = target_y & 31
	fade_color = color & 0x7FFF
	fade_active = true
	fade_decreasing = start_y >= target_y
	update_fade()
	transfer_pending = false
	return true


## `UpdatePaletteFade`: nothing until VBlank took the last frame's colours.
func update_fade() -> int:
	if transfer_pending:
		return Status.LOADING
	var status: int = _update_normal_fade()
	transfer_pending = fade_selected != 0
	return status


## VBlank's `TransferPlttBuffer`.
func transfer() -> void:
	transfer_pending = false


## `ResetPaletteFadeControl`.
func reset_fade() -> void:
	fade_active = false
	fade_selected = 0
	fade_y = 0
	fade_target = 0
	fade_color = 0
	fade_delay = 0
	fade_delay_counter = 0
	fade_delta = 2
	fade_decreasing = false
	fade_obj_toggle = false
	fade_finishing = false
	fade_finishing_counter = 0


## `UpdateNormalPaletteFade`: the BG half and the OBJ half on alternate calls, the delay counted before the BG
## half, and four more calls after the target before the fade ends (`IsSoftwarePaletteFadeFinishing`).
func _update_normal_fade() -> int:
	if not fade_active:
		return Status.DONE
	if fade_finishing:
		if fade_finishing_counter == 4:
			fade_active = false
			fade_finishing = false
			fade_finishing_counter = 0
		else:
			fade_finishing_counter += 1
		return Status.ACTIVE if fade_active else Status.DONE
	if not fade_obj_toggle:
		if fade_delay_counter < fade_delay:
			fade_delay_counter += 1
			return Status.DELAY
		fade_delay_counter = 0
	var selected: int = fade_selected >> 16 if fade_obj_toggle else fade_selected & 0xFFFF
	var offset: int = OBJ_OFFSET if fade_obj_toggle else 0
	while selected:
		if selected & 1:
			blend(offset, 16, fade_y, fade_color)
		selected >>= 1
		offset += 16
	fade_obj_toggle = not fade_obj_toggle
	if not fade_obj_toggle:
		if fade_y == fade_target:
			fade_selected = 0
			fade_finishing = true
		elif fade_decreasing:
			fade_y = maxi(fade_y - fade_delta, fade_target)
		else:
			fade_y = mini(fade_y + fade_delta, fade_target)
	return Status.ACTIVE
