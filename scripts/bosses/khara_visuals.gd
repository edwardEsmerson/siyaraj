extends Node2D
## Registered body and separate gada use the boss's existing state durations.
const FRAMES = preload("res://assets/sprites/khara/cast_frames.tres")
const GADA = preload("res://assets/sprites/khara-gada/sprite.png")
var boss: CharacterBody2D
var sprite: AnimatedSprite2D
var weapon: Sprite2D
var registrations: Dictionary


func _ready() -> void:
	boss = get_parent().get_parent()
	process_physics_priority = 10
	registrations = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/khara/cast_meta.json"))["attachment"]["frames"]
	for child in get_parent().get_children():
		if child is CanvasItem and child != self:
			child.hide()
	sprite = AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = FRAMES
	sprite.centered = false
	sprite.offset = Vector2(-173, -300)
	sprite.scale = Vector2(0.5, 0.5)
	add_child(sprite)
	weapon = Sprite2D.new()
	weapon.name = "GadaArt"
	weapon.texture = GADA
	weapon.centered = false
	weapon.offset = Vector2(-96, -130)
	weapon.scale = Vector2(0.5, 0.5)
	add_child(weapon)
	_physics_process(0.0)


func _physics_process(_delta: float) -> void:
	var animation: StringName = &"idle"
	var duration := 0.0
	match boss.state:
		boss.State.INTRO:
			animation = &"intro_roar"
			duration = boss.intro_time
		boss.State.APPROACH:
			animation = &"walk"
		boss.State.SLAM_WINDUP:
			animation = &"slam_windup"
			duration = boss.current_slam_windup()
		boss.State.SLAM_ACTIVE:
			animation = &"slam_impact"
			duration = boss.slam_active
		boss.State.SLAM_RECOVERY:
			animation = &"slam_recovery"
			duration = boss.current_slam_recovery()
		boss.State.LADI_CAST:
			animation = &"ladi_cast"
			duration = boss.ladi_cast_time
		boss.State.LADI_RECOVERY:
			animation = &"ladi_recovery"
			duration = boss.ladi_recovery
		boss.State.PHASE_SHIFT:
			animation = &"phase_shift_roar"
			duration = boss.phase_shift_time
		boss.State.DEAD:
			animation = &"death"
			duration = 1.0
	if duration > 0.0:
		var progress := clampf(boss._death_time / duration, 0.0, 0.999) if boss.state == boss.State.DEAD else clampf(1.0 - boss.state_remaining / duration, 0.0, 0.999)
		sprite.animation = animation
		sprite.pause()
		sprite.frame = mini(int(progress * FRAMES.get_frame_count(animation)), FRAMES.get_frame_count(animation) - 1)
	elif sprite.animation != animation or not sprite.is_playing():
		sprite.play(animation)
	var entry: Dictionary = registrations[animation][sprite.frame]
	var hand: Array = entry["hand_from_anchor_px"]
	weapon.position = Vector2(float(hand[0]), float(hand[1])) * 0.5
	weapon.rotation = deg_to_rad(float(entry["rotation_degrees"]))
	weapon.visible = entry["visible"]
