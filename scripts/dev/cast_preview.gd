extends Node2D
## F6 art-library viewer. Uses exported metadata and leaves gameplay controllers independent.

const INDEX_PATH := "res://assets/sprites/cast_index.json"
const BACKGROUNDS := ["Checker", "Forest", "Title skyline"]

var cast_index: Dictionary = {}
var metadata: Dictionary = {}
var subject_name := ""
var character_select: OptionButton
var action_select: OptionButton
var background_select: OptionButton
var zoom_select: OptionButton
var head_action_select: OptionButton
var head_row: HBoxContainer
var play_button: Button
var info: Label
var overlays := true
var flipped := false
var playing := true
var composite := true
var stage: Node2D
var art: AnimatedSprite2D
var gada: Sprite2D
var heads: Array[AnimatedSprite2D] = []
var background: TextureRect
var zoom := 1.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cast_index = _read_json(INDEX_PATH)
	stage = Node2D.new()
	stage.position = Vector2(480, 414)
	add_child(stage)
	art = AnimatedSprite2D.new()
	art.name = "Art"
	art.centered = false
	art.scale = Vector2(0.5, 0.5)
	art.frame_changed.connect(_update_components)
	stage.add_child(art)
	gada = Sprite2D.new()
	gada.name = "Gada"
	gada.centered = false
	gada.scale = Vector2(0.5, 0.5)
	stage.add_child(gada)
	_make_ui()
	for key: String in cast_index.get("subjects", {}):
		character_select.add_item(key)
	if character_select.item_count > 0:
		select_subject(character_select.get_item_text(0))
	queue_redraw()


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


func _make_ui() -> void:
	var backdrop := CanvasLayer.new()
	backdrop.layer = -1
	add_child(backdrop)
	background = TextureRect.new()
	background.size = Vector2(960, 540)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	backdrop.add_child(background)
	var ui := CanvasLayer.new()
	add_child(ui)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 12)
	panel.size = Vector2(928, 122)
	panel.theme = load("res://resources/ui/siyaraj_theme.tres")
	ui.add_child(panel)
	var margin := MarginContainer.new()
	for edge: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 10)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var title := Label.new()
	title.text = "SIYARAJ  /  CAST LIBRARY"
	column.add_child(title)
	var row := HBoxContainer.new()
	column.add_child(row)
	character_select = OptionButton.new()
	character_select.custom_minimum_size.x = 200
	character_select.item_selected.connect(func(i: int) -> void: select_subject(character_select.get_item_text(i)))
	row.add_child(character_select)
	action_select = OptionButton.new()
	action_select.custom_minimum_size.x = 176
	action_select.item_selected.connect(func(i: int) -> void: select_action(action_select.get_item_text(i)))
	row.add_child(action_select)
	play_button = _button(row, "Pause", toggle_play)
	_button(row, "< Frame", func() -> void: step_frame(-1))
	_button(row, "Frame >", func() -> void: step_frame(1))
	var options := HBoxContainer.new()
	column.add_child(options)
	background_select = OptionButton.new()
	for label: String in BACKGROUNDS:
		background_select.add_item(label)
	background_select.item_selected.connect(set_background)
	options.add_child(background_select)
	zoom_select = OptionButton.new()
	for label: String in ["1x gameplay size", "2x", "4x"]:
		zoom_select.add_item(label)
	zoom_select.item_selected.connect(func(i: int) -> void:
		zoom = [1.0, 2.0, 4.0][i]
		_update_transform()
	)
	options.add_child(zoom_select)
	_check(options, "Flip", false, func(value: bool) -> void:
		flipped = value
		_update_transform()
	)
	_check(options, "Colliders / anchors", true, func(value: bool) -> void:
		overlays = value
		queue_redraw()
	)
	_check(options, "Boss components", true, func(value: bool) -> void:
		composite = value
		_update_components()
	)
	head_row = HBoxContainer.new()
	head_row.visible = false
	column.add_child(head_row)
	var head_label := Label.new()
	head_label.text = "Ten heads:"
	head_row.add_child(head_label)
	head_action_select = OptionButton.new()
	head_action_select.custom_minimum_size.x = 176
	head_action_select.item_selected.connect(func(i: int) -> void: select_head_action(head_action_select.get_item_text(i)))
	head_row.add_child(head_action_select)
	info = Label.new()
	info.position = Vector2(24, 466)
	info.size = Vector2(912, 64)
	info.theme = panel.theme
	info.add_theme_font_size_override("font_size", 16)
	ui.add_child(info)


func _button(parent: Control, label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _check(parent: Control, label: String, value: bool, callback: Callable) -> void:
	var check := CheckBox.new()
	check.text = label
	check.button_pressed = value
	check.toggled.connect(callback)
	parent.add_child(check)


func select_subject(name_: String) -> void:
	subject_name = name_
	for i in character_select.item_count:
		if character_select.get_item_text(i) == subject_name:
			character_select.select(i)
	metadata = {}
	head_row.visible = false
	head_action_select.clear()
	action_select.clear()
	art.stop()
	art.sprite_frames = null
	art.visible = false
	gada.visible = false
	for head: AnimatedSprite2D in heads:
		head.queue_free()
	heads.clear()
	var entry: Dictionary = cast_index.get("subjects", {}).get(subject_name, {})
	if entry.get("approval", "pending") != "approved":
		info.text = subject_name + " — awaiting candidate selection\nUse the grouped review sheets to choose the base sprite."
		queue_redraw()
		return
	metadata = _read_json(entry["meta"])
	art.sprite_frames = load(entry["frames"]) as SpriteFrames
	art.offset = -_vector(metadata.get("anchor", [0, 0]))
	art.visible = true
	for animation: StringName in art.sprite_frames.get_animation_names():
		action_select.add_item(animation)
	_make_components()
	var preferred := "idle" if art.sprite_frames.has_animation("idle") else String(art.sprite_frames.get_animation_names()[0])
	select_action(preferred)
	_update_transform()


func select_action(action: String) -> void:
	if art.sprite_frames == null or not art.sprite_frames.has_animation(action):
		return
	for i in action_select.item_count:
		if action_select.get_item_text(i) == action:
			action_select.select(i)
	art.animation = action
	art.frame = 0
	var data: Dictionary = metadata.get("animations", {}).get(action, {})
	var is_static: bool = data.get("loop", "none") == "none"
	if playing and not is_static:
		art.play()
	else:
		art.pause()
	_update_components()


func toggle_play() -> void:
	playing = not playing
	play_button.text = "Pause" if playing else "Play"
	if art.sprite_frames != null:
		if playing and metadata.get("animations", {}).get(art.animation, {}).get("loop", "none") != "none":
			art.play()
		else:
			art.pause()
	for head: AnimatedSprite2D in heads:
		if playing and head.animation != &"faces":
			head.play()
		else:
			head.pause()


func step_frame(direction: int) -> void:
	if art.sprite_frames == null:
		return
	playing = false
	play_button.text = "Play"
	art.pause()
	var count := art.sprite_frames.get_frame_count(art.animation)
	art.frame = posmod(art.frame + direction, count)
	for head: AnimatedSprite2D in heads:
		head.pause()
		if head.animation != &"faces":
			head.frame = posmod(head.frame + direction, head.sprite_frames.get_frame_count(head.animation))
	_update_components()


func set_background(index: int) -> void:
	var path := ""
	if index == 1:
		path = "res://assets/backgrounds/cast/forest.png"
	elif index == 2:
		path = "res://assets/backgrounds/title_skyline.png"
	background.texture = load(path) as Texture2D if not path.is_empty() else null
	background_select.select(index)
	queue_redraw()


func _vector(values: Array) -> Vector2:
	return Vector2(float(values[0]), float(values[1]))


func _update_transform() -> void:
	stage.scale = Vector2(-zoom if flipped else zoom, zoom)
	_update_components()


func _make_components() -> void:
	var attachment: Dictionary = metadata.get("attachment", {})
	if subject_name == "khara":
		var entry: Dictionary = cast_index.get("subjects", {}).get("khara-gada", {})
		if entry.get("approval", "pending") == "approved":
			var gada_meta := _read_json(entry["meta"])
			var pivot: Variant = gada_meta.get("attachment", {}).get("anchor")
			if pivot is Array:
				gada.texture = load("res://assets/sprites/khara-gada/sprite.png") as Texture2D
				gada.offset = -_vector(pivot)
	elif subject_name == "swaminathan":
		var entry: Dictionary = cast_index.get("subjects", {}).get("swaminathan-head", {})
		if entry.get("approval", "pending") != "approved":
			return
		var head_meta := _read_json(entry["meta"])
		var frames: SpriteFrames = load(entry["frames"])
		head_row.visible = true
		for action: StringName in frames.get_animation_names():
			head_action_select.add_item(action)
		var positions: Array = attachment.get("head_offsets_units", [])
		for i in positions.size():
			var head := AnimatedSprite2D.new()
			head.centered = false
			head.scale = Vector2(0.5, 0.5)
			head.position = _vector(positions[i])
			head.offset = -_vector(head_meta.get("anchor", [0, 0]))
			head.sprite_frames = frames
			if frames.has_animation(&"faces"):
				head.animation = &"faces"
				head.frame = i % frames.get_frame_count(&"faces")
			else:
				head.animation = &"idle" if frames.has_animation(&"idle") else frames.get_animation_names()[0]
				if playing:
					head.play()
			stage.add_child(head)
			heads.append(head)
		select_head_action("faces" if frames.has_animation("faces") else String(frames.get_animation_names()[0]))


func select_head_action(action: String) -> void:
	for i in head_action_select.item_count:
		if head_action_select.get_item_text(i) == action:
			head_action_select.select(i)
	for i in heads.size():
		var head := heads[i]
		if not head.sprite_frames.has_animation(action):
			continue
		head.animation = action
		head.frame = i % head.sprite_frames.get_frame_count(action) if action == "faces" else 0
		if playing and action != "faces" and action != "burnt":
			head.play()
		else:
			head.pause()


func _update_components() -> void:
	if not is_instance_valid(info) or art.sprite_frames == null:
		return
	var attachment: Dictionary = metadata.get("attachment", {})
	gada.visible = false
	if subject_name == "khara" and composite and gada.texture != null:
		var entries: Array = attachment.get("frames", {}).get(art.animation, [])
		if art.frame < entries.size() and entries[art.frame] is Dictionary:
			var entry: Dictionary = entries[art.frame]
			gada.position = _vector(entry["hand_from_anchor_px"]) * 0.5
			gada.rotation = deg_to_rad(float(entry.get("rotation_degrees", 0.0)))
			gada.visible = bool(entry.get("visible", true))
		elif art.animation == &"base":
			gada.position = _vector(attachment.get("base_hand_units", [14, -70]))
			gada.rotation = 0.0
			gada.visible = true
	for head: AnimatedSprite2D in heads:
		head.visible = composite
	var count := art.sprite_frames.get_frame_count(art.animation)
	var data: Dictionary = metadata.get("animations", {}).get(art.animation, {})
	info.text = "%s / %s   ·   frame %d / %d   ·   %s   ·   %.1f FPS\n2 art px = 1 game unit   ·   canvas %s   ·   anchor %s" % [subject_name, art.animation, art.frame + 1, count, data.get("loop", "static base"), art.sprite_frames.get_animation_speed(art.animation), str(metadata.get("canvas", [])), str(metadata.get("anchor", []))]
	if subject_name == "khara" and composite and not gada.visible and not attachment.get("frames", {}).has(art.animation):
		info.text += "   ·   gada registration pending"
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(background) or background.texture == null:
		draw_rect(Rect2(0, 0, 960, 540), Color("291e32"))
		for y in range(144, 456, 16):
			for x in range(0, 960, 16):
				if (x / 16 + y / 16) % 2 == 0:
					draw_rect(Rect2(x, y, 16, 16), Color("33253d"))
	if not is_instance_valid(stage):
		return
	draw_line(Vector2(0, 414), Vector2(960, 414), Color("997445"), 1.0)
	if composite and subject_name == "swaminathan":
		var shoulder: float = metadata.get("attachment", {}).get("shoulder_units", -118.0)
		for head: AnimatedSprite2D in heads:
			draw_line(stage.to_global(Vector2(head.position.x * 0.3, shoulder)), head.global_position, Color("552648"), 4.0 * zoom)
	if not overlays:
		return
	if composite:
		for head: AnimatedSprite2D in heads:
			draw_circle(head.global_position, 17.0 * zoom, Color("43ddc7"), false, 1.0)
			draw_circle(head.global_position, 2.0, Color("ff4c93"))
		if gada.visible:
			draw_circle(gada.global_position, 3.0, Color("ff4c93"))
	var entry: Dictionary = cast_index.get("subjects", {}).get(subject_name, {})
	var collider := _vector(metadata.get("collider_units", entry.get("collider_units", [0, 0])))
	var center: bool = metadata.get("anchor_mode", "feet") == "center"
	var origin := stage.position
	var rect := Rect2(origin - Vector2(collider.x * 0.5, collider.y * 0.5 if center else collider.y) * zoom, collider * zoom)
	draw_rect(rect, Color("43ddc7"), false, 1.0)
	draw_line(origin - Vector2(5, 0), origin + Vector2(5, 0), Color("ff4c93"), 1.0)
	draw_line(origin - Vector2(0, 5), origin + Vector2(0, 5), Color("ff4c93"), 1.0)
	if art.visible:
		var canvas := _vector(metadata.get("canvas", [0, 0])) * 0.5
		var anchor := _vector(metadata.get("anchor", [0, 0])) * 0.5
		var left := canvas.x - anchor.x if flipped else anchor.x
		draw_rect(Rect2(origin - Vector2(left, anchor.y) * zoom, canvas * zoom), Color("ffd458", 0.45), false, 1.0)
