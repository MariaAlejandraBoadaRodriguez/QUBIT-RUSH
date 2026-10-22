class_name LevelSchema
extends RefCounted
## Versioned level JSON schema: validation and parsing.

const SCHEMA_VERSION := 1
const CHAPTERS := ["fundamentals", "entanglement", "algorithms"]
const GOAL_TYPES := ["state_fidelity", "measurement_distribution", "bell_state", "gate_efficiency"]
const BELL_STATES := {
	"phi_plus": {"00": 1.0, "11": 1.0},
	"phi_minus": {"00": 1.0, "11": -1.0},
	"psi_plus": {"01": 1.0, "10": 1.0},
	"psi_minus": {"01": 1.0, "10": -1.0},
}
const REQUIRED := ["schema_version", "id", "number", "chapter", "title", "qubits",
	"available_gates", "max_slots", "goal", "scoring", "tutorial", "hints"]


## Returns a list of human-readable errors (empty list = valid).
static func validate(d) -> Array[String]:
	var e: Array[String] = []
	if typeof(d) != TYPE_DICTIONARY:
		e.append("Level is not a JSON object.")
		return e
	for k in REQUIRED:
		if not d.has(k):
			e.append("Missing field '%s'." % k)
	if not e.is_empty():
		return e
	if not _is_int(d.schema_version) or int(d.schema_version) != SCHEMA_VERSION:
		e.append("Unsupported schema_version.")
	if typeof(d.id) != TYPE_STRING or d.id == "":
		e.append("id must be a non-empty string.")
	if not _is_int(d.number) or int(d.number) < 1:
		e.append("number must be a positive integer.")
	if not d.chapter in CHAPTERS:
		e.append("Unknown chapter.")
	if typeof(d.title) != TYPE_STRING or d.title == "":
		e.append("title must be a non-empty string.")
	if not _is_int(d.qubits) or int(d.qubits) < 1 or int(d.qubits) > StateVector.MAX_QUBITS:
		e.append("qubits must be between 1 and %d." % StateVector.MAX_QUBITS)
		return e
	var n := int(d.qubits)
	var start = d.get("start_state", "0".repeat(n))
	if typeof(start) != TYPE_STRING or start.length() != n or StateVector.label_to_index(start) < 0:
		e.append("start_state must be a basis label with one digit per qubit.")
	if typeof(d.available_gates) != TYPE_ARRAY or d.available_gates.is_empty():
		e.append("available_gates must be a non-empty array.")
	else:
		for g in d.available_gates:
			if typeof(g) != TYPE_STRING or not QGates.is_known(g):
				e.append("Unknown gate '%s'." % str(g))
			elif QGates.is_controlled(g) and n < 2:
				e.append("CNOT needs at least two qubits.")
	if not _is_int(d.max_slots) or int(d.max_slots) < 1 or int(d.max_slots) > 16:
		e.append("max_slots must be between 1 and 16.")
	var fixed = d.get("fixed_gates", [])
	if typeof(fixed) != TYPE_ARRAY:
		e.append("fixed_gates must be an array.")
	else:
		for op in fixed:
			var err := QGates.validate_op(op, n)
			if err != "":
				e.append("fixed_gates: " + err)
	_validate_goal(d.goal, n, e)
	_validate_scoring(d, e)
	if typeof(d.tutorial) != TYPE_DICTIONARY or typeof(d.tutorial.get("text", null)) != TYPE_STRING:
		e.append("tutorial.text is required.")
	if typeof(d.hints) != TYPE_ARRAY or d.hints.is_empty():
		e.append("At least one hint is required (a basic hint is always free).")
	if d.has("timer_seconds") and d.timer_seconds != null:
		if not _is_int(d.timer_seconds) or int(d.timer_seconds) < 0:
			e.append("timer_seconds must be a non-negative integer or null.")
	if d.has("solution"):
		if typeof(d.solution) != TYPE_ARRAY:
			e.append("solution must be an array.")
		else:
			for op in d.solution:
				var err := QGates.validate_op(op, n)
				if err != "":
					e.append("solution: " + err)
	return e


static func _validate_goal(g, n: int, e: Array[String]) -> void:
	if typeof(g) != TYPE_DICTIONARY:
		e.append("goal must be an object.")
		return
	var t = g.get("type", "")
	if not t in GOAL_TYPES:
		e.append("Unknown goal type.")
		return
	var target = g.get("target", null)
	if typeof(target) != TYPE_DICTIONARY:
		e.append("goal.target must be an object.")
		return
	match t:
		"state_fidelity", "gate_efficiency":
			if _target_state(target, n) == null:
				e.append("goal.target must describe a valid %d-qubit state." % n)
			if t == "gate_efficiency" and (not _is_int(g.get("max_gates", null)) or int(g.max_gates) < 0):
				e.append("gate_efficiency goals need a max_gates integer.")
		"measurement_distribution":
			if _target_probs(target, n).is_empty():
				e.append("goal.target.probabilities must sum to 1 over valid labels.")
		"bell_state":
			if n != 2 or not BELL_STATES.has(target.get("bell", "")):
				e.append("bell_state goals need 2 qubits and a known Bell state name.")


static func _validate_scoring(d: Dictionary, e: Array[String]) -> void:
	var s = d.scoring
	if typeof(s) != TYPE_DICTIONARY:
		e.append("scoring must be an object.")
		return
	var two = s.get("two_star_gates", null)
	var three = s.get("three_star_gates", null)
	if not _is_int(two) or not _is_int(three):
		e.append("scoring needs integer two_star_gates and three_star_gates.")
		return
	if int(three) > int(two):
		e.append("three_star_gates must not exceed two_star_gates.")
	if _is_int(d.max_slots) and int(two) > int(d.max_slots):
		e.append("two_star_gates must fit within max_slots.")


static func _target_state(target: Dictionary, n: int) -> StateVector:
	if target.has("label"):
		var lbl = target.label
		if typeof(lbl) != TYPE_STRING or lbl.length() != n:
			return null
		return StateVector.from_label(lbl)
	if target.has("kets") and typeof(target.kets) == TYPE_DICTIONARY:
		return StateVector.from_kets(n, target.kets)
	return null


static func _target_probs(target: Dictionary, n: int) -> PackedFloat64Array:
	var p := PackedFloat64Array()
	var src = target.get("probabilities", null)
	if typeof(src) != TYPE_DICTIONARY:
		return p
	p.resize(1 << n)
	p.fill(0.0)
	var total := 0.0
	for k in src:
		if typeof(k) != TYPE_STRING or k.length() != n:
			return PackedFloat64Array()
		var idx := StateVector.label_to_index(k)
		var v = src[k]
		if idx < 0 or not (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) or float(v) < 0.0:
			return PackedFloat64Array()
		p[idx] = float(v)
		total += float(v)
	if absf(total - 1.0) > 1e-6:
		return PackedFloat64Array()
	return p


static func _is_int(v) -> bool:
	return typeof(v) == TYPE_INT or (typeof(v) == TYPE_FLOAT and float(v) == floorf(float(v)))


static func _to_int_ops(ops: Array) -> Array:
	var out := []
	for op in ops:
		var o := {"gate": op.gate, "target": int(op.target)}
		if op.has("control"):
			o["control"] = int(op.control)
		out.append(o)
	return out


## Parses a dictionary into LevelData. Returns null if invalid.
static func parse(d) -> LevelData:
	if not validate(d).is_empty():
		return null
	var L := LevelData.new()
	L.raw = d
	L.id = d.id
	L.number = int(d.number)
	L.chapter = d.chapter
	L.title = d.title
	L.num_qubits = int(d.qubits)
	L.start_label = d.get("start_state", "0".repeat(L.num_qubits))
	L.available_gates = d.available_gates.duplicate()
	L.max_slots = int(d.max_slots)
	L.fixed_ops = _to_int_ops(d.get("fixed_gates", []))
	L.goal_type = d.goal.type
	match L.goal_type:
		"state_fidelity", "gate_efficiency":
			L.target_state = _target_state(d.goal.target, L.num_qubits)
			if L.goal_type == "gate_efficiency":
				L.max_gates = int(d.goal.max_gates)
		"bell_state":
			L.target_state = StateVector.from_kets(2, BELL_STATES[d.goal.target.bell])
		"measurement_distribution":
			L.target_probs = _target_probs(d.goal.target, L.num_qubits)
	L.two_star_gates = int(d.scoring.two_star_gates)
	L.three_star_gates = int(d.scoring.three_star_gates)
	var ts = d.get("timer_seconds", null)
	L.timer_seconds = int(ts) if ts != null else 0
	L.tutorial = d.tutorial
	L.hints = d.hints
	L.why = d.get("why", "")
	L.success_text = d.get("success", "Target reached.")
	L.new_gate = d.get("new_gate", "")
	L.solution = _to_int_ops(d.get("solution", []))
	return L
