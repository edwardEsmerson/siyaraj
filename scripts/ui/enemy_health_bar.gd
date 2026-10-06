extends Node2D
## World-space health feedback shared by ordinary enemies.

@export var bar_width: float = 40.0
var health_fraction: float = 1.0
var _enemy: CharacterBody2D


func _ready() -> void:
	_enemy = get_parent()
	_enemy.health_changed.connect(_update_health)
	_enemy.died.connect(hide)
	# Child nodes become ready before the controller initializes its health.
	_enemy.ready.connect(_on_enemy_ready, CONNECT_ONE_SHOT)


func _on_enemy_ready() -> void:
	_update_health(_enemy.health)


func _update_health(remaining: int) -> void:
	health_fraction = clampf(float(remaining) / maxf(_enemy.max_health, 1.0), 0.0, 1.0)
	visible = remaining > 0
	queue_redraw()


func _draw() -> void:
	var background := Rect2(-bar_width * 0.5 - 1, -1, bar_width + 2, 7)
	draw_rect(background.grow(1), Color(0, 0, 0, 0.45))
	draw_rect(background, Color("ead6a3"))
	draw_rect(Rect2(-bar_width * 0.5, 0, bar_width, 5), Color("271d2b"))
	if health_fraction > 0.0:
		draw_rect(Rect2(-bar_width * 0.5, 0, bar_width * health_fraction, 5), Color("e86b65"))
