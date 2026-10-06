extends SceneTree
## Renders Khara's ladi firecracker at its key moments for art review:
##   xvfb-run -a godot --path . --resolution 1920x1080 -s tools/ladi_shots.gd
## Writes docs/screenshots/ladi/: full arena frames (laid, fuse half burnt, mid chain,
## ash), ladi_sheet.png (the four ladi strips stacked at 2x) and ladi_closeup.png
## (the lit end at 3x).

const ARENA: String = "res://scenes/bosses/khara_arena.tscn"
const OUT: String = "res://docs/screenshots/ladi"
## Moments as [file name, ladi age in seconds]. The fuse burns 1.2 s, then 12 pops
## 0.06 s apart, each lasting 0.16 s; everything is spent at 2.02 s.
const MOMENTS: Array = [["01_laid", 0.05], ["02_fuse_half", 0.6], ["03_chain_mid", 1.47], ["04_ash", 2.08]]
## Game-unit rect around the string (origin at x 676, bursting left).
const STRIP: Rect2i = Rect2i(220, 360, 480, 80)
const CLOSE: Rect2i = Rect2i(560, 380, 140, 56)


func _init() -> void:
	await process_frame
	change_scene_to_file(ARENA)
	await scene_changed
	var arena: Node = current_scene
	var boss: CharacterBody2D = arena.get_node("TestCourse/Boss")
	var player: CharacterBody2D = arena.get_node("Player")
	boss.set_physics_process(false)
	player.set_physics_process(false)
	player.global_position = Vector2(110, 430)
	await _frames(10)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var ladi: Node2D = boss.place_ladi(boss.global_position + Vector2(-boss.ladi_origin_offset, 0), -1, 1.2, 12)
	var strips: Array[Image] = []
	for moment in MOMENTS:
		while is_instance_valid(ladi) and ladi.age < moment[1]:
			await physics_frame
		await process_frame
		await process_frame
		var image := _grab()
		image.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT, moment[0]]))
		var strip := image.get_region(Rect2i(STRIP.position * 2, STRIP.size * 2))
		strips.append(strip)
		if moment[0] == "02_fuse_half":
			var close := image.get_region(Rect2i(CLOSE.position * 2, CLOSE.size * 2))
			close.resize(close.get_width() * 3, close.get_height() * 3, Image.INTERPOLATE_NEAREST)
			close.save_png(ProjectSettings.globalize_path("%s/ladi_closeup.png" % OUT))
		if moment[0] == "03_chain_mid":
			var close := image.get_region(Rect2i((STRIP.position + Vector2i(150, 0)) * 2, Vector2i(180, 80) * 2))
			close.resize(close.get_width() * 3, close.get_height() * 3, Image.INTERPOLATE_NEAREST)
			close.save_png(ProjectSettings.globalize_path("%s/ladi_closeup_pops.png" % OUT))
	var cell := strips[0].get_size()
	var sheet := Image.create(cell.x, cell.y * strips.size(), false, strips[0].get_format())
	for index in range(strips.size()):
		sheet.blit_rect(strips[index], Rect2i(Vector2i.ZERO, cell), Vector2i(0, index * cell.y))
	sheet.save_png(ProjectSettings.globalize_path("%s/ladi_sheet.png" % OUT))
	print("ladi_shots: saved %d moments in %s" % [MOMENTS.size(), OUT])
	quit()


func _grab() -> Image:
	return root.get_texture().get_image()


func _frames(count: int) -> void:
	for frame in range(count):
		await process_frame
