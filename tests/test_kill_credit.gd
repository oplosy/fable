# Run: tests/run_all.sh test_kill_credit
extends "res://tests/test_case.gd"

## Fighter.died names the killer for every way to die: melee, bullets, blasts, fire,
## falls soon after a hit, self-kills; nobody once the credit has run out.

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const FAST := preload("res://data/characters/placeholder.tres")
const PISTOL := preload("res://data/weapons/pistol.tres")
const GRENADE := preload("res://data/throwables/grenade.tres")
const THROWN := preload("res://scenes/throwables/thrown_item.tscn")
const FIRE := preload("res://scenes/throwables/fire_area.tscn")

var arena: Node2D
## Each dead fighter -> its killer (null when nobody was credited).
var killers := {}


func run() -> void:
	arena = load("res://scenes/arenas/test_arena.tscn").instantiate()
	arena.get_node("ItemSpawns/W1").interval = 9999.0
	root.add_child(arena)

	var attacker := _spawn(Vector2(100, 328))
	var victim := _spawn(Vector2(118, 328), -1)
	await physics_frames(10)
	victim.health.current = 1
	attacker.controller.attack = true
	await physics_frames(2)
	attacker.controller.attack = false
	await physics_frames(20)
	_check_killer(victim, attacker, "a punch credits the puncher")

	victim = _spawn(Vector2(200, 328), -1)
	await physics_frames(10)
	victim.health.current = 1
	attacker.inventory.equip_firearm(PISTOL)
	await physics_frames(2)
	attacker.controller.attack = true
	await physics_frames(2)
	attacker.controller.attack = false
	await physics_frames(20)
	_check_killer(victim, attacker, "a bullet credits the shooter")
	attacker.inventory.select_slot(Inventory.Slot.MELEE)

	victim = _spawn(Vector2(400, 328))
	await physics_frames(10)
	victim.health.current = 1
	var thrown: ThrownItem = THROWN.instantiate()
	thrown.data = GRENADE
	thrown.thrower = attacker
	thrown.position = Vector2(400, 320)
	arena.add_child(thrown)
	thrown.go_off()
	await physics_frames(5)
	_check_killer(victim, attacker, "a grenade blast credits the thrower")

	victim = _spawn(Vector2(500, 328))
	await physics_frames(10)
	victim.health.current = 1
	var fire: FireArea = FIRE.instantiate()
	fire.attacker = attacker
	fire.position = Vector2(500, 300)
	arena.add_child(fire)
	await physics_frames(5)
	_check_killer(victim, attacker, "fire credits the thrower")
	fire.queue_free()

	victim = _spawn(Vector2(300, 328))
	await physics_frames(10)
	victim.take_hit(0, Vector2.ZERO, 0.0, false, attacker)
	await physics_frames(60)
	victim.fall_out()
	_check_killer(victim, attacker, "falling out soon after a hit credits the hitter")

	victim = _spawn(Vector2(300, 328))
	await physics_frames(10)
	victim.take_hit(0, Vector2.ZERO, 0.0, false, attacker)
	await physics_frames(int(Fighter.KILL_CREDIT_TIME * 60) + 10)
	victim.fall_out()
	_check_killer(victim, null, "a fall long after the last hit credits nobody")

	victim = _spawn(Vector2(300, 328))
	await physics_frames(10)
	victim.take_hit(1000, Vector2.ZERO, -1.0, false, victim)
	_check_killer(victim, victim, "a self-kill credits the fighter itself")

	victim = _spawn(Vector2(300, 328))
	await physics_frames(10)
	victim.take_hit(0, Vector2.ZERO, 0.5, false, attacker)
	check(victim.is_stunned() and not victim.can_break_combo(), "only a melee stun can be broken")


func _check_killer(victim: Fighter, killer: Fighter, label: String) -> void:
	check(killers.has(victim) and killers[victim] == killer, "%s (dead %s)" % [label, killers.has(victim)])


func _spawn(at: Vector2, facing := 1) -> Fighter:
	var fighter: Fighter = FIGHTER_SCENE.instantiate()
	fighter.character = FAST
	arena.add_child(fighter)
	fighter.global_position = at
	fighter.facing = facing
	fighter.died.connect(func(killer: Fighter) -> void: killers[fighter] = killer)
	return fighter
