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
const BLAST_COLOR := Color(1.0, 0.75, 0.25)

## Art (assets/sprites/ladi, built by tools/ladi_art.py) is drawn at the canonical 0.5 scale.
const ART_SCALE := 0.5
const CRACKER_ART: Texture2D = preload("res://assets/sprites/ladi/cracker.png")
const ASH_ART: Array[Texture2D] = [preload("res://assets/sprites/ladi/ash_0.png"), preload("res://assets/sprites/ladi/ash_1.png")]
const SPARK_ART: Array[Texture2D] = [preload("res://assets/sprites/ladi/spark_0.png"), preload("res://assets/sprites/ladi/spark_1.png"), preload("res://assets/sprites/ladi/spark_2.png")]
const POP_ART: Array[Texture2D] = [preload("res://assets/sprites/ladi/pop_0.png"), preload("res://assets/sprites/ladi/pop_1.png"), preload("res://assets/sprites/ladi/pop_2.png"), preload("res://assets/sprites/ladi/pop_3.png")]
const CORD_ART: Texture2D = preload("res://assets/sprites/ladi/cord.png")
## Lead fuse behind the lit end that the spark burns along during the fuse.
const LEAD_LENGTH := 14.0
## Gap between the ground and the bottom of the cord.
const CORD_LIFT := 1.0
const SPARK_FPS := 15.0
const CHAR_TINT := Color(0.12, 0.08, 0.09, 0.72)

var age: float = 0.0
var _hit_targets: Dictionary = {}
var _ignited: Array[bool] = []
var _detonating: bool = false


func _ready() -> void:
	direction = 1 if direction >= 0 else -1
	z_index = 4
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
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
	_draw_cord(length)
	for index in range(segment_count):
		var x := segment_offset(index)
		var flip := index % 2 == 1
		if is_segment_blasting(index):
			var t := (age - ignite_time(index)) / blast_time
			if t > 0.5:
				_draw_art(ASH_ART[index % ASH_ART.size()], Vector2(x, 0), flip)
			_draw_art(POP_ART[mini(int(t * POP_ART.size()), POP_ART.size() - 1)], Vector2(x, 0), flip)
		elif is_segment_spent(index):
			_draw_art(ASH_ART[index % ASH_ART.size()], Vector2(x, 0), flip)
		else:
			# Unlit crackers alternate facing, braided onto the cord.
			_draw_art(CRACKER_ART, Vector2(x, 0), flip)
	if lit:
		return
	# The fuse spark burns along the lead toward the lit end, with a countdown ring.
	var remaining := clampf(1.0 - age / fuse_time, 0.0, 1.0)
	var spark_at := Vector2(-direction * LEAD_LENGTH * remaining, -CORD_LIFT - CORD_ART.get_height() * 0.25)
	_draw_art(SPARK_ART[int(age * SPARK_FPS) % SPARK_ART.size()], spark_at, int(age * 7.0) % 2 == 1, true)
	draw_arc(Vector2(0, -8), 12.0, -PI * 0.5, -PI * 0.5 + remaining * TAU, 24, FUSE_COLOR, 2.0)
	# Pulsing chevrons point the way the chain will burst.
	for chevron in range(3):
		var offset := direction * (22.0 + chevron * 16.0 + fmod(age * 40.0, 16.0))
		var alpha := 0.55 + 0.45 * sin(age * 12.0 - chevron)
		var c := Color(FUSE_COLOR, alpha)
		draw_polyline(PackedVector2Array([Vector2(offset - direction * 6, -36), Vector2(offset + direction * 2, -28), Vector2(offset - direction * 6, -20)]), c, 3.0)


## The twisted cord runs from the end of the lead to the far cracker. Burnt stretches
## (the lead behind the spark, then the cord behind the pop chain) are charred dark.
func _draw_cord(length: float) -> void:
	var height := CORD_ART.get_height() * 0.5
	var top := -CORD_LIFT - height
	var start := -direction * LEAD_LENGTH
	var finish := direction * length
	draw_set_transform(Vector2(minf(start, finish), top), 0.0, Vector2(ART_SCALE, ART_SCALE))
	draw_texture_rect(CORD_ART, Rect2(0, 0, absf(finish - start) / ART_SCALE, CORD_ART.get_height()), true)
	draw_set_transform(Vector2.ZERO)
	var burnt_to := start + direction * LEAD_LENGTH * clampf(age / fuse_time, 0.0, 1.0)
	if is_lit():
		var chain := (age - fuse_time) / segment_interval + 0.5
		burnt_to = direction * clampf(chain, 0.0, segment_count) * segment_spacing
	draw_rect(Rect2(minf(start, burnt_to), top, absf(burnt_to - start), height), CHAR_TINT)


## Draws one piece of ladi art at scale 0.5. `at` is its bottom centre (or centre).
func _draw_art(texture: Texture2D, at: Vector2, flip: bool = false, centred: bool = false) -> void:
	var size := texture.get_size()
	draw_set_transform(at, 0.0, Vector2(-ART_SCALE if flip else ART_SCALE, ART_SCALE))
	draw_texture(texture, Vector2(-size.x * 0.5, -size.y * (0.5 if centred else 1.0)))
	draw_set_transform(Vector2.ZERO)
