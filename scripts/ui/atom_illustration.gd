class_name AtomIllustration
extends Control
## Subtle line illustration: a Bloch sphere with orbit-like great circles.

var t := 0.0


func _ready() -> void:
	set_process(not bool(SaveService.get_setting("reduced_motion")))


func _process(delta: float) -> void:
	t += delta * 0.25
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.42
	draw_arc(c, r, 0, TAU, 96, AppTheme.SOFT_BLUE, 3.0, true)
	for k in 3:
		var a := t + k * PI / 3.0
		var pts := PackedVector2Array()
		for i in 73:
			var th := TAU * i / 72.0
			var p := Vector2(cos(th) * r, sin(th) * r * 0.32).rotated(a)
			pts.append(c + p)
		draw_polyline(pts, Color(AppTheme.SOFT_BLUE, 0.7), 2.0, true)
	draw_line(c, c + Vector2(r * 0.55, -r * 0.62), AppTheme.PRIMARY, 4.0, true)
	draw_circle(c + Vector2(r * 0.55, -r * 0.62), 8.0, AppTheme.PRIMARY)
	draw_circle(c, 6.0, AppTheme.PRIMARY)
