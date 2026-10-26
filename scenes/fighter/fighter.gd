class_name Fighter
extends CharacterBody2D

const WEAPON_SCENE := preload("res://scenes/weapons/weapon.tscn")

enum Slot { MELEE, FIREARM, THROWABLE, POWERUP }

@export var character: CharacterData
## Without one the fighter stands idle (e.g. a target dummy).
@export var controller: FighterController
@export var run_speed := 120.0
@export var acceleration := 900.0
@export var friction := 1100.0
@export var jump_velocity := -300.0
@export var aim_speed_degrees := 90.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var facing := 1
var active_slot := Slot.MELEE
var firearm: Weapon
## Radians within the half-circle the fighter faces: 0 level, -PI/2 straight up, PI/2 straight down.
## Kept when turning around.
var aim_angle := 0.0

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


func equip_firearm(data: WeaponData) -> void:
	if firearm:
		firearm.queue_free()
	firearm = WEAPON_SCENE.instantiate()
	firearm.data = data
	_hand.add_child(firearm)
	active_slot = Slot.FIREARM


## The firearm is in hand only while standing on the floor; moving puts it away.
func is_firearm_drawn() -> bool:
	return active_slot == Slot.FIREARM and firearm != null and is_on_floor() and controller.move == 0.0


func aim_direction() -> Vector2:
	return Vector2(facing * cos(aim_angle), sin(aim_angle))


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

	if firearm:
		var drawn := is_firearm_drawn()
		firearm.visible = drawn
		if drawn:
			aim_angle = clampf(aim_angle + controller.aim * deg_to_rad(aim_speed_degrees) * delta, -PI / 2.0, PI / 2.0)
			# Visuals are mirrored by facing, so the same local angle points into the facing half.
			_hand.rotation = aim_angle
		var wants_fire := controller.attack_held if firearm.data.automatic else controller.attack
		if drawn and wants_fire:
			# Projectiles belong to the arena, not the fighter, so they outlive it.
			firearm.try_fire(aim_direction(), get_parent())

	move_and_slide()
