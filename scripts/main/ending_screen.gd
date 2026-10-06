extends Control


func _ready() -> void:
	$Center/Content/ReturnButton.pressed.connect(PlaytestNavigation.show_menu)
	$Center/Content/ReturnButton.grab_focus()
