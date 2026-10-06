extends Control

const Sandbox = preload("res://scripts/dev/sandbox.gd")
const SANDBOX: String = "res://scenes/dev/sandbox.tscn"
const LEVELS: PackedStringArray = ["res://scenes/main/forest.tscn", "res://scenes/main/river.tscn", "res://scenes/main/palace.tscn"]
## Developer snapshots, in selector order. `encounter` presets the dev sandbox
## (-1 keeps the inspector choice). Terrain snapshots omit encounters.
const SNAPSHOTS: Array[Dictionary] = [
	{"label": "Weapons / three-weapon playground", "path": "res://scenes/dev/weapons_playground.tscn"},
	{"label": "Character / movement and dash", "path": "res://scenes/main/movement_playground.tscn"},
	{"label": "Enemy / Brute", "path": SANDBOX, "encounter": Sandbox.Encounter.BRUTE},
	{"label": "Enemy / ground shooter", "path": SANDBOX, "encounter": Sandbox.Encounter.SHOOTER},
	{"label": "Enemy / flying enemy", "path": SANDBOX, "encounter": Sandbox.Encounter.FLYER},
	{"label": "Enemy / melee guard", "path": SANDBOX, "encounter": Sandbox.Encounter.GUARD},
	{"label": "Dev / sandbox (inspector encounter)", "path": SANDBOX, "encounter": -1},
	{"label": "Boss / Khara arena", "path": "res://scenes/bosses/khara_arena.tscn"},
	{"label": "Boss / Dhoomketu arena", "path": "res://scenes/bosses/dhoomketu_arena.tscn"},
	{"label": "Boss / Swaminathan arena", "path": "res://scenes/bosses/ravan/ravan_arena.tscn"},
	{"label": "Mechanic / original combat course", "path": "res://scenes/main/main.tscn"},
	{"label": "Terrain / sampler", "path": "res://scenes/main/terrain_sampler.tscn", "terrain": true},
	{"label": "Terrain / river stepping stones", "path": "res://scenes/main/river.tscn", "terrain": true, "section": 1},
	{"label": "Terrain / palace gallery and roofs", "path": "res://scenes/main/palace.tscn", "terrain": true, "section": 2},
	{"label": "Mechanic / canopy climb", "path": "res://scenes/main/forest.tscn", "terrain": true, "room": &"CanopyNest"},
	{"label": "Campaign / forest showdown", "path": "res://scenes/main/forest_showdown.tscn"},
	{"label": "Campaign / ghats showdown", "path": "res://scenes/main/river_showdown.tscn"},
	{"label": "Campaign / palace showdown", "path": "res://scenes/main/palace_showdown.tscn"},
]

func _ready() -> void:
	$Layout/Level.item_selected.connect(_select_level)
	$Layout/Start.pressed.connect(func() -> void:
		PlaytestNavigation.enemies_enabled = $Layout/Enemies.button_pressed
		PlaytestNavigation.start_level(LEVELS[$Layout/Level.selected], $Layout/Section.selected)
	)
	$Layout/Lab.clear()
	for snapshot in SNAPSHOTS:
		$Layout/Lab.add_item(snapshot.label)
	$Layout/OpenLab.pressed.connect(_open_snapshot)
	$Layout/Enemies.button_pressed = PlaytestNavigation.enemies_enabled
	_select_level(0)
	$Layout/Start.grab_focus()

func _open_snapshot() -> void:
	var snapshot: Dictionary = SNAPSHOTS[$Layout/Lab.selected]
	if snapshot.has("encounter"):
		Sandbox.next_encounter = snapshot.encounter
	# Terrain snapshots omit encounters; the standalone arenas always keep theirs.
	PlaytestNavigation.enemies_enabled = not snapshot.get("terrain", false)
	PlaytestNavigation.start_level(snapshot.path, snapshot.get("section", 0), snapshot.get("room", &""), true)

func _select_level(index: int) -> void:
	$Layout/Section.clear()
	$Layout/Section.add_item("Beginning")
	# Read authored checkpoint names without entering the level or running scripts.
	var preview: Node = load(LEVELS[index]).instantiate()
	for checkpoint in preview.get_node("TestCourse/Checkpoints").get_children():
		$Layout/Section.add_item(checkpoint.name.replace("Diya", "").capitalize())
	preview.free()
