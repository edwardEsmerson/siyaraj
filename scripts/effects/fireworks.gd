extends Node2D
## Code-drawn fireworks for menus and celebrations: rockets rise from `launch_y`
## and burst into square sparks in the festival palette. Purely visual.

const COLORS: Array[Color] = [Color("ffb026"), Color("ff3e8a"), Color("3fd0c9"), Color("fff1d6")]
const GRAVITY: float = 70.0

@export var width: float = 960.0
@export var launch_y: float = 430.0
## Burst height range, as y positions.
@export var burst_y: Vector2 = Vector2(50.0, 210.0)
## Seconds between launches.
@export var interval: Vector2 = Vector2(0.45, 1.1)

var _rockets: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _wait: float = 0.2
var _rng := RandomNumberGenerator.new()


func _process(delta: float) -> void:
	_wait -= delta
	if _wait <= 0.0:
		launch()
		_wait = _rng.randf_range(interval.x, interval.y)
	for rocket in _rockets:
		rocket.pos += rocket.vel * delta
	for rocket in _rockets.filter(func(r: Dictionary) -> bool: return r.pos.y <= r.top):
		_burst(rocket.pos, rocket.color)
	_rockets = _rockets.filter(func(r: Dictionary) -> bool: return r.pos.y > r.top)
	var drag := pow(0.25, delta)
	for spark in _sparks:
		spark.vel = spark.vel * drag + Vector2(0, GRAVITY * delta)
		spark.pos += spark.vel * delta
		spark.age += delta
	_sparks = _sparks.filter(func(s: Dictionary) -> bool: return s.age < s.life)
	for flash in _flashes:
		flash.age += delta
	_flashes = _flashes.filter(func(f: Dictionary) -> bool: return f.age < 0.15)
	queue_redraw()


func launch() -> void:
	var x := _rng.randf_range(width * 0.08, width * 0.92)
	_rockets.append({
		"pos": Vector2(x, launch_y),
		"vel": Vector2(_rng.randf_range(-20, 20), -_rng.randf_range(240, 300)),
		"top": _rng.randf_range(burst_y.x, burst_y.y),
		"color": COLORS.pick_random(),
	})


func _burst(at: Vector2, color: Color) -> void:
	_flashes.append({"pos": at, "age": 0.0})
	var count := _rng.randi_range(36, 52)
	var speed := _rng.randf_range(130, 190)
	var accent: Color = COLORS.pick_random()
	for index in count:
		var direction := Vector2.RIGHT.rotated(TAU * index / count + _rng.randf() * 0.15)
		_sparks.append({
			"pos": at,
			"vel": direction * speed * _rng.randf_range(0.75, 1.05),
			"age": 0.0,
			"life": _rng.randf_range(1.2, 1.8),
			"color": accent if index % 4 == 0 else color,
		})


func _draw() -> void:
	for rocket in _rockets:
		var head: Vector2 = rocket.pos.round()
		draw_rect(Rect2(head, Vector2(2, 2)), COLORS[3])
		for step in range(1, 4):
			var tail: Vector2 = (rocket.pos - rocket.vel * 0.025 * step).round()
			draw_rect(Rect2(tail, Vector2(1, 2)), Color(rocket.color, 0.8 - step * 0.2))
	for flash in _flashes:
		draw_circle(flash.pos.round(), 12.0 * (1.0 - flash.age / 0.15) + 4.0, Color(COLORS[3], 0.8))
	for spark in _sparks:
		var life: float = spark.age / spark.life
		# Full brightness for most of the life, then twinkle out.
		var fade: float = clampf((1.0 - life) * 2.5, 0.0, 1.0)
		if life > 0.7 and _rng.randf() < 0.35:
			continue
		var at: Vector2 = spark.pos.round()
		var tint: Color = COLORS[3] if life < 0.12 else spark.color
		draw_rect(Rect2(at - Vector2(1, 1), Vector2(3, 3)), Color(tint, fade))
		draw_rect(Rect2((spark.pos - spark.vel * 0.05).round(), Vector2(2, 2)), Color(spark.color, fade * 0.6))
		draw_rect(Rect2((spark.pos - spark.vel * 0.1).round(), Vector2(1, 1)), Color(spark.color, fade * 0.3))
