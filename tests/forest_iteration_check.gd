extends "res://tests/forest_check.gd"
## Recovery routes, aerial melee reach, guarded detours and the safe boss approach.

func run_checks() -> void:
	var forest = load("res://scripts/levels/forest.gd")
	var initial: Node = forest.new()
	initial.reset_progress()
	initial.free()
	change_scene_to_file("res://scenes/main/forest.tscn")
	await scene_changed
	player = current_scene.player
	await ticks(8)
	freeze_encounters()
	player.died.disconnect(current_scene._restart)
	current_scene.set_process(false)
	var roots: Node = current_scene.course.get_node("RecoveryRoutes")
	for chain in [["StoneCatch", "StoneRecover1", "StoneRecover2", "StoneRecover3"], ["UpperCatch", "UpperRecover1", "UpperRecover2", "UpperRecover3"]]:
		for index in range(chain.size() - 1):
			check(await traverse(roots.get_node(chain[index]), roots.get_node(chain[index + 1])), "Recovery roots must climb back to the route: %s" % chain[index])
	check(await traverse(roots.get_node("StoneRecover3"), current_scene.course.get_node("Terrain/Stone4")), "Stone catch must reconnect to the main trail")
	check(await traverse(roots.get_node("UpperRecover3"), current_scene.course.get_node("Terrain/Upper4")), "Upper catch must reconnect to the main trail")
	await place(Vector2(9520, 510))
	check(player.is_on_floor(), "Missing a stone landing must have a supported recovery root")
	await place(Vector2(14480, 510))
	check(player.is_on_floor(), "Missing the upper ravine landing must have a supported recovery root")
	current_scene.set_process(true)
	player.died.connect(current_scene._restart)
	await place(Vector2(21200, 430))
	await press_interact()
	check(forest.checkpoint_x == 21200, "The Khara approach must have an explicit final diya")
	player.die()
	await ticks(30)
	player = current_scene.player
	check(player.position.distance_to(Vector2(21200, 430)) < 1, "Preboss death must return to the quiet final landing")
	for setup in [
		{"room": &"", "name": "CanopyScout", "feet": Vector2(4300, 430)},
		{"room": &"", "name": "UpperScout", "feet": Vector2(14270, 410)},
		{"room": &"CanopyNest", "name": "NestScout", "feet": Vector2(2790, -4500)},
	]:
		forest.current_room = setup.room
		forest.room_spawn = Vector2(350, -3600)
		change_scene_to_file("res://scenes/main/forest.tscn")
		await scene_changed
		player = current_scene.player
		await ticks(8)
		freeze_encounters()
		var scout: Node2D = current_scene.course.get_node("Encounters/" + setup.name)
		var origin: Vector2 = scout.position
		player.skyshot_ammo = 0
		for strike in range(3):
			scout.position = origin
			await place(setup.feet + Vector2(-40, 0))
			player.facing_direction = 1
			player.attack_origin.position.x = 18
			Input.action_press("attack")
			await ticks(1)
			Input.action_release("attack")
			await ticks(26)
		check(not is_instance_valid(scout) or scout.health == 0, "Flying threat must be defeatable with grounded melee and no ammo: %s" % setup.name)
		check(player.skyshot_ammo == 0, "Melee route must never require a skyshot refill")
	forest.current_room = &""
	release_inputs()
	if failures == 0:
		print("PASS: recovery roots, route rejoining, final diya respawn and zero-ammo aerial melee counterplay")
	quit(1 if failures > 0 else 0)
