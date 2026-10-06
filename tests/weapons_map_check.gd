extends SceneTree
## Traverses the revised playground and checks its intended grounded encounters.
var failures: int = 0
var player: CharacterBody2D


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


func press(action: StringName) -> void:
	Input.action_press(action)
	await ticks(1)
	Input.action_release(action)


func run_checks() -> void:
	change_scene_to_file("res://scenes/dev/weapons_playground.tscn")
	await scene_changed
	player = current_scene.get_node("Player")
	var guard: CharacterBody2D = current_scene.get_node("Guard")
	guard.set_physics_process(false)
	await ticks(3)
	var target: CharacterBody2D = current_scene.get_node("SkyshotTarget")
	player.position.x = 970
	await ticks(1)
	check(player.is_on_floor(), "Skyshot firing line must provide stable grounded space")
	var firing_x: float = player.position.x
	for shot in range(2):
		await press("skyshot")
		await ticks(40)
	check(target.health == 0 and player.skyshot_ammo == 3, "Two shots from the firing line must clear the ranged target")
	check(player.position.x < firing_x - 20, "Firing line must leave space behind Siya for recoil")

	player.position = Vector2(current_scene.CHAKRI_CENTER, current_scene.FLOOR_Y)
	await ticks(3)
	Input.action_press("special")
	await ticks(65)
	Input.action_release("special")
	await ticks(2)
	for title in ["CrowdLeft", "CrowdMiddle", "CrowdRight"]:
		check(current_scene.get_node(title).health == 0, "One charged chakri from the ring must clear the whole crowd")
	await ticks(100)
	check(current_scene.get_node("CrowdMiddle").health == 3, "Crowd must respawn while chakri is recharging")
	check(player.chakri_cooldown_remaining > 0, "Respawning targets must not reset the cooldown")

	# Run the complete route with the ordinary fixed jump. The guard is frozen so
	# traversal measures terrain rather than combat decisions.
	player.position = Vector2(150, current_scene.FLOOR_Y)
	player.velocity = Vector2.ZERO
	player.skyshot_ammo = 3
	player.chakri_cooldown_remaining = 30.0
	await ticks(3)
	Input.action_press("move_right")
	var crossed_blocks: int = 0
	for frame in range(1150):
		var needs_jump := false
		for obstacle_x in [1850, 2130, 2410]:
			var distance: float = obstacle_x - player.position.x
			if distance > 12 and distance < 48 and player.is_on_floor():
				needs_jump = true
		if needs_jump:
			Input.action_press("jump")
			crossed_blocks += 1
		await ticks(1)
		Input.action_release("jump")
		check(player.position.y <= current_scene.FLOOR_Y + 1, "Recovery lane must retain a safe continuous floor")
		if player.position.x > current_scene.MAP_WIDTH - 40:
			break
	Input.action_release("move_right")
	await ticks(5)
	check(player.position.x > current_scene.MAP_WIDTH - 40 and crossed_blocks >= 3, "The whole revised map must be traversable with the existing jump")
	check(player.skyshot_ammo == 3 and player.chakri_cooldown_remaining > 0, "Traversal must preserve ammo while making progress on chakri cooldown")
	check(is_equal_approx(current_scene.camera.position.x, current_scene.MAP_WIDTH - 480.0), "Camera must frame the final arena within the new map boundary")
	player.position.x = 12
	player.velocity = Vector2.ZERO
	await ticks(3)
	check(is_equal_approx(current_scene.camera.position.x, 480.0), "Camera must frame the start without exposing outside the map")
	if failures == 0:
		print("PASS: ranged target/firing line/recoil space, chakri crowd/ring, respawn, safe route, ammo persistence, recharge and camera limits")
	quit(1 if failures > 0 else 0)
