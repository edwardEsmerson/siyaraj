extends SceneTree
## Every level and boss arena dresses with every kit piece, without touching its collision geometry, and a
## boss arena follows the direction its level last showed.

var failures: int = 0


func _init() -> void:
	await process_frame
	for biome: String in ["forest", "river", "palace"]:
		var level: Node2D = load("res://scenes/levels/%s.tscn" % biome).instantiate()
		var shapes: String = _shapes(level)
		root.add_child(level)
		var skin: WorldSkin = level.get_node("WorldSkin")
		check(skin.direction == ("titlematch" if biome == "river" else "diyalit"), "%s must start in PR #33's selected art direction" % biome)
		check(level.has_node("SkinDecor" if biome == "forest" else "KitDecor" if biome == "palace" else "Decor/titlematch"), "%s must retain its authored level dressing" % biome)
		if biome == "forest":
			check(level.get_node("SkinZones").get_child_count() > 1, "Forest must retain its section colour script")
		for direction: String in skin.available_directions():
			skin.direction = direction
			var dressing: Node = skin.get_node("Dressing")
			var name: String = "%s/%s" % [biome, direction]
			check(_count(dressing, WorldSkin.Z_LANDMARK) >= 6, "%s must place landmarks from setpieces.png" % name)
			check(_count(dressing, WorldSkin.Z_BACK) > 0, "%s must use back.png" % name)
			check(_count(dressing, WorldSkin.Z_FAR) > 0 and _count(dressing, WorldSkin.Z_MID) > 0, "%s must keep both parallax layers" % name)
			if biome == "river":
				check(_count(dressing, WorldSkin.Z_WATER) == 1, "%s must draw the river water" % name)
		check(_shapes(level) == shapes, "%s dressing must not change collision geometry" % biome)
		skin.direction = "papercut"
		level.free()
		if biome == "river":
			continue
		var stage: Node2D = load("res://scenes/bosses/khara_arena.tscn" if biome == "forest" else "res://scenes/bosses/ravan/ravan_arena.tscn").instantiate()
		root.add_child(stage)
		var arena: WorldSkin = stage.get_node("WorldSkin")
		check(arena.direction == "papercut", "%s arena must follow the level's direction" % biome)
		check(_count(arena.get_node("Dressing"), WorldSkin.Z_FAR) == 1, "%s arena must show arena.png" % biome)
		check(_count(arena.get_node("Dressing"), WorldSkin.Z_MID) == 0, "%s arena replaces the parallax layers" % biome)
		stage.free()
	print("world_skin_check: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


## Dressing canvas items drawn at `z`.
func _count(dressing: Node, z: int) -> int:
	var found: int = 0
	for item: Node in dressing.get_children():
		if item is CanvasItem and item.z_index == z:
			found += 1
	return found


func _shapes(scene: Node) -> String:
	var out: PackedStringArray = []
	for shape: Node in scene.find_children("*", "CollisionShape2D", true, false):
		if not (shape.get_parent() is StaticBody2D):
			continue  # enemies, pickups and triggers move or spawn on their own
		out.append("%s %s %s" % [scene.get_path_to(shape), shape.position, shape.shape.get_rect() if shape.shape else Rect2()])
	return "\n".join(out)
