extends Node2D
## Swaminathan campaign finale, also available as a developer snapshot.

const ENDING: String = "res://scenes/main/ending.tscn"

var _restarting: bool = false
var completed: bool = false

@onready var player: CharacterBody2D = $Player
@onready var ravan: Node2D = $Ravan


func _ready() -> void:
	if not has_node("CampaignFlow"):
		var flow := preload("res://scenes/main/campaign_victory.tscn").instantiate()
		flow.boss_path = NodePath("../Ravan")
		flow.next_level = ENDING
		flow.destination_name = "Raj's rescue"
		add_child(flow)
	player.died.connect(_restart)
	ravan.head_lost.connect(func(_index: int, remaining: int) -> void:
		$HUD/CombatStatus.text = "A head falls! %d left." % remaining if remaining > 0 else "The last head falls!"
	)
	ravan.fury_ended.connect(func() -> void:
		$HUD/CombatStatus.text = "He is spent: strike him now!"
	)
	ravan.phase_changed.connect(func(phase: int) -> void:
		$HUD/CombatStatus.text = "Phase %d. Watch the lit heads and find the safe lanes." % phase
	)
	ravan.fury_started.connect(func() -> void:
		$HUD/CombatStatus.text = "DASHANAN FURY: stand in the teal lanes."
	)
	ravan.died.connect(_on_ravan_defeated)


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
	if completed and event.is_action_pressed("ui_accept"):
		if has_node("CampaignFlow"):
			return  # Campaign dialogue and developer snapshot routing own the exit.
		get_viewport().set_input_as_handled()
		PlaytestNavigation.start_level(ENDING)
		return
	if event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		_restart()


func _on_ravan_defeated() -> void:
	completed = true
	$HUD/CombatStatus.text = "Swaminathan defeated! Enter: continue to the ending / R: replay."
