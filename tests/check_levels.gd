extends SceneTree
## Headless level solvability check:
##   ~/tools/godot --headless --path . -s tests/check_levels.gd
## Exit code 0 only if every level loads, is solvable and has achievable
## scoring thresholds. Writes reports/level-solvability.json.


func _initialize() -> void:
	var report := LevelAudit.run()
	for e in report.levels:
		var status := "OK  " if e.ok else "FAIL"
		print("%s L%02d %-24s optimal=%d ref=%d nodes=%d %s" % [status, e.number, e.title,
			e.optimal_length, e.reference_length, e.solver_nodes, "; ".join(e.problems)])
	for e in report.errors:
		print("ERROR ", e)
	var f := FileAccess.open("res://reports/level-solvability.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
	var passed: int = report.levels.filter(func(x): return x.ok).size()
	print("Levels solvable and valid: %d/%d -> %s" % [passed, report.levels.size(), "PASS" if report.ok else "FAIL"])
	quit(0 if report.ok else 1)
