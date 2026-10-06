extends Control
## Swaminathan-only add-on drawn above the generic BossHealthBar: one pip per head, each
## sitting over its tenth of the bar, so the pips go dark right to left as the bar
## drains. Lit in its attack colour while a head attacks. Below them: the phase
## and the number of heads left. Health itself is shown by
## `scenes/ui/boss_health_bar.tscn`.

var boss: Node


func _process(_delta: float) -> void:
	if not is_instance_valid(boss):
		return
	visible = boss.state != boss.State.DEAD
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(boss):
		return
	var font := preload("res://assets/fonts/YatraOne-Regular.ttf")
	# A dark backing keeps the row readable over any arena floor art.
	draw_rect(Rect2(-6, -3, size.x + 12, size.y + 2), Color(0.06, 0.05, 0.08, 0.8))
	var pip_gap: float = size.x / boss.HEAD_COUNT
	for head in boss.heads:
		var center: Vector2 = Vector2(pip_gap * (head.index + 0.5), 8)
		if not head.alive:
			# A severed head: hollow ring with a cross.
			var dead := Color(0.4, 0.36, 0.36)
			draw_arc(center, 5.0, 0.0, TAU, 16, dead, 1.5)
			draw_line(center + Vector2(-4, -4), center + Vector2(4, 4), dead, 1.5)
			draw_line(center + Vector2(-4, 4), center + Vector2(4, -4), dead, 1.5)
			continue
		var color := Color(0.95, 0.75, 0.35)
		var radius := 5.0
		if head.state == boss.HeadState.TELEGRAPH or head.state == boss.HeadState.ATTACK:
			color = head.attack_color()
			radius = 6.5
		elif boss.state == boss.State.FURY and head.fury_lit:
			color = boss.SAFE_COLOR if head.fury_silent else boss.FURY_COLOR
		draw_circle(center, radius + 1.5, Color(0.1, 0.06, 0.04))
		draw_circle(center, radius, color)
	var text_color := Color(0.85, 0.85, 0.9)
	draw_string(font, Vector2(0, 32), "PHASE %d/3" % boss.phase, HORIZONTAL_ALIGNMENT_LEFT, size.x, 14, Color(1.0, 0.85, 0.6))
	draw_string(font, Vector2(0, 32), "HEADS %d/%d" % [boss.heads_alive, boss.HEAD_COUNT], HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, text_color)
	if boss.is_spent():
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
		draw_string(font, Vector2(0, 32), "SPENT - STRIKE!", HORIZONTAL_ALIGNMENT_RIGHT, size.x, 14, Color(0.5, 1.0, 0.85, 0.5 + 0.5 * pulse))
