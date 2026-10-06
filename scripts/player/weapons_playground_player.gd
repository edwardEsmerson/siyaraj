extends "res://scripts/player/player.gd"
## Weapon controller shared by the playground and forest. Movement impulses stay here.
const Skyshot = preload("res://scripts/combat/skyshot_projectile.gd")

signal weapon_used(animation: StringName, duration: float)

const MAX_SKYSHOT_AMMO: int = 5
@export var shot_recovery_time: float = 0.45
@export var recoil_speed: float = 120.0
@export var recoil_duration: float = 0.12
@export var full_charge_time: float = 1.0
@export var chakri_radius: float = 110.0
@export var chakri_cooldown: float = 30.0

var charging: bool = false
var charge_time: float = 0.0
var special_recovery: float = 0.0
var skyshot_ammo: int = MAX_SKYSHOT_AMMO
var shot_recovery_remaining: float = 0.0
var recoil_remaining: float = 0.0
var recoil_direction: int = 0
var chakri_cooldown_remaining: float = 0.0
var effect_time: float = 0.0
var effect_kind: String = ""
var effect_radius: float = 0.0
var attack_status: String = "Ready"
var _special_targets: Dictionary = {}


func _ready() -> void:
	super._ready()
	# A fresh player enters each level/round with five shots. Ordinary damage,
	# target respawns and travel between practice stations never refill it.
	skyshot_ammo = MAX_SKYSHOT_AMMO


func _physics_process(delta: float) -> void:
	shot_recovery_remaining = maxf(shot_recovery_remaining - delta, 0.0)
	chakri_cooldown_remaining = maxf(chakri_cooldown_remaining - delta, 0.0)
	effect_time = maxf(effect_time - delta, 0.0)
	special_recovery = maxf(special_recovery - delta, 0.0)
	if state != State.NORMAL:
		# Keep the chakri charge through a dash; hurt and death still cancel it.
		if state != State.DASH:
			_cancel_specials()
		super._physics_process(delta)
		queue_redraw()
		return
	var shot_pressed := Input.is_action_just_pressed("skyshot")
	if shot_pressed and special_recovery <= 0.0 and shot_recovery_remaining <= 0.0:
		if skyshot_ammo > 0:
			var input_direction := Input.get_axis("move_left", "move_right")
			if not is_zero_approx(input_direction):
				facing_direction = 1 if input_direction > 0.0 else -1
			attack_origin.position.x = 18.0 * facing_direction
			facing_marker.position.x = 7.0 * facing_direction
			_fire_skyshot()
		else:
			attack_status = "SKYSHOT: empty"
	if recoil_remaining > 0.0:
		_process_recoil(delta)
		queue_redraw()
		return
	if special_recovery <= 0.0 and chakri_cooldown_remaining <= 0.0 and Input.is_action_just_pressed("special") and not charging:
		sparkler.cancel()
		charging = true
		get_node("/root/AudioDirector").play_sfx(&"charge", global_position)
		charge_time = 0.0
	if charging:
		charge_time = minf(charge_time + delta, full_charge_time)
		attack_status = "CHAKRI: %d%% charged" % roundi(charge_time / full_charge_time * 100.0)
		# A release during a dash is handled on the first normal movement tick.
		if not Input.is_action_pressed("special"):
			_release_chakri()
	sparkler.externally_locked = charging or special_recovery > 0.0 or shot_pressed
	super._physics_process(delta)
	if state != State.NORMAL and state != State.DASH:
		_cancel_specials()
	elif sparkler.is_busy():
		attack_status = "SPARKLER: lash"
	elif not charging and special_recovery <= 0.0:
		attack_status = "Ready"
	queue_redraw()


func _fire_skyshot() -> void:
	if skyshot_ammo <= 0 or shot_recovery_remaining > 0.0:
		return
	sparkler.cancel()
	charging = false
	charge_time = 0.0
	skyshot_ammo -= 1
	shot_recovery_remaining = shot_recovery_time
	recoil_remaining = recoil_duration
	recoil_direction = -facing_direction
	attack_status = "SKYSHOT: fired"
	weapon_used.emit(&"skyshot", shot_recovery_time)
	get_node("/root/AudioDirector").play_sfx(&"skyshot", global_position)
	var projectile := Skyshot.new()
	projectile.direction = facing_direction
	# Start inside Siya's body, which the shot ignores. A muzzle outside the
	# collider could spawn on the far side of a thin wall when firing beside it.
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + Vector2(0, -22)
	Burst.spawn(get_tree().current_scene, global_position + Vector2(facing_direction * 18, -22), Color(1, 0.65, 0.2), "", 12)


func _process_recoil(delta: float) -> void:
	_tick_timers(delta)
	_coyote_remaining = maxf(_coyote_remaining - delta, 0.0)
	_jump_buffer_remaining = maxf(_jump_buffer_remaining - delta, 0.0)
	if is_on_floor():
		dash_available = true
		_coyote_remaining = movement_settings.coyote_time
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_remaining = movement_settings.jump_buffer_time
	if _jump_buffer_remaining > 0.0 and _coyote_remaining > 0.0:
		_start_jump()
	var step := minf(delta, recoil_remaining)
	velocity.x = recoil_direction * recoil_speed * step / delta
	var gravity := movement_settings.rise_gravity if velocity.y < 0.0 else movement_settings.fall_gravity
	velocity.y = minf(velocity.y + gravity * delta, movement_settings.max_fall_speed)
	move_and_slide()
	recoil_remaining = maxf(recoil_remaining - delta, 0.0)
	if is_on_floor():
		dash_available = true
		if _jump_buffer_remaining > 0.0:
			_start_jump()
	if recoil_remaining <= 0.0:
		velocity.x = 0.0
	_update_feedback()


func _release_chakri() -> void:
	if chakri_cooldown_remaining > 0.0:
		return
	chakri_cooldown_remaining = chakri_cooldown
	var strength := clampf(charge_time / full_charge_time, 0.0, 1.0)
	charging = false
	special_recovery = 0.35 + strength * 0.20
	weapon_used.emit(&"chakri_release", special_recovery)
	get_node("/root/AudioDirector").play_sfx(&"spin", global_position)
	effect_kind = "chakri"
	effect_time = 0.30
	effect_radius = lerpf(42.0, chakri_radius, strength)
	attack_status = "CHAKRI: full spin!" if strength >= 0.95 else "CHAKRI: quick spin!"
	_special_targets.clear()
	_damage_area(effect_radius, 3 if strength >= 0.95 else 1, -180.0, "chakri")
	Burst.spawn(get_tree().current_scene, global_position + Vector2(0, -20), Color(0.2, 0.95, 0.8), "SPIN!", effect_radius)
	charge_time = 0.0


func _damage_area(radius: float, amount: int, vertical_impulse: float, weapon: String) -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position + Vector2(0, -20))
	query.collision_mask = 4
	for result in get_world_2d().direct_space_state.intersect_shape(query):
		var target: Node = result.collider
		var id := target.get_instance_id()
		if _special_targets.has(id) or not target.has_method("take_damage"):
			continue
		# A wall blocks radial attacks, including targets on the floor below.
		var ray := PhysicsRayQueryParameters2D.create(query.transform.origin, target.global_position + Vector2(0, -20), 1)
		if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		_special_targets[id] = true
		var away := signf(target.global_position.x - global_position.x)
		if is_zero_approx(away):
			away = float(facing_direction)
		var impulse := Vector2(away * 100.0, vertical_impulse)
		if target.has_method("take_weapon_damage"):
			target.take_weapon_damage(amount, impulse, weapon)
		else:
			target.take_damage(amount, impulse)


func _cancel_specials() -> void:
	charging = false
	charge_time = 0.0
	sparkler.externally_locked = false


func apply_knockback(impulse: Vector2, duration: float = 0.15) -> void:
	recoil_remaining = 0.0
	_cancel_specials()
	super.apply_knockback(impulse, duration)


func die() -> void:
	recoil_remaining = 0.0
	_cancel_specials()
	super.die()


func _draw() -> void:
	if charging:
		var progress := charge_time / full_charge_time
		draw_arc(Vector2(0, -22), 28, -PI * 0.5, -PI * 0.5 + maxf(0.01, progress) * TAU, 32, Color(0.2, 0.95, 0.8), 4)
		draw_line(Vector2(-9, -33), Vector2(9, -33), Color(0.2, 0.95, 0.8), 3)
	if effect_time <= 0.0:
		return
	var color := Color(0.2, 0.95, 0.8, effect_time / 0.30)
	draw_arc(Vector2(0, -20), effect_radius, 0, TAU, 48, color, 4)
	for index in range(6):
		var angle := index * TAU / 6.0 + effect_time * 20.0
		var tip := Vector2.RIGHT.rotated(angle) * effect_radius
		draw_line(Vector2(0, -20) + tip * 0.6, Vector2(0, -20) + tip, color, 3)


func return_to_diya(destination: Vector2) -> void:
	recoil_remaining = 0.0
	_cancel_specials()
	super.return_to_diya(destination)
