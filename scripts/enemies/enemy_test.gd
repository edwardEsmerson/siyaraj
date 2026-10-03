extends Node2D

@onready var enemy: CharacterBody2D = $Enemy
@onready var health_label: Label = $HUD/Health
@onready var hit_button: Button = $HUD/TestHit


func _ready() -> void:
	health_label.text = "Enemy health: %d" % enemy.health
	enemy.health_changed.connect(func(remaining: int) -> void:
		health_label.text = "Enemy health: %d" % remaining
	)
	enemy.died.connect(func() -> void:
		hit_button.disabled = true
		health_label.text = "Enemy defeated. Reset to test again."
	)
	hit_button.pressed.connect(func() -> void:
		enemy.take_damage(1, Vector2(120, -100))
	)
	$HUD/Reset.pressed.connect(func() -> void:
		get_tree().reload_current_scene()
	)
