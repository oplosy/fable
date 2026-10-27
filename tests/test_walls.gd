# Run: tests/run_all.sh test_walls
extends "res://tests/test_case.gd"

## No hit lands through a wall: melee, blasts, fire and shots from a muzzle poking past one.

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const FAST := preload("res://data/characters/placeholder.tres")
const PISTOL := preload("res://data/weapons/pistol.tres")
const EXPLOSION := preload("res://scenes/throwables/explosion.tscn")
const FIRE := preload("res://scenes/throwables/fire_area.tscn")

var arena: Node2D


func run() -> void:
	arena = load("res://scenes/arenas/test_arena.tscn").instantiate()
	arena.get_node("ItemSpawns/W1").interval = 9999.0
	root.add_child(arena)
	_add_wall(Vector2(106, 278), Vector2(4, 100))

	var near := _spawn(Vector2(98, 328))
	var behind := _spawn(Vector2(118, 328))
	await physics_frames(10)

	near.controller.attack = true
	await physics_frames(2)
	near.controller.attack = false
	await physics_frames(20)
	check(behind.health.current == behind.health.max_health, "a punch does not reach through a thin wall")

	near.inventory.equip_firearm(PISTOL)
	await physics_frames(2)
	near.controller.attack = true
	await physics_frames(2)
	near.controller.attack = false
	await physics_frames(10)
	check(behind.health.current == behind.health.max_health, "a muzzle poking past a thin wall does not shoot through it")
	check(get_nodes_in_group("projectiles").is_empty(), "the shot stops at the wall")

	var same_side := _spawn(Vector2(70, 328))
	await physics_frames(5)
	var blast: Explosion = EXPLOSION.instantiate()
	arena.add_child(blast)
	blast.global_position = Vector2(95, 318)
	await physics_frames(3)
	check(same_side.health.current < same_side.health.max_health, "the blast hurts fighters on its side of the wall")
	check(behind.health.current == behind.health.max_health, "the blast does not reach through the wall")
	await physics_frames(int(same_side.fighter_class.knockdown_time * 60) + 40)

	var fire: FireArea = FIRE.instantiate()
	fire.position = Vector2(100, 300)
	arena.add_child(fire)
	await physics_frames(int(fire.tick * 60) * 2 + 2)
	check(behind.health.current == behind.health.max_health, "fire does not burn through the wall")


func _add_wall(at: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = size
	wall.add_child(shape)
	wall.position = at
	arena.add_child(wall)


func _spawn(at: Vector2) -> Fighter:
	var fighter: Fighter = FIGHTER_SCENE.instantiate()
	fighter.character = FAST
	arena.add_child(fighter)
	fighter.global_position = at
	return fighter
