extends SceneTree
## Boss 1 (Khara): ladi direction and timing, gada slam, shockwave, phases,
## health bar and defeat, using real physics in the isolated boss arena.

var failures: int = 0
var player: CharacterBody2D
var boss: CharacterBody2D
var bar: Control


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
	for action in [&"attack", &"dash", &"move_left", &"move_right", &"jump", &"skyshot", &"special"]:
		Input.action_release(action)


func reset_arena(freeze_boss: bool = true) -> void:
	release_inputs()
	change_scene_to_file("res://scenes/bosses/khara_arena.tscn")
	await scene_changed
	player = current_scene.get_node("Player")
	boss = current_scene.get_node("TestCourse/Boss")
	bar = current_scene.get_node("HUD/BossHealthBar")
	boss.set_physics_process(not freeze_boss)
	await ticks(3)


func ladis() -> Array[Node]:
	return get_nodes_in_group("boss_ladis")


func shockwaves() -> Array[Node]:
	var waves: Array[Node] = []
	for hazard in get_nodes_in_group("boss_hazards"):
		if not hazard.is_in_group("boss_ladis"):
			waves.append(hazard)
	return waves


func check_setup() -> void:
	await reset_arena()
	check(boss.health == 24 and boss.max_health == 24 and boss.phase == 1, "Khara must start with 24 health in phase 1")
	check(boss.collision_layer == 4, "Khara must sit on the enemy body layer so every player weapon reaches him")
	check(bar.visible and bar.boss == boss and bar.fraction() == 1.0, "Boss health bar must bind to Khara at full health")
	check(bar.get_node("Name").text.begins_with("KHARA"), "Boss health bar must show the boss name")
	var apex: float = pow(player.movement_settings.jump_velocity, 2.0) / (2.0 * player.movement_settings.rise_gravity)
	var ladi: Node2D = boss.place_ladi(Vector2(480, 430), 1)
	check(ladi.blast_size.y < apex - 20.0, "Ladi pops must be low enough for a normal jump to clear")
	var wave: Node2D = boss.spawn_shockwave(1)
	check(wave.size.y < apex - 20.0, "Slam shockwave must be low enough for a normal jump to clear")


func check_ladi_direction() -> void:
	for direction in [1, -1]:
		await reset_arena()
		player.set_physics_process(false)
		var origin := Vector2(480, 430)
		# Siya stands on the burst side, 120 px from the lit end.
		player.global_position = origin + Vector2(direction * 120, 0)
		var ladi: Node2D = boss.place_ladi(origin, direction, 0.5, 8)
		var all_on_side := true
		for index in range(ladi.segment_count):
			all_on_side = all_on_side and signf(ladi.segment_global_position(index).x - origin.x) == direction
		check(all_on_side, "Every ladi cracker must lie on its burst side (direction %d)" % direction)
		await ticks(24)
		check(not ladi.is_lit() and player.health == 3, "Ladi must not hurt while its fuse burns (direction %d)" % direction)
		var first_ignition: Array[int] = []
		first_ignition.resize(ladi.segment_count)
		first_ignition.fill(-1)
		for frame in range(40):
			await ticks(1)
			if not is_instance_valid(ladi):
				break
			for index in range(ladi.segment_count):
				if first_ignition[index] < 0 and ladi.is_segment_blasting(index):
					first_ignition[index] = frame
		var sequential := first_ignition[0] >= 0
		for index in range(1, first_ignition.size()):
			sequential = sequential and first_ignition[index] > first_ignition[index - 1]
		check(sequential, "Ladi crackers must pop one after another away from the lit end: %s" % [first_ignition])
		check(player.health == 2, "Ladi must hit Siya on its burst side (direction %d)" % direction)

		# The same ladi aimed the other way leaves her untouched.
		await reset_arena()
		player.set_physics_process(false)
		player.global_position = origin + Vector2(direction * 120, 0)
		boss.place_ladi(origin, -direction, 0.5, 8)
		await ticks(95)
		check(player.health == 3, "Standing on the far side of the lit end must be safe (direction %d)" % direction)
		check(ladis().is_empty(), "Spent ladis must clean themselves up")

	await reset_arena()
	var clipped: Node2D = boss.place_ladi(Vector2(880, 430), 1, 0.5, 12)
	var last_x: float = clipped.segment_global_position(clipped.segment_count - 1).x
	check(clipped.segment_count < 12 and last_x < 936.0, "Ladi strings must stop before the arena wall")


func check_ladi_jump() -> void:
	for jump in [true, false]:
		await reset_arena()
		var origin := Vector2(400, 430)
		player.global_position = origin + Vector2(150, 0)
		await ticks(2)
		boss.place_ladi(origin, 1, 0.5, 10)
		# Pops reach 150 px about 0.2 s after the fuse; jump just before.
		await ticks(34)
		if jump:
			Input.action_press("jump")
			await ticks(1)
			Input.action_release("jump")
		await ticks(60)
		if jump:
			check(player.health == 3, "A timed jump must clear the travelling ladi pops")
		else:
			check(player.health == 2, "Standing still in the ladi path must take one hit")


func check_slam() -> void:
	await reset_arena()
	boss.set_physics_process(true)
	player.set_physics_process(false)
	player.global_position = boss.global_position + Vector2(-80, 0)
	await ticks(1)
	boss.start_slam(-1)
	await ticks(30)
	check(boss.state == boss.State.SLAM_WINDUP and player.health == 3, "Gada slam must be telegraphed without damage during wind-up")
	check(boss.get_node("Status").text.contains("GADA RAISED"), "Wind-up must show a readable tell")
	await ticks(25)
	check(player.health == 1, "Gada slam must deal two damage in front of Khara")
	check(player.velocity.x < 0.0, "Slam knockback must push Siya away from Khara")
	await ticks(10)
	check(boss.state == boss.State.SLAM_RECOVERY, "Slam must leave a recovery window")
	check(boss.get_node("Status").text.contains("STRIKE NOW"), "Recovery must invite a counterattack")

	await reset_arena()
	boss.set_physics_process(true)
	player.set_physics_process(false)
	player.global_position = boss.global_position + Vector2(80, 0)
	await ticks(1)
	boss.start_slam(-1)
	await ticks(80)
	check(player.health == 3, "Dashing behind Khara must avoid the slam and the phase 1 shockwave")

	await reset_arena()
	boss.set_physics_process(true)
	player.set_physics_process(false)
	player.global_position = boss.global_position + Vector2(-300, 0)
	await ticks(1)
	boss.start_slam(-1)
	await ticks(53)
	var waves := shockwaves()
	check(waves.size() == 1 and waves[0].direction == -1, "Phase 1 slam must release one shockwave in its facing direction")
	await ticks(50)
	check(player.health == 2, "Shockwave must travel along the ground and hit a grounded Siya")


func check_phase_two() -> void:
	await reset_arena()
	var phases: Array[int] = []
	boss.phase_changed.connect(func(next: int) -> void: phases.append(next))
	var windup_before: float = boss.current_slam_windup()
	var speed_before: float = boss.current_speed()
	boss.start_slam(-1)
	boss.take_damage(11, Vector2(300, -200))
	check(boss.health == 13 and boss.phase == 1 and phases.is_empty(), "Khara must stay in phase 1 above half health")
	check(boss.state == boss.State.SLAM_WINDUP and is_zero_approx(boss.velocity.x), "Hits must not interrupt or push Khara (poise)")
	check(bar.health == 13 and bar.fraction() < 0.55, "Health bar must follow boss damage")
	boss.take_damage(1, Vector2.ZERO)
	check(boss.health == 12 and boss.phase == 2 and phases == [2], "Phase 2 must begin at 50% health")
	check(boss.state == boss.State.PHASE_SHIFT, "Phase change must cancel the pending slam with a roar")
	check(boss.current_slam_windup() < windup_before and boss.current_speed() > speed_before, "Phase 2 must be faster")
	check(bar.phase == 2, "Health bar must react to the phase change")
	boss.take_damage(2, Vector2.ZERO)
	check(phases == [2], "Phase 2 must only trigger once")

	# Phase 2 ladi: a pincer of two strings bursting in opposite directions.
	await reset_arena()
	player.set_physics_process(false)
	player.global_position = Vector2(300, 430)
	boss.take_damage(12, Vector2.ZERO)
	boss.set_physics_process(true)
	boss.start_ladi()
	await ticks(35)
	var placed := ladis()
	check(placed.size() == 2, "Phase 2 must place two ladis, got %d" % placed.size())
	if placed.size() == 2:
		var directions: Array[int] = [placed[0].direction, placed[1].direction]
		directions.sort()
		check(directions == [-1, 1], "Phase 2 ladis must burst in opposite directions")
		var toward: Node = placed[0] if placed[0].direction == -1 else placed[1]
		var pincer: Node = placed[1] if toward == placed[0] else placed[0]
		check(toward.global_position.x > player.global_position.x, "The first ladi must start at Khara and burst toward Siya")
		check(pincer.fuse_time > toward.fuse_time and pincer.global_position.x < 60.0, "The pincer ladi must start at the far wall with a later fuse")

	# Phase 2 slam releases shockwaves both ways.
	await reset_arena()
	player.set_physics_process(false)
	player.global_position = Vector2(150, 430)
	boss.take_damage(12, Vector2.ZERO)
	boss.set_physics_process(true)
	boss.start_slam(-1)
	await ticks(42)
	var waves := shockwaves()
	var wave_directions: Array[int] = []
	for wave in waves:
		wave_directions.append(wave.direction)
	wave_directions.sort()
	check(wave_directions == [-1, 1], "Phase 2 slam must release shockwaves in both directions")


func check_ai() -> void:
	# Far away: Khara lights a single phase 1 ladi toward Siya.
	await reset_arena(false)
	player.set_physics_process(false)
	player.global_position = Vector2(120, 430)
	var saw_ladi := false
	for frame in range(260):
		await ticks(1)
		if not ladis().is_empty():
			saw_ladi = true
			break
	check(saw_ladi and ladis().size() == 1, "Khara must light one ladi at range in phase 1")
	if saw_ladi:
		check(ladis()[0].direction == -1, "Khara's ladi must burst toward Siya")

	# Close: Khara slams.
	await reset_arena(false)
	player.set_physics_process(false)
	player.global_position = boss.global_position + Vector2(-90, 0)
	var saw_windup := false
	for frame in range(120):
		await ticks(1)
		if boss.state == boss.State.SLAM_WINDUP:
			saw_windup = true
			break
	check(saw_windup and player.health == 3, "Khara must wind up a slam at close range before dealing damage")

	# Mid range: Khara walks over.
	await reset_arena(false)
	player.set_physics_process(false)
	player.global_position = boss.global_position + Vector2(-180, 0)
	var start_x: float = boss.global_position.x
	var approached := false
	for frame in range(150):
		await ticks(1)
		approached = approached or boss.state == boss.State.APPROACH
	check(approached and boss.global_position.x < start_x - 20.0, "Khara must approach Siya at mid range")


func check_damage_and_defeat() -> void:
	await reset_arena()
	player.global_position = boss.global_position + Vector2(-40, 0)
	player.facing_direction = 1
	await ticks(2)
	Input.action_press("attack")
	await ticks(1)
	Input.action_release("attack")
	await ticks(30)
	check(boss.health == 23, "A real sparkler lash must damage Khara")
	player.global_position = boss.global_position + Vector2(-200, 0)
	await ticks(2)
	Input.action_press("skyshot")
	await ticks(1)
	Input.action_release("skyshot")
	await ticks(30)
	check(boss.health == 21, "A real skyshot must deal two damage to Khara")
	check(bar.health == 21, "Health bar must track weapon damage")

	boss.set_physics_process(true)
	boss.place_ladi(Vector2(300, 430), 1)
	var died_count := [0]
	boss.died.connect(func() -> void: died_count[0] += 1)
	boss.take_damage(30, Vector2.ZERO)
	check(boss.health == 0 and boss.state == boss.State.DEAD and died_count[0] == 1, "Khara must die once at zero health")
	check(boss.collision_layer == 0, "Defeated Khara must stop receiving hits")
	await ticks(2)
	check(ladis().is_empty(), "Defeat must defuse remaining ladis")
	check(current_scene.get_node("HUD/CombatStatus").text.contains("Khara defeated"), "Arena must announce the defeat")
	await ticks(100)
	check(not is_instance_valid(boss), "Khara must be removed after the death animation")
	check(not bar.visible, "Boss health bar must fade out after defeat")
	var old_scene := current_scene
	var restart := InputEventAction.new()
	restart.action = "restart"
	restart.pressed = true
	Input.parse_input_event(restart)
	await ticks(3)
	check(current_scene != old_scene and current_scene.get_node("TestCourse/Boss").health == 24, "Restart must restore the boss fight")


func run_checks() -> void:
	await check_setup()
	await check_ladi_direction()
	await check_ladi_jump()
	await check_slam()
	await check_phase_two()
	await check_ai()
	await check_damage_and_defeat()
	release_inputs()
	if failures == 0:
		print("PASS: Khara setup, ladi direction/fuse/sequence/walls/jump, slam tell/damage/recovery/shockwave, phase 2, AI, weapon damage, defeat, health bar and restart")
	quit(1 if failures > 0 else 0)
