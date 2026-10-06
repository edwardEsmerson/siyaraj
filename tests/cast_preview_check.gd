extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run_checks")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func run_checks() -> void:
	var scene := load("res://scenes/dev/cast_preview.tscn") as PackedScene
	check(scene != null, "Cast preview must load")
	if scene == null:
		quit(1)
		return
	var preview: Node2D = scene.instantiate()
	root.add_child(preview)
	await process_frame
	check(preview.character_select.item_count == 11, "Preview must list the complete cast")
	var set_count := 0
	var frame_count := 0
	for name_: String in preview.cast_index.subjects:
		var entry: Dictionary = preview.cast_index.subjects[name_]
		if entry.approval != "approved":
			continue
		var frames := load(entry.frames) as SpriteFrames
		check(frames != null, name_ + " resource must load after import")
		if frames == null:
			continue
		var meta: Dictionary = preview._read_json(entry.meta)
		for action: String in meta.animations:
			if meta.animations[action].has("alias_of"):
				continue
			set_count += 1
			frame_count += frames.get_frame_count(action)
			check(frames.get_frame_count(action) == meta.animations[action].frame_count, name_ + "/" + action + " must retain its ordered frame count")
		for action: StringName in frames.get_animation_names():
			for n in frames.get_frame_count(action):
				check(frames.get_frame_texture(action, n) != null, "%s/%s/%d must have an imported texture" % [name_, action, n])
	check(set_count == 73 and frame_count == 195, "Complete library must load 73 animation sets and 195 frames")
	preview.select_subject("robin")
	check(preview.art.visible, "Approved Robin must be visible")
	check(preview.art.scale == Vector2(0.5, 0.5), "Native art must display at scale 0.5")
	check(preview.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Preview must use nearest filtering")
	preview.select_action("fly")
	check(preview.art.sprite_frames.get_frame_count("fly") == 4, "Robin fly must keep four approved frames")
	check(preview.art.sprite_frames.get_animation_speed("fly") == 10.0, "Robin fly timing must remain 10 FPS")
	preview.step_frame(1)
	check(preview.art.frame == 1 and not preview.art.is_playing(), "Stepping must pause at the next frame")
	preview.step_frame(-1)
	check(preview.art.frame == 0, "Backward stepping must preserve order")
	preview.step_frame(-1)
	check(preview.art.frame == 3, "Stepping backward from first frame must wrap")
	preview.flipped = true
	preview._update_transform()
	check(preview.stage.scale == Vector2(-1, 1), "Flip must include the whole composite")
	preview.set_background(1)
	check(preview.background.texture != null, "Forest preview background must load")
	preview.set_background(2)
	check(preview.background.texture != null, "Title skyline must load")
	preview.set_background(0)
	check(preview.background.texture == null, "Checker background must remain available")
	check(preview.art.sprite_frames.has_animation("talk"), "Robin talk compatibility must be retained")
	check(preview.art.sprite_frames.has_animation("point"), "Robin hint must also provide the point alias")
	preview.select_subject("swaminathan")
	check(preview.heads.size() == 10, "Actual boss resources must create ten heads")
	preview.select_head_action("faces")
	for n in preview.heads.size():
		check(preview.heads[n].frame == n, "Head expression frames must be individually selectable")
	preview.select_subject("khara")
	preview.select_action("ladi_cast")
	check(not preview.gada.visible, "Gada must be intentionally hidden while hands place fireworks")
	preview.select_subject("raj")
	if preview.cast_index.subjects.raj.approval == "pending":
		check(not preview.art.visible and preview.info.text.contains("awaiting"), "Pending bases must not appear approved")

	# Exercise the ten-head composition using existing approved art as a test fixture.
	preview.cast_index.subjects["swaminathan"] = preview.cast_index.subjects["robin"].duplicate(true)
	preview.cast_index.subjects["swaminathan-head"] = preview.cast_index.subjects["robin"].duplicate(true)
	preview.select_subject("swaminathan")
	preview.metadata["attachment"] = {"head_offsets_units": [[-198, -150], [-154, -162], [-110, -171], [-66, -177], [-22, -180], [22, -180], [66, -177], [110, -171], [154, -162], [198, -150]]}
	preview._make_components()
	check(preview.heads.size() == 10, "Composite must create ten independently anchored heads")
	preview.composite = false
	preview._update_components()
	for head: AnimatedSprite2D in preview.heads:
		check(not head.visible, "Composite toggle must hide every head")

	# Exercise per-frame hand attachment and shared flipping with an approved fixture.
	preview.cast_index.subjects["khara"] = preview.cast_index.subjects["robin"].duplicate(true)
	preview.select_subject("khara")
	preview.gada.texture = load("res://assets/sprites/robin/sprite.png")
	preview.metadata["attachment"] = {"frames": {"fly": [{"hand_from_anchor_px": [28, -140], "rotation_degrees": 45.0}, null, null, null]}}
	preview.composite = true
	preview.select_action("fly")
	check(preview.gada.visible, "A registered pose must show the separate gada")
	check(preview.gada.position == Vector2(14, -70), "Attachment art pixels must convert to game units")
	check(is_equal_approx(preview.gada.rotation, PI / 4.0), "Attachment rotation must follow the frame metadata")
	preview.step_frame(1)
	check(not preview.gada.visible, "An unregistered moving pose must not use a guessed attachment")
	preview.queue_free()
	await process_frame
	print("cast_preview_check: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(1 if failures else 0)
