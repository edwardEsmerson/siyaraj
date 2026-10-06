extends "res://tests/forest_check.gd"

func escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	await ticks(2)
	event = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	Input.parse_input_event(event)
	await ticks(1)

func run_checks() -> void:
	var navigation: Node = root.get_node("PlaytestNavigation")
	navigation.show_menu()
	await scene_changed
	var menu: Control = current_scene
	var snapshots: Array[Dictionary] = menu.SNAPSHOTS
	check(snapshots.size() == 16 and menu.get_node("Layout/Lab").item_count == snapshots.size(), "Menu must offer all developer snapshots")
	for wanted in ["res://scenes/dev/sandbox.tscn", "res://scenes/dev/weapons_playground.tscn", "res://scenes/bosses/khara_arena.tscn", "res://scenes/bosses/ravan/ravan_arena.tscn"]:
		check(snapshots.any(func(entry: Dictionary) -> bool: return entry.path == wanted), "Menu must offer %s" % wanted)
	for entry in snapshots:
		check(ResourceLoader.exists(entry.path), "Snapshot path must exist: %s" % entry.path)
	for index in range(3):
		menu.get_node("Layout/Level").select(index)
		menu._select_level(index)
		check(menu.get_node("Layout/Section").item_count > 5, "Each level must offer checkpoint sections")
	menu.get_node("Layout/Enemies").button_pressed = false
	menu.get_node("Layout/Section").select(3)
	menu.get_node("Layout/Start").pressed.emit()
	await scene_changed
	player = current_scene.player
	await ticks(4)
	check(current_scene.scene_file_path.ends_with("palace.tscn"), "Play must open selected level")
	check(absf(player.position.x - 8600) < 1, "Section selection must start at the roof checkpoint")
	check(current_scene.course.get_node("Encounters").get_child_count() == 0, "Enemies checkbox must affect the selected level")
	await escape()
	check(paused and navigation.panel.visible, "Esc must pause and show navigation")
	var time: float = current_scene.elapsed
	await ticks(10)
	check(current_scene.elapsed == time, "Pause must freeze the level timer")
	await escape()
	check(not paused and not navigation.panel.visible, "Esc must resume")
	navigation._restart()
	await scene_changed
	player = current_scene.player
	await ticks(4)
	check(absf(player.position.x - 160) < 1, "Restart from beginning must clear section progress")
	# Launch every snapshot through the menu's actual button signal.
	for index in range(snapshots.size()):
		var entry: Dictionary = snapshots[index]
		var canopy: bool = entry.get("room", &"") == &"CanopyNest"
		navigation.show_menu()
		await scene_changed
		menu = current_scene
		menu.get_node("Layout/Lab").select(index)
		menu.get_node("Layout/OpenLab").pressed.emit()
		await scene_changed
		await ticks(4)
		check(current_scene != null and current_scene is Node2D, "Snapshot %d must enter a gameplay scene" % index)
		check(current_scene.scene_file_path == entry.path, "Snapshot %d must open %s" % [index, entry.path])
		if entry.has("encounter") and entry.encounter >= 0:
			var enemy: Node = current_scene.get_node_or_null("Enemy")
			var expected: String = current_scene.ENCOUNTERS[entry.encounter][0].resource_path
			check(enemy != null and enemy.scene_file_path == expected, "Sandbox snapshot %d must spawn its preset enemy" % index)
		if canopy:
			check(current_scene.course.current_room == &"CanopyNest", "Canopy snapshot must enter the isolated climb")
			check(current_scene.player.is_on_floor(), "Canopy snapshot must spawn grounded")
		await escape()
		check(paused, "Every snapshot must support pause")
		# Pause-menu restart repeats every snapshot, including sandbox presets.
		var path: String = current_scene.scene_file_path
		var enemy_path: String = current_scene.get_node("Enemy").scene_file_path if current_scene.has_node("Enemy") else ""
		navigation._restart()
		await scene_changed
		await ticks(4)
		check(current_scene.scene_file_path == path and not paused, "Restart must repeat the selected snapshot")
		if not enemy_path.is_empty():
			check(current_scene.has_node("Enemy") and current_scene.get_node("Enemy").scene_file_path == enemy_path, "Restart must keep the sandbox preset")
		if canopy:
			check(current_scene.course.current_room == &"CanopyNest", "Restart must retain the canopy snapshot")
			var restart := InputEventAction.new()
			restart.action = &"restart"
			restart.pressed = true
			current_scene._unhandled_input(restart)
			await scene_changed
			check(current_scene.course.current_room == &"CanopyNest", "R must also repeat the canopy snapshot")
		navigation.show_menu()
		await scene_changed
		check(not paused, "Returning to menu must unpause")
	# Completing levels advances through the agreed game sequence.
	navigation.enemies_enabled = false
	navigation.start_level("res://scenes/main/forest.tscn")
	await scene_changed
	current_scene._finish_course()
	var accept := InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = true
	current_scene._unhandled_input(accept)
	await scene_changed
	check(current_scene.scene_file_path.ends_with("river.tscn"), "Forest completion must advance to river")
	current_scene._finish_course()
	current_scene._unhandled_input(accept)
	await scene_changed
	check(current_scene.scene_file_path.ends_with("palace.tscn"), "River completion must advance to palace")
	print("Playtest menu checks: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
