extends Control
## Ravan-only add-on drawn above the generic BossHealthBar: one pip per head,
## the current phase, the knockout goal and an AMRIT EXPOSED cue. Core health
## itself is shown by `scenes/ui/boss_health_bar.tscn`.
const RavanHead = preload("res://scripts/bosses/ravan/ravan_head.gd")

var boss: Node


func _process(_delta: float) -> void:
	if not is_instance_valid(boss):
		return
	visible = boss.state != boss.State.DEAD
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(boss):
		return
	var font := ThemeDB.fallback_font
	# One pip per head: lit when attacking, hollow when knocked out.
	var pip_gap := size.x / 10.0
	for head in boss.heads:
		var center := Vector2(pip_gap * (head.head_index + 0.5), 8)
		var color := Color(0.75, 0.6, 0.4)
		match head.state:
			RavanHead.HeadState.TELEGRAPH, RavanHead.HeadState.ATTACK, RavanHead.HeadState.EXHAUSTED:
				color = head.attack_color()
			RavanHead.HeadState.KNOCKED_OUT:
				draw_arc(center, 5.0, 0.0, TAU, 16, Color(0.5, 0.5, 0.55), 2.0)
				var left: float = clampf(head.regen_remaining / maxf(head.regen_time, 0.001), 0.0, 1.0)
				draw_arc(center, 8.0, -PI * 0.5, -PI * 0.5 + TAU * maxf(left, 0.01), 16, Color(0.6, 0.6, 0.65), 1.5)
				continue
			RavanHead.HeadState.REGROWING:
				color = Color(0.6, 1.0, 0.8)
			RavanHead.HeadState.FURY:
				color = Color(0.35, 1.0, 0.85) if head.fury_silent else (Color(1.0, 0.3, 0.12) if head.fury_lit else color)
			RavanHead.HeadState.DESTROYED:
				color = Color(0.2, 0.2, 0.2)
		draw_circle(center, 5.0, color)
	var text_color := Color(0.85, 0.85, 0.9)
	draw_string(font, Vector2(0, 32), "PHASE %d/3" % boss.phase, HORIZONTAL_ALIGNMENT_LEFT, size.x, 12, Color(1.0, 0.85, 0.6))
	var need: int = int(boss.phase_settings().threshold)
	var hint := "Knock out %d heads before they regrow: %d/%d" % [need, boss.knocked_out_count(), need]
	draw_string(font, Vector2(0, 32), hint, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, text_color)
	if boss.is_exposed():
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
		draw_string(font, Vector2(0, 32), "AMRIT EXPOSED", HORIZONTAL_ALIGNMENT_RIGHT, size.x, 12, Color(0.5, 1.0, 0.85, 0.5 + 0.5 * pulse))
