extends "res://tests/forest_check.gd"
## Real E input, bridge collisions, dash requirement and reload lifecycle.

func run_checks() -> void:
	var navigation: Node = root.get_node("PlaytestNavigation")
	navigation.enemies_enabled = false
	navigation.start_level("res://scenes/main/river.tscn")
	await scene_changed
	player = current_scene.player
	await ticks(4)
	player.died.disconnect(current_scene._restart)
	current_scene.set_process(false)
	var course: Node2D = current_scene.course
	var bridge: Node2D = course.get_node("BridgePlanks")
	var deck: Node2D = course.get_node("Terrain/BridgeDeck")
	var landing: Node2D = course.get_node("Terrain/BridgeGap1")
	check(bounds(landing).position.x - bounds(deck).end.x == 480, "Unbuilt gap must be 480 units")
	check(bridge.build_edge().x - bridge.supply_position(3).x >= 380, "All supplies must require a trip from the lower bridge approach")
	check(not await traverse(deck, landing), "Unbuilt bridge must be too wide for jump + dash")
	await place(Vector2(8250, 350))
	Input.action_press("interact")
	await ticks(2)
	player.position = bridge.supply_position(0)
	player.velocity = Vector2.ZERO
	await ticks(4)
	check(bridge.carried_index == -1, "Holding E before approaching must not pick up a plank")
	Input.action_release("interact")
	await ticks(1)
	Input.action_press("jump")
	await ticks(3)
	await press_interact()
	check(bridge.carried_index == -1, "Airborne E must not pick up a plank")
	await place(bridge.supply_position(0))
	await press_interact()
	check(bridge.carried_index == 0, "E must pick up a nearby plank")
	check(bridge.carried_visual.is_visible_in_tree(), "Picking up a plank must display the carried board")
	await press_interact()
	check(bridge.placed_count == 0, "E away from the edge must not place a plank")
	var carry_route: Array[Node] = [course.get_node("Terrain/BridgeRest"), course.get_node("Terrain/BridgeStep1"), course.get_node("Terrain/BridgeStep2"), deck]
	for index in range(carry_route.size() - 1):
		check(await traverse(carry_route[index], carry_route[index + 1]), "The approach stairs must remain traversable while carrying a plank")
	check(bridge.carried_index == 0, "A carried plank must stay with Siya throughout the approach")
	await place(bridge.build_edge() - Vector2(20, 0))
	Input.action_press("jump")
	await ticks(3)
	await press_interact()
	check(bridge.placed_count == 0 and bridge.carried_index == 0, "Airborne E must not place the carried plank")
	await place(bridge.build_edge() - Vector2(20, 0))
	await press_interact()
	check(not bridge.carried_visual.visible, "Placing a plank must remove its carried visual")
	await place(bridge.supply_position(1))
	await press_interact()
	navigation.restart_checkpoint()
	await scene_changed
	player = current_scene.player
	await ticks(4)
	course = current_scene.course
	bridge = course.get_node("BridgePlanks")
	landing = course.get_node("Terrain/BridgeGap1")
	check(bridge.placed_count == 1 and bridge.carried_index == -1, "Checkpoint reload must retain placed boards and return the carried supply")
	player.died.disconnect(current_scene._restart)
	current_scene.set_process(false)
	for index in range(1, 3):
		await place(bridge.supply_position(index))
		await press_interact()
		await place(bridge.build_edge() - Vector2(20, 0))
		await press_interact()
	check(not await traverse(bridge.placed_planks[-1], landing), "Three planks must still leave an unjumpable gap")
	await repair_river_bridge()
	check(bounds(landing).position.x - bridge.build_edge().x == 240, "Four planks must leave a reachable 240-unit dash gap")
	check(not await traverse(bridge.placed_planks[-1], landing, false), "Completed bridge must require a dash as well as a jump")
	check(await traverse(bridge.placed_planks[-1], landing), "Jump + dash must cross the completed bridge")
	await place(bridge.build_edge() - Vector2(20, 0))
	await press_interact()
	check(bridge.placed_count == 4 and bridge.carried_index == -1, "Extra E must not create a fifth plank")
	current_scene.set_process(true)
	player.died.connect(current_scene._restart)
	player.die()
	await scene_changed
	player = current_scene.player
	await ticks(4)
	check(current_scene.course.get_node("BridgePlanks").placed_count == 4, "Death must preserve built planks")
	navigation.start_level("res://scenes/main/river.tscn")
	await scene_changed
	await ticks(4)
	check(current_scene.course.get_node("BridgePlanks").placed_count == 0, "A new run must restore all four supplies")
	release_inputs()
	print("Bridge planks checks: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
