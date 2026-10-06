extends SceneTree
## Renders each level in every available world kit direction at a few camera spots, for art review:
##   xvfb-run -a godot --path . --resolution 1920x1080 -s tools/world_shots.gd [-- <biome> [<direction> | <kit dir>]]
##   ~/ml/bin/python tools/world_sheet.py    # contact sheet per biome
## Writes docs/screenshots/world/<biome>-<direction>-<n>.png (a kit dir writes <biome>-<folder name>-<n>.png).
## Siya stands on a nearby platform for scale; dev labels and enemies are left out.

const OUT: String = "res://docs/screenshots/world"
const LEVELS: Dictionary = {
	"forest": "res://scenes/levels/forest.tscn",
	"river": "res://scenes/levels/river.tscn",
	"palace": "res://scenes/levels/palace.tscn",
}
## Camera centres with several platforms in view: forest roots / ridge stairs / banyan branches,
## river bank / ghat climb / broken bridge, palace gate / pillars / gallery stairs.
const SPOTS: Dictionary = {
	"forest": [700.0, 5400.0, 11750.0],
	"river": [900.0, 5850.0, 8650.0],
	"palace": [1000.0, 3900.0, 6000.0],
}


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var count: int = 0
	await process_frame  # nodes only enter the tree once the main loop runs
	for biome: String in LEVELS:
		if args.size() > 0 and args[0] != biome:
			continue
		count += await _shoot(biome, args[1] if args.size() > 1 else "")
	print("world_shots: saved %d screenshots in %s" % [count, OUT])
	quit()


func _shoot(biome: String, only: String) -> int:
	var level: Node2D = load(LEVELS[biome]).instantiate()
	for enemy: Node in level.get_node("Encounters").get_children():
		enemy.free()
	for child: Node in level.get_children():
		if child is Label:
			child.visible = false
	var skin: WorldSkin = level.get_node_or_null("WorldSkin")
	if skin == null:
		skin = WorldSkin.new()
		skin.name = "WorldSkin"
		level.add_child(skin)
	skin.biome = biome
	var camera := Camera2D.new()
	level.add_child(camera)
	var siya: Sprite2D = _siya()
	level.add_child(siya)
	root.add_child(level)
	camera.make_current()
	var kits: PackedStringArray = skin.available_directions()
	if only == "":  # a full run replaces this biome's old shots
		for file: String in DirAccess.get_files_at(OUT):
			if file.begins_with(biome + "-") and not file.ends_with("-sheet.png"):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT.path_join(file)))
	if only.contains("/"):
		kits = [only if only.begins_with("res://") or only.is_absolute_path() else "res://" + only]
	elif only != "":
		kits = [only] if kits.has(only) else []
	if kits.is_empty():
		print("world_shots: no kits for %s %s" % [biome, only])
	var saved: int = 0
	for kit: String in kits:
		if kit.contains("/"):
			skin.kit_override = kit
		else:
			skin.kit_override = ""
			skin.direction = kit
		for n: int in SPOTS[biome].size():
			var x: float = SPOTS[biome][n]
			camera.position = Vector2(x, 270)
			siya.position = _stand(level, x - 160.0)
			for i in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			var path: String = OUT.path_join("%s-%s-%d.png" % [biome, kit.trim_suffix("/").get_file(), n + 1])
			root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
			print("saved ", path)
			saved += 1
	level.free()
	return saved


## Siya's sprite, feet on its position (asset-builder is not imported, so it loads from disk).
func _siya() -> Sprite2D:
	var siya := Sprite2D.new()
	var dir: String = "res://asset-builder/sprites/siya"
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(dir.path_join("sprite.png")))
	if image:
		var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("meta.json")))
		siya.texture = ImageTexture.create_from_image(image)
		siya.centered = false
		siya.offset = -Vector2(meta.anchor[0], meta.anchor[1])
		siya.scale = Vector2.ONE * WorldSkin.ART_SCALE
	return siya


## Top of the main-course platform nearest to x (a point on its surface).
func _stand(level: Node2D, x: float) -> Vector2:
	var best := Vector2(x, 430)
	var distance: float = INF
	for body: Node in level.get_node("Terrain").get_children():
		var poly: Polygon2D = body.get_node_or_null("Body")
		if poly == null:
			continue
		var left: float = body.position.x + poly.polygon[0].x
		var right: float = body.position.x + poly.polygon[1].x
		var gap: float = maxf(0.0, maxf(left - x, x - right))
		if gap < distance:
			distance = gap
			best = Vector2(clampf(x, left + 16.0, right - 16.0), body.position.y + poly.polygon[0].y)
	return best
