extends "res://tests/forest_check.gd"
## Overshoot leeway, return to the passed diya, curtain timing and save preservation.

func wait_for_cover(guard: CanvasLayer) -> void:
	var saw_trailing_hem: bool = false
	for frame in range(60):
		if guard.curtains.coverage >= 1.0:
			# Let the tween's finished continuation perform the covered teleport.
			await ticks(1)
			check(saw_trailing_hem, "Closing rail must reach the middle before the curved hem catches up")
			return
		if guard.curtains.coverage >= 0.72:
			saw_trailing_hem = guard.curtains.coverage_at(0.0) == 1.0 and guard.curtains.coverage_at(1.0) < 1.0
		await ticks(1)
	check(false, "Curtains must close within a bounded time")

func wait_for_return(guard: CanvasLayer) -> void:
	var saw_trailing_hem: bool = false
	for frame in range(100):
		if not guard.returning:
			check(saw_trailing_hem, "Opening rail must clear the screen before the curved hem catches up")
			return
		if guard.curtains.opening and guard.curtains.coverage <= 0.28 and guard.curtains.coverage > 0.0:
			saw_trailing_hem = guard.curtains.coverage_at(0.0) == 0.0 and guard.curtains.coverage_at(1.0) > 0.0
		await ticks(1)
	check(false, "Curtains must reopen and restore gameplay")

func run_checks() -> void:
	var navigation: Node = root.get_node("PlaytestNavigation")
	for level in ["forest", "river", "palace"]:
		navigation.enemies_enabled = true
		navigation.start_level("res://scenes/main/%s.tscn" % level)
		await scene_changed
		player = current_scene.player
		await ticks(4)
		var course: Node = current_scene.course
		var guard: CanvasLayer = current_scene.checkpoint_guard
		var checkpoints: Array[Node] = course.get_node("Checkpoints").get_children()
		var first: Area2D = checkpoints[0]
		var second: Area2D = checkpoints[1]
		var enemies: Array[Node] = course.get_node("Encounters").get_children()
		for enemy in enemies:
			enemy.set_physics_process(false)
		var wounded: Node = enemies[0]
		wounded.take_damage(1, Vector2.ZERO)
		var wounded_health: int = wounded.health
		check(guard.blocked(first), "First diya must require its encounter: %s" % level)
		await place(first.position)
		await press_interact()
		check(not first.get_node("Flame").visible, "An uncleared diya must not save a bypass")
		check(first.get_node("Prompt").text.contains("Defeat"), "Blocked diya must explain the requirement")
		player.set_physics_process(false)
		player.position = first.position + Vector2(guard.PASS_LEEWAY, -80)
		await ticks(4)
		check(not guard.returning, "Standing inside the diya leeway, including its boundary, must not trigger curtains")
		player.set_physics_process(true)
		player.health = 2
		player.skyshot_ammo = 1
		player.position = first.position + Vector2(guard.PASS_LEEWAY - 5, -100)
		player.facing_direction = 1
		Input.action_press("dash")
		await ticks(3)
		Input.action_release("dash")
		check(guard.returning, "Air dash beyond the diya leeway must trigger curtains: %s" % level)
		await wait_for_cover(guard)
		check(player.global_position.distance_to(first.global_position) < 1, "An overshoot must return to the passed diya while covered")
		check(player.health == 2 and player.skyshot_ammo == 1, "Return must preserve health and ammo")
		check(wounded.health == wounded_health, "Return must preserve damage already dealt to enemies")
		check(player.velocity == Vector2.ZERO and player.state == player.State.NORMAL, "Teleport must cancel dash momentum")
		paused = true
		await create_timer(0.15, true).timeout
		check(guard.returning and guard.curtains.coverage == 1.0, "Pausing must suspend the curtain transition")
		paused = false
		await create_timer(0.3, false).timeout
		check(guard.returning and guard.curtains.coverage == 1.0, "Curtains must remain fully closed during the half-second hold")
		check(not first.get_node("Flame").visible, "Rejection must not light the blocked diya")
		await wait_for_return(guard)
		check(current_scene.process_mode == Node.PROCESS_MODE_INHERIT and not guard.curtains.visible, "Gameplay must resume with curtains hidden")
		await ticks(4)
		check(not guard.returning, "Returning onto an uncleared diya must not immediately retrigger the curtains")
		check(current_scene.player_spawn.global_position.x < first.global_position.x, "Returning to a diya must not advance the secured death checkpoint")
		# Defeat the first segment. Overshooting the second must return to the
		# second diya, independently of the first diya or saved death checkpoint.
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.position.x <= first.position.x:
				enemy.take_damage(enemy.health, Vector2.ZERO)
		await ticks(2)
		check(not guard.blocked(first), "All defeated enemies must unlock the first diya")
		await place(first.position + Vector2(guard.PASS_LEEWAY + 20, 0))
		check(not guard.returning, "Cleared crossings must pass freely")
		check(guard.blocked(second), "The next segment must retain its own enemies")
		# Enemy patrol/repositioning past the diya must not change its assignment.
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.health > 0 and enemy.position.x < second.position.x:
				enemy.position.x = second.position.x + 200
		check(guard.blocked(second), "Guard assignment must use authored positions")
		player.position = second.position + Vector2(guard.PASS_LEEWAY + 10, -80)
		await ticks(2)
		await wait_for_cover(guard)
		check(player.position.distance_to(second.position) < 1, "Second overshoot must return to the second diya, not the prior checkpoint")
		await wait_for_return(guard)
		await place(first.position)
		await press_interact()
		check(first.get_node("Flame").visible, "Cleared diya must still save through E")
		navigation.restart_checkpoint()
		await scene_changed
		player = current_scene.player
		await ticks(4)
		guard = current_scene.checkpoint_guard
		check(not guard.blocked(current_scene.course.get_node("Checkpoints").get_child(0)), "Enemies behind the secured respawn must not re-block it")
	# Developer terrain launches have no encounter requirements.
	navigation.enemies_enabled = false
	navigation.start_level("res://scenes/main/forest.tscn")
	await scene_changed
	player = current_scene.player
	await place(Vector2(2450 + current_scene.checkpoint_guard.PASS_LEEWAY + 10, 430))
	check(not current_scene.checkpoint_guard.returning, "Enemy-free playtests must bypass the curtains")
	navigation.enemies_enabled = true
	release_inputs()
	print("Checkpoint guard checks: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
