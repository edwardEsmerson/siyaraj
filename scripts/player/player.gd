extends CharacterBody2D
## Player movement has one owner. Combat must request knockback through this controller.
const Burst = preload("res://scripts/effects/burst.gd")

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
## Dash i-frames cover the dash plus this grace, so a hit landing on the final tick still misses.
@export var dash_invulnerability_grace: float = 0.05
## An attack pressed during a dash fires when it ends, if the swing can start within this window.
@export var attack_buffer_time: float = 0.12

signal health_changed(remaining: int)

var health: int
var _protection_remaining: float = 0.0
var _hit_flash_remaining: float = 0.0
var _invulnerable_remaining: float = 0.0
var _dash_cooldown_remaining: float = 0.0
var _attack_buffer_remaining: float = 0.0

@onready var attack_origin: Marker2D = $AttackOrigin
@onready var facing_marker: Polygon2D = $FacingMarker
@onready var body: Polygon2D = $Body
@onready var sparkler: Node2D = $Sparkler


func _ready() -> void:
	health = max_health
	add_to_group("players")


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	if state == State.DEAD:
		return
	if state == State.DASH:
		# Attack presses during a dash are held until it ends, giving a dash-attack.
		if Input.is_action_just_pressed("attack"):
			_attack_buffer_remaining = attack_buffer_time
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

	if Input.is_action_just_pressed("attack") or _attack_buffer_remaining > 0.0:
		if sparkler.start(facing_direction):
			_attack_buffer_remaining = 0.0

	# Dashing cancels any swing phase, including recovery.
	if Input.is_action_just_pressed("dash") and can_dash():
		sparkler.cancel()
		var grounded := is_on_floor()
		state = State.DASH
		get_node("/root/AudioDirector").play_sfx(&"dash", global_position)
		if grounded:
			# Ground dashes keep the air charge; a cooldown stops back-to-back spam.
			_dash_cooldown_remaining = movement_settings.dash_duration + movement_settings.ground_dash_cooldown
		else:
			dash_available = false
		_dash_direction = facing_direction
		_dash_remaining = movement_settings.dash_duration
		_invulnerable_remaining = movement_settings.dash_duration + dash_invulnerability_grace
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


func _tick_timers(delta: float) -> void:
	_protection_remaining = maxf(_protection_remaining - delta, 0.0)
	_hit_flash_remaining = maxf(_hit_flash_remaining - delta, 0.0)
	_invulnerable_remaining = maxf(_invulnerable_remaining - delta, 0.0)
	_dash_cooldown_remaining = maxf(_dash_cooldown_remaining - delta, 0.0)
	if state != State.DASH:
		_attack_buffer_remaining = maxf(_attack_buffer_remaining - delta, 0.0)


## Grounded dashes only wait for the cooldown; airborne dashes also need the air charge.
func can_dash() -> bool:
	if state == State.DEAD or _dash_cooldown_remaining > 0.0:
		return false
	return is_on_floor() or dash_available


## True during dash i-frames. Damage sources should let Siya pass through untouched.
func is_invulnerable() -> bool:
	# Same epsilon as the dash timer, so summed frame deltas do not add a stray frame.
	return state != State.DEAD and _invulnerable_remaining > 0.00001


func _start_jump() -> void:
	get_node("/root/AudioDirector").play_sfx(&"jump", global_position)
	velocity.y = movement_settings.jump_velocity
	_coyote_remaining = 0.0
	_jump_buffer_remaining = 0.0


func _process_dash(delta: float) -> void:
	var was_grounded := is_on_floor()
	# move_and_slide sweeps the body against solids, including thin walls.
	# Scale the final tick so duration does not round up to a physics frame.
	var step := minf(delta, _dash_remaining)
	velocity.x = _dash_direction * movement_settings.dash_speed * step / delta
	var gravity := movement_settings.rise_gravity if velocity.y < 0.0 else movement_settings.fall_gravity
	velocity.y = minf(velocity.y + gravity * delta, movement_settings.max_fall_speed)
	move_and_slide()
	_dash_remaining = maxf(_dash_remaining - delta, 0.0)
	if not was_grounded and is_on_floor():
		dash_available = true
	if is_on_wall() or _dash_remaining <= 0.00001:
		state = State.NORMAL
		var exit_speed := movement_settings.run_speed if is_on_floor() else movement_settings.air_dash_exit_speed
		velocity.x = 0.0 if is_on_wall() else _dash_direction * exit_speed


func _update_feedback() -> void:
	body.modulate = Color.WHITE
	if _hit_flash_remaining > 0.0:
		body.modulate = Color(2.0, 0.65, 0.65)
	elif _protection_remaining > 0.0:
		body.modulate.a = 0.4 if int(_protection_remaining * 15.0) % 2 == 0 else 1.0
	elif _invulnerable_remaining > 0.0:
		body.modulate = Color(1.35, 1.35, 1.35, 0.7)
	if state == State.DEAD:
		body.color = Color(0.7, 0.2, 0.2)
	elif state == State.DASH:
		body.color = Color(1.0, 0.72, 0.2)
	elif dash_available and _dash_cooldown_remaining <= 0.0:
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
	# Dash i-frames belong to the dash; forced knockback ends both.
	_invulnerable_remaining = 0.0
	_attack_buffer_remaining = 0.0
	_coyote_remaining = 0.0
	_jump_buffer_remaining = 0.0
	_update_feedback()


func take_damage(amount: int, knockback: Vector2) -> void:
	if state == State.DEAD or _protection_remaining > 0.0 or is_invulnerable() or amount <= 0:
		return
	health = maxi(health - amount, 0)
	_protection_remaining = damage_protection_time
	_hit_flash_remaining = 0.09
	health_changed.emit(health)
	if health == 0:
		die()
	else:
		get_node("/root/AudioDirector").play_sfx(&"hit", global_position)
		apply_knockback(knockback)


## Returns the health restored. Healing never revives Siya or grants protection.
func heal(amount: int) -> int:
	if state == State.DEAD or health <= 0 or amount <= 0:
		return 0
	var restored: int = mini(amount, maxi(max_health - health, 0))
	if restored > 0:
		health += restored
		health_changed.emit(health)
	return restored


## Main-route diyas call this only after recording their first activation.
func heal_from_diya() -> void:
	var restored: int = heal(1)
	if restored > 0:
		Burst.spawn(get_tree().current_scene, global_position + Vector2(0, -20), Color("91e5a3"), "+%d HP" % restored, 32.0, 0.9)


func die() -> void:
	if state == State.DEAD:
		return
	sparkler.cancel()
	state = State.DEAD
	velocity = Vector2.ZERO
	Burst.spawn(get_tree().current_scene, global_position + Vector2(0, -20), Color(1.0, 0.35, 0.3), "DOWN", 38.0)
	_update_feedback()
	died.emit()


func return_to_diya(destination: Vector2) -> void:
	# A checkpoint rejection moves Siya without healing or resetting the encounter.
	sparkler.cancel()
	state = State.NORMAL
	velocity = Vector2.ZERO
	_dash_remaining = 0.0
	_hurt_remaining = 0.0
	_jump_buffer_remaining = 0.0
	_coyote_remaining = 0.0
	_attack_buffer_remaining = 0.0
	_invulnerable_remaining = 0.0
	global_position = destination
	_update_feedback()
