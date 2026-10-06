extends CharacterBody2D
## Ground patrol with an interruptible charge and a slowly steering projectile.
const BURST = preload("res://scripts/effects/burst.gd")
const PROJECTILE_SCENE = preload("res://scenes/combat/homing_projectile.tscn")

signal health_changed(remaining: int)
signal died
signal shot_fired

@export var max_health: int = 3
@export var patrol_speed: float = 45.0
@export var patrol_radius: float = 70.0
@export var gravity: float = 1800.0
@export var detection_range: float = 260.0
@export var windup_time: float = 0.65
@export var recovery_time: float = 1.6
@export var projectile_speed: float = 170.0
@export var projectile_turn_speed: float = 2.4
@export var projectile_damage: int = 1
@export var projectile_lifetime: float = 2.8
@export var projectile_knockback: Vector2 = Vector2(180, -120)

enum State { PATROL, CHARGING, RECOVERY, HURT, DEAD }
var state: State = State.PATROL
var health: int
var _home_x: float
var _direction: int = 1
var _aim_direction: Vector2 = Vector2.RIGHT
var _remaining: float = 0.0
var _hit_flash_remaining: float = 0.0

@onready var body: Polygon2D = $Body
@onready var pupil: Polygon2D = $Pupil
@onready var status: Label = $Name
@onready var shot_origin: Marker2D = $ShotOrigin


func _ready() -> void:
	health = max_health
	_home_x = global_position.x
	_update_feedback()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_remaining = maxf(_remaining - delta, 0.0)
	_hit_flash_remaining = maxf(_hit_flash_remaining - delta, 0.0)
	_process_attack()
	if state == State.HURT:
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	elif state == State.CHARGING:
		velocity.x = 0.0
	else:
		if global_position.x >= _home_x + patrol_radius:
			_direction = -1
		elif global_position.x <= _home_x - patrol_radius:
			_direction = 1
		var distance_left := maxf(patrol_radius - _direction * (global_position.x - _home_x), 0.0)
		velocity.x = _direction * minf(patrol_speed, distance_left / delta)
	# Stay on the platform while patrolling or reloading.
	if is_on_floor() and not is_zero_approx(velocity.x):
		var ahead := global_position + Vector2(signf(velocity.x) * 24.0, -12.0)
		var query := PhysicsRayQueryParameters2D.create(ahead, ahead + Vector2(0, 40), 1)
		if get_world_2d().direct_space_state.intersect_ray(query).is_empty():
			velocity.x = 0.0
			_direction *= -1
	velocity.y = minf(velocity.y + gravity * delta, 900.0)
	move_and_slide()
	if is_on_wall():
		_direction *= -1
	_update_feedback()


func _process_attack() -> void:
	if state == State.HURT or state == State.RECOVERY:
		if _remaining > 0.0:
			return
		state = State.PATROL
	var player := get_tree().get_first_node_in_group("players") as CharacterBody2D
	if not is_on_floor() or not _can_see(player):
		if state == State.CHARGING:
			state = State.RECOVERY
			_remaining = recovery_time
		return
	var toward := player.global_position + Vector2(0, -20) - shot_origin.global_position
	_aim_direction = toward.normalized() if not toward.is_zero_approx() else Vector2(_direction, 0)
	if state == State.PATROL:
		state = State.CHARGING
		_remaining = windup_time
	elif state == State.CHARGING and _remaining <= 0.0:
		_fire(player)
		state = State.RECOVERY
		_remaining = recovery_time


func _can_see(player: CharacterBody2D) -> bool:
	if not is_instance_valid(player) or player.health <= 0:
		return false
	var target := player.global_position + Vector2(0, -20)
	if shot_origin.global_position.distance_to(target) > detection_range:
		return false
	var query := PhysicsRayQueryParameters2D.create(shot_origin.global_position, target, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _fire(player: CharacterBody2D) -> void:
	var projectile := PROJECTILE_SCENE.instantiate() as CharacterBody2D
	projectile.direction = _aim_direction
	projectile.target = player
	projectile.speed = projectile_speed
	projectile.turn_speed = projectile_turn_speed
	projectile.damage = projectile_damage
	projectile.lifetime = projectile_lifetime
	projectile.knockback = projectile_knockback
	get_tree().current_scene.add_child(projectile)
	shot_fired.emit()
	projectile.global_position = shot_origin.global_position
	BURST.spawn(get_tree().current_scene, shot_origin.global_position, Color(0.8, 0.4, 1.0), "", 12.0)


func _update_feedback() -> void:
	body.modulate = Color.WHITE
	var action_hint := "PATROL"
	var look := Vector2(_direction, 0)
	match state:
		State.CHARGING:
			body.modulate = Color(1.8, 1.1, 2.0)
			action_hint = "HOMING CHARGE!"
			look = _aim_direction
		State.RECOVERY:
			body.modulate = Color(0.7, 0.75, 0.85)
			action_hint = "RELOADING"
		State.HURT:
			body.modulate = Color(2.0, 2.0, 2.0) if _hit_flash_remaining > 0.0 else Color(1.2, 0.8, 0.8)
			action_hint = "HIT"
	pupil.position = Vector2(0, -26) + look * 5.0
	status.text = "Shooter %d/%d\n%s" % [health, max_health, action_hint]
	queue_redraw()


func _draw() -> void:
	if state != State.CHARGING:
		return
	var progress := 1.0 - clampf(_remaining / maxf(windup_time, 0.001), 0.0, 1.0)
	var center := Vector2(0, -20) + _aim_direction * 24.0
	draw_arc(center, 5.0 + progress * 5.0, 0.0, TAU * progress, 20, Color(0.9, 0.5, 1.0), 2.0)
	draw_circle(center, 2.0 + progress * 3.0, Color(1.0, 0.8, 1.0))


func take_damage(amount: int, knockback: Vector2) -> void:
	if health <= 0 or amount <= 0:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health)
	if health == 0:
		state = State.DEAD
		BURST.spawn(get_tree().current_scene, shot_origin.global_position, Color(0.8, 0.4, 1.0), "BOOM!", 38.0)
		died.emit()
		queue_free()
		return
	state = State.HURT
	velocity = knockback
	_remaining = 0.20
	_hit_flash_remaining = 0.09
	_update_feedback()
