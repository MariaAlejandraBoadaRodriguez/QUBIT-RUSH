class_name QFidelity
extends RefCounted
## State and distribution comparison.

const STATE_THRESHOLD := 0.999
const DISTRIBUTION_THRESHOLD := 0.01


## F = |<a|b>|^2, invariant under global phase. Returns 0 for mismatched sizes.
static func state_fidelity(a: StateVector, b: StateVector) -> float:
	var ip := a.inner(b) if a != null else []
	if ip.is_empty():
		return 0.0
	return CMath.abs2(ip[0], ip[1])


## Total variation distance 0.5 * sum |p_i - q_i|. Returns 1 if sizes differ.
static func total_variation(p: PackedFloat64Array, q: PackedFloat64Array) -> float:
	if p.size() != q.size():
		return 1.0
	var d := 0.0
	for i in p.size():
		d += absf(p[i] - q[i])
	return 0.5 * d
