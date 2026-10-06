extends CanvasLayer
## Attach to the existing boss arena. Actors and arena mechanics remain shared.

@export var boss_path: NodePath
@export var next_level: String = ""
@export var destination_name: String = "level select"
var won: bool = false

func _ready() -> void:
	get_node(boss_path).died.connect(_on_defeated)

func _on_defeated() -> void:
	won = true
	$Victory.show()
	$Victory/Message.text = "BOSS DEFEATED\nEnter: %s\nR: fight again / Esc: menu" % destination_name

func _unhandled_input(event: InputEvent) -> void:
	if not won or not event.is_action_pressed("ui_accept"):
		return
	var player: CharacterBody2D = get_parent().get_node("Player")
	if player.state == player.State.DEAD:
		return
	get_viewport().set_input_as_handled()
	if next_level.is_empty() or not PlaytestNavigation.snapshot.is_empty():
		PlaytestNavigation.show_menu()
	else:
		PlaytestNavigation.start_level(next_level)
