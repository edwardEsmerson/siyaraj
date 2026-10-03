extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var player_spawn: Marker2D = $TestCourse/PlayerSpawn
@onready var input_status: Label = $HUD/InputStatus
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	player.global_position = player_spawn.global_position
	camera.position.x = player.global_position.x
	camera.limit_left = 0
	camera.limit_right = 3400
	camera.limit_top = 0
	camera.limit_bottom = 540


func _process(_delta: float) -> void:
	# Horizontal follow keeps the extended playground usable; vertical tuning comes next.
	camera.position.x = player.global_position.x


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()
		return
	for action in [&"move_left", &"move_right", &"jump", &"dash", &"attack"]:
		if event.is_action_pressed(action):
			input_status.text = "Input received: %s" % action
			break
