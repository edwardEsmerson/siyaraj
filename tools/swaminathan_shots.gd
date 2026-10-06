extends SceneTree
## Screenshots of Swaminathan's animations and attack effects in the real arena:
##   xvfb-run -a godot --path . --resolution 1920x1080 -s tools/swaminathan_shots.gd
## Writes docs/screenshots/swaminathan/*.png: the intro, each head attack mid-telegraph
## and mid-attack, the roar shockwave, Dashanan Fury (telegraph and pillars), the
## stagger after a lost head, the spent window, dying and dead, plus sheet.png.

const ARENA: String = "res://scenes/bosses/ravan/ravan_arena.tscn"
const OUT: String = "res://docs/screenshots/swaminathan"

var arena: Node
var boss: Node2D
var player: CharacterBody2D
var shots: Array[String] = []


func _init() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await _load_arena()
	# Intro: seated, rising, standing.
	await _frames(6)
	await _save("01-intro-seated")
	await _frames(40)
	await _save("02-intro-rising")
	await _wait_state(boss.State.FIGHT)
	await _frames(30)
	await _save("03-idle")
	var attacks := [["fire", 3], ["homing", 2], ["roar", 4], ["lightning", 0], ["spread", 1]]
	var number := 4
	for entry in attacks:
		boss._calm_heads()
		_clear_attacks()
		await _frames(20)
		var kind: String = entry[0]
		var head: RefCounted = boss.heads[entry[1]]
		boss.activate_head(entry[1])
		await _until(func() -> bool: return head.telegraph_progress() >= 0.6)
		await _save("%02d-%s-telegraph" % [number, kind])
		await _until(func() -> bool: return head.state == boss.HeadState.ATTACK)
		if kind == "fire" or kind == "lightning":
			# These hazards warn again after the head fires; then catch them burning.
			await _until(func() -> bool: return _hazard(func(h: Node) -> bool: return h.is_telegraphing() and h.age >= 0.25))
			await _save("%02d-%s-warning" % [number, kind])
			await _until(func() -> bool: return _hazard(func(h: Node) -> bool: return h.is_active() and h.age >= h.telegraph_time + 0.05))
		else:
			await _until(func() -> bool: return not get_nodes_in_group("ravan_attacks").is_empty())
			await _ticks(16)
		await _save("%02d-%s-attack" % [number, kind])
		number += 1
	_clear_attacks()
	boss._calm_heads()
	await _frames(30)
	# A lost head: pop and stagger.
	boss.take_damage(boss.health - boss.head_threshold(boss.heads_alive - 1), Vector2.ZERO)
	await _frames(6)
	await _save("09-head-severed")
	await _frames(18)
	await _save("10-stagger")
	# Phase 2 roar, then Dashanan Fury.
	boss.set_head_count(8)
	boss.take_damage(boss.health - boss.head_threshold(7), Vector2.ZERO)
	await _frames(30)
	await _save("11-phase-roar")
	await _wait_state(boss.State.FURY)
	await _until(func() -> bool: return boss.fury_time >= 0.7)
	await _save("12-fury-ignite")
	await _until(func() -> bool: return _hazard(func(h: Node) -> bool: return h.is_telegraphing() and h.age >= 0.9))
	await _save("13-fury-telegraph")
	await _until(func() -> bool: return _hazard(func(h: Node) -> bool: return h.is_active() and h.age >= h.telegraph_time + 0.1))
	await _save("14-fury-pillars")
	await _wait_state(boss.State.FIGHT)
	await _frames(20)
	await _save("15-spent")
	# Death: the last head falls.
	_clear_attacks()
	boss.set_head_count(1)
	boss._calm_heads()
	await _frames(10)
	boss.take_damage(boss.health, Vector2.ZERO)
	await _frames(20)
	await _save("16-dying")
	await _wait_state(boss.State.DEAD)
	# The victory dialogue would cover him.
	if arena.has_node("CampaignFlow"):
		arena.get_node("CampaignFlow").visible = false
	await _frames(12)
	await _save("17-dead")
	_sheet()
	print("swaminathan_shots: saved %d images in %s" % [shots.size(), OUT])
	quit()


func _load_arena() -> void:
	change_scene_to_file(ARENA)
	await scene_changed
	arena = current_scene
	boss = arena.get_node("Ravan")
	player = arena.get_node("Player")
	boss.auto_activate = false
	boss.rng_seed = 7
	player.position = Vector2(250, 430)
	# Siya stands still so every attack aims at the same spot (and is healed between frames).
	player.set_physics_process(false)


func _clear_attacks() -> void:
	for attack in get_nodes_in_group("ravan_attacks"):
		attack.queue_free()


func _wait_state(target: int) -> void:
	for step in range(1200):
		if boss.state == target:
			return
		await physics_frame


func _wait_head_state(index: int, target: int) -> void:
	for step in range(600):
		if boss.heads[index].state == target:
			return
		await physics_frame


func _seconds(time: float) -> void:
	await _frames(maxi(1, roundi(time * 60.0)))


func _frames(count: int) -> void:
	for frame in range(count):
		await physics_frame
		await process_frame
		if is_instance_valid(player) and player.health > 0:
			player.health = player.max_health


## True when some hazard passes `test`.
func _hazard(test: Callable) -> bool:
	for hazard in get_nodes_in_group("ravan_hazards"):
		if hazard.has_method("is_active") and test.call(hazard):
			return true
	return false


## Waits, tick by tick, until `test` passes (at most 10 s of game time).
func _until(test: Callable) -> void:
	for step in range(600):
		if test.call():
			return
		await physics_frame


func _ticks(count: int) -> void:
	for step in range(count):
		await physics_frame


## The game is paused while a frame is drawn and saved, so a slow renderer never
## skips past a short-lived effect.
func _save(file: String) -> void:
	paused = true
	await process_frame
	await RenderingServer.frame_post_draw
	paused = false
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT.path_join(file + ".png")))
	shots.append(file)


func _sheet() -> void:
	# Contact sheet: the area around Swaminathan from every shot, labelled by file name.
	var columns := 4
	var crop := Rect2i(240, 420, 1440, 480)
	var cell := Vector2i(crop.size.x / 2, crop.size.y / 2)
	var rows := ceili(shots.size() / float(columns))
	var sheet := Image.create(cell.x * columns, cell.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.08, 0.06, 0.07))
	for index in range(shots.size()):
		var image := Image.load_from_file(ProjectSettings.globalize_path(OUT.path_join(shots[index] + ".png")))
		image.convert(Image.FORMAT_RGBA8)
		var part := image.get_region(crop)
		part.resize(cell.x, cell.y, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(part, Rect2i(Vector2i.ZERO, cell), Vector2i(index % columns * cell.x, index / columns * cell.y))
	sheet.save_png(ProjectSettings.globalize_path(OUT.path_join("sheet.png")))
