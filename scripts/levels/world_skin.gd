@tool
class_name WorldSkin
extends Node2D
## Dresses a grey-box level with the art kit in `res://assets/world/<biome>/<direction>/`, at load time and
## in the editor: textured platforms (fill, cap, end pieces, fringe, one-way strips), solid foundations under
## low platforms, scattered props, landmarks cut from the set-piece sheet, back walls in recesses, side rooms
## and doorways, Parallax2D far/mid layers (or the one-screen backdrop in boss arenas) and the river water.
## Level geometry is never changed; the grey Body/Edge/Background/Backdrop/Door/RiverLine polygons are only
## hidden while a kit covers them. Every kit file is optional. Art is authored at 2 art px per game unit, so
## it is all drawn at scale 0.5 (landmarks larger, see `landmark_scale`).
##
## Optional, per level (all ignored by kits that lack the named files):
## - Platform roles: a `skin` metadata string on a platform body (or any ancestor, or its `SkinZones` zone)
##   makes its pieces use `<piece>-<skin>.png` (cap, fill, end, side, fringe, oneway) where the kit has one.
## - `side.png`: a vertically seamless strip hung down the open sides of solid platforms (left side; mirrored).
## - `near.png`: a cutout parallax layer in front of the actors, anchored to the course bottom.
## - `SkinZones`: a node whose Node2D children start zones along x. Their metadata `skin`, `far`, `mid`, `near`
##   (kit file names) and `tint` / `mid_tint` (Colors for the parallax) change the look per section, with the
##   parallax crossfading between zones as the camera moves.
## - `SkinDecor`: a node whose Node2D children each place one kit piece: metadata `piece` (path in the kit
##   without .png), `layer` (far, back, wall, landmark, body, top or front), `size` (x art scale), `hang` (anchor
##   at the top instead of the bottom), `flip`, `tint`. A level whose decor placed anything is not
##   auto-dressed with scattered props and landmarks.
## - Polygon2D nodes with a `kit_texture` metadata name are textured with that kit file (side-room `Backdrop`s
##   too, instead of back.png); `kit_tint` colours them and `kit_z` sets their z (default: back wall).
## - A portal `Door` with a `piece` metadata name (and optional `size`, `offset_x`) is drawn as that kit piece
##   standing on the door's bottom centre instead of a framed doorway, when the kit has it.

const ART_SCALE: float = 0.5
const KIT_ROOT: String = "res://assets/world"
const DIRECTIONS: PackedStringArray = ["titlematch", "madhubani", "truckart", "diyalit", "carved", "papercut"]
const Z_FAR: int = -100
const Z_MID: int = -90
const Z_BACK: int = -8  # back walls of recesses and side rooms
const Z_LANDMARK: int = -6
const Z_FOUNDATION: int = -4  # behind the river water, so ghat steps sink into it
const Z_WATER: int = -3
const Z_BODY: int = -2  # fills, fringes and props
const Z_TOP: int = -1  # caps, end pieces and one-way strips; actors stay in front at z 0
const Z_NEAR: int = 4  # near parallax and front decor, in front of the actors
const DECOR_LAYERS: Dictionary = {"far": -99, "back": Z_BACK, "wall": Z_BACK + 1, "landmark": Z_LANDMARK, "body": Z_BODY, "top": Z_TOP, "front": Z_NEAR}
const ZONE_BLEND: float = 320.0  # camera travel over which zone parallax crossfades
const MIN_PROP_PLATFORM: float = 120.0
const WATER_DRIFT: float = 10.0  # art px per second
const WATER_ABOVE_LINE: float = 40.0
const ARENA_WIDTH: float = 960.0
const SHEET_CELL: int = 4  # set-piece sheet pixels closer than this belong to the same piece
const LANDMARK_HEIGHT: int = 96  # set pieces at least this tall (art px) are landmarks; smaller ones join the props
const RECESS_DEPTH: Vector2 = Vector2(40.0, 260.0)  # floor-to-ceiling gaps that read as a covered recess
const BACK_TINT: Color = Color(0.62, 0.62, 0.68)
const ROOM_TINT: Color = Color(0.55, 0.55, 0.62)  # whole-screen room walls sit further back than recesses

## Direction each biome's level last showed, so its boss arena (a separate scene) matches.
static var _shown: Dictionary = {}

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
## Minimum gap between landmarks (large `setpieces.png` pieces standing on the ground, behind the actors).
@export var landmark_spacing: float = 420.0
## Landmarks are drawn larger than props (2 = twice their scale) so they read as background architecture.
@export_range(0.5, 2.0, 0.5) var landmark_scale: float = 2.0
## How dark the deep part of solid ground gets, so tall foundations do not read as flat tile.
@export_range(0.0, 1.0) var depth_shade: float = 0.35
## Single-screen boss arena: `arena.png` replaces the parallax layers and the grey `Backdrop`; no props or
## landmarks, and the direction follows whatever the biome's level last showed.
@export var arena: bool = false:
	set(value):
		arena = value
		_reapply()
## Reloads the kit from disk (after replacing art in the editor).
@export var refresh: bool = false:
	set(value):
		_cache.clear()
		_reapply()

var _dressing: Node2D
var _hidden: Array[CanvasItem] = []
var _cache: Dictionary = {}
var _water: Sprite2D
var _surface: Sprite2D
var _zones: Array[Dictionary] = []  # {x, skin, far, mid, near, tint, mid_tint}, sorted by x
var _layers: Array[Dictionary] = []  # {node: Parallax2D, kind, name}
var _toast: Label
var _toast_tween: Tween


func _enter_tree() -> void:
	if is_node_ready():  # the editor removes and re-adds scenes when switching tabs
		apply()


func _ready() -> void:
	if arena and not Engine.is_editor_hint() and _shown.get(biome, direction) != direction:
		direction = _shown[biome]  # the setter applies
	else:
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
	if _surface:
		_surface.region_rect.position.x = fmod(_surface.region_rect.position.x + WATER_DRIFT * 1.5 * delta, _surface.texture.get_width())
	var camera: Camera2D = get_viewport().get_camera_2d() if _zones.size() > 1 else null
	if camera:
		_blend_zones(to_local(camera.get_screen_center_position()).x)


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
	_surface = null
	_zones.clear()
	_layers.clear()
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
	if not arena and kit_override == "" and not Engine.is_editor_hint():
		_shown[biome] = direction
	_read_zones(level)
	var platforms: Array[Dictionary] = []
	_collect(level, platforms)
	_mark_foundations(platforms)
	for platform: Dictionary in platforms:
		_dress(platform, kit, platforms)
	_kit_polygons(level, kit)
	var composed: bool = _decor(level, kit)
	if not arena:
		var keep_clear: Array[Vector2] = _keep_clear(level)
		var skinned: bool = _skin_decor(level, kit) > 0
		if not composed and not skinned:  # hand-placed decor replaces the scattered landmarks and props
			var pieces: Dictionary = _setpieces(kit)
			if level.get_node_or_null("LandmarkSpots"):
				_spot_landmarks(pieces.landmarks, level.get_node("LandmarkSpots"))
			else:
				_place_landmarks(pieces.landmarks, platforms, keep_clear)
			_scatter_props(kit, platforms, keep_clear, pieces.small)
		if not composed:
			_recesses(kit, platforms)
		_rooms(level, kit)
	_doors(level, kit)
	_backdrop(level, kit)
	# Hand-placed dressing for one direction lives under `Decor/<direction>`; only the kit on show is visible.
	for decor: Node in level.get_node("Decor").get_children() if level.has_node("Decor") else []:
		if decor is CanvasItem:
			decor.visible = decor.name == direction and kit_override == ""


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
			platforms.append({"body": child, "rect": rect, "column": rect, "one_way": one_way, "foundation": false,
					"skin": _skin_of(child, rect.get_center().x)})
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


## A platform's role: `skin` metadata on the body or an ancestor, else the zone it sits in.
func _skin_of(body: Node, x: float) -> String:
	var node: Node = body
	while node and node != get_parent():
		if node.has_meta("skin") or node.has_meta("kit"):
			return str(node.get_meta("skin") if node.has_meta("skin") else node.get_meta("kit"))
		node = node.get_parent()
	return str(_zone_at(x).get("skin", ""))


## `<name>-<skin>.png` when the kit has it, else `<name>.png`.
func _role_tex(kit: String, name: String, skin: String) -> Texture2D:
	var texture: Texture2D = _tex(kit, "%s-%s" % [name, skin]) if skin != "" else null
	return texture if texture else _tex(kit, name)


func _dress(p: Dictionary, kit: String, platforms: Array[Dictionary]) -> void:
	var body: StaticBody2D = p.body
	var rect: Rect2 = p.rect
	var cap: Texture2D = _role_tex(kit, "cap", p.skin)
	var covered: bool = false
	if p.one_way:
		var strip: Texture2D = _role_tex(kit, "oneway", p.skin)
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
		var fill: Texture2D = _role_tex(kit, "fill", p.skin)
		if fill:
			_strip(fill, p.column, Z_FOUNDATION if p.foundation else Z_BODY, true)
			_hide(body.get_node("Body"))
		var side: Texture2D = _role_tex(kit, "side", p.skin)
		if side:
			_sides(p, side, platforms)
		if fill and p.foundation:
			_shade(Rect2(rect.position.x, rect.position.y + 48.0, rect.size.x, p.column.end.y - rect.position.y - 48.0))
		var fringe: Texture2D = _role_tex(kit, "fringe", p.skin)
		if fringe and not p.foundation:
			_strip(fringe, Rect2(rect.position.x, rect.end.y, rect.size.x, fringe.get_height() * ART_SCALE), Z_BODY)
		var top: float = rect.position.y - (cap.get_height() if cap else 0) * ART_SCALE * cap_surface
		if cap:
			_strip(cap, Rect2(rect.position.x, top, rect.size.x, cap.get_height() * ART_SCALE), Z_TOP)
		var end: Texture2D = _role_tex(kit, "end", p.skin)
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


## A platform part (`cap`, `fill`, `end`, `fringe`, `oneway`, `back` under it): `<part>-<skin>.png` when the platform's
## `skin` (or `kit`) meta names a variant the kit has, otherwise the kit's plain `<part>.png`.
func _part(kit: String, part: String, p: Dictionary) -> Texture2D:
	var variant: Texture2D = _tex(kit, "%s-%s" % [part, p.skin]) if p.skin != "" else null
	return variant if variant else _tex(kit, part)


## Hangs `side` down each open vertical side of a solid platform, from its top to its foundation's bottom or
## to the top of a lower neighbour that continues the ground on that side. The strip's art faces left (ragged
## edge left, solid edge right) and overhangs the edge by a third; the right side is mirrored.
func _sides(p: Dictionary, side: Texture2D, platforms: Array[Dictionary]) -> void:
	var rect: Rect2 = p.rect
	var width: float = side.get_width() * ART_SCALE
	for right: bool in [false, true]:
		var edge: float = rect.end.x if right else rect.position.x
		var top: float = rect.position.y + 2.0
		var bottom: float = p.column.end.y
		for q: Dictionary in platforms:
			if is_same(q, p) or q.one_way or absf((q.rect.position.x if right else q.rect.end.x) - edge) > 2.0:
				continue
			if q.column.end.y > top and q.rect.position.y < bottom:
				bottom = maxf(top, q.rect.position.y)
		if bottom - top < 8.0:
			continue
		var x: float = edge - width * (2.0 / 3.0) if right else edge - width / 3.0
		var strip: Sprite2D = _strip(side, Rect2(x, top, width, bottom - top), Z_FOUNDATION if p.foundation else Z_BODY, true)
		strip.region_rect.position.x = 0.0  # the whole strip's width, only its rows follow world y
		strip.flip_h = right


## False when a neighbouring platform (or its foundation) continues the surface past this corner.
func _side_open(p: Dictionary, right: bool, platforms: Array[Dictionary]) -> bool:
	var corner := Vector2(p.rect.end.x if right else p.rect.position.x, p.rect.position.y)
	var probe := Rect2(corner - Vector2(2, 2), Vector2(4, 4))
	for q: Dictionary in platforms:
		if not is_same(q, p) and not q.one_way and q.column.intersects(probe):
			return false
	return true


func _scatter_props(kit: String, platforms: Array[Dictionary], keep_clear: Array[Vector2], extra: Array[Dictionary]) -> void:
	var props: Array[Dictionary] = extra.duplicate()
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


## Large set pieces stand on wide ground behind everything that is played on, spaced out along the course.
## They cycle through a seeded shuffle so every piece of the sheet shows up before any repeats.
func _place_landmarks(pieces: Array[Dictionary], platforms: Array[Dictionary], keep_clear: Array[Vector2]) -> void:
	if pieces.is_empty():
		return
	var order: Array[Dictionary] = pieces.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kit_dir())
	for i: int in range(order.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Dictionary = order[i]
		order[i] = order[j]
		order[j] = swap
	var ground: Array[Dictionary] = []
	for p: Dictionary in platforms:
		if not p.one_way and p.rect.size.x >= 150.0:
			ground.append(p)
	ground.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.rect.position.x < b.rect.position.x)
	var placed: Array[Rect2] = []
	var next: int = 0
	for p: Dictionary in ground:
		var rect: Rect2 = p.rect
		var x: float = rect.position.x + 24.0
		while x < rect.end.x - 24.0:
			var placed_one: bool = false
			for attempt: int in mini(3, order.size()):  # a piece too wide for this spot waits for the next one
				var piece: Dictionary = order[(next + attempt) % order.size()]
				var size: Vector2 = piece.size * ART_SCALE * landmark_scale
				var area := Rect2(x, rect.position.y - size.y + 2.0, size.x, size.y)
				if area.end.x > rect.end.x - 8.0 or not _landmark_fits(area, p, platforms, keep_clear, placed):
					continue
				var sprite: Sprite2D = _sprite(piece.tex, Z_LANDMARK)
				sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
				sprite.scale = Vector2.ONE * ART_SCALE * landmark_scale
				sprite.flip_h = rng.randf() < 0.5
				sprite.position = area.position
				placed.append(area)
				order[(next + attempt) % order.size()] = order[next % order.size()]
				order[next % order.size()] = piece
				next += 1
				x = area.end.x + landmark_spacing
				placed_one = true
				break
			if not placed_one:
				x += 48.0


## Hand-chosen landmark spots: each Marker2D under the level's `LandmarkSpots` stands one set piece on its
## position (bottom centre). `metadata/piece` picks the piece by its order on the sheet (top to bottom, then
## left to right), otherwise the spots take the pieces in turn; a negative x scale mirrors it.
func _spot_landmarks(pieces: Array[Dictionary], spots: Node) -> void:
	if pieces.is_empty():
		return
	var next: int = 0
	for spot: Node in spots.get_children():
		if not (spot is Node2D):
			continue
		var piece: Dictionary = pieces[int(spot.get_meta("piece", next)) % pieces.size()]
		next += 1
		var size: Vector2 = piece.size * ART_SCALE * landmark_scale
		var at: Vector2 = to_local(spot.global_position)
		var sprite: Sprite2D = _sprite(piece.tex, Z_LANDMARK)
		sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
		sprite.scale = Vector2.ONE * ART_SCALE * landmark_scale
		sprite.flip_h = spot.scale.x < 0.0
		sprite.position = at - Vector2(size.x * 0.5, size.y)


func _landmark_fits(area: Rect2, p: Dictionary, platforms: Array[Dictionary], keep_clear: Array[Vector2], placed: Array[Rect2]) -> bool:
	var base := Rect2(area.position.x, area.get_center().y, area.size.x, area.size.y * 0.5 - 4.0)
	for q: Dictionary in platforms:
		if not is_same(q, p) and not q.one_way and q.column.intersects(base):
			return false  # its base would vanish behind a neighbouring block
	for point: Vector2 in keep_clear:
		if point.x > area.position.x - 72.0 and point.x < area.end.x + 72.0 and absf(point.y - area.end.y) < 160.0:
			return false
	for other: Rect2 in placed:
		if other.grow_individual(landmark_spacing, 0.0, landmark_spacing, 0.0).intersects(area):
			return false
	return true


## Cuts `setpieces.png` into its separate pieces (connected opaque regions, cached per kit).
## Returns {landmarks, small}: arrays of {tex, used, size}; small pieces are scattered with the props.
func _setpieces(kit: String) -> Dictionary:
	var key: String = kit.path_join("setpieces.png#pieces")
	if _cache.has(key):
		return _cache[key]
	var landmarks: Array[Dictionary] = []
	var small: Array[Dictionary] = []
	_cache[key] = {"landmarks": landmarks, "small": small}
	var sheet: Texture2D = _tex(kit, "setpieces")
	if sheet == null:
		return _cache[key]
	var image: Image = sheet.get_image()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var width: int = image.get_width()
	var columns: int = ceili(width / float(SHEET_CELL))
	var rows: int = ceili(image.get_height() / float(SHEET_CELL))
	var data: PackedByteArray = image.get_data()
	var label := PackedInt32Array()
	label.resize(columns * rows)
	label.fill(-1)
	for i: int in range(3, data.size(), 4):
		if data[i] > 24:
			var pixel: int = i / 4
			label[(pixel / width / SHEET_CELL) * columns + (pixel % width) / SHEET_CELL] = 0
	var count: int = 0
	for start: int in label.size():
		if label[start] != 0:
			continue
		count += 1
		label[start] = count
		var stack: PackedInt32Array = [start]
		var cells: Rect2i = Rect2i(start % columns, start / columns, 1, 1)
		while not stack.is_empty():
			var cell: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			var cx: int = cell % columns
			var cy: int = cell / columns
			cells = cells.expand(Vector2i(cx, cy)).expand(Vector2i(cx + 1, cy + 1))
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					var nx: int = cx + dx
					var ny: int = cy + dy
					if nx >= 0 and ny >= 0 and nx < columns and ny < rows and label[ny * columns + nx] == 0:
						label[ny * columns + nx] = count
						stack.append(ny * columns + nx)
		var region := Rect2i(cells.position * SHEET_CELL, cells.size * SHEET_CELL).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
		var piece: Image = image.get_region(region)
		for cy: int in range(cells.position.y, cells.end.y):
			for cx: int in range(cells.position.x, cells.end.x):
				if label[cy * columns + cx] != count:  # a neighbour reaching into this piece's box
					piece.fill_rect(Rect2i(Vector2i(cx, cy) * SHEET_CELL - region.position, Vector2i.ONE * SHEET_CELL), Color(0, 0, 0, 0))
		var used: Rect2i = piece.get_used_rect()
		if maxi(used.size.x, used.size.y) < 16:
			continue  # specks and sparks
		piece = piece.get_region(used)
		var entry: Dictionary = {"tex": ImageTexture.create_from_image(piece), "used": Rect2(Vector2.ZERO, used.size), "size": Vector2(used.size)}
		(landmarks if used.size.y >= LANDMARK_HEIGHT else small).append(entry)
	return _cache[key]


## Hand-placed art: each CanvasItem under a `KitDecor` node with a `piece` meta draws `<kit>/decor/<piece>.png` (kits
## without that file draw nothing). The marker is the piece's bottom centre (top centre with meta `hang`), and its
## z_index, modulate and scale (negative x flips) carry over. Meta `width` repeats the piece across that many game
## units; meta `blend` = "add" draws it additively (light pools). Returns whether any piece was drawn: a composed
## level skips the scattered landmarks, props and recess walls.
func _decor(level: Node, kit: String) -> bool:
	var drawn: bool = false
	for holder: Node in level.find_children("KitDecor", "Node", true, false):
		for marker: Node in holder.find_children("*", "CanvasItem", true, false):
			var texture: Texture2D = _tex(kit.path_join("decor"), str(marker.get_meta("piece"))) if marker.has_meta("piece") else null
			if texture == null:
				continue
			var at: Vector2 = to_local(marker.global_position)
			var stretch: Vector2 = (marker as Node2D).scale if marker is Node2D else Vector2.ONE
			var size: Vector2 = texture.get_size() * ART_SCALE * stretch.abs()
			var width: float = float(marker.get_meta("width", size.x))
			var top: float = at.y if marker.get_meta("hang", false) else at.y - size.y
			var sprite: Sprite2D = _sprite(texture, (marker as CanvasItem).z_index)
			sprite.scale = Vector2.ONE * ART_SCALE * stretch.abs()
			sprite.flip_h = stretch.x < 0.0
			sprite.position = Vector2(at.x - width * 0.5, top)
			sprite.modulate = (marker as CanvasItem).modulate
			if marker.has_meta("width"):
				sprite.region_enabled = true
				sprite.region_rect = Rect2(0.0, 0.0, width / sprite.scale.x, texture.get_height())
			else:
				sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
			if marker.get_meta("blend", "") == "add":
				var additive := CanvasItemMaterial.new()
				additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
				sprite.material = additive
			drawn = true
	return drawn


## The space under a ceiling (a roof, balcony or gallery above a floor) gets the kit's back wall,
## from the ceiling down behind the floor, so covered stretches read as interiors.
func _recesses(kit: String, platforms: Array[Dictionary]) -> void:
	for ceiling: Dictionary in platforms:
		var back: Texture2D = _part(kit, "back", ceiling)  # `back-<skin>.png` follows the ceiling's skin
		if back == null:
			continue
		for below: Dictionary in platforms:
			var gap: float = below.rect.position.y - ceiling.rect.end.y
			var left: float = maxf(ceiling.rect.position.x, below.rect.position.x)
			var right: float = minf(ceiling.rect.end.x, below.rect.end.x)
			if is_same(ceiling, below) or below.one_way or gap < RECESS_DEPTH.x or gap > RECESS_DEPTH.y or right - left < 96.0:
				continue
			var top: float = ceiling.rect.get_center().y
			var wall: Sprite2D = _strip(back, Rect2(left, top, right - left, below.rect.end.y - top), Z_BACK, true)
			wall.modulate = BACK_TINT


## Side rooms are painted on a grey `Backdrop` polygon; the back wall (or its `kit_texture`) replaces it.
func _rooms(level: Node, kit: String) -> void:
	for backdrop: Node in level.find_children("Backdrop", "Polygon2D", true, false):
		var wall_tex: Texture2D = _tex(kit, str(backdrop.get_meta("kit_texture"))) if backdrop.has_meta("kit_texture") else null
		if wall_tex == null:
			wall_tex = _tex(kit, "back")
		if wall_tex:
			var wall: Polygon2D = _textured(backdrop, wall_tex, Z_BACK)
			wall.color = backdrop.get_meta("kit_tint", ROOM_TINT)


## Polygons that name a kit texture (`kit_texture` metadata) are textured with it; side-room backdrops are
## left to `_rooms`.
func _kit_polygons(level: Node, kit: String) -> void:
	for poly: Node in level.find_children("*", "Polygon2D", true, false):
		if poly.has_meta("kit_texture") and poly.name != &"Backdrop":
			var texture: Texture2D = _tex(kit, str(poly.get_meta("kit_texture")))
			if texture:
				var copy: Polygon2D = _textured(poly, texture, int(poly.get_meta("kit_z", Z_BACK)))
				copy.color = poly.get_meta("kit_tint", Color.WHITE)


## Hand-placed kit pieces under the level's `SkinDecor` node (see the class notes). Returns how many of the kit's own `decor/` pieces showed.
func _skin_decor(level: Node, kit: String) -> int:
	var root: Node = level.get_node_or_null("SkinDecor")
	if root == null:
		return 0
	var placed: int = 0
	for marker: Node in root.find_children("*", "Node2D", true, false):
		if not marker.has_meta("piece"):
			continue
		var texture: Texture2D = _tex(kit, str(marker.get_meta("piece")))
		if texture == null:
			continue
		var key: String = kit.path_join(str(marker.get_meta("piece"))) + "#used"
		if not _cache.has(key):
			_cache[key] = Rect2(texture.get_image().get_used_rect())
		var used: Rect2 = _cache[key]
		var size: float = float(marker.get_meta("size", 1.0)) * ART_SCALE
		var sprite: Sprite2D = _sprite(texture, DECOR_LAYERS.get(str(marker.get_meta("layer", "body")), Z_BODY))
		sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
		sprite.scale = Vector2.ONE * size
		sprite.flip_h = bool(marker.get_meta("flip", false))
		var anchor := Vector2(used.get_center().x, used.position.y if marker.get_meta("hang", false) else used.end.y)
		if sprite.flip_h:
			anchor.x = texture.get_width() - anchor.x
		sprite.position = to_local((marker as Node2D).global_position) - anchor * size
		sprite.modulate = marker.get_meta("tint", Color.WHITE)
		if str(marker.get_meta("piece")).begins_with("decor/"):  # only kit-specific decor counts as composed
			placed += 1
	return placed


## Portal doors become dark doorways of back wall in a frame of the kit's fill.
func _doors(level: Node, kit: String) -> void:
	var back: Texture2D = _tex(kit, "back")
	if back == null:
		return
	var frame: Texture2D = _tex(kit, "fill")
	for door: Node in level.find_children("Door", "Polygon2D", true, false):
		var piece: Texture2D = _tex(kit, str(door.get_meta("piece"))) if door.has_meta("piece") else null
		if piece:  # the kit draws this doorway as a piece standing on the door's bottom centre
			var size: float = float(door.get_meta("size", 1.0)) * ART_SCALE
			var used := Rect2(piece.get_image().get_used_rect())
			var sprite: Sprite2D = _sprite(piece, Z_LANDMARK)
			sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
			sprite.scale = Vector2.ONE * size
			sprite.position = to_local(door.global_position) + Vector2(float(door.get_meta("offset_x", 0.0)), 2.0) \
					- Vector2(used.get_center().x, used.end.y) * size
			_hide(door)
			if door.get_parent().get_node_or_null("Threshold") is CanvasItem:
				_hide(door.get_parent().get_node("Threshold"))
			continue
		if frame:
			var outline: Polygon2D = _textured(door, frame, Z_BODY)
			var grown := PackedVector2Array()
			for point: Vector2 in door.polygon:
				grown.append(Vector2(point.x * 1.35, point.y * 1.2 if point.y < 0.0 else point.y))
			outline.polygon = grown
		var doorway: Polygon2D = _textured(door, back, Z_BODY)
		doorway.color = Color(0.5, 0.5, 0.55)
		if door.get_parent().get_node_or_null("Threshold") is CanvasItem:
			_hide(door.get_parent().get_node("Threshold"))


## A copy of `source` in this node's space with `texture` tiled at art scale and aligned to world space;
## the source polygon is hidden.
func _textured(source: Polygon2D, texture: Texture2D, z: int) -> Polygon2D:
	var copy := Polygon2D.new()
	copy.transform = get_global_transform().affine_inverse() * source.get_global_transform()
	copy.polygon = source.polygon
	copy.texture = texture
	copy.texture_scale = Vector2.ONE / ART_SCALE
	copy.texture_offset = copy.position / ART_SCALE  # world-aligned tiling
	copy.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	copy.z_index = z
	_dressing.add_child(copy)
	_hide(source)
	return copy


## Darkens solid ground towards the bottom of the course.
func _shade(area: Rect2) -> void:
	if depth_shade <= 0.0 or area.size.y <= 0.0:
		return
	if not _cache.has("#shade"):
		var gradient := Gradient.new()
		gradient.set_color(0, Color(0, 0, 0, 0))
		gradient.set_color(1, Color(0, 0, 0, 1))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.width = 1
		texture.height = 64
		texture.fill_to = Vector2(0, 1)
		_cache["#shade"] = texture
	var shade := Sprite2D.new()
	shade.texture = _cache["#shade"]
	shade.centered = false
	shade.position = area.position
	shade.scale = Vector2(area.size.x, area.size.y / 64.0)
	shade.z_index = Z_FOUNDATION
	shade.modulate.a = depth_shade * clampf((course_bottom - area.position.y) / 160.0, 0.0, 1.0)
	_dressing.add_child(shade)


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
	var stage: Texture2D = _tex(kit, "arena") if arena else null
	if stage:
		var size: Vector2 = stage.get_size() * ART_SCALE
		var sprite: Sprite2D = _sprite(stage, Z_FAR)
		sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
		sprite.position = Vector2((ARENA_WIDTH - size.x) * 0.5, course_bottom - size.y)
	var far: bool = false
	if not stage:  # one layer per distinct far/mid/near texture the zones use
		for kind: String in ["far", "mid", "near"]:
			var names: PackedStringArray = []
			for zone: Dictionary in _zones:
				if _tex(kit, zone[kind]) == null:
					zone[kind] = kind  # this kit lacks the zone's variant: use its plain layer
				if not names.has(zone[kind]):
					names.append(zone[kind])
			for name: String in names:
				var texture: Texture2D = _tex(kit, name)
				if texture == null:
					continue
				var layer: Parallax2D
				match kind:
					"far": layer = _parallax(texture, Vector2(0.15, 0.0), Z_FAR)
					"mid": layer = _parallax(texture, Vector2(0.45, 0.0), Z_MID)
					_: layer = _parallax(texture, Vector2(1.25, 1.0), Z_NEAR)
				_layers.append({"node": layer, "kind": kind, "name": name})
				far = far or kind == "far"
		if _layers.size() > 0:
			_blend_zones(_zones[0].x if is_finite(_zones[0].x) else 0.0)
		set_process(_zones.size() > 1 and not Engine.is_editor_hint())
	if stage or far:
		for name: String in ["Background", "Backdrop"] if arena else ["Background"]:
			for backdrop: Node in level.find_children(name, "CanvasItem", true, false):
				_hide(backdrop)
	var water: Texture2D = _tex(kit, "water")
	var line: Polygon2D = level.get_node_or_null("RiverLine") as Polygon2D
	if line == null:
		line = level.get_node_or_null("WaterLine") as Polygon2D
	if water and line:
		var points: PackedVector2Array = (get_global_transform().affine_inverse() * line.get_global_transform()) * line.polygon
		var rect := Rect2(points[0], Vector2.ZERO)
		for point: Vector2 in points:
			rect = rect.expand(point)
		# The line marks where a missed jump lands; the surface sits a little above it and runs off the bottom.
		var top: float = rect.position.y - WATER_ABOVE_LINE
		_water = _strip(water, Rect2(rect.position.x, top, rect.size.x, maxf(course_bottom, rect.end.y) - top), Z_WATER)
		var surface: Texture2D = _tex(kit, "water-top")  # ripple line along the surface, over submerged steps
		if surface:
			_surface = _strip(surface, Rect2(rect.position.x, top - surface.get_height() * ART_SCALE * cap_surface, rect.size.x, surface.get_height() * ART_SCALE), Z_BODY)
		_hide(line)
		set_process(not Engine.is_editor_hint())


## Zones from the level's `SkinZones` markers, sorted by x; without any, one zone using the plain kit files.
func _read_zones(level: Node) -> void:
	_zones.clear()
	var markers: Node = level.get_node_or_null("SkinZones")
	for marker: Node in markers.get_children() if markers else []:
		if marker is Node2D:
			var tint: Color = marker.get_meta("tint", Color.WHITE)
			_zones.append({"x": to_local(marker.global_position).x, "skin": str(marker.get_meta("skin", "")),
					"far": str(marker.get_meta("far", "far")), "mid": str(marker.get_meta("mid", "mid")),
					"near": str(marker.get_meta("near", "near")), "tint": tint, "mid_tint": marker.get_meta("mid_tint", tint)})
	_zones.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.x < b.x)
	if _zones.is_empty():
		_zones.append({"x": -INF, "skin": "", "far": "far", "mid": "mid", "near": "near", "tint": Color.WHITE, "mid_tint": Color.WHITE})


func _zone_at(x: float) -> Dictionary:
	var found: Dictionary = _zones[0] if not _zones.is_empty() else {}
	for zone: Dictionary in _zones:
		if zone.x <= x:
			found = zone
	return found


## Crossfades the zone parallax layers for a camera centred at `x`: each zone's weight ramps over ZONE_BLEND
## around its borders; layers take their zones' weights and tints. Opaque far layers are composited so the
## blend never shows the clear colour through both.
func _blend_zones(x: float) -> void:
	var weights: Array[float] = []
	for i: int in _zones.size():
		var enter: float = 1.0 if i == 0 else clampf((x - _zones[i].x) / ZONE_BLEND + 0.5, 0.0, 1.0)
		var leave: float = 0.0 if i == _zones.size() - 1 else clampf((x - _zones[i + 1].x) / ZONE_BLEND + 0.5, 0.0, 1.0)
		weights.append(enter * (1.0 - leave))
	var total: float = 0.0
	for layer: Dictionary in _layers:
		var weight: float = 0.0
		var tint := Color(0, 0, 0, 0)
		for i: int in _zones.size():
			if _zones[i][layer.kind] == layer.name:
				weight += weights[i]
				tint += (_zones[i].mid_tint if layer.kind == "mid" else _zones[i].tint) * weights[i]
		tint = tint / weight if weight > 0.0 else Color.WHITE
		var alpha: float = weight
		if layer.kind == "far":
			total += weight
			alpha = weight / total if total > 0.0 else 0.0
		var node: Parallax2D = layer.node
		node.modulate = Color(tint.r, tint.g, tint.b, alpha)
		node.visible = alpha > 0.001


## A horizontally repeating layer anchored to the course bottom. Far and mid layers are pinned to the screen
## vertically (scroll y 0; the camera never moves vertically on the main course).
func _parallax(texture: Texture2D, scroll: Vector2, z: int) -> Parallax2D:
	var layer := Parallax2D.new()
	layer.z_index = z
	layer.scroll_scale = scroll
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
	return layer


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
