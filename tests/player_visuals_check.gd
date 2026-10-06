extends SceneTree
## Real weapon/interaction events plus deterministic pose selection at physics boundaries.

var failures: int = 0
var player: CharacterBody2D
var visuals: Node2D
var sprite: AnimatedSprite2D


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


func press(action: StringName) -> void:
	Input.action_press(action)
	await ticks(1)
	Input.action_release(action)


func reset_player() -> void:
	for action in [&"attack", &"skyshot", &"special", &"dash", &"jump", &"interact", &"move_left", &"move_right"]:
		Input.action_release(action)
	change_scene_to_file("res://scenes/dev/weapons_playground.tscn")
	await scene_changed
	player = current_scene.get_node("Player")
	visuals = player.get_node("Visuals")
	sprite = visuals.get_node("Sprite")
	await ticks(8)


func run_checks() -> void:
	var navigation: Node = root.get_node("PlaytestNavigation")
	await reset_player()
	check(sprite.sprite_frames.get_animation_names().size() == 15, "Player must load all 15 approved Siya animations")
	check(sprite.scale == Vector2(0.5, 0.5), "Player art must keep scale 0.5")
	check(player.get_node("CollisionShape2D").shape.size == Vector2(24, 40), "Art integration must preserve the 24x40 collider")
	check(not player.get_node("Body").visible and not player.get_node("FacingMarker").visible and not player.get_node("Name").visible, "Player must hide grey body, eye and name placeholders")
	check(sprite.animation == &"idle", "Grounded rest must show idle")
	Input.action_press("move_left")
	await ticks(8)
	check(sprite.animation == &"run" and sprite.flip_h and sprite.offset.x == -16.0, "Left run must mirror around the foot anchor")
	Input.action_release("move_left")
	await ticks(10)
	check(sprite.animation == &"idle", "Stopping must return to idle")

	await reset_player()
	await press("jump")
	check(sprite.animation == &"jump" and sprite.frame == 0, "Jump launch must use takeoff pose")
	var saw_rise := false
	var saw_apex := false
	var saw_fall := false
	var saw_land := false
	for frame in 60:
		await ticks(1)
		if sprite.animation == &"jump":
			saw_rise = saw_rise or sprite.frame == 1
			saw_apex = saw_apex or sprite.frame == 2
			saw_fall = saw_fall or sprite.frame == 3
			saw_land = saw_land or sprite.frame == 4
	check(saw_rise and saw_apex and saw_fall and saw_land, "Jump must choose rise, apex, fall and landing from real physics")
	await press("dash")
	check(sprite.animation == &"dash" and sprite.frame == 0, "Ground dash must show launch")
	await ticks(3)
	check(sprite.animation == &"dash" and sprite.frame == 1, "Dash must show ride while movement is active")
	var saw_brake := false
	for frame in 12:
		await ticks(1)
		saw_brake = saw_brake or (sprite.animation == &"dash" and sprite.frame == 2)
	check(saw_brake, "Dash completion must show brake without extending movement")
	await ticks(12)
	await press("jump")
	await press("dash")
	check(sprite.animation == &"dash", "Air dash must use the same rocket poses")

	await reset_player()
	var dummy: CharacterBody2D = current_scene.get_node("SparklerDummy")
	dummy.set_physics_process(false)
	player.position.x = dummy.position.x - 42
	await press("attack")
	check(sprite.animation == &"lash" and sprite.frame == 0 and dummy.health == 12, "Lash windup must show frame 1 before damage")
	var checked_hit := false
	for frame in 24:
		await ticks(1)
		if player.sparkler.phase == player.sparkler.Phase.ACTIVE:
			check(sprite.animation == &"lash" and sprite.frame == 1, "Every active ground lash tick must use hit frame 2")
			checked_hit = checked_hit or dummy.health == 11
		elif player.sparkler.phase == player.sparkler.Phase.RECOVERY:
			check(sprite.frame == 2, "Ground lash recovery must show follow-through")
	check(checked_hit and dummy.total_hits == 1, "Visual lash must retain exactly one actual hit")
	player.position = Vector2(dummy.position.x - 42, 420)
	await ticks(1)
	await press("attack")
	check(sprite.animation == &"air_lash" and sprite.frame == 0, "Air lash must start with windup")
	await ticks(4)
	check(player.sparkler.phase == player.sparkler.Phase.ACTIVE and sprite.animation == &"air_lash" and sprite.frame == 1, "Air lash must hit on frame 2 during the real active window")
	await press("dash")
	check(not player.sparkler.is_busy() and sprite.animation == &"dash", "Dash must cancel both lash damage and its pose")

	await reset_player()
	await press("skyshot")
	check(sprite.animation == &"skyshot" and sprite.frame == 1 and player.skyshot_ammo == 4, "Actual shot must show release pose immediately and consume one ammo")
	await ticks(15)
	check(sprite.animation == &"skyshot" and sprite.frame == 2, "Shot recovery must show recover pose")
	await ticks(20)
	Input.action_press("special")
	await ticks(8)
	check(sprite.animation == &"chakri_charge", "Held K must loop charge art")
	var charge_before: float = player.charge_time
	await press("dash")
	check(sprite.animation == &"dash" and player.charging, "Dash must temporarily override charge art while preserving charge")
	await ticks(12)
	check(sprite.animation == &"chakri_charge" and player.charge_time >= charge_before, "Charge art and progress must resume after dash")
	Input.action_release("special")
	await ticks(1)
	check(sprite.animation == &"chakri_release" and sprite.frame == 1 and player.chakri_cooldown_remaining > 0.0, "K release must show the real spin event")
	player.take_damage(1, Vector2.ZERO)
	await ticks(1)
	check(sprite.animation == &"hurt" and not player.charging, "Damage must override weapons and play hurt")
	await ticks(8)
	check(is_equal_approx(sprite.modulate.a, 0.4) or is_equal_approx(sprite.modulate.a, 1.0), "Hurt protection must retain the existing blink levels")
	var saw_dim := false
	var saw_bright := false
	for frame in 30:
		await ticks(1)
		saw_dim = saw_dim or is_equal_approx(sprite.modulate.a, 0.4)
		saw_bright = saw_bright or is_equal_approx(sprite.modulate.a, 1.0)
	check(saw_dim and saw_bright, "Protected sprite must actually blink between both levels")

	await reset_player()
	visuals.play_story(&"talk")
	await ticks(1)
	check(sprite.animation == &"talk", "Story API must support talking")
	visuals.play_story(&"shocked")
	await ticks(1)
	check(sprite.animation == &"shocked", "Story API must support shocked hold")
	await press("jump")
	check(sprite.animation == &"jump", "Movement must immediately override story poses")
	player.die()
	await ticks(1)
	check(sprite.animation == &"death" and sprite.frame == 0 and sprite.modulate == Color.WHITE, "Death must override other poses and stay visible")
	await ticks(17)
	check(sprite.animation == &"death" and sprite.frame == 2, "Death must reach and hold its fallen pose before restart")

	for level in ["forest", "river", "palace"]:
		navigation.enemies_enabled = false
		navigation.start_level("res://scenes/main/%s.tscn" % level)
		await scene_changed
		player = current_scene.get_node("Player")
		visuals = player.get_node("Visuals")
		sprite = visuals.get_node("Sprite")
		var checkpoint: Area2D = current_scene.course.get_node("Checkpoints").get_child(0)
		player.position = checkpoint.position
		await ticks(12)
		await press("interact")
		check(checkpoint.get_node("Flame").visible and sprite.animation == &"light_diya", "%s successful E interaction must show diya lighting" % level)
		await ticks(18)
		visuals.play_story(&"talk")
		await press("interact")
		check(sprite.animation == &"talk", "Already lit diya must not replay the lighting animation")
		visuals.clear_story()
		current_scene.course.finished.emit()
		await ticks(2)
		check(sprite.animation == &"victory", "Level completion must celebrate when grounded and still")

	navigation.enemies_enabled = true
	for level in ["forest", "river", "palace"]:
		navigation.start_level("res://scenes/main/%s_showdown.tscn" % level)
		await scene_changed
		var flow: CanvasLayer = current_scene.get_node("CampaignFlow")
		if flow.comic != null:
			for panel in flow.introduction.size():
				var advance := InputEventAction.new()
				advance.action = &"ui_accept"
				advance.pressed = true
				flow.comic._unhandled_input(advance)
		player = current_scene.get_node("Player")
		sprite = player.get_node("Visuals/Sprite")
		var boss: Node2D = current_scene.get_node("Ravan" if level == "palace" else "TestCourse/Boss")
		boss.set_physics_process(false)
		await ticks(8)
		if level == "palace":
			boss.start_fight()
			boss.set_physics_process(true)
			await ticks(2)
			boss.set_head_count(1)
		boss.take_damage(999, Vector2.ZERO)
		check(sprite.animation != &"victory", "%s must show the boss dying before Siya celebrates" % level)
		boss.set_physics_process(true)
		await boss.died
		if flow.comic != null and flow.comic.visible:
			check(not player.can_process(), "Aftermath dialogue must freeze the player's animation clock")
			for panel in flow.comic._panels.size():
				var advance := InputEventAction.new()
				advance.action = &"ui_accept"
				advance.pressed = true
				flow.comic._unhandled_input(advance)
		await ticks(2)
		check(sprite.animation == &"victory", "%s boss death must trigger Siya's victory animation after dialogue" % level)
	print("Player visuals checks: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
