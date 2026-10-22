extends GutTest
## Level schema, loader, validator, scoring and solvability (Gate B).

var _good := {
	"schema_version": 1, "id": "T1", "number": 1, "chapter": "fundamentals", "title": "Test",
	"qubits": 1, "available_gates": ["X"], "max_slots": 2,
	"goal": {"type": "state_fidelity", "target": {"label": "1"}},
	"scoring": {"two_star_gates": 2, "three_star_gates": 1},
	"tutorial": {"text": "Reach |1⟩."}, "hints": ["X flips."],
	"solution": [{"gate": "X", "target": 0}],
}


func _level(overrides := {}) -> LevelData:
	var d := _good.duplicate(true)
	d.merge(overrides, true)
	return LevelSchema.parse(d)


func test_all_levels_load_without_errors() -> void:
	var res := LevelLoader.load_all()
	assert_eq(res.errors.size(), 0, "errors: %s" % str(res.errors))
	assert_eq(res.levels.size(), 40)


func test_level_audit_passes_for_every_level() -> void:
	var report := LevelAudit.run()
	for e in report.levels:
		assert_true(e.ok, "L%02d %s: %s" % [e.number, e.title, "; ".join(e.problems)])
	assert_true(report.ok, "audit errors: %s" % str(report.errors))


func test_curriculum_chapter_ranges() -> void:
	var levels: Array = LevelLoader.load_all().levels
	for L in levels:
		var expected := "fundamentals" if L.number <= 24 else ("entanglement" if L.number <= 32 else "algorithms")
		assert_eq(L.chapter, expected, "chapter of L%d" % L.number)
	assert_true(levels[0].available_gates.has("X") and levels[0].num_qubits == 1)
	assert_true(levels[8].new_gate == "H", "H introduced at level 9")
	assert_true(levels[16].new_gate == "Z", "Z introduced at level 17")
	assert_true(levels[27].new_gate == "CNOT", "CNOT introduced at level 28")


func test_every_level_has_tutorial_text_and_free_hint() -> void:
	for L in LevelLoader.load_all().levels:
		assert_true(str(L.tutorial.get("text", "")).length() > 5, "tutorial L%d" % L.number)
		assert_true(L.hints.size() >= 1, "free hint L%d" % L.number)


func test_valid_level_parses() -> void:
	var L := _level()
	assert_not_null(L)
	assert_eq(L.num_qubits, 1)
	assert_eq(L.start_label, "0")


func test_malformed_json_fails_safely() -> void:
	var r := LevelLoader.load_text("{ not json")
	assert_null(r.level)
	assert_eq(r.errors.size(), 1)
	assert_null(LevelLoader.load_text("[]").level, "array root")
	assert_null(LevelLoader.load_file("res://does/not/exist.json").level)


func test_invalid_fields_are_rejected() -> void:
	var cases := [
		{"schema_version": 99}, {"qubits": 4}, {"qubits": 0}, {"available_gates": ["Q"]},
		{"available_gates": ["CNOT"]}, {"max_slots": 0}, {"chapter": "nope"},
		{"goal": {"type": "teleport", "target": {}}},
		{"goal": {"type": "state_fidelity", "target": {"label": "11"}}},
		{"goal": {"type": "measurement_distribution", "target": {"probabilities": {"0": 0.7, "1": 0.7}}}},
		{"goal": {"type": "bell_state", "target": {"bell": "phi_plus"}}},
		{"goal": {"type": "gate_efficiency", "target": {"label": "1"}}},
		{"scoring": {"two_star_gates": 1, "three_star_gates": 2}},
		{"fixed_gates": [{"gate": "X", "target": 3}]},
		{"start_state": "2"}, {"hints": []}, {"tutorial": {}},
		{"solution": [{"gate": "CNOT", "control": 0, "target": 0}]},
	]
	for c in cases:
		var d := _good.duplicate(true)
		d.merge(c, true)
		assert_gt(LevelSchema.validate(d).size(), 0, "should reject %s" % str(c))
		assert_null(LevelSchema.parse(d))
	var missing := _good.duplicate(true)
	missing.erase("goal")
	assert_gt(LevelSchema.validate(missing).size(), 0)
	assert_gt(LevelSchema.validate("x").size(), 0)


func test_validator_success_and_stars() -> void:
	var L := _level()
	var r := LevelValidator.evaluate(L, [{"gate": "X", "target": 0}])
	assert_true(r.success)
	assert_eq(r.stars, 3)
	r = LevelValidator.evaluate(L, [{"gate": "X", "target": 0}, {"gate": "X", "target": 0}])
	assert_false(r.success, "XX returns to |0>")
	assert_eq(r.stars, 0)


func test_validator_rejects_invalid_circuits() -> void:
	var L := _level()
	assert_false(LevelValidator.evaluate(L, [{"gate": "H", "target": 0}]).valid, "gate not available")
	assert_false(LevelValidator.evaluate(L, [{"gate": "X", "target": 5}]).valid, "bad index")
	var too_many := [{"gate": "X", "target": 0}, {"gate": "X", "target": 0}, {"gate": "X", "target": 0}]
	assert_false(LevelValidator.evaluate(L, too_many).valid, "over max_slots")


func test_relative_phase_matters_for_state_goals() -> void:
	var L := _level({"available_gates": ["H", "X", "Z"], "max_slots": 4,
		"goal": {"type": "state_fidelity", "target": {"kets": {"0": 0.7071, "1": -0.7071}}},
		"scoring": {"two_star_gates": 3, "three_star_gates": 2}})
	var plus := LevelValidator.evaluate(L, [{"gate": "H", "target": 0}])
	assert_false(plus.success, "|+> must not pass a |-> target")
	assert_almost_eq(plus.distance, 0.0, 1e-9, "bars look identical")
	assert_string_contains(plus.message, "phase")
	assert_true(LevelValidator.evaluate(L, [{"gate": "H", "target": 0}, {"gate": "Z", "target": 0}]).success)


func test_distribution_goal_accepts_any_phase() -> void:
	var L := _level({"available_gates": ["H", "X"],
		"goal": {"type": "measurement_distribution", "target": {"probabilities": {"0": 0.5, "1": 0.5}}}})
	assert_true(LevelValidator.evaluate(L, [{"gate": "H", "target": 0}]).success)
	assert_true(LevelValidator.evaluate(L, [{"gate": "X", "target": 0}, {"gate": "H", "target": 0}]).success)


func test_gate_efficiency_requires_budget() -> void:
	var L := _level({"available_gates": ["X", "I"], "max_slots": 3,
		"goal": {"type": "gate_efficiency", "target": {"label": "1"}, "max_gates": 1},
		"scoring": {"two_star_gates": 1, "three_star_gates": 1}})
	assert_true(LevelValidator.evaluate(L, [{"gate": "X", "target": 0}]).success)
	var r := LevelValidator.evaluate(L, [{"gate": "I", "target": 0}, {"gate": "X", "target": 0}])
	assert_false(r.success, "right state, over budget")


func test_scoring_thresholds() -> void:
	assert_eq(Scoring.stars_for(false, 1, 3, 2), 0)
	assert_eq(Scoring.stars_for(true, 2, 3, 2), 3)
	assert_eq(Scoring.stars_for(true, 3, 3, 2), 2)
	assert_eq(Scoring.stars_for(true, 4, 3, 2), 1)
	assert_eq(Scoring.rush_points(3), 2)
	assert_eq(Scoring.rush_points(1), 1)
	assert_eq(Scoring.rush_points(0), 0)


func test_impossible_target_reports_unsolvable() -> void:
	# Only X available: |+> can never be reached.
	var L := _level({"goal": {"type": "state_fidelity", "target": {"kets": {"0": 1, "1": 1}}}})
	var sol := LevelSolver.solve(L)
	assert_false(sol.found)


func test_fixed_gates_are_applied_first() -> void:
	var L := _level({"fixed_gates": [{"gate": "X", "target": 0}],
		"goal": {"type": "state_fidelity", "target": {"label": "0"}}})
	assert_true(LevelValidator.evaluate(L, [{"gate": "X", "target": 0}]).success)
	assert_false(LevelValidator.evaluate(L, []).success)


func test_daily_challenge_is_deterministic_and_solvable() -> void:
	var a := ChallengeGenerator.daily("2026-10-22", 40)
	var b := ChallengeGenerator.daily("2026-10-22", 40)
	assert_eq(a.raw.goal, b.raw.goal, "same date, same puzzle")
	assert_eq(a.num_qubits, b.num_qubits)
	var distinct := {}
	for day in range(1, 11):
		var c := ChallengeGenerator.daily("2026-11-%02d" % day, 40)
		distinct[str(c.raw.goal)] = true
	assert_gt(distinct.size(), 3, "different dates give different puzzles")
	for date in ["2026-01-01", "2026-02-28", "2026-10-22", "2027-03-15"]:
		for prog in [0, 16, 30, 40]:
			var L := ChallengeGenerator.daily(date, prog)
			var r := LevelValidator.evaluate(L, L.solution)
			assert_true(r.success, "daily %s tier %d solvable" % [date, prog])
			assert_eq(r.stars, 3)
			assert_false(LevelValidator.evaluate(L, []).success, "not trivially solved")
			for g in L.available_gates:
				assert_true(g in ChallengeGenerator.tier_for(prog).gates)


func test_utc_date_string() -> void:
	assert_eq(ChallengeGenerator.utc_date_string(0.0), "1970-01-01")
	assert_eq(ChallengeGenerator.utc_date_string(1792627200.0), "2026-10-22")


func test_rush_generation_many_seeds() -> void:
	var rng := RandomNumberGenerator.new()
	for s in 25:
		rng.seed = s
		var L := ChallengeGenerator.generate(rng, ChallengeGenerator.TIERS[3], "r", "Rush")
		assert_true(LevelValidator.evaluate(L, L.solution).success, "seed %d" % s)
