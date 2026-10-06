extends Control
## Self-contained Ravan health bar: core health with phase marks plus one pip per
## head. Boss 1 has its own generic bar; merge the two when both land.
const RavanHead = preload("res://scripts/bosses/ravan/ravan_head.gd")

var boss: Node
var _shown_health: float = -1.0
var _last_health: int = -1
var _hit_flash: float = 0.0


func _process(delta: float) -> void:
	if not is_instance_valid(boss):
		return
	if _shown_health < 0.0:
		_shown_health = boss.core_health
	if boss.core_health != _last_health and _last_health >= 0:
		_hit_flash = 0.15
	_last_health = boss.core_health
	_shown_health = move_toward(_shown_health, boss.core_health, delta * 12.0)
	_hit_flash = maxf(_hit_flash - delta, 0.0)
	visible = boss.state != boss.State.DEAD
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(boss):
		return
	var font := ThemeDB.fallback_font
	var bar := Rect2(0, 18, size.x, 12)
	var title := "%s  -  DASHANAN    PHASE %d/3" % [boss.boss_name, boss.phase]
	draw_string(font, Vector2(0, 13), title, HORIZONTAL_ALIGNMENT_LEFT, size.x, 14, Color(1.0, 0.85, 0.6))
	draw_rect(bar.grow(2.0), Color(0.05, 0.04, 0.05, 0.85))
	draw_rect(bar, Color(0.25, 0.1, 0.1))
	var ratio := clampf(_shown_health / maxf(boss.max_core_health, 1), 0.0, 1.0)
	var fill := Color(0.85, 0.15, 0.12) if _hit_flash <= 0.0 else Color(1.0, 0.95, 0.9)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), fill)
	for threshold in [boss.phase_two_health, boss.phase_three_health]:
		var x: float = bar.position.x + bar.size.x * float(threshold) / maxf(boss.max_core_health, 1)
		draw_line(Vector2(x, bar.position.y - 3), Vector2(x, bar.end.y + 3), Color(1.0, 0.85, 0.5), 2.0)
	if boss.is_exposed():
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
		draw_rect(bar.grow(3.0), Color(0.4, 1.0, 0.8, 0.5 + 0.5 * pulse), false, 2.0)
		draw_string(font, Vector2(0, 13), "AMRIT EXPOSED", HORIZONTAL_ALIGNMENT_RIGHT, size.x, 14, Color(0.5, 1.0, 0.85))
	# One pip per head: lit when attacking, hollow when knocked out.
	var pip_gap := size.x / 10.0
	for head in boss.heads:
		var center := Vector2(pip_gap * (head.head_index + 0.5), 42)
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
	var need: int = int(boss.phase_settings().threshold)
	var hint := "Knock out %d heads before they regrow: %d/%d" % [need, boss.knocked_out_count(), need]
	draw_string(font, Vector2(0, 62), hint, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color(0.85, 0.85, 0.9))
