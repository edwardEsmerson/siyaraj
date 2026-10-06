extends Node2D
## Sample world positions so the trail stays behind when Siya moves or turns.

var samples: Array[Vector3] = []
var _poses: Array[Dictionary] = []
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
			_poses.remove_at(index)
	_sample_remaining -= delta
	var player := get_parent()
	if player.state == player.State.DASH and _sample_remaining <= 0.0:
		samples.append(Vector3(player.global_position.x, player.global_position.y, 0.16))
		var sprite: AnimatedSprite2D = player.get_node("Visuals/Sprite")
		_poses.append({"texture": sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame), "facing": -1 if sprite.flip_h else 1})
		_sample_remaining = 0.025
	queue_redraw()


func _draw() -> void:
	for index in samples.size():
		var sample: Vector3 = samples[index]
		var fade := sample.z / 0.16
		var pose: Dictionary = _poses[index]
		draw_set_transform(Vector2(sample.x, sample.y), 0.0, Vector2(0.5 * pose.facing, 0.5))
		draw_texture(pose.texture, Vector2(-64, -112), Color(1.0, 0.75, 0.4, fade * 0.32))
	draw_set_transform(Vector2.ZERO)
