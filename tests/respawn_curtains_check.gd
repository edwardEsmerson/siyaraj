extends "res://tests/forest_check.gd"
## Death reloads must stay covered and reveal a frozen, restored checkpoint.

func run_checks() -> void:
	var navigation: Node = root.get_node("PlaytestNavigation")
	var transition: CanvasLayer = navigation.respawn_transition
	navigation.enemies_enabled = false
	for level in ["forest", "river", "palace"]:
		navigation.start_level("res://scenes/main/%s.tscn" % level)
		await scene_changed
		player = current_scene.player
		var checkpoint: Area2D = current_scene.course.get_node("Checkpoints").get_child(0)
		await place(checkpoint.position)
		await press_interact()
		check(checkpoint.get_node("Flame").visible, "Death test must secure a checkpoint")
		var saved_position: Vector2 = checkpoint.global_position
		player.skyshot_ammo = 1
		player.chakri_cooldown_remaining = 20.0
		player.position += Vector2(60, -40)
		var original: Node = current_scene
		if level == "river":
			player.position.y = current_scene.fall_boundary + 10
			await ticks(1)
		else:
			player.take_damage(player.health, Vector2.ZERO)
		await ticks(3)
		check(transition.active and transition.curtains.visible and not transition.curtains.opening, "Lethal damage and falls must close the existing curtains")
		check(current_scene == original, "Death must not reload before the curtains cover the screen")
		var generation: int = transition._generation
		navigation.respawn(original)
		check(transition._generation == generation, "Repeated death requests must not restart the curtain sequence")
		var restart := InputEventAction.new()
		restart.action = &"restart"
		restart.pressed = true
		Input.parse_input_event(restart)
		await ticks(1)
		paused = true
		var coverage: float = transition.curtains.coverage
		await create_timer(0.12, true).timeout
		check(transition.curtains.coverage == coverage and current_scene == original, "Pause must stop the closing curtains and checkpoint reload")
		paused = false
		await scene_changed
		await ticks(1)
		player = current_scene.player
		check(transition.curtains.coverage == 1.0 and transition.curtains.visible, "Checkpoint reload must remain fully covered")
		check(player.global_position.distance_to(saved_position) < 1, "Siya must respawn at the last lit checkpoint beneath the curtains")
		check(player.health == player.max_health and player.skyshot_ammo == 5 and player.chakri_cooldown_remaining == 0.0, "Covered respawn must restore health and weapons")
		check(not current_scene.can_process(), "Gameplay must stay frozen during the covered hold and reveal")
		Input.action_press("move_right")
		await ticks(15)
		check(player.global_position.distance_to(saved_position) < 1, "Held movement must not move Siya behind the curtains")
		Input.action_release("move_right")
		await preload("res://tests/respawn_test_helpers.gd").wait_for_respawn(self)
		check(not transition.curtains.visible and current_scene.can_process(), "Opening must hide the curtains and restore gameplay")
		Input.action_press("move_right")
		await ticks(4)
		check(player.position.x > saved_position.x, "Siya must move again after the reveal")
		Input.action_release("move_right")
	# Leaving during either half must cancel the pending reload and reveal.
	for covered in [false, true]:
		player.die()
		if covered:
			await scene_changed
			await ticks(1)
		else:
			await ticks(3)
		navigation.show_menu()
		await scene_changed
		await ticks(100)
		check(current_scene.scene_file_path == navigation.MENU and not transition.active and not transition.curtains.visible, "Leaving during death must keep the menu free of stale curtains or reloads")
		navigation.start_level("res://scenes/main/forest.tscn")
		await scene_changed
		player = current_scene.player
		await ticks(4)
	navigation.enemies_enabled = true
	release_inputs()
	print("Respawn curtain checks: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
