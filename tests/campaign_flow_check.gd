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
		if not flow.introduction.is_empty():
			check(flow.comic.visible and not player.can_process() and not boss.can_process(), "Comic entry must freeze both combatants")
			var health_before: int = player.health
			var boss_timer: float = boss.state_remaining if level != "palace" else boss._state_remaining
			await ticks(90)
			check(player.health == health_before and get_nodes_in_group("boss_hazards").is_empty(), "Comic entry must not allow attacks or damage")
			check(is_equal_approx(boss_timer, boss.state_remaining if level != "palace" else boss._state_remaining), "Comic entry must preserve the boss intro timer")
			check(flow.comic.featured_art.texture != null and flow.comic.panel_art.texture != null, "Boss comic must show existing character and background art")
			for panel in flow.introduction.size():
				flow.comic._unhandled_input(accept())
			check(not flow.comic.visible and player.can_process() and boss.can_process(), "Closing the comic must release combat")
		if level == "palace":
			var cage: Node2D = showdown.get_node("RajCage")
			check(not cage.freed and cage.raj.animation == &"sulk", "Raj must be visibly captive during the final fight")
			check(cage.find_children("*", "CollisionObject2D", true, false).is_empty(), "Cage must not obstruct arena combat")
		await ticks(4)
		check(player.is_on_floor() and player.health == player.max_health and player.skyshot_ammo == 5, "Fight must start grounded with the arena's fresh loadout")
		flow._unhandled_input(accept())
		check(current_scene == showdown, "Enter must not skip a living boss")
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
		for panel in flow.comic._panels.size():
			flow.comic._unhandled_input(accept())
		check(flow.get_node("Victory").visible, "Closing the aftermath must unlock the next stage")
		flow._unhandled_input(accept())
		await scene_changed
		var destination: String = {"forest": "river.tscn", "river": "palace.tscn", "palace": "ending.tscn"}[level]
		check(current_scene.scene_file_path.ends_with(destination), "Boss victory must advance to the next campaign stage")
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
