extends ScreenBase
## Ad choices. Never shown as a wall before play; reachable from Settings and
## from optional offers. Declining has no effect on progression.


func build() -> void:
	ConsentService.set_dialog_open(true)
	header("Ad choices")
	var col := scroll_column()
	col.add_child(UI.label("Qubit Rush is free. Every level can be finished without ads."))
	col.add_child(UI.label("If you allow optional ads, you can choose to watch a short video to get an extra hint. Ads never appear during puzzles, tutorials or timed challenges."))
	if ConsentService.is_child_safe():
		col.add_child(UI.label("Family-safe mode is on: ads are not personalised and are limited to general-audience content.", "SecondaryLabel"))
	var status := UI.label(_status_text(), "HeadingLabel")
	status.name = "ConsentStatus"
	col.add_child(status)
	var allow := UI.button("Allow optional ads", "PrimaryButton")
	allow.name = "AllowAds"
	allow.pressed.connect(_allow)
	col.add_child(allow)
	var decline := UI.button("No ads, thanks")
	decline.name = "DeclineAds"
	decline.pressed.connect(func():
		ConsentService.revoke()
		go_back())
	col.add_child(decline)
	if AdsService.android() != null:
		var opts := UI.button("Privacy options (Google)", "FlatButton")
		opts.pressed.connect(func(): AdsService.android().show_privacy_options())
		col.add_child(opts)


func _status_text() -> String:
	match ConsentService.ads_choice():
		"allowed":
			return "Current choice: optional ads allowed"
		"declined":
			return "Current choice: no ads"
		_:
			return "Current choice: not set (no ads)"


func _allow() -> void:
	ConsentService.set_ads_choice("allowed")
	var p := AdsService.android()
	if p != null:
		var plugin := p.plugin()
		if not plugin.is_connected("consent_status", _on_consent_status):
			plugin.connect("consent_status", _on_consent_status)
		p.request_consent(ConsentService.is_child_safe())
	else:
		ConsentService.set_ump_status("not_required")
		go_back()


func _on_consent_status(status: String, can_request: bool) -> void:
	# Only statuses under which the UMP SDK allows ad requests unlock ads.
	if can_request:
		ConsentService.set_ump_status("obtained" if status == "obtained" else "not_required")
	else:
		ConsentService.set_ump_status(status if status in ["required", "unknown", "error"] else "unknown")
	if is_inside_tree():
		go_back()


func go_back() -> void:
	ConsentService.set_dialog_open(false)
	GameState.goto("settings")


func _exit_tree() -> void:
	ConsentService.set_dialog_open(false)
