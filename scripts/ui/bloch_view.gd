class_name BlochView
extends Control
## Simplified 2D Bloch sphere: projected circle, equator and state arrow for
## one qubit's reduced state. A shorter arrow means the qubit is entangled.

var vec := Vector3(0, 0, 1)
var qubit := 0


func set_vector(v: Vector3, q := 0) -> void:
	vec = v
	qubit = q
	var desc := "Qubit %d direction x %.2f, y %.2f, z %.2f" % [q, v.x, v.y, v.z]
	tooltip_text = desc
	if "accessibility_name" in self:
		set("accessibility_name", desc)
	queue_redraw()


func _project(v: Vector3, c: Vector2, r: float) -> Vector2:
	# Oblique projection: x to the right, z up, y receding diagonally.
	return c + Vector2(v.x * r - v.y * r * 0.38, -v.z * r + v.y * r * 0.22)


func _draw() -> void:
	var fs := AppTheme.size(12)
	var font := get_theme_default_font()
	var r := minf(size.x, size.y) * 0.36
	var c := size / 2.0
	draw_arc(c, r, 0, TAU, 72, AppTheme.BORDER, 3.0, true)
	var pts := PackedVector2Array()
	for i in 49:
		var a := TAU * i / 48.0
		pts.append(_project(Vector3(cos(a), sin(a), 0), c, r))
	draw_polyline(pts, AppTheme.BORDER, 2.0, true)
	draw_line(_project(Vector3(0, 0, 1), c, r), _project(Vector3(0, 0, -1), c, r), AppTheme.BORDER, 2.0)
	draw_line(_project(Vector3(-1, 0, 0), c, r), _project(Vector3(1, 0, 0), c, r), AppTheme.BORDER, 2.0)
	draw_string(font, _project(Vector3(0, 0, 1.22), c, r) + Vector2(-16, 8), "|0⟩", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, AppTheme.TEXT_2)
	draw_string(font, _project(Vector3(0, 0, -1.22), c, r) + Vector2(-16, 14), "|1⟩", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, AppTheme.TEXT_2)
	draw_string(font, _project(Vector3(1.3, 0, 0), c, r) + Vector2(-12, 8), "|+⟩", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, AppTheme.TEXT_2)
	var tip := _project(vec, c, r)
	draw_line(c, tip, AppTheme.PRIMARY, 5.0, true)
	draw_circle(tip, 9.0, AppTheme.PRIMARY)
	draw_string(font, Vector2(0, size.y - 4), "q%d" % qubit, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, AppTheme.TEXT_2)
