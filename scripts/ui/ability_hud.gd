extends CanvasLayer
## Compact campaign HUD. Legacy status nodes stay available to gameplay controllers.

const ORANGE: Color = Color("ffac45")
const BLUE: Color = Color("62baff")

class Indicators extends Control:
	var player: CharacterBody2D
	var skyshot_fraction: float = 1.0
	var chakri_fraction: float = 1.0

	func _process(_delta: float) -> void:
		if not is_instance_valid(player):
			return
		skyshot_fraction = clampf(float(player.skyshot_ammo) / player.MAX_SKYSHOT_AMMO, 0.0, 1.0)
		chakri_fraction = clampf(1.0 - player.chakri_cooldown_remaining / player.chakri_cooldown, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(player):
			return
		var rocket := size - Vector2(108, 44)
		var chakri := size - Vector2(44, 44)
		_ring(rocket, skyshot_fraction, ORANGE)
		_ring(chakri, chakri_fraction, BLUE)
		# Simple silhouettes keep the two abilities readable without instruction text.
		draw_colored_polygon(PackedVector2Array([
			rocket + Vector2(0, -12), rocket + Vector2(6, -3),
			rocket + Vector2(6, 7), rocket + Vector2(-6, 7), rocket + Vector2(-6, -3)
		]), Color("fff0d8"))
		draw_line(rocket + Vector2(-3, 10), rocket + Vector2(0, 15), ORANGE, 2, true)
		draw_line(rocket + Vector2(0, 15), rocket + Vector2(3, 10), ORANGE, 2, true)
		draw_arc(chakri, 10, 0, TAU, 32, Color("e8f5ff"), 2, true)
		for index in range(6):
			var direction := Vector2.from_angle(index * TAU / 6.0)
			draw_line(chakri + direction * 5, chakri + direction.rotated(0.3) * 13, Color("e8f5ff"), 2, true)
		for index in range(player.max_health):
			var at := Vector2(30 + index * 24, 28)
			var color := Color("f3776b") if index < player.health else Color("403b43")
			draw_colored_polygon(PackedVector2Array([
				at + Vector2(-9, -3), at + Vector2(-6, -7), at + Vector2(-2, -7),
				at, at + Vector2(2, -7), at + Vector2(6, -7), at + Vector2(9, -3),
				at + Vector2(9, 1), at + Vector2(0, 10), at + Vector2(-9, 1)
			]), color)

	func _ring(center: Vector2, fraction: float, color: Color) -> void:
		draw_circle(center + Vector2(0, 2), 27, Color(0, 0, 0, 0.3))
		draw_circle(center, 24, Color("171b26"))
		if fraction > 0.0:
			var points := PackedVector2Array([center])
			for index in range(49):
				points.append(center + Vector2.from_angle(-PI * 0.5 + TAU * fraction * index / 48.0) * 21)
			draw_colored_polygon(points, Color(color, 0.28))
		draw_arc(center, 24, 0, TAU, 64, Color(color, 0.4), 2, true)
		if fraction > 0.0:
			draw_arc(center, 24, -PI * 0.5, -PI * 0.5 + TAU * fraction, 64, color, 3, true)


func _ready() -> void:
	for child in get_children():
		if child is Label or child is ColorRect:
			child.hide()
	var indicators := Indicators.new()
	indicators.name = "AbilityIndicators"
	indicators.player = get_parent().get_node("Player")
	indicators.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicators.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(indicators)
	# Section names and greybox signs were development annotations.
	var course := get_parent().get_node_or_null("TestCourse")
	if course != null:
		for child in course.get_children():
			if child is Label:
				child.hide()
