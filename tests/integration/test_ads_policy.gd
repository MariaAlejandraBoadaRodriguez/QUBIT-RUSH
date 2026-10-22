extends GutTest
## Ads safety (Gate D): consent gating, declined/unavailable ads, reward
## idempotency, no ads during gameplay, child-safe interstitial policy.

const PATH := "user://test_ads_save.json"
var mock: MockAdsProvider
var granted := []


func before_each() -> void:
	for f in [PATH, PATH + ".tmp", PATH + ".bak"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	SaveService.load_data(PATH)
	ConsentService.config = ConsentService.load_config()
	AdsService.gameplay_active = false
	mock = MockAdsProvider.new()
	granted.clear()
	if not AdsService.reward_granted.is_connected(_on_granted):
		AdsService.reward_granted.connect(_on_granted)


func after_all() -> void:
	AdsService.set_provider(AdsProvider.new())
	ConsentService.config = ConsentService.load_config()
	SaveService.load_data(SaveService.DEFAULT_PATH)


func _on_granted(kind: String, context: String) -> void:
	granted.append([kind, context])


func _consent_and_init() -> void:
	ConsentService.set_ads_choice("allowed")
	ConsentService.set_ump_status("not_required")
	AdsService.set_provider(mock)


func test_shipped_config_is_child_safe_with_test_ids() -> void:
	var c := ConsentService.load_config()
	assert_eq(c.audience_policy, "child_safe")
	assert_false(c.interstitial_enabled)
	assert_true(c.test_mode)
	assert_eq(c.max_ad_content_rating, "G")
	for k in ["app_id", "rewarded_unit", "interstitial_unit"]:
		assert_true(str(c.android[k]).begins_with("ca-app-pub-3940256099942544"), "%s is a Google test ID" % k)


func test_malformed_config_falls_back_to_safe_defaults() -> void:
	var c := ConsentService.load_config("res://does/not/exist.json")
	assert_false(c.ads_enabled)
	assert_eq(c.audience_policy, "child_safe")


func test_no_ads_without_opt_in() -> void:
	AdsService.set_provider(mock)
	assert_false(ConsentService.can_request_ads(), "unset choice means no ads")
	assert_false(AdsService.can_offer_rewarded())
	assert_false(AdsService.show_rewarded("hint", "L01"))
	assert_eq(mock.shows, 0)


func test_declined_consent_blocks_ads() -> void:
	ConsentService.set_ads_choice("declined")
	ConsentService.set_ump_status("obtained")
	AdsService.set_provider(mock)
	assert_false(AdsService.can_offer_rewarded())


func test_ump_required_but_not_obtained_blocks_ads() -> void:
	ConsentService.set_ads_choice("allowed")
	ConsentService.set_ump_status("required")
	AdsService.set_provider(mock)
	assert_false(ConsentService.can_request_ads())
	assert_false(AdsService.can_offer_rewarded())


func test_rewarded_flow_grants_once() -> void:
	_consent_and_init()
	assert_true(AdsService.can_offer_rewarded(), "loaded after consent")
	assert_true(AdsService.show_rewarded("hint", "L05"))
	assert_eq(granted.size(), 1)
	assert_eq(AdsService.bonus_hints("L05"), 1)


func test_duplicate_reward_callbacks_grant_once() -> void:
	_consent_and_init()
	mock.duplicate_callbacks = 3
	AdsService.show_rewarded("hint", "L07")
	assert_eq(granted.size(), 1, "4 callbacks, 1 grant")
	assert_eq(AdsService.bonus_hints("L07"), 1)


func test_replayed_reward_id_is_not_granted_again() -> void:
	_consent_and_init()
	AdsService.show_rewarded("hint", "L08")
	# Simulate the SDK re-delivering an old callback after the ad closed.
	mock.reward_earned.emit("mock-1")
	assert_eq(granted.size(), 1)


func test_no_reward_when_dismissed_early() -> void:
	_consent_and_init()
	mock.grant_reward = false
	var finished := []
	AdsService.rewarded_finished.connect(func(g): finished.append(g), CONNECT_ONE_SHOT)
	AdsService.show_rewarded("hint", "L09")
	assert_eq(granted.size(), 0, "never granted on open/dismiss")
	assert_eq(finished, [false])


func test_reward_callback_without_active_show_is_ignored() -> void:
	_consent_and_init()
	mock.reward_earned.emit("forged-1")
	assert_eq(granted.size(), 0)


func test_no_fill_and_errors_degrade_gracefully() -> void:
	mock.fill = false
	_consent_and_init()
	assert_false(AdsService.can_offer_rewarded())
	assert_false(AdsService.show_rewarded("hint", "L01"))
	assert_eq(AdsService.last_error, "no_fill")
	var m2 := MockAdsProvider.new()
	m2.show_error = "internal"
	AdsService.set_provider(m2)
	assert_true(AdsService.show_rewarded("hint", "L01"))
	assert_eq(granted.size(), 0)
	assert_eq(AdsService.rewarded_state, AdsService.RewardedState.IDLE)


func test_init_failure_means_unavailable() -> void:
	mock.init_ok = false
	_consent_and_init()
	assert_false(AdsService.can_offer_rewarded())


func test_no_ads_during_gameplay() -> void:
	_consent_and_init()
	AdsService.gameplay_active = true
	assert_false(AdsService.can_offer_rewarded())
	assert_false(AdsService.show_rewarded("hint", "L01"))
	assert_false(AdsService.interstitial_allowed(40, 10 ** 9))
	assert_eq(mock.shows, 0)


func test_interstitials_disabled_under_child_safe_policy() -> void:
	_consent_and_init()
	ConsentService.config.interstitial_enabled = true
	SaveService.data.ads.levels_since_interstitial = 10
	assert_false(AdsService.interstitial_allowed(20, 10 ** 9))
	for i in 12:
		assert_false(AdsService.on_level_break(10 + i))
	assert_eq(mock.interstitial_shows, 0)


func test_interstitial_caps_for_general_audience() -> void:
	_consent_and_init()
	ConsentService.config.audience_policy = "general"
	ConsentService.config.interstitial_enabled = true
	var now := 1_000_000
	SaveService.data.ads.last_interstitial_unix = 0
	SaveService.data.ads.levels_since_interstitial = 4
	assert_false(AdsService.interstitial_allowed(3, now), "never in the first levels")
	assert_true(AdsService.interstitial_allowed(10, now))
	SaveService.data.ads.levels_since_interstitial = 3
	assert_false(AdsService.interstitial_allowed(10, now), "at most one per 4 levels")
	SaveService.data.ads.levels_since_interstitial = 4
	SaveService.data.ads.last_interstitial_unix = now - 300
	assert_false(AdsService.interstitial_allowed(10, now), "at most one per 10 minutes")


func test_revoking_consent_stops_offers() -> void:
	_consent_and_init()
	assert_true(AdsService.can_offer_rewarded())
	ConsentService.revoke()
	assert_false(AdsService.can_offer_rewarded())


func test_progression_never_requires_ads() -> void:
	# With ads impossible, every level is still solvable via free play.
	AdsService.set_provider(AdsProvider.new())
	for L in LevelLoader.load_all().levels:
		assert_true(LevelValidator.evaluate(L, L.solution).success, "L%d without ads" % L.number)


func test_release_override_applies_production_ids_only_when_given() -> void:
	var path := "user://test_ads_release.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"test_mode": false, "audience_policy": "child_safe",
		"android": {"app_id": "ca-app-pub-1~2", "rewarded_unit": "ca-app-pub-1/3", "interstitial_unit": ""}}))
	f.close()
	var c := ConsentService.apply_override(ConsentService.load_config(), path)
	assert_false(c.test_mode)
	assert_eq(c.android.rewarded_unit, "ca-app-pub-1/3")
	assert_eq(c.audience_policy, "child_safe")
	assert_true(str(c.android.interstitial_unit).begins_with("ca-app-pub-3940256099942544"), "empty values keep defaults")
	var bad := ConsentService.apply_override(ConsentService.load_config(), "user://missing.json")
	assert_true(bad.test_mode, "missing override changes nothing")
	DirAccess.remove_absolute(path)


func test_rewarded_offer_appears_on_results_only_when_allowed() -> void:
	_consent_and_init()
	GameState.capture_navigation = true
	GameState.mode = "learn"
	var L: LevelData = GameState.levels[4]
	GameState.last_result = LevelValidator.evaluate(L, [])
	GameState.last_result["level"] = L
	var r: Control = load(GameState.SCREENS["results"]).instantiate()
	add_child_autofree(r)
	await wait_physics_frames(2)
	var offer := r.find_child("RewardedOffer", true, false)
	assert_not_null(offer, "optional offer shown after a failed attempt when ads are allowed")
	var run_btn := r.find_child("RunButton", true, false)
	assert_null(run_btn, "offer never shares a screen with Run")
	(r.find_child("WatchAdButton", true, false) as Button).pressed.emit()
	assert_eq(AdsService.bonus_hints(L.id), 1)
	GameState.capture_navigation = false
