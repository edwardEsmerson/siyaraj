extends SceneTree
## Real ground physics, interrupted charges, steering, impacts and scene recovery.
const PROJECTILE_SCENE = preload("res://scenes/combat/homing_projectile.tscn")

var failures: int = 0
var player: CharacterBody2D
var shooter: CharacterBody2D


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


func reset_arena(freeze_shooter: bool = true) -> void:
	release_inputs()
	change_scene_to_file("res://scenes/combat/ground_shooter_arena.tscn")
	await scene_changed
	player = current_scene.get_node("Player")
	shooter = current_scene.get_node("GroundShooter")
	shooter.set_physics_process(not freeze_shooter)
	await ticks(3)


func shots() -> Array[Node]:
	return get_nodes_in_group("homing_projectiles")


func wait_for_shots(count: int, max_ticks: int = 150) -> void:
	for frame in range(max_ticks):
		if shots().size() >= count:
			return
		await ticks(1)


func add_wall(at: Vector2, size: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	wall.add_child(collider)
	current_scene.add_child(wall)
	wall.global_position = at
	return wall


func spawn_shot(at: Vector2, direction: Vector2, speed: float = 170.0, lifetime: float = 2.8) -> CharacterBody2D:
	var projectile := PROJECTILE_SCENE.instantiate() as CharacterBody2D
	projectile.direction = direction
	projectile.target = player
	projectile.speed = speed
	projectile.lifetime = lifetime
	projectile.knockback = Vector2.ZERO
	current_scene.add_child(projectile)
	projectile.global_position = at
	return projectile


func check_ground_patrol() -> void:
	await reset_arena()
	shooter.detection_range = 0.0
	shooter.position.y = 300.0
	shooter.set_physics_process(true)
	await ticks(30)
	check(shooter.is_on_floor() and absf(shooter.position.y - 430.0) < 0.1, "Shooter must fall under gravity and land on the floor")
	var minimum_x := shooter.position.x
	var maximum_x := shooter.position.x
	for frame in range(400):
		await ticks(1)
		minimum_x = minf(minimum_x, shooter.position.x)
		maximum_x = maxf(maximum_x, shooter.position.x)
	check(minimum_x >= 469.9 and minimum_x <= 471.0 and maximum_x >= 609.0 and maximum_x <= 610.1, "Ground patrol must reverse at both spawn bounds")
	check(shots().is_empty(), "Out-of-range players must not trigger shots")

	await reset_arena()
	shooter.detection_range = 0.0
	add_wall(Vector2(590, 400), Vector2(8, 100))
	shooter.set_physics_process(true)
	await ticks(65)
	check(shooter.position.x < 568.0 and shooter.velocity.x < 0.0, "Ground shooter must reverse at solid walls")

	await reset_arena()
	player.set_physics_process(false)
	shooter.detection_range = 0.0
	shooter.patrol_radius = 200.0
	var ground: StaticBody2D = current_scene.get_node("Ground")
	ground.position.x = 540.0
	var platform := RectangleShape2D.new()
	platform.size = Vector2(160, 48)
	ground.get_node("CollisionShape2D").shape = platform
	shooter.set_physics_process(true)
	var safe := true
	for frame in range(240):
		await ticks(1)
		safe = safe and shooter.position.x >= 483.0 and shooter.position.x <= 597.0 and shooter.position.y < 431.0
	check(safe, "Ground shooter must reverse before unsupported platform edges")


func check_charge() -> void:
	await reset_arena(false)
	player.set_physics_process(false)
	check(shooter.state == shooter.State.CHARGING and shots().is_empty(), "Grounded shooter must visibly charge before firing")
	var charging_x := shooter.position.x
	await ticks(20)
	check(is_equal_approx(shooter.position.x, charging_x) and shots().is_empty(), "Shooter must stop moving during its charge")
	await wait_for_shots(1)
	check(shots().size() == 1 and shooter.state == shooter.State.RECOVERY, "Charge must fire one homing shot and enter recovery")
	if not shots().is_empty():
		var projectile: CharacterBody2D = shots()[0]
		check(projectile.target == player, "Fired homing bolt must track the player")
		projectile.set_physics_process(false)
	var fired_x := shooter.position.x
	await ticks(70)
	check(shots().size() == 1 and shooter.state == shooter.State.RECOVERY and shooter.position.x != fired_x, "Reload must prevent rapid fire while allowing patrol")
	await wait_for_shots(2)
	check(shots().size() == 2, "Shooter must recharge after recovery")

	await reset_arena()
	add_wall(Vector2(440, 400), Vector2(8, 120))
	shooter.set_physics_process(true)
	await ticks(50)
	check(shots().is_empty() and shooter.state == shooter.State.PATROL, "World geometry must block detection")

	await reset_arena(false)
	add_wall(Vector2(440, 400), Vector2(8, 120))
	await ticks(45)
	check(shots().is_empty() and shooter.state == shooter.State.RECOVERY, "Lost line of sight must cancel charging")

	await reset_arena(false)
	player.position.x = 100.0
	await ticks(45)
	check(shots().is_empty(), "Leaving detection range must cancel charging")

	await reset_arena(false)
	player.remove_from_group("players")
	await ticks(45)
	check(shots().is_empty(), "Missing player must safely cancel charging")

	await reset_arena()
	player.health = 0
	shooter.set_physics_process(true)
	await ticks(45)
	check(shots().is_empty(), "Shooter must not target dead players")

	await reset_arena(false)
	var health_events: Array[int] = []
	shooter.health_changed.connect(func(remaining: int) -> void: health_events.append(remaining))
	shooter.take_damage(1, Vector2(150, -180))
	await ticks(5)
	check(shooter.state == shooter.State.HURT and shooter.health == 2 and health_events == [2], "Damage must signal health and interrupt charge")
	check(shooter.position.y < 430.0, "Ground shooter must accept vertical knockback")
	await ticks(25)
	check(shots().is_empty(), "Interrupted charge must not fire at its original deadline")


func check_homing_and_impacts() -> void:
	await reset_arena()
	player.set_physics_process(false)
	player.position = Vector2(340, 220)
	var projectile := spawn_shot(Vector2(100, 100), Vector2.RIGHT)
	var previous := Vector2.RIGHT
	var bounded := true
	for frame in range(12):
		await ticks(1)
		bounded = bounded and absf(previous.angle_to(projectile.direction)) <= projectile.turn_speed / 60.0 + 0.0001
		previous = projectile.direction
	check(projectile.direction.y > 0.2 and projectile.position.y > 100.0 and bounded, "Homing must curve toward the target with bounded steering")
	player.position = Vector2(340, 50)
	await ticks(12)
	check(projectile.direction.y < 0.0, "Homing must follow a moving target after launch")

	await reset_arena()
	player.set_physics_process(false)
	projectile = spawn_shot(Vector2(300, 200), Vector2.RIGHT)
	player.position = Vector2(100, 220)
	await ticks(5)
	check(projectile.direction.x > 0.95 and player.health == 3, "A bolt must not instantly reverse when the player dodges past it")
	var heading: Vector2 = projectile.direction
	player.health = 0
	await ticks(5)
	check(projectile.direction.dot(heading) > 0.9999, "Dead target must stop homing without stopping flight")
	var deleted_target := CharacterBody2D.new()
	projectile.target = deleted_target
	deleted_target.free()
	await ticks(5)
	check(is_instance_valid(projectile) and projectile.direction.dot(heading) > 0.9999, "Deleted targets must safely leave bolts flying straight")

	await reset_arena()
	projectile = spawn_shot(Vector2(100, 410), Vector2.RIGHT, 12000.0)
	await ticks(3)
	check(player.health == 2 and not is_instance_valid(projectile), "Fast homing bolt must sweep into the player exactly once")
	projectile = spawn_shot(player.global_position + Vector2(-30, -20), Vector2.RIGHT, 12000.0)
	await ticks(3)
	check(player.health == 2 and not is_instance_valid(projectile), "Protected player must consume homing bolts without further damage")
	await ticks(50)
	spawn_shot(player.global_position + Vector2(-30, -20), Vector2.RIGHT, 12000.0)
	await ticks(3)
	check(player.health == 1, "Homing damage must resume after protection expires")

	await reset_arena()
	add_wall(Vector2(280, 410), Vector2(2, 80))
	projectile = spawn_shot(Vector2(100, 410), Vector2.RIGHT, 12000.0)
	await ticks(3)
	check(player.health == 3 and not is_instance_valid(projectile), "Thin walls must stop homing projectiles before the player")
	projectile = spawn_shot(Vector2(100, 400), Vector2.DOWN, 12000.0)
	projectile.turn_speed = 0.0
	await ticks(2)
	check(not is_instance_valid(projectile), "Solid floors must consume homing bolts")
	projectile = spawn_shot(Vector2(100, 100), Vector2.RIGHT, 170.0, 0.1)
	await ticks(9)
	check(not is_instance_valid(projectile) and shots().is_empty(), "Homing bolts must expire instead of pursuing forever")


func check_combat_and_restart() -> void:
	await reset_arena()
	shooter.position.x = player.position.x + 48.0
	for swing_index in range(3):
		Input.action_press("attack")
		await ticks(1)
		Input.action_release("attack")
		await ticks(40)
		if swing_index < 2:
			check(shooter.health == 2 - swing_index, "Each grounded sparkler swing must hit the shooter once")
	check(not is_instance_valid(shooter) and current_scene.get_node("HUD/CombatStatus").text.contains("defeated"), "Three real melee swings must defeat the shooter and update feedback")

	await reset_arena(false)
	await wait_for_shots(1)
	if not shots().is_empty():
		var projectile: CharacterBody2D = shots()[0]
		var death_event := {"received": false}
		shooter.died.connect(func() -> void: death_event.received = true)
		shooter.take_damage(3, Vector2.ZERO)
		await ticks(2)
		check(not is_instance_valid(shooter) and death_event.received and is_instance_valid(projectile), "Defeat must emit died and leave existing homing bolts alive")
		await ticks(75)
		check(player.health == 2 and not is_instance_valid(projectile), "A homing bolt must still hit once after its shooter dies")
	var old_scene := current_scene
	var restart := InputEventAction.new()
	restart.action = "restart"
	restart.pressed = true
	Input.parse_input_event(restart)
	await ticks(3)
	check(current_scene != old_scene and shots().is_empty(), "R must restart the arena and clear all bolts")
	player = current_scene.get_node("Player")
	shooter = current_scene.get_node("GroundShooter")
	check(player.health == 3 and shooter.health == 3, "Restart must restore both combatants")
	shooter.set_physics_process(false)
	old_scene = current_scene
	player.take_damage(3, Vector2.ZERO)
	await ticks(3)
	check(current_scene != old_scene, "Lethal player damage must restart the ground encounter")


func check_course_integration() -> void:
	release_inputs()
	change_scene_to_file("res://scenes/main/main.tscn")
	await scene_changed
	var course: Node2D = current_scene.get_node("TestCourse")
	player = current_scene.get_node("Player")
	shooter = course.get_node("GroundShooter")
	course.get_node("FlyingEnemy").set_physics_process(false)
	var guard: CharacterBody2D = course.get_node("Enemy")
	guard.set_physics_process(false)
	check(shooter.position == Vector2(3970, 430), "Main course must include the ground shooter")
	player.position = Vector2(3910, 430)
	await wait_for_shots(1)
	check(not shots().is_empty(), "Main-course shooter must fire homing bolts")
	shooter.take_damage(3, Vector2.ZERO)
	await ticks(1)
	check(not course.guard_defeated and not course.get_node("ExitGate/CollisionShape2D").disabled, "Ground shooter defeat must leave the guard-controlled gate locked")
	guard.take_damage(3, Vector2.ZERO)
	await ticks(2)
	check(course.guard_defeated and course.get_node("ExitGate/CollisionShape2D").disabled, "Guard must still control the exit")


func run_checks() -> void:
	await check_ground_patrol()
	await check_charge()
	await check_homing_and_impacts()
	await check_combat_and_restart()
	await check_course_integration()
	release_inputs()
	if failures == 0:
		print("PASS: ground patrol, gravity, walls/ledges, charge/reload, interruption, homing steering, target loss, swept impacts, protection, melee, restart and course integration")
	quit(1 if failures > 0 else 0)
