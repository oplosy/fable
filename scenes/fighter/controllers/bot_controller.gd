class_name BotController
extends FighterController

## A computer player. It sees the same intent a keyboard gives: it hunts the nearest living
## fighter over the arena's WalkMap, shoots along a clear line and punches up close.
## Delays and a little randomness keep it beatable; randomness comes from the arena's rng.

## Reach of a bare punch (px), and how far above or below it still connects.
const PUNCH_REACH := 18.0
const PUNCH_HEIGHT := 12.0
## Closer than this a bot would rather punch than draw (px).
const GUN_MIN_RANGE := 32.0
## Share of a weapon's range a bot shoots from.
const GUN_RANGE := 0.9
## Aim is good enough within this angle (radians).
const AIM_TOLERANCE := 0.06
## Seconds from getting a target in reach to the first attack.
const REACTION := 0.3
## Seconds between attack presses.
const PUNCH_PAUSE := Vector2(0.12, 0.32)
const SHOT_PAUSE := Vector2(0.35, 0.8)
## Chance per physics frame of breaking a combo while it can.
const BREAK_CHANCE := 0.01
## A jump takes off this close to its point (px).
const TAKE_OFF_RANGE := 3.0
## Runs while further than this from where it has to jump or climb (px).
const RUN_FROM := 48.0
## Seconds walking into something before it jumps.
const STUCK_TIME := 0.4
## Physics frames to wait for the arena's collision before scanning it.
const SETTLE_FRAMES := 3

@onready var fighter: Fighter = get_parent()

var _map: WalkMap
var _frames := 0
var _ready_in := REACTION
var _attack_in := 0.0
var _stuck := 0.0
## Direction on a ladder: -1 up, 1 down.
var _climb := -1.0
## Where the current jump or drop should land; NAN when it has no plan.
var _landing := NAN


func poll() -> void:
	_clear_intent()
	var delta := get_physics_process_delta_time()
	_frames += 1
	_attack_in = maxf(_attack_in - delta, 0.0)
	var arena := fighter.get_parent() as Arena
	if arena == null or _frames < SETTLE_FRAMES or fighter.is_dead():
		return
	if fighter.can_break_combo() and Arena.rng_of(self).randf() < BREAK_CHANCE:
		combo_break = true
		return
	var target := _nearest_enemy()
	if target == null or not fighter.can_act():
		return
	_map = WalkMap.of(arena)
	if fighter.is_climbing():
		aim = _climb
	elif not fighter.is_on_floor():
		_steer_in_air()
	elif not _fight(target, delta):
		_ready_in = REACTION
		_walk_to(target, delta)


func _clear_intent() -> void:
	move = 0.0
	run = false
	aim = 0.0
	jump = false
	attack = false
	attack_held = false
	combo_break = false
	select_slot = -1


func _nearest_enemy() -> Fighter:
	var best: Fighter
	var distance := INF
	for other: Fighter in get_tree().get_nodes_in_group(Fighter.GROUP):
		var away := fighter.global_position.distance_squared_to(other.global_position)
		if other != fighter and not other.is_dead() and away < distance:
			best = other
			distance = away
	return best


## Attacks if `target` can be hit from here. False when the bot has to move first.
func _fight(target: Fighter, delta: float) -> bool:
	var to_target := target.center() - fighter.center()
	var sees := _sees(target)
	if absf(to_target.x) <= PUNCH_REACH and absf(to_target.y) <= PUNCH_HEIGHT and sees:
		_punch(target, to_target, delta)
		return true
	var gun := fighter.inventory.firearm
	if gun == null or absf(to_target.x) < GUN_MIN_RANGE or to_target.length() > gun.data.projectile_range * GUN_RANGE or not sees:
		return false
	var angle := atan2(to_target.y, absf(to_target.x))
	# Up or down at a ladder would grab it instead of aiming.
	if absf(angle - fighter.aim_angle) > AIM_TOLERANCE and _at_ladder():
		return false
	_shoot(to_target, angle, delta)
	return true


func _punch(target: Fighter, to_target: Vector2, delta: float) -> void:
	if fighter.inventory.active_slot != Inventory.Slot.MELEE:
		select_slot = Inventory.Slot.MELEE
	elif _facing(to_target.x):
		_ready_in = maxf(_ready_in - delta, 0.0)
		if _ready_in == 0.0 and _attack_in == 0.0 and not target.is_invulnerable():
			attack = true
			_attack_in = _pause(PUNCH_PAUSE)


func _shoot(to_target: Vector2, angle: float, delta: float) -> void:
	if fighter.inventory.active_slot != Inventory.Slot.FIREARM:
		select_slot = Inventory.Slot.FIREARM
	elif _facing(to_target.x) and fighter.is_firearm_drawn():
		var off := angle - fighter.aim_angle
		if absf(off) > AIM_TOLERANCE:
			aim = signf(off)
			return
		_ready_in = maxf(_ready_in - delta, 0.0)
		if _ready_in == 0.0 and _attack_in == 0.0:
			attack = true
			attack_held = true
			_attack_in = _pause(SHOT_PAUSE)


## True once the bot faces along `x`; until then it turns (a one-frame step).
func _facing(x: float) -> bool:
	if x == 0.0 or signf(x) == fighter.facing:
		return true
	move = signf(x)
	return false


func _pause(range_seconds: Vector2) -> float:
	return Arena.rng_of(self).randf_range(range_seconds.x, range_seconds.y)


func _sees(target: Fighter) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(fighter.center(), target.center(), HitQuery.WORLD_LAYER)
	return fighter.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()


func _at_ladder() -> bool:
	for ladder: Ladder in get_tree().get_nodes_in_group(Ladder.GROUP):
		if ladder.reaches(fighter.global_position):
			return true
	return false


func _walk_to(target: Fighter, delta: float) -> void:
	_landing = NAN
	var feet := fighter.global_position
	var here := _map.surface_under(feet)
	var there := _map.surface_under(target.global_position)
	if here < 0:
		_head_for(_map.nearest_floor_x(feet), delta)
	elif here == there or there < 0:
		# The hit area starts past the body, so stop a little short of the target.
		var goal := target.global_position.x - signf(target.global_position.x - feet.x) * PUNCH_REACH / 2.0
		_head_for(_map.surfaces[here].inside(goal, WalkMap.LANDING_INSET), delta)
	else:
		_follow(_map.next_link(here, there, feet.x, fighter.fighter_class), here, target, delta)


## Walks to the link's take-off point and takes it. With no route, gets as close as it can.
func _follow(link: WalkMap.Link, here: int, target: Fighter, delta: float) -> void:
	if link == null:
		_head_for(_map.surfaces[here].inside(target.global_position.x, WalkMap.LANDING_INSET), delta)
		return
	var to_leave := link.leave_x - fighter.global_position.x
	if absf(to_leave) > TAKE_OFF_RANGE:
		_head_for(link.leave_x, delta)
		run = absf(to_leave) > RUN_FROM
		return
	match link.move:
		WalkMap.Move.JUMP, WalkMap.Move.DROP:
			move = signf(link.land_x - fighter.global_position.x)
			jump = link.move == WalkMap.Move.JUMP
			jump_held = jump
			_landing = link.land_x
		WalkMap.Move.LADDER_UP:
			_climb = -1.0
			aim = _climb
		WalkMap.Move.LADDER_DOWN:
			_climb = 1.0
			aim = _climb


## Steps towards `x`; walking into something for a moment makes it jump.
func _head_for(x: float, delta: float) -> void:
	var off := x - fighter.global_position.x
	if absf(off) <= TAKE_OFF_RANGE:
		_stuck = 0.0
		return
	move = signf(off)
	_stuck = _stuck + delta if absf(fighter.velocity.x) < 2.0 else 0.0
	if _stuck >= STUCK_TIME:
		jump = true
		_stuck = 0.0


## Holds the jump, steers to the planned landing, and away from pits with no plan.
func _steer_in_air() -> void:
	jump_held = true
	var feet := fighter.global_position
	var goal := _landing
	if is_nan(goal) or _map.surface_under(feet) < 0:
		goal = _map.nearest_floor_x(feet)
	if absf(goal - feet.x) > TAKE_OFF_RANGE:
		move = signf(goal - feet.x)
