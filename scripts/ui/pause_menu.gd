extends Control
## In-game pause menu, owned by the PlaytestNavigation autoload (which pauses the
## tree and routes Esc here). Level select only appears in debug builds.

@onready var menu: Control = $Center/Menu
@onready var buttons: VBoxContainer = $Center/Menu/Column/Buttons
@onready var settings: Control = $Center/Settings
@onready var controls: Control = $Center/Controls

var _opened_from: Button


func _ready() -> void:
	var navigation := get_parent()
	buttons.get_node("Resume").pressed.connect(navigation._resume)
	buttons.get_node("Checkpoint").pressed.connect(navigation.restart_checkpoint)
	buttons.get_node("Restart").pressed.connect(navigation._restart)
	buttons.get_node("Controls").pressed.connect(_open_sub.bind(controls, buttons.get_node("Controls")))
	buttons.get_node("Settings").pressed.connect(_open_sub.bind(settings, buttons.get_node("Settings")))
	buttons.get_node("Title").pressed.connect(navigation.show_title)
	buttons.get_node("LevelSelect").pressed.connect(navigation.show_menu)
	buttons.get_node("LevelSelect").visible = OS.is_debug_build()
	settings.closed.connect(_close_sub)
	controls.closed.connect(_close_sub)
	hide()


## Snapshots restart as a whole; levels can also go back to their last lit diya.
func open(snapshot: bool) -> void:
	buttons.get_node("Checkpoint").visible = not snapshot
	buttons.get_node("Restart").text = "Restart snapshot" if snapshot else "Restart level"
	_close_sub()
	show()
	buttons.get_node("Resume").grab_focus()


## Esc: leave a sub-panel first, otherwise resume.
func back() -> void:
	if menu.visible:
		get_parent()._resume()
	else:
		_close_sub()


func _open_sub(panel: Control, from: Button) -> void:
	_opened_from = from
	menu.hide()
	panel.open()


func _close_sub() -> void:
	settings.hide()
	controls.hide()
	menu.show()
	if _opened_from != null:
		_opened_from.grab_focus()
		_opened_from = null
