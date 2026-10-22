extends GutTest
## Layout checks across aspect ratios, tablet size and large text:
## no horizontal overflow, minimum content fits, touch targets >= 48dp.

const H = preload("res://tests/ui/ui_helpers.gd")
const PATH := "user://test_layout_save.json"
## Viewport sizes produced by canvas_items/expand stretch from a 720x1440 base:
## 16:9 phone, 19.5:9 phone, 20:9 phone, 10:16 tablet, compact 4:3-ish phone.
const SIZES := [Vector2i(810, 1440), Vector2i(720, 1560), Vector2i(720, 1600), Vector2i(900, 1440), Vector2i(720, 1440)]


func before_all() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	SaveService.load_data(PATH)
	SaveService.set_setting("reduced_motion", true)
	GameState.capture_navigation = true
	for L in GameState.levels.slice(0, 12):
		SaveService.record_level(L.id, 2, 2)


func after_all() -> void:
	SaveService.set_setting("large_text", false)
	GameState.capture_navigation = false
	SaveService.load_data(SaveService.DEFAULT_PATH)


func _mount(screen: String, sz: Vector2i) -> Array:
	var vp := SubViewport.new()
	vp.size = sz
	vp.gui_disable_input = true
	add_child_autofree(vp)
	var s := H.screen(GameState.SCREENS[screen])
	vp.add_child(s)
	await wait_physics_frames(3)
	return [vp, s]


func _inside_scroll(c: Control) -> bool:
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false


func _check(screen: String, sz: Vector2i, select_cnot := false) -> void:
	var r := await _mount(screen, sz)
	var s: Control = r[1]
	if select_cnot:
		# Worst case for width: a selected CNOT shows every action button.
		s.editor.place_gate("H")
		s.editor.place_gate("CNOT")
		s.editor.select_op(1)
		await wait_physics_frames(2)
	var label := "%s @ %dx%d" % [screen, sz.x, sz.y]
	var margin: Control = s.margin
	assert_lte(margin.get_combined_minimum_size().y, float(sz.y) + 1.0, "content fits vertically: " + label)
	assert_lte(margin.get_combined_minimum_size().x, float(sz.x) + 1.0, "content fits horizontally: " + label)
	for c in H.find_all(s, "Control"):
		if not c.is_visible_in_tree() or _inside_scroll(c) or c is ScrollBar:
			continue
		var rect: Rect2 = c.get_global_rect()
		assert_lte(rect.end.x, float(sz.x) + 1.0, "%s within width: %s" % [c.name, label])
		assert_gte(rect.position.x, -1.0, "%s not left of screen: %s" % [c.name, label])
	for sc in H.find_all(s, "ScrollContainer"):
		if sc.is_visible_in_tree() and sc.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
			for ch in sc.get_children():
				if ch is Control and not ch is ScrollBar:
					assert_lte(ch.get_combined_minimum_size().x, sc.size.x + 1.0,
						"scroll content of %s fits its width: %s" % [sc.name, label])
	for b in H.find_all(s, "BaseButton"):
		if not b.is_visible_in_tree():
			continue
		var bs: Vector2 = b.size
		assert_gte(bs.y, AppTheme.TOUCH - 1.0, "touch target height %s: %s" % [b.name, label])
		assert_gte(bs.x, AppTheme.TOUCH - 1.0, "touch target width %s: %s" % [b.name, label])


func test_screens_on_all_sizes() -> void:
	GameState.mode = "learn"
	for sz in SIZES:
		for screen in ["home", "levels", "settings", "challenges", "learn", "consent", "practice"]:
			await _check(screen, sz)
		for idx in [0, 29, 31, 39]:  # 1-, 2- and 3-qubit puzzles
			GameState.current_level = GameState.levels[idx]
			await _check("puzzle", sz, idx == 31)
		GameState.last_result = LevelValidator.evaluate(GameState.levels[0], [{"gate": "X", "target": 0}])
		GameState.last_result["level"] = GameState.levels[0]
		await _check("results", sz)


func test_large_text_layouts() -> void:
	SaveService.set_setting("large_text", true)
	GameState.mode = "learn"
	for screen in ["home", "levels", "settings", "challenges"]:
		await _check(screen, Vector2i(720, 1440))
	GameState.current_level = GameState.levels[39]
	await _check("puzzle", Vector2i(720, 1440))
	SaveService.set_setting("large_text", false)
	AppTheme.get_theme(false)


func test_controls_have_accessible_text() -> void:
	GameState.current_level = GameState.levels[29]
	var r := await _mount("puzzle", Vector2i(720, 1560))
	for b in H.find_all(r[1], "Button"):
		var has_text: bool = str(b.text).strip_edges() != "" or str(b.tooltip_text) != ""
		assert_true(has_text, "button %s has a label or description" % b.name)


func test_gates_not_identified_by_colour_alone() -> void:
	GameState.current_level = GameState.levels[39]
	var r := await _mount("puzzle", Vector2i(720, 1560))
	for g in GameState.levels[39].available_gates:
		var b := H.find(r[1], "Gate_" + g) as Button
		assert_eq(b.text, g, "gate %s has a text label" % g)
