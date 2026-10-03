extends Node2D

@export var fall_boundary: float = 580.0
@export var camera_look_ahead: float = 140.0
@export var camera_follow_speed: float = 8.0

@onready var player: CharacterBody2D = $Player
@onready var player_spawn: Marker2D = $TestCourse/PlayerSpawn
@onready var input_status: Label = $HUD/InputStatus
@onready var dash_status: Label = $HUD/DashStatus
@onready var camera: Camera2D = $Camera2D

var _restarting: bool = false


func _ready() -> void:
	player.global_position = player_spawn.global_position
	player.died.connect(_restart)
	camera.position.x = player.global_position.x
	camera.limit_left = 0
	camera.limit_right = 4200
	camera.limit_top = 0
	camera.limit_bottom = 540
	camera.reset_smoothing()


func _process(delta: float) -> void:
	# Fixed vertical framing prevents jump/dash motion from moving the landing floor.
	# Ease horizontal look-ahead when turning so the camera does not snap.
	var target_x := clampf(player.global_position.x + player.facing_direction * camera_look_ahead, 480.0, 3720.0)
	camera.position.x = lerpf(camera.position.x, target_x, 1.0 - exp(-camera_follow_speed * delta))
	dash_status.text = "Rocket dash: READY" if player.dash_available else "Rocket dash: land to recharge"
	dash_status.modulate = Color(1.0, 0.72, 0.2) if player.dash_available else Color(0.65, 0.68, 0.74)
	if player.global_position.y > fall_boundary:
		player.die()


func _restart() -> void:
	if _restarting:
		return
	_restarting = true
	# Scene changes are deferred so death can also be requested during a physics tick.
	get_tree().call_deferred("reload_current_scene")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		_restart()
		return
	for action in [&"move_left", &"move_right", &"jump", &"dash", &"attack"]:
		if event.is_action_pressed(action):
			input_status.text = "Input received: %s" % action
			break
