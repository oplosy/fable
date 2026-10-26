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

	var target_x := target.global_position.x
	await _fire(shooter)
	await physics_frames(15)
	check(target.health.current == target.health.max_health - PISTOL.damage, "bullet damages the target")
	check(target.global_position.x > target_x, "bullet knocks the target away from the shooter")
	check(shooter.health.current == shooter.health.max_health, "shooter is not hurt by its own shot")
	check(get_nodes_in_group("projectiles").is_empty(), "bullet is used up on hit")

	shooter.controller.aim = 1.0
	await physics_frames(120)
	shooter.controller.aim = 0.0
	await _fire(shooter)
	await physics_frames(10)
	check(shooter.health.current == shooter.health.max_health, "shooting straight down never hits the shooter")

	target.controller.move = -1.0
	await physics_frames(20)
	check(target.velocity.x < 0.0, "target walks left before the hit")
	target.take_hit(5, Vector2(200, 0))
	await physics_frames(2)
	check(target.is_stunned(), "hit stuns the target")
	check(target.velocity.x > 0.0, "stunned target is pushed by knockback and ignores its move intent")
	check(target.get_node("Visuals").modulate.r > 1.0, "hit flashes the target")
	await physics_frames(20)
	check(not target.is_stunned(), "stun wears off")
	check(target.velocity.x < 0.0, "target walks again after the stun")
	check(target.get_node("Visuals").modulate == Color.WHITE, "flash fades back")

	target.take_hit(1000)
	await physics_frames(20)
	check(target.is_dead() and target.health.current == 0, "lethal hit kills the target")
	check(target.collision_layer == 0, "dead body leaves the fighters layer")
	check(is_equal_approx(absf(target.get_node("Visuals").rotation), PI / 2.0), "dead body lies down")
	check(is_zero_approx(target.velocity.x), "dead body ignores its move intent")

	target.controller.move = 0.0
	shooter.aim_angle = 0.0
	shooter.global_position.x = target.global_position.x - 60.0
	await physics_frames(2)
	await _fire(shooter)
	await physics_frames(12)
	var bullets := get_nodes_in_group("projectiles")
	check(bullets.size() == 1 and bullets[0].global_position.x > target.global_position.x + 10.0, "bullets pass through the dead body")


func _spawn(at: Vector2) -> Fighter:
	var fighter: Fighter = FIGHTER_SCENE.instantiate()
	arena.add_child(fighter)
	fighter.global_position = at
	return fighter


func _fire(fighter: Fighter) -> void:
	fighter.controller.attack = true
	await physics_frames(1)
	fighter.controller.attack = false
