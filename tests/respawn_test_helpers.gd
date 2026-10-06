extends RefCounted
## Wait for the complete curtain sequence before exercising restored gameplay.

static func wait_for_respawn(tree: SceneTree) -> void:
	# The death signal queues the transition after the current physics tick.
	await tree.process_frame
	var transition: CanvasLayer = tree.root.get_node("PlaytestNavigation").respawn_transition
	for frame in range(180):
		if not transition.active:
			return
		await tree.physics_frame
		await tree.process_frame
	push_error("Death curtains must finish within three seconds")
