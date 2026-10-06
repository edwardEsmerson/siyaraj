extends SceneTree
## Exercise the heavy melee variant through real physics, timed hits and scene reloads.

var failures: int = 0
var player: CharacterBody2D
var brute: CharacterBody2D


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


func reset_arena(freeze_brute: bool = true) -> void:
	release_inputs()
	change_scene_to_file("res://scenes/combat/brute_arena.tscn")
	await scene_changed
	player = current_scene.get_node("Player")
	brute = current_scene.get_node("TestCourse/Enemy")
	brute.set_physics_process(not freeze_brute)
	await ticks(3)


func check_variant_and_movement() -> void:
	await reset_arena()
	var guard := preload("res://scenes/enemies/enemy.tscn").instantiate()
	var brute_size: Vector2 = brute.get_node("CollisionShape2D").shape.size
	var guard_size: Vector2 = guard.get_node("CollisionShape2D").shape.size
	check(brute_size.x > guard_size.x and brute_size.y > guard_size.y, "Brute must be physically wider and taller than a guard")
	check(brute.health == 6 and brute.max_health > guard.max_health, "Brute must have more health than a guard")
	check(brute.chase_speed < guard.chase_speed and brute.patrol_speed < guard.patrol_speed, "Brute must move more slowly than a guard")
	check(brute.attack.damage == 2, "Brute must deal two damage per heavy strike")
	check(brute.get_node("Name").text.begins_with("Brute 6/6"), "Brute must identify itself with ordinary enemy feedback")
	guard.free()

	player.position.x = 100.0
	brute.set_physics_process(true)
	var min_x := brute.position.x
	var max_x := brute.position.x
	for frame in range(240):
		await ticks(1)
		min_x = minf(min_x, brute.position.x)
		max_x = maxf(max_x, brute.position.x)
	check(brute.state == brute.State.PATROL and min_x < 490 and max_x > 550, "Brute must patrol and reverse around its spawn")
	check(min_x >= 434 and max_x <= 566 and brute.is_on_floor(), "Brute patrol must remain bounded and grounded")

	# Chase beyond a platform edge without allowing the larger body to walk off.
	player.set_physics_process(false)
	player.position = Vector2(1000, 430)
	brute.position = Vector2(885, 430)
	brute.velocity = Vector2.ZERO
	await ticks(90)
	check(brute.position.x <= 890 and brute.is_on_floor(), "Brute must stop at unsupported edges using a probe ahead of its wider collider")

	await reset_arena(false)
	player.set_physics_process(false)
	player.position = Vector2(700, 430)
	brute.position = Vector2(550, 430)
	var wall := StaticBody2D.new()
	wall.position = Vector2(600, 330)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 200)
	collider.shape = shape
	wall.add_child(collider)
	current_scene.add_child(wall)
	await ticks(90)
	check(brute.position.x <= 564.1 and brute.is_on_wall(), "Brute must collide with solid walls while chasing")


func check_heavy_swing() -> void:
	await reset_arena(false)
	var approached := false
	var reached_windup := false
	for frame in range(150):
		await ticks(1)
		approached = approached or brute.state == brute.State.CHASE
		if brute.attack.phase == brute.attack.Phase.WINDUP:
			reached_windup = true
			break
	check(approached and reached_windup and player.health == 3, "Brute must approach and telegraph its strike before dealing damage")
	check(brute.get_node("Name").text.contains("WIND-UP!"), "Heavy wind-up must use readable combat feedback")
	brute.set_physics_process(false)
	player.position.x = brute.position.x - 200.0
	await ticks(54)
	check(player.health == 3 and brute.attack.phase == brute.attack.Phase.RECOVERY, "Stepping out during the long wind-up must dodge the strike and leave a recovery window")

	await reset_arena()
	player.set_physics_process(false)
	player.damage_protection_time = 0.0
	player.position = brute.position + Vector2(80, 0)
	await ticks(1)
	brute.attack.start(1)
	await ticks(30)
	check(player.health == 3 and brute.attack.phase == brute.attack.Phase.WINDUP, "Heavy strike must not damage during its longer wind-up")
	await ticks(15)
	check(player.health == 1 and player.state == player.State.HURT, "Wider strike must hit at 80 pixels and request knockback through the player controller")
	check(player.velocity == Vector2(300, -180), "Heavy strike must apply its stronger knockback")
	await ticks(9)
	check(player.health == 1 and brute.attack.phase == brute.attack.Phase.RECOVERY, "Heavy strike must hit only once per swing even without player protection")
	await ticks(30)
	check(brute.attack.phase == brute.attack.Phase.RECOVERY, "Brute must remain vulnerable throughout its long recovery")

	await reset_arena()
	player.set_physics_process(false)
	player.position = brute.position + Vector2(-60, 0)
	await ticks(1)
	brute.attack.start(1)
	await ticks(54)
	check(player.health == 3, "Heavy swing must not hit a player behind its locked facing")
	brute.attack.cancel()
	brute.attack.start(-1)
	await ticks(54)
	check(player.health == 1, "Heavy swing must hit to the left when facing left")

	await reset_arena()
	player.set_physics_process(false)
	player.position = brute.position + Vector2(112, 0)
	await ticks(1)
	brute.attack.start(1)
	await ticks(54)
	check(player.health == 3, "Heavy swing must respect its finite melee reach")


func check_damage_and_defeat() -> void:
	await reset_arena()
	var health_events: Array[int] = []
	brute.health_changed.connect(func(remaining: int) -> void: health_events.append(remaining))
	brute.attack.start(-1)
	brute.take_damage(1, Vector2(180, -140))
	check(brute.health == 5 and brute.state == brute.State.HURT and not brute.attack.is_busy(), "Player damage must interrupt the brute's wind-up")
	check(brute.velocity.is_equal_approx(Vector2(99, -77)), "Brute must resist knockback while still reacting to damage")
	check(health_events == [5], "Brute must emit the shared health signal")
	brute.attack.start(1)
	await ticks(44)
	brute.take_damage(1, Vector2.ZERO)
	check(brute.health == 4 and not brute.attack.is_busy(), "Damage must also cancel a heavy strike during its active window")

	await reset_arena()
	player.facing_direction = 1
	for swing_index in range(6):
		brute.position = player.position + Vector2(48, 0)
		await ticks(1)
		Input.action_press("attack")
		await ticks(1)
		Input.action_release("attack")
		await ticks(40)
		if swing_index < 5:
			check(is_instance_valid(brute) and brute.health == 5 - swing_index, "Each real sparkler swing must remove exactly one of the brute's six health")
	check(not is_instance_valid(brute), "Six sparkler swings must defeat the brute as an ordinary enemy")
	check(current_scene.get_node("HUD/CombatStatus").text.contains("Brute defeated"), "Isolated arena must name the defeated brute correctly")
	var old_scene := current_scene
	var restart := InputEventAction.new()
	restart.action = "restart"
	restart.pressed = true
	Input.parse_input_event(restart)
	await ticks(3)
	check(current_scene != old_scene and current_scene.get_node("TestCourse/Enemy").health == 6, "Restart must restore the brute encounter")


func check_course_integration() -> void:
	release_inputs()
	change_scene_to_file("res://scenes/main/main.tscn")
	await scene_changed
	var course: Node2D = current_scene.get_node("TestCourse")
	brute = course.get_node("Brute")
	check(brute.position == Vector2(4020, 430) and brute.health == 6, "Main course must include the new brute after the regular guard")
	check(course.hint_at(3900).contains("Brute"), "Course must explain how to fight the brute")
	brute.take_damage(6, Vector2.ZERO)
	await ticks(2)
	check(not is_instance_valid(brute) and not course.guard_defeated and not course.get_node("ExitGate/CollisionShape2D").disabled, "Brute defeat must preserve the regular guard's gate ownership")
	course.get_node("Enemy").take_damage(3, Vector2.ZERO)
	await ticks(2)
	check(course.guard_defeated and course.get_node("ExitGate/CollisionShape2D").disabled, "Regular guard defeat must still unlock the exit")


func run_checks() -> void:
	await check_variant_and_movement()
	await check_heavy_swing()
	await check_damage_and_defeat()
	await check_course_integration()
	release_inputs()
	if failures == 0:
		print("PASS: brute size, strength, patrol, edges, walls, chase, tells, dodge, reach, facing, one hit per swing, interruption, resistance, defeat, restart and course integration")
	quit(1 if failures > 0 else 0)
