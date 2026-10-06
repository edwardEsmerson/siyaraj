extends PanelContainer
## Settings shared by the title screen and the pause menu. The host shows it with
## open() and hides it when `closed` fires (Back button; hosts route Esc to Back).

signal closed

@onready var fullscreen: CheckBox = $Column/Fullscreen
@onready var volume: HSlider = $Column/VolumeRow/Volume


func _ready() -> void:
	fullscreen.toggled.connect(_set_fullscreen)
	volume.value_changed.connect(_set_volume)
	$Column/Back.pressed.connect(closed.emit)


func open() -> void:
	fullscreen.set_pressed_no_signal(GameSettings.fullscreen)
	volume.set_value_no_signal(GameSettings.master_volume)
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
