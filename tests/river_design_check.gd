extends "res://tests/forest_check.gd"
## Real controller probes for the river route, recovery routes and encounter affordances.

func run_checks() -> void:
	var navigation: Node = root.get_node("PlaytestNavigation")
	navigation.enemies_enabled = false
	navigation.start_level("res://scenes/main/river.tscn")
	await scene_changed
	player = current_scene.player
	await ticks(4)
	player.died.disconnect(current_scene._restart)
	current_scene.set_process(false)
	var course: Node2D = current_scene.course
	check(course.level_width() == 14400, "River must retain a full-length route")
	var route: Array[Node] = course.get_node("Terrain").get_children()
	for index in range(route.size() - 1):
		var passed := await traverse(route[index], route[index + 1])
		check(passed, "River unreachable: %s -> %s" % [route[index].name, route[index + 1].name])
		print("River route %s -> %s: %s" % [route[index].name, route[index + 1].name, passed])
	var branches: Array = [
		["AlternateRoutes/FerryRecovery", "AlternateRoutes/FerryRecoveryExit", "Terrain/FerryLanding"],
		["AlternateRoutes/StoneRecovery", "AlternateRoutes/StoneRecoveryStep", "Terrain/Stone5", "Terrain/GhatRest"],
		["Terrain/GhatStep3", "AlternateRoutes/GhatUpper1", "AlternateRoutes/GhatUpper2", "AlternateRoutes/GhatBalcony", "AlternateRoutes/GhatUpperExit", "Terrain/GhatDrop1"],
		["AlternateRoutes/BridgeRecovery1", "AlternateRoutes/BridgeRecovery2", "AlternateRoutes/BridgeRecoveryExit", "Terrain/BridgeFall"],
		["AlternateRoutes/ChannelRecovery1", "AlternateRoutes/ChannelRecovery2", "AlternateRoutes/ChannelRecoveryExit", "Terrain/ProcessionCourt"],
	]
	for branch: Array in branches:
		for index in range(branch.size() - 1):
			var passed := await traverse(course.get_node(branch[index]), course.get_node(branch[index + 1]))
			check(passed, "River alternate unreachable: %s -> %s" % [branch[index], branch[index + 1]])
			print("River alternate %s -> %s: %s" % [branch[index], branch[index + 1], passed])
	# A miss between upper stones must land on the recovery dock, not require a reset.
	await place(Vector2(3550, 410))
	await ticks(25)
	check(player.is_on_floor() and absf(player.position.y - 500) < 1, "Missed stone jump must land on the recovery dock")
	for checkpoint in course.get_node("Checkpoints").get_children():
		await place(checkpoint.position)
		check(player.is_on_floor(), "Every river diya must stand on solid ground")
		check(not checkpoint.get_node("Flame").visible, "Walking past a diya must not save")
		await press_interact()
		check(checkpoint.get_node("Flame").visible, "Explicit E must light the diya")
	current_scene.set_process(true)
	player.died.connect(current_scene._restart)
	player.die()
	await scene_changed
	player = current_scene.player
	await ticks(4)
	check(player.position.distance_to(Vector2(13500, 430)) < 1, "Death must restore the last river diya")
	check(player.health == 3 and player.skyshot_ammo == 5, "River death must restore player resources")
	await place(Vector2(14200, 310))
	check(current_scene.completed, "River must finish in terrain mode with no ammo or enemy gate")
	navigation.enemies_enabled = true
	navigation.start_level("res://scenes/main/river.tscn")
	await scene_changed
	player = current_scene.player
	await ticks(4)
	course = current_scene.course
	var encounters := course.get_node("Encounters")
	check(encounters.get_child_count() == 8, "River must include eight staged encounters")
	for enemy in encounters.get_children():
		if enemy.name != &"BridgeFlyer":
			check(enemy.is_on_floor(), "%s must spawn on a broad combat landing" % enemy.name)
		for checkpoint in course.get_node("Checkpoints").get_children():
			check(absf(enemy.position.x - checkpoint.position.x) > enemy.detection_range + enemy.patrol_radius, "Diya must sit outside %s patrol and detection" % enemy.name)
	freeze_encounters()
	var shooter: CharacterBody2D = encounters.get_node("BridgeShooter")
	await place(Vector2(7330, 430))
	check(not shooter._can_see(player), "Bridge crate must block shooter sight")
	player.facing_direction = 1
	player.attack_origin.position.x = 18
	Input.action_press("skyshot")
	await ticks(1)
	Input.action_release("skyshot")
	await ticks(34)
	check(shooter.health == shooter.max_health, "Native cover must also stop a real skyshot")
	await place(Vector2(7460, 430))
	check(shooter._can_see(player), "Crossing cover must expose a grounded approach to the shooter")
	Input.action_press("skyshot")
	await ticks(1)
	Input.action_release("skyshot")
	await ticks(20)
	check(is_instance_valid(shooter) and shooter.health == shooter.max_health - 2, "Open lane after crossing cover must let skyshot hit the shooter")
	# The low bridge flyer remains lash reachable with zero ammunition.
	var flyer: CharacterBody2D = encounters.get_node("BridgeFlyer")
	await place(Vector2(flyer.position.x - 43, 350))
	player.skyshot_ammo = 0
	player.facing_direction = 1
	player.attack_origin.position.x = 18
	var health_before: int = flyer.health
	Input.action_press("attack")
	await ticks(15)
	Input.action_release("attack")
	check(flyer.health < health_before, "Bridge flyer must be lash reachable without skyshot ammunition")
	# Wide court supports a real ground dash as the response to a brute's windup.
	await place(Vector2(10210, 430))
	player.facing_direction = 1
	Input.action_press("dash")
	await ticks(1)
	check(player.state == player.State.DASH and player.is_invulnerable(), "Aqueduct court must permit an invulnerable ground dash")
	Input.action_release("dash")
	await ticks(18)
	check(player.is_on_floor() and player.position.x > 10300, "Ground dash must finish safely on the aqueduct floor")
	release_inputs()
	print("River design checks: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


