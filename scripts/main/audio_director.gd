extends Node
## Persistent music crossfades and bounded event voices. Gameplay still owns its state.

const AUDIO: String = "res://assets/Audio/"
const SILENCE_DB: float = -60.0
const CROSSFADE_TIME: float = 0.65
const MUSIC_SETTLE_TIME: float = 8.0
const SFX_VOICES: int = 12
# Gains account for the supplied files' different average levels and leave peak headroom.
const MUSIC: Dictionary = {
	&"title": {"file": "extended_exploration", "intro": -7.0, "bed": -15.0},
	&"prologue": {"file": "title_menu", "intro": -2.0, "bed": -10.0},
	&"forest": {"file": "title_menu", "intro": -2.0, "bed": -10.0},
	&"river": {"file": "jungle_exploration", "intro": -1.0, "bed": -9.0},
	&"palace": {"file": "stone_ruins_exploration", "intro": -3.0, "bed": -11.0},
	&"khara": {"file": "mountain_exploration", "intro": -3.0, "bed": -10.0},
	&"dhoomketu": {"file": "stone_ruins_exploration", "intro": -2.0, "bed": -9.0},
	&"final_boss": {"file": "palace_approach", "intro": -4.0, "bed": -14.0},
	&"ending": {"file": "extended_exploration", "intro": -7.0, "bed": -15.0},
}
const SCENE_MUSIC: Dictionary = {
	"title": &"title", "playtest_menu": &"title", "ending": &"ending",
	"prologue": &"prologue",
	"forest": &"forest", "river": &"river", "palace": &"palace",
	"forest_showdown": &"khara", "khara_arena": &"khara",
	"river_showdown": &"dhoomketu", "dhoomketu_arena": &"dhoomketu",
	"palace_showdown": &"final_boss", "ravan_arena": &"final_boss",
	"main": &"forest", "movement_playground": &"forest", "test_course": &"forest",
	"sandbox": &"forest", "weapons_playground": &"forest", "terrain_sampler": &"palace",
}
# Diamond Rush melodies are reserved for occasional milestones, with one at a time.
const CUES: Dictionary = {
	&"checkpoint": {"file": "magic_activation", "gain": 1.0, "time": 2.05, "priority": 1},
	&"hint": {"file": "puzzle_clue", "gain": -8.0, "time": 2.5, "priority": 0},
	&"portal": {"file": "chest_anticipation", "gain": 0.0, "time": 2.5, "priority": 1},
	&"discovery": {"file": "treasure_reveal", "gain": -1.0, "time": 3.65, "priority": 2},
	&"bridge": {"file": "mechanism_start", "gain": -5.0, "time": 3.0, "priority": 1},
	&"victory": {"file": "victory", "gain": -5.0, "time": 6.45, "priority": 3},
	&"defeat": {"file": "defeat", "gain": -1.0, "time": 1.5, "priority": 4},
}
const SFX: PackedStringArray = ["jump", "dash", "lash", "skyshot", "charge", "spin", "hit", "pop", "tell", "slam", "curtain", "ui"]

var music_id: StringName = &""
var cue_id: StringName = &""
var music_players: Array[AudioStreamPlayer] = []
var sfx_players: Array[AudioStreamPlayer] = []
var cue_player: AudioStreamPlayer
var _streams: Dictionary = {}
var _music_tweens: Array[Tween] = [null, null]
var _active_music: int = 0
var _cue_tween: Tween
var _cue_priority: int = -1
var _duck_tween: Tween
var _cooldowns: Dictionary = {}
var _scene: Node
var _waiting_for_comic: bool = false
var _previous_health: Dictionary = {}
var enabled: bool = true
var _quitting: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = not OS.get_cmdline_user_args().has("--silent-audio")
	get_tree().set_auto_accept_quit(false)
	for index in 2:
		var voice := AudioStreamPlayer.new()
		voice.name = "Music%d" % index
		voice.bus = &"Music"
		add_child(voice)
		music_players.append(voice)
	cue_player = AudioStreamPlayer.new()
	cue_player.name = "Milestone"
	cue_player.bus = &"SFX"
	add_child(cue_player)
	cue_player.finished.connect(_finish_cue)
	for index in SFX_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.name = "Effect%d" % index
		voice.bus = &"SFX"
		add_child(voice)
		sfx_players.append(voice)
	get_tree().scene_changed.connect(_on_scene_changed)
	get_tree().node_added.connect(_on_node_added)
	# Future title and pause-menu buttons are handled by node_added too.
	_connect_buttons(get_tree().root)


func _exit_tree() -> void:
	# Release playback objects before the audio server shuts down, including Dummy.
	_stop_all()


func _stop_all() -> void:
	for tween in _music_tweens:
		if tween != null:
			tween.kill()
	if _cue_tween != null:
		_cue_tween.kill()
	if _duck_tween != null:
		_duck_tween.kill()
	for voice in music_players + sfx_players:
		voice.stop()
		voice.stream = null
	cue_player.stop()
	cue_player.stream = null
	_streams.clear()


func shutdown() -> void:
	enabled = false
	_waiting_for_comic = false
	_stop_all()
	# Godot retires stopped stream playbacks asynchronously. Keep the main loop
	# alive for a mixer buffer and its deferred cleanup before calling quit.
	var deadline := Time.get_ticks_msec() + 120
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await get_tree().process_frame


func quit_game() -> void:
	if _quitting:
		return
	_quitting = true
	await shutdown()
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


func _process(_delta: float) -> void:
	if _waiting_for_comic and is_instance_valid(_scene) and _scene.can_process():
		_waiting_for_comic = false
		play_music(SCENE_MUSIC.get(_scene.scene_file_path.get_file().get_basename(), &""), true)
	# Effects pause with gameplay; music and menu feedback remain available in Settings.
	for voice in sfx_players:
		voice.stream_paused = get_tree().paused and voice.bus != &"UI"
	cue_player.stream_paused = get_tree().paused


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_connect_button(node)


func _connect_buttons(node: Node) -> void:
	if node is BaseButton:
		_connect_button(node)
	for child in node.get_children():
		_connect_buttons(child)


func _connect_button(button: BaseButton) -> void:
	var callback := play_sfx.bind(&"ui", Vector2.INF, &"UI")
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


func _on_scene_changed() -> void:
	_scene = get_tree().current_scene
	_previous_health.clear()
	_cooldowns.clear()
	for voice in sfx_players:
		if voice.bus != &"UI":
			voice.stop()
	# A quick checkpoint reload keeps its death/discovery cue and music position.
	if _scene is Control or cue_id not in [&"defeat", &"portal", &"discovery"]:
		stop_cue()
	var key: String = _scene.scene_file_path.get_file().get_basename()
	var next: StringName = SCENE_MUSIC.get(key, &"")
	_waiting_for_comic = _scene.has_node("CampaignFlow") and not _scene.can_process()
	if _waiting_for_comic:
		play_music(&"palace" if next == &"final_boss" else &"forest")
	else:
		play_music(next, next in [&"khara", &"dhoomketu", &"final_boss"])
	var player := _scene.get_node_or_null("Player")
	if player != null:
		player.died.connect(func() -> void: play_cue(&"defeat"))
	for actor in _scene.find_children("*", "Node2D", true, false):
		if actor != player and actor.has_signal("health_changed") and actor.has_signal("died"):
			_previous_health[actor.get_instance_id()] = actor.health
			actor.health_changed.connect(_actor_health_changed.bind(actor))
			var is_boss: bool = actor.is_in_group("bosses") or actor == _scene.get_node_or_null("Ravan")
			actor.died.connect(_actor_died.bind(actor, is_boss))
			if actor.has_signal("shot_fired"):
				actor.shot_fired.connect(func() -> void: play_sfx(&"skyshot", actor.global_position))
			if actor.has_signal("phase_changed"):
				actor.phase_changed.connect(func(_phase: int) -> void: play_sfx(&"tell", actor.global_position))
			if actor.has_signal("head_lost"):
				actor.head_lost.connect(func(_index: int, _remaining: int) -> void: play_sfx(&"slam", actor.global_position))
			if actor.has_signal("fury_started"):
				actor.fury_started.connect(func() -> void: play_sfx(&"tell", actor.global_position))
	if key == "ending":
		play_cue(&"victory")


func _actor_health_changed(remaining: int, actor: Node2D) -> void:
	var id := actor.get_instance_id()
	if remaining < int(_previous_health.get(id, remaining)) and remaining > 0:
		play_sfx(&"hit", actor.global_position)
	_previous_health[id] = remaining


func _actor_died(actor: Node2D, is_boss: bool) -> void:
	if is_boss:
		play_cue(&"victory")
	else:
		play_sfx(&"pop", actor.global_position)


func _stream(file: String, extension: String = "mp3") -> AudioStream:
	var path := AUDIO + file + "." + extension
	if not _streams.has(path):
		_streams[path] = load(path)
	return _streams[path]


func play_music(id: StringName, restart: bool = false) -> void:
	if not enabled:
		return
	if id == music_id and not restart:
		return
	music_id = id
	for index in 2:
		if _music_tweens[index] != null:
			_music_tweens[index].kill()
		var old := music_players[index]
		if old.playing:
			var fade := create_tween()
			fade.tween_property(old, "volume_db", SILENCE_DB, CROSSFADE_TIME)
			fade.tween_callback(old.stop)
			_music_tweens[index] = fade
	if not MUSIC.has(id):
		return
	_active_music = 1 - _active_music
	var voice := music_players[_active_music]
	if _music_tweens[_active_music] != null:
		_music_tweens[_active_music].kill()
	voice.stop()
	var track: Dictionary = MUSIC[id]
	var stream: AudioStream
	if track.file == "extended_exploration":
		stream = _stream(track.file).duplicate()
	else:
		stream = _stream("music/" + String(track.file), "ogg").duplicate()
	stream.set("loop", true)
	voice.stream = stream
	voice.volume_db = SILENCE_DB
	voice.play()
	var entrance := create_tween()
	entrance.tween_property(voice, "volume_db", float(track.intro), 0.18)
	entrance.tween_interval(1.5)
	entrance.tween_property(voice, "volume_db", float(track.bed), MUSIC_SETTLE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_music_tweens[_active_music] = entrance


func play_cue(id: StringName) -> void:
	if not enabled:
		return
	if not CUES.has(id):
		return
	var cue: Dictionary = CUES[id]
	if cue_player.playing and int(cue.priority) <= _cue_priority:
		return
	stop_cue()
	cue_id = id
	_cue_priority = cue.priority
	cue_player.stream = _stream(cue.file)
	cue_player.volume_db = cue.gain
	cue_player.play()
	_duck_music(-7.0, 0.12)
	_cue_tween = create_tween()
	_cue_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_cue_tween.tween_interval(maxf(float(cue.time) - 0.3, 0.0))
	_cue_tween.tween_property(cue_player, "volume_db", SILENCE_DB, 0.3)
	_cue_tween.tween_callback(stop_cue)


func _finish_cue() -> void:
	stop_cue()


func stop_cue() -> void:
	if _cue_tween != null:
		_cue_tween.kill()
		_cue_tween = null
	cue_player.stop()
	cue_id = &""
	_cue_priority = -1
	_duck_music(0.0, 0.45)


func _duck_music(gain: float, duration: float) -> void:
	if _duck_tween != null:
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(func(value: float) -> void: AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"MusicDuck"), value), AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"MusicDuck")), gain, duration)


func play_sfx(id: StringName, at: Vector2 = Vector2.INF, bus: StringName = &"SFX") -> void:
	if not enabled:
		return
	if not SFX.has(String(id)) or (get_tree().paused and bus != &"UI"):
		return
	var now := Time.get_ticks_msec()
	if now < int(_cooldowns.get(id, 0)):
		return
	var gain: float = -5.0
	if at != Vector2.INF:
		var player := get_tree().get_first_node_in_group("players") as Node2D
		if player != null:
			var distance := player.global_position.distance_to(at)
			if distance > 700.0:
				return
			gain -= 12.0 * clampf(distance / 700.0, 0.0, 1.0)
	for voice in sfx_players:
		if voice.playing:
			continue
		_cooldowns[id] = now + (180 if id in [&"hit", &"tell", &"pop"] else 50)
		voice.bus = bus
		voice.stream_paused = false
		voice.stream = _stream("sfx/" + String(id), "wav")
		voice.volume_db = gain
		voice.play()
		return
