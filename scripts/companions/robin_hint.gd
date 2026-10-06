extends Area2D
## Drop into a level. When Siya walks in, Robin flies to `point` and says `text`.
## Each hint shows once per session, so death reloads do not repeat it.

@export_multiline var text: String = ""
## Where Robin hovers while explaining, relative to this node.
@export var point: Vector2 = Vector2(0.0, -110.0)
@export var duration: float = 3.5
@export var once: bool = true


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func hint_id() -> String:
	var scene := get_tree().current_scene
	return "%s:%s" % [scene.scene_file_path if scene != null else "", scene.get_path_to(self) if scene != null else get_path()]


func _on_body_entered(body: Node2D) -> void:
	if text.is_empty() or not body.is_in_group("players") or body.state == body.State.DEAD:
		return
	var robin := get_tree().get_first_node_in_group("robin")
	if robin != null:
		robin.point_out(to_global(point), text, hint_id() if once else "", duration)
