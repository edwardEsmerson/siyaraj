extends Sprite2D
## Checkpoint clay diya. The levels only toggle the sibling `Flame` node; the lamp follows it,
## showing the lit art (glowing wick) whenever that flame is visible.

@export var unlit: Texture2D
@export var lit: Texture2D

@onready var _flame: CanvasItem = get_node_or_null(^"../Flame")


func _ready() -> void:
	if _flame != null:
		_flame.visibility_changed.connect(_sync)
	_sync()


func _sync() -> void:
	texture = lit if _flame != null and _flame.visible else unlit
