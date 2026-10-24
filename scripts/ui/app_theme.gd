class_name AppTheme
extends RefCounted
## Approved light design system (SPEC §3). All colours come from these tokens.

const BG := Color("#FAFAF8")
const SURFACE := Color("#FFFFFF")
const TEXT := Color("#142338")
const TEXT_2 := Color("#667181")
const PRIMARY := Color("#253C58")
const SOFT_BLUE := Color("#7DA7EA")
const PALE_BLUE := Color("#EAF1FB")
const BORDER := Color("#E4E7EB")
const GATE_X := Color("#E78F98")
const GATE_Z := Color("#A58DDB")
const SUCCESS := Color("#3B806C")
const ERROR := Color("#B35E60")

## Design units: the canvas is 720 px wide (~360 dp), so 1 dp ≈ 2 px.
const DP := 2.0
const TOUCH := 48.0 * DP
const GUTTER := 16.0 * DP

static var _theme: Theme
static var _scale := 1.0

const FONT_REGULAR := "res://assets/fonts/Inter-Regular.otf"
const FONT_SEMIBOLD := "res://assets/fonts/Inter-SemiBold.otf"
const FONT_FALLBACK := "res://assets/fonts/DejaVuSans-ket-subset.ttf"


static func gate_color(gate: String) -> Color:
	match gate:
		"X":
			return GATE_X
		"Z", "S", "T":
			return GATE_Z
		_:
			return SOFT_BLUE


static func text_scale() -> float:
	return _scale


static func size(sp: float) -> int:
	return int(round(sp * DP * _scale))


static func font(semibold := false) -> Font:
	var f := FontVariation.new()
	var base: FontFile = load(FONT_SEMIBOLD if semibold else FONT_REGULAR)
	var fb: FontFile = load(FONT_FALLBACK)
	base.fallbacks = [fb]
	f.base_font = base
	return f


static func get_theme(large_text := false) -> Theme:
	var s := 1.2 if large_text else 1.0
	if _theme != null and is_equal_approx(s, _scale):
		return _theme
	_scale = s
	_theme = build()
	return _theme


static func stylebox(bg: Color, radius := 12.0, border := Color.TRANSPARENT, border_w := 0, pad := 12.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(int(radius * DP))
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	sb.content_margin_left = pad * DP
	sb.content_margin_right = pad * DP
	sb.content_margin_top = pad * DP * 0.6
	sb.content_margin_bottom = pad * DP * 0.6
	sb.anti_aliasing = true
	return sb


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = font(false)
	t.default_font_size = size(16)
	t.set_color("font_color", "Label", TEXT)
	# Buttons: secondary (outlined surface) by default.
	t.set_stylebox("normal", "Button", stylebox(SURFACE, 12, BORDER, 2))
	t.set_stylebox("hover", "Button", stylebox(PALE_BLUE, 12, BORDER, 2))
	t.set_stylebox("pressed", "Button", stylebox(PALE_BLUE, 12, SOFT_BLUE, 2))
	t.set_stylebox("disabled", "Button", stylebox(BG, 12, BORDER, 2))
	t.set_stylebox("focus", "Button", stylebox(Color.TRANSPARENT, 12, SOFT_BLUE, 4))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", TEXT)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", TEXT_2)
	t.set_font("font", "Button", font(true))
	t.set_font_size("font_size", "Button", size(16))
	# Primary button variation.
	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", stylebox(PRIMARY, 14))
	t.set_stylebox("hover", "PrimaryButton", stylebox(PRIMARY.lightened(0.08), 14))
	t.set_stylebox("pressed", "PrimaryButton", stylebox(PRIMARY.darkened(0.15), 14))
	t.set_stylebox("disabled", "PrimaryButton", stylebox(TEXT_2, 14))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		t.set_color(k, "PrimaryButton", Color.WHITE)
	# Flat text button.
	t.set_type_variation("FlatButton", "Button")
	for st in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(st, "FlatButton", stylebox(Color.TRANSPARENT, 10, Color.TRANSPARENT, 0, 8))
	t.set_color("font_color", "FlatButton", PRIMARY)
	# Selected tab / chip.
	t.set_type_variation("SelectedButton", "Button")
	t.set_stylebox("normal", "SelectedButton", stylebox(PRIMARY, 12))
	t.set_stylebox("hover", "SelectedButton", stylebox(PRIMARY, 12))
	t.set_stylebox("pressed", "SelectedButton", stylebox(PRIMARY, 12))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(k, "SelectedButton", Color.WHITE)
	# Panels / cards.
	t.set_stylebox("panel", "PanelContainer", stylebox(SURFACE, 16, BORDER, 2, 16))
	t.set_type_variation("PaleCard", "PanelContainer")
	t.set_stylebox("panel", "PaleCard", stylebox(PALE_BLUE, 16, Color.TRANSPARENT, 0, 16))
	t.set_type_variation("PlainPanel", "PanelContainer")
	t.set_stylebox("panel", "PlainPanel", StyleBoxEmpty.new())
	# Labels.
	t.set_type_variation("TitleLabel", "Label")
	t.set_font("font", "TitleLabel", font(true))
	t.set_font_size("font_size", "TitleLabel", size(28))
	t.set_type_variation("HeadingLabel", "Label")
	t.set_font("font", "HeadingLabel", font(true))
	t.set_font_size("font_size", "HeadingLabel", size(20))
	t.set_type_variation("SecondaryLabel", "Label")
	t.set_color("font_color", "SecondaryLabel", TEXT_2)
	t.set_font_size("font_size", "SecondaryLabel", size(14))
	# Scrollbars kept slim.
	var grabber := stylebox(BORDER, 6, Color.TRANSPARENT, 0, 2)
	for bar in ["HScrollBar", "VScrollBar"]:
		t.set_stylebox("scroll", bar, StyleBoxEmpty.new())
		t.set_stylebox("grabber", bar, grabber)
		t.set_stylebox("grabber_highlight", bar, grabber)
		t.set_stylebox("grabber_pressed", bar, grabber)
	t.set_stylebox("panel", "PopupPanel", stylebox(SURFACE, 16, BORDER, 2, 16))
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_font_size("font_size", "CheckButton", size(16))
	t.set_stylebox("normal", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover_pressed", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("focus", "CheckButton", stylebox(Color.TRANSPARENT, 8, SOFT_BLUE, 3))
	return t
