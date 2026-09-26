extends GutTest

## `AnimateExpBar` (engine/battle/core.asm), as the bar's own walk.


func _settle(animation: Gen2ExpBarAnimation, limit: int = 4000) -> int:
	var frames: int = 0
	while not animation.finished() and frames < limit:
		animation.advance_frame()
		frames += 1
	return frames


## The frames each of the first pixels costs, which is `.LoopBarAnimation`'s own
## `d` held for two values at a time and floored at one.
func _delays(animation: Gen2ExpBarAnimation, count: int) -> Array[int]:
	var out: Array[int] = []
	var waited: int = 0
	while out.size() < count and waited < 4000:
		waited += 1
		if animation.advance_frame():
			out.append(waited)
			waited = 0
	return out


## `CalcExpBar` scales the exp still *owed* to the next level and subtracts it
## from 64, after shifting the owed figure and the span right together until
## the span fits a byte. Medium Fast level 30 spans 2791 points; 1395 owed is
## 89280 over 64, and four shifts make that 5580 over 174, a quotient of 32.
## An exact division would owe 31 and draw 33.
func test_pixels_are_calc_exp_bar_rather_than_an_exact_ratio() -> void:
	var rate: int = Gen2Experience.GROWTH_MEDIUM_FAST
	assert_eq(Gen2ExpBarAnimation.pixels_for(rate, 20, Gen2Experience.total_exp_at(rate, 20)), 0)
	assert_eq(
		Gen2ExpBarAnimation.pixels_for(rate, 20, Gen2Experience.total_exp_at(rate, 21)),
		Gen2ExpBarAnimation.LENGTH_PX
	)
	assert_eq(Gen2ExpBarAnimation.pixels_for(rate, 30, 27000 + 1396), 32)


## No `MAX_LEVEL` test stands in front of `CalcExpBar`: level 100 scales
## against `CalcExpAtLevel` 101, owes the whole span and draws nothing.
func test_the_bar_is_empty_at_the_maximum_level() -> void:
	var rate: int = Gen2Experience.GROWTH_MEDIUM_FAST
	assert_eq(
		Gen2ExpBarAnimation.pixels_for(
			rate, Gen2Experience.MAX_LEVEL,
			Gen2Experience.total_exp_at(rate, Gen2Experience.MAX_LEVEL)
		),
		0
	)


## `.PlayExpBarSound`'s `ld c, 10` / `call DelayFrames` runs before
## `.LoopBarAnimation` draws anything.
func test_ten_frames_are_spent_before_the_bar_moves() -> void:
	var animation := Gen2ExpBarAnimation.create(0, [8] as Array[int])
	for frame: int in Gen2ExpBarAnimation.LEAD_FRAMES:
		assert_false(animation.advance_frame(), "the lead draws nothing")
	assert_eq(animation.pixels(), 0)


## `ld d, 3`, spent twice per value, decremented and floored at one.
func test_the_bar_starts_slow_and_settles_at_a_frame_a_pixel() -> void:
	var animation := Gen2ExpBarAnimation.create(0, [8] as Array[int])
	for frame: int in Gen2ExpBarAnimation.LEAD_FRAMES:
		animation.advance_frame()
	assert_eq(_delays(animation, 8), [3, 3, 2, 2, 1, 1, 1, 1] as Array[int])
	assert_eq(animation.pixels(), 8)
	assert_true(animation.finished())


## `.LoopLevels` fills to `$40`, prints its line and loops with `ld b, $0`, so a
## gain over a level boundary is two walks rather than one.
func test_a_level_boundary_fills_the_bar_and_refills_it_from_empty() -> void:
	var animation := Gen2ExpBarAnimation.create(
		60, [Gen2ExpBarAnimation.LENGTH_PX, 3] as Array[int]
	)
	while not animation.segment_finished():
		animation.advance_frame()
	assert_eq(animation.pixels(), Gen2ExpBarAnimation.LENGTH_PX, "the level is reached full")
	assert_false(animation.finished(), "the second segment is still owed")
	assert_true(animation.paused(), "and it waits under the grew-to-level textbox")

	assert_eq(_settle(animation, 200), 200, "a paused bar never ticks on its own")
	animation.resume()
	_settle(animation)
	assert_eq(animation.pixels(), 3)
	assert_true(animation.finished())


## Nothing draws `ld b, $0` until the next `.LoopBarAnimation` runs, which is
## after the next `.PlayExpBarSound`. So the full bar stays up under the
## grew-to-level textbox and empties only when the new segment starts.
func test_the_full_bar_stays_up_across_the_level_message() -> void:
	var animation := Gen2ExpBarAnimation.create(
		63, [Gen2ExpBarAnimation.LENGTH_PX, 5] as Array[int]
	)
	while not animation.segment_finished():
		animation.advance_frame()
	animation.resume()

	for frame: int in Gen2ExpBarAnimation.LEAD_FRAMES - 1:
		animation.advance_frame()
		assert_eq(animation.pixels(), Gen2ExpBarAnimation.LENGTH_PX)
	animation.advance_frame()
	assert_eq(animation.pixels(), 0, "the new segment's first draw is the empty bar")


## `.LoopBarAnimation` draws and waits before it compares, so an award too small
## to move a pixel still costs its lead and one delay.
func test_a_gain_too_small_to_move_a_pixel_still_takes_its_time() -> void:
	var animation := Gen2ExpBarAnimation.create(12, [12] as Array[int])
	assert_false(animation.finished())
	assert_eq(
		_settle(animation), Gen2ExpBarAnimation.LEAD_FRAMES + Gen2ExpBarAnimation.START_DELAY
	)
	assert_eq(animation.pixels(), 12)


## Which is what lets the screen treat "no animation" and "arrived" as the same
## question.
func test_an_animation_with_no_segments_is_finished_and_never_ticks() -> void:
	var animation := Gen2ExpBarAnimation.create(20, [] as Array[int])
	assert_true(animation.finished())
	assert_false(animation.advance_frame())
