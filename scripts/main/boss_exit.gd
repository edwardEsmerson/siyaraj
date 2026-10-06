extends Area2D
## A campaign exit appears only after its boss has finished dying.

signal player_entered

var _elapsed: float = 0.0
var _triggered: bool = false


func _ready() -> void:
	# Keep the route marker visible above the world's foreground decorations.
	z_index = 5
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(36, 110)
	shape.shape = rectangle
	shape.position.y = -50
	add_child(shape)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if _triggered or get_tree().paused:
		return
	var player: CharacterBody2D = get_parent().get_node("Player")
	if player.state != player.State.DEAD and overlaps_body(player):
		_triggered = true
		player_entered.emit()


func _draw() -> void:
	var pulse := 0.8 + sin(_elapsed * 3.0) * 0.2
	for ring: int in range(6, 0, -1):
		var glow := StyleBoxFlat.new()
		glow.bg_color = Color(1.0, 0.75, 0.25, 0.075 * pulse)
		glow.set_corner_radius_all(24)
		draw_style_box(glow, Rect2(-10 - ring * 4, -110 - ring * 2, 20 + ring * 8, 110 + ring * 2))
	draw_line(Vector2(0, -96), Vector2(0, -8), Color(1.0, 0.95, 0.65, 0.95 * pulse), 6.0, true)
	for spark: int in 8:
		var progress := fmod(_elapsed * 0.3 + spark / 8.0, 1.0)
		var point := Vector2(sin(spark * 2.4 + _elapsed) * 20, -progress * 110)
		draw_circle(point, 1.5, Color(1.0, 0.9, 0.65, sin(progress * PI) * pulse))
