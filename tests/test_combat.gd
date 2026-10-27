# Run: godot --headless --path . -s res://tests/test_combat.gd
extends "res://tests/test_case.gd"

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const PISTOL := preload("res://data/weapons/pistol.tres")
const SMG := preload("res://data/weapons/smg.tres")
const FAST := preload("res://data/characters/placeholder.tres")

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

	# Knockback replaces speed instead of adding up, even in the air.
	target.velocity = Vector2.ZERO
	target.controller.move = 0.0
	target.controller.jump = true
	await physics_frames(1)
	target.controller.jump = false
	await physics_frames(5)
	for i in 8:
		target.take_hit(0, Vector2(100, 0))
	check(not target.is_on_floor() and is_equal_approx(target.velocity.x, 100.0), "repeated knockback does not stack")
	await physics_frames(60)
	target.controller.move = -1.0
	await physics_frames(20)

	target.equip_firearm(PISTOL)
	target.take_hit(1000)
	await physics_frames(20)
	check(target.is_dead() and target.health.current == 0, "lethal hit kills the target")
	check(target.firearm == null, "a dying fighter drops its firearm")
	var dropped := get_nodes_in_group("dropped_items")
	check(dropped.size() == 1 and not dropped[0].pickable, "the dead fighter's firearm lies in the arena and cannot be picked up")
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
	shooter.queue_free()
	target.queue_free()
	await physics_frames(30)

	await _test_stun_rules()
	await _test_smg_stun()


## A shorter or zero stun never cuts a longer one short; zero-stun hits do not interrupt.
func _test_stun_rules() -> void:
	var attacker := _spawn(Vector2(200, 328), FAST)
	var target := _spawn(Vector2(220, 328))
	await physics_frames(10)
	target.take_hit(0, Vector2.ZERO, 0.4, false, attacker)
	target.take_hit(4, Vector2.ZERO, 0.0)
	check(target.is_stunned() and target.can_break_combo(), "a zero-stun hit (fire) keeps a melee stun and its breaker")
	target.take_hit(5, Vector2.ZERO, 0.25)
	await physics_frames(18)
	check(target.is_stunned() and target.can_break_combo(), "a shorter bullet stun keeps the longer melee stun and its breaker")
	await physics_frames(10)
	target.take_hit(0, Vector2.ZERO, 0.3)
	check(target.is_stunned() and not target.can_break_combo(), "a longer bullet stun takes over")
	await physics_frames(30)

	attacker.controller.attack = true
	await physics_frames(2)
	attacker.controller.attack = false
	attacker.take_hit(4, Vector2.ZERO, 0.0)
	check(attacker.melee.is_attacking(), "a zero-stun hit does not cancel the victim's attack")
	attacker.take_hit(4, Vector2.ZERO, 0.1)
	check(not attacker.melee.is_attacking(), "a stunning hit cancels the attack")
	attacker.queue_free()
	target.queue_free()
	await physics_frames(5)


## Automatic fire must leave the target moments to act, so it can escape.
func _test_smg_stun() -> void:
	var shooter := _spawn(Vector2(200, 328))
	var target := _spawn(Vector2(260, 328))
	await physics_frames(10)
	shooter.equip_firearm(SMG)
	await physics_frames(2)
	shooter.controller.attack_held = true
	await physics_frames(30)
	var free_frames := 0
	for i in 30:
		await physics_frames(1)
		if not target.is_stunned():
			free_frames += 1
	shooter.controller.attack_held = false
	check(target.health.current < target.health.max_health, "the SMG hits the target")
	check(free_frames >= 12, "SMG fire leaves the target free to act between hits (%d of 30 frames)" % free_frames)
	shooter.queue_free()
	target.queue_free()


func _spawn(at: Vector2, character: CharacterData = null) -> Fighter:
	var fighter: Fighter = FIGHTER_SCENE.instantiate()
	fighter.character = character
	arena.add_child(fighter)
	fighter.global_position = at
	return fighter


func _fire(fighter: Fighter) -> void:
	fighter.controller.attack = true
	await physics_frames(1)
	fighter.controller.attack = false
