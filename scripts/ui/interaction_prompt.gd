extends RefCounted
## A small keycap above the object, visible only when interaction is possible.

static func configure(prompt: Label) -> void:
	prompt.text = "E"
	prompt.position = Vector2(-13, -65)
	prompt.size = Vector2(26, 26)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.add_theme_font_size_override("font_size", 17)
	prompt.add_theme_color_override("font_color", Color("fff3d5"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("171b26")
	style.border_color = Color("ead6a3")
	style.set_border_width_all(2)
	prompt.add_theme_stylebox_override("normal", style)
	prompt.hide()


static func set_available(prompt: Label, available: bool) -> void:
	prompt.text = "E"
	prompt.visible = available
