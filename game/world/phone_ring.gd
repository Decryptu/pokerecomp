class_name Gen2WorldPhoneRing
extends RefCounted

## `RingTwice_StartCall`'s timing, scene-free: two rings of three twenty-frame
## waits each.

const RING_COUNT: int = 2
const WAITS_PER_RING: int = 3
const WAIT_FRAMES: int = 20
const RING_FRAMES: int = WAITS_PER_RING * WAIT_FRAMES
const TOTAL_FRAMES: int = RING_COUNT * RING_FRAMES

## `Phone_CallerTextbox`, and where `Phone_TextboxWithName` writes '☎' and the name.
const CALLER_BOX_SIZE := Vector2i(20, 4)
const CALLER_PHONE_AT := Vector2i(1, 1)
const CALLER_NAME_AT := Vector2i(3, 1)
const PHASE_PRE_RING: StringName = &"pre_ring"
const PHASE_RINGING: StringName = &"ringing"
const PHASE_CALLER_NAME: StringName = &"caller_name"
const PHASE_CALLER_BOX: StringName = &"caller_box"


static func caller_box_text(data: GameData, contact: Dictionary, phase: StringName) -> Array:
	if phase != PHASE_CALLER_NAME:
		return []
	var placed: Array = [[CALLER_PHONE_AT, "☎"]]
	for row: Array in Gen2WorldPhoneHost.caller_name_rows(data, contact):
		placed.append([CALLER_NAME_AT + (row[0] as Vector2i), row[1]])
	return placed


## `HangUp`: `HangUp_Beep`'s `Click!`, then three turns of `HangUp_BoopOn`'s `……`
## and `HangUp_BoopOff`'s blank box, twenty frames each and no button read.
const HANG_UP_PHASES: Array[StringName] = [
	&"click", &"ellipse", &"clear", &"ellipse", &"clear", &"ellipse", &"clear",
]
const HANG_UP_PHASE_COUNT: int = 7
const HANG_UP_FRAMES: int = HANG_UP_PHASE_COUNT * WAIT_FRAMES


## Which of the seven `HangUp` writes is on the box [param elapsed] frames in.
static func hang_up_phase(elapsed: int) -> StringName:
	var index: int = clampi(elapsed / WAIT_FRAMES, 0, HANG_UP_PHASES.size() - 1)
	return HANG_UP_PHASES[index]


static func hang_up_line(metadata: Dictionary, phase: StringName) -> String:
	if phase == &"click":
		return String(metadata.get("hang_up_click", ""))
	if phase == &"ellipse":
		return String(metadata.get("hang_up_ellipse", ""))
	return ""


var _elapsed_frames: int = 0
var _lead_frames: int = 0


func _init(lead_frames: int = 0) -> void:
	_lead_frames = maxi(0, lead_frames)


func advance_frame() -> Dictionary:
	_elapsed_frames = mini(_elapsed_frames + 1, total_frames())
	return snapshot()


func is_finished() -> bool:
	return _elapsed_frames >= total_frames()


## Whether the next frame opens a ring, behind `Phone_StartRinging`'s `WaitSFX`.
func opens_ring() -> bool:
	if _elapsed_frames == 0 and _lead_frames == 0:
		return true
	var next: int = _elapsed_frames + 1 - _lead_frames
	return next >= 0 and next < TOTAL_FRAMES and next % RING_FRAMES == 0


func elapsed_frames() -> int:
	return _elapsed_frames


func total_frames() -> int:
	return _lead_frames + TOTAL_FRAMES


func snapshot() -> Dictionary:
	var ringing_frames: int = maxi(0, _elapsed_frames - _lead_frames)
	var ring_index: int = 0
	var phase: StringName = PHASE_PRE_RING
	if ringing_frames > 0 or _elapsed_frames >= _lead_frames:
		ring_index = mini(ringing_frames / RING_FRAMES, RING_COUNT - 1)
		var phase_index: int = (ringing_frames % RING_FRAMES) / WAIT_FRAMES
		phase = [PHASE_RINGING, PHASE_CALLER_NAME, PHASE_CALLER_BOX][phase_index % 3]
	if is_finished():
		ring_index = RING_COUNT - 1
		phase = PHASE_CALLER_NAME
	return {
		"ring": ring_index + 1 if phase != PHASE_PRE_RING else 0,
		"rings": RING_COUNT,
		"phase": phase,
		"elapsed_frames": _elapsed_frames,
		"total_frames": total_frames(),
		"finished": is_finished(),
	}
