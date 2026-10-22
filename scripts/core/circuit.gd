class_name QCircuit
extends RefCounted
## Sequential list of operations applied left to right.

var num_qubits: int = 1
var ops: Array = []


static func create(n: int, operations: Array = []) -> QCircuit:
	var c := QCircuit.new()
	c.num_qubits = n
	c.ops = operations.duplicate(true)
	return c


## Returns a list of error strings; empty means valid.
## `allowed` restricts gate types (empty array = any known gate).
func validate(allowed: Array = []) -> Array[String]:
	var errors: Array[String] = []
	if num_qubits < 1 or num_qubits > StateVector.MAX_QUBITS:
		errors.append("Unsupported number of qubits.")
		return errors
	for i in ops.size():
		var e := QGates.validate_op(ops[i], num_qubits)
		if e != "":
			errors.append("Step %d: %s" % [i + 1, e])
		elif not allowed.is_empty() and not (ops[i]["gate"] in allowed):
			errors.append("Step %d: gate %s is not available here." % [i + 1, ops[i]["gate"]])
	return errors


## Runs the circuit on a copy of `start`. Returns null if any op is invalid.
func run(start: StateVector) -> StateVector:
	if start == null or start.num_qubits != num_qubits:
		return null
	var s := start.copy()
	for op in ops:
		if not QGates.apply(s, op):
			return null
	return s
