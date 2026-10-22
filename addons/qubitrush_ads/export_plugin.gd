@tool
extends EditorPlugin
## Registers the Android export plugin for QubitRushAds.

var _export: AndroidExportPlugin


func _enter_tree() -> void:
	_export = AndroidExportPlugin.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class AndroidExportPlugin extends EditorExportPlugin:
	## Debug exports always use Google's public TEST app ID.
	## Release exports include the ads SDK only when the owner supplies a real
	## AdMob configuration through environment variables at build time:
	##   QUBITRUSH_ADMOB_APP_ID, QUBITRUSH_ADMOB_REWARDED_UNIT,
	##   QUBITRUSH_ADMOB_INTERSTITIAL_UNIT (optional),
	##   QUBITRUSH_AUDIENCE_POLICY ("child_safe" default, or "general").
	## Without them, a release build ships with no ads SDK at all.
	const TEST_APP_ID := "ca-app-pub-3940256099942544~3347511713"
	const ADS_VERSION := "25.5.0"
	const UMP_VERSION := "4.0.0"

	var _debug := true

	func _get_name() -> String:
		return "QubitRushAds"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _ads_included() -> bool:
		return _debug or OS.get_environment("QUBITRUSH_ADMOB_APP_ID") != ""

	func _export_begin(_features: PackedStringArray, is_debug: bool, _path: String, _flags: int) -> void:
		_debug = is_debug
		if is_debug or not _ads_included():
			return
		# Release with owner-supplied IDs: ship a config override with production units.
		var cfg := {
			"test_mode": false,
			"audience_policy": OS.get_environment("QUBITRUSH_AUDIENCE_POLICY") if OS.get_environment("QUBITRUSH_AUDIENCE_POLICY") != "" else "child_safe",
			"android": {
				"app_id": OS.get_environment("QUBITRUSH_ADMOB_APP_ID"),
				"rewarded_unit": OS.get_environment("QUBITRUSH_ADMOB_REWARDED_UNIT"),
				"interstitial_unit": OS.get_environment("QUBITRUSH_ADMOB_INTERSTITIAL_UNIT"),
			},
		}
		add_file("res://data/config/ads_release.json", JSON.stringify(cfg).to_utf8_buffer(), false)

	func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		_debug = debug
		if not _ads_included():
			return PackedStringArray()
		return PackedStringArray(["res://addons/qubitrush_ads/bin/qubitrush-ads-%s.aar" % ("debug" if debug else "release")])

	func _get_android_dependencies(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		_debug = debug
		if not _ads_included():
			return PackedStringArray()
		return PackedStringArray([
			"com.google.android.gms:play-services-ads:" + ADS_VERSION,
			"com.google.android.ump:user-messaging-platform:" + UMP_VERSION,
		])

	func _child_safe() -> bool:
		return _debug or OS.get_environment("QUBITRUSH_AUDIENCE_POLICY") != "general"

	## Child-directed apps must not declare the advertising ID permission
	## (Google Play Families policy), so the SDK's merged entries are removed.
	func _get_android_manifest_element_contents(_platform: EditorExportPlatform, debug: bool) -> String:
		_debug = debug
		if not _ads_included() or not _child_safe():
			return ""
		var out := ""
		for perm in ["com.google.android.gms.permission.AD_ID", "android.permission.ACCESS_ADSERVICES_AD_ID",
				"android.permission.ACCESS_ADSERVICES_ATTRIBUTION", "android.permission.ACCESS_ADSERVICES_TOPICS"]:
			out += '<uses-permission android:name="%s" tools:node="remove"/>\n' % perm
		return out

	func _get_android_manifest_application_element_contents(_platform: EditorExportPlatform, debug: bool) -> String:
		_debug = debug
		if not _ads_included():
			return ""
		var app_id := TEST_APP_ID if debug else OS.get_environment("QUBITRUSH_ADMOB_APP_ID")
		return '<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="%s"/>\n' % app_id
