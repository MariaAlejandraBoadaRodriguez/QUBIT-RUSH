class_name ScreenBase
extends Control
## Common screen scaffold: background, safe-area aware margins, a vertical
## content column, Android Back handling and keyboard cancel.

var content: VBoxContainer
var margin: MarginContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = AppTheme.get_theme(bool(SaveService.get_setting("large_text")))
	var bg := ColorRect.new()
	bg.color = AppTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	content = UI.vbox(12)
	margin.add_child(content)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	build()
	_focus_first.call_deferred()


## Override to build the screen into `content`.
func build() -> void:
	pass


## Override for Android Back / Escape. Default: go home.
func go_back() -> void:
	GameState.goto("home")


func _apply_safe_area() -> void:
	var g := AppTheme.GUTTER
	var insets := Rect2(0, 0, 0, 0)
	if OS.has_feature("mobile"):
		var win := Vector2(DisplayServer.window_get_size())
		var safe := Rect2(DisplayServer.get_display_safe_area())
		var vis := get_viewport_rect().size
		if win.x > 0 and win.y > 0:
			var k := vis / win
			insets.position = safe.position * k
			insets.size = (win - safe.end) * k
	margin.add_theme_constant_override("margin_left", int(g + insets.position.x))
	margin.add_theme_constant_override("margin_top", int(g + insets.position.y))
	margin.add_theme_constant_override("margin_right", int(g + maxf(insets.size.x, 0)))
	margin.add_theme_constant_override("margin_bottom", int(g + maxf(insets.size.y, 0)))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		go_back()


func _focus_first() -> void:
	# Hardware keyboard / D-pad users get an initial focus target.
	var b := _find_first_button(content)
	if b != null and not OS.has_feature("mobile"):
		b.grab_focus()


func _find_first_button(n: Node) -> Button:
	for c in n.get_children():
		if c is Button and c.visible and not c.disabled:
			return c
		var r := _find_first_button(c)
		if r != null:
			return r
	return null


## Header row with an optional back button and a title.
func header(title: String, back_text := "‹ Back") -> HBoxContainer:
	var h := UI.hbox(8)
	if back_text != "":
		var b := UI.button(back_text, "FlatButton")
		b.name = "BackButton"
		b.pressed.connect(go_back)
		h.add_child(b)
	var t := UI.label(title, "HeadingLabel")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(t)
	content.add_child(h)
	return h


func scroll_column() -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(sc)
	var v := UI.vbox(12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	return v
