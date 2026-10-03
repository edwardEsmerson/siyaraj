extends SceneTree
## Integration checks against real collision geometry and physics ticks.

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


func reset_player(at: Vector2 = Vector2(160, 430)) -> void:
	for action in [&"move_left", &"move_right", &"jump"]:
		Input.action_release(action)
	var old: Node = current_scene.get_node("Player")
	old.free()
	player = load("res://scenes/player/player.tscn").instantiate()
	player.name = "Player"
	current_scene.add_child(player)
	current_scene.player = player
	player.position = at
	await ticks(3)


func jump_height(hold_ticks: int) -> float:
	await reset_player()
	var start_y := player.position.y
	var minimum_y := start_y
	Input.action_press("jump")
	for frame in range(60):
		if frame == hold_ticks:
			Input.action_release("jump")
		await ticks(1)
		minimum_y = minf(minimum_y, player.position.y)
	Input.action_release("jump")
	return start_y - minimum_y


func run_checks() -> void:
	change_scene_to_file("res://scenes/main/main.tscn")
	await scene_changed
	player = current_scene.get_node("Player")
	await ticks(3)
	check(player.is_on_floor(), "Player must spawn grounded")

	Input.action_press("move_right")
	await ticks(6)
	check(is_equal_approx(player.velocity.x, 240.0), "Running should reach configured speed in 0.1 seconds")
	Input.action_release("move_right")
	await ticks(5)
	check(is_zero_approx(player.velocity.x), "Releasing movement must stop the player")
	Input.action_press("move_left")
	await ticks(6)
	check(player.velocity.x < 0.0 and player.facing_direction == -1, "Turning must change velocity and facing")
	Input.action_release("move_left")

	var full_height := await jump_height(45)
	var tap_height := await jump_height(2)
	check(full_height > 75.0 and full_height < 90.0, "Full jump should clear the 40 px steps")
	check(tap_height < full_height * 0.60, "Tap jump must be clearly shorter than held jump")
	print("Jump heights: held=%.1f px, tap=%.1f px" % [full_height, tap_height])

	await reset_player(Vector2(300, 430))
	Input.action_press("jump")
	await ticks(45)
	check(player.is_on_floor(), "Held jump must land without automatically jumping again")
	Input.action_release("jump")

	# Walk off a real edge, then jump within the coyote window.
	await reset_player(Vector2(1254, 430))
	Input.action_press("move_right")
	var edge_ticks := 0
	while player.is_on_floor() and edge_ticks < 20:
		await ticks(1)
		edge_ticks += 1
	check(not player.is_on_floor(), "Coyote test must actually leave the ledge")
	await ticks(2)
	Input.action_press("jump")
	await ticks(1)
	check(player.velocity.y < -300.0, "Jump shortly after the edge must succeed")
	Input.action_release("jump")

	# Waiting too long after leaving the same edge must not allow an air jump.
	await reset_player(Vector2(1254, 430))
	Input.action_press("move_right")
	edge_ticks = 0
	while player.is_on_floor() and edge_ticks < 20:
		await ticks(1)
		edge_ticks += 1
	await ticks(7)
	Input.action_press("jump")
	await ticks(1)
	check(player.velocity.y >= 0.0, "Expired coyote time must not permit a jump")

	# Press shortly before landing and keep it held: landing consumes the buffer.
	await reset_player(Vector2(300, 380))
	var fall_ticks := 0
	while player.position.y < 408.0 and fall_ticks < 30:
		await ticks(1)
		fall_ticks += 1
	Input.action_press("jump")
	var bounced := false
	for frame in range(10):
		await ticks(1)
		if player.velocity.y < -300.0:
			bounced = true
			break
	check(bounced, "Jump pressed shortly before landing must launch on landing")

	# A released buffered press should produce a short jump rather than a full one.
	await reset_player(Vector2(300, 380))
	fall_ticks = 0
	while player.position.y < 408.0 and fall_ticks < 30:
		await ticks(1)
		fall_ticks += 1
	Input.action_press("jump")
	await ticks(1)
	Input.action_release("jump")
	bounced = false
	for frame in range(10):
		await ticks(1)
		if player.velocity.y < 0.0:
			bounced = true
			check(player.velocity.y > -250.0, "Released buffered press must shorten the jump")
			break
	check(bounced, "Releasing a buffered jump must not lose the buffered press")

	# A long-ago airborne press expires before landing.
	await reset_player(Vector2(300, 260))
	Input.action_press("jump")
	await ticks(1)
	Input.action_release("jump")
	await ticks(40)
	check(player.is_on_floor() and is_zero_approx(player.velocity.y), "Expired buffer must not jump on landing")

	# Jump into the low ceiling, land, then run into the first step's wall.
	await reset_player(Vector2(1990, 430))
	Input.action_press("jump")
	await ticks(20)
	check(player.position.y >= 410.0, "Ceiling collision must prevent passing through the roof")
	check(player.is_on_floor(), "Player must land after hitting the low ceiling")
	await reset_player(Vector2(580, 430))
	Input.action_press("move_right")
	await ticks(30)
	check(player.is_on_wall() and player.position.x <= 608.1, "Step wall must block running")

	# Verify actual course dimensions, not just the jump's height in empty space.
	await reset_player(Vector2(670, 390))
	Input.action_press("move_right")
	Input.action_press("jump")
	await ticks(40)
	check(player.is_on_floor() and absf(player.position.y - 350.0) < 1.0, "Held jump must climb the next 40 px step")
	await reset_player(Vector2(1240, 430))
	Input.action_press("move_right")
	Input.action_press("jump")
	await ticks(43)
	check(player.is_on_floor() and absf(player.position.y - 430.0) < 1.0 and player.position.x > 1330.0, "Player must clear the 70 px gap")
	await reset_player(Vector2(1460, 430))
	Input.action_press("move_right")
	Input.action_press("jump")
	await ticks(43)
	check(player.is_on_floor() and absf(player.position.y - 430.0) < 1.0 and player.position.x > 1600.0, "Player must clear the 120 px gap")

	for action in [&"move_left", &"move_right", &"jump"]:
		Input.action_release(action)
	change_scene_to_file("res://scenes/enemies/enemy_test.tscn")
	await scene_changed
	var enemy: CharacterBody2D = current_scene.get_node("Enemy")
	await ticks(110)
	check(enemy.velocity.x < 0.0, "Enemy must reverse at the end of its patrol")
	enemy.take_damage(1, Vector2(120, -100))
	check(enemy.health == 2 and enemy.velocity.y == -100.0, "Enemy damage must apply health loss and knockback")
	enemy.take_damage(1, Vector2.ZERO)
	enemy.take_damage(1, Vector2.ZERO)
	await ticks(1)
	check(not is_instance_valid(enemy), "Enemy must disappear when health reaches zero")

	if failures == 0:
		print("PASS: running, turning, jump heights, coyote/buffer windows, collisions and enemy damage")
	quit(1 if failures > 0 else 0)
