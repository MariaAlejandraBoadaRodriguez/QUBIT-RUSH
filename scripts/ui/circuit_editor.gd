class_name CircuitEditor
extends Control
## Horizontal circuit editor. One column per operation; fixed (pre-placed)
## gates come first and are locked. Supports tap-to-place on the selected
## wire, drag-and-drop onto a slot, selection, move, remove, undo and reset.

signal ops_changed(ops: Array)
signal selection_changed

const COL_W := 120.0
const WIRE_H := 128.0
const LABEL_W := 150.0
const PAD := 16.0
const BTN := 100.0

var num_qubits := 1
var start_label := "0"
var fixed_ops: Array = []
var ops: Array = []
var max_slots := 4
var allowed: Array = []
var selected_wire := 0
var selected_index := -1
var _history: Array = []
var _drop_col := -1


func configure(n: int, start: String, fixed: Array, slots: int, gates: Array, initial: Array = []) -> void:
	num_qubits = n
	start_label = start
	fixed_ops = fixed.duplicate(true)
	max_slots = slots
	allowed = gates.duplicate()
	ops = initial.duplicate(true)
	selected_wire = 0
	selected_index = -1
	_history.clear()
	_rebuild()


func total_columns() -> int:
	return fixed_ops.size() + max_slots


func slots_left() -> int:
	return max_slots - ops.size()


func _push_history() -> void:
	_history.append(ops.duplicate(true))
	if _history.size() > 100:
		_history.pop_front()


func can_undo() -> bool:
	return not _history.is_empty()


## Places a gate on the selected wire at the end (or after the selected op).
func place_gate(gate: String, wire := -1, column := -1) -> bool:
	if slots_left() <= 0 or not gate in allowed:
		return false
	var w := selected_wire if wire < 0 else wire
	if w < 0 or w >= num_qubits:
		return false
	var op := {"gate": gate, "target": w}
	if QGates.is_controlled(gate):
		if num_qubits < 2:
			return false
		op = {"gate": gate, "control": w, "target": (w + 1) % num_qubits}
	var at := ops.size()
	if column >= 0:
		at = clampi(column - fixed_ops.size(), 0, ops.size())
	elif selected_index >= 0:
		at = selected_index + 1
	_push_history()
	ops.insert(at, op)
	selected_index = -1
	_commit()
	return true


func remove_selected() -> bool:
	if selected_index < 0 or selected_index >= ops.size():
		return false
	_push_history()
	ops.remove_at(selected_index)
	selected_index = -1
	_commit()
	return true


func move_selected(delta: int) -> bool:
	var j := selected_index + delta
	if selected_index < 0 or j < 0 or j >= ops.size():
		return false
	_push_history()
	var tmp = ops[selected_index]
	ops[selected_index] = ops[j]
	ops[j] = tmp
	selected_index = j
	_commit()
	return true


## Moves the selected single-qubit gate to another wire, or for CNOT moves
## the target to the next free wire.
func shift_selected_wire(delta: int) -> bool:
	if selected_index < 0 or num_qubits < 2:
		return false
	_push_history()
	var op: Dictionary = ops[selected_index]
	if QGates.is_controlled(op.gate):
		var t := int(op.target)
		for _i in num_qubits:
			t = posmod(t + delta, num_qubits)
			if t != int(op.control):
				break
		op.target = t
	else:
		op.target = posmod(int(op.target) + delta, num_qubits)
		selected_wire = op.target
	_commit()
	return true


func swap_selected_control() -> bool:
	if selected_index < 0 or not QGates.is_controlled(ops[selected_index].gate):
		return false
	_push_history()
	var op: Dictionary = ops[selected_index]
	var c := int(op.control)
	op.control = int(op.target)
	op.target = c
	_commit()
	return true


func undo() -> bool:
	if _history.is_empty():
		return false
	ops = _history.pop_back()
	selected_index = -1
	_commit()
	return true


func reset() -> bool:
	if ops.is_empty():
		return false
	_push_history()
	ops.clear()
	selected_index = -1
	_commit()
	return true


func select_op(i: int) -> void:
	selected_index = -1 if i == selected_index else i
	if selected_index >= 0:
		var op: Dictionary = ops[selected_index]
		selected_wire = int(op.get("control", op.target)) if QGates.is_controlled(op.gate) else int(op.target)
	_rebuild()
	selection_changed.emit()


func select_wire(w: int) -> void:
	selected_wire = clampi(w, 0, num_qubits - 1)
	selected_index = -1
	_rebuild()
	selection_changed.emit()


func _commit() -> void:
	_rebuild()
	ops_changed.emit(ops)
	selection_changed.emit()


# ---- Layout -----------------------------------------------------------------

func wire_y(w: int) -> float:
	return PAD + WIRE_H * (w + 0.5)


func col_x(c: int) -> float:
	return LABEL_W + COL_W * (c + 0.5)


func _rebuild() -> void:
	for ch in get_children():
		remove_child(ch)
		ch.queue_free()
	custom_minimum_size = Vector2(LABEL_W + COL_W * total_columns() + PAD, PAD * 2 + WIRE_H * num_qubits)
	for w in num_qubits:
		var b := _btn("q%d  |%s⟩" % [w, start_label[w]], Vector2(8, wire_y(w) - BTN / 2), Vector2(LABEL_W - 20, BTN))
		b.name = "Wire_%d" % w
		b.tooltip_text = "Select qubit %d (wire %d)" % [w, w]
		b.theme_type_variation = "SelectedButton" if w == selected_wire and num_qubits > 1 else "FlatButton"
		b.pressed.connect(select_wire.bind(w))
	var col := 0
	for i in fixed_ops.size():
		_add_op_buttons(fixed_ops[i], col, -1)
		col += 1
	for i in ops.size():
		_add_op_buttons(ops[i], col, i)
		col += 1
	while col < total_columns():
		for w in num_qubits:
			var b := _btn("", Vector2(col_x(col) - BTN / 2, wire_y(w) - BTN / 2), Vector2(BTN, BTN))
			b.name = "Slot_%d_%d" % [col, w]
			b.tooltip_text = "Empty slot %d on qubit %d" % [col + 1, w]
			var sb := AppTheme.stylebox(AppTheme.SURFACE, 10, AppTheme.BORDER, 3)
			if w == selected_wire:
				sb = AppTheme.stylebox(AppTheme.PALE_BLUE, 10, AppTheme.SOFT_BLUE, 3)
			b.add_theme_stylebox_override("normal", sb)
			b.add_theme_stylebox_override("hover", sb)
			b.pressed.connect(select_wire.bind(w))
		col += 1
	queue_redraw()


func _btn(text: String, pos: Vector2, sz: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.custom_minimum_size = sz
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.set_drag_forwarding(Callable(), _fwd_can_drop.bind(b), _fwd_drop.bind(b))
	add_child(b)
	return b


func _add_op_buttons(op: Dictionary, col: int, idx: int) -> void:
	var locked := idx < 0
	var sel := idx >= 0 and idx == selected_index
	var g: String = op.gate
	var color := AppTheme.gate_color(g)
	var bg := AppTheme.PALE_BLUE if sel else (AppTheme.BG if locked else AppTheme.SURFACE)
	var border := AppTheme.PRIMARY if sel else (AppTheme.TEXT_2 if locked else color)
	var step := "step %d" % (col + 1)
	var lock_note := " (fixed)" if locked else ""
	if QGates.is_controlled(g):
		var cb := _btn("●", Vector2(col_x(col) - BTN / 2, wire_y(int(op.control)) - BTN / 2), Vector2(BTN, BTN))
		cb.name = "Op_%d_control" % col
		cb.tooltip_text = "CNOT control on qubit %d, %s%s" % [op.control, step, lock_note]
		_style_op(cb, bg, border, locked)
		var tb := _btn("⊕", Vector2(col_x(col) - BTN / 2, wire_y(int(op.target)) - BTN / 2), Vector2(BTN, BTN))
		tb.name = "Op_%d_target" % col
		tb.tooltip_text = "CNOT target on qubit %d, %s%s" % [op.target, step, lock_note]
		_style_op(tb, bg, border, locked)
		if not locked:
			cb.pressed.connect(select_op.bind(idx))
			tb.pressed.connect(select_op.bind(idx))
	else:
		var b := _btn(g, Vector2(col_x(col) - BTN / 2, wire_y(int(op.target)) - BTN / 2), Vector2(BTN, BTN))
		b.name = "Op_%d" % col
		b.tooltip_text = "%s gate on qubit %d, %s%s" % [g, op.target, step, lock_note]
		_style_op(b, bg, border, locked)
		if not locked:
			b.pressed.connect(select_op.bind(idx))
	for c in get_children():
		if c is Button and "accessibility_name" in c:
			c.set("accessibility_name", c.tooltip_text)


func _style_op(b: Button, bg: Color, border: Color, locked: bool) -> void:
	var sb := AppTheme.stylebox(bg, 12, border, 4 if not locked else 2)
	if locked:
		sb.draw_center = true
	for s in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(s, sb if s != "focus" else AppTheme.stylebox(Color.TRANSPARENT, 12, AppTheme.SOFT_BLUE, 5))
	b.add_theme_font_size_override("font_size", AppTheme.size(20))
	b.add_theme_color_override("font_color", AppTheme.TEXT_2 if locked else AppTheme.TEXT)
	if locked:
		b.disabled = false
		b.focus_mode = Control.FOCUS_NONE


func _draw() -> void:
	var width := LABEL_W + COL_W * total_columns()
	for w in num_qubits:
		var y := wire_y(w)
		draw_line(Vector2(LABEL_W - 10, y), Vector2(width, y), AppTheme.SOFT_BLUE if w == selected_wire else AppTheme.BORDER, 4.0, true)
	var all := fixed_ops + ops
	for c in all.size():
		var op: Dictionary = all[c]
		if QGates.is_controlled(op.gate):
			var x := col_x(c)
			draw_line(Vector2(x, wire_y(int(op.control))), Vector2(x, wire_y(int(op.target))), AppTheme.PRIMARY, 5.0, true)
	if fixed_ops.size() > 0:
		var x := LABEL_W + COL_W * fixed_ops.size()
		draw_dashed_line(Vector2(x, PAD), Vector2(x, PAD + WIRE_H * num_qubits), AppTheme.TEXT_2, 2.0, 8.0)
	if _drop_col >= 0:
		var x := LABEL_W + COL_W * _drop_col
		draw_line(Vector2(x, PAD), Vector2(x, PAD + WIRE_H * num_qubits), AppTheme.PRIMARY, 6.0)


# ---- Drag and drop ----------------------------------------------------------

func _drop_target(pos: Vector2) -> Vector2i:
	var col := clampi(int(round((pos.x - LABEL_W) / COL_W)), fixed_ops.size(), fixed_ops.size() + ops.size())
	var wire := clampi(int((pos.y - PAD) / WIRE_H), 0, num_qubits - 1)
	return Vector2i(col, wire)


func _can_drop_data(at: Vector2, data) -> bool:
	var ok: bool = typeof(data) == TYPE_DICTIONARY and data.has("gate") and data.gate in allowed and slots_left() > 0
	_drop_col = _drop_target(at).x if ok else -1
	queue_redraw()
	return ok


func _drop_data(at: Vector2, data) -> void:
	var t := _drop_target(at)
	_drop_col = -1
	selected_index = -1
	place_gate(data.gate, t.y, t.x)
	AudioService.play("tick")


func _fwd_can_drop(at: Vector2, data, b: Control) -> bool:
	return _can_drop_data(at + b.position, data)


func _fwd_drop(at: Vector2, data, b: Control) -> void:
	_drop_data(at + b.position, data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _drop_col >= 0:
		_drop_col = -1
		queue_redraw()
