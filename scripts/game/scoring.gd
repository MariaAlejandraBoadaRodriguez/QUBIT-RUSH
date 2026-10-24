class_name Scoring
extends RefCounted
## Stars depend only on correctness and circuit efficiency (never on ads).


static func stars_for(success: bool, player_gates: int, two_star_gates: int, three_star_gates: int) -> int:
	if not success:
		return 0
	if player_gates <= three_star_gates:
		return 3
	if player_gates <= two_star_gates:
		return 2
	return 1


## Rush score: one point per solved challenge plus a bonus for 3-star solutions.
static func rush_points(stars: int) -> int:
	return 0 if stars <= 0 else (1 if stars < 3 else 2)
