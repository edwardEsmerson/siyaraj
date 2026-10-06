@tool
class_name TerrainSkin
extends Node
## Dresses the grey Body/Edge platforms under `terrain` with a biome's texture kit, at load time and in
## the editor. Level geometry stays plain polygons: Body gets the repeating fill, Edge is hidden and a
## cap strip runs along the top, with end caps on the corners and a fringe hanging under the platform.
## Art is authored at 2 art px per game unit, so every texture is drawn at scale 0.5.

const ART_SCALE: float = 0.5

@export var terrain: NodePath = ^"../Terrain"
@export var fill: Texture2D
## Horizontally repeating strip; the walking surface sits `cap_surface` of the way down it.
@export var cap: Texture2D
@export_range(0.0, 1.0) var cap_surface: float = 0.33
## Left end of the cap (mirrored for the right end), placed over the platform corner.
@export var end_cap: Texture2D
## Repeating strip hung under platforms (roots, scallops, drapes). Skipped on thin one-way platforms.
@export var fringe: Texture2D
## Cap for one-way platforms (branches, planks); falls back to `cap`.
@export var one_way_cap: Texture2D
@export var refresh: bool = false:
	set(value):
		apply()


func _ready() -> void:
	apply()


func apply() -> void:
	var root: Node = get_node_or_null(terrain)
	if root == null:
		return
	for body: Node in root.get_children():
		if body is StaticBody2D and body.has_node("Body"):
			_skin(body)


func _skin(body: StaticBody2D) -> void:
	for old: Node in body.get_children():
		if old.has_meta("terrain_skin"):
			body.remove_child(old)
			old.free()
	var poly: Polygon2D = body.get_node("Body")
	var rect: Rect2 = _bounds(poly.polygon)
	var one_way: bool = false
	for shape: Node in body.get_children():
		if shape is CollisionShape2D and shape.one_way_collision:
			one_way = true
	if fill and not one_way:
		poly.texture = fill
		poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		poly.texture_scale = Vector2.ONE / ART_SCALE
		poly.texture_offset = body.position  # world-aligned, so neighbouring platforms line up
		poly.color = Color.WHITE
	if body.has_node("Edge"):
		body.get_node("Edge").visible = false
	var top: Texture2D = one_way_cap if one_way and one_way_cap else cap
	if top:
		var height: float = top.get_height() * ART_SCALE
		_strip(body, top, Rect2(rect.position.x, rect.position.y - height * cap_surface, rect.size.x, height), 1)
		if end_cap:
			for right: bool in [false, true]:
				var corner: Sprite2D = _sprite(body, end_cap, 2)
				corner.flip_h = right
				var w: float = end_cap.get_width() * ART_SCALE
				corner.position = Vector2(rect.end.x - w if right else rect.position.x,
						rect.position.y - end_cap.get_height() * ART_SCALE * cap_surface)
	if fringe and not one_way:
		_strip(body, fringe, Rect2(rect.position.x, rect.end.y, rect.size.x, fringe.get_height() * ART_SCALE), -1)


func _strip(body: Node2D, texture: Texture2D, area: Rect2, z: int) -> void:
	var strip: Sprite2D = _sprite(body, texture, z)
	strip.region_enabled = true
	strip.region_rect = Rect2(Vector2.ZERO, area.size / ART_SCALE)
	strip.position = area.position


func _sprite(body: Node2D, texture: Texture2D, z: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.set_meta("terrain_skin", true)
	sprite.texture = texture
	sprite.centered = false
	sprite.scale = Vector2.ONE * ART_SCALE
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.z_index = z
	body.add_child(sprite)
	return sprite


func _bounds(points: PackedVector2Array) -> Rect2:
	var rect := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		rect = rect.expand(point)
	return rect
