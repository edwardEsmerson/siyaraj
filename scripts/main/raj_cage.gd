extends Node2D
## A decorative hanging cage. It never changes arena collision or hazards.

var freed: bool = false
var raj: AnimatedSprite2D
var bars: Node2D


func _ready() -> void:
	raj = AnimatedSprite2D.new()
	raj.sprite_frames = preload("res://assets/sprites/raj/cast_frames.tres")
	raj.scale = Vector2.ONE * 0.5
	raj.centered = false
	raj.offset = Vector2(-64, -120)
	raj.position = Vector2(0, -8)
	add_child(raj)
	raj.play(&"sulk")
	bars = Node2D.new()
	bars.draw.connect(_draw_bars.bind(bars))
	add_child(bars)
	var nameplate := Label.new()
	nameplate.text = "Raj"
	nameplate.position = Vector2(-40, -126)
	nameplate.size = Vector2(80, 22)
	nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(nameplate)
	queue_redraw()


func release() -> void:
	freed = true
	raj.play(&"freed")
	bars.queue_redraw()


func _draw() -> void:
	draw_line(Vector2(0, -180), Vector2(0, -100), Color(0.65, 0.52, 0.3), 4.0)
	draw_rect(Rect2(-40, -100, 80, 100), Color(0.05, 0.035, 0.07, 0.85))


func _draw_bars(bars: Node2D) -> void:
	var metal := Color(0.86, 0.7, 0.4)
	bars.draw_rect(Rect2(-40, -100, 80, 100), metal, false, 4.0)
	if not freed:
		for x: int in [-24, -8, 8, 24]:
			bars.draw_line(Vector2(x, -100), Vector2(x, 0), metal, 3.0)
		bars.draw_rect(Rect2(-8, -44, 16, 16), metal)
