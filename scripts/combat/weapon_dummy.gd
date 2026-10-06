extends CharacterBody2D
## Durable, respawning projectile and melee practice target.
@export var shielded: bool = false
@export var max_health: int = 12
@export var gravity: float = 1800.0
var health: int = 12
var stagger_time: float = 0.0
var reset_time: float = 0.0
var flash_time: float = 0.0
var home: Vector2
var last_hit: String = "Ready"
var total_hits: int = 0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	home = position
	health = max_health
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 40)
	collider.shape = shape
	collider.position.y = -20
	add_child(collider)


func _physics_process(delta: float) -> void:
	stagger_time = maxf(stagger_time - delta, 0.0)
	flash_time = maxf(flash_time - delta, 0.0)
	if health <= 0:
		reset_time -= delta
		if reset_time <= 0.0:
			health = max_health
			collision_layer = 4
			position = home
			velocity = Vector2.ZERO
			last_hit = "Respawned"
	else:
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
		velocity.y = minf(velocity.y + gravity * delta, 900.0)
		move_and_slide()
		if is_on_floor() and absf(position.x - home.x) > 2 and stagger_time <= 0.0:
			position.x = move_toward(position.x, home.x, 70.0 * delta)
	queue_redraw()


func take_damage(amount: int, knockback: Vector2) -> void:
	take_weapon_damage(amount, knockback, "sparkler")


func take_weapon_damage(amount: int, knockback: Vector2, weapon: String) -> void:
	if health <= 0 or amount <= 0:
		return
	if shielded and stagger_time <= 0.0 and weapon != "skyshot":
		last_hit = "BLOCKED"
		flash_time = 0.12
		return
	if weapon == "skyshot":
		stagger_time = 1.6
	health = maxi(health - amount, 0)
	total_hits += 1
	velocity = knockback
	flash_time = 0.12
	last_hit = "%s -%d" % [weapon.to_upper(), amount]
	if health == 0:
		collision_layer = 0
		reset_time = 1.5
		last_hit = "Respawn in 1.5s"


func _draw() -> void:
	var color := Color(1.0, 0.4, 0.65) if not shielded else Color(0.5, 0.65, 0.9)
	if health <= 0:
		color.a = 0.25
	elif flash_time > 0.0:
		color = Color.WHITE
	draw_rect(Rect2(-14, -40, 28, 40), color)
	draw_circle(Vector2(0, -25), 5, Color(0.12, 0.15, 0.23))
	if shielded and stagger_time <= 0.0:
		draw_arc(Vector2(0, -20), 24, 0, TAU, 24, Color(0.5, 0.75, 1), 3)
	var title := "Armour" if shielded else "Dummy"
	draw_string(ThemeDB.fallback_font, Vector2(-60, -78), "%s %d/%d" % [title, health, max_health], HORIZONTAL_ALIGNMENT_CENTER, 120, 14)
	draw_string(ThemeDB.fallback_font, Vector2(-60, -99), last_hit, HORIZONTAL_ALIGNMENT_CENTER, 120, 13)
