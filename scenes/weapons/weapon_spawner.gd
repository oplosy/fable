class_name WeaponSpawner
extends Marker2D

## A fixed weapon spawn point owned by an arena. While empty, it spawns a
## pickable weapon every `interval` seconds, picked from `weapons` by spawn_weight.

const PICKUP_SCENE := preload("res://scenes/weapons/dropped_weapon.tscn")

@export var weapons: Array[WeaponData] = []
@export var interval := 10.0

var _item: DroppedWeapon
var _wait := 0.0


func has_weapon() -> bool:
	return is_instance_valid(_item) and not _item.is_queued_for_deletion()


func _pick_weighted() -> WeaponData:
	var weights := PackedFloat32Array()
	for weapon in weapons:
		weights.append(weapon.spawn_weight)
	var index := RandomNumberGenerator.new().rand_weighted(weights)
	# rand_weighted returns -1 when every weight is zero.
	return weapons[maxi(index, 0)]


func _physics_process(delta: float) -> void:
	if weapons.is_empty() or has_weapon():
		return
	_wait += delta
	if _wait < interval:
		return
	_wait = 0.0
	_item = PICKUP_SCENE.instantiate()
	_item.data = _pick_weighted()
	_item.pickable = true
	add_child(_item)
