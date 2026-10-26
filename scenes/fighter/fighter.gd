class_name Fighter
extends CharacterBody2D

const WEAPON_SCENE := preload("res://scenes/weapons/weapon.tscn")

@export var character: CharacterData
## Without one the fighter stands idle (e.g. a target dummy).
@export var controller: FighterController
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
	if controller == null:
		controller = FighterController.new()
	if controller.get_parent() == null:
		add_child(controller)


func equip(data: WeaponData) -> void:
	if weapon:
		weapon.queue_free()
	weapon = WEAPON_SCENE.instantiate()
	weapon.data = data
	_hand.add_child(weapon)


func _physics_process(delta: float) -> void:
	controller.poll()

	if not is_on_floor():
		velocity.y += gravity * delta

	if controller.jump and is_on_floor():
		velocity.y = jump_velocity

	var direction := controller.move
	if direction:
		velocity.x = move_toward(velocity.x, direction * run_speed, acceleration * delta)
		facing = 1 if direction > 0 else -1
		_visuals.scale.x = facing
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if weapon:
		var wants_fire := controller.attack_held if weapon.data.automatic else controller.attack
		if wants_fire:
			# Projectiles belong to the arena, not the fighter, so they outlive it.
			weapon.try_fire(facing, get_parent())

	move_and_slide()
