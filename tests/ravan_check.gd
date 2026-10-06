extends SceneTree
## Ravan boss: one health pool hit anywhere, every tenth of it severs the rightmost
## living head, no regrowth, only living heads attack (fixed origins, glow
## telegraph), phases, Dashanan Fury with the living heads, real weapons, generic
## boss bar with head ticks, death and restart.
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


func head(index: int) -> Object:
	return boss.heads[index]


func hurtbox() -> StaticBody2D:
	return boss.get_node("Hurtbox")


func attacks() -> Array[Node]:
	return get_nodes_in_group("ravan_attacks")


func clear_attacks() -> void:
	for attack in attacks():
		attack.free()


## Damage that takes exactly the next head, then skip any phase roar and Fury it
## starts, so a check can keep fighting in the new phase.
func sever_next() -> void:
	hurtbox().take_damage(boss.health - boss.head_threshold(boss.heads_alive - 1), Vector2.ZERO)
	if boss.state == boss.State.TRANSITION:
		boss._begin_fury()
	if boss.state == boss.State.FURY:
		boss._end_fury()
	boss._spent_remaining = 0.0
	boss._stagger_remaining = 0.0
	boss._activation_cooldown = 0.0
	clear_attacks()


func check_structure() -> void:
	await reset_arena()
	check(boss.state == boss.State.FIGHT and boss.phase == 1, "Ravan must start the fight in phase 1")
	check(boss.max_health == 80 and boss.health == 80 and boss.heads_alive == 10, "Ravan must start with 80 health and ten heads")
	check(boss.heads.size() == 10, "Ravan must have ten head slots")
	check(not boss.has_node("Heads") and get_nodes_in_group("ravan_heads").is_empty(), "Heads must not be separate entities")
	var names := {}
	var kinds := {}
	var offsets: Array = boss.RavanBody.HEAD_OFFSETS
	check(offsets.size() == 10, "Ten head offsets must describe the body art")
	for index in range(10):
		names[head(index).head_name] = true
		kinds[head(index).attack_kind] = true
		check(head(index).index == index and head(index).alive, "Heads must be indexed and alive")
		if index > 0:
			check(offsets[index].x > offsets[index - 1].x, "Head offsets must run left to right")
	check(names.size() == 10, "All ten heads must be uniquely named")
	check(kinds.size() == 5, "Heads must cover all five attack types")
	var lead := {}
	for index in range(5):
		lead[head(index).attack_kind] = true
	check(lead.size() == 5, "The five leftmost heads, the last to fall, must cover every attack type")
	var body: Node2D = boss.get_node("Body")
	check(body.has_node("Art") and body.head_count == 10, "Body must own the art slot and show ten heads")
	check(hurtbox().collision_layer == 4 and hurtbox().get_child_count() >= 2, "One enemy-body hurtbox must cover body and head row")
	var bar: Control = boss.get_node("BossUI/HealthBar")
	check(bar.boss == boss and bar.visible, "Boss health bar must bind to Ravan")
	check(bar.get_script().resource_path == "res://scripts/ui/boss_health_bar.gd", "Ravan must use the generic BossHealthBar")
	check(bar.max_health == 80 and bar.health == 80 and bar.name_label.text == "SWAMINATHAN, DASHANAN", "Generic bar must read Ravan's health and title")
	check(bar.phase_thresholds.size() == 9 and is_equal_approx(bar.phase_thresholds[0], 0.1) and is_equal_approx(bar.phase_thresholds[8], 0.9), "Generic bar must tick each head's tenth")
	var indicators: Control = boss.get_node("BossUI/HeadIndicators")
	check(indicators.boss == boss and indicators.visible, "Head indicators must bind to Ravan")


func check_hit_anywhere_with_real_weapons() -> void:
	# A grounded lash on his body.
	await reset_arena()
	player.position = Vector2(446, 430)
	player.facing_direction = 1
	await ticks(2)
	await press(&"attack")
	await ticks(20)
	check(boss.health == 79, "Grounded sparkler must hurt Ravan's body")
	check(boss.get_node("BossUI/HealthBar").health == 79, "Generic bar must follow damage through health_changed")
	# A skyshot from across the arena.
	await reset_arena()
	player.position = Vector2(200, 430)
	player.facing_direction = 1
	await ticks(2)
	await press(&"skyshot")
	await ticks(30)
	check(boss.health == 78 and player.skyshot_ammo == 4, "A skyshot must hit Ravan from range")
	# A full chakri beside him.
	await reset_arena()
	player.position = Vector2(480, 430)
	await ticks(2)
	Input.action_press("special")
	await ticks(65)
	Input.action_release("special")
	await ticks(3)
	check(boss.health == 77, "A full chakri must hurt Ravan once")
	# The head row is part of the same pool.
	await reset_arena()
	var row: CollisionShape2D = hurtbox().get_node("HeadRowShape")
	var top: float = row.global_position.y - (row.shape as RectangleShape2D).size.y * 0.5
	check(top < boss.head_global(4).y - 20.0 and (row.shape as RectangleShape2D).size.x > absf(boss.head_global(9).x - boss.head_global(0).x), "Head-row hurtbox must cover every head")


func check_head_thresholds() -> void:
	await reset_arena()
	var lost: Array[int] = []
	boss.head_lost.connect(func(index: int, _remaining: int) -> void: lost.append(index))
	# A huge hit takes only one head.
	hurtbox().take_damage(50, Vector2.ZERO)
	check(boss.health == 72 and boss.heads_alive == 9 and lost == [9], "One hit must take at most one head")
	check(not head(9).alive and head(8).alive and boss.get_node("Body").head_count == 9, "The rightmost head must fall first and the body must swap state")
	await ticks(60)
	# Every tenth after that: one point short keeps the head, the threshold takes it.
	for remaining in range(9, 0, -1):
		var threshold: int = boss.head_threshold(remaining - 1)
		hurtbox().take_damage(boss.health - threshold - 1, Vector2.ZERO)
		check(boss.heads_alive == remaining, "Damage short of a threshold must keep %d heads" % remaining)
		sever_next()
		check(boss.heads_alive == remaining - 1 and lost.back() == remaining - 1, "Crossing a threshold must sever head %d" % (remaining - 1))
		for index in range(10):
			check(head(index).alive == (index < remaining - 1), "Only the leftmost %d heads may live" % (remaining - 1))
		check(boss.get_node("Body").head_count == boss.heads_alive, "Body state must match living heads")
		if boss.heads_alive == 0:
			break
		if remaining == 6:
			# No regrowth: wait longer than the old 12 s timer.
			await ticks(780)
			check(boss.heads_alive == 5 and boss.health == boss.head_threshold(5), "Lost heads and health must not regrow")
	check(boss.state == boss.State.DYING and boss.health == 0, "Losing the last head must defeat Ravan")


func check_living_heads_attack() -> void:
	await reset_arena()
	player.set_physics_process(false)
	player.position = Vector2(300, 430)
	# A head that falls mid-telegraph never fires.
	check(boss.activate_head(9) and head(9).state == boss.HeadState.TELEGRAPH, "A living head must telegraph")
	await ticks(20)
	check(head(9).telegraph_progress() > 0.2, "Telegraph must charge up")
	hurtbox().take_damage(8, Vector2.ZERO)
	await ticks(60)
	check(attacks().is_empty() and not head(9).alive, "A head severed mid-telegraph must not attack")
	check(not boss.activate_head(9), "A severed head must never attack again")
	# Auto-activation only picks living heads, one at a time in phase 1.
	sever_next()
	sever_next()
	boss.auto_activate = true
	player.health = 99
	var seen := {}
	var peak := 0
	for frame in range(600):
		await ticks(1)
		peak = maxi(peak, boss.active_count())
		for slot in boss.heads:
			if slot.state != boss.HeadState.IDLE:
				seen[slot.index] = true
	check(boss.heads_alive == 7 and boss.phase == 2, "Three severed heads must reach phase 2")
	check(not seen.is_empty() and seen.keys().all(func(index: int) -> bool: return index < 7), "Only living heads may attack")
	check(peak == 2, "Phase 2 must run two heads at once")


func check_head_attacks() -> void:
	await reset_arena()
	player.set_physics_process(false)
	player.position = Vector2(300, 430)
	var expected := {0: "column", 1: "spread", 2: "homing", 3: "beam", 4: "shockwaves"}
	for index in [0, 1, 2, 3, 4]:
		clear_attacks()
		boss.activate_head(index)
		await ticks(56)
		var found := attacks()
		match expected[index]:
			"shockwaves":
				check(get_nodes_in_group("ravan_shockwaves").size() == 2, "Roar head must send two floor shockwaves")
			"beam":
				check(found.size() == 1 and found[0].style == found[0].Style.BEAM and found[0].is_telegraphing(), "Fire head must telegraph a breath beam")
				check(found.size() == 1 and found[0].global_position.distance_to(boss.mouth_global(index)) < 1.0, "Fire must leave the head's fixed mouth")
			"homing":
				check(found.size() == 1 and found[0].is_in_group("homing_projectiles"), "Homing head must fire one bolt in phase 1")
				check(found.size() == 1 and found[0].global_position.distance_to(boss.mouth_global(index)) < 20.0, "Homing bolt must leave the head's fixed mouth")
			"column":
				check(found.size() == 1 and absf(found[0].global_position.x - 300.0) < 1.0, "Lightning must mark the player's position")
			"spread":
				check(found.size() == 3 and found[0].is_in_group("enemy_projectiles"), "Spread head must fire a three-shot spread")
		await ticks(90)
	clear_attacks()

	# Lightning hurts a player who stays; moving off the mark is safe.
	await reset_arena()
	player.set_physics_process(false)
	player.position = Vector2(300, 430)
	boss.activate_head(0)
	await ticks(106)
	check(player.health == 4, "Lightning must strike a player who stays on the mark")
	await reset_arena()
	player.set_physics_process(false)
	player.position = Vector2(300, 430)
	boss.activate_head(9)
	await ticks(58)
	player.position = Vector2(380, 430)
	await ticks(50)
	check(player.health == 5, "Leaving the lightning mark must avoid damage")

	# Shockwaves hit grounded players and break on the ledges.
	await reset_arena()
	player.set_physics_process(false)
	player.position = Vector2(380, 430)
	boss.activate_head(4)
	await ticks(86)
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
	# The last head keeps attacking on its own.
	boss.set_head_count(1)
	var fired := 0
	for frame in range(300):
		await ticks(1)
		if head(0).state == boss.HeadState.TELEGRAPH:
			fired += 1
	check(fired > 0 and boss.phase == 3, "The last living head must still attack")


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
	var health_updates: Array[int] = []
	player.health_changed.connect(func(value: int) -> void: health_updates.append(value))
	player.health = 2
	for step in range(3):
		hurtbox().take_damage(8, Vector2.ZERO)
		if step < 2:
			check(boss.state == boss.State.FIGHT and boss.is_staggered(), "Losing a head must stagger Ravan")
			check(player.health == 2 and health_updates.is_empty(), "Losing a head inside a phase must not heal Siya")
			await ticks(40)
	check(boss.heads_alive == 7 and boss.phase == 2 and phases == [2], "Phase 2 must start with seven heads left")
	check(player.health == player.max_health and health_updates == [player.max_health], "Clearing phase 1 must fully heal Siya and notify the HUD once")
	check(boss.state == boss.State.TRANSITION, "Phase change must roar first")
	hurtbox().take_damage(5, Vector2.ZERO)
	check(boss.health == 56, "Ravan must be guarded while he roars")
	check(health_updates.size() == 1, "Hits during a phase transition must not repeat healing")
	await ticks(1)
	check(current_scene.get_node("HUD/HealthStatus").text == "Siya health: 5/5", "Phase healing must update the health HUD on the next frame")
	await ticks(80)
	check(boss.state == boss.State.FURY and boss.fury_waves.size() == 5, "Phase 2 must open with a five-wave Dashanan Fury")
	hurtbox().take_damage(5, Vector2.ZERO)
	check(boss.health == 56, "Ravan must be guarded during Dashanan Fury")
	await ticks(6)
	check(head(0).fury_lit and not head(6).fury_lit, "Living heads must ignite one by one")
	check(boss.get_node("BossUI/Tint").color.a > 0.0, "Dashanan Fury must tint the screen")
	# Stand in the first safe gap (lanes 4 and 5) and survive the wave.
	player.set_physics_process(false)
	player.position = Vector2(boss.lane_center(4) + 20.0, 430)
	await ticks(90)
	var pillars := get_nodes_in_group("ravan_hazards")
	check(pillars.size() == 8 and boss.current_safe_lanes == [4, 5], "First wave must telegraph eight lanes and leave two safe")
	check(head(6).fury_lit and not head(7).fury_lit and not head(9).fury_lit, "Severed heads must not join Dashanan Fury")
	check(head(3).fury_silent and not head(2).fury_silent, "A head whose lanes are all safe must go silent")
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
	check(boss.state == boss.State.FIGHT and boss.is_spent() and boss.active_count() == 0, "Surviving Fury must leave Ravan spent")
	hurtbox().take_damage(1, Vector2.ZERO)
	check(boss.health == 55, "Spent Ravan must take damage")
	health_updates.clear()
	for step in range(4):
		sever_next()
	check(boss.heads_alive == 3 and boss.phase == 3 and phases == [2, 3], "Phase 3 must start with three heads left")
	check(player.health == player.max_health and health_updates == [player.max_health], "Clearing phase 2 must fully heal Siya and notify the HUD once")

	# Phase 3 repeats the super move on a timer, with one wave per living head.
	await reset_arena()
	boss.set_head_count(2)
	boss._fury_clock = boss.phase_three_fury_interval - 0.05
	await ticks(6)
	check(boss.state == boss.State.FURY and boss.fury_waves.size() == 2, "Phase 3 Fury must run one wave per living head")


func check_death_and_restart() -> void:
	await reset_arena()
	var events := {"defeated": false}
	boss.died.connect(func() -> void: events.defeated = true)
	boss.set_head_count(1)
	boss.activate_head(0)
	await ticks(58)
	check(not attacks().is_empty(), "The last head must be mid-attack for this check")
	player.health = 1
	hurtbox().take_damage(boss.health, Vector2.ZERO)
	check(player.health == player.max_health, "Defeating Ravan must fully heal Siya")
	await ticks(1)
	check(boss.state == boss.State.DYING and boss.heads_alive == 0 and attacks().is_empty(), "Final hit must sever the last head, start the death and clear attacks")
	check(boss.get_node("Body").head_count == 0, "Body must show the headless state")
	await ticks(80)
	check(boss.state == boss.State.DEAD and events.defeated, "Death sequence must finish and emit died")
	var bar: Control = boss.get_node("BossUI/HealthBar")
	check(bar.health == 0 and bar._fade_out or not bar.visible, "Generic bar must empty and fade out on death")
	check(not boss.get_node("BossUI/HeadIndicators").visible, "Head indicators must hide on death")
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
	check(boss.health == 80 and boss.heads_alive == 10 and boss.phase == 1 and player.health == 5, "Restart must restore Ravan and Siya")
	old_scene = current_scene
	player.take_damage(5, Vector2.ZERO)
	await ticks(3)
	check(current_scene != old_scene, "Lethal damage must restart the Ravan arena")


## Dash i-frames: head attacks, shared projectiles and Fury pillars all go
## through the player's take_damage, so an invulnerable Siya takes nothing.
func check_dash_invulnerability() -> void:
	for index in [0, 1, 2, 3, 4]:
		await reset_arena()
		player.set_physics_process(false)
		player.position = Vector2(300, 430)
		# Physics is paused, so the dash i-frame timer holds for the whole check.
		player._invulnerable_remaining = 10.0
		boss.activate_head(index)
		await ticks(160)
		check(player.health == 5, "Dash i-frames must ignore head %d's attack" % index)
	for invulnerable in [true, false]:
		await reset_arena()
		player.set_physics_process(false)
		player.position = Vector2(boss.lane_center(1), 430)
		if invulnerable:
			player._invulnerable_remaining = 10.0
		boss.phase = 3
		boss._fury_clock = boss.phase_three_fury_interval - 0.05
		await ticks(230)
		check(boss.state == boss.State.FURY and not 1 in boss.current_safe_lanes, "Fury check must stand Siya in a burning lane")
		if invulnerable:
			check(player.health == 5, "Dash i-frames must ignore Fury pillars")
		else:
			check(player.health < 5, "Fury pillars must hurt Siya without i-frames")


func run_checks() -> void:
	await check_structure()
	await check_hit_anywhere_with_real_weapons()
	await check_head_thresholds()
	await check_living_heads_attack()
	await check_head_attacks()
	await check_auto_activation()
	check_fury_fairness_data()
	await check_phases_and_fury()
	await check_dash_invulnerability()
	await check_death_and_restart()
	release_inputs()
	if failures == 0:
		print("PASS: one health pool hit anywhere, heads severed right to left at each tenth, no regrowth, only living heads attack from fixed origins, real weapons, phases, Dashanan Fury with living heads, dash i-frames, generic boss bar, death and restart")
	quit(1 if failures > 0 else 0)
