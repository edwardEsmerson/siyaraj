extends "res://scripts/main/main.gd"
## Single-screen boss arena. Reuses the shared HUD/restart loop and binds the
## generic BossHealthBar to the `TestCourse/Boss` node.

@export var arena_width: int = 960
@export var phase_two_message: String = "Enraged: faster slams and shorter firecracker fuses. Dash behind him to dodge."

@onready var boss: CharacterBody2D = $TestCourse/Boss
@onready var boss_bar: Control = $HUD/BossHealthBar


func _ready() -> void:
	super._ready()
	_course_width = arena_width
	camera.limit_right = arena_width
	camera.position.x = arena_width * 0.5
	camera.reset_smoothing()
	camera.reset_physics_interpolation()
	boss_bar.bind(boss)
	var defeated_name: String = boss.boss_name
	boss.died.connect(func() -> void:
		combat_status.text = "%s defeated! Use Play Again to fight again." % defeated_name
	)
	if boss.has_signal("phase_changed"):
		boss.phase_changed.connect(func(_phase: int) -> void:
			combat_status.text = phase_two_message
		)
