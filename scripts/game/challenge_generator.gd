class_name ChallengeGenerator
extends RefCounted
## Deterministic, offline challenge generation for Daily Challenge and Rush.
##
## The daily seed uses the UTC calendar date ("YYYY-MM-DD"), so every device
## gets the same puzzle for the same UTC day given the same gate tier. The
## puzzle is local: nothing implies a globally synchronised competition.
## Display policy: the screen shows the UTC date the puzzle belongs to.

## Gate tiers unlock with curriculum progress (highest completed level).
const TIERS := [
	{"min_level": 0, "gates": ["X", "H"], "qubits": [1]},
	{"min_level": 16, "gates": ["X", "H", "Z", "S"], "qubits": [1]},
	{"min_level": 30, "gates": ["X", "H", "Z", "CNOT"], "qubits": [1, 2, 2]},
	{"min_level": 36, "gates": ["X", "H", "Z", "S", "T", "CNOT"], "qubits": [2, 2, 3]},
]


static func tier_for(highest_completed: int) -> Dictionary:
	var best: Dictionary = TIERS[0]
	for t in TIERS:
		if highest_completed >= t.min_level:
			best = t
	return best


static func utc_date_string(unix_time: float = -1.0) -> String:
	var t := Time.get_unix_time_from_system() if unix_time < 0.0 else unix_time
	var d := Time.get_datetime_dict_from_unix_time(int(t))
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


static func seed_for_date(date: String) -> int:
	# hash() is stable for identical strings across platforms in Godot 4.
	return absi(hash("qubit-rush-daily-" + date))


static func daily(date: String, highest_completed: int) -> LevelData:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_for_date(date)
	var lvl := generate(rng, tier_for(highest_completed), "daily-" + date, "Daily Challenge")
	lvl.raw["date"] = date
	return lvl


## Generates a solvable state-target puzzle. The target is produced by a
## random circuit, so it is always reachable; scoring uses the BFS optimum.
static func generate(rng: RandomNumberGenerator, tier: Dictionary, id: String, title: String) -> LevelData:
	for _attempt in 32:
		var n: int = tier.qubits[rng.randi_range(0, tier.qubits.size() - 1)]
		var gates: Array = tier.gates.filter(func(g): return n > 1 or not QGates.is_controlled(g))
		var moves := LevelSolver.candidate_ops(gates, n)
		var length := rng.randi_range(2, 3 + n)
		var ops := []
		for _i in length:
			ops.append(moves[rng.randi_range(0, moves.size() - 1)])
		var target := QCircuit.create(n, ops).run(StateVector.zero(n))
		if QFidelity.state_fidelity(target, StateVector.zero(n)) > 0.99:
			continue
		var d := _level_dict(id, title, n, gates, length + 2, target)
		var lvl := LevelSchema.parse(d)
		if lvl == null:
			continue
		var sol := LevelSolver.solve(lvl, 60000)
		if not sol.found or sol.length < 1:
			continue
		lvl.three_star_gates = sol.length
		lvl.two_star_gates = mini(sol.length + 2, lvl.max_slots)
		lvl.solution = sol.ops
		return lvl
	# Fallback that is always valid: reach |1⟩ with X.
	var fallback := LevelSchema.parse(_level_dict(id, title, 1, ["X", "H"], 3, StateVector.from_label("1")))
	fallback.three_star_gates = 1
	fallback.two_star_gates = 2
	fallback.solution = [{"gate": "X", "target": 0}]
	return fallback


static func _level_dict(id: String, title: String, n: int, gates: Array, slots: int, target: StateVector) -> Dictionary:
	var kets := {}
	for i in target.dim():
		if CMath.abs2(target.amp_re(i), target.amp_im(i)) > 1e-12:
			kets[StateVector.index_to_label(i, n)] = [target.amp_re(i), target.amp_im(i)]
	return {
		"schema_version": LevelSchema.SCHEMA_VERSION, "id": id, "number": 1000,
		"chapter": "algorithms", "title": title, "qubits": n,
		"available_gates": gates, "max_slots": slots,
		"goal": {"type": "state_fidelity", "target": {"kets": kets}},
		"scoring": {"two_star_gates": slots, "three_star_gates": 1},
		"tutorial": {"text": "Build a circuit that produces the target state."},
		"hints": ["Work backwards: which gate would undo the last step of the target?"],
		"success": "Challenge solved.",
	}
