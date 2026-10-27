# Run: godot --headless --path . -s res://tests/test_melee_items.gd
extends "res://tests/test_case.gd"

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const FAST := preload("res://data/characters/placeholder.tres")
const HEAVY := preload("res://data/characters/dummy.tres")
const PISTOL := preload("res://data/weapons/pistol.tres")
const KNIFE := preload("res://data/weapons/knife.tres")
const BAT := preload("res://data/weapons/bat.tres")

var arena: Node2D


func run() -> void:
	arena = load("res://scenes/arenas/test_arena.tscn").instantiate()
	arena.get_node("ItemSpawns/W1").interval = 9999.0
	root.add_child(arena)

	await _test_combos()
	await _test_durability()
	await _test_pickup_and_drop()


## The held item's combo replaces the punches.
func _test_combos() -> void:
	var attacker := _spawn(FAST, Vector2(200, 328))
	var target := _spawn(HEAVY, Vector2(214, 328))
	await physics_frames(10)
	var hits: Array[int] = []
	target.health.damaged.connect(func(amount: int) -> void: hits.append(amount))

	attacker.equip_melee_item(KNIFE)
	await physics_frames(2)
	check(attacker.active_slot == Fighter.Slot.MELEE and attacker.melee.item == KNIFE, "equipping a knife puts it in the melee slot")
	await _full_combo(attacker)
	check(hits == [5, 5, 8], "the knife combo replaces the punches")
	check(attacker.melee.item_hits_left == KNIFE.durability - 3, "each landed knife hit wears the knife")

	hits.clear()
	await physics_frames(60)
	_reset(target)
	attacker.equip_melee_item(BAT)
	await physics_frames(2)
	check(attacker.melee.item == BAT and attacker.melee.item_hits_left == BAT.durability, "equipping a new item starts at full durability")
	await _full_combo(attacker)
	check(hits == [8, 8, 14], "the bat combo replaces the punches")
	check(target.is_knocked_down(), "the bat's finisher knocks down")

	# The jump kick is a kick, so it does not wear the item.
	await physics_frames(120)
	_reset(target)
	var before := attacker.melee.item_hits_left
	attacker.controller.jump = true
	await physics_frames(1)
	attacker.controller.jump = false
	await physics_frames(4)
	await _press_attack(attacker)
	await physics_frames(30)
	check(target.health.current < target.health.max_health, "the jump kick lands")
	check(attacker.melee.item_hits_left == before, "the jump kick does not wear the item")
	attacker.queue_free()
	target.queue_free()
	await physics_frames(5)


## A worn-out item finishes its combo, then breaks and leaves bare hands.
func _test_durability() -> void:
	var attacker := _spawn(FAST, Vector2(200, 328))
	var target := _spawn(HEAVY, Vector2(214, 328))
	await physics_frames(10)
	var worn: MeleeItemData = KNIFE.duplicate()
	worn.durability = 2
	attacker.equip_melee_item(worn)
	var broke := [false]
	attacker.melee.item_broke.connect(func() -> void: broke[0] = true)
	var hits: Array[int] = []
	target.health.damaged.connect(func(amount: int) -> void: hits.append(amount))
	await _full_combo(attacker)
	check(hits.size() == 3, "a worn-out item still finishes its combo")
	check(broke[0] and attacker.melee.item == null, "the item breaks when its durability is used up")
	check(get_nodes_in_group("dropped_items").is_empty(), "a broken item leaves nothing behind")
	await physics_frames(60)
	await _press_attack(attacker)
	check(attacker.melee.current_attack() == FAST.fighter_class.melee_combo[0], "after breaking, the fighter punches again")
	attacker.queue_free()
	target.queue_free()
	await physics_frames(5)


## Spawned melee items fill the melee slot like firearms fill theirs; dead fighters drop them.
func _test_pickup_and_drop() -> void:
	var spawner: ItemSpawner = arena.get_node("ItemSpawns/W1")
	spawner.items = [KNIFE]
	spawner.interval = 0.1
	await physics_frames(20)
	spawner.interval = 9999.0
	var fighter := _spawn(FAST, Vector2(100, 328))
	await physics_frames(5)
	fighter.equip_firearm(PISTOL)
	fighter.controller.move = -1.0
	await physics_frames(40)
	fighter.controller.move = 0.0
	check(fighter.melee.item == KNIFE, "walking over a melee item with bare hands takes it")
	check(fighter.firearm != null and fighter.active_slot == Fighter.Slot.MELEE, "the firearm is kept and the melee slot is selected")

	# Full melee slot: walking over does nothing, down swaps.
	spawner.items = [BAT]
	spawner.interval = 0.1
	await physics_frames(20)
	spawner.interval = 9999.0
	fighter.global_position = Vector2(40, 328)
	fighter.velocity = Vector2.ZERO
	await physics_frames(20)
	check(fighter.melee.item == KNIFE and spawner.has_item(), "a full melee slot does not take an item by walking over")
	fighter.controller.down = true
	await physics_frames(1)
	fighter.controller.down = false
	await physics_frames(2)
	check(fighter.melee.item == BAT, "down on a melee item swaps it in")
	var dropped := get_nodes_in_group("dropped_items")
	check(dropped.size() == 1 and dropped[0].data == KNIFE and not dropped[0].pickable, "the old melee item drops and cannot be picked up")

	fighter.take_hit(0, Vector2.ZERO, -1.0, true)
	await physics_frames(2)
	check(fighter.is_knocked_down() and fighter.firearm == null and fighter.melee.item == BAT, "a knockdown drops the firearm but keeps the melee item")
	# Wait out the downed and get-up invulnerability.
	await physics_frames(110)

	fighter.take_hit(1000)
	await physics_frames(2)
	dropped = get_nodes_in_group("dropped_items")
	check(fighter.melee.item == null and dropped.any(func(d: ItemPickup) -> bool: return d.data == BAT), "a dead fighter drops its melee item")


## Presses attack until the last attack of the combo runs, so exactly one combo plays.
func _full_combo(attacker: Fighter) -> void:
	var last := attacker.melee.item.combo.size() - 1 if attacker.melee.item else 0
	for i in 30:
		await _press_attack(attacker)
		await physics_frames(2)
		if attacker.melee.combo_index() == last:
			break
	# Let the last hit land and the combo end.
	await physics_frames(30)


func _press_attack(fighter: Fighter) -> void:
	fighter.controller.attack = true
	await physics_frames(1)
	fighter.controller.attack = false


func _reset(fighter: Fighter) -> void:
	fighter.health.current = fighter.health.max_health
	fighter.global_position = Vector2(214, 328)
	fighter.velocity = Vector2.ZERO


func _spawn(character: CharacterData, at: Vector2) -> Fighter:
	var fighter: Fighter = FIGHTER_SCENE.instantiate()
	fighter.character = character
	arena.add_child(fighter)
	fighter.global_position = at
	return fighter
