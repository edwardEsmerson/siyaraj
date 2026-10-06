extends "res://tests/forest_check.gd"

func run_checks() -> void:
	var forest = load("res://scripts/levels/forest.gd")
	for room in [&"", &"RootChamber", &"CanopyNest"]:
		forest.current_room = room
		forest.room_spawn = Vector2(320, -2050) if room == &"RootChamber" else Vector2(350, -3600)
		change_scene_to_file("res://scenes/main/forest.tscn")
		await scene_changed
		player = current_scene.player
		await ticks(8)
		var enemies: Array[Node] = current_scene.course.get_node("Encounters").get_children()
		check(enemies.size() == (3 if room == &"" else (1 if room == &"RootChamber" else 0)), "Only the current area's encounters must be active")
		for enemy in enemies:
			check(enemy.is_on_floor(), "Authored enemy must settle on supported floor: %s" % enemy.name)
			check(enemy.get_meta("room") == room, "Enemy must belong to the active room")
			var start_health: int = enemy.health
			enemy.take_damage(1, Vector2.ZERO)
			check(enemy.health == start_health - 1, "Integrated enemy must retain shared damage behavior")
		freeze_encounters()
		var checkpoints: Array[Node] = current_scene.course._checkpoints()
		for checkpoint in checkpoints:
			if checkpoint.get_meta("room", &"") != room:
				continue
			for enemy in enemies:
				check(enemy.global_position.distance_to(checkpoint.global_position) > enemy.detection_range + enemy.patrol_radius, "Diya respawn must lie beyond the initial patrol detection envelope")
	forest.current_room = &""
	release_inputs()
	if failures == 0:
		print("PASS: forest encounter placement, area isolation, grounded enemies, damage and safe diya spawn spacing")
	quit(1 if failures > 0 else 0)
