# Run: tests/run_all.sh test_isles
extends "res://tests/test_case.gd"

## The Isles map can be played by both classes: every ladder stands on a floor and leads
## to a one-way platform's top, the pit is narrow enough to jump, and the bridge over it
## is low enough to jump onto.

const CLASSES := [preload("res://data/classes/fast.tres"), preload("res://data/classes/heavy.tres")]


func run() -> void:
	var arena: Node2D = load("res://scenes/arenas/isles.tscn").instantiate()
	root.add_child(arena)
	var tops := {}
	for body: Node2D in arena.get_node("Platforms").get_children():
		tops[body.name] = _top_edge(body)
	var floors: Array = tops.values() + [_top_edge(arena.get_node("GroundWest")), _top_edge(arena.get_node("GroundEast"))]
	for ladder in arena.find_children("*", "Ladder", true, false):
		var x: float = ladder.global_position.x
		check(floors.any(func(r: Rect2) -> bool: return is_equal_approx(r.position.y, ladder.bottom()) and x > r.position.x and x < r.end.x),
				"%s stands on a floor" % ladder.name)
		check(tops.values().any(func(r: Rect2) -> bool: return is_equal_approx(r.position.y, ladder.top()) and x > r.position.x and x < r.end.x),
				"%s leads to a one-way platform's top" % ladder.name)

	var west := _top_edge(arena.get_node("GroundWest"))
	var east := _top_edge(arena.get_node("GroundEast"))
	var pit := east.position.x - west.end.x
	var bridge_rise: float = west.position.y - tops["Bridge"].position.y
	var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	for fighter_class: FighterClass in CLASSES:
		var jump_height := fighter_class.jump_velocity ** 2 / (2.0 * gravity * fighter_class.gravity_scale)
		check(pit <= fighter_class.jump_reach(), "%s jumps the %d px pit (reach %.0f)" % [fighter_class.resource_path.get_file(), pit, fighter_class.jump_reach()])
		check(bridge_rise <= jump_height - 4.0, "%s jumps onto the bridge %d px up (jump %.0f)" % [fighter_class.resource_path.get_file(), bridge_rise, jump_height])
	arena.free()


## The world rect of a static body's single rectangle shape.
func _top_edge(body: Node2D) -> Rect2:
	var shape: CollisionShape2D = body.get_child(0)
	var size: Vector2 = (shape.shape as RectangleShape2D).size
	return Rect2(shape.global_position - size / 2.0, size)
