extends Node2D
## Flat dev arena for fighting one enemy in isolation. Choose the encounter and
## player loadout in the inspector, then press F6. Regression checks select the
## encounter through `next_encounter` before loading the scene.

enum Encounter { NONE, GUARD, BRUTE, FLYER, SHOOTER }

const SPARKLER_PLAYER = preload("res://scenes/player/player.tscn")
const THREE_WEAPON_PLAYER = preload("res://scenes/player/forest_player.tscn")
const ENCOUNTERS := {
	Encounter.GUARD: [preload("res://scenes/enemies/enemy.tscn"), Vector2(500, 430), "Guard",
		"Land three sparkler hits. Move or dash away during the orange tell."],
	Encounter.BRUTE: [preload("res://scenes/enemies/brute.tscn"), Vector2(500, 430), "Brute",
		"Six hits; its heavy strike deals two damage.\nStep back during the long orange wind-up. Strike during recovery."],
	Encounter.FLYER: [preload("res://scenes/enemies/flying_enemy.tscn"), Vector2(500, 385), "Flyer",
		"Orange charge: move away from the aimed shot.\nJump and press J to hit the flyer. Three hits defeat it."],
	Encounter.SHOOTER: [preload("res://scenes/enemies/ground_shooter.tscn"), Vector2(540, 430), "Shooter",
		"Purple bolts follow you: jump past them or dash through them.\nJ interrupts the charge. Three hits defeat the shooter."],
}

## Overrides the inspector choice when set; kept across R/death reloads.
static var next_encounter: int = -1

@export var encounter: Encounter = Encounter.GUARD
@export var three_weapons: bool = false
@export var fall_boundary: float = 580.0

var player: CharacterBody2D
var enemy: CharacterBody2D
var _restarting: bool = false


func _ready() -> void:
	var chosen: int = next_encounter if next_encounter >= 0 else encounter
	player = (THREE_WEAPON_PLAYER if three_weapons else SPARKLER_PLAYER).instantiate()
	player.name = "Player"
	player.position = $PlayerSpawn.position
	add_child(player)
	player.died.connect(_restart)
	$HUD/Hint.text = "No enemy selected. Pick an encounter on the Sandbox root."
	if ENCOUNTERS.has(chosen):
		var setup: Array = ENCOUNTERS[chosen]
		enemy = setup[0].instantiate()
		enemy.name = "Enemy"
		enemy.position = setup[1]
		add_child(enemy)
		$HUD/Title.text = "SIYARAJ / sandbox / %s" % setup[2].to_lower()
		$HUD/Hint.text = setup[3]
		enemy.died.connect(func() -> void:
			$HUD/CombatStatus.text = "%s defeated! R to replay." % setup[2]
		)


func _process(_delta: float) -> void:
	var status := "Siya health: %d/%d" % [player.health, player.max_health]
	if three_weapons:
		var cooldown: String = "READY" if player.chakri_cooldown_remaining <= 0.0 else "%ds" % ceili(player.chakri_cooldown_remaining)
		status += "    Skyshot: %d/5    Chakri: %s" % [player.skyshot_ammo, cooldown]
	$HUD/HealthStatus.text = status
	if player.global_position.y > fall_boundary and not _restarting:
		player.die()


func _restart() -> void:
	if _restarting:
		return
	_restarting = true
	if player.state == player.State.DEAD:
		get_node("/root/PlaytestNavigation").call_deferred("respawn", self)
		return
	# Deferred so death can also be requested during a physics tick.
	get_tree().call_deferred("reload_current_scene")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		_restart()
