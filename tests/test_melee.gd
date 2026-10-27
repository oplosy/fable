# Run: godot --headless --path . -s res://tests/test_melee.gd
extends "res://tests/test_case.gd"

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const FAST := preload("res://data/characters/placeholder.tres")
const HEAVY := preload("res://data/characters/dummy.tres")
const PISTOL := preload("res://data/weapons/pistol.tres")

var arena: Node2D


func run() -> void:
	arena = load("res://scenes/arenas/test_arena.tscn").instantiate()
	root.add_child(arena)
	var fast := _spawn(FAST, Vector2(200, 328))
	var heavy := _spawn(HEAVY, Vector2(214, 328))
	await physics_frames(10)
	var hits_on_heavy: Array[int] = []
	heavy.health.damaged.connect(func(amount: int) -> void: hits_on_heavy.append(amount))
	var fast_combo := FAST.fighter_class.melee_combo

	# Single attack.
	await _press_attack(fast)
	check(fast.melee.is_attacking() and fast.melee.combo_index() == 0, "attack starts the first combo attack")
	await physics_frames(10)
	check(hits_on_heavy == [fast_combo[0].damage], "jab hits the target once")
	check(heavy.velocity.x > 0.0 or heavy.global_position.x > 214.0, "jab pushes the target away")
	check(fast.health.current == fast.health.max_health, "attacker does not hit itself")
	await physics_frames(10)
	check(not fast.melee.is_attacking() and fast.melee.is_cooling_down(), "a short chain ends with a short pause")
	await _press_attack(fast)
	check(not fast.melee.is_attacking(), "attack is ignored during the pause")
	await physics_frames(30)
	check(not fast.melee.is_cooling_down(), "short pause wears off")

	# Full combo, then the long pause.
	hits_on_heavy.clear()
	_reset(heavy, 214)
	await physics_frames(5)
	var highest_index := 0
	for i in 30:
		await _press_attack(fast)
		highest_index = maxi(highest_index, fast.melee.combo_index())
		await physics_frames(2)
	check(hits_on_heavy == [fast_combo[0].damage, fast_combo[1].damage, fast_combo[2].damage, fast_combo[3].damage], "repeated presses chain the 4-hit combo exactly once")
	check(highest_index == 3, "combo reaches its last attack")
	check(fast.melee.is_cooling_down(), "full combo ends with a pause despite more presses")

	# Committed to the attack.
	await physics_frames(60)
	_reset(heavy, 214)
	var start_x := fast.global_position.x
	await _press_attack(fast)
	fast.controller.move = -1.0
	await physics_frames(5)
	check(absf(fast.global_position.x - start_x) < 0.5 and fast.facing == 1, "attacker cannot move or turn mid-attack")
	fast.controller.move = 0.0
	await physics_frames(30)

	# Getting hit cancels the attack.
	hits_on_heavy.clear()
	_reset(heavy, 214)
	await physics_frames(40)
	await _press_attack(fast)
	fast.take_hit(1)
	await physics_frames(15)
	check(not fast.melee.is_attacking() and hits_on_heavy.is_empty(), "getting hit cancels the attack before it lands")

	# Heavy class: punch, punch, kick.
	var hits_on_fast: Array[int] = []
	fast.health.damaged.connect(func(amount: int) -> void: hits_on_fast.append(amount))
	heavy.facing = -1
	heavy.get_node("Visuals").scale.x = -1
	_reset(fast, 200)
	await physics_frames(30)
	for i in 40:
		await _press_attack(heavy)
		await physics_frames(2)
	var heavy_combo := HEAVY.fighter_class.melee_combo
	check(hits_on_fast == [heavy_combo[0].damage, heavy_combo[1].damage, heavy_combo[2].damage], "heavy class chains punch, punch, kick")
	check(fast.global_position.x < 190.0, "kick sends the target flying")

	# Firearm slot fires instead of punching.
	await physics_frames(60)
	_reset(fast, 200)
	fast.inventory.equip_firearm(PISTOL)
	await physics_frames(2)
	await _press_attack(fast)
	check(not fast.melee.is_attacking(), "attack in the firearm slot does not punch")

	# Dead fighters are not hit.
	fast.inventory.select_slot(Inventory.Slot.MELEE)
	heavy.take_hit(1000)
	hits_on_heavy.clear()
	await physics_frames(60)
	_reset(heavy, 214)
	await _press_attack(fast)
	await physics_frames(15)
	check(hits_on_heavy.is_empty(), "melee passes over dead bodies")

	await _test_trade()
	await _test_jab_spam()


## Two attacks landing on the same frame both hit, whichever fighter is processed first.
func _test_trade() -> void:
	var first := _spawn(FAST, Vector2(400, 328))
	var second := _spawn(FAST, Vector2(414, 328))
	await physics_frames(5)
	second.facing = -1
	second.get_node("Visuals").scale.x = -1
	first.controller.attack = true
	second.controller.attack = true
	await physics_frames(1)
	first.controller.attack = false
	second.controller.attack = false
	await physics_frames(10)
	check(first.health.current < first.health.max_health and second.health.current < second.health.max_health, "simultaneous punches trade")
	first.queue_free()
	second.queue_free()
	await physics_frames(5)


## Spamming single jabs leaves the target at least combo_escape_time to act between them.
func _test_jab_spam() -> void:
	var attacker := _spawn(FAST, Vector2(500, 328))
	var target := _spawn(HEAVY, Vector2(514, 328))
	await physics_frames(5)
	var hit_once := false
	var free_run := 0
	var shortest_window := 999
	for i in 240:
		attacker.controller.attack = not attacker.melee.is_attacking() and not attacker.melee.is_cooling_down()
		await physics_frames(1)
		if target.can_act():
			free_run += 1
		else:
			if hit_once and free_run > 0:
				shortest_window = mini(shortest_window, free_run)
			hit_once = true
			free_run = 0
	attacker.controller.attack = false
	var needed := int(FAST.fighter_class.combo_escape_time * 60) - 1
	check(shortest_window != 999 and shortest_window >= needed, "single-jab spam leaves at least the escape time free (%d frames)" % shortest_window)


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
