extends SceneTree
## Screenshots of Robin in game: flying beside Siya, hinting, and perched on her head.
## xvfb-run -a godot --path . --resolution 1920x1080 -s tools/robin_shots.gd

const OUT := "res://docs/screenshots/robin/"


func _initialize() -> void:
	call_deferred("run")


func ticks(count: int) -> void:
	for frame in range(count):
		await physics_frame
		await process_frame


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("saved ", name)


func run() -> void:
	change_scene_to_file("res://scenes/main/river.tscn")
	await scene_changed
	await ticks(20)
	var robin: Node2D = current_scene.get_node("Robin")
	var sprite: AnimatedSprite2D = robin.get_node("Visuals/Sprite")
	Input.action_press(&"move_right")
	await ticks(45)
	await shot("ingame-fly")
	Input.action_release(&"move_right")
	robin.say("Mind the gap!")
	await ticks(8)
	await shot("ingame-hint")
	await ticks(420)
	await shot("ingame-perch")
	print("animation at end: ", sprite.animation)
	quit()
