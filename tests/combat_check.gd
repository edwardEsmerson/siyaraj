extends SceneTree
## Exercises timed melee queries, enemy decisions, protection and real scene reloads.
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


func reset_arena(freeze_enemy: bool = true) -> void:
	for action in [&"attack", &"dash", &"move_left", &"move_right", &"jump"]:
		Input.action_release(action)
	Sandbox.next_encounter = Sandbox.Encounter.GUARD
	change_scene_to_file("res://scenes/dev/sandbox.tscn")
	await scene_changed
	player = current_scene.get_node("Player")
	enemy = current_scene.get_node("Enemy")
	enemy.set_physics_process(not freeze_enemy)
	await ticks(3)


func swing() -> void:
	Input.action_press("attack")
	await ticks(1)
	Input.action_release("attack")


func run_checks() -> void:
	await reset_arena()
	enemy.position.x = player.position.x + 48.0
	await ticks(1)
	await swing()
	check(enemy.health == 3, "Sparkler wind-up must not cause immediate damage")
	await ticks(8)
	check(enemy.health == 2, "Sparkler must hit the enemy in front during its active window")
	await ticks(6)
	check(enemy.health == 2, "Lingering overlap must not damage a target twice in one swing")
	await ticks(12)
	check(player.sparkler.phase == player.sparkler.Phase.RECOVERY, "Sparkler must still be recovering when the old cooldown would have ended")
	await swing()
	check(player.sparkler.phase == player.sparkler.Phase.RECOVERY and enemy.health == 2, "Attack presses during recovery must be rejected")
	await ticks(12)
	await swing()
	await ticks(40)
	check(enemy.health == 1, "A fresh swing must be allowed to hit the same enemy again")
	await swing()
	await ticks(40)
	check(not is_instance_valid(enemy), "Three sparkler swings must defeat the guard")
	check(current_scene.get_node("HUD/CombatStatus").text.contains("defeated"), "Enemy death must update the encounter feedback")

	await reset_arena()
	enemy.position.x = player.position.x - 48.0
	await ticks(1)
	await swing()
	await ticks(40)
	check(enemy.health == 3, "Right-facing sparkler must not damage an enemy behind Siya")
	Input.action_press("move_left")
	await ticks(1)
	Input.action_release("move_left")
	await swing()
	await ticks(40)
	check(enemy.health == 2, "Left-facing sparkler must hit to the left")

	await reset_arena()
	enemy.position.x = player.position.x + 48.0
	await ticks(1)
	Input.action_press("jump")
	await ticks(1)
	Input.action_release("jump")
	await swing()
	Input.action_press("dash")
	await ticks(1)
	Input.action_release("dash")
	await ticks(20)
	check(enemy.health == 3 and not player.sparkler.is_busy(), "Dash must cancel a pending swing")
	Input.action_press("move_right")
	await ticks(6)
	check(player.velocity.x > 0, "Movement must remain available after combat")
	Input.action_release("move_right")

	await reset_arena(false)
	# The arena places the guard inside detection range for immediate testing.
	await ticks(12)
	check(enemy.state == enemy.State.CHASE, "Nearby guard must approach Siya")
	var reached_attack := false
	for frame in range(140):
		await ticks(1)
		if enemy.attack.phase == enemy.attack.Phase.WINDUP:
			reached_attack = true
			break
	check(reached_attack and player.health == 3, "Guard must visibly wind up before damaging Siya")
	var before: int = player.health
	await ticks(35)
	check(player.health == before - 1, "Guard's active strike must damage Siya once")
	check(enemy.attack.phase == enemy.attack.Phase.RECOVERY, "Guard must recover after striking")

	await reset_arena()
	Input.action_press("jump")
	await ticks(1)
	Input.action_release("jump")
	Input.action_press("dash")
	await ticks(1)
	Input.action_release("dash")
	check(player.state == player.State.DASH, "Damage interruption test must start during an air dash")
	player.take_damage(1, Vector2(-100, -100))
	check(player.health == 3 and player.state == player.State.DASH, "Dash i-frames must ignore damage")
	await ticks(14)
	check(not player.is_invulnerable(), "Dash i-frames must expire shortly after the dash")
	player.take_damage(1, Vector2(-100, -100))
	check(player.health == 2 and player.state == player.State.HURT, "Damage must apply once dash i-frames end")
	player.take_damage(1, Vector2.ZERO)
	check(player.health == 2, "Repeated hits during protection must not drain health")
	await ticks(50)
	player.take_damage(1, Vector2.ZERO)
	check(player.health == 1, "Damage must resume after protection expires")
	await ticks(50)
	var old_scene := current_scene
	player.take_damage(1, Vector2.ZERO)
	await ticks(3)
	check(current_scene != old_scene, "Lethal damage must restart the encounter")
	player = current_scene.get_node("Player")
	enemy = current_scene.get_node("Enemy")
	check(player.health == 3 and enemy.health == 3, "Restart must restore both combatants' health")

	await check_dash_combat()

	if failures == 0:
		print("PASS: timed sparkler, one hit per swing, facing, enemy death, dash cancellation, chase/tell/strike/recovery, protection and death restart, ground dash i-frames, recovery dash-cancel and dash-attack")
	quit(1 if failures > 0 else 0)


func check_dash_combat() -> void:
	# A grounded dash cancels sparkler recovery.
	await reset_arena()
	enemy.position.x = player.position.x - 200.0
	await ticks(1)
	await swing()
	for frame in range(40):
		if player.sparkler.phase == player.sparkler.Phase.RECOVERY:
			break
		await ticks(1)
	check(player.sparkler.phase == player.sparkler.Phase.RECOVERY and player.is_on_floor(), "Dash-cancel test must reach grounded recovery")
	Input.action_press("dash")
	await ticks(1)
	Input.action_release("dash")
	check(player.state == player.State.DASH and not player.sparkler.is_busy(), "Ground dash must cancel sparkler recovery")

	# An attack pressed mid-dash swings as the dash ends.
	await reset_arena()
	var start_x := player.position.x
	enemy.position.x = start_x + 150.0
	await ticks(1)
	Input.action_press("dash")
	await ticks(2)
	Input.action_release("dash")
	await swing()
	check(player.state == player.State.DASH and not player.sparkler.is_busy(), "Attack pressed mid-dash must wait for the dash to end")
	await ticks(8)
	check(player.state == player.State.NORMAL and player.sparkler.is_busy(), "Buffered attack must start when the dash ends")
	await ticks(30)
	check(enemy.health == 2, "Dash-attack must hit the enemy ahead once")

	# Dashing through the guard's strike avoids damage, with no contact damage.
	await reset_arena(false)
	var reached_windup := false
	for frame in range(200):
		await ticks(1)
		if enemy.attack.phase == enemy.attack.Phase.WINDUP:
			reached_windup = true
			break
	check(reached_windup, "Dodge test must reach the guard's wind-up")
	while enemy.attack.phase == enemy.attack.Phase.WINDUP and enemy.attack._remaining > 0.1:
		await ticks(1)
	var side := signf(enemy.global_position.x - player.global_position.x)
	if side < 0.0:
		Input.action_press("move_left")
	else:
		Input.action_press("move_right")
	await ticks(1)
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_press("dash")
	await ticks(1)
	Input.action_release("dash")
	check(player.state == player.State.DASH, "Dodge dash must start during the guard's wind-up")
	await ticks(50)
	check(player.health == 3, "Dashing through the guard's strike must avoid all damage")
	check(signf(enemy.global_position.x - player.global_position.x) != side, "Dash must pass through the guard's body")
