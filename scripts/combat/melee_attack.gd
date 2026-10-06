extends Node2D
## Shared timed melee swing. Movement remains owned by the character controller.
const Burst = preload("res://scripts/effects/burst.gd")

@export var target_mask: int = 4
@export var damage: int = 1
@export var windup_time: float = 0.08
@export var active_time: float = 0.10
@export var recovery_time: float = 0.18
@export var reach: float = 34.0
@export var hitbox_size: Vector2 = Vector2(48, 36)
@export var knockback: Vector2 = Vector2(180, -140)
@export var swing_color: Color = Color(1.0, 0.65, 0.15)

enum Phase { IDLE, WINDUP, ACTIVE, RECOVERY }
var phase: Phase = Phase.IDLE
var direction: int = 1
var _remaining: float = 0.0
var _hit_targets: Dictionary = {}
var _shape := RectangleShape2D.new()


func start(facing: int) -> bool:
	if is_busy():
		return false
	direction = facing
	_hit_targets.clear()
	phase = Phase.WINDUP
	_remaining = windup_time
	get_node("/root/AudioDirector").play_sfx(&"lash" if target_mask == 4 else &"tell", global_position)
	queue_redraw()
	return true


func is_busy() -> bool:
	return phase != Phase.IDLE


func cancel() -> void:
	phase = Phase.IDLE
	_hit_targets.clear()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not is_busy():
		return
	_remaining -= delta
	if _remaining <= 0.0:
		match phase:
			Phase.WINDUP:
				phase = Phase.ACTIVE
				_remaining += active_time
			Phase.ACTIVE:
				phase = Phase.RECOVERY
				_remaining += recovery_time
			Phase.RECOVERY:
				cancel()
		queue_redraw()
	if phase == Phase.ACTIVE:
		_hit_overlaps()
	queue_redraw()


func _hit_overlaps() -> void:
	_shape.size = hitbox_size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape
	query.transform = Transform2D(0.0, global_position + Vector2(reach * direction, 0))
	query.collision_mask = target_mask
	query.exclude = [get_parent().get_rid()]
	for result in get_world_2d().direct_space_state.intersect_shape(query):
		var target: Node = result.collider
		var id := target.get_instance_id()
		if _hit_targets.has(id) or not target.has_method("take_damage"):
			continue
		_hit_targets[id] = true
		var health_before: int = target.health
		var impact_at: Vector2 = target.global_position + Vector2(0, -20)
		target.take_damage(damage, Vector2(knockback.x * direction, knockback.y))
		if target.health < health_before:
			Burst.spawn(get_tree().current_scene, impact_at, swing_color, "ZAP!" if target_mask == 4 else "HIT!")


func _draw() -> void:
	if not is_busy():
		return
	var color := swing_color
	var forward := Vector2(float(direction), 0)
	match phase:
		Phase.WINDUP:
			color.a = 0.6
			draw_line(Vector2.ZERO, forward * 24 + Vector2(0, -12), color, 2.0)
			draw_circle(forward * 24 + Vector2(0, -12), 3.0, color)
		Phase.ACTIVE:
			var progress := clampf(1.0 - _remaining / active_time, 0.0, 1.0)
			var angle := lerpf(-0.65, 0.65, progress)
			var tip := Vector2(cos(angle) * (reach + hitbox_size.x * 0.5) * direction, sin(angle) * 28)
			# The bright arc spans the same forward region as the damage query.
			var start_angle := -0.65 if direction == 1 else PI - 0.65
			draw_arc(Vector2.ZERO, reach + 10, start_angle, start_angle + 1.3, 18, color, 5.0)
			draw_line(Vector2.ZERO, tip, Color.WHITE, 2.0)
			for index in range(5):
				var spark_at := tip + Vector2(cos(index * 1.7 + progress * 4), sin(index * 1.7 + progress * 4)) * 7
				draw_circle(spark_at, 2.0, color)
		Phase.RECOVERY:
			color.a = 0.2 * clampf(_remaining / recovery_time, 0.0, 1.0)
			draw_line(Vector2.ZERO, forward * 25 + Vector2(0, 10), color, 2.0)
