extends Control

const LEVELS: PackedStringArray = ["res://scenes/main/forest.tscn", "res://scenes/main/river.tscn", "res://scenes/main/palace.tscn"]
const LABS: PackedStringArray = ["res://scenes/combat/weapons_playground.tscn", "res://scenes/main/movement_playground.tscn", "res://scenes/combat/brute_arena.tscn", "res://scenes/combat/ground_shooter_arena.tscn", "res://scenes/combat/flying_enemy_arena.tscn", "res://scenes/combat/combat_arena.tscn", "res://scenes/main/main.tscn"]
const SNAPSHOT_SECTIONS: PackedInt32Array = [0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 0]
const SNAPSHOT_PATHS: PackedStringArray = ["res://scenes/main/terrain_sampler.tscn", "res://scenes/main/river.tscn", "res://scenes/main/palace.tscn", "res://scenes/main/forest.tscn"]

func _ready() -> void:
	$Layout/Level.item_selected.connect(_select_level)
	$Layout/Start.pressed.connect(func() -> void:
		PlaytestNavigation.enemies_enabled = $Layout/Enemies.button_pressed
		PlaytestNavigation.start_level(LEVELS[$Layout/Level.selected], $Layout/Section.selected)
	)
	$Layout/OpenLab.pressed.connect(_open_snapshot)
	$Layout/Enemies.button_pressed = PlaytestNavigation.enemies_enabled
	_select_level(0)
	$Layout/Start.grab_focus()

func _open_snapshot() -> void:
	var index: int = $Layout/Lab.selected
	var path: String = LABS[index] if index < LABS.size() else SNAPSHOT_PATHS[index - LABS.size()]
	# Terrain snapshots omit encounters; the standalone enemy arenas always keep theirs.
	PlaytestNavigation.enemies_enabled = index < 7
	PlaytestNavigation.start_level(path, SNAPSHOT_SECTIONS[index], &"CanopyNest" if index == 10 else &"", true)

func _select_level(index: int) -> void:
	$Layout/Section.clear()
	$Layout/Section.add_item("Beginning")
	# Read authored checkpoint names without entering the level or running scripts.
	var preview: Node = load(LEVELS[index]).instantiate()
	for checkpoint in preview.get_node("TestCourse/Checkpoints").get_children():
		$Layout/Section.add_item(checkpoint.name.replace("Diya", "").capitalize())
	preview.free()
