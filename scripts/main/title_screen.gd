extends Control
## Title screen. The developer playtest menu is offered only in debug builds, and
## Quit is hidden on web, where a game cannot close its tab.

const FIRST_LEVEL: String = "res://scenes/main/forest.tscn"

@onready var menu: VBoxContainer = $Menu
@onready var settings: Control = $Center/Settings
@onready var controls: Control = $Center/Controls
@onready var logo: Control = $Logo

var _opened_from: Button
var _logo_y: float
var _time: float = 0.0


func _ready() -> void:
	menu.get_node("NewGame").pressed.connect(_new_game)
	menu.get_node("Controls").pressed.connect(_open_sub.bind(controls, menu.get_node("Controls")))
	menu.get_node("Settings").pressed.connect(_open_sub.bind(settings, menu.get_node("Settings")))
	menu.get_node("Playtest").pressed.connect(PlaytestNavigation.show_menu)
	menu.get_node("Playtest").visible = OS.is_debug_build()
	menu.get_node("Quit").pressed.connect(get_node("/root/AudioDirector").quit_game)
	menu.get_node("Quit").visible = not OS.has_feature("web")
	settings.closed.connect(_close_sub)
	controls.closed.connect(_close_sub)
	menu.get_node("NewGame").grab_focus()
	_logo_y = logo.position.y
	$Fade.show()
	create_tween().tween_property($Fade, "modulate:a", 0.0, 0.8).from(1.0)


func _process(delta: float) -> void:
	_time += delta
	logo.position.y = roundf(_logo_y + sin(_time * 1.6) * 3.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not menu.visible:
		get_viewport().set_input_as_handled()
		_close_sub()


func _new_game() -> void:
	PlaytestNavigation.enemies_enabled = true
	PlaytestNavigation.start_level("res://scenes/main/prologue.tscn")


func _open_sub(panel: Control, from: Button) -> void:
	_opened_from = from
	menu.hide()
	logo.hide()
	panel.open()


func _close_sub() -> void:
	settings.hide()
	controls.hide()
	menu.show()
	logo.show()
	if _opened_from != null:
		_opened_from.grab_focus()
		_opened_from = null
