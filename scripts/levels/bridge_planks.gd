extends Node2D
## Carry one board at a time. Built boards survive death, while carried boards return.

const InteractionPrompt = preload("res://scripts/ui/interaction_prompt.gd")

const PLANK_COUNT: int = 4
const PLANK_LENGTH: float = 60.0
const DECK_END: Vector2 = Vector2(8470, 350)
const SUPPLY_START: Vector2 = Vector2(8030, 430)
const PICKUP_RANGE: float = 42.0
const PLACE_RANGE: float = 44.0
var placed_count: int = 0
var carried_index: int = -1
var placed_planks: Array[StaticBody2D] = []
var prompt: Label
var player: CharacterBody2D
var carried_visual: Node2D


func _ready() -> void:
	prompt = Label.new()
	prompt.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	prompt.position = SUPPLY_START + Vector2(-85, -85)
	InteractionPrompt.configure(prompt)
	add_child(prompt)
	var course := get_parent()
	var saved: Dictionary = course.progress.get(course.level_id, {})
	for index in range(int(saved.get("bridge_planks", 0))):
		_add_plank()
	queue_redraw()


func build_edge() -> Vector2:
	return DECK_END + Vector2(placed_count * PLANK_LENGTH, 0)


func supply_position(index: int) -> Vector2:
	return SUPPLY_START + Vector2(index * 18, 0)


func _physics_process(_delta: float) -> void:
	player = get_tree().get_first_node_in_group("players")
	var can_interact: bool = player != null and player.is_on_floor() and player.state == player.State.NORMAL
	var nearby_supply: int = -1
	if can_interact and carried_index < 0:
		for index in range(placed_count, PLANK_COUNT):
			if player.global_position.distance_to(supply_position(index)) <= PICKUP_RANGE:
				nearby_supply = index
				break
	var can_place: bool = can_interact and carried_index >= 0 and player.global_position.distance_to(build_edge()) <= PLACE_RANGE
	var prompt_at: Vector2 = build_edge() if carried_index >= 0 else supply_position(maxi(nearby_supply, 0))
	prompt.position = prompt_at + Vector2(-13, -65)
	InteractionPrompt.set_available(prompt, placed_count < PLANK_COUNT and (can_place or nearby_supply >= 0))
	if Input.is_action_just_pressed("interact"):
		if can_place:
			carried_index = -1
			carried_visual.hide()
			_add_plank()
			var course := get_parent()
			var saved: Dictionary = course.progress.get(course.level_id, {"spawn": Vector2(160, 430), "lit": []})
			saved["bridge_planks"] = placed_count
			course.progress[course.level_id] = saved
		elif nearby_supply >= 0:
			carried_index = nearby_supply
			_show_carried_plank()
	queue_redraw()


func _show_carried_plank() -> void:
	if not is_instance_valid(carried_visual):
		carried_visual = Node2D.new()
		carried_visual.name = "CarriedBridgePlank"
		# A fixed local offset inherits Siya's interpolated transform on every render frame.
		carried_visual.position = Vector2(-30, -58)
		carried_visual.draw.connect(_draw_carried_plank)
		player.add_child(carried_visual)
	carried_visual.show()
	carried_visual.queue_redraw()


func _draw_carried_plank() -> void:
	_draw_board(Vector2.ZERO, Vector2(60, 10), carried_visual)


func _add_plank() -> void:
	var plank := StaticBody2D.new()
	plank.name = "PlacedPlank%d" % (placed_count + 1)
	plank.position = build_edge() + Vector2(PLANK_LENGTH * 0.5, 6)
	plank.collision_layer = 1
	plank.collision_mask = 0
	var collider := CollisionShape2D.new()
	collider.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(PLANK_LENGTH, 12)
	collider.shape = shape
	plank.add_child(collider)
	add_child(plank)
	placed_planks.append(plank)
	placed_count += 1


func _draw() -> void:
	for index in range(placed_count, PLANK_COUNT):
		if index != carried_index:
			_draw_board(supply_position(index) + Vector2(-16, -14 - (index - placed_count) * 3), Vector2(32, 9))
	for plank in placed_planks:
		_draw_board(plank.position - Vector2(PLANK_LENGTH * 0.5, 6), Vector2(PLANK_LENGTH, 12))


func _draw_board(at: Vector2, size: Vector2, canvas: CanvasItem = null) -> void:
	var target: CanvasItem = self if canvas == null else canvas
	target.draw_rect(Rect2(at, size), Color("9c572b"))
	target.draw_rect(Rect2(at, size), Color("efc783"), false, 2)
	target.draw_line(at + Vector2(5, size.y * 0.5), at + Vector2(size.x - 5, size.y * 0.5), Color("60351e"), 1)
	for x in [5.0, size.x - 5]:
		target.draw_circle(at + Vector2(x, 3), 1.5, Color("e4e3dc"))
