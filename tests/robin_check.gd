extends SceneTree
## Robin follows, perches, points out one-shot hints, warns about enemies, reacts and obeys scripts.

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
	for path in ["res://scenes/main/river.tscn", "res://scenes/main/palace.tscn"]:
		change_scene_to_file(path)
		await scene_changed
		await ticks(2)
		check(current_scene.get_node_or_null("Robin") != null, "Robin must join every level: %s" % path)
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
	check(get_first_node_in_group("robin") == robin, "Robin must register in the robin group")
	check(robin.global_position.distance_to(robin._follow_spot()) < 30.0, "Robin must start beside Siya")
	check(robin.sprite.visible and not robin.placeholder.visible and robin.sprite.animation == &"fly", "Robin's sprite art must replace the placeholder")

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

	# The first sight of a live enemy gets one warning.
	var guard: Node2D = current_scene.course.get_node("Encounters/ClearingGuard")
	robin._warned.erase(guard.get_instance_id())
	robin._bubble_remaining = 0.0
	robin._warn_remaining = 0.0
	spoken.clear()
	hold(guard.global_position + Vector2(-150, -60))
	await ticks(20)
	check(robin._warned.has(guard.get_instance_id()), "Robin must notice a nearby enemy")
	check(spoken.size() == 1 and Robin.LINES[&"enemy"].has(spoken[0]), "Robin must warn about a new enemy once")

	# Reactions to damage and defeat.
	spoken.clear()
	robin._reaction_remaining = 0.0
	player.take_damage(1, Vector2.ZERO)
	check(spoken.size() == 1 and Robin.LINES[&"hurt"].has(spoken[0]), "Robin must react when Siya is hurt")
	player.die()
	check(spoken.size() == 2 and Robin.LINES[&"down"].has(spoken[1]), "Robin must react when Siya goes down")

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
	robin.release_control()
	check(robin.mode == Robin.Mode.FOLLOW, "release_control must hand Robin back to following")

	Robin.forget_hints()
	release_inputs()
	if failures == 0:
		print("PASS: Robin follows, perches, gives one-shot hints, warns, reacts and accepts scripted control")
	quit(1 if failures > 0 else 0)
