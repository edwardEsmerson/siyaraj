extends SceneTree
## Real attacks must survive repeated hits, while dodging and recovery stay useful.
const Sandbox = preload("res://scripts/dev/sandbox.gd")

var failures: int = 0
var player: CharacterBody2D
var enemy: CharacterBody2D


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


func reset_arena(encounter: int, three_weapons: bool = false) -> void:
	for action in [&"attack", &"dash", &"move_left", &"move_right", &"jump"]:
		Input.action_release(action)
	Sandbox.next_encounter = encounter
	var arena := load("res://scenes/dev/sandbox.tscn") as PackedScene
	if three_weapons:
		var setup := arena.instantiate()
		setup.three_weapons = true
		arena = PackedScene.new()
		arena.pack(setup)
		setup.free()
	change_scene_to_packed(arena)
	await scene_changed
	player = current_scene.get_node("Player")
	enemy = current_scene.get_node("Enemy")
	await ticks(3)


func check_guard_stagger() -> void:
	await reset_arena(Sandbox.Encounter.GUARD)
	player.set_physics_process(false)
	player.position = enemy.position + Vector2(-48, 0)
	await ticks(1)
	check(enemy.attack.phase == enemy.attack.Phase.WINDUP, "Guard must start a telegraphed attack")
	enemy.take_damage(1, Vector2.ZERO)
	check(enemy.health == 2 and enemy.state == enemy.State.HURT and not enemy.attack.is_busy(), "First hit must still interrupt a guard's wind-up")
	await ticks(6)
	var hurt_remaining: float = enemy._hurt_remaining
	enemy.take_damage(1, Vector2(180, -140))
	check(enemy.health == 1 and enemy._hurt_remaining == hurt_remaining and enemy.velocity == Vector2.ZERO, "Follow-up hits must not extend stun or knock the guard out of range")
	await ticks(42)
	check(player.health == 2 and enemy.attack.phase == enemy.attack.Phase.RECOVERY, "A repeatedly hit guard must recover and strike back")
	await ticks(80)
	# Once the resistance window has expired, a new wind-up can be interrupted.
	enemy.attack.cancel()
	enemy.attack.start(-1)
	enemy.health = 2
	enemy.take_damage(1, Vector2.ZERO)
	check(enemy.state == enemy.State.HURT and not enemy.attack.is_busy(), "Guard stagger must become available again after its cooldown")


func check_brute_attack_spam() -> void:
	await reset_arena(Sandbox.Encounter.BRUTE, true)
	player.position = enemy.position + Vector2(-48, 0)
	player.facing_direction = 1
	await ticks(1)
	var enemy_health_before: int = enemy.health
	# Mash real sparkler attacks without moving or dodging.
	for frame in range(75):
		if not player.sparkler.is_busy():
			Input.action_press("attack")
		await ticks(1)
		Input.action_release("attack")
		if player.health < player.max_health:
			break
	check(is_instance_valid(enemy) and enemy.health < enemy_health_before, "Real sparkler hits must damage the armored brute")
	check(player.health == 1, "Standing in front and mashing attacks must take the brute's two-damage counterstrike")


func check_campaign_guard_attack_spam() -> void:
	await reset_arena(Sandbox.Encounter.GUARD, true)
	player.position = enemy.position + Vector2(-48, 0)
	player.facing_direction = 1
	await ticks(1)
	for frame in range(90):
		if not player.sparkler.is_busy():
			Input.action_press("attack")
		await ticks(1)
		Input.action_release("attack")
		if not is_instance_valid(enemy) or player.health < player.max_health:
			break
	check(player.health == 2, "The campaign's faster lash must not kill a guard before it can counterattack")


func check_brute_dodge_and_punish() -> void:
	await reset_arena(Sandbox.Encounter.BRUTE)
	player.position = enemy.position + Vector2(-48, 0)
	player.facing_direction = 1
	await ticks(1)
	Input.action_press("attack")
	await ticks(1)
	Input.action_release("attack")
	for frame in range(50):
		if enemy.attack.phase != enemy.attack.Phase.WINDUP or enemy.attack._remaining <= 0.1:
			break
		await ticks(1)
	check(enemy.health == 5 and enemy.attack.phase == enemy.attack.Phase.WINDUP, "A nonlethal hit must leave the heavy wind-up running")
	Input.action_press("dash")
	await ticks(1)
	Input.action_release("dash")
	await ticks(14)
	check(player.health == 3 and player.position.x > enemy.position.x, "Dash must avoid the armored strike and pass behind the brute")
	for frame in range(10):
		if enemy.attack.phase == enemy.attack.Phase.RECOVERY:
			break
		await ticks(1)
	check(enemy.attack.phase == enemy.attack.Phase.RECOVERY, "Dodging must expose the brute's recovery window")
	Input.action_press("move_left")
	await ticks(1)
	Input.action_release("move_left")
	Input.action_press("attack")
	await ticks(1)
	Input.action_release("attack")
	await ticks(12)
	check(enemy.health == 4 and player.health == 3 and enemy.attack.phase == enemy.attack.Phase.RECOVERY, "A real attack after dodging must safely punish recovery")


func check_ranged_pressure(encounter: int) -> void:
	await reset_arena(encounter)
	player.set_physics_process(false)
	player.position = Vector2(360, 430)
	var shots_fired := [0]
	enemy.shot_fired.connect(func() -> void: shots_fired[0] += 1)
	# Keep the target alive long enough to exercise repeated hits throughout a cycle.
	enemy.health = 20
	enemy.take_damage(1, Vector2.ZERO)
	check(enemy.state == enemy.State.HURT, "First hit must still stagger a ranged enemy")
	await ticks(6)
	var hurt_remaining: float = enemy._remaining
	enemy.take_damage(1, Vector2(180, -140))
	check(enemy._remaining == hurt_remaining and enemy.velocity == Vector2.ZERO, "Repeated ranged hits must not reset hurt or apply more knockback")
	await ticks(9)
	check(enemy.state == enemy.State.CHARGING, "Ranged enemy must resume charging after its brief stagger")
	var charge_remaining: float = enemy._remaining
	enemy.take_damage(1, Vector2(180, -140))
	check(enemy.state == enemy.State.CHARGING and enemy._remaining == charge_remaining, "Protected charge must continue through a follow-up hit")
	await ticks(42)
	check(shots_fired[0] == 1 and enemy.state == enemy.State.RECOVERY, "Repeatedly hit ranged enemy must still fire its next projectile")
	var reload_remaining: float = enemy._remaining
	enemy.take_damage(1, Vector2(180, -140))
	check(enemy.state == enemy.State.RECOVERY and enemy._remaining == reload_remaining, "Reload hits must not reset the ranged attack cycle")
	await ticks(150)
	check(shots_fired[0] >= 2, "Ranged enemy must continue attacking after the resistance window")
	# Clear line of sight and start a fresh charge after cooldown expiry.
	enemy.state = enemy.State.PATROL
	enemy._remaining = 0.0
	await ticks(1)
	enemy.take_damage(1, Vector2.ZERO)
	check(enemy.state == enemy.State.HURT, "Ranged stagger must become available again after cooldown expiry")


func run_checks() -> void:
	await check_guard_stagger()
	await check_campaign_guard_attack_spam()
	await check_brute_attack_spam()
	await check_brute_dodge_and_punish()
	await check_ranged_pressure(Sandbox.Encounter.FLYER)
	await check_ranged_pressure(Sandbox.Encounter.SHOOTER)
	if failures == 0:
		print("PASS: limited guard/ranged staggers, counterattacks versus campaign lash spam, brute armor, dash dodge, recovery punish and cooldown expiry")
	quit(1 if failures > 0 else 0)
