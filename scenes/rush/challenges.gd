extends ScreenBase
## Challenges hub: Rush (timed, optional), Daily Challenge, Practice Lab.


func build() -> void:
	header("Challenges")
	var col := scroll_column()
	# Rush
	var rush := _card(col, "Rush", "Solve as many short circuits as you can in 60 seconds. The clock pauses if you leave the app.")
	var rb := UI.button("Start Rush", "PrimaryButton")
	rb.name = "RushButton"
	rb.disabled = not GameState.rush_unlocked()
	rb.pressed.connect(func():
		GameState.rush = {}
		GameState.mode = "rush"
		GameState.goto("puzzle"))
	rush.add_child(rb)
	if not GameState.rush_unlocked():
		rush.add_child(UI.label("Unlocks after level %d." % GameState.RUSH_UNLOCK_LEVEL, "SecondaryLabel"))
	else:
		rush.add_child(UI.label("Best score on this device: %d" % int(SaveService.data.rush.best), "SecondaryLabel"))
	# Daily
	var date := ChallengeGenerator.utc_date_string()
	var daily := _card(col, "Daily Challenge", "A new puzzle every day, made on your device from the date (%s UTC). Works offline." % date)
	var db := UI.button("Play today's puzzle" + (" again" if SaveService.is_daily_done(date) else ""))
	db.name = "DailyButton"
	db.disabled = not GameState.daily_unlocked()
	db.pressed.connect(func():
		var L := ChallengeGenerator.daily(date, GameState.highest_completed())
		GameState.start_level(L, "daily"))
	daily.add_child(db)
	if not GameState.daily_unlocked():
		daily.add_child(UI.label("Unlocks after level %d." % GameState.DAILY_UNLOCK_LEVEL, "SecondaryLabel"))
	elif SaveService.is_daily_done(date):
		daily.add_child(UI.label("Done for today: " + UI.stars_text(int(SaveService.data.daily[date]), true), "SecondaryLabel"))
	# Practice
	var lab := _card(col, "Practice Lab", "Experiment freely with the gates you have met. No goals, no timer.")
	var pb := UI.button("Open Practice Lab")
	pb.name = "PracticeButton"
	pb.pressed.connect(GameState.goto.bind("practice"))
	lab.add_child(pb)


func _card(col: VBoxContainer, title: String, text: String) -> VBoxContainer:
	var c := UI.card()
	var v := UI.vbox(8)
	c.add_child(v)
	v.add_child(UI.label(title, "HeadingLabel"))
	v.add_child(UI.label(text, "SecondaryLabel"))
	col.add_child(c)
	return v
