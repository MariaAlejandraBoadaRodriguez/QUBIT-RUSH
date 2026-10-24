extends ScreenBase
## Home: one obvious Play button, no login, no consent wall.


func build() -> void:
	content.add_child(UI.spacer(24))
	var art := AtomIllustration.new()
	art.custom_minimum_size = Vector2(0, 320)
	content.add_child(art)
	var title := UI.label("Qubit Rush", "TitleLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", AppTheme.size(36))
	content.add_child(title)
	var tag := UI.label("Solve quantum puzzles, one gate at a time", "SecondaryLabel")
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", AppTheme.size(16))
	content.add_child(tag)
	content.add_child(UI.spacer(16))
	var next := GameState.next_unfinished()
	var play := UI.button("Play", "PrimaryButton", AppTheme.TOUCH * 1.4)
	play.name = "PlayButton"
	play.add_theme_font_size_override("font_size", AppTheme.size(22))
	play.pressed.connect(_on_play)
	content.add_child(play)
	if next != null:
		var sub := UI.label("Level %d · %s" % [next.number, next.title], "SecondaryLabel")
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(sub)
	content.add_child(UI.spacer(8))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(12 * AppTheme.DP))
	grid.add_theme_constant_override("v_separation", int(12 * AppTheme.DP))
	for item in [["Levels", "levels"], ["Learn", "learn"], ["Challenges", "challenges"], ["Settings", "settings"]]:
		var b := UI.button(item[0])
		b.name = item[0] + "Button"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(GameState.goto.bind(item[1]))
		grid.add_child(b)
	content.add_child(grid)
	content.add_child(UI.spacer())
	var stars := UI.label("%d stars collected · progress is saved on this device" % SaveService.total_stars(), "SecondaryLabel")
	stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(stars)


func _on_play() -> void:
	var L := GameState.next_unfinished()
	if L != null:
		GameState.start_level(L, "learn")


func go_back() -> void:
	get_tree().quit()
