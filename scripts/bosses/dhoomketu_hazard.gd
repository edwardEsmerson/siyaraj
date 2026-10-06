extends Node2D
## Firework hazards share warnings and swept damage queries. Rocket aim locks
## before launch; chakris roll and bounce; anaar fountains occupy marked lanes.
enum Kind { ANAAR, CHAKRI, ROCKET }
var kind: Kind = Kind.ANAAR
var size: Vector2 = Vector2(48, 110)
var warning_time: float = 0.9
var active_time: float = 1.25
var speed: float = 0.0
var direction: int = 1
var heading: Vector2 = Vector2.RIGHT
var target_position: Vector2
var age: float = 0.0
var bounces_remaining: int = 1
var _hit_targets: Dictionary = {}
const GOLD := Color(1.0, 0.72, 0.18)
const PINK := Color(1.0, 0.3, 0.5)


func _ready() -> void:
	add_to_group("dhoomketu_hazards")
	add_to_group("boss_hazards")
	z_index = 4


func _physics_process(delta: float) -> void:
	age += delta
	if age >= warning_time + active_time:
		queue_free()
		return
	if age > warning_time:
		var active_delta := minf(delta, age - warning_time)
		var step := (heading if kind == Kind.ROCKET else Vector2(direction, 0)) * speed * active_delta
		if kind == Kind.CHAKRI and (position.x + step.x < 50 or position.x + step.x > 910):
			if bounces_remaining <= 0:
				queue_free()
				return
			bounces_remaining -= 1
			direction *= -1
			step.x = direction * speed * active_delta
		if kind == Kind.ROCKET:
			var ray := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -size.y * 0.5), global_position + Vector2(0, -size.y * 0.5) + step, 1)
			if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
				queue_free()
				return
		# Cover each frame's movement, including diagonal rockets.
		var shape := RectangleShape2D.new()
		shape.size = size + step.abs()
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = shape
		query.transform = Transform2D(0.0, global_position + step * 0.5 + Vector2(0, -size.y * 0.5))
		query.collision_mask = 2
		for result in get_world_2d().direct_space_state.intersect_shape(query):
			var target: Node = result.collider
			if not target.has_method("take_damage") or _hit_targets.has(target.get_instance_id()):
				continue
			if target.has_method("is_invulnerable") and target.is_invulnerable():
				continue
			_hit_targets[target.get_instance_id()] = true
			target.take_damage(1, Vector2(signf(step.x) * 180, -140))
			if kind == Kind.ROCKET:
				queue_free()
		global_position += step
	queue_redraw()


func _draw() -> void:
	var warning := age <= warning_time
	var rect := Rect2(Vector2(-size.x * 0.5, -size.y), size)
	var color := PINK if kind == Kind.ROCKET else GOLD
	if warning:
		var progress := clampf(age / warning_time, 0.0, 1.0)
		if kind == Kind.ROCKET:
			var end := target_position - position
			draw_dashed_line(Vector2(0, -size.y * 0.5), end, Color(PINK, 0.7), 2, 10)
			draw_arc(end, 12, 0, TAU, 20, PINK, 2)
		else:
			draw_rect(rect, Color(color, 0.12 + progress * 0.12))
			draw_rect(rect, Color(color, 0.9), false, 2)
			draw_rect(Rect2(-size.x * 0.5, -4, size.x * progress, 4), color)
		if kind == Kind.CHAKRI:
			draw_line(Vector2.ZERO, Vector2(direction * 80, 0), GOLD, 2)
	elif kind == Kind.ANAAR:
		# The gold outline is the damaging footprint; sparks stay inside it.
		draw_rect(rect, Color(GOLD, 0.22))
		for index in range(12):
			var rise := fmod(age * 1.8 + index / 12.0, 1.0)
			var spread := sin(index * 2.4) * size.x * 0.45 * rise
			draw_line(Vector2(spread * 0.8, -size.y * rise + 8), Vector2(spread, -size.y * rise), Color(1, 0.85, 0.35, 1.0 - rise * 0.5), 2)
	elif kind == Kind.CHAKRI:
		var center := Vector2(0, -size.y * 0.5)
		draw_arc(center, size.y * 0.5, age * 18, age * 18 + TAU * 0.85, 20, GOLD, 3)
		for index in range(6):
			var ray := Vector2.from_angle(age * 18 + index * TAU / 6)
			draw_line(center + ray * 4, center + ray * 12, PINK, 2)
	elif kind == Kind.ROCKET:
		var center := Vector2(0, -size.y * 0.5)
		var normal := heading.orthogonal()
		draw_colored_polygon(PackedVector2Array([center + heading * 12, center - heading * 9 + normal * 5, center - heading * 9 - normal * 5]), PINK)
		draw_line(center - heading * 10, center - heading * (20 + 6 * absf(sin(age * 50))), GOLD, 4)
	if kind == Kind.ANAAR:
		draw_colored_polygon(PackedVector2Array([Vector2(-10, 0), Vector2(0, -14), Vector2(10, 0)]), Color(0.65, 0.1, 0.3))
		if warning:
			draw_circle(Vector2(0, -15), 3 + absf(sin(age * 30)), GOLD)
