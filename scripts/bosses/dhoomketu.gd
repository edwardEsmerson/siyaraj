extends CharacterBody2D
## Original Diwali villain guarding the ghats aboard a stolen fireworks barge.
const Hazard = preload("res://scripts/bosses/dhoomketu_hazard.gd")
signal health_changed(remaining: int)
signal phase_changed(phase: int)
signal died

enum State { INTRO, CAST, RECOVERY, PHASE_SHIFT, DEAD }
@export var boss_name: String = "Dhoomketu"
@export var boss_title: String = "Firework Commander"
@export var max_health: int = 28
@export var warning_time: float = 0.9
@export var recovery_time: float = 1.4
@export var rocket_speed: float = 340.0
@export var rocket_stagger: float = 0.28
@export var chakri_speed: float = 220.0
@export var fountain_burn_time: float = 1.25
var health: int
var phase: int = 1
var state: State = State.INTRO
var state_remaining: float = 1.0
var attack_index: int = 0
var facing: int = -1
var _flash: float = 0.0
var _anim_time: float = 0.0
@onready var status: Label = $Status


func _ready() -> void:
	health = max_health
	add_to_group("bosses")


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_anim_time += delta
	velocity = Vector2(0, velocity.y + 1800.0 * delta)
	move_and_slide()
	state_remaining -= delta
	_flash = maxf(_flash - delta, 0.0)
	if state_remaining <= 0.0:
		match state:
			State.INTRO, State.RECOVERY, State.PHASE_SHIFT:
				var player := get_tree().get_first_node_in_group("players") as CharacterBody2D
				if player != null and player.health > 0:
					start_attack(attack_index % 3, player.position.x)
					attack_index += 1
			State.CAST:
				state = State.RECOVERY
				state_remaining = recovery_time
				status.text = "RELOADING - STRIKE NOW"
	queue_redraw()


func current_warning() -> float:
	return warning_time if phase == 1 else warning_time * 0.85


func spawn_hazard(kind: int, at: Vector2, dimensions: Vector2, duration: float, travel_speed: float = 0.0, travel_direction: int = 1, delay: float = 0.0) -> Node2D:
	var hazard := Hazard.new()
	hazard.kind = kind
	hazard.position = at
	hazard.size = dimensions
	hazard.warning_time = current_warning() + delay
	hazard.active_time = duration
	hazard.speed = travel_speed
	hazard.direction = travel_direction
	get_parent().add_child(hazard)
	state_remaining = maxf(state_remaining, hazard.warning_time + duration)
	return hazard


func spawn_rocket(at: Vector2, target: Vector2, delay: float = 0.0) -> Node2D:
	var path := target - (at + Vector2(0, -6))
	var hazard := spawn_hazard(Hazard.Kind.ROCKET, at, Vector2(20, 12), path.length() / rocket_speed + 0.12, rocket_speed, facing, delay)
	hazard.heading = path.normalized()
	hazard.target_position = target
	return hazard


func start_attack(index: int, target_x: float) -> void:
	if state == State.DEAD:
		return
	facing = 1 if target_x > position.x else -1
	state = State.CAST
	state_remaining = 0.0
	match index:
		0:
			status.text = "ROCKET SALVO - LEAVE THE FLIGHT PATHS"
			# Every target locks before the first fuse burns. No homing rockets.
			var offsets := PackedFloat32Array([-85.0, 85.0, 0.0] if phase == 1 else [-120.0, 0.0, 120.0, 55.0])
			for index_in_salvo in range(offsets.size()):
				spawn_rocket(position + Vector2(facing * 36, -82 - index_in_salvo * 8), Vector2(clampf(target_x + offsets[index_in_salvo], 65, 895), position.y - 20), index_in_salvo * rocket_stagger)
		1:
			status.text = "CHAKRI CHASE - JUMP THE SPINNERS"
			spawn_hazard(Hazard.Kind.CHAKRI, position + Vector2(facing * 42, 0), Vector2(24, 16), 2.5, chakri_speed * (1.2 if phase == 2 else 1.0), facing)
			if phase == 2:
				spawn_hazard(Hazard.Kind.CHAKRI, Vector2(50 if facing < 0 else 910, position.y), Vector2(24, 16), 2.2, chakri_speed, -facing, 0.45)
		2:
			status.text = "ANAAR FOUNTAINS - LEAVE THE GOLD MARKS"
			for offset in ([0.0, -140.0, 140.0] if phase == 2 else [0.0, 140.0]):
				spawn_hazard(Hazard.Kind.ANAAR, Vector2(clampf(target_x + offset, 65, 895), position.y), Vector2(48, 110), fountain_burn_time)


func take_damage(amount: int, _knockback: Vector2 = Vector2.ZERO) -> void:
	if state == State.DEAD or amount <= 0:
		return
	health = maxi(health - amount, 0)
	_flash = 0.12
	health_changed.emit(health)
	if health == 0:
		state = State.DEAD
		collision_layer = 0
		_clear_hazards()
		status.text = "DHOOMKETU DEFEATED"
		died.emit()
	elif phase == 1 and health <= max_health / 2:
		phase = 2
		_clear_hazards()
		state = State.PHASE_SHIFT
		state_remaining = 1.2
		status.text = "LIGHT EVERY FUSE!"
		phase_changed.emit(phase)
	queue_redraw()


func _clear_hazards() -> void:
	for hazard in get_parent().get_children():
		if hazard.get_script() == Hazard:
			hazard.set_physics_process(false)
			hazard.queue_free()


func _draw() -> void:
	var coat := Color(0.45, 0.1, 0.3) if phase == 1 else Color(0.7, 0.12, 0.2)
	var gold := Color(1, 0.72, 0.2)
	var skin := Color(0.35, 0.24, 0.45)
	if _flash > 0:
		coat = Color.WHITE
	if state == State.DEAD:
		coat = Color(0.25, 0.2, 0.25, 0.4)
	draw_colored_polygon(PackedVector2Array([Vector2(-24, 0), Vector2(-30, -64), Vector2(-18, -80), Vector2(18, -80), Vector2(30, -64), Vector2(24, 0)]), coat)
	draw_rect(Rect2(-18, -68, 36, 38), Color(0.15, 0.08, 0.18))
	# Brass bandolier of fireworks and a shoulder-mounted rocket rack.
	for index in range(4):
		var center := Vector2(-15 + index * 10, -65 + index * 7)
		draw_line(center - Vector2(0, 7), center + Vector2(0, 7), gold, 5)
	for index in range(3):
		var x := -facing * (25 + index * 8)
		draw_line(Vector2(x, -62), Vector2(x, -100), coat.lightened(0.25), 6)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 5, -100), Vector2(x, -111), Vector2(x + 5, -100)]), gold)
	draw_circle(Vector2(0, -89), 13, skin)
	draw_rect(Rect2(-15, -104, 30, 9), coat)
	draw_circle(Vector2(0, -108), 6, gold)
	draw_line(Vector2(-10, -84), Vector2(0, -81), Color(0.07, 0.03, 0.08), 4)
	draw_line(Vector2(0, -81), Vector2(10, -84), Color(0.07, 0.03, 0.08), 4)
	draw_circle(Vector2(facing * 6, -90), 3, gold)
	if state == State.CAST:
		draw_circle(Vector2(facing * 35, -62), 3 + absf(sin(_anim_time * 25)), gold)
