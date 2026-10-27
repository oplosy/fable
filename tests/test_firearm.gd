# Run: godot --headless --path . -s res://tests/test_firearm.gd
extends "res://tests/test_case.gd"

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const FAST := preload("res://data/characters/placeholder.tres")
const PISTOL := preload("res://data/weapons/pistol.tres")

var arena: Node2D


func run() -> void:
	arena = load("res://scenes/arenas/test_arena.tscn").instantiate()
	arena.get_node("ItemSpawns/W1").interval = 9999.0
	root.add_child(arena)

	await _test_ammo()
	await _test_spread_and_bloom()
	await _test_crouch()


## Every shot uses ammo; the empty weapon drops by itself and cannot be picked up.
func _test_ammo() -> void:
	var shooter := _spawn(Vector2(100, 328))
	await physics_frames(5)
	shooter.equip_firearm(PISTOL)
	await physics_frames(2)
	check(shooter.firearm.ammo_left == PISTOL.ammo, "a new weapon is fully loaded")
	for i in PISTOL.ammo - 1:
		await _fire(shooter)
	check(shooter.firearm != null and shooter.firearm.ammo_left == 1, "each shot uses one bullet")
	await _fire(shooter)
	check(shooter.firearm == null and shooter.active_slot == Fighter.Slot.MELEE, "the last shot drops the empty weapon and leaves bare hands")
	await physics_frames(2)
	var dropped := get_nodes_in_group("dropped_items")
	check(dropped.size() == 1 and not dropped[0].pickable, "the empty weapon lies in the arena and cannot be picked up")
	shooter.queue_free()
	await physics_frames(5)


## Shots deviate within the spread; automatic fire widens it, and it narrows again.
func _test_spread_and_bloom() -> void:
	var gun: WeaponData = PISTOL.duplicate()
	gun.ammo = 1000
	gun.automatic = true
	gun.fire_interval = 0.05
	gun.spread_degrees = 3.0
	gun.spread_per_shot = 1.0
	gun.max_bloom_degrees = 6.0
	gun.bloom_recovery = 5.0
	var shooter := _spawn(Vector2(100, 328))
	await physics_frames(5)
	shooter.equip_firearm(gun)
	await physics_frames(2)

	var angles: Array[float] = []
	var count_shot := func(node: Node) -> void:
		if node is Projectile:
			angles.append(rad_to_deg(node.velocity.angle_to(Vector2.RIGHT * -1.0 if shooter.facing < 0 else Vector2.RIGHT)))
	arena.child_entered_tree.connect(count_shot)
	shooter.controller.attack_held = true
	await physics_frames(60)
	shooter.controller.attack_held = false
	arena.child_entered_tree.disconnect(count_shot)

	var widest := 0.0
	for angle in angles:
		widest = maxf(widest, absf(angle))
	check(angles.size() >= 15, "automatic fire keeps shooting while held")
	check(widest <= gun.spread_degrees + gun.max_bloom_degrees + 0.01, "no shot leaves the widest spread")
	check(widest > gun.spread_degrees, "holding the trigger widens the spread")
	check(angles.min() != angles.max(), "shots do not all fly the same line")
	check(shooter.firearm.bloom <= gun.max_bloom_degrees and shooter.firearm.bloom > gun.max_bloom_degrees - 1.0, "bloom grows up to its limit")
	await physics_frames(80)
	check(shooter.firearm.bloom == 0.0, "the spread narrows back after firing stops")

	var straight: WeaponData = gun.duplicate()
	straight.spread_degrees = 0.0
	straight.spread_per_shot = 0.0
	shooter.equip_firearm(straight)
	await physics_frames(2)
	angles.clear()
	arena.child_entered_tree.connect(count_shot)
	shooter.controller.attack_held = true
	await physics_frames(20)
	shooter.controller.attack_held = false
	arena.child_entered_tree.disconnect(count_shot)
	check(not angles.is_empty() and absf(angles.max()) < 0.001 and absf(angles.min()) < 0.001, "a zero-spread weapon fires dead straight")
	shooter.queue_free()
	# Let the last bullets reach the wall before the next fighter spawns in their path.
	await physics_frames(90)
	check(get_nodes_in_group("projectiles").is_empty(), "bullets stop at the wall")


## Crouching: slow walk, lower body, narrower spread, and level shots pass over.
func _test_crouch() -> void:
	var fighter := _spawn(Vector2(200, 328))
	await physics_frames(5)
	fighter.controller.crouch = true
	await physics_frames(2)
	check(fighter.is_crouching(), "crouch intent crouches")
	fighter.equip_firearm(PISTOL)
	await physics_frames(2)
	check(fighter.firearm.visible, "a crouching fighter standing still holds the firearm")
	fighter.controller.move = 1.0
	await physics_frames(30)
	check(is_equal_approx(fighter.velocity.x, fighter.fighter_class.crouch_speed), "crouched fighters walk slowly")
	check(not fighter.firearm.visible, "walking crouched puts the firearm away")
	fighter.controller.run = true
	await physics_frames(10)
	check(is_equal_approx(fighter.velocity.x, fighter.fighter_class.crouch_speed) and not fighter.is_running(), "crouching overrides running")
	fighter.controller.run = false
	fighter.controller.move = 0.0
	await physics_frames(20)

	# A standing shooter's level shot flies over the crouched fighter.
	var shooter := _spawn(Vector2(100, 328))
	await physics_frames(5)
	var straight: WeaponData = PISTOL.duplicate()
	straight.spread_degrees = 0.0
	shooter.equip_firearm(straight)
	await physics_frames(2)
	var health_before := fighter.health.current
	await _fire(shooter)
	await physics_frames(20)
	check(fighter.health.current == health_before, "level shots pass over a crouched fighter")
	fighter.controller.crouch = false
	await physics_frames(2)
	check(not fighter.is_crouching(), "releasing crouch stands up")
	await _fire(shooter)
	await physics_frames(20)
	check(fighter.health.current == health_before - straight.damage, "the same shot hits a standing fighter")

	# Crouched shots spread less, and a crouched shooter hits a crouched target.
	shooter.controller.crouch = true
	fighter.controller.crouch = true
	await physics_frames(2)
	check(is_equal_approx(shooter.firearm.spread(shooter.crouch_spread_scale), straight.spread_degrees * shooter.crouch_spread_scale), "crouching narrows the spread")
	await physics_frames(20)
	health_before = fighter.health.current
	await _fire(shooter)
	await physics_frames(20)
	check(fighter.health.current == health_before - straight.damage, "a crouched shooter hits a crouched fighter")

	# Jumping stands up.
	fighter.controller.jump = true
	await physics_frames(1)
	fighter.controller.jump = false
	await physics_frames(3)
	check(not fighter.is_crouching() and not fighter.is_on_floor(), "jumping from a crouch stands up and jumps")


func _fire(shooter: Fighter) -> void:
	shooter.controller.attack = true
	await physics_frames(1)
	shooter.controller.attack = false
	await physics_frames(int(shooter.firearm.data.fire_interval * 60) + 2 if shooter.firearm else 2)


func _spawn(at: Vector2) -> Fighter:
	var fighter: Fighter = FIGHTER_SCENE.instantiate()
	fighter.character = FAST
	arena.add_child(fighter)
	fighter.global_position = at
	return fighter
