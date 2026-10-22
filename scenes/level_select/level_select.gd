extends ScreenBase
## Levels: chapter tabs, cards with stars and lock state. No ad banners.

const TABS := [["fundamentals", "Fundamentals"], ["entanglement", "Entanglement"], ["algorithms", "Algorithms"]]

var list: VBoxContainer
var tab_buttons := {}


func build() -> void:
	header("Levels")
	var tabs := UI.hbox(8)
	for t in TABS:
		var b := UI.button(t[1])
		b.name = "Tab_" + t[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", AppTheme.size(14))
		b.pressed.connect(_select_tab.bind(t[0]))
		tabs.add_child(b)
		tab_buttons[t[0]] = b
	content.add_child(tabs)
	list = scroll_column()
	list.name = "LevelList"
	_select_tab(GameState.level_tab)


func _select_tab(tab: String) -> void:
	GameState.level_tab = tab
	for k in tab_buttons:
		tab_buttons[k].theme_type_variation = "SelectedButton" if k == tab else ""
	for c in list.get_children():
		c.queue_free()
	for L in GameState.levels:
		if L.chapter == tab:
			list.add_child(_card(L))


func _card(L: LevelData) -> Button:
	var unlocked := GameState.is_unlocked(L)
	var stars := SaveService.level_stars(L.id)
	var b := UI.button("")
	b.name = "Level_%d" % L.number
	b.custom_minimum_size.y = AppTheme.TOUCH * 1.5
	b.disabled = not unlocked
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var row := UI.hbox(12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 16 * AppTheme.DP
	row.offset_right = -16 * AppTheme.DP
	var num := UI.label(str(L.number), "HeadingLabel", false)
	num.custom_minimum_size.x = 40 * AppTheme.DP
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(num)
	var title := UI.label(L.title, "", false)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	row.add_child(title)
	var status := UI.label(UI.stars_text(stars) if unlocked else "Locked", "SecondaryLabel", false)
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if unlocked:
		status.add_theme_font_size_override("font_size", AppTheme.size(18))
		status.add_theme_color_override("font_color", AppTheme.PRIMARY)
	row.add_child(status)
	for c in row.get_children():
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	b.tooltip_text = "Level %d, %s, %s" % [L.number, L.title,
		("%d of 3 stars" % stars) if unlocked else "locked: finish the previous level first"]
	if "accessibility_name" in b:
		b.set("accessibility_name", b.tooltip_text)
	b.pressed.connect(GameState.start_level.bind(L, "learn"))
	return b
