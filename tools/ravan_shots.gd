extends SceneTree
## Renders Ravan's body states and a mid-fight frame for art review:
##   xvfb-run -a godot --path . --resolution 960x540 -s tools/ravan_shots.gd
## Writes docs/screenshots/swaminathan_states.png (a contact sheet of states 10 to 0,
## the real state_NN.png art where it exists, else the fallback),
## swaminathan_fight.png (head telegraphs and the heads-remaining UI) and
## swaminathan_sever.png (the beat when a head is severed).

const ARENA: String = "res://scenes/bosses/ravan/ravan_arena.tscn"
const OUT: String = "res://docs/screenshots"
## Area around Ravan in the 960 x 540 arena, scaled up 2x on the sheet.
const CROP: Rect2i = Rect2i(340, 225, 280, 220)
const COLUMNS: int = 4


func _init() -> void:
	await process_frame
	change_scene_to_file(ARENA)
	await scene_changed
	var arena: Node = current_scene
	var boss: Node2D = arena.get_node("Ravan")
	var player: CharacterBody2D = arena.get_node("Player")
	boss.auto_activate = false
	boss.start_fight()
	player.set_physics_process(false)
	player.position = Vector2(300, 430)
	await _frames(3)
	boss._banner_remaining = 0.0
	# The states sheet is for judging the body, so the busy backdrop goes.
	var scenery: Array[Node] = [arena.get_node("HUD"), boss.get_node("BossUI"), arena.get_node("WorldSkin"), arena.get_node("Backdrop")]
	var was_visible: Array[bool] = []
	for item in scenery:
		was_visible.append(item.visible)
		item.visible = false
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.position = Vector2(CROP.position) + Vector2(8, 4)
	var layer := CanvasLayer.new()
	layer.add_child(label)
	arena.add_child(layer)
	var crops: Array[Image] = []
	for count in range(10, -1, -1):
		boss.get_node("Body").head_count = count
		label.text = "state_%02d: %d head%s" % [count, count, "" if count == 1 else "s"]
		await _frames(2)
		var image := _grab().get_region(CROP)
		image.resize(CROP.size.x * 2, CROP.size.y * 2, Image.INTERPOLATE_NEAREST)
		crops.append(image)
	var cell := crops[0].get_size()
	var rows := ceili(crops.size() / float(COLUMNS))
	var sheet := Image.create(cell.x * COLUMNS, cell.y * rows, false, crops[0].get_format())
	sheet.fill(Color(0.08, 0.06, 0.07))
	for index in range(crops.size()):
		sheet.blit_rect(crops[index], Rect2i(Vector2i.ZERO, cell), Vector2i(index % COLUMNS * cell.x, index / COLUMNS * cell.y))
	_save(sheet, "swaminathan_states.png")
	layer.queue_free()

	# Mid-fight: phase 2 with seven heads; the rightmost living head and one on
	# the left are charging, all UI showing.
	for index in range(scenery.size()):
		scenery[index].visible = was_visible[index]
	boss.set_head_count(7)
	boss._banner_remaining = 0.0
	boss.activate_head(6)
	boss.activate_head(1)
	await _frames(40)
	_save(_grab(), "swaminathan_fight.png")

	# The severed-head beat: pop ring, burst, banner and the body shake.
	for attack in get_nodes_in_group("ravan_attacks"):
		attack.queue_free()
	boss._calm_heads()
	boss.take_damage(boss.health - boss.head_threshold(boss.heads_alive - 1), Vector2.ZERO)
	await _frames(5)
	_save(_grab(), "swaminathan_sever.png")
	print("ravan_shots: saved 3 images in %s" % OUT)
	quit()


func _frames(count: int) -> void:
	for frame in range(count):
		await physics_frame
		await process_frame
	await RenderingServer.frame_post_draw


func _grab() -> Image:
	return root.get_texture().get_image()


func _save(image: Image, file: String) -> void:
	image.save_png(ProjectSettings.globalize_path(OUT.path_join(file)))
