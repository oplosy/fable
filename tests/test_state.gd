# Run: tests/run_all.sh test_state
extends "res://tests/test_case.gd"

## Fighter.state() names what the fighter is doing, and state_changed reports each change.

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const FAST := preload("res://data/characters/placeholder.tres")
const PISTOL := preload("res://data/weapons/pistol.tres")
const GRENADE := preload("res://data/throwables/grenade.tres")

var fighter: Fighter
var seen: Array[Fighter.State] = []


func run() -> void:
	var arena: Node2D = load("res://scenes/arenas/test_arena.tscn").instantiate()
	arena.get_node("ItemSpawns/W1").interval = 9999.0
	root.add_child(arena)
	fighter = FIGHTER_SCENE.instantiate()
	fighter.character = FAST
	arena.add_child(fighter)
	fighter.global_position = Vector2(300, 328)
	fighter.state_changed.connect(func(state: Fighter.State) -> void: seen.append(state))
	await physics_frames(10)
	# The idle controller exists only after the fighter's _ready.
	var c := fighter.controller
	check(fighter.state() == Fighter.State.IDLE, "standing still is IDLE")

	c.move = 1.0
	await physics_frames(5)
	check(fighter.state() == Fighter.State.WALK, "moving is WALK")
	c.run = true
	await physics_frames(5)
	check(fighter.state() == Fighter.State.RUN, "moving with the run intent is RUN")
	c.down = true
	await physics_frames(2)
	c.down = false
	check(fighter.state() == Fighter.State.ROLL, "down while running is ROLL")
	c.move = 0.0
	c.run = false
	await physics_frames(40)

	c.crouch = true
	await physics_frames(3)
	check(fighter.state() == Fighter.State.CROUCH, "crouching is CROUCH")
	c.crouch = false
	await _press("jump")
	await physics_frames(3)
	check(fighter.state() == Fighter.State.AIR, "a jump is AIR")
	await physics_frames(60)

	await _press("attack")
	check(fighter.state() == Fighter.State.ATTACK, "a punch is ATTACK")
	await physics_frames(60)
	fighter.take_hit(1, Vector2.ZERO, 0.3)
	await physics_frames(1)
	check(fighter.state() == Fighter.State.STUN, "a hit is STUN")
	await physics_frames(30)

	fighter.inventory.equip_firearm(PISTOL)
	await physics_frames(2)
	check(fighter.state() == Fighter.State.AIM, "standing with a firearm is AIM")
	fighter.inventory.equip_throwable(GRENADE, 1)
	fighter.inventory.select_slot(Inventory.Slot.THROWABLE)
	c.attack_held = true
	await _press("attack")
	check(fighter.state() == Fighter.State.COOK, "a pulled pin is COOK")
	c.attack_held = false
	await physics_frames(5)

	fighter.take_hit(1, Vector2.ZERO, -1.0, true)
	await physics_frames(2)
	check(fighter.state() == Fighter.State.DOWN, "a knockdown is DOWN")
	await physics_frames(int(fighter.fighter_class.knockdown_time * 60) + 30)
	fighter.take_hit(1000)
	await physics_frames(1)
	check(fighter.state() == Fighter.State.DEAD, "zero health is DEAD")

	var expected: Array[Fighter.State] = [Fighter.State.WALK, Fighter.State.RUN, Fighter.State.ROLL, Fighter.State.CROUCH, Fighter.State.AIR, Fighter.State.ATTACK, Fighter.State.STUN, Fighter.State.AIM, Fighter.State.COOK, Fighter.State.DOWN, Fighter.State.DEAD]
	var order_kept := true
	var at := 0
	for state in expected:
		at = seen.find(state, at)
		if at < 0:
			order_kept = false
			break
	check(order_kept, "state_changed reported every state in order (%s)" % [seen])


func _press(intent: String) -> void:
	fighter.controller.set(intent, true)
	await physics_frames(2)
	fighter.controller.set(intent, false)
