class_name ProbabilityBars
extends Control
## Horizontal probability bars per basis state, easing toward the computed
## values. Target values (when given) are drawn as outlined markers so the
## comparison never relies on colour alone; percentages are always printed.

const ROW_H := 54.0
const LABEL_W := 120.0
const PCT_W := 120.0

var num_qubits := 1
var values := PackedFloat64Array()
var shown := PackedFloat64Array()
var targets := PackedFloat64Array()
var bar_color := AppTheme.SOFT_BLUE


func set_values(p: PackedFloat64Array, animate := true) -> void:
	values = p.duplicate()
	num_qubits = int(round(log(maxf(p.size(), 1)) / log(2.0)))
	if shown.size() != p.size() or not animate or bool(SaveService.get_setting("reduced_motion")):
		shown = p.duplicate()
		set_process(false)
	else:
		set_process(true)
	custom_minimum_size.y = ROW_H * p.size() * AppTheme.text_scale()
	_update_a11y()
	queue_redraw()


func set_targets(t: PackedFloat64Array) -> void:
	targets = t.duplicate()
	_update_a11y()
	queue_redraw()


func summary() -> String:
	var parts: Array[String] = []
	for i in values.size():
		parts.append("|%s⟩ %d%%" % [StateVector.index_to_label(i, num_qubits), roundi(values[i] * 100.0)])
	return ", ".join(parts)


func _update_a11y() -> void:
	tooltip_text = "Probabilities: " + summary()
	if "accessibility_name" in self:
		set("accessibility_name", tooltip_text)


func _process(delta: float) -> void:
	var done := true
	for i in shown.size():
		var d := values[i] - shown[i]
		if absf(d) > 0.002:
			shown[i] += d * minf(1.0, delta * 9.0)
			done = false
		else:
			shown[i] = values[i]
	queue_redraw()
	if done:
		set_process(false)


func _draw() -> void:
	var font := get_theme_default_font()
	var fs := AppTheme.size(14)
	var row := ROW_H * AppTheme.text_scale()
	var bar_w := maxf(size.x - LABEL_W - PCT_W, 40.0)
	for i in shown.size():
		var y := i * row
		var label := "|%s⟩" % StateVector.index_to_label(i, num_qubits)
		draw_string(font, Vector2(0, y + row * 0.68), label, HORIZONTAL_ALIGNMENT_LEFT, LABEL_W, fs, AppTheme.TEXT)
		var r := Rect2(LABEL_W, y + row * 0.2, bar_w, row * 0.6)
		draw_rect(r, AppTheme.PALE_BLUE)
		draw_rect(Rect2(r.position, Vector2(bar_w * clampf(shown[i], 0, 1), r.size.y)), bar_color)
		if i < targets.size():
			var tx := LABEL_W + bar_w * clampf(targets[i], 0, 1)
			draw_rect(Rect2(LABEL_W, r.position.y - 3, bar_w * clampf(targets[i], 0, 1), r.size.y + 6), AppTheme.PRIMARY, false, 3.0)
			draw_line(Vector2(tx, r.position.y - 8), Vector2(tx, r.end.y + 8), AppTheme.PRIMARY, 4.0)
		draw_string(font, Vector2(LABEL_W + bar_w + 12, y + row * 0.68), "%d%%" % roundi(values[i] * 100.0 if i < values.size() else 0.0),
			HORIZONTAL_ALIGNMENT_LEFT, PCT_W, fs, AppTheme.TEXT)
