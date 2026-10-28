# Run: tests/run_all.sh test_docks
extends "res://tests/test_case.gd"

## The Docks arena plays as laid out: every ladder leads from a floor to a platform a
## fighter can stand on, a quay gap drops into the sea and kills, and the gaps are
## jumped edge to edge: a walking jump just clears a narrow gap, a dive the wide one.

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const FAST := preload("res://data/characters/placeholder.tres")
## Quay surface and the first gap (columns 18-20 of the layout).
const QUAY_Y := 576.0
const GAP_LEFT := 288.0
## Run-up before the edge, px.
const RUN_UP := 30.0

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

	# Edge to edge (user, session 4): a jump from the very edge just makes it across;
	# taking off well before it falls short (walking: 12 px, user wanted some slack).
	var walk_gap := Vector2(928, 976) # the last gap, jumped from its right side
	check(await _edge_jump(walk_gap, -1, 0.0, false), "a walking jump from the edge clears the last gap")
	check(not await _edge_jump(walk_gap, -1, 12.0, false), "a walking jump 12 px early falls into the last gap")
	var dive_gap := Vector2(592, 688) # the wide middle gap, dived from its right side
	check(await _edge_jump(dive_gap, -1, 0.0, true), "a running dive from the edge clears the wide gap")
	check(not await _edge_jump(dive_gap, -1, 8.0, true), "a running dive half a tile early falls into the wide gap")

	var faller := _spawn(Vector2(GAP_LEFT + 24.0, QUAY_Y - 40.0))
	await physics_frames(120)
	check(faller.is_dead(), "falling into the sea kills")


## Walks (or runs) toward the gap spanning `gap` (x from, x to) from the side `dir`
## points away from, takes off `early` px before the last moment on the edge, and tells
## whether the fighter made it across alive.
func _edge_jump(gap: Vector2, dir: int, early: float, running: bool) -> bool:
	var edge := gap.y if dir < 0 else gap.x
	var fighter := _spawn(Vector2(edge - dir * RUN_UP, QUAY_Y))
	await physics_frames(3)
	var half: float = (fighter.body_shape().shape as RectangleShape2D).size.x / 2.0
	fighter.controller.move = dir
	fighter.controller.run = running
	for frame in 120:
		await physics_frames(1)
		# Jump on the last frame the back of the feet is still over the quay: the next
		# step would carry it past the edge.
		var ahead := fighter.global_position.x + fighter.velocity.x / 60.0
		if (edge + dir * (half - early) - ahead) * dir <= 0.0:
			break
	fighter.controller.jump = true
	await physics_frames(2)
	fighter.controller.jump = false
	var took_off := fighter.velocity.y < 0.0
	await physics_frames(90)
	var across := took_off and not fighter.is_dead() and fighter.is_on_floor() and (fighter.global_position.x - (gap.x if dir < 0 else gap.y)) * dir > 0.0
	fighter.queue_free()
	await physics_frames(1)
	return across


func _spawn(at: Vector2) -> Fighter:
	var fighter: Fighter = FIGHTER_SCENE.instantiate()
	fighter.character = FAST
	arena.add_child(fighter)
	fighter.global_position = at
	return fighter
