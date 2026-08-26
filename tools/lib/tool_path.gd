class_name Gen2ToolPath
extends RefCounted

## Refuses an output path that would be written inside this project.
##
## A tool runs with `--path <this project>`, so the project is what a path
## resolves against rather than the directory the command was run from. A bare
## `out.png` lands in the checkout and the editor then makes an `.import` file
## beside it. That is a hazard this project owns, since it is what `--path`
## points at, and it belongs to anything run against it: the mod repository's own
## twenty-five tools hit it too, which is why this is a `class_name` rather than
## a copy per tool.
##
## The test is where the path ends up, not how it is spelt. `res://out.png` is
## absolute to `is_absolute_path()` and lands in the project just as a bare name
## does, so a guard written on prefixes lets through the one thing it exists to
## stop. Globalizing answers the question directly and also catches an absolute
## path that happens to point into the checkout.
##
## `user://` is allowed: it is the userdata directory, which is where a tool's
## own scratch belongs and is not the project.


## True when [param path] is refused, having printed why. A tool quits on true.
static func refuses(path: String) -> bool:
	var reason: String = refusal(path)
	if reason.is_empty():
		return false
	print(reason)
	return true


## Why [param path] is refused, or "" when it is not. Separate from
## [method refuses] so a test can read the answer instead of the console.
static func refusal(path: String) -> String:
	if path.is_empty():
		return "no output path given"
	var project: String = ProjectSettings.globalize_path("res://").simplify_path()
	var full: String = ProjectSettings.globalize_path(path).simplify_path()
	## A relative path globalizes unchanged and Godot resolves it against the
	## project, so that is where it has to be measured. The separator is what
	## keeps a sibling directory whose name merely starts the same way out of it.
	if not full.is_absolute_path():
		full = project.path_join(full)
	if full != project and not full.begins_with(project.path_join("")):
		return ""
	return "refusing %s: it would be written to %s, inside the project. %s" % [
		path, full, "Give a path outside it, or a user:// one.",
	]


## The picture a preview tool is about to write, or null with the reason printed.
##
## `--headless` has no viewport texture, so `get_image()` answers null there and
## a tool run that way otherwise calls `save_png` on it once a frame until
## `godot.sh`'s wall clock cap. Every tool here is a windowed run; this is what
## says so out loud. The draw is folded in because a capture with no forced draw
## photographs the frame before the one that was just driven.
static func capture(root: Window) -> Image:
	RenderingServer.force_draw()
	var texture: ViewportTexture = root.get_texture()
	var image: Image = texture.get_image() if texture != null else null
	if image == null:
		print("no picture to capture: run this tool without --headless")
	return image
