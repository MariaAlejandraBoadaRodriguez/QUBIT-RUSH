class_name Sheet
extends Control
## Modal bottom sheet ("Learn more" drawer, gate descriptions, confirmations).

signal closed

var body: VBoxContainer


static func open(parent: Control, title: String, text: String, close_text := "Close") -> Sheet:
	var s := Sheet.new()
	s.name = "Sheet"
	parent.add_child(s)
	s._build(title, text, close_text)
	return s


func _build(title: String, text: String, close_text: String) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(AppTheme.TEXT, 0.25)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: close())
	add_child(dim)
	var card := UI.card()
	card.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	card.offset_left = AppTheme.GUTTER / 2
	card.offset_right = -AppTheme.GUTTER / 2
	card.offset_bottom = -AppTheme.GUTTER
	add_child(card)
	body = UI.vbox(12)
	card.add_child(body)
	body.add_child(UI.label(title, "HeadingLabel"))
	if text != "":
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.custom_minimum_size.y = minf(900.0, 60.0 + text.length() * 0.9)
		var l := UI.label(text)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(l)
		body.add_child(sc)
	if close_text != "":
		var b := UI.button(close_text, "PrimaryButton")
		b.name = "CloseButton"
		b.pressed.connect(close)
		body.add_child(b)
		b.grab_focus.call_deferred()


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		close()
