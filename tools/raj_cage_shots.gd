extends SceneTree
## Renders Raj's cage in the palace showdown for art review:
##   xvfb-run -a godot --path . --resolution 1920x1080 -s tools/raj_cage_shots.gd
## Writes docs/screenshots/raj-cage/: the arena with the cage closed, the cage open and 3x close-ups of the closed and open cage.

const SHOWDOWN: String = "res://scenes/main/palace_showdown.tscn"
const OUT: String = "res://docs/screenshots/raj-cage"
## Area around the cage in 960 x 540 game units (chain, cage and landing spot).
const CLOSE: Rect2 = Rect2(722, 130, 180, 200)


func _init() -> void:
	await process_frame
	root.get_node("PlaytestNavigation").boss_introduction_seen = true
	change_scene_to_file(SHOWDOWN)
	await scene_changed
	var arena: Node = current_scene
	var cage: Node2D = arena.get_node("RajCage")
	var boss: Node2D = arena.get_node("Ravan")
	boss.auto_activate = false
	await _frames(30)
	_save(_grab(), "01-showdown-closed.png")
	_save(_close_up(), "02-closed-3x.png")
	cage.release()
	await _frames(4)
	_save(_grab(), "04-showdown-open.png")
	_save(_close_up(), "05-open-3x.png")
	print("raj_cage_shots: saved images in %s" % OUT)
	quit()


func _close_up() -> Image:
	var screen := _grab()
	var ratio: float = screen.get_width() / 960.0
	var image := screen.get_region(Rect2i(CLOSE.position * ratio, CLOSE.size * ratio))
	image.resize(image.get_width() * 3, image.get_height() * 3, Image.INTERPOLATE_NEAREST)
	return image


func _frames(count: int) -> void:
	for frame: int in count:
		await physics_frame
		await process_frame
	await RenderingServer.frame_post_draw


func _grab() -> Image:
	return root.get_texture().get_image()


func _save(image: Image, file: String) -> void:
	image.save_png(ProjectSettings.globalize_path(OUT.path_join(file)))
