extends Node2D
## Robin, Siya's bird companion. He flies free of collisions, follows Siya, perches on her
## head when she stands still, points out hints and comments on what happens. He never
## deals or takes damage. Cutscenes and the boss fight drive him with take_control().
const Burst = preload("res://scripts/effects/burst.gd")

signal arrived
signal spoke(text: String)

enum Mode { FOLLOW, PERCH, POINT, SCRIPTED }

## Reaction lines, picked at random. Writers can edit these freely.
const LINES: Dictionary = {
	&"hurt": ["Ouch!", "Careful, Siya!", "That one stung.", "Shake it off!"],
	&"down": ["SIYA!", "Get up, get up!"],
	&"enemy": ["Look out!", "Trouble ahead!", "One of Swaminathan's goons!"],
	&"idle": ["Raj won't rescue himself.", "Nice hair. Very aerodynamic.", "Are we resting? I'm resting.", "Diwali is tomorrow, you know."],
	&"hello": ["Wait for me!", "Right behind you!"],
}

## Hover spot relative to Siya's feet while following. X is mirrored by her facing.
@export var follow_offset: Vector2 = Vector2(-30.0, -64.0)
## Spot on Siya's head while perched.
@export var perch_offset: Vector2 = Vector2(0.0, -46.0)
@export var follow_stiffness: float = 7.0
@export var max_speed: float = 900.0
## Beyond this distance (scene reloads, room changes) Robin pops back beside Siya.
@export var teleport_distance: float = 700.0
@export var perch_delay: float = 2.0
@export var idle_chatter_delay: float = 9.0
@export var point_speed: float = 420.0
## A pointed hint ends early if Siya moves this far from the hint spot.
@export var point_leash: float = 380.0
@export var bubble_duration: float = 3.0
@export var warn_range: float = 260.0
@export var warn_cooldown: float = 5.0
@export var reaction_cooldown: float = 2.5

## Hint ids already shown this session. Survives death reloads; reset by forget_hints().
static var seen_hints: Dictionary = {}

var mode: Mode = Mode.FOLLOW
var player: CharacterBody2D
var velocity: Vector2 = Vector2.ZERO
var facing: int = 1
var _placed: bool = false
var _idle_time: float = 0.0
var _chattered: bool = false
var _bubble_remaining: float = 0.0
var _point_at: Vector2
var _point_remaining: float = 0.0
var _scripted_target: Vector2
var _scripted_speed: float = 0.0
var _scripted_moving: bool = false
var _warn_remaining: float = 0.0
var _scan_remaining: float = 0.0
var _reaction_remaining: float = 0.0
var _warned: Dictionary = {}
var _time: float = 0.0

@onready var visuals: Node2D = $Visuals
@onready var placeholder: Node2D = $Visuals/Placeholder
@onready var wing: Polygon2D = $Visuals/Placeholder/Wing
@onready var sprite: AnimatedSprite2D = $Visuals/Sprite
@onready var bubble: PanelContainer = $Bubble
@onready var bubble_label: Label = $Bubble/Text


static func forget_hints() -> void:
	seen_hints.clear()


func _ready() -> void:
	add_to_group("robin")
	bubble.visible = false
	# Art lives in $Visuals/Sprite as SpriteFrames with "fly" and "perch" animations
	# (optional: "talk" while perched, "point"). Without frames the polygons stand in.
	var has_art := sprite.sprite_frames != null
	sprite.visible = has_art
	placeholder.visible = not has_art


func _physics_process(delta: float) -> void:
	_time += delta
	_bubble_remaining = maxf(_bubble_remaining - delta, 0.0)
	_warn_remaining = maxf(_warn_remaining - delta, 0.0)
	_reaction_remaining = maxf(_reaction_remaining - delta, 0.0)
	bubble.visible = _bubble_remaining > 0.0
	if player == null or not is_instance_valid(player):
		_find_player()
	match mode:
		Mode.FOLLOW:
			_process_follow(delta)
		Mode.PERCH:
			_process_perch(delta)
		Mode.POINT:
			_process_point(delta)
		Mode.SCRIPTED:
			_process_scripted(delta)
	_update_visuals()


func _find_player() -> void:
	player = get_tree().get_first_node_in_group("players") as CharacterBody2D
	if player == null:
		return
	player.died.connect(func() -> void: react(&"down", true))
	player.health_changed.connect(func(remaining: int) -> void:
		if remaining > 0:
			react(&"hurt")
	)


func _follow_spot() -> Vector2:
	var offset := Vector2(follow_offset.x * player.facing_direction, follow_offset.y)
	return player.global_position + offset + Vector2(0.0, sin(_time * 3.2) * 5.0)


func _process_follow(delta: float) -> void:
	if player == null:
		return
	var spot := _follow_spot()
	if not _placed or global_position.distance_to(spot) > teleport_distance:
		snap_to(spot)
		return
	_fly_toward(spot, delta)
	if player.state == player.State.DEAD:
		return
	_scan_for_enemies(delta)
	var resting: bool = player.state == player.State.NORMAL and player.is_on_floor() and player.velocity.length() < 5.0
	_idle_time = _idle_time + delta if resting else 0.0
	if _idle_time >= perch_delay and _bubble_remaining <= 0.0:
		mode = Mode.PERCH
		_chattered = false


func _process_perch(delta: float) -> void:
	if player == null:
		mode = Mode.FOLLOW
		return
	var resting: bool = player.state == player.State.NORMAL and player.is_on_floor() and player.velocity.length() < 5.0
	if not resting:
		# Hop off with a little flap rather than sliding with her.
		mode = Mode.FOLLOW
		_idle_time = 0.0
		velocity = Vector2(-player.facing_direction * 60.0, -140.0)
		return
	var seat := player.global_position + perch_offset
	if global_position.distance_to(seat) > 2.0:
		_fly_toward(seat, delta)
		if global_position.distance_to(seat) < 6.0:
			global_position = seat
			velocity = Vector2.ZERO
	else:
		global_position = seat
		velocity = Vector2.ZERO
	_idle_time += delta
	if not _chattered and _idle_time >= idle_chatter_delay:
		_chattered = true
		react(&"idle", true)


func _process_point(delta: float) -> void:
	_point_remaining = maxf(_point_remaining - delta, 0.0)
	_fly_toward(_point_at + Vector2(0.0, sin(_time * 4.0) * 4.0), delta, point_speed)
	var wandered: bool = player != null and player.global_position.distance_to(_point_at) > point_leash
	if _point_remaining <= 0.0 or wandered or (player != null and player.state == player.State.DEAD):
		mode = Mode.FOLLOW


func _process_scripted(delta: float) -> void:
	if not _scripted_moving:
		velocity = Vector2.ZERO
		return
	var step := _scripted_speed * delta
	var to_target := _scripted_target - global_position
	if to_target.length() <= step:
		global_position = _scripted_target
		velocity = Vector2.ZERO
		_scripted_moving = false
		arrived.emit()
		return
	velocity = to_target.normalized() * _scripted_speed
	global_position += velocity * delta


## Spring toward a spot. The pull grows with distance, so a dash never leaves him far behind.
func _fly_toward(spot: Vector2, delta: float, speed_limit: float = max_speed) -> void:
	var desired := (spot - global_position) * follow_stiffness
	velocity = velocity.lerp(desired.limit_length(speed_limit), 1.0 - exp(-10.0 * delta))
	global_position += velocity * delta


func _scan_for_enemies(delta: float) -> void:
	_scan_remaining -= delta
	if _scan_remaining > 0.0 or _warn_remaining > 0.0 or _bubble_remaining > 0.0:
		return
	_scan_remaining = 0.2
	var enemies := _new_enemies_near(player.global_position, warn_range)
	if enemies.is_empty():
		return
	_warned[enemies[0].get_instance_id()] = true
	_warn_remaining = warn_cooldown
	react(&"enemy", true)
	Burst.spawn(get_tree().current_scene, global_position + Vector2(0, -14), Color(1.0, 0.85, 0.3), "!", 14.0)


## Living enemy bodies within radius that Robin has not called out yet.
func _new_enemies_near(center: Vector2, radius: float) -> Array[Object]:
	var circle := CircleShape2D.new()
	circle.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, center)
	query.collision_mask = 4
	var found: Array[Object] = []
	for result in get_world_2d().direct_space_state.intersect_shape(query):
		var enemy: Object = result.collider
		var health: Variant = enemy.get("health")
		if not _warned.has(enemy.get_instance_id()) and (health == null or int(health) > 0):
			found.append(enemy)
	return found


func _update_visuals() -> void:
	if mode == Mode.PERCH and velocity.is_zero_approx():
		if player != null:
			facing = player.facing_direction
	elif absf(velocity.x) > 20.0:
		facing = 1 if velocity.x > 0.0 else -1
	elif player != null and mode == Mode.FOLLOW:
		facing = player.facing_direction
	visuals.scale.x = float(facing)
	var perched := mode == Mode.PERCH and velocity.is_zero_approx()
	if placeholder.visible:
		wing.scale.y = 0.35 if perched else 0.4 + absf(sin(_time * 18.0)) * 0.9
	elif sprite.visible:
		var animation: StringName = &"perch" if perched else &"fly"
		# The talk frames are drawn perched; in flight he talks with his wings.
		if perched and _bubble_remaining > 0.0 and sprite.sprite_frames.has_animation(&"talk"):
			animation = &"talk"
		if mode == Mode.POINT and sprite.sprite_frames.has_animation(&"point"):
			animation = &"point"
		if sprite.animation != animation and sprite.sprite_frames.has_animation(animation):
			sprite.play(animation)


## Show a speech bubble above Robin. Works in every mode, including scripted scenes.
func say(text: String, duration: float = bubble_duration) -> void:
	bubble_label.text = _wrap(text, 30)
	bubble.reset_size()
	bubble.position = Vector2(-bubble.size.x * 0.5, -bubble.size.y - 20.0)
	bubble.visible = true
	_bubble_remaining = duration
	spoke.emit(text)


## Break on spaces so the bubble sizes itself predictably, unlike Label autowrap.
static func _wrap(text: String, width: int) -> String:
	var lines: PackedStringArray = []
	var line := ""
	for word in text.split(" ", false):
		if not line.is_empty() and line.length() + 1 + word.length() > width:
			lines.append(line)
			line = word
		else:
			line = word if line.is_empty() else line + " " + word
	lines.append(line)
	return "\n".join(lines)


## Say a random line from LINES. Reactions share a cooldown unless forced.
func react(event: StringName, force: bool = false) -> void:
	if not LINES.has(event) or (_reaction_remaining > 0.0 and not force):
		return
	_reaction_remaining = reaction_cooldown
	var lines: Array = LINES[event]
	say(lines[randi() % lines.size()])


## Fly to a spot and explain something there. Hints with an id are shown once per session.
func point_out(at: Vector2, text: String, hint_id: String = "", duration: float = 3.5) -> bool:
	if mode == Mode.SCRIPTED or (not hint_id.is_empty() and seen_hints.has(hint_id)):
		return false
	if not hint_id.is_empty():
		seen_hints[hint_id] = true
	# A hint about an enemy already counts as the warning for it.
	for enemy in _new_enemies_near(at, warn_range * 2.0):
		_warned[enemy.get_instance_id()] = true
	mode = Mode.POINT
	_point_at = at
	_point_remaining = duration
	_idle_time = 0.0
	say(text, duration)
	return true


## Hand Robin to a cutscene or boss script. He stops following until release_control().
func take_control() -> void:
	mode = Mode.SCRIPTED
	_scripted_moving = false
	velocity = Vector2.ZERO


func release_control() -> void:
	mode = Mode.FOLLOW
	_scripted_moving = false
	_idle_time = 0.0


## Scripted flight in a straight line. Usage: robin.take_control(); await robin.fly_to(spot)
func fly_to(at: Vector2, speed: float = point_speed) -> Signal:
	if mode != Mode.SCRIPTED:
		take_control()
	_scripted_target = at
	_scripted_speed = maxf(speed, 1.0)
	_scripted_moving = true
	return arrived


## Place Robin immediately, e.g. at the start of a cutscene.
func snap_to(at: Vector2) -> void:
	global_position = at
	reset_physics_interpolation()
	velocity = Vector2.ZERO
	_placed = true
