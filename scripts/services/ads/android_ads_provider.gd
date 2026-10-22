class_name AndroidAdsProvider
extends AdsProvider
## Bridge to the QubitRushAds Android plugin (android/plugins/qubitrush-ads),
## which wraps the official Google Mobile Ads SDK and Google UMP.

const SINGLETON := "QubitRushAds"

var _plugin: Object = null


func _init() -> void:
	name = "android"
	if Engine.has_singleton(SINGLETON):
		_plugin = Engine.get_singleton(SINGLETON)
		_plugin.connect("initialized", func(ok): initialized.emit(ok))
		_plugin.connect("rewarded_loaded", func(): rewarded_loaded.emit())
		_plugin.connect("rewarded_failed_to_load", func(e): rewarded_failed_to_load.emit(str(e)))
		_plugin.connect("rewarded_shown", func(): rewarded_shown.emit())
		_plugin.connect("rewarded_failed_to_show", func(e): rewarded_failed_to_show.emit(str(e)))
		_plugin.connect("reward_earned", func(id): reward_earned.emit(str(id)))
		_plugin.connect("rewarded_dismissed", func(): rewarded_dismissed.emit())
		_plugin.connect("interstitial_loaded", func(): interstitial_loaded.emit())
		_plugin.connect("interstitial_failed_to_load", func(e): interstitial_failed_to_load.emit(str(e)))
		_plugin.connect("interstitial_dismissed", func(): interstitial_dismissed.emit())


static func plugin_present() -> bool:
	return Engine.has_singleton(SINGLETON)


func is_available() -> bool:
	return _plugin != null


func initialize(config: Dictionary, child_safe: bool) -> void:
	if _plugin == null:
		initialized.emit(false)
		return
	_plugin.call("initialize", bool(config.get("test_mode", true)), child_safe,
		str(config.get("max_ad_content_rating", "G")))


func load_rewarded(unit_id: String) -> void:
	if _plugin == null:
		rewarded_failed_to_load.emit("unavailable")
		return
	_plugin.call("loadRewarded", unit_id)


func show_rewarded() -> void:
	if _plugin == null:
		rewarded_failed_to_show.emit("unavailable")
		return
	_plugin.call("showRewarded")


func load_interstitial(unit_id: String) -> void:
	if _plugin == null:
		interstitial_failed_to_load.emit("unavailable")
		return
	_plugin.call("loadInterstitial", unit_id)


func show_interstitial() -> void:
	if _plugin == null:
		interstitial_dismissed.emit()
		return
	_plugin.call("showInterstitial")


## UMP consent: requests consent info; plugin emits consent_status(status, can_request_ads).
func request_consent(under_age: bool) -> void:
	if _plugin != null:
		_plugin.call("requestConsent", under_age)


func show_privacy_options() -> void:
	if _plugin != null:
		_plugin.call("showPrivacyOptionsForm")


func reset_consent() -> void:
	if _plugin != null:
		_plugin.call("resetConsent")


func plugin() -> Object:
	return _plugin
