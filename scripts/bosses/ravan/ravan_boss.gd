extends Node2D
## Swaminathan, Dashanan. One health pool: Siya can hit him anywhere, and every tenth of
## his health lost severs his rightmost living head. Heads are fixed attack origins
## on the body sprite; only living heads attack. See docs/bosses/boss2-ravan.md.
const Burst = preload("res://scripts/effects/burst.gd")
const RavanBody = preload("res://scripts/bosses/ravan/ravan_body.gd")
const Hazard = preload("res://scripts/bosses/ravan/ravan_hazard.gd")
const Shockwave = preload("res://scripts/bosses/ravan/ravan_shockwave.gd")
const HOMING_SCENE = preload("res://scenes/combat/homing_projectile.tscn")
const STRAIGHT_SCENE = preload("res://scenes/combat/enemy_projectile.tscn")

signal health_changed(remaining: int)
signal head_lost(index: int, remaining: int)
signal phase_changed(phase: int)
signal fury_started
signal fury_ended
signal died

enum State { INTRO, FIGHT, TRANSITION, FURY, DYING, DEAD }
enum HeadState { IDLE, TELEGRAPH, ATTACK, RECOVER }
enum Attack { FIRE, HOMING, ROAR, LIGHTNING, SPREAD }

const HEAD_COUNT: int = RavanBody.HEAD_COUNT
## The ten vices and faculties, left to right.
const HEAD_NAMES: Array[String] = ["Mada", "Krodha", "Lobha", "Moha", "Matsarya", "Ahamkara", "Manas", "Kama", "Buddhi", "Chitta"]
## Five mirrored pairs. Heads fall right to left, so the last three heads standing
## carry the attacks that escalate in phase 3 (lightning, spread, homing).
const HEAD_ATTACKS: Array[Attack] = [
	Attack.LIGHTNING, Attack.SPREAD, Attack.HOMING, Attack.FIRE, Attack.ROAR,
	Attack.ROAR, Attack.FIRE, Attack.HOMING, Attack.SPREAD, Attack.LIGHTNING,
]
const ATTACK_COLORS: Array[Color] = [
	Color(1.0, 0.45, 0.1),  # FIRE: orange flame
	Color(0.8, 0.4, 1.0),  # HOMING: matches the ground shooter's purple bolts
	Color(1.0, 0.85, 0.2),  # ROAR: gold
	Color(0.35, 0.85, 1.0),  # LIGHTNING: cyan
	Color(1.0, 0.3, 0.55),  # SPREAD: rose
]
const ATTACK_WORDS: Array[String] = ["FIRE BREATH", "HOMING", "ROAR", "LIGHTNING", "SPREAD"]

## Per-phase tuning. Phase N uses PHASES[N - 1]. A head telegraphs, attacks, then
## recovers before it can be picked again; "concurrent" counts heads in any of these.
const PHASES: Array[Dictionary] = [
	{"concurrent": 1, "gap": 1.1, "telegraph": 0.9, "attack": 0.5, "recover": 1.2},
	{"concurrent": 2, "gap": 0.8, "telegraph": 0.8, "attack": 0.5, "recover": 1.0},
	{"concurrent": 2, "gap": 0.55, "telegraph": 0.7, "attack": 0.5, "recover": 0.9},
]
## Phase 2 starts when 7 heads are left, phase 3 when 3 are left.
const PHASE_HEADS: Array[int] = [7, 3]
const LANE_COUNT: int = 10
## Dashanan Fury safe gaps, by phase. Consecutive gaps move at most three lanes.
## A Fury runs one wave per living head, up to the whole sequence.
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
const POP_TIME: float = 0.45
const SHAKE_TIME: float = 0.35


## One head: a fixed attack origin on the body sprite, not a separate entity.
class HeadSlot:
	var index: int
	var head_name: String
	var attack_kind: int
	var alive: bool = true
	var state: int = HeadState.IDLE
	var remaining: float = 0.0
	var telegraph_time: float = 0.9
	var attack_time: float = 0.5
	var recover_time: float = 1.2
	var fury_lit: bool = false
	var fury_silent: bool = false

	func is_active() -> bool:
		return alive and state != HeadState.IDLE

	func telegraph_progress() -> float:
		if state != HeadState.TELEGRAPH:
			return 0.0
		return 1.0 - clampf(remaining / maxf(telegraph_time, 0.001), 0.0, 1.0)

	func attack_color() -> Color:
		return ATTACK_COLORS[attack_kind]

	func attack_word() -> String:
		return ATTACK_WORDS[attack_kind]


@export var boss_name: String = "SWAMINATHAN"
@export var boss_title: String = "Dashanan"
## Each head is worth a tenth of this.
@export var max_health: int = 80
## Global X range covered by the ten Dashanan Fury lanes.
@export var arena_left: float = 40.0
@export var arena_right: float = 920.0
@export var intro_time: float = 1.5
@export var transition_time: float = 1.2
## After a lost head, pending telegraphs are cancelled and no head starts for this long.
@export var stagger_time: float = 0.6
## After Dashanan Fury he is spent: no head attacks for this long.
@export var spent_time: float = 2.5
@export var phase_three_fury_interval: float = 30.0
@export var death_time: float = 0.9
@export var auto_activate: bool = true
@export var rng_seed: int = 0

var state: State = State.INTRO
var phase: int = 1
var health: int
var heads_alive: int = HEAD_COUNT
var heads: Array[HeadSlot] = []
var fury_time: float = 0.0
var fury_waves: Array = []
var current_safe_lanes: Array = []
var _state_remaining: float = 0.0
var _activation_cooldown: float = 0.0
var _stagger_remaining: float = 0.0
var _spent_remaining: float = 0.0
var _fury_clock: float = 0.0
var _last_activated: int = -1
var _flash_remaining: float = 0.0
var _shake_remaining: float = 0.0
var _guard_feedback_cooldown: float = 0.0
var _tint: float = 0.0
var _banner_remaining: float = 0.0
var _pops: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _overlay := Node2D.new()

@onready var body: Node2D = $Body
@onready var tint_rect: ColorRect = $BossUI/Tint
@onready var banner: Label = $BossUI/Banner
@onready var health_bar: Control = $BossUI/HealthBar
@onready var head_indicators: Control = $BossUI/HeadIndicators


func _ready() -> void:
	health = max_health
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	for index in range(HEAD_COUNT):
		var head := HeadSlot.new()
		head.index = index
		head.head_name = HEAD_NAMES[index]
		head.attack_kind = HEAD_ATTACKS[index]
		heads.append(head)
	# One tick per head on the generic bar: each tenth is one head.
	var ticks := PackedFloat32Array()
	for index in range(1, HEAD_COUNT):
		ticks.append(float(index) / HEAD_COUNT)
	health_bar.phase_thresholds = ticks
	health_bar.bind(self)
	head_indicators.boss = self
	body.head_count = heads_alive
	# Telegraphs, pops and safe lanes draw above the body.
	_overlay.z_index = 4
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_state_remaining = intro_time
	_show_banner("SWAMINATHAN, LORD OF LANKA", intro_time + 0.5)


func phase_settings() -> Dictionary:
	return PHASES[clampi(phase, 1, PHASES.size()) - 1]


## Health at which only `count` heads remain.
func head_threshold(count: int) -> int:
	return int(max_health * clampi(count, 0, HEAD_COUNT) / HEAD_COUNT)


func is_vulnerable() -> bool:
	return state == State.FIGHT


func is_staggered() -> bool:
	return _stagger_remaining > 0.0


func is_spent() -> bool:
	return _spent_remaining > 0.0


func active_count() -> int:
	var count := 0
	for head in heads:
		if head.is_active():
			count += 1
	return count


func head_global(index: int) -> Vector2:
	return to_global(RavanBody.HEAD_OFFSETS[index])


func mouth_global(index: int) -> Vector2:
	return to_global(RavanBody.mouth_offset(index))


func lane_width() -> float:
	return (arena_right - arena_left) / LANE_COUNT


func lane_center(lane: int) -> float:
	return arena_left + lane_width() * (lane + 0.5)


## The living head that burns this Fury lane: the lanes are shared out evenly.
func lane_head(lane: int) -> int:
	return int(lane * maxi(heads_alive, 1) / LANE_COUNT)


func fury_wave_count() -> int:
	var sequence: Array = FURY_SAFE_LANES.get(phase, FURY_SAFE_LANES[3])
	return mini(sequence.size(), maxi(heads_alive, 1))


func fury_duration() -> float:
	return FURY_INTRO + FURY_FIRST_TELEGRAPH + FURY_ACTIVE + FURY_REST + (fury_wave_count() - 1) * (_fury_wave_telegraph() + FURY_ACTIVE + FURY_REST) + FURY_OUTRO


func start_fight() -> void:
	if state == State.INTRO:
		_state_remaining = 0.0


## Starts a specific living head's attack, for scripted openings and tests.
func activate_head(index: int) -> bool:
	var head := heads[index]
	if state != State.FIGHT or not head.alive or head.state != HeadState.IDLE:
		return false
	var settings := phase_settings()
	head.telegraph_time = settings.telegraph
	head.attack_time = settings.attack
	head.recover_time = settings.recover
	head.state = HeadState.TELEGRAPH
	get_node("/root/AudioDirector").play_sfx(&"tell", head_global(index))
	head.remaining = head.telegraph_time
	_last_activated = index
	return true


func take_damage(amount: int, _knockback: Vector2 = Vector2.ZERO) -> void:
	if amount <= 0 or health <= 0:
		return
	if not is_vulnerable():
		if _guard_feedback_cooldown <= 0.0 and state != State.DYING and state != State.DEAD:
			_guard_feedback_cooldown = 0.3
			Burst.spawn(get_tree().current_scene, global_position + Vector2(0, -80), Color(0.6, 0.65, 0.75), "GUARDED", 14.0)
		return
	# One hit takes at most one head, so every lost head gets its own beat.
	var floor_health := head_threshold(heads_alive - 1)
	health = maxi(health - amount, floor_health)
	_flash_remaining = 0.1
	health_changed.emit(health)
	if health <= floor_health:
		_lose_head()


## The phase Ravan fights in with this many heads left.
func phase_for(count: int) -> int:
	var result := 1
	for threshold in PHASE_HEADS:
		if count <= threshold:
			result += 1
	return result


## Jumps straight to `count` living heads (1 to 10) with the matching health and
## phase, skipping the head-loss beats. For tests, screenshots and dev snapshots.
func set_head_count(count: int) -> void:
	heads_alive = clampi(count, 1, HEAD_COUNT)
	health = head_threshold(heads_alive)
	for head in heads:
		head.alive = head.index < heads_alive
	_calm_heads()
	body.head_count = heads_alive
	health_changed.emit(health)
	var next_phase := phase_for(heads_alive)
	if next_phase != phase:
		phase = next_phase
		phase_changed.emit(phase)


func _physics_process(delta: float) -> void:
	_flash_remaining = maxf(_flash_remaining - delta, 0.0)
	_shake_remaining = maxf(_shake_remaining - delta, 0.0)
	_guard_feedback_cooldown = maxf(_guard_feedback_cooldown - delta, 0.0)
	_banner_remaining = maxf(_banner_remaining - delta, 0.0)
	_state_remaining = maxf(_state_remaining - delta, 0.0)
	match state:
		State.INTRO:
			if _state_remaining <= 0.0:
				state = State.FIGHT
				_activation_cooldown = 0.4
		State.FIGHT:
			_process_fight(delta)
		State.TRANSITION:
			if _state_remaining <= 0.0:
				_begin_fury()
		State.FURY:
			_process_fury(delta)
		State.DYING:
			if _state_remaining <= 0.0:
				Burst.spawn(get_tree().current_scene, global_position + Vector2(0, -80), Color(1.0, 0.7, 0.3), "DEFEATED", 90.0)
				state = State.DEAD
				died.emit()
	_update_feedback(delta)


func _process_fight(delta: float) -> void:
	_stagger_remaining = maxf(_stagger_remaining - delta, 0.0)
	_spent_remaining = maxf(_spent_remaining - delta, 0.0)
	_process_heads(delta)
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
		if head.alive and head.state == HeadState.IDLE:
			choices.append(head.index)
	# The same head never attacks twice in a row while another can.
	if choices.size() > 1:
		choices.erase(_last_activated)
	if choices.is_empty():
		return
	activate_head(choices[_rng.randi_range(0, choices.size() - 1)])
	_activation_cooldown = float(phase_settings().gap)


func _process_heads(delta: float) -> void:
	for head in heads:
		if not head.is_active():
			continue
		head.remaining = maxf(head.remaining - delta, 0.0)
		if head.remaining > 0.0:
			continue
		match head.state:
			HeadState.TELEGRAPH:
				head.state = HeadState.ATTACK
				head.remaining = head.attack_time
				_fire_head_attack(head)
			HeadState.ATTACK:
				head.state = HeadState.RECOVER
				head.remaining = head.recover_time
			HeadState.RECOVER:
				head.state = HeadState.IDLE


## Every head stops what it is doing; attacks already fired keep flying.
func _calm_heads() -> void:
	for head in heads:
		head.state = HeadState.IDLE
		head.remaining = 0.0
		head.fury_lit = false
		head.fury_silent = false


func _lose_head() -> void:
	var lost := heads[heads_alive - 1]
	lost.alive = false
	lost.state = HeadState.IDLE
	lost.fury_lit = false
	heads_alive -= 1
	body.head_count = heads_alive
	_shake_remaining = SHAKE_TIME
	var at := head_global(lost.index)
	_pops.append({"at": RavanBody.HEAD_OFFSETS[lost.index], "age": 0.0})
	var scene_root := get_tree().current_scene
	Burst.spawn(scene_root, at, Color(1.0, 0.5, 0.2), "", 44.0)
	Burst.spawn(scene_root, at + Vector2(0, -6), Color(1.0, 0.9, 0.6), "SEVERED!", 26.0)
	head_lost.emit(lost.index, heads_alive)
	if heads_alive <= 0:
		_restore_player_health()
		_begin_death()
		return
	var next_phase := phase_for(heads_alive)
	if next_phase > phase:
		_restore_player_health()
		_begin_transition(next_phase)
		return
	# A brief stagger: pending telegraphs are cancelled and no head starts for a moment.
	for head in heads:
		if head.state == HeadState.TELEGRAPH:
			head.state = HeadState.IDLE
			head.remaining = 0.0
	_stagger_remaining = stagger_time
	_activation_cooldown = maxf(_activation_cooldown, stagger_time)
	_show_banner("%s SEVERED - %d HEADS LEFT" % [lost.head_name.to_upper(), heads_alive], 1.2)


## Clearing a phase, or defeating Ravan, fully restores Siya's health.
func _restore_player_health() -> void:
	var player := _player()
	if not is_instance_valid(player) or player.health <= 0:
		return
	player.health = player.max_health
	player.health_changed.emit(player.health)


func _begin_transition(next_phase: int) -> void:
	_calm_heads()
	_stagger_remaining = 0.0
	_spent_remaining = 0.0
	phase = next_phase
	state = State.TRANSITION
	_state_remaining = transition_time
	_show_banner("PHASE %d - DASHANAN AWAKENS" % phase, transition_time)
	Burst.spawn(get_tree().current_scene, global_position + Vector2(0, -150), FURY_COLOR, "ROAR!", 70.0)
	phase_changed.emit(phase)


func _begin_fury() -> void:
	state = State.FURY
	fury_time = 0.0
	_fury_clock = 0.0
	current_safe_lanes = []
	_calm_heads()
	# Precompute every wave so timings are fixed and readable.
	fury_waves = []
	var sequence: Array = FURY_SAFE_LANES.get(phase, FURY_SAFE_LANES[3])
	var start := FURY_INTRO
	var telegraph := FURY_FIRST_TELEGRAPH
	for wave in range(fury_wave_count()):
		fury_waves.append({"start": start, "telegraph": telegraph, "safe": sequence[wave], "spawned": false})
		start += telegraph + FURY_ACTIVE + FURY_REST
		telegraph = _fury_wave_telegraph()
	_show_banner("DASHANAN FURY", FURY_INTRO + 0.4)
	fury_started.emit()


func _fury_wave_telegraph() -> float:
	return 1.0 if phase <= 2 else 0.85


func _process_fury(delta: float) -> void:
	fury_time += delta
	# Living heads ignite one by one, left to right, before the first wave.
	for head in heads:
		head.fury_lit = head.alive and fury_time >= head.index * FURY_IGNITE_STEP
	for wave in fury_waves:
		if wave.spawned or fury_time < wave.start:
			continue
		wave.spawned = true
		current_safe_lanes = wave.safe
		var burning := {}
		for lane in range(LANE_COUNT):
			if current_safe_lanes.has(lane):
				continue
			burning[lane_head(lane)] = true
			var pillar := Hazard.new()
			pillar.style = Hazard.Style.PILLAR
			pillar.size = Vector2(lane_width() - 6.0, global_position.y - 10.0)
			pillar.color = FURY_COLOR
			pillar.telegraph_time = wave.telegraph
			pillar.active_time = FURY_ACTIVE
			pillar.knockback = Vector2(160, -220)
			get_tree().current_scene.add_child(pillar)
			pillar.global_position = Vector2(lane_center(lane), global_position.y)
		# A head whose lanes are all safe this wave goes dark.
		for head in heads:
			head.fury_silent = head.alive and not burning.has(head.index)
	if fury_time >= fury_duration():
		_end_fury()


func _end_fury() -> void:
	_calm_heads()
	current_safe_lanes = []
	fury_waves = []
	state = State.FIGHT
	# Spent from the super move, Ravan gives Siya a free punish window.
	_spent_remaining = spent_time
	_activation_cooldown = spent_time
	_show_banner("DASHANAN IS SPENT - STRIKE!", 1.5)
	fury_ended.emit()


func _fire_head_attack(head: HeadSlot) -> void:
	var mouth := mouth_global(head.index)
	var player := _player()
	var target := mouth + Vector2(0, 120)
	if is_instance_valid(player):
		target = player.global_position + Vector2(0, -20)
	var aim := (target - mouth).normalized() if not (target - mouth).is_zero_approx() else Vector2.DOWN
	var scene_root := get_tree().current_scene
	var color: Color = head.attack_color()
	match head.attack_kind:
		Attack.FIRE:
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
		Attack.HOMING:
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
		Attack.ROAR:
			var x := clampf(mouth.x, arena_left + 20.0, arena_right - 20.0)
			for direction in [-1, 1]:
				var wave := Shockwave.new()
				wave.direction = direction
				wave.color = color
				scene_root.add_child(wave)
				wave.global_position = Vector2(x, global_position.y)
			Burst.spawn(scene_root, Vector2(x, global_position.y - 10.0), color, "ROAR!", 30.0)
		Attack.LIGHTNING:
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
		Attack.SPREAD:
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
	_state_remaining = death_time
	_shake_remaining = death_time
	_calm_heads()
	# Victory should never be followed by a stray hit.
	for attack in get_tree().get_nodes_in_group("ravan_attacks"):
		attack.queue_free()
	_show_banner("SWAMINATHAN FALLS", 4.0)


func _update_feedback(delta: float) -> void:
	var target_tint := 1.0 if state == State.FURY and fury_time < fury_duration() - FURY_OUTRO else 0.0
	_tint = move_toward(_tint, target_tint, delta * 2.5)
	tint_rect.color = Color(0.45, 0.0, 0.02, 0.3 * _tint)
	banner.visible = _banner_remaining > 0.0
	# Shake after a lost head; slump while staggered or spent.
	var offset := Vector2.ZERO
	if _shake_remaining > 0.0:
		var t := Time.get_ticks_msec() * 0.001
		var strength := 4.0 * minf(_shake_remaining / SHAKE_TIME, 1.0)
		offset = Vector2(sin(t * 83.0), cos(t * 67.0) * 0.5) * strength
	if is_staggered() or is_spent():
		offset.y += 5.0
	body.position = offset
	if state == State.DEAD:
		body.modulate = Color(0.4, 0.35, 0.35, maxf(body.modulate.a - delta, 0.25))
	elif state == State.DYING:
		# Death flash: white and blood red, alternating.
		var blink := int(_state_remaining * 12.0) % 2 == 0
		body.modulate = Color(2.2, 2.2, 2.2) if blink else Color(1.4, 0.5, 0.45)
	elif _flash_remaining > 0.0:
		body.modulate = Color(2.2, 2.2, 2.2)
	elif state == State.FURY:
		body.modulate = Color(1.3, 0.75, 0.65)
	elif is_staggered() or is_spent():
		body.modulate = Color(0.75, 0.8, 0.85)
	else:
		body.modulate = Color.WHITE
	for pop in _pops:
		pop.age += delta
	_pops = _pops.filter(func(pop: Dictionary) -> bool: return pop.age < POP_TIME)
	_overlay.queue_redraw()


func _show_banner(text: String, duration: float) -> void:
	banner.text = text
	_banner_remaining = duration


func _player() -> CharacterBody2D:
	return get_tree().get_first_node_in_group("players") as CharacterBody2D


func _player_alive() -> bool:
	var player := _player()
	return is_instance_valid(player) and player.health > 0


func _draw_overlay() -> void:
	var font := preload("res://assets/fonts/YatraOne-Regular.ttf")
	for head in heads:
		if not head.alive:
			continue
		var at: Vector2 = RavanBody.HEAD_OFFSETS[head.index]
		if head.state == HeadState.TELEGRAPH or head.state == HeadState.ATTACK:
			# Heads cannot move, so the telegraph is a growing glow and a charge ring.
			var color := head.attack_color()
			var progress := head.telegraph_progress() if head.state == HeadState.TELEGRAPH else 1.0
			color.a = 0.25 + 0.2 * progress
			_overlay.draw_circle(at, 13.0 + progress * 6.0, color)
			color.a = 1.0
			_overlay.draw_arc(at, 19.0, -PI * 0.5, -PI * 0.5 + TAU * maxf(progress, 0.01), 28, color, 3.0)
			_overlay.draw_string_outline(font, at + Vector2(-60, -30), head.attack_word() + "!", HORIZONTAL_ALIGNMENT_CENTER, 120, 13, 4, Color(0.08, 0.03, 0.03))
			_overlay.draw_string(font, at + Vector2(-60, -30), head.attack_word() + "!", HORIZONTAL_ALIGNMENT_CENTER, 120, 13, color)
			# A white flash marks the moment the attack leaves the mouth.
			if head.state == HeadState.ATTACK and head.remaining > head.attack_time - 0.12:
				_overlay.draw_circle(at, 11.0, Color(1.0, 1.0, 0.9, 0.8))
		elif state == State.FURY and head.fury_lit:
			if head.fury_silent:
				_overlay.draw_circle(at, 12.0, Color(0.1, 0.25, 0.25, 0.55))
				continue
			_overlay.draw_circle(at, 15.0, Color(1.0, 0.25, 0.1, 0.35))
			# Each lit head aims at the lanes it will burn.
			var aim := FURY_COLOR
			aim.a = 0.35
			for lane in range(LANE_COUNT):
				if lane_head(lane) == head.index and not current_safe_lanes.has(lane):
					_overlay.draw_line(at, to_local(Vector2(lane_center(lane), global_position.y)), aim, 1.5)
	for pop in _pops:
		var t: float = pop.age / POP_TIME
		var ring := Color(1.0, 0.75, 0.35, 1.0 - t)
		_overlay.draw_arc(pop.at, lerpf(10.0, 46.0, t), 0.0, TAU, 28, ring, 4.0 * (1.0 - t) + 1.0)
		_overlay.draw_circle(pop.at, 14.0 * (1.0 - t), Color(1.0, 1.0, 0.85, 1.0 - t))
	if state != State.FURY:
		return
	for lane in current_safe_lanes:
		var center := to_local(Vector2(lane_center(lane), global_position.y))
		var safe := SAFE_COLOR
		safe.a = 0.16
		_overlay.draw_rect(Rect2(center.x - lane_width() * 0.5 + 3.0, -90.0, lane_width() - 6.0, 90.0), safe)
		safe.a = 0.9
		_overlay.draw_rect(Rect2(center.x - lane_width() * 0.5 + 3.0, -5.0, lane_width() - 6.0, 5.0), safe)
		_overlay.draw_string(font, Vector2(center.x - 30.0, -96.0), "SAFE", HORIZONTAL_ALIGNMENT_CENTER, 60, 13, SAFE_COLOR)
