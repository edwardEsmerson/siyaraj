extends Node2D
## Isolated encounter for tuning ground patrol and homing shots.

var _restarting: bool = false

@onready var player: CharacterBody2D = $Player


func _ready() -> void:
	player.died.connect(_restart)
	$GroundShooter.died.connect(func() -> void:
		$HUD/CombatStatus.text = "Shooter defeated! R to replay."
	)


func _process(_delta: float) -> void:
	$HUD/HealthStatus.text = "Siya health: %d/%d" % [player.health, player.max_health]
	if player.global_position.y > 580.0 and not _restarting:
		player.die()


func _restart() -> void:
	if _restarting:
		return
	_restarting = true
	get_tree().call_deferred("reload_current_scene")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		_restart()
