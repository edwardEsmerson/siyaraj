extends SceneTree
## Authored first encounters, shared lesson memory, remapped prompts and real missile dodges.
const Robin = preload("res://scripts/companions/robin.gd")
const Forest = preload("res://scripts/levels/forest.gd")

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
	for frame in count:
		await physics_frame
		await process_frame


func load_forest(room: StringName = &"") -> void:
	Forest.current_room = room
	Forest.room_spawn = Vector2(320, -2050)
	change_scene_to_file("res://scenes/main/forest.tscn")
	await scene_changed
	await ticks(2)
	player = current_scene.player
	robin = current_scene.get_node("Robin")
	robin.spoke.connect(func(line: String) -> void: spoken.append(line))
	current_scene.set_process(false)
	current_scene.checkpoint_guard.enabled = false
	for enemy in current_scene.course.get_node("Encounters").get_children():
		enemy.set_physics_process(false)
	player.set_physics_process(false)


## Stand in for the player having beaten the fights already passed on this route.
func clear_fights_before(hint: Area2D) -> void:
	for enemy in current_scene.course.get_node("Encounters").get_children():
		if enemy.get_meta("room", &"") == Forest.current_room and enemy.global_position.x < hint.global_position.x:
			enemy.free()
	await ticks(2)


func route_shooters() -> Array[Node]:
	var shooters: Array[Node] = []
	for enemy in current_scene.course.get_node("Encounters").get_children():
		if enemy.get_meta("room", &"") == Forest.current_room and enemy.scene_file_path.ends_with("ground_shooter.tscn"):
			shooters.append(enemy)
	return shooters


func enter_hint(hint: Area2D) -> void:
	player.position = hint.global_position + Vector2(-100, -20)
	await ticks(3)
	player.position = hint.global_position
	await ticks(3)


func check_lesson(room: StringName, hint_name: String, shooter_name: String) -> void:
	Robin.forget_hints()
	spoken.clear()
	await load_forest(room)
	var hint: Area2D = current_scene.course.get_node("RobinHints/" + hint_name)
	var shooter: CharacterBody2D = current_scene.course.get_node("Encounters/" + shooter_name)
	check(hint.global_position.x < shooter.global_position.x, "Lesson must precede the first shooter on this route")
	for other in route_shooters():
		check(other.global_position.x >= shooter.global_position.x, "%s must be the first shooter on this route, not %s" % [shooter_name, other.name])
	await clear_fights_before(hint)
	await enter_hint(hint)
	check(not robin.combat_is_near(), "Authored lesson must be outside live enemy and missile range")
	check(not shooter._can_see(player), "Shooter must not be able to fire during the first lesson")
	check(spoken.size() == 1 and robin.bubble.visible, "First encounter must present one contextual lesson")
	check(robin.bubble_label.text.replace("\n", " ") == hint.formatted_text(), "Bubble must show the resolved named Dash control")
	check(Robin.seen_hints.has("lesson:homing_dash"), "First presentation must remember the shared lesson")
	if "--capture-hint" in OS.get_cmdline_user_args():
		await ticks(35)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/siyaraj-%s-hint.png" % hint_name)
	await ticks(430)
	await enter_hint(hint)
	check(spoken.size() == 1, "Leaving and re-entering must not repeat the missile lesson")
	await load_forest(room)
	hint = current_scene.course.get_node("RobinHints/" + hint_name)
	await clear_fights_before(hint)
	await enter_hint(hint)
	check(spoken.size() == 1, "Death-style scene reload must retain lesson memory")
	await load_forest(&"" if room != &"" else &"RootChamber")
	hint = current_scene.course.get_node("RobinHints/" + ("ShooterHint" if room != &"" else "RootShooterHint"))
	await clear_fights_before(hint)
	await enter_hint(hint)
	check(spoken.size() == 1, "Taking the other route must not repeat the same lesson")


func check_deferral_and_prompts() -> void:
	Robin.forget_hints()
	spoken.clear()
	await load_forest()
	var hint: Area2D = current_scene.course.get_node("RobinHints/ShooterHint")
	await clear_fights_before(hint)
	var original: Array[InputEvent] = InputMap.action_get_events(&"dash")
	InputMap.action_erase_events(&"dash")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Q
	InputMap.action_add_event(&"dash", key)
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_X
	InputMap.action_add_event(&"dash", button)
	check(hint.formatted_text().contains("Dash [Q or X / Square]"), "Hint must use keyboard and gamepad remaps from InputMap")
	player.state = player.State.DASH
	await enter_hint(hint)
	check(spoken.is_empty() and not Robin.seen_hints.has(hint.hint_id()), "Active dash must defer the hint without consuming it")
	var bolt: CharacterBody2D = load("res://scenes/combat/homing_projectile.tscn").instantiate()
	current_scene.add_child(bolt)
	bolt.position = player.position + Vector2(100, -20)
	bolt.set_physics_process(false)
	await ticks(2)
	player.state = player.State.NORMAL
	await ticks(3)
	check(spoken.is_empty(), "A nearby homing missile must defer the pending lesson")
	bolt.queue_free()
	await ticks(3)
	check(spoken.size() == 1 and spoken[0].contains("Dash [Q or X / Square]"), "Pending lesson must retry with current bindings once dodging is over")
	InputMap.action_erase_events(&"dash")
	for event in original:
		InputMap.action_add_event(&"dash", event)


func fire_at_player(shooter: CharacterBody2D) -> CharacterBody2D:
	shooter._aim_direction = Vector2.RIGHT
	shooter._fire(player)
	var bolt: CharacterBody2D = get_nodes_in_group("homing_projectiles").back()
	bolt.position = player.position + Vector2(-42, -20)
	return bolt


func check_real_missile_dodge(room: StringName, shooter_name: String, at: Vector2) -> void:
	await load_forest(room)
	var shooter: CharacterBody2D = current_scene.course.get_node("Encounters/" + shooter_name)
	player.position = at
	player.facing_direction = -1
	player.set_physics_process(true)
	await ticks(4)
	var health_before: int = player.health
	var bolt := fire_at_player(shooter)
	Input.action_press(&"dash")
	await ticks(1)
	Input.action_release(&"dash")
	check(player.state == player.State.DASH and player.is_invulnerable(), "Named dash input must start actual dash invulnerability")
	await ticks(4)
	check(player.health == health_before, "Dashing through the campaign shooter's missile must prevent damage")
	check(is_instance_valid(bolt) and bolt.target == null, "Dodged missile must pass through and stop homing")
	await ticks(15)
	check(not player.is_invulnerable() and player.health == health_before, "Dodged missile must remain harmless after dash invulnerability expires")
	if is_instance_valid(bolt):
		bolt.queue_free()
	player.position = at
	player.velocity = Vector2.ZERO
	await ticks(4)
	bolt = fire_at_player(shooter)
	await ticks(14)
	check(player.health == health_before - shooter.projectile_damage, "The same campaign missile must damage Siya without a dash")
	check(not is_instance_valid(bolt), "An ordinary missile impact must consume the shot")


func run_checks() -> void:
	await check_lesson(&"", "ShooterHint", "ClearingRearShooter")
	await check_lesson(&"RootChamber", "RootShooterHint", "RootShooter")
	await check_deferral_and_prompts()
	await check_real_missile_dodge(&"", "HollowShooter", Vector2(7760, 430))
	await check_real_missile_dodge(&"RootChamber", "RootShooter", Vector2(2050, -1450))
	Robin.forget_hints()
	Forest.current_room = &""
	if failures == 0:
		print("PASS: first-route missile lessons, remapped Dash prompts, dodge/combat deferral, repeat suppression and real homing missile dash invulnerability")
	quit(1 if failures > 0 else 0)
