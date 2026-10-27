class_name Inventory
extends Node

## The fighter's four slots: what it holds, which slot is active, picking spawned
## items up and dropping items into the arena. The melee item lives in Melee and the
## throwables in Thrower; this decides when they change hands.

const WEAPON_SCENE := preload("res://scenes/weapons/weapon.tscn")
const PICKUP_SCENE := preload("res://scenes/items/item_pickup.tscn")
const PICKUPS_LAYER := 8

enum Slot { MELEE, FIREARM, THROWABLE, POWERUP }

var fighter: Fighter
## Items are held at, and dropped from, this node.
var hand: Node2D
var active_slot := Slot.MELEE
var firearm: Weapon

## Shows the held melee item; hit detection never uses it.
var _melee_sprite: Sprite2D


func setup(owner_fighter: Fighter, hand_node: Node2D) -> void:
	fighter = owner_fighter
	hand = hand_node
	_melee_sprite = Sprite2D.new()
	_melee_sprite.visible = false
	hand.add_child(_melee_sprite)
	fighter.melee.item_broke.connect(_show_melee_item)


## Draws the held melee item on `node` (an animated hand) instead of the hand marker.
## Only the art moves; items are still dropped from `hand`.
func show_melee_item_on(node: Node2D) -> void:
	_melee_sprite.reparent(node, false)


func equip_firearm(data: WeaponData) -> void:
	if firearm:
		firearm.queue_free()
	firearm = WEAPON_SCENE.instantiate()
	firearm.data = data
	hand.add_child(firearm)
	active_slot = Slot.FIREARM


func equip_melee_item(data: MeleeItemData) -> void:
	fighter.melee.equip(data)
	_show_melee_item()
	active_slot = Slot.MELEE


## Fills the throwable slot without selecting it (e.g. the starting grenades).
func equip_throwable(data: ThrowableData, amount: int) -> void:
	fighter.thrower.equip(data, amount)


## Empty slots cannot be selected; melee (bare hands) is always available.
func select_slot(slot: Slot) -> bool:
	match slot:
		Slot.MELEE:
			pass
		Slot.FIREARM:
			if firearm == null:
				return false
		Slot.THROWABLE:
			if fighter.thrower.is_empty():
				return false
		_:
			# Power-ups do not exist yet, so this slot is always empty.
			return false
	active_slot = slot
	return true


## Per-frame upkeep: the melee item shows only in its slot, and a used-up throwable
## slot falls back to bare hands.
func physics_update() -> void:
	_melee_sprite.visible = active_slot == Slot.MELEE and fighter.melee.item != null
	if active_slot == Slot.THROWABLE and fighter.thrower.is_empty():
		active_slot = Slot.MELEE


## Only spawned items can be taken: into an empty slot by walking over one, into a
## full slot by standing on one and pressing down (the old item drops).
func update_pickup() -> void:
	var item := _pickup_under()
	if item == null:
		return
	var slot_full: bool
	if item.data is WeaponData:
		slot_full = firearm != null
	elif item.data is ThrowableData:
		slot_full = not fighter.thrower.is_empty()
	else:
		slot_full = fighter.melee.item != null
	var swapping := fighter.controller.down and fighter.is_on_floor() and not fighter.is_running()
	if slot_full and not swapping:
		return
	if item.data is WeaponData:
		drop_firearm()
		equip_firearm(item.data)
	elif item.data is ThrowableData:
		_drop_throwables()
		equip_throwable(item.data, item.data.count)
		active_slot = Slot.THROWABLE
	else:
		_drop_melee_item()
		equip_melee_item(item.data)
	item.take()


## The firearm falls into the arena and the fighter is left with bare hands.
func drop_firearm() -> void:
	if firearm == null:
		return
	_drop_item(firearm.data)
	firearm.queue_free()
	firearm = null
	if active_slot == Slot.FIREARM:
		active_slot = Slot.MELEE


## A dead fighter lets go of everything it holds.
func drop_all() -> void:
	drop_firearm()
	_drop_melee_item()
	_drop_throwables()


## The melee item falls into the arena and the fighter punches again.
func _drop_melee_item() -> void:
	if fighter.melee.item == null:
		return
	_drop_item(fighter.melee.item)
	fighter.melee.item = null
	_show_melee_item()


## The unused throwables fall into the arena as one item; the slot is left empty.
func _drop_throwables() -> void:
	if fighter.thrower.is_empty():
		return
	_drop_item(fighter.thrower.item)
	fighter.thrower.equip(null, 0)


## Dropped items can never be picked up again and disappear after a while.
func _drop_item(data: ItemData) -> void:
	var dropped: ItemPickup = PICKUP_SCENE.instantiate()
	dropped.data = data
	var world := fighter.get_parent()
	dropped.position = world.to_local(hand.global_position)
	dropped.linear_velocity = Vector2(-fighter.facing * 40.0, -120.0)
	# Hits arrive from physics callbacks, where bodies cannot be added directly.
	world.add_child.call_deferred(dropped)


func _show_melee_item() -> void:
	ItemData.show_on(_melee_sprite, fighter.melee.item)


func _pickup_under() -> ItemPickup:
	var body: CollisionShape2D = fighter.body_shape()
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = body.shape
	query.transform = body.global_transform
	query.collision_mask = PICKUPS_LAYER
	for result in fighter.get_world_2d().direct_space_state.intersect_shape(query):
		var item := result.collider as ItemPickup
		if item and item.pickable and not item.is_queued_for_deletion():
			return item
	return null
