extends Node
## Versioned campaign checkpoint. Developer launches never enable this writer.

const VERSION: int = 1
const STAGES: Array[String] = ["prologue", "forest", "forest_showdown", "river", "river_showdown", "palace", "palace_showdown", "ending"]
const Forest = preload("res://scripts/levels/forest.gd")
const Draft = preload("res://scripts/levels/draft_level.gd")
var save_path: String = "user://campaign.json"
var active: bool = false
var stage: String = ""
var last_error: Error = OK

func _empty(at: String) -> Dictionary:
	return {"version": VERSION, "stage": at, "checkpoint": "", "lit": [], "rooms": [], "bridge_planks": 0}

func scene_path(at: String) -> String:
	return "res://scenes/main/%s.tscn" % at

func _reset_session() -> void:
	var forest := Forest.new()
	forest.reset_progress()
	forest.free()
	Draft.progress.clear()

func new_game() -> void:
	_reset_session()
	active = true
	stage = "prologue"
	_write(_empty(stage))

## Called before scene changes, and on boss defeat to secure the unlocked stage.
func enter_stage(path: String) -> void:
	if not active:
		return
	var next: String = path.get_file().get_basename()
	if next not in STAGES:
		active = false
		return
	stage = next
	_write(_empty(stage))

func capture() -> void:
	if not active or stage not in ["forest", "river", "palace"]:
		return
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path != scene_path(stage):
		return
	var course := scene.get_node("TestCourse")
	var data := _empty(stage)
	var spawn: Vector2
	if stage == "forest":
		spawn = Vector2(Forest.checkpoint_x, 0)
		for room in Forest.completed_rooms:
			data.rooms.append(str(room))
	else:
		var progress: Dictionary = Draft.progress.get(stage, {})
		spawn = progress.get("spawn", Vector2(160, 430))
		data.bridge_planks = progress.get("bridge_planks", 0)
	for checkpoint: Node2D in course.get_node("Checkpoints").get_children():
		var lit: bool = Forest.lit_checkpoints.has(checkpoint.name) if stage == "forest" else Draft.progress.get(stage, {}).get("lit", []).has(checkpoint.name)
		if lit:
			data.lit.append(str(checkpoint.name))
		if is_equal_approx(checkpoint.position.x, spawn.x):
			data.checkpoint = str(checkpoint.name)
	_write(data)

func suspend() -> void:
	capture()
	active = false

func read_save() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null or file.get_length() > 16384:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	var data: Variant = parser.data
	if not data is Dictionary or not _valid(data):
		return {}
	return data

func _valid(data: Dictionary) -> bool:
	if data.get("version") != VERSION or not data.get("stage") is String or data.stage not in STAGES:
		return false
	if not data.get("checkpoint") is String or not data.get("lit") is Array or not data.get("rooms") is Array:
		return false
	var boards: Variant = data.get("bridge_planks")
	if not (boards is int or boards is float) or boards < 0 or boards > 4 or not is_finite(float(boards)) or boards != int(boards):
		return false
	if data.stage != "river" and boards != 0:
		return false
	for room: Variant in data.rooms:
		if not room is String or room not in ["RootChamber", "CanopyNest"] or data.stage != "forest":
			return false
	if data.stage not in ["forest", "river", "palace"]:
		return data.checkpoint.is_empty() and data.lit.is_empty() and data.rooms.is_empty()
	var preview: Node = load(scene_path(data.stage)).instantiate()
	var checkpoints: Node = preview.get_node("TestCourse/Checkpoints")
	var names: Array[String] = []
	for checkpoint: Node in checkpoints.get_children():
		names.append(str(checkpoint.name))
	var valid: bool = true
	for name: Variant in data.lit:
		if not name is String or name not in names:
			valid = false
	if not data.checkpoint.is_empty():
		valid = valid and data.lit.has(data.checkpoint) and data.checkpoint in names
		if valid and data.stage == "river":
			var checkpoint: Node2D = checkpoints.get_node(NodePath(data.checkpoint))
			if checkpoint.position.x > 8710 and boards != 4:
				valid = false
	preview.free()
	return valid

func continue_game() -> bool:
	var data := read_save()
	if data.is_empty():
		return false
	_reset_session()
	stage = data.stage
	active = true
	if stage in ["forest", "river", "palace"]:
		var preview: Node = load(scene_path(stage)).instantiate()
		var spawn: Vector2 = preview.get_node("TestCourse/PlayerSpawn").position
		if not data.checkpoint.is_empty():
			spawn = preview.get_node("TestCourse/Checkpoints/" + data.checkpoint).position
		if stage == "forest":
			Forest.checkpoint_x = spawn.x
			for name: String in data.lit:
				Forest.lit_checkpoints.append(StringName(name))
			for room: String in data.rooms:
				Forest.completed_rooms.append(StringName(room))
		else:
			var lit: Array = []
			for name: String in data.lit:
				lit.append(StringName(name))
			Draft.progress[stage] = {"spawn": spawn, "lit": lit, "bridge_planks": int(data.bridge_planks)}
		preview.free()
	var navigation := get_node("/root/PlaytestNavigation")
	navigation.respawn_transition.cancel()
	navigation.snapshot.clear()
	navigation.pending_section = -1
	navigation.enemies_enabled = true
	navigation.boss_introduction_seen = false
	navigation._resume()
	get_tree().change_scene_to_file(scene_path(stage))
	return true

func _write(data: Dictionary) -> void:
	var temporary: String = save_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = FileAccess.get_open_error()
		push_warning("Campaign save unavailable: %s" % error_string(last_error))
		return
	file.store_string(JSON.stringify(data))
	file.flush()
	last_error = file.get_error()
	file.close()
	if last_error == OK:
		last_error = DirAccess.rename_absolute(temporary, save_path)
	if last_error != OK:
		push_warning("Campaign save unavailable: %s" % error_string(last_error))
