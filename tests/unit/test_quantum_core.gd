extends GutTest
## Quantum mathematics unit tests (SPEC §14, Gate A).
## Wire ordering: qubit 0 = least significant bit; labels are written q0 first.

const TOL := 1e-9
const R := CMath.INV_SQRT2


func _apply(s: StateVector, gate: String, t := 0, c := -1) -> StateVector:
	var op := {"gate": gate, "target": t}
	if c >= 0:
		op["control"] = c
	assert_true(QGates.apply(s, op), "apply %s" % gate)
	return s


func _assert_amps(s: StateVector, expected: Array, msg := "") -> void:
	assert_eq(s.amps.size(), expected.size() * 2, "size " + msg)
	for i in expected.size():
		var e = expected[i]
		var re: float = e[0] if typeof(e) == TYPE_ARRAY else e
		var im: float = e[1] if typeof(e) == TYPE_ARRAY else 0.0
		assert_almost_eq(s.amp_re(i), re, TOL, "re[%d] %s" % [i, msg])
		assert_almost_eq(s.amp_im(i), im, TOL, "im[%d] %s" % [i, msg])


func test_initial_state_is_all_zero() -> void:
	_assert_amps(StateVector.zero(2), [1.0, 0.0, 0.0, 0.0])


func test_x_on_zero_gives_one() -> void:
	_assert_amps(_apply(StateVector.zero(1), "X"), [0.0, 1.0])


func test_x_squared_is_identity() -> void:
	var m := CMath.mat2_mul(QGates.matrix("X"), QGates.matrix("X"))
	assert_true(CMath.mat2_approx_equal(m, QGates.matrix("I")))


func test_h_on_zero_gives_plus() -> void:
	_assert_amps(_apply(StateVector.zero(1), "H"), [R, R])


func test_h_squared_is_identity() -> void:
	var m := CMath.mat2_mul(QGates.matrix("H"), QGates.matrix("H"))
	assert_true(CMath.mat2_approx_equal(m, QGates.matrix("I"), 1e-12))


func test_z_plus_is_minus() -> void:
	var s := _apply(_apply(StateVector.zero(1), "H"), "Z")
	_assert_amps(s, [R, -R])


func test_hzh_zero_is_one() -> void:
	var s := StateVector.zero(1)
	for g in ["H", "Z", "H"]:
		_apply(s, g)
	_assert_amps(s, [0.0, 1.0])


func test_bell_state_with_documented_ordering() -> void:
	# H on q0, then CNOT control q0 -> target q1 gives (|00> + |11>)/sqrt2.
	var s := _apply(StateVector.zero(2), "H", 0)
	_apply(s, "CNOT", 1, 0)
	_assert_amps(s, [R, 0.0, 0.0, R])
	assert_eq(StateVector.index_to_label(3, 2), "11")
	var bell := StateVector.from_kets(2, {"00": 1.0, "11": 1.0})
	assert_almost_eq(QFidelity.state_fidelity(bell, s), 1.0, TOL)


func test_wire_ordering_labels() -> void:
	# X on q1 only: label "01" (q0=0, q1=1) = basis index 2.
	var s := _apply(StateVector.zero(2), "X", 1)
	_assert_amps(s, [0.0, 0.0, 1.0, 0.0])
	assert_eq(StateVector.label_to_index("01"), 2)
	assert_eq(StateVector.label_to_index("10"), 1)
	assert_eq(StateVector.from_label("01").to_ket_string(), "|01⟩")


func test_cnot_only_flips_when_control_is_one() -> void:
	var s := StateVector.zero(2)
	_apply(s, "CNOT", 1, 0)
	_assert_amps(s, [1.0, 0.0, 0.0, 0.0], "control 0")
	s = StateVector.from_label("10")  # q0 = 1
	_apply(s, "CNOT", 1, 0)
	_assert_amps(s, [0.0, 0.0, 0.0, 1.0], "control 1")
	# Reverse direction: control q1, target q0.
	s = StateVector.from_label("01")
	_apply(s, "CNOT", 0, 1)
	_assert_amps(s, [0.0, 0.0, 0.0, 1.0], "reverse")


func test_three_qubit_cnot_targets() -> void:
	var s := StateVector.from_label("100")
	_apply(s, "CNOT", 2, 0)
	assert_eq(s.to_ket_string(), "|101⟩")


func test_s_phase() -> void:
	var s := _apply(StateVector.from_label("1"), "S")
	_assert_amps(s, [0.0, [0.0, 1.0]])
	var ss := CMath.mat2_mul(QGates.matrix("S"), QGates.matrix("S"))
	assert_true(CMath.mat2_approx_equal(ss, QGates.matrix("Z")), "S^2 = Z")


func test_t_phase() -> void:
	var s := _apply(StateVector.from_label("1"), "T")
	_assert_amps(s, [0.0, [R, R]])
	var tt := CMath.mat2_mul(QGates.matrix("T"), QGates.matrix("T"))
	assert_true(CMath.mat2_approx_equal(tt, QGates.matrix("S"), 1e-12), "T^2 = S")


func test_y_has_imaginary_amplitudes() -> void:
	_assert_amps(_apply(StateVector.zero(1), "Y"), [0.0, [0.0, 1.0]], "Y|0> = i|1>")
	_assert_amps(_apply(StateVector.from_label("1"), "Y"), [[0.0, -1.0], 0.0], "Y|1> = -i|0>")
	var yy := CMath.mat2_mul(QGates.matrix("Y"), QGates.matrix("Y"))
	assert_true(CMath.mat2_approx_equal(yy, QGates.matrix("I")), "Y^2 = I")


func test_norm_preserved_for_random_sequences() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for n in [1, 2, 3]:
		var moves := LevelSolver.candidate_ops(QGates.ALL, n)
		for _trial in 50:
			var s := StateVector.zero(n)
			for _k in 40:
				QGates.apply(s, moves[rng.randi_range(0, moves.size() - 1)])
			assert_almost_eq(s.norm_squared(), 1.0, 1e-9, "norm n=%d" % n)
			var total := 0.0
			for p in s.probabilities():
				total += p
			assert_almost_eq(total, 1.0, 1e-9)


func test_fidelity_ignores_global_phase() -> void:
	var a := _apply(StateVector.zero(1), "H")
	var b := a.copy()
	# Multiply by global phase e^{i 0.7}.
	var c := cos(0.7)
	var si := sin(0.7)
	for i in b.dim():
		var re := b.amp_re(i)
		var im := b.amp_im(i)
		b.amps[i * 2] = re * c - im * si
		b.amps[i * 2 + 1] = re * si + im * c
	assert_almost_eq(QFidelity.state_fidelity(a, b), 1.0, TOL)
	# Y|0> = i|1> matches |1> up to global phase.
	assert_almost_eq(QFidelity.state_fidelity(_apply(StateVector.zero(1), "Y"), StateVector.from_label("1")), 1.0, TOL)


func test_fidelity_detects_relative_phase() -> void:
	var plus := _apply(StateVector.zero(1), "H")
	var minus := _apply(_apply(StateVector.zero(1), "H"), "Z")
	assert_almost_eq(QFidelity.state_fidelity(plus, minus), 0.0, TOL)
	assert_almost_eq(QFidelity.total_variation(plus.probabilities(), minus.probabilities()), 0.0, TOL,
		"same probabilities, different state")


func test_seeded_measurement_converges() -> void:
	var s := _apply(StateVector.zero(1), "H")
	var counts := QMeasurement.sample_counts(s, 20000, 42)
	assert_eq(counts[0] + counts[1], 20000)
	# 5 standard deviations of a binomial(20000, 0.5) is ~354.
	assert_almost_eq(float(counts[0]), 10000.0, 354.0)
	# Determinism: same seed, same result.
	var again := QMeasurement.sample_counts(s, 20000, 42)
	assert_eq(again[0], counts[0])


func test_measurement_distribution_bell() -> void:
	var s := _apply(StateVector.zero(2), "H", 0)
	_apply(s, "CNOT", 1, 0)
	var counts := QMeasurement.sample_counts(s, 10000, 7)
	assert_eq(counts[1], 0, "|10> never appears")
	assert_eq(counts[2], 0, "|01> never appears")
	assert_almost_eq(float(counts[0]), 5000.0, 250.0)


func test_measurement_collapses_copy_only() -> void:
	var s := _apply(StateVector.zero(1), "H")
	var before := s.amps.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var r := QMeasurement.measure_qubit(s, 0, rng)
	assert_eq(s.amps, before, "original state untouched")
	var collapsed: StateVector = r.state
	assert_almost_eq(collapsed.qubit_one_probability(0), float(r.result), TOL)
	var full := QMeasurement.collapse_copy(s, 1)
	_assert_amps(full, [0.0, 1.0])
	assert_eq(s.amps, before)


func test_measure_one_qubit_of_bell_pair_collapses_partner() -> void:
	var s := _apply(StateVector.zero(2), "H", 0)
	_apply(s, "CNOT", 1, 0)
	var rng := RandomNumberGenerator.new()
	for seed in 20:
		rng.seed = seed
		var r := QMeasurement.measure_qubit(s, 0, rng)
		assert_almost_eq(r.state.qubit_one_probability(1), float(r.result), TOL, "partner agrees")


func test_bloch_vectors() -> void:
	assert_almost_eq(StateVector.zero(1).bloch_vector(0).z, 1.0, TOL)
	var plus := _apply(StateVector.zero(1), "H")
	assert_almost_eq(plus.bloch_vector(0).x, 1.0, TOL)
	var i_state := _apply(_apply(StateVector.zero(1), "H"), "S")
	assert_almost_eq(i_state.bloch_vector(0).y, 1.0, TOL)
	var bell := _apply(StateVector.zero(2), "H", 0)
	_apply(bell, "CNOT", 1, 0)
	assert_almost_eq(bell.bloch_vector(0).length(), 0.0, TOL, "entangled qubit has no pure direction")


func test_invalid_operations_fail_safely() -> void:
	var s := StateVector.zero(2)
	var before := s.amps.duplicate()
	assert_false(QGates.apply(s, {"gate": "X", "target": 2}), "out of range target")
	assert_false(QGates.apply(s, {"gate": "X", "target": -1}), "negative target")
	assert_false(QGates.apply(s, {"gate": "CNOT", "control": 0, "target": 0}), "same wire")
	assert_false(QGates.apply(s, {"gate": "CNOT", "control": 5, "target": 0}), "bad control")
	assert_false(QGates.apply(s, {"gate": "Q", "target": 0}), "unknown gate")
	assert_false(QGates.apply(s, {"target": 0}), "missing gate")
	assert_false(QGates.apply(null, {"gate": "X", "target": 0}), "null state")
	assert_eq(s.amps, before, "state untouched by invalid ops")
	assert_null(StateVector.zero(0))
	assert_null(StateVector.zero(4))
	assert_null(StateVector.from_label("012"))
	assert_null(StateVector.from_kets(1, {"0": 0.0}), "zero vector rejected")
	assert_null(StateVector.from_kets(1, {"00": 1.0}), "wrong label length")
	assert_null(StateVector.from_kets(1, {"0": "x"}), "non-numeric amplitude")


func test_circuit_validation_and_run() -> void:
	var c := QCircuit.create(2, [{"gate": "H", "target": 0}, {"gate": "CNOT", "control": 0, "target": 1}])
	assert_eq(c.validate().size(), 0)
	assert_eq(c.validate(["H"]).size(), 1, "CNOT not allowed")
	var bad := QCircuit.create(2, [{"gate": "X", "target": 9}])
	assert_eq(bad.validate().size(), 1)
	assert_null(bad.run(StateVector.zero(2)), "invalid circuit does not run")
	assert_null(c.run(StateVector.zero(1)), "size mismatch")
	var start := StateVector.zero(2)
	var out := c.run(start)
	assert_almost_eq(out.amp_re(3), R, TOL)
	assert_almost_eq(start.amp_re(0), 1.0, TOL, "run does not mutate input")


func test_complex_format() -> void:
	assert_eq(CMath.format(0.70710678, 0.0), "0.707")
	assert_eq(CMath.format(0.0, -1.0), "−1i")
	assert_eq(CMath.format(0.5, -0.5), "0.5−0.5i")
	assert_eq(StateVector.from_kets(1, {"0": 1.0, "1": -1.0}).to_ket_string(), "0.707|0⟩ − 0.707|1⟩")
	var y := StateVector.zero(1)
	QGates.apply(y, {"gate": "Y", "target": 0})
	assert_eq(y.to_ket_string(), "1i|1⟩")
