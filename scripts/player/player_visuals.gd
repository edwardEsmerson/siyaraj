extends Node2D
## Presentation only: movement, damage windows and weapon costs remain controller-owned.

const Melee = preload("res://scripts/combat/melee_attack.gd")
const STORY_ACTIONS: Array[StringName] = [&"light_diya", &"victory", &"talk", &"shocked"]

var _weapon_action: StringName = &""
var _weapon_duration: float = 0.0
var _weapon_remaining: float = 0.0
var _story_action: StringName = &""
var _story_remaining: float = 0.0
var _victory_pending: bool = false
var _was_grounded: bool = false
var _was_dashing: bool = false
var _landing_remaining: float = 0.0
var _brake_remaining: float = 0.0

@onready var player: CharacterBody2D = get_parent()
@onready var melee: Node2D = $"../Sparkler"
@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	# Read the final movement and melee phases for this tick, including dash cancellation.
	process_physics_priority = 20
	if player.has_signal("weapon_used"):
		player.connect("weapon_used", _on_weapon_used)
	_bind_scene_events.call_deferred()


func _bind_scene_events() -> void:
	var course := player.get_parent().get_node_or_null("TestCourse")
	if course != null and course.has_signal("finished"):
		course.connect("finished", _queue_victory)
	var boss := player.get_parent().get_node_or_null("TestCourse/Boss")
	if boss == null:
		boss = player.get_parent().get_node_or_null("Ravan")
	if boss != null and boss.has_signal("died"):
		boss.connect("died", _queue_victory)


func _queue_victory() -> void:
	_victory_pending = true


## Cutscene callers can use talk/shocked and clear them when their panel closes.
## Cosmetic poses yield immediately to movement, weapons, dash, hurt or death.
func play_story(action: StringName) -> void:
	if not STORY_ACTIONS.has(action) or player.state != player.State.NORMAL:
		return
	_story_action = action
	_story_remaining = 0.25 if action == &"light_diya" else 0.375
	if action == &"talk" or action == &"shocked":
		_story_remaining = INF
	sprite.play(action)
	sprite.set_frame_and_progress(0, 0.0)


func clear_story() -> void:
	_story_action = &""
	_story_remaining = 0.0


func _on_weapon_used(action: StringName, duration: float) -> void:
	_weapon_action = action
	_weapon_duration = duration
	_weapon_remaining = duration
	clear_story()


func _physics_process(delta: float) -> void:
	_weapon_remaining = maxf(_weapon_remaining - delta, 0.0)
	_story_remaining = maxf(_story_remaining - delta, 0.0)
	_landing_remaining = maxf(_landing_remaining - delta, 0.0)
	_brake_remaining = maxf(_brake_remaining - delta, 0.0)
	var grounded := player.is_on_floor()
	var dashing: bool = player.state == player.State.DASH
	if grounded and not _was_grounded:
		_landing_remaining = 0.08
	if _was_dashing and not dashing:
		_brake_remaining = 0.05
	_was_grounded = grounded
	_was_dashing = dashing

	var facing: int = player.facing_direction
	if dashing:
		facing = player._dash_direction
	elif melee.is_busy():
		facing = melee.direction
	sprite.flip_h = facing < 0
	# Common 160x128 canvas, feet at (64,112); mirror the offset with the art.
	sprite.offset = Vector2(16 * facing, -48)
	_update_blink()

	if player.state == player.State.DEAD:
		clear_story()
		_weapon_remaining = 0.0
		_play(&"death")
		return
	if player.state == player.State.HURT:
		clear_story()
		_weapon_remaining = 0.0
		_play(&"hurt")
		return
	if dashing:
		clear_story()
		_weapon_remaining = 0.0
		var elapsed: float = player.movement_settings.dash_duration - player._dash_remaining
		_pose(&"dash", 0 if elapsed < 0.05 else 1)
		return
	if melee.is_busy():
		clear_story()
		_weapon_remaining = 0.0
		var airborne := not grounded or player.velocity.y < 0.0
		var action: StringName = &"air_lash" if airborne else &"lash"
		var frame := 0 if melee.phase == Melee.Phase.WINDUP else 1
		if not airborne and melee.phase == Melee.Phase.RECOVERY:
			frame = 2
		_pose(action, frame)
		return
	if player.has_signal("weapon_used") and player.charging:
		clear_story()
		_play(&"chakri_charge")
		return
	if _weapon_remaining > 0.0:
		# Shots/spins already deal damage on input; show the release pose immediately.
		var elapsed := _weapon_duration - _weapon_remaining
		_pose(_weapon_action, 1 if elapsed < _weapon_duration * 0.5 else 2)
		return
	var moving := absf(player.velocity.x) > 10.0 or not grounded or player.velocity.y < 0.0
	if moving:
		clear_story()
	elif _victory_pending:
		_victory_pending = false
		play_story(&"victory")
	if _story_remaining > 0.0:
		_play(_story_action)
		return
	if _brake_remaining > 0.0:
		_pose(&"dash", 2)
	elif not grounded or player.velocity.y < 0.0:
		var vertical: float = player.velocity.y
		var frame := 3
		if vertical < player.movement_settings.jump_velocity * 0.75:
			frame = 0
		elif vertical < -40.0:
			frame = 1
		elif vertical <= 40.0:
			frame = 2
		_pose(&"jump", frame)
	elif _landing_remaining > 0.0:
		_pose(&"jump", 4)
	elif moving:
		_play(&"run")
	else:
		_play(&"idle")


func _update_blink() -> void:
	sprite.modulate = Color.WHITE
	if player.state == player.State.DEAD:
		return
	if player._hit_flash_remaining > 0.0:
		sprite.modulate = Color(2.0, 0.65, 0.65)
	elif player._protection_remaining > 0.0:
		sprite.modulate.a = 0.4 if int(player._protection_remaining * 15.0) % 2 == 0 else 1.0
	elif player.is_invulnerable():
		sprite.modulate = Color(1.35, 1.35, 1.35, 0.7)


func _play(action: StringName) -> void:
	if sprite.animation != action or not sprite.is_playing():
		# Non-looping actions hold their last pose instead of restarting.
		if sprite.animation == action and sprite.frame == sprite.sprite_frames.get_frame_count(action) - 1:
			return
		sprite.play(action)


func _pose(action: StringName, frame: int) -> void:
	sprite.animation = action
	sprite.pause()
	sprite.frame = frame
