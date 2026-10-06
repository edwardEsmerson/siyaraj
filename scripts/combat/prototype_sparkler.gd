extends "res://scripts/combat/melee_attack.gd"
## Single ground or aerial lash. Recovery presses are ignored, never buffered.
var externally_locked: bool = false


func start(facing: int) -> bool:
	if externally_locked or is_busy():
		return false
	var airborne: bool = not get_parent().is_on_floor()
	damage = 1
	reach = 34.0
	hitbox_size = Vector2(62, 54) if airborne else Vector2(48, 36)
	windup_time = 0.06
	active_time = 0.12
	recovery_time = 0.18
	knockback = Vector2(110, -90)
	swing_color = Color(1.0, 0.75, 0.2)
	return super.start(facing)
