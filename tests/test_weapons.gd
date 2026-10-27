# Run: godot --headless --path . -s res://tests/test_weapons.gd
extends "res://tests/test_case.gd"

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const FAST := preload("res://data/characters/placeholder.tres")
const PISTOL := preload("res://data/weapons/pistol.tres")
const SHOTGUN := preload("res://data/weapons/shotgun.tres")
const SMG := preload("res://data/weapons/smg.tres")
const SNIPER := preload("res://data/weapons/sniper.tres")

var arena: Node2D


func run() -> void:
	arena = load("res://scenes/arenas/test_arena.tscn").instantiate()
	arena.get_node("ItemSpawns/W1").interval = 9999.0
	root.add_child(arena)

	_test_data()
	await _test_shotgun()
	await _test_sniper()
	_test_weighted_spawn()


## Sniper bullets fly fastest and straightest; the SMG is the slow, wide one.
func _test_data() -> void:
	check(SNIPER.projectile_speed > PISTOL.projectile_speed and PISTOL.projectile_speed > SMG.projectile_speed, "sniper bullets are fastest, SMG bullets slowest")
	check(SNIPER.spread_degrees < PISTOL.spread_degrees and PISTOL.spread_degrees < SMG.spread_degrees, "sniper is most accurate, SMG least")
	check(SMG.automatic and SMG.max_bloom_degrees > 0.0, "the SMG fires automatically and blooms")


## Point-blank blasts land every pellet and knock down; pellets die at their range.
func _test_shotgun() -> void:
	var shooter := _spawn(Vector2(100, 328))
	var target := _spawn(Vector2(115, 328))
	await physics_frames(5)
	shooter.equip_firearm(SHOTGUN)
	await physics_frames(2)
	var before := target.health.current
	var shots := get_nodes_in_group("projectiles").size()
	await _fire(shooter)
	check(shooter.firearm.ammo_left == SHOTGUN.ammo - 1, "one blast uses one shell")
	check(target.health.current == before - SHOTGUN.damage * SHOTGUN.pellets, "every pellet of a point-blank blast lands")
	check(target.is_knocked_down(), "a point-blank blast knocks down")
	check(get_nodes_in_group("projectiles").size() == shots, "pellets are used up by the hit")
	target.queue_free()

	var far := _spawn(Vector2(100 + SHOTGUN.projectile_range + 60, 328))
	await physics_frames(int(SHOTGUN.fire_interval * 60) + 2)
	before = far.health.current
	shooter.controller.attack = true
	await physics_frames(1)
	shooter.controller.attack = false
	await physics_frames(1)
	check(get_nodes_in_group("projectiles").size() == SHOTGUN.pellets, "a blast fires every pellet")
	await physics_frames(60)
	check(far.health.current == before, "pellets never reach past their range")
	check(get_nodes_in_group("projectiles").is_empty(), "pellets disappear at their range")
	check(not far.is_knocked_down(), "far targets are not knocked down")
	shooter.queue_free()
	far.queue_free()
	await physics_frames(5)


## The fast sniper bullet never skips a fighter and passes through `pierce` of them.
func _test_sniper() -> void:
	var shooter := _spawn(Vector2(60, 328))
	var targets: Array[Fighter] = []
	for i in SNIPER.pierce + 2:
		targets.append(_spawn(Vector2(200 + i * 60, 328)))
	await physics_frames(5)
	shooter.equip_firearm(SNIPER)
	await physics_frames(2)
	await _fire(shooter)
	await physics_frames(20)
	var hit := targets.filter(func(t: Fighter) -> bool: return t.health.current < t.health.max_health).size()
	check(hit == SNIPER.pierce + 1, "a sniper bullet passes through %d fighters and stops in the next" % SNIPER.pierce)
	check(targets[-1].health.current == targets[-1].health.max_health, "the fighter behind the last pierced one is safe")
	for fighter in targets:
		fighter.queue_free()
	shooter.queue_free()
	await physics_frames(5)


func _test_weighted_spawn() -> void:
	var spawner := ItemSpawner.new()
	var never: WeaponData = PISTOL.duplicate()
	never.spawn_weight = 0.0
	spawner.items = [never, SMG]
	var picks := {}
	for i in 50:
		picks[spawner._pick_weighted()] = true
	check(picks.keys() == [SMG], "a weapon with no spawn weight never spawns")
	spawner.free()


func _fire(shooter: Fighter) -> void:
	shooter.controller.attack = true
	await physics_frames(1)
	shooter.controller.attack = false
	await physics_frames(3)


func _spawn(at: Vector2) -> Fighter:
	var fighter: Fighter = FIGHTER_SCENE.instantiate()
	fighter.character = FAST
	arena.add_child(fighter)
	fighter.global_position = at
	return fighter
