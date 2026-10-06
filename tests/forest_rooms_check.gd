extends "res://tests/forest_check.gd"
## Real collisions in both detours, door flow, room respawn and forest save isolation.

func run_checks() -> void:
	var forest = load("res://scripts/levels/forest.gd")
	forest.checkpoint_x = 11000.0
	forest.lit_checkpoints.assign([&"BanyanDiya"])
	change_scene_to_file("res://scenes/main/forest.tscn")
	await scene_changed
	player = current_scene.player
	await ticks(4)
	freeze_encounters()
	for room in [&"RootChamber", &"CanopyNest"]:
		var entrance: Vector2 = Vector2(5660, 270) if room == &"RootChamber" else Vector2(11730, 230)
		await place(entrance)
		var old_scene := current_scene
		await press_interact()
		await ticks(6)
		check(current_scene != old_scene and forest.current_room == room, "E must transport into %s" % room)
		player = current_scene.player
		freeze_encounters()
		check(player.is_on_floor(), "Room entrance must spawn grounded")
		check(current_scene.camera.limit_top < -1000, "Room camera must frame the isolated climb")
		check(forest.checkpoint_x == 11000, "Entering a room must preserve the forest diya")
		current_scene.set_process(false)
		player.died.disconnect(current_scene._restart)
		var route: Array[Node] = current_scene.course.get_node("SideRooms/%s/Terrain" % room).get_children()
		route.sort_custom(func(a: Node, b: Node) -> bool: return a.get_meta("route_order") < b.get_meta("route_order"))
		for index in range(route.size() - 1):
			var passed := await traverse(route[index], route[index + 1])
			check(passed, "Unreachable detour connection: %s -> %s" % [route[index].name, route[index + 1].name])
			print("ROOM %s -> %s: %s" % [route[index].name, route[index + 1].name, passed])
		current_scene.set_process(true)
		player.died.connect(current_scene._restart)
		var checkpoint: Area2D = current_scene.course.get_node("RoomCheckpoints/RootBedDiya" if room == &"RootChamber" else "RoomCheckpoints/CrownDiya")
		var saved_position: Vector2 = checkpoint.position
		await place(checkpoint.position)
		check(not forest.lit_checkpoints.has(checkpoint.name), "Room diya must require E")
		player.health = 1
		await press_interact()
		check(player.health == 2, "Lighting a side-room diya must restore exactly one heart")
		check(forest.room_spawn == checkpoint.position, "Room diya must secure a local respawn")
		check(forest.checkpoint_x == 11000, "Local diya must not overwrite the forest save")
		old_scene = current_scene
		player.die()
		await preload("res://tests/respawn_test_helpers.gd").wait_for_respawn(self)
		player = current_scene.player
		check(current_scene != old_scene and forest.current_room == room, "Death must stay inside the room")
		check(player.position.distance_to(saved_position) < 1, "Death must return to the local diya")
		var exit: Area2D = current_scene.course.get_node("Portals/RootReturn" if room == &"RootChamber" else "Portals/NestReturn")
		await place(exit.position)
		freeze_encounters()
		await press_interact()
		check(forest.current_room == room, "The guarded far exit must require defeating its sentinel")
		var sentinel: Node = current_scene.course.get_node("Encounters/" + str(exit.get_meta("guard")))
		sentinel.take_damage(sentinel.health, Vector2.ZERO)
		await ticks(2)
		await press_interact()
		await ticks(6)
		player = current_scene.player
		check(forest.current_room == &"" and forest.completed_rooms.has(room), "Finishing must record the room and return to forest")
		check(player.position.distance_to(entrance) < 1, "Return must emerge at the tree/hollow entrance")
		check(current_scene.camera.limit_top == 0 and current_scene.camera.limit_right == 21600, "Return must restore forest camera")
		# A death after returning uses the forest diya, not the side-room spawn.
		player.die()
		await preload("res://tests/respawn_test_helpers.gd").wait_for_respawn(self)
		player = current_scene.player
		check(absf(player.position.x - 11000) < 1, "Forest death must still use the original diya")
	# An unfinished room can be left from its entrance.
	await place(Vector2(11730, 230))
	await press_interact()
	await ticks(6)
	player = current_scene.player
	await place(Vector2(160, -3600))
	await press_interact()
	await ticks(6)
	player = current_scene.player
	check(forest.current_room == &"", "Entrance door must allow abandoning a room")
	# R from inside a room must reset the entire run.
	await place(Vector2(5660, 270))
	await press_interact()
	await ticks(6)
	var event := InputEventAction.new()
	event.action = "restart"
	event.pressed = true
	Input.parse_input_event(event)
	await ticks(6)
	player = current_scene.player
	check(forest.current_room == &"" and forest.completed_rooms.is_empty() and forest.lit_checkpoints.is_empty(), "R in a room must clear all run progress")
	check(absf(player.position.x - 160) < 1, "R must return to the forest start")
	release_inputs()
	if failures == 0:
		print("PASS: both detour routes, doors, local diyas, room death, forest return and full reset")
	quit(1 if failures > 0 else 0)
