extends CharacterBody2D
## Isolated combat foundation. Player detection and attacks come later.

signal health_changed(remaining: int)
signal died

@export var max_health: int = 3
@export var patrol_speed: float = 60.0
@export var patrol_radius: float = 100.0
@export var gravity: float = 1800.0

var health: int
var _home_x: float
var _direction: int = 1
var _hurt_remaining: float = 0.0

@onready var body: Polygon2D = $Body


func _ready() -> void:
	health = max_health
	_home_x = global_position.x


func _physics_process(delta: float) -> void:
	_hurt_remaining = maxf(_hurt_remaining - delta, 0.0)
	if _hurt_remaining > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	else:
		body.modulate = Color.WHITE
		if global_position.x >= _home_x + patrol_radius:
			_direction = -1
		elif global_position.x <= _home_x - patrol_radius:
			_direction = 1
		velocity.x = _direction * patrol_speed
	velocity.y = minf(velocity.y + gravity * delta, 900.0)
	move_and_slide()
	if is_on_wall():
		_direction *= -1


func take_damage(amount: int, knockback: Vector2) -> void:
	if health <= 0 or amount <= 0:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health)
	if health == 0:
		died.emit()
		queue_free()
		return
	velocity = knockback
	_hurt_remaining = 0.20
	body.modulate = Color(2.0, 2.0, 2.0, 1.0)
