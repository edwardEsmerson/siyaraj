extends Node2D
## Course flow stays separate from the movement playground used for tuning.

signal finished

const COURSE_WIDTH: int = 4800
var guard_defeated: bool = false
var completed: bool = false


func _ready() -> void:
	$Enemy.died.connect(_open_exit)
	$Finish.body_entered.connect(_on_finish_entered)


func _open_exit() -> void:
	guard_defeated = true
	$ExitGate/CollisionShape2D.set_deferred("disabled", true)
	$ExitHint.text = "EXIT OPEN\nJump the last gap and reach the flag."
	$ExitHint.modulate = Color(0.3, 0.9, 0.85)
	create_tween().tween_property($ExitGate/Body, "modulate:a", 0.15, 0.25)


func _on_finish_entered(body: Node2D) -> void:
	if completed or not guard_defeated or not body.is_in_group("players"):
		return
	if body.state == body.State.DEAD:
		return
	completed = true
	finished.emit()


func hint_at(x: float) -> String:
	if completed:
		return "Course complete! R to replay."
	if x < 560.0:
		return "1 / Run, release to stop, and reverse direction."
	if x < 1040.0:
		return "2 / Space to climb. Tap and hold give the same jump."
	if x < 1880.0:
		return "3 / Run up and jump close to each edge."
	if x < 2260.0:
		return "4 / Low ceiling. Keep moving after a head collision."
	if x < 3330.0:
		return "5 / Jump, then Shift near the apex. Land to recharge."
	if x < 3630.0 and is_instance_valid(get_node_or_null("FlyingEnemy")):
		return "6 / Flyer: dodge the orange charge, then jump + J to strike."
	if not guard_defeated:
		return "6 / J to strike. Orange wind-up: step away or jump past."
	if x < 4210.0 and is_instance_valid(get_node_or_null("GroundShooter")):
		return "6 / Shooter: purple bolts follow you. Jump or dash past; J interrupts its charge."
	return "7 / Exit open. Jump the last gap and reach the flag."
