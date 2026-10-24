class_name MockAdsProvider
extends AdsProvider
## Deterministic provider for tests and desktop runs. Behaviour is scripted
## through public fields so tests can simulate no-fill, errors, dismissal
## without reward, and duplicate reward callbacks.

var fill := true
var init_ok := true
var grant_reward := true
var duplicate_callbacks := 0
var show_error := ""
var shows := 0
var interstitial_shows := 0
var _counter := 0
var _rewarded_ready := false


func _init() -> void:
	name = "mock"


func is_available() -> bool:
	return true


func initialize(_config: Dictionary, _child_safe: bool) -> void:
	initialized.emit(init_ok)


func load_rewarded(_unit_id: String) -> void:
	if fill:
		_rewarded_ready = true
		rewarded_loaded.emit()
	else:
		rewarded_failed_to_load.emit("no_fill")


func show_rewarded() -> void:
	if show_error != "" or not _rewarded_ready:
		rewarded_failed_to_show.emit(show_error if show_error != "" else "not_loaded")
		return
	_rewarded_ready = false
	shows += 1
	rewarded_shown.emit()
	if grant_reward:
		_counter += 1
		var id := "mock-%d" % _counter
		for _i in 1 + duplicate_callbacks:
			reward_earned.emit(id)
	rewarded_dismissed.emit()


func load_interstitial(_unit_id: String) -> void:
	if fill:
		interstitial_loaded.emit()
	else:
		interstitial_failed_to_load.emit("no_fill")


func show_interstitial() -> void:
	interstitial_shows += 1
	interstitial_dismissed.emit()
