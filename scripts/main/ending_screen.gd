extends Control
## Ending screen: the title's Diwali dusk with a busier fireworks show, then back to the title.


func _ready() -> void:
	$Center/Content/ReturnButton.pressed.connect(PlaytestNavigation.show_title)
	$Center/Content/ReturnButton.grab_focus()
	$Fade.show()
	create_tween().tween_property($Fade, "modulate:a", 0.0, 1.2).from(1.0)
	$Center/Content/RajStage.resized.connect(_place_raj)
	_place_raj()
	var rescue := create_tween()
	rescue.tween_interval(1.2)
	rescue.tween_callback(func() -> void: $Center/Content/RajStage/Raj.play(&"dramatic"))
	rescue.tween_interval(1.0)
	rescue.tween_callback(func() -> void: $Center/Content/RajStage/Raj.play(&"freed"))


func _place_raj() -> void:
	var stage: Control = $Center/Content/RajStage
	$Center/Content/RajStage/Raj.position = Vector2(stage.size.x * 0.5, stage.size.y)
