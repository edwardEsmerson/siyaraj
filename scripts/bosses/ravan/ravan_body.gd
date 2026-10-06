extends Node2D
## Ravan's body: one full-body sprite per head state (10 heads down to 0). Heads
## are lost right to left, so state n shows the leftmost n heads, and severed
## necks end in a stump. Hurt flash, Fury tint and the death flash are modulate
## effects from ravan_boss.gd on this node.
##
## Art: res://assets/sprites/swaminathan-states/state_10.png ... state_00.png,
## 464 x 384 art px each, Ravan's feet (midway between them) at the bottom
## centre. Placed at scale 0.5 (1 game unit = 2 art px). Built from the approved
## asset-builder/sprites/swaminathan-full by tools/swaminathan_states.py, which
## also prints the head offsets below. See docs/bosses/boss2-ravan.md.

const STATE_PATH: String = "res://assets/sprites/swaminathan-states/state_%02d.png"
const HEAD_COUNT: int = 10
## Centre of each head's face, in game units relative to the feet (the boss
## origin), numbered left to right; measured from state_10.png. Heads are lost
## from index 9 down to 0. This is the single source for attack origins,
## telegraph glows, head pops and Fury aim lines.
const HEAD_OFFSETS: Array[Vector2] = [
	Vector2(-94.5, -138), Vector2(-72.5, -148), Vector2(-52, -156), Vector2(-33, -161), Vector2(-13.5, -164.5),
	Vector2(8.5, -166.5), Vector2(32, -161.5), Vector2(52.5, -155), Vector2(74.5, -147), Vector2(98, -138),
]
## Attacks leave from the mouth, under the moustache.
const MOUTH_OFFSET: Vector2 = Vector2(0, 8)

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
	# Fallback when the art is not imported yet: body block and head dots.
	draw_rect(Rect2(-40, -110, 80, 110), Color(0.37, 0.24, 0.42))
	for index in range(head_count):
		draw_line(Vector2(0, -110), HEAD_OFFSETS[index], Color(0.26, 0.13, 0.31), 6.0)
		draw_circle(HEAD_OFFSETS[index], 12.0, Color(0.37, 0.24, 0.42))
