class_name FollowCamera
extends Camera2D

## The arena's camera. Keeps every living fighter in view with one uniform zoom, so
## the whole picture scales together: it sits at `art_zoom`, where one pixel of the 3x
## character art is one screen pixel, and pulls back while the fighters spread. It can
## pull back until the whole map fits (never below `min_zoom`), so on any map that fits
## at `min_zoom` every fighter is always on screen. It never shows past `camera_limits`.

## Screen pixels per world pixel at which the character art is drawn pixel for pixel.
## Closer than this the art would be magnified, so the camera never goes past it.
@export var art_zoom := 3.0
## Furthest pull-back on any map. A 96 px tall character is then 24 px tall on a 1080p
## screen, the smallest it stays readable; a 1920x1080 view then covers 2560x1440 world
## pixels, the largest map that always shows every fighter.
@export var min_zoom := 0.75
## Fraction of the screen kept free around the fighters on each side.
@export_range(0.0, 0.45) var margin := 0.15
## How fast the camera catches up with the fighters; higher is snappier.
@export var follow_speed := 6.0
## Pulling back is quick, so a fighter running off never leaves the screen.
@export var zoom_out_speed := 4.0
## Moving in is calm, so the view does not pump in and out with every jump.
@export var zoom_in_speed := 1.5
## A settled camera starts moving in only once it would gain at least this factor (or
## reach art_zoom), so small back-and-forth moves leave the zoom alone.
@export var zoom_in_threshold := 1.1

## Furthest zoom on this map: the whole map fits, but never below min_zoom.
var furthest_zoom := 0.0
var _placed := false
## True once the zoom has landed on its target; a move in, once started, runs to the end.
var _settled := true


func _ready() -> void:
	zoom = Vector2.ONE * art_zoom
	furthest_zoom = min_zoom
	var arena := get_parent() as Arena
	if arena:
		var area := Rect2(arena.to_global(arena.camera_limits.position), arena.camera_limits.size)
		limit_left = int(area.position.x)
		limit_top = int(area.position.y)
		limit_right = int(area.end.x)
		limit_bottom = int(area.end.y)
		var view := get_viewport_rect().size
		# Pulling back further than the map would only show what lies outside it.
		furthest_zoom = clampf(maxf(view.x / area.size.x, view.y / area.size.y), min_zoom, art_zoom)


func _physics_process(delta: float) -> void:
	var box := _fighters_box()
	if box.position == Vector2.INF:
		return
	var target := clampf(_zoom_to_fit(box.size), furthest_zoom, art_zoom)
	if not _placed:
		_placed = true
		global_position = box.get_center()
		zoom = Vector2.ONE * target
		return
	var current := zoom.x
	if _settled and target > current and target < art_zoom and target < current * zoom_in_threshold:
		target = current
	var speed := zoom_out_speed if target < current else zoom_in_speed
	# Zoom is a scale, so it eases in log space: every step changes the view by the
	# same proportion whether the camera is close or far.
	var next := exp(lerpf(log(current), log(target), 1.0 - exp(-speed * delta)))
	# Land exactly on the target so the art is not left at an almost-1:1 scale.
	_settled = absf(log(next / target)) < 0.005
	zoom = Vector2.ONE * (target if _settled else next)
	global_position = global_position.lerp(box.get_center(), 1.0 - exp(-follow_speed * delta))


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
