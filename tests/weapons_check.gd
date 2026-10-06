extends SceneTree
## Real input/physics checks for the isolated three-weapon prototype.
var failures: int = 0
var player: CharacterBody2D
var dummy: CharacterBody2D


func _initialize() -> void:
	call_deferred("run_checks")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func ticks(count: int) -> void:
	for frame in range(count):
		await physics_frame
		await process_frame


func reset_playground() -> void:
	for action in [&"attack", &"skyshot", &"special", &"dash", &"jump", &"restart", &"move_left", &"move_right"]:
		Input.action_release(action)
	change_scene_to_file("res://scenes/dev/weapons_playground.tscn")
	await scene_changed
	player = current_scene.get_node("Player")
	dummy = current_scene.get_node("SparklerDummy")
	await ticks(3)


func press(action: StringName) -> void:
	Input.action_press(action)
	await ticks(1)
	Input.action_release(action)


func run_checks() -> void:
	await reset_playground()
	check(player.is_on_floor(), "Playground player must spawn on solid ground")
	var shot_keys := InputMap.action_get_events("skyshot").filter(func(event: InputEvent) -> bool: return event is InputEventKey)
	check(shot_keys.size() == 1 and shot_keys[0] is InputEventKey and shot_keys[0].physical_keycode == KEY_L, "Skyshot must be bound to L")
	dummy.set_physics_process(false)
	player.position.x = dummy.position.x - 42
	await press("attack")
	check(dummy.health == 12, "Sparkler must retain a visible wind-up")
	await ticks(9)
	check(dummy.health == 11, "Single lash must deal one hit")
	await press("attack")
	await ticks(36)
	check(dummy.health == 11 and dummy.total_hits == 1, "Recovery presses must not queue a second lash")
	await ticks(25)
	check(dummy.health == 11, "Sparkler must not repeat without a fresh press")
	Input.action_press("attack")
	await ticks(65)
	Input.action_release("attack")
	check(dummy.health == 10, "Holding attack must not automatically repeat")

	await reset_playground()
	dummy.set_physics_process(false)
	player.position = Vector2(dummy.position.x - 42, 425)
	await press("attack")
	await ticks(10)
	check(dummy.health == 11, "Airborne J must hit a nearby target with the aerial lash")

	await reset_playground()
	dummy.set_physics_process(false)
	player.position.x = dummy.position.x - 42
	await press("attack")
	await press("jump")
	await ticks(12)
	check(dummy.health == 11, "Jumping during wind-up must preserve the single lash")

	await reset_playground()
	dummy.set_physics_process(false)
	player.position.x = dummy.position.x - 42
	Input.action_press("jump")
	Input.action_press("attack")
	await ticks(1)
	Input.action_release("jump")
	Input.action_release("attack")
	await ticks(12)
	check(dummy.health == 11, "Simultaneous jump and J must allow one lash")

	await reset_playground()
	player.position.x = current_scene.get_node("CrowdMiddle").position.x
	var crowd: Array[CharacterBody2D] = []
	for title in ["CrowdLeft", "CrowdMiddle", "CrowdRight"]:
		var target: CharacterBody2D = current_scene.get_node(title)
		target.set_physics_process(false)
		# Durable fixtures let this check compare multiple damage strengths.
		target.max_health = 12
		target.health = 12
		crowd.append(target)
	Input.action_press("special")
	await ticks(65)
	check(crowd[1].health == 12 and player.charging, "Charging must not deal damage before release")
	Input.action_release("special")
	await ticks(2)
	for target in crowd:
		check(target.health == 9, "Full chakri must damage targets on both sides once for three damage")
	await ticks(40)
	for target in crowd:
		check(target.health == 9, "Chakri visual must not repeatedly damage targets")
	check(player.chakri_cooldown_remaining > 29.0 and player.chakri_cooldown_remaining < 30.0, "Chakri must start a 30-second cooldown on release")
	Input.action_press("special")
	await ticks(4)
	Input.action_release("special")
	await ticks(2)
	check(not player.charging and crowd[1].health == 9, "Chakri must reject another charge while cooling down")
	check(current_scene.status.text.contains("Chakri: 30s"), "HUD must show chakri's remaining cooldown")
	# Keep targets frozen while checking expiry, without waiting 30 wall seconds.
	player.chakri_cooldown_remaining = 0.04
	await ticks(4)
	Input.action_press("special")
	await ticks(4)
	Input.action_release("special")
	await ticks(2)
	check(crowd[1].health == 8 and crowd[0].health == 9, "Quick chakri must be weaker and have shorter reach")

	await reset_playground()
	player.position.x = current_scene.get_node("CrowdMiddle").position.x
	current_scene._add_platform(Rect2(player.position.x - 60, 350, 20, 110), Color.WHITE)
	Input.action_press("special")
	await ticks(65)
	Input.action_release("special")
	await ticks(2)
	check(current_scene.get_node("CrowdLeft").health == 3, "Solid walls must block chakri damage")
	check(current_scene.get_node("CrowdRight").health == 0, "An unobstructed target must still take chakri damage")

	await reset_playground()
	Input.action_press("special")
	await ticks(8)
	player.take_damage(1, Vector2(-100, -100))
	Input.action_release("special")
	await ticks(2)
	check(not player.charging and player.effect_kind.is_empty() and player.chakri_cooldown_remaining == 0.0, "Interrupted charge must cancel without consuming chakri cooldown")
	await check_chakri_dashes()

	await check_skyshots()
	if failures == 0:
		print("PASS: single ground/air lash, projectile collision/damage, five-shot ammo/recoil, round refill, chakri cooldown, dash preservation and damage interruption")
	quit(1 if failures > 0 else 0)


func check_chakri_dashes() -> void:
	for airborne in [false, true]:
		await reset_playground()
		dummy.set_physics_process(false)
		Input.action_press("special")
		await ticks(65)
		if airborne:
			await press("jump")
		await press("dash")
		check(player.state == player.State.DASH and player.charging and is_equal_approx(player.charge_time, player.full_charge_time), "Ground and air dash must preserve a fully charged chakri")
		check(not player.sparkler.is_busy() and player.chakri_cooldown_remaining == 0.0, "Dashing with a charge must leave sparkler idle and not spend chakri cooldown")
		await ticks(12)
		check(player.state == player.State.NORMAL and player.charging and is_equal_approx(player.charge_time, player.full_charge_time), "Chakri must remain fully charged after the dash ends")
		dummy.position = player.position + Vector2(60, 0)
		await ticks(1)
		Input.action_release("special")
		await ticks(2)
		check(dummy.health == 9 and dummy.total_hits == 1, "Releasing after a dash must deal full chakri damage once")

	await reset_playground()
	Input.action_press("special")
	await ticks(8)
	await press("dash")
	var saved_charge: float = player.charge_time
	await ticks(3)
	check(player.charging and is_equal_approx(player.charge_time, saved_charge), "A partial charge must retain its progress during a dash")
	await ticks(10)
	check(player.charging and player.charge_time > saved_charge, "Holding special must resume charging after the dash")
	player.take_damage(1, Vector2.ZERO)
	check(not player.charging and player.charge_time == 0.0, "Damage after a dash must still cancel the preserved charge")

	await reset_playground()
	Input.action_press("special")
	await ticks(65)
	await press("dash")
	Input.action_release("special")
	await ticks(2)
	check(player.state == player.State.DASH and player.charging and player.chakri_cooldown_remaining == 0.0, "Releasing mid-dash must keep the charge until the dash ends")
	await ticks(12)
	check(not player.charging and is_equal_approx(player.effect_radius, player.chakri_radius) and player.chakri_cooldown_remaining > 29.9, "A mid-dash release must fire a full chakri after the dash")
	await ticks(40)
	check(player.chakri_cooldown_remaining < 29.5, "A queued chakri release must fire only once")


func fire_shot() -> void:
	await press("skyshot")


func check_skyshots() -> void:
	await reset_playground()
	dummy.set_physics_process(false)
	dummy.position.x = player.position.x + 280
	var start_x: float = player.position.x
	await fire_shot()
	check(player.skyshot_ammo == 4 and dummy.health == 12, "Firing must consume one shot without instant ranged damage")
	check(player.velocity.x < 0 and player.state == player.State.NORMAL and player.health == 3, "Right-facing fire must recoil left without damage or hurt state")
	await ticks(35)
	check(dummy.health == 10 and dummy.total_hits == 1, "Travelling projectile must damage its target once for two damage")
	check(player.position.x < start_x - 10 and player.position.x > start_x - 20, "Recoil must push Siya back a short distance")
	check(current_scene.status.text.contains("Skyshot: 4/5"), "HUD must show remaining ammo")

	await reset_playground()
	dummy.set_physics_process(false)
	player.position.x = 650
	current_scene.get_node("SparklerPractice").collision_layer = 0
	dummy.position.x = 430
	await press("move_left")
	await ticks(3)
	start_x = player.position.x
	await fire_shot()
	check(player.velocity.x > 0, "Left-facing fire must recoil right")
	await ticks(35)
	check(dummy.health == 10 and player.position.x > start_x + 10, "Left projectile and opposite recoil must both work")

	await reset_playground()
	await fire_shot()
	await fire_shot()
	check(player.skyshot_ammo == 4, "Rapid presses during firing recovery must not consume another shot")
	await press("jump")
	check(player.position.y < 460, "Jump input must remain available during recoil")
	await ticks(35)
	check(player.is_on_floor(), "Recoil must preserve gravity and normal landing")
	await press("jump")
	await ticks(4)
	await fire_shot()
	check(player.skyshot_ammo == 3 and player.position.y < 460, "Skyshots must fire in air without resetting jump movement")

	await reset_playground()
	dummy.set_physics_process(false)
	dummy.position.x = 250
	current_scene._add_platform(Rect2(163, 350, 2, 110), Color.WHITE)
	await fire_shot()
	await ticks(35)
	check(dummy.health == 12 and player.skyshot_ammo == 4, "Thin walls must stop a point-blank shot, which still costs ammo")
	check(get_nodes_in_group("skyshot_projectiles").is_empty(), "Wall impact must remove the projectile")

	await reset_playground()
	player.position.y = 250
	await fire_shot()
	await ticks(90)
	check(player.skyshot_ammo == 4 and get_nodes_in_group("skyshot_projectiles").is_empty(), "A missed shot must expire without refunding ammo")

	await reset_playground()
	current_scene._add_platform(Rect2(133, 350, 4, 110), Color.WHITE)
	await fire_shot()
	await ticks(10)
	check(player.position.x >= 148.9, "Recoil must respect a solid wall behind Siya")

	await reset_playground()
	dummy.set_physics_process(false)
	dummy.position.x = 430
	Input.action_press("skyshot")
	await ticks(90)
	Input.action_release("skyshot")
	check(player.skyshot_ammo == 4 and dummy.health == 10, "Holding fire must not repeat shots")

	await reset_playground()
	dummy.set_physics_process(false)
	dummy.position.x = 430
	for shot in range(5):
		await fire_shot()
		await ticks(40)
	check(player.skyshot_ammo == 0 and dummy.health == 2, "Exactly five shots must be available in a round")
	start_x = player.position.x
	await fire_shot()
	await ticks(35)
	check(player.skyshot_ammo == 0 and dummy.health == 2 and is_equal_approx(player.position.x, start_x), "Empty fire must produce neither damage nor recoil nor negative ammo")
	check(get_nodes_in_group("skyshot_projectiles").is_empty(), "No sixth projectile may be spawned")
	await ticks(120)
	check(player.skyshot_ammo == 0, "Waiting must never regenerate ammo")
	player.take_damage(1, Vector2.ZERO)
	await ticks(15)
	check(player.skyshot_ammo == 0, "Nonlethal damage must not refill ammo")
	player.position.x = dummy.position.x - 42
	await press("attack")
	await ticks(25)
	check(dummy.health == 1, "Empty ammo must leave sparkler available")
	Input.action_press("special")
	await ticks(65)
	Input.action_release("special")
	await ticks(2)
	check(player.chakri_cooldown_remaining > 29.9, "Empty ammo must leave chakri available")

	await reset_playground()
	await fire_shot()
	await ticks(10)
	Input.action_press("special")
	await ticks(4)
	Input.action_release("special")
	await ticks(40)
	await fire_shot()
	check(player.skyshot_ammo == 3 and player.chakri_cooldown_remaining > 0, "Skyshots must remain usable during chakri cooldown")
	await ticks(35)
	check(get_nodes_in_group("skyshot_projectiles").size() <= 1, "Projectiles must expire or collide rather than accumulate")

	await reset_playground()
	var target: CharacterBody2D = current_scene.get_node("SkyshotTarget")
	player.position.x = 970
	await fire_shot()
	await ticks(40)
	await fire_shot()
	await ticks(140)
	check(target.health == 4 and player.skyshot_ammo == 3, "Target defeat and respawn must not refill ammo")
	var previous_scene := current_scene
	player.take_damage(3, Vector2.ZERO)
	await preload("res://tests/respawn_test_helpers.gd").wait_for_respawn(self)
	check(current_scene != previous_scene and current_scene.get_node("Player").skyshot_ammo == 5, "Death must start a fresh round with five shots")
	player = current_scene.get_node("Player")
	await fire_shot()
	await ticks(10)
	change_scene_to_file("res://scenes/dev/weapons_playground.tscn")
	await scene_changed
	await ticks(3)
	player = current_scene.get_node("Player")
	check(player.skyshot_ammo == 5, "Entering a new level scene must start with five shots")
	await fire_shot()
	await ticks(10)
	previous_scene = current_scene
	await press("restart")
	await ticks(3)
	check(current_scene != previous_scene and current_scene.get_node("Player").skyshot_ammo == 5, "Playground reset must start a new round with five shots")
