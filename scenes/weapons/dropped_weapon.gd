class_name DroppedWeapon
extends RigidBody2D

## A firearm or melee item lying in the arena. Only weapons spawned by the game can be picked up;
## weapons dropped by fighters cannot, and disappear after `lifetime`.

## Emitted when a fighter picks this weapon up, just before it is removed.
signal taken

var data: ItemData
var pickable := false
## Seconds a non-pickable (dropped) weapon stays in the arena.
var lifetime := 5.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_sprite.texture = data.texture
	var shape := RectangleShape2D.new()
	shape.size = data.texture.get_size()
	_shape.shape = shape
	add_to_group("weapon_pickups" if pickable else "dropped_weapons")
	if not pickable:
		get_tree().create_timer(lifetime, false, true).timeout.connect(queue_free)


func take() -> void:
	taken.emit()
	queue_free()
