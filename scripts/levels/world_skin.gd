@tool
class_name WorldSkin
extends Node2D
## Dresses a grey-box level with the art kit in `res://assets/world/<biome>/<direction>/`, at load time and
## in the editor: textured platforms (fill, cap, end pieces, fringe, one-way strips), solid foundations under
## low platforms, scattered props, Parallax2D far/mid layers and the river water. Level geometry is never
## changed; the grey Body/Edge/Background/WaterLine polygons are only hidden while a kit covers them.
## Every kit file is optional. Art is authored at 2 art px per game unit, so it is all drawn at scale 0.5.

const ART_SCALE: float = 0.5
const KIT_ROOT: String = "res://assets/world"
const DIRECTIONS: PackedStringArray = ["titlematch", "madhubani", "truckart", "diyalit", "carved", "papercut"]
const Z_FAR: int = -100
const Z_MID: int = -90
const Z_FOUNDATION: int = -4  # behind the river WaterLine (z -3), so ghat steps sink into the water
const Z_BODY: int = -2  # fills, fringes and props
const Z_TOP: int = -1  # caps, end pieces and one-way strips; actors stay in front at z 0
const MIN_PROP_PLATFORM: float = 120.0
const WATER_DRIFT: float = 10.0  # art px per second

@export_enum("forest", "river", "palace") var biome: String = "forest":
	set(value):
		biome = value
		_reapply()
@export_enum("titlematch", "madhubani", "truckart", "diyalit", "carved", "papercut") var direction: String = "diyalit":
	set(value):
		direction = value
		_reapply()
## Any folder laid out like a kit (res:// or absolute); overrides biome/direction for art review.
@export var kit_override: String = "":
	set(value):
		kit_override = value
		_reapply()
## How far down the cap strip the walking surface sits.
@export_range(0.0, 1.0) var cap_surface: float = 0.33
## Platforms whose bottom is at least this low read as ground: their fill runs down to `course_bottom`.
@export var foundation_from: float = 420.0
@export var course_bottom: float = 540.0
## Average platform width per prop slot; larger is sparser.
@export var prop_spacing: float = 260.0
## Reloads the kit from disk (after replacing art in the editor).
@export var refresh: bool = false:
	set(value):
		_cache.clear()
		_reapply()

var _dressing: Node2D
var _hidden: Array[CanvasItem] = []
var _cache: Dictionary = {}
var _water: Sprite2D
var _toast: Label
var _toast_tween: Tween


func _enter_tree() -> void:
	if is_node_ready():  # the editor removes and re-adds scenes when switching tabs
		apply()


func _ready() -> void:
	apply()


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		clear()


func _notification(what: int) -> void:
	# Keep the hidden grey polygons out of saved scenes.
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		clear()
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		apply()


func _process(delta: float) -> void:
	if _water:
		_water.region_rect.position.x = fmod(_water.region_rect.position.x + WATER_DRIFT * delta, _water.texture.get_width())


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not InputMap.has_action("cycle_world_kit"):
		return
	if event.is_action_pressed("cycle_world_kit") and not event.is_echo():
		get_viewport().set_input_as_handled()
		cycle()


## The kit folder currently in use.
func kit_dir() -> String:
	return kit_override if kit_override != "" else KIT_ROOT.path_join(biome).path_join(direction)


## Directions of this biome whose kit folder holds any art.
func available_directions() -> PackedStringArray:
	var found := PackedStringArray()
	for name: String in DIRECTIONS:
		if not _pngs(KIT_ROOT.path_join(biome).path_join(name)).is_empty():
			found.append(name)
	return found


## Switches to the next available direction and briefly shows which one is on screen.
func cycle() -> void:
	var found: PackedStringArray = available_directions()
	if not found.is_empty():
		kit_override = ""
		direction = found[(found.find(direction) + 1) % found.size()]
	_show_toast("%s / %s" % [biome, direction if not found.is_empty() else "no kits"])


## Removes every dressing node and shows the grey polygons again.
func clear() -> void:
	for item: CanvasItem in _hidden:
		if is_instance_valid(item):
			item.visible = true
	_hidden.clear()
	if _dressing:
		_dressing.free()
	_dressing = null
	_water = null
	set_process(false)


func apply() -> void:
	clear()
	var level: Node = get_parent()
	if level == null or not is_inside_tree():
		return
	_dressing = Node2D.new()
	_dressing.name = "Dressing"
	add_child(_dressing)
	var kit: String = kit_dir()
	var platforms: Array[Dictionary] = []
	_collect(level, platforms)
	_mark_foundations(platforms)
	for platform: Dictionary in platforms:
		_dress(platform, kit, platforms)
	_scatter_props(kit, platforms, _keep_clear(level))
	_backdrop(level, kit)


func _reapply() -> void:
	if is_node_ready() and is_inside_tree():
		apply()


func _collect(node: Node, platforms: Array[Dictionary]) -> void:
	for child: Node in node.get_children():
		if child == self or child.name == &"Encounters":
			continue
		if child is StaticBody2D and child.get_node_or_null("Body") is Polygon2D and child.get_node("Body").polygon.size() >= 3:
			var poly: Polygon2D = child.get_node("Body")
			var one_way: bool = false
			for shape: Node in child.get_children():
				if shape is CollisionShape2D and shape.one_way_collision:
					one_way = true
			var points: PackedVector2Array = (get_global_transform().affine_inverse() * poly.get_global_transform()) * poly.polygon
			var rect := Rect2(points[0], Vector2.ZERO)
			for point: Vector2 in points:
				rect = rect.expand(point)
			platforms.append({"body": child, "rect": rect, "column": rect, "one_way": one_way, "foundation": false})
		elif not (child is CollisionObject2D):
			_collect(child, platforms)


## Low platforms and the stair steps and landings touching them become solid down to the course bottom,
## unless another platform sits underneath (that space must stay readable).
func _mark_foundations(platforms: Array[Dictionary]) -> void:
	var open: Array[Dictionary] = []
	for p: Dictionary in platforms:
		if p.one_way or p.rect.end.y >= course_bottom or p.rect.end.y < 0.0:
			continue
		var below: bool = false
		for q: Dictionary in platforms:
			if not is_same(q, p) and q.rect.position.y >= p.rect.end.y - 1.0 and q.rect.position.y < course_bottom \
					and minf(p.rect.end.x, q.rect.end.x) - maxf(p.rect.position.x, q.rect.position.x) > 1.0:
				below = true
		if not below:
			open.append(p)
	var grew: bool = true
	while grew:
		grew = false
		for p: Dictionary in open:
			if p.foundation:
				continue
			p.foundation = p.rect.end.y >= foundation_from
			for q: Dictionary in open:
				if q.foundation and p.rect.position.y <= q.rect.position.y + 0.5 \
						and (absf(p.rect.end.x - q.rect.position.x) <= 2.0 or absf(p.rect.position.x - q.rect.end.x) <= 2.0):
					p.foundation = true
			if p.foundation:
				p.column = Rect2(p.rect.position, Vector2(p.rect.size.x, course_bottom - p.rect.position.y))
				grew = true


func _dress(p: Dictionary, kit: String, platforms: Array[Dictionary]) -> void:
	var body: StaticBody2D = p.body
	var rect: Rect2 = p.rect
	var cap: Texture2D = _tex(kit, "cap")
	var covered: bool = false
	if p.one_way:
		var strip: Texture2D = _tex(kit, "oneway")
		if strip:
			var height: float = strip.get_height() * ART_SCALE
			_strip(strip, Rect2(rect.position.x, rect.get_center().y - height * 0.5, rect.size.x, height), Z_TOP)
		elif cap:
			var cap_height: float = cap.get_height() * ART_SCALE
			_strip(cap, Rect2(rect.position.x, rect.position.y - cap_height * cap_surface, rect.size.x, cap_height), Z_TOP)
		covered = strip != null or cap != null
		if covered:
			_hide(body.get_node("Body"))
	else:
		var fill: Texture2D = _tex(kit, "fill")
		if fill:
			_strip(fill, p.column, Z_FOUNDATION if p.foundation else Z_BODY, true)
			_hide(body.get_node("Body"))
		var fringe: Texture2D = _tex(kit, "fringe")
		if fringe and not p.foundation:
			_strip(fringe, Rect2(rect.position.x, rect.end.y, rect.size.x, fringe.get_height() * ART_SCALE), Z_BODY)
		var top: float = rect.position.y - (cap.get_height() if cap else 0) * ART_SCALE * cap_surface
		if cap:
			_strip(cap, Rect2(rect.position.x, top, rect.size.x, cap.get_height() * ART_SCALE), Z_TOP)
		var end: Texture2D = _tex(kit, "end")
		if end:
			if not cap:
				top = rect.position.y - end.get_height() * ART_SCALE * cap_surface
			for right: bool in [false, true]:
				if not _side_open(p, right, platforms):
					continue
				var piece: Sprite2D = _sprite(end, Z_TOP)
				piece.flip_h = right
				piece.position = Vector2(rect.end.x - end.get_width() * ART_SCALE if right else rect.position.x, top)
		covered = fill != null or cap != null
	if covered and body.has_node("Edge"):
		_hide(body.get_node("Edge"))


## False when a neighbouring platform (or its foundation) continues the surface past this corner.
func _side_open(p: Dictionary, right: bool, platforms: Array[Dictionary]) -> bool:
	var corner := Vector2(p.rect.end.x if right else p.rect.position.x, p.rect.position.y)
	var probe := Rect2(corner - Vector2(2, 2), Vector2(4, 4))
	for q: Dictionary in platforms:
		if not is_same(q, p) and not q.one_way and q.column.intersects(probe):
			return false
	return true


func _scatter_props(kit: String, platforms: Array[Dictionary], keep_clear: Array[Vector2]) -> void:
	var props: Array[Dictionary] = []
	for file: String in _pngs(kit.path_join("props")):
		var path: String = kit.path_join("props").path_join(file)
		var tex: Texture2D = _tex(kit.path_join("props"), file.get_basename())
		if tex and not _cache.has(path + "#used"):
			_cache[path + "#used"] = Rect2(tex.get_image().get_used_rect())  # the opaque bottom is where it stands
		if tex:
			props.append({"tex": tex, "used": _cache[path + "#used"]})
	if props.is_empty():
		return
	for p: Dictionary in platforms:
		var rect: Rect2 = p.rect
		if p.one_way or rect.size.x < MIN_PROP_PLATFORM:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s%s" % [p.body.name, rect.position])
		if rng.randf() < 0.3:
			continue  # some platforms stay bare
		var slots: int = maxi(1, int(rect.size.x / prop_spacing))
		var slot_width: float = (rect.size.x - 32.0) / slots
		for slot: int in slots:
			var prop: Dictionary = props[rng.randi() % props.size()]
			var x: float = rect.position.x + 16.0 + slot_width * (slot + rng.randf_range(0.2, 0.8))
			if rng.randf() < 0.65:
				_place_prop(prop, x, p, platforms, keep_clear)


func _place_prop(prop: Dictionary, x: float, p: Dictionary, platforms: Array[Dictionary], keep_clear: Array[Vector2]) -> void:
	var used: Rect2 = prop.used
	var size: Vector2 = used.size * ART_SCALE
	var area := Rect2(x - size.x * 0.5, p.rect.position.y - size.y, size.x, size.y)
	if area.position.x < p.rect.position.x + 8.0 or area.end.x > p.rect.end.x - 8.0:
		return
	for q: Dictionary in platforms:
		if not is_same(q, p) and q.column.grow(-1.0).intersects(area):
			return
	for point: Vector2 in keep_clear:
		if absf(point.x - x) < 56.0 + size.x * 0.5 and absf(point.y - p.rect.position.y) < 140.0:
			return
	var sprite: Sprite2D = _sprite(prop.tex, Z_BODY)
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	sprite.position = Vector2(x - (used.position.x + used.size.x * 0.5) * ART_SCALE, p.rect.position.y - used.end.y * ART_SCALE + 1.0)


## Diyas, portals and the finish keep their own silhouettes readable.
func _keep_clear(level: Node) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for group: String in ["Checkpoints", "RoomCheckpoints", "Portals"]:
		for node: Node in level.get_node(group).get_children() if level.has_node(group) else []:
			if node is Node2D:
				points.append(to_local(node.global_position))
	if level.get_node_or_null("Finish") is Node2D:
		points.append(to_local(level.get_node("Finish").global_position))
	return points


func _backdrop(level: Node, kit: String) -> void:
	var far: Texture2D = _tex(kit, "far")
	if far:
		_parallax(far, 0.15, Z_FAR)
		if level.get_node_or_null("Background") is CanvasItem:
			_hide(level.get_node("Background"))
	var mid: Texture2D = _tex(kit, "mid")
	if mid:
		_parallax(mid, 0.45, Z_MID)
	var water: Texture2D = _tex(kit, "water")
	var line: Polygon2D = level.get_node_or_null("WaterLine") as Polygon2D
	if water and line:
		var points: PackedVector2Array = (get_global_transform().affine_inverse() * line.get_global_transform()) * line.polygon
		var rect := Rect2(points[0], Vector2.ZERO)
		for point: Vector2 in points:
			rect = rect.expand(point)
		_water = _strip(water, Rect2(rect.position, rect.size), line.z_index)
		_hide(line)
		set_process(not Engine.is_editor_hint())


## A horizontally repeating layer; the camera never moves vertically on the main course, so it is pinned
## to the screen vertically (scroll 0) and anchored to the course bottom.
func _parallax(texture: Texture2D, scroll: float, z: int) -> void:
	var layer := Parallax2D.new()
	layer.z_index = z
	layer.scroll_scale = Vector2(scroll, 0.0)
	var width: float = texture.get_width() * ART_SCALE
	layer.repeat_size = Vector2(width, 0.0)
	layer.repeat_times = ceili(960.0 / width) + 1
	_dressing.add_child(layer)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.scale = Vector2.ONE * ART_SCALE
	sprite.position.y = course_bottom - texture.get_height() * ART_SCALE
	layer.add_child(sprite)


## Covers `area` (game units) with a repeating texture, aligned to world space so neighbours line up.
func _strip(texture: Texture2D, area: Rect2, z: int, align_y: bool = false) -> Sprite2D:
	var strip: Sprite2D = _sprite(texture, z)
	strip.region_enabled = true
	strip.region_rect = Rect2(Vector2(area.position.x, area.position.y if align_y else 0.0) / ART_SCALE, area.size / ART_SCALE)
	strip.position = area.position
	return strip


func _sprite(texture: Texture2D, z: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.scale = Vector2.ONE * ART_SCALE
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.z_index = z
	_dressing.add_child(sprite)
	return sprite


func _hide(item: CanvasItem) -> void:
	if item.visible:
		item.visible = false
		_hidden.append(item)


## Imported textures load normally; freshly dropped PNGs (not yet imported) load straight from disk.
func _tex(dir: String, name: String) -> Texture2D:
	var path: String = dir.path_join(name + ".png")
	if not _cache.has(path):
		var texture: Texture2D = null
		if ResourceLoader.exists(path):
			texture = load(path) as Texture2D
		elif FileAccess.file_exists(path):
			var image: Image = Image.load_from_file(path)
			texture = ImageTexture.create_from_image(image) if image else null
		_cache[path] = texture
	return _cache[path]


func _pngs(dir: String) -> PackedStringArray:
	var found := PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir):
		return found
	var names: PackedStringArray = DirAccess.get_files_at(dir)
	if dir.begins_with("res://"):
		names.append_array(ResourceLoader.list_directory(dir))  # exported builds only list imported files
	for file: String in names:
		if file.get_extension() == "png" and not found.has(file):
			found.append(file)
	found.sort()
	return found


func _show_toast(text: String) -> void:
	if _toast == null:
		var layer := CanvasLayer.new()
		layer.layer = 90
		add_child(layer)
		_toast = Label.new()
		_toast.position = Vector2(16, 124)  # just under the main scenes' HUD bar
		_toast.add_theme_font_size_override("font_size", 18)
		_toast.add_theme_constant_override("outline_size", 6)
		_toast.add_theme_color_override("font_outline_color", Color.BLACK)
		layer.add_child(_toast)
	_toast.text = text
	_toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
