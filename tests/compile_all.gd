extends SceneTree
## Loads every project script and scene with autoloads active; exits 1 if any
## fails to compile. Usage: ~/tools/godot --headless --path . -s tests/compile_all.gd


func _initialize() -> void:
	var files: Array[String] = []
	for root in ["res://scenes", "res://scripts", "res://tests"]:
		_collect(root, files)
	var failed := 0
	for f in files:
		var res = load(f)
		if res == null:
			failed += 1
			print("FAILED: ", f)
	print("Compiled %d files, %d failed" % [files.size(), failed])
	quit(1 if failed > 0 else 0)


func _collect(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for sub in d.get_directories():
		_collect(dir + "/" + sub, out)
	for f in d.get_files():
		if f.ends_with(".gd") or f.ends_with(".tscn"):
			out.append(dir + "/" + f)
