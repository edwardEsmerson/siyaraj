extends SceneTree
## Real flight, aimed shots, swept collisions, jumping melee, and scene recovery.
const Sandbox = preload("res://scripts/dev/sandbox.gd")
const PROJECTILE_SCENE = preload("res://scenes/combat/enemy_projectile.tscn")

var failures: int = 0
var player: CharacterBody2D
var flyer: CharacterBody2D


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


func reset_arena(freeze_flyer: bool = true) -> void:
	release_inputs()
	Sandbox.next_encounter = Sandbox.Encounter.FLYER
	change_scene_to_file("res://scenes/dev/sandbox.tscn")
	await scene_changed
	player = current_scene.get_node("Player")
	flyer = current_scene.get_node("Enemy")
	flyer.set_physics_process(not freeze_flyer)
	await ticks(3)


func shots() -> Array[Node]:
	return get_nodes_in_group("enemy_projectiles")


func wait_for_shots(count: int, max_ticks: int = 120) -> void:
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


func spawn_shot(at: Vector2, direction: Vector2, speed: float = 12000.0, lifetime: float = 3.0) -> CharacterBody2D:
	var projectile := PROJECTILE_SCENE.instantiate() as CharacterBody2D
	projectile.direction = direction
	projectile.speed = speed
	projectile.lifetime = lifetime
	projectile.knockback = Vector2.ZERO
	current_scene.add_child(projectile)
	projectile.global_position = at
	return projectile


func check_patrol() -> void:
	await reset_arena()
	flyer.detection_range = 0.0
	flyer.set_physics_process(true)
	var minimum_x := flyer.position.x
	var maximum_x := flyer.position.x
	var constant_height := true
	for frame in range(300):
		await ticks(1)
		minimum_x = minf(minimum_x, flyer.position.x)
		maximum_x = maxf(maximum_x, flyer.position.x)
		constant_height = constant_height and is_equal_approx(flyer.position.y, 385.0)
	check(minimum_x <= 411.1 and maximum_x >= 589.0, "Flyer must patrol to both sides of its spawn")
	check(minimum_x >= 409.9 and maximum_x <= 590.1, "Flyer must reverse within its patrol bounds")
	check(constant_height and is_zero_approx(flyer.velocity.y), "Flight must keep a constant altitude without gravity")
	check(shots().is_empty(), "Flyer must not fire at an out-of-range player")

	await reset_arena()
	flyer.detection_range = 0.0
	add_wall(Vector2(560, 365), Vector2(8, 100))
	flyer.set_physics_process(true)
	await ticks(55)
	check(flyer.position.x < 540.0 and flyer.velocity.x < 0.0, "Flyer must reverse at a solid wall instead of passing through it")
	check(is_equal_approx(flyer.position.y, 385.0), "Wall collision must preserve flight altitude")


func check_shooting() -> void:
	await reset_arena()
	player.set_physics_process(false)
	flyer.set_physics_process(true)
	await ticks(1)
	check(flyer.state == flyer.State.CHARGING and shots().is_empty(), "Visible charge must precede each projectile")
	var charging_x := flyer.position.x
	var expected_direction: Vector2 = (player.global_position + Vector2(0, -20) - flyer.get_node("ShotOrigin").global_position).normalized()
	player.position.x = 700.0
	await ticks(10)
	check(flyer.position.x > charging_x + 8.0 and flyer.state == flyer.State.CHARGING, "Patrol must continue while charging")
	check(player.health == 3 and shots().is_empty(), "The charge itself must not damage the player")
	await wait_for_shots(1)
	check(shots().size() == 1 and flyer.state == flyer.State.RECOVERY, "A charge must fire one shot and enter recovery")
	if shots().is_empty():
		return
	var projectile: CharacterBody2D = shots()[0]
	check(projectile.direction.dot(expected_direction) > 0.9999, "Shot must retain the aim captured at charge start")
	var fired_at := flyer.position.x
	await ticks(10)
	check(projectile.direction.dot(expected_direction) > 0.9999 and player.health == 3, "Moving away from locked aim must dodge a non-homing shot")
	check(flyer.position.x > fired_at + 8.0, "Flyer must keep patrolling during recovery")
	projectile.set_physics_process(false)
	await ticks(50)
	check(shots().size() == 1 and flyer.state == flyer.State.RECOVERY, "Recovery must prevent rapid repeated shots")
	await wait_for_shots(2)
	check(shots().size() == 2, "Flyer must recharge and shoot again after recovery")

	await reset_arena()
	add_wall(Vector2(420, 365), Vector2(8, 130))
	flyer.set_physics_process(true)
	await ticks(40)
	check(shots().is_empty() and flyer.state == flyer.State.PATROL, "World geometry must block detection and shooting")

	await reset_arena(false)
	check(flyer.state == flyer.State.CHARGING, "Interruption test must begin during charge")
	add_wall(Vector2(420, 365), Vector2(8, 130))
	await ticks(30)
	check(shots().is_empty() and flyer.state == flyer.State.RECOVERY, "Losing line of sight must cancel a pending shot")

	await reset_arena(false)
	player.position.x = 850.0
	await ticks(30)
	check(shots().is_empty(), "Leaving detection range must cancel a pending shot")

	await reset_arena(false)
	player.remove_from_group("players")
	await ticks(35)
	check(shots().is_empty(), "Losing the player reference must safely cancel shooting")

	await reset_arena()
	player.health = 0
	flyer.set_physics_process(true)
	await ticks(35)
	check(shots().is_empty(), "Flyer must not target a dead player")

	await reset_arena(false)
	var before_x := flyer.position.x
	var health_events: Array[int] = []
	flyer.health_changed.connect(func(remaining: int) -> void: health_events.append(remaining))
	flyer.take_damage(1, Vector2(180, -200))
	await ticks(6)
	check(flyer.health == 2 and health_events == [2] and flyer.state == flyer.State.HURT, "Damage must update health, signal it, and interrupt charging")
	check(flyer.position.x > before_x and is_equal_approx(flyer.position.y, 385.0), "Knockback must move the flyer horizontally without changing altitude")
	await ticks(24)
	check(shots().is_empty(), "Interrupted charge must not fire at its old deadline")

	await reset_arena(false)
	await wait_for_shots(1)
	check(not shots().is_empty(), "Stationary player test must receive a fired shot")
	if not shots().is_empty():
		projectile = shots()[0]
		var before := projectile.position
		var death_event := {"received": false}
		flyer.died.connect(func() -> void: death_event.received = true)
		flyer.take_damage(3, Vector2.ZERO)
		await ticks(2)
		check(not is_instance_valid(flyer) and death_event.received, "Lethal damage must remove the flyer and emit died")
		check(is_instance_valid(projectile) and projectile.position != before, "Shots in flight must survive their shooter's death")
		for frame in range(65):
			if player.health < 3:
				break
			await ticks(1)
		check(player.health == 2 and not is_instance_valid(projectile), "A fired aimed projectile must hit a stationary player once")
		check(player.state == player.State.HURT and player.velocity.x < 0.0, "Projectile knockback must use the player's hurt controller")


func check_projectiles() -> void:
	await reset_arena()
	var projectile := spawn_shot(Vector2(100, 410), Vector2.RIGHT)
	await ticks(3)
	check(player.health == 2 and not is_instance_valid(projectile), "Fast projectile must sweep into the player and be consumed")
	projectile = spawn_shot(player.global_position + Vector2(-30, -20), Vector2.RIGHT)
	await ticks(2)
	check(player.health == 2 and not is_instance_valid(projectile), "Protected player must consume the shot without losing more health")
	await ticks(50)
	spawn_shot(player.global_position + Vector2(-30, -20), Vector2.RIGHT)
	await ticks(3)
	check(player.health == 1, "Projectiles must damage again after existing player protection expires")
	await ticks(50)
	check(player.health == 1, "Consumed projectiles must not deal repeated damage")

	await reset_arena()
	add_wall(Vector2(280, 410), Vector2(2, 80))
	projectile = spawn_shot(Vector2(100, 410), Vector2.RIGHT)
	await ticks(3)
	check(player.health == 3 and not is_instance_valid(projectile), "Swept shot must hit a thin wall before the player")

	await reset_arena()
	projectile = spawn_shot(Vector2(100, 400), Vector2.DOWN)
	await ticks(2)
	check(not is_instance_valid(projectile), "Projectiles must be consumed by solid floors")
	projectile = spawn_shot(Vector2(100, 100), Vector2.RIGHT, 220.0, 0.10)
	await ticks(9)
	check(not is_instance_valid(projectile) and shots().is_empty(), "Unobstructed projectiles must expire at their lifetime")

	# A dashing player passes through an incoming shot, which flies on and ignores her.
	await reset_arena()
	projectile = spawn_shot(player.global_position + Vector2(70, -20), Vector2.LEFT, 400.0)
	Input.action_press("dash")
	await ticks(1)
	Input.action_release("dash")
	check(player.state == player.State.DASH, "Shot dodge must start a grounded dash")
	await ticks(12)
	check(player.health == 3, "Dash i-frames must let a shot pass through without damage")
	check(is_instance_valid(projectile) and projectile.global_position.x < player.global_position.x, "Dodged shot must continue past the player")
	await ticks(20)
	check(player.health == 3, "Dodged shot must not hit the player after i-frames end")


func check_melee_and_restart() -> void:
	await reset_arena()
	flyer.position = Vector2(388, 385)
	Input.action_press("attack")
	await ticks(1)
	Input.action_release("attack")
	await ticks(40)
	check(flyer.health == 3, "Flyer altitude must require a jumping sparkler attack")
	for swing_index in range(3):
		player.position = Vector2(340, 430)
		player.velocity = Vector2.ZERO
		await ticks(3)
		Input.action_press("jump")
		await ticks(8)
		Input.action_release("jump")
		Input.action_press("attack")
		await ticks(1)
		Input.action_release("attack")
		await ticks(12)
		if swing_index < 2:
			check(is_instance_valid(flyer) and flyer.health == 2 - swing_index, "Each jumping sparkler swing must damage the flyer exactly once")
		await ticks(28)
	check(not is_instance_valid(flyer), "Three real jumping swings must defeat the flyer")
	check(current_scene.get_node("HUD/CombatStatus").text.contains("defeated"), "Flyer defeat must update arena feedback")

	var old_scene := current_scene
	var restart := InputEventAction.new()
	restart.action = "restart"
	restart.pressed = true
	Input.parse_input_event(restart)
	await ticks(3)
	check(current_scene != old_scene, "R must restart the flying enemy arena")
	player = current_scene.get_node("Player")
	flyer = current_scene.get_node("Enemy")
	check(player.health == 3 and flyer.health == 3 and shots().is_empty(), "Restart must restore both combatants and clear projectiles")
	flyer.set_physics_process(false)
	old_scene = current_scene
	player.take_damage(3, Vector2.ZERO)
	await ticks(3)
	check(current_scene != old_scene, "Lethal player damage must restart the flying encounter")


func check_course_integration() -> void:
	release_inputs()
	change_scene_to_file("res://scenes/main/main.tscn")
	await scene_changed
	var course: Node2D = current_scene.get_node("TestCourse")
	player = current_scene.get_node("Player")
	flyer = course.get_node("FlyingEnemy")
	var guard: CharacterBody2D = course.get_node("Enemy")
	guard.set_physics_process(false)
	course.get_node("GroundShooter").set_physics_process(false)
	check(flyer.position == Vector2(3500, 385), "Main course must place a flyer within jumping melee reach")
	check(course.hint_at(3500).contains("Flyer"), "Main course must explain the new encounter")
	player.position = Vector2(3360, 430)
	await wait_for_shots(1)
	check(not shots().is_empty(), "Main-course flyer must detect and shoot the player")
	flyer.take_damage(3, Vector2.ZERO)
	await ticks(1)
	check(not course.guard_defeated and not course.get_node("ExitGate/CollisionShape2D").disabled, "Flyer defeat must leave the guard-controlled gate locked")
	guard.take_damage(3, Vector2.ZERO)
	await ticks(2)
	check(course.guard_defeated and course.get_node("ExitGate/CollisionShape2D").disabled, "Guard defeat must still unlock the exit")


func run_checks() -> void:
	await check_patrol()
	await check_shooting()
	await check_projectiles()
	await check_melee_and_restart()
	await check_course_integration()
	release_inputs()
	if failures == 0:
		print("PASS: flying patrol, altitude, walls, aimed charge, cooldown, interruption, swept projectiles, protection, jumping melee, restart and course integration")
	quit(1 if failures > 0 else 0)
