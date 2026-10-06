extends SceneTree
## Run with --main-pack from outside the repository; pass this script's absolute path.
var failures: int = 0


func _initialize() -> void:
	call_deferred("run_checks")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func run_checks() -> void:
	check(not ResourceLoader.exists("res://tests/movement_check.gd"), "Pack must exclude regression scripts")
	var audio: Node = root.get_node("AudioDirector")
	for track: Dictionary in audio.MUSIC.values():
		var file: String = track.file
		var path := "res://assets/Audio/extended_exploration.mp3" if file == "extended_exploration" else "res://assets/Audio/music/%s.ogg" % file
		check(load(path) is AudioStream, "Pack must ship music: %s" % file)
	for effect: String in audio.SFX:
		check(load("res://assets/Audio/sfx/%s.wav" % effect) is AudioStreamWAV, "Pack must ship effect: %s" % effect)
	for cue: Dictionary in audio.CUES.values():
		check(load("res://assets/Audio/%s.mp3" % cue.file) is AudioStreamMP3, "Pack must ship milestone cue: %s" % cue.file)
	var menu_script: Script = load("res://scripts/main/playtest_menu.gd")
	var paths: PackedStringArray = ["res://scenes/main/title.tscn", "res://scenes/main/prologue.tscn", "res://scenes/main/ending.tscn", "res://scenes/main/playtest_menu.tscn"]
	paths.append_array(menu_script.LEVELS)
	for entry: Dictionary in menu_script.SNAPSHOTS:
		if not paths.has(entry.path):
			paths.append(entry.path)
	for path: String in paths:
		check(change_scene_to_file(path) == OK, "Pack must launch %s" % path)
		await scene_changed
		for frame in 4:
			await physics_frame
			await process_frame
		if path == "res://scenes/main/prologue.tscn":
			var comic: CanvasLayer = current_scene.get_node("ComicCutscene")
			check(comic.visible and comic.panel_art.texture != null and comic.featured_art.texture != null, "Pack must play the opening with its artwork")
		var skin: Node = current_scene.get_node_or_null("TestCourse/WorldSkin")
		if skin == null:
			skin = current_scene.get_node_or_null("WorldSkin")
		if skin != null:
			check(skin.available_directions().size() == 6, "%s must ship all six world kits" % path)
			check(skin.get_node("Dressing").get_child_count() > 0, "%s must dress its world from packed textures" % path)
			if path in ["res://scenes/main/forest.tscn", "res://scenes/main/river.tscn", "res://scenes/main/palace.tscn"]:
				check(skin.direction == ("titlematch" if skin.biome == "river" else "diyalit"), "%s must export PR #33's selected level art" % path)
		var player: Node = current_scene.get_node_or_null("Player")
		if player != null:
			check(player.get_node("Visuals/Sprite").sprite_frames.get_animation_names().size() == 15, "%s must ship Siya's animation library" % path)
		if path == "res://scenes/dev/cast_preview.tscn":
			for subject in ["basic-rakshas", "brute", "ground-shooter", "winged-forest-demon", "khara", "robin", "raj"]:
				current_scene.select_subject(subject)
				check(current_scene.art.sprite_frames != null, "Pack must include %s's cast frames and metadata" % subject)
			current_scene.select_subject("khara")
			check(current_scene.gada.texture != null, "Pack must include Khara's separate gada")
		if path == "res://scenes/main/ending.tscn":
			check(current_scene.get_node("Center/Content/RajStage/Raj").sprite_frames.has_animation("freed"), "Pack must include Raj's rescue animation")
		for actor in current_scene.find_children("*", "CharacterBody2D", true, false):
			if actor.has_node("Visuals/Sprite") and actor.has_node("Body") and actor != player:
				check(not actor.get_node("Body").visible, "%s must use cast art in gameplay" % actor.name)
			if actor.has_node("Visual/Art"):
				check(actor.get_node("Visual/Art").sprite_frames.has_animation("slam_impact"), "Pack must include Khara's gameplay animations")
		var final_boss: Node = current_scene.get_node_or_null("Ravan")
		if final_boss != null:
			var body: Node = final_boss.get_node("Body")
			check(body._textures.size() == 11 and body._textures.all(func(texture: Texture2D) -> bool: return texture != null), "Pack must ship all eleven Swaminathan head-state sprites")
	print("Pack checks: %s (%d scenes)" % ["PASS" if failures == 0 else "FAIL", paths.size()])
	await audio.shutdown()
	quit(0 if failures == 0 else 1)
