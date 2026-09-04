extends GutTest

## The source budget: how much branching and how much prose the tree is allowed.

const ROOTS: Array[String] = ["autoload", "game", "mods", "tests", "tools"]
## Where the comment total is counted. The tests and the shipped example mods are
## left out: one is scaffolding and the other is written to be read.
const COUNTED_ROOTS: Array[String] = ["autoload", "game", "tools"]
## The project on disk. `res://` is the wrong door here: a test that has mounted
## a resource pack leaves entries under it whose backing zip is closed, and
## walking those raises `Parameter "zfile" is null` from inside the tier.
static var PROJECT: String = ProjectSettings.globalize_path("res://")

const MAX_COMPLEXITY: int = 20
const MAX_COMMENT_BLOCK: int = 8
## Comment lines under [constant COUNTED_ROOTS]. A ceiling, not a target: lower
## it whenever a pass leaves room. It moves up only while a generation the tree
## did not carry is being brought in, and then by what that generation's own
## files cost: `game/gen1`, `game/rom/rom_import.gd` and `tools/checks/gen1_*`
## are 580 lines of the 38600 here, and Generation 1's colour, sprites, wild
## tables, walk, text box, encounter roll, shop and Pokemon Center added 261 more
## to the shared collision, palette, world, encounter, text, save and renderer
## code. Four sweeps have said the tree has no restatement left to pay with.
const MAX_COMMENT_LINES: int = 38600

## The functions still over [constant MAX_COMPLEXITY], as `path:function`. Empty,
## and it stays empty: a function over the ceiling fails the test rather than
## joining a list.
const OVER_COMPLEXITY: Array[String] = []


func test_no_function_is_over_the_complexity_ceiling() -> void:
	var over: Array[String] = []
	for path: String in _scripts():
		var source: PackedStringArray = _lines(path)
		for row: Dictionary in _functions(source):
			if int(row["complexity"]) > MAX_COMPLEXITY:
				over.append("%s:%s" % [path, row["name"]])
	over.sort()
	var listed: Array[String] = OVER_COMPLEXITY.duplicate()
	listed.sort()
	var added: Array[String] = _missing_from(over, listed)
	var fixed: Array[String] = _missing_from(listed, over)
	_report("over complexity %d and not listed" % MAX_COMPLEXITY, added)
	_report("listed and no longer over the ceiling; delete the line", fixed)


func test_no_comment_block_is_longer_than_the_ceiling() -> void:
	var over: Array[String] = []
	for path: String in _scripts():
		var run: int = 0
		var line_number: int = 0
		for line: String in _lines(path):
			line_number += 1
			if line.strip_edges().begins_with("#"):
				run += 1
				continue
			if run > MAX_COMMENT_BLOCK:
				over.append("%s:%d is %d lines" % [path, line_number - run, run])
			run = 0
	_report("comment blocks over %d lines" % MAX_COMMENT_BLOCK, over)


func test_the_comment_total_is_under_the_recorded_ceiling() -> void:
	var total: int = 0
	for path: String in _scripts():
		if not _under(path, COUNTED_ROOTS):
			continue
		for line: String in _lines(path):
			if line.strip_edges().begins_with("#"):
				total += 1
	assert_true(total <= MAX_COMMENT_LINES, "%d comment lines under %s, ceiling %d" % [
		total, ", ".join(COUNTED_ROOTS), MAX_COMMENT_LINES,
	])
	if total < MAX_COMMENT_LINES:
		gut.p("Comment lines: %d. Lower MAX_COMMENT_LINES to it." % total)


## Fails with [param message] and prints every offender, since an assertion
## message is truncated long before a list like this ends.
func _report(message: String, offenders: Array[String]) -> void:
	for entry: String in offenders:
		gut.p("  %s" % entry)
	assert_eq(offenders.size(), 0, message)


## Every entry of [param wanted] that [param known] does not carry. Both are
## sorted, so this is the difference either way round.
func _missing_from(wanted: Array[String], known: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for entry: String in wanted:
		if not known.has(entry):
			out.append(entry)
	return out


func _under(path: String, roots: Array[String]) -> bool:
	for root: String in roots:
		if path.begins_with(root + "/"):
			return true
	return false


func _lines(path: String) -> PackedStringArray:
	return FileAccess.get_file_as_string(PROJECT.path_join(path)).split("\n")


## Every project script, by its path from the project root, in a stable order.
## `addons/` is third-party.
func _scripts() -> PackedStringArray:
	var out := PackedStringArray()
	for root: String in ROOTS:
		_collect(root, out)
	out.sort()
	return out


func _collect(directory: String, out: PackedStringArray) -> void:
	var absolute: String = PROJECT.path_join(directory)
	for file: String in DirAccess.get_files_at(absolute):
		if file.ends_with(".gd"):
			out.append(directory.path_join(file))
	for child: String in DirAccess.get_directories_at(absolute):
		_collect(directory.path_join(child), out)


## Every function in [param source] with its cyclomatic complexity, counted the
## way a linter counts it: one for the function, one per `if`, `elif`, `while`,
## `for`, `and`, `or` and inline `if`, and one per `match` arm, whether the arm
## opens a block or carries its body on the same line.
##
## An inner class's methods are functions too. Counting only the ones at column
## zero charged every one of them to whichever top-level function came last,
## which put `Gen2LauncherUI.level` at 33 for code in the class below it.
func _functions(source: PackedStringArray) -> Array[Dictionary]:
	var branches := RegEx.create_from_string(
		"(?<![A-Za-z0-9_.])(if|elif|while|for|and|or)(?![A-Za-z0-9_])"
	)
	var opener := RegEx.create_from_string("^\\t*(static\\s+)?func\\s+([A-Za-z0-9_]+)")
	var inner := RegEx.create_from_string("^class\\s+([A-Za-z0-9_]+)")
	var out: Array[Dictionary] = []
	var current: Dictionary = {}
	var scope: String = ""
	## One entry per open `match`: the indent the statement sits at, so an arm is
	## a line one deeper. An arm ends in a colon or carries its whole body after
	## one, and both are a branch: a one-line arm hid 89 of them here once.
	var matches: Array[int] = []
	var arm := RegEx.create_from_string("^[^:]*:")
	for raw: String in source:
		var code: String = _code(raw)
		var text: String = code.strip_edges()
		var nested: RegExMatch = inner.search(code)
		if nested != null:
			scope = nested.get_string(1) + "."
		var opened: RegExMatch = opener.search(code)
		if opened != null:
			var where: String = scope if code.begins_with("\t") else ""
			current = {"name": where + opened.get_string(2), "complexity": 1}
			out.append(current)
			matches.clear()
			continue
		if current.is_empty() or text.is_empty():
			continue
		var indent: int = code.length() - code.lstrip("\t").length()
		while not matches.is_empty() and indent <= matches[matches.size() - 1]:
			matches.resize(matches.size() - 1)
		if not matches.is_empty() and indent == matches[matches.size() - 1] + 1 \
			and arm.search(text) != null:
			current["complexity"] = int(current["complexity"]) + 1
		current["complexity"] = int(current["complexity"]) + branches.search_all(text).size()
		if text.begins_with("match ") and text.ends_with(":"):
			matches.append(indent)
	return out


## [param line] with its string literals and its comment blanked, so a keyword
## inside a text never reads as a branch.
func _code(line: String) -> String:
	var out: String = ""
	var quote: String = ""
	var index: int = 0
	while index < line.length():
		var symbol: String = line[index]
		if quote != "":
			if symbol == "\\":
				index += 2
				out += "  "
				continue
			if symbol == quote:
				quote = ""
			out += " "
		elif symbol == "\"" or symbol == "'":
			quote = symbol
			out += " "
		elif symbol == "#":
			break
		else:
			out += symbol
		index += 1
	return out
