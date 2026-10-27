# Run: tests/run_all.sh test_bounds
extends "res://tests/test_case.gd"

## Leaving the arena's bounds: fighters die, items and thrown objects are removed,
## and a lost spawned item frees its spawn point.

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const FAST := preload("res://data/characters/placeholder.tres")
const PISTOL := preload("res://data/weapons/pistol.tres")
const GRENADE := preload("res://data/throwables/grenade.tres")
const THROWN := preload("res://scenes/throwables/thrown_item.tscn")


func run() -> void:
	var arena: Arena = load("res://scenes/arenas/test_arena.tscn").instantiate()
	var spawner: WeaponSpawner = arena.get_node("WeaponSpawns/W1")
	spawner.weapons = [PISTOL]
	spawner.interval = 0.1
	root.add_child(arena)

	var fighter: Fighter = FIGHTER_SCENE.instantiate()
	fighter.character = FAST
	arena.add_child(fighter)
	fighter.global_position = Vector2(300, 328)
	var thrown: ThrownItem = THROWN.instantiate()
	thrown.data = GRENADE
	thrown.fuse_left = 99.0
	arena.add_child(thrown)
	thrown.global_position = Vector2(200, 200)
	await physics_frames(20)
	check(not fighter.is_dead() and is_instance_valid(thrown) and spawner.has_weapon(), "everything inside the bounds stays")

	spawner.interval = 9999.0
	var first_item := spawner.get_child(0)
	fighter.global_position.y = arena.bounds.end.y + 50.0
	thrown.global_position.y = arena.bounds.end.y + 50.0
	first_item.global_position.x = arena.bounds.position.x - 50.0
	await physics_frames(3)
	check(fighter.is_dead() and not fighter.visible, "a fighter below the map dies and disappears")
	check(not is_instance_valid(thrown), "a thrown item below the map is removed without going off")
	check(not is_instance_valid(first_item) and not spawner.has_weapon(), "a lost spawned item frees its spawn point")
	check(arena.get_children().all(func(node: Node) -> bool: return not node is Explosion), "nothing went off")
