extends Node2D
## Telegraphed damage area. It warns first, then hurts the player on active ticks.
## Player damage protection stops one hazard dealing repeated damage.
const Burst = preload("res://scripts/effects/burst.gd")

signal activated
signal finished

## BEAM extends along local +X from the origin (fire breath). COLUMN and PILLAR
## rise from the origin, which sits on the floor (lightning and Dashanan Fury).
enum Style { BEAM, COLUMN, PILLAR }

const PLAYER_BODY_MASK: int = 2

var style: Style = Style.COLUMN
var size: Vector2 = Vector2(44, 400)
var color: Color = Color(0.35, 0.85, 1.0)
var telegraph_time: float = 0.6
var active_time: float = 0.2
var damage: int = 1
var knockback: Vector2 = Vector2(220, -160)
var age: float = 0.0
var hit_player: bool = false
var _was_active: bool = false
var _shape := RectangleShape2D.new()


func _ready() -> void:
	add_to_group("ravan_hazards")
	add_to_group("ravan_attacks")
	z_index = 3


func is_telegraphing() -> bool:
	return age < telegraph_time


func is_active() -> bool:
	return age >= telegraph_time and age < telegraph_time + active_time


func local_rect() -> Rect2:
	if style == Style.BEAM:
		return Rect2(0.0, -size.y * 0.5, size.x, size.y)
	return Rect2(-size.x * 0.5, -size.y, size.x, size.y)


func _physics_process(delta: float) -> void:
	age += delta
	if is_active():
		if not _was_active:
			_was_active = true
			activated.emit()
		_hurt_overlaps()
	elif age >= telegraph_time + active_time:
		set_physics_process(false)
		finished.emit()
		queue_free()
	queue_redraw()


func _hurt_overlaps() -> void:
	var rect := local_rect()
	_shape.size = rect.size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape
	query.transform = global_transform * Transform2D(0.0, rect.get_center())
	query.collision_mask = PLAYER_BODY_MASK
	for result in get_world_2d().direct_space_state.intersect_shape(query):
		var target: Node = result.collider
		if not target.is_in_group("players") or not target.has_method("take_damage"):
			continue
		var health_before: int = target.health
		var side := signf((target as Node2D).global_position.x - global_position.x)
		if is_zero_approx(side):
			side = 1.0
		target.take_damage(damage, Vector2(knockback.x * side, knockback.y))
		if target.health < health_before:
			hit_player = true
			Burst.spawn(get_tree().current_scene, (target as Node2D).global_position + Vector2(0, -20), color, "BURN!" if style != Style.COLUMN else "ZAP!")


func _draw() -> void:
	var rect := local_rect()
	var pulse := 0.5 + 0.5 * sin(age * 18.0)
	if is_telegraphing():
		var progress := clampf(age / maxf(telegraph_time, 0.001), 0.0, 1.0)
		var warn := color
		warn.a = 0.08 + 0.14 * progress
		draw_rect(rect, warn)
		warn.a = 0.45 + 0.4 * pulse
		draw_rect(rect, warn, false, 2.0)
		match style:
			Style.BEAM:
				draw_line(Vector2.ZERO, Vector2(size.x, 0), warn, 2.0)
			Style.COLUMN:
				draw_arc(Vector2(0, -4), 10.0 + 12.0 * progress, 0.0, TAU, 24, warn, 2.0)
				for index in range(int(size.y / 24.0)):
					draw_line(Vector2(0, -index * 24.0 - 4.0), Vector2(0, -index * 24.0 - 14.0), warn, 2.0)
			Style.PILLAR:
				# Bright floor stripe: this lane is about to burn.
				var stripe := color
				stripe.a = 0.6 + 0.4 * pulse
				draw_rect(Rect2(-size.x * 0.5, -6.0, size.x, 6.0), stripe)
	elif is_active():
		var hot := color
		hot.a = 0.85
		draw_rect(rect, hot)
		var core := Color(1.0, 0.95, 0.75, 0.9)
		if style == Style.BEAM:
			draw_rect(Rect2(0.0, -size.y * 0.18, size.x, size.y * 0.36), core)
		else:
			draw_rect(Rect2(-size.x * 0.18, -size.y, size.x * 0.36, size.y), core)
