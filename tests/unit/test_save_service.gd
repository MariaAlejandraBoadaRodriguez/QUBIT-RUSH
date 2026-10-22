extends GutTest
## Save/load, migrations and corruption recovery (Gate C persistence).

const PATH := "user://test_save.json"


func before_each() -> void:
	for f in [PATH, PATH + ".tmp", PATH + ".bak"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	SaveService.load_data(PATH)


func after_all() -> void:
	for f in [PATH, PATH + ".tmp", PATH + ".bak"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	SaveService.load_data(SaveService.DEFAULT_PATH)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_fresh_install_has_defaults() -> void:
	assert_false(SaveService.recovered_from_corruption)
	assert_eq(int(SaveService.data.version), SaveService.SAVE_VERSION)
	assert_eq(SaveService.total_stars(), 0)
	assert_eq(SaveService.data.consent.ads_choice, "unset", "no ads opt-in by default")


func test_save_and_reload_preserves_progress() -> void:
	SaveService.record_level("L01", 3, 1)
	SaveService.record_level("L02", 2, 2)
	SaveService.set_setting("reduced_motion", true)
	SaveService.set_in_progress("L03", [{"gate": "X", "target": 0}])
	SaveService.load_data(PATH)
	assert_eq(SaveService.level_stars("L01"), 3)
	assert_eq(SaveService.level_stars("L02"), 2)
	assert_true(bool(SaveService.get_setting("reduced_motion")))
	assert_eq(SaveService.get_in_progress("L03"), [{"gate": "X", "target": 0}])
	assert_false(SaveService.recovered_from_corruption)


func test_best_result_is_kept() -> void:
	SaveService.record_level("L01", 3, 1)
	SaveService.record_level("L01", 1, 3)
	assert_eq(SaveService.level_stars("L01"), 3)
	assert_eq(int(SaveService.data.levels.L01.best_gates), 1)
	assert_false(SaveService.record_level("L05", 0, 2), "failures are not recorded")
	assert_false(SaveService.is_completed("L05"))


func test_corrupt_save_recovers_from_backup() -> void:
	SaveService.record_level("L01", 2, 2)
	SaveService.record_level("L02", 1, 3)  # creates .bak with L01 only
	_write(PATH, "{ corrupted")
	SaveService.load_data(PATH)
	assert_true(SaveService.recovered_from_corruption)
	assert_eq(SaveService.level_stars("L01"), 2, "restored from backup")


func test_corrupt_save_without_backup_uses_defaults() -> void:
	_write(PATH, "\u0000\u0001garbage")
	SaveService.load_data(PATH)
	assert_true(SaveService.recovered_from_corruption)
	assert_eq(SaveService.total_stars(), 0)
	assert_true(SaveService.save_data(), "can save again after recovery")


func test_wrong_types_are_repaired() -> void:
	_write(PATH, JSON.stringify({"version": 2, "levels": "oops", "settings": {"sfx": false}}))
	SaveService.load_data(PATH)
	assert_eq(typeof(SaveService.data.levels), TYPE_DICTIONARY)
	assert_false(bool(SaveService.get_setting("sfx")), "valid setting kept")
	assert_true(bool(SaveService.get_setting("haptics")), "missing setting defaulted")


func test_future_version_is_not_trusted() -> void:
	_write(PATH, JSON.stringify({"version": 999, "levels": {"L01": {"stars": 3}}}))
	SaveService.load_data(PATH)
	assert_eq(SaveService.level_stars("L01"), 0)


func test_v1_migration() -> void:
	_write(PATH, JSON.stringify({"version": 1, "stars": {"L01": 3, "L02": 2}, "sfx": false, "music": true}))
	SaveService.load_data(PATH)
	assert_eq(int(SaveService.data.version), 2)
	assert_eq(SaveService.level_stars("L01"), 3)
	assert_eq(SaveService.level_stars("L02"), 2)
	assert_false(bool(SaveService.get_setting("sfx")))
	assert_true(bool(SaveService.get_setting("music")))
	assert_false(SaveService.data.has("stars"))


func test_atomic_write_leaves_no_temp_file() -> void:
	SaveService.record_level("L01", 1, 1)
	assert_false(FileAccess.file_exists(PATH + ".tmp"))
	assert_true(FileAccess.file_exists(PATH))


func test_reset_keeps_settings() -> void:
	SaveService.record_level("L01", 3, 1)
	SaveService.set_setting("music", true)
	SaveService.reset_progress()
	assert_eq(SaveService.total_stars(), 0)
	assert_true(bool(SaveService.get_setting("music")))


func test_corrupt_in_progress_circuit_is_ignored() -> void:
	SaveService.data.in_progress["L01"] = "bad"
	assert_eq(SaveService.get_in_progress("L01"), [])
	SaveService.data.in_progress["L01"] = [1, 2]
	assert_eq(SaveService.get_in_progress("L01"), [])


func test_save_contains_no_personal_fields() -> void:
	var text := JSON.stringify(SaveService.data).to_lower()
	for word in ["email", "name\":", "birth", "phone", "location", "advertising_id"]:
		assert_false(text.contains(word), "no %s in save" % word)
