extends "res://tests/forest_check.gd"
## Title screen and pause menu: buttons, sub-panels, Esc routing and settings.

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
	var settings_state: Node = root.get_node("GameSettings")
	var saved_volume: float = settings_state.master_volume
	var saved_fullscreen: bool = settings_state.fullscreen
	check(ProjectSettings.get_setting("application/run/main_scene") == navigation.TITLE, "The game must open on the title screen")
	change_scene_to_file(navigation.TITLE)
	await scene_changed
	await ticks(2)
	var title: Control = current_scene
	var menu: Control = title.get_node("Menu")
	var first_level: String = title.FIRST_LEVEL
	check(root.gui_get_focus_owner() == menu.get_node("NewGame"), "New game must start focused")
	check(menu.get_node("Playtest").visible == OS.is_debug_build(), "Playtest menu must only show in debug builds")
	await escape()
	check(not paused and not navigation.panel.visible, "Esc must not pause the title screen")

	menu.get_node("Controls").pressed.emit()
	var controls: Control = title.get_node("Center/Controls")
	var grid: GridContainer = controls.get_node("Column/Grid")
	check(controls.visible and not menu.visible, "Controls must replace the title menu")
	check(grid.get_child_count() == controls.ACTIONS.size() * 2, "Controls must list every action")
	for index in range(0, grid.get_child_count(), 2):
		check(not (grid.get_child(index) as Label).text.is_empty(), "Every action must show its key")
	await escape()
	check(menu.visible and not controls.visible, "Esc must close Controls")
	check(root.gui_get_focus_owner() == menu.get_node("Controls"), "Closing Controls must refocus its button")

	menu.get_node("Settings").pressed.emit()
	var settings: Control = title.get_node("Center/Settings")
	check(settings.visible, "Settings must open")
	settings.get_node("Column/VolumeRow/Volume").value = 0.5
	check(is_equal_approx(settings_state.master_volume, 0.5), "Volume slider must update the setting")
	check(is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.5)), "Volume must apply to the master bus")
	settings.get_node("Column/Back").pressed.emit()
	check(menu.visible and not settings.visible, "Back must close Settings")

	menu.get_node("NewGame").pressed.emit()
	await scene_changed
	await ticks(4)
	check(current_scene.scene_file_path == first_level, "New game must start the first level")
	await escape()
	var pause: Control = navigation.panel
	var buttons: Control = pause.get_node("Center/Menu/Column/Buttons")
	check(paused and pause.visible, "Esc must pause the level")
	check(root.gui_get_focus_owner() == buttons.get_node("Resume"), "Pause must focus Resume")
	check(buttons.get_node("Checkpoint").visible, "Levels must offer the last diya")
	check(buttons.get_node("LevelSelect").visible == OS.is_debug_build(), "Level select must only show in debug builds")
	buttons.get_node("Settings").pressed.emit()
	await escape()
	check(paused and pause.get_node("Center/Menu").visible and not pause.get_node("Center/Settings").visible, "Esc must close a pause sub-panel before resuming")
	await escape()
	check(not paused and not pause.visible, "Second Esc must resume")

	await escape()
	buttons.get_node("Checkpoint").pressed.emit()
	await scene_changed
	await ticks(4)
	check(current_scene.scene_file_path == first_level and not paused, "Last diya must reload the level unpaused")

	await escape()
	buttons.get_node("Title").pressed.emit()
	await scene_changed
	await ticks(2)
	check(current_scene.scene_file_path == navigation.TITLE and not paused and not pause.visible, "Quit to title must leave the pause menu")

	settings_state.master_volume = saved_volume
	settings_state.fullscreen = saved_fullscreen
	settings_state.apply()
	settings_state.save()
	print("Menu checks: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
