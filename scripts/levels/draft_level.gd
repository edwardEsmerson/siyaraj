extends Node2D
## Shared checkpoint and finish behavior for the river and palace grey drafts.

signal finished
const COURSE_WIDTH: int = 14400
static var progress: Dictionary = {}
@export var level_id: String = "river"
@export var course_width: int = COURSE_WIDTH
@export var sections: PackedStringArray = []
@export var section_starts: PackedInt32Array = []
var completed: bool = false

func level_width() -> int:
	return course_width

func _ready() -> void:
	if progress.has(level_id):
		$PlayerSpawn.position = progress[level_id].spawn
	$Finish.body_entered.connect(_on_finish)
	_update_diyas(null)

func _physics_process(_delta: float) -> void:
	_update_diyas(get_tree().get_first_node_in_group("players"))

func _update_diyas(player: CharacterBody2D) -> void:
	var saved: Dictionary = progress.get(level_id, {"spawn": Vector2(160, 430), "lit": []})
	for checkpoint: Area2D in $Checkpoints.get_children():
		var guard: CanvasLayer = get_parent().get("checkpoint_guard")
		var blocked: bool = guard != null and guard.blocked(checkpoint)
		var nearby: bool = not blocked and player != null and checkpoint.overlaps_body(player) and player.is_on_floor() and player.state == player.State.NORMAL
		if nearby and Input.is_action_just_pressed("interact"):
			if not saved.lit.has(checkpoint.name):
				saved.lit.append(checkpoint.name)
				player.get_node("Visuals").play_story(&"light_diya")
			if checkpoint.position.x >= saved.spawn.x:
				saved.spawn = checkpoint.position
			progress[level_id] = saved
		checkpoint.get_node("Flame").visible = saved.lit.has(checkpoint.name)
		checkpoint.get_node("Prompt").text = "Defeat enemies before this diya" if blocked else ("SAVED" if saved.lit.has(checkpoint.name) else ("E: light diya" if nearby else "DIYA"))

func set_start(at: Vector2) -> void:
	progress[level_id] = {"spawn": at, "lit": []}
	$PlayerSpawn.position = at

func reset_progress() -> void:
	progress.erase(level_id)

func hint_at(x: float) -> String:
	for index in range(section_starts.size() - 1, -1, -1):
		if x >= section_starts[index]:
			return sections[index]
	return sections[0] if not sections.is_empty() else "Grey draft"

func _on_finish(body: Node2D) -> void:
	if body.is_in_group("players") and body.state != body.State.DEAD and not completed:
		completed = true
		finished.emit()
