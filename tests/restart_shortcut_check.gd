extends "res://tests/forest_check.gd"
## Exercise each shortcut handler with debug and release branches. A test-only
## script copy substitutes the engine build flag so no runtime override is shipped.

func release_script(path: String) -> GDScript:
	var source: GDScript = load(path)
	var script := GDScript.new()
	script.source_code = source.source_code.replace("OS.is_debug_build()", "false")
	check(script.reload() == OK, "Release branch must compile: %s" % path)
	return script

func open_scene(path: String, script: GDScript = null) -> void:
	if current_scene != null:
		current_scene.free()
	var scene: Node = load(path).instantiate()
	if script != null:
		scene.set_script(script)
	root.add_child(scene)
	current_scene = scene
	await ticks(4)

func labels(node: Node) -> String:
	var text: String = (node.text + "\n") if node is Label else ""
	for child in node.get_children():
		text += labels(child)
	return text

func run_checks() -> void:
	var navigation: Node = root.get_node("PlaytestNavigation")
	navigation.enemies_enabled = false
	check(OS.is_debug_build(), "The normal runner must exercise actual debug handlers")
	var bindings: Array[InputEvent] = InputMap.action_get_events(&"restart")
	check(bindings.any(func(event: InputEvent) -> bool: return event is InputEventKey and event.physical_keycode == KEY_R), "Debug restart must retain R")
	check(bindings.any(func(event: InputEvent) -> bool: return event is InputEventJoypadButton), "Debug restart must retain its controller binding")
	var release_navigation: Node = release_script("res://scripts/main/playtest_navigation.gd").new()
	release_navigation._enter_tree()
	check(InputMap.action_get_events(&"restart").is_empty(), "Release startup must clear keyboard and controller restart bindings")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_R
	key.pressed = true
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_BACK
	button.pressed = true
	check(not key.is_action_pressed(&"restart") and not button.is_action_pressed(&"restart"), "Release must not map R or View/Select to restart")
	check(not InputMap.action_get_events(&"jump").is_empty(), "Release startup must preserve other controls")
	release_navigation.free()
	for event in bindings:
		InputMap.action_add_event(&"restart", event)
	for release in [false, true]:
		var controls: Control = load("res://scenes/ui/controls_panel.tscn").instantiate()
		if release:
			controls.set_script(release_script("res://scripts/ui/controls_panel.gd"))
		root.add_child(controls)
		check(labels(controls).contains("Restart level") == not release, "Controls must advertise restart only in debug builds")
		if not release:
			check(labels(controls).contains("debug only"), "Developer shortcut must be labeled debug only")
		controls.free()
	var paths := {
		"res://scenes/main/movement_playground.tscn": "res://scripts/main/main.gd",
		"res://scenes/main/forest.tscn": "res://scripts/main/main.gd",
		"res://scenes/main/river.tscn": "res://scripts/main/main.gd",
		"res://scenes/main/palace.tscn": "res://scripts/main/main.gd",
		"res://scenes/dev/sandbox.tscn": "res://scripts/dev/sandbox.gd",
		"res://scenes/dev/weapons_playground.tscn": "res://scripts/dev/weapons_playground.gd",
		"res://scenes/bosses/ravan/ravan_arena.tscn": "res://scripts/bosses/ravan/ravan_arena.gd",
	}
	for path: String in paths:
		for release in [false, true]:
			await open_scene(path, release_script(paths[path]) if release else null)
			var old_scene: Node = current_scene
			if release and path.ends_with("forest.tscn"):
				old_scene.course.lit_checkpoints.append(&"ForestEntry")
			check(not labels(old_scene).contains("R:"), "Gameplay HUD must omit restart shortcut prompts: %s" % path)
			var event := InputEventAction.new()
			event.action = &"restart"
			event.pressed = true
			if path.contains("weapons_playground"):
				Input.action_press(&"restart")
			else:
				# Bypass InputMap too: the release handler must reject synthetic actions.
				old_scene._unhandled_input(event)
			await ticks(4)
			Input.action_release(&"restart")
			check((current_scene == old_scene) == release, "Shortcut must reload only in debug: %s" % path)
			if release:
				if path.ends_with("forest.tscn"):
					check(old_scene.course.lit_checkpoints.has(&"ForestEntry"), "Ignored release shortcut must retain checkpoint progress")
				# Use the actual pause menu signal while paused, with release handlers.
				paused = true
				navigation.panel.open(false)
				navigation.panel.buttons.get_node("Restart").pressed.emit()
				await ticks(4)
				check(current_scene != old_scene and not paused, "Menu Restart must still work with release handlers: %s" % path)
	await open_scene("res://scenes/main/forest.tscn", release_script("res://scripts/main/main.gd"))
	current_scene._finish_course()
	var completed_scene: Node = current_scene
	current_scene.get_node("HUD/Completion/Actions/Replay").pressed.emit()
	await ticks(4)
	check(current_scene != completed_scene and not current_scene.completed, "Play Again must still reload from a release completion screen")
	# Shared result UI must preserve its replay button without advertising R.
	var result: Control = load("res://scenes/ui/result_screen.tscn").instantiate()
	root.add_child(result)
	check(not labels(result).contains("R:"), "Result UI must omit the shortcut")
	check(result.has_node("Actions/Replay"), "Result UI must retain Play Again")
	result.free()
	print("Restart shortcut branches: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
