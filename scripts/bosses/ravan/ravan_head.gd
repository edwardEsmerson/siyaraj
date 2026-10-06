extends StaticBody2D
## One of Swaminathan's ten heads. Each head is its own hurtbox and art slot; the boss
## decides when it activates. Only a lit (active) head can be hurt.
const Burst = preload("res://scripts/effects/burst.gd")

signal attack_released(head: Node)
signal damaged(head: Node, remaining: int)
signal knocked_out(head: Node)
signal regrown(head: Node)

enum HeadState { IDLE, TELEGRAPH, ATTACK, EXHAUSTED, RETURNING, KNOCKED_OUT, REGROWING, FURY, DESTROYED }
enum Attack { FIRE, HOMING, ROAR, LIGHTNING, SPREAD }

const ATTACK_COLORS: Array[Color] = [
	Color(1.0, 0.45, 0.1),  # FIRE: orange flame
	Color(0.8, 0.4, 1.0),  # HOMING: matches the ground shooter's purple bolts
	Color(1.0, 0.85, 0.2),  # ROAR: gold
	Color(0.35, 0.85, 1.0),  # LIGHTNING: cyan
	Color(1.0, 0.3, 0.55),  # SPREAD: rose
]
const ATTACK_WORDS: Array[String] = ["FIRE BREATH", "HOMING", "ROAR", "LIGHTNING", "SPREAD"]
const ENEMY_BODY_LAYER: int = 4

@export var head_index: int = 0
@export var head_name: String = "Krodha"
@export var attack_kind: Attack = Attack.FIRE
@export var max_health: int = 2
## Where the head strikes from, relative to its home slot. Heads lunge down to attack,
## which brings them into sparkler reach.
@export var lunge_offset: Vector2 = Vector2(0, 85)
@export var lunge_time: float = 0.22
@export var regrow_time: float = 0.6

var state: HeadState = HeadState.IDLE
var health: int
var home_position: Vector2
var regen_time: float = 12.0
var regen_remaining: float = 0.0
var regen_paused: bool = false
var fury_lit: bool = false
var fury_silent: bool = false
var _remaining: float = 0.0
var _telegraph_time: float = 0.9
var _attack_time: float = 0.5
var _exhaust_time: float = 1.2
var _extension: float = 0.0
var _flash_remaining: float = 0.0
var _guard_feedback_cooldown: float = 0.0

@onready var visual: Node2D = $Visual
@onready var art: Node2D = $Visual/Art
@onready var placeholder: Node2D = $Visual/Placeholder
@onready var eyes: Node2D = $Visual/Placeholder/Eyes
@onready var collider: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	health = max_health
	home_position = position
	collision_layer = ENEMY_BODY_LAYER
	collision_mask = 0
	# Artists drop a Sprite2D texture or AnimatedSprite2D into Visual/Art; the
	# placeholder hides itself automatically.
	placeholder.visible = not _has_art()
	_update_feedback()


func _physics_process(delta: float) -> void:
	_flash_remaining = maxf(_flash_remaining - delta, 0.0)
	_guard_feedback_cooldown = maxf(_guard_feedback_cooldown - delta, 0.0)
	_remaining = maxf(_remaining - delta, 0.0)
	match state:
		HeadState.TELEGRAPH:
			if _remaining <= 0.0:
				state = HeadState.ATTACK
				_remaining = _attack_time
				attack_released.emit(self)
		HeadState.ATTACK:
			if _remaining <= 0.0:
				state = HeadState.EXHAUSTED
				_remaining = _exhaust_time
		HeadState.EXHAUSTED:
			if _remaining <= 0.0:
				state = HeadState.RETURNING
		HeadState.RETURNING:
			if _extension <= 0.0:
				state = HeadState.IDLE
		HeadState.KNOCKED_OUT:
			if not regen_paused:
				regen_remaining = maxf(regen_remaining - delta, 0.0)
				if regen_remaining <= 0.0:
					regrow()
		HeadState.REGROWING:
			if _remaining <= 0.0:
				state = HeadState.IDLE
				health = max_health
				collision_layer = ENEMY_BODY_LAYER
				regrown.emit(self)
	_extension = move_toward(_extension, _target_extension(), delta / maxf(lunge_time, 0.001))
	position = home_position + lunge_offset * _ease(_extension)
	_update_feedback()


func activate(telegraph_time: float, attack_time: float, exhaust_time: float) -> bool:
	if state != HeadState.IDLE:
		return false
	_telegraph_time = telegraph_time
	_attack_time = attack_time
	_exhaust_time = exhaust_time
	state = HeadState.TELEGRAPH
	_remaining = telegraph_time
	return true


func is_active() -> bool:
	return state == HeadState.TELEGRAPH or state == HeadState.ATTACK or state == HeadState.EXHAUSTED


func is_vulnerable() -> bool:
	return is_active()


func is_knocked_out() -> bool:
	return state == HeadState.KNOCKED_OUT


func telegraph_progress() -> float:
	if state != HeadState.TELEGRAPH:
		return 0.0
	return 1.0 - clampf(_remaining / maxf(_telegraph_time, 0.001), 0.0, 1.0)


## Cancel any pending attack and go home. Knocked-out heads stay knocked out.
func retreat() -> void:
	if is_active():
		state = HeadState.RETURNING
		_remaining = 0.0


func knock_out() -> void:
	if state == HeadState.KNOCKED_OUT or state == HeadState.DESTROYED:
		return
	state = HeadState.KNOCKED_OUT
	health = 0
	regen_remaining = regen_time
	collision_layer = 0
	Burst.spawn(get_tree().current_scene, global_position, Color(1.0, 0.9, 0.6), "KNOCKED OUT!", 34.0)
	knocked_out.emit(self)


## The head grows back with full health after a short invulnerable flash.
func regrow() -> void:
	if state != HeadState.KNOCKED_OUT:
		return
	state = HeadState.REGROWING
	_remaining = regrow_time
	regen_remaining = 0.0
	Burst.spawn(get_tree().current_scene, global_position, Color(0.6, 1.0, 0.8), "REGROW", 22.0)


## Super move: every head, even a knocked-out one, returns at once and stays guarded.
func enter_fury() -> void:
	if state == HeadState.DESTROYED:
		return
	state = HeadState.FURY
	health = max_health
	regen_remaining = 0.0
	collision_layer = ENEMY_BODY_LAYER
	fury_lit = false
	fury_silent = false


func exit_fury() -> void:
	if state != HeadState.FURY:
		return
	state = HeadState.IDLE
	fury_lit = false
	fury_silent = false


func destroy() -> void:
	if state == HeadState.DESTROYED:
		return
	state = HeadState.DESTROYED
	health = 0
	collision_layer = 0
	Burst.spawn(get_tree().current_scene, global_position, Color(1.0, 0.5, 0.2), "", 40.0)


func mouth_global() -> Vector2:
	return global_position + Vector2(0, 10)


func attack_color() -> Color:
	return ATTACK_COLORS[attack_kind]


func attack_word() -> String:
	return ATTACK_WORDS[attack_kind]


func take_damage(amount: int, _knockback: Vector2) -> void:
	if amount <= 0 or health <= 0:
		return
	if not is_vulnerable():
		if _guard_feedback_cooldown <= 0.0:
			_guard_feedback_cooldown = 0.3
			Burst.spawn(get_tree().current_scene, global_position, Color(0.6, 0.65, 0.75), "GUARDED", 14.0)
		return
	health = maxi(health - amount, 0)
	_flash_remaining = 0.09
	damaged.emit(self, health)
	if health == 0:
		knock_out()


func _target_extension() -> float:
	match state:
		HeadState.TELEGRAPH, HeadState.ATTACK, HeadState.EXHAUSTED:
			return 1.0
		HeadState.KNOCKED_OUT:
			return 0.45
		_:
			return 0.0


func _ease(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)


func _has_art() -> bool:
	if art is Sprite2D:
		return (art as Sprite2D).texture != null
	if art is AnimatedSprite2D:
		return (art as AnimatedSprite2D).sprite_frames != null
	return false


func _animation_name() -> StringName:
	match state:
		HeadState.TELEGRAPH:
			return &"telegraph"
		HeadState.ATTACK:
			return &"attack"
		HeadState.EXHAUSTED:
			return &"exhausted"
		HeadState.KNOCKED_OUT:
			return &"knocked_out"
		HeadState.REGROWING:
			return &"regrow"
		HeadState.FURY:
			return &"fury" if fury_lit and not fury_silent else &"idle"
		HeadState.DESTROYED:
			return &"destroyed"
	return &"idle"


func _update_feedback() -> void:
	var side := signf(home_position.x) if not is_zero_approx(home_position.x) else 1.0
	visual.rotation = 0.0
	visual.scale = Vector2.ONE
	visual.visible = true
	eyes.scale = Vector2.ONE
	var tint := Color.WHITE
	match state:
		HeadState.TELEGRAPH, HeadState.ATTACK:
			var glow := attack_color()
			tint = Color(0.6 + glow.r * 1.4, 0.6 + glow.g * 1.4, 0.6 + glow.b * 1.4)
		HeadState.EXHAUSTED:
			tint = Color(0.7, 0.75, 0.85)
			visual.rotation = 0.18 * side
		HeadState.KNOCKED_OUT:
			tint = Color(0.35, 0.3, 0.32)
			visual.rotation = 0.6 * side
			eyes.scale = Vector2(1.0, 0.25)
		HeadState.REGROWING:
			var grown := 1.0 - clampf(_remaining / maxf(regrow_time, 0.001), 0.0, 1.0)
			visual.scale = Vector2.ONE * lerpf(0.3, 1.0, grown)
			tint = Color(1.6, 2.0, 1.8)
		HeadState.FURY:
			if fury_silent:
				tint = Color(0.45, 0.85, 0.8)
				eyes.scale = Vector2(1.0, 0.25)
			elif fury_lit:
				tint = Color(2.0, 0.7, 0.45)
		HeadState.DESTROYED:
			visual.visible = false
	if _flash_remaining > 0.0:
		tint = Color(2.2, 2.2, 2.2)
	visual.modulate = tint
	if art is AnimatedSprite2D and (art as AnimatedSprite2D).sprite_frames != null:
		var sprite := art as AnimatedSprite2D
		var animation := _animation_name()
		if sprite.sprite_frames.has_animation(animation) and sprite.animation != animation:
			sprite.play(animation)
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	match state:
		HeadState.TELEGRAPH, HeadState.ATTACK:
			var color := attack_color()
			var progress := telegraph_progress() if state == HeadState.TELEGRAPH else 1.0
			color.a = 0.35
			draw_circle(Vector2.ZERO, 24.0 + progress * 4.0, color)
			color.a = 1.0
			draw_arc(Vector2.ZERO, 27.0, -PI * 0.5, -PI * 0.5 + TAU * maxf(progress, 0.01), 28, color, 3.0)
			draw_string(font, Vector2(-60, -34), attack_word() + "!", HORIZONTAL_ALIGNMENT_CENTER, 120, 13, color)
		HeadState.EXHAUSTED:
			draw_string(font, Vector2(-60, -30), "DAZED", HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Color(0.85, 0.9, 1.0))
		HeadState.KNOCKED_OUT:
			# Grey ring empties as the head approaches regrowth.
			var left := clampf(regen_remaining / maxf(regen_time, 0.001), 0.0, 1.0)
			draw_arc(Vector2.ZERO, 22.0, -PI * 0.5, -PI * 0.5 + TAU * maxf(left, 0.01), 24, Color(0.75, 0.75, 0.8, 0.8), 2.0)
		HeadState.FURY:
			if fury_lit and not fury_silent:
				draw_circle(Vector2.ZERO, 25.0, Color(1.0, 0.25, 0.1, 0.35))
		HeadState.DESTROYED:
			draw_circle(Vector2.ZERO, 6.0, Color(0.3, 0.12, 0.1))
