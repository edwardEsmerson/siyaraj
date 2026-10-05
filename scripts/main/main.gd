extends Node2D

@export var fall_boundary: float = 580.0
@export var camera_look_ahead: float = 20.0
@export var camera_follow_speed: float = 8.0
@export var restart_delay: float = 0.0

@onready var player: CharacterBody2D = $Player
@onready var player_spawn: Marker2D = $TestCourse/PlayerSpawn
@onready var input_status: Label = $HUD/InputStatus
@onready var dash_status: Label = $HUD/DashStatus
@onready var health_status: Label = $HUD/HealthStatus
@onready var combat_status: Label = $HUD/CombatStatus
@onready var camera: Camera2D = $Camera2D

var _restarting: bool = false
var completed: bool = false
var elapsed: float = 0.0
var _course_width: int = 4200
@onready var course: Node2D = $TestCourse


func _ready() -> void:
	player.global_position = player_spawn.global_position
	player.died.connect(_restart)
	camera.position.x = player.global_position.x
	camera.limit_left = 0
	if course.has_signal("finished"):
		_course_width = course.COURSE_WIDTH
		course.finished.connect(_finish_course)
	camera.limit_right = _course_width
	camera.limit_top = 0
	camera.limit_bottom = 540
	camera.reset_smoothing()
	var enemy := $TestCourse/Enemy
	var encounter_name: String = enemy.enemy_name
	enemy.died.connect(func() -> void:
		combat_status.text = "%s defeated! Exit open; reach the flag." % encounter_name if course.has_signal("finished") else "%s defeated! R to replay." % encounter_name
	)


func _process(delta: float) -> void:
	if not completed and not _restarting:
		elapsed += delta
	if course.has_method("hint_at"):
		$HUD/Milestone.text = course.hint_at(player.global_position.x)
		$HUD/InputStatus.text = "%.1f s" % elapsed
	# Fixed vertical framing prevents jump/dash motion from moving the landing floor.
	# Ease horizontal look-ahead when turning so the camera does not snap.
	var target_x := clampf(player.global_position.x + player.facing_direction * camera_look_ahead, 480.0, _course_width - 480.0)
	camera.position.x = lerpf(camera.position.x, target_x, 1.0 - exp(-camera_follow_speed * delta))
	health_status.text = "Siya health: %d/%d" % [player.health, player.max_health]
	if player.is_on_floor():
		dash_status.text = "Rocket dash: jump to dash"
	else:
		dash_status.text = "Rocket dash: READY" if player.dash_available else "Rocket dash: land to recharge"
	dash_status.modulate = Color(1.0, 0.72, 0.2) if player.dash_available else Color(0.65, 0.68, 0.74)
	if _restarting:
		return
	if player.global_position.y > fall_boundary:
		player.die()


func _restart() -> void:
	if _restarting:
		return
	_restarting = true
	if restart_delay > 0.0 and player.state == player.State.DEAD:
		$HUD/DeathMessage.visible = true
		await get_tree().create_timer(restart_delay).timeout
	# Scene changes are deferred so death can also be requested during a physics tick.
	get_tree().call_deferred("reload_current_scene")


func _finish_course() -> void:
	if completed or _restarting:
		return
	completed = true
	$HUD/Completion.visible = true
	$HUD/Completion/Message.text = "COURSE COMPLETE\nGuard defeated / %.1f seconds\nR to replay" % elapsed
	combat_status.text = "Guard defeated. Finish reached!"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		_restart()
		return
	if course.has_method("hint_at"):
		return
	for action in [&"move_left", &"move_right", &"jump", &"dash", &"attack"]:
		if event.is_action_pressed(action):
			input_status.text = "Input received: %s" % action
			break
