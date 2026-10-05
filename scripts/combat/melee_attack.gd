extends Node2D
## Shared timed melee swing. Movement remains owned by the character controller.

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
		target.take_damage(damage, Vector2(knockback.x * direction, knockback.y))


func _draw() -> void:
	if not is_busy():
		return
	var rectangle := Rect2(Vector2(reach * direction, 0) - hitbox_size / 2, hitbox_size)
	var color := swing_color
	color.a = 0.85 if phase == Phase.ACTIVE else 0.25
	if phase == Phase.ACTIVE:
		draw_rect(rectangle, color)
	else:
		draw_rect(rectangle, color, false, 2.0)
	if phase == Phase.ACTIVE:
		draw_line(Vector2.ZERO, Vector2((reach + hitbox_size.x / 2) * direction, -8), Color.WHITE, 3.0)
