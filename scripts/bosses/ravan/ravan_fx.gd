extends RefCounted
## Swaminathan's attack effect art: generated pixel-art frames in
## res://assets/sprites/swaminathan/effects/<name>/NN.png, gathered in
## effects_frames.tres (one animation per effect, with each pivot in art px in its
## `pivots` metadata). Packaged from
## asset-builder/sprites/swami-* by tools/swaminathan_effects.py.
## Every effect is placed at scale 0.5 (1 game unit = 2 art px), nearest filtered.

const DIR: String = "res://assets/sprites/swaminathan/effects/"

static var _frames: SpriteFrames


static func has(effect: StringName) -> bool:
	_load()
	return _frames.has_animation(effect)


static func frame_count(effect: StringName) -> int:
	return _frames.get_frame_count(effect) if has(effect) else 0


static func texture(effect: StringName, index: int = 0) -> Texture2D:
	var count := frame_count(effect)
	return _frames.get_frame_texture(effect, posmod(index, count)) if count > 0 else null


## The frame of a looping effect at `age` seconds.
static func texture_at(effect: StringName, age: float) -> Texture2D:
	return texture(effect, int(age * _frames.get_animation_speed(effect))) if has(effect) else null


## Pivot in art px: the point placed on the node origin.
static func pivot(effect: StringName) -> Vector2:
	_load()
	return _frames.get_meta(&"pivots", {}).get(String(effect), Vector2.ZERO)


static func sprite(effect: StringName) -> AnimatedSprite2D:
	if not has(effect):
		return null
	var node := AnimatedSprite2D.new()
	node.sprite_frames = _frames
	node.centered = false
	node.scale = Vector2(0.5, 0.5)
	node.offset = -pivot(effect)
	node.animation = effect
	node.play(effect)
	return node


## A one-shot effect that frees itself when its frames finish.
static func burst(parent: Node, effect: StringName, at: Vector2, angle: float = 0.0, tint: Color = Color.WHITE) -> AnimatedSprite2D:
	var node := sprite(effect)
	if node == null or not is_instance_valid(parent):
		return null
	node.rotation = angle
	node.modulate = tint
	node.z_index = 5
	node.animation_finished.connect(node.queue_free)
	parent.add_child(node)
	node.global_position = at
	node.reset_physics_interpolation()
	return node


## A one-shot head animation (from the head's own SpriteFrames), e.g. destroyed.
static func head_sprite(anim: StringName, head_frames: SpriteFrames, offset: Vector2) -> AnimatedSprite2D:
	if head_frames == null or not head_frames.has_animation(anim):
		return null
	var node := AnimatedSprite2D.new()
	node.sprite_frames = head_frames
	node.centered = false
	node.scale = Vector2(0.5, 0.5)
	node.offset = offset
	node.speed_scale = 0.75
	node.animation_finished.connect(node.queue_free)
	node.play(anim)
	return node


## Draws effect frame `tex` with its pivot at `at` on `item`, at art scale.
static func draw(item: CanvasItem, effect: StringName, tex: Texture2D, at: Vector2, tint: Color = Color.WHITE) -> void:
	if tex == null:
		return
	item.draw_set_transform(at, 0.0, Vector2(0.5, 0.5))
	item.draw_texture(tex, -pivot(effect), tint)
	item.draw_set_transform(Vector2.ZERO)


static func _load() -> void:
	if _frames != null:
		return
	var path := DIR + "effects_frames.tres"
	_frames = load(path) if ResourceLoader.exists(path) else SpriteFrames.new()
