extends CanvasLayer
## Main-route diyas reject skipped enemies, using authored positions rather than patrol positions.

const PASS_LEEWAY: float = 120.0
const CLOSE_TIME: float = 0.45
const HOLD_TIME: float = 0.5
const OPEN_TIME: float = 0.45

class Curtains extends Control:
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

var enabled: bool = true
var returning: bool = false
var curtains: Curtains
var _main: Node2D
var _course: Node2D
var _entries: Array[Dictionary] = []


func _ready() -> void:
	# Explicit PAUSABLE keeps the transition running while gameplay is disabled,
	# but still lets Esc pause its tween and covered hold.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	layer = 90
	_main = get_parent()
	_course = _main.course
	curtains = Curtains.new()
	curtains.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtains.mouse_filter = Control.MOUSE_FILTER_IGNORE
	curtains.clip_contents = true
	curtains.hide()
	add_child(curtains)
	var checkpoints := _course.get_node("Checkpoints").get_children()
	checkpoints.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.position.x < b.position.x)
	var start: Vector2 = _main.player_spawn.global_position
	for checkpoint: Area2D in checkpoints:
		if checkpoint.global_position.x <= start.x:
			continue
		var enemies: Array[WeakRef] = []
		for enemy: Node2D in _course.get_node("Encounters").get_children():
			if enemy.get_meta("room", &"") == &"" and enemy.global_position.x >= start.x and enemy.global_position.x <= checkpoint.global_position.x:
				enemies.append(weakref(enemy))
		_entries.append({"checkpoint": checkpoint, "enemies": enemies})


func blocked(checkpoint: Area2D) -> bool:
	if not enabled:
		return false
	for entry in _entries:
		if entry.checkpoint == checkpoint:
			return _enemies_alive(entry)
	return false


func _enemies_alive(entry: Dictionary) -> bool:
	for reference: WeakRef in entry.enemies:
		var enemy: Node = reference.get_ref()
		if enemy != null and enemy.health > 0:
			return true
	return false


func _physics_process(_delta: float) -> void:
	if not enabled or returning or _main.completed or _main.player.state == _main.player.State.DEAD:
		return
	if _course.has_method("camera_region") and _course.current_room != &"":
		return
	for entry in _entries:
		if _main.player.global_position.x > entry.checkpoint.global_position.x + PASS_LEEWAY and _enemies_alive(entry):
			_return_to_diya(entry.checkpoint.global_position)
			return


func _return_to_diya(destination: Vector2) -> void:
	returning = true
	var previous_mode: ProcessMode = _main.process_mode
	_main.process_mode = Node.PROCESS_MODE_DISABLED
	curtains.opening = false
	curtains.coverage = 0.0
	curtains.show()
	_main.combat_status.text = "Defeat all enemies before this diya to pass."
	var closing := create_tween()
	closing.tween_property(curtains, "coverage", 1.0, CLOSE_TIME)
	await closing.finished
	_main.player.return_to_diya(destination)
	_main.camera.position.x = destination.x
	_main.camera.reset_smoothing()
	_main.camera.force_update_scroll()
	await get_tree().create_timer(HOLD_TIME, false).timeout
	curtains.opening = true
	var opening := create_tween()
	opening.tween_property(curtains, "coverage", 0.0, OPEN_TIME)
	await opening.finished
	curtains.hide()
	_main.process_mode = previous_mode
	returning = false
