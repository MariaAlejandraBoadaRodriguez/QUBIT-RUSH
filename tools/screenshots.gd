extends SceneTree
## Renders key screens to PNG for visual review (needs a display, e.g. xvfb-run):
##   xvfb-run -s "-screen 0 720x1440x24" ~/tools/godot --path . --rendering-driver opengl3 \
##     --resolution 720x1440 -s tools/screenshots.gd -- <out_dir>
## Uses a throwaway save file so real progress is untouched.

var out_dir := "res://reports/screenshots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _shot(name: String) -> void:
	# frame_post_draw does not fire reliably from a -s main loop; waiting a
	# few processed frames is enough for the viewport texture to update.
	for i in 8:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)


func _show(screen: String) -> Node:
	for c in root.get_children():
		if c is Control and c.has_method("go_back"):
			c.queue_free()
	await process_frame
	var s: Node = load(root.get_node("GameState").SCREENS[screen]).instantiate()
	root.add_child(s)
	return s


func _run() -> void:
	var save = root.get_node("SaveService")
	var gs = root.get_node("GameState")
	save.load_data("user://screenshot_save.json")
	save.reset_progress()
	save.set_setting("reduced_motion", true)
	save.set_setting("sfx", false)
	gs.capture_navigation = true
	await _show("home")
	await _shot("01_home")
	gs.current_level = gs.levels[0]
	gs.mode = "learn"
	var p = await _show("puzzle")
	await _shot("02_level1")
	p.editor.place_gate("X")
	await _shot("03_level1_x_placed")
	p.run_circuit()
	await _show("results")
	await _shot("04_results")
	for L in gs.levels.slice(0, 31):
		save.record_level(L.id, 3, 1)
	await _show("levels")
	await _shot("05_levels")
	gs.current_level = gs.levels[31]
	p = await _show("puzzle")
	p.editor.place_gate("H")
	p.editor.place_gate("Z")
	p.editor.place_gate("CNOT")
	p.editor.select_op(2)
	await _shot("06_level32_bell")
	gs.current_level = gs.levels[39]
	p = await _show("puzzle")
	for op in gs.levels[39].solution:
		p.editor.ops.append(op)
	p._refresh()
	await _shot("07_level40")
	await _show("challenges")
	await _shot("08_challenges")
	var lab = await _show("practice")
	lab._set_qubits(2)
	lab.editor.place_gate("H")
	lab._measure()
	await _shot("09_practice")
	await _show("settings")
	await _shot("10_settings")
	await _show("consent")
	await _shot("11_consent")
	await _show("learn")
	await _shot("12_learn")
	save.reset_progress()
	quit(0)
