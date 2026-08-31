class_name Gen2TextLayout
extends RefCounted

## Breaking a string into the lines and pages a text box can show. Pure rules, no
## font and no screen, so a conversation's pagination can be checked without
## drawing anything. Widths count tiles rather than characters, since a ligature
## like "'s" is two of one and [method String.length] would wrap a column early.
## The cartridges do not wrap at all, their text being pre-broken at authoring
## time; a mod's string and a long name are what needs it.


## `Textbox`'s inner area: `TEXTBOX_INNERW` wide, and two rows two apart.
const TEXTBOX_COLUMNS: int = 18
const TEXTBOX_ROWS: int = 2


## Breaks [param text] into lines of at most [param columns] tiles.
##
## Explicit newlines are kept: a caller that has already decided where a line
## ends is obeyed, and only the runs between them are wrapped.
static func wrap_lines(text: String, columns: int) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if columns <= 0:
		return out

	for paragraph: String in text.split("\n"):
		var line: String = ""
		for word: String in _spaced_words(paragraph):
			var candidate: String = line + word
			if Gen2Text.encoded_length(candidate) <= columns:
				line = candidate
				continue

			if not line.is_empty():
				out.append(line)
				line = ""
				word = word.lstrip(" ")
				if Gen2Text.encoded_length(word) <= columns:
					line = word
					continue

			# A word too long for a line of its own is cut rather than allowed to
			# run off the edge. Nothing in these games is that long, but a mod's
			# text is not the cartridge's.
			while Gen2Text.encoded_length(word) > columns:
				var head: String = _take(word, columns)
				out.append(head)
				word = word.substr(head.length())
			line = word

		out.append(line)

	return out


## Each word with the spaces in front of it, so a line keeps the padding
## `PlaceString` prints. Only a wrap drops the spaces it breaks at.
static func _spaced_words(paragraph: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var trimmed: String = paragraph.rstrip(" ")
	var at: int = 0
	while at < trimmed.length():
		var start: int = at
		while at < trimmed.length() and trimmed[at] == " ":
			at += 1
		while at < trimmed.length() and trimmed[at] != " ":
			at += 1
		out.append(trimmed.substr(start, at - start))
	return out


## [method lay_out_pages] with each page's lines alone.
static func lay_out(text: String, columns: int, rows: int) -> Array:
	var out: Array = []
	for page: Dictionary in lay_out_pages(text, columns, rows):
		out.append(page["lines"])
	return out


## The same pages with what each of them costs to reach, which is what a box
## animating a scroll needs. `enter` is `page` for a `Paragraph`, whose box is
## cleared and which waits for a press first; `scroll` for `_ContText`, which
## waits and then runs `TextScroll` twice; and `scroll_nowait` for
## `_ContTextNoPause`, the same two scrolls with nothing waited for. The first
## page is `start`. `carried` is how many of the page's first lines the scroll
## moved up rather than printed, since `TextScroll` copies tiles and a carried
## line is already on screen.
static func lay_out_pages(text: String, columns: int, rows: int) -> Array:
	var out: Array = []
	if rows <= 0 or columns <= 0:
		return out
	var page: PackedStringArray = PackedStringArray()
	var enter: StringName = &"start"
	var carried: int = 0
	var at: int = 0
	while at <= text.length():
		var page_at: int = text.find(Gen2TextStream.PAGE_BREAK, at)
		var scroll_at: int = text.find(Gen2TextStream.SCROLL_BREAK, at)
		var nowait_at: int = text.find(Gen2TextStream.SCROLL_NOWAIT_BREAK, at)
		var stop: int = page_at
		for candidate: int in [scroll_at, nowait_at]:
			if candidate >= 0 and (stop < 0 or candidate < stop):
				stop = candidate
		var segment: String = text.substr(at, -1) if stop < 0 else text.substr(at, stop - at)
		for line: String in wrap_lines(segment, columns):
			page.append(line)
			if page.size() == rows:
				out.append({"lines": page, "enter": enter, "carried": carried})
				page = PackedStringArray()
				enter = &"page"
				carried = 0
		if stop < 0:
			break
		var scrolled: bool = stop == scroll_at or stop == nowait_at
		if not page.is_empty():
			out.append({"lines": page, "enter": enter, "carried": carried})
			page = PackedStringArray()
		enter = &"page"
		carried = 0
		if scrolled:
			enter = &"scroll" if stop == scroll_at else &"scroll_nowait"
			if not out.is_empty():
				var previous: PackedStringArray = out[out.size() - 1]["lines"]
				if not previous.is_empty():
					page.append(previous[previous.size() - 1])
					carried = 1
		at = stop + 1
	if not page.is_empty():
		out.append({"lines": page, "enter": enter, "carried": carried})
	return out


## What a box is left holding once [param text] has been printed to its end.
## `Paragraph` clears it between paragraphs, so a menu opens over the final page.
static func standing_page(
	text: String, columns: int = TEXTBOX_COLUMNS, rows: int = TEXTBOX_ROWS
) -> String:
	var pages: Array = lay_out_pages(text, columns, rows)
	if pages.is_empty():
		return ""
	return "\n".join(pages[pages.size() - 1]["lines"])


## The longest prefix of [param word] that fits in [param columns] tiles.
static func _take(word: String, columns: int) -> String:
	var length: int = 0
	while length < word.length():
		if Gen2Text.encoded_length(word.substr(0, length + 1)) > columns:
			break
		length += 1
	return word.substr(0, maxi(length, 1))
