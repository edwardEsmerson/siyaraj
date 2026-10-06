extends SceneTree
## Verify approved art against real combat events, defeat lifetimes and the ending.
const Sandbox = preload("res://scripts/dev/sandbox.gd")
var failures: int = 0


func _initialize() -> void:
	call_deferred("run_checks")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func ticks(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func run_checks() -> void:
	for encounter in [Sandbox.Encounter.GUARD, Sandbox.Encounter.BRUTE, Sandbox.Encounter.SHOOTER, Sandbox.Encounter.FLYER]:
		Sandbox.next_encounter = encounter
		change_scene_to_file("res://scenes/dev/sandbox.tscn")
		await scene_changed
		await ticks(8)
		var enemy: CharacterBody2D = current_scene.enemy
		var player: CharacterBody2D = current_scene.player
		var visuals: Node2D = enemy.get_node("Visuals")
		var sprite: AnimatedSprite2D = visuals.sprite
		check(sprite.sprite_frames != null and sprite.scale == Vector2(0.5, 0.5), "Every live enemy must use native cast art at scale 0.5")
		check(not enemy.body.visible, "Cast art must replace the placeholder")
		player.set_physics_process(false)
		player.died.disconnect(current_scene._restart)
		var melee: Node = enemy.get_node_or_null("MeleeAttack")
		if melee != null:
			enemy.set_physics_process(false)
			player.position = enemy.position + Vector2(45, 0)
			melee.start(1)
			var saw_active := false
			var saw_recovery := false
			for frame in 140:
				await ticks(1)
				if melee.phase == melee.Phase.WINDUP:
					check(sprite.animation == &"attack" and sprite.frame < 2, "Melee anticipation must precede the real hit window")
				elif melee.phase == melee.Phase.ACTIVE:
					saw_active = true
					check(sprite.animation == &"attack" and sprite.frame == 2, "Melee contact pose must coincide with real damage")
				elif melee.phase == melee.Phase.RECOVERY:
					saw_recovery = true
					check(sprite.frame == 3, "Melee recovery must show the withdrawn pose")
				else:
					break
			check(saw_active and saw_recovery and player.health < player.max_health, "Animated attacks must still hit and recover")
			melee.start(-1)
			await ticks(1)
			check(visuals.scale.x == -1.0 and enemy.scale == Vector2.ONE, "Facing art must never mirror physics or hitbox nodes")
		else:
			player.position = enemy.position + Vector2(-120, 0)
			var shots := [0]
			enemy.shot_fired.connect(func() -> void: shots[0] += 1)
			var saw_charge := false
			for frame in 140:
				await ticks(1)
				if enemy.state == enemy.State.CHARGING:
					saw_charge = true
					check(sprite.animation == &"charge", "Ranged anticipation must match actual charge")
				if shots[0] > 0:
					break
			check(saw_charge and shots[0] == 1, "Ranged art must follow exactly one real projectile release")
			check(sprite.animation == (&"fire" if encounter == Sandbox.Encounter.SHOOTER else &"dive"), "The actual shot must show its release pose")
			check(visuals.scale.x == -1.0, "Ranged pose must face its target")
			enemy.take_damage(1, Vector2.ZERO)
			await ticks(1)
			check(enemy.state == enemy.State.HURT and sprite.animation not in [&"fire", &"dive", &"charge"], "Interrupted ranged attacks must clear their release pose")
		enemy.take_damage(100, Vector2.ZERO)
		await ticks(2)
		check(not is_instance_valid(enemy), "Art must preserve immediate gameplay enemy removal")
		var corpses := get_nodes_in_group("enemy_defeat_visuals")
		check(corpses.size() == 1 and corpses[0].get_child(0).animation == &"death", "Defeat must leave one harmless death animation")
		check(corpses[0].get_child_count() == 1 and corpses[0].get_child(0) is AnimatedSprite2D, "Defeat art must have no collision or attack")
		await ticks(90)
		check(get_nodes_in_group("enemy_defeat_visuals").is_empty(), "Defeat art must clean itself up")
	Sandbox.next_encounter = -1

	change_scene_to_file("res://scenes/bosses/khara_arena.tscn")
	await scene_changed
	await ticks(4)
	var boss: CharacterBody2D = current_scene.get_node("TestCourse/Boss")
	
	boss.set_physics_process(false)
	boss.facing = -1
	boss._update_feedback()
	boss.start_slam(-1)
	boss.state_remaining = boss.current_slam_windup() * 0.25
	boss._update_feedback()
	await ticks(1)
	check(boss.art.animation == &"slam_windup" and boss.art.frame == 1, "Khara anticipation must follow his own windup progress")
	check(boss.gada.position == Vector2(-13, -103.5) and is_equal_approx(boss.gada.rotation, deg_to_rad(-70.0)), "Gada must attach to the reviewed raised hand")
	check(boss.visual.scale.x == -1 and boss.scale == Vector2.ONE, "Khara body and gada must mirror together")
	boss._enter(boss.State.SLAM_ACTIVE, boss.slam_active)
	boss._update_feedback()
	await ticks(1)
	check(boss.art.animation == &"slam_impact" and boss.gada.position == Vector2(27.5, -15), "Gada contact must use the impact registration")
	boss._enter(boss.State.LADI_CAST, boss.ladi_cast_time)
	boss._update_feedback()
	await ticks(1)
	check(boss.art.animation == &"ladi_cast" and not boss.gada.visible, "Khara must free his hands when lighting ladi")
	boss._enter_phase_two()
	boss._update_feedback()
	await ticks(1)
	check(boss.art.animation == &"phase_shift_roar", "Phase two must play its distinct roar")
	boss.take_damage(100, Vector2.ZERO)
	await ticks(1)
	check(boss.art.animation == &"death" and not boss.gada.visible and boss.collision_layer == 0, "Khara defeat must show death and disable damage immediately")
	boss.set_physics_process(true)
	await ticks(75)
	check(boss.art.frame == 3 and boss.visual.rotation == 0.0, "Khara must hold his drawn fallen pose without a second rotation")
	await ticks(15)
	check(not is_instance_valid(boss), "Khara must retain the existing 1.4-second defeat lifetime")

	change_scene_to_file("res://scenes/main/ending.tscn")
	await scene_changed
	await ticks(4)
	var raj: AnimatedSprite2D = current_scene.get_node("Center/Content/RajStage/Raj")
	check(raj.animation == &"sulk" and raj.scale == Vector2(0.5, 0.5), "Ending must introduce Raj at native scale")
	await ticks(80)
	check(raj.animation == &"dramatic", "Ending must show Raj's dramatic reaction")
	await ticks(65)
	check(raj.animation == &"freed", "Ending must complete with Raj freed")
	check(current_scene.get_node("Center/Content/ReturnButton").has_focus(), "Rescue animation must preserve menu controls")
	print("Cast gameplay checks: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)
