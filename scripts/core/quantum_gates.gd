class_name QGates
extends RefCounted
## Gate definitions and application of circuit operations.
##
## A circuit operation is a Dictionary:
##   single-qubit: {"gate": "H", "target": 0}
##   CNOT:         {"gate": "CNOT", "control": 0, "target": 1}

const SINGLE := ["I", "X", "Y", "Z", "H", "S", "T"]
const CONTROLLED := ["CNOT"]
const ALL := ["I", "X", "Y", "Z", "H", "S", "T", "CNOT"]

const DESCRIPTIONS := {
	"I": "Identity: leaves the qubit unchanged.",
	"X": "X flips 0 to 1 and 1 to 0.",
	"Y": "Y flips the qubit and adds an imaginary phase (i).",
	"Z": "Z flips the sign (phase) of the 1 part. Probabilities stay the same.",
	"H": "H (Hadamard) turns 0 or 1 into an equal superposition of both.",
	"S": "S adds a quarter-turn phase (i) to the 1 part. Two S gates make a Z.",
	"T": "T adds an eighth-turn phase to the 1 part. Two T gates make an S.",
	"CNOT": "CNOT flips the target qubit only when the control qubit is 1.",
}

static var _cache := {}


static func is_known(gate: String) -> bool:
	return gate in ALL


static func is_controlled(gate: String) -> bool:
	return gate in CONTROLLED


static func matrix(gate: String) -> PackedFloat64Array:
	if _cache.has(gate):
		return _cache[gate]
	var r := CMath.INV_SQRT2
	var m := PackedFloat64Array()
	match gate:
		"I":
			m = CMath.mat2(1, 0, 0, 0, 0, 0, 1, 0)
		"X", "CNOT":
			m = CMath.mat2(0, 0, 1, 0, 1, 0, 0, 0)
		"Y":
			m = CMath.mat2(0, 0, 0, -1, 0, 1, 0, 0)
		"Z":
			m = CMath.mat2(1, 0, 0, 0, 0, 0, -1, 0)
		"H":
			m = CMath.mat2(r, 0, r, 0, r, 0, -r, 0)
		"S":
			m = CMath.mat2(1, 0, 0, 0, 0, 0, 0, 1)
		"T":
			m = CMath.mat2(1, 0, 0, 0, 0, 0, r, r)
		_:
			return PackedFloat64Array()
	_cache[gate] = m
	return m


## Structural validation of one operation for an n-qubit register.
## Returns "" when valid, otherwise a short player-safe error message.
static func validate_op(op, n: int) -> String:
	if typeof(op) != TYPE_DICTIONARY:
		return "Operation is not an object."
	var gate = op.get("gate", "")
	if typeof(gate) != TYPE_STRING or not is_known(gate):
		return "Unknown gate."
	var t = op.get("target", -1)
	if not _is_int(t) or int(t) < 0 or int(t) >= n:
		return "Gate target is outside the circuit."
	if is_controlled(gate):
		var c = op.get("control", -1)
		if not _is_int(c) or int(c) < 0 or int(c) >= n:
			return "Gate control is outside the circuit."
		if int(c) == int(t):
			return "Control and target must be different wires."
	return ""


static func _is_int(v) -> bool:
	return typeof(v) == TYPE_INT or (typeof(v) == TYPE_FLOAT and float(v) == floorf(float(v)))


## Applies one operation in place. Returns false (state unchanged) if invalid.
static func apply(state: StateVector, op: Dictionary) -> bool:
	if state == null or validate_op(op, state.num_qubits) != "":
		return false
	var gate: String = op["gate"]
	var m := matrix(gate)
	if is_controlled(gate):
		return state.apply_controlled(m, int(op["control"]), int(op["target"]))
	return state.apply_single(m, int(op["target"]))


static func op_label(op: Dictionary) -> String:
	var g: String = op.get("gate", "?")
	if is_controlled(g):
		return "%s q%d→q%d" % [g, int(op.get("control", 0)), int(op.get("target", 0))]
	return "%s on q%d" % [g, int(op.get("target", 0))]
