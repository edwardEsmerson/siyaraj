extends CanvasLayer
## Attach to the existing boss arena. Actors and arena mechanics remain shared.

@export var boss_path: NodePath
@export var next_level: String = ""
@export var destination_name: String = "level select"
@export var introduction: Array[Dictionary] = []
var won: bool = false
var comic: CanvasLayer
var _arena_process_mode: ProcessMode

func _ready() -> void:
	$Victory.continued.connect(_continue_campaign)
	$Victory.replayed.connect(PlaytestNavigation._restart)
	$Victory.menu_requested.connect(PlaytestNavigation.show_title)
	if not PlaytestNavigation.snapshot.is_empty():
		destination_name = "the developer menu"
	get_node(boss_path).died.connect(_on_defeated)
	if not introduction.is_empty() and not PlaytestNavigation.boss_introduction_seen:
		comic = preload("res://scenes/ui/comic_cutscene.tscn").instantiate()
		add_child(comic)
		_arena_process_mode = get_parent().process_mode
		get_parent().process_mode = Node.PROCESS_MODE_DISABLED
		comic.finished.connect(_finish_introduction)
		comic.play(introduction)

func _finish_introduction() -> void:
	PlaytestNavigation.boss_introduction_seen = true
	get_parent().process_mode = _arena_process_mode

func _on_defeated() -> void:
	won = true
	var boss: Node = get_node(boss_path)
	var boss_name: String = boss.get("boss_name") if boss.get("boss_name") != null else boss.name
	$Victory.present("Boss defeated", "%s has fallen.\nThe path to %s is open." % [boss_name, destination_name], "Continue")

func _unhandled_input(event: InputEvent) -> void:
	if not won or not event.is_action_pressed("ui_accept"):
		return
	_continue_campaign()

func _continue_campaign() -> void:
	var player: CharacterBody2D = get_parent().get_node("Player")
	if player.state == player.State.DEAD:
		return
	get_viewport().set_input_as_handled()
	if next_level.is_empty() or not PlaytestNavigation.snapshot.is_empty():
		PlaytestNavigation.show_menu()
	else:
		PlaytestNavigation.start_level(next_level)
