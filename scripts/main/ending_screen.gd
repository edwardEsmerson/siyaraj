extends Control
## Ending screen: the title's Diwali dusk with a busier fireworks show, then back to the title.


func _ready() -> void:
	$Center/Content/ReturnButton.pressed.connect(PlaytestNavigation.show_title)
	$Center/Content/ReturnButton.grab_focus()
	$Fade.show()
	create_tween().tween_property($Fade, "modulate:a", 0.0, 1.2).from(1.0)
