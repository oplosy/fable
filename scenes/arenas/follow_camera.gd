class_name FollowCamera
extends Camera2D

## The arena's camera. Keeps every living fighter in view: it sits at `art_zoom`, where
## one pixel of the 3x character art is one screen pixel, and zooms out only while the
## fighters are spread wider than the screen holds (never below `min_zoom`). It never
## shows anything outside the arena's `camera_limits`.

## Screen pixels per world pixel at which the character art is drawn pixel for pixel.
@export var art_zoom := 3.0
## Furthest zoom-out. Below art_zoom the detailed art is drawn smaller than 1:1.
@export var min_zoom := 1.5
## Fraction of the screen kept free around the fighters on each side.
@export_range(0.0, 0.45) var margin := 0.15
## How fast the camera catches up; higher is snappier.
@export var follow_speed := 6.0

var _placed := false


func _ready() -> void:
	zoom = Vector2.ONE * art_zoom
	var arena := get_parent() as Arena
	if arena:
		var area := Rect2(arena.to_global(arena.camera_limits.position), arena.camera_limits.size)
		limit_left = int(area.position.x)
		limit_top = int(area.position.y)
		limit_right = int(area.end.x)
		limit_bottom = int(area.end.y)


func _physics_process(delta: float) -> void:
	var box := _fighters_box()
	if box.position == Vector2.INF:
		return
	var target_zoom := clampf(_zoom_to_fit(box.size), min_zoom, art_zoom)
	if not _placed:
		_placed = true
		global_position = box.get_center()
		zoom = Vector2.ONE * target_zoom
		return
	var weight := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(box.get_center(), weight)
	var next := lerpf(zoom.x, target_zoom, weight)
	# Land exactly on the target so the art is not left at an almost-1:1 scale.
	zoom = Vector2.ONE * (target_zoom if absf(next - target_zoom) < 0.01 else next)


## Bounding box of the living fighters in this camera's arena; position INF when there are none.
func _fighters_box() -> Rect2:
	var box := Rect2(Vector2.INF, Vector2.ZERO)
	for fighter: Fighter in get_tree().get_nodes_in_group(Fighter.GROUP):
		if fighter.is_dead() or not get_parent().is_ancestor_of(fighter):
			continue
		if box.position == Vector2.INF:
			box = Rect2(fighter.center(), Vector2.ZERO)
		else:
			box = box.expand(fighter.center())
	return box


## The largest zoom that still shows a box of `size` world pixels inside the margins.
func _zoom_to_fit(size: Vector2) -> float:
	var room := get_viewport_rect().size * (1.0 - 2.0 * margin)
	return minf(room.x / maxf(size.x, 1.0), room.y / maxf(size.y, 1.0))
