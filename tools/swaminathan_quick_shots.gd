extends SceneTree
## Two forced-state shots for review (no timers): the spent/exposed slump and a
## lightning strike mid-bolt.
##   xvfb-run -a godot --path . --resolution 1920x1080 -s tools/swaminathan_quick_shots.gd

const OUT: String = "res://docs/screenshots/swaminathan"


func _init() -> void:
	await process_frame
	change_scene_to_file("res://scenes/bosses/ravan/ravan_arena.tscn")
	await scene_changed
	var boss: Node2D = current_scene.get_node("Ravan")
	var player: CharacterBody2D = current_scene.get_node("Player")
	boss.auto_activate = false
	player.set_physics_process(false)
	player.position = Vector2(250, 430)
	boss.start_fight()
	await _frames(5)
	boss._banner_remaining = 0.0
	boss._spent_remaining = 5.0
	await _frames(20)
	await _save("15-spent.png")
	boss._spent_remaining = 0.0
	await _frames(5)
	boss.activate_head(0)
	boss.heads[0].remaining = 0.0
	await _frames(2)
	for hazard in get_nodes_in_group("ravan_hazards"):
		hazard.age = hazard.telegraph_time + 0.02
	await _frames(2)
	await _save("07-lightning-attack.png")
	quit()


func _frames(count: int) -> void:
	for frame in range(count):
		await physics_frame
		await process_frame
		var player: Node = current_scene.get_node_or_null("Player")
		if player != null and player.health > 0:
			player.health = player.max_health


func _save(file: String) -> void:
	paused = true
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT.path_join(file)))
	paused = false
