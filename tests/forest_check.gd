extends SceneTree
## Traverse every authored route connection with real physics and validate manual diyas.

var failures: int = 0
var player: CharacterBody2D

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

func place(at: Vector2) -> void:
	release_inputs()
	player.state = player.State.NORMAL
	player.health = player.max_health
	player.position = at
	player.velocity = Vector2.ZERO
	player.dash_available = true
	player._jump_buffer_remaining = 0
	player._coyote_remaining = 0
	player._dash_remaining = 0
	await ticks(4)

func freeze_encounters() -> void:
	# Traversal and isolated weapon probes deliberately bypass route progression.
	if current_scene.checkpoint_guard != null:
		current_scene.checkpoint_guard.enabled = false
	for enemy in current_scene.course.get_node("Encounters").get_children():
		enemy.set_physics_process(false)

func bounds(platform: Node2D) -> Rect2:
	var collider: CollisionShape2D = platform.get_node("CollisionShape2D")
	return Rect2(collider.global_position - collider.shape.size * 0.5, collider.shape.size)

func traverse(source: Node2D, target: Node2D) -> bool:
	var start := bounds(source)
	var end := bounds(target)
	var direction := 1 if end.get_center().x > start.get_center().x else -1
	var edge := start.end.x if direction == 1 else start.position.x
	var gap := end.position.x - start.end.x if direction == 1 else start.position.x - end.end.x
	var delays := [14, 20, -1, 8] if gap > 110 else [-1, 14, 20, 8]
	for delay in delays:
		for margin in [24.0, 12.0, 36.0]:
			await place(Vector2(edge - direction * (margin + 14), start.position.y))
			player.facing_direction = direction
			Input.action_press("move_right" if direction == 1 else "move_left")
			await ticks(6)
			Input.action_press("jump")
			for frame in range(75):
				if frame == 1:
					Input.action_release("jump")
				if frame == delay:
					Input.action_press("dash")
				if direction * (player.position.x - end.get_center().x) > -8:
					Input.action_release("move_right" if direction == 1 else "move_left")
				await ticks(1)
				if frame > 1 and player.is_on_floor() and absf(player.position.y - end.position.y) < 1 and player.position.x > end.position.x - 10 and player.position.x < end.end.x + 10:
					release_inputs()
					check(player.dash_available, "Landing must restore dash at %s" % target.name)
					return true
				if player.state == player.State.DEAD or player.position.y > 580:
					break
	release_inputs()
	return false

func press_interact() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	Input.parse_input_event(event)
	await ticks(2)
	event = InputEventKey.new()
	event.physical_keycode = KEY_E
	Input.parse_input_event(event)
	await ticks(1)

func run_checks() -> void:
	var forest_script = load("res://scripts/levels/forest.gd")
	forest_script.checkpoint_x = 160.0
	forest_script.lit_checkpoints.clear()
	change_scene_to_file("res://scenes/main/forest.tscn")
	await scene_changed
	player = current_scene.player
	await ticks(4)
	freeze_encounters()
	check(player.is_on_floor(), "Forest must spawn grounded")
	check(current_scene.camera.limit_right == 21600, "Expanded forest must span 21600 pixels")
	# Disable reloads only during isolated connection probes; real death is checked below.
	player.died.disconnect(current_scene._restart)
	current_scene.set_process(false)
	var route: Array[Node] = current_scene.course.get_node("Terrain").get_children()
	route.sort_custom(func(a: Node, b: Node) -> bool: return a.get_meta("route_order") < b.get_meta("route_order"))
	check(route.size() >= 55, "Forest must include a substantial traversal route")
	for index in range(route.size() - 1):
		var passed := await traverse(route[index], route[index + 1])
		check(passed, "Unreachable route connection: %s -> %s" % [route[index].name, route[index + 1].name])
		print("ROUTE %s -> %s: %s" % [route[index].name, route[index + 1].name, "PASS" if passed else "FAIL"])
	current_scene.completed = false
	current_scene.course.completed = false
	current_scene.set_process(true)
	player.died.connect(current_scene._restart)
	var checkpoints: Array[Node] = current_scene.course.get_node("Checkpoints").get_children()
	for checkpoint in checkpoints:
		await place(checkpoint.position)
		check(player.is_on_floor(), "Every diya must stand on reachable solid ground")
		check(not current_scene.course.lit_checkpoints.has(checkpoint.name), "Walking past a diya must not light it")
	check(current_scene.course.checkpoint_x == 160, "Walking past all diyas must leave spawn unchanged")
	await place(Vector2(2300, 430))
	Input.action_press("interact")
	await ticks(3)
	player.position = Vector2(2450, 430)
	await ticks(4)
	check(current_scene.course.checkpoint_x == 160, "Holding E before entering range must not auto-light")
	Input.action_release("interact")
	await ticks(1)
	Input.action_press("jump")
	await ticks(3)
	await press_interact()
	check(current_scene.course.checkpoint_x == 160, "Diya interaction must require grounded normal movement")
	await place(Vector2(2450, 430))
	check(current_scene.course.get_node("Checkpoints/ClearingDiya/Prompt").text.contains("E:"), "Nearby unlit diya must show the interaction prompt")
	await press_interact()
	check(current_scene.course.checkpoint_x == 2450, "E must light and secure the nearby diya")
	check(current_scene.course.get_node("Checkpoints/ClearingDiya/Flame").visible, "Lit diya must visibly change")
	await place(Vector2(18100, 430))
	await press_interact()
	check(current_scene.course.checkpoint_x == 18100, "Later explicit interaction must advance checkpoint progress")
	await place(Vector2(6800, 430))
	await press_interact()
	check(current_scene.course.checkpoint_x == 18100, "Lighting an older diya must not rewind progress")
	var old_scene := current_scene
	player.die()
	await ticks(30)
	check(current_scene != old_scene, "Death must reload the level")
	player = current_scene.player
	check(absf(player.position.x - 18100) < 1 and player.health == 3, "Death must restore the latest secured checkpoint and health")
	check(not current_scene.course.get_node("Checkpoints/RidgeDiya/Flame").visible, "Skipped diyas must remain unlit after reload")
	await place(Vector2(21400, 430))
	check(current_scene.completed, "Riverbank must still finish without enemies")
	var event := InputEventAction.new()
	event.action = "restart"
	event.pressed = true
	Input.parse_input_event(event)
	await ticks(4)
	player = current_scene.player
	check(absf(player.position.x - 160) < 1 and current_scene.course.lit_checkpoints.is_empty(), "R must clear all checkpoint progress")
	release_inputs()
	if failures == 0:
		print("PASS: every forest route connection, manual E checkpoints, hold/air restrictions, death recovery, completion and replay")
	quit(1 if failures > 0 else 0)

