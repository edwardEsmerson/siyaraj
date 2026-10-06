extends "res://tests/forest_check.gd"
## Every consecutive route connection is traversed with the actual player controller.

func run_checks() -> void:
	var navigation: Node = root.get_node("PlaytestNavigation")
	navigation.enemies_enabled = false
	for level in ["river", "palace", "terrain_sampler"]:
		navigation.start_level("res://scenes/main/%s.tscn" % level)
		await scene_changed
		player = current_scene.player
		await ticks(4)
		check(player.is_on_floor(), "%s start must be grounded" % level)
		check(current_scene.course.get_node("Encounters").get_child_count() == 0, "Terrain mode must omit encounters")
		player.died.disconnect(current_scene._restart)
		current_scene.set_process(false)
		var route: Array[Node] = current_scene.course.get_node("Terrain").get_children()
		if level == "river":
			await repair_river_bridge()
			route.insert(route.find(current_scene.course.get_node("Terrain/BridgeGap1")), current_scene.course.get_node("BridgePlanks").placed_planks[-1])
		for index in range(route.size() - 1):
			var passed := await traverse(route[index], route[index + 1])
			check(passed, "%s unreachable: %s -> %s" % [level, route[index].name, route[index + 1].name])
			print("%s / %s -> %s: %s" % [level, route[index].name, route[index + 1].name, passed])
		current_scene.set_process(true)
		player.died.connect(current_scene._restart)
		var checkpoints: Array[Node] = current_scene.course.get_node("Checkpoints").get_children()
		for checkpoint in checkpoints:
			await place(checkpoint.position)
			check(player.is_on_floor(), "%s diya must stand on solid ground" % checkpoint.name)
			check(not checkpoint.get_node("Flame").visible, "Walking past must not light a diya")
		var last: Vector2 = checkpoints[-1].position
		player.health = 1
		await press_interact()
		check(checkpoints[-1].get_node("Flame").visible, "E must visibly light the checkpoint")
		check(player.health == 2, "%s fresh diya must restore exactly one heart" % level)
		await press_interact()
		check(player.health == 2, "%s already lit diya must not heal again" % level)
		await place(checkpoints[0].position)
		await press_interact()
		check(player.health == player.max_health, "%s diya healing must be capped at maximum health" % level)
		player.die()
		await scene_changed
		await preload("res://tests/respawn_test_helpers.gd").wait_for_respawn(self)
		player = current_scene.player
		await ticks(4)
		check(player.position.distance_to(last) < 1, "Death must restore the saved diya")
		check(player.health == 3 and player.skyshot_ammo == 5, "Death must restore player resources")
		player.health = 1
		await press_interact()
		check(player.health == 1, "%s saved diya must stay spent after reloading" % level)
		await place(Vector2(current_scene.course.get_node("Finish").position.x, 350))
		await ticks(4)
		check(current_scene.completed, "%s must finish without enemies" % level)
		current_scene.course.reset_progress()
	navigation.enemies_enabled = true
	for level in ["river", "palace"]:
		navigation.start_level("res://scenes/main/%s.tscn" % level)
		await scene_changed
		player = current_scene.player
		await ticks(4)
		var course: Node2D = current_scene.course
		check(course.get_node("Encounters").get_child_count() == (10 if level == "river" else 6), "%s must include its revised encounter composition" % level)
		for enemy in course.get_node("Encounters").get_children():
			if not enemy.scene_file_path.ends_with("flying_enemy.tscn"):
				check(enemy.is_on_floor(), "%s encounter must stand on terrain" % enemy.name)
			for checkpoint in course.get_node("Checkpoints").get_children():
				check(absf(enemy.position.x - checkpoint.position.x) > enemy.detection_range + enemy.patrol_radius, "Checkpoint must sit beyond enemy approach range")
	print("Next levels checks: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
