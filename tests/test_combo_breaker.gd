# Run: godot --headless --path . -s res://tests/test_combo_breaker.gd
extends "res://tests/test_case.gd"

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const FAST := preload("res://data/characters/placeholder.tres")
const HEAVY := preload("res://data/characters/dummy.tres")

var arena: Node2D


func run() -> void:
	arena = load("res://scenes/arenas/test_arena.tscn").instantiate()
	root.add_child(arena)
	var attacker := _spawn(FAST, Vector2(200, 328))
	var victim := _spawn(HEAVY, Vector2(214, 328))
	await physics_frames(10)
	# Short cooldown so the test does not wait 10 s.
	var victim_class: FighterClass = HEAVY.fighter_class.duplicate()
	victim_class.combo_breaker_cooldown = 1.0
	victim.fighter_class = victim_class

	check(not victim.can_break_combo(), "nothing to break without a hit")
	await _jab(attacker)
	check(victim.is_stunned() and victim.can_break_combo(), "a melee stun can be broken")
	var attacker_x := attacker.position.x
	await _tap(victim, "combo_break")
	check(not victim.is_stunned() and victim.can_act(), "the breaker frees the victim")
	check(victim.is_on_floor() and not victim.melee.is_attacking(), "the break uses up the attack and jump presses")
	check(attacker.is_stunned() and not attacker.melee.is_attacking(), "the attacker is stunned and its combo is cancelled")
	check(attacker.health.current == attacker.health.max_health, "the push deals no damage")
	await physics_frames(10)
	check(attacker.position.x < attacker_x - 3.0, "the attacker is pushed back")
	check(victim.is_breaker_cooling_down(), "the breaker goes on cooldown")

	_reset(attacker, 200)
	_reset(victim, 214)
	await physics_frames(20)
	await _jab(attacker)
	check(victim.is_stunned() and not victim.can_break_combo(), "no breaking during the cooldown")
	await _tap(victim, "combo_break")
	check(victim.is_stunned(), "a breaker on cooldown does nothing")

	await physics_frames(int(victim_class.combo_breaker_cooldown * 60) + 2)
	victim.take_hit(5)
	check(victim.is_stunned() and not victim.can_break_combo(), "a projectile stun cannot be broken")
	await physics_frames(30)
	_reset(attacker, 200)
	_reset(victim, 214)
	await physics_frames(5)
	await _jab(attacker)
	check(victim.can_break_combo(), "the breaker is ready again after the cooldown")

	await _test_local_controller()


## Pressing attack and jump together, in either order, is the breaker.
func _test_local_controller() -> void:
	var local := LocalController.new()
	_spawn(FAST, Vector2(400, 328), local)
	await physics_frames(5)

	Input.action_press("p1_attack")
	check(await _seen(local), "attack and jump on the same frame breaks")
	Input.action_release("p1_attack")
	Input.action_release("p1_jump")
	await physics_frames(2)

	Input.action_press("p1_jump")
	await physics_frames(3)
	Input.action_press("p1_attack")
	check(await _seen(local), "attack while holding jump breaks")
	Input.action_release("p1_attack")
	Input.action_release("p1_jump")
	await physics_frames(2)

	Input.action_press("p1_attack")
	await physics_frames(3)
	Input.action_press("p1_jump")
	check(await _seen(local), "jump while holding attack breaks")
	Input.action_release("p1_attack")
	Input.action_release("p1_jump")
	await physics_frames(30)

	Input.action_press("p1_jump")
	check(not await _seen(local), "jump alone does not break")
	Input.action_release("p1_jump")


## Presses jump (and keeps what is held), then reports whether combo_break fired in the next frames.
func _seen(controller: FighterController) -> bool:
	Input.action_press("p1_jump")
	for i in 3:
		await physics_frame
		if controller.combo_break:
			return true
	return false


func _jab(attacker: Fighter) -> void:
	await _tap(attacker, "attack")
	await physics_frames(8)


func _tap(fighter: Fighter, intent: String) -> void:
	fighter.controller.set(intent, true)
	await physics_frames(1)
	fighter.controller.set(intent, false)


func _spawn(data: CharacterData, at: Vector2, controller: FighterController = null) -> Fighter:
	var fighter: Fighter = FIGHTER_SCENE.instantiate()
	fighter.character = data
	fighter.controller = controller
	arena.add_child(fighter)
	fighter.global_position = at
	return fighter


func _reset(fighter: Fighter, x: float) -> void:
	fighter.global_position = Vector2(x, 328)
	fighter.velocity = Vector2.ZERO
