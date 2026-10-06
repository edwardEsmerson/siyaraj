extends Node2D
## Isolated Ravan encounter with the three-weapon player. Not part of level progression.

var _restarting: bool = false

@onready var player: CharacterBody2D = $Player
@onready var ravan: Node2D = $Ravan


func _ready() -> void:
	player.died.connect(_restart)
	ravan.exposure_started.connect(func() -> void:
		$HUD/CombatStatus.text = "His navel is open: strike the amrit!"
	)
	ravan.exposure_ended.connect(func() -> void:
		$HUD/CombatStatus.text = "Hit the glowing head while it lunges."
	)
	ravan.phase_changed.connect(func(phase: int) -> void:
		$HUD/CombatStatus.text = "Phase %d. Watch the lit heads and find the safe lanes." % phase
	)
	ravan.fury_started.connect(func() -> void:
		$HUD/CombatStatus.text = "DASHANAN FURY: stand in the teal lanes."
	)
	ravan.defeated.connect(func() -> void:
		$HUD/CombatStatus.text = "Ravan defeated! R to replay."
	)


func _process(_delta: float) -> void:
	$HUD/HealthStatus.text = "Siya health: %d/%d" % [player.health, player.max_health]
	var chakri := "ready" if player.chakri_cooldown_remaining <= 0.0 else "%ds" % ceili(player.chakri_cooldown_remaining)
	$HUD/WeaponStatus.text = "Skyshot %d/5    Chakri %s" % [player.skyshot_ammo, chakri]
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
