extends Node2D
## Small code-drawn sparks. Never participate in physics or change combat timing.

var tint: Color = Color(1.0, 0.7, 0.2)
var label: String = ""
var lifetime: float = 0.28
var spread: float = 25.0
var age: float = 0.0


static func spawn(parent: Node, at: Vector2, color: Color, word: String = "", radius: float = 25.0) -> void:
	var effect := preload("res://scripts/effects/burst.gd").new()
	effect.tint = color
	effect.label = word
	effect.spread = radius
	parent.add_child(effect)
	effect.global_position = at


func _ready() -> void:
	z_index = 10


func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	var progress := age / lifetime
	var color := tint
	color.a = 1.0 - progress
	for index in range(8):
		var direction := Vector2.RIGHT.rotated(index * TAU / 8.0)
		var start := direction * (4.0 + progress * spread)
		draw_line(start, start + direction * (8.0 * (1.0 - progress)), color, 2.0)
	draw_arc(Vector2.ZERO, 3.0 + progress * spread * 0.6, 0.0, TAU, 20, color, 1.5)
	if not label.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(-18, -26 - progress * 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
