# Run: tests/run_all.sh test_camera
extends "res://tests/test_case.gd"

## The follow camera keeps living fighters in view: art zoom for a lone fighter,
## zoomed out (never past min_zoom) when they spread, and never past the camera limits.

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const FAST := preload("res://data/characters/placeholder.tres")

var arena: Arena


func run() -> void:
	arena = load("res://scenes/arenas/test_arena.tscn").instantiate()
	arena.get_node("ItemSpawns/W1").interval = 9999.0
	arena.camera_limits = Rect2(-2000, -2000, 4000, 4000)
	arena.bounds = Rect2(-3000, -3000, 6000, 6000)
	root.add_child(arena)
	var camera: FollowCamera = arena.get_node("Camera2D")
	var left := _spawn(Vector2(40, 328))
	await physics_frames(5)
	check(camera.zoom.x == camera.art_zoom, "a lone fighter is shown at the art zoom")
	check(camera.get_screen_center_position().distance_to(left.center()) < 1.0, "the first frame snaps onto the fighter")

	var right := _spawn(Vector2(600, 328))
	await physics_frames(120)
	var fit := (camera.get_viewport_rect().size.x * (1.0 - 2.0 * camera.margin)) / (right.center().x - left.center().x)
	check(absf(camera.zoom.x - fit) < 0.01, "spread fighters zoom out to fit (%.2f, want %.2f)" % [camera.zoom.x, fit])
	var view := Rect2(camera.get_screen_center_position() - camera.get_viewport_rect().size / camera.zoom / 2.0, camera.get_viewport_rect().size / camera.zoom)
	check(view.has_point(left.center()) and view.has_point(right.center()), "both fighters are on screen")

	var far := _spawn(Vector2(2000, 0))
	far.set_physics_process(false)
	await physics_frames(120)
	check(camera.zoom.x == camera.min_zoom, "zoom never goes below min_zoom")
	far.take_hit(1000)
	await physics_frames(180)
	check(absf(camera.zoom.x - fit) < 0.01, "dead fighters are left out of the view")

	arena.queue_free()
	await physics_frames(1)
	arena = load("res://scenes/arenas/test_arena.tscn").instantiate()
	arena.get_node("ItemSpawns/W1").interval = 9999.0
	root.add_child(arena)
	camera = arena.get_node("Camera2D")
	_spawn(Vector2(40, 328))
	await physics_frames(5)
	var center := camera.get_screen_center_position()
	check(center.is_equal_approx(Vector2(320, 180)), "the view stays inside the camera limits (%s)" % [center])


func _spawn(at: Vector2) -> Fighter:
	var fighter: Fighter = FIGHTER_SCENE.instantiate()
	fighter.character = FAST
	arena.add_child(fighter)
	fighter.global_position = at
	return fighter
