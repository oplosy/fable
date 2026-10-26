class_name Fighter
extends CharacterBody2D

const WEAPON_SCENE := preload("res://scenes/weapons/weapon.tscn")

@export var character: CharacterData
@export var run_speed := 120.0
@export var acceleration := 900.0
@export var friction := 1100.0
@export var jump_velocity := -300.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var facing := 1
var weapon: Weapon

@onready var _visuals: Node2D = $Visuals
@onready var _placeholder: ColorRect = $Visuals/Placeholder
@onready var _hand: Marker2D = $Visuals/Hand


func _ready() -> void:
	if character:
		_placeholder.color = character.placeholder_color


func equip(data: WeaponData) -> void:
	if weapon:
		weapon.queue_free()
	weapon = WEAPON_SCENE.instantiate()
	weapon.data = data
	_hand.add_child(weapon)


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

	if weapon:
		var wants_fire := Input.is_action_pressed("fire") if weapon.data.automatic else Input.is_action_just_pressed("fire")
		if wants_fire:
			# Projectiles belong to the arena, not the fighter, so they outlive it.
			weapon.try_fire(facing, get_parent())

	move_and_slide()
