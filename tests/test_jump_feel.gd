# Run: tests/run_all.sh test_jump_feel
extends "res://tests/test_case.gd"

## The jump feel settings: a released jump is cut short, falling can be heavier than
## rising, jump still works just after walking off a ledge (coyote time), and a press
## just before landing jumps on landing (jump buffer). All off by default.

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const FAST := preload("res://data/characters/placeholder.tres")
const FLOOR_Y := 328.0
## Top of a solid ledge spanning x 100..300.
const LEDGE_Y := 248.0

var arena: Node2D


func run() -> void:
	arena = load("res://scenes/arenas/test_arena.tscn").instantiate()
	arena.get_node("ItemSpawns/W1").interval = 9999.0
	root.add_child(arena)
	var ledge := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(200, 16)
	ledge.add_child(shape)
	ledge.position = Vector2(200, LEDGE_Y + 8)
	arena.add_child(ledge)

	var settings := FighterClass.new()
	var held := await _peak(_spawn(Vector2(420, FLOOR_Y), settings), 60)
	var tapped := await _peak(_spawn(Vector2(500, FLOOR_Y), settings), 2)
	check(absf(held - tapped) < 1.0, "with jump_cut off, a tap jumps as high as a held press")

	settings = FighterClass.new()
	settings.jump_cut = 0.4
	held = await _peak(_spawn(Vector2(420, FLOOR_Y), settings), 60)
	tapped = await _peak(_spawn(Vector2(500, FLOOR_Y), settings), 2)
	check(tapped < held * 0.6, "releasing jump early cuts the jump short (%.0f px vs %.0f px)" % [tapped, held])

	settings = FighterClass.new()
	settings.fall_gravity_scale = 2.0
	var heavy := _spawn(Vector2(420, FLOOR_Y), settings)
	var light := _spawn(Vector2(500, FLOOR_Y), FighterClass.new())
	await physics_frames(5)
	for fighter: Fighter in [heavy, light]:
		fighter.controller.jump = true
		fighter.controller.jump_held = true
	await physics_frames(1)
	for fighter: Fighter in [heavy, light]:
		fighter.controller.jump = false
	var landed := {}
	for frame in 90:
		await physics_frames(1)
		for fighter: Fighter in [heavy, light]:
			if not landed.has(fighter) and frame > 5 and fighter.is_on_floor():
				landed[fighter] = frame
	check(landed.get(heavy, 999) < landed.get(light, 0), "a heavier fall lands sooner (%s vs %s frames)" % [landed.get(heavy), landed.get(light)])
	heavy.queue_free()
	light.queue_free()

	settings = FighterClass.new()
	settings.coyote_time = 0.12
	check(await _jumps_after_ledge(settings, 4), "jump works a few frames after walking off a ledge with coyote time")
	check(not await _jumps_after_ledge(settings, 14), "after the coyote time, jump does nothing in the air")
	check(not await _jumps_after_ledge(FighterClass.new(), 4), "without coyote time, jump does nothing once off the ledge")

	settings = FighterClass.new()
	settings.jump_buffer = 0.12
	check(await _jumps_on_landing(settings), "a jump pressed just before landing jumps on landing")
	check(not await _jumps_on_landing(FighterClass.new()), "without a jump buffer, a press in the air is lost")


## Highest the fighter gets (px above the floor) when jump is held for `hold` frames.
func _peak(fighter: Fighter, hold: int) -> float:
	await physics_frames(5)
	fighter.controller.jump = true
	fighter.controller.jump_held = true
	await physics_frames(1)
	fighter.controller.jump = false
	var top := fighter.global_position.y
	for frame in 70:
		if frame == hold:
			fighter.controller.jump_held = false
		await physics_frames(1)
		top = minf(top, fighter.global_position.y)
	fighter.queue_free()
	return FLOOR_Y - top


## Walks off the ledge's right end and presses jump `frames` frames after leaving it.
func _jumps_after_ledge(settings: FighterClass, frames: int) -> bool:
	var fighter := _spawn(Vector2(280, LEDGE_Y), settings)
	await physics_frames(5)
	fighter.controller.move = 1.0
	while fighter.is_on_floor():
		await physics_frames(1)
	await physics_frames(frames - 1)
	fighter.controller.jump = true
	await physics_frames(1)
	fighter.controller.jump = false
	await physics_frames(1)
	var jumped := fighter.velocity.y < 0.0
	fighter.queue_free()
	return jumped


## Drops the fighter onto the floor and presses jump a few frames before it lands.
func _jumps_on_landing(settings: FighterClass) -> bool:
	var fighter := _spawn(Vector2(500, FLOOR_Y - 60.0), settings)
	await physics_frames(2)
	while fighter.global_position.y < FLOOR_Y - 8.0:
		await physics_frames(1)
	fighter.controller.jump = true
	await physics_frames(1)
	fighter.controller.jump = false
	var jumped := false
	for frame in 20:
		await physics_frames(1)
		jumped = jumped or fighter.velocity.y < -100.0
	fighter.queue_free()
	return jumped


func _spawn(at: Vector2, settings: FighterClass) -> Fighter:
	var fighter: Fighter = FIGHTER_SCENE.instantiate()
	fighter.character = FAST.duplicate()
	fighter.character.fighter_class = settings
	arena.add_child(fighter)
	fighter.global_position = at
	return fighter
