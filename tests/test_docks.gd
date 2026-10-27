# Run: tests/run_all.sh test_docks
extends "res://tests/test_case.gd"

## The Docks arena plays as laid out: every ladder leads from a floor to a platform a
## fighter can stand on, a quay gap drops into the sea and kills, and a walking jump
## clears the narrow gaps.

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const FAST := preload("res://data/characters/placeholder.tres")
## Quay surface and the first gap (columns 18-20 of the layout).
const QUAY_Y := 576.0
const GAP_LEFT := 288.0

var arena: Arena


func run() -> void:
	arena = load("res://scenes/arenas/docks.tscn").instantiate()
	for spawner: ItemSpawner in arena.get_node("ItemSpawns").get_children():
		spawner.interval = 9999.0
	root.add_child(arena)
	await physics_frames(2)

	var ladders := get_nodes_in_group(Ladder.GROUP)
	check(ladders.size() >= 8, "the docks have their ladders")
	for ladder: Ladder in ladders:
		var fighter := _spawn(Vector2(ladder.global_position.x, ladder.bottom()))
		await physics_frames(5)
		fighter.controller.aim = -1.0
		await physics_frames(int(ladder.height / fighter.fighter_class.climb_speed * 60) + 15)
		fighter.controller.aim = 0.0
		await physics_frames(10)
		check(fighter.is_on_floor() and absf(fighter.global_position.y - ladder.top()) < 1.0, "ladder at %s leads up to a platform to stand on" % ladder.global_position)
		fighter.queue_free()
		await physics_frames(1)

	var jumper := _spawn(Vector2(GAP_LEFT - 20.0, QUAY_Y))
	await physics_frames(5)
	jumper.controller.move = 1.0
	await physics_frames(8)
	jumper.controller.jump = true
	await physics_frames(1)
	jumper.controller.jump = false
	await physics_frames(60)
	jumper.controller.move = 0.0
	await physics_frames(20)
	check(not jumper.is_dead() and jumper.global_position.x > GAP_LEFT + 48.0, "a walking jump clears a narrow gap")
	jumper.queue_free()

	var faller := _spawn(Vector2(GAP_LEFT + 24.0, QUAY_Y - 40.0))
	await physics_frames(120)
	check(faller.is_dead(), "falling into the sea kills")


func _spawn(at: Vector2) -> Fighter:
	var fighter: Fighter = FIGHTER_SCENE.instantiate()
	fighter.character = FAST
	arena.add_child(fighter)
	fighter.global_position = at
	return fighter
