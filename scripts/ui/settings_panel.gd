extends PanelContainer
## Settings shared by the title screen and the pause menu. The host shows it with
## open() and hides it when `closed` fires (Back button; hosts route Esc to Back).

signal closed

@onready var fullscreen: CheckBox = $Column/Fullscreen
@onready var volume: HSlider = $Column/VolumeRow/Volume
@onready var music_volume: HSlider = $Column/MusicRow/Volume
@onready var sfx_volume: HSlider = $Column/SFXRow/Volume


func _ready() -> void:
	fullscreen.toggled.connect(_set_fullscreen)
	volume.value_changed.connect(_set_volume)
	music_volume.value_changed.connect(_set_music_volume)
	sfx_volume.value_changed.connect(_set_sfx_volume)
	$Column/Back.pressed.connect(closed.emit)


func open() -> void:
	fullscreen.set_pressed_no_signal(GameSettings.fullscreen)
	volume.set_value_no_signal(GameSettings.master_volume)
	music_volume.set_value_no_signal(GameSettings.music_volume)
	sfx_volume.set_value_no_signal(GameSettings.sfx_volume)
	show()
	fullscreen.grab_focus()


func _set_fullscreen(on: bool) -> void:
	GameSettings.fullscreen = on
	GameSettings.apply()
	GameSettings.save()


func _set_volume(value: float) -> void:
	GameSettings.master_volume = value
	GameSettings.apply()
	GameSettings.save()


func _set_music_volume(value: float) -> void:
	GameSettings.music_volume = value
	GameSettings.apply()
	GameSettings.save()


func _set_sfx_volume(value: float) -> void:
	GameSettings.sfx_volume = value
	GameSettings.apply()
	GameSettings.save()
