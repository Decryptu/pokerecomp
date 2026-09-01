class_name Gen2HpBarAnimation
extends RefCounted

## The HP bar draining or filling, one pixel at a time
## (engine/battle/anim_hp_bar.asm). The bar arrives before the message that
## describes the hit: `NormalHit` runs `applydamage` before `criticaltext`.
## `_AnimateHPBar`'s two branches are keyed on whether the maximum reaches
## `HP_BAR_LENGTH_PX`; both redraw one pixel per iteration, and what differs is
## the HP number [method hp] answers.

## `HP_BAR_LENGTH * TILE_WIDTH`, the bar's full width in pixels.
const LENGTH_PX: int = Gen2BattleHud.HP_BAR_TILES * Gen2BattleHud.TILE

## `HPBarAnim_BGMapUpdate` waits two frames per redraw on both paths: a battle bar
## is `wWhichHPBar` 0 or 1, which takes `.finish`'s two `DelayFrame`s.
const FRAMES_PER_STEP: int = 2

var _max_hp: int = 0
var _from_hp: int = 0
var _to_hp: int = 0
var _pixels: int = 0
var _target_pixels: int = 0
var _frames: int = 0

var _hp: int = 0


## A bar already at its destination is finished on arrival and never ticks.
static func create(from_hp: int, to_hp: int, max_hp: int) -> Gen2HpBarAnimation:
	var animation := Gen2HpBarAnimation.new()
	animation._max_hp = max_hp
	animation._from_hp = from_hp
	animation._to_hp = to_hp
	animation._hp = from_hp
	animation._pixels = Gen2BattleHud.bar_pixels(from_hp, max_hp, LENGTH_PX)
	animation._target_pixels = Gen2BattleHud.bar_pixels(to_hp, max_hp, LENGTH_PX)
	return animation


func finished() -> bool:
	return _pixels == _target_pixels


func pixels() -> int:
	return _pixels


## One hardware frame. Answers whether the bar moved, so the screen redraws.
func advance_frame() -> bool:
	if finished():
		return false
	_frames += 1
	if _frames < FRAMES_PER_STEP:
		return false
	_frames = 0
	_pixels += 1 if _target_pixels > _pixels else -1
	_walk_hp_to_pixels()
	return true


## `LongAnim_UpdateVariables`' own loop: it steps `wCurHPAnimOldHP` one HP at a
## time until the bar it recomputes draws the pixel count just reached.
func _walk_hp_to_pixels() -> void:
	if _max_hp < LENGTH_PX:
		return
	var step: int = 1 if _to_hp > _hp else -1
	while _hp != _to_hp:
		if Gen2BattleHud.bar_pixels(_hp, _max_hp, LENGTH_PX) == _pixels:
			return
		_hp += step


## The HP to print beside the bar while it moves, and the real value once it has
## arrived. The long branch prints the HP it walked to; the short branch never
## walks, and answers from `ShortHPBar_CalcPixelFrame` instead.
func hp() -> int:
	if finished():
		return _to_hp
	if _max_hp <= 0:
		return 0
	if _max_hp < LENGTH_PX:
		return _short_bar_hp()
	return _hp


## `ShortHPBar_CalcPixelFrame`, which recovers an HP number from a pixel count
## under a maximum narrower than the bar. Its loop subtracts before it tests, so an
## exact multiple of the width is counted and then rounded up again: one HP too
## many, `docs/bugs_and_glitches.md`'s low-HP off-by-one, where pret's fix stops on
## the zero. `wCurHPAnimLowHP`/`wCurHPAnimHighHP` clamp it to this drain's ends.
func _short_bar_hp() -> int:
	if _pixels >= LENGTH_PX:
		return _max_hp
	if _pixels <= 0:
		return 0
	var total: int = _max_hp * _pixels
	var counted: int = 0
	var rest: int = total
	while true:
		rest -= LENGTH_PX
		if rest < 0:
			break
		if rest == 0 and not Gen2Rules.hardware(&"short_hp_bar_number_off_by_one"):
			break
		counted += 1
	if rest + 0x80 - LENGTH_PX >= 0:
		counted += 1
	return clampi(counted, mini(_from_hp, _to_hp), maxi(_from_hp, _to_hp))
