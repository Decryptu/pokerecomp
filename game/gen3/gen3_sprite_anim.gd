class_name Gen3SpriteAnim
extends RefCounted

## One sprite's image animation in `sprite.c`: `StartSpriteAnim`, `SeekSpriteAnim`
## and `AnimateSprite`'s `sAnimFuncs` over an imported `anims` table. Indices and
## the loop counter are u8 and the delay counter six bits, as in `struct Sprite`.

const SEQUENCE_LIMIT: int = 64
## `union AnimCmd` types in the low halfword; any other value is a frame's image.
const LOOP: int = 0xFFFD
const JUMP: int = 0xFFFE
const END: int = 0xFFFF

var anims: Array = []
var anim_num: int = 0
var cmd_index: int = 0
var delay: int = 0
var loop_counter: int = 0
var paused: bool = false
var ended: bool = false
var beginning: bool = false
## `oam.affineMode` on: frames then leave the flip bits alone.
var affine: bool = false
var image: int = 0
var h_flip: bool = false
var v_flip: bool = false


func start(number: int) -> void:
	anim_num = number & 0xFF
	beginning = true
	ended = false


func start_if_different(number: int) -> void:
	if anim_num != number & 0xFF:
		start(number)


## `SeekSpriteAnim` runs the command before [param index] with the pause lifted.
func seek(index: int) -> void:
	var held: bool = paused
	cmd_index = (index - 1) & 0xFF
	delay = 0
	beginning = false
	ended = false
	paused = false
	_continue()
	if delay != 0:
		delay = (delay + 1) & 0x3F
	paused = held


## `SetAndStartSpriteAnim` in `event_object_movement.c`.
func set_and_start(number: int, index: int) -> void:
	anim_num = number & 0xFF
	paused = false
	seek(index)


func animate() -> void:
	if beginning:
		_begin()
	else:
		_continue()


## An anim number past the imported table reads `ANIMCMD_END`; the cartridge
## reads whatever words follow the table.
func _cmd(index: int) -> int:
	var sequence: Array = anims[anim_num] if anim_num < anims.size() else []
	return int(sequence[index]) if index >= 0 and index < sequence.size() else END


## `BeginAnim` leaves `animBeginning` set on a sequence that opens with `ANIMCMD_END`.
func _begin() -> void:
	cmd_index = 0
	ended = false
	loop_counter = 0
	var word: int = _cmd(0)
	if word & 0xFFFF != END:
		beginning = false
		_frame(word)


func _continue() -> void:
	if delay != 0:
		if not paused:
			delay -= 1
		_flip(_cmd(cmd_index))
	elif not paused:
		cmd_index = (cmd_index + 1) & 0xFF
		var word: int = _cmd(cmd_index)
		match word & 0xFFFF:
			LOOP:
				loop_counter = (loop_counter - 1) & 0xFF if loop_counter != 0 else (word >> 16) & 0x3F
				_jump_to_loop_top()
				_continue()
			JUMP:
				cmd_index = (word >> 16) & 0x3F
				_frame(_cmd(cmd_index))
			END:
				cmd_index = (cmd_index - 1) & 0xFF
				ended = true
			_:
				_frame(word)


func _frame(word: int) -> void:
	var duration: int = (word >> 16) & 0x3F
	delay = maxi(duration - 1, 0)
	_flip(word)
	image = word & 0xFFFF
	if image >= 0x8000:
		image -= 0x10000


func _flip(word: int) -> void:
	if not affine:
		h_flip = bool(word >> 22 & 1)
		v_flip = bool(word >> 23 & 1)


## `JumpToTopOfAnimLoop`: back to the command after the previous `ANIMCMD_LOOP`,
## or the first, reading index -1 as the cartridge does before it stops at 0.
func _jump_to_loop_top() -> void:
	if loop_counter == 0:
		return
	cmd_index = (cmd_index - 1) & 0xFF
	while _cmd(cmd_index - 1) & 0xFFFF != LOOP:
		if cmd_index == 0:
			break
		cmd_index = (cmd_index - 1) & 0xFF
	cmd_index = (cmd_index - 1) & 0xFF
