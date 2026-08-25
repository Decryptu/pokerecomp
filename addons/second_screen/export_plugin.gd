@tool
extends EditorPlugin

## Links the second display's Android library into the gradle build.
##
## The library itself is Kotlin, under `kotlin/`, and is built by
## `tools/build_android_plugin.sh` into `bin/`. Nothing here runs at play time:
## the game reaches the plugin through [Gen2SecondScreenHost], which asks the
## engine for the singleton and finds nothing on every other platform.

const LIBRARY: String = "res://addons/second_screen/bin/second_screen.aar"

var _export: AndroidExportPlugin = null


func _enter_tree() -> void:
	_export = AndroidExportPlugin.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	if _export != null:
		remove_export_plugin(_export)
	_export = null


class AndroidExportPlugin extends EditorExportPlugin:
	func _get_name() -> String:
		return "second_screen"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	## One library for both targets: the plugin has no DEBUG_ENABLED of its own,
	## unlike the iOS one, because it links against nothing of the engine's C++.
	func _get_android_libraries(
		_platform: EditorExportPlatform, _debug: bool
	) -> PackedStringArray:
		if not FileAccess.file_exists(LIBRARY):
			push_warning(
				"No second-screen library at %s. Run tools/build_android_plugin.sh."
					% LIBRARY
			)
			return PackedStringArray()
		return PackedStringArray([LIBRARY])

	## None. The panel is a window on a display the platform already offers this
	## app, and Android asks for no permission to put one there.
	func _get_android_permissions(
		_platform: EditorExportPlatform, _debug: bool
	) -> PackedStringArray:
		return PackedStringArray()
