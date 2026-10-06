extends SceneTree
## Screenshot a level dressed with a terrain kit, for art review.
## xvfb-run godot --path . --resolution 1920x1080 -s tools/terrain_shot.gd -- \
##     <level.tscn> <kit dir> <out.png> <camera x> [camera y]
## The kit dir holds any of fill.png cap.png end.png fringe.png oneway.png bg.png (loaded straight from disk,
## so new art needs no import). bg.png is a 1080 px tall backdrop pinned to the camera.

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var kit: String = args[1]
	var level: Node2D = load(args[0]).instantiate()
	var skin := TerrainSkin.new()
	skin.terrain = ^"../Terrain"
	skin.fill = _tex(kit, "fill")
	skin.cap = _tex(kit, "cap")
	skin.end_cap = _tex(kit, "end")
	skin.fringe = _tex(kit, "fringe")
	skin.one_way_cap = _tex(kit, "oneway")
	level.add_child(skin)
	var camera := Camera2D.new()
	camera.position = Vector2(float(args[3]), float(args[4]) if args.size() > 4 else 270.0)
	level.add_child(camera)
	var bg: Texture2D = _tex(kit, "bg")
	if bg:
		var back := Sprite2D.new()
		back.texture = bg
		back.scale = Vector2.ONE * 0.5
		back.region_enabled = true
		back.region_rect = Rect2(0, 0, 1920, 1080)
		back.z_index = -10
		camera.add_child(back)
		if level.has_node("Background"):
			level.get_node("Background").visible = false
	var hero: Texture2D = _tex("res://asset-builder/sprites/siya", "sprite")
	if hero and level.has_node("PlayerSpawn"):
		var siya := Sprite2D.new()
		siya.texture = hero
		siya.scale = Vector2.ONE * 0.5
		var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://asset-builder/sprites/siya/meta.json"))
		siya.centered = false
		siya.offset = -Vector2(meta.anchor[0], meta.anchor[1])  # feet on the spawn point
		siya.position = level.get_node("PlayerSpawn").position + Vector2(0, 16)
		level.add_child(siya)
	root.add_child(level)
	camera.make_current()
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(args[2])
	print("saved ", args[2])
	quit()


func _tex(dir: String, name: String) -> Texture2D:
	var path: String = dir.path_join(name + ".png")
	if not FileAccess.file_exists(path):
		return null
	return ImageTexture.create_from_image(Image.load_from_file(path))
