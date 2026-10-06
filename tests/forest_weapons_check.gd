extends "res://tests/forest_check.gd"
## Exercise the weapon PR against real forest enemies and side-room transitions.

func press(action: StringName) -> void:
	Input.action_press(action)
	await ticks(1)
	Input.action_release(action)


func run_checks() -> void:
	change_scene_to_file("res://scenes/main/forest.tscn")
	await scene_changed
	player = current_scene.player
	await ticks(4)
	freeze_encounters()
	check(player.skyshot_ammo == 5, "Forest must begin with five skyshots")
	var indicators: Control = current_scene.get_node("HUD/AbilityIndicators")
	check(is_equal_approx(indicators.skyshot_fraction, 1.0) and is_equal_approx(indicators.chakri_fraction, 1.0), "Fresh abilities must show full circles")
	for node_name in ["Controls", "InputStatus", "Milestone", "WeaponStatus", "DashStatus", "CombatStatus", "Backdrop", "StatusBackdrop"]:
		check(not current_scene.get_node("HUD/" + node_name).visible, "Gameplay must hide debug HUD: " + node_name)
	check(indicators.size == root.get_visible_rect().size, "Ability HUD must follow the viewport")
	var guard: CharacterBody2D = current_scene.course.get_node("Encounters/ClearingGuard")
	await place(Vector2(1900, 430))
	player.facing_direction = 1
	var event := InputEventKey.new()
	event.physical_keycode = KEY_L
	event.pressed = true
	Input.parse_input_event(event)
	await ticks(1)
	event = InputEventKey.new()
	event.physical_keycode = KEY_L
	Input.parse_input_event(event)
	await ticks(20)
	check(player.skyshot_ammo == 4 and guard.health == 1, "Physical L must fire a two-damage shot at the forest guard")
	check(is_equal_approx(indicators.skyshot_fraction, 0.8), "One shot must drain one fifth of the orange circle")
	await place(Vector2(2010, 430))
	await press(&"attack")
	await ticks(25)
	check(not is_instance_valid(guard), "J must finish the guard with the integrated lash")
	var brute: CharacterBody2D = current_scene.course.get_node("Encounters/ShrineBrute")
	await place(Vector2(15760, 430))
	Input.action_press("special")
	await ticks(65)
	Input.action_release("special")
	await ticks(3)
	check(brute.health == 3, "Full chakri must deal three damage to the forest Brute")
	check(player.chakri_cooldown_remaining > 9, "Chakri must begin its 10-second cooldown")
	check(indicators.chakri_fraction < 0.02, "Released chakri must empty the blue circle")
	var fraction_before: float = indicators.chakri_fraction
	await ticks(30)
	check(indicators.chakri_fraction > fraction_before + 0.04, "Blue circle must refill as cooldown elapses")
	# Nonlethal damage and lighting a diya never refill specials.
	player.take_damage(1, Vector2.ZERO)
	await ticks(16)
	await place(Vector2(2450, 430))
	player.health = 2
	await press_interact()
	check(player.skyshot_ammo == 4 and player.health == 2, "Lighting a diya must preserve ammo and health")
	await place(Vector2(5660, 270))
	player.health = 2
	var cooldown_before: float = player.chakri_cooldown_remaining
	await press_interact()
	await ticks(6)
	player = current_scene.player
	freeze_encounters()
	check(current_scene.course.current_room == &"RootChamber", "Door must enter the root chamber")
	check(player.skyshot_ammo == 4 and player.health == 2, "Entering a side room must preserve ammo and health")
	check(player.chakri_cooldown_remaining > cooldown_before - 1, "Door must preserve chakri cooldown")
	await place(Vector2(160, -2050))
	player.health = 2
	await press_interact()
	await ticks(6)
	player = current_scene.player
	check(player.skyshot_ammo == 4 and player.health == 2, "Returning to the trail must preserve ammo and health")
	check(player.chakri_cooldown_remaining > 5, "Returning must not reset chakri cooldown")
	player.die()
	await ticks(30)
	player = current_scene.player
	check(player.skyshot_ammo == 5 and player.health == 3 and player.chakri_cooldown_remaining == 0, "Death must restore health, ammo and chakri at the secured forest diya")
	check(absf(player.position.x - 2450) < 1, "Weapon death must retain forest checkpoint flow")
	for action in [&"attack", &"skyshot", &"special"]:
		Input.action_release(action)
	release_inputs()
	if failures == 0:
		print("PASS: forest lash, physical L skyshot, charged chakri, HUD, diya state, portal preservation and death reset")
	quit(1 if failures > 0 else 0)
