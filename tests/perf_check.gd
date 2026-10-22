extends SceneTree
## Headless performance and memory checks (targets, not device benchmarks):
##   ~/tools/godot --headless --path . -s tests/perf_check.gd
## Writes reports/performance.json; exit 1 if a budget is exceeded.

const BUDGETS := {
	"simulate_3q_20_gates_ms": 2.0,      # one Run on the largest circuit
	"preview_refresh_ms": 2.0,           # live preview after one edit
	"load_all_levels_ms": 500.0,
	"solve_all_levels_ms": 20000.0,
	"object_growth_after_session": 200,  # leaked objects after 300 screen cycles
}


func _initialize() -> void:
	_run.call_deferred()


func _ms(start: int) -> float:
	return (Time.get_ticks_usec() - start) / 1000.0


func _run() -> void:
	var r := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var moves := LevelSolver.candidate_ops(QGates.ALL, 3)
	var ops := []
	for i in 20:
		ops.append(moves[rng.randi_range(0, moves.size() - 1)])
	var c := QCircuit.create(3, ops)
	var t := Time.get_ticks_usec()
	for i in 1000:
		c.run(StateVector.zero(3))
	r["simulate_3q_20_gates_ms"] = _ms(t) / 1000.0
	var levels: Array = LevelLoader.load_all().levels
	var L: LevelData = levels[39]
	t = Time.get_ticks_usec()
	for i in 1000:
		var s := L.full_circuit(L.solution).run(L.start_state())
		s.probabilities()
		s.bloch_vector(0)
	r["preview_refresh_ms"] = _ms(t) / 1000.0
	t = Time.get_ticks_usec()
	LevelLoader.load_all()
	r["load_all_levels_ms"] = _ms(t)
	t = Time.get_ticks_usec()
	for lv in levels:
		LevelSolver.solve(lv)
	r["solve_all_levels_ms"] = _ms(t)
	# Simulated long session: open/close puzzle and results screens repeatedly.
	var gs = root.get_node("GameState")
	var save = root.get_node("SaveService")
	save.load_data("user://perf_save.json")
	save.set_setting("reduced_motion", true)
	gs.capture_navigation = true
	var puzzle: PackedScene = load(gs.SCREENS["puzzle"])
	for i in 20:
		await _cycle(gs, puzzle, levels, i)
	var base := Performance.get_monitor(Performance.OBJECT_COUNT)
	var mem0 := Performance.get_monitor(Performance.MEMORY_STATIC)
	for i in 300:
		await _cycle(gs, puzzle, levels, i)
	for i in 5:
		await process_frame
	r["object_growth_after_session"] = Performance.get_monitor(Performance.OBJECT_COUNT) - base
	r["static_memory_growth_kb"] = (Performance.get_monitor(Performance.MEMORY_STATIC) - mem0) / 1024.0
	save.reset_progress()
	var ok := true
	var report := {"results": r, "budgets": BUDGETS, "failures": []}
	for k in BUDGETS:
		if float(r[k]) > float(BUDGETS[k]):
			ok = false
			report.failures.append(k)
	report["ok"] = ok
	for k in r:
		print("%-32s %10.3f  (budget %s)" % [k, float(r[k]), str(BUDGETS.get(k, "-"))])
	var f := FileAccess.open("res://reports/performance.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	print("PERFORMANCE ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)


func _cycle(gs, puzzle: PackedScene, levels: Array, i: int) -> void:
	gs.current_level = levels[i % levels.size()]
	gs.mode = "learn"
	var p: Node = puzzle.instantiate()
	root.add_child(p)
	await process_frame
	for op in gs.current_level.solution:
		p.editor.place_gate(op.gate, int(op.get("control", op.target)))
	p.editor.undo()
	p.queue_free()
	await process_frame
