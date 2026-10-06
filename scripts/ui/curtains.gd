extends Control
## Shared curtain fabric for checkpoint returns and death respawns.

const CURVE_SEGMENTS: int = 32
const TOP_TRAVEL: float = 0.64
const BOTTOM_DELAY: float = 0.36

var opening: bool = false
var coverage: float = 0.0:
	set(value):
		coverage = value
		queue_redraw()

func coverage_at(height_fraction: float) -> float:
	# The rail finishes first. Each lower strip starts later, so the hem
	# keeps moving after the top stops. Reverse travel for the opening pull.
	var progress := 1.0 - coverage if opening else coverage
	var delay := BOTTOM_DELAY * pow(clampf(height_fraction, 0.0, 1.0), 1.7)
	var travel := smoothstep(0.0, 1.0, clampf((progress - delay) / TOP_TRAVEL, 0.0, 1.0))
	return 1.0 - travel if opening else travel

func _point(side: int, row: int, inset: float = 0.0) -> Vector2:
	var height_fraction := float(row) / CURVE_SEGMENTS
	var edge := size.x * 0.5 * coverage_at(height_fraction)
	var x := edge - inset
	return Vector2(x if side == 0 else size.x - x, size.y * height_fraction)

func _draw() -> void:
	var panel_width := size.x * 0.5
	for side in [0, 1]:
		var outer := 0.0 if side == 0 else size.x
		var panel := PackedVector2Array([Vector2(outer, 0)])
		var edge := PackedVector2Array()
		for row in range(CURVE_SEGMENTS + 1):
			var point := _point(side, row)
			panel.append(point)
			edge.append(point)
		panel.append(Vector2(outer, size.y))
		# At a fully open endpoint the panel has zero area.
		if coverage_at(1.0) > 0.0 or coverage_at(0.0) > 0.0:
			draw_colored_polygon(panel, Color(0.22, 0.025, 0.07))
			# Folds travel with the fabric instead of stretching with its width.
			for fold in range(12):
				var stripe := PackedVector2Array()
				var inset := panel_width * float(fold) / 12.0
				for row in range(CURVE_SEGMENTS + 1):
					stripe.append(_point(side, row, inset))
				for row in range(CURVE_SEGMENTS, -1, -1):
					stripe.append(_point(side, row, inset + panel_width / 24.0))
				draw_colored_polygon(stripe, Color(0.32, 0.04, 0.1))
			draw_polyline(edge, Color(0.95, 0.65, 0.2), 3.0, true)
