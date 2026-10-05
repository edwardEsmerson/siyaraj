extends CharacterBody2D
## Player movement has one owner. Combat must request knockback through this controller.

@export var movement_settings: PlayerMovementSettings

signal died

enum State { NORMAL, DASH, HURT, DEAD }

var state: State = State.NORMAL
var dash_available: bool = true
var facing_direction: int = 1
var _dash_remaining: float = 0.0
var _dash_direction: int = 1
var _hurt_remaining: float = 0.0
var _coyote_remaining: float = 0.0
var _jump_buffer_remaining: float = 0.0
@export var max_health: int = 3
@export var damage_protection_time: float = 0.8

signal health_changed(remaining: int)

var health: int
var _protection_remaining: float = 0.0

@onready var attack_origin: Marker2D = $AttackOrigin
@onready var facing_marker: Polygon2D = $FacingMarker
@onready var body: Polygon2D = $Body
@onready var sparkler: Node2D = $Sparkler
@onready var exhaust: Polygon2D = $DashExhaust


func _ready() -> void:
	health = max_health
	add_to_group("players")


func _physics_process(delta: float) -> void:
	_protection_remaining = maxf(_protection_remaining - delta, 0.0)
	if state == State.DEAD:
		return
	if state == State.DASH:
		_process_dash(delta)
		_update_feedback()
		return
	if state == State.HURT:
		_hurt_remaining = maxf(_hurt_remaining - delta, 0.0)
		velocity.y = minf(velocity.y + movement_settings.fall_gravity * delta, movement_settings.max_fall_speed)
		move_and_slide()
		if is_on_floor():
			dash_available = true
		if _hurt_remaining <= 0.0:
			state = State.NORMAL
		_update_feedback()
		return
	if is_on_floor():
		dash_available = true
	var direction := Input.get_axis("move_left", "move_right")
	var horizontal_rate := movement_settings.acceleration
	if is_zero_approx(direction):
		horizontal_rate = movement_settings.deceleration
	velocity.x = move_toward(velocity.x, direction * movement_settings.run_speed, horizontal_rate * delta)
	if not is_zero_approx(direction):
		facing_direction = 1 if direction > 0.0 else -1
		attack_origin.position.x = 18.0 * facing_direction
		facing_marker.position.x = 7.0 * facing_direction

	if Input.is_action_just_pressed("attack"):
		sparkler.start(facing_direction)

	if Input.is_action_just_pressed("dash") and dash_available and not is_on_floor():
		sparkler.cancel()
		state = State.DASH
		dash_available = false
		_dash_direction = facing_direction
		_dash_remaining = movement_settings.dash_duration
		_coyote_remaining = 0.0
		_jump_buffer_remaining = 0.0
		_process_dash(delta)
		_update_feedback()
		return

	_coyote_remaining = maxf(_coyote_remaining - delta, 0.0)
	if is_on_floor() and velocity.y >= 0.0:
		_coyote_remaining = movement_settings.coyote_time

	_jump_buffer_remaining = maxf(_jump_buffer_remaining - delta, 0.0)
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_remaining = movement_settings.jump_buffer_time
	if _jump_buffer_remaining > 0.0 and _coyote_remaining > 0.0:
		_start_jump()

	var gravity := movement_settings.rise_gravity if velocity.y < 0.0 else movement_settings.fall_gravity
	velocity.y = minf(velocity.y + gravity * delta, movement_settings.max_fall_speed)
	move_and_slide()
	if is_on_floor():
		dash_available = true
	_update_feedback()

	# A press just before landing launches immediately, without requiring another press.
	if is_on_floor() and _jump_buffer_remaining > 0.0:
		_start_jump()


func _start_jump() -> void:
	velocity.y = movement_settings.jump_velocity
	_coyote_remaining = 0.0
	_jump_buffer_remaining = 0.0


func _process_dash(delta: float) -> void:
	var was_grounded := is_on_floor()
	# move_and_slide sweeps the body against solids, including thin walls.
	# Scale the final tick so duration does not round up to a physics frame.
	var step := minf(delta, _dash_remaining)
	velocity = Vector2(_dash_direction * movement_settings.dash_speed * step / delta, 0.0)
	move_and_slide()
	_dash_remaining = maxf(_dash_remaining - delta, 0.0)
	if not was_grounded and is_on_floor():
		dash_available = true
	if is_on_wall() or _dash_remaining <= 0.00001:
		state = State.NORMAL
		velocity = Vector2(0.0 if is_on_wall() else _dash_direction * movement_settings.run_speed, 0.0)


func _update_feedback() -> void:
	body.modulate = Color(1.0, 0.45, 0.45) if _protection_remaining > 0.0 else Color.WHITE
	exhaust.visible = state == State.DASH
	exhaust.scale.x = float(_dash_direction)
	if state == State.DASH:
		body.color = Color(1.0, 0.72, 0.2)
	elif dash_available:
		body.color = Color(0.76, 0.78, 0.82)
	else:
		body.color = Color(0.44, 0.48, 0.55)


func apply_knockback(impulse: Vector2, duration: float = 0.15) -> void:
	if state == State.DEAD:
		return
	sparkler.cancel()
	state = State.HURT
	velocity = impulse
	_hurt_remaining = maxf(duration, 0.0)
	_dash_remaining = 0.0
	_coyote_remaining = 0.0
	_jump_buffer_remaining = 0.0
	_update_feedback()


func take_damage(amount: int, knockback: Vector2) -> void:
	if state == State.DEAD or _protection_remaining > 0.0 or amount <= 0:
		return
	health = maxi(health - amount, 0)
	_protection_remaining = damage_protection_time
	health_changed.emit(health)
	if health == 0:
		die()
	else:
		apply_knockback(knockback)


func die() -> void:
	if state == State.DEAD:
		return
	sparkler.cancel()
	state = State.DEAD
	velocity = Vector2.ZERO
	_update_feedback()
	died.emit()
