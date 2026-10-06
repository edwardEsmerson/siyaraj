extends "res://tests/forest_check.gd"
## Isolated save file, real input/checkpoint/bridge restoration and a fresh process.

func run_checks() -> void:
	var saves: Node = root.get_node("CampaignSave")
	var navigation: Node = root.get_node("PlaytestNavigation")
	saves.save_path = "user://campaign_save_check.json"
	if "--reopen-probe" in OS.get_cmdline_user_args():
		check(saves.continue_game(), "Fresh process must load the previous process's save")
		await scene_changed
		await ticks(4)
		check(current_scene.course.get_node("BridgePlanks").placed_count == 4, "Fresh process must restore the complete bridge")
		check(current_scene.player.position.distance_to(current_scene.player_spawn.position) < 2, "Fresh process must spawn at the secured checkpoint")
		print("Reopen probe: %s" % ("PASS" if failures == 0 else "FAIL"))
		quit(0 if failures == 0 else 1)
		return
	DirAccess.remove_absolute(saves.save_path)
	change_scene_to_file(navigation.TITLE)
	await scene_changed
	check(current_scene.get_node("Menu/Continue").disabled, "Missing save must disable Continue")
	var invalid: Array = [null, [], {}, {"version": 0}, {"version": 99}, {"version": 1, "stage": "../../bad"}]
	var base: Dictionary = saves._empty("river")
	for field: String in ["checkpoint", "lit", "rooms", "bridge_planks", "stage"]:
		var bad := base.duplicate(true)
		bad[field] = null
		invalid.append(bad)
	for boards: Variant in [-1, 5, 1.5, "4"]:
		var bad := base.duplicate(true)
		bad.bridge_planks = boards
		invalid.append(bad)
	var traversal := base.duplicate(true)
	traversal.checkpoint = "../PlayerSpawn"
	traversal.lit = ["../PlayerSpawn"]
	invalid.append(traversal)
	for bad: Variant in invalid:
		var file := FileAccess.open(saves.save_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(bad))
		file.close()
		check(saves.read_save().is_empty() and not saves.continue_game(), "Invalid/obsolete save must fail safely: %s" % str(bad))
	var broken := FileAccess.open(saves.save_path, FileAccess.WRITE)
	broken.store_string("{broken")
	broken.close()
	check(saves.read_save().is_empty(), "Truncated JSON must fail safely")
	current_scene.get_node("Menu/NewGame").pressed.emit()
	await scene_changed
	check(saves.read_save().stage == "prologue", "New Game must replace an invalid save and secure the opening")
	navigation.start_level(saves.scene_path("forest"))
	await scene_changed
	player = current_scene.player
	freeze_encounters()
	var diya: Node2D = current_scene.course.get_node("Checkpoints").get_child(0)
	await place(diya.position)
	await press_interact()
	var forest_save: Dictionary = saves.read_save()
	check(forest_save.checkpoint == str(diya.name), "Lighting a real diya must write its stable name")
	var forest: GDScript = preload("res://scripts/levels/forest.gd")
	forest.completed_rooms.append(&"RootChamber")
	forest.current_room = &"CanopyNest"
	forest.room_spawn = Vector2(350, -3600)
	saves.capture()
	navigation.show_title()
	await scene_changed
	check(not current_scene.get_node("Menu/Continue").disabled, "Saved game must enable Continue")
	current_scene.get_node("Menu/Continue").pressed.emit()
	await scene_changed
	check(forest.current_room == &"" and forest.completed_rooms.has(&"RootChamber"), "Side-room quit must restore the secured trail and retain completed rooms")
	check(is_equal_approx(current_scene.player.position.x, diya.position.x) if is_instance_valid(diya) else is_equal_approx(current_scene.player.position.x, forest.checkpoint_x), "Forest Continue must restore its diya")
	navigation.start_level(saves.scene_path("river"))
	await scene_changed
	player = current_scene.player
	freeze_encounters()
	await repair_river_bridge()
	check(saves.read_save().bridge_planks == 4, "Every placed board must be saved without another diya interaction")
	diya = current_scene.course.get_node("Checkpoints").get_child(3)
	await place(diya.position)
	await press_interact()
	var river_save: Dictionary = saves.read_save()
	check(river_save.checkpoint == str(diya.name) and river_save.bridge_planks == 4, "Saving a diya must retain the bridge")
	player.die()
	await scene_changed
	await preload("res://tests/respawn_test_helpers.gd").wait_for_respawn(self)
	check(current_scene.course.get_node("BridgePlanks").placed_count == 4, "Death/retry must retain bridge collision")
	check(saves.read_save() == river_save, "Death/retry must retain the disk checkpoint")
	var output: Array = []
	var exit_code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/campaign_save_check.gd", "--", "--silent-audio", "--reopen-probe"], output, true)
	check(exit_code == 0 and "Reopen probe: PASS" in str(output) and not "ERROR:" in str(output), "Quit/reopen probe must pass: %s" % str(output))
	navigation.show_title()
	await scene_changed
	navigation.start_level(saves.scene_path("forest_showdown"), 0, &"", true)
	await scene_changed
	current_scene.get_node("CampaignFlow")._on_defeated()
	check(saves.read_save() == river_save, "Developer snapshot victory must not overwrite the campaign")
	navigation.show_title()
	await scene_changed
	check(saves.continue_game(), "Continue after a snapshot must still restore the campaign")
	await scene_changed
	navigation.start_level(saves.scene_path("forest_showdown"))
	await scene_changed
	var flow: Node = current_scene.get_node("CampaignFlow")
	flow._on_defeated()
	check(saves.read_save().stage == "river", "Boss defeat must secure the next stage before dialogue ends")
	saves.enter_stage(saves.scene_path("ending"))
	navigation.show_title()
	await scene_changed
	check(current_scene.get_node("Menu/Continue").text == "View ending", "Completed save must offer the ending")
	current_scene.get_node("Menu/Continue").pressed.emit()
	await scene_changed
	check(current_scene.scene_file_path == saves.scene_path("ending"), "Completed Continue must open the ending without replaying the boss")
	navigation.show_title()
	await scene_changed
	current_scene.get_node("Menu/NewGame").pressed.emit()
	await scene_changed
	check(saves.read_save().get("stage") == "prologue" and saves.read_save().get("checkpoint") == "" and saves.read_save().get("bridge_planks") == 0 and forest.completed_rooms.is_empty(), "New Game must deliberately clear completed progress")
	check(preload("res://scripts/levels/draft_level.gd").progress.is_empty(), "New Game must clear bridge and draft checkpoint state")
	saves.active = false
	DirAccess.remove_absolute(saves.save_path)
	release_inputs()
	print("Campaign save checks: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
