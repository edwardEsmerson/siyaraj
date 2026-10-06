extends PanelContainer
## Keyboard and controller bindings read from the InputMap.
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
	[&"interact", "Light diya"],
	[&"ui_accept", "Confirm / continue"],
	[&"ui_cancel", "Pause / back"],
	[&"restart", "Restart level"],
	[&"cycle_world_kit", "Cycle scenery (dev)"],
]

const JOYPAD_NAMES: Dictionary = {
	JOY_BUTTON_A: "A / Cross",
	JOY_BUTTON_B: "B / Circle",
	JOY_BUTTON_X: "X / Square",
	JOY_BUTTON_Y: "Y / Triangle",
	JOY_BUTTON_LEFT_SHOULDER: "LB / L1 (hold)",
	JOY_BUTTON_RIGHT_SHOULDER: "RB / R1",
	JOY_BUTTON_BACK: "View / Select",
	JOY_BUTTON_START: "Menu / Start",
	JOY_BUTTON_RIGHT_STICK: "Right stick click",
	JOY_BUTTON_DPAD_LEFT: "D-pad left",
	JOY_BUTTON_DPAD_RIGHT: "D-pad right",
}


func _ready() -> void:
	var grid: GridContainer = $Column/Grid
	for heading in ["Action", "Keyboard", "Controller"]:
		_add_label(grid, heading, true)
	for entry in ACTIONS:
		_add_label(grid, entry[1])
		_add_label(grid, key_text(entry[0]))
		_add_label(grid, joypad_text(entry[0]))
	$Column/Back.pressed.connect(closed.emit)


func _add_label(grid: GridContainer, text: String, heading: bool = false) -> void:
	var label := Label.new()
	label.text = text
	if heading:
		label.theme_type_variation = &"KeyLabel"
	grid.add_child(label)


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


static func joypad_text(action: StringName) -> String:
	var names: PackedStringArray = []
	for event in InputMap.action_get_events(action):
		var text := ""
		if event is InputEventJoypadButton:
			text = JOYPAD_NAMES.get(event.button_index, event.as_text())
		elif event is InputEventJoypadMotion:
			if event.axis == JOY_AXIS_LEFT_X:
				text = "Left stick %s" % ("left" if event.axis_value < 0.0 else "right")
			else:
				text = event.as_text()
		if not text.is_empty() and text not in names:
			names.append(text)
	return " or ".join(names)
