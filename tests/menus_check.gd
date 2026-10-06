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

func joy_button(button: JoyButton, pressed: bool = true) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	await ticks(2)

func joy_tap(button: JoyButton) -> void:
	await joy_button(button)
	await joy_button(button, false)

func run_checks() -> void:
	var saves: Node = root.get_node("CampaignSave")
	saves.save_path = "user://menus_check_campaign.json"
	DirAccess.remove_absolute(saves.save_path)
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
	check(not menu.get_node("Playtest").visible, "The game menu must hide developer playtests")
	await escape()
	check(not paused and not navigation.panel.visible, "Esc must not pause the title screen")

	menu.get_node("Controls").pressed.emit()
	var controls: Control = title.get_node("Center/Controls")
	var grid: GridContainer = controls.get_node("Column/Grid")
	check(controls.visible and not menu.visible, "Controls must replace the title menu")
	check(grid.columns == 3 and grid.get_child_count() == (controls.ACTIONS.size() + 1) * 3, "Controls must list every action with keyboard and controller columns")
	for index in range(3, grid.get_child_count(), 3):
		check(not (grid.get_child(index + 1) as Label).text.is_empty(), "Every action must show its key")
		check(not (grid.get_child(index + 2) as Label).text.is_empty(), "Every action must show its controller binding")
	for entry in controls.ACTIONS:
		var has_joypad := false
		for event in InputMap.action_get_events(entry[0]):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				has_joypad = true
				check(event.device == -1, "Gamepad actions must work on any controller")
		check(has_joypad, "Every listed action must have a gamepad binding: %s" % entry[0])
	var motion := InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 0.1
	Input.parse_input_event(motion)
	await ticks(1)
	check(is_zero_approx(Input.get_axis("move_left", "move_right")), "Stick drift below the deadzone must not move Siya")
	motion = InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = -1.0
	Input.parse_input_event(motion)
	await ticks(1)
	check(Input.get_axis("move_left", "move_right") < -0.9, "Left stick must drive left movement")
	motion = InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 1.0
	Input.parse_input_event(motion)
	await ticks(1)
	check(Input.get_axis("move_left", "move_right") > 0.9, "Left stick must drive right movement")
	motion = InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 0.0
	Input.parse_input_event(motion)
	await ticks(1)
	await escape()
	check(menu.visible and not controls.visible, "Esc must close Controls")
	check(root.gui_get_focus_owner() == menu.get_node("Controls"), "Closing Controls must refocus its button")
	await joy_tap(JOY_BUTTON_DPAD_DOWN)
	check(root.gui_get_focus_owner() == menu.get_node("Settings"), "D-pad must navigate menu buttons")
	await joy_tap(JOY_BUTTON_A)
	check(title.get_node("Center/Settings").visible, "Controller confirm must open the focused menu button")
	await joy_tap(JOY_BUTTON_START)
	check(menu.visible, "Controller back must close the title sub-panel")

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
	check(current_scene.scene_file_path == "res://scenes/main/prologue.tscn", "New game must start with Raj's abduction")
	var opening: CanvasLayer = current_scene.get_node("ComicCutscene")
	check(opening.visible and opening._panels.size() > 0, "Opening dialogue must be playable")
	for panel in opening._panels.size():
		var advance := InputEventAction.new()
		advance.action = &"ui_accept"
		advance.pressed = true
		opening._unhandled_input(advance)
	await scene_changed
	await ticks(4)
	check(current_scene.scene_file_path == first_level, "Closing the opening must start the forest")
	await escape()
	var pause: Control = navigation.panel
	var buttons: Control = pause.get_node("Center/Menu/Column/Buttons")
	check(paused and pause.visible, "Esc must pause the level")
	check(root.gui_get_focus_owner() == buttons.get_node("Resume"), "Pause must focus Resume")
	check(buttons.get_node("Checkpoint").visible, "Levels must offer the last diya")
	check(not buttons.get_node("LevelSelect").visible, "Pause must hide developer level select")
	buttons.get_node("Settings").pressed.emit()
	await escape()
	check(paused and pause.get_node("Center/Menu").visible and not pause.get_node("Center/Settings").visible, "Esc must close a pause sub-panel before resuming")
	await escape()
	check(not paused and not pause.visible, "Second Esc must resume")
	await joy_button(JOY_BUTTON_B)
	check(Input.is_action_pressed("interact") and not paused, "Controller interaction must not open pause")
	await joy_button(JOY_BUTTON_B, false)
	await joy_tap(JOY_BUTTON_START)
	check(paused and pause.visible, "Start must pause gameplay")
	await joy_tap(JOY_BUTTON_A)
	check(not paused and not pause.visible, "Controller confirm must activate Resume")

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
	DirAccess.remove_absolute(saves.save_path)
	print("Menu checks: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
