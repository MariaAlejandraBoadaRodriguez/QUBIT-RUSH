extends ScreenBase
## Learn: short explanations of the gates and ideas met so far, with an
## optional "Learn more" drawer for curious adults.

const CONCEPTS := [
	["Qubit", "A qubit can be measured as 0 or 1.", "Before measurement a qubit is described by two amplitudes, one for |0⟩ and one for |1⟩. Amplitudes are complex numbers; the chance of each result is the squared size of its amplitude."],
	["Probability", "A probability tells you how often a result appears after many runs.", "One measurement gives only one result, so a single run never proves what the state was. Repeating the same circuit many times reveals the probabilities."],
	["Superposition", "The H gate creates two possibilities.", "A superposition is not the same as a coin that is secretly heads or tails. The two amplitudes can interfere: a later gate can make them add up or cancel out."],
	["Phase", "The Z gate changes a phase. The probability may look the same, but the next gate can reveal the difference.", "|+⟩ and |−⟩ both give 0 or 1 half the time, yet they are different states. H turns |+⟩ into |0⟩ and |−⟩ into |1⟩. Changing the whole state by the same phase (a global phase) changes nothing you can measure."],
	["Entanglement", "Two qubits can become linked in a way ordinary bits cannot.", "After H and CNOT, two qubits share the state (|00⟩ + |11⟩)/√2. Each result alone looks random, but the two always agree. Neither qubit has a definite direction on its own, which is why its Bloch arrow shrinks."],
]


func build() -> void:
	header("Learn")
	var col := scroll_column()
	var gates := GameState.unlocked_gates()
	col.add_child(UI.label("Ideas", "SecondaryLabel"))
	for c in CONCEPTS:
		col.add_child(_item(c[0], c[1], c[2]))
	col.add_child(UI.label("Gates you have met", "SecondaryLabel"))
	for g in QGates.ALL:
		if g in gates:
			col.add_child(_item(g + " gate", QGates.DESCRIPTIONS[g], ""))


func _item(title: String, short: String, more: String) -> PanelContainer:
	var card := UI.card()
	var v := UI.vbox(4)
	card.add_child(v)
	v.add_child(UI.label(title, "HeadingLabel"))
	v.add_child(UI.label(short))
	if more != "":
		var b := UI.button("Learn more", "FlatButton")
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.pressed.connect(func(): Sheet.open(self, title, more))
		v.add_child(b)
	return card
