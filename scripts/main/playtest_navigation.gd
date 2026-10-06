extends CanvasLayer
## One pause menu also serves the team's standalone tuning scenes.

const MENU: String = "res://scenes/main/playtest_menu.tscn"
var enemies_enabled: bool = true
var pending_section: int = -1
var snapshot: Dictionary = {}
var panel: PanelContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	panel = PanelContainer.new()
	panel.position = Vector2(310, 140)
	panel.custom_minimum_size = Vector2(340, 250)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)
	_add_button(column, "Resume / Esc", _resume)
	_add_button(column, "Restart from beginning", _restart)
	_add_button(column, "Level select", show_menu)
	panel.hide()

func _add_button(parent: Node, title: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 42
	button.pressed.connect(action)
	parent.add_child(button)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo() and get_tree().current_scene != null and get_tree().current_scene.scene_file_path != MENU:
		get_viewport().set_input_as_handled()
		if panel.visible:
			_resume()
		else:
			get_tree().paused = true
			panel.get_child(0).get_child(2).text = "Restart snapshot" if not snapshot.is_empty() else "Restart from beginning"
			panel.show()
			panel.get_child(0).get_child(1).grab_focus()

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

func show_menu() -> void:
	snapshot.clear()
	_resume()
	get_tree().change_scene_to_file(MENU)

func start_level(path: String, section: int = 0, room: StringName = &"", as_snapshot: bool = false) -> void:
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
