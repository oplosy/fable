class_name Melee
extends Node

## Runs a fighter's melee combo: timing, chaining, the end-of-combo pause and hit detection.
## Hits come from a physics shape query, so they never depend on sprite art.

## Emitted when a held item has used up its durability and is gone.
signal item_broke

var fighter: Fighter
var fighter_class: FighterClass
## Held melee item; its combo replaces the class's punches. Null means bare hands.
var item: MeleeItemData
## Hits the held item can still land before it breaks.
var item_hits_left := 0

var _index := -1
var _air := false
var _air_used := false
var _time := 0.0
var _queued := false
var _cooldown := 0.0
var _already_hit: Array[Node] = []


func is_attacking() -> bool:
	return _index >= 0 or _air


func is_air_attacking() -> bool:
	return _air


func current_attack() -> MeleeAttack:
	if _air:
		return fighter_class.air_attack
	return _combo()[_index] if _index >= 0 else null


## Index of the running attack within the combo, -1 when idle.
func combo_index() -> int:
	return _index


func is_hitting() -> bool:
	if not is_attacking():
		return false
	var attack := current_attack()
	return _time >= attack.windup and _time < attack.windup + attack.active


func is_cooling_down() -> bool:
	return _cooldown > 0.0


## On the ground: starts the combo, or queues the next attack if one is running.
## In the air: the class's jump kick, once per jump.
func request_attack(airborne: bool) -> void:
	if fighter_class == null:
		return
	if airborne:
		if not is_attacking() and not _air_used and fighter_class.air_attack:
			_air_used = true
			_start(-1)
			_air = true
		return
	if _combo().is_empty() or _air:
		return
	if is_attacking():
		if _index + 1 < _combo().size():
			_queued = true
		return
	if _cooldown > 0.0:
		return
	_start(0)


## Takes `data` in hand with full durability, replacing bare hands or the old item.
func equip(data: MeleeItemData) -> void:
	item = data
	item_hits_left = data.durability


## Stops the combo without a pause, e.g. when the fighter is hit.
func cancel() -> void:
	_index = -1
	_air = false
	_queued = false


func physics_update(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if fighter.is_on_floor():
		_air_used = false
	# A worn-out item lasts until its combo ends, so the combo never switches mid-chain.
	if item and item_hits_left <= 0 and not is_attacking():
		item = null
		item_broke.emit()
	if not is_attacking():
		return
	_time += delta
	var attack := current_attack()
	if is_hitting():
		_apply_hits(attack)
	if _time < attack.duration():
		return
	if _air:
		_air = false
	elif _queued:
		_start(_index + 1)
	else:
		# A longer chain earns a longer pause, so cutting combos short cannot be spammed.
		var full_pause := item.combo_cooldown if item else fighter_class.combo_cooldown
		var scaled := full_pause * float(_index + 1) / _combo().size()
		_cooldown = maxf(scaled, _escape_pause(attack))
		_index = -1


## Shortest pause after `last` that leaves its target free for combo_escape_time before
## the next combo can hit, assuming the latest possible hit (end of the active time).
func _escape_pause(last: MeleeAttack) -> float:
	var stun_left_at_end := last.stun_time - last.recovery
	return stun_left_at_end - _combo()[0].windup + fighter_class.combo_escape_time


func _combo() -> Array[MeleeAttack]:
	return item.combo if item else fighter_class.melee_combo


func _start(index: int) -> void:
	_index = index
	_time = 0.0
	_queued = false
	_already_hit.clear()


func _apply_hits(attack: MeleeAttack) -> void:
	var shape := RectangleShape2D.new()
	shape.size = attack.hitbox_size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, fighter.global_position + Vector2(attack.hitbox_offset.x * fighter.facing, attack.hitbox_offset.y))
	query.collision_mask = Fighter.FIGHTERS_LAYER
	query.exclude = [fighter.get_rid()]
	for result in fighter.get_world_2d().direct_space_state.intersect_shape(query):
		var body: Node = result.collider
		if body in _already_hit or not body.has_method("take_hit"):
			continue
		_already_hit.append(body)
		# Landed after every fighter's physics step, so two attacks connecting on the same
		# frame both land instead of the first-processed fighter cancelling the other.
		_land_hit.call_deferred(body, attack, Vector2(attack.knockback.x * fighter.facing, attack.knockback.y), item != null and not _air)


## `with_item`: the hit comes from the held item's combo (not the jump kick) and wears it.
func _land_hit(body: Node, attack: MeleeAttack, knockback: Vector2, with_item: bool) -> void:
	if is_instance_valid(body) and is_instance_valid(fighter):
		body.take_hit(attack.damage, knockback, attack.stun_time, attack.knocks_down, fighter)
		if with_item:
			item_hits_left -= 1
