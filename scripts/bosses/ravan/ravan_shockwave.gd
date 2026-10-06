extends Node2D
## Low roar shockwave that rolls along the floor. Jump over it; walls stop it.
const Burst = preload("res://scripts/effects/burst.gd")
const RavanFx = preload("res://scripts/bosses/ravan/ravan_fx.gd")

const PLAYER_BODY_MASK: int = 2
const WORLD_MASK: int = 1

var direction: int = 1
var speed: float = 280.0
var size: Vector2 = Vector2(26, 22)
var damage: int = 1
var knockback: Vector2 = Vector2(200, -200)
var lifetime: float = 3.5
var color: Color = Color(1.0, 0.85, 0.2)
var hit_player: bool = false
var _age: float = 0.0
var _shape := RectangleShape2D.new()
var _has_art: bool = false


func _ready() -> void:
	add_to_group("ravan_hazards")
	add_to_group("ravan_attacks")
	add_to_group("ravan_shockwaves")
	z_index = 3
	# Generated wave art (rolls right; flipped for waves rolling left), feet on the floor.
	var art := RavanFx.sprite(&"shockwave")
	if art != null:
		_has_art = true
		art.flip_h = direction < 0
		if art.flip_h:
			art.offset.x = -(art.sprite_frames.get_frame_texture(&"shockwave", 0).get_width() - RavanFx.pivot(&"shockwave").x)
		add_child(art)


func _physics_process(delta: float) -> void:
	_age += delta
	var step := direction * speed * delta
	# The wave hugs the floor; a solid wall or ledge face ahead ends it.
	var from := global_position + Vector2(0, -8)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(step + direction * size.x * 0.5, 0), WORLD_MASK)
	if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		Burst.spawn(get_tree().current_scene, global_position + Vector2(0, -10), color, "", 16.0)
		queue_free()
		return
	global_position.x += step
	_hurt_overlaps()
	if _age >= lifetime:
		queue_free()
	queue_redraw()


func _hurt_overlaps() -> void:
	_shape.size = size
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = _shape
	params.transform = Transform2D(0.0, global_position + Vector2(0, -size.y * 0.5))
	params.collision_mask = PLAYER_BODY_MASK
	for result in get_world_2d().direct_space_state.intersect_shape(params):
		var target: Node = result.collider
		if not target.is_in_group("players") or not target.has_method("take_damage"):
			continue
		var health_before: int = target.health
		target.take_damage(damage, Vector2(knockback.x * direction, knockback.y))
		if target.health < health_before:
			hit_player = true
			Burst.spawn(get_tree().current_scene, (target as Node2D).global_position + Vector2(0, -20), color, "ROAR!")


func _draw() -> void:
	if _has_art:
		return
	var half := size.x * 0.5
	var crest := PackedVector2Array([Vector2(-half, 0), Vector2(-half * 0.3, -size.y), Vector2(half * 0.4 * direction, -size.y * 0.6), Vector2(half, 0)])
	draw_colored_polygon(crest, color)
	var trail := color
	for index in range(3):
		trail.a = 0.45 - index * 0.13
		var back := -direction * (half + 8.0 + index * 10.0)
		draw_line(Vector2(back, -2), Vector2(back, -size.y * (0.7 - index * 0.2)), trail, 3.0)
