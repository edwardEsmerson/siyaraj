extends "res://tests/forest_check.gd"
## Real patrol and zero-ammo lash probes for the added encounters, including raised main-route landings.

const ADDED: Dictionary = {
	"forest": [
		"ClearingScout",
		"RidgeGuard",
		"HollowExitGuard",
		"BanyanExitGuard",
		"UpperEntryGuard",
		"FinalScout",
		"FinalLowGuard",
		"FinalExitGuard",
		"EdgeRunGuard",
		"EdgeStumpGuard",
		"ClearingRearShooter",
		"BranchGuard",
		"BranchScout",
		"RidgeApproachGuard",
		"RidgeDropShooter",
		"RidgeExitGuard",
		"HollowEntryGuard",
		"HollowWestGuard",
		"StoneEntryScout",
		"StoneMiddleGuard",
		"StoneExitGuard",
		"BanyanCrownScout",
		"BanyanDescentGuard",
		"UpperLandingShooter",
		"ShrineBranchScout",
		"FinalHighGuard",
	],
	"river": [
		"DockGuard",
		"GhatRestGuard",
		"GhatEntryShooter",
		"ChannelScout",
		"ProcessionBrute",
		"BankGuard",
		"DockShooter",
		"BrokenDockGuard",
		"BrokenDockScout",
		"FerryRearGuard",
		"StoneBankGuard",
		"StoneHighScout",
		"StoneCourtShooter",
		"GhatWestScout",
		"GhatCourtGuard",
		"GhatExitGuard",
		"BridgeDescentGuard",
		"BridgeFarGuard",
		"ChannelMiddleGuard",
		"ChannelExitShooter",
	],
	"palace": [
		"GateGuard",
		"GalleryEntranceGuard",
		"GalleryExitGuard",
		"RoofLookoutScout",
		"InnerEntryBrute",
		"InnerHallGuard",
		"GateLintelShooter",
		"GateDescentGuard",
		"CourtyardRearGuard",
		"WestColumnGuard",
		"GalleryRearShooter",
		"RoofStairGuard",
		"BrokenRoofGuard",
		"BrokenRoofScout",
		"RoofCourtRearGuard",
		"InnerWestScout",
		"InnerEastGuard",
		"ThroneRoofGuard",
	],
}

func run_checks() -> void:
	var navigation: Node = root.get_node("PlaytestNavigation")
	navigation.enemies_enabled = true
	var forest = load("res://scripts/levels/forest.gd")
	forest.checkpoint_x = 160.0
	forest.current_room = &""
	forest.lit_checkpoints.clear()
	for level: String in ADDED:
		navigation.start_level("res://scenes/main/%s.tscn" % level)
		await scene_changed
		player = current_scene.player
		await ticks(180)
		check(player.health == player.max_health, "%s entry must remain safe through a patrol cycle" % level)
		freeze_encounters()
		for enemy_name: String in ADDED[level]:
			await probe_encounter(enemy_name)
	forest.current_room = &"RootChamber"
	forest.room_spawn = Vector2(320, -2050)
	change_scene_to_file("res://scenes/main/forest.tscn")
	await scene_changed
	player = current_scene.player
	await ticks(180)
	check(player.health == player.max_health, "Root room arrival must remain safe through a patrol cycle")
	freeze_encounters()
	for enemy_name: String in ["RootDescentGuard", "RootFirstGuard", "RootSecondScout", "RootBedGuard"]:
		await probe_encounter(enemy_name)
	forest.current_room = &"CanopyNest"
	forest.room_spawn = Vector2(350, -3600)
	change_scene_to_file("res://scenes/main/forest.tscn")
	await scene_changed
	player = current_scene.player
	await ticks(180)
	check(player.health == player.max_health, "Nest arrival must remain safe through a patrol cycle")
	freeze_encounters()
	for enemy_name: String in ["NestEntryGuard", "CrownEastShooter"]:
		await probe_encounter(enemy_name)
	forest.checkpoint_x = 160.0
	forest.current_room = &""
	forest.lit_checkpoints.clear()
	release_inputs()
	print("Enemy pacing checks: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func probe_encounter(enemy_name: String) -> void:
	var course: Node2D = current_scene.course
	var enemy: CharacterBody2D = course.get_node("Encounters/" + enemy_name)
	var airborne: bool = enemy.get_meta("airborne", false)
	var home: Vector2 = enemy._home if airborne else Vector2(enemy._home_x, enemy.global_position.y)
	# Both ends of the patrol need room for the body and a grounded melee approach.
	for offset: float in [-enemy.patrol_radius - 24.0, enemy.patrol_radius + 24.0]:
		var at := home + Vector2(offset, -1)
		var query := PhysicsRayQueryParameters2D.create(at, at + Vector2(0, 48), 1)
		var support: Dictionary = enemy.get_world_2d().direct_space_state.intersect_ray(query)
		check(not support.is_empty(), "%s patrol must stay over a broad landing" % enemy_name)
		if not support.is_empty() and enemy.get_meta("room", &"") == &"":
			check(not support.collider.get_meta("alternate_route", false), "%s must not force an optional recovery or balcony route" % enemy_name)
	check(airborne or enemy.is_on_floor(), "%s must remain supported after patrolling" % enemy_name)
	if course.has_node("EncounterSpawns"):
		var marker: Node2D = course.get_node("EncounterSpawns/" + enemy_name)
		check(is_equal_approx(home.x, marker.global_position.x), "%s home must match its authored marker" % enemy_name)
	var checkpoints: Array[Node] = course._checkpoints() if course.has_method("_checkpoints") else course.get_node("Checkpoints").get_children()
	for checkpoint: Node2D in checkpoints:
		if checkpoint.get_meta("room", &"") == enemy.get_meta("room", &""):
			check(home.distance_to(checkpoint.global_position) > enemy.detection_range + enemy.patrol_radius, "%s must leave the diya outside its patrol/detection envelope" % enemy_name)
	# Low flyers and raised encounters must be defeatable without spending ammunition.
	var start := enemy.global_position + Vector2(-43, -1)
	var floor_query := PhysicsRayQueryParameters2D.create(start, start + Vector2(0, 48), 1)
	var floor_hit: Dictionary = enemy.get_world_2d().direct_space_state.intersect_ray(floor_query)
	check(not floor_hit.is_empty(), "%s must offer a grounded lash approach" % enemy_name)
	if floor_hit.is_empty():
		return
	player.sparkler.cancel()
	await place(Vector2(start.x, floor_hit.position.y))
	check(player.is_on_floor(), "%s melee approach must support Siya" % enemy_name)
	player.skyshot_ammo = 0
	player.facing_direction = 1
	player.attack_origin.position.x = 18
	var health_before: int = enemy.health
	Input.action_press("attack")
	await ticks(15)
	Input.action_release("attack")
	check(enemy.health < health_before, "%s must take a real grounded lash with zero ammo" % enemy_name)
	await ticks(35)
