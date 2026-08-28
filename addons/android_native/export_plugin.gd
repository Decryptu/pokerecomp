@tool
extends EditorPlugin

## Links this project's Android library into the gradle build.
##
## One AAR, two plugins: the lower display of a dual-screen handheld and the
## battery reading, neither of which the engine offers. The library is Kotlin,
## under `kotlin/`, and is built by `tools/build_android_plugin.sh` into `bin/`.
## Nothing here runs at play time: the game reaches each plugin through
## [Gen2SecondScreenHost] and [Gen2LauncherBattery], which ask the engine for
## the singleton and find nothing on every other platform.

const LIBRARY: String = "res://addons/android_native/bin/android_native.aar"

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
		return "android_native"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	## One library for both targets: nothing here has a DEBUG_ENABLED of its own,
	## unlike the iOS plugins, because it links against nothing of the engine's
	## C++.
	func _get_android_libraries(
		_platform: EditorExportPlatform, _debug: bool
	) -> PackedStringArray:
		if not FileAccess.file_exists(LIBRARY):
			push_warning(
				"No Android library at %s. Run tools/build_android_plugin.sh." % LIBRARY
			)
			return PackedStringArray()
		return PackedStringArray([LIBRARY])

	## None. The panel is a window on a display the platform already offers this
	## app, and a battery broadcast is public: Android asks for no permission for
	## either.
	func _get_android_permissions(
		_platform: EditorExportPlatform, _debug: bool
	) -> PackedStringArray:
		return PackedStringArray()
