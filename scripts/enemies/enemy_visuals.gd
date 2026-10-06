extends Node2D
## Presentation follows combat; it never owns movement, collision or attack timing.
@export_enum("basic-rakshas", "brute", "ground-shooter", "winged-forest-demon") var subject: String = "basic-rakshas"

const FRAMES := {
	"basic-rakshas": preload("res://assets/sprites/basic-rakshas/cast_frames.tres"),
	"brute": preload("res://assets/sprites/brute/cast_frames.tres"),
	"ground-shooter": preload("res://assets/sprites/ground-shooter/cast_frames.tres"),
	"winged-forest-demon": preload("res://assets/sprites/winged-forest-demon/cast_frames.tres"),
}
const ANCHORS := {
	"basic-rakshas": Vector2(96, 135), "brute": Vector2(104, 195),
	"ground-shooter": Vector2(72, 135), "winged-forest-demon": Vector2(64, 71),
}
var actor: CharacterBody2D
var sprite: AnimatedSprite2D
var _fire_remaining: float = 0.0


func _ready() -> void:
	actor = get_parent()
	process_physics_priority = 10
	sprite = AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = FRAMES[subject]
	sprite.centered = false
	sprite.offset = -ANCHORS[subject]
	sprite.scale = Vector2(0.5, 0.5)
	add_child(sprite)
	for node_name in ["Body", "Eye", "Pupil"]:
		var placeholder := actor.get_node_or_null(node_name) as CanvasItem
		if placeholder != null:
			placeholder.hide()
	actor.died.connect(_show_death)
	if actor.has_signal("shot_fired"):
		actor.shot_fired.connect(_on_shot_fired)
	sprite.play(&"fly" if subject == "winged-forest-demon" else &"walk")


func _on_shot_fired() -> void:
	_fire_remaining = 0.16


func _physics_process(delta: float) -> void:
	_fire_remaining = maxf(_fire_remaining - delta, 0.0)
	var melee := actor.get_node_or_null("MeleeAttack")
	var direction: int = actor._direction
	if melee != null and melee.is_busy():
		direction = melee.direction
	elif melee == null and actor.state in [actor.State.CHARGING, actor.State.RECOVERY]:
		direction = 1 if actor._aim_direction.x >= 0.0 else -1
	scale.x = float(direction)
	sprite.modulate = actor.body.modulate
	if melee != null and melee.is_busy():
		# First two frames anticipate, third hits, fourth recovers.
		var frame := 2
		if melee.phase == melee.Phase.WINDUP:
			frame = 0 if melee._remaining > melee.windup_time * 0.5 else 1
		elif melee.phase == melee.Phase.RECOVERY:
			frame = 3
		_set_pose(&"attack", frame)
		return
	var animation: StringName
	if melee != null:
		animation = &"walk" if absf(actor.velocity.x) > 3.0 else &"idle"
	elif actor.state == actor.State.CHARGING:
		animation = &"charge"
	elif _fire_remaining > 0.0 and actor.state == actor.State.RECOVERY:
		animation = &"fire" if subject == "ground-shooter" else &"dive"
	elif actor.state == actor.State.RECOVERY:
		animation = &"recovery"
	else:
		animation = &"fly" if subject == "winged-forest-demon" else &"walk"
	if sprite.animation != animation or not sprite.is_playing():
		sprite.play(animation)


func _set_pose(animation: StringName, frame: int) -> void:
	sprite.animation = animation
	sprite.pause()
	sprite.frame = frame


func _show_death() -> void:
	# Bodies despawn immediately as before; a harmless sprite finishes the defeat.
	var corpse := Node2D.new()
	corpse.name = "EnemyDefeat"
	corpse.add_to_group("enemy_defeat_visuals")
	actor.get_parent().add_child(corpse)
	corpse.global_transform = global_transform
	corpse.z_index = actor.z_index
	var art := AnimatedSprite2D.new()
	art.sprite_frames = sprite.sprite_frames
	art.centered = false
	art.offset = sprite.offset
	art.scale = sprite.scale
	corpse.add_child(art)
	art.play(&"death")
	var duration := float(art.sprite_frames.get_frame_count(&"death")) / art.sprite_frames.get_animation_speed(&"death")
	var tween := corpse.create_tween()
	tween.tween_interval(duration + 0.25)
	tween.tween_property(art, "modulate:a", 0.0, 0.2)
	tween.tween_callback(corpse.queue_free)
