extends CharacterBody2D
## Patrol and shooting run together. Staggers interrupt firing, never flight altitude.
const BURST = preload("res://scripts/effects/burst.gd")
const PROJECTILE_SCENE = preload("res://scenes/combat/enemy_projectile.tscn")

signal health_changed(remaining: int)
signal died
signal shot_fired

@export var max_health: int = 3
@export var patrol_speed: float = 60.0
@export var patrol_radius: float = 90.0
@export var detection_range: float = 300.0
@export var windup_time: float = 0.45
@export var recovery_time: float = 1.2
@export var projectile_speed: float = 220.0
@export var projectile_damage: int = 1
@export var projectile_lifetime: float = 3.0
@export var projectile_knockback: Vector2 = Vector2(180, -120)
@export var stagger_cooldown: float = 1.4

enum State { PATROL, CHARGING, RECOVERY, HURT, DEAD }
var state: State = State.PATROL
var health: int
var _home: Vector2
var _direction: int = 1
var _aim_direction: Vector2 = Vector2.RIGHT
var _remaining: float = 0.0
var _hit_flash_remaining: float = 0.0
var _stagger_cooldown_remaining: float = 0.0

@onready var body: Polygon2D = $Body
@onready var pupil: Polygon2D = $Pupil
@onready var status: Label = $Name
@onready var shot_origin: Marker2D = $ShotOrigin


func _ready() -> void:
	health = max_health
	_home = global_position
	_update_feedback()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_hit_flash_remaining = maxf(_hit_flash_remaining - delta, 0.0)
	_stagger_cooldown_remaining = maxf(_stagger_cooldown_remaining - delta, 0.0)
	_remaining = maxf(_remaining - delta, 0.0)
	if global_position.x >= _home.x + patrol_radius:
		_direction = -1
	elif global_position.x <= _home.x - patrol_radius:
		_direction = 1
	if state == State.HURT:
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	else:
		velocity.x = _direction * patrol_speed
	velocity.y = 0.0
	var next_x := clampf(global_position.x + velocity.x * delta, _home.x - patrol_radius, _home.x + patrol_radius)
	var collision := move_and_collide(Vector2(next_x - global_position.x, 0.0))
	if collision != null:
		_direction *= -1
	global_position.y = _home.y
	_process_attack()
	_update_feedback()


func _process_attack() -> void:
	if state == State.HURT or state == State.RECOVERY:
		if _remaining > 0.0:
			return
		state = State.PATROL
	var player := get_tree().get_first_node_in_group("players") as CharacterBody2D
	if not _can_see(player):
		if state == State.CHARGING:
			state = State.RECOVERY
			_remaining = recovery_time
		return
	if state == State.PATROL:
		var toward := player.global_position + Vector2(0, -20) - shot_origin.global_position
		_aim_direction = toward.normalized() if not toward.is_zero_approx() else Vector2(_direction, 0)
		state = State.CHARGING
		get_node("/root/AudioDirector").play_sfx(&"tell", global_position)
		_remaining = windup_time
	elif state == State.CHARGING and _remaining <= 0.0:
		_fire()
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


func _fire() -> void:
	var projectile := PROJECTILE_SCENE.instantiate() as CharacterBody2D
	projectile.direction = _aim_direction
	projectile.speed = projectile_speed
	projectile.damage = projectile_damage
	projectile.lifetime = projectile_lifetime
	projectile.knockback = projectile_knockback
	# Scene ownership keeps existing shots alive after this enemy is defeated.
	get_tree().current_scene.add_child(projectile)
	shot_fired.emit()
	projectile.global_position = shot_origin.global_position
	BURST.spawn(get_tree().current_scene, shot_origin.global_position, Color(1.0, 0.5, 0.2), "", 12.0)


func _update_feedback() -> void:
	body.modulate = Color.WHITE
	var action_hint := "PATROL"
	var look := Vector2(_direction, 0)
	match state:
		State.CHARGING:
			body.modulate = Color(2.0, 1.2, 0.35)
			action_hint = "CHARGING!"
			look = _aim_direction
		State.RECOVERY:
			body.modulate = Color(0.7, 0.75, 0.85)
			action_hint = "RELOADING"
			look = _aim_direction
		State.HURT:
			body.modulate = Color(2.0, 2.0, 2.0) if _hit_flash_remaining > 0.0 else Color(1.2, 0.8, 0.8)
			action_hint = "HIT"
	if _hit_flash_remaining > 0.0 and state != State.HURT:
		body.modulate = body.modulate.lerp(Color(2.0, 2.0, 2.0), 0.35)
	pupil.position = Vector2(0, -20) + look * 5.0
	status.text = "Flyer %d/%d\n%s" % [health, max_health, action_hint]
	queue_redraw()


func _draw() -> void:
	if state != State.CHARGING:
		return
	var center := Vector2(0, -20)
	var progress := 1.0 - clampf(_remaining / maxf(windup_time, 0.001), 0.0, 1.0)
	draw_line(center + _aim_direction * 18, center + _aim_direction * 34, Color(1.0, 0.7, 0.2), 2.0)
	draw_circle(center + _aim_direction * 22, 3.0 + progress * 3.0, Color(1.0, 0.8, 0.3))


func take_damage(amount: int, knockback: Vector2) -> void:
	if health <= 0 or amount <= 0:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health)
	if health == 0:
		state = State.DEAD
		BURST.spawn(get_tree().current_scene, shot_origin.global_position, Color(0.4, 0.8, 1.0), "BOOM!", 38.0)
		died.emit()
		queue_free()
		return
	_hit_flash_remaining = 0.09
	# Follow-up hits still deal damage, but cannot restart hurt or reload timers.
	if _stagger_cooldown_remaining <= 0.0 and state != State.RECOVERY:
		state = State.HURT
		velocity = Vector2(knockback.x, 0.0)
		_remaining = 0.20
		_stagger_cooldown_remaining = stagger_cooldown
	_update_feedback()
