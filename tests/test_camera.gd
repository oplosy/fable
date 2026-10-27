# Run: tests/run_all.sh test_camera
extends "res://tests/test_case.gd"

## The follow camera keeps living fighters in view with one zoom: art zoom for a lone
## fighter, pulled back to fit spread fighters, never further than the whole map,
## calm about small moves, and never past the camera limits.

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const FAST := preload("res://data/characters/placeholder.tres")

var arena: Arena


func run() -> void:
	var camera := await _open(Rect2(Vector2(-1000, -1080), FollowCamera.MAX_MAP_SIZE))
	check(camera.furthest_zoom == FollowCamera.MIN_ZOOM, "the biggest allowed map pulls back to MIN_ZOOM")
	var left := _spawn(Vector2(40, 328))
	await physics_frames(5)
	check(camera.zoom.x == camera.art_zoom, "a lone fighter is shown at the art zoom")
	# Only x: the map's bottom edge keeps the view from centring on the floor level.
	check(absf(camera.get_screen_center_position().x - left.center().x) < 1.0, "the first frame snaps onto the fighter")

	var right := _spawn(Vector2(600, 328))
	await physics_frames(120)
	var fit := _fit(camera, right.center().x - left.center().x)
	check(absf(camera.zoom.x - fit) < 0.01, "spread fighters pull the camera back to fit (%.2f, want %.2f)" % [camera.zoom.x, fit])
	check(_view(camera).has_point(left.center()) and _view(camera).has_point(right.center()), "both fighters are on screen")

	right.global_position.x -= 30.0
	await physics_frames(60)
	check(absf(camera.zoom.x - fit) < 0.01, "a small step closer leaves the zoom alone (%.2f)" % camera.zoom.x)

	var far := _spawn(Vector2(-950, 0))
	var other_far := _spawn(Vector2(1500, 0))
	far.set_physics_process(false)
	other_far.set_physics_process(false)
	await physics_frames(120)
	check(camera.zoom.x == camera.furthest_zoom, "fighters at the map's ends pull back to the furthest zoom, quickly")
	check(_view(camera).has_point(far.center()) and _view(camera).has_point(other_far.center()), "fighters at the map's ends are both on screen")
	far.take_hit(1000)
	other_far.take_hit(1000)
	await physics_frames(300)
	fit = _fit(camera, right.center().x - left.center().x)
	check(absf(camera.zoom.x - fit) < 0.01, "dead fighters are left out of the view (%.2f, want %.2f)" % [camera.zoom.x, fit])
	right.global_position.x = 200.0
	await physics_frames(300)
	check(camera.zoom.x == camera.art_zoom, "fighters coming together bring the camera back to the art zoom exactly")

	camera = await _open(Rect2(0, 0, 2000, 1000))
	check(is_equal_approx(camera.furthest_zoom, 1080.0 / 1000.0), "a large map pulls back just far enough to show all of it")

	camera = await _open(Rect2(0, 0, 640, 360))
	_spawn(Vector2(40, 328))
	_spawn(Vector2(600, 328))
	await physics_frames(60)
	check(camera.zoom.x == camera.art_zoom, "a map one screen big is always shown at the art zoom")
	var center := camera.get_screen_center_position()
	check(center.is_equal_approx(Vector2(320, 180)), "the view stays inside the camera limits (%s)" % [center])


## A fresh test arena with these camera limits; returns its camera once it is ready.
func _open(limits: Rect2) -> FollowCamera:
	if arena:
		arena.queue_free()
		await physics_frames(1)
	arena = load("res://scenes/arenas/test_arena.tscn").instantiate()
	arena.get_node("ItemSpawns/W1").interval = 9999.0
	arena.camera_limits = limits
	arena.bounds = limits.grow(1000.0)
	root.add_child(arena)
	await physics_frames(1)
	return arena.get_node("Camera2D")


func _fit(camera: FollowCamera, width: float) -> float:
	return camera.get_viewport_rect().size.x * (1.0 - 2.0 * camera.margin) / width


func _view(camera: FollowCamera) -> Rect2:
	var size := camera.get_viewport_rect().size / camera.zoom
	return Rect2(camera.get_screen_center_position() - size / 2.0, size)


func _spawn(at: Vector2) -> Fighter:
	var fighter: Fighter = FIGHTER_SCENE.instantiate()
	fighter.character = FAST
	arena.add_child(fighter)
	fighter.global_position = at
	return fighter
