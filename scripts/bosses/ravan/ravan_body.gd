extends Node2D
## Swaminathan's body: the approved headless body (`assets/sprites/swaminathan`,
## animated from its cast SpriteFrames) with ten separate heads
## (`assets/sprites/swaminathan-head`) on generated neck art. Heads are lost right
## to left, so with n heads alive the leftmost n remain and severed necks end in a
## stump. Every frame is placed at scale 0.5 (1 game unit = 2 art px) with the feet
## on the node origin.
##
## Registration: each body frame's collar point (where the necks leave the torso)
## is recorded in cast_meta.json as `attachment.collar_from_anchor_px`; the head row
## follows the collar's movement from the idle pose, so heads stay on the body in
## every animation. Attack origins never move: they are HEAD_OFFSETS (gameplay).
## Hurt flash, Fury tint and the death flash are modulate effects from
## ravan_boss.gd on this node. See docs/bosses/boss2-ravan.md.

const BODY_FRAMES: String = "res://assets/sprites/swaminathan/cast_frames.tres"
const BODY_META: String = "res://assets/sprites/swaminathan/cast_meta.json"
const HEAD_FRAMES: String = "res://assets/sprites/swaminathan-head/cast_frames.tres"
const HEAD_META: String = "res://assets/sprites/swaminathan-head/cast_meta.json"
const RavanFx = preload("res://scripts/bosses/ravan/ravan_fx.gd")
const HEAD_COUNT: int = 10
## Centre of each head's face, in game units relative to the feet (the boss
## origin), numbered left to right. Heads are lost from index 9 down to 0. This
## is the single source for attack origins, telegraphs, head pops and Fury aims.
const HEAD_OFFSETS: Array[Vector2] = [
	Vector2(-94.5, -138), Vector2(-72.5, -148), Vector2(-52, -156), Vector2(-33, -161), Vector2(-13.5, -164.5),
	Vector2(8.5, -166.5), Vector2(32, -161.5), Vector2(52.5, -155), Vector2(74.5, -147), Vector2(98, -138),
]
## Attacks leave from the mouth, under the moustache.
const MOUTH_OFFSET: Vector2 = Vector2(0, 8)
## Where a neck meets the bottom of its head sprite, from the face centre.
const NECK_TOP: Vector2 = Vector2(0, 13)
## How far apart the necks leave the collar, as a fraction of the head spread.
const COLLAR_SPREAD: float = 0.16
## A severed neck keeps this much of its length as a stump (game units).
const STUMP_LENGTH: float = 18.0
## Body animations that show no neck: the headless body falls on its own.
const NECKLESS: Array[StringName] = [&"dying", &"dead"]

enum HeadPose { FACE, TELEGRAPH, ATTACK, EXHAUSTED, FURY, DARK }
const HEAD_ANIMS: Dictionary = {
	HeadPose.FACE: &"faces", HeadPose.TELEGRAPH: &"telegraph", HeadPose.ATTACK: &"attack",
	HeadPose.EXHAUSTED: &"exhausted", HeadPose.FURY: &"fury", HeadPose.DARK: &"faces",
}

## Living heads, 0 to 10. Setting it hides severed heads and caps their necks.
var head_count: int = HEAD_COUNT:
	set(value):
		head_count = clampi(value, 0, HEAD_COUNT)
		_apply_heads()

var heads: Array[AnimatedSprite2D] = []
var necks: Array[Line2D] = []
var _head_poses: Array[int] = []
var _collars: Dictionary = {}
var _rest_collar: Vector2 = Vector2(4, -118)
var _pose: StringName = &""
var _held: bool = false
var _neck_texture: Texture2D
var _stump_texture: Texture2D
var _neck_layer := Node2D.new()
var _head_layer := Node2D.new()

@onready var art: AnimatedSprite2D = $Art


static func mouth_offset(index: int) -> Vector2:
	return HEAD_OFFSETS[index] + MOUTH_OFFSET


func _ready() -> void:
	art.centered = false
	art.scale = Vector2(0.5, 0.5)
	if ResourceLoader.exists(BODY_FRAMES):
		art.sprite_frames = load(BODY_FRAMES)
	var meta := _read_json(BODY_META)
	var anchor: Array = meta.get("anchor", [235, 345])
	art.offset = -Vector2(anchor[0], anchor[1])
	var collars: Dictionary = meta.get("attachment", {}).get("collar_from_anchor_px", {})
	for anim: String in collars:
		var points: Array[Vector2] = []
		for point: Array in collars[anim]:
			points.append(Vector2(point[0], point[1]) * 0.5)
		_collars[StringName(anim)] = points
	if _collars.has(&"idle"):
		_rest_collar = _collars[&"idle"][0]
	_neck_texture = RavanFx.texture(&"neck")
	_stump_texture = RavanFx.texture(&"neck-stump")
	# Necks leave from behind the collar; heads sit in front of the whole body.
	_neck_layer.z_index = -1
	add_child(_neck_layer)
	_head_layer.z_index = 1
	add_child(_head_layer)
	var head_frames: SpriteFrames = load(HEAD_FRAMES) if ResourceLoader.exists(HEAD_FRAMES) else null
	var head_anchor: Array = _read_json(HEAD_META).get("anchor", [64, 64])
	for index in range(HEAD_COUNT):
		var neck := Line2D.new()
		neck.texture = _neck_texture
		neck.texture_mode = Line2D.LINE_TEXTURE_STRETCH
		neck.default_color = Color.WHITE if _neck_texture != null else Color("552648")
		neck.width = _neck_texture.get_height() * 0.5 if _neck_texture != null else 8.0
		neck.joint_mode = Line2D.LINE_JOINT_ROUND
		_neck_layer.add_child(neck)
		necks.append(neck)
		var head := AnimatedSprite2D.new()
		head.name = "Head%d" % index
		head.centered = false
		head.scale = Vector2(0.5, 0.5)
		head.offset = -Vector2(head_anchor[0], head_anchor[1])
		head.sprite_frames = head_frames
		head.animation_finished.connect(_on_head_finished.bind(index))
		heads.append(head)
		_head_poses.append(-1)
	# Outer heads first, so the centre heads overlap their neighbours' moustaches.
	var order := range(HEAD_COUNT)
	order.sort_custom(func(a: int, b: int) -> bool: return absf(a - 4.5) > absf(b - 4.5))
	for index: int in order:
		_head_layer.add_child(heads[index])
	art.frame_changed.connect(_place_heads)
	art.animation_changed.connect(_place_heads)
	for index in range(HEAD_COUNT):
		set_head_pose(index, HeadPose.FACE)
	set_pose(&"idle")
	_apply_heads()


func has_art() -> bool:
	return art != null and art.sprite_frames != null and art.sprite_frames.has_animation(&"idle")


## Plays a body animation. `speed` scales its authored FPS; `hold` >= 0 shows one
## frame of it, paused (used to sync a wind-up/strike pair to a head attack).
func set_pose(anim: StringName, speed: float = 1.0, hold: int = -1) -> void:
	if not has_art():
		return
	if not art.sprite_frames.has_animation(anim):
		anim = &"idle"
	art.speed_scale = speed
	if hold >= 0:
		hold = mini(hold, art.sprite_frames.get_frame_count(anim) - 1)
		if art.animation != anim:
			art.animation = anim
		if art.frame != hold:
			art.frame = hold
		art.pause()
		_held = true
		_pose = anim
	elif _pose != anim or _held:
		_pose = anim
		_held = false
		art.play(anim)
	_neck_layer.visible = not NECKLESS.has(anim)


func pose() -> StringName:
	return art.animation


func set_head_pose(index: int, head_pose: HeadPose, speed: float = 1.0) -> void:
	var head := heads[index]
	if head.sprite_frames == null:
		return
	head.speed_scale = speed
	head.modulate = Color(0.42, 0.45, 0.55) if head_pose == HeadPose.DARK else Color.WHITE
	if _head_poses[index] == head_pose:
		return
	_head_poses[index] = head_pose
	var anim: StringName = HEAD_ANIMS[head_pose]
	if anim == &"faces":
		# Each head keeps its own expression (Mada to Chitta) when idle.
		head.animation = anim
		head.frame = index % head.sprite_frames.get_frame_count(anim)
		head.pause()
	else:
		head.play(anim)


func head_pose(index: int) -> int:
	return _head_poses[index]


## Where head `index` is drawn now, relative to the boss origin (follows the body).
func head_position(index: int) -> Vector2:
	return position + HEAD_OFFSETS[index] + _collar_shift()


## The severed head bursts (cracks, sparks, falling crown) where it was.
func pop_head(index: int) -> void:
	var pop := RavanFx.head_sprite(&"destroyed", heads[index].sprite_frames, heads[index].offset)
	if pop == null:
		return
	pop.position = HEAD_OFFSETS[index] + _collar_shift()
	pop.z_index = 2
	add_child(pop)


func _on_head_finished(index: int) -> void:
	# Attack and other one-shot faces settle back on the head's own expression.
	if _head_poses[index] == HeadPose.ATTACK:
		heads[index].pause()


func _collar_shift() -> Vector2:
	var points: Array = _collars.get(art.animation, [])
	if art.frame < points.size():
		return points[art.frame] - _rest_collar
	return Vector2.ZERO


func _apply_heads() -> void:
	if not is_node_ready():
		return
	for index in range(HEAD_COUNT):
		heads[index].visible = index < head_count
		necks[index].texture = _neck_texture if index < head_count else _stump_texture
		if _stump_texture != null and index >= head_count:
			necks[index].width = _stump_texture.get_height() * 0.5
		elif _neck_texture != null:
			necks[index].width = _neck_texture.get_height() * 0.5
	_place_heads()


func _place_heads() -> void:
	if heads.is_empty():
		return
	var shift := _collar_shift()
	var collar := _rest_collar + shift
	for index in range(HEAD_COUNT):
		var head_at := HEAD_OFFSETS[index] + shift
		heads[index].position = head_at
		# Necks leave the collar side by side, rise, then bend out into the head.
		var start := collar + Vector2(HEAD_OFFSETS[index].x * COLLAR_SPREAD, 4)
		var end := head_at + NECK_TOP
		var bend := Vector2(lerpf(start.x, end.x, 0.25), minf(end.y, start.y) - 10.0)
		var points := PackedVector2Array()
		if index < head_count:
			for step in range(9):
				var t := step / 8.0
				points.append(start.lerp(bend, t).lerp(bend.lerp(end, t), t))
		else:
			var toward := (bend - start).normalized()
			points.append(start)
			points.append(start + toward * STUMP_LENGTH)
		necks[index].points = points


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}
