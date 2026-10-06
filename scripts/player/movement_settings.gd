class_name PlayerMovementSettings
extends Resource
## Tune these values together in the movement playground.

@export var run_speed: float = 240.0
@export var acceleration: float = 2400.0
@export var deceleration: float = 3000.0
@export var jump_velocity: float = -450.0
@export var rise_gravity: float = 1200.0
@export var fall_gravity: float = 1800.0
@export var max_fall_speed: float = 900.0
@export var coyote_time: float = 0.10
@export var jump_buffer_time: float = 0.12
@export var dash_speed: float = 720.0
@export var dash_duration: float = 0.15
## Horizontal speed an air dash leaves Siya with; it eases back to run_speed at
## the normal acceleration. Set a touch above dash_speed so jump + dash reach
## matches the old gravity-suspending dash.
@export var air_dash_exit_speed: float = 780.0
## Seconds after a ground dash's full duration before any dash can start again.
## Air dashes are limited by their single charge instead.
@export var ground_dash_cooldown: float = 0.25
