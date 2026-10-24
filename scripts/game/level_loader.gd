class_name LevelLoader
extends RefCounted
## Loads level JSON listed in res://data/levels/index.json.
## Invalid levels are reported and skipped; loading never crashes the game.

const LEVEL_DIR := "res://data/levels/"
const INDEX_PATH := "res://data/levels/index.json"


static func parse_json_text(text: String):
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data


## Returns {"levels": Array[LevelData] sorted by number, "errors": Array[String]}.
static func load_all(index_path := INDEX_PATH) -> Dictionary:
	var levels: Array = []
	var errors: Array[String] = []
	var index_text := FileAccess.get_file_as_string(index_path)
	var index = parse_json_text(index_text)
	if typeof(index) != TYPE_DICTIONARY or typeof(index.get("levels", null)) != TYPE_ARRAY:
		errors.append("Level index is missing or malformed.")
		return {"levels": levels, "errors": errors}
	var base := index_path.get_base_dir() + "/"
	var seen := {}
	for file in index.levels:
		if typeof(file) != TYPE_STRING:
			errors.append("Level index entry is not a file name.")
			continue
		var res := load_file(base + file)
		if res.level == null:
			errors.append("%s: %s" % [file, "; ".join(res.errors)])
			continue
		var L: LevelData = res.level
		if seen.has(L.id):
			errors.append("%s: duplicate level id %s." % [file, L.id])
			continue
		seen[L.id] = true
		levels.append(L)
	levels.sort_custom(func(a, b): return a.number < b.number)
	return {"levels": levels, "errors": errors}


## Returns {"level": LevelData or null, "errors": Array[String]}.
static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"level": null, "errors": ["File not found."] as Array[String]}
	return load_text(FileAccess.get_file_as_string(path))


static func load_text(text: String) -> Dictionary:
	var d = parse_json_text(text)
	if d == null:
		return {"level": null, "errors": ["Malformed JSON."] as Array[String]}
	var errors := LevelSchema.validate(d)
	if not errors.is_empty():
		return {"level": null, "errors": errors}
	return {"level": LevelSchema.parse(d), "errors": errors}
