extends SceneTree
## Robin follows, perches, points out one-shot hints, stays quiet in combat, reacts and obeys scripts.

const Robin = preload("res://scripts/companions/robin.gd")

var failures: int = 0
var player: CharacterBody2D
var robin: Node2D
var spoken: Array[String] = []


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
	for action in [&"move_right", &"move_left", &"jump", &"dash", &"interact"]:
		Input.action_release(action)


func hold(at: Vector2) -> void:
	player.state = player.State.NORMAL
	player.position = at
	player.velocity = Vector2.ZERO


func run_checks() -> void:
	Robin.forget_hints()
	var levels := ["res://scenes/main/forest.tscn", "res://scenes/main/river.tscn", "res://scenes/main/palace.tscn"]
	for index in range(5):
		# First traverse the campaign, then test fresh direct river/palace launches.
		if index >= 3:
			Robin.forget_hints()
		var path: String = levels[index if index < 3 else index - 2]
		change_scene_to_file(path)
		await scene_changed
		await ticks(2)
		check(current_scene.get_node_or_null("Robin") != null, "Robin must join every level: %s" % path)
		player = current_scene.player
		robin = current_scene.get_node("Robin")
		player.set_physics_process(false)
		current_scene.set_process(false)
		current_scene.checkpoint_guard.enabled = false
		for enemy in current_scene.course.get_node("Encounters").get_children():
			enemy.set_physics_process(false)
			enemy.collision_layer = 0
		var hints: Node2D = current_scene.course.get_node("RobinHints")
		check(hints.get_child_count() >= 6, "River and palace must guide each new hazard section")
		for area in hints.get_children():
			var already_seen: bool = Robin.seen_hints.has(area.hint_id())
			# Leave each bubble's cooldown intact, then enter the real trigger.
			hold(area.global_position + Vector2(-100, -20))
			await ticks(roundi((robin.hint_cooldown + area.duration + 1.0) * 60.0))
			hold(area.global_position + Vector2(0, -20))
			await ticks(3)
			if already_seen:
				check(robin.mode != Robin.Mode.POINT, "Later encounters must not repeat a learned topic: %s/%s" % [path, area.name])
			else:
				check(robin.mode == Robin.Mode.POINT and robin.bubble_label.text.replace("\n", " ") == area.text, "New lesson or progression hint must speak: %s/%s" % [path, area.name])
			check(Robin.seen_hints.has(area.hint_id()), "Authored hints must be remembered across death reloads")
			check(not robin.point_out(area.to_global(area.point), area.text, area.hint_id()), "Authored hints must only show once")
		var final_hint: Area2D = hints.get_children().back()
		var final_id: String = final_hint.hint_id()
		reload_current_scene()
		await scene_changed
		await ticks(2)
		player = current_scene.player
		robin = current_scene.get_node("Robin")
		current_scene.checkpoint_guard.enabled = false
		current_scene.set_process(false)
		player.set_physics_process(false)
		final_hint = current_scene.course.get_node("RobinHints").get_children().back()
		hold(final_hint.global_position + Vector2(0, -20))
		await ticks(3)
		check(final_hint.hint_id() == final_id and robin.mode != Robin.Mode.POINT, "Reloading a level must not repeat its final hint")
		if path.ends_with("palace.tscn"):
			check(final_hint.text.contains("Swaminathan"), "Palace approach must introduce Swaminathan")
	Robin.forget_hints()
	change_scene_to_file("res://scenes/main/forest.tscn")
	await scene_changed
	player = current_scene.player
	robin = current_scene.get_node("Robin")
	robin.spoke.connect(func(text: String) -> void: spoken.append(text))
	# Keep scene reloads out of the way; death reactions are checked directly.
	player.died.disconnect(current_scene._restart)
	current_scene.set_process(false)
	# These probes teleport freely to isolate companion behavior from route gates.
	current_scene.checkpoint_guard.enabled = false
	for enemy in current_scene.course.get_node("Encounters").get_children():
		enemy.set_physics_process(false)
	await ticks(10)
	check(current_scene.course.get_node("RobinHints/BossHint").text.contains("Khara"), "Forest approach must introduce Khara")
	check(get_first_node_in_group("robin") == robin, "Robin must register in the robin group")
	check(robin.global_position.distance_to(robin._follow_spot()) < 30.0, "Robin must start beside Siya")
	check(robin.sprite.visible and not robin.placeholder.visible and robin.sprite.animation in [&"fly", &"hover", &"hint"], "Robin's sprite art must replace the placeholder")

	# Standing still lets him perch on her head; moving sends him back into the air.
	await ticks(roundi((robin.perch_delay + 0.8) * 60.0))
	check(player.is_on_floor(), "Siya must be standing at spawn for the perch check")
	check(robin.mode == Robin.Mode.PERCH, "Robin must perch while Siya stands still")
	check(robin.global_position.distance_to(player.global_position + robin.perch_offset) < 1.0, "Perched Robin must sit on Siya's head")
	Input.action_press("move_right")
	await ticks(6)
	release_inputs()
	check(robin.mode == Robin.Mode.FOLLOW, "Robin must take off when Siya moves")

	# A dash-sized jump is caught up by flight; a room-sized jump snaps him over.
	player.set_physics_process(false)
	hold(player.position + Vector2(180, -60))
	await ticks(45)
	check(robin.global_position.distance_to(robin._follow_spot()) < 40.0, "Robin must catch up after a dash-length move")
	hold(Vector2(8650, 420))
	await ticks(2)
	check(robin.global_position.distance_to(robin._follow_spot()) < 20.0, "Robin must snap beside Siya after a long jump")
	player.set_physics_process(true)

	# Walking into a hint sends him to its spot with the text, once per session.
	var hint: Area2D = current_scene.course.get_node("RobinHints/DiyaHint")
	hold(hint.global_position + Vector2(0, -60))
	await ticks(3)
	check(robin.mode == Robin.Mode.POINT, "Entering a hint must send Robin to point it out")
	check(robin.bubble.visible and robin.bubble_label.text.replace("\n", " ") == hint.text, "The hint text must show in Robin's bubble")
	check(Robin.seen_hints.has(hint.hint_id()), "Shown hints must be remembered")
	await ticks(30)
	check(robin.global_position.distance_to(hint.to_global(hint.point)) < 40.0, "Robin must fly to the hint spot")
	hold(Vector2(8650, 420))
	await ticks(roundi(hint.duration * 60.0) + 5)
	check(robin.mode != Robin.Mode.POINT and not robin.bubble.visible, "Robin must return once the hint ends")
	hold(hint.global_position + Vector2(0, -60))
	await ticks(3)
	check(robin.mode != Robin.Mode.POINT, "A hint must not repeat")

	# Ordinary enemies, damage and long idle pauses must not produce chatter.
	var guard: Node2D = current_scene.course.get_node("Encounters/ClearingGuard")
	robin._bubble_remaining = 0.0
	spoken.clear()
	hold(guard.global_position + Vector2(-100, -20))
	await ticks(20)
	check(spoken.is_empty(), "Ordinary encounters must not get automatic warnings")
	player.take_damage(1, Vector2.ZERO)
	check(spoken.is_empty(), "Damage must not interrupt combat with chatter")
	player.state = player.State.NORMAL
	player.set_physics_process(false)
	var hint_id := "combat-deferred"
	var lesson := "Read this once it is safe."
	check(not robin.point_out(robin.global_position, lesson, hint_id), "Nearby live enemies must defer tutorials")
	check(not Robin.seen_hints.has(hint_id), "Deferred hints must remain unseen for a retry")

	# Exercise a real trigger while fighting, leaving, re-entering and recovering.
	hold(Vector2(8650, 420))
	await ticks(roundi((robin.hint_cooldown + 5.0) * 60.0))
	var pending: Area2D = current_scene.course.get_node("RobinHints/GuardHint")
	Robin.seen_hints.erase(pending.hint_id())
	var guard_position: Vector2 = guard.global_position
	guard.global_position = pending.global_position + Vector2(100, 0)
	hold(pending.global_position + Vector2(-100, -20))
	await ticks(2)
	hold(pending.global_position + Vector2(0, -20))
	await ticks(3)
	check(not Robin.seen_hints.has(pending.hint_id()), "Combat entry must not consume the first enemy introduction")
	hold(pending.global_position + Vector2(-100, -20))
	await ticks(3)
	guard.global_position = guard_position + Vector2(1000, 0)
	await ticks(3)
	check(not Robin.seen_hints.has(pending.hint_id()), "Leaving a blocked hint must cancel its pending bubble")
	hold(pending.global_position + Vector2(0, -20))
	await ticks(3)
	check(Robin.seen_hints.has(pending.hint_id()), "Re-entry after combat must show the first enemy introduction")
	guard.global_position = player.global_position + Vector2(100, 0)
	await ticks(3)
	check(not robin.bubble.visible, "Combat starting must clear the tutorial bubble")
	# An unseen tutorial entered during combat should speak without another entry
	# if Siya remains in its area when the enemy is gone.
	Robin.seen_hints.erase(pending.hint_id())
	hold(pending.global_position + Vector2(-100, -20))
	await ticks(roundi((robin.hint_cooldown + pending.duration + 1.0) * 60.0))
	hold(pending.global_position + Vector2(0, -20))
	await ticks(3)
	guard.global_position = guard_position + Vector2(1000, 0)
	await ticks(3)
	check(Robin.seen_hints.has(pending.hint_id()), "Remaining inside a hint must retry automatically after combat")
	guard.global_position = guard_position

	# Hurt, weapon use and spacing defer an unseen lesson without overwriting speech.
	hold(Vector2(8650, 420))
	await ticks(roundi((robin.hint_cooldown + pending.duration + 1.0) * 60.0))
	var bolt: CharacterBody2D = load("res://scenes/combat/enemy_projectile.tscn").instantiate()
	current_scene.add_child(bolt)
	bolt.set_physics_process(false)
	bolt.global_position = player.global_position + Vector2(100, -20)
	await ticks(2)
	check(not robin.point_out(robin.global_position, lesson, hint_id), "Hostile shots must defer tutorials even after the shooter is gone")
	bolt.queue_free()
	await ticks(2)
	var health_before: int = guard.health
	guard.global_position = player.global_position + Vector2(100, 0)
	guard.health = 0
	await ticks(2)
	check(not robin.combat_is_near(), "Defeated enemy bodies must not block tutorials")
	guard.global_position = guard_position
	guard.health = health_before
	await ticks(2)
	player.state = player.State.HURT
	check(not robin.point_out(robin.global_position, lesson, hint_id), "Hurt state must defer tutorials")
	player.state = player.State.NORMAL
	player.charging = true
	check(not robin.point_out(robin.global_position, lesson, hint_id), "Chakri charge must defer tutorials")
	player.charging = false
	player.sparkler.start(1)
	check(not robin.point_out(robin.global_position, lesson, hint_id), "Sparkler swing must defer tutorials")
	player.sparkler.cancel()
	check(robin.point_out(robin.global_position, lesson, hint_id), "An unseen lesson must be available once combat ends")
	player.state = player.State.DASH
	await ticks(2)
	check(robin.bubble.visible, "Traversal dashes without combat must not cut off a lesson")
	player.state = player.State.NORMAL
	check(not robin.point_out(robin.global_position, "Another lesson", "spacing-test"), "Tutorials must not overwrite a bubble")
	await ticks(220)
	check(not robin.point_out(robin.global_position, "Another lesson", "spacing-test"), "Tutorial cooldown must leave quiet time after speech")
	await ticks(500)
	check(robin.point_out(robin.global_position, "Another lesson", "spacing-test"), "Tutorials must resume after the cooldown")
	await ticks(900)
	hold(Vector2(80, 430))
	player.set_physics_process(true)
	await ticks(180)
	spoken.clear()
	await ticks(900)
	check(spoken.is_empty(), "Long idle pauses must stay quiet")
	player.die()
	check(spoken.size() == 1 and Robin.LINES[&"down"].has(spoken[0]), "Robin must still react to defeat")

	# Scripted control for cutscenes and the boss fight.
	var arrived := [false]
	robin.arrived.connect(func() -> void: arrived[0] = true)
	var target := robin.global_position + Vector2(200, -80)
	robin.fly_to(target, 400.0)
	check(robin.mode == Robin.Mode.SCRIPTED, "fly_to must take control of Robin")
	await ticks(50)
	check(arrived[0] and robin.global_position == target, "Scripted flight must reach its target and signal arrival")
	await ticks(30)
	check(robin.global_position == target, "Scripted Robin must hold still until released")
	check(not robin.point_out(target, "ignored", "scripted-test"), "Hints must not interrupt scripted scenes")
	robin.say("Story dialogue", 2.0)
	await ticks(3)
	check(robin.bubble.visible and robin.bubble_label.text == "Story dialogue", "Scripted speech must bypass combat and tutorial cooldowns")
	robin.release_control()
	check(robin.mode == Robin.Mode.FOLLOW, "release_control must hand Robin back to following")

	Robin.forget_hints()
	release_inputs()
	if failures == 0:
		print("PASS: Robin follows, perches, gives spaced one-shot lessons, stays quiet in combat, reacts and accepts scripted control")
	quit(1 if failures > 0 else 0)
