extends Node2D
## Low ground wave released by a boss slam. Jump over it; it stops at walls.
const Burst = preload("res://scripts/effects/burst.gd")

@export var direction: int = 1
@export var speed: float = 380.0
@export var lifetime: float = 1.0
## Kept low so an ordinary jump clears it.
@export var size: Vector2 = Vector2(28, 16)
@export var damage: int = 1
@export var knockback: Vector2 = Vector2(200, -240)
@export var target_mask: int = 2
@export var world_mask: int = 1

const WAVE_COLOR := Color(1.0, 0.55, 0.25)

var age: float = 0.0
var _hit_targets: Dictionary = {}


func _ready() -> void:
	direction = 1 if direction >= 0 else -1
	z_index = 4
	add_to_group("boss_hazards")


func _physics_process(delta: float) -> void:
	age += delta
	var step := Vector2(direction * speed * delta, 0)
	var space := get_world_2d().direct_space_state
	var ray := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -size.y * 0.5), global_position + Vector2(0, -size.y * 0.5) + step + Vector2(direction * size.x * 0.5, 0), world_mask)
	if not space.intersect_ray(ray).is_empty():
		Burst.spawn(get_tree().current_scene, global_position + Vector2(direction * size.x * 0.5, -8), WAVE_COLOR, "", 14.0)
		queue_free()
		return
	global_position += step
	var shape := RectangleShape2D.new()
	shape.size = size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position + Vector2(0, -size.y * 0.5))
	query.collision_mask = target_mask
	for result in space.intersect_shape(query):
		var target: Node = result.collider
		var id := target.get_instance_id()
		if _hit_targets.has(id) or not target.has_method("take_damage"):
			continue
		_hit_targets[id] = true
		var health_before: int = target.health
		target.take_damage(damage, Vector2(knockback.x * direction, knockback.y))
		if target.health < health_before:
			Burst.spawn(get_tree().current_scene, target.global_position + Vector2(0, -20), WAVE_COLOR, "HIT!")
	if age >= lifetime:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var fade := clampf(1.0 - age / lifetime, 0.25, 1.0)
	var front := direction * size.x * 0.5
	var back := -direction * size.x * 0.5
	var points := PackedVector2Array([Vector2(back, 0), Vector2(back * 0.3, -size.y), Vector2(front, -size.y * 0.35), Vector2(front, 0)])
	draw_colored_polygon(points, Color(WAVE_COLOR, 0.8 * fade))
	draw_polyline(PackedVector2Array([Vector2(back, 0), Vector2(back * 0.3, -size.y), Vector2(front, -size.y * 0.35)]), Color(1, 0.9, 0.7, fade), 2.0)
	for index in range(3):
		var dust := Vector2(back * (1.2 + index * 0.4), -3 - index * 2)
		draw_circle(dust, 3.0 - index * 0.6, Color(0.7, 0.55, 0.4, 0.5 * fade))
