extends CanvasLayer
## Main-route diyas reject skipped enemies, using authored positions rather than patrol positions.

const PASS_LEEWAY: float = 120.0
const CLOSE_TIME: float = 0.45
const HOLD_TIME: float = 0.5
const OPEN_TIME: float = 0.45

const Curtains = preload("res://scripts/ui/curtains.gd")

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
	get_node("/root/AudioDirector").play_sfx(&"curtain")
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
	get_node("/root/AudioDirector").play_sfx(&"curtain")
	var opening := create_tween()
	opening.tween_property(curtains, "coverage", 0.0, OPEN_TIME)
	await opening.finished
	curtains.hide()
	_main.process_mode = previous_mode
	returning = false
