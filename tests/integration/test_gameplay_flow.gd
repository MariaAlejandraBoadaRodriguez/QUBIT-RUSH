extends GutTest
## Gameplay integration (Gate C): offline first run, onboarding, input,
## undo/reset/run, progression, persistence, pause/resume.

const H = preload("res://tests/ui/ui_helpers.gd")
const PATH := "user://test_flow_save.json"


func before_each() -> void:
	for f in [PATH, PATH + ".tmp", PATH + ".bak"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	SaveService.load_data(PATH)
	SaveService.set_setting("reduced_motion", true)
	SaveService.set_setting("sfx", false)
	GameState.capture_navigation = true
	GameState.navigation_log.clear()
	GameState.mode = "learn"
	GameState.rush = {}
	AdsService.set_provider(AdsProvider.new())


func after_all() -> void:
	GameState.capture_navigation = false
	SaveService.load_data(SaveService.DEFAULT_PATH)


func _open(screen: String) -> Control:
	var s := H.screen(GameState.SCREENS[screen])
	add_child_autofree(s)
	await wait_physics_frames(2)
	return s


func test_new_user_starts_offline_without_account_or_ads() -> void:
	assert_eq(SaveService.total_stars(), 0)
	assert_eq(ConsentService.ads_choice(), "unset")
	assert_false(AdsService.can_offer_rewarded())
	var home := await _open("home")
	assert_not_null(H.find(home, "PlayButton"), "single obvious Play button")
	for word in ["Sign in", "Log in", "Email", "Account"]:
		for l in H.find_all(home, "Label") + H.find_all(home, "Button"):
			assert_false(str(l.text).contains(word), "no %s on home" % word)
	assert_true(H.press(home, "PlayButton"))
	assert_eq(GameState.navigation_log.back(), "puzzle", "Play goes straight to a puzzle")
	assert_eq(GameState.current_level.number, 1)


func test_level_one_tap_x_then_run() -> void:
	GameState.current_level = GameState.levels[0]
	var p := await _open("puzzle")
	assert_true(AdsService.gameplay_active, "gameplay flag set while puzzle open")
	assert_not_null(H.find(p, "TutorialCard"), "tutorial shown on first visit")
	var x := H.find(p, "Gate_X") as GateButton
	x.tapped.emit("X")
	assert_eq(p.editor.ops, [{"gate": "X", "target": 0}])
	p.run_circuit()
	await wait_physics_frames(2)
	assert_eq(GameState.navigation_log.back(), "results")
	assert_true(GameState.last_result.success)
	assert_eq(GameState.last_result.stars, 3)
	assert_eq(SaveService.level_stars("L01"), 3)
	assert_true(GameState.is_unlocked(GameState.levels[1]), "level 2 unlocked")
	var r := await _open("results")
	assert_eq((H.find(r, "ResultTitle") as Label).text.replace("\u2060", ""), "You made |1⟩. Nice work.")
	assert_true(H.press(r, "NextButton"))
	assert_eq(GameState.current_level.number, 2)


func test_wrong_answer_shows_retry_not_progress() -> void:
	GameState.current_level = GameState.levels[0]
	var p := await _open("puzzle")
	p.run_circuit()
	await wait_physics_frames(1)
	assert_false(GameState.last_result.success)
	assert_eq(SaveService.level_stars("L01"), 0)
	var r := await _open("results")
	assert_null(H.find(r, "NextButton"))
	assert_not_null(H.find(r, "RetryButton"))
	assert_null(H.find(r, "RewardedOffer"), "no ad offer without consent")


func test_undo_reset_and_editing() -> void:
	GameState.current_level = GameState.levels[19]  # H-Z-H, 1 qubit, 4 slots
	var p := await _open("puzzle")
	var e: CircuitEditor = p.editor
	for g in ["H", "Z", "H"]:
		e.place_gate(g)
	assert_eq(e.ops.size(), 3)
	assert_true(H.press(p, "UndoButton"))
	assert_eq(e.ops.size(), 2)
	e.select_op(0)
	assert_true(e.move_selected(1))
	assert_eq(e.ops[1].gate, "H")
	assert_true(e.remove_selected())
	assert_eq(e.ops.size(), 1)
	assert_true(H.press(p, "ResetButton"))
	assert_eq(e.ops.size(), 0)
	assert_true(e.undo(), "reset can be undone")
	assert_eq(e.ops.size(), 1)
	for i in 10:
		e.place_gate("H")
	assert_eq(e.ops.size(), 4, "cannot exceed max_slots")
	assert_false(e.place_gate("X"), "unavailable gate rejected")


func test_drop_onto_slot_inserts_gate() -> void:
	GameState.current_level = GameState.levels[24]  # 2 qubits, X
	var p := await _open("puzzle")
	var e: CircuitEditor = p.editor
	var pos := Vector2(e.col_x(0), e.wire_y(1))
	assert_true(e._can_drop_data(pos, {"gate": "X"}))
	e._drop_data(pos, {"gate": "X"})
	assert_eq(e.ops, [{"gate": "X", "target": 1}])
	assert_false(e._can_drop_data(pos, {"gate": "H"}), "gate not in this level")
	p.run_circuit()
	await wait_physics_frames(1)
	assert_true(GameState.last_result.success, "|01> reached by dropping X on q1")


func test_cnot_editing_controls() -> void:
	GameState.current_level = GameState.levels[29]  # Bell pair
	var p := await _open("puzzle")
	var e: CircuitEditor = p.editor
	e.select_wire(0)
	e.place_gate("H")
	e.place_gate("CNOT")
	assert_eq(e.ops[1], {"gate": "CNOT", "control": 0, "target": 1})
	e.select_op(1)
	assert_true(e.swap_selected_control())
	assert_eq(e.ops[1], {"gate": "CNOT", "control": 1, "target": 0})
	e.swap_selected_control()
	p.run_circuit()
	await wait_physics_frames(1)
	assert_true(GameState.last_result.success)


func test_in_progress_circuit_survives_restart() -> void:
	GameState.current_level = GameState.levels[19]
	var p := await _open("puzzle")
	p.editor.place_gate("H")
	p.editor.place_gate("Z")
	p.queue_free()
	await wait_physics_frames(1)
	SaveService.load_data(PATH)  # simulate process death and relaunch
	var p2 := await _open("puzzle")
	assert_eq(p2.editor.ops.size(), 2, "circuit restored")


func test_rush_timer_pauses_in_background() -> void:
	for L in GameState.levels.slice(0, 12):
		SaveService.record_level(L.id, 3, 1)
	assert_true(GameState.rush_unlocked())
	GameState.mode = "rush"
	GameState.rush = {}
	var p := await _open("puzzle")
	assert_true(p.timer_running)
	var t0: float = p.time_left
	p._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await wait_seconds(0.3)
	assert_almost_eq(p.time_left, t0, 0.02, "clock frozen while backgrounded")
	p._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await wait_seconds(0.3)
	assert_lt(p.time_left, t0 - 0.1, "clock resumes")
	ConsentService.set_dialog_open(true)
	var t1: float = p.time_left
	await wait_seconds(0.3)
	assert_almost_eq(p.time_left, t1, 0.02, "clock frozen while consent dialog open")
	ConsentService.set_dialog_open(false)


func test_rush_solve_advances_and_timeout_ends() -> void:
	for L in GameState.levels.slice(0, 12):
		SaveService.record_level(L.id, 3, 1)
	GameState.mode = "rush"
	GameState.rush = {}
	var p := await _open("puzzle")
	var lvl: LevelData = p.level
	for op in lvl.solution:
		p.editor.ops.append(op)
	p.run_circuit()
	await wait_physics_frames(1)
	assert_eq(int(GameState.rush.solved), 1)
	assert_ne(p.level, lvl, "next challenge loaded")
	p.time_left = 0.01
	await wait_physics_frames(3)
	assert_eq(GameState.navigation_log.back(), "results")
	assert_true(GameState.last_result.rush)
	assert_eq(int(SaveService.data.rush.best), int(GameState.last_result.score))


func test_daily_challenge_records_completion() -> void:
	var L := ChallengeGenerator.daily("2026-10-22", 10)
	GameState.start_level(L, "daily")
	var p := await _open("puzzle")
	for op in L.solution:
		p.editor.ops.append(op)
	p.run_circuit()
	await wait_physics_frames(1)
	assert_true(SaveService.is_daily_done("2026-10-22"))


func test_locked_levels_cannot_be_started_from_list() -> void:
	var ls := await _open("levels")
	var l2 := H.find(ls, "Level_2") as Button
	assert_true(l2.disabled, "level 2 locked for a new player")
	assert_false((H.find(ls, "Level_1") as Button).disabled)


func test_all_levels_playable_through_ui_in_order() -> void:
	# End-to-end offline run of the whole curriculum through the puzzle screen.
	for L in GameState.levels:
		assert_true(GameState.is_unlocked(L), "L%d unlocked in order" % L.number)
		GameState.current_level = L
		GameState.mode = "learn"
		var p := await _open("puzzle")
		for op in L.solution:
			p.editor.ops.append(op)
		p.run_circuit()
		await wait_physics_frames(1)
		assert_true(GameState.last_result.success, "L%d solved via UI" % L.number)
		p.queue_free()
	assert_eq(GameState.highest_completed(), 40)
	assert_eq(SaveService.total_stars(), 120)


func test_back_navigation() -> void:
	GameState.current_level = GameState.levels[0]
	var p := await _open("puzzle")
	p._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(GameState.navigation_log.back(), "levels")
	var ls := await _open("levels")
	ls._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(GameState.navigation_log.back(), "home")


func test_hints_are_free() -> void:
	GameState.current_level = GameState.levels[12]
	var p := await _open("puzzle")
	assert_true(H.press(p, "HintButton"))
	var hint := H.find(p, "HintText") as Label
	assert_true(hint.visible and hint.text.length() > 0)


func test_practice_lab_measurement_does_not_change_state() -> void:
	SaveService.record_level("L09", 3, 1)
	SaveService.record_level("L08", 3, 1)
	for L in GameState.levels.slice(0, 9):
		SaveService.record_level(L.id, 3, 1)
	var lab := await _open("practice")
	lab.editor.place_gate("H")
	var before: String = (H.find(lab, "KetLabel") as Label).text
	assert_true(H.press(lab, "MeasureButton"))
	assert_string_contains((H.find(lab, "CountsLabel") as Label).text, "100 measurements")
	lab._refresh()
	assert_eq((H.find(lab, "KetLabel") as Label).text, before)
