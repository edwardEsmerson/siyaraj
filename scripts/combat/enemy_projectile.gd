extends CharacterBody2D
## Straight shot. Swept body movement catches walls and players between frames.
const BURST = preload("res://scripts/effects/burst.gd")

@export var speed: float = 220.0
@export var damage: int = 1
@export var lifetime: float = 3.0
@export var knockback: Vector2 = Vector2(180, -120)

var direction: Vector2 = Vector2.RIGHT
var _remaining: float = 0.0


func _ready() -> void:
	direction = direction.normalized()
	_remaining = lifetime


func _physics_process(delta: float) -> void:
	var step := minf(delta, _remaining)
	_update_direction(step)
	velocity = direction * speed
	var collision := move_and_collide(velocity * step)
	if collision != null and _is_dodged_by(collision.get_collider()):
		collision = move_and_collide(collision.get_remainder())
	_remaining -= delta
	if collision != null:
		var target := collision.get_collider() as Node2D
		if is_instance_valid(target) and target.is_in_group("players") and target.has_method("take_damage"):
			var health_before: int = target.health
			var side := 1.0 if direction.x >= 0.0 else -1.0
			target.take_damage(damage, Vector2(knockback.x * side, knockback.y))
			if target.health < health_before:
				BURST.spawn(get_tree().current_scene, global_position, Color(1.0, 0.4, 0.2), "HIT!")
		set_physics_process(false)
		queue_free()
	elif _remaining <= 0.0:
		queue_free()


## A dashing player passes through the shot, which then ignores them and flies on.
func _is_dodged_by(collider: Object) -> bool:
	var player := collider as Node2D
	if not is_instance_valid(player) or not player.is_in_group("players") or not player.has_method("is_invulnerable"):
		return false
	if not player.is_invulnerable():
		return false
	add_collision_exception_with(player)
	_on_dodged()
	return true


func _on_dodged() -> void:
	pass


func _update_direction(_delta: float) -> void:
	pass
