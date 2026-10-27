# Run: tests/run_all.sh test_props
extends "res://tests/test_case.gd"

## Map props: ladders up to a one-way platform and back down, jumping off one, and
## explosive barrels that blow up when hit, set each other off and credit the shooter.

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const FAST := preload("res://data/characters/placeholder.tres")
const FLOOR_Y := 328.0
const PLATFORM_Y := 232.0

var arena: Node2D


func run() -> void:
	arena = load("res://scenes/arenas/test_arena.tscn").instantiate()
	arena.get_node("ItemSpawns/W1").interval = 9999.0
	root.add_child(arena)
	_add_platform(Vector2(200, PLATFORM_Y), 64.0)
	var ladder := Ladder.new()
	ladder.height = FLOOR_Y - PLATFORM_Y
	ladder.position = Vector2(200, FLOOR_Y)
	arena.add_child(ladder)

	var climber := _spawn(Vector2(203, FLOOR_Y))
	await physics_frames(10)
	climber.controller.aim = -1.0
	await physics_frames(3)
	check(climber.state() == Fighter.State.CLIMB, "up next to a ladder takes hold of it")
	check(climber.global_position.x == 200.0, "the climber is on the ladder's middle")
	await physics_frames(int((FLOOR_Y - PLATFORM_Y) / climber.fighter_class.climb_speed * 60) + 10)
	check(not climber.is_climbing(), "the top of the ladder lets go")
	await physics_frames(10)
	climber.controller.aim = 0.0
	await physics_frames(10)
	check(climber.is_on_floor() and absf(climber.global_position.y - PLATFORM_Y) < 1.0, "the climber stands on the one-way platform the ladder goes through")

	climber.controller.aim = 1.0
	await physics_frames(3)
	check(climber.is_climbing(), "down on top of a ladder climbs down")
	await physics_frames(30)
	climber.controller.aim = 0.0
	climber.controller.jump = true
	await physics_frames(1)
	climber.controller.jump = false
	check(not climber.is_climbing() and climber.velocity.y < 0.0, "jump lets go of the ladder with a jump")
	await physics_frames(90)
	check(climber.is_on_floor(), "after jumping off, the climber lands")

	var walker := _spawn(Vector2(260, FLOOR_Y))
	await physics_frames(5)
	walker.controller.aim = -1.0
	await physics_frames(5)
	check(not walker.is_climbing(), "up away from a ladder does nothing")
	walker.controller.aim = 0.0
	walker.queue_free()
	climber.queue_free()

	# Two barrels side by side; the second is out of the shooter's blast but next to the first.
	var shooter := _spawn(Vector2(60, FLOOR_Y))
	var victim := _spawn(Vector2(420, FLOOR_Y))
	var first := _barrel(Vector2(380, FLOOR_Y))
	var second := _barrel(Vector2(440, FLOOR_Y))
	await physics_frames(5)
	first.take_hit(5, Vector2.ZERO, -1.0, false, shooter)
	await physics_frames(3)
	check(is_instance_valid(first), "a light hit does not set a barrel off")
	first.take_hit(50, Vector2.ZERO, -1.0, false, shooter)
	await physics_frames(5)
	check(not is_instance_valid(first), "enough damage blows the barrel up")
	check(not is_instance_valid(second), "the blast sets off the barrel next to it")
	check(victim.health.current < victim.health.max_health, "the blast hurts a fighter next to the barrel")
	check(shooter.health.current == shooter.health.max_health, "fighters far away are not hurt")
	await physics_frames(int(victim.fighter_class.knockdown_time * 60) + 40)

	var third := _barrel(Vector2(120, FLOOR_Y))
	# One jab is enough; the test is about reach, not how much a barrel takes.
	third.health = 1
	await physics_frames(3)
	var killed_by: Array = []
	victim.died.connect(func(killer: Fighter) -> void: killed_by.append(killer))
	victim.health.current = 1
	victim.global_position = Vector2(150, FLOOR_Y)
	shooter.global_position = Vector2(106, FLOOR_Y)
	await physics_frames(3)
	shooter.controller.attack = true
	await physics_frames(2)
	shooter.controller.attack = false
	await physics_frames(5)
	check(not is_instance_valid(third), "a punch sets off a barrel in reach")
	check(killed_by == [shooter], "a barrel kill is credited to whoever set it off")


func _add_platform(top_middle: Vector2, width: float) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(width, 4)
	shape.position.y = 2
	shape.one_way_collision = true
	body.add_child(shape)
	body.position = top_middle
	arena.add_child(body)


func _barrel(at: Vector2) -> ExplosiveBarrel:
	var barrel := ExplosiveBarrel.new()
	barrel.collision_layer = 1 | Fighter.FIGHTERS_LAYER
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(12, 18)
	shape.position.y = -9
	barrel.add_child(shape)
	barrel.position = at
	arena.add_child(barrel)
	return barrel


func _spawn(at: Vector2) -> Fighter:
	var fighter: Fighter = FIGHTER_SCENE.instantiate()
	fighter.character = FAST
	arena.add_child(fighter)
	fighter.global_position = at
	return fighter
