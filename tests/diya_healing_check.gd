extends "res://tests/forest_check.gd"
## Real diya input, health API, retries and disk restoration without touching player saves.

var health_events: Array[int] = []

func wound() -> void:
	await ticks(50)
	player.take_damage(2, Vector2.ZERO)
	await ticks(50)
	check(player.health == 1, "Damage must leave Siya injured before the healing probe")

func healing_bursts() -> Array[Node]:
	var effects: Array[Node] = []
	for child in current_scene.get_children():
		if child.get_script() == preload("res://scripts/effects/burst.gd") and child.label == "+1 HP":
			effects.append(child)
	return effects

func run_checks() -> void:
	var saves: Node = root.get_node("CampaignSave")
	var navigation: Node = root.get_node("PlaytestNavigation")
	saves.save_path = "user://diya_healing_check.json"
	DirAccess.remove_absolute(saves.save_path)
	for level: String in ["forest", "river", "palace"]:
		saves._reset_session()
		saves.active = true
		saves.stage = level
		change_scene_to_file(saves.scene_path(level))
		await scene_changed
		player = current_scene.player
		freeze_encounters()
		var checkpoints: Array[Node] = current_scene.course.get_node("Checkpoints").get_children()
		var first: Vector2 = checkpoints[0].position
		var second: Vector2 = checkpoints[1].position
		await place(first)
		player.health_changed.connect(func(remaining: int) -> void: health_events.append(remaining))
		health_events.clear()
		await press_interact()
		check(player.health == player.max_health and health_events.is_empty(), "Full health activation must cap health and emit no false heal: " + level)
		check(healing_bursts().is_empty(), "Full health activation must show no +HP burst")
		await wound()
		await press_interact()
		check(player.health == 1, "A diya used at full health must not bank a later heal: " + level)
		await place(second)
		await wound()
		health_events.clear()
		player._protection_remaining = 0.4
		await press_interact()
		check(player.health == 2 and health_events == [2], "New diya must restore exactly one HP through the health signal: " + level)
		check(player._protection_remaining < 0.4, "Healing must not extend damage protection")
		check(checkpoints[1].get_node("Flame").visible, "Healing must still light and secure the diya")
		check(healing_bursts().size() == 1, "Injured activation must show one +1 HP burst")
		if level == "forest" and "--capture-healing" in OS.get_cmdline_user_args():
			current_scene.camera.position = Vector2(player.position.x, 270)
			current_scene.camera.reset_smoothing()
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/siyaraj-diya-healing.png")
		await press_interact()
		check(player.health == 2, "Repeat activation must not heal: " + level)
		await place(first)
		await wound()
		await press_interact()
		check(player.health == 1, "Returning to an earlier lit diya must not heal: " + level)
		var saved: Dictionary = saves.read_save()
		player.die()
		await preload("res://tests/respawn_test_helpers.gd").wait_for_respawn(self)
		player = current_scene.player
		freeze_encounters()
		check(player.health == player.max_health, "Death must retain full-health retry: " + level)
		check(player.position.distance_to(second) < 2, "Death must retain the furthest checkpoint")
		await wound()
		await press_interact()
		check(player.health == 1, "Death/retry must not renew the diya heal: " + level)
		check(saves.read_save() == saved, "Retry must preserve disk diya state")
		# Continue clears session statics and reconstructs them from the actual file.
		check(saves.continue_game(), "Continue must accept the existing save schema")
		await scene_changed
		player = current_scene.player
		freeze_encounters()
		await ticks(4)
		check(healing_bursts().is_empty(), "Restoring a lit diya must not award healing")
		await wound()
		await press_interact()
		check(player.health == 1, "Disk-restored diya must not heal again: " + level)
		# API limits also cover non-default max health and lethal damage.
		player.max_health = 5
		check(player.heal(99) == 4 and player.health == 5, "Healing API must cap at configured max health")
		check(player.heal(1) == 0 and player.heal(0) == 0 and player.heal(-1) == 0, "Full, zero and negative heals must do nothing")
		player.died.disconnect(current_scene._restart)
		player.die()
		check(player.heal(1) == 0 and player.state == player.State.DEAD, "Healing must not revive a dead player")
		player.state = player.State.NORMAL
		player.health = 0
		check(player.heal(1) == 0, "Healing must not revive zero health before death processing")

	# Detour lamps are deliberately excluded because each visit resets them.
	saves.active = false
	saves._reset_session()
	navigation.enemies_enabled = false
	change_scene_to_file(saves.scene_path("forest"))
	await scene_changed
	player = current_scene.player
	freeze_encounters()
	for visit in range(2):
		await place(Vector2(5660, 270))
		await press_interact()
		await ticks(6)
		player = current_scene.player
		freeze_encounters()
		var lamp: Area2D = current_scene.course.get_node("RoomCheckpoints/RootBedDiya")
		await place(lamp.position)
		await wound()
		await press_interact()
		check(player.health == 1 and healing_bursts().is_empty(), "Room diya must not heal on initial visit or re-entry")
		check(current_scene.course.room_spawn == lamp.position, "Room diya must retain local checkpoint behavior")
		await place(current_scene.course.get_node("Portals/RootAbort").position)
		await press_interact()
		await ticks(6)
		player = current_scene.player
		freeze_encounters()
	DirAccess.remove_absolute(saves.save_path)
	DirAccess.remove_absolute(saves.save_path + ".tmp")
	release_inputs()
	if failures == 0:
		print("PASS: one-HP main-route diyas, health API caps, feedback, repeated input, re-entry, death/retry and campaign Continue")
	quit(1 if failures > 0 else 0)
