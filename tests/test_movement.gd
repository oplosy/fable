# Run: godot --headless --path . -s res://tests/test_movement.gd
extends "res://tests/test_case.gd"

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const FAST := preload("res://data/characters/placeholder.tres")

var arena: Node2D


func run() -> void:
	arena = load("res://scenes/arenas/test_arena.tscn").instantiate()
	root.add_child(arena)
	var fighter := _spawn(Vector2(100, 328))
	await physics_frames(10)
	# The fighter creates its idle controller in _ready.
	var input: FighterController = fighter.controller

	# Walk and run speeds.
	input.move = 1.0
	await physics_frames(40)
	check(is_equal_approx(fighter.velocity.x, fighter.walk_speed), "fighter walks at walk speed")
	check(not fighter.is_running(), "walking is not running")
	input.run = true
	await physics_frames(20)
	check(is_equal_approx(fighter.velocity.x, fighter.run_speed) and fighter.is_running(), "run intent speeds up to run speed")

	# A walking jump goes straight up, with no steering in the air.
	_reset(fighter, 100)
	input.run = false
	await physics_frames(20)
	await _tap(fighter, "jump")
	var takeoff_x := fighter.position.x
	await physics_frames(20)
	check(not fighter.is_on_floor() and not fighter.is_diving(), "walking jump is a normal jump")
	check(absf(fighter.position.x - takeoff_x) < 0.5, "walking jump goes straight up while move is held")
	input.move = 0.0
	await physics_frames(60)
	check(fighter.is_on_floor(), "fighter lands")

	# A running jump is a forward dive.
	_reset(fighter, 100)
	input.move = 1.0
	input.run = true
	await physics_frames(20)
	await _tap(fighter, "jump")
	takeoff_x = fighter.position.x
	check(fighter.is_diving() and fighter.velocity.x > fighter.run_speed, "running jump starts a forward dive")
	input.move = -1.0
	await _tap(fighter, "attack")
	check(not fighter.melee.is_attacking(), "no attacking during a dive")
	await physics_frames(10)
	check(fighter.facing == 1 and fighter.velocity.x > 0.0, "a dive cannot be steered or turned")
	check(is_equal_approx(fighter.get_node("Visuals").rotation, PI / 2.0), "diver is head-first")
	input.move = 0.0
	for i in 60:
		if fighter.is_on_floor():
			break
		await physics_frames(1)
	check(fighter.position.x - takeoff_x > 80.0, "dive covers ground")
	await physics_frames(2)
	check(not fighter.is_diving() and fighter.get_node("Visuals").rotation == 0.0, "landing ends the dive")

	# Down while running rolls forward, out of reach of hits.
	_reset(fighter, 100)
	input.move = 1.0
	input.run = false
	await physics_frames(20)
	await _tap(fighter, "down")
	check(not fighter.is_rolling(), "down while walking does not roll")
	input.run = true
	await physics_frames(20)
	await _tap(fighter, "down")
	var roll_x := fighter.position.x
	check(fighter.is_rolling() and fighter.is_invulnerable() and fighter.collision_layer == 0, "down while running rolls invulnerably")
	input.move = 0.0
	var health_before := fighter.health.current
	fighter.take_hit(10)
	check(fighter.health.current == health_before, "a rolling fighter cannot be hit")
	await physics_frames(int(fighter.roll_time * 60) - 2)
	check(fighter.is_rolling() and fighter.position.x - roll_x > 60.0, "roll keeps moving forward without input")
	await physics_frames(4)
	check(not fighter.is_rolling() and fighter.collision_layer == Fighter.FIGHTERS_LAYER, "roll ends and the fighter is hittable again")
	fighter.take_hit(10)
	check(fighter.health.current == health_before - 10, "hits land after the roll")

	await _test_local_controller()


## Shift or a double tap of a direction runs.
func _test_local_controller() -> void:
	var local := LocalController.new()
	var fighter := _spawn(Vector2(300, 328), local)
	await physics_frames(5)

	Input.action_press("p1_right")
	await physics_frames(10)
	check(not local.run, "holding a direction walks")
	Input.action_release("p1_right")
	await physics_frames(20)
	Input.action_press("p1_right")
	await physics_frames(2)
	check(not local.run, "a slow second tap still walks")
	Input.action_release("p1_right")
	await physics_frames(3)
	Input.action_press("p1_right")
	await physics_frames(2)
	check(local.run and fighter.is_running(), "a quick double tap runs")
	await physics_frames(30)
	check(local.run, "the run lasts while the direction is held")
	Input.action_release("p1_right")
	await physics_frames(2)
	check(not local.run, "releasing the direction ends the run")

	Input.action_press("p1_left")
	await physics_frames(3)
	Input.action_release("p1_left")
	Input.action_press("p1_right")
	await physics_frames(2)
	check(not local.run, "tapping opposite directions does not run")
	Input.action_press("p1_run")
	await physics_frames(2)
	check(local.run, "holding Shift runs")
	Input.action_release("p1_run")
	Input.action_release("p1_right")


func _tap(fighter: Fighter, intent: String) -> void:
	fighter.controller.set(intent, true)
	await physics_frames(1)
	fighter.controller.set(intent, false)


func _spawn(at: Vector2, controller: FighterController = null) -> Fighter:
	var fighter: Fighter = FIGHTER_SCENE.instantiate()
	fighter.character = FAST
	fighter.controller = controller
	arena.add_child(fighter)
	fighter.global_position = at
	return fighter


func _reset(fighter: Fighter, x: float) -> void:
	fighter.controller.move = 0.0
	fighter.global_position = Vector2(x, 328)
	fighter.velocity = Vector2.ZERO
