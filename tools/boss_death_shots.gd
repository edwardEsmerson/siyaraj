extends SceneTree
## Render actual death playback in the three isolated arenas:
## xvfb-run -a godot --path . --fixed-fps 60 --resolution 960x540 -s tools/boss_death_shots.gd -- --silent-audio

const OUTPUT: String = "res://docs/screenshots/boss-deaths"
const CELL: Vector2i = Vector2i(280, 240)
const ARENAS: Array[String] = [
	"res://scenes/bosses/khara_arena.tscn",
	"res://scenes/bosses/dhoomketu_arena.tscn",
	"res://scenes/bosses/ravan/ravan_arena.tscn",
]
const NAMES: Array[String] = ["khara", "dhoomketu", "swaminathan"]
const CAPTURE_TICKS: Array[int] = [1, 26, 48, 72, 100]
const SWAMINATHAN_TICKS: Array[int] = [1, 17, 31, 45, 60]


func _init() -> void:
	call_deferred("capture")


func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var sheet := Image.create(CELL.x * 6, CELL.y * 3, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.08, 0.06, 0.07))
	for row in range(ARENAS.size()):
		change_scene_to_file(ARENAS[row])
		await scene_changed
		# The isolated final arena adds developer victory controls; hide them for
		# the crops so the final drawn corpse stays readable in the evidence.
		var flow := current_scene.get_node_or_null("CampaignFlow")
		if flow != null:
			flow.get_node("Victory").hide()
		var boss: Node2D = current_scene.get_node("Ravan" if row == 2 else "TestCourse/Boss")
		var player: CharacterBody2D = current_scene.get_node("Player")
		player.set_physics_process(false)
		player.position = Vector2(100, 430)
		if row == 2:
			boss.auto_activate = false
			boss.start_fight()
			boss.set_head_count(1)
		await frames(3)
		var origin: Vector2 = boss.get_global_transform_with_canvas().origin
		var crop := Rect2i(Vector2i(origin) - Vector2i(140, 212), CELL)
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 4)
		label.position = Vector2(crop.position) + Vector2(6, 4)
		var layer := CanvasLayer.new()
		layer.layer = 50
		layer.add_child(label)
		current_scene.add_child(layer)
		label.text = "%s / alive" % NAMES[row].capitalize()
		await frames(1)
		sheet.blit_rect(root.get_texture().get_image().get_region(crop), Rect2i(Vector2i.ZERO, CELL), Vector2i(0, row * CELL.y))
		boss.take_damage(boss.health, Vector2.ZERO)
		var elapsed := 0
		var times := SWAMINATHAN_TICKS if row == 2 else CAPTURE_TICKS
		for index in range(times.size()):
			label.text = "%s / %.2f s" % [NAMES[row].capitalize(), times[index] / 60.0]
			await frames(times[index] - elapsed)
			elapsed = times[index]
			if flow != null:
				flow.get_node("Victory").hide()
				await RenderingServer.frame_post_draw
			var shot := root.get_texture().get_image()
			shot.save_png(ProjectSettings.globalize_path(OUTPUT.path_join("%s-%02d.png" % [NAMES[row], index + 1])))
			sheet.blit_rect(shot.get_region(crop), Rect2i(Vector2i.ZERO, CELL), Vector2i((index + 1) * CELL.x, row * CELL.y))
	sheet.save_png(ProjectSettings.globalize_path(OUTPUT.path_join("sequence.png")))
	print("PASS: captured real death playback for all three bosses in %s" % OUTPUT)
	quit()


func frames(count: int) -> void:
	for frame in range(count):
		await physics_frame
		await process_frame
	await RenderingServer.frame_post_draw
