extends "res://tests/forest_check.gd"
## Fight mechanics are checked by the original boss suites; this tests campaign wiring.

func accept() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = true
	return event

func run_checks() -> void:
	var story: GDScript = preload("res://scripts/main/story_panels.gd")
	var sequences: Array = [story.opening()]
	for region: String in ["forest", "river", "palace"]:
		sequences.append(story.introduction(region))
		sequences.append(story.aftermath(region))
	for sequence: Array in sequences:
		check(not sequence.is_empty(), "Every story stage must have dialogue")
		for panel: Dictionary in sequence:
			check(not panel.text.is_empty(), "Story panels must have dialogue")
			for key: String in ["texture", "subject", "supporting_subject"]:
				if not str(panel.get(key, "")).is_empty():
					check(ResourceLoader.exists(panel[key]), "Story artwork must exist: %s" % panel[key])
	var navigation: Node = root.get_node("PlaytestNavigation")
	navigation.enemies_enabled = true
	for level in ["forest", "river", "palace"]:
		navigation.start_level("res://scenes/main/%s.tscn" % level)
		await scene_changed
		current_scene._finish_course()
		if level == "river":
			check(current_scene.get_node("HUD/Completion/Message").text.contains("face"), "River exit must offer its boss fight")
			current_scene._unhandled_input(accept())
		await scene_changed
		check(current_scene.scene_file_path == "res://scenes/main/%s_showdown.tscn" % level, "Exit must enter its own showdown")
		var showdown: Node = current_scene
		var flow: CanvasLayer = showdown.get_node("CampaignFlow")
		var boss: Node = flow.get_node(flow.boss_path)
		player = showdown.get_node("Player")
		check(flow.comic.visible and not player.can_process() and not boss.can_process(), "Every versus entry must freeze both combatants")
		var health_before: int = player.health
		var boss_timer: float = boss._state_remaining if level == "palace" else boss.state_remaining
		await ticks(90)
		check(player.health == health_before and get_nodes_in_group("boss_hazards").is_empty(), "Versus entry must not allow attacks or damage")
		check(is_equal_approx(boss_timer, boss._state_remaining if level == "palace" else boss.state_remaining), "Versus entry must preserve the boss intro timer")
		var boss_art: String = {"forest": "khara", "river": "dhoomketu", "palace": "swaminathan"}[level]
		check(flow.comic.panel_art.texture.resource_path == "res://assets/cutscenes/boss-versus/%s.png" % boss_art, "Each showdown must show its approved versus card first")
		check(flow.comic.panel_art.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and flow.comic.panel_art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Versus cards must preserve pixels and the complete image")
		check(not flow.comic.bubble.visible and not flow.comic.featured_art.visible and not flow.comic.supporting_art.visible and not flow.comic.bubble_tail.visible and flow.comic.splash_advance.visible, "Versus faces and names must stay clear of dialogue and extra character overlays")
		var repeated_enter := InputEventKey.new()
		repeated_enter.keycode = KEY_ENTER
		repeated_enter.pressed = true
		repeated_enter.echo = true
		flow.comic._unhandled_input(repeated_enter)
		check(flow.comic._index == 0, "Held Enter must not skip the versus card")
		paused = true
		flow.comic._unhandled_input(accept())
		check(flow.comic._index == 0, "Pause must block advancing the versus card")
		paused = false
		flow.comic._unhandled_input(accept())
		check(flow.introduction.size() == story.introduction(level).size() + 1, "Versus card must preserve all current story dialogue")
		if not flow.introduction.is_empty():
			check(flow.comic.bubble.visible and flow.comic.bubble_tail.visible and not flow.comic.splash_advance.visible, "After the versus card, the existing dialogue layout must return")
			check(flow.comic.featured_art.texture != null and flow.comic.panel_art.texture != null, "Boss comic must show existing character and background art")
			for panel in flow.introduction.size() - 1:
				flow.comic._unhandled_input(accept())
		check(not flow.comic.visible and player.can_process() and boss.can_process(), "Closing the introduction must release combat")
		if level == "palace":
			var cage: Node2D = showdown.get_node("RajCage")
			check(not cage.freed and cage.raj.animation == &"sulk", "Raj must be visibly captive during the final fight")
			check(cage.find_children("*", "CollisionObject2D", true, false).is_empty(), "Cage must not obstruct arena combat")
		await ticks(4)
		check(player.is_on_floor() and player.health == player.max_health and player.skyshot_ammo == 5, "Fight must start grounded with the arena's fresh loadout")
		flow._unhandled_input(accept())
		check(current_scene == showdown, "Enter must not skip a living boss")
		if level == "palace":
			flow.finish_escape()
			check(not showdown.get_node("PalaceEscape").unlocked and current_scene == showdown, "Living boss must keep the palace escape locked")
		player.die()
		await scene_changed
		await preload("res://tests/respawn_test_helpers.gd").wait_for_respawn(self)
		check(current_scene.scene_file_path.ends_with("%s_showdown.tscn" % level), "Death must retry the boss, not the long level")
		flow = current_scene.get_node("CampaignFlow")
		boss = flow.get_node(flow.boss_path)
		check(flow.comic == null and current_scene.can_process(), "Death must retry without replaying the comic")
		player = current_scene.get_node("Player")
		await ticks(4)
		check(not flow.won and boss.health == boss.max_health and player.health == player.max_health, "Retry must reset boss and player")
		if level != "palace":
			boss.take_damage(boss.max_health, Vector2.ZERO)
		else:
			boss.start_fight()
			await ticks(2)
			boss.set_head_count(1)
			boss.take_damage(boss.health, Vector2.ZERO)
			await ticks(600)
		check(flow.won and flow.comic.visible and not player.can_process(), "Boss defeat must show the region transition with combat frozen")
		check(not flow.get_node("Victory").visible, "Victory controls must wait for the story")
		flow._unhandled_input(accept())
		check(current_scene == flow.get_parent(), "Enter must not bypass the aftermath dialogue")
		flow.get_node("Victory/Actions/Continue").pressed.emit()
		check(current_scene == flow.get_parent(), "Result button must not bypass the aftermath dialogue")
		await ticks(120)  # Boss corpses may finish freeing while the reader stays in the comic.
		if level == "palace":
			check(current_scene.get_node("RajCage").freed, "Swaminathan's defeat must open Raj's cage")
			check(not current_scene.get_node("PalaceEscape").unlocked, "Palace gates must wait for Robin's reveal and the reunion dialogue")
		for panel in flow.comic._panels.size():
			flow.comic._unhandled_input(accept())
		if level == "palace":
			var escape: Node = current_scene.get_node("PalaceEscape")
			check(escape.unlocked and not flow.get_node("Victory").visible, "Final dialogue must unlock the escape instead of covering the gates")
			check(story.aftermath("palace")[3].text.contains("always served Swaminathan"), "Finale must preserve Robin's allegiance reveal")
			flow._unhandled_input(accept())
			flow.get_node("Victory/Actions/Continue").pressed.emit()
			check(current_scene == flow.get_parent(), "Enter and hidden result controls must not bypass the escape")
			player.position = Vector2(800, 430)
			player.velocity = Vector2.ZERO
			Input.action_press("move_right")
			await ticks(90)
			Input.action_release("move_right")
		else:
			check(flow.get_node("Victory").visible, "Closing the aftermath must unlock the next stage")
			flow._unhandled_input(accept())
			await scene_changed
		var destination: String = {"forest": "river.tscn", "river": "palace.tscn", "palace": "ending.tscn"}[level]
		check(current_scene.scene_file_path.ends_with(destination), "Boss victory must advance to the next campaign stage")
	# Every ending action must work with mouse activation and focus navigation.
	check(current_scene.get_node("Center/Content/ReturnButton").has_focus(), "Victory must focus a usable navigation button")
	for button_name: String in ["ReturnButton", "NewJourney", "ReplayFinale"]:
		var button: Button = current_scene.get_node("Center/Content/" + button_name)
		check(button.get_global_rect().intersection(current_scene.get_global_rect()) == button.get_global_rect(), "Every ending button must fit inside the viewport")
	var down := InputEventAction.new()
	down.action = &"ui_down"
	down.pressed = true
	Input.parse_input_event(down)
	await ticks(1)
	check(current_scene.get_node("Center/Content/NewJourney").has_focus(), "Keyboard and controller navigation must reach the next ending action")
	down.pressed = false
	Input.parse_input_event(down)
	current_scene.get_node("Center/Content/ReplayFinale").pressed.emit()
	await scene_changed
	check(current_scene.scene_file_path.ends_with("palace_showdown.tscn") and not current_scene.get_node("CampaignFlow").won, "Replay finale must start a fresh boss with its dialogue")
	navigation.start_level("res://scenes/main/ending.tscn")
	await scene_changed
	current_scene.get_node("Center/Content/NewJourney").pressed.emit()
	await scene_changed
	check(current_scene.scene_file_path.ends_with("prologue.tscn") and navigation.enemies_enabled, "New journey must start the story with encounters enabled")
	navigation.start_level("res://scenes/main/ending.tscn")
	await scene_changed
	current_scene.get_node("Center/Content/ReturnButton").pressed.emit()
	await scene_changed
	check(current_scene.scene_file_path.ends_with("title.tscn") and not paused, "Return to title must leave an interactive menu")
	navigation.start_level("res://scenes/main/ending.tscn")
	await scene_changed
	var back := InputEventAction.new()
	back.action = &"ui_cancel"
	back.pressed = true
	current_scene._unhandled_input(back)
	await scene_changed
	check(current_scene.scene_file_path.ends_with("title.tscn"), "Ending back action must return to title")
	# Terrain-only launches deliberately bypass encounters and boss fights.
	navigation.enemies_enabled = false
	for level in ["forest", "river"]:
		navigation.start_level("res://scenes/main/%s.tscn" % level)
		await scene_changed
		current_scene._finish_course()
		current_scene._unhandled_input(accept())
		await scene_changed
		check(current_scene.scene_file_path.ends_with("river.tscn" if level == "forest" else "palace.tscn"), "Terrain-only levels must bypass bosses")
	print("Campaign flow: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
