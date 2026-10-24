extends ScreenBase
## Results: success/failure, target comparison, explanation, stars and
## next/retry. An optional rewarded hint is offered separately, never next
## to Run/Undo and never during gameplay.

var r: Dictionary


func build() -> void:
	r = GameState.last_result
	if r.is_empty():
		GameState.goto.call_deferred("home")
		return
	if r.get("rush", false):
		_build_rush()
		return
	var L: LevelData = r.level
	var col := scroll_column()
	var title := UI.label(L.success_text if r.success else "Not quite yet", "TitleLabel")
	title.name = "ResultTitle"
	title.add_theme_color_override("font_color", AppTheme.SUCCESS if r.success else AppTheme.ERROR)
	col.add_child(title)
	var stars := UI.label(UI.stars_text(int(r.stars), true), "HeadingLabel")
	stars.name = "Stars"
	stars.add_theme_color_override("font_color", AppTheme.PRIMARY)
	col.add_child(stars)
	if r.success:
		var eff := "You used %d gate%s. Three stars need %d or fewer." % [r.gate_count, "" if r.gate_count == 1 else "s", L.three_star_gates]
		col.add_child(UI.label(eff, "SecondaryLabel"))
	else:
		col.add_child(UI.label(str(r.message)))
	# Comparison.
	var card := UI.card()
	var v := UI.vbox(8)
	card.add_child(v)
	v.add_child(UI.label("Target: " + L.target_description()))
	var final: StateVector = r.final_state
	if final != null:
		v.add_child(UI.label("Yours: " + final.to_ket_string()))
		if L.target_state != null:
			v.add_child(UI.label("Match (fidelity): %d%%" % roundi(r.fidelity * 100.0), "SecondaryLabel"))
		var bars := ProbabilityBars.new()
		bars.name = "ComparisonBars"
		bars.set_values(final.probabilities(), false)
		bars.set_targets(L.target_state.probabilities() if L.target_state != null else L.target_probs)
		v.add_child(bars)
		v.add_child(UI.label("Filled bars: your result. Outlined boxes: the target.", "SecondaryLabel"))
	col.add_child(card)
	if L.why != "":
		var why := UI.card("PaleCard")
		var wv := UI.vbox(6)
		why.add_child(wv)
		wv.add_child(UI.label("Why it works", "HeadingLabel"))
		wv.add_child(UI.label(L.why))
		col.add_child(why)
	var buttons := UI.vbox(10)
	var next := GameState.next_level(L) if GameState.mode == "learn" else null
	if r.success and next != null:
		var nb := UI.button("Next level", "PrimaryButton")
		nb.name = "NextButton"
		nb.pressed.connect(_go_next.bind(next))
		buttons.add_child(nb)
	var retry := UI.button("Try again" if not r.success else "Replay")
	retry.name = "RetryButton"
	retry.pressed.connect(_retry)
	buttons.add_child(retry)
	var lv := UI.button("Levels" if GameState.mode == "learn" else "Challenges", "FlatButton")
	lv.name = "LevelsButton"
	lv.pressed.connect(go_back)
	buttons.add_child(lv)
	col.add_child(buttons)
	_maybe_offer_rewarded(col, L)


func _maybe_offer_rewarded(col: VBoxContainer, L: LevelData) -> void:
	if GameState.mode != "learn" or int(r.stars) >= 3 or not AdsService.can_offer_rewarded():
		return
	col.add_child(UI.spacer(24))
	var card := UI.card("PaleCard")
	card.name = "RewardedOffer"
	var v := UI.vbox(8)
	card.add_child(v)
	v.add_child(UI.label("Optional: watch a short ad to unlock one extra hint for your next attempt at this level. Basic hints are always free.", "SecondaryLabel"))
	var b := UI.button("Watch ad for an extra hint")
	b.name = "WatchAdButton"
	b.pressed.connect(func():
		AdsService.show_rewarded("hint", L.id)
		card.visible = false)
	v.add_child(b)
	col.add_child(card)


func _build_rush() -> void:
	header("Rush results", "")
	content.add_child(UI.label("%d challenges solved" % r.solved, "TitleLabel"))
	content.add_child(UI.label("Score: %d%s" % [r.score, "  · new personal best" if r.new_best else ""], "HeadingLabel"))
	content.add_child(UI.label("Best on this device: %d" % int(SaveService.data.rush.best), "SecondaryLabel"))
	var again := UI.button("Play again", "PrimaryButton")
	again.name = "RetryButton"
	again.pressed.connect(func():
		GameState.rush = {}
		GameState.mode = "rush"
		GameState.goto("puzzle"))
	content.add_child(again)
	var back := UI.button("Challenges", "FlatButton")
	back.name = "LevelsButton"
	back.pressed.connect(go_back)
	content.add_child(back)


func _go_next(next: LevelData) -> void:
	AdsService.on_level_break(r.level.number)
	GameState.start_level(next, "learn")


func _retry() -> void:
	if r.success and GameState.mode == "learn":
		AdsService.on_level_break(r.level.number)
	GameState.start_level(r.level, GameState.mode)


func go_back() -> void:
	if GameState.mode == "learn":
		GameState.goto("levels")
	else:
		GameState.goto("challenges")
