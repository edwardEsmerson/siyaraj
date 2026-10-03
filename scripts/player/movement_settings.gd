class_name PlayerMovementSettings
extends Resource
## Starting values for the next movement milestone. Tune together in the test course.

@export var run_speed: float = 240.0
@export var acceleration: float = 2400.0
@export var deceleration: float = 3000.0
@export var jump_velocity: float = -420.0
@export var rise_gravity: float = 1200.0
@export var fall_gravity: float = 1800.0
@export_range(0.0, 1.0) var jump_release_multiplier: float = 0.45
@export var coyote_time: float = 0.10
@export var jump_buffer_time: float = 0.12
@export var dash_speed: float = 720.0
@export var dash_duration: float = 0.15
