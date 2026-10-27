# Run: tests/run_all.sh test_arenas
extends "res://tests/test_case.gd"

## Every arena scene follows the map rules, so a new map cannot break the game:
## an Arena root with spawn points, item spawns and a follow camera, and a camera area
## no bigger than FollowCamera.MAX_MAP_SIZE, so every fighter is always on screen.

const ARENAS := "res://scenes/arenas/"


func run() -> void:
	var view := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))
	check(FollowCamera.MAX_MAP_SIZE == view / FollowCamera.MIN_ZOOM, "the map size limit is the render size at the furthest zoom")
	var oversized := Arena.new()
	oversized.camera_limits = Rect2(Vector2.ZERO, FollowCamera.MAX_MAP_SIZE + Vector2(16, 0))
	check(not oversized.fits_camera(), "a map one tile wider than the limit is rejected")
	oversized.free()

	var found := 0
	for file in DirAccess.get_files_at(ARENAS):
		if not file.ends_with(".tscn"):
			continue
		found += 1
		var arena := load(ARENAS + file).instantiate() as Arena
		check(arena != null, "%s: the root is an Arena" % file)
		if arena == null:
			continue
		check(arena.fits_camera(), "%s: camera_limits %s fit in %s" % [file, arena.camera_limits.size, FollowCamera.MAX_MAP_SIZE])
		check(arena.bounds.encloses(arena.camera_limits), "%s: the whole visible map lies inside the arena bounds" % file)
		check(arena.get_node_or_null("SpawnPoints") != null and arena.get_node("SpawnPoints").get_child_count() >= 2, "%s: has at least two spawn points" % file)
		check(arena.get_node_or_null("ItemSpawns") != null, "%s: has ItemSpawns" % file)
		check(arena.find_children("*", "FollowCamera", false).size() == 1, "%s: has one FollowCamera" % file)
		arena.free()
	check(found > 0, "found the arena scenes")
