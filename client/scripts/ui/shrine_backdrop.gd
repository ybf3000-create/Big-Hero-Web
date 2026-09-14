extends Control

const SKY := Color("f6d6d6")
const HILL_FAR := Color("dbc9df")
const HILL_NEAR := Color("b9a9bf")
const GROUND := Color("8799a9")
const SUN := Color(1.0, 0.98, 0.95, 0.72)
const CLOUD := Color(1.0, 0.98, 0.97, 0.78)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SKY)
	draw_circle(Vector2(size.x * 0.88, size.y * 0.22), 54.0, SUN)
	draw_circle(Vector2(size.x * 0.88, size.y * 0.22), 72.0, Color(1, 1, 1, 0.10))

	_draw_cloud(Vector2(size.x * 0.13, size.y * 0.24), 1.0)
	_draw_cloud(Vector2(size.x * 0.72, size.y * 0.42), 0.62)

	var far_hills := PackedVector2Array([
		Vector2(0, size.y * 0.72), Vector2(size.x * 0.15, size.y * 0.42),
		Vector2(size.x * 0.28, size.y * 0.68), Vector2(size.x * 0.43, size.y * 0.34),
		Vector2(size.x * 0.59, size.y * 0.67), Vector2(size.x * 0.76, size.y * 0.40),
		Vector2(size.x, size.y * 0.69), Vector2(size.x, size.y), Vector2(0, size.y),
	])
	draw_colored_polygon(far_hills, HILL_FAR)

	var near_hills := PackedVector2Array([
		Vector2(0, size.y * 0.82), Vector2(size.x * 0.19, size.y * 0.60),
		Vector2(size.x * 0.38, size.y * 0.78), Vector2(size.x * 0.58, size.y * 0.55),
		Vector2(size.x * 0.79, size.y * 0.76), Vector2(size.x, size.y * 0.59),
		Vector2(size.x, size.y), Vector2(0, size.y),
	])
	draw_colored_polygon(near_hills, HILL_NEAR)
	draw_rect(Rect2(0, size.y * 0.78, size.x, size.y * 0.22), GROUND)


func _draw_cloud(center: Vector2, scale_factor: float) -> void:
	draw_circle(center, 32.0 * scale_factor, CLOUD)
	draw_circle(center + Vector2(34, 5) * scale_factor, 24.0 * scale_factor, CLOUD)
	draw_circle(center - Vector2(34, 8) * scale_factor, 20.0 * scale_factor, CLOUD)
	draw_rect(Rect2(center - Vector2(55, 2) * scale_factor, Vector2(110, 25) * scale_factor), CLOUD)
