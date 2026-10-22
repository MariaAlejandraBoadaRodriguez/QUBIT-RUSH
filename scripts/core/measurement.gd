class_name QMeasurement
extends RefCounted
## Born-rule sampling. Measurement never mutates the input state: collapse
## always returns a new copy, so deterministic comparisons stay random-free.


## Samples one basis index from the state's probabilities using `rng`.
static func sample(state: StateVector, rng: RandomNumberGenerator) -> int:
	var p := state.probabilities()
	var r := rng.randf()
	var acc := 0.0
	for i in p.size():
		acc += p[i]
		if r < acc:
			return i
	# Floating point slack: return the last index with non-zero probability.
	for i in range(p.size() - 1, -1, -1):
		if p[i] > 0.0:
			return i
	return 0


## Repeats `shots` measurements on fresh copies; returns counts per basis index.
static func sample_counts(state: StateVector, shots: int, seed: int) -> PackedInt64Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var counts := PackedInt64Array()
	counts.resize(state.dim())
	counts.fill(0)
	for _i in shots:
		counts[sample(state, rng)] += 1
	return counts


## Returns a collapsed copy for a full-register outcome.
static func collapse_copy(state: StateVector, outcome: int) -> StateVector:
	if outcome < 0 or outcome >= state.dim():
		return null
	var s := StateVector.zero(state.num_qubits)
	s.amps[0] = 0.0
	s.amps[outcome * 2] = 1.0
	return s


## Measures one qubit: returns {"result": 0|1, "state": collapsed copy}.
static func measure_qubit(state: StateVector, q: int, rng: RandomNumberGenerator) -> Dictionary:
	if q < 0 or q >= state.num_qubits:
		return {}
	var p1 := state.qubit_one_probability(q)
	var result := 1 if rng.randf() < p1 else 0
	var s := state.copy()
	var bit := 1 << q
	for i in s.dim():
		var is_one := (i & bit) != 0
		if is_one != (result == 1):
			s.amps[i * 2] = 0.0
			s.amps[i * 2 + 1] = 0.0
	s.normalize()
	return {"result": result, "state": s}
