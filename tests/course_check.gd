extends SceneTree
## Exercise the integrated course using real collisions, swings, and finish overlaps.

var failures: int = 0
var player: CharacterBody2D
var course: Node2D


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


func release_inputs() -> void:
	for action in [&"attack", &"dash", &"move_left", &"move_right", &"jump"]:
		Input.action_release(action)


func place_player(at: Vector2) -> void:
	release_inputs()
	player.position = at
	player.velocity = Vector2.ZERO
	player.state = player.State.NORMAL
	player.sparkler.cancel()
	await ticks(3)


func run_checks() -> void:
	change_scene_to_file("res://scenes/main/main.tscn")
	await scene_changed
	player = current_scene.get_node("Player")
	course = current_scene.get_node("TestCourse")
	var enemy: CharacterBody2D = course.get_node("Enemy")
	enemy.set_physics_process(false)
	# Guard/gate regression stays isolated from the independently tested flyer.
	course.get_node("FlyingEnemy").set_physics_process(false)
	course.get_node("Brute").set_physics_process(false)
	course.get_node("GroundShooter").set_physics_process(false)
	await ticks(3)
	check(player.is_on_floor(), "Combined course must spawn Siya on solid ground")
	check(current_scene.get_node("Camera2D").limit_right == 4800, "Camera must cover the finish platform")

	for start_x in [2625.0, 3065.0]:
		await place_player(Vector2(start_x, 430))
		Input.action_press("move_right")
		await ticks(7)
		Input.action_press("jump")
		# Dash keeps the jump arc, so it buys reach while rising, not by hovering late.
		await ticks(12)
		Input.action_press("dash")
		await ticks(2)
		check(not player.get_node("DashTrail").visible and player.get_node("DashTrail").samples.is_empty(), "Dashing must use the sprite without an extra trail")
		check(not player.get_node("DashExhaust").visible, "Dashing must not show the prototype exhaust")
		await ticks(7)
		Input.action_release("dash")
		await ticks(23)
		check(player.is_on_floor() and absf(player.position.y - 430) < 1, "Each new dash gap must be traversable with the existing controller")
		check(player.dash_available, "Landing between course gaps must restore the air dash")
		release_inputs()
		await ticks(12)
		check(player.get_node("DashTrail").samples.is_empty(), "Dash must not leave trail samples after it ends")

	await place_player(Vector2(4130, 400))
	Input.action_press("dash")
	await ticks(9)
	check(player.position.x <= 4174.1 and player.state == player.State.NORMAL, "Locked exit must block Siya without dash tunnelling")

	# Even teleporting around the gate cannot finish before defeating the guard.
	await place_player(Vector2(4600, 430))
	check(not course.completed and not current_scene.completed, "Finish must reject a player while the guard is alive")

	await place_player(Vector2(3722, 430))
	player.facing_direction = 1
	for swing_index in range(3):
		enemy.position = player.position + Vector2(48, 0)
		await ticks(1)
		Input.action_press("attack")
		await ticks(1)
		Input.action_release("attack")
		await ticks(40)
	check(not is_instance_valid(enemy) and course.guard_defeated, "Three real sparkler swings must defeat the guard and unlock the exit")
	check(course.get_node("ExitGate/CollisionShape2D").disabled, "Defeating the guard must remove the exit collision")
	check(player.state == player.State.NORMAL, "Successful combat must not leave Siya stuck in a movement state")

	await place_player(Vector2(4195, 430))
	Input.action_press("move_right")
	await ticks(7)
	Input.action_press("jump")
	await ticks(35)
	Input.action_release("jump")
	check(player.is_on_floor() and player.position.x > 4280, "Post-combat jump must reach the final platform")
	await ticks(75)
	release_inputs()
	check(course.completed and current_scene.completed, "Reaching the flag after combat must complete the course")
	check(current_scene.get_node("HUD/Completion").visible, "Completion must show the replay prompt")
	var finish_time: float = current_scene.elapsed
	await ticks(10)
	check(is_equal_approx(current_scene.elapsed, finish_time), "Completion must freeze the displayed time")
	var finished_x := player.position.x
	Input.action_press("move_left")
	await ticks(6)
	check(player.position.x < finished_x, "Finish feedback must leave movement responsive")
	release_inputs()

	var old_scene := current_scene
	var restart := InputEventAction.new()
	restart.action = "restart"
	restart.pressed = true
	Input.parse_input_event(restart)
	await ticks(3)
	check(current_scene != old_scene, "Manual replay must restart immediately")
	player = current_scene.get_node("Player")
	course = current_scene.get_node("TestCourse")
	check(not course.completed and not course.guard_defeated and player.health == 3, "Replay must reset health, guard, gate, and completion")
	check(course.get_node("FlyingEnemy").health == 3, "Replay must restore the flying enemy")
	check(course.get_node("Brute").health == 6, "Replay must restore the brute")

	old_scene = current_scene
	player.take_damage(3, Vector2.ZERO)
	await ticks(2)
	check(current_scene == old_scene and current_scene.get_node("HUD/DeathMessage").visible, "Death must briefly display its cue before restarting")
	await preload("res://tests/respawn_test_helpers.gd").wait_for_respawn(self)
	check(current_scene != old_scene, "Death cue must not prevent automatic restart")
	if failures == 0:
		print("PASS: combined course gaps, trail expiry, locked exit, real combat unlock, final jump, completion, responsive movement, replay and death cue")
	quit(1 if failures > 0 else 0)
