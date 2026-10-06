extends SceneTree
## Capture actual player animation states in-engine for C2 review.
## xvfb-run -a godot --path . --script res://tools/player_shots.gd

const OUT: String = "res://docs/screenshots/siya"
var player: CharacterBody2D
var visuals: Node2D


func _initialize() -> void:
	call_deferred("capture")


func ticks(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func press(action: StringName) -> void:
	Input.action_press(action)
	await ticks(1)
	Input.action_release(action)


func wait_pose(action: StringName, frame: int) -> void:
	var sprite: AnimatedSprite2D = player.get_node("Visuals/Sprite")
	for tick in 90:
		if sprite.animation == action and sprite.frame == frame:
			return
		await ticks(1)
	push_error("Pose never reached: %s/%d" % [action, frame])
	quit(1)


func reset_player() -> void:
	for action in [&"attack", &"skyshot", &"special", &"dash", &"jump", &"interact", &"move_left", &"move_right"]:
		Input.action_release(action)
	change_scene_to_file("res://scenes/dev/weapons_playground.tscn")
	await scene_changed
	player = current_scene.get_node("Player")
	visuals = player.get_node("Visuals")
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	await ticks(8)


func save_shot(label: String, closeup: bool = true) -> void:
	current_scene.process_mode = Node.PROCESS_MODE_DISABLED
	for layer in current_scene.find_children("*", "CanvasLayer", true, false):
		layer.hide()
	# Keep the review camera outside the frozen gameplay tree.
	var camera := Camera2D.new()
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_IDLE
	if closeup:
		camera.zoom = Vector2(4, 4)
		camera.position = player.global_position + Vector2(0, -28)
		for label_node in current_scene.find_children("*", "Label", true, false):
			label_node.hide()
	else:
		camera.position = current_scene.camera.global_position
	root.add_child(camera)
	camera.make_current()
	camera.force_update_scroll()
	for frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT.path_join(label + ".png")))
	print("Saved ", label)
	camera.free()
	current_scene.process_mode = Node.PROCESS_MODE_INHERIT
	current_scene.camera.make_current()


func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await reset_player()
	await save_shot("01-idle")
	Input.action_press("move_left")
	await ticks(8)
	await save_shot("02-run-left")
	await reset_player()
	await press("jump")
	await wait_pose(&"jump", 1)
	await save_shot("03-jump-rise")
	await wait_pose(&"jump", 2)
	await save_shot("04-jump-apex")
	await wait_pose(&"jump", 3)
	await save_shot("05-jump-fall")
	await reset_player()
	await press("dash")
	await save_shot("06-dash-launch")
	await wait_pose(&"dash", 1)
	await save_shot("07-dash-ride")
	await wait_pose(&"dash", 2)
	await save_shot("08-dash-brake")
	await reset_player()
	await press("attack")
	await ticks(4)
	await save_shot("09-lash-hit")
	await reset_player()
	await press("jump")
	await press("attack")
	await ticks(4)
	await save_shot("10-air-lash-hit")
	await reset_player()
	await press("skyshot")
	await save_shot("11-skyshot")
	await reset_player()
	Input.action_press("special")
	await ticks(16)
	await save_shot("12-chakri-charge")
	Input.action_release("special")
	await ticks(1)
	await save_shot("13-chakri-release")
	await reset_player()
	player.take_damage(1, Vector2.ZERO)
	await ticks(1)
	await save_shot("14-hurt")
	await reset_player()
	player.die()
	await ticks(17)
	await save_shot("15-death")
	await reset_player()
	visuals.play_story(&"talk")
	await ticks(1)
	await save_shot("16-talk")
	visuals.play_story(&"shocked")
	await ticks(1)
	await save_shot("17-shocked")

	var navigation: Node = root.get_node("PlaytestNavigation")
	navigation.enemies_enabled = false
	navigation.start_level("res://scenes/main/forest.tscn")
	await scene_changed
	player = current_scene.get_node("Player")
	var checkpoint: Area2D = current_scene.course.get_node("Checkpoints").get_child(0)
	player.position = checkpoint.position
	await ticks(12)
	await press("interact")
	await save_shot("18-light-diya")
	await ticks(18)
	current_scene.course.finished.emit()
	await ticks(2)
	await save_shot("19-victory")
	navigation.start_level("res://scenes/main/forest.tscn")
	await scene_changed
	player = current_scene.get_node("Player")
	await ticks(12)
	await save_shot("20-forest-gameplay", false)
	quit()
