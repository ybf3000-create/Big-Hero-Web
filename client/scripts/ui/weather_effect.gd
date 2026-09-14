class_name WeatherEffect
extends Control

var weather: String = "sunny"
var density_scale: float = 1.0
var _time := 0.0
var _particles: Array[Dictionary] = []

func setup(weather_id: String, low_density: bool = false) -> void:
	weather = weather_id
	density_scale = 0.55 if low_density else 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reseed()
	queue_redraw()

func set_weather(weather_id: String) -> void:
	if weather == weather_id:
		return
	weather = weather_id
	_reseed()

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _reseed() -> void:
	_particles.clear()
	var count := int(90.0 * density_scale)
	for i in range(count):
		_particles.append({
			"x": randf(), "y": randf(), "speed": randf_range(0.55, 1.35),
			"size": randf_range(1.2, 3.5), "phase": randf_range(0.0, TAU),
		})

func _draw() -> void:
	var view := size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	match weather:
		"sunny": _draw_sunny(view)
		"drizzle": _draw_rain(view, false)
		"thunderstorm": _draw_rain(view, true)
		"blizzard": _draw_snow(view)
		"fog": _draw_fog(view)
		"scorching_sun": _draw_heat(view)
		"sandstorm": _draw_sand(view)
		"aurora": _draw_aurora(view)

func _draw_sunny(view: Vector2) -> void:
	draw_circle(Vector2(view.x * 0.82, view.y * 0.13), 78.0, Color(1.0, 0.88, 0.48, 0.09))
	for p in _particles.slice(0, int(28.0 * density_scale)):
		var y := fposmod(float(p.y) * view.y - _time * 7.0 * float(p.speed), view.y)
		var x := fposmod(float(p.x) * view.x + sin(_time + float(p.phase)) * 12.0, view.x)
		draw_circle(Vector2(x, y), float(p.size), Color(1.0, 0.89, 0.55, 0.20))

func _draw_rain(view: Vector2, thunder: bool) -> void:
	for p in _particles:
		var y := fposmod(float(p.y) * view.y + _time * 330.0 * float(p.speed), view.y + 35.0) - 20.0
		var x := fposmod(float(p.x) * view.x - y * 0.12, view.x)
		draw_line(Vector2(x, y), Vector2(x - 7.0, y + 23.0), Color(0.58, 0.78, 0.91, 0.34), 1.2)
	for i in range(9):
		var gx := fposmod(float(i) * 151.0 + _time * 42.0, view.x)
		draw_line(Vector2(gx, view.y - 22.0), Vector2(gx + 26.0, view.y - 22.0), Color(0.72, 0.90, 0.96, 0.18), 2.0)
	if thunder:
		var pulse := sin(_time * 0.73) * sin(_time * 2.17)
		if pulse > 0.91:
			draw_rect(Rect2(Vector2.ZERO, view), Color(0.88, 0.93, 1.0, (pulse - 0.91) * 2.8))
			var bx := view.x * 0.78
			var bolt := PackedVector2Array([Vector2(bx, 10), Vector2(bx - 22, 75), Vector2(bx + 5, 72), Vector2(bx - 30, 145)])
			draw_polyline(bolt, Color(0.94, 0.97, 1.0, 0.75), 3.0)

func _draw_snow(view: Vector2) -> void:
	for p in _particles:
		var y := fposmod(float(p.y) * view.y + _time * 46.0 * float(p.speed), view.y + 14.0) - 8.0
		var x := fposmod(float(p.x) * view.x + sin(_time * float(p.speed) + float(p.phase)) * 24.0, view.x)
		var radius := float(p.size) * (1.45 if float(p.speed) > 1.0 else 0.8)
		draw_circle(Vector2(x, y), radius, Color(0.95, 0.98, 1.0, 0.62 if radius > 2.0 else 0.38))
	draw_rect(Rect2(0, view.y - 14, view.x, 14), Color(0.83, 0.93, 1.0, 0.15))

func _draw_fog(view: Vector2) -> void:
	for i in range(5):
		var y := view.y * (0.18 + i * 0.16)
		var offset := sin(_time * 0.14 + i) * 45.0
		draw_rect(Rect2(-60 + offset, y, view.x + 120, 44), Color(0.91, 0.95, 0.94, 0.10))

func _draw_heat(view: Vector2) -> void:
	draw_circle(Vector2(view.x * 0.84, 55), 105, Color(1.0, 0.56, 0.22, 0.12))
	for i in range(12):
		var x := float(i) / 11.0 * view.x
		var y := view.y - 35.0 + sin(_time * 2.0 + i) * 7.0
		draw_line(Vector2(x, y), Vector2(x + 12, y - 28), Color(1.0, 0.65, 0.35, 0.13), 2.0)

func _draw_sand(view: Vector2) -> void:
	for p in _particles:
		var x := fposmod(float(p.x) * view.x + _time * 180.0 * float(p.speed), view.x + 20.0) - 10.0
		var y := fposmod(float(p.y) * view.y + sin(_time + float(p.phase)) * 14.0, view.y)
		draw_line(Vector2(x, y), Vector2(x + 13, y + 2), Color(0.72, 0.52, 0.26, 0.28), 1.4)

func _draw_aurora(view: Vector2) -> void:
	for i in range(4):
		var points := PackedVector2Array()
		for j in range(9):
			var x := float(j) / 8.0 * view.x
			var y := 55.0 + i * 18.0 + sin(_time * 0.35 + j * 0.8 + i) * 22.0
			points.append(Vector2(x, y))
		draw_polyline(points, [Color(0.35, 0.95, 0.72, 0.22), Color(0.48, 0.72, 1.0, 0.18), Color(0.82, 0.50, 1.0, 0.16), Color(0.42, 0.92, 0.88, 0.15)][i], 13.0)
