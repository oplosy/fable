class_name Fighter
extends CharacterBody2D

@export var character: CharacterData
@export var run_speed := 120.0
@export var acceleration := 900.0
@export var friction := 1100.0
@export var jump_velocity := -300.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var facing := 1

@onready var _visuals: Node2D = $Visuals
@onready var _placeholder: ColorRect = $Visuals/Placeholder


func _ready() -> void:
	if character:
		_placeholder.color = character.placeholder_color


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = move_toward(velocity.x, direction * run_speed, acceleration * delta)
		facing = 1 if direction > 0 else -1
		_visuals.scale.x = facing
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	move_and_slide()
