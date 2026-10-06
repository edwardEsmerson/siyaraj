extends CanvasLayer
## Pauses gameplay scenes (Esc) and moves between the title, levels and the
## developer playtest menu. The pause menu itself is scenes/ui/pause_menu.tscn.

const MENU: String = "res://scenes/main/playtest_menu.tscn"
const TITLE: String = "res://scenes/main/title.tscn"
var enemies_enabled: bool = true
var pending_section: int = -1
var snapshot: Dictionary = {}
var boss_introduction_seen: bool = false
var panel: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	panel = load("res://scenes/ui/pause_menu.tscn").instantiate()
	add_child(panel)

func _input(event: InputEvent) -> void:
	# Title, menus and the ending are Controls; only gameplay scenes (Node2D) pause.
	if event.is_action_pressed("ui_cancel") and not event.is_echo() and get_tree().current_scene is Node2D:
		get_viewport().set_input_as_handled()
		if panel.visible:
			panel.back()
		else:
			get_tree().paused = true
			panel.open(not snapshot.is_empty())

func _resume() -> void:
	panel.hide()
	get_tree().paused = false

func _restart() -> void:
	if not snapshot.is_empty():
		start_level(snapshot.path, snapshot.section, snapshot.room, true)
		return
	var course := get_tree().current_scene.get_node_or_null("TestCourse")
	if course != null and course.has_method("reset_progress"):
		course.reset_progress()
	_resume()
	get_tree().reload_current_scene()

## Reload keeps the level's session checkpoint, so Siya returns to the last lit diya.
func restart_checkpoint() -> void:
	_resume()
	get_tree().reload_current_scene()

func show_menu() -> void:
	snapshot.clear()
	_resume()
	get_tree().change_scene_to_file(MENU)

func show_title() -> void:
	snapshot.clear()
	_resume()
	get_tree().change_scene_to_file(TITLE)

func start_level(path: String, section: int = 0, room: StringName = &"", as_snapshot: bool = false) -> void:
	boss_introduction_seen = false
	snapshot = {"path": path, "section": section, "room": room} if as_snapshot else {}
	# Reset before the new course's _ready restores its session checkpoint.
	if path == "res://scenes/main/forest.tscn":
		var forest: Node = load("res://scripts/levels/forest.gd").new()
		forest.reset_progress()
		if room == &"CanopyNest":
			forest.current_room = room
			forest.room_spawn = Vector2(350, -3600)
			forest.return_point = Vector2(11730, 230)
		forest.free()
	elif path in ["res://scenes/main/river.tscn", "res://scenes/main/palace.tscn", "res://scenes/main/terrain_sampler.tscn"]:
		var draft: GDScript = load("res://scripts/levels/draft_level.gd")
		draft.progress.erase(path.get_file().get_basename())
	pending_section = section
	_resume()
	get_tree().change_scene_to_file(path)

func configure_course(course: Node2D) -> void:
	if not enemies_enabled:
		var encounters := course.get_node_or_null("Encounters")
		if encounters != null:
			for enemy in encounters.get_children():
				enemy.free()
	if pending_section > 0 and course.has_node("Checkpoints"):
		var checkpoints := course.get_node("Checkpoints").get_children()
		var at: Vector2 = checkpoints[mini(pending_section - 1, checkpoints.size() - 1)].position
		if course.has_method("set_start"):
			course.set_start(at)
		else:
			course.checkpoint_x = at.x
			course.get_node("PlayerSpawn").position = at
	pending_section = -1
