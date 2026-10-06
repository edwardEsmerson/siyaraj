extends Node2D
## Ravan's body: one full-body sprite per head state (10 heads down to 0). Heads
## are lost right to left, so state n shows the leftmost n heads. Until the art
## exists, a code-drawn placeholder shows the same body and heads.
##
## Art: res://assets/sprites/swaminathan-states/state_10.png ... state_00.png,
## all the same canvas size, with Ravan's feet at the bottom centre. Placed at
## scale 0.5 (1 game unit = 2 art px). See docs/bosses/boss2-ravan.md.

const STATE_PATH: String = "res://assets/sprites/swaminathan-states/state_%02d.png"
const HEAD_COUNT: int = 10
## Centre of each head's face, in game units relative to the feet (the boss
## origin), numbered left to right. Heads are lost from index 9 down to 0. This is
## the single source for attack origins, telegraph glows and head pops: re-align
## it to the approved state_10.png when the art lands.
const HEAD_OFFSETS: Array[Vector2] = [
	Vector2(-198, -150.0), Vector2(-154, -161.9), Vector2(-110, -170.7), Vector2(-66, -176.7), Vector2(-22, -179.6),
	Vector2(22, -179.6), Vector2(66, -176.7), Vector2(110, -170.7), Vector2(154, -161.9), Vector2(198, -150.0),
]
## Attacks leave from the mouth, a little below the face centre.
const MOUTH_OFFSET: Vector2 = Vector2(0, 10)
const SHOULDER_Y: float = -118.0

const SKIN := Color(0.55, 0.36, 0.28)
const BODY := Color(0.4, 0.28, 0.25)
const ARM := Color(0.45, 0.31, 0.26)
const GOLD := Color(0.9, 0.7, 0.2)
const DHOTI := Color(0.78, 0.5, 0.12)
const NECK := Color(0.33, 0.24, 0.22)
const STUMP := Color(0.3, 0.1, 0.08)

## Living heads, 0 to 10. Setting it swaps the body sprite.
var head_count: int = HEAD_COUNT:
	set(value):
		head_count = clampi(value, 0, HEAD_COUNT)
		_apply_state()

var _textures: Array[Texture2D] = []

@onready var art: Sprite2D = $Art


static func mouth_offset(index: int) -> Vector2:
	return HEAD_OFFSETS[index] + MOUTH_OFFSET


func _ready() -> void:
	for state in range(HEAD_COUNT + 1):
		var path := STATE_PATH % state
		_textures.append(load(path) as Texture2D if ResourceLoader.exists(path) else null)
	art.scale = Vector2(0.5, 0.5)
	_apply_state()


func has_art() -> bool:
	return art != null and art.texture != null


func _apply_state() -> void:
	if not is_node_ready():
		return
	var texture: Texture2D = _textures[head_count]
	art.texture = texture
	art.visible = texture != null
	if texture != null:
		# Feet at the node origin: the canvas's bottom centre.
		art.offset = Vector2(0, -texture.get_height() * 0.5)
	queue_redraw()


func _draw() -> void:
	if has_art():
		return
	# Placeholder body, feet at the origin.
	draw_colored_polygon(PackedVector2Array([Vector2(-50, -118), Vector2(-68, -112), Vector2(-78, -52), Vector2(-62, -48), Vector2(-50, -98)]), ARM)
	draw_colored_polygon(PackedVector2Array([Vector2(50, -118), Vector2(68, -112), Vector2(78, -52), Vector2(62, -48), Vector2(50, -98)]), ARM)
	draw_colored_polygon(PackedVector2Array([Vector2(-44, 0), Vector2(-6, 0), Vector2(0, -12), Vector2(6, 0), Vector2(44, 0), Vector2(36, -40), Vector2(-36, -40)]), DHOTI)
	draw_colored_polygon(PackedVector2Array([Vector2(-38, -40), Vector2(38, -40), Vector2(52, -118), Vector2(-52, -118)]), BODY)
	draw_colored_polygon(PackedVector2Array([Vector2(-40, -26), Vector2(40, -26), Vector2(38, -46), Vector2(-38, -46)]), GOLD)
	for index in range(HEAD_COUNT):
		var head := HEAD_OFFSETS[index]
		var anchor := Vector2(head.x * 0.3, SHOULDER_Y)
		if index < head_count:
			draw_line(anchor, head, NECK, 7.0)
		else:
			# A short stump where a lost head was.
			var stump := anchor.lerp(head, 0.35)
			draw_line(anchor, stump, NECK, 7.0)
			draw_circle(stump, 5.0, STUMP)
	draw_colored_polygon(PackedVector2Array([Vector2(-58, -120), Vector2(58, -120), Vector2(40, -100), Vector2(0, -92), Vector2(-40, -100)]), GOLD)
	for index in range(head_count):
		_draw_head(HEAD_OFFSETS[index])


func _draw_head(at: Vector2) -> void:
	var face := PackedVector2Array([Vector2(-12, -12), Vector2(12, -12), Vector2(15, 0), Vector2(10, 14), Vector2(-10, 14), Vector2(-15, 0)])
	var crown := PackedVector2Array([Vector2(-13, -11), Vector2(-13, -24), Vector2(-7, -17), Vector2(0, -28), Vector2(7, -17), Vector2(13, -24), Vector2(13, -11)])
	var jewel := PackedVector2Array([Vector2(0, -21), Vector2(3, -17), Vector2(0, -13), Vector2(-3, -17)])
	var moustache := PackedVector2Array([Vector2(-10, 6), Vector2(0, 4), Vector2(10, 6), Vector2(6, 8), Vector2(0, 6), Vector2(-6, 8)])
	draw_set_transform(at)
	draw_colored_polygon(face, SKIN)
	draw_colored_polygon(crown, Color(0.95, 0.75, 0.2))
	draw_colored_polygon(jewel, Color(0.85, 0.15, 0.2))
	draw_rect(Rect2(-9, -4, 6, 4), Color(1, 0.95, 0.75))
	draw_rect(Rect2(3, -4, 6, 4), Color(1, 0.95, 0.75))
	draw_colored_polygon(moustache, Color(0.12, 0.08, 0.08))
	draw_rect(Rect2(-4, 9, 8, 3), Color(0.25, 0.05, 0.05))
	draw_set_transform(Vector2.ZERO)
