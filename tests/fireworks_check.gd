extends "res://tests/forest_check.gd"
## Shared moving effect, bounded sky placement and scene-owned cleanup.


func exercise(effect: Node2D) -> void:
	effect.set_process(false)
	effect._rng.seed = 42
	var peak: int = 0
	for frame in 7200:
		effect._process(1.0 / 60.0)
		peak = maxi(peak, effect._sparks.size())
		check(effect._rockets.size() < 5 and effect._sparks.size() < 260, "Decorative particles must stay bounded over two minutes")
	check(peak >= 36, "Reused rockets must actually burst into the title sparks")
	effect.hide()
	check(not effect.is_processing() and effect._rockets.is_empty() and effect._sparks.is_empty() and effect._flashes.is_empty(), "Hiding fireworks must stop and clear all animation")
	effect.show()
	check(effect.is_processing(), "Showing fireworks must resume launches")


func run_checks() -> void:
	change_scene_to_file("res://scenes/main/palace.tscn")
	await scene_changed
	await ticks(4)
	var sky: Parallax2D = current_scene.get_node("TestCourse/FestivalSky")
	var window: Control = sky.get_node("SkyWindow")
	var effect: Node2D = window.get_node("Fireworks")
	check(sky.z_index > WorldSkin.Z_FAR and sky.z_index < WorldSkin.Z_MID, "Palace fireworks must sit between the far sky and architecture")
	check(window.clip_contents and window.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Palace sky must clip sparks without intercepting input")
	var screen_origin: Vector2 = window.get_global_transform_with_canvas().origin
	current_scene.set_process(false)
	current_scene.set_physics_process(false)
	current_scene.get_node("Camera2D").position.x = 7000.0
	current_scene.get_node("Camera2D").reset_smoothing()
	await ticks(4)
	check(current_scene.get_node("Camera2D").get_screen_center_position().x > 6000.0, "Scrolling probe must reach the middle of the palace")
	check(window.get_global_transform_with_canvas().origin.is_equal_approx(screen_origin), "Palace sky must remain on screen throughout the scrolling course")
	exercise(effect)
	paused = true
	check(not effect.can_process(), "Palace fireworks must follow the normal pause contract")
	paused = false
	var old_effect: WeakRef = weakref(effect)
	change_scene_to_file("res://scenes/main/ending.tscn")
	await scene_changed
	await ticks(4)
	check(old_effect.get_ref() == null, "Leaving the palace must free its fireworks")
	var ending: Control = current_scene
	var celebration: Control = ending.get_node("Fireworks")
	var message: Label = ending.get_node("Center/Content/Message")
	var text_size: Vector2 = message.get_theme_font("font").get_multiline_string_size(message.text, HORIZONTAL_ALIGNMENT_CENTER, -1, message.get_theme_font_size("font_size"))
	var text_rect := Rect2(message.get_global_rect().get_center() - text_size * 0.5, text_size)
	for lane: Control in celebration.get_children():
		check(lane.clip_contents and not lane.get_global_rect().intersects(text_rect), "Victory fireworks must stay outside the centered story text")
		for control_name: String in ["Title", "ReturnButton", "NewJourney", "ReplayFinale"]:
			check(not lane.get_global_rect().intersects(ending.get_node("Center/Content/" + control_name).get_global_rect()), "Victory fireworks must stay outside the heading and result buttons")
		effect = lane.get_node("Fireworks")
		exercise(effect)
		celebration.hide()
		check(not effect.is_processing() and effect._sparks.is_empty(), "Hiding a parent must also stop its fireworks")
		celebration.show()
	check(ending.get_node("Center/Content/ReturnButton").has_focus(), "Decorations must preserve ending button focus")
	old_effect = weakref(effect)
	ending.get_node("Center/Content/ReturnButton").pressed.emit()
	await scene_changed
	await ticks(4)
	check(current_scene.scene_file_path == "res://scenes/main/title.tscn" and old_effect.get_ref() == null, "Return to title must free victory effects and retain navigation")
	check(current_scene.get_node("Fireworks").get_script() == effect_script(), "Title and celebrations must share the existing moving effect")
	print("Fireworks checks: %d failure(s)" % failures)
	quit(1 if failures else 0)


func effect_script() -> GDScript:
	return preload("res://scripts/effects/fireworks.gd")
