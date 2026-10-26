class_name DroppedWeapon
extends RigidBody2D

## A firearm lying in the arena after its owner was knocked down.
## Picking it up comes with the pickup system.

var data: WeaponData

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_sprite.texture = data.texture
	var shape := RectangleShape2D.new()
	shape.size = data.texture.get_size()
	_shape.shape = shape
