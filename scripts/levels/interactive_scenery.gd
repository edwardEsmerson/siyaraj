extends Sprite2D
## Optional lash reactions on existing art. No body collision or interaction input.

signal reacted

const SCENERY_MASK: int = 32
const FEEDBACK_TIME: float = 0.65

@export var bell: bool = true
@export var hit_center: Vector2 = Vector2(21, 27)
@export var hit_size: Vector2 = Vector2(26, 30)
@export var cooldown: float = 0.8

var _cooldown_remaining: float = 0.0
var _feedback_remaining: float = 0.0
var _rest_offset: Vector2


func _ready() -> void:
	_rest_offset = offset
	add_to_group("interactive_scenery")
	var sensor := Area2D.new()
	sensor.name = "LashTarget"
	sensor.collision_layer = SCENERY_MASK
	sensor.collision_mask = 0
	sensor.monitoring = false
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = hit_size
	collider.shape = shape
	collider.position = hit_center
	sensor.add_child(collider)
	add_child(sensor)


func on_scenery_hit(direction: int) -> void:
	if _cooldown_remaining > 0.0 or not is_visible_in_tree():
		return
	_cooldown_remaining = cooldown
	_feedback_remaining = FEEDBACK_TIME
	# Reuse the clean high chime for bells and the short dull impact for pottery.
	get_node("/root/AudioDirector").play_sfx(&"ui" if bell else &"hit", global_position)
	offset.x = _rest_offset.x + 4.0 * direction
	queue_redraw()
	reacted.emit()


func _physics_process(delta: float) -> void:
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
	if _feedback_remaining <= 0.0:
		return
	_feedback_remaining = maxf(0.0, _feedback_remaining - delta)
	var progress := 1.0 - _feedback_remaining / FEEDBACK_TIME
	offset.x = _rest_offset.x + sin(progress * TAU * 3.0) * 4.0 * (1.0 - progress)
	queue_redraw()


func _draw() -> void:
	if _feedback_remaining <= 0.0:
		return
	var progress := 1.0 - _feedback_remaining / FEEDBACK_TIME
	var color := Color(1.0, 0.85, 0.4, 1.0 - progress)
	var radius := 18.0 + 24.0 * progress
	if bell:
		draw_arc(hit_center, radius, -0.7, 0.7, 12, color, 3.0)
		draw_arc(hit_center, radius, PI - 0.7, PI + 0.7, 12, color, 3.0)
	else:
		draw_arc(hit_center, radius, PI + 0.3, TAU - 0.3, 16, color, 3.0)
