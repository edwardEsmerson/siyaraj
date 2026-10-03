extends CharacterBody2D
## Player movement has one owner. Combat must request knockback through this controller.

@export var movement_settings: PlayerMovementSettings

var facing_direction: int = 1
var _coyote_remaining: float = 0.0
var _jump_buffer_remaining: float = 0.0
var _jump_cut_applied: bool = false

@onready var attack_origin: Marker2D = $AttackOrigin
@onready var facing_marker: Polygon2D = $FacingMarker


func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	var horizontal_rate := movement_settings.acceleration
	if is_zero_approx(direction):
		horizontal_rate = movement_settings.deceleration
	velocity.x = move_toward(velocity.x, direction * movement_settings.run_speed, horizontal_rate * delta)
	if not is_zero_approx(direction):
		facing_direction = 1 if direction > 0.0 else -1
		attack_origin.position.x = 18.0 * facing_direction
		facing_marker.position.x = 7.0 * facing_direction

	_coyote_remaining = maxf(_coyote_remaining - delta, 0.0)
	if is_on_floor() and velocity.y >= 0.0:
		_coyote_remaining = movement_settings.coyote_time

	_jump_buffer_remaining = maxf(_jump_buffer_remaining - delta, 0.0)
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_remaining = movement_settings.jump_buffer_time
	if _jump_buffer_remaining > 0.0 and _coyote_remaining > 0.0:
		_start_jump()

	_apply_jump_release()
	var gravity := movement_settings.rise_gravity if velocity.y < 0.0 else movement_settings.fall_gravity
	velocity.y = minf(velocity.y + gravity * delta, movement_settings.max_fall_speed)
	move_and_slide()

	# A press just before landing launches immediately, without requiring another press.
	if is_on_floor() and _jump_buffer_remaining > 0.0:
		_start_jump()
		_apply_jump_release()


func _start_jump() -> void:
	velocity.y = movement_settings.jump_velocity
	_coyote_remaining = 0.0
	_jump_buffer_remaining = 0.0
	_jump_cut_applied = false


func _apply_jump_release() -> void:
	# Also handles a buffered jump whose key was released before landing.
	if velocity.y < 0.0 and not Input.is_action_pressed("jump") and not _jump_cut_applied:
		velocity.y *= movement_settings.jump_release_multiplier
		_jump_cut_applied = true
