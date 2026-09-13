class_name PokeDebugKeys
extends RefCounted

## Whether the development shortcuts and readouts are live. The editor, a
## headless run and a debug export answer true; a release export answers false
## and offers exactly the eight buttons. Each shortcut's method stays public
## either way, so the preview tools drive the same paths in a release build.

static func enabled() -> bool:
	return OS.is_debug_build()
