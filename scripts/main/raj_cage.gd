extends Node2D
## A decorative hanging cage. It never changes arena collision or hazards.
## Art is packaged by tools/raj_cage_art.py: Raj sits between the back layer
## (interior, back bars, floor) and the front bars; the origin is the cage base.

const ART: String = "res://assets/sprites/raj-cage/"
## Layer canvas is 260 x 308 art px with the anchor at its bottom centre.
const LAYER_OFFSET: Vector2 = Vector2(-130, -308)
## Raj's feet on the floor plate, and the top of the hanging ring, in game units.
const FLOOR_Y: float = -22.0
const RING_TOP: float = -150.0

var freed: bool = false
var raj: AnimatedSprite2D
var bars: Sprite2D
var back: Sprite2D
var _chain: Texture2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_chain = _art("chain.png")
	back = _layer("back.png")
	raj = AnimatedSprite2D.new()
	raj.sprite_frames = preload("res://assets/sprites/raj/cast_frames.tres")
	raj.scale = Vector2.ONE * 0.5
	raj.centered = false
	raj.offset = Vector2(-64, -120)
	raj.position = Vector2(0, FLOOR_Y)
	add_child(raj)
	raj.play(&"sulk")
	bars = _layer("front_closed.png")
	var nameplate := Label.new()
	nameplate.text = "Raj"
	nameplate.position = Vector2(-40, 2)
	nameplate.size = Vector2(80, 22)
	nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(nameplate)
	queue_redraw()


func release() -> void:
	freed = true
	raj.play(&"freed")
	bars.texture = _art("front_open.png")


## The chain runs from the ring up past the top of the screen.
func _draw() -> void:
	var top: float = minf(-global_position.y - 8.0, RING_TOP)
	if _chain == null:
		draw_line(Vector2(0, top), Vector2(0, RING_TOP + 6.0), Color(0.65, 0.52, 0.3), 4.0)
		return
	var size: Vector2 = _chain.get_size() * 0.5
	var y: float = RING_TOP + 5.0 - size.y
	while y + size.y > top:
		draw_texture_rect(_chain, Rect2(Vector2(-size.x * 0.5, y), size), false)
		y -= size.y


func _layer(file: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _art(file)
	sprite.scale = Vector2.ONE * 0.5
	sprite.centered = false
	sprite.offset = LAYER_OFFSET
	add_child(sprite)
	return sprite


func _art(file: String) -> Texture2D:
	var path: String = ART + file
	return load(path) if ResourceLoader.exists(path) else null
