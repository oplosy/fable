# Run: godot --headless --path . -s res://tests/test_pickup.gd
extends "res://tests/test_case.gd"

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const FAST := preload("res://data/characters/placeholder.tres")
const PISTOL := preload("res://data/weapons/pistol.tres")

var arena: Node2D
var spawner: ItemSpawner


func run() -> void:
	arena = load("res://scenes/arenas/test_arena.tscn").instantiate()
	spawner = arena.get_node("ItemSpawns/W1")
	spawner.interval = 0.5
	# Only the pistol, so the test knows what spawns.
	spawner.items = [PISTOL]
	root.add_child(arena)

	await physics_frames(20)
	check(get_nodes_in_group("item_pickups").is_empty(), "nothing spawns before the interval")
	await physics_frames(20)
	var pickups := get_nodes_in_group("item_pickups")
	check(pickups.size() == 1 and spawner.has_item(), "an empty spawn point spawns a weapon")
	await physics_frames(60)
	check(get_nodes_in_group("item_pickups").size() == 1, "a full spawn point spawns nothing more")
	if pickups.size() == 1:
		check(absf(pickups[0].global_position.y - 325.0) < 4.0, "the spawned weapon rests on the floor")

	# Empty slot: walking over the weapon takes it.
	var fighter := _spawn(Vector2(100, 328))
	await physics_frames(5)
	check(fighter.inventory.firearm == null, "fighter starts unarmed")
	fighter.controller.move = -1.0
	await physics_frames(70)
	fighter.controller.move = 0.0
	check(fighter.inventory.firearm != null and fighter.inventory.firearm.data == PISTOL, "walking over a spawned weapon picks it up")
	check(fighter.inventory.active_slot == Inventory.Slot.FIREARM, "the picked-up firearm is selected")
	await physics_frames(1)
	check(get_nodes_in_group("item_pickups").is_empty() and not spawner.has_item(), "the picked-up weapon leaves the arena")

	# Full slot: standing on a weapon does not take it; down swaps.
	var old_data: WeaponData = PISTOL.duplicate()
	fighter.inventory.equip_firearm(old_data)
	fighter.global_position = Vector2(40, 328)
	fighter.velocity = Vector2.ZERO
	await physics_frames(40)
	check(spawner.has_item() and fighter.inventory.firearm.data == old_data, "a full slot does not pick up by walking over")
	fighter.controller.move = 1.0
	fighter.controller.run = true
	await physics_frames(2)
	fighter.global_position.x = 40
	await _tap(fighter, "down")
	check(fighter.is_rolling() and fighter.inventory.firearm.data == old_data, "down while running rolls instead of swapping")
	fighter.controller.move = 0.0
	fighter.controller.run = false
	await physics_frames(40)
	fighter.global_position = Vector2(40, 328)
	fighter.velocity = Vector2.ZERO
	await physics_frames(5)
	await _tap(fighter, "down")
	check(fighter.inventory.firearm != null and fighter.inventory.firearm.data == PISTOL, "down on a spawned weapon swaps it in")
	await physics_frames(2)
	var dropped := get_nodes_in_group("dropped_items")
	check(dropped.size() == 1 and dropped[0].data == old_data and not dropped[0].pickable, "the old firearm drops and cannot be picked up")

	# Dropped weapons are never taken, and disappear after their lifetime.
	# No new spawn, so the only weapon near the spawn point is the dropped one.
	spawner.interval = 1000.0
	var unarmed := _spawn(Vector2(40, 328))
	await physics_frames(5)
	if dropped.size() == 1:
		unarmed.global_position = dropped[0].global_position + Vector2(0, 2)
	await physics_frames(10)
	check(unarmed.inventory.firearm == null, "walking over a dropped weapon does not pick it up")
	await physics_frames(5 * 60)
	check(get_nodes_in_group("dropped_items").is_empty(), "dropped weapons disappear after a few seconds")


func _tap(fighter: Fighter, intent: String) -> void:
	fighter.controller.set(intent, true)
	await physics_frames(1)
	fighter.controller.set(intent, false)


func _spawn(at: Vector2) -> Fighter:
	var fighter: Fighter = FIGHTER_SCENE.instantiate()
	fighter.character = FAST
	arena.add_child(fighter)
	fighter.global_position = at
	return fighter
