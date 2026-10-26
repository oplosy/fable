# Run: godot --headless --path . -s res://tests/test_knockdown.gd
extends "res://tests/test_case.gd"

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const FAST := preload("res://data/characters/placeholder.tres")
const HEAVY := preload("res://data/characters/dummy.tres")

var arena: Node2D


func run() -> void:
	arena = load("res://scenes/arenas/test_arena.tscn").instantiate()
	root.add_child(arena)
	var fast := _spawn(FAST, Vector2(200, 328))
	var heavy := _spawn(HEAVY, Vector2(214, 328))
	await physics_frames(10)
	var heavy_class: FighterClass = HEAVY.fighter_class

	# Single punches only stun.
	await _press_attack(fast)
	await physics_frames(10)
	check(heavy.is_stunned() and not heavy.is_knocked_down(), "a single jab stuns but does not knock down")
	await physics_frames(40)

	# The combo finisher knocks down.
	_reset(heavy, 214)
	await physics_frames(5)
	for i in 30:
		await _press_attack(fast)
		if heavy.is_knocked_down():
			break
		await physics_frames(2)
	check(heavy.is_knocked_down(), "combo finisher knocks the target down")
	check(not heavy.can_act() and heavy.is_invulnerable(), "downed fighter cannot act and is invulnerable")
	check(heavy.collision_layer == 0, "downed fighter leaves the fighters layer")
	check(is_equal_approx(absf(heavy.get_node("Visuals").rotation), PI / 2.0), "downed fighter lies on the ground")

	var health_when_down := heavy.health.current
	heavy.take_hit(10)
	check(heavy.health.current == health_when_down, "downed fighter cannot be hit")

	# Gets up after knockdown_time, then is briefly invulnerable.
	await physics_frames(int(heavy_class.knockdown_time * 60) + 2)
	check(not heavy.is_knocked_down() and heavy.can_act(), "fighter gets up after the knockdown time")
	check(heavy.get_node("Visuals").rotation == 0.0, "fighter stands up again")
	check(heavy.is_invulnerable() and heavy.collision_layer == 0, "fighter is invulnerable while getting up")
	heavy.take_hit(10)
	check(heavy.health.current == health_when_down, "hits during get-up invulnerability are ignored")
	await physics_frames(int(heavy_class.getup_invulnerability * 60) + 2)
	check(not heavy.is_invulnerable() and heavy.collision_layer == Fighter.FIGHTERS_LAYER, "invulnerability wears off")
	heavy.take_hit(10)
	check(heavy.health.current == health_when_down - 10, "fighter can be hit again")

	# Classes may allow hits on the ground, but never a second knockdown.
	var soft_class := heavy_class.duplicate()
	soft_class.downed_invulnerable = false
	heavy.fighter_class = soft_class
	await physics_frames(20)
	heavy.take_hit(5, Vector2.ZERO, -1.0, true)
	await physics_frames(10)
	var down_time_left: float = heavy._down_time
	heavy.take_hit(5, Vector2.ZERO, -1.0, true)
	check(down_time_left < soft_class.knockdown_time - 0.1, "knockdown timer is running")
	check(heavy.is_knocked_down() and heavy.health.current == health_when_down - 20, "class setting allows hits on the ground")
	check(is_equal_approx(heavy._down_time, down_time_left), "a downed fighter is not knocked down again")

	# Death while down still kills.
	heavy.take_hit(1000)
	check(heavy.is_dead(), "a lethal hit on the ground kills")


func _spawn(data: CharacterData, at: Vector2) -> Fighter:
	var fighter: Fighter = FIGHTER_SCENE.instantiate()
	fighter.character = data
	arena.add_child(fighter)
	fighter.global_position = at
	return fighter


func _reset(fighter: Fighter, x: float) -> void:
	fighter.global_position = Vector2(x, 328)
	fighter.velocity = Vector2.ZERO


func _press_attack(fighter: Fighter) -> void:
	fighter.controller.attack = true
	await physics_frames(1)
	fighter.controller.attack = false
