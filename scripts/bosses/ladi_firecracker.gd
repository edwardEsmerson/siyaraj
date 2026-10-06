extends Node2D
## A ladi: a string of firecrackers laid on the ground. After its fuse burns, the
## crackers pop one after another, travelling away from the origin in `direction`.
## The root sits on the ground at the lit (origin) end. Hazards never move bodies.
const Burst = preload("res://scripts/effects/burst.gd")

signal detonation_started
signal finished

@export var direction: int = 1
@export var fuse_time: float = 1.2
@export var segment_count: int = 12
@export var segment_spacing: float = 36.0
@export var segment_interval: float = 0.06
@export var blast_time: float = 0.16
## Kept below Siya's ~47 px jump apex so a timed jump clears each pop.
@export var blast_size: Vector2 = Vector2(34, 18)
@export var damage: int = 1
@export var knockback: Vector2 = Vector2(220, -260)
@export var target_mask: int = 2
@export var world_mask: int = 1

const FUSE_COLOR := Color(1.0, 0.9, 0.2)
const CRACKER_COLOR := Color(0.85, 0.12, 0.18)
const CORD_COLOR := Color(0.35, 0.08, 0.1)
const ASH_COLOR := Color(0.25, 0.22, 0.22)
const BLAST_COLOR := Color(1.0, 0.75, 0.25)

var age: float = 0.0
var _hit_targets: Dictionary = {}
var _ignited: Array[bool] = []
var _detonating: bool = false


func _ready() -> void:
	direction = 1 if direction >= 0 else -1
	z_index = 4
	add_to_group("boss_hazards")
	add_to_group("boss_ladis")
	_truncate_at_walls()
	_ignited.resize(segment_count)
	_ignited.fill(false)


## Keep the string inside the arena: stop before the first solid wall.
func _truncate_at_walls() -> void:
	if not is_inside_tree():
		return
	var from := global_position + Vector2(0, -blast_size.y * 0.5)
	var to := from + Vector2(direction * segment_spacing * segment_count, 0)
	var query := PhysicsRayQueryParameters2D.create(from, to, world_mask)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var room := absf(hit.position.x - from.x) - blast_size.x * 0.5
		segment_count = clampi(floori(room / segment_spacing + 0.5), 1, segment_count)


func segment_offset(index: int) -> float:
	return direction * (index + 0.5) * segment_spacing


func segment_global_position(index: int) -> Vector2:
	return global_position + Vector2(segment_offset(index), 0)


func is_lit() -> bool:
	return age >= fuse_time


func ignite_time(index: int) -> float:
	return fuse_time + index * segment_interval


func is_segment_blasting(index: int) -> bool:
	var t := age - ignite_time(index)
	return t >= 0.0 and t < blast_time


func is_segment_spent(index: int) -> bool:
	return age - ignite_time(index) >= blast_time


func total_duration() -> float:
	return ignite_time(segment_count - 1) + blast_time


func _physics_process(delta: float) -> void:
	age += delta
	if not _detonating and is_lit():
		_detonating = true
		detonation_started.emit()
	for index in range(segment_count):
		if not is_segment_blasting(index):
			continue
		if not _ignited[index]:
			_ignited[index] = true
			Burst.spawn(get_tree().current_scene, segment_global_position(index) + Vector2(0, -10), BLAST_COLOR, "PATAKA!" if index % 4 == 0 else "", 16.0)
		_hit_overlaps(index)
	if age >= total_duration() + 0.35:
		finished.emit()
		queue_free()
	queue_redraw()


func _hit_overlaps(index: int) -> void:
	var shape := RectangleShape2D.new()
	shape.size = blast_size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, segment_global_position(index) + Vector2(0, -blast_size.y * 0.5))
	query.collision_mask = target_mask
	for result in get_world_2d().direct_space_state.intersect_shape(query):
		var target: Node = result.collider
		var id := target.get_instance_id()
		if _hit_targets.has(id) or not target.has_method("take_damage"):
			continue
		_hit_targets[id] = true
		var health_before: int = target.health
		target.take_damage(damage, Vector2(knockback.x * direction, knockback.y))
		if target.health < health_before:
			Burst.spawn(get_tree().current_scene, target.global_position + Vector2(0, -20), Color(1.0, 0.35, 0.2), "HIT!")


func _draw() -> void:
	var length := segment_count * segment_spacing
	var lit := is_lit()
	# Faint lane shows exactly how far the chain will travel.
	if not lit:
		var lane := FUSE_COLOR
		lane.a = 0.12 + 0.08 * sin(age * 14.0)
		var lane_x := 0.0 if direction > 0 else -length
		draw_rect(Rect2(lane_x, -blast_size.y, length, blast_size.y), lane)
	# Cord along the ground.
	draw_line(Vector2(0, -3), Vector2(direction * length, -3), CORD_COLOR if not lit else ASH_COLOR, 2.0)
	for index in range(segment_count):
		var x := segment_offset(index)
		if is_segment_blasting(index):
			var t := (age - ignite_time(index)) / blast_time
			var flash := BLAST_COLOR.lerp(Color.WHITE, 1.0 - t)
			draw_rect(Rect2(x - blast_size.x * 0.5, -blast_size.y, blast_size.x, blast_size.y), Color(flash, 0.85))
			draw_circle(Vector2(x, -blast_size.y * 0.5), blast_size.y * (0.6 + t * 0.5), Color(1, 1, 0.8, 1.0 - t))
			for spark in range(4):
				var angle := -PI * 0.15 - spark * PI * 0.23
				var tip := Vector2(x, -6) + Vector2(cos(angle), sin(angle)) * (10 + t * 18)
				draw_line(Vector2(x, -6), tip, Color(1, 0.6, 0.2, 1.0 - t), 2.0)
		elif is_segment_spent(index):
			draw_rect(Rect2(x - 5, -4, 10, 4), ASH_COLOR)
		else:
			# Unlit cracker: red tube with a gold wick. Alternating tilt reads as a string.
			var tilt := 2.0 if index % 2 == 0 else -2.0
			draw_colored_polygon(PackedVector2Array([Vector2(x - 4 + tilt, -14), Vector2(x + 4 + tilt, -14), Vector2(x + 4, 0), Vector2(x - 4, 0)]), CRACKER_COLOR)
			draw_line(Vector2(x + tilt, -14), Vector2(x + tilt, -18), FUSE_COLOR, 1.5)
	if lit:
		return
	# Sputtering fuse spark at the lit end, with a countdown ring.
	var remaining := clampf(1.0 - age / fuse_time, 0.0, 1.0)
	var jitter := Vector2(sin(age * 47.0), cos(age * 39.0)) * 2.0
	draw_circle(Vector2(0, -8) + jitter, 4.0 + 2.0 * absf(sin(age * 30.0)), FUSE_COLOR)
	draw_arc(Vector2(0, -8), 12.0, -PI * 0.5, -PI * 0.5 + remaining * TAU, 24, FUSE_COLOR, 2.0)
	# Pulsing chevrons point the way the chain will burst.
	for chevron in range(3):
		var offset := direction * (22.0 + chevron * 16.0 + fmod(age * 40.0, 16.0))
		var alpha := 0.55 + 0.45 * sin(age * 12.0 - chevron)
		var c := Color(FUSE_COLOR, alpha)
		draw_polyline(PackedVector2Array([Vector2(offset - direction * 6, -36), Vector2(offset + direction * 2, -28), Vector2(offset - direction * 6, -20)]), c, 3.0)
