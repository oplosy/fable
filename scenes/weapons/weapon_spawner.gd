class_name WeaponSpawner
extends Marker2D

## A fixed weapon spawn point owned by an arena. While empty, it spawns a
## pickable weapon (one of `weapons`, at random) every `interval` seconds.

const PICKUP_SCENE := preload("res://scenes/weapons/dropped_weapon.tscn")

@export var weapons: Array[WeaponData] = []
@export var interval := 10.0

var _item: DroppedWeapon
var _wait := 0.0


func has_weapon() -> bool:
	return is_instance_valid(_item) and not _item.is_queued_for_deletion()


func _physics_process(delta: float) -> void:
	if weapons.is_empty() or has_weapon():
		return
	_wait += delta
	if _wait < interval:
		return
	_wait = 0.0
	_item = PICKUP_SCENE.instantiate()
	_item.data = weapons.pick_random()
	_item.pickable = true
	add_child(_item)
