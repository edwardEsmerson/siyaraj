extends TextureRect
## Lit diya that sits inside the left end of whichever Button in `menu` has keyboard focus.
## Add it as a sibling of the menu container (not inside it, so it does not take a slot).

@export var menu: Control
## Distance from the button's left edge, inside its border.
@export var inset: float = 10.0

var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	hide()
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	# Hovering moves focus, so the mouse and keyboard never highlight two buttons.
	if menu != null:
		for button in menu.find_children("*", "BaseButton", true, false):
			button.mouse_entered.connect(button.grab_focus)


func _process(delta: float) -> void:
	_time += delta
	# Flame flicker: a slight brightness wobble, no movement so it never looks jittery.
	modulate = Color(1, 1, 1).lerp(Color(1.15, 1.05, 0.9), 0.5 + 0.5 * sin(_time * 9.0) * sin(_time * 3.7))
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and visible:
		if not focused.is_visible_in_tree():
			hide()
		else:
			_place(focused)


func _on_focus_changed(control: Control) -> void:
	# Plain menu buttons only: checkboxes and sliders show their own focus ring.
	visible = control is Button and not (control as Button).toggle_mode and menu != null and menu.is_ancestor_of(control)


func _place(button: Control) -> void:
	var rect := button.get_global_rect()
	global_position = Vector2(rect.position.x + inset, rect.get_center().y - size.y * 0.5).round()
