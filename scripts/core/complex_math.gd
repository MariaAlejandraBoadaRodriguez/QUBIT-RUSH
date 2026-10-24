class_name CMath
extends RefCounted
## Minimal double-precision complex helpers.
##
## Complex numbers are stored as interleaved (re, im) pairs inside
## PackedFloat64Array so that the simulator never depends on engine types
## with float32 precision (Vector2 is single precision in standard builds).

const EPS := 1e-9
const INV_SQRT2 := 0.70710678118654752440


static func mul_re(a_re: float, a_im: float, b_re: float, b_im: float) -> float:
	return a_re * b_re - a_im * b_im


static func mul_im(a_re: float, a_im: float, b_re: float, b_im: float) -> float:
	return a_re * b_im + a_im * b_re


static func abs2(re: float, im: float) -> float:
	return re * re + im * im


## Builds a 2x2 complex matrix [[a, b], [c, d]] from 8 floats in row-major order.
static func mat2(a_re: float, a_im: float, b_re: float, b_im: float,
		c_re: float, c_im: float, d_re: float, d_im: float) -> PackedFloat64Array:
	return PackedFloat64Array([a_re, a_im, b_re, b_im, c_re, c_im, d_re, d_im])


## Multiplies two 2x2 complex matrices (m1 * m2).
static func mat2_mul(m1: PackedFloat64Array, m2: PackedFloat64Array) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(8)
	for r in 2:
		for c in 2:
			var re := 0.0
			var im := 0.0
			for k in 2:
				var a := (r * 2 + k) * 2
				var b := (k * 2 + c) * 2
				re += mul_re(m1[a], m1[a + 1], m2[b], m2[b + 1])
				im += mul_im(m1[a], m1[a + 1], m2[b], m2[b + 1])
			out[(r * 2 + c) * 2] = re
			out[(r * 2 + c) * 2 + 1] = im
	return out


static func mat2_approx_equal(m1: PackedFloat64Array, m2: PackedFloat64Array, tol := 1e-9) -> bool:
	if m1.size() != 8 or m2.size() != 8:
		return false
	for i in 8:
		if absf(m1[i] - m2[i]) > tol:
			return false
	return true


## Formats a complex number compactly for UI ("0.707", "-0.707i", "0.5+0.5i").
static func format(re: float, im: float, digits := 3) -> String:
	var r := snappedf(re, pow(10.0, -digits))
	var i := snappedf(im, pow(10.0, -digits))
	if absf(r) < 0.5 * pow(10.0, -digits):
		r = 0.0
	if absf(i) < 0.5 * pow(10.0, -digits):
		i = 0.0
	if i == 0.0:
		return _num(r, digits)
	if r == 0.0:
		return _num(i, digits) + "i"
	var sign := "+" if i > 0.0 else "−"
	return "%s%s%si" % [_num(r, digits), sign, _num(absf(i), digits)]


static func _num(v: float, digits: int) -> String:
	var s := String.num(v, digits)
	if s.ends_with(".0"):
		s = s.substr(0, s.length() - 2)
	if s.begins_with("-"):
		s = "−" + s.substr(1)
	return s
