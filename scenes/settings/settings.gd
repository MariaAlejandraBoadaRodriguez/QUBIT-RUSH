extends ScreenBase
## Settings: sound, music, haptics, accessibility, privacy, ad choices, reset.


func build() -> void:
	header("Settings")
	var col := scroll_column()
	col.add_child(UI.label("Sound", "SecondaryLabel"))
	_toggle(col, "Sound effects", "sfx")
	_toggle(col, "Music", "music")
	_toggle(col, "Vibration (haptics)", "haptics")
	col.add_child(UI.label("Accessibility", "SecondaryLabel"))
	_toggle(col, "Reduce motion", "reduced_motion")
	_toggle(col, "Larger text", "large_text", true)
	col.add_child(UI.label("Privacy", "SecondaryLabel"))
	var pp := UI.button("Privacy policy")
	pp.name = "PrivacyButton"
	pp.pressed.connect(func(): Sheet.open(self, "Privacy policy", FileAccess.get_file_as_string("res://data/privacy_policy.txt")))
	col.add_child(pp)
	var ads := UI.button("Ad choices")
	ads.name = "AdChoicesButton"
	ads.pressed.connect(GameState.goto.bind("consent"))
	col.add_child(ads)
	col.add_child(UI.label("Progress", "SecondaryLabel"))
	var reset := UI.button("Reset local progress")
	reset.name = "ResetProgressButton"
	reset.add_theme_color_override("font_color", AppTheme.ERROR)
	reset.pressed.connect(_confirm_reset)
	col.add_child(reset)
	var lic := UI.button("Credits and licences", "FlatButton")
	lic.pressed.connect(func(): Sheet.open(self, "Credits and licences", FileAccess.get_file_as_string("res://data/credits.txt")))
	col.add_child(lic)
	col.add_child(UI.label("Qubit Rush %s · No account needed. Progress is stored only on this device." % ProjectSettings.get_setting("application/config/version"), "SecondaryLabel"))


func _toggle(parent: Control, text: String, key: String, rebuild := false) -> void:
	var c := CheckButton.new()
	c.name = "Toggle_" + key
	c.text = text
	c.custom_minimum_size.y = AppTheme.TOUCH
	c.button_pressed = bool(SaveService.get_setting(key))
	c.toggled.connect(func(on):
		SaveService.set_setting(key, on)
		AudioService.play("tick")
		if rebuild:
			GameState.goto("settings"))
	parent.add_child(c)


func _confirm_reset() -> void:
	var s := Sheet.open(self, "Reset progress?", "This clears stars and unlocked levels on this device. Settings stay as they are. This cannot be undone.", "Cancel")
	var b := UI.button("Reset progress")
	b.name = "ConfirmReset"
	b.add_theme_color_override("font_color", AppTheme.ERROR)
	b.pressed.connect(func():
		SaveService.reset_progress()
		s.close()
		GameState.goto("home"))
	s.body.add_child(b)
