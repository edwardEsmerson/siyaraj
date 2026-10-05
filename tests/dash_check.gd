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
	Input.action_press("dash")
	await ticks(1)
	check(player.state == player.State.NORMAL and player.dash_available, "Ground dash must be rejected without spending the air charge")
	check(absf(player.position.x - grounded_x) < 0.1, "Ground dash must not move Siya")
	Input.action_release("dash")
	Input.action_press("jump")
	await ticks(2)
	Input.action_release("jump")
	Input.action_press("dash")
	await ticks(1)
	check(player.state == player.State.DASH, "Dash must become available after jumping")

	await reset_player(Vector2(300, 200))
	var start_x := player.position.x
	Input.action_press("dash")
	await ticks(1)
	check(player.state == player.State.DASH and not player.dash_available, "Air dash must enter DASH and consume its charge")
	check(is_zero_approx(player.velocity.y), "Dash must suspend vertical motion")
	Input.action_release("dash")
	Input.action_press("move_left")
	await ticks(8)
	check(absf(player.position.x - start_x - 108.0) < 0.2, "Dash distance must be 108 px, independent of opposite input")
	check(player.state == player.State.NORMAL, "Dash must return to NORMAL after its duration")
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
		Input.action_press("move_right")
		await ticks(7)
		Input.action_press("jump")
		await ticks(20)
		Input.action_press("dash")
		await ticks(9)
		Input.action_release("dash")
		await ticks(23)
		print("Gap start=", gap_start, " landing=", player.position, " grounded=", player.is_on_floor())
		check(player.is_on_floor() and absf(player.position.y - 430.0) < 1.0, "Jump + dash must clear the %.0f px test gap" % (220.0 if gap_start == 3335.0 else 250.0))

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
		print("PASS: airborne-only dash, distance/direction, air charge, gravity, thin-wall/ceiling collision, both gaps, hurt interruption, fall and manual restart")
	quit(1 if failures > 0 else 0)
