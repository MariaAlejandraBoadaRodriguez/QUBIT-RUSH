class_name StateVector
extends RefCounted
## Pure n-qubit state stored as 2^n complex amplitudes.
##
## Qubit ordering convention (documented and tested):
## * Qubit 0 is the top wire in the circuit editor.
## * Basis index i = sum(bit_q << q): qubit 0 is the LEAST significant bit.
## * Ket labels are written in wire order, qubit 0 first: "|q0 q1 q2⟩".
##   Example (2 qubits): label "01" means q0 = 0, q1 = 1, which is index 2.

const MAX_QUBITS := 3

var num_qubits: int = 0
## Interleaved (re, im) amplitudes, length 2 * 2^num_qubits.
var amps := PackedFloat64Array()


static func zero(n: int) -> StateVector:
	if n < 1 or n > MAX_QUBITS:
		return null
	var s := StateVector.new()
	s.num_qubits = n
	s.amps.resize(2 * (1 << n))
	s.amps.fill(0.0)
	s.amps[0] = 1.0
	return s


## Builds a computational basis state from a ket label in wire order ("01").
static func from_label(label: String) -> StateVector:
	var idx := label_to_index(label)
	if idx < 0:
		return null
	var s := StateVector.zero(label.length())
	s.amps[0] = 0.0
	s.amps[idx * 2] = 1.0
	return s


## Builds a state from {label: [re, im]} pairs, normalising the result.
## Returns null for malformed input or a zero vector.
static func from_kets(n: int, kets: Dictionary) -> StateVector:
	var s := StateVector.zero(n)
	if s == null or kets.is_empty():
		return null
	s.amps.fill(0.0)
	for key in kets:
		if typeof(key) != TYPE_STRING or (key as String).length() != n:
			return null
		var idx := label_to_index(key)
		if idx < 0:
			return null
		var v = kets[key]
		var re := 0.0
		var im := 0.0
		if typeof(v) == TYPE_ARRAY and (v as Array).size() == 2 \
				and _is_number(v[0]) and _is_number(v[1]):
			re = float(v[0])
			im = float(v[1])
		elif _is_number(v):
			re = float(v)
		else:
			return null
		s.amps[idx * 2] = re
		s.amps[idx * 2 + 1] = im
	if not s.normalize():
		return null
	return s


static func _is_number(v) -> bool:
	return typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT


static func label_to_index(label: String) -> int:
	var n := label.length()
	if n < 1 or n > MAX_QUBITS:
		return -1
	var idx := 0
	for q in n:
		var ch := label[q]
		if ch == "1":
			idx |= 1 << q
		elif ch != "0":
			return -1
	return idx


static func index_to_label(index: int, n: int) -> String:
	var out := ""
	for q in n:
		out += "1" if (index >> q) & 1 else "0"
	return out


func dim() -> int:
	return 1 << num_qubits


func copy() -> StateVector:
	var s := StateVector.new()
	s.num_qubits = num_qubits
	s.amps = amps.duplicate()
	return s


func amp_re(i: int) -> float:
	return amps[i * 2]


func amp_im(i: int) -> float:
	return amps[i * 2 + 1]


func norm_squared() -> float:
	var total := 0.0
	for i in dim():
		total += amps[i * 2] * amps[i * 2] + amps[i * 2 + 1] * amps[i * 2 + 1]
	return total


func normalize() -> bool:
	var n2 := norm_squared()
	if n2 < CMath.EPS:
		return false
	var inv := 1.0 / sqrt(n2)
	for i in amps.size():
		amps[i] *= inv
	return true


## Born-rule probabilities P(i) = |amplitude_i|^2.
func probabilities() -> PackedFloat64Array:
	var p := PackedFloat64Array()
	p.resize(dim())
	for i in dim():
		p[i] = CMath.abs2(amps[i * 2], amps[i * 2 + 1])
	return p


## Probability that a single qubit is measured as 1.
func qubit_one_probability(q: int) -> float:
	var total := 0.0
	for i in dim():
		if (i >> q) & 1:
			total += CMath.abs2(amps[i * 2], amps[i * 2 + 1])
	return total


## Applies a 2x2 unitary to qubit q. Returns false (state untouched) on bad index.
func apply_single(m: PackedFloat64Array, q: int) -> bool:
	if q < 0 or q >= num_qubits or m.size() != 8:
		return false
	var bit := 1 << q
	for i in dim():
		if i & bit:
			continue
		var j := i | bit
		var a_re := amps[i * 2]
		var a_im := amps[i * 2 + 1]
		var b_re := amps[j * 2]
		var b_im := amps[j * 2 + 1]
		amps[i * 2] = CMath.mul_re(m[0], m[1], a_re, a_im) + CMath.mul_re(m[2], m[3], b_re, b_im)
		amps[i * 2 + 1] = CMath.mul_im(m[0], m[1], a_re, a_im) + CMath.mul_im(m[2], m[3], b_re, b_im)
		amps[j * 2] = CMath.mul_re(m[4], m[5], a_re, a_im) + CMath.mul_re(m[6], m[7], b_re, b_im)
		amps[j * 2 + 1] = CMath.mul_im(m[4], m[5], a_re, a_im) + CMath.mul_im(m[6], m[7], b_re, b_im)
	return true


## Applies a 2x2 unitary to `target` only where `control` is 1.
func apply_controlled(m: PackedFloat64Array, control: int, target: int) -> bool:
	if control < 0 or control >= num_qubits or target < 0 or target >= num_qubits:
		return false
	if control == target or m.size() != 8:
		return false
	var cbit := 1 << control
	var tbit := 1 << target
	for i in dim():
		if not (i & cbit) or (i & tbit):
			continue
		var j := i | tbit
		var a_re := amps[i * 2]
		var a_im := amps[i * 2 + 1]
		var b_re := amps[j * 2]
		var b_im := amps[j * 2 + 1]
		amps[i * 2] = CMath.mul_re(m[0], m[1], a_re, a_im) + CMath.mul_re(m[2], m[3], b_re, b_im)
		amps[i * 2 + 1] = CMath.mul_im(m[0], m[1], a_re, a_im) + CMath.mul_im(m[2], m[3], b_re, b_im)
		amps[j * 2] = CMath.mul_re(m[4], m[5], a_re, a_im) + CMath.mul_re(m[6], m[7], b_re, b_im)
		amps[j * 2 + 1] = CMath.mul_im(m[4], m[5], a_re, a_im) + CMath.mul_im(m[6], m[7], b_re, b_im)
	return true


## Inner product <self|other> as [re, im]. Returns [] if sizes differ.
func inner(other: StateVector) -> Array:
	if other == null or other.num_qubits != num_qubits:
		return []
	var re := 0.0
	var im := 0.0
	for i in dim():
		# conj(self_i) * other_i
		var a_re := amps[i * 2]
		var a_im := -amps[i * 2 + 1]
		re += CMath.mul_re(a_re, a_im, other.amps[i * 2], other.amps[i * 2 + 1])
		im += CMath.mul_im(a_re, a_im, other.amps[i * 2], other.amps[i * 2 + 1])
	return [re, im]


## Reduced Bloch vector (x, y, z) of qubit q. Length < 1 means q is entangled.
func bloch_vector(q: int) -> Vector3:
	if q < 0 or q >= num_qubits:
		return Vector3.ZERO
	var bit := 1 << q
	var rho10_re := 0.0
	var rho10_im := 0.0
	var p0 := 0.0
	var p1 := 0.0
	for i in dim():
		if i & bit:
			continue
		var j := i | bit
		var a_re := amps[i * 2]
		var a_im := amps[i * 2 + 1]
		var b_re := amps[j * 2]
		var b_im := amps[j * 2 + 1]
		p0 += CMath.abs2(a_re, a_im)
		p1 += CMath.abs2(b_re, b_im)
		# rho_10 = sum b * conj(a)
		rho10_re += CMath.mul_re(b_re, b_im, a_re, -a_im)
		rho10_im += CMath.mul_im(b_re, b_im, a_re, -a_im)
	return Vector3(2.0 * rho10_re, 2.0 * rho10_im, p0 - p1)


## Human-readable ket expansion, e.g. "0.707|00⟩ + 0.707|11⟩".
func to_ket_string(digits := 3) -> String:
	var parts: Array[String] = []
	for i in dim():
		var re := amps[i * 2]
		var im := amps[i * 2 + 1]
		if CMath.abs2(re, im) < 1e-8:
			continue
		var coeff := CMath.format(re, im, digits)
		if absf(re) > 1e-9 and absf(im) > 1e-9:
			coeff = "(" + coeff + ")"
		elif coeff == "1":
			coeff = ""
		elif coeff == "−1":
			coeff = "−"
		parts.append("%s|%s⟩" % [coeff, index_to_label(i, num_qubits)])
	var s := " + ".join(parts)
	return s.replace("+ −", "− ")
