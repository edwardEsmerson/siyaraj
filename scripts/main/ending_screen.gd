extends Control
## Campaign result with the rescued pair and explicit routes to play again.


func _ready() -> void:
	$Center/Content/ReturnButton.pressed.connect(PlaytestNavigation.show_title)
	$Center/Content/NewJourney.pressed.connect(_new_journey)
	$Center/Content/ReplayFinale.pressed.connect(_replay_finale)
	$Center/Content/ReturnButton.grab_focus()
	$Fade.show()
	create_tween().tween_property($Fade, "modulate:a", 0.0, 1.2).from(1.0)
	$Center/Content/RajStage.resized.connect(_place_raj)
	_place_raj()
	# Raj was freed in the palace. Hold the reunion pose at home.
	$Center/Content/RajStage/Raj.play(&"freed")


func _new_journey() -> void:
	PlaytestNavigation.enemies_enabled = true
	PlaytestNavigation.start_level("res://scenes/main/prologue.tscn")


func _replay_finale() -> void:
	PlaytestNavigation.enemies_enabled = true
	PlaytestNavigation.start_level("res://scenes/main/palace_showdown.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		PlaytestNavigation.show_title()


func _place_raj() -> void:
	var stage: Control = $Center/Content/RajStage
	$Center/Content/RajStage/Raj.position = Vector2(stage.size.x * 0.5, stage.size.y)
	$Center/Content/RajStage/Raj.position.x += 38.0
	$Center/Content/RajStage/Siya.position = Vector2(stage.size.x * 0.5 - 38.0, stage.size.y)
