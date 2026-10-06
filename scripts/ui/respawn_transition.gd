extends CanvasLayer
## Lives under navigation so the curtains survive the checkpoint scene reload.

const Curtains = preload("res://scripts/ui/curtains.gd")
const Guard = preload("res://scripts/levels/checkpoint_guard.gd")

var active: bool = false
var curtains: Curtains
var _scene: Node
var _previous_mode: ProcessMode
var _generation: int = 0
var _tween: Tween
var _frozen: bool = false
var _reload_pending: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	layer = 90
	curtains = Curtains.new()
	curtains.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtains.mouse_filter = Control.MOUSE_FILTER_IGNORE
	curtains.clip_contents = true
	curtains.hide()
	add_child(curtains)
	get_tree().scene_changed.connect(_on_scene_changed)


func respawn(source: Node, death_delay: float = 0.0) -> void:
	if active or source != get_tree().current_scene:
		return
	active = true
	_generation += 1
	var generation := _generation
	_scene = source
	curtains.opening = false
	curtains.coverage = 0.0
	curtains.show()
	# Let the existing death pose finish while the fabric closes.
	_tween = create_tween()
	_tween.tween_property(curtains, "coverage", 1.0, maxf(Guard.CLOSE_TIME, death_delay))
	await _tween.finished
	if generation != _generation:
		return
	_reload_pending = true
	if get_tree().reload_current_scene() != OK:
		cancel()
		return
	await get_tree().scene_changed
	if generation != _generation:
		return
	_reload_pending = false
	_scene = get_tree().current_scene
	_previous_mode = _scene.process_mode
	_scene.process_mode = Node.PROCESS_MODE_DISABLED
	_frozen = true
	await get_tree().create_timer(Guard.HOLD_TIME, false).timeout
	if generation != _generation:
		return
	curtains.opening = true
	_tween = create_tween()
	_tween.tween_property(curtains, "coverage", 0.0, Guard.OPEN_TIME)
	await _tween.finished
	cancel()


func cancel() -> void:
	_generation += 1
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if _frozen and is_instance_valid(_scene):
		_scene.process_mode = _previous_mode
	_frozen = false
	_reload_pending = false
	_scene = null
	curtains.hide()
	active = false


func _on_scene_changed() -> void:
	if active and not _reload_pending:
		cancel()
