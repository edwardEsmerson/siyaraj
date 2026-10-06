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
	_arena_process_mode = get_parent().process_mode
	get_parent().process_mode = Node.PROCESS_MODE_DISABLED
	comic.play(panels)

func _finish_comic() -> void:
	get_parent().process_mode = _arena_process_mode
	if _showing_aftermath:
		_show_victory()
	else:
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
		_showing_aftermath = true
		_play_comic(aftermath)
	else:
		_show_victory()

func _show_victory() -> void:
	var escape: Node = get_parent().get_node_or_null("PalaceEscape")
	if escape != null and PlaytestNavigation.snapshot.is_empty():
		_escape_ready = true
		escape.open()
		return
	$Victory.present("Boss defeated", "%s has fallen.\nThe path to %s is open." % [_boss_name, destination_name], "Continue")

func _unhandled_input(event: InputEvent) -> void:
	if _escape_ready or get_tree().paused or (comic != null and comic.visible) or not won or not event.is_action_pressed("ui_accept"):
		return
	_continue_campaign()

func _continue_campaign() -> void:
	if _escape_ready:
		return
	_change_destination()

## Only the unlocked palace gate can finish the campaign escape.
func finish_escape() -> void:
	if not _escape_ready:
		return
	_change_destination()

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
