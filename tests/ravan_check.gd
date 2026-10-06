extends SceneTree
## Ravan boss: head slots, guarded/active heads, knockout and regrowth, navel exposure,
## phases, Dashanan Fury safe lanes, head attacks, real weapons, death and restart.
const ARENA := "res://scenes/bosses/ravan/ravan_arena.tscn"

var failures: int = 0
var player: CharacterBody2D
var boss: Node2D


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


func press(action: StringName) -> void:
	Input.action_press(action)
	await ticks(1)
	Input.action_release(action)


func reset_arena(auto_activate: bool = false) -> void:
	release_inputs()
	change_scene_to_file(ARENA)
	await scene_changed
	player = current_scene.get_node("Player")
	boss = current_scene.get_node("Ravan")
	boss.auto_activate = auto_activate
	boss.start_fight()
	await ticks(3)


func head(index: int) -> Node2D:
	return boss.heads[index]


func attacks() -> Array[Node]:
	return get_nodes_in_group("ravan_attacks")


func knock_out(indices: Array) -> void:
	for index in indices:
		boss.activate_head(index)
		head(index).take_damage(head(index).max_health, Vector2.ZERO)


func check_structure() -> void:
	await reset_arena()
	check(boss.state == boss.State.FIGHT and boss.phase == 1 and boss.core_health == 30, "Ravan must start phase 1 with full core health")
	check(boss.heads.size() == 10, "Ravan must have ten separate head nodes")
	var names := {}
	var kinds := {}
	var positions := {}
	for index in range(boss.heads.size()):
		var slot: Node2D = head(index)
		names[slot.head_name] = true
		kinds[slot.attack_kind] = true
		positions[slot.position] = true
		check(slot.head_index == index and slot.get_parent() == boss.get_node("Heads"), "Heads must be indexed slots under Ravan/Heads")
		check(slot.has_node("Visual/Art") and slot.has_node("Visual/Placeholder") and slot.has_node("CollisionShape2D"), "Each head must own an art slot, placeholder and hurtbox")
		check(slot.collision_layer == 4 and slot.health == slot.max_health, "Each head must be an enemy-body hurtbox with full health")
	check(names.size() == 10 and positions.size() == 10, "All ten heads must be uniquely named and positioned")
	check(kinds.size() == 5, "Heads must cover all five attack types")
	check(boss.has_node("Body/Art") and boss.get_node("Core").collision_layer == 0, "Body must have an art slot and the navel must start closed")
	var bar: Control = boss.get_node("BossUI/HealthBar")
	check(bar.boss == boss and bar.visible, "Boss health bar must bind to Ravan")


func check_guard_knockout_and_regrowth() -> void:
	await reset_arena()
	var slot := head(3)
	slot.take_damage(5, Vector2.ZERO)
	check(slot.health == 2 and slot.state == slot.HeadState.IDLE, "Idle heads must guard against damage")
	boss.get_node("Core").take_damage(3, Vector2.ZERO)
	check(boss.core_health == 30, "Closed navel must ignore damage")
	check(boss.activate_head(3) and slot.state == slot.HeadState.TELEGRAPH, "Activated head must telegraph")
	await ticks(16)
	check(slot.position.y > slot.home_position.y + 60.0, "Active head must lunge down into reach")
	slot.take_damage(1, Vector2.ZERO)
	check(slot.health == 1 and slot.state == slot.HeadState.TELEGRAPH, "Active head must take damage without cancelling")
	slot.take_damage(1, Vector2.ZERO)
	check(slot.state == slot.HeadState.KNOCKED_OUT and slot.collision_layer == 0, "Depleted head must be knocked out and stop colliding")
	await ticks(70)
	check(attacks().is_empty(), "Knocking out a telegraphing head must cancel its attack")
	check(slot.regen_remaining > 9.0 and boss.knocked_out_count() == 1, "Knocked-out head must start its regrowth timer")
	slot.regen_remaining = 0.1
	await ticks(10)
	check(slot.state == slot.HeadState.REGROWING, "Head must regrow when its timer ends")
	await ticks(40)
	check(slot.state == slot.HeadState.IDLE and slot.health == 2 and slot.collision_layer == 4, "Regrown head must return with full health")
	# Two knockouts in phase 1 are not enough to open the navel.
	knock_out([1, 8])
	await ticks(2)
	check(boss.state == boss.State.FIGHT and not boss.is_exposed(), "Fewer than three knockouts must not expose the navel")


func check_exposure() -> void:
	await reset_arena()
	var exposures := {"count": 0}
	boss.exposure_started.connect(func() -> void: exposures.count += 1)
	knock_out([0, 4, 9])
	await ticks(2)
	check(boss.is_exposed() and exposures.count == 1 and boss.get_node("Core").collision_layer == 4, "Three knockouts must expose the amrit in phase 1")
	check(head(0).regen_paused and head(0).is_knocked_out(), "Knocked-out heads must stay down during exposure")
	check(boss.activate_head(2) == false, "No head may attack while the navel is exposed")
	# A real grounded lash reaches the navel.
	player.position = Vector2(446, 430)
	player.facing_direction = 1
	await ticks(2)
	await press(&"attack")
	await ticks(20)
	check(boss.core_health == 29, "Grounded sparkler must hit the exposed navel")
	await ticks(300)
	check(boss.state == boss.State.FIGHT and boss.get_node("Core").collision_layer == 0, "Exposure must end and close the navel")
	var regrowing: bool = head(0).state == head(0).HeadState.REGROWING or head(0).state == head(0).HeadState.IDLE
	check(boss.knocked_out_count() == 0 and regrowing, "All knocked-out heads must regrow when the navel closes")


func check_real_weapons_on_heads() -> void:
	await reset_arena()
	boss.activate_head(0)
	player.position = Vector2(224, 430)
	player.facing_direction = 1
	await ticks(16)
	await press(&"jump")
	await ticks(8)
	await press(&"attack")
	await ticks(12)
	check(head(0).health == 1, "Jumping sparkler must hit a lunging outer head")

	await reset_arena()
	boss.activate_head(9)
	player.position = Vector2(600, 430)
	player.facing_direction = 1
	await ticks(16)
	await press(&"jump")
	await ticks(9)
	await press(&"skyshot")
	await ticks(14)
	check(head(9).is_knocked_out() and player.skyshot_ammo == 4, "A jumping skyshot must knock out an active head")

	await reset_arena()
	boss.activate_head(4)
	boss.activate_head(5)
	player.position = Vector2(480, 430)
	# Protection keeps the spread shots from cancelling the charge in this check.
	player._protection_remaining = 10.0
	await ticks(16)
	Input.action_press("special")
	await ticks(65)
	Input.action_release("special")
	await ticks(3)
	check(head(4).is_knocked_out() and head(5).is_knocked_out() and head(3).health == 2, "Full chakri must knock out lunging heads but not guarded ones")


func check_head_attacks() -> void:
	await reset_arena()
	player.set_physics_process(false)
	player.position = Vector2(300, 430)
	var expected := {0: "shockwaves", 1: "beam", 2: "homing", 3: "column", 4: "spread"}
	for index in [0, 1, 2, 3, 4]:
		for attack in attacks():
			attack.free()
		boss.activate_head(index)
		await ticks(56)
		var found := attacks()
		match expected[index]:
			"shockwaves":
				check(get_nodes_in_group("ravan_shockwaves").size() == 2, "Roar head must send two floor shockwaves")
			"beam":
				check(found.size() == 1 and found[0].style == found[0].Style.BEAM and found[0].is_telegraphing(), "Fire head must telegraph a breath beam")
			"homing":
				check(found.size() == 1 and found[0].is_in_group("homing_projectiles"), "Greed head must fire one homing bolt in phase 1")
			"column":
				check(found.size() == 1 and absf(found[0].global_position.x - 300.0) < 1.0, "Lightning must mark the player's position")
			"spread":
				check(found.size() == 3 and found[0].is_in_group("enemy_projectiles"), "Envy head must fire a three-shot spread")
		head(index).retreat()
		await ticks(30)

	# Lightning hurts a player who stays; moving off the mark is safe.
	await reset_arena()
	player.set_physics_process(false)
	player.position = Vector2(300, 430)
	boss.activate_head(6)
	await ticks(56)
	await ticks(50)
	check(player.health == 4, "Lightning must strike a player who stays on the mark")
	await reset_arena()
	player.set_physics_process(false)
	player.position = Vector2(300, 430)
	boss.activate_head(6)
	await ticks(58)
	player.position = Vector2(380, 430)
	await ticks(50)
	check(player.health == 5, "Leaving the lightning mark must avoid damage")

	# Shockwaves hit grounded players and break on the ledges.
	await reset_arena()
	player.set_physics_process(false)
	player.position = Vector2(300, 430)
	boss.activate_head(0)
	await ticks(56)
	await ticks(30)
	check(player.health == 4, "Shockwave must hit a grounded player")
	await ticks(140)
	check(get_nodes_in_group("ravan_shockwaves").is_empty(), "Shockwaves must stop at ledges and walls")


func check_auto_activation() -> void:
	await reset_arena(true)
	player.set_physics_process(false)
	player.health = 99
	var peak := 0
	for frame in range(240):
		await ticks(1)
		peak = maxi(peak, boss.active_count())
	check(peak == 1, "Phase 1 must activate exactly one head at a time")
	boss.phase = 2
	peak = 0
	for frame in range(300):
		await ticks(1)
		peak = maxi(peak, boss.active_count())
	check(peak == 2, "Phase 2 must activate two heads at once")


func check_fury_fairness_data() -> void:
	for phase in boss.FURY_SAFE_LANES:
		var waves: Array = boss.FURY_SAFE_LANES[phase]
		for index in range(waves.size()):
			var safe: Array = waves[index]
			check(safe.size() == 2 and absi(safe[0] - safe[1]) == 1, "Each Fury wave must leave two adjacent safe lanes")
			if index > 0:
				var shift := absf((safe[0] + safe[1]) * 0.5 - (waves[index - 1][0] + waves[index - 1][1]) * 0.5)
				var telegraph := 1.0 if phase <= 2 else 0.85
				# Distance from the old gap centre to inside the new gap, at run speed 240.
				var travel := maxf(shift * boss.lane_width() - boss.lane_width() + 12.0, 0.0)
				check(shift <= 3.0 and travel / 240.0 < telegraph + boss.FURY_REST, "Fury safe gaps must be reachable on foot")


func check_phases_and_fury() -> void:
	await reset_arena()
	var phases: Array[int] = []
	boss.phase_changed.connect(func(value: int) -> void: phases.append(value))
	knock_out([0, 4, 9])
	await ticks(2)
	boss.get_node("Core").take_damage(15, Vector2.ZERO)
	check(boss.core_health == 20 and boss.phase == 2 and phases == [2], "Phase damage must clamp at 20 and start phase 2")
	check(boss.state == boss.State.TRANSITION and boss.knocked_out_count() == 0, "Phase change must close the navel and regrow heads")
	await ticks(80)
	check(boss.state == boss.State.FURY, "Phase 2 must open with Dashanan Fury")
	for slot in boss.heads:
		check(slot.state == slot.HeadState.FURY, "Every head must join Dashanan Fury")
	head(2).take_damage(3, Vector2.ZERO)
	check(head(2).health == 2, "Heads must be guarded during Dashanan Fury")
	await ticks(6)
	check(head(1).fury_lit and not head(9).fury_lit, "Heads must ignite one by one")
	check(boss.get_node("BossUI/Tint").color.a > 0.0, "Dashanan Fury must tint the screen")
	# Stand in the first safe gap (lanes 4 and 5) and survive the wave.
	player.set_physics_process(false)
	player.position = Vector2(boss.lane_center(4) + 20.0, 430)
	await ticks(90)
	var pillars := get_nodes_in_group("ravan_hazards")
	check(pillars.size() == 8 and boss.current_safe_lanes == [4, 5], "First wave must telegraph eight lanes and leave two safe")
	check(head(4).fury_silent and head(5).fury_silent and not head(3).fury_silent, "Safe-lane heads must go silent")
	await ticks(110)
	check(player.health == 5, "Standing in the safe gap must avoid the Fury wave")
	# The next gap moves; standing in an old safe lane now burns.
	boss.fury_time = boss.fury_waves[1].start - 0.02
	await ticks(4)
	check(boss.current_safe_lanes == [1, 2], "Second wave must move the safe gap")
	await ticks(75)
	check(player.health == 4, "Pillars must hurt a player outside the safe gap")
	boss.fury_time = boss.fury_duration() - 0.02
	await ticks(4)
	check(boss.state == boss.State.EXPOSED and head(0).state == head(0).HeadState.IDLE, "Surviving Fury must leave Ravan briefly exposed")
	boss.get_node("Core").take_damage(15, Vector2.ZERO)
	check(boss.core_health == 10 and boss.phase == 3 and phases == [2, 3], "Phase 3 must begin at 10 core health")

	# Phase 3 repeats the super move on a timer.
	await reset_arena()
	boss.phase = 3
	boss._fury_clock = boss.phase_three_fury_interval - 0.05
	await ticks(6)
	check(boss.state == boss.State.FURY and boss.fury_waves.size() == 6, "Phase 3 must repeat a longer Dashanan Fury")


func check_death_and_restart() -> void:
	await reset_arena()
	var events := {"defeated": false}
	boss.defeated.connect(func() -> void: events.defeated = true)
	boss.phase = 3
	boss.core_health = 2
	knock_out([0, 1, 2, 3, 9])
	await ticks(2)
	check(boss.is_exposed(), "Five knockouts must expose the navel in phase 3")
	boss.get_node("Core").take_damage(2, Vector2.ZERO)
	await ticks(1)
	check(boss.state == boss.State.DYING and attacks().is_empty(), "Final navel hit must start the death sequence and clear attacks")
	await ticks(200)
	check(boss.state == boss.State.DEAD and events.defeated, "Death sequence must finish and emit defeated")
	for slot in boss.heads:
		check(slot.state == slot.HeadState.DESTROYED, "All ten heads must be destroyed in the death sequence")
	check(current_scene.get_node("HUD/CombatStatus").text.contains("defeated"), "Arena must announce victory")
	var old_scene := current_scene
	var restart := InputEventAction.new()
	restart.action = "restart"
	restart.pressed = true
	Input.parse_input_event(restart)
	await ticks(3)
	check(current_scene != old_scene, "R must restart the Ravan arena")
	boss = current_scene.get_node("Ravan")
	player = current_scene.get_node("Player")
	check(boss.core_health == 30 and boss.phase == 1 and player.health == 5, "Restart must restore Ravan and Siya")
	old_scene = current_scene
	player.take_damage(5, Vector2.ZERO)
	await ticks(3)
	check(current_scene != old_scene, "Lethal damage must restart the Ravan arena")


func run_checks() -> void:
	await check_structure()
	await check_guard_knockout_and_regrowth()
	await check_exposure()
	await check_real_weapons_on_heads()
	await check_head_attacks()
	await check_auto_activation()
	check_fury_fairness_data()
	await check_phases_and_fury()
	await check_death_and_restart()
	release_inputs()
	if failures == 0:
		print("PASS: ten head slots, guarded/active heads, knockout and regrowth, navel exposure, real weapons, head attacks, phases, Dashanan Fury safe lanes, death and restart")
	quit(1 if failures > 0 else 0)
