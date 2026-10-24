extends ScreenBase
## Practice Lab: free experimentation with unlocked gates, live state view,
## and a seeded "measure many times" demonstration.

var n := 1
var editor: CircuitEditor
var ket: Label
var bars: ProbabilityBars
var bloch: BlochView
var counts_label: Label
var tray: HFlowContainer
var qbuttons := []
var circuit_scroll: ScrollContainer


func build() -> void:
	AdsService.gameplay_active = true
	header("Practice Lab")
	var qrow := UI.hbox(8)
	qrow.add_child(UI.label("Qubits:", "", false))
	for k in [1, 2, 3]:
		var b := UI.button(str(k))
		b.name = "Qubits_%d" % k
		b.pressed.connect(_set_qubits.bind(k))
		qrow.add_child(b)
		qbuttons.append(b)
	content.add_child(qrow)
	var col := scroll_column()
	circuit_scroll = ScrollContainer.new()
	circuit_scroll.name = "CircuitScroll"
	circuit_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(circuit_scroll)
	editor = CircuitEditor.new()
	editor.name = "CircuitEditor"
	circuit_scroll.add_child(editor)
	editor.ops_changed.connect(func(_o): _refresh())
	editor.selection_changed.connect(_refresh)
	tray = HFlowContainer.new()
	tray.add_theme_constant_override("h_separation", int(10 * AppTheme.DP))
	col.add_child(tray)
	var controls := UI.hbox(10)
	for it in [["Undo", func(): editor.undo()], ["Remove", func(): editor.remove_selected()], ["Clear", func(): editor.reset()]]:
		var b := UI.button(it[0])
		b.name = it[0] + "Button"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(it[1])
		controls.add_child(b)
	col.add_child(controls)
	var card := UI.card()
	var v := UI.vbox(6)
	card.add_child(v)
	ket = UI.label("", "HeadingLabel")
	ket.name = "KetLabel"
	v.add_child(ket)
	var row := UI.hbox(8)
	bars = ProbabilityBars.new()
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bars)
	bloch = BlochView.new()
	bloch.custom_minimum_size = Vector2(220, 220)
	row.add_child(bloch)
	v.add_child(row)
	var mb := UI.button("Measure 100 times")
	mb.name = "MeasureButton"
	mb.pressed.connect(_measure)
	v.add_child(mb)
	counts_label = UI.label("", "SecondaryLabel")
	counts_label.name = "CountsLabel"
	v.add_child(counts_label)
	col.add_child(card)
	_set_qubits(1)


func _set_qubits(k: int) -> void:
	n = k
	var gates := GameState.unlocked_gates().filter(func(g): return k > 1 or not QGates.is_controlled(g))
	if gates.is_empty():
		gates = ["X"]
	for i in qbuttons.size():
		qbuttons[i].theme_type_variation = "SelectedButton" if i + 1 == k else ""
	editor.configure(k, "0".repeat(k), [], 10, gates)
	circuit_scroll.custom_minimum_size.y = CircuitEditor.PAD * 2 + CircuitEditor.WIRE_H * k + 24
	for c in tray.get_children():
		c.queue_free()
	for g in gates:
		var b := GateButton.new().setup(g)
		b.tapped.connect(func(gate): editor.place_gate(gate))
		b.described.connect(func(gate): Sheet.open(self, gate + " gate", QGates.DESCRIPTIONS[gate]))
		tray.add_child(b)
	counts_label.text = ""
	_refresh()


func current_state() -> StateVector:
	return QCircuit.create(n, editor.ops).run(StateVector.zero(n))


func _refresh() -> void:
	var s := current_state()
	if s == null:
		return
	ket.text = s.to_ket_string()
	bars.set_values(s.probabilities())
	bloch.set_vector(s.bloch_vector(editor.selected_wire), editor.selected_wire)


func _measure() -> void:
	var s := current_state()
	var counts := QMeasurement.sample_counts(s, 100, int(Time.get_ticks_usec()))
	var parts: Array[String] = []
	for i in counts.size():
		if counts[i] > 0:
			parts.append("|%s⟩ × %d" % [StateVector.index_to_label(i, n), counts[i]])
	counts_label.text = "100 measurements on fresh copies: " + ", ".join(parts) + ". The state itself is unchanged."


func go_back() -> void:
	GameState.goto("challenges")
