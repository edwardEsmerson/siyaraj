extends "res://tests/forest_check.gd"
## Real campaign placements and named attack input, including shared enemy hits.


func lash() -> void:
	Input.action_press(&"attack")
	await ticks(1)
	Input.action_release(&"attack")
	await ticks(24)


func run_checks() -> void:
	root.get_node("PlaytestNavigation").enemies_enabled = false
	change_scene_to_file("res://scenes/main/river.tscn")
	await scene_changed
	player = current_scene.player
	await ticks(4)
	freeze_encounters()
	var props := get_nodes_in_group("interactive_scenery")
	check(props.size() == 6, "Campaign river must contain four bells and two pottery targets")
	var checkpoints: Dictionary = current_scene.course.progress.duplicate(true)
	for prop: Sprite2D in props:
		var reactions := [0]
		prop.reacted.connect(func() -> void: reactions[0] += 1)
		var center: Vector2 = prop.to_global(prop.hit_center)
		var feet := Vector2(center.x - 34.0, prop.position.y + prop.texture.get_height() * 0.5)
		await place(feet)
		check(player.is_on_floor(), "Scenery must be reachable from its platform: %s" % prop.name)
		player.facing_direction = 1
		await ticks(3)
		check(reactions[0] == 0, "Walking beside scenery must not activate it")
		Input.action_press(&"attack")
		await ticks(1)
		Input.action_release(&"attack")
		check(reactions[0] == 0, "Lash windup must not hit scenery")
		await ticks(12)
		check(reactions[0] == 1, "Active lash must react once per swing: %s" % prop.name)
		check(prop._feedback_remaining > 0.0, "Accepted hit must show feedback")
		await ticks(12)
		await lash()
		check(reactions[0] == 1, "Cooldown must reject the next rapid swing")
		await ticks(40)
		check(prop.offset == prop._rest_offset, "Wobble must restore the original art offset")
		await lash()
		check(reactions[0] == 2, "Scenery must rearm after cooldown")
		await ticks(50)
		player.facing_direction = -1
		await lash()
		check(reactions[0] == 2, "A lash facing away must not hit scenery")
		await place(Vector2(center.x + 34.0, feet.y))
		player.facing_direction = -1
		await lash()
		check(reactions[0] == 3, "Scenery must respond from the other side")

	var bell: Sprite2D = props[0]
	var bell_hits := [0]
	bell.reacted.connect(func() -> void: bell_hits[0] += 1)
	var center: Vector2 = bell.to_global(bell.hit_center)
	await place(Vector2(center.x - 34.0, bell.position.y + bell.texture.get_height() * 0.5))
	player.facing_direction = 1
	await ticks(50)
	player.sparkler.start(1)
	player.sparkler.cancel()
	await ticks(15)
	check(bell_hits[0] == 0, "Cancelled windup must not hit scenery")
	bell.hide()
	await lash()
	check(bell_hits[0] == 0, "Hidden art must not react")
	bell.show()
	var enemy: CharacterBody2D = load("res://scenes/enemies/enemy.tscn").instantiate()
	current_scene.add_child(enemy)
	enemy.global_position = Vector2(center.x, player.global_position.y)
	enemy.set_physics_process(false)
	await ticks(50)
	enemy.attack.start(-1)
	await ticks(24)
	check(bell_hits[0] == 0, "Enemy swings must not activate optional scenery")
	var health_before: int = enemy.health
	await lash()
	check(enemy.health == health_before - 1, "Scenery in a lash must preserve one hit on an overlapping enemy")
	check(bell_hits[0] == 1, "The same lash must also hit the overlapping bell")
	check(current_scene.course.progress == checkpoints, "Decorative hits must not light checkpoints")
	check(current_scene.course.get_node("BridgePlanks").placed_count == 0, "Decorative hits must not build the bridge")

	# Run a real sound through the shared bounded pool, then drain its mixer.
	var audio: Node = root.get_node("AudioDirector")
	audio.enabled = true
	audio._cooldowns.clear()
	await ticks(50)
	bell.on_scenery_hit(1)
	check(audio.sfx_players.any(func(voice: AudioStreamPlayer) -> bool: return voice.playing and voice.bus == &"SFX" and voice.stream == load("res://assets/Audio/sfx/ui.wav")), "Bell must play the existing chime on the effects bus")
	var voices: int = audio.sfx_players.filter(func(voice: AudioStreamPlayer) -> bool: return voice.playing).size()
	bell.on_scenery_hit(1)
	check(audio.sfx_players.filter(func(voice: AudioStreamPlayer) -> bool: return voice.playing).size() == voices, "Repeated hits must not stack audio during cooldown")
	await audio.shutdown()
	print("Interactive scenery checks: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
