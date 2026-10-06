extends Node2D
## Ravan, Dashanan. Ten heads take turns attacking and grow back after being
## knocked out. Knocking out enough heads at once exposes the amrit in his navel,
## the only place he can be hurt. See docs/bosses/boss2-ravan.md.
const Burst = preload("res://scripts/effects/burst.gd")
const RavanHead = preload("res://scripts/bosses/ravan/ravan_head.gd")
const Hazard = preload("res://scripts/bosses/ravan/ravan_hazard.gd")
const Shockwave = preload("res://scripts/bosses/ravan/ravan_shockwave.gd")
const HOMING_SCENE = preload("res://scenes/combat/homing_projectile.tscn")
const STRAIGHT_SCENE = preload("res://scenes/combat/enemy_projectile.tscn")

signal core_health_changed(remaining: int)
signal phase_changed(phase: int)
signal exposure_started
signal exposure_ended
signal fury_started
signal fury_ended
signal defeated

enum State { INTRO, FIGHT, EXPOSED, TRANSITION, FURY, DYING, DEAD }

## Per-phase tuning. Phase N uses PHASES[N - 1].
const PHASES: Array[Dictionary] = [
	{"concurrent": 1, "gap": 1.1, "telegraph": 0.9, "attack": 0.5, "exhaust": 1.2, "regen": 12.0, "threshold": 3, "exposure": 5.0},
	{"concurrent": 2, "gap": 0.8, "telegraph": 0.8, "attack": 0.5, "exhaust": 1.0, "regen": 11.0, "threshold": 4, "exposure": 4.5},
	{"concurrent": 2, "gap": 0.55, "telegraph": 0.7, "attack": 0.5, "exhaust": 0.9, "regen": 10.0, "threshold": 5, "exposure": 4.0},
]
const LANE_COUNT: int = 10
## Dashanan Fury safe gaps, by phase. Consecutive gaps move at most three lanes.
const FURY_SAFE_LANES: Dictionary = {
	2: [[4, 5], [1, 2], [4, 5], [7, 8], [5, 6]],
	3: [[4, 5], [7, 8], [4, 5], [1, 2], [3, 4], [6, 7]],
}
const FURY_IGNITE_STEP: float = 0.12
const FURY_INTRO: float = 1.4
const FURY_FIRST_TELEGRAPH: float = 1.6
const FURY_ACTIVE: float = 0.4
const FURY_REST: float = 0.3
const FURY_OUTRO: float = 0.6
const FURY_COLOR: Color = Color(1.0, 0.3, 0.12)
const SAFE_COLOR: Color = Color(0.35, 1.0, 0.85)

@export var boss_name: String = "RAVAN"
@export var max_core_health: int = 30
@export var phase_two_health: int = 20
@export var phase_three_health: int = 10
## Global X range covered by the ten Dashanan Fury lanes.
@export var arena_left: float = 40.0
@export var arena_right: float = 920.0
@export var intro_time: float = 1.5
@export var transition_time: float = 1.2
@export var fury_bonus_exposure: float = 2.5
@export var phase_three_fury_interval: float = 30.0
@export var auto_activate: bool = true
@export var rng_seed: int = 0

var state: State = State.INTRO
var phase: int = 1
var core_health: int
var heads: Array = []
var fury_time: float = 0.0
var fury_waves: Array = []
var current_safe_lanes: Array = []
var _state_remaining: float = 0.0
var _activation_cooldown: float = 0.0
var _fury_clock: float = 0.0
var _last_activated: int = -1
var _flash_remaining: float = 0.0
var _tint: float = 0.0
var _banner_remaining: float = 0.0
var _death_index: int = 0
var _rng := RandomNumberGenerator.new()
var _lane_overlay := Node2D.new()

@onready var body: Node2D = $Body
@onready var body_art: Node2D = $Body/Art
@onready var core: StaticBody2D = $Core
@onready var tint_rect: ColorRect = $BossUI/Tint
@onready var banner: Label = $BossUI/Banner
@onready var health_bar: Control = $BossUI/HealthBar


func _ready() -> void:
	core_health = max_core_health
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	for child in $Heads.get_children():
		heads.append(child)
		child.attack_released.connect(_on_head_attack)
		child.knocked_out.connect(_on_head_knocked_out)
	heads.sort_custom(func(a: Node, b: Node) -> bool: return a.head_index < b.head_index)
	_apply_phase_tuning()
	health_bar.boss = self
	# Artists drop a texture or AnimatedSprite2D into Body/Art; the placeholder hides.
	var has_art := (body_art is Sprite2D and (body_art as Sprite2D).texture != null) or (body_art is AnimatedSprite2D and (body_art as AnimatedSprite2D).sprite_frames != null)
	$Body/Placeholder.visible = not has_art
	# Safe lanes draw above Ravan's body; the first gap sits right under him.
	_lane_overlay.z_index = 4
	_lane_overlay.draw.connect(_draw_safe_lanes)
	add_child(_lane_overlay)
	_state_remaining = intro_time
	_show_banner("RAVAN, LORD OF LANKA", intro_time + 0.5)


func phase_settings() -> Dictionary:
	return PHASES[clampi(phase, 1, PHASES.size()) - 1]


func is_exposed() -> bool:
	return state == State.EXPOSED


func knocked_out_count() -> int:
	var count := 0
	for head in heads:
		if head.is_knocked_out():
			count += 1
	return count


func active_count() -> int:
	var count := 0
	for head in heads:
		if head.is_active():
			count += 1
	return count


func lane_width() -> float:
	return (arena_right - arena_left) / LANE_COUNT


func lane_center(lane: int) -> float:
	return arena_left + lane_width() * (lane + 0.5)


func fury_duration() -> float:
	var waves: Array = FURY_SAFE_LANES.get(phase, FURY_SAFE_LANES[3])
	var telegraph := _fury_wave_telegraph()
	return FURY_INTRO + FURY_FIRST_TELEGRAPH + FURY_ACTIVE + FURY_REST + (waves.size() - 1) * (telegraph + FURY_ACTIVE + FURY_REST) + FURY_OUTRO


func start_fight() -> void:
	if state == State.INTRO:
		_state_remaining = 0.0


## Starts a specific head's attack, for scripted openings and tests.
func activate_head(index: int) -> bool:
	if state != State.FIGHT:
		return false
	var settings := phase_settings()
	var started: bool = heads[index].activate(settings.telegraph, settings.attack, settings.exhaust)
	if started:
		_last_activated = index
	return started


func _physics_process(delta: float) -> void:
	_flash_remaining = maxf(_flash_remaining - delta, 0.0)
	_banner_remaining = maxf(_banner_remaining - delta, 0.0)
	_state_remaining = maxf(_state_remaining - delta, 0.0)
	match state:
		State.INTRO:
			if _state_remaining <= 0.0:
				state = State.FIGHT
				_activation_cooldown = 0.4
		State.FIGHT:
			_process_fight(delta)
		State.EXPOSED:
			if _state_remaining <= 0.0:
				_end_exposure()
		State.TRANSITION:
			if _state_remaining <= 0.0:
				_begin_fury()
		State.FURY:
			_process_fury(delta)
		State.DYING:
			_process_dying()
	_update_feedback(delta)


func _process_fight(delta: float) -> void:
	if knocked_out_count() >= int(phase_settings().threshold):
		_begin_exposure(float(phase_settings().exposure))
		return
	if phase >= 3:
		_fury_clock += delta
		if _fury_clock >= phase_three_fury_interval:
			_begin_fury()
			return
	_activation_cooldown = maxf(_activation_cooldown - delta, 0.0)
	if not auto_activate or _activation_cooldown > 0.0 or not _player_alive():
		return
	if active_count() >= int(phase_settings().concurrent):
		return
	var choices: Array[int] = []
	for head in heads:
		if head.state == RavanHead.HeadState.IDLE and head.head_index != _last_activated:
			choices.append(head.head_index)
	if choices.is_empty():
		return
	activate_head(choices[_rng.randi_range(0, choices.size() - 1)])
	_activation_cooldown = float(phase_settings().gap)


func _on_head_knocked_out(_head: Node) -> void:
	if state == State.FIGHT and knocked_out_count() >= int(phase_settings().threshold):
		_begin_exposure(float(phase_settings().exposure))


func _begin_exposure(duration: float) -> void:
	state = State.EXPOSED
	_state_remaining = duration
	for head in heads:
		head.retreat()
		head.regen_paused = true
	core.open()
	_show_banner("THE AMRIT IS EXPOSED - STRIKE HIS NAVEL!", minf(duration, 2.0))
	Burst.spawn(get_tree().current_scene, core.global_position, Color(0.5, 1.0, 0.8), "", 40.0)
	exposure_started.emit()


func _end_exposure() -> void:
	_close_core_and_regrow()
	state = State.FIGHT
	_activation_cooldown = 1.2
	_show_banner("THE HEADS GROW BACK", 1.2)
	exposure_ended.emit()


func _close_core_and_regrow() -> void:
	core.close()
	for head in heads:
		head.regen_paused = false
		if head.is_knocked_out():
			head.regrow()


func damage_core(amount: int) -> void:
	if state != State.EXPOSED or amount <= 0 or core_health <= 0:
		return
	# Each phase boundary clamps damage so every phase, and its super move, is seen.
	var floor_health := 0
	if phase == 1:
		floor_health = phase_two_health
	elif phase == 2:
		floor_health = phase_three_health
	core_health = maxi(core_health - amount, floor_health)
	_flash_remaining = 0.1
	core_health_changed.emit(core_health)
	if core_health <= 0:
		_begin_death()
	elif core_health <= floor_health:
		_begin_transition()


func _begin_transition() -> void:
	_close_core_and_regrow()
	exposure_ended.emit()
	phase += 1
	_apply_phase_tuning()
	state = State.TRANSITION
	_state_remaining = transition_time
	_show_banner("PHASE %d - DASHANAN AWAKENS" % phase, transition_time)
	Burst.spawn(get_tree().current_scene, global_position + Vector2(0, -150), FURY_COLOR, "ROAR!", 70.0)
	phase_changed.emit(phase)


func _apply_phase_tuning() -> void:
	for head in heads:
		head.regen_time = float(phase_settings().regen)


func _begin_fury() -> void:
	state = State.FURY
	fury_time = 0.0
	_fury_clock = 0.0
	current_safe_lanes = []
	_close_core_and_regrow()
	for head in heads:
		head.enter_fury()
	# Precompute every wave so timings are fixed and readable.
	fury_waves = []
	var start := FURY_INTRO
	var telegraph := FURY_FIRST_TELEGRAPH
	for safe in FURY_SAFE_LANES.get(phase, FURY_SAFE_LANES[3]):
		fury_waves.append({"start": start, "telegraph": telegraph, "safe": safe, "spawned": false})
		start += telegraph + FURY_ACTIVE + FURY_REST
		telegraph = _fury_wave_telegraph()
	_show_banner("DASHANAN FURY", FURY_INTRO + 0.4)
	fury_started.emit()


func _fury_wave_telegraph() -> float:
	return 1.0 if phase <= 2 else 0.85


func _process_fury(delta: float) -> void:
	fury_time += delta
	# Heads ignite one by one, left to right, before the first wave.
	for head in heads:
		head.fury_lit = fury_time >= head.head_index * FURY_IGNITE_STEP
	for wave in fury_waves:
		if wave.spawned or fury_time < wave.start:
			continue
		wave.spawned = true
		current_safe_lanes = wave.safe
		for head in heads:
			head.fury_silent = current_safe_lanes.has(head.head_index)
		for lane in range(LANE_COUNT):
			if current_safe_lanes.has(lane):
				continue
			var pillar := Hazard.new()
			pillar.style = Hazard.Style.PILLAR
			pillar.size = Vector2(lane_width() - 6.0, global_position.y - 10.0)
			pillar.color = FURY_COLOR
			pillar.telegraph_time = wave.telegraph
			pillar.active_time = FURY_ACTIVE
			pillar.knockback = Vector2(160, -220)
			get_tree().current_scene.add_child(pillar)
			pillar.global_position = Vector2(lane_center(lane), global_position.y)
	if fury_time >= fury_duration():
		_end_fury()


func _end_fury() -> void:
	for head in heads:
		head.exit_fury()
	current_safe_lanes = []
	fury_waves = []
	fury_ended.emit()
	# Spent from the super move, Ravan briefly leaves his navel open.
	_begin_exposure(fury_bonus_exposure)


func _on_head_attack(head: Node) -> void:
	if state != State.FIGHT:
		return
	var mouth: Vector2 = head.mouth_global()
	var player := _player()
	var target := mouth + Vector2(0, 120)
	if is_instance_valid(player):
		target = player.global_position + Vector2(0, -20)
	var aim := (target - mouth).normalized() if not (target - mouth).is_zero_approx() else Vector2.DOWN
	var scene_root := get_tree().current_scene
	var color: Color = head.attack_color()
	match head.attack_kind:
		RavanHead.Attack.FIRE:
			var beam := Hazard.new()
			beam.style = Hazard.Style.BEAM
			# The flame splashes on the floor instead of passing through it.
			var reach := 330.0
			if aim.y > 0.05:
				reach = minf(reach, (global_position.y - mouth.y) / aim.y + 12.0)
			beam.size = Vector2(reach, 34)
			beam.color = color
			beam.telegraph_time = 0.45
			beam.active_time = 0.45
			scene_root.add_child(beam)
			beam.global_position = mouth
			beam.rotation = aim.angle()
		RavanHead.Attack.HOMING:
			var spreads := [0.0] if phase < 3 else [-0.35, 0.35]
			for offset in spreads:
				var bolt := HOMING_SCENE.instantiate() as CharacterBody2D
				bolt.direction = aim.rotated(offset)
				bolt.target = player
				bolt.speed = 160.0
				bolt.turn_speed = 2.2
				bolt.lifetime = 3.2
				bolt.add_to_group("ravan_attacks")
				scene_root.add_child(bolt)
				bolt.global_position = mouth
		RavanHead.Attack.ROAR:
			var x := clampf(mouth.x, arena_left + 20.0, arena_right - 20.0)
			for direction in [-1, 1]:
				var wave := Shockwave.new()
				wave.direction = direction
				wave.color = color
				scene_root.add_child(wave)
				wave.global_position = Vector2(x, global_position.y)
			Burst.spawn(scene_root, Vector2(x, global_position.y - 10.0), color, "ROAR!", 30.0)
		RavanHead.Attack.LIGHTNING:
			# Phase 3 adds a delayed second strike on the same spot: move, don't return.
			var strikes := [0.7] if phase < 3 else [0.7, 1.15]
			for delay in strikes:
				var bolt := Hazard.new()
				bolt.style = Hazard.Style.COLUMN
				bolt.size = Vector2(44, global_position.y - 10.0)
				bolt.color = color
				bolt.telegraph_time = delay
				bolt.active_time = 0.18
				scene_root.add_child(bolt)
				bolt.global_position = Vector2(clampf(target.x, arena_left + 22.0, arena_right - 22.0), global_position.y)
		RavanHead.Attack.SPREAD:
			var count := 3 if phase < 3 else 5
			for index in range(count):
				var shot := STRAIGHT_SCENE.instantiate() as CharacterBody2D
				shot.direction = aim.rotated((index - (count - 1) * 0.5) * 0.22)
				shot.speed = 210.0
				shot.add_to_group("ravan_attacks")
				scene_root.add_child(shot)
				shot.global_position = mouth
				shot.get_node("Body").color = color


func _begin_death() -> void:
	state = State.DYING
	_state_remaining = 0.0
	_death_index = 0
	core.close()
	for head in heads:
		head.retreat()
		head.regen_paused = true
	# Victory should never be followed by a stray hit.
	for attack in get_tree().get_nodes_in_group("ravan_attacks"):
		attack.queue_free()
	_show_banner("RAVAN FALLS", 4.0)


func _process_dying() -> void:
	if _state_remaining > 0.0:
		return
	if _death_index < heads.size():
		# Heads burst from the outside in.
		var pair := int(_death_index / 2.0)
		var order := pair if _death_index % 2 == 0 else heads.size() - 1 - pair
		heads[order].destroy()
		_death_index += 1
		_state_remaining = 0.18
		return
	if _death_index == heads.size():
		_death_index += 1
		_state_remaining = 0.8
		return
	Burst.spawn(get_tree().current_scene, global_position + Vector2(0, -80), Color(1.0, 0.7, 0.3), "DEFEATED", 90.0)
	state = State.DEAD
	defeated.emit()


func _update_feedback(delta: float) -> void:
	var target_tint := 1.0 if state == State.FURY and fury_time < fury_duration() - FURY_OUTRO else 0.0
	_tint = move_toward(_tint, target_tint, delta * 2.5)
	tint_rect.color = Color(0.45, 0.0, 0.02, 0.3 * _tint)
	banner.visible = _banner_remaining > 0.0
	body.position.y = 6.0 if state == State.EXPOSED else 0.0
	if state == State.DEAD:
		body.modulate = Color(0.4, 0.35, 0.35, maxf(body.modulate.a - delta, 0.25))
	elif _flash_remaining > 0.0:
		body.modulate = Color(2.2, 2.2, 2.2)
	elif state == State.EXPOSED:
		body.modulate = Color(0.75, 0.8, 0.85)
	elif state == State.FURY:
		body.modulate = Color(1.3, 0.75, 0.65)
	else:
		body.modulate = Color.WHITE
	_play_body_animation()
	queue_redraw()
	_lane_overlay.queue_redraw()


func _play_body_animation() -> void:
	if not body_art is AnimatedSprite2D:
		return
	var sprite := body_art as AnimatedSprite2D
	if sprite.sprite_frames == null:
		return
	var names := {State.INTRO: &"intro", State.FIGHT: &"idle", State.EXPOSED: &"exposed", State.TRANSITION: &"roar", State.FURY: &"fury", State.DYING: &"dying", State.DEAD: &"dead"}
	var animation: StringName = names[state]
	if sprite.sprite_frames.has_animation(animation) and sprite.animation != animation:
		sprite.play(animation)


func _show_banner(text: String, duration: float) -> void:
	banner.text = text
	_banner_remaining = duration


func _player() -> CharacterBody2D:
	return get_tree().get_first_node_in_group("players") as CharacterBody2D


func _player_alive() -> bool:
	var player := _player()
	return is_instance_valid(player) and player.health > 0


func _draw() -> void:
	# Necks connect each head to the shoulders and stretch when a head lunges.
	for head in heads:
		if head.state == RavanHead.HeadState.DESTROYED:
			continue
		var anchor := Vector2(head.home_position.x * 0.3, -118.0)
		var neck_color := Color(0.33, 0.24, 0.22) if not head.is_knocked_out() else Color(0.22, 0.18, 0.18)
		draw_line(anchor, head.position, neck_color, 7.0)
	if state != State.FURY:
		return
	for head in heads:
		if not head.fury_lit or head.fury_silent:
			continue
		# Each lit head aims at the lane it will burn.
		var lane_floor := to_local(Vector2(lane_center(head.head_index), global_position.y))
		var aim := FURY_COLOR
		aim.a = 0.35
		draw_line(head.position, lane_floor, aim, 1.5)


func _draw_safe_lanes() -> void:
	if state != State.FURY:
		return
	for lane in current_safe_lanes:
		var center := to_local(Vector2(lane_center(lane), global_position.y))
		var safe := SAFE_COLOR
		safe.a = 0.16
		_lane_overlay.draw_rect(Rect2(center.x - lane_width() * 0.5 + 3.0, -90.0, lane_width() - 6.0, 90.0), safe)
		safe.a = 0.9
		_lane_overlay.draw_rect(Rect2(center.x - lane_width() * 0.5 + 3.0, -5.0, lane_width() - 6.0, 5.0), safe)
		_lane_overlay.draw_string(ThemeDB.fallback_font, Vector2(center.x - 30.0, -96.0), "SAFE", HORIZONTAL_ALIGNMENT_CENTER, 60, 13, SAFE_COLOR)
