extends Node
## Local-only counters (no network, no identifiers, no third-party SDK).
## Used to surface the business metrics in SPEC §11 on-device only; any real
## reporting must come from consent-aware AdMob reporting, not from this app.

var counters := {}


func count(event: String, amount := 1) -> void:
	counters[event] = int(counters.get(event, 0)) + amount


func get_count(event: String) -> int:
	return int(counters.get(event, 0))


func reset() -> void:
	counters.clear()
