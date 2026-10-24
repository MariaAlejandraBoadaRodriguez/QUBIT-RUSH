# Level format (schema v1)

One JSON file per level in `data/levels/`, listed in `data/levels/index.json`. Validated by `scripts/game/level_schema.gd` on load; invalid files are skipped and reported, never crash the game.

| Field | Type | Notes |
|---|---|---|
| `schema_version` | int | must be `1` |
| `id` | string | unique, e.g. `"L07"` |
| `number` | int | curriculum order, consecutive from 1 |
| `chapter` | `fundamentals` \| `entanglement` \| `algorithms` | Levels tab |
| `title` | string | |
| `qubits` | 1–3 | |
| `start_state` | string | basis label in wire order, default `"0…0"` |
| `available_gates` | array | subset of `I X Y Z H S T CNOT` |
| `max_slots` | 1–16 | player-placed gates |
| `fixed_gates` | array of ops | locked gates applied before the player's |
| `goal` | object | see below |
| `scoring` | `{two_star_gates, three_star_gates}` | three ≤ two ≤ max_slots; three must equal the optimum |
| `timer_seconds` | int or null | optional per-level timer |
| `tutorial` | `{text, example?, action?}` | one sentence + optional example and action |
| `hints` | array of strings | at least one (free) |
| `why` | string | optional "Why?" panel |
| `success` | string | result headline |
| `new_gate` | string | gate introduced by this level (highlighted) |
| `solution` | array of ops | reference solution, checked by the audit |
| `preview` | bool | default true; false hides live probability preview |

Operation: `{"gate": "H", "target": 0}` or `{"gate": "CNOT", "control": 0, "target": 1}`.

Goals:
- `state_fidelity`: `target` = `{"label": "01"}` or `{"kets": {"00": [re, im], "11": 0.7071}}` (normalised on load). Passes at fidelity ≥ 0.999.
- `measurement_distribution`: `target.probabilities` = `{"0": 0.5, "1": 0.5}` summing to 1. Passes at total variation ≤ 0.01.
- `bell_state`: `target.bell` ∈ `phi_plus, phi_minus, psi_plus, psi_minus` (2 qubits).
- `gate_efficiency`: like `state_fidelity` plus `max_gates` (hard limit).
