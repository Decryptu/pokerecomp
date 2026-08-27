extends GutTest


func _spend(ring: Gen2WorldPhoneRing, frames: int) -> void:
	for _frame: int in frames:
		ring.advance_frame()


func test_source_ring_has_two_three_wait_cycles() -> void:
	var ring := Gen2WorldPhoneRing.new()
	assert_eq(ring.total_frames(), 120)
	assert_eq(ring.snapshot()["phase"], &"ringing")
	_spend(ring, 20)
	assert_eq(ring.snapshot()["phase"], &"caller_name")
	_spend(ring, 40)
	assert_eq(ring.snapshot()["ring"], 2)
	assert_eq(ring.snapshot()["phase"], &"ringing")
	assert_false(ring.is_finished())
	_spend(ring, 60)
	assert_true(ring.is_finished())
	assert_eq(ring.snapshot()["elapsed_frames"], 120)


func test_special_call_lead_precedes_the_same_two_rings() -> void:
	var ring := Gen2WorldPhoneRing.new(30)
	assert_eq(ring.total_frames(), 150)
	assert_eq(ring.snapshot()["phase"], &"pre_ring")
	_spend(ring, 30)
	assert_eq(ring.snapshot()["phase"], &"ringing")
	assert_eq(ring.snapshot()["ring"], 1)


## `HangUp`: `HangUp_Beep`'s click, then `HangUp_BoopOn` and `HangUp_BoopOff`
## three times each, twenty frames apiece and no button anywhere in it.
func test_hang_up_writes_the_click_then_three_boops() -> void:
	assert_eq(
		Gen2WorldPhoneRing.HANG_UP_PHASES.size(), Gen2WorldPhoneRing.HANG_UP_PHASE_COUNT
	)
	assert_eq(Gen2WorldPhoneRing.HANG_UP_FRAMES, 140)
	var phases: Array[StringName] = []
	for phase_index: int in Gen2WorldPhoneRing.HANG_UP_PHASE_COUNT:
		phases.append(Gen2WorldPhoneRing.hang_up_phase(
			phase_index * Gen2WorldPhoneRing.WAIT_FRAMES
		))
	assert_eq(phases, Gen2WorldPhoneRing.HANG_UP_PHASES)
	assert_eq(Gen2WorldPhoneRing.hang_up_phase(19), &"click")
	assert_eq(Gen2WorldPhoneRing.hang_up_phase(20), &"ellipse")
	assert_eq(
		Gen2WorldPhoneRing.hang_up_phase(Gen2WorldPhoneRing.HANG_UP_FRAMES), &"clear",
		"the last twenty frames are the box HangUp_BoopOff redraws"
	)
