extends Control
## Shared campaign result presentation, using the title screen's panel and buttons.

signal continued
signal replayed
signal menu_requested

func _ready() -> void:
	$Actions/Continue.pressed.connect(continued.emit)
	$Actions/Replay.pressed.connect(replayed.emit)
	$Actions/Menu.pressed.connect(menu_requested.emit)

func present(title: String, detail: String, destination: String = "Continue") -> void:
	$Heading.text = title
	$Message.text = detail
	$Actions/Continue.text = destination
	show()
	$Actions/Continue.grab_focus()
