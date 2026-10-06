extends "res://tests/forest_check.gd"
## Exercise real scene entrances, event hooks, pauses, mixing and saved controls.


func run_checks() -> void:
	var audio: Node = root.get_node("AudioDirector")
	var navigation: Node = root.get_node("PlaytestNavigation")
	var settings: Node = root.get_node("GameSettings")
	var saved: Vector3 = Vector3(settings.master_volume, settings.music_volume, settings.sfx_volume)
	for bus in [&"Music", &"SFX", &"UI", &"MusicDuck"]:
		check(AudioServer.get_bus_index(bus) > 0, "Audio bus must exist: %s" % bus)
	check(AudioServer.get_bus_effect(0, 0) is AudioEffectLimiter, "Master must bound mixed peaks")
	check(AudioServer.get_bus_send(AudioServer.get_bus_index(&"UI")) == &"SFX", "Effects slider must also control menu feedback")
	change_scene_to_file(navigation.TITLE)
	await scene_changed
	await ticks(20)
	check(audio.music_id == &"title", "Title must play Welcome to Persia")
	var voice: AudioStreamPlayer = audio.music_players[audio._active_music]
	check(voice.playing and voice.stream is AudioStreamMP3 and voice.stream.loop, "Welcome to Persia must play and loop")
	check(is_equal_approx(voice.stream.get_length(), load("res://assets/Audio/extended_exploration.mp3").get_length()), "Title must use the supplied Welcome to Persia recording")
	check(voice.volume_db > -8.0, "Title entrance must start prominently")
	await ticks(600)
	check(is_equal_approx(voice.volume_db, float(audio.MUSIC[&"title"].bed)), "Title must settle to its quieter bed")
	var panel: Control = current_scene.get_node("Center/Settings")
	panel.open()
	panel.get_node("Column/MusicRow/Volume").value = 0.0
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")), "Music slider must mute independently")
	panel.get_node("Column/SFXRow/Volume").value = 0.5
	check(is_equal_approx(settings.sfx_volume, 0.5), "Effects slider must update saved settings")
	check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"SFX")), linear_to_db(0.5)), "Effects slider must apply to its bus")
	var reloaded: Node = load("res://scripts/main/game_settings.gd").new()
	root.add_child(reloaded)
	check(is_zero_approx(reloaded.music_volume) and is_equal_approx(reloaded.sfx_volume, 0.5), "Audio controls must survive a settings reload")
	reloaded.queue_free()
	settings.music_volume = saved.y
	settings.sfx_volume = saved.z
	settings.apply()
	settings.save()

	current_scene.get_node("Menu/NewGame").pressed.emit()
	await scene_changed
	await ticks(20)
	check(current_scene.scene_file_path.ends_with("prologue.tscn") and audio.music_id == &"prologue", "New game must play Diamond Rush Title during the opening story")
	var opening: CanvasLayer = current_scene.get_node("ComicCutscene")
	for index in opening._panels.size():
		var accept := InputEventAction.new()
		accept.action = &"ui_accept"
		accept.pressed = true
		opening._unhandled_input(accept)
	await scene_changed
	await ticks(20)
	check(audio.music_id == &"forest", "Forest must have its own music entrance after the opening story")

	navigation.enemies_enabled = false
	for level in ["forest", "river", "palace"]:
		navigation.start_level("res://scenes/main/%s.tscn" % level)
		await scene_changed
		await ticks(20)
		check(audio.music_id == StringName(level), "%s must select its soundtrack" % level)
		voice = audio.music_players[audio._active_music]
		check(voice.playing and voice.stream is AudioStreamOggVorbis and voice.stream.loop, "Level music must loop its prepared copy")
		check(voice.volume_db > float(audio.MUSIC[StringName(level)].bed) + 5.0, "Each level must enter loud before settling")
		await ticks(600)
		check(is_equal_approx(voice.volume_db, float(audio.MUSIC[StringName(level)].bed)), "Level entrance must settle automatically")
		check(audio.music_players.filter(func(p: AudioStreamPlayer) -> bool: return p.playing).size() == 1, "Crossfade must retire the previous music voice")
		if level == "river":
			check(voice.stream.get_length() < 9.0, "Angkor Wat loop must omit its nearly three-second silent tail")
			player = current_scene.get_node("Player")
			current_scene.checkpoint_guard.enabled = false
			var checkpoint: Area2D = current_scene.course.get_node("Checkpoints").get_child(0)
			await place(checkpoint.position)
			await press_interact()
			check(audio.cue_id == &"checkpoint", "Lighting an actual diya must play Magic Circle")
			var retained_stream: AudioStream = voice.stream
			navigation.restart_checkpoint()
			await scene_changed
			await ticks(4)
			check(voice.stream == retained_stream and voice.playing, "Checkpoint reload must preserve the level's music rather than replay its entrance")

	audio.stop_cue()
	for effect in audio.SFX:
		var stream: AudioStream = load("res://assets/Audio/sfx/%s.wav" % effect)
		check(stream != null and stream.get_length() > 0.04 and stream.get_length() <= 0.6, "Every action effect must be present and brief: %s" % effect)
	player = current_scene.get_node("Player")
	player._start_jump()
	check(audio.sfx_players.any(func(p: AudioStreamPlayer) -> bool: return p.playing and p.stream == load("res://assets/Audio/sfx/jump.wav")), "Accepted jump must produce an effect")
	player._fire_skyshot()
	check(audio.sfx_players.any(func(p: AudioStreamPlayer) -> bool: return p.playing and p.stream == load("res://assets/Audio/sfx/skyshot.wav")), "Actual skyshot must produce an effect")
	for effect_voice: AudioStreamPlayer in audio.sfx_players:
		effect_voice.stop()
	audio._cooldowns.clear()
	for effect in audio.SFX:
		audio.play_sfx(StringName(effect))
	check(audio.sfx_players.filter(func(p: AudioStreamPlayer) -> bool: return p.playing).size() == audio.SFX_VOICES, "Effects must use a bounded voice pool")
	audio.play_sfx(&"tell")
	check(audio.sfx_players.size() == audio.SFX_VOICES, "A busy encounter must not allocate extra voices")
	for effect_voice: AudioStreamPlayer in audio.sfx_players:
		effect_voice.stop()
	audio._cooldowns.clear()
	audio.play_sfx(&"charge")
	audio.play_cue(&"checkpoint")
	paused = true
	await ticks(3)
	check(audio.cue_player.stream_paused and audio.sfx_players[0].stream_paused, "Gameplay effects and milestone cues must pause")
	check(voice.playing and not voice.stream_paused, "Music must remain available while changing Settings")
	audio.play_sfx(&"ui", Vector2.INF, &"UI")
	await ticks(2)
	check(audio.sfx_players.any(func(p: AudioStreamPlayer) -> bool: return p.bus == &"UI" and p.playing and not p.stream_paused), "Menu feedback must work while paused")
	paused = false
	await ticks(30)
	check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"MusicDuck")) < -6.0, "Milestone cues must duck the music")
	audio.play_cue(&"victory")
	audio.play_cue(&"hint")
	check(audio.cue_id == &"victory", "Hint must not interrupt a victory cue")
	audio.stop_cue()
	await ticks(40)
	check(is_zero_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"MusicDuck"))), "Duck must release after a cue")

	navigation.enemies_enabled = true
	navigation.start_level("res://scenes/main/palace_showdown.tscn")
	await scene_changed
	await ticks(4)
	check(audio._waiting_for_comic and audio.music_id != &"final_boss", "Final boss entrance must wait for the comic to finish")
	var flow: CanvasLayer = current_scene.get_node("CampaignFlow")
	for index in flow.introduction.size():
		var event := InputEventAction.new()
		event.action = &"ui_accept"
		event.pressed = true
		flow.comic._unhandled_input(event)
	await ticks(20)
	voice = audio.music_players[audio._active_music]
	check(audio.music_id == &"final_boss" and voice.playing, "Combat entrance must play Climbing the Throne Room")
	check(is_equal_approx(voice.stream.get_length(), load("res://assets/Audio/music/palace_approach.ogg").get_length()), "Final boss must use the requested recording")
	check(voice.volume_db > -5.0, "Final boss opening must be prominent")
	current_scene.get_node("Ravan").set_physics_process(false)
	await ticks(600)
	check(is_equal_approx(voice.volume_db, -14.0), "Final boss music must settle without going silent")
	player = current_scene.get_node("Player")
	player.die()
	await scene_changed
	await ticks(4)
	check(audio.cue_id == &"defeat" and audio.cue_player.playing, "Death cue must survive an immediate boss retry")
	check(audio.music_id == &"final_boss", "Boss retry must keep the correct track")
	current_scene.get_node("Ravan").died.emit()
	# Lethal cues deliberately retain priority over victory in simultaneous deaths.
	audio.stop_cue()
	current_scene.get_node("Ravan").died.emit()
	check(audio.cue_id == &"victory", "Boss death signal must play the victory cue")
	navigation.show_title()
	await scene_changed
	await ticks(60)
	check(audio.music_id == &"title" and audio.cue_id == &"", "Returning to title must clear combat cues and restore Welcome to Persia")
	settings.master_volume = saved.x
	settings.music_volume = saved.y
	settings.sfx_volume = saved.z
	settings.apply()
	settings.save()
	print("Audio checks: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	await audio.shutdown()
	quit(0 if failures == 0 else 1)
