class_name ItemPickup
extends RigidBody2D

## An item (firearm, melee item, throwables) lying in the arena. Only items spawned by the
## game can be picked up; items dropped by fighters cannot, and disappear after `lifetime`.

var data: ItemData
var pickable := false
## Seconds a non-pickable (dropped) item stays in the arena.
var lifetime := 5.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	ItemData.show_on(_sprite, data, false)
	var shape := RectangleShape2D.new()
	shape.size = data.world_size()
	_shape.shape = shape
	add_to_group("item_pickups" if pickable else "dropped_items")
	add_to_group(Arena.BOUNDED)
	if not pickable:
		get_tree().create_timer(lifetime, false, true).timeout.connect(queue_free)


func take() -> void:
	queue_free()
