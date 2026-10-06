extends CharacterBody2D
const Burst = preload("res://scripts/effects/burst.gd")

signal health_changed(remaining: int)
signal died

@export var enemy_name: String = "Guard"
@export var max_health: int = 3
@export var patrol_speed: float = 60.0
@export var chase_speed: float = 95.0
@export var patrol_radius: float = 100.0
@export var detection_range: float = 200.0
@export var attack_range: float = 52.0
@export var gravity: float = 1800.0
@export var edge_probe_distance: float = 24.0
@export_range(0.0, 1.0) var knockback_multiplier: float = 1.0

enum State { PATROL, CHASE, ATTACK, HURT, DEAD }
var state: State = State.PATROL
var health: int
var _home_x: float
var _direction: int = 1
var _hurt_remaining: float = 0.0
var _hit_flash_remaining: float = 0.0

@onready var body: Polygon2D = $Body
@onready var art: Node2D = $Visuals/Art
@onready var sprite: AnimatedSprite2D = $Visuals/Art/Sprite
@onready var attack: Node2D = $MeleeAttack
@onready var status: Label = $Name


static func play_death_art(scene: Node, art: Node2D, world_position: Vector2) -> void:
	if not is_instance_valid(scene) or not is_instance_valid(art):
		return
	var death_art := art.duplicate() as Node2D
	scene.add_child(death_art)
	death_art.global_position = world_position + art.position
	var death_sprite := death_art.get_node("Sprite") as AnimatedSprite2D
	death_sprite.animation = &"death"
	death_sprite.frame = 0
	death_sprite.modulate = Color.WHITE
	death_sprite.animation_finished.connect(death_art.queue_free)
	death_sprite.play()


func _ready() -> void:
	body.hide()
	health = max_health
	_home_x = global_position.x
	_update_feedback()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_hurt_remaining = maxf(_hurt_remaining - delta, 0.0)
	_hit_flash_remaining = maxf(_hit_flash_remaining - delta, 0.0)
	var player := get_tree().get_first_node_in_group("players") as CharacterBody2D
	var can_see := is_instance_valid(player) and absf(player.global_position.x - global_position.x) <= detection_range and absf(player.global_position.y - global_position.y) < 64.0
	if _hurt_remaining > 0.0:
		state = State.HURT
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	elif attack.is_busy():
		state = State.ATTACK
		velocity.x = 0.0
	elif can_see:
		_direction = 1 if player.global_position.x >= global_position.x else -1
		if absf(player.global_position.x - global_position.x) <= attack_range:
			state = State.ATTACK
			velocity.x = 0.0
			attack.start(_direction)
		else:
			state = State.CHASE
			velocity.x = _direction * chase_speed
	else:
		state = State.PATROL
		if global_position.x >= _home_x + patrol_radius:
			_direction = -1
		elif global_position.x <= _home_x - patrol_radius:
			_direction = 1
		velocity.x = _direction * patrol_speed
	# Stop at unsupported edges instead of chasing the player into a pit.
	if is_on_floor() and not is_zero_approx(velocity.x):
		var ahead := global_position + Vector2(signf(velocity.x) * edge_probe_distance, -12.0)
		var query := PhysicsRayQueryParameters2D.create(ahead, ahead + Vector2(0, 40), 1)
		if get_world_2d().direct_space_state.intersect_ray(query).is_empty():
			velocity.x = 0.0
			_direction *= -1
	velocity.y = minf(velocity.y + gravity * delta, 900.0)
	move_and_slide()
	if is_on_wall():
		_direction *= -1
	_update_feedback()


func _update_feedback() -> void:
	sprite.modulate = Color.WHITE
	var action_hint := "PATROL"
	match state:
		State.HURT:
			sprite.modulate = Color(2.0, 2.0, 2.0) if _hit_flash_remaining > 0.0 else Color(1.2, 0.8, 0.8)
			action_hint = "HIT"
		State.ATTACK:
			match attack.phase:
				attack.Phase.WINDUP:
					sprite.modulate = Color(2.0, 1.2, 0.35)
					action_hint = "WIND-UP!"
				attack.Phase.ACTIVE:
					sprite.modulate = Color(2.2, 0.4, 0.3)
					action_hint = "STRIKE!"
				_:
					sprite.modulate = Color(0.7, 0.75, 0.85)
					action_hint = "RECOVERING"
		State.CHASE:
			sprite.modulate = Color(1.4, 1.1, 0.7)
			action_hint = "APPROACHING"
	status.text = "%s %d/%d\n%s" % [enemy_name, health, max_health, action_hint]
	art.scale.x = -0.5 if _direction < 0 else 0.5
	var animation: StringName = &"walk"
	match state:
		State.ATTACK:
			animation = &"attack"
		State.HURT:
			animation = &"idle"
	if sprite.animation != animation or not sprite.is_playing():
		sprite.play(animation)


func take_damage(amount: int, knockback: Vector2) -> void:
	if health <= 0 or amount <= 0:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health)
	attack.cancel()
	if health == 0:
		state = State.DEAD
		play_death_art(get_tree().current_scene, art, global_position)
		Burst.spawn(get_tree().current_scene, global_position + Vector2(0, -20), Color(1.0, 0.75, 0.25), "BOOM!", 38.0)
		died.emit()
		queue_free()
		return
	state = State.HURT
	velocity = knockback * knockback_multiplier
	_hurt_remaining = 0.20
	_hit_flash_remaining = 0.09
	_update_feedback()
