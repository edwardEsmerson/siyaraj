extends CanvasLayer
## Attach to the existing boss arena. Actors and arena mechanics remain shared.

const Story = preload("res://scripts/main/story_panels.gd")

@export var boss_path: NodePath
@export var next_level: String = ""
@export var destination_name: String = "level select"
@export var introduction: Array[Dictionary] = []
@export var story_key: String = ""
@export var versus_texture: String = ""
var won: bool = false
var comic: CanvasLayer
var _arena_process_mode: ProcessMode
var _showing_aftermath: bool = false
var _boss_name: String
var _escape_ready: bool = false
var exit_zone: Area2D
var curtains: Control
var _transitioning: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not story_key.is_empty():
		introduction = Story.introduction(story_key)
	if not versus_texture.is_empty():
		introduction.push_front({"texture": versus_texture, "presentation": "versus", "text": ""})
	$Victory.continued.connect(_continue_campaign)
	$Victory.replayed.connect(PlaytestNavigation._restart)
	$Victory.menu_requested.connect(PlaytestNavigation.show_title)
	if not PlaytestNavigation.snapshot.is_empty():
		destination_name = "the developer menu"
	var boss: Node = get_node(boss_path)
	_boss_name = boss.get("boss_name") if boss.get("boss_name") != null else boss.name
	boss.died.connect(_on_defeated)
	if not introduction.is_empty() and not PlaytestNavigation.boss_introduction_seen:
		_play_comic(introduction)

func _play_comic(panels: Array[Dictionary]) -> void:
	if comic == null:
		comic = preload("res://scenes/ui/comic_cutscene.tscn").instantiate()
		add_child(comic)
		comic.finished.connect(_finish_comic)
	if not _transitioning:
		_arena_process_mode = get_parent().process_mode
	get_parent().process_mode = Node.PROCESS_MODE_DISABLED
	comic.play(panels)

func _finish_comic() -> void:
	if _showing_aftermath:
		call_deferred("_change_destination")
	else:
		get_parent().process_mode = _arena_process_mode
		PlaytestNavigation.boss_introduction_seen = true

func _on_defeated() -> void:
	if won:
		return
	won = true
	var cage: Node = get_parent().get_node_or_null("RajCage")
	if cage != null:
		cage.release()
	var aftermath: Array[Dictionary] = Story.aftermath(story_key)
	if not aftermath.is_empty() and PlaytestNavigation.snapshot.is_empty():
		_escape_ready = true
		call_deferred("_unlock_exit")
	else:
		_show_victory()

func _show_victory() -> void:
	$Victory.present("Boss defeated", "%s has fallen.\nThe path to %s is open." % [_boss_name, destination_name], "Continue")

func _unhandled_input(event: InputEvent) -> void:
	if _escape_ready or get_tree().paused or (comic != null and comic.visible) or not won or not event.is_action_pressed("ui_accept"):
		return
	_continue_campaign()

func _continue_campaign() -> void:
	if _escape_ready:
		return
	_change_destination()

## Campaign exits trigger the curtain close, then the existing aftermath.
func _unlock_exit() -> void:
	var escape: Node = get_parent().get_node_or_null("PalaceEscape")
	if escape != null:
		escape.open()
	exit_zone = preload("res://scripts/main/boss_exit.gd").new()
	exit_zone.name = "BossExit"
	exit_zone.position = Vector2(862 if story_key == "palace" else 900, 430)
	exit_zone.player_entered.connect(finish_escape)
	get_parent().add_child(exit_zone)
	var prompt := Label.new()
	prompt.text = "Walk right through the glowing exit to continue."
	prompt.theme_type_variation = &"WorldPrompt"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.position = Vector2(120, 480)
	prompt.size = Vector2(720, 42)
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().get_node("HUD").add_child(prompt)

func finish_escape() -> void:
	if not _escape_ready or _transitioning or get_tree().paused:
		return
	var player: CharacterBody2D = get_parent().get_node("Player")
	if player.state == player.State.DEAD or exit_zone == null or not exit_zone.overlaps_body(player):
		return
	_transitioning = true
	_arena_process_mode = get_parent().process_mode
	get_parent().process_mode = Node.PROCESS_MODE_DISABLED
	var curtain_layer := CanvasLayer.new()
	curtain_layer.layer = 35
	curtain_layer.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(curtain_layer)
	curtains = preload("res://scripts/ui/curtains.gd").new()
	curtains.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtains.mouse_filter = Control.MOUSE_FILTER_IGNORE
	curtains.clip_contents = true
	curtain_layer.add_child(curtains)
	var close := curtain_layer.create_tween()
	close.tween_property(curtains, "coverage", 1.0, 0.45)
	await close.finished
	_showing_aftermath = true
	_play_comic(Story.aftermath(story_key))

func _change_destination() -> void:
	if get_tree().paused or (comic != null and comic.visible) or not won:
		return
	var player: CharacterBody2D = get_parent().get_node("Player")
	if player.state == player.State.DEAD:
		return
	get_viewport().set_input_as_handled()
	if next_level.is_empty() or not PlaytestNavigation.snapshot.is_empty():
		PlaytestNavigation.show_menu()
	else:
		PlaytestNavigation.start_level(next_level)
