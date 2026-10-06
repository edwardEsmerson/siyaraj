extends Node2D
## Grounded weapon arenas connected by a safe movement/recharge lane.
const PlayerScene = preload("res://scenes/player/player.tscn")
const PrototypePlayer = preload("res://scripts/player/weapons_playground_player.gd")
const PrototypeSparkler = preload("res://scripts/combat/prototype_sparkler.gd")
const Dummy = preload("res://scripts/combat/weapon_dummy.gd")
const GuardScene = preload("res://scenes/enemies/enemy.tscn")

const MAP_WIDTH: int = 4200
const FLOOR_Y: float = 460.0
const CHAKRI_CENTER: float = 2850.0

var player: CharacterBody2D
var status: Label
var camera: Camera2D


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.055, 0.07, 0.11))
	_add_platform(Rect2(0, FLOOR_Y, MAP_WIDTH, 80), Color(0.15, 0.19, 0.27))
	_add_platform(Rect2(-24, 0, 24, 540), Color(0.15, 0.19, 0.27))
	_add_platform(Rect2(MAP_WIDTH, 0, 24, 540), Color(0.15, 0.19, 0.27))
	# Combat stays flat with clear overhead space. Obstacles are in the safe lane.
	_add_platform(Rect2(1850, 425, 80, 35), Color(0.25, 0.35, 0.42))
	_add_platform(Rect2(2130, 425, 80, 35), Color(0.25, 0.35, 0.42))
	_add_platform(Rect2(2410, 425, 80, 35), Color(0.25, 0.35, 0.42))
	_add_sign(Vector2(70, 185), "01 / GHATS / SPARKLER", "J: one lash. Jump + J: aerial lash.\nPractise here while your specials recharge.", Color(1, 0.45, 0.65))
	_add_sign(Vector2(920, 185), "02 / FOREST / SKYSHOT", "L: fire ahead. Recoil pushes you back.\nFive shots per round. Death or next level refills.", Color(1, 0.7, 0.2))
	_add_sign(Vector2(1740, 185), "RECOVERY LANE", "Space: jump the low blocks. Shift: air dash.\nRun back and forth while the HUD timers count down.", Color(0.6, 0.8, 0.9))
	_add_sign(Vector2(2650, 185), "03 / PALACE / CHAKRI", "Stand on the ring. Hold K for 1 sec, then release.\nClear both sides. Cooldown: 30 sec; J stays available.", Color(0.2, 0.95, 0.8))
	_add_sign(Vector2(3560, 185), "LIVE GUARD / MIXED PRACTICE", "Orange means wind-up. Dodge, land, then strike.\nUse specials when ready. R resets everything.", Color(0.8, 0.7, 1))
	_add_dummy("SparklerDummy", Vector2(390, FLOOR_Y))
	_add_dummy("SparklerPractice", Vector2(600, FLOOR_Y), false, 3)
	_add_dummy("SkyshotTarget", Vector2(1210, FLOOR_Y), false, 4)
	_add_dummy("SkyshotFarTarget", Vector2(1500, FLOOR_Y), false, 4)
	_add_dummy("CrowdLeft", Vector2(CHAKRI_CENTER - 95, FLOOR_Y), false, 3)
	_add_dummy("CrowdMiddle", Vector2(CHAKRI_CENTER, FLOOR_Y), false, 3)
	_add_dummy("CrowdRight", Vector2(CHAKRI_CENTER + 95, FLOOR_Y), false, 3)
	_add_dummy("CooldownPractice", Vector2(3270, FLOOR_Y), false, 3)
	var guard := GuardScene.instantiate()
	guard.name = "Guard"
	guard.position = Vector2(3930, FLOOR_Y)
	guard.patrol_radius = 75.0
	guard.detection_range = 160.0
	add_child(guard)
	player = PlayerScene.instantiate()
	player.set_script(PrototypePlayer)
	player.movement_settings = preload("res://resources/player/default_movement.tres")
	player.get_node("Sparkler").set_script(PrototypeSparkler)
	player.name = "Player"
	player.position = Vector2(150, 460)
	add_child(player)
	player.died.connect(_on_player_died)
	camera = Camera2D.new()
	camera.position = Vector2(480, 270)
	camera.limit_left = 0
	camera.limit_right = MAP_WIDTH
	camera.limit_top = 0
	camera.limit_bottom = 540
	add_child(camera)
	var hud := CanvasLayer.new()
	add_child(hud)
	var panel := ColorRect.new()
	panel.position = Vector2(16, 14)
	panel.size = Vector2(928, 147)
	panel.color = Color(0.04, 0.055, 0.085, 0.96)
	hud.add_child(panel)
	var heading := Label.new()
	heading.position = Vector2(30, 22)
	heading.add_theme_font_size_override("font_size", 24)
	heading.text = "SIYARAJ / three-weapon playground"
	hud.add_child(heading)
	var controls := Label.new()
	controls.position = Vector2(30, 58)
	controls.text = "A/D: move    Space: jump    Shift: air dash    J: sparkler    L: skyshot\nHold/release K: chakri    R: reset    Walk right through practice arenas and recovery lane"
	hud.add_child(controls)
	status = Label.new()
	status.position = Vector2(30, 112)
	status.add_theme_color_override("font_color", Color(1, 0.8, 0.4))
	hud.add_child(status)


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("restart") or player.position.y > 620:
		get_tree().reload_current_scene()
		return
	camera.position.x = clampf(player.position.x, 480.0, MAP_WIDTH - 480.0)
	status.text = "Health %d/%d    Dash: %s    %s" % [player.health, player.max_health, "ready" if player.dash_available else "land to recharge", player.attack_status]
	status.text += "\nSkyshot: %d/5 shots    Chakri: %s" % [player.skyshot_ammo, _cooldown_text(player.chakri_cooldown_remaining)]


func _cooldown_text(remaining: float) -> String:
	return "READY" if remaining <= 0.0 else "%ds" % ceili(remaining)


func _on_player_died() -> void:
	await get_tree().create_timer(0.6).timeout
	get_tree().reload_current_scene()


func _add_platform(rect: Rect2, color: Color) -> void:
	var platform := StaticBody2D.new()
	platform.position = rect.position
	platform.collision_layer = 1
	platform.collision_mask = 0
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collider.shape = shape
	collider.position = rect.size * 0.5
	platform.add_child(collider)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([Vector2.ZERO, Vector2(rect.size.x, 0), rect.size, Vector2(0, rect.size.y)])
	visual.color = color
	visual.z_index = -1
	platform.add_child(visual)
	add_child(platform)


func _add_dummy(title: String, at: Vector2, armour: bool = false, durability: int = 12) -> void:
	var dummy := Dummy.new()
	dummy.name = title
	dummy.position = at
	dummy.shielded = armour
	dummy.max_health = durability
	add_child(dummy)


func _add_sign(at: Vector2, title: String, instructions: String, tint: Color) -> void:
	var label := Label.new()
	label.position = at
	label.text = title + "\n\n" + instructions
	label.add_theme_color_override("font_color", tint)
	label.add_theme_font_size_override("font_size", 18)
	add_child(label)


func _draw() -> void:
	# Arena colours and floor markers explain the layout without more controls.
	var zones := [
		Rect2(40, 174, 680, 286), Rect2(880, 174, 760, 286),
		Rect2(1700, 174, 820, 286), Rect2(2610, 174, 800, 286),
		Rect2(3510, 174, 650, 286),
	]
	var colours := [Color(1, 0.45, 0.65), Color(1, 0.7, 0.2),
		Color(0.6, 0.8, 0.9), Color(0.2, 0.95, 0.8), Color(0.8, 0.7, 1)]
	for index in range(zones.size()):
		var tint: Color = colours[index]
		tint.a = 0.035
		draw_rect(zones[index], tint)
		tint.a = 0.65
		draw_line(Vector2(zones[index].position.x, FLOOR_Y - 2), Vector2(zones[index].end.x, FLOOR_Y - 2), tint, 3)
		# Small diya placeholders mark each safe entrance.
		var diya := Vector2(zones[index].position.x + 12, FLOOR_Y - 4)
		draw_arc(diya, 8, 0, PI, 12, tint, 3)
		draw_circle(diya + Vector2(0, -8), 4, tint)
	# The firing line leaves distance to the targets and clear space for recoil.
	var firing_x := 970.0
	draw_line(Vector2(firing_x, FLOOR_Y - 2), Vector2(firing_x, 488), Color(1, 0.7, 0.2), 3)
	draw_string(ThemeDB.fallback_font, Vector2(firing_x - 65, 510), "FIRE FROM HERE", HORIZONTAL_ALIGNMENT_CENTER, 130, 14, Color(1, 0.7, 0.2))
	# The targets sit within full-charge reach on either side of this ring.
	var ring_color := Color(0.2, 0.95, 0.8, 0.65)
	draw_ellipse_marker(Vector2(CHAKRI_CENTER, FLOOR_Y - 3), ring_color)
	draw_string(ThemeDB.fallback_font, Vector2(CHAKRI_CENTER - 55, 507), "CHARGE HERE", HORIZONTAL_ALIGNMENT_CENTER, 110, 14, ring_color)
	for x in [800, 1670, 2560, 3450]:
		draw_line(Vector2(x - 12, 499), Vector2(x + 12, 499), Color(0.6, 0.8, 0.9), 2)
		draw_line(Vector2(x + 12, 499), Vector2(x + 4, 493), Color(0.6, 0.8, 0.9), 2)
		draw_line(Vector2(x + 12, 499), Vector2(x + 4, 505), Color(0.6, 0.8, 0.9), 2)


func draw_ellipse_marker(at: Vector2, tint: Color) -> void:
	var points := PackedVector2Array()
	for index in range(33):
		var angle := index * TAU / 32.0
		points.append(at + Vector2(cos(angle) * 110, sin(angle) * 8))
	draw_polyline(points, tint, 3)
