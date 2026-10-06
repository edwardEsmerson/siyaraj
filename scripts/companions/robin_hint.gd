extends Area2D

const Robin = preload("res://scripts/companions/robin.gd")
const Controls = preload("res://scripts/ui/controls_panel.gd")
## Drop into a level. When Siya walks in, Robin flies to `point` and says `text`.
## Each hint shows once per session, so death reloads do not repeat it.

@export_multiline var text: String = ""
## Where Robin hovers while explaining, relative to this node.
@export var point: Vector2 = Vector2(0.0, -110.0)
@export var duration: float = 3.5
@export var once: bool = true
## Shared lesson key suppresses the same advice in later levels.
@export var topic: StringName = &""

var _visitor: Node2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func hint_id() -> String:
	if not topic.is_empty():
		return "lesson:%s" % topic
	var scene := get_tree().current_scene
	return "%s:%s" % [scene.scene_file_path if scene != null else "", scene.get_path_to(self) if scene != null else get_path()]


## Resolve the dash prompt when presented, including current InputMap remaps.
func formatted_text() -> String:
	if not text.contains("{dash}"):
		return text
	var bindings: PackedStringArray = []
	for binding in [Controls.key_text(&"dash"), Controls.joypad_text(&"dash")]:
		if not binding.is_empty():
			bindings.append(binding)
	var prompt := "Dash" if bindings.is_empty() else "Dash [%s]" % " or ".join(bindings)
	return text.replace("{dash}", prompt)


func _on_body_entered(body: Node2D) -> void:
	if text.is_empty() or not body.is_in_group("players") or body.state == body.State.DEAD:
		return
	_visitor = body
	_try_hint()


func _on_body_exited(body: Node2D) -> void:
	if body == _visitor:
		_visitor = null


func _physics_process(_delta: float) -> void:
	if is_instance_valid(_visitor):
		_try_hint()


func _try_hint() -> void:
	if not is_instance_valid(_visitor) or _visitor.state == _visitor.State.DEAD:
		return
	if once and Robin.seen_hints.has(hint_id()):
		_visitor = null
		return
	var robin := get_tree().get_first_node_in_group("robin")
	if robin != null:
		if robin.point_out(to_global(point), formatted_text(), hint_id() if once else "", duration):
			_visitor = null
			get_node("/root/AudioDirector").play_cue(&"hint")
