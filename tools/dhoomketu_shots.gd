extends SceneTree
## Renders Dhoomketu's sprite states in his isolated arena for art review:
##   xvfb-run -a godot --path . --resolution 1920x1080 -s tools/dhoomketu_shots.gd
## Writes docs/screenshots/dhoomketu/<n>-<state>.png. Siya stands still near him for scale.

const OUT: String = "res://docs/screenshots/dhoomketu"
const ARENA: String = "res://scenes/bosses/dhoomketu_arena.tscn"
## Name, attack index (-1 for none), seconds of live boss physics, phase-two first, defeat.
const SHOTS: Array = [
	["intro", -1, 0.55, false, false],
	["idle", 1, 3.0, false, false],
	["rocket-fuse", 0, 0.35, false, false],
	["rocket-launch", 0, 1.15, false, false],
	["chakri-throw", 1, 1.05, false, false],
	["anaar-lob", 2, 0.75, false, false],
	["anaar-burn", 2, 1.6, false, false],
	["reload", 2, 2.55, false, false],
	["phase-shift", -1, 0.5, true, false],
	["phase2-rockets", 0, 1.15, true, false],
	["death", -1, 1.6, false, true],
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await process_frame
	var n: int = 0
	for shot: Array in SHOTS:
		n += 1
		var stage: Node2D = load(ARENA).instantiate()
		root.add_child(stage)
		await process_frame
		var boss: CharacterBody2D = stage.get_node("TestCourse/Boss")
		var player: CharacterBody2D = stage.get_node("Player")
		player.set_physics_process(false)
		player.position = Vector2(470, 430)
		boss.set_physics_process(false)
		if shot[3]:
			boss.take_damage(boss.max_health / 2)
		if shot[1] >= 0:
			if shot[3]:
				boss.phase = 2
			boss.start_attack(shot[1], player.position.x)
		if shot[4]:
			boss.take_damage(boss.health)
		boss.set_physics_process(not shot[4])
		var frames: int = int(shot[2] * 60.0)
		for _i: int in frames:
			await physics_frame
		boss.set_physics_process(false)
		for hazard: Node in boss.get_parent().get_children():
			hazard.set_physics_process(false)
		await process_frame
		await RenderingServer.frame_post_draw
		var path: String = OUT.path_join("%02d-%s.png" % [n, shot[0]])
		root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		stage.free()
		await process_frame
	print("dhoomketu_shots: saved %d screenshots in %s" % [n, OUT])
	quit()
