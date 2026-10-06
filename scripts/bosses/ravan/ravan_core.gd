extends StaticBody2D
## The amrit in Swaminathan's navel. Only collides with player attacks while exposed.
const ENEMY_BODY_LAYER: int = 4

var exposed: bool = false
var health: int:
	get:
		return get_parent().core_health


func _ready() -> void:
	collision_mask = 0
	close()


func open() -> void:
	exposed = true
	collision_layer = ENEMY_BODY_LAYER
	queue_redraw()


func close() -> void:
	exposed = false
	collision_layer = 0
	queue_redraw()


func take_damage(amount: int, _knockback: Vector2) -> void:
	get_parent().damage_core(amount)


func _process(_delta: float) -> void:
	if exposed:
		queue_redraw()


func _draw() -> void:
	if not exposed:
		# A dull navel jewel hints at the weak point all fight long.
		draw_circle(Vector2.ZERO, 6.0, Color(0.45, 0.4, 0.2))
		draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 16, Color(0.3, 0.25, 0.15), 2.0)
		return
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
	draw_circle(Vector2.ZERO, 22.0 + pulse * 4.0, Color(0.4, 1.0, 0.75, 0.25))
	draw_circle(Vector2.ZERO, 14.0, Color(0.55, 1.0, 0.8))
	draw_circle(Vector2.ZERO, 7.0, Color(1.0, 1.0, 0.85))
	draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 24, Color(1.0, 0.95, 0.5), 2.0)
