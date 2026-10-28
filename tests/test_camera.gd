# Run: tests/run_all.sh test_camera
extends "res://tests/test_case.gd"

## The camera shows the map through shots: the closest shot holding every living fighter,
## held while they stay in it, the whole map when no closer shot holds them, and always
## landing exactly on one of the crisp zooms.

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const FAST := preload("res://data/characters/placeholder.tres")
## Two close shots side by side on a 1280x720 map; the whole map is the 1.5 shot.
const LEFT := Vector2(320, 180)
const RIGHT := Vector2(960, 180)
const MIDDLE := Vector2(640, 360)

var arena: Arena


func run() -> void:
	var camera := await _open(Rect2(0, 0, 1280, 720), [LEFT, RIGHT])
	check(camera.whole_map == Rect2(0, 0, 1280, 720), "a 1280x720 map's whole-map shot is all of it")
	var left := _spawn(Vector2(100, 328))
	await physics_frames(3)
	check(_on_shot(camera, LEFT, 3.0), "a lone fighter is shown in the close shot around it, on the first frame")

	var right := _spawn(Vector2(600, 328))
	await physics_frames(5)
	check(_on_shot(camera, LEFT, 3.0), "a fighter still inside the held shot keeps it, even near its edge")
	# Held in the air past the test arena's floor, so it does not fall out of the map.
	right.set_physics_process(false)
	right.global_position.x = 700.0
	await physics_frames(150)
	check(_on_shot(camera, MIDDLE, 1.5), "fighters no close shot holds get the whole-map shot, at exactly 1.5")
	check(_view(camera).has_point(left.center()) and _view(camera).has_point(right.center()), "both fighters are on screen")

	right.global_position.x = 300.0
	right.set_physics_process(true)
	await physics_frames(150)
	check(_on_shot(camera, LEFT, 3.0), "fighters coming together bring back the close shot, at exactly 3")

	var far := _spawn(Vector2(900, 200))
	var other_far := _spawn(Vector2(1000, 200))
	far.set_physics_process(false)
	other_far.set_physics_process(false)
	left.take_hit(1000)
	right.take_hit(1000)
	await physics_frames(200)
	check(_on_shot(camera, RIGHT, 3.0), "dead fighters are left out; the others get the shot around them")

	camera = await _open(Rect2(0, 0, 640, 360), [])
	_spawn(Vector2(40, 328))
	_spawn(Vector2(600, 328))
	await physics_frames(60)
	check(_on_shot(camera, Vector2(320, 180), 3.0), "a map one screen big is its own shot at the art zoom")

	camera = await _open(Rect2(0, 0, 2560, 1440), [])
	check(camera.whole_map.size == FollowCamera.MAX_MAP_SIZE, "the biggest map's whole-map shot is at MIN_ZOOM")


## A fresh test arena with these camera limits and close shots at `shots`; returns its
## camera once it is ready.
func _open(limits: Rect2, shots: Array) -> FollowCamera:
	if arena:
		arena.queue_free()
		await physics_frames(1)
	arena = load("res://scenes/arenas/test_arena.tscn").instantiate()
	arena.get_node("ItemSpawns/W1").interval = 9999.0
	arena.camera_limits = limits
	arena.bounds = limits.grow(1000.0)
	for at: Vector2 in shots:
		var shot := CameraShot.new()
		shot.position = at
		arena.add_child(shot)
	root.add_child(arena)
	await physics_frames(1)
	return arena.get_node("Camera2D")


func _on_shot(camera: FollowCamera, center: Vector2, zoom: float) -> bool:
	return camera.zoom == Vector2.ONE * zoom and camera.get_screen_center_position() == center


func _view(camera: FollowCamera) -> Rect2:
	var size := camera.get_viewport_rect().size / camera.zoom
	return Rect2(camera.get_screen_center_position() - size / 2.0, size)


func _spawn(at: Vector2) -> Fighter:
	var fighter: Fighter = FIGHTER_SCENE.instantiate()
	fighter.character = FAST
	arena.add_child(fighter)
	fighter.global_position = at
	return fighter
