class_name Gen3Random
extends RefCounted

## `random.c`: `gRngValue` and `Random`, the one stream object movement, berry yields and the weather draw from.

var value: int = 0


func next() -> int:
	value = (value * 0x41C64E6D + 0x6073) & 0xFFFFFFFF
	return value >> 16
