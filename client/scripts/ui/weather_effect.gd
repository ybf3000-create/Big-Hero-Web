class_name WeatherEffect
extends Control

const BASE_STRENGTH := 0.72

var weather: String = "sunny"
var density_scale: float = 1.0
var _time := 0.0
var _particles: Array[Dictionary] = []
var _clouds: Array[Dictionary] = []
var _next_lightning := 0.65
var _lightning_elapsed := 1.0
var _lightning_x := 0.62
var _lightning_top := 0.05
var _next_aurora_flare := 0.35
var _aurora_flare_elapsed := 3.0
var _aurora_flare_x := 0.5


func setup(weather_id: String, low_density: bool = false) -> void:
	weather = weather_id
	density_scale = 0.72 * (0.75 if low_density else 1.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_reseed()
	queue_redraw()


func set_weather(weather_id: String) -> void:
	if weather == weather_id:
		return
	weather = weather_id
	_time = 0.0
	_reseed()
	queue_redraw()


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	if weather == "thunderstorm":
		_next_lightning -= delta
		_lightning_elapsed += delta
		if _next_lightning <= 0.0:
			_lightning_elapsed = 0.0
			_lightning_x = randf_range(0.18, 0.82)
			_lightning_top = randf_range(0.04, 0.18)
			_next_lightning = randf_range(2.4, 6.0)
	if weather == "aurora":
		_next_aurora_flare -= delta
		_aurora_flare_elapsed += delta
		if _next_aurora_flare <= 0.0:
			_aurora_flare_elapsed = 0.0
			_aurora_flare_x = randf_range(0.2, 0.8)
			_next_aurora_flare = 5.2
	queue_redraw()


func _reseed() -> void:
	_particles.clear()
	_clouds.clear()
	for _index in range(_particle_count()):
		_particles.append({
			"x": randf(), "y": randf(), "speed": randf_range(0.72, 1.35),
			"size": randf_range(1.0, 4.0), "phase": randf_range(0.0, TAU),
			"length": randf_range(8.0, 20.0),
		})
	for index in range(9):
		_clouds.append({
			"x": randf_range(-0.15, 1.0), "y": randf_range(0.08, 0.74),
			"width": randf_range(170.0, 430.0), "height": randf_range(70.0, 195.0),
			"speed": randf_range(0.016, 0.032), "phase": randf(), "index": index,
		})
	_next_lightning = 0.65
	_lightning_elapsed = 1.0
	_next_aurora_flare = 0.35
	_aurora_flare_elapsed = 3.0


func _particle_count() -> int:
	var base: int = {
		"thunderstorm": 130, "drizzle": 80, "blizzard": 150,
		"scorching_sun": 90, "sandstorm": 190, "aurora": 45,
	}.get(weather, 0)
	return int(float(base) * density_scale)


func _draw() -> void:
	var view := size
	if view.x <= 0.0 or view.y <= 0.0 or weather == "sunny":
		return
	match weather:
		"thunderstorm": _draw_thunderstorm(view)
		"drizzle": _draw_drizzle(view)
		"fog": _draw_fog(view)
		"blizzard": _draw_blizzard(view)
		"scorching_sun": _draw_scorching_sun(view)
		"sandstorm": _draw_sandstorm(view)
		"aurora": _draw_aurora(view)


func _draw_thunderstorm(view: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.08, 0.16, 0.23, 0.20 * BASE_STRENGTH))
	_draw_rain(view, true)
	if _lightning_elapsed < 0.46:
		_draw_lightning(view, _lightning_elapsed / 0.46)


func _draw_drizzle(view: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.20, 0.36, 0.36, 0.12 * BASE_STRENGTH))
	_draw_rain(view, false)


func _draw_rain(view: Vector2, heavy: bool) -> void:
	var velocity := 480.0 if heavy else 360.0
	var alpha := 0.38 if heavy else 0.29
	for particle in _particles:
		var y := fposmod(float(particle.y) * view.y + _time * velocity * float(particle.speed), view.y + 32.0) - 20.0
		var x := fposmod(float(particle.x) * view.x - y * 0.13, view.x + 18.0) - 9.0
		var length := float(particle.length) * (1.1 if heavy else 0.75)
		draw_line(Vector2(x, y), Vector2(x - length * 0.32, y + length), Color(0.75, 0.90, 0.94, alpha), 1.1)


func _draw_lightning(view: Vector2, progress: float) -> void:
	var opacity := 0.0
	if progress < 0.08:
		opacity = progress / 0.08
	elif progress < 0.22:
		opacity = lerpf(1.0, 0.2, (progress - 0.08) / 0.14)
	elif progress < 0.35:
		opacity = lerpf(0.2, 0.88, (progress - 0.22) / 0.13)
	elif progress < 0.55:
		opacity = lerpf(0.88, 0.05, (progress - 0.35) / 0.20)
	else:
		opacity = lerpf(0.05, 0.0, (progress - 0.55) / 0.45)
	var start := Vector2(view.x * _lightning_x, view.y * _lightning_top)
	var bolt := PackedVector2Array([
		start, start + Vector2(-22, view.y * 0.17), start + Vector2(5, view.y * 0.16),
		start + Vector2(-31, view.y * 0.34), start + Vector2(-8, view.y * 0.25),
	])
	draw_polyline(bolt, Color(0.91, 0.97, 1.0, opacity), 4.0, true)
	draw_polyline(bolt, Color(0.82, 0.94, 1.0, opacity * 0.5), 10.0, true)
	for index in range(5):
		var radius := view.x * (0.08 + index * 0.035)
		draw_circle(start + Vector2(0, view.y * 0.16), radius, Color(0.92, 0.98, 1.0, opacity * (0.10 - index * 0.014)))
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.92, 0.97, 1.0, opacity * 0.22))


func _draw_fog(view: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.84, 0.89, 0.87, 0.10))
	for cloud in _clouds:
		var travel := fposmod(float(cloud.x) + float(cloud.phase) - _time * float(cloud.speed), 1.35) - 0.25
		var center := Vector2(travel * view.x, float(cloud.y) * view.y)
		_draw_fog_cloud(center, float(cloud.width), float(cloud.height), int(cloud.index))


func _draw_fog_cloud(center: Vector2, width: float, height: float, index: int) -> void:
	var cloud_alpha := (0.26 + float(index % 3) * 0.035) * BASE_STRENGTH
	_draw_soft_ellipse(center, Vector2(width * 0.70, height * 0.48), Color(0.91, 0.95, 0.93, cloud_alpha * 0.50))
	_draw_soft_ellipse(center + Vector2(-width * 0.25, height * 0.08), Vector2(width * 0.34, height * 0.42), Color(0.94, 0.97, 0.96, cloud_alpha * 0.82))
	_draw_soft_ellipse(center + Vector2(0, -height * 0.08), Vector2(width * 0.42, height * 0.54), Color(0.92, 0.96, 0.94, cloud_alpha))
	_draw_soft_ellipse(center + Vector2(width * 0.30, height * 0.10), Vector2(width * 0.35, height * 0.40), Color(0.88, 0.93, 0.91, cloud_alpha * 0.78))


func _draw_blizzard(view: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.78, 0.88, 0.91, 0.16 * BASE_STRENGTH))
	for particle in _particles:
		var x := fposmod(float(particle.x) * view.x + _time * 230.0 * float(particle.speed), view.x + 24.0) - 12.0
		var y := fposmod(float(particle.y) * view.y + _time * 85.0 * float(particle.speed), view.y + 24.0) - 12.0
		var radius := float(particle.size)
		draw_circle(Vector2(x, y), radius, Color(0.95, 0.98, 0.97, 0.78 if radius > 2.2 else 0.56))
	for index in range(14):
		var y := fposmod(float(index) * 43.0 + _time * 74.0, view.y + 30.0) - 15.0
		var x := fposmod(float(index) * 113.0 + _time * 295.0, view.x + 70.0) - 35.0
		draw_line(Vector2(x, y), Vector2(x + 45, y + 13), Color(0.94, 0.98, 1.0, 0.24), 2.0)


func _draw_scorching_sun(view: Vector2) -> void:
	_draw_vertical_gradient(
		view, 0.0, 0.32,
		Color(1.0, 0.12, 0.05, 0.30 * BASE_STRENGTH),
		Color(0.94, 0.27, 0.08, 0.13 * BASE_STRENGTH)
	)
	_draw_vertical_gradient(
		view, 0.32, 0.62,
		Color(0.94, 0.27, 0.08, 0.13 * BASE_STRENGTH),
		Color(1.0, 0.52, 0.16, 0.0)
	)
	for index in range(16):
		var x := float(index) / 15.0 * view.x + sin(_time * 2.0 + index) * 4.0
		var y := view.y * 0.20 + fposmod(float(index * 71) - _time * 18.0, view.y * 0.78)
		draw_line(Vector2(x, y), Vector2(x + sin(_time * 2.2 + index) * 8.0, y - 30), Color(1.0, 0.72, 0.40, 0.09), 2.0)
	for particle in _particles:
		var y := fposmod(float(particle.y) * view.y - _time * 34.0 * float(particle.speed), view.y + 18.0)
		var x := float(particle.x) * view.x + sin(_time + float(particle.phase)) * 6.0
		draw_circle(Vector2(x, y), float(particle.size) * 0.62, Color(1.0, 0.65, 0.26, 0.40))


func _draw_sandstorm(view: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.64, 0.42, 0.20, 0.24 * BASE_STRENGTH))
	for band in range(12):
		var y := fposmod(float(band) * 57.0 + _time * 28.0, view.y + 30.0) - 15.0
		draw_line(Vector2(-20, y), Vector2(view.x + 20, y + view.x * 0.14), Color(0.91, 0.72, 0.47, 0.10), 15.0)
	for particle in _particles:
		var x := fposmod(float(particle.x) * view.x + _time * 640.0 * float(particle.speed), view.x + 30.0) - 15.0
		var y := fposmod(float(particle.y) * view.y + sin(_time + float(particle.phase)) * 10.0, view.y)
		var length := float(particle.length)
		draw_line(Vector2(x, y), Vector2(x + length, y + length * 0.10), Color(0.89, 0.69, 0.41, 0.44), maxf(1.0, float(particle.size) * 0.55))


func _draw_aurora(view: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.06, 0.12, 0.23, 0.34))
	for particle in _particles:
		var x := float(particle.x) * view.x
		var y := float(particle.y) * view.y * 0.52
		var pulse := 0.34 + sin(_time * 1.2 + float(particle.phase)) * 0.18
		draw_circle(Vector2(x, y), float(particle.size) * 0.42, Color(0.82, 1.0, 0.94, pulse))
	var colors := [Color(0.31, 0.89, 0.68, 0.22), Color(0.35, 0.61, 1.0, 0.17), Color(0.48, 0.93, 0.77, 0.15)]
	for band in range(3):
		var points := PackedVector2Array()
		for point_index in range(15):
			var x := float(point_index) / 14.0 * view.x
			var y := view.y * (0.10 + band * 0.065) + sin(_time * 0.55 + point_index * 0.54 + band * 1.3) * view.y * 0.07
			points.append(Vector2(x, y))
		draw_polyline(points, colors[band], 30.0 - band * 5.0, true)
	if _aurora_flare_elapsed < 2.0:
		var progress := _aurora_flare_elapsed / 2.0
		var alpha := sin(progress * PI) * 0.58
		var flare_center := Vector2(view.x * _aurora_flare_x, view.y * 0.05)
		for index in range(7):
			_draw_ellipse(flare_center, Vector2(view.x * (0.08 + index * 0.055), view.y * (0.04 + index * 0.028)), Color(0.55, 1.0, 0.83, alpha * (0.18 - index * 0.021)))


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, radii.y / maxf(1.0, radii.x)))
	draw_circle(Vector2.ZERO, radii.x, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_soft_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	for layer in range(7):
		var scale := 1.21 - float(layer) * 0.08
		var layer_color := color
		layer_color.a *= 0.17
		_draw_ellipse(center, radii * scale, layer_color)


func _draw_vertical_gradient(view: Vector2, top_ratio: float, bottom_ratio: float, top_color: Color, bottom_color: Color) -> void:
	var top := view.y * top_ratio
	var bottom := view.y * bottom_ratio
	draw_polygon(
		PackedVector2Array([Vector2(0, top), Vector2(view.x, top), Vector2(view.x, bottom), Vector2(0, bottom)]),
		PackedColorArray([top_color, top_color, bottom_color, bottom_color])
	)
