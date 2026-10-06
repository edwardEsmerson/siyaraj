extends SceneTree
## Capture the approved cards and their transition to dialogue/combat in-engine.
## xvfb-run -a godot --path . --resolution 1920x1080 --fixed-fps 60 --script res://tools/boss_versus_shots.gd

const OUT: String = "res://docs/screenshots/boss-versus"


func _initialize() -> void:
	call_deferred("capture")


func ticks(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func save_shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT.path_join(name + ".png")))
	print("Saved ", name)


func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var navigation: Node = root.get_node("PlaytestNavigation")
	for level in ["forest", "river", "palace"]:
		navigation.start_level("res://scenes/main/%s_showdown.tscn" % level)
		await scene_changed
		await ticks(4)
		var comic: CanvasLayer = current_scene.get_node("CampaignFlow").comic
		assert(comic.visible and comic.splash_advance.visible)
		await save_shot(level + "-versus")
		var event := InputEventAction.new()
		event.action = &"ui_accept"
		event.pressed = true
		comic._unhandled_input(event)
		await ticks(4)
		if level == "river":
			assert(not comic.visible and current_scene.can_process())
		else:
			assert(comic.bubble.visible and not comic.splash_advance.visible)
		await save_shot(level + ("-combat" if level == "river" else "-dialogue"))
	print("Boss versus screenshots: PASS")
	quit(0)
