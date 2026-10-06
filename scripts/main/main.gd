extends Node2D

@export var fall_boundary: float = 580.0
@export var camera_look_ahead: float = 20.0
@export var camera_follow_speed: float = 8.0
@export var restart_delay: float = 0.0
@export var completion_title: String = "COURSE COMPLETE"
@export var completion_detail: String = "Guard defeated"
@export var completion_status: String = "Guard defeated. Finish reached!"
@export var next_level: String = ""
@export var showdown_scene: String = ""
@export var showdown_name: String = ""
@export var automatic_showdown: bool = false

@onready var player: CharacterBody2D = $Player
@onready var player_spawn: Marker2D = $TestCourse/PlayerSpawn
@onready var input_status: Label = $HUD/InputStatus
@onready var dash_status: Label = $HUD/DashStatus
@onready var health_status: Label = $HUD/HealthStatus
@onready var combat_status: Label = $HUD/CombatStatus
@onready var camera: Camera2D = $Camera2D

var checkpoint_guard: CanvasLayer
var _restarting: bool = false
var completed: bool = false
var elapsed: float = 0.0
var _course_width: int = 4200
@onready var course: Node2D = $TestCourse


func _enter_tree() -> void:
	# Follow after player, companion and course physics have updated.
	process_physics_priority = 10
	$Camera2D.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS


func _ready() -> void:
	if course.has_node("Boss") and not has_node("CampaignFlow"):
		var flow := preload("res://scenes/main/campaign_victory.tscn").instantiate()
		flow.boss_path = NodePath("../TestCourse/Boss")
		flow.destination_name = "the developer menu"
		add_child(flow)
	var completion := get_node_or_null("HUD/Completion")
	if completion != null:
		completion.continued.connect(_continue_course)
		completion.replayed.connect(PlaytestNavigation._restart)
		completion.menu_requested.connect(PlaytestNavigation.show_title)
	PlaytestNavigation.configure_course(course)
	if not PlaytestNavigation.snapshot.is_empty():
		combat_status.text = "E: light diya / Esc: pause and developer menu"
	player.global_position = player_spawn.global_position
	if course.has_method("restore_transition_state"):
		course.restore_transition_state(player)
	player.reset_physics_interpolation()
	player.died.connect(_restart)
	camera.position.x = player.global_position.x
	camera.limit_left = 0
	if course.has_signal("finished"):
		_course_width = course.level_width() if course.has_method("level_width") else course.COURSE_WIDTH
		course.finished.connect(_finish_course)
	camera.limit_right = _course_width
	camera.limit_top = 0
	camera.limit_bottom = 540
	_update_camera_region()
	if course.has_method("camera_region"):
		camera.position.y = clampf(player.position.y - 70.0, camera.limit_top + 270.0, camera.limit_bottom - 270.0)
	camera.reset_smoothing()
	camera.reset_physics_interpolation()
	var enemy := course.get_node_or_null("Enemy")
	if enemy != null:
		var encounter_name: String = enemy.enemy_name
		enemy.died.connect(func() -> void:
			combat_status.text = "%s defeated! Exit open; reach the flag." % encounter_name if course.has_signal("finished") else "%s defeated! Use Restart in the pause menu to replay." % encounter_name
		)

	if course.has_node("Checkpoints") and course.has_node("Encounters"):
		checkpoint_guard = preload("res://scripts/levels/checkpoint_guard.gd").new()
		add_child(checkpoint_guard)


func _process(delta: float) -> void:
	if not completed and not _restarting:
		elapsed += delta
	if course.has_method("hint_at"):
		$HUD/Milestone.text = course.hint_at(player.global_position.x)
		$HUD/InputStatus.text = "%.1f s" % elapsed
	health_status.text = "Siya health: %d/%d" % [player.health, player.max_health]
	var weapon_status := get_node_or_null("HUD/WeaponStatus") as Label
	if weapon_status != null:
		var cooldown: String = "READY" if player.chakri_cooldown_remaining <= 0.0 else "%ds" % ceili(player.chakri_cooldown_remaining)
		weapon_status.text = "Skyshot: %d/5    Chakri: %s    %s" % [player.skyshot_ammo, cooldown, "Hold K to charge; release to spin." if player.attack_status == "Ready" else player.attack_status]
	var dash_ready: bool = player.can_dash()
	if dash_ready:
		dash_status.text = "Rocket dash: READY"
	elif player.dash_available or player.is_on_floor():
		dash_status.text = "Rocket dash: cooling"
	else:
		dash_status.text = "Rocket dash: land to recharge"
	dash_status.modulate = Color(1.0, 0.72, 0.2) if dash_ready else Color(0.65, 0.68, 0.74)
	if _restarting:
		return
	var death_y: float = course.death_boundary() if course.has_method("death_boundary") else fall_boundary
	if player.global_position.y > death_y:
		player.die()


func _physics_process(delta: float) -> void:
	# Track on the same clock as Siya and Robin; Godot interpolates between ticks.
	# Fixed vertical framing prevents jump/dash motion from moving the landing floor.
	# Ease horizontal look-ahead when turning so the camera does not snap.
	var target_x := clampf(player.global_position.x + player.facing_direction * camera_look_ahead, 480.0, _course_width - 480.0)
	if not course.has_method("camera_region") or course.current_room == &"":
		camera.position.x = lerpf(camera.position.x, target_x, 1.0 - exp(-camera_follow_speed * delta))
	if course.has_method("camera_region"):
		_update_camera_region()
		if course.current_room != &"":
			camera.position.x = lerpf(camera.position.x, clampf(player.position.x, camera.limit_left + 480.0, camera.limit_right - 480.0), 1.0 - exp(-camera_follow_speed * delta))
			camera.position.y = lerpf(camera.position.y, clampf(player.position.y - 70.0, camera.limit_top + 270.0, camera.limit_bottom - 270.0), 1.0 - exp(-camera_follow_speed * delta))
		else:
			camera.position.y = 270.0


func _update_camera_region() -> void:
	if not course.has_method("camera_region"):
		return
	var region: Rect2 = course.camera_region()
	camera.limit_left = int(region.position.x)
	camera.limit_right = int(region.end.x)
	camera.limit_top = int(region.position.y)
	camera.limit_bottom = int(region.end.y)


func _restart() -> void:
	if _restarting:
		return
	_restarting = true
	if player.state == player.State.DEAD:
		if restart_delay > 0.0:
			$HUD/DeathMessage.visible = true
		PlaytestNavigation.call_deferred("respawn", self, restart_delay)
		return
	# Scene changes are deferred so death can also be requested during a physics tick.
	get_tree().call_deferred("reload_current_scene")


func _finish_course() -> void:
	if completed or _restarting:
		return
	completed = true
	if automatic_showdown and not showdown_scene.is_empty() and PlaytestNavigation.enemies_enabled:
		PlaytestNavigation.call_deferred("start_level", showdown_scene)
		return
	get_node("/root/AudioDirector").play_cue(&"victory")
	var title := completion_title.capitalize()
	var detail := "%s / %.1f seconds" % [completion_detail, elapsed]
	var destination := "Next level" if not next_level.is_empty() else "Menu"
	if not showdown_scene.is_empty() and PlaytestNavigation.enemies_enabled:
		title = "Trail cleared"
		detail = "%s awaits. Enter to face %s.\nTime: %.1f seconds" % [showdown_name, showdown_name, elapsed]
		destination = "Face " + showdown_name
		combat_status.text = "Enter the showdown with fresh health and weapons. Death retries the fight."
	else:
		combat_status.text = completion_status
	$HUD/Completion.present(title, detail, destination)


func _continue_course() -> void:
	if not completed:
		return
	if not showdown_scene.is_empty() and PlaytestNavigation.enemies_enabled:
		PlaytestNavigation.start_level(showdown_scene)
	elif not next_level.is_empty():
		PlaytestNavigation.start_level(next_level)
	else:
		PlaytestNavigation.show_menu()


func _unhandled_input(event: InputEvent) -> void:
	if _restarting:
		return
	if completed and automatic_showdown and PlaytestNavigation.enemies_enabled:
		return
	if completed and event.is_action_pressed("ui_accept") and (not next_level.is_empty() or not showdown_scene.is_empty()):
		get_viewport().set_input_as_handled()
		_continue_course()
		return
	if OS.is_debug_build() and event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		if PlaytestNavigation.snapshot.get("path", "") == scene_file_path:
			PlaytestNavigation._restart()
			return
		if course.has_method("reset_progress"):
			course.reset_progress()
		CampaignSave.capture()
		_restart()
		return
	if course.has_method("hint_at"):
		return
	for action in [&"move_left", &"move_right", &"jump", &"dash", &"attack"]:
		if event.is_action_pressed(action):
			input_status.text = "Input received: %s" % action
			break
