class_name DialogueBank
extends RefCounted
## Central JSON dialogue repository and Zelda-style semantic rich-text formatter
## for customers, Trixie reactions, tutorials, and wave closings.

const CUSTOMERS_PATH: String = "res://data/dialogues/customers.json"
const TRIXIE_PATH: String = "res://data/dialogues/trixie.json"

const SEMANTIC_TAGS: Dictionary = {
	"pocion": "#b31b58",
	"secreto": "#6b21a8",
	"clave": "#2541a8",
	"alerta": "#b91c1c",
	"naturaleza": "#1b6e42",
	"oro": "#9a5b08",
}

static var _customers_data: Dictionary = {}
static var _trixie_data: Dictionary = {}
static var _loaded: bool = false


static func reload() -> void:
	_customers_data = _load_json_dict(CUSTOMERS_PATH)
	_trixie_data = _load_json_dict(TRIXIE_PATH)
	_loaded = true


static func _ensure_loaded() -> void:
	if not _loaded:
		reload()


static func _load_json_dict(path: String) -> Dictionary:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


static func format_rich_text(raw_text: String) -> String:
	var formatted: String = raw_text
	for tag_key: Variant in SEMANTIC_TAGS:
		var tag: String = String(tag_key)
		var hex: String = String(SEMANTIC_TAGS[tag_key])
		formatted = formatted.replace("{%s}" % tag, "[b][color=%s]" % hex)
		formatted = formatted.replace("{/%s}" % tag, "[/color][/b]")
	return formatted


static func strip_tags(raw_text: String) -> String:
	var clean: String = raw_text
	for tag_key: Variant in SEMANTIC_TAGS:
		var tag: String = String(tag_key)
		clean = clean.replace("{%s}" % tag, "")
		clean = clean.replace("{/%s}" % tag, "")
	return clean


static func _apply_vars(template: String, vars: Dictionary) -> String:
	var result: String = template
	for k_var: Variant in vars:
		var k: String = str(k_var)
		result = result.replace("{%s}" % k, str(vars[k_var]))
	return result


static func get_customer_lines(customer_id: StringName, category: String) -> Array[String]:
	_ensure_loaded()
	var customers: Dictionary = _customers_data.get("customers", {}) as Dictionary
	var entry: Dictionary = customers.get(String(customer_id), {}) as Dictionary
	var raw_arr: Array = entry.get(category, []) as Array
	if raw_arr.is_empty():
		var fallbacks: Dictionary = _customers_data.get("fallbacks", {}) as Dictionary
		raw_arr = fallbacks.get(category, []) as Array
	var out: Array[String] = []
	for item: Variant in raw_arr:
		var s: String = String(item)
		if s != "":
			out.append(s)
	return out


static func pick_customer_line(customer_id: StringName, category: String) -> String:
	var lines: Array[String] = get_customer_lines(customer_id, category)
	if lines.is_empty():
		return ""
	return lines[randi() % lines.size()]


static func get_trixie_reaction(key: String, vars: Dictionary = {}) -> String:
	_ensure_loaded()
	var reactions: Dictionary = _trixie_data.get("reactions", {}) as Dictionary
	var tmpl: String = String(reactions.get(key, ""))
	return _apply_vars(tmpl, vars) if not vars.is_empty() else tmpl


static func get_trixie_tutorial(key: String, vars: Dictionary = {}) -> String:
	_ensure_loaded()
	var tutorials: Dictionary = _trixie_data.get("tutorials", {}) as Dictionary
	var tmpl: String = String(tutorials.get(key, ""))
	return _apply_vars(tmpl, vars) if not vars.is_empty() else tmpl


static func get_trixie_gallery_quotes() -> PackedStringArray:
	_ensure_loaded()
	var raw_arr: Array = _trixie_data.get("gallery_quotes", []) as Array
	var out: PackedStringArray = PackedStringArray()
	for item: Variant in raw_arr:
		out.append(strip_tags(String(item)))
	return out


static func get_stop_closing_lines(stop_id: StringName, victory: bool) -> Array[Dictionary]:
	_ensure_loaded()
	var closings: Dictionary = _trixie_data.get("stop_closings", {}) as Dictionary
	var branch_key: String = "victory" if victory else "timeout"
	var stop_entry: Dictionary = closings.get(String(stop_id), {}) as Dictionary
	var raw_arr: Array = stop_entry.get(branch_key, []) as Array
	if raw_arr.is_empty():
		var def_entry: Dictionary = closings.get("default", {}) as Dictionary
		raw_arr = def_entry.get(branch_key, []) as Array
	var out: Array[Dictionary] = []
	for item: Variant in raw_arr:
		if item is Dictionary:
			out.append((item as Dictionary).duplicate())
	return out
