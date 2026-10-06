extends SceneTree
## Record the real Master mix and capture Settings for review.
## xvfb-run -a godot --audio-driver Dummy --path . --script res://tools/audio_preview.gd
## Outputs are ignored build artifacts, except the Settings screenshot.

var recorder: AudioEffectRecord
var audio: Node


func _initialize() -> void:
	call_deferred("capture")


func hold(seconds: float) -> void:
	await create_timer(seconds).timeout


func capture() -> void:
	audio = root.get_node("AudioDirector")
	var settings: Node = root.get_node("GameSettings")
	var original := Vector3(settings.master_volume, settings.music_volume, settings.sfx_volume)
	settings.master_volume = 0.8
	settings.music_volume = 0.8
	settings.sfx_volume = 0.9
	settings.apply()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/audio"))
	recorder = AudioEffectRecord.new()
	recorder.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0, recorder)
	change_scene_to_file("res://scenes/main/title.tscn")
	await scene_changed
	recorder.set_recording_active(true)
	await hold(11.0)
	current_scene.get_node("Menu/Settings").pressed.emit()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/audio-settings.png"))
	root.get_node("PlaytestNavigation").enemies_enabled = false
	for level in ["forest", "river"]:
		root.get_node("PlaytestNavigation").start_level("res://scenes/main/%s.tscn" % level)
		await scene_changed
		await hold(1.0)
		Input.action_press("jump")
		await hold(0.1)
		Input.action_release("jump")
		Input.action_press("dash")
		await hold(0.1)
		Input.action_release("dash")
		await hold(0.4)
		Input.action_press("attack")
		await hold(0.1)
		Input.action_release("attack")
		await hold(0.4)
		Input.action_press("skyshot")
		await hold(0.1)
		Input.action_release("skyshot")
		await hold(8.0)
		audio.play_cue(&"checkpoint")
		await hold(2.5)
	root.get_node("PlaytestNavigation").start_level("res://scenes/main/palace_showdown.tscn")
	await scene_changed
	var flow: CanvasLayer = current_scene.get_node("CampaignFlow")
	for index in flow.introduction.size():
		var accept := InputEventAction.new()
		accept.action = &"ui_accept"
		accept.pressed = true
		flow.comic._unhandled_input(accept)
	current_scene.get_node("Ravan").set_physics_process(false)
	await hold(11.0)
	audio.play_cue(&"victory")
	await hold(6.8)
	recorder.set_recording_active(false)
	var recording := recorder.get_recording()
	var path := ProjectSettings.globalize_path("res://builds/audio/campaign-preview.wav")
	if not check_recording(recording, path):
		await audio.shutdown()
		quit(1)
		return
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	settings.master_volume = original.x
	settings.music_volume = original.y
	settings.sfx_volume = original.z
	settings.apply()
	print("Audio preview: PASS / ", path)
	await audio.shutdown()
	quit()


func check_recording(recording: AudioStreamWAV, path: String) -> bool:
	if recording == null or recording.data.is_empty():
		push_error("Master mix recording is empty")
		return false
	return recording.save_to_wav(path) == OK
