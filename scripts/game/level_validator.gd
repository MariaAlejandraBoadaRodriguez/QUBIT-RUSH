class_name LevelValidator
extends RefCounted
## Evaluates a player circuit against a level objective.
## Relative phase always matters for state objectives: probability bars that
## look the same are NOT accepted when the target is a state.


## Returns a result Dictionary:
## {success, valid, errors, fidelity, distance, gate_count, stars, final_state,
##  final_probs, message}
static func evaluate(level: LevelData, player_ops: Array) -> Dictionary:
	var result := {
		"success": false, "valid": false, "errors": [], "fidelity": 0.0,
		"distance": 1.0, "gate_count": player_ops.size(), "stars": 0,
		"final_state": null, "final_probs": PackedFloat64Array(), "message": "",
	}
	if player_ops.size() > level.max_slots:
		result.errors = ["This circuit uses more slots than the level allows."]
		result.message = result.errors[0]
		return result
	var player := QCircuit.create(level.num_qubits, player_ops)
	var errors := player.validate(level.available_gates)
	if not errors.is_empty():
		result.errors = errors
		result.message = errors[0]
		return result
	var final := level.full_circuit(player_ops).run(level.start_state())
	if final == null:
		result.errors = ["The circuit could not be simulated."]
		result.message = result.errors[0]
		return result
	result.valid = true
	result.final_state = final
	result.final_probs = final.probabilities()
	var ok := false
	match level.goal_type:
		"measurement_distribution":
			result.distance = QFidelity.total_variation(result.final_probs, level.target_probs)
			ok = result.distance <= QFidelity.DISTRIBUTION_THRESHOLD
			result.fidelity = 1.0 - result.distance
		_:
			result.fidelity = QFidelity.state_fidelity(level.target_state, final)
			result.distance = QFidelity.total_variation(result.final_probs, level.target_state.probabilities())
			ok = result.fidelity >= QFidelity.STATE_THRESHOLD
			if ok and level.goal_type == "gate_efficiency" and player_ops.size() > level.max_gates:
				ok = false
				result.message = "Right state, but use at most %d gates." % level.max_gates
	result.success = ok
	result.stars = Scoring.stars_for(ok, player_ops.size(), level.two_star_gates, level.three_star_gates)
	if result.message == "":
		result.message = _feedback(level, result)
	return result


static func _feedback(level: LevelData, r: Dictionary) -> String:
	if r.success:
		return level.success_text
	if level.goal_type != "measurement_distribution" and r.distance <= QFidelity.DISTRIBUTION_THRESHOLD:
		return "The probabilities match, but the phase is different. The next gate would reveal it."
	return "Not quite. Compare your result with the target and try again."
