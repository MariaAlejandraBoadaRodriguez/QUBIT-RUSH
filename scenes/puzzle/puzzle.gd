extends ScreenBase
## Puzzle screen for Learn, Daily and Rush modes.
## Simulation runs only when the circuit changes or on Run, never per frame.
## No ads can appear while this screen is active (AdsService.gameplay_active).

const RUSH_SECONDS := 60.0

var level: LevelData
var editor: CircuitEditor
var bars: ProbabilityBars
var bloch: BlochView
var tray: HFlowContainer
var info: Label
var slots_label: Label
var timer_label: Label
var run_button: Button
var undo_button: Button
var reset_button: Button
var action_row: HFlowContainer
var objective_label: Label
var target_label: Label
var hint_label: Label
var tutorial_card: PanelContainer
var gate_buttons := {}
var hints_shown := 0
var time_left := 0.0
var timer_running := false
var paused := false
var running := false
var preview_enabled := true
var column: VBoxContainer
var circuit_scroll: ScrollContainer


func build() -> void:
	AdsService.gameplay_active = true
	level = GameState.current_level
	if GameState.mode == "rush" and GameState.rush.is_empty():
		_start_rush()
	if level == null:
		GameState.goto.call_deferred("levels")
		return
	var back_text := "‹ Exit" if GameState.mode == "rush" else "‹ Back"
	var h := header(_title(), back_text)
	timer_label = UI.label("", "HeadingLabel", false)
	timer_label.name = "TimerLabel"
	h.add_child(timer_label)
	column = scroll_column()
	column.name = "PuzzleColumn"
	_build_objective()
	circuit_scroll = ScrollContainer.new()
	circuit_scroll.name = "CircuitScroll"
	circuit_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	circuit_scroll.custom_minimum_size.y = CircuitEditor.PAD * 2 + CircuitEditor.WIRE_H * level.num_qubits + 24
	column.add_child(circuit_scroll)
	editor = CircuitEditor.new()
	editor.name = "CircuitEditor"
	circuit_scroll.add_child(editor)
	slots_label = UI.label("", "SecondaryLabel")
	column.add_child(slots_label)
	action_row = HFlowContainer.new()
	action_row.add_theme_constant_override("h_separation", int(8 * AppTheme.DP))
	action_row.add_theme_constant_override("v_separation", int(8 * AppTheme.DP))
	action_row.name = "SelectionActions"
	column.add_child(action_row)
	tray = HFlowContainer.new()
	tray.name = "GateTray"
	tray.add_theme_constant_override("h_separation", int(10 * AppTheme.DP))
	tray.add_theme_constant_override("v_separation", int(10 * AppTheme.DP))
	column.add_child(tray)
	info = UI.label("", "SecondaryLabel")
	info.name = "InfoLabel"
	column.add_child(info)
	_build_preview()
	var controls := UI.hbox(10)
	undo_button = UI.button("Undo")
	undo_button.name = "UndoButton"
	undo_button.pressed.connect(func(): editor.undo())
	reset_button = UI.button("Reset")
	reset_button.name = "ResetButton"
	reset_button.pressed.connect(func(): editor.reset())
	run_button = UI.button("Run", "PrimaryButton")
	run_button.name = "RunButton"
	run_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	run_button.pressed.connect(run_circuit)
	controls.add_child(undo_button)
	controls.add_child(reset_button)
	controls.add_child(run_button)
	content.add_child(controls)
	editor.ops_changed.connect(_on_ops_changed)
	editor.selection_changed.connect(_refresh_actions)
	_load_level_into_editor()
	if GameState.mode == "rush":
		time_left = float(GameState.rush.get("time_left", RUSH_SECONDS))
		timer_running = true
	elif level.timer_seconds > 0:
		time_left = level.timer_seconds
		timer_running = true
	_update_timer_label()
	ConsentService.dialog_state_changed.connect(func(_o): _update_pause())


func _title() -> String:
	match GameState.mode:
		"rush":
			return "Rush · %d solved" % int(GameState.rush.get("solved", 0))
		"daily":
			return "Daily · %s UTC" % level.raw.get("date", "")
		_:
			return "%d · %s" % [level.number, level.title]


## First visit only: one-sentence example and a simple action, shown inside
## the objective card (no extra dismiss step).
func _build_tutorial(v: VBoxContainer) -> void:
	if GameState.mode != "learn" or SaveService.is_completed(level.id):
		return
	var tut: Dictionary = level.tutorial
	if not tut.has("example") and not tut.has("action"):
		return
	tutorial_card = UI.card("PaleCard")
	tutorial_card.name = "TutorialCard"
	var tv := UI.vbox(4)
	tutorial_card.add_child(tv)
	if tut.has("example"):
		tv.add_child(UI.label(str(tut.example), "HeadingLabel"))
	if tut.has("action"):
		tv.add_child(UI.label(str(tut.action)))
	v.add_child(tutorial_card)


func _build_objective() -> void:
	var card := UI.card()
	card.name = "ObjectiveCard"
	var v := UI.vbox(6)
	card.add_child(v)
	objective_label = UI.label(str(level.tutorial.get("text", "")))
	objective_label.name = "Objective"
	v.add_child(objective_label)
	_build_tutorial(v)
	target_label = UI.label("", "HeadingLabel")
	target_label.name = "Target"
	v.add_child(target_label)
	hint_label = UI.label("", "SecondaryLabel")
	hint_label.name = "HintText"
	hint_label.visible = false
	v.add_child(hint_label)
	var row := UI.hbox(8)
	var hint := UI.button("Hint", "FlatButton")
	hint.name = "HintButton"
	hint.pressed.connect(show_hint)
	row.add_child(hint)
	if level.why != "":
		var why := UI.button("Why?", "FlatButton")
		why.name = "WhyButton"
		why.pressed.connect(func(): Sheet.open(self, "Why?", level.why))
		row.add_child(why)
	v.add_child(row)
	column.add_child(card)
	_update_target_text()


func _update_target_text() -> void:
	var prefix := "Target: "
	if level.goal_type == "measurement_distribution":
		prefix = "Target odds: "
	elif level.goal_type == "gate_efficiency":
		prefix = "Target (≤ %d gates): " % level.max_gates
	elif level.goal_type == "bell_state":
		prefix = "Target Bell pair: "
	target_label.text = prefix + level.target_description()


func _build_preview() -> void:
	var card := UI.card()
	card.name = "PreviewCard"
	var v := UI.vbox(6)
	card.add_child(v)
	var cap := UI.label("Preview: chance of each result when measured", "SecondaryLabel")
	v.add_child(cap)
	var row := UI.hbox(8)
	v.add_child(row)
	bars = ProbabilityBars.new()
	bars.name = "ProbabilityBars"
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bars)
	bloch = BlochView.new()
	bloch.name = "BlochView"
	bloch.custom_minimum_size = Vector2(220, 220)
	row.add_child(bloch)
	preview_enabled = bool(level.raw.get("preview", true))
	bars.visible = preview_enabled
	bloch.visible = preview_enabled
	if not preview_enabled:
		v.add_child(UI.label("Preview is hidden in this level. Run to see the result."))
	column.add_child(card)


func _load_level_into_editor() -> void:
	var initial: Array = []
	if GameState.mode == "learn":
		initial = SaveService.get_in_progress(level.id)
		if not QCircuit.create(level.num_qubits, initial).validate(level.available_gates).is_empty() \
				or initial.size() > level.max_slots:
			initial = []
	editor.configure(level.num_qubits, level.start_label, level.fixed_ops, level.max_slots, level.available_gates, initial)
	for c in tray.get_children():
		c.queue_free()
	gate_buttons.clear()
	for g in level.available_gates:
		var b := GateButton.new().setup(g)
		b.tapped.connect(_on_gate_tapped)
		b.described.connect(_on_gate_described)
		tray.add_child(b)
		gate_buttons[g] = b
		if g == level.new_gate and not SaveService.is_completed(level.id):
			b.highlight(true)
	hints_shown = 0
	hint_label.visible = false
	_update_target_text()
	objective_label.text = str(level.tutorial.get("text", ""))
	_refresh()


func _on_gate_tapped(g: String) -> void:
	if running:
		return
	if editor.place_gate(g):
		AudioService.play("tick")
		AudioService.haptic()
		info.text = ""
	else:
		AudioService.play("error")
		info.text = "No free slots. Remove a gate or press Reset." if editor.slots_left() <= 0 else "That gate can't go there."


func _on_gate_described(g: String) -> void:
	Sheet.open(self, g + " gate", QGates.DESCRIPTIONS.get(g, ""))


func _on_ops_changed(ops: Array) -> void:
	if GameState.mode == "learn":
		SaveService.set_in_progress(level.id, ops)
	_refresh()


func _refresh() -> void:
	slots_label.text = "%d of %d slots free · selected wire q%d" % [editor.slots_left(), level.max_slots, editor.selected_wire]
	undo_button.disabled = not editor.can_undo()
	reset_button.disabled = editor.ops.is_empty()
	var state := level.full_circuit(editor.ops).run(level.start_state())
	if state != null and preview_enabled:
		bars.set_values(state.probabilities())
		bloch.set_vector(state.bloch_vector(editor.selected_wire), editor.selected_wire)
	_refresh_actions()


func _refresh_actions() -> void:
	for c in action_row.get_children():
		c.queue_free()
	slots_label.text = "%d of %d slots free · selected wire q%d" % [editor.slots_left(), level.max_slots, editor.selected_wire]
	if preview_enabled:
		var state := level.full_circuit(editor.ops).run(level.start_state())
		if state != null:
			bloch.set_vector(state.bloch_vector(editor.selected_wire), editor.selected_wire)
	if editor.selected_index < 0:
		action_row.visible = false
		return
	action_row.visible = true
	var op: Dictionary = editor.ops[editor.selected_index]
	var items := [["◀", "MoveLeft", func(): editor.move_selected(-1)],
		["▶", "MoveRight", func(): editor.move_selected(1)]]
	if level.num_qubits > 1:
		if QGates.is_controlled(op.gate):
			items.append(["Target ↕", "ShiftWire", func(): editor.shift_selected_wire(1)])
			items.append(["Swap", "SwapControl", func(): editor.swap_selected_control()])
		else:
			items.append(["Wire ↕", "ShiftWire", func(): editor.shift_selected_wire(1)])
	items.append(["Remove", "RemoveGate", func(): editor.remove_selected()])
	for it in items:
		var b := UI.button(it[0])
		b.name = it[1]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(it[2])
		action_row.add_child(b)


func show_hint() -> void:
	var all: Array = level.hints.duplicate()
	var bonus := AdsService.bonus_hints(level.id)
	if bonus > 0 and not level.solution.is_empty():
		all.append("Extra hint: a shortest solution starts with %s." % QGates.op_label(level.solution[0]))
	if all.is_empty():
		return
	hint_label.text = str(all[mini(hints_shown, all.size() - 1)])
	hint_label.visible = true
	hints_shown += 1


func run_circuit() -> void:
	if running:
		return
	var result := LevelValidator.evaluate(level, editor.ops)
	if not result.valid:
		AudioService.play("error")
		info.text = result.message
		return
	running = true
	AudioService.play("run")
	if not bool(SaveService.get_setting("reduced_motion")) and is_inside_tree():
		var tw := create_tween()
		tw.tween_property(editor, "modulate", Color(0.85, 0.9, 1.0), 0.15)
		tw.tween_property(editor, "modulate", Color.WHITE, 0.2)
		await tw.finished
	running = false
	_handle_result(result)


func _handle_result(result: Dictionary) -> void:
	if result.success:
		AudioService.play("success")
		AudioService.haptic(30)
	else:
		AudioService.play("error")
	match GameState.mode:
		"rush":
			if result.success:
				GameState.rush.solved = int(GameState.rush.solved) + 1
				GameState.rush.score = int(GameState.rush.score) + Scoring.rush_points(result.stars)
				_next_rush_challenge()
			else:
				info.text = result.message
		"daily":
			if result.success:
				SaveService.record_daily(level.raw.get("date", ""), result.stars)
			_finish(result)
		_:
			if result.success:
				SaveService.record_level(level.id, result.stars, result.gate_count)
			_finish(result)


func _finish(result: Dictionary) -> void:
	GameState.last_result = result
	GameState.last_result["level"] = level
	GameState.last_result["ops"] = editor.ops.duplicate(true)
	GameState.goto("results")


# ---- Rush -------------------------------------------------------------------

func _start_rush() -> void:
	GameState.rush = {"seed": int(Time.get_unix_time_from_system()), "solved": 0, "score": 0,
		"time_left": RUSH_SECONDS, "index": 0}
	_make_rush_level()


func _make_rush_level() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(GameState.rush.seed) + int(GameState.rush.index) * 7919
	var tier := ChallengeGenerator.tier_for(GameState.highest_completed())
	level = ChallengeGenerator.generate(rng, tier, "rush-%d" % GameState.rush.index, "Rush")
	GameState.current_level = level


func _next_rush_challenge() -> void:
	GameState.rush.index = int(GameState.rush.index) + 1
	_make_rush_level()
	info.text = "Solved! Next challenge."
	var h := content.get_child(0)
	h.get_child(1).text = _title()
	editor.custom_minimum_size = Vector2.ZERO
	circuit_scroll.custom_minimum_size.y = CircuitEditor.PAD * 2 + CircuitEditor.WIRE_H * level.num_qubits + 24
	_load_level_into_editor()


func _end_rush() -> void:
	timer_running = false
	var best := SaveService.record_rush(int(GameState.rush.score))
	GameState.last_result = {"rush": true, "score": int(GameState.rush.score),
		"solved": int(GameState.rush.solved), "new_best": best}
	GameState.rush = {}
	GameState.goto("results")


# ---- Timer and pause ----------------------------------------------------------

func _process(delta: float) -> void:
	if not timer_running or paused:
		return
	time_left = maxf(time_left - delta, 0.0)
	if GameState.mode == "rush":
		GameState.rush.time_left = time_left
	_update_timer_label()
	if time_left <= 0.0:
		timer_running = false
		if GameState.mode == "rush":
			_end_rush()
		else:
			info.text = "Time is up. You can keep working without the clock."


func _update_timer_label() -> void:
	if timer_label == null:
		return
	timer_label.text = ("%d s" % ceili(time_left)) if timer_running or time_left > 0.0 else ""
	if paused and timer_running:
		timer_label.text += " (paused)"


var _app_focused := true


func _notification(what: int) -> void:
	super._notification(what)
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			_app_focused = false
			_update_pause()
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			_app_focused = true
			_update_pause()
		NOTIFICATION_EXIT_TREE:
			AdsService.gameplay_active = false


func _update_pause() -> void:
	paused = not _app_focused or ConsentService.dialog_open
	_update_timer_label()


func go_back() -> void:
	if GameState.mode == "rush":
		GameState.rush = {}
		GameState.goto("challenges")
	elif GameState.mode == "daily":
		GameState.goto("challenges")
	else:
		GameState.goto("levels")
