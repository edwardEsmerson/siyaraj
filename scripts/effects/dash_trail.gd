extends Node2D
## Sample world positions so the trail stays behind when Siya moves or turns.

var samples: Array[Vector3] = []
var _sample_remaining: float = 0.0


func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	z_index = -1


func _process(delta: float) -> void:
	for index in range(samples.size() - 1, -1, -1):
		samples[index].z -= delta
		if samples[index].z <= 0.0:
			samples.remove_at(index)
	_sample_remaining -= delta
	var player := get_parent()
	if player.state == player.State.DASH and _sample_remaining <= 0.0:
		samples.append(Vector3(player.global_position.x, player.global_position.y, 0.16))
		_sample_remaining = 0.025
	queue_redraw()


func _draw() -> void:
	for sample in samples:
		var fade := sample.z / 0.16
		draw_rect(Rect2(Vector2(sample.x - 12, sample.y - 40), Vector2(24, 40)), Color(1.0, 0.65, 0.15, fade * 0.32))
		draw_line(Vector2(sample.x - 8, sample.y - 20), Vector2(sample.x + 8, sample.y - 20), Color(1.0, 0.85, 0.4, fade * 0.5), 2.0)
