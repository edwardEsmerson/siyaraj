extends SceneTree
## Screenshots the checkpoint diyas, unlit and lit, in each level for art review:
##   xvfb-run -a godot --path . --resolution 1920x1080 -s tools/diya_shots.gd
## Writes docs/screenshots/diyas/<biome>-{unlit,lit}.png (game view) and <biome>-{unlit,lit}-zoom.png (4x).

const OUT: String = "res://docs/screenshots/diyas"
const LEVELS: Dictionary = {
	"forest": "res://scenes/levels/forest.tscn",
	"river": "res://scenes/levels/river.tscn",
	"palace": "res://scenes/levels/palace.tscn",
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await process_frame
	for biome: String in LEVELS:
		var level: Node2D = load(LEVELS[biome]).instantiate()
		for enemy: Node in level.get_node("Encounters").get_children():
			enemy.free()
		root.add_child(level)
		level.set_physics_process(false)  # the shots set the lit state themselves
		for label: Node in level.find_children("*", "Label", true, false):
			label.visible = false
		var camera := Camera2D.new()
		level.add_child(camera)
		camera.make_current()
		var diya: Area2D = level.get_node("Checkpoints").get_child(0)
		for lit: bool in [false, true]:
			diya.get_node("Flame").visible = lit
			for zoom: int in [1, 4]:
				camera.zoom = Vector2(zoom, zoom)
				camera.position = diya.position + (Vector2(0, -160) if zoom == 1 else Vector2(0, -30))
				for i in 6:
					await process_frame
				await RenderingServer.frame_post_draw
				var path: String = OUT.path_join("%s-%s%s.png" % [biome, "lit" if lit else "unlit", "-zoom" if zoom > 1 else ""])
				root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
				print("saved ", path)
		level.free()
	quit()
