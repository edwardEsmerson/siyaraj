extends Control
## Reusable boss health bar. Place it under a CanvasLayer and call bind(boss), or
## set boss_path. Boss contract (only the first two are required):
## - `max_health: int`, `health: int`, signal `health_changed(remaining: int)`
## - optional signal `died`, signal `phase_changed(phase: int)`
## - optional display name: `boss_name`, then `enemy_name`, else the node name;
##   optional `boss_title` subtitle.

@export var boss_path: NodePath
## Display name override; leave empty to read it from the boss.
@export var display_name: String = ""
## Fractions of max health where tick marks are drawn (phase boundaries).
@export var phase_thresholds: PackedFloat32Array = PackedFloat32Array([0.5])
@export var fill_color: Color = Color(0.86, 0.2, 0.18)
@export var enraged_fill_color: Color = Color(1.0, 0.45, 0.1)
@export var chip_color: Color = Color(1.0, 0.85, 0.55)
@export var background_color: Color = Color(0.06, 0.05, 0.08, 0.85)
@export var frame_color: Color = Color(0.85, 0.68, 0.3)
@export var chip_delay: float = 0.4
@export var chip_speed: float = 0.6
@export var hide_on_death: bool = true

var boss: Node
var max_health: int = 1
var health: int = 1
var phase: int = 1
var displayed_fraction: float = 1.0
var _chip_wait: float = 0.0
var _fade_out: bool = false

@onready var name_label: Label = $Name


func _ready() -> void:
	visible = false
	if not boss_path.is_empty():
		var target := get_node_or_null(boss_path)
		if target != null:
			bind(target)


func bind(target: Node) -> void:
	unbind()
	boss = target
	max_health = maxi(int(target.get("max_health")), 1)
	health = int(target.get("health"))
	var boss_phase: Variant = target.get("phase")
	phase = int(boss_phase) if boss_phase != null else 1
	displayed_fraction = fraction()
	target.health_changed.connect(_on_health_changed)
	if target.has_signal("died"):
		target.died.connect(_on_died)
	if target.has_signal("phase_changed"):
		target.phase_changed.connect(_on_phase_changed)
	name_label.text = _resolve_name(target)
	modulate.a = 1.0
	_fade_out = false
	visible = true
	queue_redraw()


func unbind() -> void:
	if is_instance_valid(boss):
		if boss.health_changed.is_connected(_on_health_changed):
			boss.health_changed.disconnect(_on_health_changed)
		if boss.has_signal("died") and boss.died.is_connected(_on_died):
			boss.died.disconnect(_on_died)
		if boss.has_signal("phase_changed") and boss.phase_changed.is_connected(_on_phase_changed):
			boss.phase_changed.disconnect(_on_phase_changed)
	boss = null


func fraction() -> float:
	return clampf(float(health) / float(max_health), 0.0, 1.0)


func _resolve_name(target: Node) -> String:
	if not display_name.is_empty():
		return display_name
	var title := ""
	for property in ["boss_name", "enemy_name"]:
		var value: Variant = target.get(property)
		if value is String and not value.is_empty():
			title = value
			break
	if title.is_empty():
		title = String(target.name)
	var subtitle: Variant = target.get("boss_title")
	if subtitle is String and not subtitle.is_empty():
		title = "%s, %s" % [title, subtitle]
	return title.to_upper()


func _on_health_changed(remaining: int) -> void:
	health = clampi(remaining, 0, max_health)
	_chip_wait = chip_delay
	queue_redraw()


func _on_phase_changed(next_phase: int) -> void:
	phase = next_phase
	queue_redraw()


func _on_died() -> void:
	health = 0
	if hide_on_death:
		_fade_out = true
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	var target := fraction()
	if displayed_fraction > target:
		_chip_wait = maxf(_chip_wait - delta, 0.0)
		if _chip_wait <= 0.0:
			displayed_fraction = maxf(displayed_fraction - chip_speed * delta, target)
		queue_redraw()
	else:
		displayed_fraction = target
	if _fade_out:
		modulate.a = maxf(modulate.a - delta * 0.8, 0.0)
		if modulate.a <= 0.0:
			visible = false
			_fade_out = false


func _bar_rect() -> Rect2:
	return Rect2(Vector2(0, size.y - 16.0), Vector2(size.x, 16.0))


func _draw() -> void:
	var bar := _bar_rect()
	draw_rect(bar.grow(3.0), background_color)
	var inner := bar
	draw_rect(Rect2(inner.position, Vector2(inner.size.x * displayed_fraction, inner.size.y)), chip_color)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x * fraction(), inner.size.y)), enraged_fill_color if phase >= 2 else fill_color)
	for threshold in phase_thresholds:
		var x := inner.position.x + inner.size.x * clampf(threshold, 0.0, 1.0)
		draw_line(Vector2(x, inner.position.y - 4.0), Vector2(x, inner.end.y + 4.0), frame_color, 2.0)
	draw_rect(bar.grow(3.0), frame_color, false, 2.0)
