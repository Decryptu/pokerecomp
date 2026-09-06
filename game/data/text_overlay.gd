class_name Gen2TextOverlay
extends RefCounted

## Boxes a mod rewrites, read ahead of the cartridge's own by
## [method GameData.text]. See `docs/MODS.md`.

## The run a map dialogue is addressed under; [method world_name] packs its name.
const RUN_WORLD: StringName = &"world"

static var _shared: Gen2TextOverlay = null

## run to name to the replacement text.
var _texts: Dictionary = {}
## run to name to the mod id that claimed it, so a conflict can name both.
var _owners: Dictionary = {}


static func shared() -> Gen2TextOverlay:
	if _shared == null:
		_shared = Gen2TextOverlay.new()
	return _shared


static func reset() -> void:
	_shared = null


func is_empty() -> bool:
	return _texts.is_empty()


## Replaces one box. Shape only, a Crystal-only box having to install on Gold.
func patch(run: StringName, name: String, id: StringName, text: String) -> Dictionary:
	if String(run).is_empty() or name.is_empty():
		return {"ok": false, "reason": &"invalid_text_key", "detail": "%s %s" % [run, name]}
	if text.is_empty():
		return {"ok": false, "reason": &"empty_text", "detail": "%s %s" % [run, name]}
	var claimed: Dictionary = _claim(run, name, id)
	if not bool(claimed.get("ok", false)):
		return claimed
	var run_texts: Dictionary = _texts.get(run, {})
	run_texts[name] = text
	_texts[run] = run_texts
	return {"ok": true, "run": run, "name": name}


## The text a reader gets. A box this cartridge does not ship stays empty rather
## than conjured, the way a patched content row does: a screen reads empty as
## "use my own wording".
func resolve(run: StringName, name: String, base: String) -> String:
	var run_texts: Variant = _texts.get(run, {})
	if base.is_empty() or not run_texts is Dictionary:
		return base
	return String((run_texts as Dictionary).get(name, base))


func clear_owner(id: StringName) -> void:
	for run: StringName in _owners.keys():
		for name: String in (_owners[run] as Dictionary).keys():
			if (_owners[run] as Dictionary)[name] != id:
				continue
			(_owners[run] as Dictionary).erase(name)
			(_texts.get(run, {}) as Dictionary).erase(name)
		if (_owners[run] as Dictionary).is_empty():
			_owners.erase(run)
			_texts.erase(run)


static func world_name(bank: int, address: int) -> String:
	return Gen2WorldScript.pointer_key(bank, address)


func _claim(run: StringName, name: String, id: StringName) -> Dictionary:
	var run_owners: Dictionary = _owners.get(run, {})
	var held: StringName = StringName(run_owners.get(name, &""))
	if held != &"" and held != id:
		return {
			"ok": false, "reason": &"duplicate_text", "detail": "%s %s" % [run, name],
		}
	run_owners[name] = id
	_owners[run] = run_owners
	return {"ok": true}
