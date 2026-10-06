extends "res://scripts/combat/enemy_projectile.gd"
## Limited steering lets fast movement evade a shot. World collisions still stop it.

@export var turn_speed: float = 2.4

var target: CharacterBody2D


func _on_dodged() -> void:
	# A dodged bolt stops steering, so it cannot circle back harmlessly through Siya.
	target = null


func _update_direction(delta: float) -> void:
	if is_instance_valid(target) and target.is_inside_tree() and target.health > 0:
		var toward := target.global_position + Vector2(0, -20) - global_position
		if not toward.is_zero_approx():
			var turn := clampf(direction.angle_to(toward), -maxf(turn_speed, 0.0) * delta, maxf(turn_speed, 0.0) * delta)
			direction = direction.rotated(turn).normalized()
	queue_redraw()


func _draw() -> void:
	var side := direction.orthogonal()
	draw_circle(-direction * 12.0, 4.0, Color(0.7, 0.3, 1.0, 0.55))
	draw_circle(-direction * 20.0, 2.5, Color(0.7, 0.3, 1.0, 0.25))
	draw_colored_polygon(PackedVector2Array([direction * 9.0, -direction * 7.0 + side * 6.0, -direction * 3.0, -direction * 7.0 - side * 6.0]), Color(0.8, 0.4, 1.0))
	draw_circle(Vector2.ZERO, 3.5, Color(1.0, 0.85, 1.0))
