extends StaticBody2D
## Ravan's one hurtbox: body and head row share a single health pool. It sits on
## the enemy body layer, so the lash, skyshot and chakri hit it unchanged, and
## each weapon hits it once per swing however many of its shapes overlap.
const ENEMY_BODY_LAYER: int = 4

var health: int:
	get:
		return get_parent().health


func _ready() -> void:
	collision_layer = ENEMY_BODY_LAYER
	collision_mask = 0


func take_damage(amount: int, knockback: Vector2) -> void:
	get_parent().take_damage(amount, knockback)
