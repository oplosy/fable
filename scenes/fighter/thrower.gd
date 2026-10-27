class_name Thrower
extends Node

## The fighter's throwable slot: the item, how many are left, and the pin-pull/throw cycle.
## Pressing attack pulls the pin (the fuse starts), releasing throws along the aim.

const THROWN_SCENE := preload("res://scenes/throwables/thrown_item.tscn")

## Degrees the throw is lifted above the aim, so a level aim still lobs in an arc.
@export var lift_degrees := 30.0

var fighter: Fighter
var item: ThrowableData
var count := 0

var _cooking := false
var _cook_time := 0.0


func equip(data: ThrowableData, amount: int) -> void:
	item = data
	count = amount


func is_empty() -> bool:
	return item == null or count <= 0


## The pin is pulled and the item is still in hand.
func is_cooking() -> bool:
	return _cooking


## `drawn`: the item is in hand and aimed. `pressed`/`held`: the attack intent this frame.
## `hand`: where the item is, `direction`: the aim as a unit vector.
func physics_update(delta: float, drawn: bool, pressed: bool, held: bool, hand: Vector2, direction: Vector2) -> void:
	if not _cooking:
		if drawn and pressed and not is_empty():
			_cooking = true
			_cook_time = 0.0
		return
	_cook_time += delta
	if item.fuse_time > 0.0 and _cook_time >= item.fuse_time:
		# Held too long: it goes off in the hand.
		var data := item
		_use_one()
		ThrownItem.spawn_effect(data, fighter.get_parent(), hand, fighter)
		return
	# A stunned fighter keeps holding it; the throw waits until it can act.
	if not held and fighter.can_act():
		var lifted := direction.rotated(-deg_to_rad(lift_degrees) * signf(direction.x if direction.x != 0.0 else 1.0))
		_release(hand, lifted * item.throw_speed)


## A knocked-down or dead fighter lets go: a live item falls at its feet.
func drop_live(hand: Vector2) -> void:
	if _cooking:
		_release(hand, Vector2.ZERO)


func _release(hand: Vector2, velocity: Vector2) -> void:
	var thrown: ThrownItem = THROWN_SCENE.instantiate()
	thrown.data = item
	thrown.fuse_left = item.fuse_time - _cook_time
	thrown.thrower = fighter
	thrown.linear_velocity = velocity
	thrown.position = fighter.get_parent().to_local(hand)
	# Releases can come from hits in physics callbacks, where bodies cannot be added directly.
	fighter.get_parent().add_child.call_deferred(thrown)
	_use_one()


func _use_one() -> void:
	_cooking = false
	count -= 1
	if count <= 0:
		item = null
		count = 0
