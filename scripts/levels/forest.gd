extends Node2D
## Explicit diya interaction. Saved progress survives death reloads, not a new run.

signal finished

const COURSE_WIDTH: int = 21600
static var checkpoint_x: float = 160.0
static var lit_checkpoints: Array[StringName] = []
static var current_room: StringName = &""
static var room_spawn: Vector2
static var return_point: Vector2
static var pending_return: bool = false
static var completed_rooms: Array[StringName] = []
static var transition_state: Dictionary = {}
var transitioning: bool = false
var completed: bool = false


func _ready() -> void:
	$PlayerSpawn.position.x = checkpoint_x
	if current_room != &"":
		$PlayerSpawn.position = room_spawn
	elif pending_return:
		$PlayerSpawn.position = return_point
		pending_return = false
	for checkpoint in _checkpoints():
		checkpoint.get_node("Flame").visible = lit_checkpoints.has(checkpoint.name)
	for enemy in $Encounters.get_children():
		if enemy.get_meta("room", &"") != current_room:
			enemy.free()
	$Finish.body_entered.connect(_on_finish_entered)


func _physics_process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("players") as CharacterBody2D
	if player == null or transitioning:
		return
	for portal in $Portals.get_children():
		var active: bool = portal.get_meta("room", &"") == current_room
		var blocked := portal_guard_alive(portal)
		var can_enter: bool = active and not blocked and not completed and player.state == player.State.NORMAL and player.is_on_floor() and portal.overlaps_body(player)
		var explored: bool = current_room == &"" and completed_rooms.has(portal.get_meta("destination", &""))
		portal.get_node("Prompt").text = ("E: " if can_enter else "") + str(portal.get_meta("label")) + ("\nDefeat the sentinel" if blocked else ("\nCLEARED" if explored else ""))
		if can_enter and Input.is_action_just_pressed("interact"):
			_use_portal(portal)
			return
	for checkpoint in _checkpoints():
		var guard: CanvasLayer = get_parent().get("checkpoint_guard")
		var blocked: bool = guard != null and guard.blocked(checkpoint)
		var saved := lit_checkpoints.has(checkpoint.name)
		var can_light: bool = not blocked and checkpoint.get_meta("room", &"") == current_room and not completed and player.state == player.State.NORMAL and player.is_on_floor() and checkpoint.overlaps_body(player)
		checkpoint.get_node("Prompt").text = "Defeat enemies before this diya" if blocked else ("SAVED" if saved else ("E: light diya" if can_light else "DIYA"))
		if can_light and not saved and Input.is_action_just_pressed("interact"):
			lit_checkpoints.append(checkpoint.name)
			get_node("/root/AudioDirector").play_cue(&"checkpoint")
			if current_room == &"":
				checkpoint_x = maxf(checkpoint_x, checkpoint.position.x)
			else:
				room_spawn = checkpoint.global_position
			checkpoint.get_node("Flame").visible = true
			checkpoint.get_node("Prompt").text = "SAVED"
			player.get_node("Visuals").play_story(&"light_diya")
			get_parent().combat_status.text = "Diya lit. Death returns here. R resets the whole forest, including side rooms."


func _checkpoints() -> Array[Node]:
	return $Checkpoints.get_children() + $RoomCheckpoints.get_children()


func portal_guard_alive(portal: Area2D) -> bool:
	var guard_name: String = portal.get_meta("guard", "")
	var guard := $Encounters.get_node_or_null(NodePath(guard_name)) if not guard_name.is_empty() else null
	return guard != null and guard.health > 0


func _use_portal(portal: Area2D) -> void:
	transitioning = true
	var player := get_tree().get_first_node_in_group("players") as CharacterBody2D
	transition_state = {
		"health": player.health,
		"skyshot_ammo": player.skyshot_ammo,
		"chakri_cooldown_remaining": player.chakri_cooldown_remaining,
		"shot_recovery_remaining": player.shot_recovery_remaining,
	}
	if current_room == &"":
		current_room = portal.get_meta("destination")
		get_node("/root/AudioDirector").play_cue(&"portal")
		return_point = portal.global_position
		room_spawn = get_node("RoomStarts/" + str(current_room)).position
		# Each visit starts at the entrance; a local diya applies only to that visit.
		for checkpoint in $RoomCheckpoints.get_children():
			if checkpoint.get_meta("room") == current_room:
				lit_checkpoints.erase(checkpoint.name)
	else:
		if portal.get_meta("complete", false) and not completed_rooms.has(current_room):
			completed_rooms.append(current_room)
			get_node("/root/AudioDirector").play_cue(&"discovery")
		current_room = &""
		pending_return = true
	get_tree().call_deferred("reload_current_scene")


func restore_transition_state(player: CharacterBody2D) -> void:
	# Doors remain within this forest level. Death and R create a fresh player.
	for property in transition_state:
		player.set(property, transition_state[property])
	transition_state.clear()


func camera_region() -> Rect2:
	if current_room == &"RootChamber":
		return Rect2(0, -2500, 3300, 1400)
	if current_room == &"CanopyNest":
		return Rect2(0, -5000, 2900, 1600)
	return Rect2(0, 0, COURSE_WIDTH, 540)


func death_boundary() -> float:
	return camera_region().end.y + 40.0 if current_room != &"" else 580.0


func _on_finish_entered(body: Node2D) -> void:
	if completed or not body.is_in_group("players") or body.state == body.State.DEAD:
		return
	completed = true
	finished.emit()


func reset_progress() -> void:
	checkpoint_x = 160.0
	lit_checkpoints.clear()
	current_room = &""
	pending_return = false
	completed_rooms.clear()
	transition_state.clear()


func hint_at(x: float) -> String:
	if current_room == &"RootChamber":
		return "Root chamber / Drop past the shooter, climb the roots, then defeat the exit sentinel."
	if current_room == &"CanopyNest":
		return "Canopy nest / Changing branch lanes lead to two combat rests. Defeat the nest sentinel to return."
	if completed:
		return "Khara clearing reached. R to replay the forest."
	if x < 1600.0:
		return "Forest edge / Climb the roots. Control your landing before the next jump."
	if x < 2800.0:
		return "First clearing / J strikes the guard. Step away during its wind-up. E lights the diya."
	if x < 4800.0:
		return "Broken canopy / Land on the broad branch. Jump-lash the scout or spend a skyshot."
	if x < 6500.0:
		return "Root ridge / Climb four high steps, then cross the descending ledges."
	if x < 8900.0:
		return "Hollow trunks / Low roofs create a dash lane. Cross the shooter's bolt, then interrupt its next charge."
	if x < 11200.0:
		return "Stone crossing / Land and recharge. At the banyan, dodge purple bolts or J to interrupt."
	if x < 13600.0:
		return "Banyan climb / Alternate left and right to climb the stacked branches."
	if x < 16100.0:
		return "Upper ravine / Catch roots recover a missed landing. Fight the scout from the wide middle branch."
	if x < 18400.0:
		return "Old shrine / Dash through the brute's wind-up, then lash during recovery. Secure the final crossing diya."
	if x < 21000.0:
		return "Last crossing / Rise to the crown, drop into the ravine, then climb out. Save your air dash for the long breaks."
	return "Khara clearing / Light the last diya. The showdown begins beyond this trail."
