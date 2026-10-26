# Run: godot --headless --path . -s res://tests/test_combat.gd
extends "res://tests/test_case.gd"

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const PISTOL := preload("res://data/weapons/pistol.tres")

var arena: Node2D


func run() -> void:
	arena = load("res://scenes/arenas/test_arena.tscn").instantiate()
	root.add_child(arena)
	# Fighters without a controller of their own get the idle base controller,
	# whose intent fields the test sets directly.
	var shooter := _spawn(Vector2(200, 328))
	var target := _spawn(Vector2(300, 328))
	await physics_frames(10)
	shooter.equip_firearm(PISTOL)
	await physics_frames(2)

	await _fire(shooter)
	await physics_frames(15)
	check(target.health.current == target.health.max_health - PISTOL.damage, "bullet damages the target")
	check(shooter.health.current == shooter.health.max_health, "shooter is not hurt by its own shot")
	check(get_nodes_in_group("projectiles").is_empty(), "bullet is used up on hit")

	shooter.controller.aim = 1.0
	await physics_frames(120)
	shooter.controller.aim = 0.0
	await _fire(shooter)
	await physics_frames(10)
	check(shooter.health.current == shooter.health.max_health, "shooting straight down never hits the shooter")


func _spawn(at: Vector2) -> Fighter:
	var fighter: Fighter = FIGHTER_SCENE.instantiate()
	arena.add_child(fighter)
	fighter.global_position = at
	return fighter


func _fire(fighter: Fighter) -> void:
	fighter.controller.attack = true
	await physics_frames(1)
	fighter.controller.attack = false
