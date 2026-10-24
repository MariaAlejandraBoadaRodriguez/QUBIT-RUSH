extends Node
## Privacy/consent decisions that gate ad loading.
##
## Audience policy (see docs/COMPLIANCE.md): until the owner records a Play
## Console target-audience decision, the app runs the stricter "child_safe"
## configuration: child-directed + under-age-of-consent tags, G-rated ads only,
## no personalisation, no interstitials. Gameplay never waits for consent.

signal consent_changed
signal dialog_state_changed(open: bool)

const CONFIG_PATH := "res://data/config/ads_config.json"
## Written by the export plugin only for release builds with owner-supplied
## production AdMob IDs. Never present in source control.
const RELEASE_OVERRIDE_PATH := "res://data/config/ads_release.json"

var config := {}
var dialog_open := false


func _ready() -> void:
	config = load_config()
	if FileAccess.file_exists(RELEASE_OVERRIDE_PATH):
		config = apply_override(config, RELEASE_OVERRIDE_PATH)


static func apply_override(base: Dictionary, path: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return base
	var out := base.duplicate(true)
	var o: Dictionary = json.data
	if typeof(o.get("android", null)) == TYPE_DICTIONARY:
		for k in o.android:
			if str(o.android[k]) != "":
				out.android[k] = str(o.android[k])
	if o.has("test_mode"):
		out.test_mode = bool(o.test_mode)
	if o.get("audience_policy", "") == "general":
		out.audience_policy = "general"
	return out


static func load_config(path := CONFIG_PATH) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var d := {}
	if text != "" and json.parse(text) == OK and typeof(json.data) == TYPE_DICTIONARY:
		d = json.data
	# Safe defaults if anything is missing or the file is malformed.
	var defaults := {
		"ads_enabled": false, "test_mode": true, "audience_policy": "child_safe",
		"rewarded_enabled": false, "interstitial_enabled": false,
		"interstitial_first_after_level": 6, "interstitial_min_levels_between": 4,
		"interstitial_min_seconds_between": 600, "max_ad_content_rating": "G", "android": {},
	}
	for k in defaults:
		if not d.has(k) or typeof(d[k]) != typeof(defaults[k]):
			d[k] = defaults[k]
	if d.audience_policy != "general":
		d.audience_policy = "child_safe"
	return d


func is_child_safe() -> bool:
	return config.get("audience_policy", "child_safe") != "general"


func ads_choice() -> String:
	return str(SaveService.data.consent.get("ads_choice", "unset"))


func ump_status() -> String:
	return str(SaveService.data.consent.get("ump_status", "unknown"))


## The player's in-app choice: "allowed" or "declined" optional ads.
func set_ads_choice(choice: String) -> void:
	if not choice in ["allowed", "declined", "unset"]:
		return
	SaveService.data.consent.ads_choice = choice
	SaveService.save_data()
	consent_changed.emit()


## Result of Google UMP (or "not_required" on platforms without the plugin).
func set_ump_status(status: String) -> void:
	SaveService.data.consent.ump_status = status
	SaveService.save_data()
	consent_changed.emit()


## Whether any ad may be requested right now.
func can_request_ads() -> bool:
	if not bool(config.get("ads_enabled", false)):
		return false
	if ads_choice() != "allowed":
		return false
	return ump_status() in ["obtained", "not_required"]


func set_dialog_open(open: bool) -> void:
	if dialog_open == open:
		return
	dialog_open = open
	dialog_state_changed.emit(open)


## Revokes the in-app choice and resets UMP consent where available.
func revoke() -> void:
	set_ads_choice("declined")
	set_ump_status("unknown")
	if AdsService.android() != null:
		AdsService.android().reset_consent()
