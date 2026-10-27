class_name ItemSpawner
extends Marker2D

## A fixed item spawn point owned by an arena. While empty, it spawns a
## pickable item every `interval` seconds, picked from `items` by spawn_weight.

const PICKUP_SCENE := preload("res://scenes/items/item_pickup.tscn")

@export var items: Array[ItemData] = []
@export var interval := 10.0

var _item: ItemPickup
var _wait := 0.0


func has_item() -> bool:
	return is_instance_valid(_item) and not _item.is_queued_for_deletion()


func _pick_weighted() -> ItemData:
	var weights := PackedFloat32Array()
	for item in items:
		weights.append(item.spawn_weight)
	var index := RandomNumberGenerator.new().rand_weighted(weights)
	# rand_weighted returns -1 when every weight is zero.
	return items[maxi(index, 0)]


func _physics_process(delta: float) -> void:
	if items.is_empty() or has_item():
		return
	_wait += delta
	if _wait < interval:
		return
	_wait = 0.0
	_item = PICKUP_SCENE.instantiate()
	_item.data = _pick_weighted()
	_item.pickable = true
	add_child(_item)
