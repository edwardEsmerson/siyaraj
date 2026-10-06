extends SceneTree
## Renders each level in every available world kit direction at a few camera spots, plus the biome's boss
## arena, for art review:
##   xvfb-run -a godot --path . --resolution 1920x1080 -s tools/world_shots.gd [-- <biome> [<direction> | <kit dir>]]
##   ~/ml/bin/python tools/world_sheet.py    # contact sheet per biome
## Writes docs/screenshots/world/<biome>-<direction>-<n>.png (a kit dir writes <biome>-<folder name>-<n>.png).
## The spots between them show every kit piece: fill/cap/end/fringe/oneway, props and landmarks, far/mid
## parallax, back walls (recesses, side rooms, doorways), river water and the arena backdrop.
## Siya stands on a nearby platform for scale; dev labels, HUDs and enemies are left out.

const OUT: String = "res://docs/screenshots/world"
const LEVELS: Dictionary = {
	"forest": "res://scenes/levels/forest.tscn",
	"river": "res://scenes/levels/river.tscn",
	"palace": "res://scenes/levels/palace.tscn",
}
const ARENAS: Dictionary = {
	"forest": "res://scenes/bosses/khara_arena.tscn",
	"palace": "res://scenes/bosses/ravan/ravan_arena.tscn",
}
## Camera centres, in shot order: forest roots / ridge stairs / hollow trunks (roofed recess and doorway) /
## banyan climb / root chamber side room; river bank / ghat balcony / broken bridge / aqueduct / temple steps;
## palace gate / column gallery / broken roofs / inner hall / throne approach. The arena comes last.
const SPOTS: Dictionary = {
	"forest": [Vector2(700, 270), Vector2(5400, 270), Vector2(7240, 270), Vector2(11750, 270), Vector2(2050, -1640)],
	"river": [Vector2(900, 270), Vector2(6150, 270), Vector2(8650, 270), Vector2(10600, 270), Vector2(13700, 270)],
	"palace": [Vector2(1000, 270), Vector2(4250, 270), Vector2(6600, 270), Vector2(9850, 270), Vector2(13700, 270)],
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
	if only == "":  # a full run replaces this biome's old shots
		for file: String in DirAccess.get_files_at(OUT):
			if file.begins_with(biome + "-") and not file.ends_with("-sheet.png"):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT.path_join(file)))
	var level: Node2D = load(LEVELS[biome]).instantiate()
	for enemy: Node in level.get_node("Encounters").get_children():
		enemy.free()
	var skin: WorldSkin = _skin(level, biome)
	var siya: Sprite2D = _siya()
	level.add_child(siya)
	root.add_child(level)
	_hide_dev(level)
	var camera := _camera(level)
	var kits: PackedStringArray = skin.available_directions()
	if only.contains("/"):
		kits = [only if only.begins_with("res://") or only.is_absolute_path() else "res://" + only]
	elif only != "":
		kits = [only] if kits.has(only) else []
	if kits.is_empty():
		print("world_shots: no kits for %s %s" % [biome, only])
	var saved: int = 0
	for kit: String in kits:
		_use(skin, kit)
		for n: int in SPOTS[biome].size():
			camera.position = SPOTS[biome][n]
			siya.position = _stand(level, camera.position - Vector2(160, 0))
			saved += await _save(biome, kit, n + 1)
	level.free()
	if ARENAS.has(biome) and not kits.is_empty():
		var stage: Node2D = load(ARENAS[biome]).instantiate()
		root.add_child(stage)
		var arena_skin: WorldSkin = _skin(stage, biome)
		_hide_dev(stage)
		var player: Node2D = stage.get_node_or_null("Player")
		if player:  # the arena's player is still a grey box; Siya's sprite stands in for scale
			player.visible = false
			var stand_in: Sprite2D = _siya()
			stage.add_child(stand_in)
			stand_in.position = player.global_position
		_camera(stage).position = Vector2(480, 270)
		for kit: String in kits:
			_use(arena_skin, kit)
			saved += await _save(biome, kit, SPOTS[biome].size() + 1)
		stage.free()
	return saved


## The scene's WorldSkin, added if missing.
func _skin(scene: Node2D, biome: String) -> WorldSkin:
	var skin: WorldSkin = scene.get_node_or_null("WorldSkin")
	if skin == null:
		skin = WorldSkin.new()
		skin.name = "WorldSkin"
		scene.add_child(skin)
	skin.biome = biome
	return skin


## Dev labels (section names, prompts, signs) and HUD layers stay out of the shots.
func _hide_dev(scene: Node) -> void:
	for label: Node in scene.find_children("*", "Label", true, false):
		label.visible = false
	for layer: Node in scene.find_children("*", "CanvasLayer", true, false):
		layer.visible = false


func _camera(scene: Node2D) -> Camera2D:
	var camera := Camera2D.new()
	scene.add_child(camera)
	camera.make_current()
	return camera


func _use(skin: WorldSkin, kit: String) -> void:
	if kit.contains("/"):
		skin.kit_override = kit
	else:
		skin.kit_override = ""
		skin.direction = kit


func _save(biome: String, kit: String, n: int) -> int:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = OUT.path_join("%s-%s-%d.png" % [biome, kit.trim_suffix("/").get_file(), n])
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("saved ", path)
	return 1


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


## A point on top of the solid platform nearest to `at` (within the camera's view height).
func _stand(level: Node2D, at: Vector2) -> Vector2:
	var best := Vector2(at.x, at.y + 160.0)
	var distance: float = INF
	for body: Node in level.find_children("*", "StaticBody2D", true, false):
		var poly: Polygon2D = body.get_node_or_null("Body")
		if poly == null or poly.polygon.size() < 3:
			continue
		var points: PackedVector2Array = poly.get_global_transform() * poly.polygon
		var rect := Rect2(points[0], Vector2.ZERO)
		for point: Vector2 in points:
			rect = rect.expand(point)
		if absf(rect.position.y - at.y) > 250.0 or rect.size.x < 40.0:
			continue
		var gap: float = maxf(0.0, maxf(rect.position.x - at.x, at.x - rect.end.x)) + absf(rect.position.y - at.y - 160.0) * 0.25
		if gap < distance:
			distance = gap
			best = Vector2(clampf(at.x, rect.position.x + 16.0, rect.end.x - 16.0), rect.position.y)
	return best
