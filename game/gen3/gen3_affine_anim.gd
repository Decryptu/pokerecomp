class_name Gen3AffineAnim
extends RefCounted

## `sprite.c` affine rows: [signed x, signed y, signed rotation, duration], or [control, operand].
const LOOP: int = 0x7FFD
const JUMP: int = 0x7FFE
const END: int = 0x7FFF

static var _bios_sine: PackedInt32Array = _bios_sine_table()

var anims: Array = []
var anim_num: int = 0
var cmd_index: int = 0
var delay: int = 0
var loop_counter: int = 0
var scale := Vector2i(256, 256)
var rotation: int = 0
var beginning: bool = true
var ended: bool = false
var paused: bool = false
var enabled: bool = true


func start(number: int) -> void:
	anim_num = number & 255
	scale = Vector2i(256, 256)
	rotation = 0
	beginning = true
	ended = false


func change(number: int) -> void:
	anim_num = number & 255
	beginning = true
	ended = false


func animate() -> void:
	if not enabled:
		return
	if beginning:
		if anims.is_empty() or int(anims[0][0][0]) == END:
			return
		cmd_index = 0
		loop_counter = 0
		beginning = false
		ended = false
		_frame(_cmd(0))
	else:
		_continue()


func _cmd(index: int) -> Array:
	var sequence: Array = anims[anim_num] if anim_num < anims.size() else []
	return sequence[index] if index >= 0 and index < sequence.size() else [END, 0]


func _continue() -> void:
	if paused:
		return
	if delay:
		delay -= 1
		_relative(_cmd(cmd_index))
		return
	cmd_index = (cmd_index + 1) & 255
	var row: Array = _cmd(cmd_index)
	match int(row[0]):
		LOOP:
			loop_counter = (loop_counter - 1) & 255 if loop_counter else int(row[1]) & 255
			_loop_top()
			_continue()
		JUMP:
			cmd_index = int(row[1]) & 255
			_frame(_cmd(cmd_index))
		END:
			ended = true
			cmd_index = (cmd_index - 1) & 255
		_:
			_frame(row)


func _loop_top() -> void:
	if not loop_counter:
		return
	cmd_index = (cmd_index - 1) & 255
	while int(_cmd(cmd_index - 1)[0]) != LOOP:
		if cmd_index == 0:
			break
		cmd_index = (cmd_index - 1) & 255
	cmd_index = (cmd_index - 1) & 255


func _frame(row: Array) -> void:
	delay = int(row[3]) & 255
	if delay:
		delay -= 1
		_relative(row)
	else:
		scale = Vector2i(_s16(int(row[0])), _s16(int(row[1])))
		rotation = (int(row[2]) << 8) & 65535


func _relative(row: Array) -> void:
	scale = Vector2i(_s16(scale.x + int(row[0])), _s16(scale.y + int(row[1])))
	rotation = (rotation + (int(row[2]) << 8)) & 65535


static func _s16(value: int) -> int:
	return ((value + 32768) & 65535) - 32768


## `ConvertScaleParam` then BIOS `ObjAffineSet`: signed reciprocals and 1.14 trig, negation after shifting.
func matrix() -> Vector4i:
	var x: int = _s16(65536 / scale.x) if scale.x else 0
	var y: int = _s16(65536 / scale.y) if scale.y else 0
	var angle: int = (rotation >> 8) & 255
	var sine: int = _bios_sine[angle]
	var cosine: int = _bios_sine[(angle + 64) & 255]
	return Vector4i(_s16((x * cosine) >> 14), _s16(-((x * sine) >> 14)),
		_s16((y * sine) >> 14), _s16((y * cosine) >> 14))


static func _bios_sine_table() -> PackedInt32Array:
	var table := PackedInt32Array()
	for angle: int in 256:
		table.append(int(sin(angle * TAU / 256.0) * 16384.0))
	return table
