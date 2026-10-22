class_name AdsProvider
extends RefCounted
## Provider interface. Implementations emit these signals; AdsService owns all
## policy decisions (gating, frequency caps, reward idempotency).

signal initialized(ok: bool)
signal rewarded_loaded
signal rewarded_failed_to_load(error: String)
signal rewarded_shown
signal rewarded_failed_to_show(error: String)
## `reward_id` must be unique per verified reward callback when available.
signal reward_earned(reward_id: String)
signal rewarded_dismissed
signal interstitial_loaded
signal interstitial_failed_to_load(error: String)
signal interstitial_dismissed

var name := "none"


func is_available() -> bool:
	return false


func initialize(_config: Dictionary, _child_safe: bool) -> void:
	initialized.emit(false)


func load_rewarded(_unit_id: String) -> void:
	rewarded_failed_to_load.emit("unavailable")


func show_rewarded() -> void:
	rewarded_failed_to_show.emit("unavailable")


func load_interstitial(_unit_id: String) -> void:
	interstitial_failed_to_load.emit("unavailable")


func show_interstitial() -> void:
	interstitial_dismissed.emit()
