class_name LevelData
extends RefCounted
## Parsed, validated level. Built only by LevelSchema.parse().

var id := ""
var number := 0
var chapter := ""
var title := ""
var num_qubits := 1
var start_label := "0"
var available_gates: Array = []
var max_slots := 1
var fixed_ops: Array = []
var goal_type := ""
var target_state: StateVector = null
var target_probs := PackedFloat64Array()
var max_gates := -1
var two_star_gates := 0
var three_star_gates := 0
var timer_seconds := 0
var tutorial := {}
var hints: Array = []
var why := ""
var success_text := ""
var new_gate := ""
var solution: Array = []
var raw := {}


func start_state() -> StateVector:
	return StateVector.from_label(start_label)


## State after the level's fixed (pre-placed) gates.
func prepared_state() -> StateVector:
	return QCircuit.create(num_qubits, fixed_ops).run(start_state())


## Full circuit: fixed ops followed by player ops.
func full_circuit(player_ops: Array) -> QCircuit:
	var all := fixed_ops.duplicate(true)
	all.append_array(player_ops)
	return QCircuit.create(num_qubits, all)


func target_description() -> String:
	if target_state != null:
		return target_state.to_ket_string(3)
	var parts: Array[String] = []
	for i in target_probs.size():
		if target_probs[i] > 1e-9:
			parts.append("P(%s) = %s" % [StateVector.index_to_label(i, num_qubits), String.num(target_probs[i], 3)])
	return ", ".join(parts)
