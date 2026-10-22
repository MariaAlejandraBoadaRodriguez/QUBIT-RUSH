class_name LevelSolver
extends RefCounted
## Breadth-first search for a shortest player circuit that solves a level.
## Used by the solvability check, scoring audits and challenge generation.

const DEFAULT_NODE_LIMIT := 250000


## All single operations the player could place with the given gates.
static func candidate_ops(gates: Array, n: int) -> Array:
	var ops := []
	for g in gates:
		if QGates.is_controlled(g):
			for c in n:
				for t in n:
					if c != t:
						ops.append({"gate": g, "control": c, "target": t})
		else:
			for t in n:
				ops.append({"gate": g, "target": t})
	return ops


static func state_key(s: StateVector) -> String:
	var parts := PackedStringArray()
	for v in s.amps:
		parts.append(str(snappedf(v, 1e-6) + 0.0))
	return ",".join(parts)


## Returns {"found": bool, "ops": Array, "length": int, "nodes": int}.
static func solve(level: LevelData, node_limit := DEFAULT_NODE_LIMIT) -> Dictionary:
	var start := level.prepared_state()
	if start == null:
		return {"found": false, "ops": [], "length": -1, "nodes": 0}
	var moves := candidate_ops(level.available_gates, level.num_qubits)
	var frontier := [{"state": start, "ops": []}]
	var seen := {state_key(start): true}
	var nodes := 1
	for depth in level.max_slots + 1:
		for node in frontier:
			if LevelValidator.evaluate(level, node.ops).success:
				return {"found": true, "ops": node.ops, "length": node.ops.size(), "nodes": nodes}
		if depth == level.max_slots:
			break
		var next := []
		for node in frontier:
			for op in moves:
				var s: StateVector = node.state.copy()
				QGates.apply(s, op)
				var k := state_key(s)
				if seen.has(k):
					continue
				seen[k] = true
				var ops: Array = node.ops.duplicate()
				ops.append(op)
				next.append({"state": s, "ops": ops})
				nodes += 1
				if nodes > node_limit:
					return {"found": false, "ops": [], "length": -1, "nodes": nodes}
		frontier = next
	return {"found": false, "ops": [], "length": -1, "nodes": nodes}
