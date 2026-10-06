extends PanelContainer
## Key list read from the InputMap, so it stays right when bindings change.
## Shared by the title screen and the pause menu; emits `closed` on Back.

signal closed

const ACTIONS: Array[Array] = [
	[&"move_left", "Move left"],
	[&"move_right", "Move right"],
	[&"jump", "Jump"],
	[&"dash", "Rocket dash"],
	[&"attack", "Sparkler lash"],
	[&"skyshot", "Skyshot"],
	[&"special", "Chakri"],
	[&"interact", "Light diya / enter"],
	[&"ui_cancel", "Pause"],
]


func _ready() -> void:
	var grid: GridContainer = $Column/Grid
	for entry in ACTIONS:
		var keys := Label.new()
		keys.text = key_text(entry[0])
		keys.theme_type_variation = &"KeyLabel"
		keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(keys)
		var action := Label.new()
		action.text = entry[1]
		grid.add_child(action)
	$Column/Back.pressed.connect(closed.emit)


func open() -> void:
	show()
	$Column/Back.grab_focus()


static func key_text(action: StringName) -> String:
	var names: PackedStringArray = []
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key == null:
			continue
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		var text := OS.get_keycode_string(code)
		if not text.is_empty() and text not in names:
			names.append(text)
	return " / ".join(names)
