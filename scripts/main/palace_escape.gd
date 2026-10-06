extends Node2D
## Campaign-only escape. The isolated boss arena retains its result controls.

var unlocked: bool = false
var _leaving: bool = false
var _doors: Array[Polygon2D] = []
var _raj: AnimatedSprite2D
var _exit: Area2D


func _ready() -> void:
	var gate := Sprite2D.new()
	gate.texture = preload("res://assets/world/palace/diyalit/decor/gate.png")
	gate.scale = Vector2.ONE * 0.5
	gate.position = Vector2(870, 260.25)
	gate.z_index = -1
	add_child(gate)
	# The approved gate is an archway. Add two leaves inside its opening.
	for side: int in 2:
		var door := Polygon2D.new()
		door.polygon = PackedVector2Array([Vector2(-17.5, 0), Vector2(-17.5, -70), Vector2(17.5, -96), Vector2(17.5, 0)])
		door.color = Color("44223c")
		door.scale.x = 1.0 if side == 0 else -1.0
		door.position = Vector2(850 + (side * 2 - 1) * 17.5, 425)
		door.z_index = -1
		var border := Line2D.new()
		border.points = door.polygon
		border.closed = true
		border.width = 2.0
		border.default_color = Color("b89158")
		door.add_child(border)
		add_child(door)
		_doors.append(door)
	_exit = Area2D.new()
	_exit.position = Vector2(862, 395)
	_exit.collision_layer = 0
	_exit.collision_mask = 2
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(26, 100)
	shape.shape = rectangle
	_exit.add_child(shape)
	add_child(_exit)
	_exit.body_entered.connect(_enter_gate)


func open() -> void:
	if unlocked:
		return
	unlocked = true
	# Clear the small combat perch so the walk out is level and readable.
	get_parent().get_node("LedgeRight/CollisionShape2D").set_deferred("disabled", true)
	var tween := create_tween().set_parallel(true)
	for side: int in 2:
		tween.tween_property(_doors[side], "position:x", 850 + (side * 2 - 1) * 38.0, 0.6)
		tween.tween_property(_doors[side], "scale:x", 0.35 if side == 0 else -0.35, 0.6)
	_raj = get_parent().get_node("RajCage").raj
	_raj.reparent(self)
	_raj.position = Vector2(770, 430)
	get_parent().get_node("RajCage").hide()
	var boss_ui := get_parent().get_node_or_null("Ravan/BossUI")
	if boss_ui != null:
		boss_ui.hide()
	get_parent().get_node("HUD/CombatStatus").text = "Raj is free. Walk right through the open gates to go home."
	get_parent().get_node("HUD/Hint").text = "Swaminathan defeated. Leave together through the palace gates."
	var prompt := Label.new()
	prompt.text = "Raj is free! Walk right through the open gates to go home."
	prompt.theme_type_variation = &"WorldPrompt"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.position = Vector2(120, 480)
	prompt.size = Vector2(720, 42)
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().get_node("HUD").add_child(prompt)


func _process(delta: float) -> void:
	if not unlocked:
		return
	var player: CharacterBody2D = get_parent().get_node("Player")
	_raj.position.x = move_toward(_raj.position.x, clampf(player.position.x - 38.0, 65.0, 870.0), 240.0 * delta)
	_raj.position.y = 430.0
	_raj.flip_h = _raj.position.x > player.position.x
	# Also handles Siya already standing at the exit when the dialogue closes.
	if _exit.overlaps_body(player):
		_enter_gate(player)


func _enter_gate(body: Node2D) -> void:
	if not unlocked or _leaving or body != get_parent().get_node("Player"):
		return
	if body.state == body.State.DEAD or get_tree().paused:
		return
	_leaving = true
	get_parent().get_node("CampaignFlow").call_deferred("finish_escape")
