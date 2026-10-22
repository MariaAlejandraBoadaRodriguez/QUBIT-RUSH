class_name GateButton
extends Button
## Gate tray button: tap to place, drag onto the circuit, long-press to read
## a description (motor-accessible tap alternative is always available).

signal tapped(gate: String)
signal described(gate: String)

const LONG_PRESS_SEC := 0.5

var gate := ""
var _press_time := -1.0
var _long_fired := false


func setup(g: String) -> GateButton:
	gate = g
	text = g
	name = "Gate_" + g
	custom_minimum_size = Vector2(AppTheme.TOUCH * 1.15, AppTheme.TOUCH * 1.15)
	focus_mode = Control.FOCUS_ALL
	tooltip_text = QGates.DESCRIPTIONS.get(g, g)
	if "accessibility_name" in self:
		set("accessibility_name", "%s gate. %s" % [g, tooltip_text])
	var col := AppTheme.gate_color(g)
	add_theme_stylebox_override("normal", AppTheme.stylebox(AppTheme.SURFACE, 12, col, 4))
	add_theme_stylebox_override("hover", AppTheme.stylebox(AppTheme.PALE_BLUE, 12, col, 4))
	add_theme_stylebox_override("pressed", AppTheme.stylebox(AppTheme.PALE_BLUE, 12, AppTheme.PRIMARY, 4))
	add_theme_font_size_override("font_size", AppTheme.size(20))
	pressed.connect(_on_pressed)
	return self


func highlight(on: bool) -> void:
	var col := AppTheme.PRIMARY if on else AppTheme.gate_color(gate)
	add_theme_stylebox_override("normal", AppTheme.stylebox(AppTheme.PALE_BLUE if on else AppTheme.SURFACE, 12, col, 6 if on else 4))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_time = Time.get_ticks_msec() / 1000.0
			_long_fired = false
		else:
			_press_time = -1.0


func _process(_delta: float) -> void:
	if _press_time > 0.0 and not _long_fired and Time.get_ticks_msec() / 1000.0 - _press_time >= LONG_PRESS_SEC:
		_long_fired = true
		described.emit(gate)


func _on_pressed() -> void:
	if _long_fired:
		_long_fired = false
		return
	tapped.emit(gate)


func _get_drag_data(_at: Vector2):
	_press_time = -1.0
	var preview := Label.new()
	preview.text = gate
	preview.add_theme_font_size_override("font_size", AppTheme.size(22))
	preview.add_theme_color_override("font_color", AppTheme.PRIMARY)
	set_drag_preview(preview)
	return {"gate": gate}
