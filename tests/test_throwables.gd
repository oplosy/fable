# Run: godot --headless --path . -s res://tests/test_throwables.gd
extends "res://tests/test_case.gd"

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const FAST := preload("res://data/characters/placeholder.tres")
const GRENADE := preload("res://data/throwables/grenade.tres")
const MOLOTOV := preload("res://data/throwables/molotov.tres")
const EXPLOSION := preload("res://scenes/throwables/explosion.tscn")
const FIRE := preload("res://scenes/throwables/fire_area.tscn")

var arena: Node2D


func run() -> void:
	arena = load("res://scenes/arenas/test_arena.tscn").instantiate()
	arena.get_node("ItemSpawns/W1").interval = 9999.0
	root.add_child(arena)

	await _test_explosion()
	await _test_fire()
	await _test_grenade_throw()
	await _test_cooking()
	await _test_molotov()
	await _test_pickup()


## Every fighter in range is hurt, pushed away and knocked down, the thrower included.
func _test_explosion() -> void:
	var left := _spawn(Vector2(280, 328))
	var right := _spawn(Vector2(320, 328))
	var far := _spawn(Vector2(450, 328))
	await physics_frames(10)
	var blast: Explosion = EXPLOSION.instantiate()
	arena.add_child(blast)
	blast.global_position = Vector2(300, 318)
	await physics_frames(3)
	check(left.health.current == left.health.max_health - blast.damage and right.health.current == right.health.max_health - blast.damage, "the blast hurts every fighter in range")
	check(left.velocity.x < 0.0 and right.velocity.x > 0.0, "the blast pushes fighters away from its centre")
	check(left.is_knocked_down() and right.is_knocked_down(), "the blast knocks down")
	check(far.health.current == far.health.max_health, "fighters out of range are untouched")
	await physics_frames(30)
	check(not is_instance_valid(blast), "the blast disappears")
	for fighter in [left, right, far]:
		fighter.queue_free()
	await physics_frames(5)


## Fire burns whoever stands in it every tick, without stunning, until it dies out.
func _test_fire() -> void:
	var fighter := _spawn(Vector2(300, 328))
	await physics_frames(10)
	var fire: FireArea = FIRE.instantiate()
	# Placed before entering the tree, like a molotov's fire, so it settles from there.
	fire.position = Vector2(300, 260)
	arena.add_child(fire)
	await physics_frames(2)
	check(is_equal_approx(fire.global_position.y, 328.0), "fire settles on the floor below where it starts")
	check(fighter.health.current == fighter.health.max_health - fire.damage_per_tick and not fighter.is_stunned(), "fire burns at once without stunning")
	await physics_frames(int(fire.tick * 60) + 1)
	check(fighter.health.current == fighter.health.max_health - 2 * fire.damage_per_tick, "fire keeps burning every tick")
	fighter.global_position.x = 400
	var health_out := fighter.health.current
	await physics_frames(60)
	check(fighter.health.current == health_out, "leaving the fire stops the burning")
	await physics_frames(int(fire.lifetime * 60))
	check(not is_instance_valid(fire), "fire dies out after its lifetime")
	fighter.queue_free()
	await physics_frames(5)


## Press pulls the pin, release lobs the grenade forward; it goes off after the fuse.
func _test_grenade_throw() -> void:
	var thrower := _spawn(Vector2(100, 328))
	await physics_frames(10)
	thrower.inventory.equip_throwable(GRENADE, GRENADE.count)
	check(thrower.inventory.active_slot == Inventory.Slot.MELEE, "starting grenades do not select their slot")
	check(thrower.inventory.select_slot(Inventory.Slot.THROWABLE), "the grenade slot can be selected")
	await physics_frames(2)
	thrower.controller.attack = true
	thrower.controller.attack_held = true
	await physics_frames(1)
	thrower.controller.attack = false
	check(thrower.thrower.is_cooking(), "pressing attack pulls the pin")
	thrower.controller.move = 1.0
	var x_before := thrower.global_position.x
	await physics_frames(30)
	thrower.controller.move = 0.0
	check(absf(thrower.global_position.x - x_before) < 0.5, "a fighter holding a live grenade cannot move")
	thrower.controller.attack_held = false
	await physics_frames(2)
	var thrown := get_nodes_in_group("thrown_items")
	check(thrown.size() == 1 and thrower.thrower.count == GRENADE.count - 1, "releasing attack throws one grenade")
	if thrown.size() == 1:
		check(absf(thrown[0].fuse_left - (GRENADE.fuse_time - 0.5)) < 0.05, "the fuse keeps the time already cooked in hand")
		await physics_frames(40)
		check(thrown[0].global_position.x > 140.0, "a level aim still lobs the grenade forward")
	await physics_frames(int((GRENADE.fuse_time - 0.5) * 60))
	check(get_nodes_in_group("thrown_items").is_empty(), "the grenade goes off when its fuse ends")
	check(thrower.health.current == thrower.health.max_health, "a grenade thrown far away does not hurt the thrower")
	thrower.queue_free()
	await physics_frames(5)


## Held too long, the grenade goes off in hand; a knockdown drops a live one at the feet.
func _test_cooking() -> void:
	var fighter := _spawn(Vector2(200, 328))
	await physics_frames(10)
	fighter.inventory.equip_throwable(GRENADE, 1)
	fighter.inventory.select_slot(Inventory.Slot.THROWABLE)
	await physics_frames(2)
	fighter.controller.attack = true
	fighter.controller.attack_held = true
	await physics_frames(1)
	fighter.controller.attack = false
	await physics_frames(int(GRENADE.fuse_time * 60) + 3)
	check(fighter.health.current < fighter.health.max_health and fighter.is_knocked_down(), "a grenade held past its fuse goes off in hand")
	check(fighter.thrower.is_empty() and fighter.inventory.active_slot == Inventory.Slot.MELEE, "the last grenade used empties the slot")
	check(not fighter.inventory.select_slot(Inventory.Slot.THROWABLE), "an empty grenade slot cannot be selected")
	fighter.controller.attack_held = false
	fighter.queue_free()

	var holder := _spawn(Vector2(200, 328))
	await physics_frames(10)
	holder.inventory.equip_throwable(GRENADE, 2)
	holder.inventory.select_slot(Inventory.Slot.THROWABLE)
	await physics_frames(2)
	holder.controller.attack = true
	holder.controller.attack_held = true
	await physics_frames(1)
	holder.controller.attack = false
	await physics_frames(10)
	holder.take_hit(0, Vector2.ZERO, -1.0, true)
	await physics_frames(3)
	var dropped := get_nodes_in_group("thrown_items")
	check(dropped.size() == 1 and absf(dropped[0].global_position.x - 200.0) < 12.0, "a knockdown drops the live grenade at the fighter's feet")
	check(holder.thrower.count == 1 and not holder.thrower.is_cooking(), "the dropped grenade is used up")
	holder.controller.attack_held = false
	await physics_frames(int(GRENADE.fuse_time * 60))
	holder.queue_free()
	await physics_frames(5)


## A molotov breaks on the first fighter it hits and leaves fire there.
func _test_molotov() -> void:
	var thrower := _spawn(Vector2(100, 328))
	var target := _spawn(Vector2(150, 328))
	await physics_frames(10)
	thrower.inventory.equip_throwable(MOLOTOV, MOLOTOV.count)
	thrower.inventory.select_slot(Inventory.Slot.THROWABLE)
	thrower.thrower.lift_degrees = 0.0
	await physics_frames(2)
	thrower.controller.attack = true
	thrower.controller.attack_held = true
	await physics_frames(1)
	thrower.controller.attack = false
	thrower.controller.attack_held = false
	await physics_frames(20)
	var fires := get_nodes_in_group("fire_areas")
	check(get_nodes_in_group("thrown_items").is_empty() and fires.size() == 1, "a molotov breaks on impact and leaves fire")
	check(target.health.current < target.health.max_health, "the fire burns the fighter it hit")
	check(thrower.health.current == thrower.health.max_health, "the thrower outside the fire is safe")
	for fire in fires:
		fire.queue_free()
	thrower.queue_free()
	target.queue_free()
	await physics_frames(5)


## Spawned throwables fill an empty slot by walking over them; a full slot needs down.
func _test_pickup() -> void:
	var spawner: ItemSpawner = arena.get_node("ItemSpawns/W1")
	spawner.items = [MOLOTOV]
	spawner.interval = 0.1
	await physics_frames(20)
	spawner.interval = 9999.0
	var fighter := _spawn(Vector2(40, 328))
	fighter.inventory.equip_throwable(GRENADE, 1)
	await physics_frames(20)
	check(fighter.thrower.item == GRENADE and spawner.has_item(), "a full throwable slot does not take an item by walking over")
	fighter.controller.down = true
	await physics_frames(1)
	fighter.controller.down = false
	await physics_frames(2)
	check(fighter.thrower.item == MOLOTOV and fighter.thrower.count == MOLOTOV.count, "down swaps in the full count of the new throwable")
	check(fighter.inventory.active_slot == Inventory.Slot.THROWABLE, "the picked-up throwable is selected")
	var dropped := get_nodes_in_group("dropped_items")
	check(dropped.size() == 1 and dropped[0].data == GRENADE and not dropped[0].pickable, "the old throwables drop and cannot be picked up")


func _spawn(at: Vector2) -> Fighter:
	var fighter: Fighter = FIGHTER_SCENE.instantiate()
	fighter.character = FAST
	arena.add_child(fighter)
	fighter.global_position = at
	return fighter
