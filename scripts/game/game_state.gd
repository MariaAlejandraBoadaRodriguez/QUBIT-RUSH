extends Node
## Session state and navigation. Holds loaded levels and the current context
## (level, mode, last result) passed between screens.

signal screen_changed(path: String)

const SCREENS := {
	"home": "res://scenes/home/home.tscn",
	"levels": "res://scenes/level_select/level_select.tscn",
	"puzzle": "res://scenes/puzzle/puzzle.tscn",
	"results": "res://scenes/results/results.tscn",
	"settings": "res://scenes/settings/settings.tscn",
	"practice": "res://scenes/practice/practice.tscn",
	"consent": "res://scenes/consent/consent.tscn",
	"challenges": "res://scenes/rush/challenges.tscn",
	"learn": "res://scenes/home/learn.tscn",
}

## Modes: "learn" (curriculum), "rush", "daily", "practice".
var mode := "learn"
var levels: Array = []
var load_errors: Array[String] = []
var current_level: LevelData = null
var last_result := {}
var rush := {}
var level_tab := "fundamentals"
var current_screen := ""
## When true (tests), goto() records the destination instead of switching scenes.
var capture_navigation := false
var navigation_log: Array[String] = []


func _ready() -> void:
	reload_levels()


func reload_levels() -> void:
	var res := LevelLoader.load_all()
	levels = res.levels
	load_errors = res.errors
	for e in load_errors:
		push_error("Level load error: " + e)


func level_by_id(id: String) -> LevelData:
	for L in levels:
		if L.id == id:
			return L
	return null


func level_index(L: LevelData) -> int:
	return levels.find(L)


func next_level(L: LevelData) -> LevelData:
	var i := levels.find(L)
	if i < 0 or i + 1 >= levels.size():
		return null
	return levels[i + 1]


## A level is unlocked when it is the first one or the previous one is completed.
func is_unlocked(L: LevelData) -> bool:
	var i := levels.find(L)
	if i <= 0:
		return i == 0
	return SaveService.is_completed(levels[i - 1].id)


## Highest curriculum level number completed (0 if none).
func highest_completed() -> int:
	var best := 0
	for L in levels:
		if SaveService.is_completed(L.id):
			best = maxi(best, L.number)
	return best


## The level "Play" should open: first unlocked, uncompleted level.
func next_unfinished() -> LevelData:
	for L in levels:
		if not SaveService.is_completed(L.id) and is_unlocked(L):
			return L
	return levels[levels.size() - 1] if not levels.is_empty() else null


## Gates the player has met so far (used by Practice Lab).
func unlocked_gates() -> Array:
	var gates := []
	for L in levels:
		if is_unlocked(L):
			for g in L.available_gates:
				if not g in gates:
					gates.append(g)
	return gates


const RUSH_UNLOCK_LEVEL := 10
const DAILY_UNLOCK_LEVEL := 9


func rush_unlocked() -> bool:
	return highest_completed() >= RUSH_UNLOCK_LEVEL


func daily_unlocked() -> bool:
	return highest_completed() >= DAILY_UNLOCK_LEVEL


func start_level(L: LevelData, play_mode := "learn") -> void:
	current_level = L
	mode = play_mode
	goto("puzzle")


func goto(screen: String) -> void:
	var path: String = SCREENS.get(screen, "")
	if path == "":
		push_error("Unknown screen " + screen)
		return
	current_screen = screen
	AdsService.gameplay_active = false
	navigation_log.append(screen)
	if capture_navigation:
		return
	get_tree().call_deferred("change_scene_to_file", path)
	screen_changed.emit(path)
