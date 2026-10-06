extends "res://tests/forest_check.gd"
## Check real layout bounds and result-button navigation at the game's viewport size.

func inside_viewport(control: Control) -> bool:
	return Rect2(Vector2.ZERO, Vector2(960, 540)).encloses(control.get_global_rect())

func run_checks() -> void:
	var navigation: Node = root.get_node("PlaytestNavigation")
	navigation.show_title()
	await scene_changed
	var controls: Control = current_scene.get_node("Center/Controls")
	controls.open()
	await ticks(3)
	check(inside_viewport(controls), "Controls must fit inside the viewport with the display font")
	for level in ["forest", "river", "palace"]:
		navigation.enemies_enabled = false
		navigation.start_level("res://scenes/main/%s.tscn" % level)
		await scene_changed
		await ticks(2)
		if level == "forest":
			var sign: Label = current_scene.get_node("TestCourse/SideRooms/RootChamber/DescentSign")
			var portal: Label = current_scene.get_node("TestCourse/Portals/RootAbort/Prompt")
			check(not sign.get_global_rect().intersects(portal.get_global_rect()), "Root Hollow instructions must not overlap the exit prompt")
			check(sign.get_line_count() == 3, "Root Hollow instructions must wrap into three readable lines")
		current_scene._finish_course()
		await ticks(2)
		var result: Control = current_scene.get_node("HUD/Completion")
		check(inside_viewport(result.get_node("Card")), "Completion card must fit the viewport")
		check(result.get_node("Message").get_minimum_size().y <= 64, "Completion details must fit their reserved space")
		check(root.gui_get_focus_owner() == result.get_node("Actions/Continue"), "Continue must be focused for keyboard and controller play")
		result.get_node("Actions/Replay").pressed.emit()
		await scene_changed
		check(not current_scene.completed, "Replay button must restart the actual level")
	for path in ["res://scenes/bosses/khara_arena.tscn", "res://scenes/bosses/dhoomketu_arena.tscn", "res://scenes/bosses/ravan/ravan_arena.tscn"]:
		navigation.start_level(path, 0, &"", true)
		await scene_changed
		await ticks(2)
		var hud: Node = current_scene.get_node("HUD")
		var hint: Label = hud.get_node("Milestone" if hud.has_node("Milestone") else "Hint")
		check(hint.get_global_rect().end.y <= 124, "Boss instructions must fit inside the HUD backing")
		check(not hint.get_global_rect().intersects(hud.get_node("HealthStatus").get_global_rect()), "Boss instructions must not overlap health text")
		var flow: CanvasLayer = current_scene.get_node("CampaignFlow")
		flow._on_defeated()
		await ticks(2)
		check(flow.get_node("Victory").visible, "Developer boss arenas must show the shared victory UI")
		flow.get_node("Victory/Actions/Continue").pressed.emit()
		await scene_changed
		check(current_scene.scene_file_path == navigation.MENU, "Continue from a boss snapshot must return to the developer menu")
	print("Typography: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
