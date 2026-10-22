class_name UI
extends RefCounted
## Small factory helpers so screens stay declarative and consistent.


static func label(text: String, variation := "", wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 1
	return l


static func button(text: String, variation := "", min_h := AppTheme.TOUCH) -> Button:
	var b := Button.new()
	b.text = text
	if variation != "":
		b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(AppTheme.TOUCH, min_h)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func(): AudioService.play("tick"))
	return b


static func card(variation := "") -> PanelContainer:
	var p := PanelContainer.new()
	if variation != "":
		p.theme_type_variation = variation
	return p


static func vbox(sep := 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(sep * AppTheme.DP))
	return v


static func hbox(sep := 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(sep * AppTheme.DP))
	return h


static func spacer(h := 0.0) -> Control:
	var c := Control.new()
	if h > 0.0:
		c.custom_minimum_size.y = h * AppTheme.DP
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func hspacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func expand(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


## Star text that does not rely on colour: "★★☆  2 of 3 stars".
static func stars_text(stars: int, with_words := false) -> String:
	var s := "★".repeat(stars) + "☆".repeat(3 - stars)
	if with_words:
		s += "  %d of 3 stars" % stars
	return s
