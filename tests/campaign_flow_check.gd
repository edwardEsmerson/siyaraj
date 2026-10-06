extends "res://tests/forest_check.gd"
## Fight mechanics are checked by the original boss suites; this tests campaign wiring.

func accept() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = true
	return event

func run_checks() -> void:
	var navigation: Node = root.get_node("PlaytestNavigation")
	navigation.enemies_enabled = true
	for level in ["forest", "river", "palace"]:
		navigation.start_level("res://scenes/main/%s.tscn" % level)
		await scene_changed
		current_scene._finish_course()
		check(current_scene.get_node("HUD/Completion/Message").text.contains("face"), "Campaign exit must clearly offer the boss fight")
		if level == "palace":
			check(current_scene.showdown_name == "Swaminathan" and current_scene.get_node("HUD/Completion/Message").text.contains("face Swaminathan"), "Palace exit must name Swaminathan")
		current_scene._unhandled_input(accept())
		await scene_changed
		check(current_scene.scene_file_path == "res://scenes/main/%s_showdown.tscn" % level, "Exit must enter its own showdown")
		var showdown: Node = current_scene
		var flow: CanvasLayer = showdown.get_node("CampaignFlow")
		var boss: Node = flow.get_node(flow.boss_path)
		player = showdown.get_node("Player")
		await ticks(4)
		check(player.is_on_floor() and player.health == player.max_health and player.skyshot_ammo == 5, "Fight must start grounded with the arena's fresh loadout")
		flow._unhandled_input(accept())
		check(current_scene == showdown, "Enter must not skip a living boss")
		player.die()
		await scene_changed
		check(current_scene.scene_file_path.ends_with("%s_showdown.tscn" % level), "Death must retry the boss, not the long level")
		flow = current_scene.get_node("CampaignFlow")
		boss = flow.get_node(flow.boss_path)
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
		check(flow.won and flow.get_node("Victory").visible, "Boss's real death signal must unlock victory")
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
