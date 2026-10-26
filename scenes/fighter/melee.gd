class_name Melee
extends Node

## Runs a fighter's melee combo: timing, chaining, the end-of-combo pause and hit detection.
## Hits come from a physics shape query, so they never depend on sprite art.

var fighter: Fighter
var fighter_class: FighterClass

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
	return fighter_class.melee_combo[_index] if _index >= 0 else null


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
	if fighter_class.melee_combo.is_empty() or _air:
		return
	if is_attacking():
		if _index + 1 < fighter_class.melee_combo.size():
			_queued = true
		return
	if _cooldown > 0.0:
		return
	_start(0)


## Stops the combo without a pause, e.g. when the fighter is hit.
func cancel() -> void:
	_index = -1
	_air = false
	_queued = false


func physics_update(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if fighter.is_on_floor():
		_air_used = false
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
		_cooldown = fighter_class.combo_cooldown * float(_index + 1) / fighter_class.melee_combo.size()
		_index = -1


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
		body.take_hit(attack.damage, Vector2(attack.knockback.x * fighter.facing, attack.knockback.y), attack.stun_time, attack.knocks_down)
