extends Node
## Player settings, saved to user://settings.cfg and applied at startup.

const PATH: String = "user://settings.cfg"

var fullscreen: bool = false
var master_volume: float = 0.8
var music_volume: float = 0.8
var sfx_volume: float = 0.9


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		fullscreen = config.get_value("display", "fullscreen", fullscreen)
		master_volume = config.get_value("audio", "master_volume", master_volume)
		music_volume = config.get_value("audio", "music_volume", music_volume)
		sfx_volume = config.get_value("audio", "sfx_volume", sfx_volume)
	apply()


func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(0, master_volume <= 0.0)
	_set_audio_bus(&"Music", music_volume)
	_set_audio_bus(&"SFX", sfx_volume)
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.save(PATH)


func _set_audio_bus(bus: StringName, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(index, volume <= 0.0)
