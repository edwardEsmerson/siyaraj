extends CharacterBody2D
## Boss 1: Khara, rakshasa lord of Janasthana in the Dandaka forest.
## Moveset: telegraphed gada slam with ground shockwave, and ladi fireworks that
## burst left or right along the ground. Phase 2 starts at half health.
## Health, damage and signals follow the shared enemy contract, so player
## weapons and the generic BossHealthBar work without special cases.
const Burst = preload("res://scripts/effects/burst.gd")
const Ladi = preload("res://scripts/bosses/ladi_firecracker.gd")
const Shockwave = preload("res://scripts/bosses/ground_shockwave.gd")

signal health_changed(remaining: int)
signal phase_changed(phase: int)
signal died

@export var boss_name: String = "Khara"
@export var boss_title: String = "Lord of Janasthana"
@export var max_health: int = 24
@export_range(0.0, 1.0) var phase_two_threshold: float = 0.5
@export var gravity: float = 1800.0

@export_group("Movement")
@export var walk_speed: float = 75.0
@export var phase_two_speed_multiplier: float = 1.4
@export var intro_time: float = 1.0
@export var idle_time: float = 0.7
@export var phase_two_idle_time: float = 0.4
@export var phase_shift_time: float = 1.2
## Approaching longer than this switches to a ladi once its cooldown allows.
@export var approach_patience: float = 2.0

@export_group("Gada slam")
@export var slam_range: float = 105.0
@export var slam_windup: float = 0.85
@export var phase_two_slam_windup: float = 0.65
@export var slam_active: float = 0.12
@export var slam_recovery: float = 1.1
@export var phase_two_slam_recovery: float = 0.8
@export var slam_damage: int = 1
@export var slam_reach: float = 64.0
@export var slam_hitbox: Vector2 = Vector2(120, 80)
@export var slam_knockback: Vector2 = Vector2(360, -220)
@export var shockwave_speed: float = 380.0
@export var shockwave_lifetime: float = 1.0

@export_group("Ladi fireworks")
@export var ladi_cast_time: float = 0.5
@export var ladi_recovery: float = 0.6
@export var ladi_cooldown: float = 4.5
@export var phase_two_ladi_cooldown: float = 3.0
@export var ladi_fuse: float = 1.2
@export var phase_two_ladi_fuse: float = 0.9
@export var ladi_segments: int = 12
@export var phase_two_ladi_segments: int = 14
@export var ladi_origin_offset: float = 44.0

enum State { INTRO, IDLE, APPROACH, SLAM_WINDUP, SLAM_ACTIVE, SLAM_RECOVERY, LADI_CAST, LADI_RECOVERY, PHASE_SHIFT, DEAD }

const SLAM_COLOR := Color(1.0, 0.35, 0.12)
const LADI_COLOR := Color(1.0, 0.9, 0.2)

var state: State = State.INTRO
var phase: int = 1
var health: int
var facing: int = -1
var state_remaining: float = 0.0
var ladi_cooldown_remaining: float = 0.0
var slams_since_ladi: int = 0
var _approach_time: float = 0.0
var _hit_flash_remaining: float = 0.0
var _slam_targets: Dictionary = {}
var _death_time: float = 0.0
var _anim_time: float = 0.0
var _state_duration: float = 0.0
var _attachment_frames: Dictionary = {}

@onready var visual: Node2D = $Visual
@onready var gada: Node2D = $Visual/Gada
@onready var status: Label = $Status
@onready var art: AnimatedSprite2D = $Visual/Art


func _ready() -> void:
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/khara/cast_meta.json"))
	_attachment_frames = metadata["attachment"]["frames"]
	art.frame_changed.connect(_update_gada_art)
	health = max_health
	add_to_group("bosses")
	_enter(State.INTRO, intro_time)
	ladi_cooldown_remaining = 1.5
	_update_feedback()


func is_phase_two() -> bool:
	return phase >= 2


func current_speed() -> float:
	return walk_speed * (phase_two_speed_multiplier if is_phase_two() else 1.0)


func current_slam_windup() -> float:
	return phase_two_slam_windup if is_phase_two() else slam_windup


func current_slam_recovery() -> float:
	return phase_two_slam_recovery if is_phase_two() else slam_recovery


func current_ladi_fuse() -> float:
	return phase_two_ladi_fuse if is_phase_two() else ladi_fuse


func _enter(next: State, duration: float = 0.0) -> void:
	state = next
	state_remaining = duration
	_state_duration = duration


func _find_player() -> CharacterBody2D:
	var player := get_tree().get_first_node_in_group("players") as CharacterBody2D
	if not is_instance_valid(player) or player.health <= 0:
		return null
	return player


func _face(player: Node2D) -> void:
	if player != null and not is_equal_approx(player.global_position.x, global_position.x):
		facing = 1 if player.global_position.x > global_position.x else -1


func _physics_process(delta: float) -> void:
	_anim_time += delta
	_hit_flash_remaining = maxf(_hit_flash_remaining - delta, 0.0)
	if state == State.DEAD:
		_process_death(delta)
		return
	ladi_cooldown_remaining = maxf(ladi_cooldown_remaining - delta, 0.0)
	state_remaining -= delta
	var player := _find_player()
	velocity.x = 0.0
	match state:
		State.INTRO, State.PHASE_SHIFT:
			if state_remaining <= 0.0:
				_enter(State.IDLE, 0.0)
		State.IDLE:
			if state_remaining <= 0.0 and player != null:
				_decide(player)
		State.APPROACH:
			_approach_time += delta
			if player == null:
				_enter(State.IDLE, idle_time)
			else:
				_face(player)
				var distance := absf(player.global_position.x - global_position.x)
				if distance <= slam_range:
					start_slam(facing)
				elif ladi_cooldown_remaining <= 0.0 and _approach_time >= approach_patience:
					start_ladi()
				else:
					velocity.x = facing * current_speed()
		State.SLAM_WINDUP:
			if state_remaining <= 0.0:
				_slam_impact()
		State.SLAM_ACTIVE:
			_hit_slam_overlaps()
			if state_remaining <= 0.0:
				_enter(State.SLAM_RECOVERY, current_slam_recovery() + state_remaining)
		State.SLAM_RECOVERY:
			if state_remaining <= 0.0:
				_enter(State.IDLE, _idle_duration())
		State.LADI_CAST:
			if state_remaining <= 0.0:
				_place_ladis(player)
				_enter(State.LADI_RECOVERY, ladi_recovery)
		State.LADI_RECOVERY:
			if state_remaining <= 0.0:
				_enter(State.IDLE, _idle_duration())
	velocity.y = minf(velocity.y + gravity * delta, 900.0)
	move_and_slide()
	_update_feedback()


func _idle_duration() -> float:
	return phase_two_idle_time if is_phase_two() else idle_time


func _decide(player: CharacterBody2D) -> void:
	if _has_active_hazards():
		return
	_face(player)
	var distance := absf(player.global_position.x - global_position.x)
	if ladi_cooldown_remaining <= 0.0 and (distance > slam_range * 2.0 or slams_since_ladi >= 2):
		start_ladi()
	elif distance <= slam_range:
		start_slam(facing)
	else:
		_approach_time = 0.0
		_enter(State.APPROACH)


## Let each attack finish before beginning another, including burning ladi fuses.
func _has_active_hazards() -> bool:
	for hazard in get_tree().get_nodes_in_group("boss_hazards"):
		if not hazard.is_queued_for_deletion():
			return true
	return false


## Begin the gada slam. Facing locks for the whole swing.
func start_slam(direction: int) -> void:
	if state == State.DEAD or _has_active_hazards():
		return
	facing = 1 if direction >= 0 else -1
	_slam_targets.clear()
	_enter(State.SLAM_WINDUP, current_slam_windup())


func _slam_impact() -> void:
	_enter(State.SLAM_ACTIVE, slam_active + state_remaining)
	slams_since_ladi += 1
	var parent := get_tree().current_scene
	Burst.spawn(parent, global_position + Vector2(facing * 50, -6), SLAM_COLOR, "DHAM!", 46.0)
	spawn_shockwave(facing)
	_hit_slam_overlaps()


func spawn_shockwave(direction: int) -> Node2D:
	var wave := Shockwave.new()
	wave.direction = direction
	wave.speed = shockwave_speed
	wave.lifetime = shockwave_lifetime
	var parent := get_tree().current_scene
	wave.position = parent.to_local(global_position + Vector2(direction * 70.0, 0))
	parent.add_child(wave)
	return wave


func _hit_slam_overlaps() -> void:
	var shape := RectangleShape2D.new()
	shape.size = slam_hitbox
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position + Vector2(facing * slam_reach, -slam_hitbox.y * 0.5))
	query.collision_mask = 2
	query.exclude = [get_rid()]
	for result in get_world_2d().direct_space_state.intersect_shape(query):
		var target: Node = result.collider
		var id := target.get_instance_id()
		if _slam_targets.has(id) or not target.has_method("take_damage"):
			continue
		_slam_targets[id] = true
		var health_before: int = target.health
		target.take_damage(slam_damage, Vector2(slam_knockback.x * facing, slam_knockback.y))
		if target.health < health_before:
			Burst.spawn(get_tree().current_scene, target.global_position + Vector2(0, -20), SLAM_COLOR, "SMASH!", 34.0)


## Begin placing ladi fireworks; they are laid when the cast finishes.
func start_ladi() -> void:
	if state == State.DEAD or _has_active_hazards():
		return
	_enter(State.LADI_CAST, ladi_cast_time)


func _place_ladis(player: CharacterBody2D) -> void:
	slams_since_ladi = 0
	ladi_cooldown_remaining = phase_two_ladi_cooldown if is_phase_two() else ladi_cooldown
	# Burst toward the player's side. Standing behind the lit end is safe.
	_face(player)
	var origin := global_position + Vector2(facing * ladi_origin_offset, 0)
	place_ladi(origin, facing, current_ladi_fuse(), phase_two_ladi_segments if is_phase_two() else ladi_segments)


func place_ladi(origin: Vector2, direction: int, fuse: float = -1.0, segments: int = -1) -> Node2D:
	var ladi := Ladi.new()
	ladi.direction = direction
	ladi.fuse_time = current_ladi_fuse() if fuse < 0.0 else fuse
	ladi.segment_count = ladi_segments if segments <= 0 else segments
	var parent := get_tree().current_scene
	ladi.position = parent.to_local(origin)
	parent.add_child(ladi)
	return ladi


func take_damage(amount: int, _knockback: Vector2) -> void:
	# Khara has poise: hits flash him but never push him or cancel a swing.
	if state == State.DEAD or health <= 0 or amount <= 0:
		return
	health = maxi(health - amount, 0)
	_hit_flash_remaining = 0.09
	health_changed.emit(health)
	if health == 0:
		_die()
		return
	if phase == 1 and health <= ceili(max_health * phase_two_threshold):
		_enter_phase_two()
	_update_feedback()


func _enter_phase_two() -> void:
	phase = 2
	# The roar cancels any pending swing and opens with fireworks.
	_enter(State.PHASE_SHIFT, phase_shift_time)
	ladi_cooldown_remaining = 0.0
	slams_since_ladi = 2
	Burst.spawn(get_tree().current_scene, global_position + Vector2(0, -60), Color(1.0, 0.25, 0.2), "ROAR!", 60.0)
	phase_changed.emit(phase)


func _die() -> void:
	state = State.DEAD
	_death_time = 0.0
	velocity = Vector2.ZERO
	collision_layer = 0
	# Defeat defuses every remaining ladi and shockwave.
	for hazard in get_tree().get_nodes_in_group("boss_hazards"):
		hazard.queue_free()
	Burst.spawn(get_tree().current_scene, global_position + Vector2(0, -48), Color(1.0, 0.75, 0.25), "KHARA FALLS!", 70.0)
	_update_feedback()
	died.emit()


func _process_death(delta: float) -> void:
	_death_time += delta
	_update_art()
	if fmod(_death_time, 0.25) < delta:
		Burst.spawn(get_tree().current_scene, global_position + Vector2(randf_range(-30, 30), randf_range(-80, -10)), Color(1.0, 0.6, 0.2), "", 30.0)
	if _death_time >= 1.4:
		queue_free()


func _update_feedback() -> void:
	visual.scale.x = float(facing)
	var tint := Color(1.25, 0.85, 0.85) if is_phase_two() else Color.WHITE
	var hint := "WATCHING"
	var gada_angle := 0.35
	match state:
		State.INTRO:
			hint = "KHARA BLOCKS THE PATH"
		State.APPROACH:
			hint = "APPROACHING"
			gada_angle = 0.35 + sin(_anim_time * 8.0) * 0.1
		State.SLAM_WINDUP:
			var progress := 1.0 - clampf(state_remaining / current_slam_windup(), 0.0, 1.0)
			tint = Color(2.0, 1.2, 0.35)
			hint = "GADA RAISED!"
			gada_angle = lerpf(0.35, -2.4, minf(progress * 1.6, 1.0)) + sin(_anim_time * 40.0) * 0.04 * progress
		State.SLAM_ACTIVE:
			tint = Color(2.2, 0.4, 0.3)
			hint = "SLAM!"
			gada_angle = 1.05
		State.SLAM_RECOVERY:
			tint = Color(0.7, 0.75, 0.85)
			hint = "STUCK - STRIKE NOW"
			gada_angle = 1.05 - clampf(1.0 - state_remaining / current_slam_recovery(), 0.0, 1.0) * 0.4
		State.LADI_CAST:
			tint = Color(1.7, 1.55, 0.6)
			hint = "LIGHTING LADI!"
			gada_angle = 1.3
		State.LADI_RECOVERY:
			hint = "FIREWORKS!"
		State.PHASE_SHIFT:
			tint = Color(2.0, 0.5, 0.4) if int(_anim_time * 10.0) % 2 == 0 else Color(1.3, 0.7, 0.6)
			hint = "ENRAGED!"
			gada_angle = -1.6
		State.DEAD:
			hint = "DEFEATED"
	if _hit_flash_remaining > 0.0:
		tint = Color(2.2, 2.2, 2.2)
	visual.modulate = Color(tint, visual.modulate.a)
	gada.rotation = gada_angle
	_update_art()
	status.text = hint
	status.modulate = SLAM_COLOR if state == State.SLAM_WINDUP else (LADI_COLOR if state == State.LADI_CAST else Color.WHITE)
	queue_redraw()


func _update_art() -> void:
	var animation: StringName = &"idle"
	match state:
		State.INTRO: animation = &"intro_roar"
		State.APPROACH: animation = &"walk"
		State.SLAM_WINDUP: animation = &"slam_windup"
		State.SLAM_ACTIVE: animation = &"slam_impact"
		State.SLAM_RECOVERY: animation = &"slam_recovery"
		State.LADI_CAST: animation = &"ladi_cast"
		State.LADI_RECOVERY: animation = &"ladi_recovery"
		State.PHASE_SHIFT: animation = &"phase_shift_roar"
		State.DEAD: animation = &"death"
	if art.animation != animation:
		art.play(animation)
	if state not in [State.IDLE, State.APPROACH]:
		# Pose timing follows combat, including tuned phase-two durations.
		art.pause()
		var progress := _death_time / 1.4 if state == State.DEAD else 1.0 - state_remaining / maxf(_state_duration, 0.001)
		var count := art.sprite_frames.get_frame_count(animation)
		art.frame = clampi(int(progress * count), 0, count - 1)
	_update_gada_art()


func _update_gada_art() -> void:
	var frames: Array = _attachment_frames.get(art.animation, [])
	if art.frame >= frames.size():
		gada.hide()
		return
	var attachment: Dictionary = frames[art.frame]
	var hand: Array = attachment["hand_from_anchor_px"]
	gada.position = Vector2(float(hand[0]), float(hand[1])) * 0.5
	gada.rotation = deg_to_rad(float(attachment["rotation_degrees"]))
	gada.visible = attachment["visible"]


func _draw() -> void:
	if state == State.SLAM_WINDUP:
		# Ground danger zone matching the slam hitbox fills as the wind-up ends.
		var progress := 1.0 - clampf(state_remaining / current_slam_windup(), 0.0, 1.0)
		var near := facing * (slam_reach - slam_hitbox.x * 0.5)
		var width := slam_hitbox.x
		var left := near if facing > 0 else near - width
		draw_rect(Rect2(left, -slam_hitbox.y, width, slam_hitbox.y), Color(SLAM_COLOR, 0.04 + 0.08 * progress))
		draw_rect(Rect2(left, -slam_hitbox.y, width, slam_hitbox.y), Color(SLAM_COLOR, 0.35 + 0.4 * progress), false, 2.0)
		draw_rect(Rect2(left, -6, width, 6), Color(SLAM_COLOR, 0.5))
		var filled := width * progress
		draw_rect(Rect2(left if facing > 0 else left + width - filled, -6, filled, 6), SLAM_COLOR)
	elif state == State.LADI_CAST:
		var origin := Vector2(facing * ladi_origin_offset, -8)
		draw_circle(origin, 5.0 + 3.0 * absf(sin(_anim_time * 25.0)), LADI_COLOR)
	if is_phase_two() and state != State.DEAD:
		for index in range(5):
			var x := -26.0 + index * 13.0
			var flicker := 8.0 + 6.0 * absf(sin(_anim_time * 9.0 + index * 1.3))
			draw_colored_polygon(PackedVector2Array([Vector2(x - 5, -92), Vector2(x, -92 - flicker), Vector2(x + 5, -92)]), Color(1.0, 0.35, 0.15, 0.75))
