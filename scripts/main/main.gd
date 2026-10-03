extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var player_spawn: Marker2D = $TestCourse/PlayerSpawn
@onready var input_status: Label = $HUD/InputStatus


func _ready() -> void:
	player.global_position = player_spawn.global_position


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()
		return
	for action in [&"move_left", &"move_right", &"jump", &"dash", &"attack"]:
		if event.is_action_pressed(action):
			input_status.text = "Input received: %s" % action
			break
