extends Node
## Respectful ad orchestration (SPEC §11). Policies enforced here:
## * Ads are never shown while gameplay, a tutorial or a timer is active.
## * Rewarded ads are opt-in; rewards are granted only from a verified reward
##   callback, exactly once per ad show (idempotent), never on ad open.
## * Interstitials are disabled under the child-safe audience policy and are
##   otherwise capped (natural breaks only, frequency limits).
## * Any failure (no fill, offline, SDK error, declined consent) simply makes
##   ads unavailable; progression never depends on ads.

signal rewarded_state_changed
signal reward_granted(kind: String, context: String)
signal rewarded_finished(granted: bool)

enum RewardedState { IDLE, LOADING, READY, SHOWING }

var provider: AdsProvider
var rewarded_state := RewardedState.IDLE
var last_error := ""
## Set by puzzle/tutorial/timer screens; while true no ad can be shown.
var gameplay_active := false
var _initialized := false
var _pending := {}
var _show_token := ""
var _granted_this_show := false
var _token_counter := 0


func _ready() -> void:
	ConsentService.consent_changed.connect(_on_consent_changed)
	set_provider(_default_provider())


func _default_provider() -> AdsProvider:
	if AndroidAdsProvider.plugin_present():
		return AndroidAdsProvider.new()
	return AdsProvider.new()  # Desktop / plain export: ads unavailable.


## The Android bridge when the native plugin is present, else null.
func android() -> AndroidAdsProvider:
	return provider as AndroidAdsProvider


func set_provider(p: AdsProvider) -> void:
	provider = p
	_initialized = false
	rewarded_state = RewardedState.IDLE
	provider.initialized.connect(_on_initialized)
	provider.rewarded_loaded.connect(_on_rewarded_loaded)
	provider.rewarded_failed_to_load.connect(_on_rewarded_failed)
	provider.rewarded_failed_to_show.connect(_on_rewarded_show_failed)
	provider.reward_earned.connect(_on_reward_earned)
	provider.rewarded_dismissed.connect(_on_rewarded_dismissed)
	_maybe_initialize()


func _on_consent_changed() -> void:
	if not ConsentService.can_request_ads():
		rewarded_state = RewardedState.IDLE
		rewarded_state_changed.emit()
	_maybe_initialize()


## Initialise only after consent decisions allow it.
func _maybe_initialize() -> void:
	if _initialized or provider == null or not provider.is_available():
		return
	if not ConsentService.can_request_ads():
		return
	provider.initialize(ConsentService.config, ConsentService.is_child_safe())


func _on_initialized(ok: bool) -> void:
	_initialized = ok
	if ok:
		preload_rewarded()


func _unit(kind: String) -> String:
	return str(ConsentService.config.get("android", {}).get(kind + "_unit", ""))


func preload_rewarded() -> void:
	if not _initialized or rewarded_state != RewardedState.IDLE or not _rewarded_policy_ok():
		return
	rewarded_state = RewardedState.LOADING
	rewarded_state_changed.emit()
	provider.load_rewarded(_unit("rewarded"))


func _rewarded_policy_ok() -> bool:
	return bool(ConsentService.config.get("rewarded_enabled", false)) and ConsentService.can_request_ads()


## True when an optional rewarded offer may be displayed to the player.
func can_offer_rewarded() -> bool:
	return _initialized and _rewarded_policy_ok() and not gameplay_active \
		and rewarded_state == RewardedState.READY


## Starts a rewarded ad. Returns false (and nothing happens) if not allowed.
func show_rewarded(kind: String, context: String) -> bool:
	if not can_offer_rewarded():
		return false
	_token_counter += 1
	_show_token = "show-%d" % _token_counter
	_granted_this_show = false
	_pending = {"kind": kind, "context": context}
	rewarded_state = RewardedState.SHOWING
	rewarded_state_changed.emit()
	AnalyticsService.count("rewarded_opt_in")
	provider.show_rewarded()
	return true


func _on_rewarded_loaded() -> void:
	rewarded_state = RewardedState.READY
	last_error = ""
	rewarded_state_changed.emit()


func _on_rewarded_failed(error: String) -> void:
	last_error = error
	rewarded_state = RewardedState.IDLE
	rewarded_state_changed.emit()


func _on_rewarded_show_failed(error: String) -> void:
	last_error = error
	_pending = {}
	rewarded_state = RewardedState.IDLE
	rewarded_state_changed.emit()
	rewarded_finished.emit(false)


func _on_reward_earned(reward_id: String) -> void:
	# Only while an ad we started is showing, once per show and per reward id.
	if rewarded_state != RewardedState.SHOWING or _pending.is_empty() or _granted_this_show:
		return
	var granted: Array = SaveService.data.ads.granted_rewards
	var key := reward_id if reward_id != "" else _show_token
	if key in granted:
		return
	_granted_this_show = true
	granted.append(key)
	while granted.size() > 50:
		granted.pop_front()
	if _pending.kind == "hint":
		var hints: Dictionary = SaveService.data.ads.bonus_hints
		hints[_pending.context] = int(hints.get(_pending.context, 0)) + 1
	SaveService.save_data()
	AnalyticsService.count("rewarded_completed")
	reward_granted.emit(_pending.kind, _pending.context)


func _on_rewarded_dismissed() -> void:
	var granted := _granted_this_show
	_pending = {}
	rewarded_state = RewardedState.IDLE
	rewarded_state_changed.emit()
	rewarded_finished.emit(granted)
	preload_rewarded()


func bonus_hints(level_id: String) -> int:
	return int(SaveService.data.ads.bonus_hints.get(level_id, 0))


# ---- Interstitials (natural breaks only) ------------------------------------

func interstitial_allowed(completed_level_number: int, now_unix: int) -> bool:
	var c: Dictionary = ConsentService.config
	if ConsentService.is_child_safe() or not bool(c.get("interstitial_enabled", false)):
		return false
	if gameplay_active or not _initialized or not ConsentService.can_request_ads():
		return false
	if completed_level_number < int(c.interstitial_first_after_level):
		return false
	var a: Dictionary = SaveService.data.ads
	if int(a.levels_since_interstitial) < int(c.interstitial_min_levels_between):
		return false
	return now_unix - int(a.last_interstitial_unix) >= int(c.interstitial_min_seconds_between)


## Call after a level is completed, at the moment the player leaves results.
func on_level_break(completed_level_number: int) -> bool:
	var a: Dictionary = SaveService.data.ads
	a.levels_since_interstitial = int(a.levels_since_interstitial) + 1
	var now := int(Time.get_unix_time_from_system())
	if not interstitial_allowed(completed_level_number, now):
		SaveService.save_data()
		return false
	a.levels_since_interstitial = 0
	a.last_interstitial_unix = now
	SaveService.save_data()
	AnalyticsService.count("interstitial_shown")
	provider.show_interstitial()
	return true
