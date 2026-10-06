extends SceneTree
## Dash checks run through real physics and course collisions.

var player: CharacterBody2D
var failures: int = 0


func _initialize() -> void:
	call_deferred("run_checks")


func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func ticks(count: int) -> void:
	for tick in range(count):
		await physics_frame
		await process_frame


func release_inputs() -> void:
	for action in [&"move_left", &"move_right", &"jump", &"dash", &"restart"]:
		Input.action_release(action)


func reset_player(at: Vector2) -> void:
	release_inputs()
	current_scene.get_node("Player").free()
	player = load("res://scenes/player/player.tscn").instantiate()
	player.name = "Player"
	current_scene.add_child(player)
	current_scene.player = player
	player.died.connect(current_scene._restart)
	player.position = at
	await ticks(3)


func run_checks() -> void:
	change_scene_to_file("res://scenes/main/movement_playground.tscn")
	await scene_changed
	await reset_player(Vector2(300, 430))
	var grounded_x := player.position.x
	check(player.is_on_floor(), "Ground dash test must start on the floor")
	Input.action_press("dash")
	await ticks(1)
	check(player.state == player.State.DASH and player.dash_available, "Ground dash must start without spending the air charge")
	check(player.is_invulnerable(), "Ground dash must grant i-frames")
	Input.action_release("dash")
	await ticks(8)
	check(absf(player.position.x - grounded_x - 108.0) < 0.2, "Ground dash must travel the same 108 px")
	check(player.state == player.State.NORMAL and player.is_on_floor(), "Ground dash must end on the floor")
	await ticks(4)
	check(not player.is_invulnerable(), "I-frames must end shortly after the dash")
	Input.action_press("dash")
	await ticks(1)
	check(player.state == player.State.NORMAL and not player.can_dash(), "Ground dash cooldown must reject an immediate second dash")
	Input.action_release("dash")
	await ticks(16)
	check(player.can_dash(), "Ground dash must be ready again after its cooldown")
	Input.action_press("dash")
	await ticks(1)
	check(player.state == player.State.DASH, "Second ground dash must start after the cooldown")
	Input.action_release("dash")
	await ticks(30)
	Input.action_press("jump")
	await ticks(2)
	Input.action_release("jump")
	Input.action_press("dash")
	await ticks(1)
	check(player.state == player.State.DASH and not player.dash_available, "Air dash must still be available after ground dashes")

	await reset_player(Vector2(300, 200))
	player.velocity.y = player.movement_settings.jump_velocity
	var rising_y := player.position.y
	Input.action_press("dash")
	await ticks(1)
	check(is_equal_approx(player.velocity.y, player.movement_settings.jump_velocity + player.movement_settings.rise_gravity / 60.0), "Dash must preserve upward momentum with normal rise gravity")
	Input.action_release("dash")
	await ticks(8)
	check(player.position.y < rising_y and player.state == player.State.NORMAL, "Siya must keep rising throughout an early-jump dash")
	check(is_equal_approx(player.velocity.y, player.movement_settings.jump_velocity + player.movement_settings.rise_gravity * 9.0 / 60.0), "Ending a dash must preserve upward momentum")

	await reset_player(Vector2(300, 200))
	var start_x := player.position.x
	var falling_y := player.position.y
	var falling_speed := player.velocity.y
	Input.action_press("dash")
	await ticks(1)
	check(player.state == player.State.DASH and not player.dash_available, "Air dash must enter DASH and consume its charge")
	check(is_equal_approx(player.velocity.y, falling_speed + player.movement_settings.fall_gravity / 60.0), "Dash must preserve downward momentum with normal fall gravity")
	Input.action_release("dash")
	Input.action_press("move_left")
	await ticks(8)
	check(absf(player.position.x - start_x - 108.0) < 0.2, "Dash distance must be 108 px, independent of opposite input")
	check(player.state == player.State.NORMAL, "Dash must return to NORMAL after its duration")
	check(player.position.y > falling_y, "Siya must keep falling during a dash")
	check(is_equal_approx(player.velocity.y, falling_speed + player.movement_settings.fall_gravity * 9.0 / 60.0), "Ending a dash must preserve downward momentum")
	Input.action_release("move_left")
	Input.action_press("dash")
	await ticks(1)
	check(player.state == player.State.NORMAL and not player.dash_available, "Second air dash must be rejected")
	Input.action_release("dash")
	await ticks(40)
	check(player.is_on_floor() and player.dash_available, "Landing must restore the dash charge")
	check(player.velocity.y == 0.0, "Dash must return to normal gravity and eventually land")

	await reset_player(Vector2(300, 200))
	Input.action_press("move_left")
	await ticks(2)
	Input.action_release("move_left")
	start_x = player.position.x
	Input.action_press("dash")
	await ticks(9)
	check(absf(player.position.x - start_x + 108.0) < 0.2, "Left-facing dash must also travel 108 px")

	# Eight-pixel wall is narrower than a dash tick's 12 px displacement.
	await reset_player(Vector2(4080, 400))
	Input.action_press("dash")
	await ticks(9)
	check(player.position.x <= 4114.1 and player.position.x >= 4113.0, "Dash must stop at the thin wall without tunnelling")
	check(player.state == player.State.NORMAL, "Wall impact must end the dash")

	await reset_player(Vector2(1990, 430))
	Input.action_press("jump")
	await ticks(2)
	Input.action_press("dash")
	await ticks(9)
	check(player.position.y >= 410.0, "Dash under a low ceiling must respect the roof")

	for gap_start in [3335.0, 3735.0]:
		await reset_player(Vector2(gap_start, 430))
		var gap_scene := current_scene
		Input.action_press("move_right")
		await ticks(7)
		Input.action_press("jump")
		await ticks(20)
		Input.action_press("dash")
		await ticks(9)
		Input.action_release("dash")
		for frame in range(23):
			await ticks(1)
			if current_scene != gap_scene:
				break
		var cleared_gap := is_instance_valid(player) and current_scene == gap_scene
		if cleared_gap:
			cleared_gap = player.is_on_floor() and absf(player.position.y - 430.0) < 1.0
		check(cleared_gap, "Jump + dash must clear the %.0f px test gap" % (220.0 if gap_start == 3335.0 else 250.0))

	await reset_player(Vector2(300, 200))
	Input.action_press("dash")
	await ticks(1)
	player.apply_knockback(Vector2(-100, -100), 0.1)
	check(player.state == player.State.HURT, "Knockback must interrupt a dash")
	await ticks(7)
	check(player.state == player.State.NORMAL, "Hurt must recover to normal movement")

	# Fall recovery must reload once, including fresh state, camera, and enemy.
	await reset_player(Vector2(3440, 560))
	var old_scene := current_scene
	for frame in range(30):
		await ticks(1)
		if current_scene != old_scene:
			break
	check(current_scene != old_scene, "Falling below the boundary must restart the scene")
	player = current_scene.get_node("Player")
	await ticks(3)
	check(player.position.distance_to(Vector2(160, 430)) < 1.0 and player.dash_available, "Fall recovery must restore spawn and dash charge")
	check(current_scene.get_node("Camera2D").get_screen_center_position().x < 600.0, "Restart must reset the camera to the starting area")

	old_scene = current_scene
	Input.action_press("restart")
	# action_press does not dispatch _unhandled_input; send a real action event.
	var restart_event := InputEventAction.new()
	restart_event.action = "restart"
	restart_event.pressed = true
	Input.parse_input_event(restart_event)
	await ticks(3)
	check(current_scene != old_scene, "R action must reload the scene")
	release_inputs()
	if failures == 0:
		print("PASS: ground dash with cooldown and i-frames, air dash distance/direction, air charge, gravity, thin-wall/ceiling collision, both gaps, hurt interruption, fall and manual restart")
	quit(1 if failures > 0 else 0)
