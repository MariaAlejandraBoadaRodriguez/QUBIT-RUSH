extends Node
## Guest-only local persistence: atomic, versioned, corruption-tolerant.
##
## Files (all under user://, never synced anywhere):
##   save.json      current data
##   save.json.tmp  written first, verified, then renamed over save.json
##   save.json.bak  previous good copy, used when save.json is corrupt
## No personal or sensitive information is stored.

signal settings_changed(key: String, value)
signal progress_reset

const SAVE_VERSION := 2
const DEFAULT_PATH := "user://save.json"

const DEFAULT_SETTINGS := {
	"sfx": true,
	"music": false,
	"haptics": true,
	"reduced_motion": false,
	"large_text": false,
	"volume": 0.7,
}

var save_path := DEFAULT_PATH
var data := {}
## Set when the last load had to fall back to a backup or defaults.
var recovered_from_corruption := false
var autosave := true


func _ready() -> void:
	load_data()


static func defaults() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"levels": {},
		"settings": DEFAULT_SETTINGS.duplicate(),
		"in_progress": {},
		"daily": {},
		"rush": {"best": 0, "runs": 0},
		"consent": {"ads_choice": "unset", "ump_status": "unknown"},
		"ads": {"levels_since_interstitial": 0, "last_interstitial_unix": 0,
			"granted_rewards": [], "bonus_hints": {}},
		"stats": {"levels_completed": 0},
	}


## Loads from `path` (default save_path). Never throws; falls back safely.
func load_data(path := "") -> void:
	if path != "":
		save_path = path
	recovered_from_corruption = false
	var main = _read_json(save_path)
	if main != null:
		data = migrate(main)
		if not data.is_empty():
			return
	var bak = _read_json(save_path + ".bak")
	var main_exists := FileAccess.file_exists(save_path)
	if bak != null:
		var migrated := migrate(bak)
		if not migrated.is_empty():
			data = migrated
			recovered_from_corruption = main_exists
			return
	data = defaults()
	recovered_from_corruption = main_exists


func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return null
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return null
	return json.data


## Upgrades older save formats. Returns {} for unusable data.
static func migrate(d: Dictionary) -> Dictionary:
	var v = d.get("version", 1)
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
		return {}
	var version := int(v)
	if version > SAVE_VERSION or version < 1:
		return {}
	var out := d.duplicate(true)
	if version == 1:
		# v1 stored {"stars": {level_id: stars}} and flat settings booleans.
		var levels := {}
		var stars = out.get("stars", {})
		if typeof(stars) == TYPE_DICTIONARY:
			for id in stars:
				levels[id] = {"stars": clampi(int(stars[id]), 0, 3), "best_gates": -1}
		out.erase("stars")
		out["levels"] = levels
		var settings := DEFAULT_SETTINGS.duplicate()
		for k in ["sfx", "music", "haptics"]:
			if out.has(k):
				settings[k] = bool(out[k])
				out.erase(k)
		out["settings"] = settings
		out["version"] = 2
	# Fill any missing keys from defaults (forward compatible).
	var base := defaults()
	for k in base:
		if not out.has(k) or typeof(out[k]) != typeof(base[k]):
			out[k] = base[k]
	for k in DEFAULT_SETTINGS:
		if not out.settings.has(k):
			out.settings[k] = DEFAULT_SETTINGS[k]
	for k in base.ads:
		if not out.ads.has(k):
			out.ads[k] = base.ads[k]
	return out


## Atomic write: tmp file -> verify -> keep backup -> rename.
func save_data() -> bool:
	var text := JSON.stringify(data, "\t")
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Save failed: cannot open temp file.")
		return false
	f.store_string(text)
	f.close()
	if _read_json(tmp) == null:
		push_warning("Save failed: verification of temp file failed.")
		return false
	var dir := DirAccess.open(save_path.get_base_dir())
	if dir == null:
		return false
	var main_name := save_path.get_file()
	if dir.file_exists(main_name) and _read_json(save_path) != null:
		if dir.file_exists(main_name + ".bak"):
			dir.remove(main_name + ".bak")
		dir.rename(main_name, main_name + ".bak")
	elif dir.file_exists(main_name):
		dir.remove(main_name)
	return dir.rename(tmp.get_file(), main_name) == OK


func _changed() -> void:
	if autosave:
		save_data()


# ---- Levels ---------------------------------------------------------------

func level_stars(id: String) -> int:
	return int(data.levels.get(id, {}).get("stars", 0))


func is_completed(id: String) -> bool:
	return level_stars(id) > 0


## Records a result keeping the best stars / fewest gates. Returns true if improved.
func record_level(id: String, stars: int, gates: int) -> bool:
	if stars <= 0:
		return false
	var prev: Dictionary = data.levels.get(id, {"stars": 0, "best_gates": -1})
	var first := int(prev.stars) == 0
	var improved: bool = stars > int(prev.stars) or prev.best_gates < 0 or gates < int(prev.best_gates)
	data.levels[id] = {
		"stars": maxi(stars, int(prev.stars)),
		"best_gates": gates if prev.best_gates < 0 else mini(gates, int(prev.best_gates)),
	}
	if first:
		data.stats.levels_completed = int(data.stats.levels_completed) + 1
	data.in_progress.erase(id)
	_changed()
	return improved


func total_stars() -> int:
	var t := 0
	for id in data.levels:
		t += int(data.levels[id].get("stars", 0))
	return t


# ---- In-progress circuits (survive backgrounding and process death) ------

func set_in_progress(id: String, ops: Array) -> void:
	if ops.is_empty():
		data.in_progress.erase(id)
	else:
		data.in_progress[id] = ops.duplicate(true)
	_changed()


func get_in_progress(id: String) -> Array:
	var ops = data.in_progress.get(id, [])
	if typeof(ops) != TYPE_ARRAY:
		return []
	var out := []
	for op in ops:
		if typeof(op) != TYPE_DICTIONARY:
			return []
		var o := {"gate": str(op.get("gate", "")), "target": int(op.get("target", -1))}
		if op.has("control"):
			o["control"] = int(op.control)
		out.append(o)
	return out


# ---- Settings ---------------------------------------------------------------

func get_setting(key: String):
	return data.settings.get(key, DEFAULT_SETTINGS.get(key))


func set_setting(key: String, value) -> void:
	data.settings[key] = value
	_changed()
	settings_changed.emit(key, value)


# ---- Daily / Rush -------------------------------------------------------------

func is_daily_done(date: String) -> bool:
	return data.daily.has(date)


func record_daily(date: String, stars: int) -> void:
	data.daily[date] = maxi(stars, int(data.daily.get(date, 0)))
	_changed()


func record_rush(score: int) -> bool:
	data.rush.runs = int(data.rush.runs) + 1
	var best := score > int(data.rush.best)
	if best:
		data.rush.best = score
	_changed()
	return best


# ---- Reset ------------------------------------------------------------------

## Clears progress but keeps settings and privacy choices.
func reset_progress() -> void:
	var keep_settings: Dictionary = data.settings.duplicate()
	var keep_consent: Dictionary = data.consent.duplicate()
	data = defaults()
	data.settings = keep_settings
	data.consent = keep_consent
	save_data()
	progress_reset.emit()
