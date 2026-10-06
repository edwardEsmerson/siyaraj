extends CharacterBody2D
## Swept projectile collision prevents fast shots passing through thin walls.
const Burst = preload("res://scripts/effects/burst.gd")

@export var speed: float = 640.0
@export var damage: int = 2
@export var lifetime: float = 1.2
var direction: int = 1
var age: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 4
	z_index = 5
	add_to_group("skyshot_projectiles")
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 4.0
	collider.shape = shape
	add_child(collider)


func _physics_process(delta: float) -> void:
	age += delta
	var collision := move_and_collide(Vector2(direction * speed * delta, 0))
	if collision != null:
		var target: Object = collision.get_collider()
		var word := "POP!"
		var impulse := Vector2(direction * 160.0, -100)
		if target.has_method("take_weapon_damage"):
			target.take_weapon_damage(damage, impulse, "skyshot")
		elif target.has_method("take_damage"):
			target.take_damage(damage, impulse)
		Burst.spawn(get_tree().current_scene, global_position, Color(1, 0.65, 0.2), word, 24)
		queue_free()
		return
	if age >= lifetime:
		Burst.spawn(get_tree().current_scene, global_position, Color(1, 0.65, 0.2), "", 12)
		queue_free()
	queue_redraw()


func _draw() -> void:
	draw_line(Vector2(-direction * 24, 0), Vector2.ZERO, Color(1, 0.4, 0.2, 0.6), 3)
	draw_circle(Vector2.ZERO, 6, Color(1, 0.7, 0.15, 0.5))
	draw_circle(Vector2.ZERO, 3, Color(1, 0.95, 0.7))
	for index in range(3):
		var offset := Vector2(-direction * (12 + index * 7), sin(age * 35 + index * 2) * 4)
		draw_circle(offset, 1.5, Color(1, 0.6, 0.2, 0.6))
