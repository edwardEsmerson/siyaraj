extends "res://tests/forest_check.gd"
## Real player probes cover both routes, checkpoint pockets and shooter cover.

func run_checks() -> void:
	var navigation: Node = root.get_node("PlaytestNavigation")
	navigation.enemies_enabled = false
	navigation.start_level("res://scenes/main/palace.tscn")
	await scene_changed
	player = current_scene.player
	await ticks(4)
	player.died.disconnect(current_scene._restart)
	current_scene.set_process(false)
	var course: Node2D = current_scene.course
	var terrain: Node2D = course.get_node("Terrain")
	var alternate: Node2D = course.get_node("AlternateRoutes")
	var route: Array[Node] = terrain.get_children()
	for index in range(route.size() - 1):
		var passed := await traverse(route[index], route[index + 1])
		check(passed, "Palace main route: %s -> %s" % [route[index].name, route[index + 1].name])
		print("Palace %s -> %s: %s" % [route[index].name, route[index + 1].name, passed])
	var choices := [
		[alternate.get_node("GalleryRoofStep1"), alternate.get_node("GalleryRoofStep2")],
		[alternate.get_node("GalleryRoofStep2"), alternate.get_node("GalleryRoofStep3")],
		[alternate.get_node("GalleryRoofStep3"), alternate.get_node("GalleryRoofStep4")],
		[alternate.get_node("GalleryRoofStep4"), alternate.get_node("GalleryRoof")],
		[alternate.get_node("GalleryRoof"), alternate.get_node("GalleryRoofDrop1")],
		[alternate.get_node("GalleryRoofDrop1"), alternate.get_node("GalleryRoofDrop2")],
		[alternate.get_node("GalleryRoofDrop2"), alternate.get_node("GalleryRoofDrop3")],
		[alternate.get_node("GalleryRoofDrop3"), terrain.get_node("GalleryExit")],
		[alternate.get_node("RoofRecoveryWest"), alternate.get_node("RoofRecoveryCentre")],
		[alternate.get_node("RoofRecoveryCentre"), alternate.get_node("RoofRecoveryEast")],
		[alternate.get_node("RoofRecoveryEast"), alternate.get_node("RoofRecoveryExit")],
		[alternate.get_node("RoofRecoveryExit"), terrain.get_node("RoofCourt")],
		[alternate.get_node("InnerBalconyStep1"), alternate.get_node("InnerBalconyStep2")],
		[alternate.get_node("InnerBalconyStep2"), alternate.get_node("InnerBalconyStep3")],
		[alternate.get_node("InnerBalconyStep3"), alternate.get_node("InnerBalconyStep4")],
		[alternate.get_node("InnerBalconyStep4"), alternate.get_node("InnerBalcony")],
		[alternate.get_node("InnerBalcony"), alternate.get_node("InnerBalconyDescent1")],
		[alternate.get_node("InnerBalconyDescent1"), alternate.get_node("InnerBalconyDescent2")],
		[alternate.get_node("InnerBalconyDescent2"), alternate.get_node("InnerBalconyDescent3")],
		[alternate.get_node("InnerBalconyDescent3"), terrain.get_node("InnerHall")],
		[alternate.get_node("SanctumRecovery"), alternate.get_node("SanctumRecoveryStep1")],
		[alternate.get_node("SanctumRecoveryStep1"), alternate.get_node("SanctumRecoveryStep2")],
		[alternate.get_node("SanctumRecoveryStep2"), terrain.get_node("ThroneApproach")]
	]
	for pair in choices:
		check(await traverse(pair[0], pair[1]), "Palace alternate route: %s -> %s" % [pair[0].name, pair[1].name])
	# These stairs overlap their broad lower floor. Probe the actual takeoff pocket,
	# rather than the far edge of that floor used by the consecutive-route helper.
	for entry in [[3420, "GalleryRoofStep1"], [9030, "InnerBalconyStep1"]]:
		var takeoff := Node2D.new()
		var collider := CollisionShape2D.new()
		collider.name = "CollisionShape2D"
		var shape := RectangleShape2D.new()
		shape.size = Vector2(100, 32)
		collider.shape = shape
		takeoff.add_child(collider)
		course.add_child(takeoff)
		takeoff.position = Vector2(entry[0] - 10, 446)
		check(await traverse(takeoff, alternate.get_node(entry[1])), "Optional stairs must be reachable from their marked entrance")
		takeoff.queue_free()
	for checkpoint: Area2D in course.get_node("Checkpoints").get_children():
		await place(checkpoint.position)
		check(player.is_on_floor(), "%s must stand on terrain" % checkpoint.name)
		await press_interact()
		check(checkpoint.get_node("Flame").visible, "%s must light with E" % checkpoint.name)
	course.reset_progress()
	navigation.enemies_enabled = true
	navigation.start_level("res://scenes/main/palace.tscn")
	await scene_changed
	player = current_scene.player
	await ticks(4)
	course = current_scene.course
	check(course.get_node("Encounters").get_child_count() == 12, "Palace has twelve staged encounters")
	for enemy: CharacterBody2D in course.get_node("Encounters").get_children():
		if not enemy.get_meta("airborne", false):
			check(enemy.is_on_floor(), "%s must stand on reachable solid ground" % enemy.name)
		for checkpoint: Area2D in course.get_node("Checkpoints").get_children():
			check(absf(enemy.position.x - checkpoint.position.x) > enemy.detection_range + enemy.patrol_radius, "%s must be outside %s approach" % [checkpoint.name, enemy.name])
	freeze_encounters()
	var shooter: CharacterBody2D = course.get_node("Encounters/GalleryShooter")
	await place(Vector2(3620, 430))
	check(not shooter._can_see(player), "West column base must block shooter sightline")
	await place(Vector2(3940, 430))
	check(shooter._can_see(player), "Shooter must see an exposed grounded melee approach")
	player.facing_direction = 1
	player.position.x = shooter.position.x - 45
	await ticks(2)
	Input.action_press("attack")
	await ticks(8)
	Input.action_release("attack")
	check(shooter.health < shooter.max_health, "Shooter must be reachable by grounded J lash")
	print("Palace layout checks: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
