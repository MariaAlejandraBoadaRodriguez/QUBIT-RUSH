class_name LevelAudit
extends RefCounted
## Shared level solvability/scoring audit used by the GUT test and the
## standalone check (tests/check_levels.gd).


## Returns {"ok": bool, "levels": [per-level dicts], "errors": [String]}.
static func run(index_path := LevelLoader.INDEX_PATH) -> Dictionary:
	var res := LevelLoader.load_all(index_path)
	var report := {"ok": true, "levels": [], "errors": res.errors.duplicate()}
	if not res.errors.is_empty():
		report.ok = false
	var levels: Array = res.levels
	for i in levels.size():
		var L: LevelData = levels[i]
		var entry := {"id": L.id, "number": L.number, "title": L.title, "ok": true, "problems": []}
		if L.number != i + 1:
			entry.problems.append("Level numbers must be consecutive from 1 (got %d at position %d)." % [L.number, i + 1])
		var ref := LevelValidator.evaluate(L, L.solution)
		entry["reference_solution_ok"] = ref.success
		entry["reference_length"] = L.solution.size()
		if not ref.success:
			entry.problems.append("Reference solution does not solve the level: " + str(ref.message))
		var sol := LevelSolver.solve(L)
		entry["solver_found"] = sol.found
		entry["optimal_length"] = sol.length
		entry["solver_nodes"] = sol.nodes
		entry["solver_solution"] = sol.ops.map(func(o): return QGates.op_label(o))
		if not sol.found:
			entry.problems.append("Solver found no solution within max_slots.")
		else:
			if sol.length != L.three_star_gates:
				entry.problems.append("three_star_gates (%d) must equal the optimal length (%d)." % [L.three_star_gates, sol.length])
			if sol.length > L.two_star_gates:
				entry.problems.append("two_star_gates below optimum.")
			var check := LevelValidator.evaluate(L, sol.ops)
			if check.stars != 3:
				entry.problems.append("Optimal solution does not earn 3 stars.")
		if L.new_gate != "" and not L.new_gate in L.available_gates:
			entry.problems.append("new_gate not available.")
		if i > 0:
			var prev_gates := {}
			for k in i:
				for g in levels[k].available_gates:
					prev_gates[g] = true
			var new_count := 0
			for g in L.available_gates:
				if not prev_gates.has(g):
					new_count += 1
			if new_count > 1:
				entry.problems.append("Introduces more than one new gate.")
			if new_count == 1 and L.new_gate == "":
				entry.problems.append("Introduces a gate without marking new_gate.")
		# The prepared state must not already satisfy the goal (no empty solution).
		if LevelValidator.evaluate(L, []).success:
			entry.problems.append("Level is solved by an empty circuit.")
		entry.ok = entry.problems.is_empty()
		if not entry.ok:
			report.ok = false
		report.levels.append(entry)
	if levels.size() < 40:
		report.ok = false
		report.errors.append("Expected at least 40 levels, found %d." % levels.size())
	return report
