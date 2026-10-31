# Run: tests/run_all.sh test_bots
extends "res://tests/test_case.gd"

## The WalkMap finds every part of the Isles for both classes, and a bot gets to a target
## anywhere on it and hits it without falling in the pit. Two bots play a match on their own.

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const FAST := preload("res://data/characters/stickman.tres")
const HEAVY := preload("res://data/characters/stickman_heavy.tres")
const PISTOL := preload("res://data/weapons/pistol.tres")
## Simulated seconds a bot gets to reach a target and hit it.
const HUNT_TIME := 25.0
## Simulated seconds of a bot against bot match.
const MATCH_TIME := 90.0

var arena: Arena


func _init() -> void:
	time_limit = 600.0


func run() -> void:
	arena = load("res://scenes/arenas/isles.tscn").instantiate()
	root.add_child(arena)
	arena.rng.seed = 8
	for spawner in arena.get_node("ItemSpawns").get_children():
		spawner.interval = 9999.0
	await physics_frames(5)
	var map := WalkMap.of(arena)
	_check_map(map)
	# A spot on each kind of place: the far ground, every island, the bridge.
	var spots: Array[Vector2] = [Vector2(600, 300), Vector2(20, 300), Vector2(130, 226), Vector2(520, 226), Vector2(300, 160), Vector2(110, 106), Vector2(520, 100), Vector2(310, 282)]
	for character: CharacterData in [FAST, HEAVY]:
		for spot in spots:
			await _hunt(character, Vector2(280, 300), spot, null)
	await _hunt(FAST, Vector2(96, 300), Vector2(560, 300), PISTOL)
	arena.free()
	await _bot_match()


func _check_map(map: WalkMap) -> void:
	check(map.surfaces.size() >= 8, "the scan finds the map's floors (%d surfaces)" % map.surfaces.size())
	for spot: Vector2 in [Vector2(100, 300), Vector2(500, 300), Vector2(100, 226), Vector2(500, 226), Vector2(320, 160), Vector2(120, 106), Vector2(520, 100), Vector2(320, 282)]:
		var found := map.surface_under(spot)
		check(found >= 0 and absf(map.surfaces[found].y - spot.y) <= 3.0, "there is a floor at %s" % spot)
	check(map.surface_under(Vector2(320, 340)) < 0, "the pit has no floor")
	var ground := map.surface_under(Vector2(100, 300))
	for character: CharacterData in [FAST, HEAVY]:
		for i in map.surfaces.size():
			if i != ground:
				check(map.next_link(ground, i, 100.0, character.fighter_class) != null, "%s gets from the ground to surface %d at y %d" % [character.resource_path.get_file(), i, map.surfaces[i].y])
				check(map.next_link(i, ground, map.surfaces[i].left, character.fighter_class) != null, "%s gets from surface %d to the ground" % [character.resource_path.get_file(), i])


func _hunt(character: CharacterData, start: Vector2, spot: Vector2, gun: WeaponData) -> void:
	var bot: Fighter = FIGHTER_SCENE.instantiate()
	bot.character = character
	bot.controller = BotController.new()
	arena.add_child(bot)
	bot.global_position = start
	var target: Fighter = FIGHTER_SCENE.instantiate()
	target.character = FAST
	arena.add_child(target)
	target.global_position = spot
	target.health.max_health = 100000
	target.health.current = 100000
	await physics_frames(2)
	bot.inventory.drop_firearm()
	if gun:
		bot.inventory.equip_firearm(gun)
	var damage := [0]
	target.health.damaged.connect(func(amount: int) -> void: damage[0] += amount)
	var left := int(HUNT_TIME * 60)
	while left > 0 and damage[0] == 0 and not bot.is_dead():
		left -= 1
		await physics_frame
	var label := "%s from %s %s the target at %s" % [character.resource_path.get_file(), start, "shoots" if gun else "reaches", spot]
	check(damage[0] > 0, label + " (after %.1f s, ended at %s)" % [HUNT_TIME - left / 60.0, bot.global_position])
	check(not bot.is_dead(), label + " and stays alive")
	bot.free()
	target.free()
	await physics_frames(2)


func _bot_match() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.bot_players.assign([0, 1])
	root.add_child(main)
	main.arena.rng.seed = 3
	var left := int(MATCH_TIME * 60)
	var kills := 0
	while left > 0 and kills < 3:
		left -= 1
		await physics_frame
		kills = main.mode.kills[0] + main.mode.kills[1]
	check(kills >= 3, "two bots score kills on their own (%s)" % [main.mode.kills])
	main.free()
